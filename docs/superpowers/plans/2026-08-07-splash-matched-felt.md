# Splash-Matched Felt Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the directional, cyan-leaning gameplay felt with deterministic warm-green multi-direction short-nap PBR maps calibrated to the splash-screen table.

**Architecture:** Keep the existing Blender-authored GLB/PBR pipeline and runtime material interface. Add one offline verifier for source maps and Metal screenshots, drive the generator with balanced multi-direction fibre fields, update the Godot visual contract, then validate four real Metal captures before running the focused regression set.

**Tech Stack:** Blender 5.2 LTS Python API, NumPy, Pillow, Godot 4.6.2 Mono, GDScript contract runners, Metal/Forward+ screenshots.

## Global Constraints

- Keep `TableFelt`, `DeepEmeraldShortNapFelt`, all table geometry, UVs and 2048×2048 map sizes unchanged.
- Keep walnut, leather, grooves, center instrument, camera, layout, touch, rules and AI unchanged.
- Do not add a runtime shader layer, texture sampler, per-frame animation or baked splash-image crop.
- Normal X/Y mean-square energy ratio must be `<= 1.30`.
- Base-color luminance coefficient of variation must be `0.006–0.018`.
- Roughness median must be `0.86–0.90`, roughness span must be `<= 0.06`, and metallic maximum must be `0`.
- Metal render mask median must satisfy `R/G = 0.35–0.50`, `B/G = 0.40–0.62`, and luminance `0.36–0.46`.
- Do not build or install iOS until the user approves the new rendered comparison.

---

### Task 1: Add The Offline Felt Quality Gate

**Files:**
- Create: `tools/verify_splash_matched_felt.py`
- Create: `evidence/ui_splash_matched_felt_20260807/baseline_metrics.json`

**Interfaces:**
- Consumes: the three felt PNG maps plus zero or more Metal PNG paths.
- Produces: `analyze_maps(root: Path) -> dict`, `analyze_render(path: Path) -> dict`, JSON stdout/output, and exit code 0 only when every check passes.

- [ ] **Step 1: Write the source-map and render verifier**

Create a Pillow/NumPy CLI with these exact calculations:

