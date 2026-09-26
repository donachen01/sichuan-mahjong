class_name TableUtilityBar
extends Control


class ToggleGlyph extends Control:
	var collapsed_state := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_collapsed_state(value: bool) -> void:
		collapsed_state = value
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var glyph_color := Color(0.88, 1.0, 0.98, 0.88)
		if collapsed_state:
			var half_width := minf(size.x, size.y) * 0.17
			var spacing := minf(size.x, size.y) * 0.105
			var stroke := maxf(3.0, minf(size.x, size.y) * 0.052)
			for row in [-1.0, 0.0, 1.0]:
				draw_line(
					center + Vector2(-half_width, row * spacing),
					center + Vector2(half_width, row * spacing),
					glyph_color,
					stroke,
					true
				)
			return
		# Centre the triangle by its geometric centroid rather than its bounding
		# box. Font triangles carry baseline whitespace and look visibly too high.
		var triangle_height := minf(size.x, size.y) * 0.34
		var triangle_half_width := minf(size.x, size.y) * 0.22
		var points := PackedVector2Array([
			center + Vector2(0.0, -triangle_height * 2.0 / 3.0),
			center + Vector2(triangle_half_width, triangle_height / 3.0),
			center + Vector2(-triangle_half_width, triangle_height / 3.0),
		])
		draw_colored_polygon(points, glyph_color)

signal ai_pressed
signal settings_pressed
signal opponent_hands_pressed
signal skin_pressed
signal voice_pressed
signal choose_voice_pressed
signal details_pressed
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
const COLLAPSED_WIDTH := 104.0
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
@onready var choose_voice_button: Button = %ChooseVoiceButton
@onready var details_button: Button = %DetailsButton
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
var drawer_gradient: ColorRect
var toggle_glyph: ToggleGlyph
var _rendered_once := false
var _drawer_panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_drawer_gradient()
	_setup_toggle_glyph()
	toggle_button.pressed.connect(_toggle_collapsed)
	ai_button.pressed.connect(func() -> void: ai_pressed.emit())
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	opponent_hands_button.pressed.connect(func() -> void: opponent_hands_pressed.emit())
	skin_button.pressed.connect(func() -> void: skin_pressed.emit())
	voice_button.pressed.connect(func() -> void: voice_pressed.emit())
	choose_voice_button.pressed.connect(func() -> void: choose_voice_pressed.emit())
	details_button.pressed.connect(func() -> void: details_pressed.emit())
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
	toggle_button.add_theme_font_size_override("font_size", 52)
	_apply_button_styles()
	_apply_focus_navigation()
	if not resized.is_connected(_layout_buttons):
		resized.connect(_layout_buttons)
	render(false, false, false)
	set_collapsed(true)
	call_deferred("_layout_buttons")


func set_safe_margins(margins: Vector4) -> void:
	var next_margins := Vector4(
		maxf(METRICS.BASE_SAFE_MARGIN.x, margins.x),
		maxf(METRICS.BASE_SAFE_MARGIN.y, margins.y),
		maxf(METRICS.BASE_SAFE_MARGIN.z, margins.z),
		maxf(METRICS.BASE_SAFE_MARGIN.w, margins.w)
	)
	if safe_margins == next_margins:
		return
	safe_margins = next_margins
	_layout_buttons()


