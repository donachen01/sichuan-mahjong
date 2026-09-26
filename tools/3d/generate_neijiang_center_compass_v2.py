"""Generate the Blender-authored single-ring four-way turn instrument.

The GLB owns all visible physical geometry and PBR materials. Godot keeps only
the live wall count plus visibility of the four authored signal-yellow active
sector overlays. This preserves turn state without rebuilding the manufactured
object from runtime flat meshes or adding direction glyphs.

Usage:
  Blender --background --python tools/3d/generate_neijiang_center_compass_v2.py
"""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "res" / "art" / "3d" / "neijiang_center_compass_v2.glb"
ACTIVE_YELLOW_TARGET_HEX = "F4C430"
ACTIVE_YELLOW_AUTHORING_HEX = "D9A514"
INACTIVE_JADE_TARGET_HEX = "3A644D"
INACTIVE_JADE_AUTHORING_HEX = "24483A"
COUNTER_RING_OUTER_RADIUS = 0.505
COUNTER_RING_INNER_RADIUS = 0.355
COUNTER_LENS_RADIUS = 0.340
PANEL_WIDTH_SCALE = 1.08
PANEL_DEPTH_SCALE = 0.96
# Keep every red face outside the physical bezel. The small allowance also
# keeps the straight chords between sampled arc points from crossing the ring.
ACTIVE_SECTOR_CUTOUT_RADIUS = COUNTER_RING_OUTER_RADIUS + 0.005
ACTIVE_SECTOR_ARC_SEGMENTS = 8
SEPARATOR_LINE_START_RADIUS = COUNTER_RING_OUTER_RADIUS - 0.06
# One coordinate system owns the physical field boundary, the signal-yellow
# inlay boundary and the pearl separator.  The former model used an approximate
# 0.38/0.20 separator ray beside a 1.22/0.705 plate ray; their divergence exposed
# a second dark bevel line inside one colour field on mobile.
SEPARATOR_CORNER_ANGLE_DEGREES = math.degrees(math.atan2(0.705, 1.22))


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


def extruded_polygon_collection(
    name: str,
    polygons: list[list[tuple[float, float]]],
    bottom: float,
    top: float,
    material: bpy.types.Material,
    *,
    bevel: float,
    bevel_segments: int = 3,
) -> bpy.types.Object:
    """Build a watertight plate around the circular counter cutout.

    The sector is tessellated for the hole, but every shared coordinate is
    welded before faces are authored. Boundary edges are detected once and
    receive one side wall each. This avoids Solidify's overlapping rims and the
    long black shading spikes those non-manifold rims produced in Godot.
    """
    point_indices: dict[tuple[float, float], int] = {}
    unique_points: list[tuple[float, float]] = []
    top_faces: list[tuple[int, ...]] = []
    edge_occurrences: dict[tuple[int, int], tuple[int, tuple[int, int]]] = {}
    for polygon in polygons:
        indices: list[int] = []
        for x, y in polygon:
            key = (round(x, 7), round(y, 7))
            if key not in point_indices:
                point_indices[key] = len(unique_points)
                unique_points.append((x, y))
            indices.append(point_indices[key])
        top_faces.append(tuple(indices))
        for index, start in enumerate(indices):
            end = indices[(index + 1) % len(indices)]
            edge_key = (min(start, end), max(start, end))
            count, oriented = edge_occurrences.get(edge_key, (0, (start, end)))
            edge_occurrences[edge_key] = (count + 1, oriented)

    point_count = len(unique_points)
    vertices = (
        [(x, y, top) for x, y in unique_points]
        + [(x, y, bottom) for x, y in unique_points]
    )
    faces: list[tuple[int, ...]] = list(top_faces)
    faces.extend(tuple(point_count + index for index in reversed(face)) for face in top_faces)
    for count, (start, end) in edge_occurrences.values():
        if count == 1:
            faces.append((start, end, point_count + end, point_count + start))

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if bevel > 0.0:
        bevel_object(obj, bevel, bevel_segments)
    # Planar caps remain flat; only the bevel/side band shares smooth normals.
    for polygon in obj.data.polygons:
        polygon.use_smooth = abs(polygon.normal.z) < 0.985
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


