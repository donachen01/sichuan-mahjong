"""Export the approved native Blender table to a review destination.

Blender --background --python tools/3d/generate_current_table.py -- --output PATH
The approved .blend owns geometry and base materials. Godot owns final materials,
lighting and the selected skin. This entry never overwrites the live GLB implicitly.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
import struct
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'source_assets/table/launch_glass_v1/launch_glass_table_review.blend'
NODES = ('TableWalnutBase', 'TableFelt', 'WalnutApronRing', 'SingleClearGlassCap',
         'InnerGlassEdge', 'RaisedTransparentGlassLip')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    output = args.output.expanduser().resolve()
    if output == (ROOT / 'res/art/3d/sichuan_table_v2.glb').resolve():
        raise ValueError('Export to a review path, inspect the result, then install it separately.')
    if output.suffix != '.glb':
        raise ValueError('Output must be a .glb file.')
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    missing = [name for name in NODES if bpy.data.objects.get(name) is None]
    if missing:
        raise ValueError(f'Approved source is missing table nodes: {missing}')
    spec = importlib.util.spec_from_file_location('table_geometry', Path(__file__).with_name('generate_sichuan_table_v2.py'))
    geometry = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(geometry)
    geometry.OUTPUT_GLB = output
    geometry.export_glb([bpy.data.objects[name] for name in NODES])
    raw = output.read_bytes()
    json_length = struct.unpack_from('<I', raw, 12)[0]
    document = json.loads(raw[20:20 + json_length].decode().rstrip(' \0'))
    exported = {node.get('name') for node in document.get('nodes', [])}
    if set(NODES) != exported:
        raise ValueError(f'Exported node contract changed: {exported}')
    if any('uri' in image for image in document.get('images', [])):
        raise ValueError('Current-table export must embed its images.')
    print(f'CURRENT_TABLE_EXPORT_OK {output}')


if __name__ == '__main__':
    main()
