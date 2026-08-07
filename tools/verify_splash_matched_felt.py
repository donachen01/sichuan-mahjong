#!/usr/bin/env python3
"""Verify splash-matched felt source maps and final Metal renders."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


EXPECTED_MAP_SIZE = (2048, 2048)
NORMAL_ENERGY_RATIO_MAX = 1.30
BASE_LUMINANCE_CV_RANGE = (0.006, 0.018)
ROUGHNESS_MEDIAN_RANGE = (0.86, 0.90)
ROUGHNESS_SPAN_MAX = 0.06
RENDER_RED_GREEN_RANGE = (0.35, 0.50)
RENDER_BLUE_GREEN_RANGE = (0.40, 0.62)
RENDER_LUMINANCE_RANGE = (0.36, 0.46)


def _in_range(value: float, accepted: tuple[float, float]) -> bool:
    return accepted[0] <= value <= accepted[1]


def _load_rgb(path: Path) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    if image.size != EXPECTED_MAP_SIZE:
        raise ValueError(f"expected {EXPECTED_MAP_SIZE} map, found {image.size}: {path}")
    return np.asarray(image, dtype=np.float64) / 255.0


def analyze_maps(root: Path) -> dict[str, object]:
    base = _load_rgb(root / "felt_basecolor.png")
    normal = _load_rgb(root / "felt_normal.png")
    orm = _load_rgb(root / "felt_orm.png")

    luminance = base @ np.array([0.2126, 0.7152, 0.0722])
    tangent_x = normal[:, :, 0] * 2.0 - 1.0
    tangent_y = normal[:, :, 1] * 2.0 - 1.0
    energy_x = float(np.mean(tangent_x * tangent_x))
    energy_y = float(np.mean(tangent_y * tangent_y))
    energy_ratio = max(energy_x, energy_y) / max(min(energy_x, energy_y), 1e-12)
    roughness = orm[:, :, 1]

    metrics = {
        "normal_energy_x": energy_x,
        "normal_energy_y": energy_y,
        "normal_energy_ratio": energy_ratio,
        "base_luminance_cv": float(np.std(luminance) / np.mean(luminance)),
        "roughness_median": float(np.median(roughness)),
        "roughness_span": float(np.max(roughness) - np.min(roughness)),
        "metallic_max": float(np.max(orm[:, :, 2])),
    }
    checks = {
        "balanced_normal_energy": metrics["normal_energy_ratio"] <= NORMAL_ENERGY_RATIO_MAX,
        "subtle_base_variation": _in_range(
            metrics["base_luminance_cv"], BASE_LUMINANCE_CV_RANGE
        ),
        "high_roughness": _in_range(
            metrics["roughness_median"], ROUGHNESS_MEDIAN_RANGE
        ),
        "restrained_roughness_span": metrics["roughness_span"] <= ROUGHNESS_SPAN_MAX,
        "non_metallic": metrics["metallic_max"] == 0.0,
    }
    return {"root": str(root), "metrics": metrics, "checks": checks, "passed": all(checks.values())}


def analyze_render(path: Path) -> dict[str, object]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    height, width, _ = rgb.shape
    y, x = np.mgrid[0:height, 0:width]
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    spatial = (
        (x > width * 0.15)
        & (x < width * 0.85)
        & (y > height * 0.03)
        & (y < height * 0.95)
    )
    mask = (
        spatial
        & (green > red * 1.15)
        & (green > blue * 1.08)
        & (green > 0.18)
        & (green < 0.75)
    )
    selected = rgb[mask]
    minimum_pixels = int(width * height * 0.10)
    if selected.shape[0] < minimum_pixels:
        raise RuntimeError(
            f"insufficient felt pixels in {path}: {selected.shape[0]} < {minimum_pixels}"
        )

    median = np.median(selected, axis=0)
    luminance = float(median @ np.array([0.2126, 0.7152, 0.0722]))
    metrics = {
        "image_size": [width, height],
        "felt_pixel_count": int(selected.shape[0]),
        "median_rgb8": np.rint(median * 255.0).astype(int).tolist(),
        "red_green_ratio": float(median[0] / median[1]),
        "blue_green_ratio": float(median[2] / median[1]),
        "luminance": luminance,
    }
    checks = {
        "warm_green_red_ratio": _in_range(
            metrics["red_green_ratio"], RENDER_RED_GREEN_RANGE
        ),
        "reduced_cyan_blue_ratio": _in_range(
            metrics["blue_green_ratio"], RENDER_BLUE_GREEN_RANGE
        ),
        "splash_matched_luminance": _in_range(luminance, RENDER_LUMINANCE_RANGE),
    }
    return {"path": str(path), "metrics": metrics, "checks": checks, "passed": all(checks.values())}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--maps-root", required=True, type=Path)
    parser.add_argument("--render", action="append", default=[], type=Path)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()

    maps = analyze_maps(arguments.maps_root)
    renders = [analyze_render(path) for path in arguments.render]
    payload = {
        "maps": maps,
        "renders": renders,
        "passed": bool(maps["passed"]) and all(bool(render["passed"]) for render in renders),
    }
    output = json.dumps(payload, ensure_ascii=False, indent=2)
    if arguments.output is not None:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(output + "\n", encoding="utf-8")
    print(output)
    return 0 if payload["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
