"""Canonicalise embedded GLB PNG payloads and JSON for byte-stable builds."""

from __future__ import annotations

import io
import json
import math
import struct
import argparse
from pathlib import Path

from PIL import Image


JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def canonical_png(payload: bytes) -> bytes:
    image = Image.open(io.BytesIO(payload))
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=False, compress_level=9)
    return output.getvalue()


def canonical_floats(payload: bytes) -> bytes:
    """Remove harmless exporter jitter below one hundred-thousandth.

    Blender's triangulation/export path can alternate UV components around a
    six-decimal rounding boundary between otherwise identical clean-process
    exports. Five decimal places are still far below a texel at the authored
    texture sizes while making the delivery artifact byte reproducible.
    """
    if len(payload) % 4:
        return payload
    values = struct.unpack("<%df" % (len(payload) // 4), payload)
    rounded = [round(value, 5) if math.isfinite(value) else value for value in values]
    return struct.pack("<%df" % len(rounded), *rounded)


def align4(data: bytearray, fill: int = 0) -> None:
    while len(data) % 4:
        data.append(fill)


def canonicalise(path: Path, unlit_materials: set[str] | None = None) -> None:
    raw = path.read_bytes()
    magic, version, _ = struct.unpack_from("<III", raw, 0)
    if magic != 0x46546C67 or version != 2:
        raise ValueError(f"Not a glTF 2 GLB: {path}")
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    if json_type != JSON_CHUNK:
        raise ValueError("GLB JSON chunk missing")
    json_start = 20
    document = json.loads(raw[json_start:json_start + json_length].decode("utf-8").rstrip(" \0"))
    requested_unlit_materials = unlit_materials or set()
    found_unlit_materials: set[str] = set()
    for material in document.get("materials", []):
        material_name = str(material.get("name", ""))
        if material_name not in requested_unlit_materials:
            continue
        material.setdefault("extensions", {})["KHR_materials_unlit"] = {}
        found_unlit_materials.add(material_name)
    missing_unlit_materials = requested_unlit_materials - found_unlit_materials
    if missing_unlit_materials:
        missing = ", ".join(sorted(missing_unlit_materials))
        raise ValueError(f"Requested unlit GLB materials were not found: {missing}")
    if found_unlit_materials:
        extensions_used = document.setdefault("extensionsUsed", [])
        if "KHR_materials_unlit" not in extensions_used:
            extensions_used.append("KHR_materials_unlit")
    bin_header = json_start + json_length
    bin_length, bin_type = struct.unpack_from("<II", raw, bin_header)
    if bin_type != BIN_CHUNK:
        raise ValueError("GLB BIN chunk missing")
    old_bin = raw[bin_header + 8:bin_header + 8 + bin_length]

    image_views = {int(image["bufferView"]) for image in document.get("images", []) if "bufferView" in image}
    float_views = {
        int(accessor["bufferView"])
        for accessor in document.get("accessors", [])
        if accessor.get("componentType") == 5126 and "bufferView" in accessor
    }
    views = document.get("bufferViews", [])
    order = sorted(range(len(views)), key=lambda index: int(views[index].get("byteOffset", 0)))
    new_bin = bytearray()
    for index in order:
        view = views[index]
        old_offset = int(view.get("byteOffset", 0))
        old_length = int(view["byteLength"])
        payload = old_bin[old_offset:old_offset + old_length]
        if index in image_views:
            payload = canonical_png(payload)
        elif index in float_views:
            payload = canonical_floats(payload)
        align4(new_bin)
        view["byteOffset"] = len(new_bin)
        view["byteLength"] = len(payload)
        new_bin.extend(payload)
    align4(new_bin)
    document["buffers"][0]["byteLength"] = len(new_bin)

    json_payload = json.dumps(document, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    json_bytes = bytearray(json_payload)
    align4(json_bytes, fill=0x20)
    total_length = 12 + 8 + len(json_bytes) + 8 + len(new_bin)
    result = bytearray(struct.pack("<III", magic, version, total_length))
    result.extend(struct.pack("<II", len(json_bytes), JSON_CHUNK))
    result.extend(json_bytes)
    result.extend(struct.pack("<II", len(new_bin), BIN_CHUNK))
    result.extend(new_bin)
    path.write_bytes(result)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--unlit-material", action="append", default=[])
    arguments = parser.parse_args()
    canonicalise(arguments.path, set(arguments.unlit_material))
