#!/usr/bin/env python3
"""Extract baseline or exact-timestamp evidence frames with a JSON manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from decimal import Decimal
from pathlib import Path


def args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("video", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--fps", type=Decimal, default=Decimal("1"))
    parser.add_argument("--start", type=Decimal, default=Decimal("0"))
    parser.add_argument("--end", type=Decimal)
    parser.add_argument("--timestamps", help="Comma-separated exact seconds")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def exact_frames(video: Path, out: Path, values: list[Decimal]) -> list[dict]:
    frames = []
    for index, timestamp in enumerate(values, 1):
        path = out / f"frame_{index:06d}_{float(timestamp):010.3f}s.jpg"
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-ss", str(timestamp), "-i", str(video), "-frames:v", "1",
            "-q:v", "2", str(path),
        ], check=True)
        frames.append({"index": index, "timestamp": float(timestamp),
                       "file": path.name, "sha256": digest(path)})
    return frames


def baseline_frames(video: Path, out: Path, fps: Decimal, start: Decimal,
                    end: Decimal | None) -> list[dict]:
    pattern = out / "frame_%06d.jpg"
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
               "-ss", str(start), "-i", str(video)]
    if end is not None:
        command += ["-t", str(end - start)]
    command += ["-vf", f"fps={fps}", "-q:v", "2", str(pattern)]
    subprocess.run(command, check=True)
    frames = []
    for index, path in enumerate(sorted(out.glob("frame_*.jpg")), 1):
        timestamp = start + (Decimal(index - 1) / fps)
        frames.append({"index": index, "timestamp": float(timestamp),
                       "file": path.name, "sha256": digest(path)})
    return frames


def main() -> None:
    cfg = args()
    if not shutil.which("ffmpeg"):
        raise SystemExit("ffmpeg is required")
    if not cfg.video.is_file():
        raise SystemExit(f"Video not found: {cfg.video}")
    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    existing = list(cfg.output_dir.glob("frame_*.jpg"))
    if existing and not cfg.force:
        raise SystemExit("Frames already exist; pass --force or use another directory")
    if cfg.force:
        # A forced re-extraction may use fewer or differently named timestamps.
        # Remove only evidence frames owned by this exact output directory so
        # stale JPEGs cannot leak into OCR or contact-sheet manifests.
        for path in existing:
            path.unlink()
        for generated in ("frames.json", "ocr.json"):
            (cfg.output_dir / generated).unlink(missing_ok=True)
    if cfg.timestamps:
        values = [Decimal(x.strip()) for x in cfg.timestamps.split(",") if x.strip()]
        frames = exact_frames(cfg.video, cfg.output_dir, values)
        mode = "exact"
    else:
        if cfg.fps <= 0 or (cfg.end is not None and cfg.end <= cfg.start):
            raise SystemExit("Invalid fps/start/end")
        frames = baseline_frames(cfg.video, cfg.output_dir, cfg.fps, cfg.start, cfg.end)
        # Only a whole-video cadence is the baseline.  A bounded escalation is
        # a review window; labelling it as baseline makes the bundle validator
        # (correctly) expect it to cover the whole source.
        mode = "baseline" if cfg.start == 0 and cfg.end is None else "window"
    manifest = {
        "video": str(cfg.video.resolve()), "video_sha256": digest(cfg.video),
        "mode": mode, "fps": float(cfg.fps), "start": float(cfg.start),
        "end": float(cfg.end) if cfg.end is not None else None,
        "frame_count": len(frames), "frames": frames,
    }
    (cfg.output_dir / "frames.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({k: manifest[k] for k in ("mode", "frame_count", "video_sha256")},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
