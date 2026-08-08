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
BASE_LUMINANCE_CV_MAX = 0.004
BASE_LOWPASS_STD_FRACTION_MAX = 0.20
BASE_LOWFREQ_P99_P1_MAX = 1.5 / 255.0
NORMAL_LOWPASS_STD_FRACTION_MAX = 0.05
NORMAL_MID_FREQUENCY_RATIO_MIN = 0.10
ROUGHNESS_MEDIAN_RANGE = (0.83, 0.87)
ROUGHNESS_SPAN_MAX = 0.06
ROUGHNESS_P99_P1_MAX = 0.025
TOP_FACE_UV_BOUNDS = (0.6556, 0.9423, 0.5037, 0.9799)
LOWPASS_GRID_SIZE = (28, 28)
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


def _top_face_crop(field: np.ndarray) -> np.ndarray:
    u0, u1, v0, v1 = TOP_FACE_UV_BOUNDS
    height, width = field.shape[:2]
    return field[
        round((1.0 - v1) * height):round((1.0 - v0) * height),
        round(u0 * width):round(u1 * width),
    ]


def _lowpass(field: np.ndarray) -> np.ndarray:
    source = Image.fromarray(field.astype(np.float32))
    return np.asarray(
        source.resize(LOWPASS_GRID_SIZE, Image.Resampling.BOX).resize(
            source.size, Image.Resampling.BILINEAR
        ),
        dtype=np.float64,
    )


def _lowpass_std_fraction(field: np.ndarray) -> float:
    total_std = float(np.std(field))
    if total_std <= 1e-12:
        return 0.0
    return float(np.std(_lowpass(field)) / total_std)


def _resampled_lowpass(field: np.ndarray, grid_size: tuple[int, int]) -> np.ndarray:
    source = Image.fromarray(field.astype(np.float32))
    return np.asarray(
        source.resize(grid_size, Image.Resampling.BOX).resize(
            source.size, Image.Resampling.BILINEAR
        ),
        dtype=np.float64,
    )


def analyze_normal_frequency_bands(normal_rgb: np.ndarray) -> dict[str, float]:
    """Measure normal energy on the actual felt top-face UV footprint."""
    tangent_x = _top_face_crop(normal_rgb[:, :, 0] * 2.0 - 1.0)
    tangent_y = _top_face_crop(normal_rgb[:, :, 1] * 2.0 - 1.0)
    total_energy = float(np.mean(tangent_x * tangent_x + tangent_y * tangent_y))
    if total_energy <= 1e-12:
        return {
            "normal_direction_energy_ratio": 1.0,
            "normal_low_frequency_ratio": 0.0,
            "normal_mid_frequency_ratio": 0.0,
        }

    energy_x = float(np.mean(tangent_x * tangent_x))
    energy_y = float(np.mean(tangent_y * tangent_y))
    low_x = _resampled_lowpass(tangent_x, LOWPASS_GRID_SIZE)
    low_y = _resampled_lowpass(tangent_y, LOWPASS_GRID_SIZE)
    # 160x160 retains the intended 180-320-cycle nap over this UV crop while
    # rejecting the existing 520-830-cycle micro fibres.
    mid_x = _resampled_lowpass(tangent_x, (160, 160))
    mid_y = _resampled_lowpass(tangent_y, (160, 160))
    low_energy = float(np.mean(low_x * low_x + low_y * low_y))
    mid_energy = float(
        np.mean((mid_x - low_x) ** 2 + (mid_y - low_y) ** 2)
    )
    return {
        "normal_direction_energy_ratio": max(energy_x, energy_y)
        / max(min(energy_x, energy_y), 1e-12),
        "normal_low_frequency_ratio": low_energy / total_energy,
        "normal_mid_frequency_ratio": mid_energy / total_energy,
    }


