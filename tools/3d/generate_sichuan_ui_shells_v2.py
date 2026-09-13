"""Generate transparent orthographic UI shells for the Deep Emerald table.

Blender owns the lacquer/copper material response and bevel lighting. Godot
keeps all text, data, layout, state and touch handling. The generated PNGs are
therefore decorative nine-patch/style-box inputs rather than rasterised UI.

Usage:
  Blender --background --python tools/3d/generate_sichuan_ui_shells_v2.py
"""

from __future__ import annotations

import math
import struct
import sys
import zlib
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "res" / "art" / "ui" / "table_v2"
SOURCE_DIR = ROOT / "source_assets" / "ui" / "settlement"

PANEL_JADE = "102F29"
PANEL_INNER = "09211C"
AGED_COPPER = "9D743A"
COPPER_HIGHLIGHT = "C49A55"
HU = "B84236"
GANG = "6F542D"
PENG = "2C9B8A"
PASS = "53645E"
SKIN_BADGES = {
    "deep_emerald_crepe": ("3E6654", "F6E8CF", 0.90),
    "emerald_linen": ("416B56", "F4E5CE", 0.94),
    "warm_caban_velvet": ("4C6856", "F8E2C2", 0.96),
    "black_gold_jacquard": ("2E443B", "F7DDB8", 0.92),
    "champagne_satin": ("70644A", "FFF0D2", 0.86),
    "teal_teddy_check": ("385D64", "E7E2D1", 0.98),
}
DING_QUE = {
    "tiao": ("176F58", "32B485"),
    "tong": ("8A6325", "D2A33E"),
    "wan": ("82332D", "C55145"),
}


