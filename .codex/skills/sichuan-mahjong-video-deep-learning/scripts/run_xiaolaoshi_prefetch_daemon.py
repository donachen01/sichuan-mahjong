#!/usr/bin/env python3
"""LaunchAgent entry point for the resumable Xiao Laoshi source prefetch.

This wrapper refuses to create the target path when the external volume is not
mounted.  launchd will retry later because the wrapper exits non-zero.
"""

from __future__ import annotations

import os
import json
import signal
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


PROJECT_ROOT = Path("/Volumes/AI/Codex/四川麻将工程_20260701_v2")
TARGET_VOLUME = Path("/Volumes/other")
TARGET_ROOT = TARGET_VOLUME / "潇老师麻将视频下载"
PREFETCH = PROJECT_ROOT / ".codex/skills/sichuan-mahjong-video-deep-learning/scripts/prefetch_xiaolaoshi_video_library.py"
INVENTORY = PROJECT_ROOT / "research/xiaolaoshi_deep_learning/video-inventory.json"
RESEARCH_ROOT = PROJECT_ROOT / "research/xiaolaoshi_deep_learning"
RUNTIME_ROOT = PROJECT_ROOT / ".codex_runtime/sichuan-video-learning"
CONTROL_FILE = TARGET_ROOT / "prefetch-control.json"
STATE_FILE = TARGET_ROOT / "prefetch-state.json"
PARALLEL_DOWNLOADS = 1


def requested_mode() -> str:
    try:
        value = json.loads(CONTROL_FILE.read_text(encoding="utf-8"))
        return str(value.get("mode") or "running")
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return "running"


def mark_paused() -> None:
    try:
        state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return
    now = datetime.now(timezone.utc).isoformat()
    for record in state.get("items", {}).values():
        if isinstance(record, dict) and record.get("status") == "downloading":
            record.update({
                "status": "failed",
                "failed_at": now,
                "error": "paused before completion; queued for retry",
            })
    state.update({
        "run_status": "paused",
        "run_phase": "paused",
        "parallel_downloads": PARALLEL_DOWNLOADS,
        "updated_at": now,
    })
    state.pop("current_video_id", None)
    state["current_video_ids"] = []
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=STATE_FILE.parent,
        prefix=f".{STATE_FILE.name}.", suffix=".tmp", delete=False,
    ) as handle:
        json.dump(state, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        temporary = Path(handle.name)
    temporary.replace(STATE_FILE)


def main() -> int:
    if not TARGET_VOLUME.is_dir() or not os.path.ismount(TARGET_VOLUME):
        print(f"target volume is not mounted: {TARGET_VOLUME}", file=sys.stderr, flush=True)
        return 75
    if not PREFETCH.is_file() or not INVENTORY.is_file():
        print("prefetch program or inventory is missing", file=sys.stderr, flush=True)
        return 66
    if requested_mode() == "paused":
        mark_paused()
        print("download is paused by the desktop controller", flush=True)
        return 0

    command = [
        sys.executable,
        str(PREFETCH),
        "--inventory", str(INVENTORY),
        "--target-root", str(TARGET_ROOT),
        "--research-root", str(RESEARCH_ROOT),
        "--runtime-dir", str(RUNTIME_ROOT),
        "--parallel-downloads", str(PARALLEL_DOWNLOADS),
        "--capture-wait-ms", "10000",
        "--download-attempts", "2",
        "--retry-delay-seconds", "15",
        "--download-timeout-seconds", "0",
        "--circuit-breaker-failures", "5",
        "--circuit-breaker-sleep-seconds", "120",
    ]
    child = subprocess.Popen(command, cwd=PROJECT_ROOT, start_new_session=True)

    def forward_signal(signum: int, _frame: object) -> None:
        try:
            os.killpg(child.pid, signum)
        except (ProcessLookupError, PermissionError):
            raise SystemExit(128 + signum)
        try:
            child.wait(timeout=3.0)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, forward_signal)
    signal.signal(signal.SIGINT, forward_signal)
    return_code = child.wait()
    if requested_mode() == "paused":
        mark_paused()
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
