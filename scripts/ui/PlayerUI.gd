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
const SIDE_MELD_TILE_SCALE := 1.05
const SIDE_MELD_VERTICAL_OVERLAP := -10.0
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
@onready var discard_lane: GridContainer = %DiscardLane

var identity_overlay: Control
var identity_box: VBoxContainer
var identity_name_label: Label
var identity_ding_que_label: Label
var identity_win_stamp: Label
var identity_dealer_badge: Label
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
var discard_render_signature: String = ""
var top_row_tile_scale := TOP_ROW_TILE_SCALE


func _ready() -> void:
	if style_config == null:
		style_config = load("res://res/ui/default_ui_style.tres")
	root_panel.clip_contents = true
	_build_identity_overlay()
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
	var identity_player := player.duplicate(false)
	identity_player["_is_dealer"] = int(player.get("seat", -1)) == current_dealer_seat
	_apply_identity_snapshot(identity_player, ding_que_suit, show_ding_que_badges)
	_apply_player_win_state(player)

	_render_hand(player, show_back)
	_render_melds(player)
	_render_opponent_band(player, show_back)
	_render_discards(player.get("discards", []))


func _apply_style() -> void:
	style_config.apply_tabletop_zone_panel(root_panel)
	style_config.apply_label(title_label, false, true)
	style_config.apply_label(meta_label, true, false)
	style_config.apply_label(state_tag, false, false)
	style_config.apply_label(ding_que_tag, false, false)
	style_config.apply_label(identity_name_label, false, true)
	style_config.apply_label(identity_ding_que_label, false, true)
	style_config.apply_label(identity_win_stamp, false, true)
	style_config.apply_label(identity_dealer_badge, false, true)
	_apply_name_style()
	_apply_state_style({}, -1, -1)
	_apply_ding_que_style("")
	_apply_identity_name_style()
	_apply_identity_ding_que_style("")
	_apply_identity_win_stamp_style()
	_apply_identity_dealer_badge_style()


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
			discard_lane.visible = false
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
			_place_identity_overlay(Vector2(0.5, 1.52), Vector2(-116, -28), HORIZONTAL_ALIGNMENT_CENTER, Vector2(232, 98))
		SeatDock.TOP:
			root_panel.custom_minimum_size = Vector2(0, 204)
			custom_minimum_size = Vector2(1482, 210)
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
			discard_lane.visible = false
			root_vbox.add_theme_constant_override("separation", 0)
			meld_lane.alignment = BoxContainer.ALIGNMENT_CENTER
			hand_lane.custom_minimum_size = Vector2(0, 148)
			meld_lane.custom_minimum_size = Vector2(0, 148)
			hand_lane.visible = false
			meld_lane.visible = false
			opponent_band.add_theme_constant_override("separation", 2)
			opponent_band.alignment = BoxContainer.ALIGNMENT_BEGIN
			_apply_shell_style(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), 0, 0)
			_place_identity_overlay(Vector2(0.5, 0.0), Vector2(-88, -2), HORIZONTAL_ALIGNMENT_CENTER, Vector2(176, 156))
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
			discard_lane.visible = false
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
			if seat_dock == SeatDock.LEFT:
				_place_identity_overlay(Vector2(0.0, 0.50), Vector2(12, -76), HORIZONTAL_ALIGNMENT_CENTER, Vector2(132, 152))
			else:
				_place_identity_overlay(Vector2(1.0, 0.50), Vector2(-144, -76), HORIZONTAL_ALIGNMENT_CENTER, Vector2(132, 152))

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
		var is_bao_gang := _is_bao_gang_tile(player, source_tile_data)
		tile.call("configure", tile_data, scale, show_back and not reveal_tiles, false, is_bao_gang)
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
		var row_height := 184.0
		var content_x := 26.0

		var row_root := _create_fixed_slot(row_width, row_height)
		row_root.name = "HorizontalRowRoot"
		var row_x := maxf(8.0, layout_width - row_width - 8.0)
		var row_rect := Rect2(Vector2(row_x, 6.0), Vector2(row_width, row_height))
		_place_rect_in_parent(layout_root, row_root, row_rect)
		_apply_band_slot_plate(row_root, false, true)

		var top_slot_height := 166.0
		var top_slot_y := 9.0
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
			var is_bao_gang := _is_bao_gang_tile(player, source_tile_data)
			top_tile.call("configure", tile_data, top_row_tile_scale, show_back and tile_data.is_empty(), false, is_bao_gang)
			top_tile.rotation_degrees = _seat_tile_rotation_degrees()
			top_hand_box.add_child(top_tile)

		if has_hu:
			var hu_center := CenterContainer.new()
			hu_center.set_anchors_preset(Control.PRESET_FULL_RECT)
			hu_slot.add_child(hu_center)
			hu_center.add_child(hu_wrapper)
		return

	var layout_root := _create_band_layout_root()
	var layout_width := 340.0 if size.x <= 1.0 else size.x
	var layout_height := 660.0 if size.y <= 1.0 else size.y
	layout_root.custom_minimum_size = Vector2(layout_width, layout_height)
	layout_root.size = layout_root.custom_minimum_size
	opponent_band.add_child(layout_root)

	var side_hand_width := 120.0
	var side_meld_width := 184.0
	var side_margin := 6.0
	var side_gap := 8.0
	var hand_rect := Rect2(Vector2(side_margin, 20.0), Vector2(side_hand_width, layout_height - 92.0)) if seat_dock == SeatDock.LEFT else Rect2(Vector2(layout_width - side_margin - side_hand_width, 20.0), Vector2(side_hand_width, layout_height - 92.0))
	var side_content_x := hand_rect.end.x + side_gap if seat_dock == SeatDock.LEFT else hand_rect.position.x - side_gap - side_meld_width
	var side_content_y := 0.0
	var meld_height := layout_height if has_melds else 0.0
	var meld_tile_visual_size := _tile_visual_size_for_scale(_meld_tile_scale())
	var hu_width := maxf(side_meld_width, meld_tile_visual_size.y + 16.0)
	var hu_height := maxf(122.0, meld_tile_visual_size.x + 16.0)
	var hu_gap := 10.0
	var hu_x := 0.0 if seat_dock == SeatDock.LEFT else layout_width - hu_width
	var hu_rect := Rect2(Vector2(hu_x, hand_rect.end.y - hu_height), Vector2(hu_width, hu_height))
	if has_hu:
		hand_rect = Rect2(hand_rect.position, Vector2(hand_rect.size.x, maxf(96.0, hand_rect.size.y - hu_height - hu_gap)))
		hu_rect.position.y = hand_rect.end.y + hu_gap
	var meld_rect := Rect2(Vector2(side_content_x, side_content_y), Vector2(side_meld_width, meld_height))

	var hand_column := _create_fixed_slot(hand_rect.size.x, hand_rect.size.y)
	var meld_column := _create_fixed_slot(meld_rect.size.x, meld_rect.size.y)
	var hu_slot := _create_fixed_slot(hu_rect.size.x, hu_rect.size.y)
	hand_column.name = "SideHandColumn"
	meld_column.name = "SideMeldColumn"
	hu_slot.name = "SideHuSlot"
	_place_rect_in_parent(layout_root, hand_column, hand_rect)
	_place_rect_in_parent(layout_root, meld_column, meld_rect)
	_place_rect_in_parent(layout_root, hu_slot, hu_rect)
	_apply_band_slot_plate(hand_column, false, true)
	meld_column.visible = has_melds
	hu_slot.visible = has_hu
	if has_melds:
		_apply_band_slot_plate(meld_column, false, false)

	var hand_vbox := VBoxContainer.new()
	hand_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hand_vbox.add_theme_constant_override("separation", 4)
	hand_column.add_child(hand_vbox)

	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", _side_hand_gap_for_count(mini(hand_count, 14), hand_rect.size.y))
	hand_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_vbox.add_child(hand_box)
	for index in range(mini(hand_count, 14)):
		var source_tile_data: Dictionary = hand_tiles[index] if index < hand_tiles.size() else {}
		var tile_data: Dictionary = source_tile_data if not show_back else {}
		var is_bao_gang := _is_bao_gang_tile(player, source_tile_data)
		hand_box.add_child(_create_side_hand_tile(show_back and tile_data.is_empty(), tile_data, false, -1.0, is_bao_gang))

	if has_hu:
		var hu_center := CenterContainer.new()
		hu_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		hu_slot.add_child(hu_center)
		hu_center.add_child(hu_wrapper)

	var meld_vbox := VBoxContainer.new()
	meld_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	meld_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	meld_vbox.add_theme_constant_override("separation", 4)
	meld_column.add_child(meld_vbox)
	for meld in melds:
		meld_vbox.add_child(_create_meld_display_wrapper(meld))


