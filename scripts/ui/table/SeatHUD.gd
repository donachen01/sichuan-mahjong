class_name SeatHUD
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var inner_frame: Panel = %InnerFrame
@onready var name_label: Label = %NameLabel
@onready var score_label: Label = %ScoreLabel
@onready var ding_que_badge: Control = %DingQueBadge
@onready var dealer_badge: Label = %DealerBadge
@onready var won_badge: Label = %WonBadge

var seat := 0
var compact := false
var reduced_motion := false
var previous_active := false
var previous_won := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	for label in [name_label, score_label, dealer_badge, won_badge]:
		STYLE_CONFIG.apply_label(label, false, true)
	_apply_layout(false)


func configure_seat(seat_value: int) -> void:
	seat = clampi(seat_value, 0, 3)
	var viewport_size := get_viewport_rect().size if is_inside_tree() else METRICS.DESIGN_SIZE
	compact = seat in [1, 3] or METRICS.is_compact(viewport_size)
	_apply_layout(false)


func render(player: Dictionary, current_turn_seat: int, reveal_ding_que: bool) -> void:
	if name_label == null:
		return
	var viewport_size := get_viewport_rect().size if is_inside_tree() else METRICS.DESIGN_SIZE
	compact = seat in [1, 3] or METRICS.is_compact(viewport_size)
	var active := seat == current_turn_seat and not bool(player.get("has_won", false))
	var has_won := bool(player.get("has_won", false))
	_apply_layout(active)
	if craft_panel != null and craft_panel.has_method("set_active"):
		craft_panel.call("set_active", active)
	name_label.text = str(player.get("nickname", _seat_name(seat)))
	score_label.text = "%d分" % int(player.get("score", 0))
	var ding_que := str(player.get("ding_que", ""))
	ding_que_badge.configure(ding_que, compact)
	ding_que_badge.set_revealed(reveal_ding_que and not ding_que.is_empty())
	dealer_badge.visible = bool(player.get("_is_dealer", false))
	won_badge.visible = has_won
	modulate = Color(0.74, 0.78, 0.75, 0.96) if won_badge.visible else Color.WHITE
	_animate_state_change(active, has_won)
	previous_active = active
	previous_won = has_won


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


func is_reduced_motion() -> bool:
	return reduced_motion


func get_content_rect() -> Rect2:
	return get_global_rect()


func get_ding_que_badge() -> Control:
	return ding_que_badge


func get_visual_contract() -> Dictionary:
	return {
		"material_family": "ebony_lacquer_cut_corner_nameplate",
		"shape_motif": "shu_courtyard_cut_corner",
		"active_treatment": "copper_edge_light",
		"dealer_badge": "gold_corner_seal",
		"won_treatment": "desaturated_stamp",
	}


func _apply_layout(active: bool) -> void:
	if background_panel == null:
		return
	background_panel.add_theme_stylebox_override("panel", TABLE_THEME.make_panel_style(active))
	inner_frame.add_theme_stylebox_override("panel", _inner_frame_style(active))
	name_label.add_theme_font_size_override("font_size", TABLE_THEME.font_size("player_name", compact))
	score_label.add_theme_font_size_override("font_size", TABLE_THEME.font_size("score", compact))
	name_label.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
	score_label.add_theme_color_override("font_color", TABLE_THEME.TEXT_SECONDARY)
	for label in [name_label, score_label]:
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.05, 0.94))
		label.add_theme_constant_override("outline_size", 3)
	dealer_badge.add_theme_font_size_override("font_size", 30 if compact else 34)
	dealer_badge.add_theme_color_override("font_color", Color("F6D66B"))
	dealer_badge.add_theme_stylebox_override("normal", _corner_badge_style(Color("4A1B13"), Color("E5B843")))
	won_badge.add_theme_font_size_override("font_size", 24 if compact else 28)
	won_badge.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
	won_badge.add_theme_stylebox_override("normal", _corner_badge_style(Color("9A2D28"), Color("F1C15D")))
	var dealer_size := Vector2(48.0, 48.0)
	dealer_badge.size = dealer_size
	dealer_badge.position = Vector2(maxf(6.0, size.x - dealer_size.x - 6.0), 6.0)
	var won_size := Vector2(64.0, 40.0)
	won_badge.size = won_size
	won_badge.position = Vector2(6.0, 6.0)


func _inner_frame_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(TABLE_THEME.BRASS, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(7)
	return style


func _corner_badge_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _animate_state_change(active: bool, has_won: bool) -> void:
	if reduced_motion:
		background_panel.modulate = Color.WHITE
		won_badge.modulate = Color.WHITE
		return
	if active and not previous_active:
		background_panel.modulate = Color(1.0, 0.91, 0.66, 0.82)
		var active_tween := background_panel.create_tween()
		active_tween.tween_property(background_panel, "modulate", Color.WHITE, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if has_won and not previous_won:
		won_badge.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var won_tween := won_badge.create_tween()
		won_tween.tween_property(won_badge, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _seat_name(seat_value: int) -> String:
	return ["本家", "上家", "对家", "下家"][clampi(seat_value, 0, 3)]
