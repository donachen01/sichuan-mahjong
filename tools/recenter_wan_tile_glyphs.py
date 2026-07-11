#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
WAN_DIRS = [
    ROOT / "res/art/ui_3d_cartoon/tile_symbols",
    ROOT / "res/art/tiles",
]
BLACK = (24, 22, 20)
RED = (205, 18, 32)


def is_visible(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[3] > 20


def is_red(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 20 and r > 80 and r > g * 1.55 and r > b * 1.55


def is_black(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 20 and r < 95 and g < 95 and b < 95


def recolor_and_center(path: Path) -> tuple[float, float]:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    split_y = resolve_split_y(image)

    black_points: list[tuple[int, int]] = []
    red_points: list[tuple[int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if not is_visible((r, g, b, a)):
                continue
            if y <= split_y:
                black_points.append((x, y))
                pixels[x, y] = (*BLACK, a)
            else:
                red_points.append((x, y))
                pixels[x, y] = (*RED, a)

    if red_points:
        red_center = sum(x for x, _ in red_points) / len(red_points)
        target_center = (image.width - 1) * 0.5
        shift_x = max(-28, min(28, int(round(target_center - red_center))))
        if shift_x != 0:
            base = Image.new("RGBA", image.size, (0, 0, 0, 0))
            red_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
            base_pixels = base.load()
            red_pixels = red_layer.load()
            for y in range(image.height):
                for x in range(image.width):
                    pixel = pixels[x, y]
                    if is_red(pixel):
                        red_pixels[x, y] = pixel
                    else:
                        base_pixels[x, y] = pixel
            base.alpha_composite(red_layer, (shift_x, 0))
            image = base

    image.save(path)
    new_pixels = image.load()
    red_x: list[int] = []
    black_x: list[int] = []
    for y in range(image.height):
        for x in range(image.width):
            pixel = new_pixels[x, y]
            if is_red(pixel):
                red_x.append(x)
            elif is_black(pixel):
                black_x.append(x)
    red_center_after = sum(red_x) / len(red_x) if red_x else -1.0
    black_center_after = sum(black_x) / len(black_x) if black_x else -1.0
    return red_center_after, black_center_after


def resolve_split_y(image: Image.Image) -> int:
    visible_rows: list[int] = []
    for y in range(image.height):
        if any(image.getpixel((x, y))[3] > 20 for x in range(image.width)):
            visible_rows.append(y)
    if len(visible_rows) < 2:
        return image.height // 2
    groups: list[tuple[int, int]] = []
    start = visible_rows[0]
    previous = visible_rows[0]
    for row in visible_rows[1:]:
        if row == previous + 1:
            previous = row
            continue
        groups.append((start, previous))
        start = row
        previous = row
    groups.append((start, previous))
    if len(groups) >= 2:
        return groups[-1][0] - 1
    return int(round((visible_rows[0] + visible_rows[-1]) * 0.43))


def main() -> None:
    for directory in WAN_DIRS:
        for rank in range(1, 10):
            path = directory / f"wan_{rank}.png"
            red_center, black_center = recolor_and_center(path)
            print(f"{path}: red_center={red_center:.2f} black_center={black_center:.2f}")


if __name__ == "__main__":
    main()