func _render_discards(discards: Array) -> void:
	var signature := _build_discards_render_signature(discards)
	if signature == discard_render_signature:
		return
	discard_render_signature = signature
	_clear_children(discard_lane)
	if not discard_lane.visible:
		return

	var visible_discards := discards.duplicate(true)
	if seat_dock == SeatDock.TOP:
		visible_discards = visible_discards.slice(maxi(0, visible_discards.size() - 8), visible_discards.size())
	elif seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		visible_discards = visible_discards.slice(maxi(0, visible_discards.size() - 6), visible_discards.size())

	for tile_data in visible_discards:
		var tile := TILE_SCENE.instantiate()
		var scale := 0.56 if seat_dock == SeatDock.TOP else 0.6
		tile.call("configure", tile_data, scale, false, false, false)
		tile.rotation_degrees = _seat_tile_rotation_degrees()
		discard_lane.add_child(tile)


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
		var group_height := tile_count * tile_step + maxf(0.0, tile_count - 1.0) * (1.0 + SIDE_MELD_VERTICAL_OVERLAP)
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
	style_config.apply_tabletop_zone_panel(panel)
	panel.visible = false


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
	var separation := 1.0 if is_vertical else 2.0
	var tile_controls: Array[Control] = []
	var tile_size := Vector2.ZERO

	for index in range(tiles.size()):
		var tile_data: Dictionary = tiles[index]
		var tile_show_back := show_back and not (reveal_one_tile and index == 1)
		var tile := _create_plain_meld_tile(tile_data, scale, 0.0, tile_show_back)
		if tile_size == Vector2.ZERO:
			tile_size = tile.custom_minimum_size
		tile_controls.append(tile)
		host.add_child(tile)

	var oriented_size := Vector2(tile_size.y, tile_size.x) if is_vertical else tile_size
	var group_size: Vector2
	if is_vertical:
		group_size = Vector2(oriented_size.x, oriented_size.y * float(tiles.size()) + (separation + SIDE_MELD_VERTICAL_OVERLAP) * maxf(0.0, float(tiles.size() - 1)))
	elif seat_dock == SeatDock.SELF:
		group_size = Vector2(oriented_size.x + SELF_MELD_TILE_STEP * maxf(0.0, float(tiles.size() - 1)), oriented_size.y)
	else:
		group_size = Vector2(oriented_size.x * float(tiles.size()) + separation * maxf(0.0, float(tiles.size() - 1)), oriented_size.y)
	host.custom_minimum_size = group_size
	host.size = group_size

	for index in range(tile_controls.size()):
		var tile := tile_controls[index]
		if is_vertical:
			var padding := (tile_size.y - oriented_size.y) * 0.5
			tile.position = Vector2(
				(oriented_size.x - tile_size.x) * 0.5,
				float(index) * (oriented_size.y + separation + SIDE_MELD_VERTICAL_OVERLAP) - padding
			)
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
		"bao_gang": player.get("bao_gang_tiles", []).duplicate(),
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
		"bao_gang": player.get("bao_gang_tiles", []).duplicate(),
		"melds": _meld_signature_list(player.get("melds", [])),
		"has_won": bool(player.get("has_won", false)),
		"winning_tile": _single_tile_signature(player.get("winning_tile", {})),
		"winning_source_seat": int(player.get("winning_source_seat", -1)),
		"win_type": str(player.get("win_type", "")),
	})


