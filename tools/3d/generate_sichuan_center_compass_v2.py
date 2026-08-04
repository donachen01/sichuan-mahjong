"""Generate the premium Blender-authored flush glass four-way table inlay.

The GLB owns all visible physical geometry and PBR materials. Godot keeps only
the live wall count and direction glyphs, plus visibility of the four authored
red-enamel active-sector overlays. This split preserves localization and turn
state without rebuilding the manufactured object from runtime flat meshes.

Usage:
  Blender --background --python tools/3d/generate_sichuan_center_compass_v2.py
"""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "res" / "art" / "3d" / "sichuan_center_compass_v2.glb"
ACTIVE_RED_DISPLAY_HEX = "A13D2D"
# The table uses Godot's filmic tonemapper. Its display transform lifts a raw
# unlit A13D2D material to a salmon RGB around 195/76/54. This calibrated
# authoring value renders back to the requested display RGB 161/61/45 while the
# semantic target remains ACTIVE_RED_DISPLAY_HEX and the 2D fallback uses it
# directly (Canvas output is not processed through the 3D filmic transform).
ACTIVE_RED_FILMIC_AUTHORING_HEX = "7F3226"
COUNTER_BEZEL_RADIUS = 0.455
COUNTER_LENS_RADIUS = 0.365
# Keep every red face outside the physical bezel. The small allowance also
# keeps the straight chords between sampled arc points from crossing the ring.
ACTIVE_SECTOR_CUTOUT_RADIUS = COUNTER_BEZEL_RADIUS + 0.005
ACTIVE_SECTOR_ARC_SEGMENTS = 8
SEPARATOR_INNER_X = 0.38
SEPARATOR_INNER_Y = 0.20
# The separator hairlines do not divide the wide panel into four equal 90°
# wedges. Top/bottom span about 124.5°, while left/right span about 55.5°.
# Active lacquer must use the same rays or East/West leave dark wedges beside
# the counter even though their outer bands look red.
SEPARATOR_CORNER_ANGLE_DEGREES = math.degrees(
    math.atan2(SEPARATOR_INNER_Y, SEPARATOR_INNER_X)
)


