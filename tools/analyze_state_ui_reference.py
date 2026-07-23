#!/usr/bin/env python3
"""Measure the three ding-que decision seals in a real rendered capture."""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def _largest_component(mask: np.ndarray) -> tuple[int, int, int, int, int]:
    height, width = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    best = (0, 0, 0, 0, 0)
    for y, x in zip(*np.nonzero(mask)):
        if visited[y, x]:
            continue
        queue: deque[tuple[int, int]] = deque([(int(y), int(x))])
        visited[y, x] = True
        count = 0
        min_x = max_x = int(x)
        min_y = max_y = int(y)
        while queue:
            current_y, current_x = queue.popleft()
            count += 1
            min_x = min(min_x, current_x)
            max_x = max(max_x, current_x)
            min_y = min(min_y, current_y)
            max_y = max(max_y, current_y)
            for next_y, next_x in (
                (current_y - 1, current_x),
                (current_y + 1, current_x),
                (current_y, current_x - 1),
                (current_y, current_x + 1),
            ):
                if 0 <= next_y < height and 0 <= next_x < width and mask[next_y, next_x] and not visited[next_y, next_x]:
                    visited[next_y, next_x] = True
                    queue.append((next_y, next_x))
        if count > best[4]:
            best = (min_x, min_y, max_x + 1, max_y + 1, count)
    return best


def _relative_luminance(rgb: np.ndarray) -> float:
    values = rgb / 255.0
    values = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    return float(0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2])


def _contrast(first: np.ndarray, second: np.ndarray) -> float:
    first_luminance = _relative_luminance(first)
    second_luminance = _relative_luminance(second)
    lighter = max(first_luminance, second_luminance)
    darker = min(first_luminance, second_luminance)
    return (lighter + 0.05) / (darker + 0.05)


def analyze(path: Path) -> dict[str, object]:
    image = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    height, width, _ = image.shape
    x0, x1 = round(width * 0.30), round(width * 0.70)
    y0, y1 = round(height * 0.35), round(height * 0.70)
    crop = image[y0:y1, x0:x1]
    red, green, blue = crop[..., 0], crop[..., 1], crop[..., 2]
    masks = {
        "tiao": (green > 95) & (green > red * 1.30) & (green > blue * 1.05),
        "tong": (red > 170) & (green > 115) & (blue < 145) & (red > green * 1.05),
        "wan": (red > 150) & (red > green * 1.35) & (red > blue * 1.18),
    }
    components: dict[str, dict[str, object]] = {}
    centers: list[float] = []
    diameter_ratios: list[float] = []
    for name, mask in masks.items():
        left, top, right, bottom, count = _largest_component(mask)
        if count == 0:
            raise RuntimeError(f"no decision-seal pixels matched {name}")
        absolute_box = [left + x0, top + y0, right + x0, bottom + y0]
        component_width = right - left
        component_height = bottom - top
        diameter = min(component_width, component_height)
        center_x = x0 + (left + right) / 2.0
        centers.append(center_x)
        diameter_ratios.append(diameter / height)
        components[name] = {
            "bbox": absolute_box,
            "pixel_count": count,
            "diameter_px": diameter,
            "diameter_short_edge_ratio": round(diameter / height, 6),
            "center_x": round(center_x, 3),
        }
    spacing = [centers[1] - centers[0], centers[2] - centers[1]]
    spacing_error = abs(spacing[0] - spacing[1])
    # The text is white with an explicit near-black outline. Sampling those two
    # style endpoints avoids pretending that white-on-bright-fill alone is the
    # accessibility mechanism.
    outline_contrast = _contrast(np.array([245.0, 255.0, 250.0]), np.array([5.0, 15.0, 13.0]))
    checks = {
        "three_components_found": len(components) == 3,
        "visible_diameter_ratio_gte_13pct": min(diameter_ratios) >= 0.13,
        "equal_spacing_error_lte_4px": spacing_error <= 4.0,
        "ordered_tiao_tong_wan": centers[0] < centers[1] < centers[2],
        "text_outline_contrast_gte_4_5": outline_contrast >= 4.5,
    }
    return {
        "candidate": str(path),
        "size": [width, height],
        "components": components,
        "center_spacing_px": [round(value, 3) for value in spacing],
        "spacing_error_px": round(spacing_error, 3),
        "text_outline_contrast": round(outline_contrast, 4),
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