func _build_discards_render_signature(discards: Array) -> String:
	return JSON.stringify({
		"dock": int(seat_dock),
		"visible": discard_lane.visible,
		"tiles": _tile_signature_list(discards, true),
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


func _is_bao_gang_tile(player: Dictionary, tile_data: Dictionary) -> bool:
	var bao_gang_keys: Array = player.get("bao_gang_tiles", [])
	if bao_gang_keys.is_empty() or tile_data.is_empty():
		return false
	return bao_gang_keys.has(_tile_key(tile_data))


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
	tile.rotation_degrees = rotation if rotation != 0.0 else _meld_rotation_degrees()
	return tile


func _create_side_hand_tile(show_back: bool, tile_data: Dictionary = {}, is_winning_tile: bool = false, scale_override: float = -1.0, is_bao_gang_tile: bool = false) -> Control:
	var tile := TILE_SCENE.instantiate()
	var scale := scale_override if scale_override > 0.0 else _side_hand_tile_scale()
	tile.call("configure", tile_data, scale, show_back and tile_data.is_empty(), false, is_bao_gang_tile, false, is_winning_tile)
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
	return wrapper


func _side_hand_tile_scale() -> float:
	if seat_dock == SeatDock.TOP:
		return TOP_ROW_TILE_SCALE
	return SIDE_HAND_TILE_SCALE


func _side_hand_gap_for_count(tile_count: int, available_height: float) -> int:
	if tile_count <= 1:
		return 0
	var oriented_tile_height := _tile_visual_size_for_scale(_side_hand_tile_scale()).x
	var fit_gap := (available_height - oriented_tile_height * float(tile_count)) / float(tile_count - 1)
	return int(floor(clampf(fit_gap, -32.0, 4.0)))


func _side_hand_tile_rotation_degrees() -> float:
	return _meld_rotation_degrees() + 180.0


func _create_claim_tile_stack(tile_data: Dictionary, scale: float, rotation: float, arrow_text: String, show_back: bool = false, highlight_winning: bool = false) -> Control:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tile := _create_plain_meld_tile(tile_data, scale, rotation, show_back, highlight_winning)
	var tile_size := tile.custom_minimum_size
	var is_side_rotation := absf(fmod(absf(rotation), 180.0) - 90.0) < 0.1
	var wrapper_size := Vector2(tile_size.y, tile_size.x) if is_side_rotation else tile_size
	wrapper.custom_minimum_size = wrapper_size
	wrapper.size = wrapper_size
	tile.position = Vector2(
		(wrapper_size.x - tile_size.x) * 0.5,
		(wrapper_size.y - tile_size.y) * 0.5
	)
	wrapper.add_child(tile)

	wrapper.add_child(_create_claim_arrow_overlay(wrapper_size, arrow_text, true))
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
	if bool(player.get("bao_jiao", false)):
		return "报叫"
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


func _build_identity_overlay() -> void:
	identity_overlay = Control.new()
	identity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.add_child(identity_overlay)

	identity_box = VBoxContainer.new()
	identity_box.add_theme_constant_override("separation", 8)
	identity_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_overlay.add_child(identity_box)

	identity_name_label = Label.new()
	identity_name_label.text = "Player"
	identity_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_box.add_child(identity_name_label)

	identity_win_stamp = Label.new()
	identity_win_stamp.text = "已胡"
	identity_win_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_win_stamp.visible = false
	identity_name_label.add_child(identity_win_stamp)

	identity_dealer_badge = Label.new()
	identity_dealer_badge.text = "庄"
	identity_dealer_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_dealer_badge.visible = false
	identity_name_label.add_child(identity_dealer_badge)

	identity_ding_que_label = Label.new()
	identity_ding_que_label.text = ""
	identity_ding_que_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_box.add_child(identity_ding_que_label)


func _place_identity_overlay(anchor: Vector2, offset: Vector2, align: HorizontalAlignment, box_size: Vector2 = Vector2(180, 82)) -> void:
	identity_box.anchor_left = anchor.x
	identity_box.anchor_right = anchor.x
	identity_box.anchor_top = anchor.y
	identity_box.anchor_bottom = anchor.y
	identity_box.offset_left = offset.x
	identity_box.offset_top = offset.y
	identity_box.offset_right = offset.x + box_size.x
	identity_box.offset_bottom = offset.y + box_size.y
	identity_box.custom_minimum_size = box_size
	identity_name_label.horizontal_alignment = align
	identity_ding_que_label.horizontal_alignment = align


func _apply_identity_snapshot(player: Dictionary, ding_que_suit: String, show_ding_que_badges: bool) -> void:
	var score := int(player.get("score", 0))
	var nickname := str(player.get("nickname", "-"))
	identity_box.visible = false
	if seat_dock == SeatDock.LEFT:
		identity_name_label.text = "%s\n%d分" % [nickname, score]
	elif seat_dock == SeatDock.TOP:
		identity_name_label.text = "%s\n%d分" % [nickname, score]
	elif seat_dock == SeatDock.RIGHT:
		identity_name_label.text = "%s\n%d分" % [nickname, score]
	else:
		identity_name_label.text = "%s\n%d分" % [nickname, score]
	if identity_dealer_badge != null:
		identity_dealer_badge.visible = bool(player.get("_is_dealer", false)) and seat_dock != SeatDock.SELF
		_position_identity_dealer_badge()

	identity_ding_que_label.text = _identity_status_text(player, ding_que_suit, show_ding_que_badges)
	identity_ding_que_label.visible = not identity_ding_que_label.text.is_empty() and seat_dock != SeatDock.SELF
	if seat_dock == SeatDock.SELF:
		identity_box.move_child(identity_ding_que_label, 0)
		identity_box.move_child(identity_name_label, 1)
	else:
		identity_box.move_child(identity_name_label, 0)
		identity_box.move_child(identity_ding_que_label, 1)
	_apply_identity_ding_que_style(ding_que_suit)


func _apply_player_win_state(player: Dictionary) -> void:
	var won := bool(player.get("has_won", false))
	var dim_color := Color(0.70, 0.70, 0.70, 0.92)
	var normal_color := Color(1.0, 1.0, 1.0, 1.0)
	root_panel.modulate = dim_color if won else normal_color
	if identity_box != null:
		identity_box.modulate = dim_color if won else normal_color
	if identity_win_stamp != null:
		identity_win_stamp.visible = won and seat_dock != SeatDock.SELF


func _apply_identity_name_style() -> void:
	var style := _build_identity_plate_style(Color(0.08, 0.30, 0.23, 0.82), Color(0.92, 1.0, 0.88, 0.24), 18, 8)
	identity_name_label.add_theme_stylebox_override("normal", style)
	identity_name_label.remove_theme_font_override("font")
	identity_name_label.add_theme_font_size_override("font_size", _identity_name_font_size())
	identity_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_name_label.custom_minimum_size = Vector2(156 if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else 148, 102 if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT] else 84)
	identity_name_label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.96, 1.0))
	identity_name_label.add_theme_color_override("font_outline_color", Color(0.03, 0.12, 0.08, 0.92))
	identity_name_label.add_theme_constant_override("outline_size", 3 if seat_dock != SeatDock.SELF else 2)
	identity_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.18))
	identity_name_label.add_theme_constant_override("shadow_offset_x", 0)
	identity_name_label.add_theme_constant_override("shadow_offset_y", 2)
	identity_name_label.add_theme_constant_override("line_spacing", 8)


