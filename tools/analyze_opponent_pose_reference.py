#!/usr/bin/env python3
"""Measure opponent-rack placement and axis angle against the target frame."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def _green_mask(image: np.ndarray) -> np.ndarray:
    red, green, blue = [image[:, :, index].astype(np.int16) for index in range(3)]
    return (green > 60) & ((green - red) > 18) & ((green - blue) > -8)


def _largest_rack(mask: np.ndarray, x0: int, x1: int, y1: int) -> np.ndarray:
    cropped = mask[:y1, x0:x1]
    closed = ndimage.binary_closing(cropped, structure=np.ones((21, 21), dtype=bool))
    labels, _ = ndimage.label(closed)
    best: np.ndarray | None = None
    best_area = -1
    for label_id, slices in enumerate(ndimage.find_objects(labels), start=1):
        if slices is None:
            continue
        y_slice, x_slice = slices
        if y_slice.stop - y_slice.start < mask.shape[0] * 0.30:
            continue
        local_y, local_x = np.where(labels[slices] == label_id)
        if local_x.size <= best_area:
            continue
        best_area = local_x.size
        best = np.column_stack(
            [local_x + x_slice.start + x0, local_y + y_slice.start]
        )
    if best is None:
        raise RuntimeError("could not locate side rack")
    return best


def _far_rack(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    x0, x1, y1 = int(width * 0.20), int(width * 0.80), int(height * 0.25)
    cropped = mask[:y1, x0:x1]
    closed = ndimage.binary_closing(cropped, structure=np.ones((15, 15), dtype=bool))
    labels, _ = ndimage.label(closed)
    best: np.ndarray | None = None
    best_width = -1
    for label_id, slices in enumerate(ndimage.find_objects(labels), start=1):
        if slices is None:
            continue
        y_slice, x_slice = slices
        component_width = x_slice.stop - x_slice.start
        if component_width < width * 0.20 or component_width <= best_width:
            continue
        local_y, local_x = np.where(labels[slices] == label_id)
        best_width = component_width
        best = np.column_stack(
            [local_x + x_slice.start + x0, local_y + y_slice.start]
        )
    if best is None:
        raise RuntimeError("could not locate far rack")
    return best


def _rack_metrics(points: np.ndarray, width: int, height: int) -> dict[str, float]:
    centered = points.astype(np.float64) - points.mean(axis=0)
    values, vectors = np.linalg.eigh(np.cov(centered, rowvar=False))
    axis = vectors[:, int(np.argmax(values))]
    angle = abs(float(np.degrees(np.arctan2(axis[1], axis[0]))))
    if angle > 90.0:
        angle = 180.0 - angle
    x_min, y_min = points.min(axis=0)
    x_max, y_max = points.max(axis=0)
    y_mid = float(np.median(points[:, 1]))
    top_points = points[points[:, 1] < y_mid]
    bottom_points = points[points[:, 1] >= y_mid]
    if top_points.size == 0 or bottom_points.size == 0:
        raise RuntimeError("rack axis does not contain both near and far halves")
    # Screen Y grows toward the local viewer.  Preserve the sign of the X
    # displacement so an inward-pointing rack cannot pass merely because its
    # absolute PCA angle matches the reference.
    foreground_dx = float(bottom_points[:, 0].mean() - top_points[:, 0].mean()) / width
    return {
        "axis_angle_degrees": angle,
        "x0": float(x_min) / width,
        "y0": float(y_min) / height,
        "x1": float(x_max + 1) / width,
        "y1": float(y_max + 1) / height,
        "width": float(x_max - x_min + 1) / width,
        "height": float(y_max - y_min + 1) / height,
        "foreground_dx": foreground_dx,
    }


def measure(path: Path) -> dict[str, object]:
    image = np.asarray(Image.open(path).convert("RGB"))
    height, width = image.shape[:2]
    mask = _green_mask(image)
    left = _rack_metrics(
        _largest_rack(mask, 0, int(width * 0.40), int(height * 0.88)), width, height
    )
    right = _rack_metrics(
        _largest_rack(mask, int(width * 0.60), width, int(height * 0.88)),
        width,
        height,
    )
    # The far rack uses the same physical pose but remains a horizontal row.
    # Measuring it separately prevents a left/right fix from silently leaving
    # the opponent row flat or vertically mis-scaled.
    far = _rack_metrics(_far_rack(mask), width, height)
    return {
        "path": str(path),
        "size": [width, height],
        "left": left,
        "right": right,
        "far": far,
        "side_average_angle_degrees": (left["axis_angle_degrees"] + right["axis_angle_degrees"]) / 2.0,
        "side_mirror_angle_error_degrees": abs(left["axis_angle_degrees"] - right["axis_angle_degrees"]),
        "side_average_width": (left["width"] + right["width"]) / 2.0,
        "side_average_top": (left["y0"] + right["y0"]) / 2.0,
        "side_average_bottom": (left["y1"] + right["y1"]) / 2.0,
        "side_average_inner_edge": (left["x1"] + (1.0 - right["x0"])) / 2.0,
    }


def compare(reference: dict[str, object], candidate: dict[str, object]) -> dict[str, object]:
    checks: dict[str, dict[str, object]] = {}

    def add(name: str, target: float, actual: float, tolerance: float) -> None:
        delta = actual - target
        checks[name] = {
            "target": round(target, 4),
            "actual": round(actual, 4),
            "delta": round(delta, 4),
            "tolerance": tolerance,
            "pass": abs(delta) <= tolerance,
        }

    add(
        "side_axis_angle",
        float(reference["side_average_angle_degrees"]),
        float(candidate["side_average_angle_degrees"]),
        3.0,
    )
    add(
        "left_foreground_dx",
        float(reference["left"]["foreground_dx"]),
        float(candidate["left"]["foreground_dx"]),
        0.015,
    )
    add(
        "right_foreground_dx",
        float(reference["right"]["foreground_dx"]),
        float(candidate["right"]["foreground_dx"]),
        0.015,
    )
    checks["left_foreground_outward"] = {
        "target": "<=-0.02",
        "actual": round(float(candidate["left"]["foreground_dx"]), 4),
        "pass": float(candidate["left"]["foreground_dx"]) <= -0.02,
    }
    checks["right_foreground_outward"] = {
        "target": ">=0.02",
        "actual": round(float(candidate["right"]["foreground_dx"]), 4),
        "pass": float(candidate["right"]["foreground_dx"]) >= 0.02,
    }
    add(
        "side_average_width",
        float(reference["side_average_width"]),
        float(candidate["side_average_width"]),
        0.012,
    )
    add(
        "side_average_top",
        float(reference["side_average_top"]),
        float(candidate["side_average_top"]),
        0.020,
    )
    add(
        "side_average_bottom",
        float(reference["side_average_bottom"]),
        float(candidate["side_average_bottom"]),
        0.025,
    )
    add(
        "side_average_inner_edge",
        float(reference["side_average_inner_edge"]),
        float(candidate["side_average_inner_edge"]),
        0.015,
    )
    add(
        "far_width",
        float(reference["far"]["width"]),
        float(candidate["far"]["width"]),
        0.020,
    )
    add(
        "far_top",
        float(reference["far"]["y0"]),
        float(candidate["far"]["y0"]),
        0.020,
    )
    add(
        "far_height",
        float(reference["far"]["height"]),
        float(candidate["far"]["height"]),
        0.012,
    )
    checks["far_horizontal_axis"] = {
        "target": "<=2",
        "actual": round(float(candidate["far"]["axis_angle_degrees"]), 4),
        "pass": float(candidate["far"]["axis_angle_degrees"]) <= 2.0,
    }
    checks["target_angle_band"] = {
        "target": "70-77",
        "actual": round(float(candidate["side_average_angle_degrees"]), 4),
        "pass": 70.0 <= float(candidate["side_average_angle_degrees"]) <= 77.0,
    }
    checks["mirror_angle"] = {
        "target": "<=3",
        "actual": round(float(candidate["side_mirror_angle_error_degrees"]), 4),
        "pass": float(candidate["side_mirror_angle_error_degrees"]) <= 3.0,
    }
    failures = [name for name, result in checks.items() if not bool(result["pass"])]
    return {"pass": not failures, "failures": failures, "checks": checks}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = {
        "reference": measure(args.reference),
        "candidate": measure(args.candidate),
    }
    result["comparison"] = compare(result["reference"], result["candidate"])
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    print(payload)
    return 0 if bool(result["comparison"]["pass"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
