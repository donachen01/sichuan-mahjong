class_name TableActionBar
extends Control

signal action_selected(action: String)

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const ENTRANCE_DURATION := 0.16
const ENTRANCE_STAGGER := 0.025
const HOVER_DURATION := 0.10
const PRESS_DURATION := 0.12
const ENTRANCE_SCALE := 0.94
const HOVER_SCALE := 1.035
const PRESS_SCALE := 0.94
const PRIMARY_COMPACT_SIZE := Vector2(132.0, 132.0)
const SECONDARY_COMPACT_SIZE := Vector2(108.0, 108.0)
const PRIMARY_FOCUSED_SIZE := Vector2(184.0, 184.0)
const SECONDARY_FOCUSED_SIZE := Vector2(156.0, 156.0)

@onready var background_panel: Panel = %BackgroundPanel
@onready var craft_panel: Control = %CraftPanel
@onready var status_label: Label = %StatusLabel
@onready var context_mark: Label = %ContextMark
@onready var button_row: HBoxContainer = %ButtonRow
@onready var hu_button: Button = %HuButton
@onready var gang_button: Button = %GangButton
@onready var peng_button: Button = %PengButton
@onready var pass_button: Button = %PassButton

var action_buttons: Dictionary = {}
var reduced_motion := false
var button_tweens: Dictionary = {}
var button_overlays: Dictionary = {}


func _ready() -> void:
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	action_buttons = {
		"hu": hu_button,
		"gang": gang_button,
		"peng": peng_button,
		"pass": pass_button,
	}
	mouse_filter = Control.MOUSE_FILTER_PASS
	STYLE_CONFIG.apply_label(status_label, false, true)
	STYLE_CONFIG.apply_label(context_mark, false, true)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("F4E2AF"))
	status_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.96))
	status_label.add_theme_constant_override("outline_size", 2)
	context_mark.add_theme_font_size_override("font_size", 20)
	context_mark.add_theme_color_override("font_color", Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.92))
	context_mark.add_theme_stylebox_override("normal", TABLE_THEME.make_badge_style(""))
	status_label.visible = false
	context_mark.visible = false
	var context_row := context_mark.get_parent() as Control
	if context_row != null:
		context_row.visible = false
	# The action choices float above the table like individual jade seals. The
	# previous shared cut-corner frame made the group feel like a desktop tool
	# panel and reduced the clarity of each decision on a phone.
	craft_panel.visible = false
	background_panel.add_theme_stylebox_override("panel", _make_background_style())
	for action in action_buttons:
		var button: Button = action_buttons[action]
		STYLE_CONFIG.apply_button(button, true)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", TABLE_THEME.font_size("action_primary" if action == "hu" else "action_secondary"))
		button.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		button.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.92))
		button.add_theme_constant_override("outline_size", 3)
		button.add_theme_stylebox_override("normal", _make_action_seal_style(action, false))
		button.add_theme_stylebox_override("hover", _make_hover_style(action))
		button.add_theme_stylebox_override("focus", _make_focus_style(action))
		button.add_theme_stylebox_override("pressed", _make_action_seal_style(action, true))
		button_overlays[button] = _create_motion_overlay(button)
		button.pressed.connect(_on_button_pressed.bind(str(action)))
		button.mouse_entered.connect(_on_button_attention_entered.bind(button))
		button.mouse_exited.connect(_on_button_attention_exited.bind(button))
		button.focus_entered.connect(_on_button_attention_entered.bind(button))
		button.focus_exited.connect(_on_button_attention_exited.bind(button))
	_apply_focus_navigation()
	hide_actions()


func render(actions: Array[String], _status_text: String) -> void:
	var accepted: Array[String] = []
	for action in actions:
		if action_buttons.has(action) and not accepted.has(action):
			accepted.append(action)
	_apply_action_size_profile(accepted.size())
	var bar_was_visible := visible
	var appearing_actions: Array[String] = []
	for action in action_buttons:
		var button: Button = action_buttons[action]
		var should_be_visible := accepted.has(str(action))
		if should_be_visible and (not bar_was_visible or not button.visible):
			appearing_actions.append(str(action))
		button.visible = should_be_visible
	status_label.text = ""
	status_label.visible = false
	context_mark.visible = false
	visible = not accepted.is_empty()
	if visible:
		_update_size()
		if not appearing_actions.is_empty():
			call_deferred("_animate_action_entrance", appearing_actions)