func _identity_name_font_size() -> int:
	if seat_dock in [SeatDock.LEFT, SeatDock.RIGHT]:
		return 30
	if seat_dock == SeatDock.TOP:
		return 28
	return 28


func _apply_identity_win_stamp_style() -> void:
	var stamp_style := StyleBoxFlat.new()
	stamp_style.bg_color = Color(0.46, 0.05, 0.03, 0.18)
	stamp_style.border_color = Color(0.88, 0.14, 0.08, 0.98)
	stamp_style.set_border_width_all(5)
	stamp_style.corner_radius_top_left = 12
	stamp_style.corner_radius_top_right = 12
	stamp_style.corner_radius_bottom_left = 12
	stamp_style.corner_radius_bottom_right = 12
	stamp_style.content_margin_left = 18
	stamp_style.content_margin_right = 18
	stamp_style.content_margin_top = 8
	stamp_style.content_margin_bottom = 8
	stamp_style.shadow_color = Color(0.18, 0.02, 0.00, 0.34)
	stamp_style.shadow_size = 10
	stamp_style.shadow_offset = Vector2(0, 4)
	identity_win_stamp.add_theme_stylebox_override("normal", stamp_style)
	identity_win_stamp.add_theme_font_size_override("font_size", 48 if seat_dock == SeatDock.TOP else 42)
	identity_win_stamp.add_theme_color_override("font_color", Color(0.97, 0.16, 0.10, 0.98))
	identity_win_stamp.add_theme_color_override("font_outline_color", Color(1.0, 0.84, 0.80, 0.54))
	identity_win_stamp.add_theme_color_override("font_shadow_color", Color(0.46, 0.03, 0.02, 0.30))
	identity_win_stamp.add_theme_constant_override("outline_size", 3)
	identity_win_stamp.add_theme_constant_override("shadow_offset_x", 0)
	identity_win_stamp.add_theme_constant_override("shadow_offset_y", 3)
	identity_win_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_win_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_win_stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	identity_win_stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_win_stamp.rotation_degrees = -16.0
	identity_win_stamp.custom_minimum_size = Vector2(126, 62)
	identity_win_stamp.position = Vector2(94, -4) if seat_dock == SeatDock.TOP else Vector2(72, 6)
	identity_win_stamp.pivot_offset = Vector2(63, 31)


