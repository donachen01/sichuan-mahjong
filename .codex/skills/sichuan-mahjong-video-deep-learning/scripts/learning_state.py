#!/usr/bin/env python3
"""Atomically maintain the low-traffic, single-video learning state."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path


STAGES = (
    "screening",
    "acquire_source",
    "source_verified",
    "baseline_indexed",
    "evidence_review",
    "knowledge_note_complete",
    "decision_windows_verified",
    "semantic_review",
    "validation",
    "summary",
    "complete",
    "excluded",
    "blocked",
)

# Ordered forward chain used by the artifact-based reconciler.  Only stages
# whose output can be checked without understanding Mahjong are listed here.
# Semantic reconstruction, validation, and summary are explicit model commits:
# a handful of JSON files must never be mistaken for a completed lesson.
FORWARD_CHAIN = (
    "source_verified",
    "baseline_indexed",
    "decision_windows_verified",
)

NEXT_STAGE = {
    "screening": {"acquire_source", "source_verified", "excluded", "blocked"},
    "acquire_source": {"source_verified", "excluded", "blocked"},
    "source_verified": {"baseline_indexed", "excluded", "blocked"},
    "baseline_indexed": {"evidence_review", "decision_windows_verified", "excluded", "blocked"},
    "evidence_review": {"knowledge_note_complete", "blocked"},
    "knowledge_note_complete": set(),
    "decision_windows_verified": {"semantic_review", "excluded", "blocked"},
    "semantic_review": {"validation", "blocked"},
    "validation": {"summary", "blocked"},
    "summary": {"complete", "blocked"},
    "complete": set(),
    "excluded": set(),
    "blocked": set(),
}

# Default idle threshold (minutes) after which an active video is considered stalled.
DEFAULT_STALL_MINUTES = 30


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def utc_now_iso() -> str:
    return utc_now().isoformat()


def parse_iso(value: str) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json_atomic(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def verify_and_mark_inventory(inventory_path: Path, validator: Path, active: dict) -> None:
    """Validate first, then persist the inventory completion mark."""
    project_root = inventory_path.resolve().parents[2]
    bundle = project_root / str(active.get("bundle_path", ""))
    result = subprocess.run(
        [sys.executable, str(validator), str(bundle), "--verify-frame-hashes"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stdout.strip() or result.stderr.strip() or "validator failed"
        raise SystemExit(f"cannot complete before bundle verification: {detail}")
    inventory = read_json(inventory_path)
    item = next((entry for entry in inventory.get("items", []) if str(entry.get("video_id")) == str(active.get("video_id"))), None)
    if not isinstance(item, dict):
        raise SystemExit("cannot complete: active video is absent from inventory")
    item["screening_status"] = "relevant"
    item["learning_status"] = "verified"
    item["bundle_path"] = str(active["bundle_path"])
    write_json_atomic(inventory_path, inventory)


def verify_and_mark_knowledge_note(inventory_path: Path, validator: Path, active: dict) -> None:
    """Validate phase-one knowledge, then persist a non-algorithmic inventory mark."""
    project_root = inventory_path.resolve().parents[2]
    bundle = project_root / str(active.get("bundle_path", ""))
    report_path = bundle / "knowledge-note-validation.json"
    result = subprocess.run(
        [sys.executable, str(validator), str(bundle), "--report", str(report_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stdout.strip() or result.stderr.strip() or "knowledge-note validator failed"
        raise SystemExit(f"cannot complete knowledge note: {detail}")
    report = read_json(report_path)
    if report.get("ok") is not True or report.get("knowledge_status") != "knowledge_note_complete":
        raise SystemExit("cannot complete knowledge note: validator did not confirm the phase-one status")
    if str(report.get("video_id")) != str(active.get("video_id")):
        raise SystemExit("cannot complete knowledge note: note video_id does not match active video")
    inventory = read_json(inventory_path)
    item = next((entry for entry in inventory.get("items", []) if str(entry.get("video_id")) == str(active.get("video_id"))), None)
    if not isinstance(item, dict):
        raise SystemExit("cannot complete knowledge note: active video is absent from inventory")
    note_path = bundle / "knowledge-note.json"
    item["screening_status"] = "relevant"
    item["learning_status"] = "knowledge_note_complete"
    item["knowledge_status"] = "knowledge_note_complete"
    item["bundle_path"] = str(active["bundle_path"])
    item["knowledge_note_path"] = str(note_path.relative_to(project_root))
    item["knowledge_note_sha256"] = hashlib.sha256(note_path.read_bytes()).hexdigest()
    item["algorithm_status"] = item.get("algorithm_status", "not_started")
    item["strength_status"] = item.get("strength_status", "not_started")
    write_json_atomic(inventory_path, inventory)


def mark_inventory_excluded(inventory_path: Path, active: dict, reason: str) -> None:
    """Persist a screened-out item without treating it as learned or verified."""
    inventory = read_json(inventory_path)
    item = next((entry for entry in inventory.get("items", []) if str(entry.get("video_id")) == str(active.get("video_id"))), None)
    if not isinstance(item, dict):
        raise SystemExit("cannot exclude: active video is absent from inventory")
    item["screening_status"] = "not_relevant"
    item["learning_status"] = "excluded"
    item["bundle_path"] = str(active["bundle_path"])
    item["exclusion_reason"] = reason
    write_json_atomic(inventory_path, inventory)


def defer_inventory_for_calibration(inventory_path: Path, active: dict, reason: str) -> dict:
    """Park a semantically validated lesson without calling it complete."""
    project_root = inventory_path.resolve().parents[2]
    bundle = project_root / str(active.get("bundle_path", ""))
    report_path = bundle / "validation-report.json"
    if (bundle / "evidence-retraction.json").exists():
        raise SystemExit("calibration deferral rejected: evidence retracted; independent review required")
    if not report_path.is_file():
        raise SystemExit("calibration deferral requires validation-report.json")
    report = read_json(report_path)
    checks = report.get("checks", {})
    if (
        report.get("ok") is not True
        or checks.get("semantic_mastery") is not True
        or checks.get("learning_stage") != "technique_understood"
        or checks.get("required_stage") != "understanding"
    ):
        raise SystemExit("calibration deferral requires a strict-green understanding-stage report")
    if checks.get("ai_application_gate") is True:
        raise SystemExit("algorithmically applied lessons should complete normally, not enter calibration queue")
    inventory = read_json(inventory_path)
    item = next((entry for entry in inventory.get("items", []) if str(entry.get("video_id")) == str(active.get("video_id"))), None)
    if not isinstance(item, dict):
        raise SystemExit("cannot defer: active video is absent from inventory")
    item["screening_status"] = "relevant"
    item["learning_status"] = "awaiting_calibration"
    item["bundle_path"] = str(active["bundle_path"])
    item["calibration_wait_reason"] = reason
    write_json_atomic(inventory_path, inventory)
    return {
        **active,
        "deferred_at": utc_now_iso(),
        "calibration_wait_reason": reason,
        "validation_report": {
            "path": str(report_path.relative_to(project_root)),
            "sha256": hashlib.sha256(report_path.read_bytes()).hexdigest(),
        },
    }


def touch_progress(state: dict) -> None:
    """Stamp the latest real progress point (stage move / claim / reconciliation)."""
    state["last_progress_at"] = utc_now_iso()


def append_event(state: dict, event: str, note: str) -> None:
    events = state.setdefault("events", [])
    events.append({"at": utc_now_iso(), "event": event, "note": note})
    del events[:-40]
    state["updated_at"] = utc_now_iso()


def next_action(stage: str, workflow_mode: str = "mechanism_validation") -> str:
    actions = {
        "screening": "根据标题、原片与规则范围判断相关性；相关后核验本地原片，缺原片才进入获取。",
        "acquire_source": "获取精确目标原片；先核对ID、标题、时长和播放器实际源，再固化SHA-256。",
        "source_verified": "从00:00生成或复用完整1 FPS基线、OCR和联系表。",
        "baseline_indexed": (
            "审查视频证据并撰写第一阶段学习笔记。"
            if workflow_mode == "knowledge_acquisition"
            else "定位全部摸打、碰杠胡过和攻守转换节点，补精确决策窗口帧。"
        ),
        "evidence_review": "完成逐条学习笔记：核心观点、公开依据、候选取舍、改意条件、未知和能力挂接。",
        "knowledge_note_complete": "本条知识笔记已关闭但尚未验证算法；领取下一条候选视频。",
        "decision_windows_verified": "重建公开时间线，生成知识单元，并完成独立复述、反事实和迁移盲测。",
        "semantic_review": "运行带帧哈希的验证器并将报告持久化到证据包。",
        "validation": "写知识卡总结，更新库存后运行协调器；成功才关闭本条。",
        "summary": "将本条标记完成并立即领取下一条。",
        "complete": "领取下一条候选视频。",
        "excluded": "本条未计入学习完成；领取下一条候选视频。",
        "blocked": "等待人工或外部阻塞解除；不要尝试重复网络请求。",
    }
    return actions[stage]


def stall_view(state: dict, stall_minutes: int = DEFAULT_STALL_MINUTES) -> dict:
    """Return whether the active video looks stalled (active but no recent progress)."""
    active = state.get("active")
    if state.get("run_status") != "active" or not isinstance(active, dict):
        return {"stalled": False, "reason": "not_active"}
    stage = active.get("stage")
    if stage in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
        return {"stalled": False, "reason": f"stage_{stage}"}
    last = parse_iso(state.get("last_progress_at") or state.get("updated_at", ""))
    if last is None:
        return {"stalled": True, "reason": "missing_progress_timestamp", "minutes_idle": None}
    idle = (utc_now() - last).total_seconds() / 60.0
    return {
        "stalled": idle > stall_minutes,
        "reason": "idle_over_threshold" if idle > stall_minutes else "within_threshold",
        "minutes_idle": round(idle, 1),
        "threshold_minutes": stall_minutes,
        "last_progress_at": state.get("last_progress_at"),
        "stage": stage,
    }


def compact(state: dict, stall_minutes: int = DEFAULT_STALL_MINUTES) -> dict:
    active = state.get("active")
    view = {
        "schema_version": state.get("schema_version"),
        "updated_at": state.get("updated_at"),
        "last_progress_at": state.get("last_progress_at"),
        "last_heartbeat_at": state.get("last_heartbeat_at"),
        "run_status": state.get("run_status"),
        "active": active,
        "workflow_mode": state.get("workflow_mode", "mechanism_validation"),
        "next_action": next_action(active["stage"], state.get("workflow_mode", "mechanism_validation")) if active else "领取下一条候选视频",
        "awaiting_calibration": [
            {
                "video_id": item.get("video_id"),
                "order": item.get("order"),
                "stage": item.get("stage"),
                "reason": item.get("calibration_wait_reason"),
            }
            for item in state.get("calibration_queue", [])
            if isinstance(item, dict)
        ],
    }
    view["stall"] = stall_view(state, stall_minutes)
    return view


def stage_artifacts_ready(bundle: Path, stage: str) -> bool:
    """Mechanically decide whether a forward stage's required artifacts already exist.

    This only checks deterministic local artifacts. Semantic correctness is never
    inferred from file presence and is gated by an explicit model commit followed
    by validate_learning_bundle.py. It never advances to `complete`.
    """
    if not bundle.is_dir():
        return False
    if stage == "source_verified":
        return (bundle / "source-verification.json").is_file() and (bundle / "source.mp4").is_file()
    if stage == "baseline_indexed":
        manifest = bundle / "artifacts" / "baseline_1fps" / "frames.json"
        ocr = bundle / "artifacts" / "baseline_1fps" / "ocr.json"
        sheets = list((bundle / "artifacts" / "contact_sheets").glob("sheet_*.jpg"))
        return manifest.is_file() and ocr.is_file() and bool(sheets)
    if stage == "decision_windows_verified":
        manifest = bundle / "artifacts" / "keyframe_verification" / "frames.json"
        ocr = bundle / "artifacts" / "keyframe_verification" / "ocr.json"
        if not (manifest.is_file() and ocr.is_file()):
            return False
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return False
        return data.get("mode") == "exact" and int(data.get("frame_count", 0)) > 0
    if stage == "semantic_review":
        required = (
            "evidence-index.json",
            "public-timeline.json",
            "knowledge-units.json",
            "semantic-review.json",
            "evidence-context.json",
        )
        return all((bundle / name).is_file() for name in required)
    if stage == "validation":
        report = bundle / "validation-report.json"
        if not report.is_file():
            return False
        try:
            return bool(json.loads(report.read_text(encoding="utf-8")).get("ok"))
        except (OSError, json.JSONDecodeError):
            return False
    if stage == "summary":
        card = bundle / "knowledge-card.md"
        if not card.is_file():
            return False
        return "状态：已吃透" in card.read_text(encoding="utf-8")
    return False


def reconcile(state: dict, project_root: Path) -> list[str]:
    """Advance the active video along the legal chain to match existing artifacts."""
    active = state.get("active")
    if not isinstance(active, dict):
        return []
    current = active.get("stage")
    if current in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
        return []
    bundle = project_root / active.get("bundle_path", "")
    moves: list[str] = []
    # Walk the forward chain; only pass stages that are ahead of the current position.
    order_index = {stage: i for i, stage in enumerate(FORWARD_CHAIN)}
    start_index = order_index.get(current, -1)
    for target in FORWARD_CHAIN:
        if order_index[target] <= start_index:
            continue
        if target not in NEXT_STAGE.get(active["stage"], set()):
            break
        if not stage_artifacts_ready(bundle, target):
            break
        previous = active["stage"]
        active["stage"] = target
        active["manual_blocker"] = None
        active["network_permitted"] = target == "acquire_source"
        moves.append(f"{previous}->{target}")
        append_event(state, f"reconcile:{previous}->{target}", "检测到目标阶段产物已齐备，原子校准阶段")
    if moves:
        touch_progress(state)
    return moves


def main() -> int:
    parser = argparse.ArgumentParser()
    subcommands = parser.add_subparsers(dest="command", required=True)
    for name in ("status", "claim-next", "claim-review"):
        command = subcommands.add_parser(name)
        command.add_argument("--state", type=Path, required=True)
        command.add_argument("--stall-minutes", type=int, default=DEFAULT_STALL_MINUTES)
        if name in {"claim-next", "claim-review"}:
            command.add_argument("--inventory", type=Path, required=True)
        if name == "claim-next":
            command.add_argument("--after-order", type=int)
            command.add_argument("--mode", choices=("knowledge_acquisition", "mechanism_validation"))
        if name == "claim-review":
            command.add_argument("--order", type=int)
    suspend = subcommands.add_parser("suspend-for-review")
    suspend.add_argument("--state", type=Path, required=True)
    suspend.add_argument("--note", required=True)
    resume = subcommands.add_parser("resume-suspended")
    resume.add_argument("--state", type=Path, required=True)
    set_mode = subcommands.add_parser("set-mode")
    set_mode.add_argument("--state", type=Path, required=True)
    set_mode.add_argument("--mode", choices=("knowledge_acquisition", "mechanism_validation"), required=True)
    defer = subcommands.add_parser("defer-for-calibration")
    defer.add_argument("--state", type=Path, required=True)
    defer.add_argument("--inventory", type=Path, required=True)
    defer.add_argument("--reason", required=True)
    resume_calibration = subcommands.add_parser("resume-calibration")
    resume_calibration.add_argument("--state", type=Path, required=True)
    resume_calibration.add_argument("--video-id")
    resume_blocked = subcommands.add_parser("resume-blocked")
    resume_blocked.add_argument("--state", type=Path, required=True)
    resume_blocked.add_argument("--video-id")
    transition = subcommands.add_parser("transition")
    transition.add_argument("--state", type=Path, required=True)
    transition.add_argument("--stage", choices=STAGES, required=True)
    transition.add_argument("--note", required=True)
    transition.add_argument("--inventory", type=Path)
    transition.add_argument("--validator", type=Path)
    transition.add_argument("--note-validator", type=Path)
    blocked = subcommands.add_parser("block")
    blocked.add_argument("--state", type=Path, required=True)
    blocked.add_argument("--reason", required=True)
    rec = subcommands.add_parser("reconcile")
    rec.add_argument("--state", type=Path, required=True)
    rec.add_argument("--project-root", type=Path)
    rec.add_argument("--stall-minutes", type=int, default=DEFAULT_STALL_MINUTES)
    hb = subcommands.add_parser("heartbeat")
    hb.add_argument("--state", type=Path, required=True)
    hb.add_argument("--stall-minutes", type=int, default=DEFAULT_STALL_MINUTES)
    stalled = subcommands.add_parser("check-stalled")
    stalled.add_argument("--state", type=Path, required=True)
    stalled.add_argument("--minutes", type=int, default=DEFAULT_STALL_MINUTES)
    cfg = parser.parse_args()

    if cfg.command == "status":
        if not cfg.state.exists():
            print(json.dumps({"run_status": "idle", "next_action": "领取下一条候选视频"}, ensure_ascii=False, indent=2))
            return 0
        print(json.dumps(compact(read_json(cfg.state), cfg.stall_minutes), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "check-stalled":
        if not cfg.state.exists():
            print(json.dumps({"stalled": False, "reason": "no_state"}, ensure_ascii=False, indent=2))
            return 0
        view = stall_view(read_json(cfg.state), cfg.minutes)
        print(json.dumps(view, ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "heartbeat":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; claim a video first")
        state = read_json(cfg.state)
        state["last_heartbeat_at"] = utc_now_iso()
        append_event(state, "heartbeat", "低流量接力心跳登记（不推进阶段）")
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state, cfg.stall_minutes), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "set-mode":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; claim a video first")
        state = read_json(cfg.state)
        state["workflow_mode"] = cfg.mode
        touch_progress(state)
        append_event(state, "workflow_mode_changed", f"切换为 {cfg.mode}")
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state), ensure_ascii=False, indent=2))
        return 0

    if cfg.command in {"claim-next", "claim-review"}:
        state = read_json(cfg.state) if cfg.state.exists() else {"schema_version": 1, "events": []}
        if cfg.command == "claim-next" and cfg.mode:
            state["workflow_mode"] = cfg.mode
        active = state.get("active")
        suspended = state.get("suspended_active")
        if (
            isinstance(active, dict)
            and isinstance(suspended, dict)
            and str(active.get("video_id", "")) == str(suspended.get("video_id", ""))
        ):
            # A suspended video is already owned by this run. An older state-machine
            # version could claim the same inventory row again after another review
            # completed. Preserve the suspended copy (which may be further along)
            # and discard only the duplicate claim.
            state["active"] = None
            active = None
            append_event(
                state,
                "duplicate_claim_discarded",
                f"保留已暂停的 order={suspended.get('order')}，丢弃同视频重复领取",
            )
        if active and active.get("stage") not in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
            state["run_status"] = "active"
            touch_progress(state)
            write_json_atomic(cfg.state, state)
            print(json.dumps(compact(state, cfg.stall_minutes), ensure_ascii=False, indent=2))
            return 0
        inventory = read_json(cfg.inventory)
        if cfg.command == "claim-next" and cfg.after_order is not None:
            if cfg.after_order < 0:
                raise SystemExit("after-order must be non-negative")
            state["cursor_order"] = cfg.after_order
        cursor_order = int(state.get("cursor_order", 0))
        suspended_video_id = ""
        if isinstance(state.get("suspended_active"), dict):
            suspended_video_id = str(state["suspended_active"].get("video_id", ""))
        blocked_video_ids = {
            str(item.get("video_id", ""))
            for item in state.get("blocked_items", [])
            if isinstance(item, dict)
        }
        if isinstance(active, dict) and active.get("stage") == "blocked":
            blocked_video_ids.add(str(active.get("video_id", "")))
        if cfg.command == "claim-next":
            candidates = [
                item for item in inventory.get("items", [])
                if item.get("learning_status") == "not_started"
                and item.get("screening_status") in {"pending", "relevant"}
                and str(item.get("video_id", ""))
                and str(item.get("video_id", "")) != suspended_video_id
                and str(item.get("video_id", "")) not in blocked_video_ids
                and int(item.get("order", -1)) > cursor_order
            ]
        else:
            candidates = [
                item for item in inventory.get("items", [])
                if item.get("learning_status") == "needs_review"
                and item.get("screening_status") == "relevant"
                and str(item.get("video_id", ""))
                and (cfg.order is None or int(item.get("order", -1)) == cfg.order)
            ]
        candidates.sort(key=lambda item: int(item.get("order", 10**12)))
        if not candidates:
            state["active"] = None
            state["run_status"] = "idle"
            queue_name = "复核" if cfg.command == "claim-review" else "pending/relevant"
            append_event(state, "queue_empty", f"没有可领取的{queue_name}视频")
            write_json_atomic(cfg.state, state)
            print(json.dumps(compact(state, cfg.stall_minutes), ensure_ascii=False, indent=2))
            return 0
        item = candidates[0]
        project_root = cfg.inventory.resolve().parents[2]
        configured = item.get("bundle_path")
        bundle = (project_root / configured) if configured else project_root / "research/xiaolaoshi_deep_learning" / str(item["video_id"])
        # Reviewed lessons re-enter at screening: this enforces source identity and
        # rules scope before any old artifact is trusted, but never authorizes a
        # re-download unless that check actually finds the local source missing.
        stage = "screening" if cfg.command == "claim-review" or item.get("screening_status") == "pending" else "acquire_source"
        state["active"] = {
            "video_id": str(item["video_id"]),
            "order": item.get("order"),
            "title": item.get("title", ""),
            "stage": stage,
            "bundle_path": str(bundle.relative_to(project_root)),
            "media_reuse_required": True,
            "network_permitted": stage == "acquire_source",
            "manual_blocker": None,
        }
        state["run_status"] = "active"
        touch_progress(state)
        queue_name = "review" if cfg.command == "claim-review" else "next"
        append_event(state, f"claimed:{queue_name}", f"领取 order={item.get('order')} video_id={item['video_id']}")
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state, cfg.stall_minutes), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "suspend-for-review":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; nothing to suspend")
        state = read_json(cfg.state)
        active = state.get("active")
        if not isinstance(active, dict) or active.get("stage") in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
            raise SystemExit("only an active, resumable video can be suspended")
        if state.get("suspended_active"):
            raise SystemExit("a suspended video already exists; resume it before suspending another")
        state["suspended_active"] = active
        state["active"] = None
        state["run_status"] = "idle"
        touch_progress(state)
        append_event(state, "suspended_for_review", cfg.note)
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "resume-suspended":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; no suspended video")
        state = read_json(cfg.state)
        current_active = state.get("active")
        if isinstance(current_active, dict) and current_active.get("stage") not in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
            raise SystemExit("cannot resume while another video is active")
        suspended = state.get("suspended_active")
        if not isinstance(suspended, dict):
            raise SystemExit("no suspended video to resume")
        state["active"] = suspended
        state.pop("suspended_active", None)
        state["run_status"] = "active"
        touch_progress(state)
        append_event(state, "resumed_suspended", f"恢复 order={suspended.get('order')}")
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "defer-for-calibration":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; nothing to defer")
        state = read_json(cfg.state)
        active = state.get("active")
        if not isinstance(active, dict) or active.get("stage") != "summary":
            raise SystemExit("only a semantically validated lesson at summary can await calibration")
        deferred = defer_inventory_for_calibration(cfg.inventory, active, cfg.reason)
        queue = [
            item for item in state.get("calibration_queue", [])
            if isinstance(item, dict) and str(item.get("video_id", "")) != str(active.get("video_id", ""))
        ]
        queue.append(deferred)
        queue.sort(key=lambda item: int(item.get("order", 10**12)))
        state["calibration_queue"] = queue
        state["cursor_order"] = max(int(state.get("cursor_order", 0)), int(active.get("order", 0)))
        state["active"] = None
        state["run_status"] = "idle"
        touch_progress(state)
        append_event(state, "deferred_for_calibration", cfg.reason)
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "resume-calibration":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; no calibration queue")
        state = read_json(cfg.state)
        current_active = state.get("active")
        if isinstance(current_active, dict) and current_active.get("stage") not in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
            raise SystemExit("cannot resume calibration while another video is active")
        queue = [item for item in state.get("calibration_queue", []) if isinstance(item, dict)]
        matches = [
            (position, item) for position, item in enumerate(queue)
            if cfg.video_id is None or str(item.get("video_id", "")) == cfg.video_id
        ]
        if not matches:
            raise SystemExit("no matching calibration item")
        if cfg.video_id is None and len(matches) > 1:
            raise SystemExit("multiple calibration items exist; provide --video-id")
        position, restored = matches[0]
        queue.pop(position)
        restored = dict(restored)
        restored.pop("deferred_at", None)
        restored.pop("calibration_wait_reason", None)
        restored.pop("validation_report", None)
        state["calibration_queue"] = queue
        state["active"] = restored
        state["run_status"] = "active"
        touch_progress(state)
        append_event(state, "resumed_calibration", f"恢复 order={restored.get('order')}")
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "resume-blocked":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; no blocked video")
        state = read_json(cfg.state)
        current_active = state.get("active")
        if isinstance(current_active, dict) and current_active.get("stage") not in {"complete", "knowledge_note_complete", "excluded", "blocked"}:
            raise SystemExit("cannot resume a blocked video while another video is active")
        blocked_items = [item for item in state.get("blocked_items", []) if isinstance(item, dict)]
        matches = [
            (position, item) for position, item in enumerate(blocked_items)
            if cfg.video_id is None or str(item.get("video_id", "")) == cfg.video_id
        ]
        if not matches:
            raise SystemExit("no matching blocked video to resume")
        if cfg.video_id is None and len(matches) > 1:
            raise SystemExit("multiple blocked videos exist; provide --video-id")
        position, restored = matches[0]
        blocked_items.pop(position)
        restored["manual_blocker"] = None
        restored["network_permitted"] = restored.get("stage") == "acquire_source"
        state["blocked_items"] = blocked_items
        state["active"] = restored
        state["run_status"] = "active"
        touch_progress(state)
        append_event(state, "resumed_blocked", f"恢复 order={restored.get('order')}")
        write_json_atomic(cfg.state, state)
        print(json.dumps(compact(state), ensure_ascii=False, indent=2))
        return 0

    if cfg.command == "reconcile":
        if not cfg.state.exists():
            raise SystemExit("state file does not exist; claim a video first")
        state = read_json(cfg.state)
        project_root = cfg.project_root.resolve() if cfg.project_root else cfg.state.resolve().parents[2]
        moves = reconcile(state, project_root)
        if moves:
            write_json_atomic(cfg.state, state)
        result = {"moves": moves, **compact(state, cfg.stall_minutes)}
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0

    if not cfg.state.exists():
        raise SystemExit("state file does not exist; claim a video first")
    state = read_json(cfg.state)
    active = state.get("active")
    if not isinstance(active, dict):
        raise SystemExit("no active video; claim a video first")
    current = active.get("stage")
    if cfg.command == "block":
        blocked_copy = dict(active)
        blocked_copy["stage"] = current
        blocked_copy["manual_blocker"] = cfg.reason
        blocked_items = [
            item for item in state.get("blocked_items", [])
            if isinstance(item, dict) and str(item.get("video_id", "")) != str(active.get("video_id", ""))
        ]
        blocked_items.append(blocked_copy)
        state["blocked_items"] = blocked_items
        active["stage"] = "blocked"
        active["manual_blocker"] = cfg.reason
        active["network_permitted"] = False
        state["run_status"] = "blocked"
        append_event(state, "blocked", cfg.reason)
    else:
        if cfg.stage not in NEXT_STAGE.get(current, set()):
            raise SystemExit(f"illegal transition: {current} -> {cfg.stage}")
        if cfg.stage == "complete":
            if not cfg.inventory or not cfg.validator:
                raise SystemExit("complete requires --inventory and --validator to atomically mark verified")
            verify_and_mark_inventory(cfg.inventory, cfg.validator, active)
        elif cfg.stage == "knowledge_note_complete":
            if not cfg.inventory or not cfg.note_validator:
                raise SystemExit("knowledge_note_complete requires --inventory and --note-validator")
            verify_and_mark_knowledge_note(cfg.inventory, cfg.note_validator, active)
        elif cfg.stage == "excluded":
            if not cfg.inventory:
                raise SystemExit("excluded requires --inventory to atomically record the screening decision")
            mark_inventory_excluded(cfg.inventory, active, cfg.note)
        active["stage"] = cfg.stage
        active["manual_blocker"] = None
        active["network_permitted"] = cfg.stage == "acquire_source"
        state["run_status"] = "idle" if cfg.stage in {"complete", "knowledge_note_complete", "excluded"} else "active"
        if cfg.stage in {"complete", "knowledge_note_complete", "excluded"}:
            state["cursor_order"] = int(active.get("order", 0))
        touch_progress(state)
        append_event(state, f"transition:{current}->{cfg.stage}", cfg.note)
    write_json_atomic(cfg.state, state)
    print(json.dumps(compact(state), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
