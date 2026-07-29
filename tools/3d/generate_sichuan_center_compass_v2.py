"""Generate the low-profile PBR center compass for the Deep Emerald table.

The mesh is deliberately text-free. Godot overlays live direction/countdown
labels so language, turn state and accessibility remain dynamic UI concerns.

Usage:
  Blender --background --python tools/3d/generate_sichuan_center_compass_v2.py
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "res" / "art" / "3d" / "sichuan_center_compass_v2.glb"


def srgb_to_linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def rgba(hex_value: str) -> tuple[float, float, float, float]:
    rgb = tuple(int(hex_value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple(srgb_to_linear(channel) for channel in rgb) + (1.0,)


def make_material(name: str, hex_value: str, metallic: float, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = rgba(hex_value)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = rgba(hex_value)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return material


def bevel_object(obj: bpy.types.Object, width: float, segments: int) -> None:
    bevel = obj.modifiers.new("CompassSoftBevel", "BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.profile = 0.62
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def add_octagonal_cylinder(name: str, radius: float, depth: float, z: float, material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=depth, location=(0.0, 0.0, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    bevel_object(obj, 0.09, 4)
    return obj


def add_direction_wedge(name: str, angle: float, material: bpy.types.Material) -> bpy.types.Object:
    # One shallow triangular prism per seat. The live active highlight remains
    # a Godot overlay, but the physical seam and directional silhouette are PBR.
    inner = 0.31
    outer = 0.96
    half = 0.53
    vertices_2d = [(-half, inner), (half, inner), (0.0, outer)]
    vertices = [(x, y, 0.17) for x, y in vertices_2d] + [(x, y, 0.27) for x, y in vertices_2d]
    faces = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.rotation_euler.z = angle
    bevel_object(obj, 0.045, 4)
    return obj


def build() -> list[bpy.types.Object]:
    shadow = make_material("CompassShadow", "020806", 0.0, 0.92)
    walnut = make_material("CompassWalnut", "281F1B", 0.04, 0.62)
    copper = make_material("CompassAgedCopper", "9D743A", 0.52, 0.46)
    ink_jade = make_material("CompassInkJade", "0A4B41", 0.08, 0.58)
    highlight = make_material("CompassCopperHighlight", "C49A55", 0.42, 0.40)

    objects = [
        add_octagonal_cylinder("CompassShadowFoot", 1.42, 0.16, 0.01, shadow),
        add_octagonal_cylinder("CompassWalnutBase", 1.34, 0.20, 0.10, walnut),
        add_octagonal_cylinder("CompassCopperInset", 1.23, 0.16, 0.20, copper),
        add_octagonal_cylinder("CompassJadeWell", 1.13, 0.14, 0.28, ink_jade),
    ]
    for index, angle in enumerate((0.0, 1.5707963268, 3.1415926536, 4.7123889804)):
        objects.append(add_direction_wedge(f"DirectionWedge{index}", angle, ink_jade))
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD",
        major_segments=108,
        minor_segments=8,
        location=(0.0, 0.0, 0.37),
        major_radius=0.28,
        minor_radius=0.055,
    )
    ring = bpy.context.object
    ring.name = "CountdownCopperRing"
    ring.data.materials.append(highlight)
    objects.append(ring)
    return objects


def export(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    subprocess.run(
        ["python3", str(ROOT / "tools" / "3d" / "canonicalize_glb_images.py"), str(OUTPUT)],
        check=True,
    )


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objects = build()
    export(objects)
    triangles = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    print(f"Generated {OUTPUT}")
    print(f"Object count: {len(objects)}; triangulated faces before exporter: {triangles}")


if __name__ == "__main__":
    main()
