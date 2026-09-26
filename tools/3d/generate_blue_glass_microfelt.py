#!/usr/bin/env python3
"""Generate deep teal glass felt inspired by the user's launch table artwork.

Run with Blender so the asset has one deterministic authoring pipeline:
  Blender --background --factory-startup --python tools/3d/generate_blue_glass_microfelt.py

The broad, gentle centre lift is painted into the Blender base-colour map so
the same glass-table character survives Godot's mobile renderer. No reference
image or watermark is baked into the game. Geometry displacement is forbidden.
"""

from pathlib import Path

import bpy
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "res/art/materials/table_skins/blue_glass"
SIZE = 2048
SEED = 260922
BASE_RGB = np.array([0.050, 0.158, 0.150], dtype=np.float32)


def seamless_noise(rng: np.random.Generator, size: int) -> np.ndarray:
	"""High-frequency isotropic micro-grain with no low-frequency illumination."""
	field = rng.standard_normal((size, size), dtype=np.float32)
	# Average only immediate neighbours. Roll makes the result exactly tileable.
	field = (
		field * 4.0
		+ np.roll(field, 1, 0)
		+ np.roll(field, -1, 0)
		+ np.roll(field, 1, 1)
		+ np.roll(field, -1, 1)
	) / 8.0
	field -= float(field.mean())
	field /= max(float(field.std()), 1.0e-6)
	return np.clip(field, -2.5, 2.5)


def micro_nap(field: np.ndarray) -> np.ndarray:
	"""Broaden grains to ~8 texels: 1-2 pixels in the final gameplay view."""
	result = field * 4.0
	weight = 4.0
	for offset in range(1, 5):
		axis_weight = 1.0 if offset < 3 else 0.65
		for axis in (0, 1):
			result += np.roll(field, offset, axis) * axis_weight
			result += np.roll(field, -offset, axis) * axis_weight
			weight += 2.0 * axis_weight
	return result / weight


def short_fibres(rng: np.random.Generator, size: int, count: int = 260_000) -> np.ndarray:
	"""Rasterize seamless, randomly oriented 3-7 texel cow-hair-like nap."""
	fibres = np.zeros((size, size), dtype=np.float32)
	x0 = rng.integers(0, size, count)
	y0 = rng.integers(0, size, count)
	angles = rng.uniform(0.0, np.pi, count)
	lengths = rng.integers(2, 5, count)
	values = rng.uniform(0.45, 1.0, count).astype(np.float32)
	for step in range(7):
		active = lengths > step
		x = np.rint(x0[active] + np.cos(angles[active]) * step).astype(np.int32) % size
		y = np.rint(y0[active] + np.sin(angles[active]) * step).astype(np.int32) % size
		np.add.at(fibres, (y, x), values[active])
	# Sub-pixel antialiasing without producing a broad cloudy field.
	fibres = (
		fibres * 8.0
		+ np.roll(fibres, 1, 0) + np.roll(fibres, -1, 0)
		+ np.roll(fibres, 1, 1) + np.roll(fibres, -1, 1)
	) / 8.0
	fibres -= float(fibres.mean())
	fibres /= max(float(fibres.std()), 1.0e-6)
	return np.clip(fibres, -1.8, 3.0)


def save_rgba(name: str, rgb: np.ndarray) -> Path:
	path = OUT / name
	image = bpy.data.images.new(name, width=SIZE, height=SIZE, alpha=True, float_buffer=False)
	rgba = np.empty((SIZE, SIZE, 4), dtype=np.float32)
	rgba[:, :, :3] = np.clip(rgb, 0.0, 1.0)
	rgba[:, :, 3] = 1.0
	image.pixels.foreach_set(rgba[::-1].reshape(-1))
	image.filepath_raw = str(path)
	image.file_format = "PNG"
	image.save()
	bpy.data.images.remove(image)
	return path


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	rng = np.random.default_rng(SEED)
	grain = seamless_noise(rng, SIZE)
	secondary = seamless_noise(rng, SIZE)
	fibres = short_fibres(rng, SIZE)
	# Keep the authored nap isotropic. Axis-aligned broadening creates a visible
	# linen weave in the oblique game camera, which the target short felt lacks.

	# Fine granular bed plus brighter/darker short strands. The fibre layer owns
	# most visible texture; the noise bed prevents empty gaps between strands.
	nap = micro_nap(grain)
	albedo = BASE_RGB[None, None, :] * (
		1.0 + grain[:, :, None] * 0.038 + nap[:, :, None] * 0.048
		+ fibres[:, :, None] * 0.056
	)
	albedo += secondary[:, :, None] * np.array([0.0003, 0.0005, 0.0006], dtype=np.float32)
	# An oblique glass reflection and a wide luminous centre reproduce the
	# launch artwork without a circular spotlight or a photographic tabletop.
	y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
	u = (x + 0.5) / SIZE - 0.5
	v = (y + 0.5) / SIZE - 0.5
	centre = np.exp(-((u / 0.32) ** 2 + (v / 0.26) ** 2) * 1.20)
	soft_streak = np.exp(-((v + 0.23 * u + 0.11) / 0.20) ** 2) * 0.35
	albedo += centre[:, :, None] * np.array([0.46, 0.43, 0.41], dtype=np.float32)
	albedo += soft_streak[:, :, None] * np.array([0.009, 0.030, 0.043], dtype=np.float32)

	# Derive tangent-space micro-normal from the same seamless height field.
	height = nap * 0.35 + grain * 0.25 + fibres * 0.40
	dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
	dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
	strength = 0.095
	normal = np.stack((-dx * strength, -dy * strength, np.ones_like(grain)), axis=2)
	normal /= np.linalg.norm(normal, axis=2, keepdims=True)
	normal = normal * 0.5 + 0.5

	roughness_value = np.clip(0.84 + secondary * 0.012 - fibres * 0.004, 0.80, 0.88)
	roughness = np.repeat(roughness_value[:, :, None], 3, axis=2)

	paths = [
		save_rgba("albedo_2k.png", albedo),
		save_rgba("normal_2k.png", normal),
		save_rgba("roughness_2k.png", roughness),
	]
	print("BLUE_GLASS_MICROFELT_GENERATED")
	for path in paths:
		print(path)


if __name__ == "__main__":
	main()