def add_annular_ring(
    name: str,
    outer_radius: float,
    inner_radius: float,
    bottom: float,
    top: float,
    material: bpy.types.Material,
    *,
    vertices: int = 96,
    bevel: float = 0.010,
) -> bpy.types.Object:
    """Build one genuinely hollow metal ring instead of stacked solid discs."""
    points: list[tuple[float, float, float]] = []
    for height in (bottom, top):
        for radius in (outer_radius, inner_radius):
            points.extend([
                (
                    math.cos(math.tau * index / vertices) * radius,
                    math.sin(math.tau * index / vertices) * radius,
                    height,
                )
                for index in range(vertices)
            ])
    outer_bottom = 0
    inner_bottom = vertices
    outer_top = vertices * 2
    inner_top = vertices * 3
    faces: list[tuple[int, ...]] = []
    for index in range(vertices):
        next_index = (index + 1) % vertices
        faces.extend([
            (outer_top + index, outer_top + next_index, inner_top + next_index, inner_top + index),
            (outer_bottom + next_index, outer_bottom + index, inner_bottom + index, inner_bottom + next_index),
            (outer_bottom + index, outer_bottom + next_index, outer_top + next_index, outer_top + index),
            (inner_bottom + next_index, inner_bottom + index, inner_top + index, inner_top + next_index),
        ])
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(points, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if bevel > 0.0:
        bevel_object(obj, bevel, 3)
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


def polar_point(radius: float, degrees: float) -> tuple[float, float]:
    return (
        math.cos(math.radians(degrees)) * radius,
        math.sin(math.radians(degrees)) * radius,
    )


def direction_panel_outline() -> list[tuple[float, float]]:
    """Return the single manufactured body shared by all four colour fields."""
    return [
        (-1.025, 0.90),
        (1.025, 0.90),
        (1.22, 0.705),
        (1.22, -0.705),
        (1.025, -0.90),
        (-1.025, -0.90),
        (-1.22, -0.705),
        (-1.22, 0.705),
    ]


def sector_with_counter_cutout(
    outer_start: tuple[float, float],
    outer_end: tuple[float, float],
    outer_before: tuple[float, float],
    outer_after: tuple[float, float],
    arc_start_degrees: float,
    arc_end_degrees: float,
    *,
    include_corner_wings: bool,
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
    # Only the top and bottom fields own the chamfered corner wings.  The old
    # shared helper also added those triangles to the left/right fields.  Their
    # tips crossed the diagonal separator rays, so a side player's yellow field
    # visibly swallowed the white separator and leaked into the neighbouring
    # colour region.  Side fields already span their complete outer edge and
    # must end exactly on the two corner-to-counter rays.
    if include_corner_wings:
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
            include_corner_wings=True,
        ),
        sector_with_counter_cutout(
            (1.22, 0.705),
            (1.22, -0.705),
            (1.025, 0.90),
            (1.025, -0.90),
            corner_angle,
            -corner_angle,
            include_corner_wings=False,
        ),
        sector_with_counter_cutout(
            (1.025, -0.90),
            (-1.025, -0.90),
            (1.22, -0.705),
            (-1.22, -0.705),
            -corner_angle,
            lower_left_angle,
            include_corner_wings=True,
        ),
        sector_with_counter_cutout(
            (-1.22, -0.705),
            (-1.22, 0.705),
            (-1.025, -0.90),
            (-1.025, 0.90),
            lower_left_angle,
            -180.0 - corner_angle,
            include_corner_wings=False,
        ),
    ]


