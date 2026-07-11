#!/usr/bin/env python3
"""Generate bright emerald-jade Mahjong tile body assets used by the 2D table."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "res/art/ui_3d_cartoon"


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", size)
    pixels = image.load()
    height = max(1, size[1] - 1)
    for y in range(size[1]):
        t = y / height
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(size[0]):
            pixels[x, y] = (*color, 255)
    return image


def tri_gradient(
    size: tuple[int, int],
    top: tuple[int, int, int],
    mid: tuple[int, int, int],
    bottom: tuple[int, int, int],
) -> Image.Image:
    image = Image.new("RGBA", size)
    pixels = image.load()
    height = max(1, size[1] - 1)
    for y in range(size[1]):
        t = y / height
        if t < 0.5:
            local_t = t / 0.5
            color = tuple(int(top[i] * (1 - local_t) + mid[i] * local_t) for i in range(3))
        else:
            local_t = (t - 0.5) / 0.5
            color = tuple(int(mid[i] * (1 - local_t) + bottom[i] * local_t) for i in range(3))
        for x in range(size[0]):
            pixels[x, y] = (*color, 255)
    return image


def add_frost_noise(image: Image.Image, amount: int, alpha: int) -> Image.Image:
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            offset = ((x * 17 + y * 29) % (amount * 2 + 1)) - amount
            pixels[x, y] = (
                max(0, min(255, r + offset)),
                max(0, min(255, g + offset)),
                max(0, min(255, b + offset)),
                max(0, min(255, a - alpha // 8)),
            )
    return image


def draw_tile(size: tuple[int, int], back: bool) -> Image.Image:
    w, h = size
    scale = w / 110.0
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    radius = int(round(10 * scale))
    body_rect = (
        int(round(5 * scale)),
        int(round(3 * scale)),
        w - int(round(6 * scale)),
        h - int(round(10 * scale)),
    )
    body_size = (body_rect[2] - body_rect[0] + 1, body_rect[3] - body_rect[1] + 1)
    mask = rounded_mask(body_size, radius)

    shadow = Image.new("RGBA", body_size, (0, 0, 0, 0))
    shadow.putalpha(
        mask.filter(ImageFilter.GaussianBlur(max(3, int(4.8 * scale)))).point(
            lambda value: int(value * 0.14)
        )
    )
    shadow = shadow.resize(
        (body_size[0] + int(4 * scale), max(1, body_size[1] - int(2 * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas.alpha_composite(shadow, (body_rect[0] + int(2 * scale), body_rect[1] + int(9 * scale)))

    front_top = (232, 252, 240)
    front_mid = (193, 236, 211)
    front_bottom = (140, 205, 171)
    back_top = (56, 144, 98)
    back_mid = (34, 111, 73)
    back_bottom = (20, 79, 52)
    if back:
        face = tri_gradient(body_size, back_top, back_mid, back_bottom)
        face = add_frost_noise(face, max(1, int(3 * scale)), 12)
    else:
        face = tri_gradient(body_size, front_top, front_mid, front_bottom)
        face = add_frost_noise(face, max(1, int(2 * scale)), 8)
    face.putalpha(mask)
    canvas.alpha_composite(face, (body_rect[0], body_rect[1]))

    border_color = (66, 138, 98, 238) if not back else (136, 196, 156, 220)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        body_rect,
        radius=radius,
        outline=border_color,
        width=max(1, int(round(1.0 * scale))),
    )

    top_wash = Image.new("RGBA", body_size, (255, 255, 255, 0))
    wash_draw = ImageDraw.Draw(top_wash)
    wash_draw.rounded_rectangle(
        (int(8 * scale), int(7 * scale), body_size[0] - int(8 * scale), int(24 * scale)),
        radius=max(3, int(6 * scale)),
        fill=(255, 255, 252, 86) if not back else (228, 255, 242, 34),
    )
    top_wash = top_wash.filter(ImageFilter.GaussianBlur(max(2, int(1.5 * scale))))
    canvas.alpha_composite(top_wash, (body_rect[0], body_rect[1]))

    gloss = Image.new("RGBA", body_size, (0, 0, 0, 0))
    gloss_draw = ImageDraw.Draw(gloss)
    gloss_draw.rounded_rectangle(
        (int(10 * scale), int(10 * scale), body_size[0] - int(28 * scale), int(20 * scale)),
        radius=max(3, int(5 * scale)),
        fill=(255, 255, 255, 36) if not back else (220, 248, 236, 14),
    )
    gloss = gloss.filter(ImageFilter.GaussianBlur(max(2, int(1.3 * scale))))
    canvas.alpha_composite(gloss, (body_rect[0], body_rect[1]))

    relief = Image.new("RGBA", body_size, (0, 0, 0, 0))
    relief_draw = ImageDraw.Draw(relief)
    relief_draw.rounded_rectangle(
        (
            int(10 * scale),
            body_size[1] - int(16 * scale),
            body_size[0] - int(10 * scale),
            body_size[1] - int(9 * scale),
        ),
        radius=max(3, int(5 * scale)),
        fill=(46, 110, 74, 44) if not back else (10, 38, 24, 34),
    )
    relief = relief.filter(ImageFilter.GaussianBlur(max(2, int(1.6 * scale))))
    canvas.alpha_composite(relief, (body_rect[0], body_rect[1]))

    if back:
        pattern = Image.new("RGBA", body_size, (0, 0, 0, 0))
        pattern_draw = ImageDraw.Draw(pattern)
        step = max(10, int(16 * scale))
        for y in range(step, body_size[1] - step, step):
            for x in range(step, body_size[0] - step, step):
                pattern_draw.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(255, 255, 255, 10))
        pattern = pattern.filter(ImageFilter.GaussianBlur(0.6))
        canvas.alpha_composite(pattern, (body_rect[0], body_rect[1]))

    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    draw_tile((154, 226), False).save(OUT_DIR / "tile_face_large.png")
    draw_tile((110, 162), False).save(OUT_DIR / "tile_face_table.png")
    draw_tile((110, 162), True).save(OUT_DIR / "tile_back_table.png")
    print(f"generated tile bodies in {OUT_DIR}")


if __name__ == "__main__":
    main()
