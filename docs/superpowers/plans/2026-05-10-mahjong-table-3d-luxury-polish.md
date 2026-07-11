# Mahjong Table 3D Luxury Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the already-tuned V17 table layout into a unified 3D cartoon luxury mahjong tabletop by removing visible region boxes and keeping all tiles visually seated on one shared table surface.

**Architecture:** Keep the current scene hierarchy and layout contracts intact, but change the visual contract: gameplay containers remain for positioning and hit testing while their backgrounds, frames, and plate fills become invisible. A single tabletop material from `MainSceneV2.gd` and `UIStyleConfig.gd` carries the surface; tile depth, shadows, and floating UI carry hierarchy.

**Tech Stack:** Godot 4 GDScript, existing V17 layout scene/scripts, `StyleBoxFlat`, project contract tests in `tests/V17LayoutContract.gd`, screenshot capture via `tools/capture_main_scene.gd`.

---

## File Structure

- Modify `docs/superpowers/specs/2026-05-10-mahjong-table-3d-luxury-polish-design.md`: already added; keep as the design source of truth.
- Create `docs/superpowers/plans/2026-05-10-mahjong-table-3d-luxury-polish.md`: this implementation plan.
- Modify `scripts/game/MainSceneV2.gd`: apply the unified tabletop theme, make board/hand/meld/hu/discard region containers visually transparent, keep player info and action overlays styled.
- Modify `scripts/ui/PlayerUI.gd`: make player hand/meld/hu slot plates invisible while retaining layout, clipping, and tile hosts.
- Modify `scripts/ui/UIStyleConfig.gd`: add a reusable transparent gameplay-zone panel helper so the visual rule is centralized instead of scattered.
- Modify `res/ui/default_ui_style.tres`: update style resource values only if needed after code inspection; keep layout-independent styling here.
- Modify `tests/V17LayoutContract.gd`: update tests that expected `V17Backplate` or `SlotPlate` visibility, and add explicit checks that gameplay zone containers no longer show region frames/fills.
- Modify `tools/capture_main_scene.gd`: ensure the capture state includes hands, melds, hu tiles, and discards so visual QA actually exercises all removed panels.
- Modify version files: bump `VERSION.md`, `project.godot`, and ignored `export_presets.cfg` package version after implementation.

---

### Task 1: Add a Central Transparent Gameplay Panel Style

**Files:**
- Modify: `scripts/ui/UIStyleConfig.gd`
- Test: `tests/V17LayoutContract.gd`

- [ ] **Step 1: Inspect existing panel helpers**

Run:

```bash
sed -n '1,260p' scripts/ui/UIStyleConfig.gd
```

Expected: identify the existing `apply_panel`, `apply_clear_panel`, and `apply_plate_panel` helpers.

- [ ] **Step 2: Add a helper for invisible gameplay zones**

Add this method near the other panel helpers in `scripts/ui/UIStyleConfig.gd`:

```gdscript
func apply_tabletop_zone_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)
```

- [ ] **Step 3: Add a predicate helper for tests**

Add this method below `apply_tabletop_zone_panel`:

```gdscript
func panel_is_tabletop_zone(panel: Panel) -> bool:
	if panel == null:
		return false
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return false
	return (
		style.bg_color.a <= 0.01
		and style.border_color.a <= 0.01
		and style.get_border_width(SIDE_LEFT) == 0
		and style.get_border_width(SIDE_TOP) == 0
		and style.get_border_width(SIDE_RIGHT) == 0
		and style.get_border_width(SIDE_BOTTOM) == 0
		and style.shadow_size == 0
	)
```

- [ ] **Step 4: Run script parse check**

Run:

```bash
swift test
```

Expected: if Swift tests are unrelated and unavailable, record the failure reason and proceed to the Godot layout test in later tasks. Do not claim this task is verified until a Godot script load or project test succeeds.

---

### Task 2: Remove Central Board and Discard Region Frames

**Files:**
- Modify: `scripts/game/MainSceneV2.gd`
- Test: `tests/V17LayoutContract.gd`

