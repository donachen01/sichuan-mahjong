"""Author the launch-art-inspired table as an isolated Blender review asset.

Run with Blender 5.2 in background mode. This saves a native .blend file and a
render; it does not replace the live Godot table. The approved native source is exported
through generate_current_table.py; this script is for new visual experiments.
"""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "source_assets" / "table" / "launch_glass_experiments"
SOURCE = Path(__file__).with_name("generate_sichuan_table_v2.py")
SPEC = importlib.util.spec_from_file_location("sichuan_table_geometry", SOURCE)
geometry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(geometry)


def principled(name: str, rgb: tuple[float, float, float], roughness: float,
               metallic: float = 0.0, coat: float = 0.0,
               transmission: float = 0.0, ior: float = 1.45) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.035
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["IOR"].default_value = ior
    return material


def add_area(name: str, location: tuple[float, float, float], target: tuple[float, float, float],
             power: float, color: tuple[float, float, float], size: float, size_y: float,
             shape: str = "RECTANGLE") -> None:
    lamp = bpy.data.lights.new(name, type="AREA")
    lamp.energy = power
    lamp.color = color
    lamp.shape = shape
    lamp.size = size
    if shape == "RECTANGLE":
        lamp.size_y = size_y
    obj = bpy.data.objects.new(name, lamp)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    geometry.clear_scene()

    navy = principled("01 Deep Navy Lacquer · opaque support", (0.004, 0.013, 0.065), 0.23, 0.32, 0.42)
    sapphire = principled("02 Sapphire Lacquer · one visual frame", (0.008, 0.12, 0.50), 0.09, 0.08, 0.82)
    glass = principled("03 Blue Tinted Clear Glass · continuous cap", (0.80, 0.95, 1.0), 0.055, 0.0, 0.15, 0.98, 1.47)
    edge = principled("04 Glass edge · cool specular", (0.31, 0.82, 0.87), 0.055, 0.22, 0.95)
    felt = principled("05 Deep Teal Felt", (1.0, 1.0, 1.0), 0.82, 0.0, 0.0)
    size = 2048
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u, v = (xx + 0.5) / size, (yy + 0.5) / size
    broad = np.exp(-(((u - 0.50) / 0.34) ** 2 + ((v - 0.50) / 0.36) ** 2) * 1.10)
    central = np.exp(-(((u - 0.51) / 0.21) ** 2 + ((v - 0.47) / 0.25) ** 2) * 0.75)
    ambient = np.array([0.080, 0.39, 0.34], dtype=np.float32)
    rgb = ambient[None, None, :] + broad[:, :, None] * np.array([0.23, 0.25, 0.24], dtype=np.float32)
    rgb += central[:, :, None] * np.array([0.69, 0.56, 0.57], dtype=np.float32)
    grain = np.random.default_rng(260925).normal(0.0, 0.008, (size, size, 1)).astype(np.float32)
    rgb *= 1.0 + grain
    felt_image = geometry.save_rgba_image("LaunchTableDeepTealBaseColor", OUT / "felt_basecolor.png", rgb)
    felt_nodes = felt.node_tree.nodes
    felt_image_node = felt_nodes.new("ShaderNodeTexImage")
    felt_image_node.image = felt_image
    texture_coordinates = felt_nodes.new("ShaderNodeTexCoord")
    felt.node_tree.links.new(texture_coordinates.outputs["UV"], felt_image_node.inputs["Vector"])
    felt.node_tree.links.new(felt_image_node.outputs["Color"], felt_nodes.get("Principled BSDF").inputs["Base Color"])
    backdrop = principled("06 Pale blue studio backdrop", (0.87, 0.92, 1.0), 1.0)

    # All rail layers share the same silhouette. The opaque lacquer supplies
    # depth under a real clear cap, instead of simulating glass with alpha alone.
    support = geometry.rounded_box("TableWalnutBase", (15.35, 9.95, 0.67), (0, 0, -0.34), 0.34, 12, navy)
    playing_surface = geometry.rounded_box("TableFelt", (14.33, 8.98, 0.30), (0, 0, 0.02), 0.19, 12, felt)
    lacquer = geometry.rounded_rectangle_ring(
        "WalnutApronRing", (15.16, 9.76), (13.72, 8.32),
        0.28, (0, 0, 0.12), 0.49, 0.27, 24, 0.13, sapphire,
    )
    glass_cap = geometry.rounded_rectangle_ring(
        "SingleClearGlassCap", (15.16, 9.76), (13.72, 8.32),
        0.13, (0, 0, 0.315), 0.49, 0.27, 24, 0.055, glass,
    )
    glass_edge = geometry.rounded_rectangle_ring(
        "InnerGlassEdge", (13.79, 8.39), (13.72, 8.32),
        0.027, (0, 0, 0.390), 0.27, 0.27, 24, 0.010, edge,
    )
    glass_lip = geometry.rounded_rectangle_ring(
        "RaisedTransparentGlassLip", (13.94, 8.54), (13.78, 8.38),
        0.18, (0, 0, 0.420), 0.29, 0.27, 24, 0.024, glass,
    )
    geometry.rounded_box("StudioFloor", (200, 200, 0.06), (0, 0, -0.78), 0.01, 2, backdrop)
    # The ring builder uses Blender's UV unwrap operator. Set the felt UVs only
    # after every ring is complete, so multi-object edit mode cannot overwrite
    # the planar map and shift the broad reflected-light region to one side.
    uv_layer = playing_surface.data.uv_layers.active or playing_surface.data.uv_layers.new(name="PlaySurfacePlanarUV")
    for polygon in playing_surface.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = playing_surface.data.vertices[playing_surface.data.loops[loop_index].vertex_index]
            uv_layer.data[loop_index].uv = (vertex.co.x / 14.33 + 0.5, vertex.co.y / 8.98 + 0.5)

    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.80, 0.88, 1.0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.62
    add_area("Wide softbox above far rail", (-3, 5, 10), (0, 1, 0), 280, (0.82, 0.94, 1.0), 8.0, 8.0, "DISK")

    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0, -10.2, 11.0)
    camera.rotation_euler = (Vector((0, -2.0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "PERSP"
    camera_data.lens = 30.0
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 2048
    scene.render.resolution_y = 1152
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / "launch_glass_table_review.png")
    scene.view_settings.view_transform = "Standard"
    scene.render.film_transparent = False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "launch_glass_table_review.blend"))
    bpy.ops.render.render(write_still=True)
    geometry.OUTPUT_GLB = OUT / "launch_glass_table_review.glb"
    geometry.export_glb([support, playing_surface, lacquer, glass_cap, glass_edge, glass_lip])
    print(f"BLENDER_TABLE_REVIEW_READY {OUT}")


if __name__ == "__main__":
    main()
