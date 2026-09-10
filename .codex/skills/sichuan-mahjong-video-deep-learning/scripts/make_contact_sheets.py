#!/usr/bin/env python3
"""Build timestamp-labelled contact sheets for rapid visual timeline review."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frame_dir", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--cell-width", type=int, default=640)
    cfg = parser.parse_args()
    manifest = json.loads((cfg.frame_dir / "frames.json").read_text(encoding="utf-8"))
    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    sample = Image.open(cfg.frame_dir / manifest["frames"][0]["file"])
    cell_height = round(cfg.cell_width * sample.height / sample.width)
    label_height = 34
    per_sheet = cfg.columns * cfg.rows
    font = ImageFont.load_default(size=24)
    for sheet_index, offset in enumerate(range(0, len(manifest["frames"]), per_sheet), 1):
        sheet = Image.new("RGB", (cfg.columns * cfg.cell_width,
                                  cfg.rows * (cell_height + label_height)), "#111111")
        draw = ImageDraw.Draw(sheet)
        for slot, record in enumerate(manifest["frames"][offset:offset + per_sheet]):
            row, column = divmod(slot, cfg.columns)
            x = column * cfg.cell_width
            y = row * (cell_height + label_height)
            with Image.open(cfg.frame_dir / record["file"]) as frame:
                frame = frame.convert("RGB")
                frame.thumbnail((cfg.cell_width, cell_height), Image.Resampling.LANCZOS)
                sheet.paste(frame, (x, y))
            seconds = float(record["timestamp"])
            label = f"{int(seconds // 60):02d}:{seconds % 60:05.2f}  {record['file']}"
            draw.rectangle((x, y + cell_height, x + cfg.cell_width,
                            y + cell_height + label_height), fill="#111111")
            draw.text((x + 8, y + cell_height + 3), label, fill="white", font=font)
        path = cfg.output_dir / f"sheet_{sheet_index:03d}.jpg"
        sheet.save(path, quality=90)
    print(f"contact sheets: {sheet_index}")


if __name__ == "__main__":
    main()