def build() -> list[bpy.types.Object]:
    # The reference is deliberately simple: a shallow dark-jade instrument,
    # one unmistakably yellow active field and exactly one broad gold ring.
    counter_gold = make_material(
        "CenterSingleChampagneGoldRing",
        "E8CA78",
        metallic=0.42,
        roughness=0.18,
        coat=0.46,
        coat_roughness=0.075,
        anisotropic=0.08,
    )
    gold_edge = make_material(
        "CenterLowerGoldEdge",
        "D7A947",
        metallic=0.62,
        roughness=0.30,
        coat=0.16,
        coat_roughness=0.18,
    )
    recess = make_material(
        "CenterGraphiteJadeRecess",
        "2F5145",
        metallic=0.06,
        roughness=0.58,
        coat=0.12,
        coat_roughness=0.32,
    )
    dark_jade = make_material(
        "CenterDeepJadeLacquer",
        INACTIVE_JADE_AUTHORING_HEX,
        metallic=0.02,
        roughness=0.29,
        coat=0.42,
        coat_roughness=0.15,
        anisotropic=0.05,
        alpha=1.0,
        transmission=0.0,
    )
    matte_counter = make_material(
        "CenterMatteSmokedJadeCounter",
        "163B32",
        metallic=0.01,
        roughness=0.72,
        coat=0.0,
        alpha=1.0,
        transmission=0.0,
    )
    separator_light = make_material(
        "CenterSeparatorPearlLine",
        "B9C9B8",
        metallic=0.12,
        roughness=0.32,
        emission="667C6C",
        emission_strength=0.16,
    )
    active_yellow = make_material(
        "CenterActiveSignalYellow",
        ACTIVE_YELLOW_AUTHORING_HEX,
        metallic=0.0,
        roughness=0.31,
        coat=0.30,
        coat_roughness=0.15,
        emission="8C6A12",
        emission_strength=0.012,
    )

    objects: list[bpy.types.Object] = [
        add_chamfered_panel(
            "CenterLowerGoldTrim",
            2.43,
            1.79,
            0.19,
            -0.075,
            0.000,
            gold_edge,
            bevel=0.022,
        ),
        add_chamfered_panel(
            "CenterRecessBed",
            2.40,
            1.76,
            0.18,
            -0.055,
            0.018,
            recess,
            bevel=0.025,
        ),
    ]

    corner_angle = SEPARATOR_CORNER_ANGLE_DEGREES
    separator_angles = [
        180.0 - corner_angle,
        corner_angle,
        -corner_angle,
        -180.0 + corner_angle,
    ]
    separator_outer_points = [
        (-1.22, 0.705),
        (1.22, 0.705),
        (1.22, -0.705),
        (-1.22, -0.705),
    ]
    separator_segments = [
        (polar_point(SEPARATOR_LINE_START_RADIUS, angle), separator_outer_points[index])
        for index, angle in enumerate(separator_angles)
    ]
    for index, segment in enumerate(separator_segments):
        objects.append(
            flat_line_segments(
                f"DirectionSeparator{index}",
                [segment],
                0.013,
                0.0635,
                separator_light,
            )
        )

    # One continuous extruded body supplies the manufactured depth and outer
    # bevel. Internal fields are colour inlays, not four separately bevelled
    # solids; therefore no black physical seam can appear inside a colour field.
    objects.append(
        prism_from_outline(
            "DirectionBase0",
            direction_panel_outline(),
            0.020,
            0.060,
            dark_jade,
            bevel=0.012,
            bevel_segments=3,
        )
    )

    # Only the current seat reveals one clearly yellow lacquer field. These
    # top-only flush inlays share the exact boundary rays used by the pearl
    # separators; bevelled overlay edges previously created the extra dark line.
    for index, polygon_pieces in enumerate(direction_polygon_pieces()):
        objects.append(
            flat_polygon_collection(
                f"DirectionActive{index}",
                polygon_pieces,
                0.0615,
                active_yellow,
            )
        )
    objects.extend([
        add_annular_ring(
            "CounterSingleGoldRing",
            COUNTER_RING_OUTER_RADIUS,
            COUNTER_RING_INNER_RADIUS,
            0.058,
            0.126,
            counter_gold,
            vertices=96,
            bevel=0.012,
        ),
        add_cylinder("CounterNumberPlate", COUNTER_LENS_RADIUS, 0.062, 0.112, matte_counter, vertices=96, bevel=0.008),
    ])
    # The target body is a wide, shallow instrument while its counter remains
    # truly circular. Scale only the body/fields here so the dial is not
    # distorted into an ellipse by a runtime node transform.
    for obj in objects:
        if obj.name.startswith("Counter"):
            continue
        obj.scale.x = PANEL_WIDTH_SCALE
        obj.scale.y = PANEL_DEPTH_SCALE
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.select_set(False)
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
