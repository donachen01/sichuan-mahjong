#!/usr/bin/env python3
"""Measure neutral face brightness for the human rack and public river."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


REFERENCE_SIZE = (2048, 1152)
REFERENCE_REGIONS = {
    "self_hand": (587, 880, 1865, 1028),
    "public_river": (570, 270, 1480, 700),
}


def _scaled_region(name: str, width: int, height: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = REFERENCE_REGIONS[name]
    sx = width / REFERENCE_SIZE[0]
    sy = height / REFERENCE_SIZE[1]
    return tuple(round(value * (sx if index % 2 == 0 else sy)) for index, value in enumerate((left, top, right, bottom)))


def _neutral_bright_median(image: np.ndarray, region: tuple[int, int, int, int]) -> dict[str, object]:
    left, top, right, bottom = region
    pixels = image[top:bottom, left:right]
    channel_spread = pixels.max(axis=2) - pixels.min(axis=2)
    channel_mean = pixels.mean(axis=2)
    mask = (channel_mean > 225.0) & (channel_spread < 20)
    selected = pixels[mask]
    if selected.size == 0:
        raise RuntimeError(f"no neutral bright pixels in region {region}")
    median_rgb = np.median(selected, axis=0)
    median_brightness = float(np.median(selected.mean(axis=1)))
    return {
        "region": list(region),
        "sample_count": int(selected.shape[0]),
        "median_rgb": [round(float(value), 4) for value in median_rgb],
        "median_srgb_channel_mean": round(median_brightness, 4),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    image = np.asarray(Image.open(args.image).convert("RGB"))
    height, width = image.shape[:2]
    hand = _neutral_bright_median(image, _scaled_region("self_hand", width, height))
    river = _neutral_bright_median(image, _scaled_region("public_river", width, height))
    delta = abs(float(hand["median_srgb_channel_mean"]) - float(river["median_srgb_channel_mean"]))
    result = {
        "criterion": "AC-HAND-01",
        "image": str(args.image),
        "image_size": [width, height],
        "method": "median sRGB channel mean over neutral bright face pixels (mean>225, channel spread<20)",
        "self_hand": hand,
        "public_river": river,
        "median_brightness_delta_255": round(delta, 4),
        "allowed_delta_255": 3.0,
        "objective_result": "PASS" if delta <= 3.0 else "FAIL",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["objective_result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
