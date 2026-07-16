class_name TableActionBar
extends Control

signal action_selected(action: String)

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

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
	background_panel.add_theme_stylebox_override("panel", _make_background_style())
	for action in action_buttons:
		var button: Button = action_buttons[action]
		STYLE_CONFIG.apply_button(button, true)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", TABLE_THEME.font_size("action_primary" if action == "hu" else "action_secondary"))
		button.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		button.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.92))
		button.add_theme_constant_override("outline_size", 3)
		button.add_theme_stylebox_override("normal", TABLE_THEME.make_action_style(action, false))
		button.add_theme_stylebox_override("hover", _make_hover_style(action))
		button.add_theme_stylebox_override("pressed", TABLE_THEME.make_action_style(action, true))
		button.pressed.connect(_on_button_pressed.bind(str(action)))
	hide_actions()


func render(actions: Array[String], _status_text: String) -> void:
	var accepted: Array[String] = []
	for action in actions:
		if action_buttons.has(action) and not accepted.has(action):
			accepted.append(action)
	for action in action_buttons:
		var button: Button = action_buttons[action]
		button.visible = accepted.has(str(action))
	status_label.text = ""
	status_label.visible = false
	context_mark.visible = false
	visible = not accepted.is_empty()
	if visible:
		_update_size()


func hide_actions() -> void:
	visible = false
	for button in action_buttons.values():
		(button as Button).visible = false


func set_action_label(action: String, label_text: String) -> void:
	var button: Button = action_buttons.get(action)
	if button != null:
		button.text = label_text


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


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
		"material_family": "ivory_jade_action_tiles",
		"primary_shape": "shu_cut_corner_tile",
		"shape_motif": "shu_courtyard_cut_corner",
		"pass_hierarchy": "secondary",
		"context_surface": "decision_tile_group",
		"auxiliary_text": "hidden",
		"pressed_feedback": "depth_compression",
	}


func _on_button_pressed(action: String) -> void:
	if not reduced_motion:
		var button: Button = action_buttons.get(action)
		if button != null:
			button.modulate = Color(0.78, 0.82, 0.79, 1.0)
			var tween := button.create_tween()
			tween.tween_property(button, "modulate", Color.WHITE, 0.14)
	action_selected.emit(action)


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
	var style := TABLE_THEME.make_action_style(action, false)
	style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = style.border_color.lightened(0.10)
	return style
