class_name CenterTurnIndicator
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const DIRECTION_LABELS := ["东", "南", "西", "北"]
const SEGMENT_FOR_SEAT := [2, 3, 0, 1]

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var compass_visual: Control = %CompassVisual
@onready var top_direction_label: Label = %CaptionLabel
@onready var countdown_label: Label = %CountLabel
@onready var bottom_direction_label: Label = %StatusLabel
@onready var wall_count_label: Label = %TurnChipLabel
@onready var left_direction_label: Label = %LeftDirectionLabel
@onready var right_direction_label: Label = %RightDirectionLabel

var compact := false
var current_turn_seat := -1
var wall_count := 0
var reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [top_direction_label, countdown_label, bottom_direction_label, wall_count_label, left_direction_label, right_direction_label]:
		STYLE_CONFIG.apply_label(label, false, false)
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	_configure_direction_copy()
	_apply_layout()
	# 3D 对局把数字直接贴在实体中心盘上；这里仅保留非 3D 降级路径
	# 的静态数字，不能出现悬浮、绕行或旋转动效。
	set_process(false)


func render(next_wall_count: int, turn_seat: int, _status_text: String = "") -> void:
	var next_seat := turn_seat if turn_seat >= 0 and turn_seat < 4 else -1
	if next_seat != current_turn_seat:
		current_turn_seat = next_seat
	wall_count = maxi(0, next_wall_count)
	wall_count_label.text = str(wall_count)
	if compass_visual != null:
		compass_visual.call("configure", current_turn_seat, reduced_motion)
	_apply_direction_styles()


func set_compact(compact_value: bool) -> void:
	compact = compact_value
	custom_minimum_size = METRICS.center_indicator_size(compact)
	size = custom_minimum_size
	_apply_layout()


func get_reserved_rect() -> Rect2:
	return get_global_rect()


func get_active_direction_text() -> String:
	if current_turn_seat < 0:
		return ""
	return DIRECTION_LABELS[SEGMENT_FOR_SEAT[current_turn_seat]]


func get_visual_contract() -> Dictionary:
	return {
		"concept": "reference_four_way_turn_panel",
		"physical_asset": "blender_authored_flush_glass_four_way_inlay",
		"shape": "flush_chamfered_glass_inlay_with_circular_counter",
		"material": "gloss_smoked_jade_glass_with_clean_outer_edges_and_central_antique_bronze_counter",
		"primary_information": "turn_direction_and_static_wall_count",
		"wall_count_surface": "static_number_in_central_circular_counter",
		"wall_count_format": "%d",
		"wall_count_motion": "none",
		"direction_labels": DIRECTION_LABELS,
		"active_encoding": ["opaque_vivid_red_main_field_and_both_chamfer_fills", "warm_ivory_direction_glyph_with_dark_outline"],
		"active_color_hex": "A13D2D",
		"active_direction": get_active_direction_text(),
		"overlay_frames": "owned_by_3d_table_stage_without_duplicate_2d_panel",
		"persistent_long_status_text": false,
		"visual_density": "low",
		"maximum_layout_size": Vector2(210.0, 210.0),
		"turn_countdown": "removed",
		"center_copy": "removed",
	}


func _apply_layout() -> void:
	if background_panel == null:
		return
	craft_panel.visible = false
	background_panel.visible = false
	# This fallback is hidden as a whole while the physical 3D stage is active,
	# but remains complete if 3D initialization is unavailable.
	compass_visual.visible = true
	background_panel.add_theme_stylebox_override("panel", _transparent_style())
	wall_count_label.visible = true
	wall_count_label.add_theme_font_size_override("font_size", 30 if compact else 36)
	wall_count_label.add_theme_color_override("font_color", Color("F3E7C6"))
	wall_count_label.add_theme_color_override("font_outline_color", Color("061512"))
	wall_count_label.add_theme_constant_override("outline_size", 5)
	wall_count_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.01, 0.62))
	wall_count_label.add_theme_constant_override("shadow_offset_x", 2)
	wall_count_label.add_theme_constant_override("shadow_offset_y", 4)
	wall_count_label.add_theme_stylebox_override("normal", _transparent_style())
	_apply_direction_styles()
	_layout_labels()


func _layout_labels() -> void:
	var scale := size.x / 210.0
	var label_box := Vector2(30.0, 32.0) * scale
	top_direction_label.size = label_box
	top_direction_label.position = Vector2((size.x - label_box.x) * 0.5, 32.0 * scale)
	bottom_direction_label.size = label_box
	bottom_direction_label.position = Vector2((size.x - label_box.x) * 0.5, size.y - 66.0 * scale)
	left_direction_label.size = label_box
	left_direction_label.position = Vector2(26.0 * scale, (size.y - label_box.y) * 0.5)
	right_direction_label.size = label_box
	right_direction_label.position = Vector2(size.x - 56.0 * scale, (size.y - label_box.y) * 0.5)
	countdown_label.size = Vector2(64.0, 58.0) * scale
	countdown_label.position = (size - countdown_label.size) * 0.5
	# The 2D fallback remains borderless and still. In a normal 3D match this
	# node is hidden by MainSceneV2 and the physical number lies directly on the
	# real centre object.
	wall_count_label.size = Vector2(122.0, 54.0) * scale
	wall_count_label.position = Vector2(
		(size.x - wall_count_label.size.x) * 0.5,
		(size.y - wall_count_label.size.y) * 0.5
	)
	wall_count_label.pivot_offset = wall_count_label.size * 0.5
	wall_count_label.rotation = 0.0


func _transparent_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	return style


func _configure_direction_copy() -> void:
	top_direction_label.text = DIRECTION_LABELS[0]
	right_direction_label.text = DIRECTION_LABELS[1]
	bottom_direction_label.text = DIRECTION_LABELS[2]
	left_direction_label.text = DIRECTION_LABELS[3]
	for label in [top_direction_label, bottom_direction_label, left_direction_label, right_direction_label]:
		label.visible = true
		label.add_theme_font_size_override("font_size", 24 if compact else 28)
		label.add_theme_color_override("font_outline_color", Color("071713"))
		label.add_theme_constant_override("outline_size", 4)
	countdown_label.visible = false


func _apply_direction_styles() -> void:
	if top_direction_label == null:
		return
	var labels := [top_direction_label, right_direction_label, bottom_direction_label, left_direction_label]
	var active_segment := -1
	if current_turn_seat >= 0:
		active_segment = int(SEGMENT_FOR_SEAT[current_turn_seat])
	for index in range(labels.size()):
		var label := labels[index] as Label
		label.add_theme_color_override(
			"font_color",
			Color("FFF4E0") if index == active_segment else Color.WHITE
		)
		label.add_theme_color_override("font_outline_color", Color("2A090B") if index == active_segment else Color("071713"))
