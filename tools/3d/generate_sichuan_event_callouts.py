"""Build the six original Sichuan table callouts and their editable Blender source.

Run with:
    /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/3d/generate_sichuan_event_callouts.py

The artwork is a deterministic, locally-authored parametric composition.  It
does not use an image-generation service or copy pixels from a reference game.
Each callout is rendered as a transparent 1024x512 PNG and all editable text,
seal, ring, line, particle and petal layers remain in the saved .blend file.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "res" / "art" / "ui" / "event_callouts"
SOURCE_DIR = PROJECT_ROOT / "res" / "source" / "ui" / "event_callouts"
FONT_PATH = PROJECT_ROOT / "res" / "fonts" / "NotoSansCJKsc-Regular.otf"

CALLOUTS = (
    ("peng", "碰", "jade_seal"),
    ("gang", "杠", "copper_jade"),
    ("hu", "胡", "cinnabar_gold"),
    ("self_draw", "自摸", "ivory_ring"),
    ("gang_self_draw", "杠上花", "cinnabar_petals"),
    ("qiang_gang_hu", "抢杠胡", "sharp_cinnabar"),
)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in tuple(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def material(name: str, rgba: tuple[float, float, float, float]):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = rgba
    emission.inputs["Strength"].default_value = 1.0
    mat.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return mat


JADE = None
JADE_GLOW = None
DEEP_JADE = None
COPPER = None
GOLD = None
CINNABAR = None
DARK_RED = None
IVORY = None


def assign_to_collection(obj, collection) -> None:
    for owner in tuple(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def rounded_plate(name: str, center: tuple[float, float], size: tuple[float, float], radius: float, mat, collection, z: float = 0.0):
    bpy.ops.mesh.primitive_cube_add(location=(center[0], center[1], z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[1], 0.12)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("HandRoundedCorners", "BEVEL")
    bevel.width = radius
    bevel.segments = 8
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    assign_to_collection(obj, collection)
    return obj


def disc(name: str, center: tuple[float, float], radius: float, mat, collection, z: float = 0.0, vertices: int = 96):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=0.10, location=(center[0], center[1], z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    assign_to_collection(obj, collection)
    return obj


def text_layer(name: str, value: str, center: tuple[float, float], size: float, mat, collection, z: float = 0.20):
    bpy.ops.object.text_add(location=(center[0], center[1], z))
    obj = bpy.context.object
    obj.name = name
    obj.data.body = value
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.size = size
    obj.data.extrude = 0.018
    obj.data.bevel_depth = 0.010
    obj.data.bevel_resolution = 3
    obj.data.font = bpy.data.fonts.load(str(FONT_PATH), check_existing=True)
    obj.data.materials.append(mat)
    assign_to_collection(obj, collection)
    return obj


def slash(name: str, center: tuple[float, float], length: float, angle: float, mat, collection, z: float = 0.04):
    obj = rounded_plate(name, center, (length, 0.11), 0.055, mat, collection, z)
    obj.rotation_euler[2] = angle
    return obj


def build_callout(index: int, key: str, label: str, style: str):
    x = float(index) * 14.0
    collection = bpy.data.collections.new(f"Callout_{key}")
    bpy.context.scene.collection.children.link(collection)
    center = (x, 0.0)

    if style == "jade_seal":
        disc("JadeGlow", center, 2.36, JADE_GLOW, collection, -0.08)
        disc("JadeOuterSeal", center, 2.05, COPPER, collection, 0.00)
        disc("JadeInnerSeal", center, 1.78, JADE, collection, 0.08)
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            disc(f"JadeSpark_{angle}", (x + math.cos(rad) * 2.55, math.sin(rad) * 2.55), 0.07, JADE_GLOW, collection, 0.03, 32)
        text_layer("PengText", label, center, 2.70, IVORY, collection)
    elif style == "copper_jade":
        rounded_plate("GangCopperFrame", center, (6.35, 3.70), 0.58, COPPER, collection, 0.00)
        rounded_plate("GangDeepJade", center, (5.88, 3.24), 0.45, DEEP_JADE, collection, 0.08)
        slash("GangTopInlay", (x, 1.29), 4.45, 0.0, GOLD, collection, 0.15)
        slash("GangBottomInlay", (x, -1.29), 4.45, 0.0, GOLD, collection, 0.15)
        text_layer("GangText", label, center, 2.62, GOLD, collection)
    elif style == "cinnabar_gold":
        disc("HuGoldRim", center, 2.16, GOLD, collection, 0.00)
        disc("HuCinnabarSeal", center, 1.91, CINNABAR, collection, 0.08)
        for i, angle in enumerate((18, 51, 126, 202, 247, 321)):
            rad = math.radians(angle)
            distance = 2.35 + (i % 2) * 0.28
            disc(f"GoldGrain_{i}", (x + math.cos(rad) * distance, math.sin(rad) * distance), 0.06 + (i % 3) * 0.018, GOLD, collection, 0.03, 32)
        text_layer("HuText", label, center, 2.75, IVORY, collection)
    elif style == "ivory_ring":
        disc("SelfDrawOuterRing", center, 2.38, JADE_GLOW, collection, -0.03)
        disc("SelfDrawInnerCut", center, 2.08, DEEP_JADE, collection, 0.05)
        rounded_plate("SelfDrawIvorySlip", center, (5.65, 2.55), 0.72, IVORY, collection, 0.10)
        slash("SelfDrawCopperKeyline", (x, -1.08), 3.80, 0.0, COPPER, collection, 0.18)
        text_layer("SelfDrawText", label, center, 1.90, JADE, collection)
    elif style == "cinnabar_petals":
        rounded_plate("GangFlowerSeal", center, (8.05, 3.36), 0.78, DARK_RED, collection, 0.00)
        rounded_plate("GangFlowerInner", center, (7.55, 2.92), 0.62, CINNABAR, collection, 0.08)
        for i, (px, py, angle) in enumerate(((3.70, 1.62, 0.55), (4.12, 0.84, -0.32), (-3.92, -1.40, 0.72))):
            petal = rounded_plate(f"PaleGoldPetal_{i}", (x + px, py), (0.58, 0.18), 0.09, IVORY, collection, 0.15)
            petal.rotation_euler[2] = angle
        text_layer("GangFlowerText", label, center, 1.66, IVORY, collection)
    elif style == "sharp_cinnabar":
        rounded_plate("RobGangDarkCore", center, (8.20, 3.14), 0.36, DARK_RED, collection, 0.00)
        slash("SharpEntryTop", (x, 1.63), 8.55, 0.06, GOLD, collection, 0.08)
        slash("SharpEntryBottom", (x, -1.63), 8.55, -0.06, GOLD, collection, 0.08)
        slash("SharpLeft", (x - 4.18, 0.0), 2.40, 1.02, CINNABAR, collection, 0.08)
        slash("SharpRight", (x + 4.18, 0.0), 2.40, -1.02, CINNABAR, collection, 0.08)
        text_layer("RobGangText", label, center, 1.70, IVORY, collection)
    return collection


def configure_scene():
    scene = bpy.context.scene
    # Blender 5.2 LTS on this machine exposes the Eevee identifier without the
    # historical `_NEXT` suffix.
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"
    camera_data = bpy.data.cameras.new("CalloutOrthoCamera")
    camera = bpy.data.objects.new("CalloutOrthoCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0.0, 0.0, 12.0)
    camera.rotation_euler = (0.0, 0.0, 0.0)
    camera_data.type = "ORTHO"
    # Leave a real transparent safety margin around even the longest sharp
    # callout; Godot can then scale the art without clipping its authored edge.
    camera_data.ortho_scale = 10.4
    scene.camera = camera
    return scene, camera


def main() -> None:
    global JADE, JADE_GLOW, DEEP_JADE, COPPER, GOLD, CINNABAR, DARK_RED, IVORY
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    JADE = material("EmeraldSeal", (0.035, 0.43, 0.31, 1.0))
    JADE_GLOW = material("JadeMicroGlow", (0.10, 0.86, 0.61, 1.0))
    DEEP_JADE = material("DeepInkJade", (0.012, 0.10, 0.078, 1.0))
    COPPER = material("AgedCopper", (0.54, 0.34, 0.14, 1.0))
    GOLD = material("RestrainedGold", (0.92, 0.70, 0.25, 1.0))
    CINNABAR = material("CinnabarSeal", (0.66, 0.10, 0.075, 1.0))
    DARK_RED = material("DarkCinnabar", (0.24, 0.028, 0.026, 1.0))
    IVORY = material("WarmIvory", (1.0, 0.91, 0.68, 1.0))
    scene, camera = configure_scene()
    for index, (key, label, style) in enumerate(CALLOUTS):
        build_callout(index, key, label, style)
    source_path = SOURCE_DIR / "sichuan_event_callouts.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    for index, (key, _label, _style) in enumerate(CALLOUTS):
        camera.location.x = float(index) * 14.0
        scene.render.filepath = str(OUTPUT_DIR / f"{key}.png")
        bpy.ops.render.render(write_still=True)
    print(f"Generated {len(CALLOUTS)} transparent callouts in {OUTPUT_DIR}")
    print(f"Editable source: {source_path}")


if __name__ == "__main__":
    main()
