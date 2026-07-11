#!/usr/bin/env python3
"""Build a searchable index for hell-training decision snapshots."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


DEFAULT_TRAINING_DIR = Path("测试数据统计/hell_training")
DEFAULT_OUTPUT_DIR = Path("测试数据统计/hell_training_index")


@dataclass(frozen=True)
class IndexPaths:
    csv_path: Path
    summary_path: Path


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)
    if not isinstance(data, dict):
        raise ValueError(f"Expected JSON object in {path}")
    return data


def iter_decision_files(training_dir: Path) -> Iterable[Path]:
    return sorted(training_dir.glob("*_decision_*.json"))


def get_nested(data: dict[str, Any], keys: list[str], default: Any = "") -> Any:
    current: Any = data
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return default
        current = current[key]
    return current


def first_value(data: dict[str, Any], *keys: str, default: Any = "") -> Any:
    for key in keys:
        if key in data:
            return data[key]
    return default


def as_number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def normalize_csharp_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    return {
        "tile_type": first_value(candidate, "tile_type", "tileType"),
        "tile_label": first_value(candidate, "tile_label", "tileName", "tile_name", "tileType"),
        "score": first_value(candidate, "score"),
        "shanten": first_value(candidate, "shanten"),
        "live_ukeire": first_value(candidate, "live_ukeire", "liveUkeire", "exactWallRemaining"),
        "danger": first_value(candidate, "danger"),
        "strategy_mode": first_value(candidate, "strategy_mode", "strategyMode"),
        "keeps_ready": first_value(candidate, "keeps_ready", "keepsReady"),
        "exact_deal_in": first_value(candidate, "exact_deal_in", "exactDealIn"),
        "feeds_human_hu": first_value(candidate, "feeds_human_hu", "feedsHumanHu"),
        "feeds_human_peng": first_value(candidate, "feeds_human_peng", "feedsHumanPeng"),
        "feeds_human_gang": first_value(candidate, "feeds_human_gang", "feedsHumanGang"),
        "human_peng_threat": first_value(candidate, "human_peng_threat", "humanPengThreat"),
        "human_peng_penalty": first_value(candidate, "human_peng_penalty", "humanPengPenalty"),
        "peng_only_interaction_bonus": first_value(candidate, "peng_only_interaction_bonus", "pengOnlyInteractionBonus"),
        "tier": first_value(candidate, "tier", "selectedTier"),
        "tier_rank": first_value(candidate, "tier_rank", "tierRank"),
        "tier_adjustment": first_value(candidate, "tier_adjustment", "tierAdjustment"),
        "score_components": {
            "expected_net_score": first_value(candidate, "expected_net_score", "expectedNetScore")
        },
    }


def build_hell_challenge_context(analysis: dict[str, Any], actual_action: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], list[str]]:
    csharp = get_nested(analysis, ["csharp_result"], {})
    if not isinstance(csharp, dict) or not csharp:
        return {}, {}, {}, {}, {}, []
    raw_candidates = csharp.get("candidates", [])
    if not isinstance(raw_candidates, list):
        raw_candidates = []
    candidates = [normalize_csharp_candidate(item) for item in raw_candidates if isinstance(item, dict)]
    selected_tile = first_value(csharp, "tileType", "tile_type", default=actual_action.get("tile_type", ""))
    selected = next((item for item in candidates if str(item.get("tile_type", "")) == str(selected_tile)), {})
    if not selected:
        selected = normalize_csharp_candidate(csharp)
        selected["tile_type"] = selected_tile
        selected["tile_label"] = selected_tile
        selected["strategy_mode"] = "地狱挑战"
        selected["keeps_ready"] = csharp.get("exactKeepsReady", "")
        selected["tier"] = csharp.get("selectedTier", "")
    best_safe = min(candidates, key=lambda item: as_number(item.get("danger"), 999.0), default={})
    best_speed = min(candidates, key=lambda item: (as_number(item.get("shanten"), 99.0), -as_number(item.get("live_ukeire"))), default={})
    best_big_route = min(
        [item for item in candidates if str(item.get("tier", "")).startswith(("A_", "B_", "C_WIDE"))],
        key=lambda item: as_number(item.get("tier_rank"), 999.0),
        default={},
    )
    quality = build_synthetic_quality(selected, candidates, best_safe, best_speed)
    return selected, quality, best_safe, best_speed, best_big_route, quality.get("quality_flags", [])


def build_synthetic_quality(
    selected: dict[str, Any],
    candidates: list[dict[str, Any]],
    best_safe: dict[str, Any],
    best_speed: dict[str, Any],
) -> dict[str, Any]:
    flags: list[str] = []
    selected_score = as_number(selected.get("score"))
    selected_shanten = as_number(selected.get("shanten"), 99.0)
    selected_live = as_number(selected.get("live_ukeire"))
    selected_danger = as_number(selected.get("danger"))
    best_score = max((as_number(item.get("score")) for item in candidates), default=selected_score)
    score_gap = max(0.0, best_score - selected_score)
    if str(selected.get("feeds_human_hu", "")).lower() == "true" or str(selected.get("exact_deal_in", "")).lower() == "true":
        flags.append("hell_selected_feeds_hu")
    if str(selected.get("feeds_human_gang", "")).lower() == "true":
        flags.append("hell_selected_feeds_gang")
    if str(selected.get("feeds_human_peng", "")).lower() == "true" and as_number(selected.get("human_peng_threat")) >= 3:
        flags.append("hell_selected_feeds_strong_peng")
    if best_speed and as_number(best_speed.get("shanten"), 99.0) < selected_shanten and score_gap < 1200:
        flags.append("faster_alternative_exists")
    if selected_live <= 4 and any(as_number(item.get("live_ukeire")) >= selected_live + 3 and as_number(item.get("shanten"), 99.0) <= selected_shanten for item in candidates):
        flags.append("selected_narrow_live_ukeire")
    if best_safe and selected_danger >= 35 and as_number(best_safe.get("danger"), 999.0) + 20 <= selected_danger and selected_score - as_number(best_safe.get("score")) <= 650:
        flags.append("safe_alternative_close")
    opportunity_loss = min(100.0, score_gap / 18.0 + len(flags) * 8.0)
    return {
        "quality_score": int(round(max(0.0, 100.0 - opportunity_loss))),
        "opportunity_loss_score": round(opportunity_loss, 3),
        "mode_consistency_score": 100 if not flags else max(0, 100 - len(flags) * 18),
        "expected_net_gap_to_best": "",
        "score_gap_to_best": int(round(score_gap)),
        "risk_gap_to_best_safe": max(0, int(round(selected_danger - as_number(best_safe.get("danger"))))) if best_safe else "",
        "quality_flags": flags,
    }


def build_index_rows(training_dir: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in iter_decision_files(training_dir):
        data = load_json(path)
        decision = get_nested(data, ["extra", "decision"], {})
        analysis = get_nested(decision, ["analysis"], {})
        turn_diagnostic = get_nested(analysis, ["turn_diagnostic"], get_nested(data, ["fair_ai", "turn_diagnostic"], {}))
        selected = get_nested(turn_diagnostic, ["selected"], {})
        quality = get_nested(turn_diagnostic, ["quality_metrics"], {})
        best_safe = get_nested(turn_diagnostic, ["best_safe_alternative"], {})
        best_speed = get_nested(turn_diagnostic, ["best_speed_alternative"], {})
        best_big_route = get_nested(turn_diagnostic, ["best_big_route_alternative"], {})
        actual_action = data.get("actual_action", {})
        if not isinstance(actual_action, dict):
            actual_action = {}
        if not isinstance(selected, dict):
            selected = {}
        if not isinstance(quality, dict):
            quality = {}
        if not isinstance(best_safe, dict):
            best_safe = {}
        if not isinstance(best_speed, dict):
            best_speed = {}
        if not isinstance(best_big_route, dict):
            best_big_route = {}
        if not selected:
            selected, quality, best_safe, best_speed, best_big_route, synthetic_flags = build_hell_challenge_context(analysis, actual_action)
        else:
            synthetic_flags = []
        diagnostic_flags = get_nested(turn_diagnostic, ["diagnostic_flags"], [])
        if not isinstance(diagnostic_flags, list):
            diagnostic_flags = []
        quality_flags = quality.get("quality_flags", [])
        if not isinstance(quality_flags, list):
            quality_flags = []
        for flag in synthetic_flags:
            if flag not in quality_flags:
                quality_flags.append(flag)
        rows.append(
            {
                "file": path.name,
                "path": str(path),
                "session_id": data.get("session_id", ""),
                "decision_index": data.get("decision_index", ""),
                "created_at": data.get("created_at", ""),
                "round_index": data.get("round_index", ""),
                "phase": data.get("phase", ""),
                "decision_type": data.get("decision_type", ""),
                "seat": data.get("seat", ""),
                "actual_action": actual_action.get("action", ""),
                "actual_tile_type": actual_action.get("tile_type", get_nested(data, ["extra", "actual_tile_type"], "")),
                "selected_tile_type": selected.get("tile_type", ""),
                "selected_tile_label": selected.get("tile_label", ""),
                "selected_score": selected.get("score", ""),
                "selected_shanten": selected.get("shanten", ""),
                "selected_live_ukeire": selected.get("live_ukeire", ""),
                "selected_danger": selected.get("danger", ""),
                "selected_strategy_mode": selected.get("strategy_mode", ""),
                "selected_expected_net_score": get_nested(selected, ["score_components", "expected_net_score"], ""),
                "keeps_ready": selected.get("keeps_ready", ""),
                "exact_deal_in": selected.get("exact_deal_in", ""),
                "feeds_human_hu": selected.get("feeds_human_hu", ""),
                "feeds_human_peng": selected.get("feeds_human_peng", ""),
                "feeds_human_gang": selected.get("feeds_human_gang", ""),
                "human_peng_threat": selected.get("human_peng_threat", ""),
                "human_peng_penalty": selected.get("human_peng_penalty", ""),
                "peng_only_interaction_bonus": selected.get("peng_only_interaction_bonus", ""),
                "selected_tier": selected.get("tier", ""),
                "selected_tier_rank": selected.get("tier_rank", ""),
                "selected_tier_adjustment": selected.get("tier_adjustment", ""),
                "quality_score": quality.get("quality_score", ""),
                "opportunity_loss_score": quality.get("opportunity_loss_score", ""),
                "mode_consistency_score": quality.get("mode_consistency_score", ""),
                "expected_net_gap_to_best": quality.get("expected_net_gap_to_best", ""),
                "score_gap_to_best": quality.get("score_gap_to_best", get_nested(turn_diagnostic, ["score_gap_to_best"], "")),
                "risk_gap_to_best_safe": quality.get("risk_gap_to_best_safe", ""),
                "best_safe_tile_type": best_safe.get("tile_type", ""),
                "best_safe_score": best_safe.get("score", ""),
                "best_safe_danger": best_safe.get("danger", ""),
                "best_speed_tile_type": best_speed.get("tile_type", ""),
                "best_speed_shanten": best_speed.get("shanten", ""),
                "best_speed_live_ukeire": best_speed.get("live_ukeire", ""),
                "best_big_route_tile_type": best_big_route.get("tile_type", ""),
                "best_big_route_tier": best_big_route.get("tier", ""),
                "diagnostic_flags": "|".join(str(flag) for flag in diagnostic_flags),
                "quality_flags": "|".join(str(flag) for flag in quality_flags),
                "difference_category": get_nested(data, ["difference", "category"], ""),
                "difference_severity": get_nested(data, ["difference", "severity"], ""),
            }
        )
    return rows


def write_index(rows: list[dict[str, Any]], output_dir: Path, date_slug: str | None = None) -> IndexPaths:
    output_dir.mkdir(parents=True, exist_ok=True)
    slug = date_slug or datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = output_dir / f"{slug}_index.csv"
    summary_path = output_dir / f"{slug}_summary.md"
    fieldnames = [
        "file",
        "path",
        "session_id",
        "decision_index",
        "created_at",
        "round_index",
        "phase",
        "decision_type",
        "seat",
        "actual_action",
        "actual_tile_type",
        "selected_tile_type",
        "selected_tile_label",
        "selected_score",
        "selected_shanten",
        "selected_live_ukeire",
        "selected_danger",
        "selected_strategy_mode",
        "selected_expected_net_score",
        "keeps_ready",
        "exact_deal_in",
        "feeds_human_hu",
        "feeds_human_peng",
        "feeds_human_gang",
        "human_peng_threat",
        "human_peng_penalty",
        "peng_only_interaction_bonus",
        "selected_tier",
        "selected_tier_rank",
        "selected_tier_adjustment",
        "quality_score",
        "opportunity_loss_score",
        "mode_consistency_score",
        "expected_net_gap_to_best",
        "score_gap_to_best",
        "risk_gap_to_best_safe",
        "best_safe_tile_type",
        "best_safe_score",
        "best_safe_danger",
        "best_speed_tile_type",
        "best_speed_shanten",
        "best_speed_live_ukeire",
        "best_big_route_tile_type",
        "best_big_route_tier",
        "diagnostic_flags",
        "quality_flags",
        "difference_category",
        "difference_severity",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    summary_path.write_text(build_summary_markdown(rows, csv_path), encoding="utf-8")
    return IndexPaths(csv_path=csv_path, summary_path=summary_path)


def build_summary_markdown(rows: list[dict[str, Any]], csv_path: Path) -> str:
    by_session = Counter(str(row.get("session_id", "")) for row in rows)
    by_category = Counter(str(row.get("difference_category", "")) for row in rows)
    by_severity = Counter(str(row.get("difference_severity", "")) for row in rows)
    by_quality_flag = Counter(
        flag
        for row in rows
        for flag in str(row.get("quality_flags", "")).split("|")
        if flag
    )
    feeds_peng = sum(1 for row in rows if str(row.get("feeds_human_peng", "")).lower() == "true")
    deal_in = sum(1 for row in rows if str(row.get("exact_deal_in", "")).lower() == "true")
    quality_values = [float(row["quality_score"]) for row in rows if is_number(row.get("quality_score"))]
    opportunity_values = [float(row["opportunity_loss_score"]) for row in rows if is_number(row.get("opportunity_loss_score"))]
    lines = [
        "# Hell Training Index Summary",
        "",
        f"- CSV: `{csv_path}`",
        f"- Decisions: {len(rows)}",
        f"- Sessions: {len([key for key in by_session if key])}",
        f"- feeds_human_peng candidates: {feeds_peng}",
        f"- exact_deal_in candidates: {deal_in}",
        f"- avg_quality_score: {average(quality_values):.2f}" if quality_values else "- avg_quality_score: n/a",
        f"- avg_opportunity_loss_score: {average(opportunity_values):.2f}" if opportunity_values else "- avg_opportunity_loss_score: n/a",
        "",
        "## Category Counts",
    ]
    lines.extend(format_counter(by_category))
    lines.append("")
    lines.append("## Severity Counts")
    lines.extend(format_counter(by_severity))
    lines.append("")
    lines.append("## Quality Flag Counts")
    lines.extend(format_counter(by_quality_flag))
    lines.append("")
    lines.append("## Top Sessions")
    for session_id, count in by_session.most_common(10):
        if session_id:
            lines.append(f"- `{session_id}`: {count}")
    if len(lines) > 0 and lines[-1] == "## Top Sessions":
        lines.append("- None")
    return "\n".join(lines) + "\n"


def format_counter(counter: Counter[str]) -> list[str]:
    rows = [f"- `{key or 'unknown'}`: {count}" for key, count in counter.most_common()]
    return rows or ["- None"]


def is_number(value: Any) -> bool:
    try:
        float(value)
        return True
    except (TypeError, ValueError):
        return False


def average(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build hell-training CSV and Markdown indexes.")
    parser.add_argument("--training-dir", type=Path, default=DEFAULT_TRAINING_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--slug", default=None, help="Optional output file prefix, for example 20260522.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = build_index_rows(args.training_dir)
    paths = write_index(rows, args.output_dir, args.slug)
    print(f"indexed_decisions={len(rows)}")
    print(f"csv={paths.csv_path}")
    print(f"summary={paths.summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
