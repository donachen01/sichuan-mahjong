#!/usr/bin/env python3
"""Measure camera-composition anchors against the supplied target screenshot.

This intentionally measures only large, stable camera/layout silhouettes:
the blue table trapezoid, the green concealed hands, and the bright self hand.
It does not score colors, materials, avatars, text, or action-button artwork.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def _components(mask: np.ndarray, minimum_area: int) -> list[dict[str, float]]:
    labels, _ = ndimage.label(mask)
    result: list[dict[str, float]] = []
    for label_id, slices in enumerate(ndimage.find_objects(labels), start=1):
        if slices is None:
            continue
        area = int(np.count_nonzero(labels[slices] == label_id))
        if area < minimum_area:
            continue
        y_slice, x_slice = slices
        result.append(
            {
                "area": float(area),
                "x0": float(x_slice.start),
                "y0": float(y_slice.start),
                "x1": float(x_slice.stop),
                "y1": float(y_slice.stop),
            }
        )
    return result


def _normalized_bounds(component: dict[str, float], width: int, height: int) -> list[float]:
    return [
        component["x0"] / width,
        component["y0"] / height,
        (component["x1"] - component["x0"]) / width,
        (component["y1"] - component["y0"]) / height,
    ]


def _union(components: list[dict[str, float]]) -> dict[str, float]:
    return {
        "x0": min(item["x0"] for item in components),
        "y0": min(item["y0"] for item in components),
        "x1": max(item["x1"] for item in components),
        "y1": max(item["y1"] for item in components),
        "area": sum(item["area"] for item in components),
    }


def _surface_width(blue_mask: np.ndarray, y_ratio: float) -> float:
    height, width = blue_mask.shape
    y = min(height - 1, max(0, int(round((height - 1) * y_ratio))))
    window = max(31, int(round(width * 0.047)))
    density = ndimage.uniform_filter1d(
        blue_mask[y].astype(np.float32), size=window, mode="constant"
    )
    indices = np.flatnonzero(density > 0.60)
    if indices.size == 0:
        return 0.0
    return float(indices[-1] - indices[0]) / width


def measure(path: Path) -> dict[str, object]:
    image = np.asarray(Image.open(path).convert("RGB"))
    height, width = image.shape[:2]
    red, green, blue = [image[:, :, index].astype(np.float32) for index in range(3)]

    green_mask = (
        (green > 70)
        & (green > red * 1.18)
        & (green > blue * 0.78)
        & ((green - red) > 20)
        & ((green - blue) > -10)
    )
    green_components = _components(green_mask, minimum_area=max(300, width * height // 12000))
    far_candidates = [
        item
        for item in green_components
        if item["y1"] / height < 0.28
        and (item["x1"] - item["x0"]) / width > 0.20
        and (item["x1"] - item["x0"]) > (item["y1"] - item["y0"]) * 3.0
    ]
    if far_candidates:
        far = max(far_candidates, key=lambda item: item["area"])
    else:
        far_tiles = [
            item
            for item in green_components
            if item["y1"] / height < 0.28
            and 0.012 < (item["x1"] - item["x0"]) / width < 0.09
            and 0.035 < (item["y1"] - item["y0"]) / height < 0.13
        ]
        if len(far_tiles) < 10:
            raise RuntimeError(f"could not locate far concealed hand in {path}")
        far = _union(far_tiles)

    # Crop away the bottom self hand before labeling each side. In close
    # perspective screenshots its green rack can touch a side-hand silhouette
    # by a single antialiased pixel and would otherwise merge both components.
    side_y1 = int(round(height * 0.86))
    left_x1 = int(round(width * 0.32))
    right_x0 = int(round(width * 0.68))
    left_candidates = _components(green_mask[:side_y1, :left_x1], minimum_area=300)
    right_candidates = _components(green_mask[:side_y1, right_x0:], minimum_area=300)
    for item in right_candidates:
        item["x0"] += right_x0
        item["x1"] += right_x0
    left_candidates = [
        item for item in left_candidates if (item["y1"] - item["y0"]) / height > 0.34
    ]
    right_candidates = [
        item for item in right_candidates if (item["y1"] - item["y0"]) / height > 0.34
    ]
    if not left_candidates or not right_candidates:
        raise RuntimeError(f"could not locate both side concealed hands in {path}")
    left = max(left_candidates, key=lambda item: item["area"])
    right = max(right_candidates, key=lambda item: item["area"])

    neutral_span = np.maximum.reduce([red, green, blue]) - np.minimum.reduce([red, green, blue])
    self_face_mask = (red > 145) & (green > 145) & (blue > 145) & (neutral_span < 65)
    self_components = _components(self_face_mask, minimum_area=max(180, width * height // 18000))
    self_tiles = [
        item
        for item in self_components
        if item["y0"] / height > 0.76
        and 0.025 < (item["x1"] - item["x0"]) / width < 0.09
        and (item["y1"] - item["y0"]) / height > 0.10
    ]
    if len(self_tiles) < 10:
        raise RuntimeError(f"located only {len(self_tiles)} self-hand faces in {path}")
    self_hand = _union(self_tiles)
    median_self_face_height = float(
        np.median([item["y1"] - item["y0"] for item in self_tiles]) / height
    )

    table_blue_mask = (
        (blue > 105)
        & (blue > green * 1.10)
        & (green > red * 1.07)
        & (red > 45)
        & (green > 65)
    )
    upper_width = _surface_width(table_blue_mask, 0.01)
    # 75% avoids the self-hand rack while still sampling the near half of the
    # trapezoid on both the target and generated frame.
    lower_width = _surface_width(table_blue_mask, 0.75)

    return {
        "path": str(path),
        "size": [width, height],
        "aspect_ratio": width / height,
        "self_bounds": _normalized_bounds(self_hand, width, height),
        "self_face_height": median_self_face_height,
        "self_bottom_gap": (height - self_hand["y1"]) / height,
        "far_bounds": _normalized_bounds(far, width, height),
        "far_self_height_ratio": ((far["y1"] - far["y0"]) / height) / median_self_face_height,
        "left_bounds": _normalized_bounds(left, width, height),
        "right_bounds": _normalized_bounds(right, width, height),
        "table_upper_width": upper_width,
        "table_lower_width": lower_width,
        "table_convergence": upper_width / lower_width if lower_width > 0 else 0.0,
    }


CAMERA_TOLERANCES = {
    "self_width": 0.035,
    "self_top": 0.035,
    "self_face_height": 0.025,
    "self_bottom_gap": 0.018,
    "far_width": 0.035,
    "far_top": 0.045,
    "far_height": 0.018,
    "far_self_height_ratio": 0.10,
    "side_inner_edge": 0.045,
    "side_width": 0.04,
    "side_top": 0.055,
    "side_bottom": 0.065,
    "table_upper_width": 0.06,
    "table_lower_width": 0.06,
    "table_convergence": 0.08,
}


# The camera gate intentionally allowed some placement slack while the lens and
# table trapezoid were being solved.  Once the camera is frozen, the layout gate
# uses materially tighter limits so the accepted P2 observations (side hands
# being too thin/low and a loose centre) cannot pass unchanged.
LAYOUT_TOLERANCES = {
    "self_width": 0.020,
    "self_top": 0.020,
    "self_face_height": 0.015,
    "self_bottom_gap": 0.012,
    "far_width": 0.020,
    "far_top": 0.020,
    "far_height": 0.012,
    "far_self_height_ratio": 0.060,
    "side_inner_edge": 0.020,
    "side_width": 0.006,
    "side_top": 0.015,
    "side_bottom": 0.020,
    "table_upper_width": 0.020,
    "table_lower_width": 0.025,
    "table_convergence": 0.035,
}


def compare(
    reference: dict[str, object],
    candidate: dict[str, object],
    tolerances: dict[str, float] = CAMERA_TOLERANCES,
) -> dict[str, object]:
    ref_self = reference["self_bounds"]
    got_self = candidate["self_bounds"]
    ref_far = reference["far_bounds"]
    got_far = candidate["far_bounds"]
    ref_left = reference["left_bounds"]
    got_left = candidate["left_bounds"]
    ref_right = reference["right_bounds"]
    got_right = candidate["right_bounds"]
    values = {
        "self_width": (ref_self[2], got_self[2]),
        "self_top": (ref_self[1], got_self[1]),
        "self_face_height": (reference["self_face_height"], candidate["self_face_height"]),
        "self_bottom_gap": (reference["self_bottom_gap"], candidate["self_bottom_gap"]),
        "far_width": (ref_far[2], got_far[2]),
        "far_top": (ref_far[1], got_far[1]),
        "far_height": (ref_far[3], got_far[3]),
        "far_self_height_ratio": (
            reference["far_self_height_ratio"],
            candidate["far_self_height_ratio"],
        ),
        "side_inner_edge": ((ref_left[0] + ref_left[2] + ref_right[0]) * 0.5, (got_left[0] + got_left[2] + got_right[0]) * 0.5),
        "side_width": ((ref_left[2] + ref_right[2]) * 0.5, (got_left[2] + got_right[2]) * 0.5),
        "side_top": ((ref_left[1] + ref_right[1]) * 0.5, (got_left[1] + got_right[1]) * 0.5),
        "side_bottom": (
            (ref_left[1] + ref_left[3] + ref_right[1] + ref_right[3]) * 0.5,
            (got_left[1] + got_left[3] + got_right[1] + got_right[3]) * 0.5,
        ),
        "table_upper_width": (reference["table_upper_width"], candidate["table_upper_width"]),
        "table_lower_width": (reference["table_lower_width"], candidate["table_lower_width"]),
        "table_convergence": (reference["table_convergence"], candidate["table_convergence"]),
    }
    checks = {}
    for key, (expected, actual) in values.items():
        delta = float(actual) - float(expected)
        checks[key] = {
            "target": round(float(expected), 4),
            "actual": round(float(actual), 4),
            "delta": round(delta, 4),
            "tolerance": tolerances[key],
            "pass": abs(delta) <= tolerances[key],
        }
    failures = [key for key, value in checks.items() if not value["pass"]]
    return {"pass": not failures, "failures": failures, "checks": checks}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    parser.add_argument("candidate", type=Path, nargs="?")
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--profile",
        choices=("camera", "layout"),
        default="camera",
        help="camera keeps the lens gate tolerances; layout tightens tile placement",
    )
    args = parser.parse_args()

    reference = measure(args.reference)
    result: dict[str, object] = {"reference": reference}
    exit_code = 0
    if args.candidate is not None:
        candidate = measure(args.candidate)
        tolerances = LAYOUT_TOLERANCES if args.profile == "layout" else CAMERA_TOLERANCES
        comparison = compare(reference, candidate, tolerances)
        result.update({"profile": args.profile, "candidate": candidate, "comparison": comparison})
        exit_code = 0 if comparison["pass"] else 1
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    print(payload)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