func render(
	ai_is_enabled: bool,
	round_complete: bool,
	settlement_dismissed: bool,
	preset_label: String = "骨灰",
	opponent_hands_are_visible: bool = false,
	voice_language_value: String = "mandarin"
) -> void:
	var resolved_language := voice_language_value if voice_language_value in ["mandarin", "sichuan"] else "mandarin"
	if _rendered_once and ai_enabled == ai_is_enabled and round_is_complete == round_complete \
		and settlement_is_dismissed == settlement_dismissed and current_preset_label == preset_label \
		and self.opponent_hands_are_visible == opponent_hands_are_visible and voice_language == resolved_language:
		return
	_rendered_once = true
	ai_enabled = ai_is_enabled
	round_is_complete = round_complete
	settlement_is_dismissed = settlement_dismissed
	current_preset_label = preset_label
	self.opponent_hands_are_visible = opponent_hands_are_visible
	voice_language = resolved_language
	ai_button.text = "✦  AI提示 · %s" % ("开" if ai_enabled else "关")
	ai_button.tooltip_text = "AI辅助：%s" % ("开" if ai_enabled else "关")
	settings_button.text = "⚙  难度 · %s" % preset_label
	settings_button.tooltip_text = "切换 AI 难度（当前：%s）" % preset_label
	opponent_hands_button.text = "◉  明牌 · %s" % ("开" if opponent_hands_are_visible else "关")
	opponent_hands_button.tooltip_text = "是否显示三家 AI 手牌"
	skin_button.text = "▦  桌布皮肤"
	skin_button.tooltip_text = "切换六套桌布皮肤"
	voice_button.text = "♪  语音 · %s" % ("四川话" if voice_language == "sichuan" else "普通话")
	voice_button.tooltip_text = "点击切换为%s" % ("普通话" if voice_language == "sichuan" else "四川话")
	choose_voice_button.text = "♫  选择声音"
	choose_voice_button.tooltip_text = "选择和试听当前玩家的声音"
	details_button.text = "☷  对局详情"
	details_button.tooltip_text = "查看对局排行、对局流水和房间玩法"
	exit_button.text = "↪  退出牌局"
	exit_button.tooltip_text = "离开当前牌局并返回游戏模式选择"
	_apply_collapsed_visibility()
	_apply_button_styles()
	_layout_buttons()


func set_collapsed(value: bool) -> void:
	if collapsed == value and toggle_button != null:
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
	toggle_button.text = ""
	if toggle_glyph != null:
		toggle_glyph.set_collapsed_state(collapsed)
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
	choose_voice_button.visible = not collapsed
	details_button.visible = false
	exit_button.visible = not collapsed
	settlement_button.visible = not collapsed
	settlement_button.text = "☷  对局详情"
	settlement_button.tooltip_text = "查看本局结算、对局排行、流水和玩法"
	next_round_button.visible = false
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
		"choose_voice":
			return choose_voice_button
		"details":
			return details_button
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
	var drawer_buttons: Array[Button] = [ai_button, settings_button, opponent_hands_button, skin_button, voice_button, choose_voice_button, details_button, settlement_button, next_round_button, exit_button]
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
	toggle_button.add_theme_font_size_override("font_size", int(round(52.0 * drawer_scale)))
	for button in drawer_buttons:
		button.add_theme_font_size_override("font_size", int(round(44.0 * drawer_scale)))
	var drawer_top := start.y + handle_size + gap
	var drawer_height := padding * 2.0 + reference_rows * button_height + maxf(0.0, reference_rows - 1) * gap
	# The expanded menu sits on one continuous dark veil beginning behind the
	# handle and fading toward the table. This keeps the buttons readable without
	# turning the left side into an opaque card.
	drawer_panel.position = start
	drawer_panel.size = Vector2(button_width * DRAWER_COLUMNS + gap + padding * 2.0, handle_size + gap + drawer_height)
	drawer_panel.custom_minimum_size = drawer_panel.size
	if _drawer_panel_style == null:
		_drawer_panel_style = _drawer_style()
		drawer_panel.add_theme_stylebox_override("panel", _drawer_panel_style)
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
	if button.position == position_value and button.size == size_value and button.custom_minimum_size == size_value:
		return
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
	if button in [ai_button, settings_button, opponent_hands_button, skin_button, voice_button, choose_voice_button, details_button]:
		return EXPANDED_WIDTH
	return 100.0


