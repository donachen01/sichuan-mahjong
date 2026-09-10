#!/usr/bin/env python3
"""Advance deterministic local artifacts for one evidence bundle, then stop.

Source verification plus the complete 1 FPS/OCR baseline are deterministic local
work. Decision-window reconstruction and all semantic conclusions remain for an
agent review; this worker never crosses into those stages.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def active_stage(state_path: Path) -> str:
    state = json.loads(state_path.read_text(encoding="utf-8"))
    return str((state.get("active") or {}).get("stage") or "")


def transition(state_script: Path, state_path: Path, target: str, note: str) -> None:
    run([
        sys.executable, str(state_script), "transition", "--state", str(state_path),
        "--stage", target, "--note", note,
    ])


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify local media and build reusable baseline artifacts, then stop for semantic review."
    )
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--video-id", required=True)
    parser.add_argument("--expected-title", required=True)
    parser.add_argument("--skill-root", type=Path, required=True)
    cfg = parser.parse_args()

    root = cfg.bundle.resolve()
    scripts = cfg.skill_root.resolve() / "scripts"
    state_script = scripts / "learning_state.py"
    active = json.loads(cfg.state.read_text(encoding="utf-8")).get("active") or {}
    if str(active.get("video_id")) != cfg.video_id:
        raise SystemExit("active video does not match --video-id; refusing to advance another bundle")
    if active_stage(cfg.state) not in {"acquire_source", "source_verified", "baseline_indexed"}:
        raise SystemExit(f"worker cannot run from stage {active_stage(cfg.state)!r}")

    run([sys.executable, str(scripts / "resolve_or_verify_source.py"), str(root),
         "--video-id", cfg.video_id, "--expected-title", cfg.expected_title])
    if active_stage(cfg.state) == "acquire_source":
        transition(state_script, cfg.state, "source_verified",
                   "本地工作器已核验ID、标题、时长与SHA-256；不再重复下载。")

    frame_dir = root / "artifacts" / "baseline_1fps"
    if not (frame_dir / "frames.json").is_file():
        run([sys.executable, str(scripts / "extract_frames.py"), str(root / "source.mp4"),
             "--output-dir", str(frame_dir), "--fps", "1"])
    if not (frame_dir / "ocr.json").is_file():
        run(["swift", str(scripts / "ocr_subtitles.swift"), str(frame_dir), str(frame_dir / "ocr.json")])
    sheet_dir = root / "artifacts" / "contact_sheets"
    if not any(sheet_dir.glob("sheet_*.jpg")):
        run([sys.executable, str(scripts / "make_contact_sheets.py"), str(frame_dir),
             "--output-dir", str(sheet_dir), "--columns", "3", "--rows", "3", "--cell-width", "480"])
    if not (root / "analysis-plan.json").is_file():
        run([sys.executable, str(scripts / "build_low_traffic_artifacts.py"), "init-plan", str(root)])
    if not (root / "subtitle-evidence.json").is_file():
        run([sys.executable, str(scripts / "build_low_traffic_artifacts.py"), "subtitle-skeleton", str(root)])
    if active_stage(cfg.state) == "source_verified":
        transition(state_script, cfg.state, "baseline_indexed",
                   "本地工作器已完成从00:00开始的1 FPS帧、OCR、联系表与采样账本；等待语义决策窗口复核。")
    print(json.dumps({"ok": True, "stopped_at": active_stage(cfg.state),
                      "bundle": str(root)}, ensure_ascii=False))


if __name__ == "__main__":
    raise SystemExit(main())
