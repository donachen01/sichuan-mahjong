#!/usr/bin/env python3
"""Recompute heldout calibration error against a predeclared plan.

This evaluates supplied data, it never invents numerical Mahjong weights.
"""
import argparse
import json
import math
import statistics
from datetime import datetime
from pathlib import Path
from evaluate_paired_strength import plan_hash


def require(condition, message):
    if not condition:
        raise ValueError(message)


def evaluate(plan, samples):
    require(samples.get("plan_sha256") == plan_hash(plan), "calibration plan mismatch")
    require(plan.get("target") in {"probability", "net_score"}, "unknown calibration target")
    require(isinstance(plan.get("model_version"), str) and plan["model_version"], "missing calibrated model version")
    train, heldout = set(plan.get("training_groups", [])), set(plan.get("heldout_groups", []))
    require(len(train) >= 2 and heldout and not train.intersection(heldout), "single-source or overlapping calibration split")
    require(type(plan.get("min_heldout_groups")) is int and plan["min_heldout_groups"] >= 2, "insufficient declared independent groups")
    threshold = plan.get("max_error")
    require(type(threshold) in (int, float) and math.isfinite(threshold) and threshold >= 0, "invalid calibration error threshold")
    frozen = datetime.fromisoformat(plan["frozen_at"].replace("Z", "+00:00"))
    started = datetime.fromisoformat(samples["started_at"].replace("Z", "+00:00"))
    require(frozen.tzinfo and started.tzinfo and frozen < started, "calibration plan not frozen before measurement")
    rows = samples.get("rows")
    require(isinstance(rows, list) and rows, "no calibration samples")
    groups, ids = {}, set()
    for row in rows:
        require(row.get("id") and row["id"] not in ids, "duplicate/missing sample ID")
        ids.add(row["id"])
        require(row.get("group_id") in heldout and row.get("model_version") == plan["model_version"], "calibration population/version mismatch")
        prediction, observed = row.get("prediction"), row.get("observed")
        require(all(type(x) in (int, float) and math.isfinite(x) for x in (prediction, observed)), "invalid calibration measurement")
        if plan["target"] == "probability":
            require(0 <= prediction <= 1 and observed in (0, 1), "invalid probability outcome")
            error = (prediction - observed) ** 2
        else:
            error = abs(prediction - observed)
        groups.setdefault(row["group_id"], []).append(error)
    require(set(groups) == heldout and len(groups) >= plan["min_heldout_groups"], "missing/insufficient heldout groups")
    # Weight source games equally; repeated frames cannot dominate the metric.
    error = statistics.mean(statistics.mean(v) for v in groups.values())
    return {"accepted": error <= threshold, "metric": "brier" if plan["target"] == "probability" else "mae",
            "error": error, "independent_groups": len(groups), "samples": len(rows),
            "scope": "Declared heldout population only; not proof of universal calibrated probabilities."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("samples", type=Path)
    args = parser.parse_args()
    try:
        result = evaluate(json.loads(args.plan.read_text()), json.loads(args.samples.read_text()))
    except (OSError, ValueError, TypeError, KeyError) as exc:
        result = {"accepted": False, "errors": [str(exc)]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["accepted"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
