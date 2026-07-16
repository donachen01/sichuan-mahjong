extends Control

class_name PlayerUI

enum SeatDock {
	SELF,
	TOP,
	LEFT,
	RIGHT,
}

@export var seat_dock: SeatDock = SeatDock.SELF
@export var style_config: Resource

const TILE_SCENE := preload("res://scenes/ui/MahjongTile.tscn")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const SELF_ROW_TILE_VISUAL_HEIGHT := 204.0
const TILE_VISUAL_BASE_WIDTH := 98.0
const TILE_VISUAL_BASE_HEIGHT := 153.0
const SELF_MELD_TILE_SCALE := SELF_ROW_TILE_VISUAL_HEIGHT / TILE_VISUAL_BASE_HEIGHT
const SELF_MELD_TILE_STEP := 124.0
const TOP_ROW_TILE_SCALE := 0.86
const TOP_ROW_TILE_SEPARATION := 4
const TOP_ROW_MAX_COMBINED_TILE_SLOTS := 18
const TOP_ROW_MIN_TILE_SCALE := 0.56
const TOP_ROW_MELD_TILE_SEPARATION := 2.0
const TOP_ROW_MELD_GROUP_SEPARATION := 6
const TOP_ROW_SLOT_PADDING := 30.0
const SIDE_HAND_TILE_SCALE := 0.74
const SIDE_MELD_TILE_SCALE := 0.78
const SIDE_TILE_GAP := 5.0
const SIDE_GROUP_GAP := 12.0
const SIDE_TRACK_GAP := 10.0
const SIDE_MAX_ROWS := 7
const SIDE_MELD_GROUPS_PER_COLUMN := 2
@onready var root_panel: Panel = %RootPanel
@onready var root_margin: MarginContainer = $RootPanel/Margin
@onready var root_vbox: VBoxContainer = %VBox
@onready var header: HBoxContainer = %Header
@onready var title_label: Label = %TitleLabel
@onready var meta_label: Label = %MetaLabel
@onready var tag_row: HBoxContainer = %TagRow
@onready var tag_spacer: Control = %TagSpacer
@onready var state_tag: Label = %StateTag
@onready var ding_que_tag: Label = %DingQueTag
@onready var opponent_band: HBoxContainer = %OpponentBand
@onready var hand_lane: GridContainer = %HandLane
@onready var meld_lane: HBoxContainer = %MeldLane

var top_lane_center: CenterContainer
var top_lane_row: HBoxContainer
var side_lane_center: CenterContainer
var side_lane_row: HBoxContainer
var last_current_turn_seat: int = -1
var last_current_dealer_seat: int = -1
var last_show_ding_que_badges: bool = true
var hand_render_signature: String = ""
var meld_render_signature: String = ""
var opponent_band_render_signature: String = ""
var top_row_tile_scale := TOP_ROW_TILE_SCALE


func _ready() -> void:
	if style_config == null:
		style_config = load("res://res/ui/default_ui_style.tres")
	root_panel.clip_contents = true
	_apply_style()
	_apply_orientation()


func apply_snapshot(
	player: Dictionary,
	show_back: bool,
	current_turn_seat: int = -1,
	current_dealer_seat: int = -1,
	show_ding_que_badges: bool = true
) -> void:
	last_current_turn_seat = current_turn_seat
	last_current_dealer_seat = current_dealer_seat
	last_show_ding_que_badges = show_ding_que_badges
	title_label.text = str(player.get("nickname", "-"))
	meta_label.text = "%d分  %d张  副露%d" % [
		int(player.get("score", 0)),
		int(player.get("hand_count", 0)),
		int(player.get("melds", []).size()),
	]

	var state_text := _build_state_text(player, current_turn_seat, current_dealer_seat)
	state_tag.text = state_text
	state_tag.visible = not state_text.is_empty() and seat_dock != SeatDock.TOP
	_apply_state_style(player, current_turn_seat, current_dealer_seat)

	var ding_que_suit := str(player.get("ding_que", ""))
	ding_que_tag.text = _ding_que_text(ding_que_suit)
	ding_que_tag.visible = false
	_apply_ding_que_style(ding_que_suit)
	_apply_tag_layout(player, current_turn_seat)
	_apply_player_win_state(player)

	_render_hand(player, show_back)
	_render_melds(player)
	_render_opponent_band(player, show_back)


func _apply_style() -> void:
	style_config.apply_tabletop_zone_panel(root_panel)
	style_config.apply_label(title_label, false, true)
	style_config.apply_label(meta_label, true, false)
	style_config.apply_label(state_tag, false, false)
	style_config.apply_label(ding_que_tag, false, false)
	_apply_name_style()
	_apply_state_style({}, -1, -1)
	_apply_ding_que_style("")


func _apply_orientation() -> void:
	root_vbox.add_theme_constant_override("separation", 8)
	hand_lane.add_theme_constant_override("h_separation", 4)
	hand_lane.add_theme_constant_override("v_separation", 4)
	meld_lane.add_theme_constant_override("separation", 6)
	_restore_default_lane_layout()
	root_margin.add_theme_constant_override("margin_left", 14)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_right", 14)
	root_margin.add_theme_constant_override("margin_bottom", 14)

	match seat_dock:
		SeatDock.SELF:
			custom_minimum_size = Vector2(0, SELF_ROW_TILE_VISUAL_HEIGHT)
			root_panel.custom_minimum_size = Vector2(0, SELF_ROW_TILE_VISUAL_HEIGHT)
			opponent_band.visible = false
			header.visible = false
			tag_row.visible = false
			hand_lane.visible = false
			hand_lane.columns = 12
			header.alignment = BoxContainer.ALIGNMENT_CENTER
			header.custom_minimum_size = Vector2(0, 0)
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root_vbox.add_theme_constant_override("separation", 0)
			root_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
			meld_lane.alignment = BoxContainer.ALIGNMENT_BEGIN
			meld_lane.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			meld_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			meld_lane.add_theme_constant_override("separation", 0)
			meld_lane.custom_minimum_size = Vector2(0, SELF_ROW_TILE_VISUAL_HEIGHT)
			root_margin.add_theme_constant_override("margin_left", 0)
			root_margin.add_theme_constant_override("margin_top", 0)
			root_margin.add_theme_constant_override("margin_right", 0)
			root_margin.add_theme_constant_override("margin_bottom", 0)
			_apply_shell_style(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), 0, 0)
		SeatDock.TOP:
			root_panel.custom_minimum_size = Vector2(0, 144)
			custom_minimum_size = Vector2(1388, 144)
			opponent_band.visible = true
			opponent_band.clip_contents = true
			header.visible = false
			root_margin.add_theme_constant_override("margin_left", 0)
			root_margin.add_theme_constant_override("margin_top", 0)
			root_margin.add_theme_constant_override("margin_right", 0)
			root_margin.add_theme_constant_override("margin_bottom", 0)
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag_row.visible = false
			hand_lane.columns = 14
			hand_lane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			root_vbox.add_theme_constant_override("separation", 0)
			meld_lane.alignment = BoxContainer.ALIGNMENT_CENTER
			hand_lane.custom_minimum_size = Vector2(0, 148)
			meld_lane.custom_minimum_size = Vector2(0, 148)
			hand_lane.visible = false
			meld_lane.visible = false
			opponent_band.add_theme_constant_override("separation", 2)
			opponent_band.alignment = BoxContainer.ALIGNMENT_BEGIN
			_apply_shell_style(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), 0, 0)
		SeatDock.LEFT, SeatDock.RIGHT:
			root_panel.custom_minimum_size = Vector2(248, 0)
			custom_minimum_size = Vector2(340, 660)
			opponent_band.visible = true
			opponent_band.clip_contents = true
			header.visible = false
			tag_row.visible = false
			root_margin.add_theme_constant_override("margin_left", 0)
			root_margin.add_theme_constant_override("margin_top", 0)
			root_margin.add_theme_constant_override("margin_right", 0)
			root_margin.add_theme_constant_override("margin_bottom", 0)
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ding_que_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hand_lane.columns = 14
			hand_lane.add_theme_constant_override("h_separation", 6)
			hand_lane.add_theme_constant_override("v_separation", 0)
			root_vbox.add_theme_constant_override("separation", 0)
			root_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
			hand_lane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			hand_lane.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hand_lane.custom_minimum_size = Vector2(0, 0)
			meld_lane.custom_minimum_size = Vector2(132, 0)
			hand_lane.visible = false
			meld_lane.visible = false
			opponent_band.add_theme_constant_override("separation", 8)
			opponent_band.alignment = BoxContainer.ALIGNMENT_BEGIN if seat_dock == SeatDock.LEFT else BoxContainer.ALIGNMENT_END
			opponent_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opponent_band.size_flags_vertical = Control.SIZE_EXPAND_FILL
			opponent_band.custom_minimum_size = Vector2(340, 660)
			_apply_shell_style(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), 0, 0)

	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meta_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ding_que_tag.size_flags_horizontal = Control.SIZE_SHRINK_END
	tag_spacer.visible = true
	title_label.visible = false
	meta_label.visible = false
	ding_que_tag.visible = false