func _apply_identity_dealer_badge_style() -> void:
	if identity_dealer_badge == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.07, 0.03, 0.97)
	style.border_color = Color(1.0, 0.78, 0.22, 0.98)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	identity_dealer_badge.add_theme_stylebox_override("normal", style)
	identity_dealer_badge.add_theme_font_size_override("font_size", 36)
	identity_dealer_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
	identity_dealer_badge.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.95))
	identity_dealer_badge.add_theme_constant_override("outline_size", 4)
	identity_dealer_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_dealer_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_dealer_badge.custom_minimum_size = Vector2(76, 56)


func _position_identity_dealer_badge() -> void:
	if identity_dealer_badge == null:
		return
	var label_width := maxf(identity_name_label.size.x, identity_name_label.custom_minimum_size.x)
	identity_dealer_badge.position = Vector2(label_width - identity_dealer_badge.custom_minimum_size.x + 8.0, -22.0)


func _apply_identity_ding_que_style(suit: String) -> void:
	var status_text := "" if identity_ding_que_label == null else str(identity_ding_que_label.text)
	var has_bao_gang := status_text.find("杠") != -1
	var has_bao_jiao := status_text.find("报叫") != -1
	var palette := _ding_que_badge_palette(suit)
	var bg: Color = palette.get("bg", _ding_que_color(suit))
	var border: Color = palette.get("border", Color(0.82, 0.95, 0.90, 0.20))
	var font_color: Color = palette.get("font", Color(0.96, 0.94, 0.86, 1.0))
	var outline_color: Color = palette.get("outline", Color(0.04, 0.12, 0.10, 0.88))
	var shadow := Color(0.0, 0.0, 0.0, 0.24)
	var shadow_size := 6
	if has_bao_gang:
		bg = Color(0.69, 0.53, 0.17, 0.94)
		border = Color(0.94, 0.86, 0.56, 0.92)
		shadow = Color(0.32, 0.15, 0.00, 0.32)
		shadow_size = 7
	elif has_bao_jiao:
		bg = Color(0.63, 0.25, 0.21, 0.90)
		border = Color(0.95, 0.79, 0.64, 0.82)
		shadow = Color(0.22, 0.06, 0.03, 0.26)
	var style := _build_identity_plate_style(bg, border, 16, shadow_size)
	style.shadow_color = shadow
	style.set_border_width_all(3 if not has_bao_gang and not has_bao_jiao else 4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	identity_ding_que_label.add_theme_stylebox_override("normal", style)
	identity_ding_que_label.add_theme_font_size_override("font_size", 32)
	identity_ding_que_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_ding_que_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_ding_que_label.custom_minimum_size = Vector2(176, 64)
	identity_ding_que_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0) if has_bao_gang else font_color)
	identity_ding_que_label.add_theme_color_override("font_outline_color", Color(0.22, 0.10, 0.03, 0.96) if has_bao_gang else outline_color)
	identity_ding_que_label.add_theme_constant_override("outline_size", 4)