func hide_actions() -> void:
	visible = false
	for button in action_buttons.values():
		var action_button := button as Button
		_kill_button_tween(action_button)
		action_button.scale = Vector2.ONE
		action_button.modulate = Color.WHITE
		_reset_motion_overlay(action_button)
		action_button.visible = false


func set_action_label(action: String, label_text: String) -> void:
	var button: Button = action_buttons.get(action)
	if button != null:
		button.text = label_text


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if reduced_motion:
		for button in action_buttons.values():
			var action_button := button as Button
			_kill_button_tween(action_button)
			action_button.scale = Vector2.ONE
			action_button.modulate = Color.WHITE
			_reset_motion_overlay(action_button)


func get_touch_rect(action: String) -> Rect2:
	var button: Button = action_buttons.get(action)
	return button.get_global_rect() if button != null and button.visible else Rect2()


func get_button(action: String) -> Button:
	return action_buttons.get(action)


func get_visible_actions() -> Array[String]:
	var actions: Array[String] = []
	for action in ["hu", "gang", "peng", "pass"]:
		var button: Button = action_buttons.get(action)
		if button != null and button.visible:
			actions.append(action)
	return actions


func get_visual_contract() -> Dictionary:
	return {
		"material_family": "jade_cinnabar_decision_seals",
		"primary_shape": "round_jade_seal",
		"shape_motif": "circular_chinese_seal",
		"pass_hierarchy": "secondary",
		"context_surface": "floating_decision_seals",
		"auxiliary_text": "hidden",
		"pressed_feedback": "depth_compression",
		"motion_language": "short_scale_and_light_response",
	}


func get_motion_contract() -> Dictionary:
	return {
		"entrance_duration": ENTRANCE_DURATION,
		"entrance_stagger": ENTRANCE_STAGGER,
		"hover_duration": HOVER_DURATION,
		"press_duration": PRESS_DURATION,
		"hover_scale": HOVER_SCALE,
		"press_scale": PRESS_SCALE,
		"reduced_motion": reduced_motion,
		"layout_stable": true,
		"touch_target_transform": "stable_parent_with_visual_overlay",
	}


