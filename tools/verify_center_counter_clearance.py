"""Verify that no active red sector enters the projected counter bezel."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


EXPECTED_SIZE = (2048, 1152)
COUNTER_PROBE_POINTS_BY_SEAT = {
    0: [(975, 495), (1075, 495)],
    1: [(976, 465), (974, 475), (977, 485)],
    2: [(1000, 445), (1047, 445), (975, 450), (1075, 450)],
    3: [(1070, 465), (1072, 475), (1073, 485)],
}


def is_active_wine_red(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return red >= 120 and red >= green + 55 and red >= blue + 70


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", nargs=4, type=Path, metavar="SEAT_CAPTURE")
    arguments = parser.parse_args()

    failures: list[str] = []
    for seat, path in enumerate(arguments.captures):
        image = Image.open(path).convert("RGB")
        if image.size != EXPECTED_SIZE:
            failures.append(f"seat {seat}: expected {EXPECTED_SIZE}, found {image.size}")
            continue
        samples = [
            (point, image.getpixel(point))
            for point in COUNTER_PROBE_POINTS_BY_SEAT[seat]
        ]
        intrusions = [sample for sample in samples if is_active_wine_red(sample[1])]
        print(f"seat={seat} counter_red_intrusions={len(intrusions)} samples={samples}")
        if intrusions:
            failures.append(f"seat {seat}: active red entered counter bezel at {intrusions}")

    if failures:
        print("CENTER_COUNTER_CLEARANCE_FAILED")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("CENTER_COUNTER_CLEARANCE_PASS counter_red_intrusions=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