func _ding_que_badge_palette(suit: String) -> Dictionary:
	match suit:
		"wan":
			return {
				"bg": Color(0.58, 0.10, 0.08, 0.96),
				"border": Color(1.0, 0.58, 0.36, 0.96),
				"font": Color(1.0, 0.92, 0.80, 1.0),
				"outline": Color(0.20, 0.02, 0.01, 0.96),
			}
		"tiao":
			return {
				"bg": Color(0.09, 0.40, 0.20, 0.96),
				"border": Color(0.54, 0.96, 0.58, 0.94),
				"font": Color(0.90, 1.0, 0.86, 1.0),
				"outline": Color(0.01, 0.14, 0.06, 0.96),
			}
		"tong":
			return {
				"bg": Color(0.08, 0.28, 0.58, 0.96),
				"border": Color(0.48, 0.82, 1.0, 0.94),
				"font": Color(0.88, 0.96, 1.0, 1.0),
				"outline": Color(0.01, 0.08, 0.18, 0.96),
			}
		_:
			return {
				"bg": Color(0.30, 0.29, 0.25, 0.96),
				"border": Color(0.82, 0.95, 0.90, 0.26),
				"font": Color(0.96, 0.94, 0.86, 1.0),
				"outline": Color(0.04, 0.12, 0.10, 0.88),
			}