func _apply_button_styles() -> void:
	if ai_button == null:
		return
	for button in _all_buttons():
		if button == toggle_button:
			var toggle_normal := _toggle_glass_style(Color(0.025, 0.085, 0.09, 0.42), Color(0.76, 0.94, 0.92, 0.24), 2)
			var toggle_hover := _toggle_glass_style(Color(0.05, 0.18, 0.19, 0.54), Color(0.80, 0.98, 0.96, 0.42), 2)
			var toggle_pressed := _toggle_glass_style(Color(0.03, 0.13, 0.14, 0.62), Color(0.72, 0.96, 0.93, 0.52), 2)
			var toggle_focus := _toggle_glass_style(Color(0.05, 0.18, 0.19, 0.54), Color(0.82, 1.0, 0.97, 0.76), 3)
			button.add_theme_stylebox_override("normal", toggle_normal)
			button.add_theme_stylebox_override("hover", toggle_hover)
			button.add_theme_stylebox_override("pressed", toggle_pressed)
			button.add_theme_stylebox_override("focus", toggle_focus)
			button.add_theme_stylebox_override("disabled", toggle_normal.duplicate())
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_color_override("font_color", Color(0.88, 1.0, 0.98, 0.86))
			button.add_theme_color_override("font_hover_color", Color(0.94, 1.0, 0.99, 0.98))
			button.add_theme_color_override("font_pressed_color", Color(0.78, 0.98, 0.95, 0.94))
			button.add_theme_color_override("font_focus_color", Color.WHITE)
			button.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.035, 0.46))
			button.add_theme_constant_override("outline_size", 1)
			continue
		var danger := button == exit_button
		var normal := _menu_item_style(Color.TRANSPARENT)
		var hover := _menu_item_style(Color(0.56, 0.92, 0.94, 0.11))
		var pressed := _menu_item_style(Color(0.36, 0.82, 0.86, 0.18))
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		var focus := _menu_item_style(Color(0.56, 0.92, 0.94, 0.10))
		focus.border_color = Color(0.72, 0.97, 0.98, 0.72)
		focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_stylebox_override("disabled", normal.duplicate())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Keep long state labels inside their assigned invisible touch column.
		# Without clipping, Button's text minimum can silently widen the control
		# and overlap the neighbouring menu entry even though no frame is drawn.
		button.clip_text = true
		var active := (button == ai_button and ai_enabled) or (button == opponent_hands_button and "开" in button.text)
		var font_color := Color("B8F5F1") if active else Color("F1F7F5")
		if danger:
			font_color = Color("FFD5CE")
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color("D6FFFC"))
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.92))
		button.add_theme_constant_override("outline_size", 2)


func _menu_item_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _toggle_glass_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(COLLAPSED_WIDTH * 0.5))
	style.anti_aliasing = true
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 9
	style.shadow_offset = Vector2(3, 4)
	return style


func _drawer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 22
	style.shadow_offset = Vector2(10, 8)
	return style


func _setup_drawer_gradient() -> void:
	if drawer_panel == null or drawer_gradient != null:
		return
	drawer_gradient = ColorRect.new()
	drawer_gradient.name = "DrawerGradient"
	drawer_gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer_gradient.color = Color.WHITE
	drawer_gradient.set_meta("utility_gradient_shadow", true)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	float horizontal_fade = 1.0 - smoothstep(0.34, 1.0, UV.x);
	float vertical_fade = 1.0 - smoothstep(0.76, 1.0, UV.y) * 0.24;
	float edge_softness = smoothstep(0.0, 0.035, UV.y) * (1.0 - smoothstep(0.965, 1.0, UV.y));
	vec3 tint = mix(vec3(0.010, 0.024, 0.032), vec3(0.020, 0.070, 0.078), UV.x * 0.55);
	float alpha = (0.72 * horizontal_fade + 0.10) * vertical_fade * edge_softness;
	COLOR = vec4(tint, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	drawer_gradient.material = material
	drawer_panel.add_child(drawer_gradient)


func _setup_toggle_glyph() -> void:
	if toggle_button == null or toggle_glyph != null:
		return
	toggle_glyph = ToggleGlyph.new()
	toggle_glyph.name = "ToggleGlyph"
	toggle_glyph.set_meta("geometrically_centered_toggle_glyph", true)
	toggle_button.add_child(toggle_glyph)
	toggle_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _all_buttons() -> Array[Button]:
	return [toggle_button, ai_button, settings_button, opponent_hands_button, skin_button, voice_button, choose_voice_button, details_button, settlement_button, next_round_button, exit_button]


func _apply_focus_navigation() -> void:
	var drawer_order: Array[Button] = [toggle_button, ai_button, settings_button, opponent_hands_button, skin_button, voice_button, choose_voice_button, details_button, settlement_button, next_round_button, exit_button]
	for index in range(drawer_order.size()):
		var button := drawer_order[index]
		var previous := drawer_order[maxi(0, index - 1)]
		var following := drawer_order[mini(drawer_order.size() - 1, index + 1)]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(following)
