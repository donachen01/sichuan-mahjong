#!/usr/bin/env python3
"""Build compact local artifacts used by the schema-v3 low-traffic gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path


def read_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json_atomic(path: Path, value: object) -> None:
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


def source_hash(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def load_frames(root: Path) -> tuple[dict[str, dict], dict[str, dict]]:
    frames: dict[str, dict] = {}
    ocr: dict[str, dict] = {}
    for manifest_path in root.glob("artifacts/*/frames.json"):
        manifest = read_json(manifest_path)
        for record in manifest.get("frames", []):
            relative = (manifest_path.parent / record["file"]).relative_to(root).as_posix()
            frames[relative] = record
        ocr_path = manifest_path.parent / "ocr.json"
        if ocr_path.is_file():
            for row in read_json(ocr_path):
                relative = (manifest_path.parent / row["file"]).relative_to(root).as_posix()
                ocr[relative] = row
    return frames, ocr


def init_plan(root: Path, force: bool) -> None:
    path = root / "analysis-plan.json"
    if path.exists() and not force:
        raise SystemExit("analysis-plan.json exists; use --force only for a deliberate rebuild")
    frames, _ = load_frames(root)
    baseline = [path for path in frames if path.startswith("artifacts/baseline_1fps/")]
    payload = {
        "schema_version": 3,
        "video_id": root.name,
        "source_sha256": source_hash(root / "source.mp4"),
        "baseline": {"fps": 1, "frame_count": len(baseline), "complete": bool(baseline)},
        "sampling_escalations": [],
        "unresolved_ambiguities": [],
        "sampling_escalation_contract": {
            "required_fields": ["id", "decision_node_ids", "trigger", "baseline_insufficiency", "sampling", "resolution", "evidence"],
            "sampling_contract": "mode=exact_timestamps时必须同时给timestamps、start_seconds、end_seconds；每一项只覆盖一个有明确牌局意义的歧义。",
            "rule": "只有基线、OCR或公开动作无法消除关键歧义时才添加sampling_escalations；每项必须说明触发信号、歧义、补采样边界、证据和解决结果。",
        },
    }
    write_json_atomic(path, payload)


def build_subtitle_skeleton(root: Path, force: bool) -> None:
    path = root / "subtitle-evidence.json"
    if path.exists() and not force:
        raise SystemExit("subtitle-evidence.json exists; fill its claim_links or use --force deliberately")
    frames, ocr = load_frames(root)
    candidates = []
    for relative, row in sorted(ocr.items(), key=lambda item: float(frames[item[0]].get("timestamp", 0))):
        text = [str(value).strip() for value in row.get("text", []) if str(value).strip()]
        if text:
            candidates.append({"file": relative, "timestamp": frames[relative]["timestamp"], "text": text})
    payload = {
        "schema_version": 3,
        "video_id": root.name,
        "source": "本地硬字幕OCR候选；关键文字必须由人工回看原帧复核。",
        "transcript_candidates": candidates,
        "claim_links": [],
    }
    write_json_atomic(path, payload)


def export_context(root: Path) -> None:
    index = read_json(root / "evidence-index.json")
    timeline = read_json(root / "public-timeline.json")
    metadata = read_json(root / "metadata.json")
    claims = []
    for claim in index.get("claims", []):
        claims.append({
            "id": claim["id"], "claim": claim["claim"], "grade": claim["grade"],
            "start_seconds": claim["start_seconds"], "end_seconds": claim["end_seconds"],
            "evidence_refs": [{"file": item["file"], "timestamp": item["timestamp"]} for item in claim["evidence"]],
        })
    payload = {
        "schema_version": 3,
        "video": {"id": root.name, "sha256": index["source_sha256"], "duration_seconds": metadata.get("probe", {}).get("format", {}).get("duration")},
        "claims": claims,
        "timeline_refs": [{"id": event["id"], "start_seconds": event["start_seconds"], "end_seconds": event["end_seconds"], "evidence": event["evidence"]} for event in timeline["events"]],
        "forbidden_payloads": ["source.mp4", "image_bytes", "audio_bytes", "contact_sheets", "temporary_media_url", "cookies"],
    }
    encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(encoded) > 64 * 1024:
        raise SystemExit("evidence context exceeds 64KiB; reduce summaries, never embed media")
    write_json_atomic(root / "evidence-context.json", payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("init-plan", "subtitle-skeleton", "export-context"):
        command = commands.add_parser(name)
        command.add_argument("bundle", type=Path)
        if name != "export-context":
            command.add_argument("--force", action="store_true")
    cfg = parser.parse_args()
    root = cfg.bundle.resolve()
    if not (root / "source.mp4").is_file():
        raise SystemExit("source.mp4 is required")
    if cfg.command == "init-plan":
        init_plan(root, cfg.force)
    elif cfg.command == "subtitle-skeleton":
        build_subtitle_skeleton(root, cfg.force)
    else:
        export_context(root)
    print(json.dumps({"ok": True, "command": cfg.command, "bundle": str(root)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
