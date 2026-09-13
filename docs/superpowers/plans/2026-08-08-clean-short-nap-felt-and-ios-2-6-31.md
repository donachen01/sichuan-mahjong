# Clean Short-Nap Felt and iOS 2.6.31 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the standing 27-command regression manifest, rebuild the tabletop as clean splash-referenced short-nap PBR without visible low-frequency stains, and install signed version 2.6.31 on the target iPhone.

**Architecture:** Keep the existing `TableFelt` geometry, UVs and Blender-authored PBR pipeline. Reject the current asset with a top-face-UV-aware spatial-frequency verifier, remove only low-frequency BaseColor modulation in the Blender generator, then prove the new asset through deterministic generation, scoped Godot/Metal checks and final iOS artifact/device validation. Existing individual runners remain available, but no persistent regression manifest is created or implied.

**Tech Stack:** Blender 5.2.0 LTS, Python 3 with NumPy/Pillow, Godot 4.6.2 .NET/Metal Forward+, .NET 10, Xcode 26.6, Apple Development signing, `xcrun devicectl`.

## Global Constraints

- Work directly on the current branch; do not create a branch or worktree.
- Delete the fixed manifest and do not create any replacement manifest, CI list or documentation list unless the user explicitly requests one.
- Preserve existing individual test runners and historical `27/27 PASS` evidence.
- Freeze gameplay rules, scoring, AI, touch behavior, HUD, tiles, melds, center indicator, table frame, leather, walnut, camera, geometry dimensions and UVs.
- Use `/Applications/Blender.app/Contents/MacOS/Blender` version 5.2.0 LTS for asset generation.
- BaseColor must contain no visible broad/medium cloud field; Normal/ORM may carry only micro-scale short-nap response.
- Do not change lighting unless clean authored maps pass but the new Metal capture fails the established splash color ratios.
- Version the fixed mobile package as 2.6.31 with Android code 291, even though this task only builds iOS.
- Every test command in this plan is scoped to this task and must not be enrolled into a standing suite.

---

### Task 1: Remove The Standing Regression Manifest Policy

**Files:**
- Delete: `docs/ui_rework/emerald_final_runner_manifest_V1.txt`
- Modify: `docs/ui_rework/四川麻将深翡翠精品牌桌与牌局演出最终验收标准_V1.md:336-340`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: the user's explicit policy that standing regression lists require prior user instruction.
- Produces: project-local instructions that preserve individual tests while preventing implicit fixed manifests.

- [ ] **Step 1: Delete the obsolete manifest**

Delete only `docs/ui_rework/emerald_final_runner_manifest_V1.txt`. Do not delete files under `tests/current/`.

- [ ] **Step 2: Replace AC-ENG-04's fixed-list mandate**

Replace the fixed-manifest sentence with:

```markdown
- 表现层改动不得改变规则结果、可操作集合或最终分数。验证项目按本次改动风险选择并逐项记录；除非用户明确指定，不创建、扩充、维护或默认执行固定回归清单，也不以脚本、CI 或其他文档变相重建。
- 现有单项 Runner 保持独立可用，只在与当前修改直接相关时按需执行；历史报告中的既有结果保持不变。
```

- [ ] **Step 3: Add the project Agent rule**

Append a `回归清单策略` section to `AGENTS.md` containing:

```markdown
## 回归清单策略

- 固定回归清单只能由用户明确指定。用户未指定时，Agent 不得自行创建、扩充、维护或默认执行固定清单，也不得以脚本、CI、计划或文档表格变相重建。
- 保留现有单项测试。每次只选择与当前修改和风险直接相关的聚焦验证，并在执行前说明范围；本次选择不自动成为后续任务的默认清单。
- 历史报告和证据中的既有测试结果是历史事实，不因清单策略变化而删除或改写。
```

- [ ] **Step 4: Verify policy removal**

Run:

```bash
test ! -e docs/ui_rework/emerald_final_runner_manifest_V1.txt
rg -n "固定回归清单只能由用户明确指定" AGENTS.md
! rg -n "裁判只认清单|emerald_final_runner_manifest_V1" docs/ui_rework/四川麻将深翡翠精品牌桌与牌局演出最终验收标准_V1.md
git diff --check -- AGENTS.md docs/ui_rework/四川麻将深翡翠精品牌桌与牌局演出最终验收标准_V1.md
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit**

```bash
git add -- AGENTS.md docs/ui_rework/四川麻将深翡翠精品牌桌与牌局演出最终验收标准_V1.md docs/ui_rework/emerald_final_runner_manifest_V1.txt
git commit -m "docs: remove standing regression manifest"
```

### Task 2: Add A Failing Top-Face Low-Frequency Gate

**Files:**
- Modify: `tools/verify_splash_matched_felt.py`
- Create: `evidence/ui_clean_felt_20260808/baseline_source_metrics.json`

**Interfaces:**
- Consumes: `felt_basecolor.png`, `felt_normal.png`, `felt_orm.png` and the measured top-face UV bounds.
- Produces: `analyze_maps(root: Path) -> dict[str, object]` with top-face low-frequency metrics that reject the 2.6.30 stains.

- [ ] **Step 1: Add exact thresholds and UV bounds**

Replace the old BaseColor range with:

```python
BASE_LUMINANCE_CV_MAX = 0.004
BASE_LOWPASS_STD_FRACTION_MAX = 0.20
BASE_LOWFREQ_P99_P1_MAX = 1.5 / 255.0
NORMAL_LOWPASS_STD_FRACTION_MAX = 0.05
ROUGHNESS_P99_P1_MAX = 0.02
TOP_FACE_UV_BOUNDS = (0.6556, 0.9423, 0.5037, 0.9799)
LOWPASS_GRID_SIZE = (28, 28)
```

- [ ] **Step 2: Add float-safe UV and low-pass helpers**

Add:

```python
def _top_face_crop(field: np.ndarray) -> np.ndarray:
    u0, u1, v0, v1 = TOP_FACE_UV_BOUNDS
    height, width = field.shape[:2]
    return field[
        round((1.0 - v1) * height):round((1.0 - v0) * height),
        round(u0 * width):round(u1 * width),
    ]


def _lowpass(field: np.ndarray) -> np.ndarray:
    source = Image.fromarray(field.astype(np.float32), mode="F")
    return np.asarray(
        source.resize(LOWPASS_GRID_SIZE, Image.Resampling.BOX).resize(
            source.size, Image.Resampling.BILINEAR
        ),
        dtype=np.float64,
    )


def _lowpass_std_fraction(field: np.ndarray) -> float:
    total_std = float(np.std(field))
    if total_std <= 1e-12:
        return 0.0
    return float(np.std(_lowpass(field)) / total_std)
```

- [ ] **Step 3: Measure the actual top face**

In `analyze_maps`, crop luminance, tangent X/Y and roughness with `_top_face_crop`; add:

```python
base_luminance_cv = float(np.std(luminance) / np.mean(luminance))
top_luminance = _top_face_crop(luminance)
top_lowpass = _lowpass(top_luminance)
base_lowpass_std_fraction = _lowpass_std_fraction(top_luminance)
base_lowfreq_p99_p1 = float(np.percentile(top_lowpass, 99) - np.percentile(top_lowpass, 1))
normal_lowpass_std_fraction = max(
    _lowpass_std_fraction(_top_face_crop(tangent_x)),
    _lowpass_std_fraction(_top_face_crop(tangent_y)),
)
roughness_p99_p1 = float(
    np.percentile(_top_face_crop(roughness), 99)
    - np.percentile(_top_face_crop(roughness), 1)
)
```

Check the five new bounds and remove the old BaseColor minimum.

- [ ] **Step 4: Verify the current asset fails for the expected reason**

Run:

```bash
python3 tools/verify_splash_matched_felt.py \
  --maps-root res/art/materials/table_v2 \
  --output evidence/ui_clean_felt_20260808/baseline_source_metrics.json
