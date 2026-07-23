#!/usr/bin/env python3
"""Measure the accepted camera's summer-blue tabletop color hierarchy."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


TARGETS = {
    "top": np.array([83.0, 120.0, 170.0]),
    "middle": np.array([74.0, 100.0, 151.0]),
    "lower": np.array([70.0, 88.0, 139.0]),
}
REGIONS = {
    "top": (0.20, 0.15, 0.80, 0.30),
    "middle": (0.18, 0.34, 0.82, 0.55),
    "lower": (0.18, 0.60, 0.82, 0.75),
}
BAND_Y_VALUES = np.arange(0.15, 0.751, 0.05)
BAND_REGION_X = (0.18, 0.82)
TEXTURE_REGION = (0.65, 0.22, 0.73, 0.30)


def _crop(image: Image.Image, box: tuple[float, float, float, float]) -> np.ndarray:
    width, height = image.size
    x0, y0, x1, y1 = box
    return np.asarray(
        image.crop((round(x0 * width), round(y0 * height), round(x1 * width), round(y1 * height))).convert("RGB"),
        dtype=np.float64,
    ).reshape(-1, 3)


def _table_blue(pixels: np.ndarray) -> np.ndarray:
    mask = (
        (pixels[:, 2] > pixels[:, 1] * 1.20)
        & (pixels[:, 1] > pixels[:, 0] * 1.05)
        & (pixels[:, 0] > 35.0)
        & (pixels[:, 2] < 210.0)
    )
    selected = pixels[mask]
    if selected.size == 0:
        raise RuntimeError("no tabletop-blue pixels found")
    return selected


def _relative_luminance(rgb: np.ndarray) -> float:
    values = rgb / 255.0
    values = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    return float(0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2])


def analyze(path: Path) -> dict[str, object]:
    image = Image.open(path).convert("RGB")
    medians: dict[str, np.ndarray] = {}
    distances: dict[str, float] = {}
    for name, region in REGIONS.items():
        pixels = _table_blue(_crop(image, region))
        medians[name] = np.median(pixels, axis=0)
        distances[name] = float(np.linalg.norm(medians[name] - TARGETS[name]))

    luminances = {name: _relative_luminance(value) for name, value in medians.items()}
    top_middle_drop = luminances["top"] - luminances["middle"]
    middle_lower_drop = luminances["middle"] - luminances["lower"]
    top_lower_drop = luminances["top"] - luminances["lower"]

    band_medians: list[np.ndarray] = []
    for y_start in BAND_Y_VALUES:
        band_region = (
            BAND_REGION_X[0],
            float(y_start),
            BAND_REGION_X[1],
            float(min(y_start + 0.025, 0.77)),
        )
        band_medians.append(np.median(_table_blue(_crop(image, band_region)), axis=0))
    band_jumps = [
        float(np.linalg.norm(band_medians[index + 1] - band_medians[index]))
        for index in range(len(band_medians) - 1)
    ]

    texture_pixels = _table_blue(_crop(image, TEXTURE_REGION))
    texture_std = np.std(texture_pixels, axis=0)
    texture_max_std = float(texture_std.max())
    checks = {
        "top_distance_lte_18": distances["top"] <= 18.0,
        "middle_distance_lte_18": distances["middle"] <= 18.0,
        "lower_distance_lte_20": distances["lower"] <= 20.0,
        "top_middle_luminance_drop_gte_0_035": top_middle_drop >= 0.035,
        "middle_lower_luminance_drop_gte_0_018": middle_lower_drop >= 0.018,
        "top_lower_luminance_drop_gte_0_055": top_lower_drop >= 0.055,
        "blue_channel_order": all(value[2] > value[1] > value[0] for value in medians.values()),
        "adjacent_5_percent_band_jump_lte_18": max(band_jumps) <= 18.0,
        "local_texture_channel_std_lte_8": texture_max_std <= 8.0,
        "local_texture_has_subtle_variation": texture_max_std >= 0.30,
    }
    result = {
        "candidate": str(path),
        "medians": {name: np.rint(value).astype(int).tolist() for name, value in medians.items()},
        "distances": {name: round(value, 4) for name, value in distances.items()},
        "luminances": {name: round(value, 6) for name, value in luminances.items()},
        "drops": {
            "top_middle": round(top_middle_drop, 6),
            "middle_lower": round(middle_lower_drop, 6),
            "top_lower": round(top_lower_drop, 6),
        },
        "band_medians": [np.rint(value).astype(int).tolist() for value in band_medians],
        "band_jumps": [round(value, 4) for value in band_jumps],
        "max_band_jump": round(max(band_jumps), 4),
        "texture_region": {
            "normalized_box": list(TEXTURE_REGION),
            "channel_std": [round(float(value), 4) for value in texture_std],
            "max_channel_std": round(texture_max_std, 4),
        },
        "checks": checks,
        "passed": all(checks.values()),
    }
    return result


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
