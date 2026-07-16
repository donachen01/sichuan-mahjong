#!/usr/bin/env python3
"""Validate the final Sichuan Mahjong UI screenshot matrix."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageStat


EXPECTED_SIZES = {
    "table_1365x768.png": (1365, 768),
    "table_2048x1152.png": (2048, 1152),
    "table_2400x1080.png": (2400, 1080),
    "table_2556x1179.png": (2556, 1179),
}


def _near_black(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[0] <= 8 and pixel[1] <= 8 and pixel[2] <= 8 and pixel[3] >= 240


def inspect_capture(path: Path, expected_size: tuple[int, int]) -> tuple[dict, list[str]]:
    failures: list[str] = []
    with Image.open(path) as source:
        image = source.convert("RGBA")
    width, height = image.size
    # Godot/Metal rounds odd viewport edges to the next even pixel.
    if abs(width - expected_size[0]) > 1 or abs(height - expected_size[1]) > 1:
        failures.append(f"尺寸错误: expected={expected_size}, actual={image.size}")

    pixels = list(image.getdata())
    total = max(1, len(pixels))
    black_ratio = sum(1 for pixel in pixels if _near_black(pixel)) / total
    transparent_ratio = sum(1 for pixel in pixels if pixel[3] < 16) / total
    if black_ratio > 0.025:
        failures.append(f"近纯黑像素比例过高: {black_ratio:.4%}")
    if transparent_ratio > 0.001:
        failures.append(f"透明空白比例过高: {transparent_ratio:.4%}")

    edge_width = max(3, int(width * 0.012))
    left = image.crop((0, 0, edge_width, height))
    right = image.crop((width - edge_width, 0, width, height))
    left_pixels = list(left.getdata())
    right_pixels = list(right.getdata())
    left_black_ratio = sum(1 for pixel in left_pixels if _near_black(pixel)) / max(1, len(left_pixels))
    right_black_ratio = sum(1 for pixel in right_pixels if _near_black(pixel)) / max(1, len(right_pixels))
    if left_black_ratio > 0.08:
        failures.append(f"左侧疑似黑柱: {left_black_ratio:.4%}")
    if right_black_ratio > 0.08:
        failures.append(f"右侧疑似黑柱: {right_black_ratio:.4%}")

    corner_radius = max(4, int(min(width, height) * 0.015))
    corner_boxes = {
        "左上": (0, 0, corner_radius, corner_radius),
        "右上": (width - corner_radius, 0, width, corner_radius),
        "左下": (0, height - corner_radius, corner_radius, height),
        "右下": (width - corner_radius, height - corner_radius, width, height),
    }
    corner_means: dict[str, tuple[float, float, float]] = {}
    for name, box in corner_boxes.items():
        rgb = image.crop(box).convert("RGB")
        mean = tuple(round(value, 2) for value in ImageStat.Stat(rgb).mean)
        corner_means[name] = mean
        if max(mean) <= 8.0:
            failures.append(f"{name}角未被牌桌覆盖: mean={mean}")

    alpha = image.getchannel("A")
    content_bbox = alpha.getbbox()
    if content_bbox is None:
        failures.append("截图为空")
        content_bbox = (0, 0, 0, 0)

    return {
        "file": path.name,
        "size": [width, height],
        "black_ratio": round(black_ratio, 6),
        "transparent_ratio": round(transparent_ratio, 6),
        "left_edge_black_ratio": round(left_black_ratio, 6),
        "right_edge_black_ratio": round(right_black_ratio, 6),
        "content_bbox": list(content_bbox),
        "corner_rgb_means": corner_means,
    }, failures


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_ui_capture.py <capture-directory>", file=sys.stderr)
        return 2
    capture_dir = Path(sys.argv[1]).expanduser().resolve()
    reports: list[dict] = []
    all_failures: list[str] = []
    for filename, expected_size in EXPECTED_SIZES.items():
        path = capture_dir / filename
        if not path.is_file():
            all_failures.append(f"缺少截图: {filename}")
            continue
        report, failures = inspect_capture(path, expected_size)
        reports.append(report)
        all_failures.extend(f"{filename}: {failure}" for failure in failures)

    report_path = capture_dir / "capture_check_report.json"
    report_path.write_text(
        json.dumps({"captures": reports, "failures": all_failures}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for report in reports:
        print(
            f"{report['file']}: black={report['black_ratio']:.4%}, "
            f"left={report['left_edge_black_ratio']:.4%}, "
            f"right={report['right_edge_black_ratio']:.4%}, "
            f"bbox={report['content_bbox']}"
        )
    if all_failures:
        for failure in all_failures:
            print(f"FAILED: {failure}", file=sys.stderr)
        return 1
    print(f"SICHUAN UI CAPTURE CHECK OK: {len(reports)}/{len(EXPECTED_SIZES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
