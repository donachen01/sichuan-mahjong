"""Verify the final Metal pixels of the four center active-direction fields."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


TARGET_RGB = (161, 61, 45)
EXPECTED_SIZE = (2048, 1152)
SAMPLE_POINTS_BY_SEAT = {
    # East/West include the two separator-adjacent wedges beside the bezel;
    # these were the exact dark gaps reported in the acceptance screenshot.
    0: [(900, 532), (930, 532), (1120, 532), (975, 495), (1075, 495)],
    1: [(891, 470), (891, 490), (891, 510)],
    2: [(930, 424), (1115, 424), (975, 450), (1075, 450)],
    3: [(1154, 470), (1154, 490), (1154, 510)],
}


def channel_delta(pixel: tuple[int, int, int]) -> int:
    return max(abs(value - target) for value, target in zip(pixel, TARGET_RGB))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", nargs=4, type=Path, metavar="SEAT_CAPTURE")
    parser.add_argument("--tolerance", type=int, default=0)
    arguments = parser.parse_args()

    failures: list[str] = []
    for seat, path in enumerate(arguments.captures):
        image = Image.open(path).convert("RGB")
        if image.size != EXPECTED_SIZE:
            failures.append(f"seat {seat}: expected {EXPECTED_SIZE}, found {image.size}")
            continue
        pixels = [image.getpixel(point) for point in SAMPLE_POINTS_BY_SEAT[seat]]
        maximum_delta = max(channel_delta(pixel) for pixel in pixels)
        print(f"seat={seat} pixels={pixels} max_channel_delta={maximum_delta}")
        if maximum_delta > arguments.tolerance:
            failures.append(
                f"seat {seat}: target={TARGET_RGB}, pixels={pixels}, "
                f"max_channel_delta={maximum_delta}"
            )

    if failures:
        print("CENTER_ACTIVE_COLOR_FAILED")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"CENTER_ACTIVE_COLOR_PASS target=#A13D2D tolerance={arguments.tolerance}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
