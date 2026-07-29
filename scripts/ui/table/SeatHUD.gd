class_name SeatHUD
extends Control

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const NAMEPLATE_STYLE_NAMES := ["深翡翠玉印", "鎏金铜脊", "青黛绶带", "琥珀云窗", "夜玉切角"]
const SEAT_AVATAR_GLYPHS := ["旭", "燕", "东", "玲"]

@export_enum("深翡翠玉印", "鎏金铜脊", "青黛绶带", "琥珀云窗", "夜玉切角")
var nameplate_style_variant := 0

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var material_shell: TextureRect = %MaterialShell
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
@onready var score_delta_label: Label = %ScoreDeltaLabel

var seat := 0
var compact := false
var reduced_motion := false
var previous_active := false
var previous_won := false
var previous_score := 0
var has_rendered_score := false
var active_transition_started_msec := -1
var score_delta_tween: Tween
var score_total_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	# The avatar is the only decorative display glyph in the seat card. Player
	# identity, score and state copy use the embedded body face for fast reading.
	STYLE_CONFIG.apply_label(avatar_glyph, false, true)
	for label in [name_label, score_label, dealer_badge, won_badge, turn_badge]:
		STYLE_CONFIG.apply_label(label, false, false)
	avatar_glyph.text = SEAT_AVATAR_GLYPHS[seat]
	if avatar_medallion != null and avatar_medallion.has_method("configure"):
		avatar_medallion.call("configure", seat, false, false)
	# Static lacquer/copper depth is baked by Blender; dynamic state, text and
	# hit-independent highlights stay in Godot. Do not paint a second opaque
	# procedural panel over the orthographic nine-patch shell.
	craft_panel.visible = false
	# The old shell texture contained two hard horizontal bars. The new plate is
	# a single layered Control style so the silhouette stays clean at every
	# resolution and can be switched among the five theme variants below.
	material_shell.visible = false
	_apply_layout(false)
	set_process(true)


func _process(_delta: float) -> void:
	if inner_frame == null:
		return
	if not previous_active or reduced_motion:
		inner_frame.modulate = Color.WHITE
		return
	var elapsed := maxi(0, Time.get_ticks_msec() - active_transition_started_msec)
	if elapsed < 180:
		var t := float(elapsed) / 180.0
		inner_frame.modulate = Color(1.18, 1.10, 0.88, lerpf(0.82, 1.0, t))
		return
	# A restrained edge-only breath follows the 180 ms arrival. The panel never
	# moves or scales, so hand/river geometry remains immutable.
	var pulse := 0.78 + sin(float(elapsed - 180) / 1000.0 * TAU / 1.2) * 0.22
	inner_frame.modulate = Color(1.26, 1.08, 0.78, pulse)


func configure_seat(seat_value: int) -> void:
	seat = clampi(seat_value, 0, 3)
	var viewport_size := get_viewport_rect().size if is_inside_tree() else METRICS.DESIGN_SIZE
	compact = METRICS.is_compact(viewport_size)
	if avatar_glyph != null:
		avatar_glyph.text = SEAT_AVATAR_GLYPHS[seat]
	if avatar_medallion != null and avatar_medallion.has_method("configure"):
		avatar_medallion.call("configure", seat, false, false)
	if background_panel != null:
		_apply_layout(false)


func set_nameplate_style_variant(value: int) -> void:
	nameplate_style_variant = clampi(value, 0, NAMEPLATE_STYLE_NAMES.size() - 1)
	if background_panel != null:
		_apply_layout(previous_active)


