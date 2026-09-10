#!/usr/bin/env python3
"""Evaluate predeclared full-game paired results, never internal proxy scores."""
import argparse
import hashlib
import json
import math
import random
import statistics
from datetime import datetime
from pathlib import Path


def demand(condition, message):
    if not condition:
        raise ValueError(message)


def plan_hash(plan):
    return hashlib.sha256(json.dumps(plan, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def evaluate(plan, runs):
    demand(runs.get("plan_sha256") == plan_hash(plan), "results not bound to frozen plan")
    frozen = datetime.fromisoformat(plan["frozen_at"].replace("Z", "+00:00"))
    started = datetime.fromisoformat(runs["started_at"].replace("Z", "+00:00"))
    demand(frozen.tzinfo and started.tzinfo and frozen < started, "strength plan not frozen before measurement")
    demand(plan.get("primary_metric") == "net_score", "use actual settlement net score")
    demand(plan.get("baseline_version") and plan.get("candidate_version") and plan["baseline_version"] != plan["candidate_version"], "distinct frozen versions required")
    demand(plan.get("rules_sha256") and plan.get("opponent_version"), "freeze rules and opponents")
    demand(plan.get("min_deals", 0) >= 2 and 0 < plan.get("alpha", 0) < .5, "invalid sample/confidence plan")
    for field in ("min_mean_gain", "max_deal_in_increase", "max_p95_latency_ms"):
        demand(type(plan.get(field)) in (int, float) and math.isfinite(plan[field]), f"missing finite threshold: {field}")
    demand(plan.get("seats") == [0, 1, 2, 3], "require all four seat rotations")
    train, heldout = set(plan.get("training_groups", [])), set(plan.get("heldout_groups", []))
    demand(heldout and not train.intersection(heldout), "training and heldout source-game groups overlap")
    required_trigger_seats = plan.get("required_trigger_seats", {})
    demand(isinstance(required_trigger_seats, dict), "required_trigger_seats must be a group-to-seat mapping")
    if required_trigger_seats:
        demand(set(required_trigger_seats) == heldout, "required trigger mapping must cover every heldout opportunity group exactly")
        demand(all(type(seat) is int and seat in plan["seats"] for seat in required_trigger_seats.values()),
               "required trigger mapping contains an invalid seat")
    demand(runs.get("measurement_kind") == "full_game_settlement", "proxy oracle/regret scores are not playing strength")
    demand(isinstance(runs.get("rows"), list) and runs["rows"], "no measured games")
    pairs = {}
    wall_owners = {}
    mechanism_triggers = 0
    for row in runs["rows"]:
        demand(row.get("group_id") in heldout, "outside heldout population")
        for field in ("rules_sha256", "opponent_version"):
            demand(row.get(field) == plan[field], f"changed {field}")
        demand(row.get("arm") in {"baseline", "candidate"}, "invalid arm")
        demand(row.get("version") == plan[row["arm"] + "_version"], "changed policy version")
        demand(row.get("seat") in plan["seats"] and type(row.get("seed")) is int, "invalid seat/seed")
        demand(row.get("completed") is True and row.get("uses_hidden_information") is False, "incomplete or oracle-assisted game")
        demand(row.get("game_origin") == "natural_full_round", "strength row is not a natural full round")
        demand(row.get("initial_wall_sha256") and row.get("replay_sha256"), "missing deal/replay provenance")
        owner = wall_owners.setdefault(row["initial_wall_sha256"], row["group_id"])
        demand(owner == row["group_id"], "same initial deal counted as independent groups")
        for field in ("net_score", "deal_in_rate", "latency_p95_ms"):
            demand(type(row.get(field)) in (int, float) and math.isfinite(row[field]), f"invalid metric: {field}")
        demand(0 <= row["deal_in_rate"] <= 1 and row["latency_p95_ms"] >= 0, "invalid rate/latency")
        key = (row["group_id"], row["seed"], row["seat"])
        demand(row["arm"] not in pairs.setdefault(key, {}), "duplicate game arm")
        pairs[key][row["arm"]] = row
        if row["arm"] == "candidate":
            mechanism_triggers += int(row.get("mechanism_trigger_count", 0))
    grouped, risk, latency = {}, [], []
    reproduced_trigger_groups = set()
    for (group, seed, seat), pair in pairs.items():
        demand(set(pair) == {"baseline", "candidate"}, "missing paired arm")
        old, new = pair["baseline"], pair["candidate"]
        demand(old["initial_wall_sha256"] == new["initial_wall_sha256"], "different initial walls")
        grouped.setdefault((group, seed), {})[seat] = new["net_score"] - old["net_score"]
        risk.append(new["deal_in_rate"] - old["deal_in_rate"])
        latency.append(new["latency_p95_ms"])
        if required_trigger_seats.get(group) == seat and int(new.get("mechanism_trigger_count", 0)) > 0:
            reproduced_trigger_groups.add(group)
    clusters = {}
    for (group, _), rotations in grouped.items():
        demand(set(rotations) == set(plan["seats"]), "incomplete seat rotation")
        clusters.setdefault(group, []).append(statistics.mean(rotations.values()))
    # Seats, frames and synthetic variants of one original game are NOT
    # independent samples. Bootstrap at the original-game cluster level.
    demand(set(clusters) == heldout, "omitted heldout groups")
    values = [statistics.mean(v) for v in clusters.values()]
    demand(len(values) >= plan["min_deals"], "insufficient independent game groups")
    rng = random.Random(plan.get("bootstrap_seed", 0))
    samples = sorted(statistics.mean(rng.choices(values, k=len(values))) for _ in range(4000))
    lower = samples[int(4000 * plan["alpha"] / 2)]
    upper = samples[min(3999, int(4000 * (1 - plan["alpha"] / 2)))]
    mean = statistics.mean(values)
    required_integrity = plan.get("required_integrity", {})
    observed_integrity = runs.get("integrity", {})
    integrity_ok = all(observed_integrity.get(field) == expected for field, expected in required_integrity.items())
    checks = {"positive_confidence_lower_bound": lower > 0,
              "minimum_mean_gain": mean >= plan["min_mean_gain"],
              "deal_in_guardrail": max(risk) <= plan["max_deal_in_increase"],
              "latency_guardrail": max(latency) <= plan["max_p95_latency_ms"],
              "mechanism_exercised": "mechanism_trigger_min" not in plan or mechanism_triggers >= plan["mechanism_trigger_min"],
              "selected_opportunities_reproduced": not required_trigger_seats or reproduced_trigger_groups == heldout,
              "integrity_gate": integrity_ok}
    return {"promotable": all(checks.values()), "independent_groups": len(values),
            "paired_rotations": len(pairs), "mean_net_score_gain": mean,
            "confidence_interval": [lower, upper], "mechanism_triggers": mechanism_triggers,
            "integrity": observed_integrity, "checks": checks,
            "scope": "Declared rules/opponents/heldout population only; not expert-level equivalence."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("runs", type=Path)
    args = parser.parse_args()
    try:
        result = evaluate(json.loads(args.plan.read_text()), json.loads(args.runs.read_text()))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        result = {"promotable": False, "errors": [str(exc)]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["promotable"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
