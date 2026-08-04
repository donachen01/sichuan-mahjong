"""Reject bronze/yellow pixels on the outer edge of the 3D center panel."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


EXPECTED_SIZE = (2048, 1152)
PANEL_ROI = (860, 400, 1181, 551)
COUNTER_CENTER = (1024, 478)
COUNTER_EXCLUSION_RADII = (82.0, 64.0)


def is_inside_counter_exclusion(x: int, y: int) -> bool:
    radius_x, radius_y = COUNTER_EXCLUSION_RADII
    delta_x = (x - COUNTER_CENTER[0]) / radius_x
    delta_y = (y - COUNTER_CENTER[1]) / radius_y
    return delta_x * delta_x + delta_y * delta_y <= 1.0


def is_bronze_yellow(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return (
        red >= 120
        and 80 <= green <= 180
        and blue <= 110
        and red >= green + 20
        and green >= blue + 18
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", nargs=4, type=Path, metavar="SEAT_CAPTURE")
    arguments = parser.parse_args()

    failures: list[str] = []
    left, top, right, bottom = PANEL_ROI
    for seat, path in enumerate(arguments.captures):
        image = Image.open(path).convert("RGB")
        if image.size != EXPECTED_SIZE:
            failures.append(f"seat {seat}: expected {EXPECTED_SIZE}, found {image.size}")
            continue

        yellow_pixels: list[tuple[int, int, tuple[int, int, int]]] = []
        for y in range(top, bottom):
            for x in range(left, right):
                if is_inside_counter_exclusion(x, y):
                    continue
                pixel = image.getpixel((x, y))
                if is_bronze_yellow(pixel):
                    yellow_pixels.append((x, y, pixel))

        print(f"seat={seat} outer_bronze_yellow_pixels={len(yellow_pixels)}")
        if yellow_pixels:
            failures.append(
                f"seat {seat}: found {len(yellow_pixels)} outer bronze/yellow pixels; "
                f"examples={yellow_pixels[:5]}"
            )

    if failures:
        print("CENTER_OUTER_EDGES_FAILED")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("CENTER_OUTER_EDGES_PASS outer_bronze_yellow_pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
