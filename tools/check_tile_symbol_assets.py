#!/usr/bin/env python3
"""Validate the 27 generated Mahjong glyph assets and their import settings."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SYMBOL_DIR = ROOT / "res/art/ui_3d_cartoon/tile_symbols"


def main() -> int:
    failures: list[str] = []
    reports: list[dict[str, object]] = []
    paths = sorted(SYMBOL_DIR.glob("*.png"))
    if len(paths) != 27:
        failures.append(f"expected 27 symbols, found {len(paths)}")

    for path in paths:
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
            bbox = rgba.getchannel("A").getbbox()
            if bbox is None:
                failures.append(f"{path.name}: empty alpha")
                continue
            width_ratio = (bbox[2] - bbox[0]) / rgba.width
            height_ratio = (bbox[3] - bbox[1]) / rgba.height
        minimum_height = 0.48 if path.stem == "tong_1" else 0.54
        if height_ratio < minimum_height:
            failures.append(f"{path.name}: height ratio {height_ratio:.3f} < {minimum_height:.2f}")
        if width_ratio < 0.42 and path.stem != "tiao_2":
            failures.append(f"{path.name}: width ratio {width_ratio:.3f} < 0.42")

        import_path = path.with_suffix(path.suffix + ".import")
        import_text = import_path.read_text(encoding="utf-8") if import_path.is_file() else ""
        has_mipmaps = "mipmaps/generate=true" in import_text
        if not has_mipmaps:
            failures.append(f"{path.name}: mipmaps are not enabled")
        reports.append(
            {
                "file": path.name,
                "width_ratio": round(width_ratio, 4),
                "height_ratio": round(height_ratio, 4),
                "mipmaps": has_mipmaps,
            }
        )

    output = {
        "symbol_count": len(paths),
        "symbols": reports,
        "failures": failures,
        "passed": not failures,
    }
    report_path = ROOT / "evidence/ui_tile_quality_20260718/final/symbol_asset_report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