```python
NORMAL_ENERGY_RATIO_MAX = 1.30
BASE_LUMINANCE_CV_RANGE = (0.006, 0.018)
ROUGHNESS_MEDIAN_RANGE = (0.86, 0.90)
ROUGHNESS_SPAN_MAX = 0.06
RENDER_RED_GREEN_RANGE = (0.35, 0.50)
RENDER_BLUE_GREEN_RANGE = (0.40, 0.62)
RENDER_LUMINANCE_RANGE = (0.36, 0.46)

def analyze_maps(root: Path) -> dict[str, object]:
    base = np.asarray(Image.open(root / "felt_basecolor.png").convert("RGB"), dtype=np.float64) / 255.0
    normal = np.asarray(Image.open(root / "felt_normal.png").convert("RGB"), dtype=np.float64) / 255.0
    orm = np.asarray(Image.open(root / "felt_orm.png").convert("RGB"), dtype=np.float64) / 255.0
    luminance = base @ np.array([0.2126, 0.7152, 0.0722])
    tangent_x = normal[:, :, 0] * 2.0 - 1.0
    tangent_y = normal[:, :, 1] * 2.0 - 1.0
    energy_x = float(np.mean(tangent_x * tangent_x))
    energy_y = float(np.mean(tangent_y * tangent_y))
    energy_ratio = max(energy_x, energy_y) / max(min(energy_x, energy_y), 1e-12)
    roughness = orm[:, :, 1]
    metrics = {
        "normal_energy_ratio": energy_ratio,
        "base_luminance_cv": float(np.std(luminance) / np.mean(luminance)),
        "roughness_median": float(np.median(roughness)),
        "roughness_span": float(np.max(roughness) - np.min(roughness)),
        "metallic_max": float(np.max(orm[:, :, 2])),
    }
    checks = {
        "balanced_normal_energy": metrics["normal_energy_ratio"] <= NORMAL_ENERGY_RATIO_MAX,
        "subtle_base_variation": BASE_LUMINANCE_CV_RANGE[0] <= metrics["base_luminance_cv"] <= BASE_LUMINANCE_CV_RANGE[1],
        "high_roughness": ROUGHNESS_MEDIAN_RANGE[0] <= metrics["roughness_median"] <= ROUGHNESS_MEDIAN_RANGE[1],
        "restrained_roughness_span": metrics["roughness_span"] <= ROUGHNESS_SPAN_MAX,
        "non_metallic": metrics["metallic_max"] == 0.0,
    }
    return {"metrics": metrics, "checks": checks, "passed": all(checks.values())}

def analyze_render(path: Path) -> dict[str, object]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    height, width, _ = rgb.shape
    y, x = np.mgrid[0:height, 0:width]
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    spatial = (x > width * 0.15) & (x < width * 0.85) & (y > height * 0.03) & (y < height * 0.95)
    mask = spatial & (green > red * 1.15) & (green > blue * 1.08) & (green > 0.18) & (green < 0.75)
    selected = rgb[mask]
    if selected.shape[0] < width * height * 0.10:
        raise RuntimeError(f"insufficient felt pixels in {path}: {selected.shape[0]}")
    median = np.median(selected, axis=0)
    luminance = float(median @ np.array([0.2126, 0.7152, 0.0722]))
    metrics = {
        "median_rgb8": np.rint(median * 255.0).astype(int).tolist(),
        "red_green_ratio": float(median[0] / median[1]),
        "blue_green_ratio": float(median[2] / median[1]),
        "luminance": luminance,
    }
    checks = {
        "warm_green_red_ratio": RENDER_RED_GREEN_RANGE[0] <= metrics["red_green_ratio"] <= RENDER_RED_GREEN_RANGE[1],
        "reduced_cyan_blue_ratio": RENDER_BLUE_GREEN_RANGE[0] <= metrics["blue_green_ratio"] <= RENDER_BLUE_GREEN_RANGE[1],
        "splash_matched_luminance": RENDER_LUMINANCE_RANGE[0] <= luminance <= RENDER_LUMINANCE_RANGE[1],
    }
    return {"path": str(path), "metrics": metrics, "checks": checks, "passed": all(checks.values())}
```

The CLI accepts `--maps-root`, repeated `--render`, and `--output`; it prints one JSON object and returns 1 if map analysis or any supplied render fails.

- [ ] **Step 2: Run the gate against the current baseline and verify failure**

```bash
python3 tools/verify_splash_matched_felt.py \
  --maps-root res/art/materials/table_v2 \
  --render evidence/ui_latest_discard_velvet_20260728/final_table_2556x1179.png \
  --output evidence/ui_splash_matched_felt_20260807/baseline_metrics.json
```

Expected: exit 1; normal energy ratio is approximately `2.09`, base CV approximately `0.00375`, roughness median approximately `0.82`, and render `B/G` approximately `0.82`.

- [ ] **Step 3: Compile and commit the gate**

```bash
python3 -m py_compile tools/verify_splash_matched_felt.py
git add tools/verify_splash_matched_felt.py evidence/ui_splash_matched_felt_20260807/baseline_metrics.json
git commit -m "test: add splash-matched felt quality gate"
```

Expected: Python compilation exits 0; the commit contains only the verifier and small baseline JSON.

### Task 2: Regenerate Balanced Warm-Green PBR Felt

**Files:**
- Modify: `tools/3d/generate_sichuan_table_v2.py:26-165,370-375`
- Modify: `res/art/materials/table_v2/felt_basecolor.png`
- Modify: `res/art/materials/table_v2/felt_normal.png`
- Modify: `res/art/materials/table_v2/felt_orm.png`
- Modify: `res/art/3d/sichuan_table_v2.glb`

**Interfaces:**
- Consumes: fixed NumPy seeds and the unchanged `pbr_material(...)` interface.
- Produces: three deterministic 2048 maps and one deterministic GLB with the existing node/material names.

