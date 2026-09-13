#!/usr/bin/env python3
"""Reuse a verified local video source or state precisely why acquisition is needed."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def normalize_title(value: object) -> str:
    """Ignore incidental title whitespace while preserving all identity checks."""
    return re.sub(r"\s+", " ", str(value)).strip()


def duration(path: Path) -> float:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        raise SystemExit("ffprobe is required")
    completed = subprocess.run(
        [ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    return float(json.loads(completed.stdout)["format"]["duration"])


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--video-id", required=True)
    parser.add_argument("--expected-title")
    cfg = parser.parse_args()
    bundle = cfg.bundle.resolve()
    source = bundle / "source.mp4"
    metadata_path = bundle / "metadata.json"
    reasons: list[str] = []
    if not source.is_file():
        reasons.append("source.mp4 missing")
    if not metadata_path.is_file():
        reasons.append("metadata.json missing")
    metadata: dict = {}
    if metadata_path.is_file():
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            reasons.append("metadata.json invalid")
    if metadata and str(metadata.get("aweme_id", "")) != cfg.video_id:
        reasons.append("metadata aweme_id mismatch")
    if cfg.expected_title and metadata:
        observed = normalize_title(metadata.get("description", ""))
        expected = normalize_title(cfg.expected_title)
        if expected not in observed and observed not in expected:
            reasons.append("metadata title/description mismatch")
    if source.is_file() and metadata:
        observed_hash = digest(source)
        if metadata.get("sha256") != observed_hash:
            reasons.append("source SHA-256 mismatch")
        observed_duration = duration(source)
        declared = float(metadata.get("duration_seconds") or metadata.get("probe", {}).get("format", {}).get("duration") or 0)
        if not declared or abs(observed_duration - declared) > 0.05:
            reasons.append("source duration mismatch")
    payload = {
        "video_id": cfg.video_id,
        "bundle": str(bundle),
        "action": "reuse_local_source" if not reasons else "acquire_source",
        "network_permitted": bool(reasons),
        "reasons": reasons,
    }
    if not reasons:
        payload["source_sha256"] = observed_hash
        payload["duration_seconds"] = observed_duration
        payload["verified_at"] = datetime.now(timezone.utc).isoformat()
        write_json_atomic(bundle / "source-verification.json", payload)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if not reasons else 2


if __name__ == "__main__":
    raise SystemExit(main())
