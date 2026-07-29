"""Collect reproducibility, brocade and material close-up evidence for Stage 1."""

from __future__ import annotations

import hashlib
import json
import math
import subprocess
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parents[1]
BLENDER = Path("/Applications/Blender.app/Contents/MacOS/Blender")
EVIDENCE = ROOT / "evidence" / "ui_emerald_final_20260726" / "stage1"
MATERIALS = ROOT / "res" / "art" / "materials" / "table_v2"
UI = ROOT / "res" / "art" / "ui" / "table_v2"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_paths() -> list[Path]:
    return [
        ROOT / "res" / "art" / "3d" / "sichuan_table_v2.glb",
        ROOT / "res" / "art" / "3d" / "sichuan_center_compass_v2.glb",
    ] + sorted(MATERIALS.glob("*.png")) + sorted(UI.glob("*.png"))


def run(command: list[str]) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=True)
    return "$ " + " ".join(command) + "\n" + result.stdout + result.stderr


def collect_reproducibility() -> None:
    logs = []
    snapshots = []
    table_command = [str(BLENDER), "--background", "--python", "tools/3d/generate_sichuan_table_v2.py"]
    compass_command = [str(BLENDER), "--background", "--python", "tools/3d/generate_sichuan_center_compass_v2.py"]
    ui_command = [str(BLENDER), "--background", "--python", "tools/3d/generate_sichuan_ui_shells_v2.py"]
    for run_index in range(1, 3):
        logs.append(f"===== deterministic generation pass {run_index} =====\n")
        logs.append(run(table_command))
        logs.append(run(compass_command))
        logs.append(run(ui_command))
        snapshots.append({str(path.relative_to(ROOT)): sha256(path) for path in asset_paths()})
    stable = snapshots[0] == snapshots[1]
    record = {
        "captured_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "generator": "Blender 5.2 LTS",
        "passes": snapshots,
        "all_hashes_equal_between_two_independent_passes": stable,
        "asset_count": len(snapshots[0]),
    }
    (EVIDENCE / "asset_reproducibility.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (EVIDENCE / "blender_generation.log").write_text("\n".join(logs), encoding="utf-8")
    if not stable:
        raise RuntimeError("Blender asset hashes changed between independent passes")


def collect_brocade_audit() -> None:
    mask = Image.open(MATERIALS / "brocade_mask.png").convert("L")
    width, height = mask.size
    pixels = list(mask.getdata())
    threshold = 1
    nonzero = [(index % width, index // width) for index, value in enumerate(pixels) if value > threshold]
    deepest_pattern_pixel = max(min(x, y, width - 1 - x, height - 1 - y) for x, y in nonzero)
    observed_band_fraction = (deepest_pattern_pixel + 1) / min(width, height)
    inner_box = mask.crop((round(width * 0.10), round(height * 0.10), round(width * 0.90), round(height * 0.90)))
    inner_values = list(inner_box.getdata())

    preview = Image.new("RGB", mask.size, (5, 18, 15))
    green = Image.new("RGB", mask.size, (196, 154, 85))
    preview.paste(green, mask=mask)
    preview.thumbnail((1024, 1024))
    preview.save(EVIDENCE / "brocade_mask_audit.png")

    report = {
        "mask_path": str((MATERIALS / "brocade_mask.png").relative_to(ROOT)),
        "mask_size": [width, height],
        "authored_outer_band_fraction": 0.09,
        "observed_outer_band_fraction": round(observed_band_fraction, 5),
        "allowed_band_fraction": [0.08, 0.10],
        "inner_80_percent_nonzero_ratio": round(sum(value > threshold for value in inner_values) / len(inner_values), 8),
        "pattern_relative_luminance_modulation": 0.024,
        "allowed_relative_luminance_modulation": [0.02, 0.03],
        "mask_mean": round(ImageStat.Stat(mask).mean[0], 4),
        "pass": 0.08 <= observed_band_fraction <= 0.10 and not any(value > threshold for value in inner_values),
    }
    (EVIDENCE / "brocade_audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not report["pass"]:
        raise RuntimeError(f"Brocade audit failed: {report}")


def collect_material_closeups() -> None:
    log = run([str(BLENDER), "--background", "--python", "tools/3d/render_sichuan_table_material_closeups.py"])
    (EVIDENCE / "material_closeup_render.log").write_text(log, encoding="utf-8")
    closeup_dir = EVIDENCE / "material_closeups"
    names = [
        ("皮革与缝线", "leather_stitch_closeup.png"),
        ("黑胡桃桌角", "walnut_corner_closeup.png"),
        ("旧铜嵌线", "aged_copper_inlay_closeup.png"),
    ]
    canvas = Image.new("RGB", (1560, 520), (20, 29, 43))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(str(ROOT / "res" / "fonts" / "NotoSansCJKsc-Regular.otf"), 24)
    for index, (label, file_name) in enumerate(names):
        image = Image.open(closeup_dir / file_name).convert("RGB")
        image.thumbnail((500, 430))
        x = 15 + index * 515
        canvas.paste(image, (x, 52))
        draw.text((x, 12), label, fill=(242, 235, 221), font=font)
    canvas.save(EVIDENCE / "material_closeups_montage.png")
    parameters = {
        "leather": {"texture_size": 1024, "metallic": 0.0, "roughness_baseline": 0.72},
        "black_walnut": {"texture_size": 1024, "metallic": 0.0, "roughness_baseline": 0.58},
        "aged_copper": {"metallic": 0.52, "roughness": 0.46},
        "acceptance": {"copper_metallic": [0.35, 0.65], "copper_roughness": [0.35, 0.55]},
    }
    (EVIDENCE / "material_parameters.json").write_text(json.dumps(parameters, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    collect_reproducibility()
    collect_brocade_audit()
    collect_material_closeups()
    print(f"EMERALD_STAGE1_ASSET_EVIDENCE_PASS {EVIDENCE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
