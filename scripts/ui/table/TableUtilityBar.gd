class_name TableUtilityBar
extends Control

signal ai_pressed
signal settings_pressed
signal opponent_hands_pressed
signal settlement_pressed
signal next_round_pressed
signal exit_pressed

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const BUTTON_HEIGHT := 76.0
const BUTTON_GAP := 12.0
const EDGE_GAP := Vector2(24.0, 18.0)

@onready var ai_button: Button = %AIButton
@onready var settings_button: Button = %SettingsButton
@onready var opponent_hands_button: Button = %OpponentHandsButton
@onready var settlement_button: Button = %SettlementButton
@onready var next_round_button: Button = %NextRoundButton
@onready var exit_button: Button = %ExitButton

var safe_margins := METRICS.BASE_SAFE_MARGIN
var ai_enabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ai_button.pressed.connect(func() -> void: ai_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	opponent_hands_button.pressed.connect(func() -> void: opponent_hands_pressed.emit())
	settlement_button.pressed.connect(func() -> void: settlement_pressed.emit())
	next_round_button.pressed.connect(func() -> void: next_round_pressed.emit())
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())
	for button in _all_buttons():
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		STYLE_CONFIG.apply_button(button, false)
		button.add_theme_font_size_override("font_size", 26)
	_apply_button_styles()
	if not resized.is_connected(_layout_buttons):
		resized.connect(_layout_buttons)
	render(false, false, false)
	call_deferred("_layout_buttons")


func set_safe_margins(margins: Vector4) -> void:
	safe_margins = Vector4(
		maxf(METRICS.BASE_SAFE_MARGIN.x, margins.x),
		maxf(METRICS.BASE_SAFE_MARGIN.y, margins.y),
		maxf(METRICS.BASE_SAFE_MARGIN.z, margins.z),
		maxf(METRICS.BASE_SAFE_MARGIN.w, margins.w)
	)
	_layout_buttons()


func render(
	ai_is_enabled: bool,
	round_complete: bool,
	settlement_dismissed: bool,
	preset_label: String = "骨灰",
	opponent_hands_are_visible: bool = false
) -> void:
	ai_enabled = ai_is_enabled
	ai_button.text = "AI提示 · %s" % ("开" if ai_enabled else "关")
	ai_button.tooltip_text = "AI辅助：%s" % ("开" if ai_enabled else "关")
	settings_button.text = "难度 · %s" % preset_label
	settings_button.tooltip_text = "切换 AI 难度（当前：%s）" % preset_label
	opponent_hands_button.text = "明牌 · %s" % ("开" if opponent_hands_are_visible else "关")
	opponent_hands_button.tooltip_text = "是否显示三家 AI 手牌"
	settlement_button.visible = round_complete and settlement_dismissed
	next_round_button.visible = round_complete
	settlement_button.disabled = not settlement_button.visible
	next_round_button.disabled = not next_round_button.visible
	_apply_button_styles()
	_layout_buttons()


func get_touch_rect(action: String) -> Rect2:
	var button := get_button(action)
	return button.get_global_rect() if button != null and button.visible else Rect2()


func get_button(action: String) -> Button:
	match action:
		"ai":
			return ai_button
		"settings":
			return settings_button
		"opponent_hands":
			return opponent_hands_button
		"settlement":
			return settlement_button
		"next_round":
			return next_round_button
		"exit":
			return exit_button
		_:
			return null


func _layout_buttons() -> void:
	if ai_button == null or size.x <= 0.0:
		return
	var start := Vector2(safe_margins.x + EDGE_GAP.x, safe_margins.y + EDGE_GAP.y)
	_place_button(ai_button, start, Vector2(154.0, BUTTON_HEIGHT))
	var left_edge := start.x + 154.0 + BUTTON_GAP
	for button in [settings_button, opponent_hands_button, exit_button]:
		if not button.visible:
			continue
		var button_width := _button_width(button)
		_place_button(button, Vector2(left_edge, start.y), Vector2(button_width, BUTTON_HEIGHT))
		left_edge += button_width + BUTTON_GAP
	var round_action_x := start.x
	for button in [next_round_button, settlement_button]:
		if not button.visible:
			continue
		var button_width := _button_width(button)
		_place_button(button, Vector2(round_action_x, start.y + BUTTON_HEIGHT + BUTTON_GAP), Vector2(button_width, BUTTON_HEIGHT))
		round_action_x += button_width + BUTTON_GAP


func _place_button(button: Button, position_value: Vector2, size_value: Vector2) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = position_value
	button.size = size_value
	button.custom_minimum_size = size_value


func _button_width(button: Button) -> float:
	if button == exit_button:
		return 76.0
	if button == next_round_button:
		return 124.0
	if button == settlement_button:
		return 108.0
	if button == settings_button:
		return 156.0
	if button == opponent_hands_button:
		return 142.0
	return 92.0


func _apply_button_styles() -> void:
	if ai_button == null:
		return
	for button in _all_buttons():
		var danger := button == exit_button
		var normal := TABLE_THEME.make_utility_style(danger, false)
		if (button == ai_button and ai_enabled) or (button == opponent_hands_button and "开" in button.text):
			normal.bg_color = Color("0D5A3E")
			normal.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.96)
			normal.set_border_width_all(2)
		var hover := normal.duplicate()
		hover.bg_color = hover.bg_color.lightened(0.10)
		var pressed := TABLE_THEME.make_utility_style(danger, true)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("disabled", TABLE_THEME.make_utility_style(danger, true))
		button.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		button.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.92))
		button.add_theme_constant_override("outline_size", 2)


func _all_buttons() -> Array[Button]:
	return [ai_button, settings_button, opponent_hands_button, settlement_button, next_round_button, exit_button]
