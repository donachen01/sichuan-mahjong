"""Create the LAN waiting-room glass shells with Blender.

Only the decorative pixels are baked here. Godot owns the labels, ready state,
layout and input. Run with Blender --background --python this_script.py.
"""

from pathlib import Path

import bpy
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "res" / "art" / "ui" / "network"


def rounded_coverage(width: int, height: int, radius: float, inset: float = 0.0) -> np.ndarray:
    y, x = np.mgrid[:height, :width].astype(np.float32)
    radius = max(1.0, radius - inset)
    half_width = width * 0.5 - inset
    half_height = height * 0.5 - inset
    qx = np.abs(x + 0.5 - width * 0.5) - (half_width - radius)
    qy = np.abs(y + 0.5 - height * 0.5) - (half_height - radius)
    distance = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0)) + np.minimum(np.maximum(qx, qy), 0.0) - radius
    return np.clip(0.5 - distance, 0.0, 1.0)


def save_rgba(name: str, rgba: np.ndarray) -> None:
    height, width, _ = rgba.shape
    image = bpy.data.images.new(name, width=width, height=height, alpha=True, float_buffer=False)
    image.colorspace_settings.name = "sRGB"
    # Blender's image buffer starts at the bottom row; the arrays above use
    # screen coordinates from the top, like the mode-selection reference.
    image.pixels.foreach_set(np.clip(rgba[::-1], 0.0, 1.0).astype(np.float32).ravel())
    image.filepath_raw = str(OUTPUT / f"{name}.png")
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def make_panel() -> None:
    width, height = 860, 430
    y, x = np.mgrid[:height, :width].astype(np.float32)
    u, v = x / (width - 1), y / (height - 1)
    outer = rounded_coverage(width, height, 23.0, 2.0)
    inner = rounded_coverage(width, height, 23.0, 5.0)
    border = np.clip(outer - inner, 0.0, 1.0)
    sheen = np.clip(1.0 - np.abs(u - v - 0.08) / 0.31, 0.0, 1.0)
    rgba = np.zeros((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = np.stack((
        0.88 + 0.10 * sheen,
        0.94 + 0.06 * sheen,
        np.ones_like(sheen),
    ), axis=-1)
    # The mode selector uses an almost empty pane with a white rim. Keep the
    # table visible through this pane while leaving a faint refracted sheen.
    rgba[:, :, 3] = inner * (0.025 + 0.025 * sheen) + border * 0.94
    save_rgba("lan_lobby_panel_glass", rgba)


def make_round_ready_panel() -> None:
    # Compact table overlay for the next-round ready action. Keep the felt
    # visible; the rim, rather than an opaque fill, defines the glass sheet.
    width, height = 420, 104
    y, x = np.mgrid[:height, :width].astype(np.float32)
    u, v = x / (width - 1), y / (height - 1)
    outer = rounded_coverage(width, height, 18.0, 2.0)
    inner = rounded_coverage(width, height, 18.0, 5.0)
    border = np.clip(outer - inner, 0.0, 1.0)
    sheen = np.clip(1.0 - np.abs(u - v - 0.08) / 0.31, 0.0, 1.0)
    rgba = np.zeros((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = np.stack((
        0.88 + 0.10 * sheen,
        0.94 + 0.06 * sheen,
        np.ones_like(sheen),
    ), axis=-1)
    rgba[:, :, 3] = inner * (0.025 + 0.025 * sheen) + border * 0.94
    save_rgba("lan_round_ready_panel_glass", rgba)


def make_button(name: str, primary: bool) -> None:
    width, height = 720, 136
    y, x = np.mgrid[:height, :width].astype(np.float32)
    u, v = x / (width - 1), y / (height - 1)
    outer = rounded_coverage(width, height, 15.0, 4.0)
    inner = rounded_coverage(width, height, 15.0, 6.0)
    border = np.clip(outer - inner, 0.0, 1.0)
    diagonal = np.clip(1.0 - np.abs(u - v - 0.05) / 0.24, 0.0, 1.0) ** 2
    upper_left = np.clip(1.0 - np.hypot((u + 0.08) / 0.78, (v + 0.12) / 0.98), 0.0, 1.0)
    lower_right = np.clip(1.0 - np.hypot((u - 1.04) / 0.47, (v - 1.10) / 0.65), 0.0, 1.0)
    top = np.array((0.19, 0.67, 1.0) if primary else (0.97, 0.985, 1.0), dtype=np.float32)
    bottom = np.array((0.00, 0.30, 0.78) if primary else (0.80, 0.85, 0.93), dtype=np.float32)
    light = (0.08 * diagonal + 0.20 * upper_left + 0.54 * lower_right) if primary else (0.10 * diagonal + 0.07 * upper_left + 0.31 * lower_right)
    rgba = np.zeros((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(top[None, None, :] * (1.0 - v[:, :, None]) + bottom[None, None, :] * v[:, :, None] + light[:, :, None], 0.0, 1.0)
    rgba[:, :, :3] = rgba[:, :, :3] * inner[:, :, None] + np.array((0.82, 0.93, 1.0), dtype=np.float32)[None, None, :] * border[:, :, None]
    rgba[:, :, 3] = inner * (0.985 if primary else 0.94) + border * 0.99
    save_rgba(name, rgba)


def make_dice_panel() -> None:
    # A circular inlaid tray seen obliquely from the table camera. The ellipse
    # and its bevel are baked together; no square outline reaches the table.
    width, height = 384, 240
    y, x = np.mgrid[:height, :width].astype(np.float32)
    u, v = x / (width - 1), y / (height - 1)
    dx = (x + 0.5 - width * 0.5) / (width * 0.5 - 9.0)
    dy = (y + 0.5 - height * 0.5) / (height * 0.5 - 8.0)
    radius = np.hypot(dx, dy)
    shadow = np.clip((1.045 - radius) * 75.0, 0.0, 1.0)
    outer = np.clip((1.005 - radius) * 85.0, 0.0, 1.0)
    well = np.clip((0.895 - radius) * 85.0, 0.0, 1.0)
    inset = np.clip((0.80 - radius) * 55.0, 0.0, 1.0)
    upper_light = np.clip(0.54 - v, 0.0, 0.54) / 0.54
    diagonal = np.clip(1.0 - np.abs(u - v - 0.04) / 0.30, 0.0, 1.0)
    rgba = np.zeros((height, width, 4), dtype=np.float32)
    shadow_rgb = np.array((0.008, 0.035, 0.075), dtype=np.float32)
    rim_rgb = np.stack((
        0.32 + 0.29 * upper_light + 0.12 * diagonal,
        0.59 + 0.25 * upper_light + 0.12 * diagonal,
        0.78 + 0.18 * upper_light + 0.10 * diagonal,
    ), axis=-1)
    bevel_rgb = np.stack((
        0.025 + 0.055 * (1.0 - upper_light),
        0.16 + 0.09 * (1.0 - upper_light),
        0.30 + 0.10 * (1.0 - upper_light),
    ), axis=-1)
    well_rgb = np.stack((
        0.055 + 0.04 * diagonal,
        0.25 + 0.05 * diagonal,
        0.43 + 0.06 * diagonal,
    ), axis=-1)
    rgba[:, :, :3] = shadow_rgb
    rgba[:, :, :3] = rgba[:, :, :3] * (1.0 - outer[:, :, None]) + rim_rgb * outer[:, :, None]
    rgba[:, :, :3] = rgba[:, :, :3] * (1.0 - well[:, :, None]) + bevel_rgb * well[:, :, None]
    rgba[:, :, :3] = rgba[:, :, :3] * (1.0 - inset[:, :, None]) + well_rgb * inset[:, :, None]
    rgba[:, :, 3] = np.maximum(shadow * 0.32, outer * 0.98)
    save_rgba("lan_dice_panel_glass", rgba)


def make_dice_face() -> None:
    width = height = 112
    y, x = np.mgrid[:height, :width].astype(np.float32)
    u, v = x / (width - 1), y / (height - 1)
    outer = rounded_coverage(width, height, 17.0, 3.0)
    inner = rounded_coverage(width, height, 17.0, 6.0)
    rim = np.clip(outer - inner, 0.0, 1.0)
    diagonal = np.clip(1.0 - np.abs(u - v - 0.07) / 0.29, 0.0, 1.0)
    lower_right = np.clip(1.0 - np.hypot((u - 1.12) / 0.7, (v - 1.12) / 0.7), 0.0, 1.0)
    rgba = np.zeros((height, width, 4), dtype=np.float32)
    shade = 0.995 - 0.15 * v + 0.08 * diagonal + 0.16 * lower_right
    rgba[:, :, 0] = np.clip(shade, 0.0, 1.0)
    rgba[:, :, 1] = np.clip(shade + 0.025, 0.0, 1.0)
    rgba[:, :, 2] = np.clip(shade + 0.07, 0.0, 1.0)
    rgba[:, :, 3] = inner * 0.96 + rim * 0.99
    save_rgba("lan_dice_face_glass", rgba)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    make_panel()
    make_round_ready_panel()
    make_button("lan_lobby_ready_glass", True)
    make_button("lan_lobby_leave_glass", False)
    make_dice_panel()
    make_dice_face()
    print(f"LAN lobby glass shells: {OUTPUT}")


if __name__ == "__main__":
    main()