func _build_identity_plate_style(bg: Color, border: Color, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg.lightened(0.05)
	style.border_color = border.lightened(0.18)
	style.set_border_width_all(1)
	var restrained_radius := mini(radius, 8)
	style.corner_radius_top_left = restrained_radius
	style.corner_radius_top_right = restrained_radius
	style.corner_radius_bottom_left = restrained_radius
	style.corner_radius_bottom_right = restrained_radius
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style.shadow_size = mini(shadow_size, 4)
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.3
	return style


func _create_top_inline_identity_card(player: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 6)
	card.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(168, 0)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(header_row)

	var name_label := Label.new()
	name_label.text = "%s\n%d分" % [str(player.get("nickname", "-")), int(player.get("score", 0))]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(168, 54)
	style_config.apply_label(name_label, false, true)
	name_label.add_theme_stylebox_override("normal", _build_top_identity_name_style())
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.96, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.14, 0.10, 0.86))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_constant_override("line_spacing", 4)
	header_row.add_child(name_label)

	if bool(player.get("_is_dealer", false)):
		var dealer_badge := Label.new()
		dealer_badge.text = "庄"
		dealer_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dealer_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dealer_badge.custom_minimum_size = Vector2(76, 56)
		style_config.apply_label(dealer_badge, false, false)
		dealer_badge.add_theme_stylebox_override("normal", _build_top_identity_dealer_style())
		dealer_badge.add_theme_font_size_override("font_size", 36)
		dealer_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
		dealer_badge.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.95))
		dealer_badge.add_theme_constant_override("outline_size", 4)
		dealer_badge.position = Vector2(108, -24)
		name_label.add_child(dealer_badge)

	if bool(player.get("has_won", false)):
		var won_stamp := Label.new()
		won_stamp.text = "已胡"
		won_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		won_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		style_config.apply_label(won_stamp, false, true)
		won_stamp.add_theme_stylebox_override("normal", _build_top_identity_win_style())
		won_stamp.add_theme_font_size_override("font_size", 32)
		won_stamp.add_theme_constant_override("outline_size", 3)
		won_stamp.custom_minimum_size = Vector2(102, 50)
		won_stamp.rotation_degrees = -16.0
		won_stamp.position = Vector2(88, -10)
		name_label.add_child(won_stamp)

	var state_text := _build_state_text(player, last_current_turn_seat, last_current_dealer_seat)
	if not state_text.is_empty():
		var state_label := Label.new()
		state_label.text = state_text
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		style_config.apply_label(state_label, false, false)
		_apply_inline_top_state_style(state_label, player)
		header_row.add_child(state_label)

	var status_text := _identity_status_text(
		player,
		str(player.get("ding_que", "")),
		last_show_ding_que_badges
	)
	if not status_text.is_empty():
		var status_row := HBoxContainer.new()
		status_row.add_theme_constant_override("separation", 6)
		status_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(status_row)
		var info_label := Label.new()
		info_label.text = status_text
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		style_config.apply_label(info_label, false, false)
		info_label.add_theme_stylebox_override("normal", _build_top_identity_info_style(player))
		info_label.add_theme_font_size_override("font_size", 15)
		info_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84, 1.0))
		info_label.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.03, 0.92))
		info_label.add_theme_constant_override("outline_size", 1)
		status_row.add_child(info_label)

	return card