```

Expected: exit 1; `base_lowpass_std_fraction` is approximately `0.76`, `clean_base_low_frequency` is false, and no syntax/runtime error occurs.

- [ ] **Step 5: Verify the verifier itself**

Run:

```bash
python3 -m py_compile tools/verify_splash_matched_felt.py
git diff --check -- tools/verify_splash_matched_felt.py
```

Expected: exit 0.

- [ ] **Step 6: Commit the red test**

```bash
git add -- tools/verify_splash_matched_felt.py evidence/ui_clean_felt_20260808/baseline_source_metrics.json
git commit -m "test: reject low-frequency felt stains"
```

### Task 3: Rebuild The Blender Felt Without BaseColor Clouds

**Files:**
- Modify: `tools/3d/generate_sichuan_table_v2.py:96-166`
- Modify: `res/art/materials/table_v2/felt_basecolor.png`
- Modify: `res/art/materials/table_v2/felt_normal.png`
- Modify: `res/art/materials/table_v2/felt_orm.png`
- Modify: `res/art/3d/sichuan_table_v2.glb`
- Create: `evidence/ui_clean_felt_20260808/final_source_metrics.json`
- Create: `evidence/ui_clean_felt_20260808/hashes_generation_1.txt`
- Create: `evidence/ui_clean_felt_20260808/hashes_generation_2.txt`

**Interfaces:**
- Consumes: the red low-frequency verifier from Task 2.
- Produces: deterministic clean BaseColor plus the existing balanced micro-Normal/high-Roughness PBR asset.

- [ ] **Step 1: Remove only BaseColor cloud modulation**

Delete `broad = smooth_noise(...)` and the entire `tone` block. Keep `medium`, `fine`, `phase_noise`, fibre fields, Normal and ORM. Build BaseColor as:

```python
clean_felt_color = TABLE_BASE * 0.82 + TABLE_CENTER * 0.18
base = np.broadcast_to(clean_felt_color[None, None, :], (size, size, 3)).copy()
base *= np.array([0.66, 1.03, 0.90], dtype=np.float32)[None, None, :]
```

Update comments to state that BaseColor is deliberately uniform and all short-nap response lives in Normal/roughness.

- [ ] **Step 2: Compile the generator**

Run:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python-expr "import py_compile; py_compile.compile('tools/3d/generate_sichuan_table_v2.py', doraise=True)"
```

Expected: exit 0.

- [ ] **Step 3: Generate with Blender 5.2.0 LTS**

Run:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/3d/generate_sichuan_table_v2.py
```

Expected: exit 0 and all four production assets receive a current timestamp.

- [ ] **Step 4: Verify green**

Run:

```bash
python3 tools/verify_splash_matched_felt.py \
  --maps-root res/art/materials/table_v2 \
  --output evidence/ui_clean_felt_20260808/final_source_metrics.json
```

Expected: exit 0; BaseColor CV and low-frequency metrics are zero or below bounds; Normal, Roughness and Metallic checks pass.

- [ ] **Step 5: Prove deterministic generation**

Hash the three maps and GLB into `hashes_generation_1.txt`, rerun Blender unchanged, hash into `hashes_generation_2.txt`, then run `diff -u`.

Expected: no differences.

- [ ] **Step 6: Commit the Blender source and authored assets**

```bash
git add -- tools/3d/generate_sichuan_table_v2.py \
  res/art/materials/table_v2/felt_basecolor.png \
  res/art/materials/table_v2/felt_normal.png \
  res/art/materials/table_v2/felt_orm.png \
  res/art/3d/sichuan_table_v2.glb \
  evidence/ui_clean_felt_20260808/final_source_metrics.json \
  evidence/ui_clean_felt_20260808/hashes_generation_1.txt \
  evidence/ui_clean_felt_20260808/hashes_generation_2.txt
