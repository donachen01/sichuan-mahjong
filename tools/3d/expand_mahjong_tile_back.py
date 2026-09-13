#!/usr/bin/env python3
"""Expand the generated GLB back mesh to the shared 3mm ivory lip contract.

Blender is the source generator, but release machines may not have Blender
installed. This deterministic maintenance utility updates only the first GLB
mesh (MahjongTileBack) vertices and its POSITION bounds; it does not alter the
body mesh, materials, node transforms, or the shared 0.42x0.24x0.58 dimensions.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
GLB_PATH = PROJECT_ROOT / "res/art/3d/mahjong_tile_body.glb"
GLB_MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
TARGET_SIZE_X = 0.42 - 0.006
TARGET_SIZE_Z = 0.58 - 0.006
OLD_SIZE_X = 0.42 - 0.018
OLD_SIZE_Z = 0.58 - 0.018


def main() -> None:
    payload = bytearray(GLB_PATH.read_bytes())
    magic, version, declared_length = struct.unpack_from("<4sII", payload, 0)
    if magic != GLB_MAGIC or version != 2 or declared_length != len(payload):
        raise SystemExit("unexpected GLB header")

    offset = 12
    json_start = json_end = bin_start = bin_end = -1
    document: dict = {}
    while offset < len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, offset)
        data_start = offset + 8
        data_end = data_start + chunk_length
        if chunk_type == JSON_CHUNK:
            json_start, json_end = data_start, data_end
            document = json.loads(payload[data_start:data_end].rstrip(b" \t\r\n\0"))
        elif chunk_type == BIN_CHUNK:
            bin_start, bin_end = data_start, data_end
        offset = data_end
    if json_start < 0 or bin_start < 0:
        raise SystemExit("GLB is missing JSON or BIN chunk")

    position_accessor = document["meshes"][0]["primitives"][0]["attributes"]["POSITION"]
    accessor = document["accessors"][position_accessor]
    if accessor["type"] != "VEC3" or accessor["componentType"] != 5126:
        raise SystemExit("back POSITION accessor is not float32 VEC3")
    view = document["bufferViews"][accessor["bufferView"]]
    start = bin_start + int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    stride = int(view.get("byteStride", 12))
    if stride < 12:
        raise SystemExit("invalid back POSITION stride")

    scale_x = TARGET_SIZE_X / OLD_SIZE_X
    scale_z = TARGET_SIZE_Z / OLD_SIZE_Z
    min_x = min_z = float("inf")
    max_x = max_z = float("-inf")
    for index in range(int(accessor["count"])):
        vertex_offset = start + index * stride
        x, y, z = struct.unpack_from("<3f", payload, vertex_offset)
        x *= scale_x
        z *= scale_z
        struct.pack_into("<3f", payload, vertex_offset, x, y, z)
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_z = min(min_z, z)
        max_z = max(max_z, z)

    accessor["min"] = [min_x, float(accessor["min"][1]), min_z]
    accessor["max"] = [max_x, float(accessor["max"][1]), max_z]
    json_bytes = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_capacity = json_end - json_start
    if len(json_bytes) > json_capacity:
        raise SystemExit("updated GLB JSON no longer fits its fixed chunk")
    payload[json_start:json_end] = json_bytes + b" " * (json_capacity - len(json_bytes))
    GLB_PATH.write_bytes(payload)
    print(f"expanded MahjongTileBack to {TARGET_SIZE_X:.3f} x {TARGET_SIZE_Z:.3f}")


if __name__ == "__main__":
    main()
