#!/usr/bin/env python3
"""Build a richer local preview sheet for the warm jade tile redesign."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BODY_LARGE_PATH = ROOT / "res/art/ui_3d_cartoon/tile_face_large.png"
BODY_TABLE_PATH = ROOT / "res/art/ui_3d_cartoon/tile_face_table.png"
BACK_PATH = ROOT / "res/art/ui_3d_cartoon/tile_back_table.png"
SYMBOL_DIR = ROOT / "res/art/ui_3d_cartoon/tile_symbols"
OUT_PATH = ROOT / "docs/ui_baseline/mockups/tile_redesign_preview.png"

HERO_TILES = [
    ("Tiao 1", "tiao_1.png"),
    ("Tiao 5", "tiao_5.png"),
    ("Tong 1", "tong_1.png"),
    ("Tong 9", "tong_9.png"),
    ("Wan 1", "wan_1.png"),
    ("Wan 9", "wan_9.png"),
]

HAND_ROW = [
    "tiao_1.png",
    "tiao_2.png",
    "tiao_3.png",
    "tiao_5.png",
    "tiao_7.png",
    "tong_1.png",
    "tong_3.png",
    "tong_6.png",
    "tong_9.png",
    "wan_1.png",
    "wan_5.png",
    "wan_9.png",
    "tong_8.png",
]

MELD_ROW = [
    "tong_4.png",
    "tong_4.png",
    "tong_4.png",
    "tiao_7.png",
    "tiao_7.png",
    "tiao_7.png",
    "tiao_7.png",
    "wan_9.png",
]


def compose_tile(body: Image.Image, symbol: Image.Image, scale_ratio: float = 0.66, y_bias: int = 2) -> Image.Image:
    tile = body.copy()
    symbol = symbol.copy()
    scale = min((body.width * scale_ratio) / symbol.width, (body.height * 0.70) / symbol.height)
    symbol = symbol.resize(
        (max(1, int(symbol.width * scale)), max(1, int(symbol.height * scale))),
        Image.Resampling.LANCZOS,
    )
    x = (tile.width - symbol.width) // 2 - 1
    y = (tile.height - symbol.height) // 2 + y_bias
    tile.alpha_composite(symbol, (x, y))
    return tile


def apply_outline(tile: Image.Image, color: tuple[int, int, int, int], border: int = 2, scale: float = 1.0) -> Image.Image:
    pad = max(4, border + 4)
    canvas = Image.new("RGBA", (tile.width + pad * 2, tile.height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (pad - 1, pad + tile.height - 3, pad + tile.width + 1, pad + tile.height + 3),
        radius=9,
        fill=(0, 0, 0, 22),
    )
    canvas.alpha_composite(shadow, (0, 0))
    target = tile
    if scale != 1.0:
        target = tile.resize(
            (max(1, int(tile.width * scale)), max(1, int(tile.height * scale))),
            Image.Resampling.LANCZOS,
        )
    x = (canvas.width - target.width) // 2
    y = (canvas.height - target.height) // 2 - 1
    canvas.alpha_composite(target, (x, y))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x - border, y - border, x + target.width + border - 1, y + target.height + border - 1),
        radius=12,
        outline=color,
        width=border,
    )
    return canvas


def shadow_panel(size: tuple[int, int], fill: tuple[int, int, int, int]) -> Image.Image:
    panel = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=12, fill=fill, outline=(36, 92, 70, 220), width=1)
    return panel


def draw_label(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, color: tuple[int, int, int, int]) -> None:
    draw.text((x, y), text, fill=color)


def main() -> None:
    body_large = Image.open(BODY_LARGE_PATH).convert("RGBA")
    body_table = Image.open(BODY_TABLE_PATH).convert("RGBA")
    back_tile = Image.open(BACK_PATH).convert("RGBA").resize(body_large.size, Image.Resampling.LANCZOS)

    sheet = Image.new("RGBA", (1760, 1360), (15, 55, 39, 255))
    draw = ImageDraw.Draw(sheet)
    title_color = (241, 232, 210, 255)
    sub_color = (199, 183, 142, 255)
    muted = (187, 202, 188, 255)

    draw_label(draw, 48, 28, "Bright Realistic Jade Tile Preview", title_color)
    draw_label(draw, 48, 60, "brighter green jade / stronger relief / printed symbols / discard readability", sub_color)

    hero_panel = shadow_panel((1664, 356), (23, 69, 50, 228))
    sheet.alpha_composite(hero_panel, (48, 98))
    draw_label(draw, 72, 118, "Hero tiles", title_color)

    hero_items = []
    for label, filename in HERO_TILES:
        symbol = Image.open(SYMBOL_DIR / filename).convert("RGBA")
        hero_items.append((label, compose_tile(body_large, symbol)))
    hero_items.append(("Back", back_tile))

    for index, (label, tile) in enumerate(hero_items):
        x = 84 + index * 226
        y = 154
        card_panel = shadow_panel((192, 250), (20, 63, 46, 220))
        sheet.alpha_composite(card_panel, (x, y))
        tile_x = x + (192 - tile.width) // 2
        tile_y = y + 18
        sheet.alpha_composite(tile, (tile_x, tile_y))
        draw_label(draw, x + 18, y + 214, label, muted)

    hand_panel = shadow_panel((1664, 254), (23, 69, 50, 228))
    sheet.alpha_composite(hand_panel, (48, 484))
    draw_label(draw, 72, 504, "Self hand row", title_color)
    draw_label(draw, 72, 532, "selected tile uses cinnabar 2px outline and 1.05x scale only", sub_color)

    hand_tiles = []
    for filename in HAND_ROW:
        symbol = Image.open(SYMBOL_DIR / filename).convert("RGBA")
        hand_tiles.append(compose_tile(body_large, symbol))

    x = 74
    y = 564
    for index, tile in enumerate(hand_tiles):
        if index == len(hand_tiles) - 1:
            selected = apply_outline(tile, (195, 29, 56, 225), border=2, scale=1.05)
            sheet.alpha_composite(selected, (x - 8, y - 6))
            x += selected.width - 12
        else:
            sheet.alpha_composite(tile, (x, y))
            x += 112

    discard_panel = shadow_panel((1664, 170), (23, 69, 50, 228))
    sheet.alpha_composite(discard_panel, (48, 758))
    draw_label(draw, 72, 778, "Discard readability strip", title_color)

    discard_x = 74
    discard_y = 826
    for filename in ["tong_1.png", "tong_6.png", "tong_9.png", "wan_1.png", "wan_9.png", "tiao_1.png", "tiao_9.png"]:
        symbol = Image.open(SYMBOL_DIR / filename).convert("RGBA")
        tile = compose_tile(body_table, symbol, scale_ratio=0.70, y_bias=1)
        sheet.alpha_composite(tile, (discard_x, discard_y))
        discard_x += tile.width + 16

    meld_panel = shadow_panel((1664, 330), (23, 69, 50, 228))
    sheet.alpha_composite(meld_panel, (48, 948))
    draw_label(draw, 72, 968, "Meld / settlement scale", title_color)
    draw_label(draw, 72, 996, "winning tile uses a softer crimson accent instead of selected-state styling", sub_color)

    meld_tiles = []
    for index, filename in enumerate(MELD_ROW):
        if filename == "back":
            tile = Image.open(BACK_PATH).convert("RGBA")
        else:
            symbol = Image.open(SYMBOL_DIR / filename).convert("RGBA")
            tile = compose_tile(body_table, symbol, scale_ratio=0.68, y_bias=1)
        if index == len(MELD_ROW) - 1:
            tile = apply_outline(tile, (198, 62, 82, 148), border=2, scale=1.0)
        meld_tiles.append(tile)

    meld_x = 74
    meld_y = 1046
    for index, tile in enumerate(meld_tiles):
        sheet.alpha_composite(tile, (meld_x, meld_y))
        meld_x += tile.width + 12
        if index == 2:
            meld_x += 22
        if index == 6:
            meld_x += 34

    back_small = Image.open(BACK_PATH).convert("RGBA")
    back_y = 1050
    for offset in range(3):
        sheet.alpha_composite(back_small, (1240 + offset * 38, back_y))

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_PATH)
    print(OUT_PATH)


if __name__ == "__main__":
    main()