def srgb_to_linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def rgba(hex_value: str) -> tuple[float, float, float, float]:
    rgb = tuple(int(hex_value[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    return tuple(srgb_to_linear(channel) for channel in rgb) + (1.0,)


def set_shader_input(shader: bpy.types.ShaderNodeBsdfPrincipled, names: tuple[str, ...], value: object) -> None:
    for name in names:
        socket = shader.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return


def make_material(
    name: str,
    color: str,
    *,
    metallic: float,
    roughness: float,
    coat: float = 0.0,
    coat_roughness: float = 0.20,
    anisotropic: float = 0.0,
    alpha: float = 1.0,
    transmission: float = 0.0,
    emission: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    base_color = rgba(color)[:3] + (alpha,)
    material.diffuse_color = base_color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is None:
        raise RuntimeError(f"Principled BSDF is unavailable for {name}")
    set_shader_input(shader, ("Base Color",), base_color)
    set_shader_input(shader, ("Metallic",), metallic)
    set_shader_input(shader, ("Roughness",), roughness)
    set_shader_input(shader, ("Coat Weight", "Clearcoat"), coat)
    set_shader_input(shader, ("Coat Roughness", "Clearcoat Roughness"), coat_roughness)
    set_shader_input(shader, ("Anisotropic IOR Level", "Anisotropic"), anisotropic)
    set_shader_input(shader, ("Alpha",), alpha)
    set_shader_input(shader, ("Transmission Weight", "Transmission"), transmission)
    set_shader_input(shader, ("IOR",), 1.47)
    if alpha < 1.0:
        material.surface_render_method = "DITHERED"
    if emission is not None and emission_strength > 0.0:
        set_shader_input(shader, ("Emission Color", "Emission"), rgba(emission))
        set_shader_input(shader, ("Emission Strength",), emission_strength)
    return material


def bevel_object(obj: bpy.types.Object, width: float, segments: int = 3) -> None:
    bevel = obj.modifiers.new("PrecisionEdgeBevel", "BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.profile = 0.62
    bevel.limit_method = "ANGLE"
    if hasattr(bevel, "harden_normals"):
        bevel.harden_normals = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def prism_from_outline(
    name: str,
    points: list[tuple[float, float]],
    bottom: float,
    top: float,
    material: bpy.types.Material,
    *,
    bevel: float = 0.012,
    bevel_segments: int = 3,
) -> bpy.types.Object:
    vertex_count = len(points)
    vertices = [(x, y, bottom) for x, y in points] + [(x, y, top) for x, y in points]
    faces: list[tuple[int, ...]] = [
        tuple(reversed(range(vertex_count))),
        tuple(range(vertex_count, vertex_count * 2)),
    ]
    for index in range(vertex_count):
        next_index = (index + 1) % vertex_count
        faces.append((index, next_index, vertex_count + next_index, vertex_count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if bevel > 0.0:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bevel_object(obj, bevel, bevel_segments)
        obj.select_set(False)
    return obj


def flat_polygon(
    name: str,
    points: list[tuple[float, float]],
    plane_height: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Author a top-only polygon: no extrusion, side wall, or bevel."""
    vertices = [(x, y, plane_height) for x, y in points]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], [tuple(range(len(points)))])
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def flat_polygon_collection(
    name: str,
    polygons: list[list[tuple[float, float]]],
    plane_height: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Combine several convex top-only polygons into one exported component."""
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for polygon in polygons:
        base = len(vertices)
        vertices.extend((x, y, plane_height) for x, y in polygon)
        faces.append(tuple(range(base, base + len(polygon))))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def flat_line_segments(
    name: str,
    segments: list[tuple[tuple[float, float], tuple[float, float]]],
    line_width: float,
    plane_height: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Build several coplanar hairlines as one top-only mesh."""
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    half_width = line_width * 0.5
    for start, end in segments:
        delta_x = end[0] - start[0]
        delta_y = end[1] - start[1]
        length = math.hypot(delta_x, delta_y)
        normal_x = -delta_y / length * half_width
        normal_y = delta_x / length * half_width
        base = len(vertices)
        vertices.extend([
            (start[0] + normal_x, start[1] + normal_y, plane_height),
            (end[0] + normal_x, end[1] + normal_y, plane_height),
            (end[0] - normal_x, end[1] - normal_y, plane_height),
            (start[0] - normal_x, start[1] - normal_y, plane_height),
        ])
        faces.append((base, base + 1, base + 2, base + 3))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def chamfered_outline(width: float, depth: float, corner: float) -> list[tuple[float, float]]:
    half_width = width * 0.5
    half_depth = depth * 0.5
    return [
        (-half_width + corner, -half_depth),
        (half_width - corner, -half_depth),
        (half_width, -half_depth + corner),
        (half_width, half_depth - corner),
        (half_width - corner, half_depth),
        (-half_width + corner, half_depth),
        (-half_width, half_depth - corner),
        (-half_width, -half_depth + corner),
    ]


def add_chamfered_panel(
    name: str,
    width: float,
    depth: float,
    corner: float,
    bottom: float,
    top: float,
    material: bpy.types.Material,
    *,
    bevel: float,
) -> bpy.types.Object:
    return prism_from_outline(
        name,
        chamfered_outline(width, depth, corner),
        bottom,
        top,
        material,
        bevel=bevel,
    )


def add_box(
    name: str,
    size: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    *,
    rotation_z: float = 0.0,
    bevel: float = 0.006,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=(0.0, 0.0, rotation_z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        bevel_object(obj, bevel, 2)
    return obj


def add_cylinder(
    name: str,
    radius: float,
    bottom: float,
    top: float,
    material: bpy.types.Material,
    *,
    vertices: int = 40,
    bevel: float = 0.008,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=top - bottom,
        location=(0.0, 0.0, (bottom + top) * 0.5),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if bevel > 0.0:
        bevel_object(obj, bevel, 2)
    return obj


def join_objects(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    if not objects:
        raise ValueError(f"Cannot join empty object list for {name}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def interpolate_point(
    start: tuple[float, float],
    end: tuple[float, float],
    amount: float,
) -> tuple[float, float]:
    return (
        start[0] + (end[0] - start[0]) * amount,
        start[1] + (end[1] - start[1]) * amount,
    )


def arc_points(start_degrees: float, end_degrees: float) -> list[tuple[float, float]]:
    return [
        (
            math.cos(math.radians(start_degrees + (end_degrees - start_degrees) * index / ACTIVE_SECTOR_ARC_SEGMENTS))
            * ACTIVE_SECTOR_CUTOUT_RADIUS,
            math.sin(math.radians(start_degrees + (end_degrees - start_degrees) * index / ACTIVE_SECTOR_ARC_SEGMENTS))
            * ACTIVE_SECTOR_CUTOUT_RADIUS,
        )
        for index in range(ACTIVE_SECTOR_ARC_SEGMENTS + 1)
    ]


def sector_with_counter_cutout(
    outer_start: tuple[float, float],
    outer_end: tuple[float, float],
    outer_before: tuple[float, float],
    outer_after: tuple[float, float],
    arc_start_degrees: float,
    arc_end_degrees: float,
) -> list[list[tuple[float, float]]]:
    """Tessellate one field around the counter with convex, deterministic faces."""
    inner_arc = arc_points(arc_start_degrees, arc_end_degrees)
    outer_line = [
        interpolate_point(outer_start, outer_end, index / ACTIVE_SECTOR_ARC_SEGMENTS)
        for index in range(ACTIVE_SECTOR_ARC_SEGMENTS + 1)
    ]
    pieces = [
        [outer_line[index], outer_line[index + 1], inner_arc[index + 1], inner_arc[index]]
        for index in range(ACTIVE_SECTOR_ARC_SEGMENTS)
    ]
    pieces.append([outer_start, outer_before, inner_arc[0]])
    pieces.append([outer_end, inner_arc[-1], outer_after])
    return pieces


def direction_polygon_pieces() -> list[list[list[tuple[float, float]]]]:
    """Return four clockwise fields sharing one circular counter cutout."""
    # Blender +Y exports to Godot -Z, so this order remains top/right/bottom/left.
    # All four sectors use the same physical cutout radius. The earlier top and
    # bottom fields stopped at y=+/-0.20 while the side fields stopped at
    # x=+/-0.38, which let East/West red enamel show through the counter lens.
    corner_angle = SEPARATOR_CORNER_ANGLE_DEGREES
    upper_left_angle = 180.0 - corner_angle
    lower_left_angle = -180.0 + corner_angle
    return [
        sector_with_counter_cutout(
            (-1.025, 0.90),
            (1.025, 0.90),
            (-1.22, 0.705),
            (1.22, 0.705),
            upper_left_angle,
            corner_angle,
        ),
        sector_with_counter_cutout(
            (1.22, 0.705),
            (1.22, -0.705),
            (1.025, 0.90),
            (1.025, -0.90),
            corner_angle,
            -corner_angle,
        ),
        sector_with_counter_cutout(
            (1.025, -0.90),
            (-1.025, -0.90),
            (1.22, -0.705),
            (-1.22, -0.705),
            -corner_angle,
            lower_left_angle,
        ),
        sector_with_counter_cutout(
            (-1.22, -0.705),
            (-1.22, 0.705),
            (-1.025, -0.90),
            (-1.025, 0.90),
            lower_left_angle,
            -180.0 - corner_angle,
        ),
    ]


def build() -> list[bpy.types.Object]:
    # The complete insert intersects the felt plane instead of sitting on it.
    # Its highest authored surface is only 0.006 world units above the felt,
    # which is the anti-z-fighting allowance for a visually flush glass inlay.
    counter_bronze = make_material(
        "CenterCounterAntiqueBronze",
        "8F744B",
        metallic=0.56,
        roughness=0.44,
        coat=0.10,
        coat_roughness=0.22,
        anisotropic=0.08,
    )
    recess = make_material(
        "CenterGraphiteJadeRecess",
        "071F1B",
        metallic=0.12,
        roughness=0.38,
        coat=0.28,
        coat_roughness=0.16,
    )
    smoked_glass = make_material(
        "CenterGlossSmokedJadeGlass",
        "0A3A31",
        metallic=0.02,
        roughness=0.075,
        coat=1.0,
        coat_roughness=0.035,
        alpha=0.86,
        transmission=0.18,
    )
    exact_active_red = make_material(
        "CenterExactActiveRed",
        ACTIVE_RED_FILMIC_AUTHORING_HEX,
        metallic=0.0,
        roughness=0.50,
    )

    objects: list[bpy.types.Object] = [
        flat_polygon("CenterRecessBed", chamfered_outline(2.40, 1.76, 0.18), 0.002, recess),
        flat_polygon("CenterGlassInlay", chamfered_outline(2.40, 1.76, 0.18), 0.0040, smoked_glass),
        flat_line_segments(
            "DirectionSeparatorHairlines",
            [
                ((-SEPARATOR_INNER_X, SEPARATOR_INNER_Y), (-1.20, 0.70)),
                ((SEPARATOR_INNER_X, SEPARATOR_INNER_Y), (1.20, 0.70)),
                ((SEPARATOR_INNER_X, -SEPARATOR_INNER_Y), (1.20, -0.70)),
                ((-SEPARATOR_INNER_X, -SEPARATOR_INNER_Y), (-1.20, -0.70)),
            ],
            0.010,
            0.0044,
            recess,
        ),
    ]

    # Only the current seat reveals one opaque deep-wine lacquer field. It
    # reaches the outer boundary and sits above, rather than blending into, the
    # independent glass sector underneath.
    for index, polygon_pieces in enumerate(direction_polygon_pieces()):
        objects.append(
            flat_polygon_collection(
                f"DirectionActive{index}",
                polygon_pieces,
                0.005,
                exact_active_red,
            )
        )
    objects.extend([
        add_cylinder("CounterBronzeBezel", COUNTER_BEZEL_RADIUS, 0.001, 0.005, counter_bronze, vertices=40, bevel=0.0015),
        add_cylinder("CounterGlassLens", COUNTER_LENS_RADIUS, 0.003, 0.006, smoked_glass, vertices=40, bevel=0.001),
    ])
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
        [
            "python3",
            str(ROOT / "tools" / "3d" / "canonicalize_glb_images.py"),
            str(OUTPUT),
            "--unlit-material",
            "CenterExactActiveRed",
        ],
        check=True,
    )


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objects = build()
    export(objects)
    triangles = 0
    material_names: set[str] = set()
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        material_names.update(material.name for material in obj.data.materials)
    print(f"Generated {OUTPUT}")
    print(f"Object count: {len(objects)}")
    print(f"Material count: {len(material_names)}")
    print(f"Triangulated faces before exporter: {triangles}")


if __name__ == "__main__":
    main()
