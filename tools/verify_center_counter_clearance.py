"""Verify that no active red sector enters the projected counter bezel."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


EXPECTED_SIZE = (2048, 1152)
COUNTER_PROBE_POINTS_BY_SEAT = {
    # The East/West sectors are wider than 90 degrees. Their separator-aligned
    # wedges legitimately occupy the projected corners outside the circular
    # bezel, so probe the real counter interior instead of those former missing
    # wedges. The imported-mesh runner separately enforces cutout >= bezel radius.
    0: [(990, 486), (1000, 486), (1048, 486), (1058, 486)],
    1: [(976, 465), (974, 475), (977, 485)],
    2: [(990, 470), (1000, 460), (1048, 460), (1058, 470)],
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
