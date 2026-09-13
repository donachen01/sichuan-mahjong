# Sichuan Mahjong 2.6.33 Tactile Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 2.6.33 with visible clean short-nap felt, a glare-free matte wall counter, and a natural detached-right new-draw tile that sorts into the hand after discard, then publish the signed iOS build and push the scoped release to GitHub.

**Architecture:** Keep `GameState` authoritative and rearrange only the 3D presentation while `human_can_discard` is true. Rebuild the deterministic Blender table and center assets without new runtime shader samples. Lock each behavior with focused RED/GREEN tests and protect the dirty worktree with explicit Git whitelists.

**Tech Stack:** Godot 4.6.2 .NET, GDScript/C#, Blender 5.2.0 LTS, Python/NumPy, Metal Forward+, .NET 10, Xcode 26.6, Apple Development signing, `xcrun devicectl`, Git/GitHub.

## Global Constraints

- Work on the existing branch; do not create a branch or worktree.
- Do not modify rules, scoring, AI, authoritative hand order, camera, table/tile dimensions, HUD, menus, settlement, discard slots or latest-discard marker.
- Do not restore or create a fixed regression manifest; execute only task-scoped checks.
- Felt BaseColor remains free of low-frequency clouds, stains, bands, radial spots and baked lighting.
- Add no runtime felt shader, texture sampler, particle, glow or per-frame felt animation.
- The draw layout consumes `human_last_draw_tile_id` and `human_can_discard`; it never mutates `GameState` hand data.
- Release version is `2.6.33`; Android `versionCode` is `293`.
- Never use `git add -A`; stage only listed source/assets/tests/docs/evidence.
- Report source, package, device install, launch, true iPhone rendering and touch as separate evidence levels.

## File Map

- `tools/verify_splash_matched_felt.py`: clean BaseColor and Normal frequency gates.
- `tools/3d/generate_sichuan_table_v2.py`: deterministic dual-scale felt PBR.
- `tools/3d/generate_sichuan_center_compass_v2.py`: matte wall-counter insert.
- `scripts/ui/3d/SichuanTableStage3D.gd`: detached draw ordering, gap and sorting motion.
- `scripts/ui/3d/SichuanTile3D.gd`: remove the blue marker and draw-frame processing.
- `tests/current/SichuanTableMaterialQualityRunner.gd`: imported table PBR.
- `tests/current/Sichuan3DTableStageRunner.gd`: center and detached draw contracts.
- `tests/current/SichuanTileVisualQualityRunner.gd`: marker absence.
- `tests/current/SichuanTableMotionContractRunner.gd`: draw arrival and sorting motion.
- `tests/current/SichuanTableLayoutContractRunner.gd`: 14/18-tile and safe-area layout.
- `tests/current/SichuanTableTouchTargetRunner.gd`: detached-tile hit target.
- `tests/current/SichuanVersionConsistencyRunner.gd`: release metadata.
- `evidence/ui_tactile_table_2_6_33_20260808/`: Metal evidence.
- `evidence/2.6.33_ios_release_20260808/`: release/device evidence.

---

### Task 1: Freeze The Verified 2.6.32 Baseline

**Files:**
- Commit: current scoped 2.6.32 source/assets/tests/docs/evidence
- Exclude: AI pressure `.translation`, caches, old reports and unrelated evidence

**Interfaces:**
- Consumes: `evidence/ui_physical_integration_20260808/verification_report.md`.
- Produces: a Git baseline that isolates the new 2.6.33 diff.

- [ ] **Step 1: Re-run baseline verification**

Run the 11 runners recorded in the 2.6.32 report, `dotnet build SichuanMahjong.Godot.sln -c Release --no-restore`, and `git diff --check`.

Expected: `11/11` exit `0`, build `0 warning / 0 error`, no whitespace errors. Record but do not hide existing post-exit cleanup diagnostics.

- [ ] **Step 2: Stage and inspect only the 2.6.32 whitelist**

Use explicit `git add -- <paths>`, then:

```bash
git diff --cached --name-status
git diff --cached --check
```