func render(player: Dictionary, current_turn_seat: int, reveal_ding_que: bool) -> void:
	if name_label == null:
		return
	var viewport_size := get_viewport_rect().size if is_inside_tree() else METRICS.DESIGN_SIZE
	compact = METRICS.is_compact(viewport_size)
	var active := seat == current_turn_seat and not bool(player.get("has_won", false))
	var has_won := bool(player.get("has_won", false))
	dealer_badge.visible = bool(player.get("_is_dealer", false))
	won_badge.visible = has_won
	# Turn ownership is communicated by the continuously breathing nameplate ring,
	# never by a "出牌" word sitting on top of the player's name.
	turn_badge.visible = false
	_apply_layout(active)
	if craft_panel != null and craft_panel.has_method("set_active"):
		craft_panel.call("set_active", active)
	name_label.text = str(player.get("nickname", _seat_name(seat)))
	var next_score := int(player.get("score", 0))
	score_label.text = "%d分" % next_score
	if has_rendered_score and next_score != previous_score:
		_animate_score_change(next_score - previous_score)
	previous_score = next_score
	has_rendered_score = true
	turn_badge.text = str(player.get("_interaction_label", "出牌"))
	if avatar_medallion != null and avatar_medallion.has_method("configure"):
		avatar_medallion.call("configure", seat, active, has_won)
	var ding_que := str(player.get("ding_que", ""))
	ding_que_badge.configure(ding_que, compact)
	ding_que_badge.set_revealed(reveal_ding_que and not ding_que.is_empty())
	# Desaturate only the material/portrait layer after winning. Live name and
	# score text stay full-contrast so the seat remains a usable orientation
	# anchor while the explicit 已胡 seal carries the semantic state.
	material_shell.modulate = Color(0.72, 0.75, 0.72, 0.88) if has_won else Color.WHITE
	avatar_medallion.modulate = Color(0.74, 0.76, 0.74, 0.90) if has_won else Color.WHITE
	modulate = Color.WHITE
	_animate_state_change(active, has_won)
	previous_active = active
	previous_won = has_won


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_stop_score_tweens()
	if score_delta_label != null:
		score_delta_label.visible = false
		score_delta_label.modulate = Color.WHITE
	if score_label != null:
		score_label.modulate = Color.WHITE


func is_reduced_motion() -> bool:
	return reduced_motion


func get_content_rect() -> Rect2:
	return get_global_rect()


func get_ding_que_badge() -> Control:
	return ding_que_badge


func get_visual_contract() -> Dictionary:
	return {
		"material_family": "five_variant_emerald_nameplate",
		"identity_surface": "original_jade_seal_medallion",
		"identity_encoding": ["seat_glyph", "material_palette", "shape_motif"],
		"seat_avatar_glyphs": SEAT_AVATAR_GLYPHS,
		"shape_motif": "shu_courtyard_cut_corner",
		"nameplate_variants": NAMEPLATE_STYLE_NAMES,
		"selected_nameplate_variant": nameplate_style_variant,
		"removed_elements": ["upper_lower_horizontal_bars", "出牌_text_badge"],
		"active_treatment": "pulsing_emerald_copper_nameplate_ring",
		"dealer_badge": "gold_corner_seal",
		"won_treatment": "identity_preserved_with_cinnabar_stamp",
		"active_text_badge": "none",
		"active_arrival_seconds": 0.18,
		"active_followup": "continuous_edge_blink_without_move_or_scale",
		"score_feedback": "signed_delta_near_panel_then_total_score_highlight",
		"score_float_seconds": 0.42,
		"reduced_motion_active": "stable_edge_highlight",
		"reduced_motion_score": "numeric_update_without_path_or_color_pulse",
	}


func get_layout_contract() -> Dictionary:
	return {
		"seat": seat,
		"compact": compact,
		"hud_size": METRICS.seat_hud_size(compact),
		"name_safe_inset": 40.0,
		"badges_inside_bounds": true,
	}


func get_motion_state_contract() -> Dictionary:
	var tween_count := 0
	for tween in [score_delta_tween, score_total_tween]:
		if tween != null and tween.is_valid():
			tween_count += 1
	return {
		"score_tween_count": tween_count,
		"score_delta_visible": score_delta_label != null and score_delta_label.visible,
		"score_label_modulate": score_label.modulate if score_label != null else Color.WHITE,
		"reduced_motion": reduced_motion,
	}


func _apply_layout(active: bool) -> void:
	if background_panel == null:
		return
	background_panel.add_theme_stylebox_override("panel", _nameplate_shell_style())
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
	turn_badge.visible = false
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
	score_delta_label.size = Vector2(76.0, 36.0)
	match seat:
		0:
			score_delta_label.position = Vector2(size.x - 82.0, -38.0)
		1:
			score_delta_label.position = Vector2(size.x + 6.0, (size.y - 36.0) * 0.5)
		2:
			score_delta_label.position = Vector2(8.0, size.y + 2.0)
		_:
			score_delta_label.position = Vector2(-82.0, (size.y - 36.0) * 0.5)
	score_delta_label.add_theme_font_size_override("font_size", 26 if compact else 30)
	score_delta_label.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.03, 0.96))
	score_delta_label.add_theme_constant_override("outline_size", 3)
	score_delta_label.add_theme_stylebox_override("normal", _score_delta_style())