- [ ] **Step 1: Replace the cyan-compensated palette and single-axis fibre field**

Use these authored sRGB colors:

```python
TABLE_CENTER = np.array([0x32, 0x78, 0x43], dtype=np.float32) / 255.0
TABLE_BASE = np.array([0x29, 0x69, 0x39], dtype=np.float32) / 255.0
TABLE_EDGE = np.array([0x20, 0x55, 0x31], dtype=np.float32) / 255.0
```

Keep the legacy brocade audit mask, but replace production base/normal/roughness calculations with:

```python
broad = smooth_noise(size, 5301, 28)
medium = smooth_noise(size, 5302, 96)
fine = smooth_noise(size, 5303, 360)
phase_noise = smooth_noise(size, 5304, 180)
fibre_fields = [
    np.sin((u * 760.0 + v * 250.0 + phase_noise * 0.34) * math.tau),
    np.sin((-u * 310.0 + v * 830.0 + fine * 0.28) * math.tau),
    np.sin((u * 610.0 - v * 690.0 + phase_noise * 0.30) * math.tau),
    np.sin((u * 520.0 + v * 540.0 + medium * 0.18) * math.tau),
]
micro_nap = sum(fibre_fields) * 0.125 + 0.5
clean_felt_color = TABLE_BASE * 0.82 + TABLE_CENTER * 0.18
tone = (broad - 0.5) * 0.028 + (medium - 0.5) * 0.018 + (fine - 0.5) * 0.006
base = clean_felt_color[None, None, :] * (1.0 + tone[:, :, None])
base *= np.array([0.82, 0.96, 0.72], dtype=np.float32)[None, None, :]
height = (
    fibre_fields[0] * 0.050 + fibre_fields[1] * 0.050
    + fibre_fields[2] * 0.050 + fibre_fields[3] * 0.050
    + (fine - 0.5) * 0.045
)
grad_y, grad_x = np.gradient(height)
normal = np.dstack((-grad_x * 2.15, -grad_y * 2.15, np.ones_like(height)))
normal /= np.linalg.norm(normal, axis=2, keepdims=True)
roughness = np.clip(
    0.88 + (fine - 0.5) * 0.018 + (micro_nap - 0.5) * 0.014,
    0.86,
    0.90,
)
```

Change the felt material call to `normal_strength=0.34`. Do not modify leather, walnut, groove or mesh generation.

- [ ] **Step 2: Regenerate and run the source-map gate**

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/3d/generate_sichuan_table_v2.py \
  2>&1 | tee evidence/ui_splash_matched_felt_20260807/blender_generation_1.log
python3 tools/verify_splash_matched_felt.py \
  --maps-root res/art/materials/table_v2 \
  --output evidence/ui_splash_matched_felt_20260807/source_map_metrics.json
```

Expected: Blender exits 0; verifier exits 0 with every source-map check true.

- [ ] **Step 3: Prove deterministic output**

```bash
shasum -a 256 res/art/materials/table_v2/felt_basecolor.png res/art/materials/table_v2/felt_normal.png res/art/materials/table_v2/felt_orm.png res/art/3d/sichuan_table_v2.glb \
  > evidence/ui_splash_matched_felt_20260807/hashes_1.txt
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/3d/generate_sichuan_table_v2.py \
  2>&1 | tee evidence/ui_splash_matched_felt_20260807/blender_generation_2.log
shasum -a 256 res/art/materials/table_v2/felt_basecolor.png res/art/materials/table_v2/felt_normal.png res/art/materials/table_v2/felt_orm.png res/art/3d/sichuan_table_v2.glb \
  > evidence/ui_splash_matched_felt_20260807/hashes_2.txt
