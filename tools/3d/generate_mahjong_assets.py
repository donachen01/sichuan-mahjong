"""Generate deterministic Sichuan Mahjong GLB assets with Blender.

Run with:
    blender --background --python tools/3d/generate_mahjong_assets.py

The generated meshes are intentionally small and exact.  They replace paid
text-to-3D generation for the core gameplay pieces, whose dimensions and
origins must remain stable for interaction and layout tests.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "res" / "art" / "3d"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], roughness: float, metallic: float = 0.0):
    value = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    value.diffuse_color = color
    value.use_nodes = True
    shader = next(
        (node for node in value.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
        None,
    )
    if shader is None:
        shader = value.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        output = next(
            (node for node in value.node_tree.nodes if node.type == "OUTPUT_MATERIAL"),
            value.node_tree.nodes.new("ShaderNodeOutputMaterial"),
        )
        value.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return value


def rounded_box(
    name: str,
    size: tuple[float, float, float],
    location: tuple[float, float, float],
    bevel: float,
    bevel_segments: int,
    box_material,
):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = size
    # 关键：把 location 一并烘进顶点(location=True)。否则两块几何都居中在原点、
    # 只是对象原点不同，glTF 导出后堆叠偏移丢失，导致象牙块与绿块同心嵌套、
    # 四周侧面 z-fighting 渗出绿边。烘进顶点后两块沿 Z 真正分离。
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    modifier = obj.modifiers.new(name="ManufacturedBevel", type="BEVEL")
    modifier.width = bevel
    modifier.segments = bevel_segments
    modifier.profile = 0.64
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(25.0)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(box_material)
    return obj


def carve_face_well(
    body,
    well_size: tuple[float, float, float],
    well_top_z: float,
):
    """在牌体顶面布尔挖出一个浅凹槽，形成"凸起象牙边框 + 内凹符号区"的层次。

    well_top_z 应略高于牌体顶面，保证凹槽完全切穿顶面留出边框；凹槽深度由
    well_size 的 Z 决定。使用 EXACT 布尔求解器保持确定性。"""
    bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, well_top_z))
    cutter = bpy.context.active_object
    cutter.name = "FaceWellCutter"
    cutter.dimensions = well_size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # 凹槽内边缘做一点小倒角，避免硬直角、更接近注塑牌面。
    edge = cutter.modifiers.new(name="WellEdge", type="BEVEL")
    edge.width = 0.008
    edge.segments = 2
    edge.limit_method = "ANGLE"
    edge.angle_limit = math.radians(25.0)
    bpy.context.view_layer.objects.active = cutter
    bpy.ops.object.modifier_apply(modifier=edge.name)

    boolean = body.modifiers.new(name="FaceWell", type="BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    for polygon in body.data.polygons:
        polygon.use_smooth = True
    return body


def export_selected(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )


def generate_tile_body() -> None:
    """分层牌体：圆润玉白牌身 + 背面翡翠绿层。

    目标是让每张牌读起来是一块圆润、光滑、微透的玉石注塑体，而不是“白色直角
    边框+内凹贴片”。符号由 Godot 的透明印刷层直接落在圆润顶面；牌身背面保留独立
    翡翠绿层。整体外框尺寸统一为 0.42×0.58×0.24。旧 0.18 厚度在远端平扣、
    手机宽屏透视下只剩几像素，牌身会读成纸片；这里直接加厚唯一的实体模型，
    立牌、平扣牌、弃牌和副露继续共享同一几何，不按姿态做非等比缩放。Blender
    为 Z-up，glTF 导出转 Godot Y-up。"""
    clear_scene()
    ivory = material("WarmIvoryJade", (0.90, 0.88, 0.84, 1.0), roughness=0.25)
    jade_back = material("JadeBack", (0.035, 0.46, 0.12, 1.0), roughness=0.28, metallic=0.01)

    # 商业参考的层次不是“白色平面贴在绿砖上”，而是完整的象牙注塑主体，
    # 背面再嵌一层翡翠绿树脂。目标图的平牌侧面约三分之一为绿色背层；旧值
    # 仅占 16%，在手机上缩成一根绿色细线，层次明显不足。
    # 绿背层继续占总厚度约 30.8%，避免只加厚象牙牌身后破坏既有分层比例。
    back_thickness = 0.074
    body_bottom = back_thickness
    body_top = 0.24
    body_thickness = body_top - body_bottom
    body_center_z = (body_bottom + body_top) * 0.5

    # 玉白主牌身：0.032 圆角 + 8 段曲面。旧 0.046 会让相邻两牌的倒角叠成
    # 粗白框；缩窄倒角后仍有连续圆润高光，但牌面有效面积更接近目标图。
    tile = rounded_box(
        name="MahjongTileBody",
        size=(0.42, 0.58, body_thickness),
        location=(0.0, 0.0, body_center_z),
        bevel=0.032,
        bevel_segments=8,
        box_material=ivory,
    )

    # 翡翠绿背：薄薄一层贴在反面，宽度略窄于牌身(内缩 0.018)使象牙侧面在四周
    # 连续露出，读起来是"象牙牌身、背面镀了层绿"，而不是绿块。
    back = rounded_box(
        name="MahjongTileBack",
        size=(0.42 - 0.018, 0.58 - 0.018, back_thickness),
        location=(0.0, 0.0, back_thickness * 0.5),
        bevel=0.018,
        bevel_segments=6,
        box_material=jade_back,
    )

    bpy.ops.object.select_all(action="DESELECT")
    tile.select_set(True)
    back.select_set(True)
    export_selected(OUTPUT_DIR / "mahjong_tile_body.glb")


def generate_table() -> None:
    clear_scene()
    felt = material("InkJadeFelt", (0.012, 0.105, 0.082, 1.0), roughness=0.86)
    wood = material("BlackWalnut", (0.055, 0.035, 0.024, 1.0), roughness=0.48)
    brass = material("AgedBrass", (0.43, 0.27, 0.10, 1.0), roughness=0.39, metallic=0.82)

    objects = [
        rounded_box("TableFrame", (14.8, 9.6, 0.56), (0.0, 0.0, -0.30), 0.30, 4, wood),
        rounded_box("TableFelt", (13.9, 8.7, 0.34), (0.0, 0.0, -0.14), 0.20, 4, felt),
        rounded_box("CopperTop", (13.95, 0.035, 0.025), (0.0, -4.35, 0.045), 0.012, 2, brass),
        rounded_box("CopperBottom", (13.95, 0.035, 0.025), (0.0, 4.35, 0.045), 0.012, 2, brass),
        rounded_box("CopperLeft", (0.035, 8.7, 0.025), (-6.95, 0.0, 0.045), 0.012, 2, brass),
        rounded_box("CopperRight", (0.035, 8.7, 0.025), (6.95, 0.0, 0.045), 0.012, 2, brass),
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    export_selected(OUTPUT_DIR / "sichuan_table.glb")


if __name__ == "__main__":
    generate_tile_body()
    generate_table()
    print(f"Generated Mahjong 3D kit in {OUTPUT_DIR}")
