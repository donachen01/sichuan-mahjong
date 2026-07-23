class_name TableUtilityBar
extends Control

signal ai_pressed
signal settings_pressed
signal opponent_hands_pressed
signal settlement_pressed
signal next_round_pressed
signal exit_pressed
signal collapsed_changed(collapsed: bool)

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const BUTTON_HEIGHT := 76.0
const BUTTON_GAP := 12.0
const EDGE_GAP := Vector2(24.0, 18.0)
const COLLAPSED_WIDTH := 76.0
const EXPANDED_WIDTH := 184.0
const EXIT_WIDTH := 156.0

@onready var ai_button: Button = %AIButton
@onready var toggle_button: Button = %ToggleButton
@onready var settings_button: Button = %SettingsButton
@onready var opponent_hands_button: Button = %OpponentHandsButton
@onready var settlement_button: Button = %SettlementButton
@onready var next_round_button: Button = %NextRoundButton
@onready var exit_button: Button = %ExitButton

var safe_margins := METRICS.BASE_SAFE_MARGIN
var ai_enabled := false
var collapsed := true
var round_is_complete := false
var settlement_is_dismissed := false
var current_preset_label := "骨灰"
var opponent_hands_are_visible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toggle_button.pressed.connect(_toggle_collapsed)
	ai_button.pressed.connect(func() -> void: ai_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	opponent_hands_button.pressed.connect(func() -> void: opponent_hands_pressed.emit())
	settlement_button.pressed.connect(func() -> void: settlement_pressed.emit())
	next_round_button.pressed.connect(func() -> void: next_round_pressed.emit())
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())
	for button in _all_buttons():
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		STYLE_CONFIG.apply_button(button, false)
		button.add_theme_font_size_override("font_size", 26)
	# The compact entry is an icon, not body copy. Give its three strokes enough
	# visual weight to remain immediately recognisable on a phone.
	toggle_button.add_theme_font_size_override("font_size", 40)
	_apply_button_styles()
	_apply_focus_navigation()
	if not resized.is_connected(_layout_buttons):
		resized.connect(_layout_buttons)
	render(false, false, false)
	set_collapsed(true)
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
	round_is_complete = round_complete
	settlement_is_dismissed = settlement_dismissed
	current_preset_label = preset_label
	self.opponent_hands_are_visible = opponent_hands_are_visible
	ai_button.text = "AI提示 · %s" % ("开" if ai_enabled else "关")
	ai_button.tooltip_text = "AI辅助：%s" % ("开" if ai_enabled else "关")
	settings_button.text = "难度 · %s" % preset_label
	settings_button.tooltip_text = "切换 AI 难度（当前：%s）" % preset_label
	opponent_hands_button.text = "明牌 · %s" % ("开" if opponent_hands_are_visible else "关")
	opponent_hands_button.tooltip_text = "是否显示三家 AI 手牌"
	exit_button.text = "退出游戏"
	exit_button.tooltip_text = "确认后退出四川麻将"
	_apply_collapsed_visibility()
	_apply_button_styles()
	_layout_buttons()


func set_collapsed(value: bool) -> void:
	if collapsed == value and toggle_button != null:
		_apply_collapsed_visibility()
		_layout_buttons()
		return
	collapsed = value
	_apply_collapsed_visibility()
	_layout_buttons()
	collapsed_changed.emit(collapsed)


func is_collapsed() -> bool:
	return collapsed


func _toggle_collapsed() -> void:
	set_collapsed(not collapsed)


func _apply_collapsed_visibility() -> void:
	if toggle_button == null:
		return
	toggle_button.visible = true
	toggle_button.text = "☰" if collapsed else "‹"
	toggle_button.tooltip_text = "%s左上角牌桌工具；难度：%s；明牌：%s；AI提示：%s" % [
		"展开" if collapsed else "缩进",
		current_preset_label,
		"开" if opponent_hands_are_visible else "关",
		"开" if ai_enabled else "关",
	]
	ai_button.visible = not collapsed
	settings_button.visible = not collapsed
	opponent_hands_button.visible = not collapsed
	exit_button.visible = not collapsed
	settlement_button.visible = not collapsed and round_is_complete and settlement_is_dismissed
	next_round_button.visible = not collapsed and round_is_complete
	settlement_button.disabled = not settlement_button.visible
	next_round_button.disabled = not next_round_button.visible


