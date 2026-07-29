class_name CenterTurnIndicator
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

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
	# The center surface is now a quiet compass plus a diegetic wall tile. The
	# old four direction words and per-turn countdown competed with the table
	# action; keep the nodes for scene/diagnostic compatibility but never show
	# them in the release surface.
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	_hide_legacy_center_copy()
	_apply_layout()
	# 3D 对局使用 SichuanTableStage3D 里的立体余牌字模；这里仅保留
	# 非 3D 降级路径的静态文本，不能再出现绕中心环行的旧动效。
	set_process(false)


func render(next_wall_count: int, turn_seat: int, _status_text: String = "") -> void:
	var next_seat := clampi(turn_seat, 0, 3)
	if next_seat != current_turn_seat:
		current_turn_seat = next_seat
	wall_count = maxi(0, next_wall_count)
	wall_count_label.text = "余%d" % wall_count


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
		"concept": "floating_wall_count_above_physical_center",
		"physical_asset": "res://res/art/3d/sichuan_center_compass_v2.glb",
		"primary_information": "floating_wall_count",
		"wall_count_surface": "static_2d_fallback_text_above_center_graphic",
		"wall_count_format": "余%d",
		"wall_count_motion": "3d_stage_primary_self_rotation",
		"direction_labels": [],
		"active_encoding": [],
		"overlay_frames": "removed",
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
	compass_visual.visible = false
	background_panel.add_theme_stylebox_override("panel", _transparent_style())
	wall_count_label.visible = true
	wall_count_label.add_theme_font_size_override("font_size", 30 if compact else 36)
	wall_count_label.add_theme_color_override("font_color", Color("FFF0B8"))
	wall_count_label.add_theme_color_override("font_outline_color", Color(0.01, 0.055, 0.042, 0.98))
	wall_count_label.add_theme_constant_override("outline_size", 5)
	wall_count_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.01, 0.62))
	wall_count_label.add_theme_constant_override("shadow_offset_x", 2)
	wall_count_label.add_theme_constant_override("shadow_offset_y", 4)
	wall_count_label.add_theme_stylebox_override("normal", _transparent_style())
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
	# The 2D fallback remains borderless and still.  In a normal 3D match this
	# node is hidden by MainSceneV2 and the physical rotating text lives in the
	# stage directly above the real centre object.
	wall_count_label.size = Vector2(122.0, 54.0) * scale
	wall_count_label.position = Vector2(
		(size.x - wall_count_label.size.x) * 0.5,
		12.0 * scale
	)
	wall_count_label.pivot_offset = wall_count_label.size * 0.5
	wall_count_label.rotation = 0.0


func _transparent_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	return style


func _hide_legacy_center_copy() -> void:
	for label in [top_direction_label, countdown_label, bottom_direction_label, left_direction_label, right_direction_label]:
		if label != null:
			label.visible = false
