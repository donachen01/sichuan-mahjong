#!/usr/bin/env python3
"""Generate high-contrast commercial Mahjong symbols for 2D and 3D tables.

This version restores traditional Mahjong color language so the face symbols
stay readable and recognizable on a bright green-jade tile body.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "res/art/tiles"
OUT_DIR = ROOT / "res/art/ui_3d_cartoon/tile_symbols"
CONTACT_SHEET = ROOT / "docs/ui_baseline/mockups/tile_symbols_matte_contact_sheet.png"
SYMBOL_SIZE = (196, 288)
SUITS = ("tiao", "tong", "wan")
SUIT_STYLES = {
    "tiao": {
        "ink": (3, 59, 6),
        "red": (120, 16, 15),
        "shadow": (16, 28, 20, 18),
        "paper_glow": (252, 255, 250, 8),
        "contrast": 1.10,
        "color": 0.98,
        "resize": (0.84, 0.87),
        "offset": (-2, 0),
        "alpha_gain": 1.04,
        "thin_px": 0,
    },
    "tong": {
        "ink": (36, 55, 58),
        "red": (120, 16, 15),
        "blue": (3, 59, 6),
        "shadow": (16, 24, 20, 16),
        "paper_glow": (252, 255, 250, 6),
        "contrast": 1.10,
        "color": 1.00,
        "resize": (0.83, 0.87),
        "offset": (-2, -1),
        "alpha_gain": 1.04,
        "thin_px": 0,
    },
    "wan": {
        "ink": (22, 22, 22),
        "red": (120, 16, 15),
        "shadow": (16, 16, 16, 14),
        "paper_glow": (252, 255, 250, 4),
        "contrast": 1.10,
        "color": 0.92,
        "resize": (0.83, 0.87),
        "offset": (0, 1),
        "alpha_gain": 1.02,
        "thin_px": 0,
    },
}

RANK_LAYOUT_OVERRIDES = {
    "tong_1": {"resize": (0.80, 0.82), "offset": (-1, 0), "alpha_gain": 1.02, "thin_px": 0},
    "tong_6": {"resize": (0.81, 0.84), "offset": (-2, -1)},
    "tong_7": {"resize": (0.81, 0.84), "offset": (-2, -1)},
    "tong_8": {"resize": (0.80, 0.83), "offset": (-2, -1)},
    "tong_9": {"resize": (0.80, 0.83), "offset": (-2, -1)},
    "wan_1": {"resize": (0.81, 0.84), "offset": (0, 1)},
    "wan_2": {"resize": (0.82, 0.85), "offset": (0, 1)},
    "wan_3": {"resize": (0.82, 0.85), "offset": (0, 1)},
    "wan_8": {"resize": (0.81, 0.84), "offset": (0, 1)},
    "wan_9": {"resize": (0.81, 0.84), "offset": (0, 1)},
}


def _alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    return alpha.getbbox()


def _trim(image: Image.Image, padding: int = 6) -> Image.Image:
    bbox = _alpha_bbox(image)
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def _fit_symbol(image: Image.Image, scale_xy: tuple[float, float]) -> Image.Image:
    trimmed = _trim(image)
    target_w = max(1, int(SYMBOL_SIZE[0] * scale_xy[0]))
    target_h = max(1, int(SYMBOL_SIZE[1] * scale_xy[1]))
    ratio = min(target_w / max(1, trimmed.width), target_h / max(1, trimmed.height))
    size = (max(1, int(trimmed.width * ratio)), max(1, int(trimmed.height * ratio)))
    return trimmed.resize(size, Image.Resampling.LANCZOS)


def _soft_alpha(alpha: Image.Image) -> Image.Image:
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.25))
    return alpha.point(lambda value: min(255, int(value * 0.98)))


def _style_for(suit: str, rank: int) -> dict:
    style = dict(SUIT_STYLES[suit])
    style.update(RANK_LAYOUT_OVERRIDES.get(f"{suit}_{rank}", {}))
    return style


def _taper_alpha(alpha: Image.Image, thin_px: int, alpha_gain: float) -> Image.Image:
    softened = _soft_alpha(alpha)
    if thin_px > 0:
        kernel = thin_px * 2 + 1
        thinned = softened.filter(ImageFilter.MinFilter(kernel))
        softened = Image.blend(softened, thinned, 0.32)
    feather = softened.filter(ImageFilter.GaussianBlur(0.45))
    mixed = ImageChops.lighter(softened, feather.point(lambda value: int(value * 0.18)))
    return mixed.point(lambda value: min(255, int(value * alpha_gain)))


def _neutralize_symbol(source: Image.Image, suit: str, rank: int) -> Image.Image:
    style = _style_for(suit, rank)
    source = source.convert("RGBA").resize(SYMBOL_SIZE, Image.Resampling.LANCZOS)
    source = ImageEnhance.Color(source).enhance(style["color"])
    source = ImageEnhance.Contrast(source).enhance(style["contrast"])

    alpha = _taper_alpha(source.getchannel("A"), int(style.get("thin_px", 1)), float(style.get("alpha_gain", 0.9)))
    neutral = Image.new("RGBA", source.size, (0, 0, 0, 0))
    pixels = source.load()
    out = neutral.load()

    for y in range(source.height):
        for x in range(source.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if suit == "tong":
                if rank == 1 and r > 140 and g < 125:
                    color = style["red"]
                elif r > 145 and g < 110:
                    color = style["red"]
                elif b > 135:
                    color = style["blue"]
                else:
                    color = style["ink"]
            elif suit == "tiao":
                if r > 145 and g < 120:
                    color = style["red"]
                else:
                    color = style["ink"]
            else:
                if r > 95 and r > g * 1.55 and r > b * 1.55 and y > source.height * 0.34:
                    color = style["red"]
                else:
                    color = style["ink"]
            out[x, y] = (*color, alpha.getpixel((x, y)))
    return neutral


def _recenter_wan_red_glyph(image: Image.Image) -> Image.Image:
    split_y = _resolve_wan_split_y(image)
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a <= 20:
                continue
            if y <= split_y:
                pixels[x, y] = (*SUIT_STYLES["wan"]["ink"], a)
            else:
                pixels[x, y] = (*SUIT_STYLES["wan"]["red"], a)

    red_pixels: list[tuple[int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a > 20 and r > 95 and r > g * 1.55 and r > b * 1.55:
                red_pixels.append((x, y))
    if not red_pixels:
        return image

    red_center = sum(x for x, _ in red_pixels) / len(red_pixels)
    target_center = (image.width - 1) * 0.5
    shift_x = max(-24, min(24, int(round(target_center - red_center))))
    if shift_x == 0:
        return image

    base = Image.new("RGBA", image.size, (0, 0, 0, 0))
    red_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    base_pixels = base.load()
    red_pixels_out = red_layer.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a > 20 and r > 95 and r > g * 1.55 and r > b * 1.55:
                red_pixels_out[x, y] = (r, g, b, a)
            else:
                base_pixels[x, y] = (r, g, b, a)
    base.alpha_composite(red_layer, (shift_x, 0))
    return base


def _resolve_wan_split_y(image: Image.Image) -> int:
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


def _compose_symbol(symbol: Image.Image, suit: str, rank: int) -> Image.Image:
    style = _style_for(suit, rank)
    fitted = _fit_symbol(symbol, style["resize"])
    canvas = Image.new("RGBA", SYMBOL_SIZE, (0, 0, 0, 0))
    shadow = Image.new("RGBA", fitted.size, style["shadow"])
    shadow.putalpha(fitted.getchannel("A").filter(ImageFilter.GaussianBlur(0.45)).point(lambda value: int(value * 0.14)))

    glow = Image.new("RGBA", fitted.size, style["paper_glow"])
    glow.putalpha(fitted.getchannel("A").filter(ImageFilter.GaussianBlur(0.65)).point(lambda value: int(value * 0.10)))

    x = (SYMBOL_SIZE[0] - fitted.width) // 2 + style["offset"][0]
    y = (SYMBOL_SIZE[1] - fitted.height) // 2 + style["offset"][1]

    canvas.alpha_composite(shadow, (x + 1, y + 2))
    canvas.alpha_composite(glow, (x, y - 1))
    # At the 60-80 px mobile tile size, the old single-pass antialiasing left
    # most strokes with only a translucent edge and blended red into pink. A
    # two-source-pixel print spread creates roughly one extra physical screen
    # pixel while preserving the original glyph silhouette.
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        canvas.alpha_composite(fitted, (x + dx, y + dy))
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def build_contact_sheet() -> None:
    cell_w, cell_h = 118, 174
    sheet = Image.new("RGBA", (cell_w * 9, cell_h * 3), (18, 60, 41, 255))
    for row, suit in enumerate(SUITS):
        for rank in range(1, 10):
            image = Image.open(OUT_DIR / f"{suit}_{rank}.png").convert("RGBA")
            image = image.resize((94, 138), Image.Resampling.LANCZOS)
            x = (rank - 1) * cell_w + (cell_w - image.width) // 2
            y = row * cell_h + (cell_h - image.height) // 2
            sheet.alpha_composite(image, (x, y))
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_SHEET)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for suit in SUITS:
        for rank in range(1, 10):
            source_path = SOURCE_DIR / f"{suit}_{rank}.png"
            source = Image.open(source_path).convert("RGBA")
            neutral = _neutralize_symbol(source, suit, rank)
            composed = _compose_symbol(neutral, suit, rank)
            if suit == "wan":
                composed = _recenter_wan_red_glyph(composed)
            composed.save(OUT_DIR / f"{suit}_{rank}.png")
    build_contact_sheet()
    print(f"generated {OUT_DIR}")
    print(f"contact_sheet {CONTACT_SHEET}")


if __name__ == "__main__":
    main()
