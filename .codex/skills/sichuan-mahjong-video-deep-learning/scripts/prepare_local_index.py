#!/usr/bin/env python3
"""Advance one verified local source through the deterministic indexing stage.

This worker deliberately has no browser, HTTP, cookie, or AI-analysis capability.
It exists so a completed download is not left waiting for a later model turn before
the source hash, 1 FPS baseline, OCR, contact sheets, and state transition are
durably recorded.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json_atomic(path: Path, value: dict) -> None:
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


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def baseline_complete(frame_dir: Path, source: Path) -> bool:
    manifest_path = frame_dir / "frames.json"
    if not manifest_path.is_file():
        return False
    try:
        manifest = read_json(manifest_path)
    except (OSError, json.JSONDecodeError):
        return False
    frames = manifest.get("frames")
    return (
        manifest.get("mode") == "baseline"
        and float(manifest.get("fps", 0)) == 1.0
        and isinstance(frames, list)
        and bool(frames)
        and all((frame_dir / str(item.get("file", ""))).is_file() for item in frames if isinstance(item, dict))
        and Path(manifest.get("video", "")).resolve() == source.resolve()
    )


def ocr_complete(frame_dir: Path) -> bool:
    manifest_path = frame_dir / "frames.json"
    ocr_path = frame_dir / "ocr.json"
    if not manifest_path.is_file() or not ocr_path.is_file():
        return False
    try:
        frames = read_json(manifest_path).get("frames", [])
        ocr = read_json(ocr_path)
    except (OSError, json.JSONDecodeError, AttributeError):
        return False
    if not isinstance(frames, list) or not isinstance(ocr, list) or len(frames) != len(ocr):
        return False
    frame_names = {str(item.get("file", "")) for item in frames if isinstance(item, dict)}
    ocr_names = {str(item.get("file", "")) for item in ocr if isinstance(item, dict)}
    return bool(frame_names) and frame_names == ocr_names


def contact_sheets_complete(frame_dir: Path, sheet_dir: Path) -> bool:
    try:
        frame_count = int(read_json(frame_dir / "frames.json").get("frame_count", 0))
    except (OSError, json.JSONDecodeError, AttributeError, ValueError):
        return False
    expected = (frame_count + 8) // 9
    sheets = list(sheet_dir.glob("sheet_*.jpg")) if sheet_dir.is_dir() else []
    return expected > 0 and len(sheets) == expected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, required=True)
    cfg = parser.parse_args()

    state_path = cfg.state.resolve()
    root = cfg.project_root.resolve()
    state = read_json(state_path)
    active = state.get("active")
    if state.get("run_status") != "active" or not isinstance(active, dict):
        raise SystemExit("no active learning video")
    if active.get("stage") not in {"source_verified", "baseline_indexed"}:
        raise SystemExit(f"local indexing requires source_verified, got {active.get('stage')!r}")

    bundle = root / str(active.get("bundle_path", ""))
    source = bundle / "source.mp4"
    metadata = bundle / "metadata.json"
    if not source.is_file() or not metadata.is_file():
        raise SystemExit("source.mp4 and metadata.json are required")
    metadata_data = read_json(metadata)
    video_id = str(active.get("video_id", ""))
    if str(metadata_data.get("aweme_id", "")) != video_id:
        raise SystemExit("metadata aweme_id does not match active video")

    status_path = bundle / "local-index-worker.json"
    write_json_atomic(status_path, {
        "schema_version": 1,
        "video_id": video_id,
        "stage": "running",
        "started_at": utc_now(),
        "network_used": False,
    })

    try:
        run([
            sys.executable, str(SCRIPT_DIR / "resolve_or_verify_source.py"), str(bundle),
            "--video-id", video_id, "--expected-title", str(active.get("title", "")),
        ])
        frame_dir = bundle / "artifacts" / "baseline_1fps"
        if not baseline_complete(frame_dir, source):
            run([
                sys.executable, str(SCRIPT_DIR / "extract_frames.py"), str(source),
                "--output-dir", str(frame_dir), "--fps", "1", "--force",
            ])
        if not ocr_complete(frame_dir):
            run(["swift", str(SCRIPT_DIR / "ocr_subtitles.swift"), str(frame_dir), str(frame_dir / "ocr.json")])
        sheets = bundle / "artifacts" / "contact_sheets"
        if not contact_sheets_complete(frame_dir, sheets):
            run([
                sys.executable, str(SCRIPT_DIR / "make_contact_sheets.py"), str(frame_dir),
                "--output-dir", str(sheets),
                "--columns", "3", "--rows", "3", "--cell-width", "480",
            ])
        for command in ("init-plan", "subtitle-skeleton"):
            target = bundle / ("analysis-plan.json" if command == "init-plan" else "subtitle-evidence.json")
            if not target.exists():
                run([sys.executable, str(SCRIPT_DIR / "build_low_traffic_artifacts.py"), command, str(bundle)])
        if active.get("stage") == "source_verified":
            run([
                sys.executable, str(SCRIPT_DIR / "learning_state.py"), "transition",
                "--state", str(state_path), "--stage", "baseline_indexed",
                "--note", "本地确定性工作器已完成1 FPS基线、OCR、联系表与低流量采样账本；未访问网络。",
            ])
        write_json_atomic(status_path, {
            "schema_version": 1,
            "video_id": video_id,
            "stage": "complete",
            "completed_at": utc_now(),
            "network_used": False,
        })
    except Exception as exc:
        write_json_atomic(status_path, {
            "schema_version": 1,
            "video_id": video_id,
            "stage": "failed",
            "failed_at": utc_now(),
            "network_used": False,
            "error": str(exc),
        })
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
