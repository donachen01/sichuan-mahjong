#!/usr/bin/env python3
"""Split one grouped voice synthesis at natural pauses without changing speed.

Review the reported boundaries and listen to the output before copying it into
res/audio. The command stops when it cannot find the expected number of pauses.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / "artifacts/voice_options_20260924/batches.json"
SAMPLE_RATE = 24_000
FRAME_SAMPLES = 240


def decode(path: Path) -> np.ndarray:
    result = subprocess.run(
        ["/opt/homebrew/bin/ffmpeg", "-v", "error", "-i", str(path),
         "-f", "f32le", "-acodec", "pcm_f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "pipe:1"],
        check=True, capture_output=True,
    )
    return np.frombuffer(result.stdout, dtype="<f4").copy()


def energy_envelope(audio: np.ndarray) -> np.ndarray:
    full_frames = len(audio) // FRAME_SAMPLES
    frames = audio[:full_frames * FRAME_SAMPLES].reshape(full_frames, FRAME_SAMPLES)
    return np.sqrt(np.mean(frames * frames, axis=1))


def silence_intervals(envelope: np.ndarray, threshold: float, minimum_frames: int) -> list[tuple[int, int]]:
    quiet = envelope < threshold
    edges = np.diff(np.r_[False, quiet, False].astype(np.int8))
    starts = np.where(edges == 1)[0]
    ends = np.where(edges == -1)[0]
    return [(int(start), int(end)) for start, end in zip(starts, ends) if end - start >= minimum_frames]


def find_boundaries(audio: np.ndarray, count: int) -> tuple[list[float], dict]:
    envelope = energy_envelope(audio)
    peak = float(np.percentile(envelope, 99))
    duration = len(audio) / SAMPLE_RATE
    alternatives = []
    for relative_db in (24, 28, 32, 36, 40):
        threshold = max(0.0005, peak * 10 ** (-relative_db / 20))
        for minimum_frames in (7, 5, 4):
            intervals = [
                (start, end) for start, end in silence_intervals(envelope, threshold, minimum_frames)
                if start * 0.01 > 0.2 and end * 0.01 < duration - 0.2
            ]
            if len(intervals) < count - 1:
                continue
            # Full-stop pauses should be longer than pauses at commas. Keep
            # the longest expected number, then restore reading order.
            chosen = sorted(sorted(intervals, key=lambda pair: pair[1] - pair[0], reverse=True)[:count - 1])
            points = [(start + end) * 0.005 for start, end in chosen]
            lengths = np.diff([0.0, *points, duration])
            if float(np.min(lengths)) < 0.16:
                continue
            score = float(sum(end - start for start, end in chosen)) - 8.0 * float(np.std(lengths))
            alternatives.append((score, points, relative_db, minimum_frames, chosen))
    if not alternatives:
        raise ValueError(f"only insufficient natural pauses found for {count} utterances; split manually")
    _, points, relative_db, minimum_frames, chosen = max(alternatives, key=lambda item: item[0])
    return points, {
        "duration": duration,
        "relative_db": relative_db,
        "minimum_pause_ms": minimum_frames * 10,
        "pauses": [[start * 0.01, end * 0.01] for start, end in chosen],
    }


def trimmed_region(audio: np.ndarray, envelope: np.ndarray, start: float, end: float) -> np.ndarray:
    first = max(0, int(start * SAMPLE_RATE))
    last = min(len(audio), int(end * SAMPLE_RATE))
    segment = audio[first:last]
    if len(segment) == 0:
        raise ValueError("empty segment")
    frame_first = int(start * 100)
    frame_last = min(len(envelope), int(end * 100))
    local = envelope[frame_first:frame_last]
    active = np.flatnonzero(local >= max(0.0008, float(np.percentile(envelope, 95)) * 0.04))
    if len(active) == 0:
        raise ValueError("segment contains no audible speech")
    trim_start = max(0, int(active[0] * FRAME_SAMPLES) - 480)
    trim_end = min(len(segment), int((active[-1] + 1) * FRAME_SAMPLES) + 480)
    return segment[trim_start:trim_end]


def write_wav(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(audio, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("voice_id")
    parser.add_argument("group")
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/voice_options_20260924/split_preview")
    parser.add_argument("--boundaries", help="manual comma-separated cut times in seconds")
    args = parser.parse_args()

    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    voice = next(item for item in plan if item["id"] == args.voice_id)
    group = next(item for item in voice["groups"] if item["group"] == args.group)
    audio = decode(args.source)
    envelope = energy_envelope(audio)
    if args.boundaries:
        points = [float(value) for value in args.boundaries.split(",")]
        info = {"duration": len(audio) / SAMPLE_RATE, "manual": True}
    else:
        points, info = find_boundaries(audio, len(group["keys"]))
    if len(points) != len(group["keys"]) - 1:
        raise ValueError("boundary count does not match utterance count")
    edges = [0.0, *points, len(audio) / SAMPLE_RATE]
    clips = [trimmed_region(audio, envelope, start, end) for start, end in zip(edges, edges[1:])]
    group_peak = max(float(np.max(np.abs(clip))) for clip in clips)
    gain = min(3.0, 0.85 / group_peak) if group_peak > 0 else 1.0
    report = {"voice_id": args.voice_id, "group": args.group, "source": str(args.source),
              "keys": group["keys"], "texts": group["texts"], "boundaries": points,
              "split_detection": info, "clips": {}}
    for key, text, clip in zip(group["keys"], group["texts"], clips):
        destination = args.output / args.voice_id / f"{key}.wav"
        write_wav(destination, clip * gain)
        report["clips"][key] = {"text": text, "seconds": round(len(clip) / SAMPLE_RATE, 3),
                                "path": str(destination)}
    report_path = args.output / args.voice_id / f"{args.group}_split.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"voice_id": args.voice_id, "group": args.group, "boundaries": points,
                      "durations": [round(len(clip) / SAMPLE_RATE, 3) for clip in clips]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