- [ ] **Step 1: Write the failing visual contract**

In `tests/V17LayoutContract.gd`, add a call near the existing board checks:

```gdscript
_check_tabletop_zone_visual_contract(root_node, failures)
```

Add this function near the other visual contract checks:

```gdscript
func _check_tabletop_zone_visual_contract(root_node: Node, failures: Array[String]) -> void:
	var panels: Array[Panel] = [
		root_node.get("board_cross_top_plate") as Panel,
		root_node.get("board_cross_bottom_plate") as Panel,
		root_node.get("board_cross_left_plate") as Panel,
		root_node.get("board_cross_right_plate") as Panel,
		root_node.get("board_cross_center_plate") as Panel,
	]
	for panel in panels:
		if panel == null:
			failures.append("桌面精修需要保留布局容器，但有中心牌区容器缺失")
			continue
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			failures.append("%s 缺少 panel style，无法验证是否去分区化" % panel.name)
			continue
		if style.bg_color.a > 0.03:
			failures.append("%s 不应再显示独立底色，当前透明度 %.2f" % [panel.name, style.bg_color.a])
		if style.border_color.a > 0.03 or style.get_border_width(SIDE_LEFT) > 0 or style.get_border_width(SIDE_TOP) > 0 or style.get_border_width(SIDE_RIGHT) > 0 or style.get_border_width(SIDE_BOTTOM) > 0:
			failures.append("%s 不应再显示区域边框" % panel.name)
		if style.shadow_size > 0:
			failures.append("%s 不应再用面板阴影形成独立分区" % panel.name)
```

- [ ] **Step 2: Run the contract and confirm it fails before implementation**

Run the existing Godot contract command used in this repo. If the command is not documented, inspect project scripts with:

```bash
rg -n "V17LayoutContract|capture_main_scene|--headless|godot" .
```

Expected: contract fails with messages about center plate independent backgrounds/borders.

- [ ] **Step 3: Apply transparent style to central gameplay plates**

In `scripts/game/MainSceneV2.gd`, change `_apply_v17_plate_panel` from plate styling to tabletop-zone styling:

```gdscript
func _apply_v17_plate_panel(panel: Panel, glowing: bool) -> void:
	if panel == null:
		return
	STYLE_CONFIG.apply_tabletop_zone_panel(panel)
	panel.clip_contents = true
	_remove_material_overlay(panel, "V17SoftPlateLight")
```

If `_remove_material_overlay` does not exist, add it near `_ensure_material_overlay`:

```gdscript
func _remove_material_overlay(parent: Control, overlay_name: String) -> void:
	if parent == null:
		return
	var existing := parent.get_node_or_null(overlay_name)
	if existing != null:
		existing.queue_free()
```

- [ ] **Step 4: Remove felt panels from center area containers**

In `_apply_tabletop_matte_theme`, change these calls:

```gdscript
_apply_felt_panel(center_meld_card, Color(0.16, 0.48, 0.32, 0.84), Color(0.88, 0.96, 0.72, 0.16), 18, 1, 8)
_apply_felt_panel(center_discard_card, Color(0.16, 0.48, 0.32, 0.84), Color(0.88, 0.96, 0.72, 0.16), 18, 1, 8)
```

to:

```gdscript
_apply_clear_panel(center_meld_card)
_apply_clear_panel(center_discard_card)
```

- [ ] **Step 5: Re-run the contract**

Run the same Godot contract command.

Expected: new tabletop zone visual contract passes; existing discard geometry tests still pass.

---

### Task 3: Remove Player Hand, Meld, and Hu Slot Backplates

**Files:**
- Modify: `scripts/ui/PlayerUI.gd`
- Modify: `scripts/game/MainSceneV2.gd`
- Test: `tests/V17LayoutContract.gd`

- [ ] **Step 1: Update tests that expected visible slot plates**

Find current assertions around `SlotPlate` and `V17Backplate`:

```bash
rg -n "SlotPlate|V17Backplate" tests/V17LayoutContract.gd
```