diff -u evidence/ui_splash_matched_felt_20260807/hashes_1.txt evidence/ui_splash_matched_felt_20260807/hashes_2.txt
```

Expected: `diff` exits 0 with no output.

- [ ] **Step 4: Commit the deterministic asset change**

```bash
git add tools/3d/generate_sichuan_table_v2.py res/art/materials/table_v2/felt_basecolor.png res/art/materials/table_v2/felt_normal.png res/art/materials/table_v2/felt_orm.png res/art/3d/sichuan_table_v2.glb
git commit -m "feat: match gameplay felt to splash texture"
```

### Task 3: Update Runtime Contract And Provenance

**Files:**
- Modify: `tests/current/SichuanTableMaterialQualityRunner.gd:55-60`
- Modify: `scripts/ui/3d/SichuanTableStage3D.gd:1338-1343`
- Modify: `res/art/materials/table_v2/README.md`
- Modify: `res/art/3d/README.md`

**Interfaces:**
- Consumes: `get_last_contract()` from `SichuanTableStage3D`.
- Produces: exact `table_surface_finish = "splash_matched_natural_warm_green_balanced_short_nap_felt"`.

- [ ] **Step 1: Make the contract test fail first**

Change only the expected test string and message:

```gdscript
_check(
    str(contract.get("table_surface_finish", "")) == "splash_matched_natural_warm_green_balanced_short_nap_felt",
    "stage exposes the splash-matched balanced short-nap felt contract"
)
```

Run `SichuanTableMaterialQualityRunner.gd`. Expected: exit 1 because runtime still reports the old directional finish.

- [ ] **Step 2: Update runtime contract and provenance docs**

Set the matching string in `SichuanTableStage3D.gd`. Update both README files to state that the splash image is a visual calibration reference only; production maps remain original deterministic generated assets; base color is warm natural green; normal uses balanced multi-direction short nap; roughness is `0.86–0.90`.

- [ ] **Step 3: Import and run focused contracts**

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --editor \
  --path /Volumes/AI/Codex/四川麻将工程_20260701_v2 --quit-after 2
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless \
  --path /Volumes/AI/Codex/四川麻将工程_20260701_v2 \
  --script res://tests/current/SichuanTableMaterialQualityRunner.gd
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless \
  --path /Volumes/AI/Codex/四川麻将工程_20260701_v2 \
  --script res://tests/current/Sichuan3DTableStageRunner.gd
```

Expected: both runners print PASS and exit 0. Existing shutdown-only RID/ObjectDB warnings do not count as failures.

- [ ] **Step 4: Commit contract and provenance**

```bash
git add tests/current/SichuanTableMaterialQualityRunner.gd scripts/ui/3d/SichuanTableStage3D.gd res/art/materials/table_v2/README.md res/art/3d/README.md
git commit -m "test: lock splash-matched felt contract"
```

### Task 4: Capture And Calibrate Real Metal Output

**Files:**
- Create: `evidence/ui_splash_matched_felt_20260807/after/table_1365x768.png`
- Create: `evidence/ui_splash_matched_felt_20260807/after/table_2048x1152.png`
- Create: `evidence/ui_splash_matched_felt_20260807/after/table_2400x1080.png`
- Create: `evidence/ui_splash_matched_felt_20260807/after/table_2556x1179.png`
- Conditionally modify: `scripts/ui/3d/SichuanTableStage3D.gd:270-330`

**Interfaces:**
- Consumes: real Metal captures from `tools/capture_main_scene.gd --capture-mode=camera`.
- Produces: four render checks satisfying all global color ratios.

- [ ] **Step 1: Capture four real Metal frames**

Run this command for `1365x768`, `2048x1152`, `2400x1080`, and `2556x1179`:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --path /Volumes/AI/Codex/四川麻将工程_20260701_v2 \
  --resolution 2048x1152 --script res://tools/capture_main_scene.gd -- \
  --capture-mode=camera --capture-output=res://evidence/ui_splash_matched_felt_20260807/after/table_2048x1152.png
```

Expected: each exits 0 and writes a nonblank PNG. macOS may produce `1366x768` and `2556x1180` drawable images for odd logical dimensions.

- [ ] **Step 2: Run all render gates**

```bash
python3 tools/verify_splash_matched_felt.py \
  --maps-root res/art/materials/table_v2 \
  --render evidence/ui_splash_matched_felt_20260807/after/table_1365x768.png \
  --render evidence/ui_splash_matched_felt_20260807/after/table_2048x1152.png \
  --render evidence/ui_splash_matched_felt_20260807/after/table_2400x1080.png \
  --render evidence/ui_splash_matched_felt_20260807/after/table_2556x1179.png \
  --output evidence/ui_splash_matched_felt_20260807/final_metrics.json
