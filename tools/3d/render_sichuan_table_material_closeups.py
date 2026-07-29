"""Render independent leather, walnut and aged-copper acceptance close-ups."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
GLB_PATH = PROJECT_ROOT / "res" / "art" / "3d" / "sichuan_table_v2.glb"
OUTPUT_DIR = PROJECT_ROOT / "evidence" / "ui_emerald_final_20260726" / "stage1" / "material_closeups"


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_scene() -> bpy.types.Object:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(GLB_PATH))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.look = "AgX - Medium High Contrast"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("CloseupWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.010, 0.016, 0.014, 1.0)
    background.inputs["Strength"].default_value = 0.24

    bpy.ops.object.camera_add(location=(0.0, -6.8, 3.1))
    camera = bpy.context.object
    camera.data.lens = 62.0
    camera.data.sensor_width = 36.0
    scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(-4.8, -6.2, 7.4))
    key = bpy.context.object
    key.name = "WarmMaterialKey"
    key.data.energy = 940.0
    key.data.color = (1.0, 0.86, 0.67)
    key.data.shape = "RECTANGLE"
    key.data.size = 5.2
    key.data.size_y = 3.6
    look_at(key, Vector((0.0, -3.7, 0.0)))

    bpy.ops.object.light_add(type="AREA", location=(4.6, -2.1, 4.8))
    fill = bpy.context.object
    fill.name = "JadeMaterialFill"
    fill.data.energy = 520.0
    fill.data.color = (0.48, 0.82, 0.72)
    fill.data.size = 4.0
    look_at(fill, Vector((1.0, -3.8, 0.0)))
    return camera


def render(camera: bpy.types.Object, name: str, position: tuple[float, float, float], target: tuple[float, float, float], lens: float) -> None:
    camera.location = Vector(position)
    camera.data.lens = lens
    look_at(camera, Vector(target))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output = OUTPUT_DIR / f"{name}.png"
    bpy.context.scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    print(output)


def main() -> None:
    camera = setup_scene()
    render(camera, "leather_stitch_closeup", (0.0, -6.9, 2.65), (0.0, -4.22, 0.08), 66.0)
    render(camera, "walnut_corner_closeup", (-8.0, -6.3, 3.35), (-6.30, -3.88, -0.10), 72.0)
    render(camera, "aged_copper_inlay_closeup", (7.6, -6.0, 2.70), (5.55, -4.08, 0.14), 78.0)


if __name__ == "__main__":
    main()
