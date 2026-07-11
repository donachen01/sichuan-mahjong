#!/usr/bin/env python3
"""Generate the shared luxury felt table base for the main match scene."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "res/art/ui_3d_cartoon/felt_table_luxury.png"
SIZE = (2560, 1440)


def lerp(a: float, b: float, t: float) -> float:
	return a * (1.0 - t) + b * t


def main() -> None:
	random.seed(20260511)
	w, h = SIZE
	img = Image.new("RGBA", SIZE, (0, 0, 0, 255))
	pixels = img.load()
	center = (w * 0.50, h * 0.47)
	warm_spot = (w * 0.46, h * 0.58)
	for y in range(h):
		for x in range(w):
			nx = (x - center[0]) / (w * 0.62)
			ny = (y - center[1]) / (h * 0.70)
			r = math.sqrt(nx * nx + ny * ny)
			spot = max(0.0, 1.0 - r)
			wx = (x - warm_spot[0]) / (w * 0.38)
			wy = (y - warm_spot[1]) / (h * 0.42)
			warm = max(0.0, 1.0 - math.sqrt(wx * wx + wy * wy))
			vignette = min(1.0, r * 0.86)
			weave = math.sin(x * 0.045) * 1.8 + math.cos(y * 0.058) * 1.35
			fiber = random.randint(-3, 3)
			base = (
				int(lerp(18, 46, spot) + warm * 16 - vignette * 9 + weave + fiber),
				int(lerp(104, 158, spot) + warm * 24 - vignette * 24 + weave * 0.45 + fiber),
				int(lerp(72, 104, spot) + warm * 15 - vignette * 14 + fiber),
			)
			pixels[x, y] = (max(0, min(255, base[0])), max(0, min(255, base[1])), max(0, min(255, base[2])), 255)

	img = img.filter(ImageFilter.GaussianBlur(0.35))
	d = ImageDraw.Draw(img, "RGBA")

	fiber_layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
	fd = ImageDraw.Draw(fiber_layer, "RGBA")
	for i in range(18):
		y = random.randrange(h)
		x = random.randrange(w)
		length = random.randrange(18, 72)
		alpha = 1
		color = (128, 202, 136, alpha) if random.random() > 0.55 else (10, 58, 36, alpha)
		fd.line((x, y, min(w, x + length), y + random.randrange(-1, 2)), fill=color, width=1)

	for i in range(6):
		x = random.randrange(w)
		y = random.randrange(h)
		length = random.randrange(14, 54)
		alpha = 1
		fd.line((x, y, x + random.randrange(-1, 2), min(h, y + length)), fill=(12, 58, 36, alpha), width=1)
	fiber_layer = fiber_layer.filter(ImageFilter.GaussianBlur(0.6))
	img.alpha_composite(fiber_layer)

	light = Image.new("RGBA", SIZE, (0, 0, 0, 0))
	ld = ImageDraw.Draw(light, "RGBA")
	for radius, alpha in [(840, 18), (620, 20), (420, 16), (260, 11)]:
		bbox = (center[0] - radius, center[1] - radius * 0.52, center[0] + radius, center[1] + radius * 0.52)
		ld.ellipse(bbox, fill=(142, 224, 142, alpha))
	for radius, alpha in [(660, 12), (440, 10)]:
		bbox = (warm_spot[0] - radius, warm_spot[1] - radius * 0.44, warm_spot[0] + radius, warm_spot[1] + radius * 0.44)
		ld.ellipse(bbox, fill=(236, 196, 112, alpha))
	light = light.filter(ImageFilter.GaussianBlur(42))
	img.alpha_composite(light)

	for radius, alpha in [(1560, 46), (1260, 30), (980, 16)]:
		layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
		ld = ImageDraw.Draw(layer, "RGBA")
		ld.ellipse((center[0] - radius, center[1] - radius * 0.68, center[0] + radius, center[1] + radius * 0.68), outline=(0, 38, 25, alpha), width=90)
		layer = layer.filter(ImageFilter.GaussianBlur(35))
		img.alpha_composite(layer)

	img = img.filter(ImageFilter.GaussianBlur(0.25))

	OUT.parent.mkdir(parents=True, exist_ok=True)
	img.save(OUT)
	print(OUT)


if __name__ == "__main__":
	main()