func _restore_default_lane_layout() -> void:
	if top_lane_center != null and is_instance_valid(top_lane_center):
		if top_lane_center.get_parent() != null:
			top_lane_center.get_parent().remove_child(top_lane_center)
		top_lane_center.queue_free()
	top_lane_center = null
	if top_lane_row != null and is_instance_valid(top_lane_row):
		if hand_lane.get_parent() == top_lane_row:
			top_lane_row.remove_child(hand_lane)
		if meld_lane.get_parent() == top_lane_row:
			top_lane_row.remove_child(meld_lane)
		if top_lane_row.get_parent() != null:
			top_lane_row.get_parent().remove_child(top_lane_row)
		top_lane_row.queue_free()
	top_lane_row = null
	if side_lane_center != null and is_instance_valid(side_lane_center):
		if side_lane_center.get_parent() != null:
			side_lane_center.get_parent().remove_child(side_lane_center)
		side_lane_center.queue_free()
	side_lane_center = null
	if side_lane_row == null:
		return
	if is_instance_valid(side_lane_row):
		if hand_lane.get_parent() == side_lane_row:
			side_lane_row.remove_child(hand_lane)
		if meld_lane.get_parent() == side_lane_row:
			side_lane_row.remove_child(meld_lane)
		if side_lane_row.get_parent() != null:
			side_lane_row.get_parent().remove_child(side_lane_row)
		side_lane_row.queue_free()
	side_lane_row = null
	if hand_lane.get_parent() != root_vbox:
		if hand_lane.get_parent() != null:
			hand_lane.get_parent().remove_child(hand_lane)
		root_vbox.add_child(hand_lane)
	if meld_lane.get_parent() != root_vbox:
		if meld_lane.get_parent() != null:
			meld_lane.get_parent().remove_child(meld_lane)
		root_vbox.add_child(meld_lane)
	root_vbox.move_child(hand_lane, 2)
	root_vbox.move_child(meld_lane, 3)


func _rebuild_top_lane_row() -> void:
	_restore_default_lane_layout()
	top_lane_center = CenterContainer.new()
	top_lane_center.name = "TopLaneCenter"
	top_lane_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_lane_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_lane_row = HBoxContainer.new()
	top_lane_row.name = "TopLaneRow"
	top_lane_row.add_theme_constant_override("separation", 10)
	top_lane_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_lane_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_lane_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root_vbox.remove_child(hand_lane)
	root_vbox.remove_child(meld_lane)
	root_vbox.add_child(top_lane_center)
	root_vbox.move_child(top_lane_center, 2)
	top_lane_center.add_child(top_lane_row)
	top_lane_row.add_child(meld_lane)
	top_lane_row.add_child(hand_lane)


func _rebuild_side_lane_row() -> void:
	_restore_default_lane_layout()
	side_lane_center = CenterContainer.new()
	side_lane_center.name = "SideLaneCenter"
	side_lane_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_lane_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_lane_row = HBoxContainer.new()
	side_lane_row.name = "SideLaneRow"
	side_lane_row.add_theme_constant_override("separation", 2)
	side_lane_row.alignment = BoxContainer.ALIGNMENT_CENTER
	side_lane_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side_lane_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root_vbox.remove_child(hand_lane)
	root_vbox.remove_child(meld_lane)
	root_vbox.add_child(side_lane_center)
	root_vbox.move_child(side_lane_center, 2)
	side_lane_center.add_child(side_lane_row)
	if seat_dock == SeatDock.LEFT:
		side_lane_row.add_child(meld_lane)
		side_lane_row.add_child(hand_lane)
	else:
		side_lane_row.add_child(hand_lane)
		side_lane_row.add_child(meld_lane)


func _render_hand(player: Dictionary, show_back: bool) -> void:
	var signature := _build_hand_render_signature(player, show_back)
	if signature == hand_render_signature:
		return
	hand_render_signature = signature
	_clear_children(hand_lane)
	if not hand_lane.visible:
		return

	var count := int(player.get("hand_count", 0))
	var reveal_tiles := not show_back
	var hand_tiles: Array = player.get("hand_tiles", [])

	for index in range(count):
		var tile := TILE_SCENE.instantiate()
		var scale := 0.16
		match seat_dock:
			SeatDock.TOP:
				scale = 0.248
			SeatDock.LEFT, SeatDock.RIGHT:
				scale = 0.19
		var source_tile_data: Dictionary = hand_tiles[index] if index < hand_tiles.size() else {}
		var tile_data: Dictionary = source_tile_data if reveal_tiles else {}
		tile.call("configure", tile_data, scale, show_back and not reveal_tiles, false)
		tile.rotation_degrees = _seat_tile_rotation_degrees()
		hand_lane.add_child(tile)


