#!/usr/bin/env python3
"""Validate multi-source public wall-posterior calibration without reveal leakage."""

import argparse
import hashlib
import json
import math
import statistics
from datetime import datetime
from pathlib import Path


FORBIDDEN_PUBLIC_KEYS = {
    "actual_wall", "oracle_wall", "hidden_hands", "opponent_hands",
    "future_draws", "reveal", "reveal_label", "observed_outcome",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_hash(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def parse_time(value, field):
    require(isinstance(value, str) and value, f"missing {field}")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.tzinfo is not None, f"{field} must include timezone")
    return parsed


def walk_keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_keys(child)


def load_bound_json(base, row, path_key, hash_key):
    relative = row.get(path_key)
    require(isinstance(relative, str) and relative, f"missing {path_key}")
    path = (base / relative).resolve()
    require(path.is_file(), f"missing bound file: {relative}")
    require(digest(path) == row.get(hash_key), f"{hash_key} mismatch: {relative}")
    return json.loads(path.read_text(encoding="utf-8"))


def evaluate(plan, samples, base):
    require(samples.get("plan_sha256") == canonical_hash(plan), "calibration plan mismatch")
    require(plan.get("target") == "wall_inclusion_probability", "wrong posterior target")
    require(isinstance(plan.get("model_version"), str) and plan["model_version"], "missing model version")
    model_hash = plan.get("model_assembly_sha256")
    require(isinstance(model_hash, str) and len(model_hash) == 64, "invalid model assembly hash")
    train = set(plan.get("training_groups", []))
    heldout = set(plan.get("heldout_groups", []))
    require(len(train) >= 2 and len(heldout) >= 2 and train.isdisjoint(heldout),
            "need disjoint multi-source training and heldout groups")
    require(plan.get("min_heldout_groups", 0) >= 2, "insufficient heldout group gate")
    seeds = plan.get("seeds")
    require(isinstance(seeds, list) and len(seeds) >= 3 and len(seeds) == len(set(seeds))
            and all(type(seed) is int for seed in seeds), "need at least three unique frozen seeds")
    samples_per_seed = plan.get("samples_per_seed")
    require(type(samples_per_seed) is int and 32 <= samples_per_seed <= 4096,
            "invalid samples_per_seed")
    min_ess_ratio = plan.get("min_effective_sample_ratio")
    max_seed_range = plan.get("max_seed_range")
    max_brier = plan.get("max_brier")
    require(all(type(value) in (int, float) and math.isfinite(value)
                for value in (min_ess_ratio, max_seed_range, max_brier)), "invalid numeric gates")
    require(0 < min_ess_ratio <= 1 and 0 <= max_seed_range <= 1 and 0 <= max_brier <= 1,
            "numeric gates out of range")
    frozen = parse_time(plan.get("frozen_at"), "frozen_at")
    started = parse_time(samples.get("started_at"), "started_at")
    require(frozen < started, "plan must be frozen before measurement")

    rows = samples.get("rows")
    require(isinstance(rows, list) and rows, "no heldout posterior rows")
    ids, groups, errors, ranges, ess_ratios = set(), set(), [], [], []
    for row in rows:
        row_id = row.get("id")
        require(isinstance(row_id, str) and row_id and row_id not in ids, "duplicate/missing row id")
        ids.add(row_id)
        group = row.get("group_id")
        require(group in heldout, "row outside frozen heldout groups")
        groups.add(group)
        require(row.get("model_version") == plan["model_version"]
                and row.get("model_assembly_sha256") == model_hash, "model version/hash drift")
        require(isinstance(row.get("source_sha256"), str) and len(row["source_sha256"]) == 64,
                "invalid source hash")
        require(type(row.get("tile_type")) is int and 0 <= row["tile_type"] < 27,
                "invalid tile_type")

        public_input = load_bound_json(base, row, "public_input_path", "public_input_sha256")
        reveal_label = load_bound_json(base, row, "reveal_label_path", "reveal_label_sha256")
        require(not FORBIDDEN_PUBLIC_KEYS.intersection(walk_keys(public_input)),
                "forbidden reveal/hidden field in public input")
        require(public_input.get("information_mode") == "public", "public input mode required")
        require(public_input.get("source_sha256") == row["source_sha256"], "public input source mismatch")
        require(reveal_label.get("source_sha256") == row["source_sha256"], "reveal source mismatch")
        decision_time = reveal_label.get("decision_timestamp_seconds")
        label_time = reveal_label.get("label_timestamp_seconds")
        require(all(type(value) in (int, float) and math.isfinite(value)
                    for value in (decision_time, label_time)) and label_time > decision_time,
                "reveal label must occur after decision")
        observed = reveal_label.get("observed")
        require(observed in (0, 1) and observed == row.get("observed"), "invalid/mismatched observed label")
        require(reveal_label.get("tile_type") == row["tile_type"], "label tile mismatch")

        predictions = row.get("prediction_by_seed")
        require(isinstance(predictions, list) and len(predictions) == len(seeds),
                "missing seed predictions")
        by_seed = {item.get("seed"): item for item in predictions}
        require(set(by_seed) == set(seeds), "seed set mismatch")
        values = []
        for seed in seeds:
            item = by_seed[seed]
            prediction, ess = item.get("prediction"), item.get("effective_sample_size")
            require(type(prediction) in (int, float) and math.isfinite(prediction) and 0 <= prediction <= 1,
                    "invalid seed prediction")
            require(item.get("sample_count") == samples_per_seed, "sample count drift")
            require(type(ess) in (int, float) and math.isfinite(ess) and 0 < ess <= samples_per_seed,
                    "invalid effective sample size")
            ratio = ess / samples_per_seed
            require(ratio >= min_ess_ratio, "effective sample ratio below frozen gate")
            values.append(prediction)
            ess_ratios.append(ratio)
        seed_range = max(values) - min(values)
        require(seed_range <= max_seed_range, "seed instability above frozen gate")
        prediction = statistics.mean(values)
        errors.append((prediction - observed) ** 2)
        ranges.append(seed_range)

    require(groups == heldout and len(groups) >= plan["min_heldout_groups"],
            "missing heldout groups")
    group_errors = []
    for group in sorted(groups):
        group_rows = [index for index, row in enumerate(rows) if row["group_id"] == group]
        group_errors.append(statistics.mean(errors[index] for index in group_rows))
    brier = statistics.mean(group_errors)
    return {
        "accepted": brier <= max_brier,
        "metric": "group_weighted_brier",
        "brier": brier,
        "independent_groups": len(groups),
        "rows": len(rows),
        "maximum_seed_range": max(ranges),
        "minimum_effective_sample_ratio": min(ess_ratios),
        "scope": "Frozen heldout public-wall labels only; not policy or playing-strength promotion.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("samples", type=Path)
    args = parser.parse_args()
    try:
        plan = json.loads(args.plan.read_text(encoding="utf-8"))
        samples = json.loads(args.samples.read_text(encoding="utf-8"))
        result = evaluate(plan, samples, args.samples.resolve().parent)
    except (OSError, ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
        result = {"accepted": False, "errors": [str(exc)]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["accepted"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
