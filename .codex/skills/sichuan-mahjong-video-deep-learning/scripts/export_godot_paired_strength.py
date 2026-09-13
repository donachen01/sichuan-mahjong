#!/usr/bin/env python3
"""Bind a Godot paired-policy report to a frozen strength plan."""
import argparse
import hashlib
import json
from pathlib import Path


def canonical_sha256(value):
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return hashlib.sha256(payload).hexdigest()


def demand(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    report = json.loads(args.report.read_text(encoding="utf-8"))
    demand(report.get("game_origin") == "natural_full_round", "report is not natural full round evidence")
    demand(report.get("candidate_policy", "").endswith(plan["candidate_policy_variant"]), "candidate policy changed")
    demand(report.get("baseline_policy") == "bone_ash_current", "baseline policy changed")
    demand(report.get("opponent_policy") == plan["opponent_version"], "opponent policy changed")
    rows = []
    for game in report.get("game_results", []):
        seed, seat = int(game["seed"]), int(game["candidate_seat"])
        group_id = f"natural-seed-{seed}"
        for arm_name in ("baseline", "candidate"):
            arm = game[f"{arm_name}_arm"]
            rows.append({
                "group_id": group_id,
                "seed": seed,
                "seat": seat,
                "arm": arm_name,
                "version": plan[f"{arm_name}_version"],
                "rules_sha256": plan["rules_sha256"],
                "opponent_version": plan["opponent_version"],
                "game_origin": arm.get("game_origin"),
                "completed": arm.get("completed"),
                "uses_hidden_information": arm.get("uses_hidden_information"),
                "initial_wall_sha256": arm.get("initial_wall_hash"),
                "replay_sha256": arm.get("replay_hash"),
                "net_score": arm.get("seat_delta"),
                "deal_in_rate": arm.get("deal_in_rate", 0.0),
                "latency_p95_ms": arm.get("mechanism_decision_latency_p95_ms", 0.0),
                "mechanism_trigger_count": game.get("candidate_override_triggers", 0) if arm_name == "candidate" else 0,
            })
    runs = {
        "plan_sha256": canonical_sha256(plan),
        "started_at": report["measurement_started_at"],
        "completed_at": report.get("measurement_completed_at"),
        "measurement_kind": "full_game_settlement",
        "source_report_sha256": hashlib.sha256(args.report.read_bytes()).hexdigest(),
        "integrity": {
            "completed_arms": report.get("complete_game_arms"),
            "forced_stop_games": report.get("forced_stop_games"),
            "ledger_failure_games": report.get("ledger_failure_games"),
            "initial_world_mismatch_pairs": report.get("initial_world_mismatch_pairs"),
            "checkpoint_legality_failure_arms": report.get("checkpoint_legality_failure_arms"),
            "baseline_override_triggers": report.get("baseline_override_triggers"),
        },
        "rows": rows,
    }
    args.output.write_text(json.dumps(runs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "plan_sha256": runs["plan_sha256"], "rows": len(rows)}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(str(exc))
