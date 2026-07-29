"""Measure Deep Emerald Stage-1 screenshots against the locked colour gate."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageStat


TARGET = (0x16, 0x7A, 0x64)
RESOLUTIONS = ("1365x768", "2048x1152", "2400x1080", "2556x1179")
SAMPLE_CENTRES = ((0.25, 0.68), (0.30, 0.68), (0.70, 0.68), (0.75, 0.68))


def distance(rgb: tuple[int, int, int]) -> float:
    return math.sqrt(sum((rgb[index] - TARGET[index]) ** 2 for index in range(3)))


def percentile(values: list[int], fraction: float) -> int:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(round((len(ordered) - 1) * fraction)))]


def inspect(path: Path) -> dict:
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    rgb = image.convert("RGB")
    samples = []
    pooled = [[], [], []]
    for centre_x, centre_y in SAMPLE_CENTRES:
        x = round(width * centre_x)
        y = round(height * centre_y)
        half = 24
        crop = rgb.crop((x - half, y - half, x + half, y + half))
        channels = [list(channel.getdata()) for channel in crop.split()]
        median = tuple(percentile(channel, 0.5) for channel in channels)
        stddev = tuple(round(value, 3) for value in ImageStat.Stat(crop).stddev)
        for index, channel in enumerate(channels):
            pooled[index].extend(channel)
        samples.append({
            "centre": [x, y],
            "median_rgb": list(median),
            "distance_to_table_center": round(distance(median), 3),
            "stddev_rgb": list(stddev),
        })
    pooled_median = tuple(percentile(channel, 0.5) for channel in pooled)
    alpha = list(image.getchannel("A").getdata())
    pixels = list(rgb.getdata())
    near_black = sum(1 for red, green, blue in pixels if red <= 3 and green <= 3 and blue <= 3)
    return {
        "path": str(path),
        "size": [width, height],
        "pooled_median_rgb": list(pooled_median),
        "pooled_distance_to_table_center": round(distance(pooled_median), 3),
        "transparent_pixel_ratio": round(sum(1 for value in alpha if value < 255) / len(alpha), 8),
        "near_black_pixel_ratio": round(near_black / len(pixels), 8),
        "samples": samples,
    }


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("evidence/ui_emerald_final_20260726/stage1")
    report = {
        "target_rgb": list(TARGET),
        "maximum_colour_distance": 18.0,
        "maximum_channel_stddev": 8.0,
        "minimum_nonzero_channel_stddev": 0.01,
        "screenshots": [],
        "pass": True,
    }
    for resolution in RESOLUTIONS:
        result = inspect(root / resolution / "table.png")
        report["screenshots"].append(result)
        if result["pooled_distance_to_table_center"] > 18.0:
            report["pass"] = False
        for sample in result["samples"]:
            maximum = max(sample["stddev_rgb"])
            if maximum > 8.0 or maximum < 0.01:
                report["pass"] = False
        if result["transparent_pixel_ratio"] != 0.0:
            report["pass"] = False
    output = root / "stage1_pixel_metrics.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": report["pass"],
        "distances": [item["pooled_distance_to_table_center"] for item in report["screenshots"]],
        "report": str(output),
    }, ensure_ascii=False))
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
