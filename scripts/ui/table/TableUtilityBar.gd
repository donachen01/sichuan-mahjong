class_name TableUtilityBar
extends Control

signal ai_pressed
signal settings_pressed
signal opponent_hands_pressed
signal skin_pressed
signal voice_pressed
signal settlement_pressed
signal next_round_pressed
signal exit_pressed
signal collapsed_changed(collapsed: bool)

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const BUTTON_HEIGHT := 116.0
const BUTTON_GAP := 12.0
const EDGE_GAP := Vector2(24.0, 18.0)
const COLLAPSED_WIDTH := 148.0
const EXPANDED_WIDTH := 372.0
const EXIT_WIDTH := 372.0
const DRAWER_PADDING := 12.0
const DRAWER_COLUMNS := 2

@onready var ai_button: Button = %AIButton
@onready var toggle_button: Button = %ToggleButton
@onready var drawer_panel: Panel = %DrawerPanel
@onready var settings_button: Button = %SettingsButton
@onready var opponent_hands_button: Button = %OpponentHandsButton
@onready var skin_button: Button = %SkinButton
@onready var voice_button: Button = %VoiceButton
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
var voice_language := "mandarin"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toggle_button.pressed.connect(_toggle_collapsed)
	ai_button.pressed.connect(func() -> void: ai_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	opponent_hands_button.pressed.connect(func() -> void: opponent_hands_pressed.emit())
	skin_button.pressed.connect(func() -> void: skin_pressed.emit())
	voice_button.pressed.connect(func() -> void: voice_pressed.emit())
	settlement_button.pressed.connect(func() -> void: settlement_pressed.emit())
	next_round_button.pressed.connect(func() -> void: next_round_pressed.emit())
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())
	for button in _all_buttons():
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		STYLE_CONFIG.apply_button(button, false)
		button.add_theme_font_size_override("font_size", 44)
	# The compact entry is an icon, not body copy. Give its three strokes enough
	# visual weight to remain immediately recognisable on a phone.
	toggle_button.add_theme_font_size_override("font_size", 78)
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
	opponent_hands_are_visible: bool = false,
	voice_language_value: String = "mandarin"
) -> void:
	ai_enabled = ai_is_enabled
	round_is_complete = round_complete
	settlement_is_dismissed = settlement_dismissed
	current_preset_label = preset_label
	self.opponent_hands_are_visible = opponent_hands_are_visible
	voice_language = voice_language_value if voice_language_value in ["mandarin", "sichuan"] else "mandarin"
	ai_button.text = "AI提示 · %s" % ("开" if ai_enabled else "关")
	ai_button.tooltip_text = "AI辅助：%s" % ("开" if ai_enabled else "关")
	settings_button.text = "难度 · %s" % preset_label
	settings_button.tooltip_text = "切换 AI 难度（当前：%s）" % preset_label
	opponent_hands_button.text = "明牌 · %s" % ("开" if opponent_hands_are_visible else "关")
	opponent_hands_button.tooltip_text = "是否显示三家 AI 手牌"
	skin_button.text = "桌布皮肤"
	skin_button.tooltip_text = "切换六套桌布皮肤"
	voice_button.text = "语音 · %s" % ("四川话" if voice_language == "sichuan" else "普通话")
	voice_button.tooltip_text = "点击切换为%s" % ("普通话" if voice_language == "sichuan" else "四川话")
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
	toggle_button.text = "☰" if collapsed else "▲"
	toggle_button.tooltip_text = "%s左上角牌桌工具；难度：%s；明牌：%s；AI提示：%s" % [
		"展开" if collapsed else "缩进",
		current_preset_label,
		"开" if opponent_hands_are_visible else "关",
		"开" if ai_enabled else "关",
	]
	ai_button.visible = not collapsed
	settings_button.visible = not collapsed
	opponent_hands_button.visible = not collapsed
	skin_button.visible = not collapsed
	voice_button.visible = not collapsed
	exit_button.visible = not collapsed
	settlement_button.visible = not collapsed and round_is_complete and settlement_is_dismissed
	next_round_button.visible = not collapsed and round_is_complete
	settlement_button.disabled = not settlement_button.visible
	next_round_button.disabled = not next_round_button.visible
	drawer_panel.visible = not collapsed


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
		"skin":
			return skin_button
		"voice":
			return voice_button
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
	_place_button(toggle_button, start, Vector2(COLLAPSED_WIDTH, COLLAPSED_WIDTH))
	if collapsed:
		drawer_panel.visible = false
		return
	var drawer_buttons: Array[Button] = [ai_button, settings_button, opponent_hands_button, skin_button, voice_button, settlement_button, next_round_button, exit_button]
	var visible_buttons: Array[Button] = []
	for button in drawer_buttons:
		if not button.visible:
			continue
		visible_buttons.append(button)
	# At the 2048x1152 reference size every control and glyph is exactly twice
	# the previous drawer. On shorter compatibility windows the entire grid is
	# uniformly scaled, never allowing a touch target below 76px.
	var available_height := maxf(1.0, size.y - start.y - 18.0)
	var reference_rows := ceili(float(visible_buttons.size()) / float(DRAWER_COLUMNS))
	var reference_total_height := COLLAPSED_WIDTH + BUTTON_GAP + DRAWER_PADDING * 2.0 \
		+ reference_rows * BUTTON_HEIGHT + maxf(0.0, reference_rows - 1) * BUTTON_GAP
	var drawer_scale := minf(1.0, available_height / reference_total_height)
	drawer_scale = maxf(drawer_scale, 76.0 / BUTTON_HEIGHT)
	var handle_size := COLLAPSED_WIDTH * drawer_scale
	var button_width := EXPANDED_WIDTH * drawer_scale
	var button_height := BUTTON_HEIGHT * drawer_scale
	var gap := BUTTON_GAP * drawer_scale
	var padding := DRAWER_PADDING * drawer_scale
	_place_button(toggle_button, start, Vector2(handle_size, handle_size))
	toggle_button.add_theme_font_size_override("font_size", int(round(78.0 * drawer_scale)))
	for button in drawer_buttons:
		button.add_theme_font_size_override("font_size", int(round(44.0 * drawer_scale)))
	var drawer_top := start.y + handle_size + gap
	var drawer_height := padding * 2.0 + reference_rows * button_height + maxf(0.0, reference_rows - 1) * gap
	drawer_panel.position = Vector2(start.x, drawer_top)
	drawer_panel.size = Vector2(button_width * DRAWER_COLUMNS + gap + padding * 2.0, drawer_height)
	drawer_panel.custom_minimum_size = drawer_panel.size
	drawer_panel.add_theme_stylebox_override("panel", _drawer_style())
	for index in range(visible_buttons.size()):
		var column := index % DRAWER_COLUMNS
		var row := index / DRAWER_COLUMNS
		_place_button(
			visible_buttons[index],
			Vector2(start.x + padding + column * (button_width + gap), drawer_top + padding + row * (button_height + gap)),
			Vector2(button_width, button_height)
		)


func get_occupied_rect() -> Rect2:
	if toggle_button == null:
		return Rect2()
	var occupied := toggle_button.get_global_rect()
	if not collapsed and drawer_panel != null and drawer_panel.visible:
		occupied = occupied.merge(drawer_panel.get_global_rect())
	return occupied


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
	if button in [ai_button, settings_button, opponent_hands_button, skin_button, voice_button]:
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


func _drawer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.095, 0.078, 0.97)
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 14
	style.shadow_offset = Vector2(4, 6)
	return style


func _all_buttons() -> Array[Button]:
	return [toggle_button, ai_button, settings_button, opponent_hands_button, skin_button, voice_button, settlement_button, next_round_button, exit_button]


func _apply_focus_navigation() -> void:
	var drawer_order: Array[Button] = [toggle_button, ai_button, settings_button, opponent_hands_button, skin_button, voice_button, settlement_button, next_round_button, exit_button]
	for index in range(drawer_order.size()):
		var button := drawer_order[index]
		var previous := drawer_order[maxi(0, index - 1)]
		var following := drawer_order[mini(drawer_order.size() - 1, index + 1)]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(following)