func _on_button_pressed(action: String) -> void:
	if not reduced_motion:
		var button: Button = action_buttons.get(action)
		if button != null:
			_kill_button_tween(button)
			var overlay: Panel = button_overlays.get(button)
			_prepare_overlay_pivot(overlay)
			if overlay != null:
				overlay.scale = Vector2.ONE * PRESS_SCALE
				overlay.modulate = Color(1.0, 0.78, 0.32, 0.94)
			button.modulate = Color(1.0, 0.88, 0.62, 1.0)
			var tween := button.create_tween()
			button_tweens[button] = tween
			tween.set_parallel(true)
			if overlay != null:
				tween.tween_property(overlay, "scale", Vector2.ONE * 1.04, PRESS_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(overlay, "modulate", Color(1.0, 0.78, 0.32, 0.0), PRESS_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(button, "modulate", Color.WHITE, PRESS_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	action_selected.emit(action)


func _animate_action_entrance(actions: Array[String]) -> void:
	if reduced_motion or not visible:
		return
	for index in range(actions.size()):
		var button: Button = action_buttons.get(actions[index])
		if button == null or not button.visible:
			continue
		_kill_button_tween(button)
		var overlay: Panel = button_overlays.get(button)
		_prepare_overlay_pivot(overlay)
		if overlay != null:
			overlay.scale = Vector2.ONE * ENTRANCE_SCALE
			overlay.modulate = Color(1.0, 0.78, 0.34, 0.76)
		button.modulate = Color(1.0, 0.94, 0.78, 0.0)
		var delay := float(index) * ENTRANCE_STAGGER
		var tween := button.create_tween()
		button_tweens[button] = tween
		tween.set_parallel(true)
		if overlay != null:
			tween.tween_property(overlay, "scale", Vector2.ONE, ENTRANCE_DURATION).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(overlay, "modulate", Color(1.0, 0.78, 0.34, 0.0), ENTRANCE_DURATION).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, ENTRANCE_DURATION).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_button_attention_entered(button: Button) -> void:
	_animate_button_attention(button, HOVER_SCALE)


func _on_button_attention_exited(button: Button) -> void:
	if button.has_focus():
		return
	_animate_button_attention(button, 1.0)


func _animate_button_attention(button: Button, target_scale: float) -> void:
	if reduced_motion or button == null or not button.visible:
		return
	_kill_button_tween(button)
	var overlay: Panel = button_overlays.get(button)
	_prepare_overlay_pivot(overlay)
	var tween := button.create_tween()
	button_tweens[button] = tween
	tween.set_parallel(true)
	if overlay != null:
		tween.tween_property(overlay, "scale", Vector2.ONE * target_scale, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(overlay, "modulate", Color(1.0, 0.78, 0.34, 0.72 if target_scale > 1.0 else 0.0), HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.06, 1.02, 0.90, 1.0) if target_scale > 1.0 else Color.WHITE, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _prepare_overlay_pivot(overlay: Panel) -> void:
	if overlay != null:
		overlay.pivot_offset = overlay.size * 0.5


func _kill_button_tween(button: Button) -> void:
	var tween: Tween = button_tweens.get(button)
	if tween != null and tween.is_valid():
		tween.kill()
	button_tweens.erase(button)


func _apply_focus_navigation() -> void:
	var ordered: Array[Button] = [hu_button, gang_button, peng_button, pass_button]
	for index in range(ordered.size()):
		var button := ordered[index]
		var previous := ordered[(index - 1 + ordered.size()) % ordered.size()]
		var following := ordered[(index + 1) % ordered.size()]
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(following)


func _create_motion_overlay(button: Button) -> Panel:
	var overlay := Panel.new()
	overlay.name = "MotionHighlight"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.92)
	style.set_border_width_all(4)
	style.set_corner_radius_all(96)
	style.shadow_color = Color(0.88, 0.42, 0.12, 0.42)
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	overlay.add_theme_stylebox_override("panel", style)
	button.add_child(overlay)
	return overlay


func _reset_motion_overlay(button: Button) -> void:
	var overlay: Panel = button_overlays.get(button)
	if overlay == null:
		return
	overlay.scale = Vector2.ONE
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _update_size() -> void:
	var button_width := 0.0
	var button_height := 0.0
	var visible_count := 0
	for button in action_buttons.values():
		var action_button := button as Button
		if not action_button.visible:
			continue
		visible_count += 1
		button_width += action_button.custom_minimum_size.x
		button_height = maxf(button_height, action_button.custom_minimum_size.y)
	var gap := float(button_row.get_theme_constant("separation")) * float(maxi(0, visible_count - 1))
	var button_group_width := button_width + gap + 36.0
	custom_minimum_size = Vector2(
		clampf(button_group_width, 250.0, 540.0),
		button_height + 34.0
	)
	size = custom_minimum_size


func _apply_action_size_profile(visible_count: int) -> void:
	# Mobile Mahjong decisions are usually one primary action plus Cancel. Give
	# that focused pair the same visual authority as commercial circular seals;
	# keep the compact profile only for rare three/four-option collisions.
	var focused := visible_count > 0 and visible_count <= 2
	for action in action_buttons:
		var button: Button = action_buttons[action]
		if action == "hu":
			button.custom_minimum_size = PRIMARY_FOCUSED_SIZE if focused else PRIMARY_COMPACT_SIZE
		else:
			button.custom_minimum_size = SECONDARY_FOCUSED_SIZE if focused else SECONDARY_COMPACT_SIZE


func _make_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.038, 0.0)
	style.border_color = Color(TABLE_THEME.BRASS, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


func _make_hover_style(action: String) -> StyleBoxFlat:
	var style := _make_action_seal_style(action, false)
	style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = style.border_color.lightened(0.10)
	return style


func _make_focus_style(action: String) -> StyleBoxFlat:
	var style := _make_hover_style(action)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 1.0)
	style.set_border_width_all(4)
	return style


func _make_action_seal_style(action: String, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match action:
		"hu":
			style.bg_color = Color("E86F67")
			style.border_color = Color("FFE4A8")
		"gang":
			style.bg_color = Color("F0B744")
			style.border_color = Color("FFF0BD")
		"peng":
			style.bg_color = Color("48BE92")
			style.border_color = Color("DDFBEF")
		_:
			style.bg_color = Color("438AA3")
			style.border_color = Color("DDF4F6")
	if pressed:
		style.bg_color = style.bg_color.darkened(0.18)
	style.set_border_width_all(3)
	style.set_corner_radius_all(96)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	style.shadow_color = Color(0.04, 0.22, 0.24, 0.42)
	style.shadow_size = 11 if not pressed else 3
	style.shadow_offset = Vector2(6.0, 8.0 if not pressed else 2.0)
	style.content_margin_top = 1.0 if not pressed else 6.0
	style.anti_aliasing = true
	return style
