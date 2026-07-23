class_name CenterTurnIndicator
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var compass_visual: Control = %CompassVisual
@onready var caption_label: Label = %CaptionLabel
@onready var count_label: Label = %CountLabel
@onready var status_label: Label = %StatusLabel
@onready var turn_chip_label: Label = %TurnChipLabel

var compact := false
var current_turn_seat := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [caption_label, count_label, status_label, turn_chip_label]:
		STYLE_CONFIG.apply_label(label, false, true)
	_apply_layout()


func render(wall_count: int, turn_seat: int, status_text: String = "") -> void:
	current_turn_seat = clampi(turn_seat, 0, 3)
	count_label.text = str(maxi(0, wall_count))
	turn_chip_label.text = ""
	status_label.text = status_text if not status_text.is_empty() else "%s出牌中" % _seat_name(current_turn_seat)
	if compass_visual != null and compass_visual.has_method("configure"):
		compass_visual.call("configure", current_turn_seat, bool(ProjectSettings.get_setting("accessibility/reduced_motion", false)))
	_apply_turn_chip_style()


func set_compact(compact_value: bool) -> void:
	compact = compact_value
	custom_minimum_size = METRICS.center_indicator_size(compact)
	size = custom_minimum_size
	_apply_layout()


func get_reserved_rect() -> Rect2:
	return get_global_rect()


func get_active_direction_text() -> String:
	return ["本", "上", "对", "下"][clampi(current_turn_seat, 0, 3)]


func get_visual_contract() -> Dictionary:
	return {
		"concept": "restored_remaining_tile_plaque",
		"shape_motif": "dark_cut_corner_double_line_plaque",
		"material_family": "ink_jade_and_aged_copper",
		"primary_information": "wall_count",
		"direction_labels": "none",
		"active_encoding": ["status_text"],
		"visual_density": "low",
		"decorative_divisions": 0,
		"border_lines": 2,
	}


func _apply_layout() -> void:
	if background_panel == null:
		return
	# The bespoke visual owns the plaque. Keep the generic craft frame disabled so
	# the center does not get a double border or extra corner ornaments.
	craft_panel.visible = false
	background_panel.add_theme_stylebox_override("panel", _make_center_style())
	caption_label.add_theme_font_size_override("font_size", 25 if compact else 30)
	count_label.add_theme_font_size_override("font_size", 68 if compact else 80)
	status_label.add_theme_font_size_override("font_size", 23 if compact else 27)
	turn_chip_label.add_theme_font_size_override("font_size", 15 if compact else 17)
	# 旧版深青黑牌匾使用暖象牙字和克制暗金标题，不再显示蓝色数码或方位字。
	for label in [caption_label, count_label, status_label, turn_chip_label]:
		label.add_theme_color_override("font_color", Color("F7E8BF"))
		label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.025, 0.96))
		label.add_theme_constant_override("outline_size", 4)
	count_label.add_theme_color_override("font_color", Color("FFF1CD"))
	caption_label.add_theme_color_override("font_color", Color("D1B378"))
	status_label.add_theme_color_override("font_color", Color("E7CE96"))
	_layout_labels()
	_apply_turn_chip_style()


func _apply_turn_chip_style() -> void:
	if turn_chip_label == null:
		return
	turn_chip_label.visible = false


func _layout_labels() -> void:
	turn_chip_label.size = Vector2.ZERO
	turn_chip_label.position = Vector2.ZERO
	caption_label.size = Vector2(size.x * 0.78, 34.0)
	caption_label.position = Vector2(size.x * 0.11, size.y * 0.105)
	count_label.size = Vector2(size.x * 0.76, size.y * 0.37)
	count_label.position = Vector2(size.x * 0.12, size.y * 0.275)
	status_label.size = Vector2(size.x * 0.86, 34.0 if compact else 38.0)
	status_label.position = Vector2(size.x * 0.07, size.y * 0.720)


func _seat_name(seat: int) -> String:
	return ["本家", "上家", "对家", "下家"][clampi(seat, 0, 3)]


func _make_center_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.16, 0.12, 0.0)
	style.border_color = Color(TABLE_THEME.BRASS.lightened(0.10), 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(18)
	return style


func _make_turn_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(TABLE_THEME.INK_JADE_DEEP, 0.94)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.58)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 7
	return style