func _render_opponent_band(player: Dictionary, show_back: bool) -> void:
	var signature := _build_opponent_band_render_signature(player, show_back)
	if signature == opponent_band_render_signature:
		return
	opponent_band_render_signature = signature
	_clear_children(opponent_band)
	if seat_dock == SeatDock.SELF or not opponent_band.visible:
		return

	var hand_count := int(player.get("hand_count", 0))
	var hand_tiles: Array = player.get("hand_tiles", [])
	var melds: Array = player.get("melds", [])
	var has_melds := not melds.is_empty()
	var hu_wrapper: Control = null
	if bool(player.get("has_won", false)) and not player.get("winning_tile", {}).is_empty():
		hu_wrapper = _create_hu_display_wrapper(player)
	var has_hu := hu_wrapper != null
	if seat_dock == SeatDock.TOP:
		var layout_width := 1482.0 if size.x <= 1.0 else size.x
		var layout_height := 210.0 if size.y <= 1.0 else size.y
		var layout_root := _create_band_layout_root()
		layout_root.custom_minimum_size = Vector2(layout_width, layout_height)
		layout_root.size = layout_root.custom_minimum_size
		opponent_band.add_child(layout_root)

		var content_gap := 28.0
		var hu_width := 116.0 if has_hu else 0.0
		var row_width := minf(maxf(520.0, layout_width - 16.0), 1466.0)
		var content_width := row_width - 56.0
		var meld_tile_slots := _top_row_meld_tile_slot_count(melds)
		var visible_hand_count := _top_row_visible_hand_count(hand_count, meld_tile_slots)
		top_row_tile_scale = _top_row_scale_for_capacity(melds, visible_hand_count, content_width, hu_width, has_hu, content_gap)
		var top_tile_size := _tile_visual_size_for_scale(top_row_tile_scale)
		var meld_width := _top_row_meld_width(melds, top_tile_size.x) if has_melds else 0.0
		var hand_width := _top_row_hand_width(visible_hand_count, top_tile_size.x)
		var row_height := minf(144.0, layout_height)
		var content_x := 26.0

		var row_root := _create_fixed_slot(row_width, row_height)
		row_root.name = "HorizontalRowRoot"
		var row_x := maxf(8.0, layout_width - row_width - 8.0)
		var row_rect := Rect2(Vector2(row_x, 6.0), Vector2(row_width, row_height))
		_place_rect_in_parent(layout_root, row_root, row_rect)
		_apply_band_slot_plate(row_root, false, true)

		var top_slot_height := maxf(1.0, row_height - 8.0)
		var top_slot_y := 4.0
		var meld_slot := _create_fixed_slot(meld_width, top_slot_height)
		var hand_slot := _create_fixed_slot(hand_width, top_slot_height)
		hand_slot.name = "TopHandSlot"
		var hu_slot := _create_fixed_slot(hu_width, top_slot_height)
		hu_slot.name = "TopHuSlot"
		if has_melds:
			meld_slot.name = "TopMeldSlot"
			_place_rect_in_parent(row_root, meld_slot, Rect2(Vector2(content_x, top_slot_y), Vector2(meld_width, top_slot_height)))
			content_x += meld_width + content_gap
		_place_rect_in_parent(row_root, hand_slot, Rect2(Vector2(content_x, top_slot_y), Vector2(hand_width, top_slot_height)))
		content_x += hand_width + (content_gap if has_hu else 0.0)
		if has_hu:
			_place_rect_in_parent(row_root, hu_slot, Rect2(Vector2(content_x, top_slot_y), Vector2(hu_width, top_slot_height)))

		var meld_center := CenterContainer.new()
		meld_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		if has_melds:
			meld_slot.add_child(meld_center)
			var meld_row := HBoxContainer.new()
			meld_row.add_theme_constant_override("separation", 6)
			meld_row.alignment = BoxContainer.ALIGNMENT_BEGIN
			meld_center.add_child(meld_row)
			for meld in melds:
				meld_row.add_child(_create_meld_display_wrapper(meld))

		var hand_center := CenterContainer.new()
		hand_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		hand_slot.add_child(hand_center)
		var top_hand_box := HBoxContainer.new()
		top_hand_box.add_theme_constant_override("separation", TOP_ROW_TILE_SEPARATION)
		top_hand_box.alignment = BoxContainer.ALIGNMENT_BEGIN
		hand_center.add_child(top_hand_box)
		for index in range(visible_hand_count):
			var top_tile := TILE_SCENE.instantiate()
			var source_tile_data: Dictionary = hand_tiles[index] if index < hand_tiles.size() else {}
			var tile_data: Dictionary = source_tile_data if not show_back else {}
			top_tile.call("configure", tile_data, top_row_tile_scale, show_back and tile_data.is_empty(), false)
			top_hand_box.add_child(_wrap_tile_with_rotation(top_tile, _seat_tile_rotation_degrees()))

		if has_hu:
			var hu_center := CenterContainer.new()
			hu_center.set_anchors_preset(Control.PRESET_FULL_RECT)
			hu_slot.add_child(hu_center)
			hu_center.add_child(hu_wrapper)
		return

	var layout_root := _create_band_layout_root()
	var layout_width := 390.0 if size.x <= 1.0 else size.x
	var layout_height := 700.0 if size.y <= 1.0 else size.y
	layout_root.custom_minimum_size = Vector2(layout_width, layout_height)
	layout_root.size = layout_root.custom_minimum_size
	opponent_band.add_child(layout_root)

	var hand_tile_size := _oriented_side_tile_size(_side_hand_tile_scale())
	var meld_tile_size := _oriented_side_tile_size(_meld_tile_scale())
	var visible_hand_count := mini(hand_count, 14)
	var hand_columns := 2 if visible_hand_count > SIDE_MAX_ROWS else 1
	var meld_columns := 0 if not has_melds else (2 if melds.size() > SIDE_MELD_GROUPS_PER_COLUMN else 1)
	var hand_width := hand_tile_size.x * float(hand_columns) + SIDE_TILE_GAP * float(maxi(0, hand_columns - 1))
	var meld_width := meld_tile_size.x * float(meld_columns) + SIDE_TILE_GAP * float(maxi(0, meld_columns - 1))
	var hu_width := meld_tile_size.x if has_hu else 0.0
	var total_width := hand_width + (SIDE_TRACK_GAP + meld_width if has_melds else 0.0) + (SIDE_TRACK_GAP + hu_width if has_hu else 0.0)
	var start_x := maxf(0.0, floor((layout_width - total_width) * 0.5))
	var hand_x := start_x if seat_dock == SeatDock.LEFT else start_x + meld_width + (SIDE_TRACK_GAP if has_melds else 0.0)
	var meld_x := start_x + hand_width + SIDE_TRACK_GAP if seat_dock == SeatDock.LEFT else start_x
	var hu_x := start_x + hand_width + (SIDE_TRACK_GAP + meld_width if has_melds else 0.0) + SIDE_TRACK_GAP if seat_dock == SeatDock.LEFT else start_x + meld_width + (SIDE_TRACK_GAP if has_melds else 0.0) + hand_width + SIDE_TRACK_GAP
	var track_height := layout_height
	var hand_rect := Rect2(Vector2(hand_x, 0.0), Vector2(hand_width, track_height))
	var meld_rect := Rect2(Vector2(meld_x, 0.0), Vector2(meld_width, track_height))
	var hu_rect := Rect2(Vector2(hu_x, 0.0), Vector2(hu_width, meld_tile_size.y))

	var hand_column := _create_fixed_slot(hand_rect.size.x, hand_rect.size.y)
	var meld_column := _create_fixed_slot(meld_rect.size.x, meld_rect.size.y)
	var hu_slot := _create_fixed_slot(hu_rect.size.x, hu_rect.size.y)
	hand_column.name = "SideHandColumn"
	meld_column.name = "SideMeldColumn"
	hu_slot.name = "SideHuSlot"
	_place_rect_in_parent(layout_root, hand_column, hand_rect)
	_place_rect_in_parent(layout_root, meld_column, meld_rect)
	_place_rect_in_parent(layout_root, hu_slot, hu_rect)
	# Side tiles already have their own jade backs, ceramic faces and shadows.
	# A plate stretched across the full 700 px track reads as an unrelated dark
	# bar and crowds the name/action HUDs, so side tracks deliberately remain
	# transparent.  Top and self racks may still use a bounded furniture rail.
	meld_column.visible = has_melds
	hu_slot.visible = has_hu

	var hand_grid := Control.new()
	hand_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_column.add_child(hand_grid)
	for index in range(visible_hand_count):
		var source_tile_data: Dictionary = hand_tiles[index] if index < hand_tiles.size() else {}
		var tile_data: Dictionary = source_tile_data if not show_back else {}
		var tile_host := _create_side_hand_tile(show_back and tile_data.is_empty(), tile_data)
		tile_host.position = Vector2(
			float(index / SIDE_MAX_ROWS) * (hand_tile_size.x + SIDE_TILE_GAP),
			float(index % SIDE_MAX_ROWS) * (hand_tile_size.y + SIDE_TILE_GAP)
		)
		hand_grid.add_child(tile_host)

	if has_hu:
		var hu_center := CenterContainer.new()
		hu_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		hu_slot.add_child(hu_center)
		hu_center.add_child(hu_wrapper)

	var meld_grid := Control.new()
	(meld_grid as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	meld_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(meld_column as Control).add_child(meld_grid)
	var column_heights: Array[float] = []
	for column_index in range(meld_columns):
		column_heights.append(0.0)
	for meld_index in range(melds.size()):
		var group_host := _create_exposed_meld_tiles_host(melds[meld_index])
		var column_index := meld_index / SIDE_MELD_GROUPS_PER_COLUMN
		group_host.position = Vector2(
			float(column_index) * (meld_tile_size.x + SIDE_TILE_GAP),
			column_heights[column_index]
		)
		column_heights[column_index] += group_host.custom_minimum_size.y + SIDE_GROUP_GAP
		meld_grid.add_child(group_host)


func _render_melds(player: Dictionary) -> void:
	var signature := _build_melds_render_signature(player)
	if signature == meld_render_signature:
		return
	meld_render_signature = signature
	_clear_children(meld_lane)
	var melds: Array = player.get("melds", [])
	var exposed_melds: Array = []
	var concealed_melds: Array = []
	for meld in melds:
		if _is_concealed_gang_meld(meld):
			concealed_melds.append(meld)
		else:
			exposed_melds.append(meld)
	var hu_wrapper: Control = null

	if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		var side_lane := HBoxContainer.new()
		side_lane.add_theme_constant_override("separation", 3)
		side_lane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		side_lane.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meld_lane.add_child(side_lane)
		if seat_dock == SeatDock.RIGHT and hu_wrapper != null:
			side_lane.add_child(hu_wrapper)
		for meld in exposed_melds:
			side_lane.add_child(_create_meld_display_wrapper(meld))
		for meld in concealed_melds:
			side_lane.add_child(_create_meld_display_wrapper(meld))
		if seat_dock == SeatDock.LEFT and hu_wrapper != null:
			side_lane.add_child(hu_wrapper)
	else:
		var exposed_lane := HBoxContainer.new()
		exposed_lane.add_theme_constant_override("separation", 12)
		exposed_lane.alignment = BoxContainer.ALIGNMENT_BEGIN
		exposed_lane.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var concealed_lane := HBoxContainer.new()
		concealed_lane.add_theme_constant_override("separation", 12)
		concealed_lane.alignment = BoxContainer.ALIGNMENT_BEGIN if seat_dock == SeatDock.SELF else BoxContainer.ALIGNMENT_END
		concealed_lane.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		for meld in exposed_melds:
			exposed_lane.add_child(_create_meld_display_wrapper(meld))
		for meld in concealed_melds:
			concealed_lane.add_child(_create_meld_display_wrapper(meld))
		var has_exposed := not exposed_lane.get_children().is_empty()
		var has_concealed := not concealed_lane.get_children().is_empty()
		if seat_dock == SeatDock.TOP:
			if hu_wrapper != null:
				meld_lane.add_child(hu_wrapper)
			if has_exposed or has_concealed:
				meld_lane.add_child(_create_flex_spacer(true, false))
		elif seat_dock == SeatDock.SELF and has_exposed:
			pass
		if has_exposed:
			meld_lane.add_child(exposed_lane)
		else:
			exposed_lane.free()
		if has_concealed:
			if has_exposed and not (seat_dock in [SeatDock.SELF, SeatDock.TOP]):
				meld_lane.add_child(_create_flex_spacer(true, false))
			meld_lane.add_child(concealed_lane)
		else:
			concealed_lane.free()
		if seat_dock == SeatDock.SELF and hu_wrapper != null:
			meld_lane.add_child(_create_flex_spacer(true, false))
			meld_lane.add_child(hu_wrapper)


func _create_flex_spacer(horizontal: bool, vertical: bool) -> Control:
	var spacer := Control.new()
	if horizontal:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


func _create_fixed_spacer(width: float, height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, height)
	return spacer


func _create_fixed_slot(width: float, height: float) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(width, height)
	slot.size = slot.custom_minimum_size
	slot.clip_contents = true
	return slot


func _top_row_meld_tile_slot_count(melds: Array) -> int:
	var count := 0
	for meld in melds:
		count += (meld.get("tiles", []) as Array).size()
	return count


func _top_row_visible_hand_count(hand_count: int, meld_tile_slots: int) -> int:
	if hand_count <= 0:
		return 0
	var available_slots := TOP_ROW_MAX_COMBINED_TILE_SLOTS - maxi(0, meld_tile_slots)
	return clampi(hand_count, 1, maxi(1, available_slots))


func _top_row_scale_for_capacity(
	melds: Array,
	visible_hand_count: int,
	content_width: float,
	hu_width: float,
	has_hu: bool,
	content_gap: float
) -> float:
	var reserved_gap := (content_gap if not melds.is_empty() else 0.0) + (content_gap if has_hu else 0.0)
	var slot_padding := (TOP_ROW_SLOT_PADDING if not melds.is_empty() else 0.0) + (TOP_ROW_SLOT_PADDING if visible_hand_count > 0 else 0.0)
	var available_width := maxf(1.0, content_width - hu_width - reserved_gap)
	var units := _top_row_width_units(melds, visible_hand_count)
	if units <= 0.0:
		return TOP_ROW_TILE_SCALE
	var fit_scale := maxf(1.0, available_width - slot_padding) / units / TILE_VISUAL_BASE_WIDTH
	return clampf(fit_scale, TOP_ROW_MIN_TILE_SCALE, TOP_ROW_TILE_SCALE)


func _top_row_width_units(melds: Array, visible_hand_count: int) -> float:
	var units := 0.0
	for meld in melds:
		var tiles: Array = meld.get("tiles", [])
		if tiles.is_empty():
			continue
		if units > 0.0:
			units += TOP_ROW_MELD_GROUP_SEPARATION / TILE_VISUAL_BASE_WIDTH
		units += float(tiles.size())
		units += TOP_ROW_MELD_TILE_SEPARATION * maxf(0.0, float(tiles.size() - 1)) / TILE_VISUAL_BASE_WIDTH
	if visible_hand_count > 0:
		if units > 0.0:
			units += 28.0 / TILE_VISUAL_BASE_WIDTH
		units += float(visible_hand_count)
		units += float(TOP_ROW_TILE_SEPARATION) * maxf(0.0, float(visible_hand_count - 1)) / TILE_VISUAL_BASE_WIDTH
	return units


func _top_row_meld_width(melds: Array, tile_width: float) -> float:
	var width := 0.0
	var visible_groups := 0
	for meld in melds:
		var tiles: Array = meld.get("tiles", [])
		if tiles.is_empty():
			continue
		if visible_groups > 0:
			width += float(TOP_ROW_MELD_GROUP_SEPARATION)
		width += tile_width * float(tiles.size())
		width += TOP_ROW_MELD_TILE_SEPARATION * maxf(0.0, float(tiles.size() - 1))
		visible_groups += 1
	if width <= 0.0:
		return 0.0
	return ceil(width + TOP_ROW_SLOT_PADDING)


func _top_row_hand_width(visible_hand_count: int, tile_width: float) -> float:
	if visible_hand_count <= 0:
		return 0.0
	return ceil(tile_width * float(visible_hand_count) + float(TOP_ROW_TILE_SEPARATION) * maxf(0.0, float(visible_hand_count - 1)) + TOP_ROW_SLOT_PADDING)


func _side_meld_column_height(melds: Array) -> float:
	var content_height := 0.0
	var meld_gap := 4.0
	var tile_size := _tile_visual_size_for_scale(_meld_tile_scale())
	var tile_step := tile_size.x if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else tile_size.y
	for meld in melds:
		var tiles: Array = meld.get("tiles", [])
		if tiles.is_empty():
			continue
		var tile_count := float(tiles.size())
		var group_height := tile_count * tile_step + maxf(0.0, tile_count - 1.0) * SIDE_TILE_GAP
		if content_height > 0.0:
			content_height += meld_gap
		content_height += group_height
	if content_height <= 0.0:
		return 0.0
	return clampf(content_height + 8.0, 108.0, 590.0)


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
	panel.add_theme_stylebox_override("panel", TABLE_THEME.make_seat_rail_style(strong))
	panel.set_meta("sichuan_material", "ebony_seat_rail")
	panel.visible = true


func _create_band_layout_root() -> Control:
	var root := Control.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 0.0
	root.anchor_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true
	return root


func _place_rect_in_parent(parent: Control, child: Control, rect: Rect2) -> void:
	parent.add_child(child)
	child.anchor_left = 0.0
	child.anchor_top = 0.0
	child.anchor_right = 0.0
	child.anchor_bottom = 0.0
	child.offset_left = rect.position.x
	child.offset_top = rect.position.y
	child.offset_right = rect.position.x + rect.size.x
	child.offset_bottom = rect.position.y + rect.size.y


func _create_meld_display_wrapper(meld: Dictionary) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.add_theme_constant_override("separation", 0)

	wrapper.add_child(_create_exposed_meld_tiles_host(meld))

	var label := Label.new()
	label.text = _meld_badge_text(meld)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_config.apply_label(label, true, false)
	label.add_theme_font_size_override("font_size", 15 if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else 16)
	label.add_theme_stylebox_override("normal", _build_meld_badge_style(meld))
	label.visible = false
	wrapper.add_child(label)
	return wrapper


func _create_hu_display_wrapper(player: Dictionary) -> Control:
	if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		var winning_tile: Dictionary = player.get("winning_tile", {})
		if winning_tile.is_empty():
			return Control.new()
		var viewer_seat := _viewer_seat()
		var win_type: String = str(player.get("win_type", ""))
		var source_seat: int = int(player.get("winning_source_seat", viewer_seat))
		if win_type in ["self_draw", "gang_self_draw"] or source_seat == viewer_seat:
			return _create_side_hand_tile(false, winning_tile, true, _meld_tile_scale())
		return _create_claim_tile_stack(
			winning_tile,
			_meld_tile_scale(),
			_side_hand_tile_rotation_degrees(),
			_claim_arrow_text(viewer_seat, source_seat),
			false,
			true
		)
	var wrapper: BoxContainer = VBoxContainer.new() if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else VBoxContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_constant_override("separation", 4)
	var hu_group: BoxContainer = VBoxContainer.new() if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else HBoxContainer.new()
	hu_group.add_theme_constant_override("separation", 6)
	_render_hu_group(hu_group, player)
	wrapper.add_child(hu_group)
	if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		return wrapper
	return wrapper


func _render_exposed_meld_group(meld_group: BoxContainer, meld: Dictionary) -> void:
	var tiles: Array = meld.get("tiles", [])
	if tiles.is_empty():
		return
	var scale := _meld_tile_scale()
	var viewer_seat := _viewer_seat()
	var from_seat: int = int(meld.get("from_seat", viewer_seat))
	var claim_index := _claim_tile_index_for_meld(tiles.size(), viewer_seat, from_seat)
	var arrow_text := _claim_arrow_text(viewer_seat, from_seat)
	var show_back := _should_show_back_for_meld(meld)
	var reveal_one_tile := _is_concealed_gang_meld(meld)

	for index in range(tiles.size()):
		var tile_data: Dictionary = tiles[index]
		var tile_show_back := show_back and not (reveal_one_tile and index == 1)
		if index == claim_index and from_seat != viewer_seat:
			meld_group.add_child(_create_claim_tile_stack(tile_data, scale, 0.0, arrow_text, tile_show_back))
		else:
			meld_group.add_child(_create_plain_meld_tile(tile_data, scale, 0.0, tile_show_back))


func _create_exposed_meld_tiles_host(meld: Dictionary) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tiles: Array = meld.get("tiles", [])
	if tiles.is_empty():
		return host

	var scale := _meld_tile_scale()
	var viewer_seat := _viewer_seat()
	var from_seat: int = int(meld.get("from_seat", viewer_seat))
	var show_back := _should_show_back_for_meld(meld)
	var reveal_one_tile := _is_concealed_gang_meld(meld)
	var is_vertical := seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]
	var separation := SIDE_TILE_GAP if is_vertical else 2.0
	var tile_controls: Array[Control] = []
	var tile_size := Vector2.ZERO

	for index in range(tiles.size()):
		var tile_data: Dictionary = tiles[index]
		var tile_show_back := show_back and not (reveal_one_tile and index == 1)
		var tile := _create_side_hand_tile(tile_show_back, tile_data, false, scale) if is_vertical else _create_plain_meld_tile(tile_data, scale, 0.0, tile_show_back)
		if not is_vertical:
			_mark_visual_rect_host(tile)
		if tile_size == Vector2.ZERO:
			tile_size = tile.custom_minimum_size
		tile_controls.append(tile)
		host.add_child(tile)

	var oriented_size := tile_size
	var group_size: Vector2
	if is_vertical:
		group_size = Vector2(oriented_size.x, oriented_size.y * float(tiles.size()) + separation * maxf(0.0, float(tiles.size() - 1)))
	elif seat_dock == SeatDock.SELF:
		group_size = Vector2(oriented_size.x + SELF_MELD_TILE_STEP * maxf(0.0, float(tiles.size() - 1)), oriented_size.y)
	else:
		group_size = Vector2(oriented_size.x * float(tiles.size()) + separation * maxf(0.0, float(tiles.size() - 1)), oriented_size.y)
	host.custom_minimum_size = group_size
	host.size = group_size

	for index in range(tile_controls.size()):
		var tile := tile_controls[index]
		if is_vertical:
			tile.position = Vector2(0.0, float(index) * (oriented_size.y + separation))
		elif seat_dock == SeatDock.SELF:
			tile.position = Vector2(float(index) * SELF_MELD_TILE_STEP, 0.0)
		else:
			tile.position = Vector2(float(index) * (tile_size.x + separation), 0.0)

	if from_seat != viewer_seat:
		host.add_child(_create_claim_arrow_overlay(group_size, _claim_arrow_text(viewer_seat, from_seat), true))
	return host