Expected: no `.translation`, `__pycache__`, build products or unrelated evidence.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: integrate the physical mahjong table presentation"
```

---

### Task 2: Add A Failing Dual-Scale Felt Gate

**Files:**
- Modify: `tools/verify_splash_matched_felt.py`
- Modify: `tests/current/SichuanTableMaterialQualityRunner.gd`

**Interfaces:**
- Consumes: final top-face UV bounds and 2.6.32 PBR maps.
- Produces: `analyze_normal_frequency_bands(normal_rgb, top_face_uv) -> dict` with low/mid/high energy.

- [ ] **Step 1: Add spectral and roughness assertions**

Decode tangent-space Normal X/Y, measure representative mip bands on the real top-face UV region, and require:

```python
assert metrics["normal_direction_energy_ratio"] <= 1.30
assert metrics["normal_low_frequency_ratio"] <= 0.05
assert metrics["normal_mid_frequency_ratio"] >= 0.10
assert 0.83 <= metrics["roughness_median"] <= 0.87
assert metrics["roughness_p99_p1"] <= 0.025
assert metrics["metallic_max"] == 0
```

Keep existing clean BaseColor low-frequency limits unchanged.

- [ ] **Step 2: Run RED**

```bash
python3 tools/verify_splash_matched_felt.py --project-root . --output-json /tmp/sichuan_2_6_33_felt_red.json
```

Expected: FAIL for insufficient mid-frequency Normal and/or roughness above the new range; clean BaseColor still passes.

- [ ] **Step 3: Add the imported PBR presence check**

Require `DeepEmeraldShortNapFelt` to retain imported Normal/ORM material data, metallic `0` and no runtime override. Keep spectral math in Python only.

- [ ] **Step 4: Commit RED tests**

```bash
git add -- tools/verify_splash_matched_felt.py tests/current/SichuanTableMaterialQualityRunner.gd
git commit -m "test: require visible clean mid-scale felt nap"
```

---

### Task 3: Generate Dual-Scale Felt PBR

**Files:**
- Modify: `tools/3d/generate_sichuan_table_v2.py`
- Regenerate: `res/art/materials/table_v2/felt_normal.png`
- Regenerate: `res/art/materials/table_v2/felt_orm.png`
- Preserve hash: `res/art/materials/table_v2/felt_basecolor.png`
- Regenerate: `res/art/3d/sichuan_table_v2.glb`
- Regenerate: `res/art/3d/sichuan_table_v2_felt_*.png`

**Interfaces:**
- Consumes: Task 2 verifier.
- Produces: deterministic band-limited mid nap plus micro nap, roughness `0.83–0.87`.

- [ ] **Step 1: Implement the band-limited mid layer**

Keep BaseColor generation byte-identical. Build an isotropic band-limited field from fixed-seed waves whose frequencies are restricted to `180–320` cycles across the texture. Randomized directions/phases and at least 48 components prevent a dominant weave direction, while the explicit frequency floor prevents low-frequency height islands:

```python
mid_rng = np.random.default_rng(5310)
mid_nap = np.zeros((size, size), dtype=np.float32)
for _ in range(48):
    angle = mid_rng.uniform(0.0, math.tau)
    cycles = mid_rng.uniform(180.0, 320.0)
    phase = mid_rng.uniform(0.0, math.tau)
    projected = u * math.cos(angle) + v * math.sin(angle)
    mid_nap += np.sin(projected * cycles * math.tau + phase)
mid_nap /= math.sqrt(24.0)
height = mid_nap * 0.020 + sum(field * 0.035 for field in fibre_fields) + (fine - 0.5) * 0.030
```

Tune only amplitudes and Normal strength within the approved design; never write mid/low noise to BaseColor.

- [ ] **Step 2: Generate tactile ORM**

Center roughness near `0.85`, use only band-limited mid/micro variation, clip `0.83–0.87`, keep AO `0.97` and metallic `0`.

- [ ] **Step 3: Rebuild with Blender**

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/3d/generate_sichuan_table_v2.py
```

Expected: exit `0`; object/material names and geometry budget unchanged.

- [ ] **Step 4: Run GREEN and protect BaseColor**

Run the Python verifier. Require BaseColor SHA-256 to remain `8e7b8686250a0b9bee7a5b907d3cb417201353f891f640e667114d4ada26f798`.

- [ ] **Step 5: Prove determinism**