def srgb_channel_to_linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def color(hex_value: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    rgb = tuple(int(hex_value[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    return tuple(srgb_channel_to_linear(value) for value in rgb) + (alpha,)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.materials, bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(collection):
            collection.remove(item)


def material(name: str, hex_value: str, metallic: float, roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color(hex_value)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color(hex_value)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


def table_fabric_material(name: str, skin_id: str, tint_hex: str, roughness: float) -> bpy.types.Material:
    """Use the exact selected tabletop albedo as a round action-badge face."""
    image_path = ROOT / "res" / "art" / "materials" / "table_skins" / skin_id / "albedo_2k.jpg"
    image = bpy.data.images.load(str(image_path), check_existing=True)
    mat = material(name, tint_hex, 0.0, roughness)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    tex_coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.65, 1.65, 1.0)
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    tint = nodes.new("ShaderNodeRGB")
    tint.outputs[0].default_value = color(tint_hex)
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs[0].default_value = 0.82
    shader = nodes.get("Principled BSDF")
    links.new(tex_coord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], texture.inputs["Vector"])
    links.new(tint.outputs[0], multiply.inputs[1])
    links.new(texture.outputs["Color"], multiply.inputs[2])
    links.new(multiply.outputs[0], shader.inputs["Base Color"])
    return mat


def cut_corner_prism(
    name: str,
    width: float,
    height: float,
    cut: float,
    depth: float,
    z: float,
    mat: bpy.types.Material,
    bevel: float,
) -> bpy.types.Object:
    x = width * 0.5
    y = height * 0.5
    points = [
        (-x + cut, -y), (x - cut, -y), (x, -y + cut), (x, y - cut),
        (x - cut, y), (-x + cut, y), (-x, y - cut), (-x, -y + cut),
    ]
    vertices = [(px, py, z - depth * 0.5) for px, py in points] + [(px, py, z + depth * 0.5) for px, py in points]
    faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
    for index in range(8):
        nxt = (index + 1) % 8
        faces.append((index, nxt, nxt + 8, index + 8))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bevel_modifier = obj.modifiers.new("SoftMachinedBevel", "BEVEL")
    bevel_modifier.width = bevel
    bevel_modifier.segments = 4
    return obj


def cylinder(
    name: str,
    radius: float,
    depth: float,
    z: float,
    mat: bpy.types.Material,
    bevel: float,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=radius, depth=depth, location=(0.0, 0.0, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("SealBevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 4
    return obj


def add_camera_and_lights(ortho_scale: float) -> None:
    bpy.ops.object.camera_add(location=(0.0, -0.10, 8.0))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    camera.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(-3.6, 4.2, 7.0))
    key = bpy.context.object
    key.data.energy = 700.0
    key.data.color = (1.0, 0.91, 0.72)
    key.data.shape = "DISK"
    key.data.size = 5.0

    bpy.ops.object.light_add(type="AREA", location=(3.7, -2.4, 4.0))
    fill = bpy.context.object
    fill.data.energy = 330.0
    fill.data.color = (0.55, 0.84, 0.78)
    fill.data.size = 4.0


def configure_render(width: int, height: int, output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(output)
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.resolution_percentage = 100
    if scene.world is None:
        scene.world = bpy.data.worlds.new("TransparentUIWorld")
    scene.world.color = (0.012, 0.018, 0.016)


def strip_png_text_chunks(path: Path) -> None:
    """Remove Blender timestamp/software text while preserving pixel bytes."""
    raw = path.read_bytes()
    result = bytearray(raw[:8])
    offset = 8
    while offset < len(raw):
        length = struct.unpack(">I", raw[offset:offset + 4])[0]
        chunk_type = raw[offset + 4:offset + 8]
        payload = raw[offset + 8:offset + 8 + length]
        offset += 12 + length
        if chunk_type == b"tEXt":
            continue
        result.extend(struct.pack(">I", length))
        result.extend(chunk_type)
        result.extend(payload)
        result.extend(struct.pack(">I", zlib.crc32(chunk_type + payload) & 0xFFFFFFFF))
    path.write_bytes(result)


def render_hud_shell() -> None:
    reset_scene()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    shadow = material("HUDShadow", "020806", 0.0, 0.92)
    copper = material("HUDAgedCopper", AGED_COPPER, 0.52, 0.46)
    highlight = material("HUDCopperHighlight", COPPER_HIGHLIGHT, 0.42, 0.40)
    jade = material("HUDInkJadeLacquer", PANEL_JADE, 0.08, 0.56)
    inner = material("HUDInsetJade", PANEL_INNER, 0.03, 0.72)
    cut_corner_prism("Shadow", 7.70, 4.48, 0.34, 0.14, -0.12, shadow, 0.10)
    cut_corner_prism("CopperOuter", 7.48, 4.28, 0.31, 0.18, 0.00, copper, 0.09)
    cut_corner_prism("JadeBody", 7.31, 4.11, 0.27, 0.18, 0.13, jade, 0.08)
    cut_corner_prism("InsetWell", 6.93, 3.73, 0.22, 0.10, 0.25, inner, 0.055)
    # Thin top and bottom reliefs preserve a crafted silhouette after nine-patch scaling.
    cut_corner_prism("TopRelief", 6.20, 0.13, 0.04, 0.04, 0.34, highlight, 0.02).location.y = 1.53
    cut_corner_prism("BottomRelief", 5.50, 0.08, 0.03, 0.04, 0.34, copper, 0.015).location.y = -1.54
    # Blender's orthographic scale is the horizontal span for this camera;
    # 8.4 keeps the full cut-corner silhouette inside the 16:10 frame.
    add_camera_and_lights(ortho_scale=8.40)
    output = OUTPUT_DIR / "hud_shell.png"
    configure_render(768, 480, output)
    bpy.ops.render.render(write_still=True)
    strip_png_text_chunks(output)


def render_settlement_panel() -> None:
    """Render the editable, text-free nine-slice shell for the rich ledger."""
    reset_scene()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    shadow = material("SettlementShadow", "010705", 0.0, 0.94)
    outer_copper = material("SettlementAgedCopper", AGED_COPPER, 0.58, 0.42)
    highlight = material("SettlementCopperHighlight", COPPER_HIGHLIGHT, 0.45, 0.38)
    jade = material("SettlementDeepEmeraldLacquer", "0A4B41", 0.10, 0.58)
    ink = material("SettlementInkJadeWell", "061E19", 0.03, 0.76)
    cut_corner_prism("SettlementShadow", 8.32, 5.15, 0.38, 0.15, -0.15, shadow, 0.12).location += Vector((0.10, -0.12, 0.0))
    cut_corner_prism("SettlementCopperFrame", 8.12, 4.95, 0.36, 0.18, -0.01, outer_copper, 0.10)
    cut_corner_prism("SettlementJadeBody", 7.92, 4.75, 0.32, 0.20, 0.13, jade, 0.09)
    cut_corner_prism("SettlementHighlightKeyline", 7.66, 4.49, 0.29, 0.075, 0.27, highlight, 0.045)
    cut_corner_prism("SettlementInkWell", 7.54, 4.37, 0.26, 0.10, 0.35, ink, 0.055)
    # Corner rivets survive nine-slice scaling and make the old-copper frame
    # visibly authored without baking any state, copy or score into the asset.
    for index, (x, y) in enumerate(((-3.58, -2.05), (3.58, -2.05), (-3.58, 2.05), (3.58, 2.05))):
        rivet = cylinder(f"SettlementRivet{index}", 0.085, 0.055, 0.43, highlight, 0.022)
        rivet.location.x = x
        rivet.location.y = y
    add_camera_and_lights(ortho_scale=8.85)
    output = OUTPUT_DIR / "settlement_panel_9slice.png"
    configure_render(1024, 640, output)
    bpy.ops.render.render(write_still=True)
    strip_png_text_chunks(output)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "settlement_panel_9slice.blend"), check_existing=False)


def render_action_seal(action: str, hex_value: str) -> None:
    reset_scene()
    shadow = material(f"{action}Shadow", "020806", 0.0, 0.94)
    copper = material(f"{action}Copper", AGED_COPPER, 0.56, 0.42)
    highlight = material(f"{action}Highlight", COPPER_HIGHLIGHT, 0.44, 0.38)
    body = material(f"{action}Body", hex_value, 0.10, 0.48)
    inner_hex = {
        "hu": "D15749", "gang": "896A36", "peng": "36AF9B", "pass": "647972",
    }[action]
    inner = material(f"{action}Inner", inner_hex, 0.06, 0.55)
    cylinder("Shadow", 2.08, 0.13, -0.13, shadow, 0.08).location += Vector((0.10, -0.12, 0.0))
    cylinder("CopperOuter", 2.00, 0.18, 0.00, copper, 0.08)
    cylinder("ActionBody", 1.82, 0.20, 0.13, body, 0.07)
    cylinder("CopperRing", 1.58, 0.10, 0.25, highlight, 0.045)
    cylinder("InnerSeal", 1.50, 0.11, 0.33, inner, 0.045)
    add_camera_and_lights(ortho_scale=4.75)
    output = OUTPUT_DIR / f"action_{action}.png"
    configure_render(384, 384, output)
    bpy.ops.render.render(write_still=True)
    strip_png_text_chunks(output)


def render_skin_action_badge(skin_id: str, palette: tuple[str, str, float]) -> None:
    """Render one minimal, text-free decision badge for one tabletop skin.

    The asset deliberately contains only a fabric face and a single aged-copper
    rim. Godot supplies the live 碰/杠/胡/取消 word, focus state and pressed
    motion, so there is no repeated inner circle or baked state decoration.
    """
    reset_scene()
    tint_hex, _light_hex, roughness = palette
    skin_dir = ROOT / "res" / "art" / "materials" / "table_skins" / skin_id
    skin_dir.mkdir(parents=True, exist_ok=True)
    shadow = material(f"{skin_id}BadgeShadow", "020806", 0.0, 0.94)
    copper = material(f"{skin_id}BadgeCopper", AGED_COPPER, 0.62, 0.34)
    fabric = table_fabric_material(f"{skin_id}BadgeFabric", skin_id, tint_hex, roughness)
    cylinder("BadgeShadow", 2.10, 0.14, -0.13, shadow, 0.09).location += Vector((0.10, -0.12, 0.0))
    cylinder("BadgeCopperRim", 1.98, 0.19, 0.00, copper, 0.075)
    cylinder("BadgeFabricFace", 1.80, 0.18, 0.14, fabric, 0.065)
    add_camera_and_lights(ortho_scale=4.75)
    output = skin_dir / "action_badge.png"
    configure_render(512, 512, output)
    bpy.ops.render.render(write_still=True)
    strip_png_text_chunks(output)


def render_ding_que_seal(suit: str, palette: tuple[str, str]) -> None:
    """Render a text-free jade seal while Godot retains the live label/touch."""
    reset_scene()
    deep_hex, light_hex = palette
    shadow = material(f"{suit}QueShadow", "020806", 0.0, 0.94)
    copper = material(f"{suit}QueCopper", AGED_COPPER, 0.54, 0.44)
    rim = material(f"{suit}QueIvoryRim", "E9DEC1", 0.08, 0.42)
    body = material(f"{suit}QueBody", deep_hex, 0.08, 0.54)
    inset = material(f"{suit}QueInset", light_hex, 0.05, 0.60)
    cylinder("Shadow", 2.17, 0.14, -0.15, shadow, 0.09).location += Vector((0.12, -0.15, 0.0))
    cylinder("CopperFoot", 2.07, 0.18, -0.01, copper, 0.08)
    cylinder("IvoryOuterRim", 1.98, 0.16, 0.10, rim, 0.065)
    cylinder("JadeBody", 1.89, 0.22, 0.23, body, 0.075)
    cylinder("CopperKeyline", 1.61, 0.08, 0.36, copper, 0.04)
    cylinder("InsetSeal", 1.53, 0.11, 0.41, inset, 0.045)
    add_camera_and_lights(ortho_scale=4.95)
    output = OUTPUT_DIR / f"ding_que_{suit}.png"
    configure_render(384, 384, output)
    bpy.ops.render.render(write_still=True)
    strip_png_text_chunks(output)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if "--settlement-only" in sys.argv:
        render_settlement_panel()
        print(f"Generated settlement nine-slice in {OUTPUT_DIR}")
        return
    if "--ding-que-only" in sys.argv:
        for suit, palette in DING_QUE.items():
            render_ding_que_seal(suit, palette)
        print(f"Generated dot-free ding-que seals in {OUTPUT_DIR}")
        return
    render_hud_shell()
    for action, hex_value in (("hu", HU), ("gang", GANG), ("peng", PENG), ("pass", PASS)):
        render_action_seal(action, hex_value)
    for skin_id, palette in SKIN_BADGES.items():
        render_skin_action_badge(skin_id, palette)
    for suit, palette in DING_QUE.items():
        render_ding_que_seal(suit, palette)
    render_settlement_panel()
    print(f"Generated Deep Emerald UI shells in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