func _render_hu_group(group: BoxContainer, player: Dictionary) -> void:
	var viewer_seat := _viewer_seat()
	var win_type: String = str(player.get("win_type", ""))
	var source_seat: int = int(player.get("winning_source_seat", viewer_seat))
	var winning_tile: Dictionary = player.get("winning_tile", {})
	if winning_tile.is_empty():
		return
	var scale := _meld_tile_scale()

	var winning_wrapper: Control
	if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		if win_type in ["self_draw", "gang_self_draw"] or source_seat == viewer_seat:
			winning_wrapper = _create_plain_meld_tile(winning_tile, _meld_tile_scale(), _side_hand_tile_rotation_degrees(), false, true)
		else:
			winning_wrapper = _create_claim_tile_stack(
				winning_tile,
				_meld_tile_scale(),
				_side_hand_tile_rotation_degrees(),
				_claim_arrow_text(viewer_seat, source_seat),
				false,
				true
			)
	elif win_type in ["self_draw", "gang_self_draw"]:
		winning_wrapper = _create_plain_meld_tile(winning_tile, scale * 1.08, 90.0 if seat_dock in [SeatDock.SELF, SeatDock.TOP] else 0.0, false, true)
	else:
		winning_wrapper = _create_claim_tile_stack(
			winning_tile,
			scale * 1.08,
			0.0,
			_claim_arrow_text(viewer_seat, source_seat),
			false,
			true
		)
	group.add_child(winning_wrapper)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _build_hand_render_signature(player: Dictionary, show_back: bool) -> String:
	return JSON.stringify({
		"seat": int(player.get("seat", -1)),
		"dock": int(seat_dock),
		"visible": hand_lane.visible,
		"show_back": show_back,
		"hand_count": int(player.get("hand_count", 0)),
		"tiles": _tile_signature_list(player.get("hand_tiles", []), not show_back),
	})