Hash BaseColor, Normal, ORM and GLB, rerun Blender, hash again and compare.

Expected: both generations byte-identical.

- [ ] **Step 6: Reimport and test**

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --editor --path . --quit
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script tests/current/SichuanTableMaterialQualityRunner.gd
```

Expected: import and Runner succeed.

- [ ] **Step 7: Commit**

Stage only the generator, changed felt/GLB assets, verifier and focused test; commit `feat: add mip-resilient dual-scale felt nap`.

---

### Task 4: Replace Counter Glare With Matte Smoked Jade

**Files:**
- Modify: `tests/current/Sichuan3DTableStageRunner.gd`
- Modify: `tools/3d/generate_sichuan_center_compass_v2.py`
- Modify: `scripts/ui/3d/SichuanTableStage3D.gd`
- Regenerate: `res/art/3d/sichuan_center_compass_v2.glb`

**Interfaces:**
- Consumes: existing `CounterGlassLens`, `CounterBronzeBezel`, `CenterWallCount3DText` nodes.
- Produces: opaque matte counter insert with unchanged geometry/radii.

- [ ] **Step 1: Write failing material/label assertions**

Require `CounterGlassLens` transparency disabled, alpha `1`, metallic `<=0.03`, roughness `0.68–0.76`, no emission; require number outline size `4–6`, warm ivory and no processing.

- [ ] **Step 2: Run RED**

Run `Sichuan3DTableStageRunner.gd`.

Expected: FAIL on current transparent roughness `0.18` glass and outline `12`.

- [ ] **Step 3: Add the Blender counter material**

```python
counter_insert = make_material(
    "CenterMatteSmokedJadeCounter", "163B32",
    metallic=0.01, roughness=0.72,
    coat=0.0, coat_roughness=0.5,
    alpha=1.0, transmission=0.0,
)
```

Assign it only to `CounterGlassLens`. Preserve full-panel glass, four red sectors, object count, radii and triangle count.

- [ ] **Step 4: Reduce the number halo**

Set number modulate to `E8DFC8`, outline `071713`, outline size `5`; update Stage contracts from glass/highlight language to matte insert language.

- [ ] **Step 5: Rebuild twice and run GREEN**

Prove equal center GLB hashes, reimport, run `Sichuan3DTableStageRunner.gd`.

Expected: PASS; exact red sectors and geometry gates remain green.

- [ ] **Step 6: Commit**

Stage only center generator/GLB, Stage and focused test; commit `feat: remove glare from the wall counter`.

---

### Task 5: Replace The Blue Diamond With A Detached Draw Tile

**Files:**
- Modify: `tests/current/SichuanTileVisualQualityRunner.gd`
- Modify: `tests/current/Sichuan3DTableStageRunner.gd`
- Modify: `tests/current/SichuanTableMotionContractRunner.gd`
- Modify: `tests/current/SichuanTableLayoutContractRunner.gd`
- Modify: `tests/current/SichuanTableTouchTargetRunner.gd`
- Modify: `scripts/ui/3d/SichuanTile3D.gd`
- Modify: `scripts/ui/3d/SichuanTableStage3D.gd`

**Interfaces:**
- Consumes: `human_last_draw_tile_id`, `human_can_discard`, existing tile ids/nodes.
- Produces: `self_layout_has_detached_draw`, `SELF_NEW_DRAW_GAP_PER_SCALE`, sort-after-discard tween.

- [ ] **Step 1: Write failing no-marker tests**

```gdscript
_check(tile.new_draw_marker == null or tile.new_draw_marker.mesh == null,
    "new draw uses physical rack position, not a floating marker")