Replace expectations that these nodes are visible with expectations that they are hidden or transparent:

```gdscript
var backplate := host.find_child("V17Backplate", true, false) as Control
if backplate != null and backplate.visible:
	failures.append("桌面精修后本家手牌/胡牌背板不应可见：%s" % host.name)
```

For `SlotPlate` checks:

```gdscript
var slot_plate := slot.find_child("SlotPlate", true, false) as Panel
if slot_plate != null and slot_plate.visible:
	var style := slot_plate.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null or style.bg_color.a > 0.03 or style.border_color.a > 0.03:
		failures.append("%s 的 SlotPlate 不应再显示独立底色或边框" % slot.name)
```

- [ ] **Step 2: Make band slot plates invisible**

In `scripts/ui/PlayerUI.gd`, change `_apply_band_slot_plate` to keep the node for layout compatibility but make it visually silent:

```gdscript
func _apply_band_slot_plate(slot: Control, warm: bool, strong: bool) -> void:
	if slot == null:
		return
	var panel := slot.get_node_or_null("SlotPlate") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "SlotPlate"
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(panel)
		slot.move_child(panel, 0)
	style_config.apply_tabletop_zone_panel(panel)
	panel.visible = false
```

- [ ] **Step 3: Keep player root panels visually transparent**

In `_ready` or `_refresh_layout`, ensure every non-info gameplay root calls:

```gdscript
_apply_shell_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
```

Expected: this is already true for side and top docks; update the self dock if it still receives `style_config.apply_panel(root_panel)`.

- [ ] **Step 4: Keep self hu and self hand host backplates hidden**

In `scripts/game/MainSceneV2.gd`, keep this behavior in `_apply_v17_plate_styles`:

```gdscript
for host in [player_self_host, self_hu_tile_host]:
	_hide_v17_host_backplate(host)
```

If any call still uses `_apply_v17_host_backplate` for gameplay areas, replace it with `_hide_v17_host_backplate`.

- [ ] **Step 5: Run the layout contract**

Run the Godot layout contract.

Expected: hand/meld/hu layout assertions still pass; visible `SlotPlate`/`V17Backplate` failures are gone.

---

### Task 4: Unify the Tabletop Material and Preserve Important Floating UI

**Files:**
- Modify: `scripts/game/MainSceneV2.gd`
- Modify: `scripts/ui/UIStyleConfig.gd`
- Optional Modify: `res/ui/default_ui_style.tres`
- Test: `tools/capture_main_scene.gd`

- [ ] **Step 1: Strengthen the single tabletop surface**

In `_apply_tabletop_matte_theme`, keep only one visible tabletop base for gameplay:

```gdscript
if background_rect != null:
	background_rect.color = MATTE_FELT_BG
	_ensure_material_overlay(background_rect, "TableFeltSoftGlow", TABLE_MATERIAL_OVERLAY_SCRIPT.MaterialMode.FELT, 0.52)
```

Keep these containers clear:

```gdscript
_apply_clear_panel(board_area)
_apply_clear_panel(board_square)
_apply_clear_panel(%SelfSection)
_apply_clear_panel(%TopRail)
_apply_clear_panel(%LeftRail)
_apply_clear_panel(%RightRail)
```

- [ ] **Step 2: Preserve player info cards and action buttons**

Do not make these panels transparent:

```gdscript
room_card
info_card
center_stats_card
center_hint_card
action_panel
ding_que_panel
settlement_panel
```

Expected: these are floating UI/control surfaces, not gameplay tile zones.

- [ ] **Step 3: Keep AI hint panel readable but not region-like**

In `_setup_discard_helper_panel`, keep `DiscardHelperPanel` as a floating glass panel with readable text. Do not clear it completely because the user previously asked for a large readable helper panel.

Expected visual rule: AI helper remains a floating overlay; it is not part of the hand/meld/hu/discard region removal.

- [ ] **Step 4: Capture visual state**

Run:

```bash
godot --headless --path . --script tools/capture_main_scene.gd
```