func get_touch_rect(action: String) -> Rect2:
	var button := get_button(action)
	return button.get_global_rect() if button != null and button.visible else Rect2()


func get_button(action: String) -> Button:
	match action:
		"toggle":
			return toggle_button
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
	if toggle_button == null or size.x <= 0.0:
		return
	var start := Vector2(safe_margins.x + EDGE_GAP.x, safe_margins.y + EDGE_GAP.y)
	# The drawer handle stays icon-sized in both states. Expanding must not turn
	# the compact target-style icon back into a wide textual header.
	_place_button(toggle_button, start, Vector2(COLLAPSED_WIDTH, BUTTON_HEIGHT))
	if collapsed:
		return
	# Keep the three requested tools in a single top row. A vertical drawer used
	# to cover the upper-left player card after the HUD was aligned to the target
	# image. The horizontal tray occupies the otherwise empty top gutter.
	var row_x := start.x + COLLAPSED_WIDTH + BUTTON_GAP
	for button in [ai_button, settings_button, opponent_hands_button]:
		if not button.visible:
			continue
		var button_width := _button_width(button)
		_place_button(button, Vector2(row_x, start.y), Vector2(button_width, BUTTON_HEIGHT))
		row_x += button_width + BUTTON_GAP
	if exit_button.visible:
		# 退出是完整文字按钮并留在同一工具行，避免孤立的“×”被误认为缩进
		# 图标；1365 宽基准下仍位于对家 HUD 左侧，不遮挡任何牌区。
		_place_button(exit_button, Vector2(row_x, start.y), Vector2(EXIT_WIDTH, BUTTON_HEIGHT))
	var right_edge := size.x - safe_margins.z - EDGE_GAP.x
	var round_action_x := right_edge
	for button in [next_round_button, settlement_button]:
		if not button.visible:
			continue
		var button_width := _button_width(button)
		round_action_x -= button_width
		_place_button(button, Vector2(round_action_x, start.y + BUTTON_HEIGHT + BUTTON_GAP), Vector2(button_width, BUTTON_HEIGHT))
		round_action_x -= BUTTON_GAP


func _place_button(button: Button, position_value: Vector2, size_value: Vector2) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = position_value
	# Lower the minimum before assigning size. If the expanded 184px minimum is
	# still active while collapsing to the 76px icon, Godot clamps one frame to
	# the old width; the next touch is then measured from a stale center and can
	# miss after relayout on iOS.
	button.custom_minimum_size = size_value
	button.size = size_value


func _button_width(button: Button) -> float:
	if button == exit_button:
		return EXIT_WIDTH
	if button == next_round_button:
		return 124.0
	if button == settlement_button:
		return 108.0
	if button in [ai_button, settings_button, opponent_hands_button]:
		return EXPANDED_WIDTH
	return 100.0


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
		var focus := normal.duplicate()
		focus.bg_color = focus.bg_color.lightened(0.06)
		focus.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 1.0)
		focus.set_border_width_all(3)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_stylebox_override("disabled", TABLE_THEME.make_utility_style(danger, true))
		button.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		button.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.92))
		button.add_theme_constant_override("outline_size", 2)


func _all_buttons() -> Array[Button]:
	return [toggle_button, ai_button, settings_button, opponent_hands_button, settlement_button, next_round_button, exit_button]


func _apply_focus_navigation() -> void:
	var drawer_order: Array[Button] = [toggle_button, ai_button, settings_button, opponent_hands_button, exit_button]
	for index in range(drawer_order.size()):
		var button := drawer_order[index]
		var previous := drawer_order[maxi(0, index - 1)]
		var following := drawer_order[mini(drawer_order.size() - 1, index + 1)]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(following)