def analyze_maps(root: Path) -> dict[str, object]:
    base = _load_rgb(root / "felt_basecolor.png")
    normal = _load_rgb(root / "felt_normal.png")
    orm = _load_rgb(root / "felt_orm.png")

    luminance = base @ np.array([0.2126, 0.7152, 0.0722])
    tangent_x = normal[:, :, 0] * 2.0 - 1.0
    tangent_y = normal[:, :, 1] * 2.0 - 1.0
    energy_x = float(np.mean(tangent_x * tangent_x))
    energy_y = float(np.mean(tangent_y * tangent_y))
    normal_bands = analyze_normal_frequency_bands(normal)
    roughness = orm[:, :, 1]
    top_luminance = _top_face_crop(luminance)
    top_lowpass = _lowpass(top_luminance)
    base_luminance_cv = float(np.std(luminance) / np.mean(luminance))
    base_lowpass_std_fraction = _lowpass_std_fraction(top_luminance)
    base_lowfreq_p99_p1 = float(
        np.percentile(top_lowpass, 99) - np.percentile(top_lowpass, 1)
    )
    normal_lowpass_std_fraction = max(
        _lowpass_std_fraction(_top_face_crop(tangent_x)),
        _lowpass_std_fraction(_top_face_crop(tangent_y)),
    )
    top_roughness = _top_face_crop(roughness)
    roughness_p99_p1 = float(
        np.percentile(top_roughness, 99) - np.percentile(top_roughness, 1)
    )

    metrics = {
        "normal_energy_x": energy_x,
        "normal_energy_y": energy_y,
        "normal_energy_ratio": normal_bands["normal_direction_energy_ratio"],
        **normal_bands,
        "base_luminance_cv": base_luminance_cv,
        "base_lowpass_std_fraction": base_lowpass_std_fraction,
        "base_lowfreq_p99_p1": base_lowfreq_p99_p1,
        "normal_lowpass_std_fraction": normal_lowpass_std_fraction,
        "roughness_median": float(np.median(roughness)),
        "roughness_span": float(np.max(roughness) - np.min(roughness)),
        "roughness_p99_p1": roughness_p99_p1,
        "metallic_max": float(np.max(orm[:, :, 2])),
    }
    checks = {
        "balanced_normal_energy": metrics["normal_energy_ratio"] <= NORMAL_ENERGY_RATIO_MAX,
        "subtle_base_variation": metrics["base_luminance_cv"] <= BASE_LUMINANCE_CV_MAX,
        "clean_base_low_frequency": (
            metrics["base_lowpass_std_fraction"] <= BASE_LOWPASS_STD_FRACTION_MAX
        ),
        "restrained_base_lowfreq_span": (
            metrics["base_lowfreq_p99_p1"] <= BASE_LOWFREQ_P99_P1_MAX
        ),
        "clean_normal_low_frequency": (
            metrics["normal_lowpass_std_fraction"] <= NORMAL_LOWPASS_STD_FRACTION_MAX
        ),
        "visible_mid_scale_nap": (
            metrics["normal_mid_frequency_ratio"] >= NORMAL_MID_FREQUENCY_RATIO_MIN
        ),
        "tactile_roughness": _in_range(
            metrics["roughness_median"], ROUGHNESS_MEDIAN_RANGE
        ),
        "restrained_roughness_span": metrics["roughness_span"] <= ROUGHNESS_SPAN_MAX,
        "restrained_roughness_percentiles": (
            metrics["roughness_p99_p1"] <= ROUGHNESS_P99_P1_MAX
        ),
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
    parser.add_argument("--maps-root", type=Path)
    parser.add_argument("--project-root", type=Path)
    parser.add_argument("--render", action="append", default=[], type=Path)
    parser.add_argument("--output", "--output-json", dest="output", type=Path)
    arguments = parser.parse_args()

    maps_root = arguments.maps_root
    if maps_root is None and arguments.project_root is not None:
        maps_root = arguments.project_root / "res/art/materials/table_v2"
    if maps_root is None:
        parser.error("one of --maps-root or --project-root is required")

    maps = analyze_maps(maps_root)
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