func _build_opponent_band_render_signature(player: Dictionary, show_back: bool) -> String:
	return JSON.stringify({
		"seat": int(player.get("seat", -1)),
		"dock": int(seat_dock),
		"visible": opponent_band.visible,
		"show_back": show_back,
		"size": [int(round(size.x)), int(round(size.y))],
		"hand_count": int(player.get("hand_count", 0)),
		"tiles": _tile_signature_list(player.get("hand_tiles", []), not show_back),
		"melds": _meld_signature_list(player.get("melds", [])),
		"has_won": bool(player.get("has_won", false)),
		"winning_tile": _single_tile_signature(player.get("winning_tile", {})),
		"winning_source_seat": int(player.get("winning_source_seat", -1)),
		"win_type": str(player.get("win_type", "")),
	})


func _build_melds_render_signature(player: Dictionary) -> String:
	return JSON.stringify({
		"seat": int(player.get("seat", -1)),
		"dock": int(seat_dock),
		"melds": _meld_signature_list(player.get("melds", [])),
		"has_won": bool(player.get("has_won", false)),
		"winning_tile": _single_tile_signature(player.get("winning_tile", {})),
	})


func _tile_signature_list(tiles: Array, include_faces: bool) -> Array:
	if not include_faces:
		return []
	var result: Array = []
	for tile in tiles:
		var tile_data: Dictionary = tile
		result.append(_single_tile_signature(tile_data))
	return result


