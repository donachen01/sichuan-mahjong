#!/usr/bin/env python3
"""Build per-discard audit events and a mistake-focused review report."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from tools.hell_training_index import (
    as_number,
    build_hell_challenge_context,
    get_nested,
    is_number,
    load_json,
)


DEFAULT_TRAINING_DIR = Path("测试数据统计/hell_training")
DEFAULT_OUTPUT_DIR = Path("测试数据统计/discard_audit")
SHORT_TOP_LIST_LIMIT = 8


@dataclass(frozen=True)
class AuditPaths:
    jsonl_path: Path
    report_path: Path


def iter_decision_files(training_dir: Path, session_id: str | None = None) -> Iterable[Path]:
    files = sorted(training_dir.glob("*_decision_*.json"))
    if session_id:
        files = [path for path in files if path.name.startswith(f"{session_id}_decision_")]
    return files


def build_audit_events(training_dir: Path, session_id: str | None = None) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for path in iter_decision_files(training_dir, session_id):
        data = load_json(path)
        if str(data.get("decision_type", "")) != "discard":
            continue
        event = build_audit_event(data, path)
        if event:
            events.append(event)
    return events


def build_audit_events_from_trace(trace_events_path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    with trace_events_path.open("r", encoding="utf-8") as file:
        for line in file:
            if not line.strip():
                continue
            data = json.loads(line)
            event = build_audit_event_from_trace(data, trace_events_path)
            if event:
                events.append(event)
    return events


def build_audit_event_from_trace(trace_event: dict[str, Any], path: Path) -> dict[str, Any] | None:
    event_type = str(trace_event.get("event_type", ""))
    if event_type not in {"turn_decision_built", "turn_analysis_ready"}:
        return None
    payload = trace_event.get("payload", {})
    if not isinstance(payload, dict):
        return None
    decision = payload.get("decision", {})
    if not isinstance(decision, dict):
        decision = {}
    if event_type == "turn_decision_built" and str(payload.get("decision_path", "")) != "discard":
        return None
    if event_type == "turn_analysis_ready" and str(decision.get("action", "")) != "discard":
        return None
    turn_diagnostic = payload.get("turn_diagnostic", {})
    if not isinstance(turn_diagnostic, dict) or not turn_diagnostic:
        return None
    selected = turn_diagnostic.get("selected", {})
    if not isinstance(selected, dict):
        selected = {}
    actual_action = decision.get("actual_action", {})
    if not isinstance(actual_action, dict):
        actual_action = {}
    if not actual_action:
        actual_action = {
            "action": decision.get("action", "discard"),
            "tile_type": selected.get("tile_type", get_nested(turn_diagnostic, ["selected_tile", "csharp_tile_type"], "")),
        }
    synthetic_data = {
        "session_id": trace_event.get("session_id", path.parent.name),
        "decision_index": trace_event.get("event_index", 0),
        "created_at": trace_event.get("created_at", ""),
        "round_index": trace_event.get("round_index", ""),
        "phase": trace_event.get("phase", ""),
        "decision_type": "discard",
        "seat": payload.get("seat", trace_event.get("current_turn_seat", -1)),
        "actual_action": actual_action,
        "visible_state": trace_event.get("visible_state", {}),
        "hidden_state": trace_event.get("hidden_state", {}),
        "fair_ai": {
            "turn_diagnostic": turn_diagnostic,
        },
        "extra": {
            "decision": decision,
            "trace_event_index": trace_event.get("event_index", 0),
            "trace_event_type": event_type,
        },
    }
    return build_audit_event(synthetic_data, path)


def build_audit_event(data: dict[str, Any], path: Path) -> dict[str, Any]:
    fair_ai = data.get("fair_ai", {})
    if not isinstance(fair_ai, dict):
        fair_ai = {}
    turn_diagnostic = fair_ai.get("turn_diagnostic", {})
    if not isinstance(turn_diagnostic, dict):
        turn_diagnostic = get_nested(data, ["extra", "decision", "analysis", "turn_diagnostic"], {})
    if not isinstance(turn_diagnostic, dict):
        turn_diagnostic = {}

    actual_action = data.get("actual_action", {})
    if not isinstance(actual_action, dict):
        actual_action = {}
    selected = turn_diagnostic.get("selected", {})
    quality = turn_diagnostic.get("quality_metrics", {})
    best_safe = turn_diagnostic.get("best_safe_alternative", {})
    best_speed = turn_diagnostic.get("best_speed_alternative", {})
    best_big_route = turn_diagnostic.get("best_big_route_alternative", {})
    synthetic_flags: list[str] = []
    if not isinstance(selected, dict) or not selected:
        selected, quality, best_safe, best_speed, best_big_route, synthetic_flags = build_hell_challenge_context(
            get_nested(data, ["extra", "decision", "analysis"], fair_ai),
            actual_action,
        )
    selected = selected if isinstance(selected, dict) else {}
    quality = quality if isinstance(quality, dict) else {}
    best_safe = best_safe if isinstance(best_safe, dict) else {}
    best_speed = best_speed if isinstance(best_speed, dict) else {}
    best_big_route = best_big_route if isinstance(best_big_route, dict) else {}

    top_score_candidates = turn_diagnostic.get("top_score_candidates", [])
    if not isinstance(top_score_candidates, list):
        top_score_candidates = []
    candidate_count = int(turn_diagnostic.get("candidate_count", len(top_score_candidates)))
    diagnostic_flags = normalize_list(turn_diagnostic.get("diagnostic_flags", []))
    quality_flags = normalize_list(quality.get("quality_flags", []))
    for flag in synthetic_flags:
        if flag not in quality_flags:
            quality_flags.append(flag)

    visible_state = data.get("visible_state", {})
    if not isinstance(visible_state, dict):
        visible_state = {}
    seat = int(data.get("seat", -1))
    player = player_by_seat(visible_state, seat)
    selected_tile_type = value_or(selected.get("tile_type"), actual_action.get("tile_type", ""))
    actual_tile_type = actual_action.get("tile_type", get_nested(data, ["extra", "actual_tile_type"], ""))
    stage = stage_from_wall_count(int(visible_state.get("wall_count", data.get("wall_count", 0))))
    mode = str(selected.get("strategy_mode", get_nested(turn_diagnostic, ["strategy_profile", "mode_label"], "")))
    score_gap = int(as_number(quality.get("score_gap_to_best", turn_diagnostic.get("score_gap_to_best", 0))))
    opportunity_loss = as_number(quality.get("opportunity_loss_score", 0.0))
    quality_score = int(round(resolve_quality_score(quality, selected, best_safe, score_gap, opportunity_loss)))
    categories = classify_categories(
        data=data,
        selected=selected,
        best_safe=best_safe,
        best_speed=best_speed,
        best_big_route=best_big_route,
        quality=quality,
        diagnostic_flags=diagnostic_flags,
        quality_flags=quality_flags,
        actual_tile_type=actual_tile_type,
        selected_tile_type=selected_tile_type,
        player=player,
        stage=stage,
        mode=mode,
    )
    if candidate_count <= 0 and not top_score_candidates:
        categories = ["INCOMPLETE_DIAGNOSTIC"]
        grade = "UNRATED_INCOMPLETE"
    else:
        grade = grade_for_event(quality_score, categories, selected, best_safe, stage, mode, score_gap)

    return {
        "event_id": "%s#%s" % (data.get("session_id", ""), data.get("decision_index", "")),
        "source_file": str(path),
        "session_id": data.get("session_id", ""),
        "decision_index": int(data.get("decision_index", 0)),
        "created_at": data.get("created_at", ""),
        "round_index": data.get("round_index", ""),
        "phase": data.get("phase", ""),
        "stage": stage,
        "seat": seat,
        "seat_name": player.get("nickname", ""),
        "wall_count": visible_state.get("wall_count", ""),
        "discard_count": len(visible_state.get("discard_pile", [])) if isinstance(visible_state.get("discard_pile", []), list) else "",
        "score_before": player.get("score", ""),
        "bao_jiao": bool(player.get("bao_jiao", False)),
        "actual_action": actual_action.get("action", ""),
        "actual_tile_type": actual_tile_type,
        "selected_tile_type": selected_tile_type,
        "selected_tile_label": selected.get("tile_label", selected.get("tile_name", selected_tile_type)),
        "selected_rank_by_score": turn_diagnostic.get("selected_rank_by_score", ""),
        "candidate_count": candidate_count,
        "selected_score": selected.get("score", ""),
        "selected_shanten": selected.get("shanten", ""),
        "selected_live_ukeire": selected.get("live_ukeire", ""),
        "selected_wait_count": selected.get("wait_count", ""),
        "selected_danger": selected.get("danger", ""),
        "selected_risk_label": selected.get("risk_label", ""),
        "strategy_mode": mode,
        "quality_score": quality_score,
        "quality_grade": grade,
        "opportunity_loss_score": round(opportunity_loss, 3),
        "score_gap_to_best": score_gap,
        "expected_net_gap_to_best": quality.get("expected_net_gap_to_best", ""),
        "risk_gap_to_best_safe": quality.get("risk_gap_to_best_safe", ""),
        "categories": categories,
        "diagnostic_flags": diagnostic_flags,
        "quality_flags": quality_flags,
        "best_score_candidate": compact_candidate(top_score_candidates[0]) if top_score_candidates else {},
        "best_safe_alternative": compact_candidate(best_safe),
        "best_speed_alternative": compact_candidate(best_speed),
        "best_big_route_alternative": compact_candidate(best_big_route),
        "top_score_candidates": [compact_candidate(item) for item in top_score_candidates[:SHORT_TOP_LIST_LIMIT] if isinstance(item, dict)],
        "selected_reasons": normalize_list(selected.get("reasons", []))[:8],
    }


def resolve_quality_score(
    quality: dict[str, Any],
    selected: dict[str, Any],
    best_safe: dict[str, Any],
    score_gap: int,
    opportunity_loss: float,
) -> float:
    if is_number(quality.get("quality_score")):
        return as_number(quality.get("quality_score"), 100.0)
    penalty = min(100.0, max(0.0, opportunity_loss))
    if score_gap > 0:
        penalty = max(penalty, min(100.0, score_gap / 18.0))
    selected_danger = as_number(selected.get("danger"))
    best_safe_danger = as_number(best_safe.get("danger"), selected_danger)
    if selected_danger >= 65 and selected_danger - best_safe_danger >= 25:
        penalty += 18.0
    return max(0.0, 100.0 - min(100.0, penalty))


def classify_categories(
    *,
    data: dict[str, Any],
    selected: dict[str, Any],
    best_safe: dict[str, Any],
    best_speed: dict[str, Any],
    best_big_route: dict[str, Any],
    quality: dict[str, Any],
    diagnostic_flags: list[str],
    quality_flags: list[str],
    actual_tile_type: Any,
    selected_tile_type: Any,
    player: dict[str, Any],
    stage: str,
    mode: str,
) -> list[str]:
    categories: list[str] = []
    score_gap = as_number(quality.get("score_gap_to_best", get_nested(data, ["fair_ai", "turn_diagnostic", "score_gap_to_best"], 0)))
    selected_danger = as_number(selected.get("danger"))
    best_safe_danger = as_number(best_safe.get("danger"), selected_danger)
    selected_shanten = as_number(selected.get("shanten"), 99.0)
    best_speed_shanten = as_number(best_speed.get("shanten"), selected_shanten)
    strategic_fold_safety = mode == "fold" and selected_danger <= 12 and stage == "late"

    if not same_tile_value(actual_tile_type, selected_tile_type):
        categories.append("FRONTEND_EXECUTION_MISMATCH")
    if bool(player.get("bao_jiao", False)) and str(selected.get("keeps_ready", "")).lower() == "false":
        categories.append("BAO_JIAO_ERROR")
    if str(selected.get("exact_deal_in", "")).lower() == "true" or str(selected.get("feeds_human_hu", "")).lower() == "true":
        categories.append("RISK_ERROR")
    if selected_danger >= 65 and selected_danger - best_safe_danger >= 25:
        categories.append("RISK_ERROR")
    if score_gap >= 500 and not strategic_fold_safety:
        categories.append("WEIGHT_ERROR")
    if best_speed and best_speed_shanten < selected_shanten and score_gap < 1200 and not strategic_fold_safety:
        categories.append("HAND_VALUE_ERROR")
    if as_number(quality.get("expected_net_gap_to_best")) >= 2.0 and not strategic_fold_safety:
        categories.append("EV_ERROR")
    if best_big_route and "missed_big_route" in "|".join(quality_flags):
        categories.append("EV_ERROR")
    if any("mode" in flag for flag in quality_flags):
        categories.append("MODE_ERROR")
    if "selected_narrow_live_ukeire" in quality_flags or "faster_alternative_exists" in quality_flags:
        categories.append("HAND_VALUE_ERROR")
    if "defense_mode_ignored_safe_alternative" in quality_flags:
        categories.append("MODE_ERROR")
        categories.append("RISK_ERROR")
    if "high_table_threat" in diagnostic_flags and selected_danger >= 55:
        categories.append("EXPLAIN_MISMATCH")
    if not selected:
        categories.append("CANDIDATE_ERROR")
    quality_score = as_number(quality.get("quality_score"), 100.0)
    critical_categories = {
        "FRONTEND_EXECUTION_MISMATCH",
        "BAO_JIAO_ERROR",
        "RISK_ERROR",
        "CANDIDATE_ERROR",
    }
    if quality_score >= 90 and not any(category in critical_categories for category in categories):
        return ["OK"]
    return sorted(set(categories)) or ["OK"]


def grade_for_event(
    quality_score: int,
    categories: list[str],
    selected: dict[str, Any],
    best_safe: dict[str, Any],
    stage: str,
    mode: str,
    score_gap: int,
) -> str:
    grade = grade_from_score(quality_score)
    selected_danger = as_number(selected.get("danger"))
    best_safe_danger = as_number(best_safe.get("danger"), selected_danger)
    if mode == "fold" and stage == "late" and selected_danger <= 12:
        return "B_ACCEPTABLE" if score_gap >= 1500 else "A_OPTIMAL"
    if "FRONTEND_EXECUTION_MISMATCH" in categories or "BAO_JIAO_ERROR" in categories:
        return "E_BLUNDER"
    if "RISK_ERROR" in categories and (stage == "late" or selected_danger >= 80):
        return worse_grade(grade, "E_BLUNDER")
    if "RISK_ERROR" in categories and selected_danger - best_safe_danger >= 25:
        return worse_grade(grade, "D_MISTAKE")
    if "WEIGHT_ERROR" in categories:
        return worse_grade(grade, "C_QUESTIONABLE")
    return grade


def grade_from_score(score: int) -> str:
    if score >= 90:
        return "A_OPTIMAL"
    if score >= 75:
        return "B_ACCEPTABLE"
    if score >= 60:
        return "C_QUESTIONABLE"
    if score >= 40:
        return "D_MISTAKE"
    return "E_BLUNDER"


def worse_grade(current: str, floor: str) -> str:
    order = ["A_OPTIMAL", "B_ACCEPTABLE", "C_QUESTIONABLE", "D_MISTAKE", "E_BLUNDER"]
    return order[max(order.index(current), order.index(floor))]


def stage_from_wall_count(wall_count: int) -> str:
    if wall_count >= 14:
        return "early"
    if wall_count >= 7:
        return "middle"
    return "late"


def player_by_seat(visible_state: dict[str, Any], seat: int) -> dict[str, Any]:
    players = visible_state.get("players", [])
    if not isinstance(players, list):
        return {}
    for player in players:
        if isinstance(player, dict) and int(player.get("seat", -1)) == seat:
            return player
    return {}


def compact_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(candidate, dict) or not candidate:
        return {}
    return {
        "tile_type": candidate.get("tile_type", candidate.get("tileType", "")),
        "tile_label": candidate.get("tile_label", candidate.get("tile_name", candidate.get("tileName", ""))),
        "score": candidate.get("score", ""),
        "shanten": candidate.get("shanten", ""),
        "live_ukeire": candidate.get("live_ukeire", candidate.get("liveUkeire", "")),
        "wait_count": candidate.get("wait_count", candidate.get("waitCount", "")),
        "danger": candidate.get("danger", ""),
        "risk_label": candidate.get("risk_label", candidate.get("riskLabel", "")),
        "strategy_mode": candidate.get("strategy_mode", candidate.get("strategyMode", "")),
        "keeps_ready": candidate.get("keeps_ready", candidate.get("keepsReady", "")),
        "exact_deal_in": candidate.get("exact_deal_in", candidate.get("exactDealIn", "")),
        "feeds_human_hu": candidate.get("feeds_human_hu", candidate.get("feedsHumanHu", "")),
        "feeds_human_peng": candidate.get("feeds_human_peng", candidate.get("feedsHumanPeng", "")),
        "feeds_human_gang": candidate.get("feeds_human_gang", candidate.get("feedsHumanGang", "")),
        "tier": candidate.get("tier", ""),
    }


def normalize_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value]
    if value in ("", None):
        return []
    return [str(value)]


def value_or(value: Any, fallback: Any) -> Any:
    if value == "" or value is None:
        return fallback
    return value


def same_tile_value(left: Any, right: Any) -> bool:
    if left in ("", None) or right in ("", None):
        return True
    if is_number(left) and is_number(right):
        return int(float(left)) == int(float(right))
    return str(left) == str(right)


def write_audit(events: list[dict[str, Any]], output_dir: Path, slug: str | None = None) -> AuditPaths:
    output_dir.mkdir(parents=True, exist_ok=True)
    actual_slug = slug or datetime.now().strftime("%Y%m%d_%H%M%S")
    jsonl_path = output_dir / f"{actual_slug}_discard_audit_events.jsonl"
    report_path = output_dir / f"{actual_slug}_discard_audit_report.md"
    with jsonl_path.open("w", encoding="utf-8") as file:
        for event in events:
            file.write(json.dumps(event, ensure_ascii=False, sort_keys=True) + "\n")
    report_path.write_text(build_report_markdown(events, jsonl_path), encoding="utf-8")
    return AuditPaths(jsonl_path=jsonl_path, report_path=report_path)


def build_report_markdown(events: list[dict[str, Any]], jsonl_path: Path) -> str:
    grade_counts = Counter(str(event.get("quality_grade", "")) for event in events)
    category_counts = Counter(category for event in events for category in event.get("categories", []))
    stage_counts = Counter(str(event.get("stage", "")) for event in events)
    mode_counts = Counter(str(event.get("strategy_mode", "")) or "unknown" for event in events)
    by_stage_grade: dict[str, Counter[str]] = defaultdict(Counter)
    by_mode_grade: dict[str, Counter[str]] = defaultdict(Counter)
    for event in events:
        by_stage_grade[str(event.get("stage", ""))][str(event.get("quality_grade", ""))] += 1
        by_mode_grade[str(event.get("strategy_mode", "")) or "unknown"][str(event.get("quality_grade", ""))] += 1
    quality_values = [
        float(event["quality_score"])
        for event in events
        if str(event.get("quality_grade", "")) != "UNRATED_INCOMPLETE" and is_number(event.get("quality_score"))
    ]
    mistake_events = [
        event
        for event in events
        if str(event.get("quality_grade", "")) in {"C_QUESTIONABLE", "D_MISTAKE", "E_BLUNDER"}
    ]
    top_mistakes = sorted(
        mistake_events,
        key=lambda event: (
            grade_rank(str(event.get("quality_grade", ""))),
            int(event.get("quality_score", 100)),
            -as_number(event.get("opportunity_loss_score")),
        ),
    )[:20]
    unrated_count = grade_counts["UNRATED_INCOMPLETE"]
    rated_count = len(events) - unrated_count
    ab_count = grade_counts["A_OPTIMAL"] + grade_counts["B_ACCEPTABLE"]
    de_count = grade_counts["D_MISTAKE"] + grade_counts["E_BLUNDER"]
    lines = [
        "# AI 逐张出牌审计报告",
        "",
        f"- 事件文件：`{jsonl_path}`",
        f"- 审计出牌数：{len(events)}",
        f"- 可评级出牌数：{rated_count}",
        f"- 诊断不完整出牌数：{unrated_count}",
        f"- 平均出牌质量分：{average(quality_values):.2f}" if quality_values else "- 平均出牌质量分：n/a",
        f"- A/B 可接受率：{ratio_text(ab_count, rated_count)}",
        f"- D/E 明显错误率：{ratio_text(de_count, rated_count)}",
        f"- E 级严重错牌：{grade_counts['E_BLUNDER']}",
        "",
        "## 质量等级分布",
        *format_counter(grade_counts),
        "",
        "## 错误归因分布",
        *format_counter(category_counts),
        "",
        "## 阶段分布",
        *format_counter(stage_counts),
        "",
        "## 策略模式分布",
        *format_counter(mode_counts),
        "",
        "## 阶段 x 质量",
        *format_nested_counter(by_stage_grade),
        "",
        "## 策略模式 x 质量",
        *format_nested_counter(by_mode_grade),
        "",
        "## 最需要复盘的错牌 Top 20",
    ]
    if not top_mistakes:
        lines.append("- 暂无 C/D/E 级错牌。")
    for index, event in enumerate(top_mistakes, start=1):
        best = event.get("best_score_candidate", {})
        safe = event.get("best_safe_alternative", {})
        speed = event.get("best_speed_alternative", {})
        lines.extend(
            [
                f"### {index}. {event.get('quality_grade')} {event.get('event_id')}",
                "",
                (
                    f"- 座位：{event.get('seat')} {event.get('seat_name')}；"
                    f"阶段：{event.get('stage')}；墙牌：{event.get('wall_count')}；"
                    f"模式：{event.get('strategy_mode') or 'unknown'}"
                ),
                (
                    f"- AI 出牌：{event.get('selected_tile_label')}({event.get('selected_tile_type')})；"
                    f"分数：{event.get('selected_score')}；危险：{event.get('selected_danger')}；"
                    f"向听：{event.get('selected_shanten')}；活张：{event.get('selected_live_ukeire')}"
                ),
                (
                    f"- 质量分：{event.get('quality_score')}；"
                    f"与最优分差：{event.get('score_gap_to_best')}；"
                    f"机会损失：{event.get('opportunity_loss_score')}"
                ),
                f"- 归因：{', '.join(event.get('categories', []))}",
                f"- 最优分候选：{format_candidate(best)}",
                f"- 最安全候选：{format_candidate(safe)}",
                f"- 最快候选：{format_candidate(speed)}",
                f"- 质量标记：{', '.join(event.get('quality_flags', [])) or '无'}",
                f"- 诊断标记：{', '.join(event.get('diagnostic_flags', [])) or '无'}",
                "",
            ]
        )
    lines.extend(build_recommendations(category_counts))
    return "\n".join(lines).rstrip() + "\n"


def build_recommendations(category_counts: Counter[str]) -> list[str]:
    lines = ["", "## 调教建议"]
    actionable_counts = Counter({key: value for key, value in category_counts.items() if key != "OK"})
    if not actionable_counts:
        return lines + ["- 当前样本未发现明确错牌；下一步看总分和场景覆盖是否足够。"]
    if set(actionable_counts.keys()) == {"INCOMPLETE_DIAGNOSTIC"}:
        return lines + ["- 当前可评级样本不足；需要使用新 session 的完整候选诊断数据。"]
    if category_counts.get("RULE_ERROR", 0) or category_counts.get("BAO_JIAO_ERROR", 0):
        lines.append("- 先修规则约束，不要调权重；报叫/报杠类错误必须归零。")
    if category_counts.get("FRONTEND_EXECUTION_MISMATCH", 0):
        lines.append("- 检查前端/执行层是否执行了非 C# 推荐牌，避免分析和实际出牌脱节。")
    if category_counts.get("RISK_ERROR", 0) >= category_counts.get("WEIGHT_ERROR", 0):
        lines.append("- 优先复查危险牌模型和后期防守阈值，尤其是高危牌与安全替代之间的惩罚差。")
    if category_counts.get("WEIGHT_ERROR", 0) > category_counts.get("RISK_ERROR", 0):
        lines.append("- 候选都有但排序错，优先调候选评分权重，而不是改候选生成。")
    if category_counts.get("MODE_ERROR", 0):
        lines.append("- StrategyMode 与实际出牌冲突，先检查模式切换条件，再调单张牌分值。")
    if category_counts.get("HAND_VALUE_ERROR", 0):
        lines.append("- 复查向听、活张、宽叫和保听价值，避免只看安全导致手牌效率下降。")
    if category_counts.get("EV_ERROR", 0):
        lines.append("- 复查长期净胜分估计，尤其是落后追分与领先保守时的收益权重。")
    if len(lines) == 1:
        lines.append("- 当前错误主要在可接受范围内，下一步看 20-30 局总分和错牌是否集中于少数场景。")
    return lines


def grade_rank(grade: str) -> int:
    order = {
        "E_BLUNDER": 0,
        "D_MISTAKE": 1,
        "C_QUESTIONABLE": 2,
        "B_ACCEPTABLE": 3,
        "A_OPTIMAL": 4,
    }
    return order.get(grade, 5)


def format_candidate(candidate: dict[str, Any]) -> str:
    if not candidate:
        return "无"
    label = candidate.get("tile_label") or candidate.get("tile_type") or "?"
    return (
        f"{label}(score={candidate.get('score', '')}, "
        f"danger={candidate.get('danger', '')}, "
        f"shanten={candidate.get('shanten', '')}, "
        f"live={candidate.get('live_ukeire', '')})"
    )


def format_counter(counter: Counter[str]) -> list[str]:
    return [f"- `{key or 'unknown'}`: {count}" for key, count in counter.most_common()] or ["- 无"]


def format_nested_counter(counters: dict[str, Counter[str]]) -> list[str]:
    lines: list[str] = []
    for outer_key in sorted(counters):
        inner = ", ".join(f"{key}={value}" for key, value in counters[outer_key].most_common())
        lines.append(f"- `{outer_key or 'unknown'}`: {inner or '无'}")
    return lines or ["- 无"]


def ratio_text(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return "0/0 (0.00%)"
    return f"{numerator}/{denominator} ({numerator / denominator:.2%})"


def average(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build per-discard audit events and report.")
    parser.add_argument("--training-dir", type=Path, default=DEFAULT_TRAINING_DIR)
    parser.add_argument("--trace-events", type=Path, default=None, help="Optional ai_decision_trace events.jsonl path.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--session-id", default=None, help="Only audit one hell-training session id.")
    parser.add_argument("--slug", default=None, help="Output file prefix, for example 20260630_20rounds.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    events = build_audit_events_from_trace(args.trace_events) if args.trace_events else build_audit_events(args.training_dir, args.session_id)
    paths = write_audit(events, args.output_dir, args.slug)
    print(f"audited_discards={len(events)}")
    print(f"jsonl={paths.jsonl_path}")
    print(f"report={paths.report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