```

Expected: exit 0 and all source/render checks true.

- [ ] **Step 3: Use the bounded lighting fallback only if needed**

If maps pass but render ratios fail, set ambient color to `Color("A9B79C")`, ambient energy to `0.16`, key color to `Color("FFF1E1")`, and key energy to `0.88`. Do not change key rotation, shadow settings or tile-only fill. Recapture all four frames and rerun Step 2. If the material-only captures pass, do not edit lighting.

- [ ] **Step 4: Create the three-way comparison**

Use Pillow to resize the splash image, old accepted baseline and new 2556 capture into equal 1278×590 panels, label them `启动图基准 / 修改前 / 修改后`, and save `evidence/ui_splash_matched_felt_20260807/splash_before_after_contact_sheet.png`. Preserve aspect ratio with center crop and do not alter color.

- [ ] **Step 5: Commit only if lighting fallback was required**

```bash
git add scripts/ui/3d/SichuanTableStage3D.gd
git commit -m "fix: calibrate table light for warm felt"
```

Skip this commit when Step 3 was not needed.

### Task 5: Focused Regression And Evidence Report

**Files:**
- Modify: `VERSION`
- Modify: `VERSION.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Create: `evidence/ui_splash_matched_felt_20260807/verification_report.md`
- Modify: `.codex/交接/当前.md`

**Interfaces:**
- Consumes: source-map metrics, deterministic hashes, four Metal captures and runner logs.
- Produces: an evidence-layered report that stops at local Metal rendering.

- [ ] **Step 1: Upgrade the source version to 2.6.30**

Set `VERSION`, `project.godot`, all desktop/iOS short/build versions, Android `version/name`, README and VERSION documentation to `2.6.30`; set Android `version/code=290`. Add a `2.6.30 - 2026-08-07` changelog entry describing only the splash-matched felt change and its frozen gameplay/UI scope. Do not build a mobile package in this task.

- [ ] **Step 2: Run focused regressions**

Run these runners independently and preserve each log: `SichuanTableMaterialQualityRunner.gd`, `Sichuan3DTableStageRunner.gd`, `SichuanPremiumTableVisualContractRunner.gd`, `SichuanTileVisualQualityRunner.gd`, `SichuanTableLayoutContractRunner.gd`, `SichuanTableTouchTargetRunner.gd`, `SichuanCameraCompositionRunner.gd`, and `SichuanLightingQualityRunner.gd`.

Expected: 8/8 exit 0 with no explicit FAIL marker.

- [ ] **Step 3: Run spatial contracts and C# build**

Run `SichuanSpatialLayoutRunner.gd` with `1365x768`, `2048x1152`, `2400x1080`, and `2556x1179`, then:

```bash
dotnet build SichuanMahjong.Godot.csproj -c Release --no-restore
git diff --check
```

Expected: spatial 4/4 pass; C# has 0 warnings and 0 errors; diff check exits 0.

- [ ] **Step 4: Write the report and handoff**

Report exact source commit, changed files, map metrics, hashes, Metal renderer, four viewport results, focused runner totals, C# result, comparison image and evidence boundary. State explicitly that no iOS package was built or installed and no phone rendering/touch claim is made. Add the same verified boundary at the top of `.codex/交接/当前.md` using `apply_patch`, then read both files back.

- [ ] **Step 5: Commit version and evidence metadata**

Commit only the report, handoff entry and small JSON/text metrics. Large screenshots remain evidence files unless the containing directory is already tracked by project convention.

- [ ] **Step 6: Present comparison and stop before iOS**

Show `splash_before_after_contact_sheet.png`, summarize exact metrics and regression evidence, and wait for user visual approval before any version bump, iOS signing, installation or launch.