Expected: screenshot generation succeeds and includes hands, melds, hu tile, discards, and AI helper preview.

---

### Task 5: Update Screenshot Fixture Coverage

**Files:**
- Modify: `tools/capture_main_scene.gd`
- Test: generated screenshot

- [ ] **Step 1: Inspect current capture fixture**

Run:

```bash
sed -n '1,260p' tools/capture_main_scene.gd
```

Expected: identify where sample players, discards, helper preview, and hand preview are forced.

- [ ] **Step 2: Ensure all removed zone types are visible in the capture**

Add or keep fixture setup so the screenshot includes:

```gdscript
sample_players[0]["melds"] = [{"type": "peng", "tile": "tiao_2", "tiles": ["tiao_2", "tiao_2", "tiao_2"], "from_seat": 1}]
sample_players[0]["winning_tile"] = {"suit": "tong", "rank": 8, "id": 8008}
sample_players[1]["melds"] = [{"type": "gang", "tile": "tong_3", "tiles": ["tong_3", "tong_3", "tong_3", "tong_3"], "from_seat": 0}]
sample_players[2]["melds"] = [{"type": "peng", "tile": "tiao_6", "tiles": ["tiao_6", "tiao_6", "tiao_6"], "from_seat": 3}]
sample_players[3]["melds"] = [{"type": "peng", "tile": "wan_5", "tiles": ["wan_5", "wan_5", "wan_5"], "from_seat": 2}]
```

Use the project’s current tile dictionary format if it differs from these string examples.

- [ ] **Step 3: Capture and inspect**

Run:

```bash
godot --headless --path . --script tools/capture_main_scene.gd
```

Expected: the screenshot shows no visible hand/meld/hu/discard region boxes, while all tile groups are present.

---

### Task 6: Version Bump and Verification

**Files:**
- Modify: `VERSION.md`
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Test: `git diff`, layout contract, screenshot

- [ ] **Step 1: Bump app version**

If current version is `1.0.4`, bump to `1.0.5`:

```text
VERSION.md: 1.0.5
project.godot: config/version="1.0.5"
export_presets.cfg:
application/short_version="1.0.5"
application/version="1.0.5"
version/code=6
version/name="1.0.5"
```

- [ ] **Step 2: Run final contract verification**

Run the Godot V17 layout contract command discovered earlier.

Expected: all existing geometry tests pass and new tabletop visual contract passes.

- [ ] **Step 3: Run final screenshot capture**

Run:

```bash
godot --headless --path . --script tools/capture_main_scene.gd
```

Expected: capture succeeds.

- [ ] **Step 4: Review diff**

Run:

```bash
git diff --stat
git diff -- scripts/game/MainSceneV2.gd scripts/ui/PlayerUI.gd scripts/ui/UIStyleConfig.gd tests/V17LayoutContract.gd tools/capture_main_scene.gd VERSION.md project.godot export_presets.cfg
```

Expected: changes are scoped to visual polish, tests, capture fixture, and version bump.

- [ ] **Step 5: Commit**

Run:

```bash
git add docs/superpowers/specs/2026-05-10-mahjong-table-3d-luxury-polish-design.md docs/superpowers/plans/2026-05-10-mahjong-table-3d-luxury-polish.md scripts/game/MainSceneV2.gd scripts/ui/PlayerUI.gd scripts/ui/UIStyleConfig.gd tests/V17LayoutContract.gd tools/capture_main_scene.gd VERSION.md project.godot export_presets.cfg
git commit -m "Polish tabletop visual style"
```

Expected: commit succeeds on `main`.

---

## Self-Review

- Spec coverage: the plan removes visible region backgrounds/borders, keeps current layout, preserves floating UI, updates tests, captures screenshots, and bumps version.
- Placeholder scan: no TBD/TODO placeholders are used.
- Type consistency: all new helpers use Godot `Panel`, `StyleBoxFlat`, `Color`, and existing `STYLE_CONFIG`/`style_config` naming patterns.
- Scope: gameplay logic, AI strategy, startup page, and settlement page are intentionally out of scope.