_check(not tile.is_processing(), "drawn tile has no marker process")
```

Reject `NewDrawRotatingBlueDiamond`, `NewDrawWorldYawPivot` and blue marker material contracts.

- [ ] **Step 2: Write failing layout/state tests**

Use a drawn tile that sorts into the middle. With `human_can_discard=true`, require it to be rightmost with one bounded physical gap. With the same retained hand and `human_can_discard=false`, require suit/rank position and ordinary pitch. If the tile is in discards, require no detached hand slot and the same id in its discard node.

- [ ] **Step 3: Write failing motion/touch tests**

Require existing `200ms + 50ms` draw arrival, `~180ms` retained-tile sorting, correct reduced-motion final transforms and a pickable detached screen rect at supported viewports.

- [ ] **Step 4: Run RED**

Run TileVisual, 3DTableStage, TableMotion, TableLayout and TableTouchTarget.

Expected: failures for blue marker, sorted-in-place draw and missing detached gap/sort motion.

- [ ] **Step 5: Remove blue marker production code**

Delete exported draw-marker variants, speed/tilt/position constants, pivot/mesh members, `_process`, blue material, diamond mesh and marker-position helper. Keep `new_draw` only as semantic motion input; it must create no visual node or process.

- [ ] **Step 6: Implement presentation-only detachment**

```gdscript
var detach_human_draw := bool(snapshot.get("human_can_discard", false)) \
    and new_draw_id >= 0 \
    and not bool(self_player.get("has_won", false))