func _build_top_identity_name_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.25, 0.19, 0.54)
	style.border_color = Color(0.84, 0.95, 0.90, 0.04)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


func _build_top_identity_dealer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.07, 0.03, 0.97)
	style.border_color = Color(1.0, 0.78, 0.22, 0.98)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


func _build_top_identity_win_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.50, 0.06, 0.04, 0.16)
	style.border_color = Color(0.96, 0.23, 0.14, 0.96)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.34, 0.05, 0.02, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


func _build_top_identity_info_style(player: Dictionary) -> StyleBoxFlat:
	var status_text := _identity_status_text(player, str(player.get("ding_que", "")), last_show_ding_que_badges)
	var style := StyleBoxFlat.new()
	if status_text.find("杠") != -1:
		style.bg_color = Color(0.69, 0.53, 0.17, 0.94)
		style.border_color = Color(0.94, 0.86, 0.56, 0.92)
	elif status_text.find("报叫") != -1:
		style.bg_color = Color(0.63, 0.25, 0.21, 0.90)
		style.border_color = Color(0.95, 0.79, 0.64, 0.82)
	else:
		var ding_color := _ding_que_color(str(player.get("ding_que", ""))).darkened(0.10)
		style.bg_color = Color(ding_color.r, ding_color.g, ding_color.b, 0.58)
		style.border_color = Color(0.82, 0.95, 0.90, 0.12)
	style.set_border_width_all(1 if not status_text.is_empty() else 0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _apply_inline_top_state_style(label: Label, player: Dictionary) -> void:
	var badge_style := StyleBoxFlat.new()
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 5
	badge_style.content_margin_bottom = 5
	badge_style.set_border_width_all(2)
	badge_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	badge_style.shadow_size = 4
	badge_style.shadow_offset = Vector2(0, 2)

	var seat := int(player.get("seat", -1))
	if bool(player.get("has_won", false)):
		badge_style.bg_color = Color(0.67, 0.48, 0.22, 0.96)
		badge_style.border_color = Color(1.0, 0.86, 0.50, 0.96)
	elif seat == last_current_turn_seat:
		badge_style.bg_color = Color(0.19, 0.47, 0.34, 0.96)
		badge_style.border_color = Color(0.90, 0.94, 0.80, 0.48)
	else:
		badge_style.bg_color = Color(0.08, 0.30, 0.23, 0.82)
		badge_style.border_color = Color(0.82, 0.95, 0.90, 0.18)
	label.add_theme_stylebox_override("normal", badge_style)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04, 0.92))
	label.add_theme_constant_override("outline_size", 1)


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


func _identity_status_text(player: Dictionary, ding_que_suit: String, show_ding_que_badges: bool) -> String:
	var parts: Array[String] = []
	if bool(player.get("bao_jiao", false)):
		var bao_gang_count := int(Array(player.get("bao_gang_tiles", [])).size())
		parts.append("报叫")
		if bao_gang_count > 0:
			parts.append("杠x%d" % bao_gang_count)
	var ding_que_text := _ding_que_text(ding_que_suit)
	if show_ding_que_badges and not ding_que_text.is_empty():
		parts.append(ding_que_text)
	return " · ".join(parts)


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