func _single_tile_signature(tile: Dictionary) -> String:
	if tile.is_empty():
		return ""
	var tile_id := int(tile.get("id", -1))
	if tile_id >= 0:
		return str(tile_id)
	return "%s:%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


func _tile_key(tile_data: Dictionary) -> String:
	return "%s_%d" % [str(tile_data.get("suit", "")), int(tile_data.get("rank", 0))]


func _meld_signature_list(melds: Array) -> Array:
	var result: Array = []
	for meld in melds:
		var meld_data: Dictionary = meld
		result.append({
			"type": str(meld_data.get("type", "")),
			"seat": int(meld_data.get("seat", -1)),
			"from": int(meld_data.get("from_seat", -1)),
			"source": int(meld_data.get("source_seat", -1)),
			"tiles": _tile_signature_list(meld_data.get("tiles", []), true),
		})
	return result


func _create_plain_meld_tile(tile_data: Dictionary, scale: float, rotation: float, show_back: bool = false, highlight_winning: bool = false) -> Control:
	var tile := TILE_SCENE.instantiate()
	tile.call("configure", tile_data, scale, show_back, false, false, false, highlight_winning)
	return _wrap_tile_with_rotation(tile, rotation if rotation != 0.0 else _meld_rotation_degrees())


func _wrap_tile_with_rotation(tile: Control, rotation: float) -> Control:
	if absf(rotation) < 0.01:
		_mark_visual_rect_host(tile)
		return tile
	var tile_size := tile.custom_minimum_size
	var side_rotation := absf(fmod(absf(rotation), 180.0) - 90.0) < 0.1
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(tile_size.y, tile_size.x) if side_rotation else tile_size
	wrapper.size = wrapper.custom_minimum_size
	tile.position = (wrapper.custom_minimum_size - tile_size) * 0.5
	tile.rotation_degrees = rotation
	wrapper.add_child(tile)
	_mark_visual_rect_host(wrapper)
	return wrapper


func _create_side_hand_tile(show_back: bool, tile_data: Dictionary = {}, is_winning_tile: bool = false, scale_override: float = -1.0) -> Control:
	var tile := TILE_SCENE.instantiate()
	var scale := scale_override if scale_override > 0.0 else _side_hand_tile_scale()
	tile.call("configure", tile_data, scale, show_back and tile_data.is_empty(), false, false, false, is_winning_tile)
	var tile_size: Vector2 = tile.custom_minimum_size
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(tile_size.y, tile_size.x)
	wrapper.size = wrapper.custom_minimum_size
	tile.rotation_degrees = _side_hand_tile_rotation_degrees()
	tile.position = Vector2(
		(wrapper.custom_minimum_size.x - tile_size.x) * 0.5,
		(wrapper.custom_minimum_size.y - tile_size.y) * 0.5
	)
	wrapper.add_child(tile)
	_mark_visual_rect_host(wrapper)
	return wrapper


func _side_hand_tile_scale() -> float:
	if seat_dock == SeatDock.TOP:
		return TOP_ROW_TILE_SCALE
	return SIDE_HAND_TILE_SCALE


func _oriented_side_tile_size(scale_value: float) -> Vector2:
	var visual_size := _tile_visual_size_for_scale(scale_value)
	return Vector2(visual_size.y, visual_size.x)


func _mark_visual_rect_host(host: Control) -> void:
	host.set_meta("sichuan_tile_visual_rect", true)


func get_visual_tile_rects() -> Array:
	var rects: Array = []
	_collect_visual_tile_rects(opponent_band, rects)
	return rects


func get_track_rects() -> Dictionary:
	var result: Dictionary = {}
	for track_name in ["TopHandSlot", "TopMeldSlot", "TopHuSlot", "SideHandColumn", "SideMeldColumn", "SideHuSlot"]:
		var track := opponent_band.find_child(track_name, true, false) as Control
		if track != null and track.visible and track.size.x > 0.0 and track.size.y > 0.0:
			result[track_name] = track.get_global_rect()
	return result


func _collect_visual_tile_rects(node: Node, rects: Array) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta("sichuan_tile_visual_rect"):
			rects.append((child as Control).get_global_rect())
			continue
		_collect_visual_tile_rects(child, rects)


func _side_hand_tile_rotation_degrees() -> float:
	return _meld_rotation_degrees() + 180.0


