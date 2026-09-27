#!/usr/bin/env python3
"""Read-only inventory of literal runtime references, GLB images and large duplicates.

Dynamic resource paths, reflection, native libraries and importer-generated texture
references need their owning module checked as well; this is not a reachability proof.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOTS = ('autoload', 'scripts', 'scenes', 'shaders', 'tools', 'tests/current')
SOURCE_SUFFIXES = {'.gd', '.cs', '.tscn', '.tres', '.gdshader', '.py', '.sh'}
RESOURCE = re.compile(r'''["'](res://[^"'\n]+)["']''')


def glb_document(path: Path) -> dict:
    raw = path.read_bytes()
    magic, version, length, json_length, json_type = struct.unpack_from('<IIIII', raw)
    if magic != 0x46546C67 or version != 2 or length != len(raw) or json_type != 0x4E4F534A:
        raise ValueError(f'invalid GLB: {path}')
    return json.loads(raw[20:20 + json_length].decode().rstrip(' \0'))


def inventory() -> dict:
    refs = defaultdict(list)
    sources = [ROOT / 'project.godot', ROOT / 'export_presets.cfg']
    for directory in SOURCE_ROOTS:
        sources.extend(p for p in (ROOT / directory).rglob('*')
                       if p.is_file() and p.suffix in SOURCE_SUFFIXES
                       and not any(part in {'bin', 'obj', '.build', '__pycache__'} for part in p.parts))
    for source in sorted(sources):
        if not source.exists():
            continue
        for line_no, line in enumerate(source.read_text(errors='replace').splitlines(), 1):
            if line.lstrip().startswith(('#', '//')):
                continue
            for ref in RESOURCE.findall(line):
                if any(mark in ref for mark in ('%', '{', '*')) or ref.endswith('/'):
                    continue
                refs[ref].append(f'{source.relative_to(ROOT)}:{line_no}')
    missing = {ref: sites for ref, sites in refs.items() if not (ROOT / ref[6:]).exists()}
    duplicates = defaultdict(list)
    for directory in ('res/art', 'res/audio', 'source_assets'):
        for path in (ROOT / directory).rglob('*'):
            if path.is_file() and path.suffix not in {'.import', '.uid'} and path.stat().st_size >= 100_000:
                duplicates[(path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest())].append(str(path.relative_to(ROOT)))
    duplicate_groups = [{'bytes_per_file': size, 'sha256': digest, 'paths': paths}
                        for (size, digest), paths in duplicates.items() if len(paths) > 1]
    models = {}
    for path in sorted((ROOT / 'res/art/3d').glob('*.glb')):
        document = glb_document(path)
        models[str(path.relative_to(ROOT))] = {
            'nodes': [node.get('name', '') for node in document.get('nodes', [])],
            'external_images': [image['uri'] for image in document.get('images', []) if 'uri' in image],
            'embedded_images': sum('bufferView' in image for image in document.get('images', [])),
        }
    return {'scope': 'literal references only; includes test and tool dependencies',
            'references': dict(sorted(refs.items())), 'missing_literal_paths': missing,
            'large_duplicate_groups': duplicate_groups, 'models': models}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = inventory()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'references': len(report['references']),
                      'missing_literal_paths': report['missing_literal_paths'],
                      'duplicate_groups': len(report['large_duplicate_groups'])}, ensure_ascii=False))


if __name__ == '__main__':
    main()
