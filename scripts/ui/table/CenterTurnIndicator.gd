class_name CenterTurnIndicator
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var caption_label: Label = %CaptionLabel
@onready var count_label: Label = %CountLabel
@onready var status_label: Label = %StatusLabel
@onready var north_label: Label = %NorthLabel
@onready var east_label: Label = %EastLabel
@onready var south_label: Label = %SouthLabel
@onready var west_label: Label = %WestLabel

var compact := false
var current_turn_seat := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [caption_label, count_label, status_label, north_label, east_label, south_label, west_label]:
		STYLE_CONFIG.apply_label(label, false, true)
	for direction_label in [north_label, east_label, south_label, west_label]:
		direction_label.visible = false
	_apply_layout()


func render(wall_count: int, turn_seat: int, status_text: String = "") -> void:
	current_turn_seat = clampi(turn_seat, 0, 3)
	count_label.text = str(maxi(0, wall_count))
	status_label.text = status_text if not status_text.is_empty() else "当前：%s" % _seat_name(current_turn_seat)
	_apply_direction_state()


func set_compact(compact_value: bool) -> void:
	compact = compact_value
	custom_minimum_size = METRICS.center_indicator_size(compact)
	size = custom_minimum_size
	_apply_layout()


func get_reserved_rect() -> Rect2:
	return get_global_rect()


func get_active_direction_text() -> String:
	return ""


func get_visual_contract() -> Dictionary:
	return {
		"concept": "four_waters_courtyard_compass",
		"shape_motif": "shu_courtyard_cut_corner",
		"material_family": "ink_jade_and_aged_copper",
		"primary_information": "wall_count",
		"direction_labels": "hidden",
	}


func _apply_layout() -> void:
	if background_panel == null:
		return
	background_panel.add_theme_stylebox_override("panel", _make_center_style())
	caption_label.add_theme_font_size_override("font_size", TABLE_THEME.font_size("center_caption", compact))
	count_label.add_theme_font_size_override("font_size", TABLE_THEME.font_size("center_count", compact))
	status_label.add_theme_font_size_override("font_size", 20 if compact else 23)
	for label in [caption_label, count_label, status_label]:
		label.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.96))
		label.add_theme_constant_override("outline_size", 3)
	count_label.add_theme_color_override("font_color", Color("FFF1C4"))
	caption_label.add_theme_color_override("font_color", Color(TABLE_THEME.TEXT_SECONDARY, 0.90))
	_apply_direction_state()


func _apply_direction_state() -> void:
	if north_label == null:
		return
	for direction_label in [north_label, east_label, south_label, west_label]:
		direction_label.visible = false


func _direction_label_for_seat(seat: int) -> Label:
	match seat:
		0:
			return south_label
		1:
			return west_label
		2:
			return north_label
		3:
			return east_label
		_:
			return south_label


func _seat_name(seat: int) -> String:
	return ["本家", "上家", "对家", "下家"][clampi(seat, 0, 3)]


func _make_center_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.16, 0.12, 0.0)
	style.border_color = Color(TABLE_THEME.BRASS.lightened(0.10), 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


func _make_direction_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(TABLE_THEME.LACQUER_BROWN, 0.88) if active else Color(TABLE_THEME.INK_JADE_DEEP, 0.78)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.88 if active else 0.24)
	style.set_border_width_all(2 if active else 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 8
	return style