```

Sort a duplicate display hand, remove the matching draw dictionary and append it. Never mutate `all_hands` or `player.hand_tiles`.

- [ ] **Step 7: Add the gap to layout math**

Add `SELF_NEW_DRAW_GAP_PER_SCALE := 0.10`. Include one scaled gap in `span_per_scale` only when detached draw and organized tiles coexist; add the gap only before the last appended draw tile. Preserve automatic scale floor and safe bounds.

- [ ] **Step 8: Animate retained-tile sorting**

When the same existing node transitions from detached to sorted after `human_can_discard` becomes false, tween its target transform for `0.18s` with quadratic ease-out. Direct draw discard uses the existing current-transform-to-river path; create no duplicate node.

- [ ] **Step 9: Run GREEN and remove stale contracts**

Rerun the five runners. Replace blue/rotation contract strings with `detached_right_draw_then_sort_after_discard`; use `rg` to eliminate stale source comments.

Expected: five exits `0`, detached tile pickable, no new-draw node processing.

- [ ] **Step 10: Commit**

Stage only the two scripts and five focused tests; commit `feat: present new draws in a natural detached rack slot`.

---

### Task 6: Synchronize Version 2.6.33 And Verify Source

**Files:**
- Modify: `project.godot`, `export_presets.cfg`, `VERSION`, `VERSION.md`, `README.md`, `CHANGELOG.md`
- Modify: `tests/current/SichuanVersionConsistencyRunner.gd`

**Interfaces:**
- Consumes: completed visual contracts.
- Produces: synchronized `2.6.33` / Android `293` metadata.

- [ ] **Step 1: Set RED expectations**

Set `EXPECTED_VERSION := "2.6.33"`, `EXPECTED_ANDROID_CODE := 293`; run VersionConsistency.

Expected: FAIL against 2.6.32 files.

- [ ] **Step 2: Update all metadata and release notes**

Synchronize Godot and three presets plus root docs. Describe all three user-visible changes and the current iOS evidence boundary.

- [ ] **Step 3: Run GREEN and focused source verification**

Run VersionConsistency, felt verifier, Blender determinism, Lighting, TableMaterial, TileVisual, PremiumTableVisual, 3DTableStage, TableMotion, TableLayout, TableTouchTarget, CameraComposition and HudStateIntegrity, followed by:

```bash
dotnet build SichuanMahjong.Godot.sln -c Release --no-restore
git diff --check
```

Expected: selected checks exit `0`, build `0 warning / 0 error`, no whitespace errors. This is evidence, not a standing manifest.

- [ ] **Step 4: Commit**

Stage only metadata/docs/version test; commit `chore: release version 2.6.33`.

---

### Task 7: Capture And Review Metal Output

**Files:**
- Create: `evidence/ui_tactile_table_2_6_33_20260808/` screenshots, metrics and report

**Interfaces:**
- Consumes: final imported assets and Stage states.
- Produces: actual Metal evidence for felt, counter, detached draw, sorting and safe areas.

- [ ] **Step 1: Capture required states**

Use `tools/capture_main_scene.gd` or a narrowly scoped payload extension for empty, detached draw, post-discard sorted and dense states at `1365x768`, `2048x1152`, `2556x1179`.

Expected: Apple M1 Pro / Metal 4.0 / Forward+, nonblank images with exact sizes.

- [ ] **Step 2: Run metrics and manual inspection**

Confirm splash-matched green ratios and low-frequency gates. At actual and iPhone-like display size verify: visible fine diffuse nap without stains/bands/sparkles; no wall-count bright point/halo; natural rightmost draw gap; sorted state restores pitch; no overlap or safe-area violation.

- [ ] **Step 3: Iterate only within approved bounds**

If nap is invisible while gates pass, adjust mid amplitude/Normal strength or roughness inside approved ranges. If broad patterns appear, reject and reduce/remove mid field; never modify BaseColor to hide them. For residual counter glare, adjust only counter insert roughness/color.

- [ ] **Step 4: Write and commit report**

Record hashes, metrics, screenshots, tests/build and iOS boundary. Commit only the evidence directory and final approved asset deltas as `test: verify the tactile table on Metal`.

---

### Task 8: Build, Sign And Install iOS 2.6.33

**Files:**
- Create: `build/ios/SichuanMahjong-2.6.33-ios-xcode/`
- Create: `build/ios/SichuanMahjong-2.6.33-development-20260808.ipa`
- Create: `evidence/2.6.33_ios_release_20260808/`

**Interfaces:**
- Consumes: final committed 2.6.33 source and GLB hashes.
- Produces: signed App/IPA and package/device evidence.

- [ ] **Step 1: Fresh Release build/export**

```bash
dotnet build SichuanMahjong.Godot.sln -c Release --no-restore
zsh tools/export_ios_xcode_project.sh
```

Expected: current-source Godot/NativeAOT export; no reused old App.

- [ ] **Step 2: Xcode sign and build**

Run noninteractive `xcodebuild` Release for configured team/device and save logs.

Expected: `** BUILD SUCCEEDED **`; arm64 App reports `2.6.33/2.6.33`.

- [ ] **Step 3: Validate/archive IPA**

Run deep codesign, inspect certificate/profile/entitlements/Bundle ID/UDID/expiry, archive `Payload/*.app`, validate ZIP and hash IPA. Prove packaged table/center resources match source hashes.

- [ ] **Step 4: Install and launch when available**

Use `xcrun devicectl` to list, install, read applications, launch with `--terminate-existing` and query process after a bounded delay.

Expected when online/unlocked/trusted: device reads `2.6.33/2.6.33` and process remains. If blocked, record exact state and do not claim that layer.

- [ ] **Step 5: Obtain device visual evidence if possible**

Capture/request the detached-draw state and verify felt, matte counter and absence of blue marker. Install/launch alone does not prove visual acceptance.

- [ ] **Step 6: Write compact release report**

Record IPA hash/size, signing/profile expiry, package source hashes, device/install/version/launch/process results and visual/touch boundary. Do not commit App/IPA/Xcode directory or large raw logs unless project policy explicitly requires it.

---

### Task 9: Final Review And GitHub Publication

**Files:**
- Modify: `.codex/交接/当前.md`
- Include: approved task commits and compact evidence

**Interfaces:**
- Consumes: verified source, assets, Metal, signed artifact and device results.
- Produces: remote branch updated to final release commit.

- [ ] **Step 1: Update handoff and reverify final tree**

Record 2.6.33 status, strongest evidence, artifact paths/hashes, profile expiry, device result and residual warnings. Freshly rerun risk-focused checks, Release build, version consistency and `git diff --check`.

- [ ] **Step 2: Audit commit/worktree scope**

```bash
git log --oneline --decorate -10
git status --short
git diff --check
git diff origin/codex/tile-model-consistency-2.6.14...HEAD --name-status
```

Expected: commits contain approved source/assets/tests/docs/evidence only; unrelated dirty files remain unstaged and untouched.

- [ ] **Step 3: Commit handoff and push**

```bash
git add -- .codex/交接/当前.md
git commit -m "docs: hand off the 2.6.33 release"
git push origin codex/tile-model-consistency-2.6.14
```

Expected: push exit `0`; remote branch resolves to final local commit.

- [ ] **Step 4: Report evidence by layer**

State separately: source/tests/build, Blender determinism, macOS Metal, signed App/IPA, device install/version/launch, true iPhone visual inspection, touch/complete game, and GitHub remote commit.