func _inner_frame_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.96 if active else 0.22)
	style.set_border_width_all(3 if active else 1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.52 if active else 0.0)
	style.shadow_size = 8 if active else 0
	style.shadow_offset = Vector2.ZERO
	return style


func _nameplate_shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var variant := clampi(int(nameplate_style_variant), 0, NAMEPLATE_STYLE_NAMES.size() - 1)
	match variant:
		0:
			style.bg_color = Color("0B332B")
			style.border_color = Color("5BB58D")
			style.set_border_width_all(2)
			style.set_corner_radius_all(16)
		1:
			style.bg_color = Color("102D2B")
			style.border_color = Color("C59A58")
			style.set_border_width_all(3)
			style.set_corner_radius_all(10)
		2:
			style.bg_color = Color("162D3B")
			style.border_color = Color("6BA9A6")
			style.set_border_width_all(2)
			style.corner_radius_top_left = 20
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 20
		3:
			style.bg_color = Color("3A2B22")
			style.border_color = Color("D7B56D")
			style.set_border_width_all(2)
			style.set_corner_radius_all(18)
		_:
			style.bg_color = Color("111C29")
			style.border_color = Color("8FB9A4")
			style.set_border_width_all(2)
			style.corner_radius_top_left = 8
			style.corner_radius_top_right = 18
			style.corner_radius_bottom_left = 18
			style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.02, 0.01, 0.48)
	style.shadow_size = 9
	style.shadow_offset = Vector2(3, 5)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _transparent_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.shadow_size = 0
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


func _score_delta_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(TABLE_THEME.TABLE_EDGE, 0.94)
	style.border_color = Color(TABLE_THEME.AGED_COPPER, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.shadow_color = Color(0.0, 0.02, 0.01, 0.32)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2.0, 3.0)
	return style


func _animate_state_change(active: bool, has_won: bool) -> void:
	if reduced_motion:
		background_panel.modulate = Color.WHITE
		inner_frame.modulate = Color.WHITE
		won_badge.modulate = Color.WHITE
		return
	if active and not previous_active:
		active_transition_started_msec = Time.get_ticks_msec()
	if has_won and not previous_won:
		won_badge.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var won_tween := won_badge.create_tween()
		won_tween.tween_property(won_badge, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_score_change(delta: int) -> void:
	if score_delta_label == null or delta == 0:
		return
	score_delta_label.text = "%+d" % delta
	score_delta_label.add_theme_color_override(
		"font_color",
		TABLE_THEME.POSITIVE_SCORE if delta > 0 else TABLE_THEME.NEGATIVE_SCORE
	)
	score_delta_label.visible = true
	score_delta_label.modulate = Color.WHITE if reduced_motion else Color(1.0, 1.0, 1.0, 0.0)
	score_label.modulate = Color.WHITE
	_stop_score_tweens()
	score_delta_label.visible = true
	if reduced_motion:
		# Numeric feedback is allowed in reduced motion, but no path, scale, loop or
		# colour pulse remains. The signed value is held statically for 420 ms.
		score_delta_tween = score_delta_label.create_tween()
		score_delta_tween.tween_interval(0.42)
		score_delta_tween.tween_callback(func() -> void: score_delta_label.visible = false)
		return
	score_delta_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	score_delta_tween = score_delta_label.create_tween()
	score_delta_tween.tween_property(score_delta_label, "modulate:a", 1.0, 0.10)
	score_delta_tween.tween_interval(0.20)
	score_delta_tween.tween_property(score_delta_label, "modulate:a", 0.0, 0.12)
	score_delta_tween.tween_callback(func() -> void: score_delta_label.visible = false)
	score_total_tween = score_label.create_tween()
	score_total_tween.tween_interval(0.20)
	score_total_tween.tween_property(score_label, "modulate", Color(1.16, 1.10, 0.74, 1.0), 0.10)
	score_total_tween.tween_property(score_label, "modulate", Color.WHITE, 0.12)


func _stop_score_tweens() -> void:
	for tween in [score_delta_tween, score_total_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	score_delta_tween = null
	score_total_tween = null


func _seat_name(seat_value: int) -> String:
	return ["本家", "上家", "对家", "下家"][clampi(seat_value, 0, 3)]
