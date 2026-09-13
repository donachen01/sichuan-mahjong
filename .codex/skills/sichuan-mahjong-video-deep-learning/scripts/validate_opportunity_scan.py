#!/usr/bin/env python3
"""Validate an outcome-blind natural opportunity scan against its frozen plan."""
import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path


def demand(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_time(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    demand(parsed.tzinfo is not None, "timestamps must include a timezone")
    return parsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("reports", type=Path, nargs="+")
    args = parser.parse_args()
    project = args.project.resolve()
    plan_path = args.plan.resolve()
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    ranges = plan.get("ranges", [])
    demand(len(args.reports) == len(ranges), "one ordered report is required for every frozen range")
    demand(plan.get("game_origin") == "natural_full_round", "opportunity scan must start from natural full rounds")
    demand(plan.get("include_all_matching_seeds") is True, "plan may not omit matching seeds")
    demand(plan.get("stop_at_first_trigger") is True, "scan must stop at the first trigger")
    demand(plan.get("opponent_policy_variant") == "current", "current-opponent scan required for the frozen V7 contract")
    version_match = re.search(r"_v(\d+)(?:_|$)", plan["candidate_policy_variant"])
    demand(version_match is not None, "candidate policy variant does not carry a version")
    version_label = f"V{version_match.group(1)}"
    required_meld_count = 2 if "two_meld" in plan["candidate_policy_variant"] else None

    frozen_at = parse_time(plan["frozen_at"])
    source_paths = {
        "ai_core_sha256": project / "dotnet/AI.Core/bin/Debug/net10.0/SichuanMahjong.AI.Core.dll",
        "decision_engine_sha256": project / "dotnet/AI.Core/Engines/SichuanDecisionEngine.cs",
        "two_ply_evaluator_sha256": project / "dotnet/AI.Core/Decision/SichuanTwoPlyReadyEvaluator.cs",
        "candidate_model_sha256": project / "dotnet/AI.Core/Models/SichuanCandidateDetail.cs",
        "benchmark_harness_sha256": project / "tests/current/sichuan_ai_pressure_benchmark.gd",
    }
    source_hashes = {}
    for field, path in source_paths.items():
        observed = sha256(path)
        source_hashes[field] = observed
        demand(observed == plan.get(field), f"frozen source changed: {path}")

    allowed_row_fields = {
        "group_id", "seed", "triggered", "first_trigger_seat", "first_trigger_wall_count",
        "first_trigger_meld_count", "first_trigger_reason_code", "initial_world_hash",
        "scan_stopped_on_first_trigger", "uses_hidden_information", "game_origin",
    }
    all_rows = []
    selected = []
    source_reports = []
    started = []
    completed = []
    seen_seeds = set()
    for frozen_range, report_path in zip(ranges, args.reports):
        report_path = report_path.resolve()
        report = json.loads(report_path.read_text(encoding="utf-8"))
        demand(report.get("valid") is True, f"invalid scan report: {report_path}")
        demand(report.get("benchmark_mode") == "natural_first_trigger_opportunity_scan", "wrong scan mode")
        demand(report.get("candidate_policy", "").endswith(plan["candidate_policy_variant"]), "candidate changed")
        demand(report.get("baseline_policy") == "bone_ash_current", "baseline changed")
        demand(report.get("opponent_policy") == plan["opponent_policy_variant"], "opponent changed")
        demand(version_label in report.get("selection_rule", ""), "scan report carries stale mechanism metadata")
        demand(report.get("seed_base") == frozen_range["seed_base"], "seed base differs from frozen range")
        demand(report.get("seed_stride") == plan["seed_stride"], "seed stride changed")
        demand(report.get("scanned_deals") == frozen_range["deals"], "frozen range was not fully scanned")
        rows = report.get("rows", [])
        demand(len(rows) == frozen_range["deals"], "row count differs from frozen range")
        expected_seeds = [frozen_range["seed_base"] + i * plan["seed_stride"] for i in range(frozen_range["deals"])]
        demand([row.get("seed") for row in rows] == expected_seeds, "seed order/gaps differ from frozen range")
        report_selected = report.get("selected_groups", [])
        demand(report_selected == [row for row in rows if row.get("triggered") is True],
               "selected groups are not exactly all triggered rows")
        demand(report.get("selected_deals") == len(report_selected), "selected count mismatch")
        demand(report.get("mechanism_triggers") == len(report_selected), "scan must stop after one trigger per selected deal")
        for row in rows:
            demand(set(row) == allowed_row_fields, "opportunity row contains outcome data or an unknown field")
            seed = row["seed"]
            demand(seed not in seen_seeds, "seed appears in more than one frozen range")
            seen_seeds.add(seed)
            demand(row["group_id"] == f"natural-seed-{seed}", "group id does not bind to seed")
            demand(row["game_origin"] == "natural_full_round", "non-natural row in opportunity scan")
            demand(row["uses_hidden_information"] is False, "hidden information used during opportunity selection")
            demand(bool(row["initial_world_hash"]), "missing initial world hash")
            if row["triggered"]:
                demand(row["first_trigger_seat"] in (0, 1, 2, 3), "invalid first-trigger seat")
                if required_meld_count is not None:
                    demand(row["first_trigger_meld_count"] == required_meld_count,
                           "candidate triggered outside its declared meld-count scope")
                demand(row["first_trigger_reason_code"] == "PUBLIC_ROUTE_FRONTIER_OVERRIDE", "wrong trigger reason")
                demand(row["scan_stopped_on_first_trigger"] is True, "selected deal continued beyond first trigger")
            else:
                demand(row["first_trigger_seat"] == -1 and row["scan_stopped_on_first_trigger"] is False,
                       "untriggered row contains trigger metadata")
        started_at = parse_time(report["measurement_started_at"])
        completed_at = parse_time(report["measurement_completed_at"])
        demand(frozen_at < started_at <= completed_at, "scan did not start after the plan was frozen")
        started.append(started_at)
        completed.append(completed_at)
        all_rows.extend(rows)
        selected.extend(report_selected)
        source_reports.append({"path": str(report_path), "sha256": sha256(report_path)})

    demand(len(all_rows) == plan["total_scanned_deals"], "total scanned population differs from plan")
    demand(len(seen_seeds) == plan["total_scanned_deals"], "total seed population is not unique")
    result = {
        "valid": True,
        "plan_path": str(plan_path),
        "plan_sha256": sha256(plan_path),
        "source_hashes": source_hashes,
        "source_reports": source_reports,
        "measurement_started_at": min(started).isoformat(),
        "measurement_completed_at": max(completed).isoformat(),
        "scanned_deals": len(all_rows),
        "selected_deals": len(selected),
        "minimum_selected_groups_met": len(selected) >= plan["minimum_selected_groups_for_followup_strength_plan"],
        "selected_groups": selected,
        "selection_used_outcome": False,
    }
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"valid": True, "scanned_deals": len(all_rows), "selected_deals": len(selected),
                      "minimum_selected_groups_met": result["minimum_selected_groups_met"],
                      "output": str(args.output)}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(str(exc))