func _create_claim_tile_stack(tile_data: Dictionary, scale: float, rotation: float, arrow_text: String, show_back: bool = false, highlight_winning: bool = false) -> Control:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tile := _create_plain_meld_tile(tile_data, scale, rotation, show_back, highlight_winning)
	var wrapper_size := tile.custom_minimum_size
	wrapper.custom_minimum_size = wrapper_size
	wrapper.size = wrapper_size
	tile.position = Vector2.ZERO
	wrapper.add_child(tile)

	wrapper.add_child(_create_claim_arrow_overlay(wrapper_size, arrow_text, true))
	_mark_visual_rect_host(wrapper)
	return wrapper


func _claim_tile_index_for_meld(tile_count: int, viewer_seat: int, from_seat: int) -> int:
	if tile_count <= 0:
		return 0
	if from_seat == viewer_seat:
		return clampi(tile_count - 1, 0, tile_count - 1)
	if seat_dock in [SeatDock.SELF, SeatDock.TOP]:
		match from_seat:
			1:
				return 0
			3:
				return tile_count - 1
			_:
				return mini(1, tile_count - 1)
	match from_seat:
		2:
			return 0
		0:
			return tile_count - 1
		_:
			return mini(1, tile_count - 1)


func _viewer_seat() -> int:
	match seat_dock:
		SeatDock.SELF:
			return 0
		SeatDock.LEFT:
			return 1
		SeatDock.TOP:
			return 2
		SeatDock.RIGHT:
			return 3
	return 0


func _meld_tile_scale() -> float:
	if seat_dock == SeatDock.SELF:
		return SELF_MELD_TILE_SCALE
	if seat_dock == SeatDock.TOP:
		return top_row_tile_scale
	if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		return SIDE_MELD_TILE_SCALE
	return 1.0


func _tile_visual_size_for_scale(tile_scale_value: float) -> Vector2:
	return Vector2(TILE_VISUAL_BASE_WIDTH, TILE_VISUAL_BASE_HEIGHT) * tile_scale_value


func _meld_rotation_degrees() -> float:
	if seat_dock == SeatDock.LEFT:
		return -90.0
	if seat_dock == SeatDock.RIGHT:
		return 90.0
	return 0.0


func _seat_tile_rotation_degrees() -> float:
	if seat_dock == SeatDock.LEFT:
		return -90.0
	if seat_dock == SeatDock.RIGHT:
		return 90.0
	return 0.0




func _meld_badge_text(meld: Dictionary) -> String:
	var meld_type := str(meld.get("type", ""))
	if meld_type == "peng":
		return "碰"
	if _is_concealed_gang_meld(meld):
		return "暗杠"
	if meld_type == "gang":
		return "杠"
	return ""


func _is_concealed_gang_meld(meld: Dictionary) -> bool:
	return str(meld.get("type", "")) == "gang" and str(meld.get("gang_subtype", "")) == "an_gang"


func _should_show_back_for_meld(meld: Dictionary) -> bool:
	return _is_concealed_gang_meld(meld)


func _build_meld_badge_style(meld: Dictionary) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.set_border_width_all(1)
	if _is_concealed_gang_meld(meld):
		style.bg_color = Color(0.22, 0.22, 0.22, 0.88)
		style.border_color = Color(0.88, 0.88, 0.88, 0.42)
	elif str(meld.get("type", "")) == "gang":
		style.bg_color = Color(0.53, 0.22, 0.80, 0.88)
		style.border_color = Color(0.88, 0.78, 1.0, 0.62)
	else:
		style.bg_color = Color(0.16, 0.43, 0.88, 0.88)
		style.border_color = Color(0.78, 0.90, 1.0, 0.62)
	return style


func _claim_arrow_text(viewer_seat: int, from_seat: int) -> String:
	if from_seat == viewer_seat:
		return "自摸"
	match from_seat:
		0:
			return "↓本家"
		1:
			return "←上家"
		2:
			return "↑对家"
		3:
			return "→下家"
		_:
			return "自摸"


func _claim_arrow_symbol(arrow_text: String) -> String:
	if arrow_text.begins_with("←"):
		return "◀"
	if arrow_text.begins_with("↑"):
		return "▲"
	if arrow_text.begins_with("→"):
		return "▶"
	if arrow_text.begins_with("↓"):
		return "▼"
	return "▲"


func _create_claim_arrow_overlay(tile_size: Vector2, arrow_text: String, centered: bool = false) -> Control:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.custom_minimum_size = tile_size
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0

	var badge_size := Vector2(26, 22) if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else Vector2(30, 24)
	var badge := Node2D.new()
	badge.position = tile_size * 0.5 if centered else Vector2(tile_size.x * 0.5, tile_size.y * 0.16)
	badge.rotation = _claim_arrow_rotation(arrow_text)
	overlay.add_child(badge)

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(0, -badge_size.y * 0.5),
		Vector2(badge_size.x * 0.56, badge_size.y * 0.46),
		Vector2(0, badge_size.y * 0.18),
		Vector2(-badge_size.x * 0.56, badge_size.y * 0.46),
	])
	shadow.color = Color(0.34, 0.22, 0.02, 0.18)
	shadow.position = Vector2(0, 2)
	badge.add_child(shadow)

	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(0, -badge_size.y * 0.5),
		Vector2(badge_size.x * 0.56, badge_size.y * 0.46),
		Vector2(0, badge_size.y * 0.18),
		Vector2(-badge_size.x * 0.56, badge_size.y * 0.46),
	])
	arrow.color = Color(1.0, 0.84, 0.18, 0.72)
	badge.add_child(arrow)

	var highlight := Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(0, -badge_size.y * 0.42),
		Vector2(badge_size.x * 0.28, badge_size.y * 0.12),
		Vector2(-badge_size.x * 0.28, badge_size.y * 0.12),
	])
	highlight.color = Color(1.0, 0.97, 0.70, 0.36)
	highlight.position = Vector2(0, -1)
	badge.add_child(highlight)

	var outline := Line2D.new()
	outline.width = 1.6
	outline.default_color = Color(0.70, 0.48, 0.04, 0.76)
	outline.closed = true
	outline.points = PackedVector2Array([
		Vector2(0, -badge_size.y * 0.5),
		Vector2(badge_size.x * 0.56, badge_size.y * 0.46),
		Vector2(0, badge_size.y * 0.18),
		Vector2(-badge_size.x * 0.56, badge_size.y * 0.46),
	])
	badge.add_child(outline)
	return overlay


func _claim_arrow_rotation(arrow_text: String) -> float:
	if arrow_text.begins_with("←"):
		return -PI * 0.5
	if arrow_text.begins_with("→"):
		return PI * 0.5
	if arrow_text.begins_with("↓"):
		return PI
	return 0.0


func _build_state_text(player: Dictionary, current_turn_seat: int, current_dealer_seat: int) -> String:
	if bool(player.get("has_won", false)):
		return ""
	if int(player.get("seat", -1)) == current_turn_seat:
		return "出牌中"
	if int(player.get("seat", -1)) == current_dealer_seat:
		return "庄家"
	return ""