git commit -m "fix: remove low-frequency felt stains"
```

### Task 4: Reimport And Verify The Metal Result

**Files:**
- Modify through Godot import: `res/art/3d/sichuan_table_v2_felt_basecolor.png`
- Modify through Godot import: `res/art/3d/sichuan_table_v2_felt_normal.png`
- Modify through Godot import: `res/art/3d/sichuan_table_v2_felt_orm.png`
- Create: `evidence/ui_clean_felt_20260808/metal/table_empty_2556x1179.png`
- Create: `evidence/ui_clean_felt_20260808/metal/table_game_2556x1179.png`
- Create: `evidence/ui_clean_felt_20260808/metal_metrics.json`

**Interfaces:**
- Consumes: the clean GLB from Task 3.
- Produces: actual Godot Metal evidence and imported texture copies for packaging.

- [ ] **Step 1: Force Godot import and verify texture identity**

Run the Godot editor headless once, then compare the three author/imported PNGs as decoded RGBA arrays. Expected: maximum channel delta 0 for each map.

- [ ] **Step 2: Run only directly relevant runners**

Run individually:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Volumes/AI/Codex/四川麻将工程_20260701_v2 --script res://tests/current/SichuanTableMaterialQualityRunner.gd
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Volumes/AI/Codex/四川麻将工程_20260701_v2 --script res://tests/current/Sichuan3DTableStageRunner.gd
```

Expected: both exit 0. Do not run or recreate a 27-item manifest.

- [ ] **Step 3: Capture the principal Metal views**

Use `tools/capture_main_scene.gd` at `2556x1179` for the empty table and normal game state, saving the two explicit paths above.

Expected: each PNG is nonblank, approximately 2556×1180, and shows no visible cloud/water-stain islands.

- [ ] **Step 4: Run source/render color checks**

Run `tools/verify_splash_matched_felt.py` with both captures and write `metal_metrics.json`.

Expected: exit 0; render median remains within splash green ratios. Manually inspect at original resolution because numeric medians cannot prove stain removal.

- [ ] **Step 5: Keep lighting unchanged unless the bounded fallback is required**

If maps are clean and both captures pass the existing color ratios, do not edit `SichuanTableStage3D.gd`. If they fail only by global color, adjust only ambient/key color or energy within the approved design bounds, recapture and reverify.

- [ ] **Step 6: Commit imported assets and Metal evidence**

Commit only the three imported felt PNGs and current evidence files; do not stage unrelated `.translation` or historical evidence changes.

### Task 5: Bump Release Metadata To 2.6.31

**Files:**
- Modify: `VERSION`
- Modify: `VERSION.md`
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: verified clean felt source and Metal captures.
- Produces: consistent `2.6.31` metadata and Android code 291 for future parity.

- [ ] **Step 1: Update every active version field**

Set all short/build versions to `2.6.31`; set Android `version/code=291` and `version/name="2.6.31"`.

- [ ] **Step 2: Correct the product documentation**

Add a 2.6.31 changelog entry stating that 2.6.30's broad/medium BaseColor modulation produced iOS water-stain islands, that BaseColor is now uniform and micro texture remains in Normal/roughness, and that the standing 27-item manifest was removed by user instruction. Update current-version summaries without rewriting historical 2.6.30 text.

- [ ] **Step 3: Verify metadata consistency**

Run focused `rg` checks for active `2.6.30` version fields and `git diff --check`.

Expected: no active field remains on 2.6.30; historical sections may still mention it.

- [ ] **Step 4: Commit**

```bash
git add -- VERSION VERSION.md project.godot export_presets.cfg README.md CHANGELOG.md
git commit -m "release: bump Sichuan Mahjong to 2.6.31"
```

