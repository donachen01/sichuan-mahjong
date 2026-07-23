#!/usr/bin/env python3
"""Measure contact-shadow depth beneath the accepted far concealed hand row."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def _screen_luminance(pixels: np.ndarray) -> np.ndarray:
    return pixels @ np.array([0.2126, 0.7152, 0.0722])


def _top_hand_bottom(image: np.ndarray) -> int:
    height, width, _ = image.shape
    region = image[: round(height * 0.23), round(width * 0.22) : round(width * 0.78)]
    green = (
        (region[:, :, 1] > region[:, :, 0] * 1.25)
        & (region[:, :, 1] > region[:, :, 2] * 1.05)
        & (region[:, :, 1] > 20)
        & (region[:, :, 0] < 110)
    )
    row_counts = green.sum(axis=1)
    dense_rows = np.flatnonzero(row_counts > max(20, round(width * 0.04)))
    if dense_rows.size == 0:
        raise RuntimeError("far concealed hand row was not found")
    return int(dense_rows.max())


def _strip(image: np.ndarray, hand_bottom: int, start: int, end: int) -> dict[str, object]:
    height, width, _ = image.shape
    pixels = image[
        hand_bottom + start : min(height, hand_bottom + end),
        round(width * 0.22) : round(width * 0.78),
    ].reshape(-1, 3)
    # Exclude leaked green tile pixels and any bright HUD/tile-face pixels while
    # retaining blue-tinted shadow pixels all the way down to their dark core.
    green = (
        (pixels[:, 1] > pixels[:, 0] * 1.40)
        & (pixels[:, 1] > pixels[:, 2] * 1.10)
        & (pixels[:, 1] > 70)
    )
    usable = pixels[(~green) & (pixels.max(axis=1) < 230)]
    if usable.size == 0:
        raise RuntimeError("no usable tabletop pixels in shadow strip")
    luminance = _screen_luminance(usable)
    return {
        "median_rgb": np.rint(np.median(usable, axis=0)).astype(int).tolist(),
        "median_luminance": round(float(np.median(luminance)), 4),
        "p10_luminance": round(float(np.percentile(luminance, 10)), 4),
        "sample_count": int(usable.shape[0]),
    }


def analyze(path: Path) -> dict[str, object]:
    image = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    hand_bottom = _top_hand_bottom(image)
    contact = _strip(image, hand_bottom, 2, 6)
    transition = _strip(image, hand_bottom, 7, 12)
    recovery = _strip(image, hand_bottom, 13, 20)
    contact_luma = float(contact["median_luminance"])
    transition_luma = float(transition["median_luminance"])
    recovery_luma = float(recovery["median_luminance"])
    ratio = contact_luma / max(1.0, recovery_luma)
    recovery_delta = recovery_luma - contact_luma

    height, width, _ = image.shape
    center_pixels = image[
        round(height * 0.30) : round(height * 0.65),
        round(width * 0.35) : round(width * 0.65),
    ].reshape(-1, 3)
    center_blue = (
        (center_pixels[:, 2] > center_pixels[:, 1] * 1.12)
        & (center_pixels[:, 1] > center_pixels[:, 0] * 1.02)
        & (center_pixels[:, 2] < 220)
        & (center_pixels[:, 0] > 5)
    )
    center_luminance = _screen_luminance(center_pixels[center_blue])
    center_median = float(np.median(center_luminance))
    center_p5 = float(np.percentile(center_luminance, 5))
    center_p10 = float(np.percentile(center_luminance, 10))
    center_p5_ratio = center_p5 / max(1.0, center_median)
    center_p10_ratio = center_p10 / max(1.0, center_median)
    center_dark_coverage = float(np.mean(center_luminance < center_median * 0.72))
    checks = {
        "center_p5_median_ratio_between_0_45_and_0_72": 0.45 <= center_p5_ratio <= 0.72,
        "center_dark_shadow_coverage_between_0_04_and_0_10": 0.04 <= center_dark_coverage <= 0.10,
        "center_p5_luminance_gte_45": center_p5 >= 45.0,
    }
    return {
        "candidate": str(path),
        "far_hand_bottom_y": hand_bottom,
        "contact": contact,
        "transition": transition,
        "recovery": recovery,
        "contact_recovery_ratio": round(ratio, 6),
        "recovery_delta": round(recovery_delta, 4),
        "center_play_area": {
            "median_luminance": round(center_median, 4),
            "p5_luminance": round(center_p5, 4),
            "p10_luminance": round(center_p10, 4),
            "p5_median_ratio": round(center_p5_ratio, 6),
            "p10_median_ratio": round(center_p10_ratio, 6),
            "dark_shadow_coverage": round(center_dark_coverage, 6),
        },
        "checks": checks,
        "passed": all(checks.values()),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = analyze(args.candidate)
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    print(payload)
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
