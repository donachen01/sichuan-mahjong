class_name SeatHUD
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var inner_frame: Panel = %InnerFrame
@onready var avatar_medallion: Control = %AvatarMedallion
@onready var avatar_glyph: Label = %AvatarGlyph
@onready var content_margin: MarginContainer = $ContentMargin
@onready var name_safe_margin: MarginContainer = %NameSafeMargin
@onready var name_label: Label = %NameLabel
@onready var score_label: Label = %ScoreLabel
@onready var ding_que_badge: Control = %DingQueBadge
@onready var dealer_badge: Label = %DealerBadge
@onready var won_badge: Label = %WonBadge
@onready var turn_badge: Label = %TurnBadge

var seat := 0
var compact := false
var reduced_motion := false
var previous_active := false
var previous_won := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	for label in [avatar_glyph, name_label, score_label, dealer_badge, won_badge, turn_badge]:
		STYLE_CONFIG.apply_label(label, false, true)
	avatar_glyph.text = ["川", "锦", "玉", "蜀"][seat]
	if avatar_medallion != null and avatar_medallion.has_method("configure"):
		avatar_medallion.call("configure", seat, false, false)
	_apply_layout(false)


func configure_seat(seat_value: int) -> void:
	seat = clampi(seat_value, 0, 3)
	var viewport_size := get_viewport_rect().size if is_inside_tree() else METRICS.DESIGN_SIZE
	compact = METRICS.is_compact(viewport_size)
	if avatar_glyph != null:
		avatar_glyph.text = ["川", "锦", "玉", "蜀"][seat]
	if avatar_medallion != null and avatar_medallion.has_method("configure"):
		avatar_medallion.call("configure", seat, false, false)
	if background_panel != null:
		_apply_layout(false)


func render(player: Dictionary, current_turn_seat: int, reveal_ding_que: bool) -> void:
	if name_label == null:
		return
	var viewport_size := get_viewport_rect().size if is_inside_tree() else METRICS.DESIGN_SIZE
	compact = METRICS.is_compact(viewport_size)
	var active := seat == current_turn_seat and not bool(player.get("has_won", false))
	var has_won := bool(player.get("has_won", false))
	dealer_badge.visible = bool(player.get("_is_dealer", false))
	won_badge.visible = has_won
	turn_badge.visible = active
	_apply_layout(active)
	if craft_panel != null and craft_panel.has_method("set_active"):
		craft_panel.call("set_active", active)
	name_label.text = str(player.get("nickname", _seat_name(seat)))
	score_label.text = "%d分" % int(player.get("score", 0))
	turn_badge.text = str(player.get("_interaction_label", "出牌"))
	if avatar_medallion != null and avatar_medallion.has_method("configure"):
		avatar_medallion.call("configure", seat, active, has_won)
	var ding_que := str(player.get("ding_que", ""))
	ding_que_badge.configure(ding_que, compact)
	ding_que_badge.set_revealed(reveal_ding_que and not ding_que.is_empty())
	# Preserve the player's name, score and seat identity after winning.  A full
	# HUD desaturation made completed players look disabled and removed the
	# strongest orientation anchor; the explicit 已胡 seal is sufficient state.
	modulate = Color.WHITE
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
		"identity_surface": "original_jade_seal_medallion",
		"identity_encoding": ["seat_glyph", "material_palette", "shape_motif"],
		"shape_motif": "shu_courtyard_cut_corner",
		"active_treatment": "copper_edge_light",
		"dealer_badge": "gold_corner_seal",
		"won_treatment": "identity_preserved_with_cinnabar_stamp",
		"active_text_badge": "出牌",
	}


func get_layout_contract() -> Dictionary:
	return {
		"seat": seat,
		"compact": compact,
		"hud_size": METRICS.seat_hud_size(compact),
		"name_safe_inset": 40.0,
		"badges_inside_bounds": true,
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
	var avatar_size := Vector2(64.0, 64.0) if compact else Vector2(72.0, 72.0)
	avatar_medallion.size = avatar_size
	avatar_medallion.position = Vector2(10.0, maxf(8.0, (size.y - avatar_size.y) * 0.5))
	avatar_glyph.size = avatar_size
	avatar_glyph.position = avatar_medallion.position
	avatar_glyph.add_theme_font_size_override("font_size", 30 if compact else 34)
	avatar_glyph.add_theme_color_override("font_color", Color("FFF1C4"))
	avatar_glyph.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.96))
	avatar_glyph.add_theme_constant_override("outline_size", 3)
	content_margin.add_theme_constant_override("margin_left", int(avatar_size.x + 24.0))
	content_margin.add_theme_constant_override("margin_right", 10)
	name_safe_margin.add_theme_constant_override("margin_left", 6)
	name_safe_margin.add_theme_constant_override("margin_right", 48 if dealer_badge.visible else 40)
	for label in [name_label, score_label]:
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.05, 0.94))
		label.add_theme_constant_override("outline_size", 3)
	dealer_badge.add_theme_font_size_override("font_size", 30 if compact else 34)
	dealer_badge.add_theme_color_override("font_color", Color("F6D66B"))
	dealer_badge.add_theme_stylebox_override("normal", _corner_badge_style(Color("4A1B13"), Color("E5B843")))
	won_badge.add_theme_font_size_override("font_size", 24 if compact else 28)
	won_badge.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
	won_badge.add_theme_stylebox_override("normal", _corner_badge_style(Color("9A2D28"), Color("F1C15D")))
	turn_badge.add_theme_font_size_override("font_size", 19 if compact else 21)
	turn_badge.add_theme_color_override("font_color", Color("FFF1C4"))
	turn_badge.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.96))
	turn_badge.add_theme_constant_override("outline_size", 2)
	turn_badge.add_theme_stylebox_override("normal", _corner_badge_style(Color("123F35"), Color("C59A58")))
	var dealer_size := Vector2(40.0, 40.0) if compact else Vector2(44.0, 44.0)
	dealer_badge.size = dealer_size
	dealer_badge.position = Vector2(maxf(6.0, size.x - dealer_size.x - 6.0), 6.0)
	var won_size := Vector2(62.0, 38.0) if compact else Vector2(68.0, 42.0)
	won_badge.size = won_size
	# Won and active-turn are mutually exclusive.  They share one fixed status
	# slot instead of piling over the avatar and ding-que badge.
	won_badge.position = Vector2(5.0, 4.0)
	var turn_size := Vector2(58.0, 34.0) if compact else Vector2(64.0, 36.0)
	turn_badge.size = turn_size
	# Keep the explicit turn text clear of the centered player name. The earlier
	# offset crossed into the name safe area and visually merged into strings
	# such as "响应本家" on compact phones.
	turn_badge.position = Vector2(5.0, 4.0)


func _inner_frame_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.42 if active else 0.0)
	style.set_border_width_all(1 if active else 0)
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
		active_tween.tween_property(background_panel, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_won and not previous_won:
		won_badge.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var won_tween := won_badge.create_tween()
		won_tween.tween_property(won_badge, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _seat_name(seat_value: int) -> String:
	return ["本家", "上家", "对家", "下家"][clampi(seat_value, 0, 3)]