### Task 6: Build, Sign And Install iOS 2.6.31

**Files:**
- Create: `build/ios/SichuanMahjong-2.6.31-ios-xcode/`
- Create: `build/ios/DerivedData-2.6.31-20260808/`
- Create: `build/ios/SichuanMahjong-2.6.31-development-20260808.ipa`
- Create: `evidence/2.6.31_ios_install_20260808/`

**Interfaces:**
- Consumes: source at the final 2.6.31 commit, current Apple Development identity/profile and online iPhone.
- Produces: signed app/IPA plus device install, version, launch, process and screenshot evidence.

- [ ] **Step 1: Verify signing and target device**

Confirm Xcode 26.6, Apple Development identity, team `FCB4ZVWWD8`, bundle `com.chendong.sichuanmahjong.iosdev`, profile expiry, target UDID `00008120-000915803A90A01E`, and CoreDevice ID `516E99D2-18B6-5DD8-94E1-6993510A036D`.

- [ ] **Step 2: Build required runtime layers**

Run `dotnet build SichuanMahjong.Godot.csproj -c Release --no-restore`, then `zsh tools/export_ios_xcode_project.sh` with explicit Godot and Xcode paths.

Expected: 0 warnings/errors from C# and `ios_export_result=0`; the new arm64 AOT framework contains `SichuanAiFacade` and representative decision symbols.

- [ ] **Step 3: Xcode device build**

Build Release/iphoneos with automatic Apple Development signing, destination UDID, team, bundle ID, `MARKETING_VERSION=2.6.31` and `CURRENT_PROJECT_VERSION=2.6.31`.

Expected: `BUILD SUCCEEDED` and deep codesign verification passes.

- [ ] **Step 4: Validate final package contents**

Check Info.plist versions, arm64 binaries, embedded profile, entitlements, cert fingerprint, PCK hash equality, and load the final App PCK to verify clean felt asset hashes and version 2.6.31.

- [ ] **Step 5: Create and validate IPA**

Package only `Payload/SichuanMahjongIOS.app`, run `unzip -t`, confirm no `__MACOSX`, and record size/SHA-256.

- [ ] **Step 6: Install and launch over LAN**

Use `devicectl device install app`, read back `2.6.31/2.6.31`, launch with `--terminate-existing`, and verify the process remains present after a delayed query.

- [ ] **Step 7: Obtain or request the final iPhone screenshot**

If device screenshot automation is available, capture the same empty-table state. Otherwise keep the app running and ask the user for the same-state screenshot. Do not claim true iOS visual acceptance without inspecting it.

### Task 7: Final Evidence, Handoff And Verification

**Files:**
- Create: `evidence/2.6.31_ios_install_20260808/install_report.md`
- Modify: `.codex/交接/当前.md`

**Interfaces:**
- Consumes: all task-local metrics, captures, artifact hashes and device readbacks.
- Produces: self-contained evidence with clear automatic/manual verification boundaries.

- [ ] **Step 1: Write the report and handoff**

Record root cause, exact changed files, absence of a standing manifest, scoped tests executed, Blender determinism, Metal screenshots, version/signing/package/device results, profile expiry and remaining manual iPhone visual/touch boundary.

- [ ] **Step 2: Run the verification loop**

Freshly verify Blender metrics, the two scoped Godot runners, C# Release, Xcode success, codesign, IPA integrity/hash, PCK contents, device version and running process. Review `git diff --check` and staged file scope.

- [ ] **Step 3: Commit only current evidence**

Stage the 2.6.31 evidence directory, the current clean-felt evidence additions and `.codex/交接/当前.md`; do not stage unrelated historical changes.

```bash
git commit -m "release: verify and install iOS 2.6.31"
```

- [ ] **Step 4: Report the strongest evidence layer**

State separately: source/Metal verified, signed app/IPA verified, device install/version/launch verified, and whether final iPhone visual inspection has or has not been completed.
