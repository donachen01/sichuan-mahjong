"""Build the canonical Blender review scene for target Mahjong pieces.

The scene deliberately uses one imported ``mahjong_tile_body.glb`` for every
target object.  Only pose and uniform scale change between the far rack,
discard river, exposed meld and fallen winning tile.  The existing player
hands remain outside this review scene and are not edited by this script.

Run from Blender's GUI Python console or with Blender's GUI launcher:
    blender --python tools/3d/blender_target_tile_review.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
TILE_GLB = ROOT / "res/art/3d/mahjong_tile_body.glb"
TABLE_GLB = ROOT / "res/art/3d/sichuan_table_v2.glb"
OUT_DIR = ROOT / "evidence/ui_blender_target_review"
OUT_BLEND = OUT_DIR / "canonical_target_tile_review.blend"
OUT_RENDER = OUT_DIR / "canonical_target_tile_review.png"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def import_glb(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def canonical_tile_source() -> list[bpy.types.Object]:
    objects = [obj for obj in import_glb(TILE_GLB) if obj.type == "MESH"]
    if not objects:
        raise RuntimeError(f"No tile meshes imported from {TILE_GLB}")
    for obj in objects:
        obj.hide_render = True
        obj.hide_viewport = True
    return objects


def duplicate_tile(source: list[bpy.types.Object], name: str, location: tuple[float, float, float], rotation: tuple[float, float, float], scale: float = 1.0) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    root.rotation_euler = rotation
    root.scale = (scale, scale, scale)
    for source_obj in source:
        copy = source_obj.copy()
        copy.data = source_obj.data.copy()
        copy.hide_render = False
        copy.hide_viewport = False
        bpy.context.scene.collection.objects.link(copy)
        copy.parent = root
        copy.matrix_parent_inverse = root.matrix_world.inverted()
        copy.location = source_obj.location
        copy.rotation_euler = source_obj.rotation_euler
        copy.scale = source_obj.scale
        for polygon in copy.data.polygons:
            polygon.use_smooth = True
    return root


def setup_table() -> None:
    table_objects = import_glb(TABLE_GLB)
    roots = [obj for obj in table_objects if obj.parent is None]
    for root in roots:
        root.scale = (1.0, 1.60, 1.0)
        root.location.y = -2.30


def setup_lights() -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("CanonicalReviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.012, 0.020, 0.016, 1.0)
    bg.inputs["Strength"].default_value = 0.18

    def area(name: str, location: tuple[float, float, float], energy: float, size: float, color: tuple[float, float, float]) -> None:
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        obj = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = location
        look_at(obj, Vector((0.0, 0.0, 0.0)))

    area("WarmKey", (-5.5, -6.5, 11.0), 1350.0, 5.0, (1.0, 0.91, 0.80))
    area("SoftFill", (5.0, -1.0, 7.0), 720.0, 6.0, (0.72, 0.84, 1.0))
    area("FarRim", (0.0, 6.0, 8.0), 900.0, 4.0, (0.92, 1.0, 0.90))


def setup_camera() -> None:
    camera_data = bpy.data.cameras.new("CanonicalReviewCamera")
    camera = bpy.data.objects.new("CanonicalReviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (0.0, -13.0, 11.0)
    camera_data.lens = 48.0
    camera_data.sensor_width = 36.0
    look_at(camera, Vector((0.0, 0.2, 0.15)))
    bpy.context.scene.camera = camera


def build_targets(source: list[bpy.types.Object]) -> None:
    # Opposite hand: standing pose, one shared GLB, uniform scale only.
    for index in range(13):
        x = (index - 6) * 0.55
        duplicate_tile(source, f"TargetFarHand_{index:02d}", (x, 3.05, 0.40), (math.radians(90.0), 0.0, 0.0), 1.28)

    # Four discard tiles: lying flat on the table, same source geometry.
    for index in range(4):
        x = (index - 1.5) * 0.72
        duplicate_tile(source, f"TargetDiscard_{index:02d}", (x, 0.95, 0.23), (0.0, 0.0, 0.0), 1.16)

    # One exposed peng and one gang preview. The orientation changes, the model
    # and the uniform scale do not.
    for index in range(3):
        x = (index - 1) * 0.58
        duplicate_tile(source, f"TargetPeng_{index:02d}", (x, -0.40, 0.23), (0.0, 0.0, 0.0), 1.12)
    for index in range(4):
        x = (index - 1.5) * 0.58
        duplicate_tile(source, f"TargetGang_{index:02d}", (x, -1.40, 0.23), (0.0, 0.0, 0.0), 1.12)

    # Fallen winning tile preview: same body and scale, only a different pose.
    duplicate_tile(source, "TargetWinningTile", (2.2, 0.55, 0.23), (0.0, 0.0, math.radians(10.0)), 1.12)


def render() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 2048
    scene.render.resolution_y = 1152
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT_RENDER)
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    bpy.ops.render.render(write_still=True)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    setup_table()
    source = canonical_tile_source()
    build_targets(source)
    setup_lights()
    setup_camera()
    render()
    print(f"BLENDER_TARGET_REVIEW_OK {OUT_RENDER}")
    # The review is a batch artifact even when launched through Blender's GUI
    # binary.  Quit after the render so the launcher can provide a reliable
    # completion status instead of leaving a hidden window behind.
    bpy.ops.wm.quit_blender()


if __name__ == "__main__":
    main()
