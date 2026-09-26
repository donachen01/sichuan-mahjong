#!/usr/bin/env python3
"""Replace the five-wan glyph with 伍 in every tile-face fallback.

The lower 万 and the existing tile material remain from the project's art.
Run after any bulk tile-symbol regeneration, which otherwise restores 五.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
WU_REFERENCE = ROOT / "source_assets/tiles/whole_wu_reference_new.png"
PNG_FACES = (
    ROOT / "res/art/tiles/wan_5.png",
    ROOT / "res/art/ui_3d_cartoon/tile_symbols/wan_5.png",
)
PNG_ORIGINALS = (
    ROOT / "source_assets/tiles/wan_5_overlay_original.png",
    ROOT / "source_assets/tiles/wan_5_symbol_original.png",
)
JPEG_FACE = ROOT / "res/art/tiles/wan_5.jpg"
JPEG_ORIGINAL = ROOT / "source_assets/tiles/wan_5_photo_original.jpg"


def wu_glyph(height: int, ink: tuple[int, int, int]) -> Image.Image:
    # The current source is cropped directly from the user's five-rank sample.
    # Its slanted strokes and aspect ratio stay intact at each tile resolution.
    source = Image.open(WU_REFERENCE).convert("RGBA")
    cropped = source.crop(source.getchannel("A").getbbox())
    width = round(cropped.width * height / cropped.height)
    scaled = cropped.resize((width, height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", scaled.size, (*ink, 0))
    # The sample's near-black pixels carry alpha around 245. The other ranks
    # print with opaque ink, so make the stroke core opaque while retaining
    # antialiasing only at the edges.
    result.putalpha(scaled.getchannel("A").point(lambda value: min(255, round(value * 255 / 220))))
    return result


def replace_png(path: Path, original: Path, ink: tuple[int, int, int], center_x: int) -> None:
    image = Image.open(original).convert("RGBA")
    # The first glyph ends above y=112; 万 starts at y>=120.
    ImageDraw.Draw(image).rectangle((0, 0, image.width, 115), fill=(0, 0, 0, 0))
    symbol = wu_glyph(102, ink)
    image.alpha_composite(symbol, (center_x - symbol.width // 2, 9))
    image.save(path)


def replace_jpeg() -> None:
    image = Image.open(JPEG_ORIGINAL).convert("RGB")
    pixels = image.load()
    # Rebuild only the upper ivory field; retain the photographed tile edge
    # and the red 万 below it. Clean side strips supply the original lighting.
    for y in range(15, 119):
        left = pixels[55, y]
        right = pixels[205, y]
        for x in range(58, 201):
            t = (x - 55) / (205 - 55)
            clean = tuple(round(left[channel] * (1.0 - t) + right[channel] * t) for channel in range(3))
            edge = min(1.0, (x - 58) / 8, (200 - x) / 8, (y - 15) / 7, (118 - y) / 7)
            original = pixels[x, y]
            pixels[x, y] = tuple(round(original[channel] * (1.0 - edge) + clean[channel] * edge) for channel in range(3))
    symbol = wu_glyph(91, (17, 16, 95))
    image.paste(symbol, (121 - symbol.width // 2, 17), symbol.getchannel("A"))
    image.save(JPEG_FACE, quality=96, subsampling=0)


def main() -> None:
    replace_png(PNG_FACES[0], PNG_ORIGINALS[0], (24, 22, 20), 103)
    replace_png(PNG_FACES[1], PNG_ORIGINALS[1], (22, 22, 22), 98)
    replace_jpeg()
    print("五万牌面已改为伍万：2D、3D 和 JPG 后备素材")


if __name__ == "__main__":
    main()
