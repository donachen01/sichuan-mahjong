#!/usr/bin/env python3
"""Compare rendered Mahjong tile colors and glyph contrast with the target image."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


TARGET_FACE = np.array([233.0, 232.0, 235.0])
TARGET_BACK = np.array([43.0, 144.0, 49.0])
TARGET_GREEN_CONTRAST = 7.3917
TARGET_RED_CONTRAST = 6.8729


def crop_normalized(image: Image.Image, box: tuple[float, float, float, float]) -> np.ndarray:
    width, height = image.size
    left, top, right, bottom = box
    crop = image.crop((round(left * width), round(top * height), round(right * width), round(bottom * height)))
    return np.asarray(crop.convert("RGB"), dtype=np.float64).reshape(-1, 3)


def median_for_mask(pixels: np.ndarray, mask: np.ndarray, label: str) -> np.ndarray:
    selected = pixels[mask]
    if selected.size == 0:
        raise RuntimeError(f"no pixels matched {label}")
    return np.median(selected, axis=0)


def relative_luminance(rgb: np.ndarray) -> float:
    values = rgb / 255.0
    values = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    return float(0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2])


def contrast_ratio(first: np.ndarray, second: np.ndarray) -> float:
    first_luminance = relative_luminance(first)
    second_luminance = relative_luminance(second)
    lighter = max(first_luminance, second_luminance)
    darker = min(first_luminance, second_luminance)
    return (lighter + 0.05) / (darker + 0.05)


def rgb_distance(first: np.ndarray, second: np.ndarray) -> float:
    return float(np.linalg.norm(first - second))


def analyze(candidate_path: Path) -> dict[str, object]:
    image = Image.open(candidate_path).convert("RGB")
    # These regions follow the fixed camera/layout contract accepted in stages 1-2.
    hand = crop_normalized(image, (0.080, 0.755, 0.870, 0.920))
    far_back = crop_normalized(image, (0.350, 0.085, 0.640, 0.205))

    neutral_mask = (hand.min(axis=1) > 190.0) & ((hand.max(axis=1) - hand.min(axis=1)) < 20.0)
    green_mask = (hand[:, 1] > hand[:, 0] * 1.25) & (hand[:, 1] > hand[:, 2] * 1.05) & (hand[:, 1] > 35.0)
    red_mask = (hand[:, 0] > hand[:, 1] * 1.35) & (hand[:, 0] > hand[:, 2] * 1.15) & (hand[:, 0] > 70.0)
    back_mask = (
        (far_back[:, 1] > far_back[:, 0] * 1.22)
        & (far_back[:, 1] > far_back[:, 2] * 1.05)
        & (far_back[:, 1] > 55.0)
    )

    face = median_for_mask(hand, neutral_mask, "neutral face")
    green = median_for_mask(hand, green_mask, "green glyph")
    red = median_for_mask(hand, red_mask, "red glyph")
    back = median_for_mask(far_back, back_mask, "green back")
    face_q90 = np.quantile(hand[neutral_mask], 0.90, axis=0)
    green_contrast = contrast_ratio(face, green)
    red_contrast = contrast_ratio(face, red)

    checks = {
        "face_rgb_distance_lte_15": rgb_distance(face, TARGET_FACE) <= 15.0,
        "back_rgb_distance_lte_22": rgb_distance(back, TARGET_BACK) <= 22.0,
        "face_q90_max_lte_248": float(face_q90.max()) <= 248.0,
        "green_contrast_gte_6": green_contrast >= 6.0,
        "green_contrast_gte_80pct_target": green_contrast >= TARGET_GREEN_CONTRAST * 0.80,
        "red_contrast_gte_5_5": red_contrast >= 5.5,
        "red_contrast_gte_80pct_target": red_contrast >= TARGET_RED_CONTRAST * 0.80,
    }
    return {
        "candidate": str(candidate_path),
        "face_median_rgb": np.rint(face).astype(int).tolist(),
        "face_q90_rgb": np.rint(face_q90).astype(int).tolist(),
        "back_median_rgb": np.rint(back).astype(int).tolist(),
        "green_median_rgb": np.rint(green).astype(int).tolist(),
        "red_median_rgb": np.rint(red).astype(int).tolist(),
        "face_rgb_distance": round(rgb_distance(face, TARGET_FACE), 4),
        "back_rgb_distance": round(rgb_distance(back, TARGET_BACK), 4),
        "green_contrast": round(green_contrast, 4),
        "red_contrast": round(red_contrast, 4),
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