func _apply_state_style(player: Dictionary, current_turn_seat: int, current_dealer_seat: int) -> void:
	var badge_style := StyleBoxFlat.new()
	badge_style.corner_radius_top_left = 10
	badge_style.corner_radius_top_right = 10
	badge_style.corner_radius_bottom_left = 10
	badge_style.corner_radius_bottom_right = 10
	badge_style.content_margin_left = 12
	badge_style.content_margin_right = 12
	badge_style.content_margin_top = 6
	badge_style.content_margin_bottom = 6
	badge_style.set_border_width_all(2)
	badge_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	badge_style.shadow_size = 3
	badge_style.shadow_offset = Vector2(0, 2)

	var seat := int(player.get("seat", -1))
	if bool(player.get("has_won", false)):
		badge_style.bg_color = Color(0.60, 0.47, 0.24, 0.96)
		badge_style.border_color = Color(0.90, 0.78, 0.52, 0.84)
	elif seat == current_turn_seat:
		badge_style.bg_color = Color(0.17, 0.36, 0.31, 0.98)
		badge_style.border_color = Color(0.72, 0.57, 0.32, 0.90)
		badge_style.set_border_width_all(2)
		badge_style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
		badge_style.shadow_size = 5
		badge_style.shadow_offset = Vector2(0, 3)
	elif seat == current_dealer_seat:
		badge_style.bg_color = Color(0.44, 0.24, 0.16, 0.96)
		badge_style.border_color = Color(0.78, 0.60, 0.36, 0.82)
	else:
		badge_style.bg_color = Color(0.16, 0.24, 0.21, 0.84)
		badge_style.border_color = Color(0.72, 0.57, 0.32, 0.24)
	state_tag.add_theme_stylebox_override("normal", badge_style)
	state_tag.add_theme_font_size_override("font_size", 22 if seat == current_turn_seat else (18 if seat_dock == SeatDock.SELF else 17))
	state_tag.scale = Vector2(1.14, 1.14) if seat == current_turn_seat else Vector2.ONE
	state_tag.pivot_offset = state_tag.size * 0.5
	state_tag.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86, 1.0))
	state_tag.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.92))
	state_tag.add_theme_constant_override("outline_size", 1)


func _apply_ding_que_style(suit: String) -> void:
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = _ding_que_color(suit)
	tag_style.corner_radius_top_left = 12
	tag_style.corner_radius_top_right = 12
	tag_style.corner_radius_bottom_left = 12
	tag_style.corner_radius_bottom_right = 12
	tag_style.content_margin_left = 14
	tag_style.content_margin_right = 14
	tag_style.content_margin_top = 8
	tag_style.content_margin_bottom = 8
	tag_style.set_border_width_all(2)
	tag_style.border_color = Color(0.82, 0.68, 0.42, 0.82)
	tag_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	tag_style.shadow_size = 4
	tag_style.shadow_offset = Vector2(0, 2)
	ding_que_tag.add_theme_stylebox_override("normal", tag_style)
	ding_que_tag.add_theme_font_size_override("font_size", 20 if seat_dock == SeatDock.SELF else 18)
	ding_que_tag.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86, 1.0))
	ding_que_tag.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.92))
	ding_que_tag.add_theme_constant_override("outline_size", 1)


func _apply_chip_style(label: Label, meld_type: String = "") -> void:
	var chip_style := StyleBoxFlat.new()
	chip_style.corner_radius_top_left = 8
	chip_style.corner_radius_top_right = 8
	chip_style.corner_radius_bottom_left = 8
	chip_style.corner_radius_bottom_right = 8
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 10
	chip_style.content_margin_top = 5
	chip_style.content_margin_bottom = 5
	chip_style.set_border_width_all(2)
	chip_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	chip_style.shadow_size = 3
	chip_style.shadow_offset = Vector2(0, 2)

	match meld_type:
		"PENG":
			chip_style.bg_color = Color(0.19, 0.45, 0.93, 0.96)
			chip_style.border_color = Color(0.76, 0.88, 1.0, 0.92)
		"GANG":
			chip_style.bg_color = Color(0.57, 0.24, 0.82, 0.96)
			chip_style.border_color = Color(0.88, 0.76, 1.0, 0.92)
		"HU":
			chip_style.bg_color = Color(0.84, 0.18, 0.12, 0.96)
			chip_style.border_color = Color(1.0, 0.82, 0.72, 0.92)
		_:
			chip_style.bg_color = Color(0.11, 0.17, 0.12, 0.82)
			chip_style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	label.add_theme_stylebox_override("normal", chip_style)
	label.add_theme_font_size_override("font_size", 16 if seat_dock == SeatDock.SELF else 15)


func _apply_name_style() -> void:
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.09, 0.30, 0.23, 0.82)
	title_style.border_color = Color(0.82, 0.95, 0.90, 0.18)
	title_style.set_border_width_all(1)
	title_style.corner_radius_top_left = 14
	title_style.corner_radius_top_right = 14
	title_style.corner_radius_bottom_left = 14
	title_style.corner_radius_bottom_right = 14
	title_style.content_margin_left = 12
	title_style.content_margin_right = 12
	title_style.content_margin_top = 6
	title_style.content_margin_bottom = 6
	title_style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	title_style.shadow_size = 2
	title_style.shadow_offset = Vector2(0, 2)
	title_label.add_theme_stylebox_override("normal", title_style)
	title_label.add_theme_font_size_override("font_size", 19 if seat_dock in [SeatDock.SELF, SeatDock.TOP] else 18)
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meta_label.add_theme_font_size_override("font_size", 15 if seat_dock in [SeatDock.SELF, SeatDock.TOP] else 14)


func _apply_player_win_state(player: Dictionary) -> void:
	var won := bool(player.get("has_won", false))
	root_panel.modulate = Color(0.66, 0.68, 0.66, 0.92) if won else Color.WHITE


func _apply_tag_layout(player: Dictionary, current_turn_seat: int) -> void:
	var is_current_player := int(player.get("seat", -1)) == current_turn_seat
	tag_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	state_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ding_que_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	if seat_dock == SeatDock.SELF:
		tag_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_row.move_child(ding_que_tag, 0)
		tag_row.move_child(state_tag, 1)
		tag_row.move_child(tag_spacer, 2)
		return

	if is_current_player:
		tag_row.move_child(state_tag, 0)
		tag_row.move_child(tag_spacer, 1)
		tag_row.move_child(ding_que_tag, 2)


func _apply_shell_style(bg: Color, border: Color, border_width: int, shadow_size: int) -> void:
	var style := StyleBoxFlat.new()
	if seat_dock != SeatDock.SELF and border_width == 0 and shadow_size == 0:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = Color(0.0, 0.0, 0.0, 0.0)
		style.set_border_width_all(0)
		style.corner_radius_top_left = 18
		style.corner_radius_top_right = 18
		style.corner_radius_bottom_left = 18
		style.corner_radius_bottom_right = 18
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
	else:
		style.bg_color = Color(bg.r, bg.g, bg.b, minf(bg.a, 0.54))
		style.border_color = Color(border.r, border.g, border.b, minf(border.a, 0.05))
		style.set_border_width_all(0)
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0, 2)
	root_panel.add_theme_stylebox_override("panel", style)


func _ding_que_color(suit: String) -> Color:
	match suit:
		"wan":
			return Color(0.48, 0.13, 0.16, 0.94)
		"tiao":
			return Color(0.16, 0.39, 0.27, 0.94)
		"tong":
			return Color(0.16, 0.30, 0.48, 0.94)
		_:
			return Color(0.18, 0.18, 0.16, 0.58)


func _ding_que_text(suit: String) -> String:
	match suit:
		"wan":
			return "缺万"
		"tiao":
			return "缺条"
		"tong":
			return "缺筒"
		_:
			return ""


func _verticalize_text(text: String) -> String:
	if text.is_empty():
		return ""
	var filtered: Array[String] = []
	for index in range(text.length()):
		var char := text.substr(index, 1)
		if char == "":
			continue
		filtered.append(char)
	return "\n".join(filtered)
