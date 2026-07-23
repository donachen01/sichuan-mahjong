extends Control

class_name AIAssistant

signal toggle_requested(expanded: bool)
signal recommendation_requested(tile_id: int)
signal opacity_changed(opacity: float)
signal opacity_change_finished(opacity: float)
signal position_changed(normalized_position: Vector2)
signal position_change_finished(normalized_position: Vector2)

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")

@export var style_config: Resource

@onready var root_panel: Panel = %RootPanel
@onready var drag_header: HBoxContainer = %Header
@onready var title_label: Label = %Title
@onready var toggle_button: Button = %ToggleButton
@onready var opacity_label: Label = %OpacityLabel
@onready var opacity_slider: HSlider = %OpacitySlider
@onready var content: VBoxContainer = %Content
@onready var recommendation_button: Button = %RecommendationButton
@onready var summary_label: Label = %SummaryLabel
@onready var reason_label: Label = %ReasonLabel
@onready var danger_label: Label = %DangerLabel
@onready var routes_label: Label = %RoutesLabel

var expanded: bool = false
var last_hint: Dictionary = {}
var glass_opacity: float = 0.70
var drag_bounds := Rect2()
var user_position_normalized := Vector2(0.5, 0.5)
var has_user_position := false
var dragging := false
var drag_offset := Vector2.ZERO
const GLASS_OPACITY_MIN := 0.0
const GLASS_OPACITY_MAX := 1.0
const GLASS_OPACITY_LEVELS := [0.0, 0.50, 1.0]
const COLLAPSED_SIZE := Vector2(560.0, 76.0)
const EXPANDED_SIZE := Vector2(760.0, 264.0)
const LOW_OPACITY_READABILITY_THRESHOLD := 0.22
const MEDIUM_OPACITY_READABILITY_THRESHOLD := 0.55


func _ready() -> void:
	if style_config == null:
		style_config = load("res://res/ui/default_ui_style.tres")
	style_config.apply_panel(root_panel)
	style_config.apply_button(toggle_button, false)
	style_config.apply_button(recommendation_button, true)
	style_config.apply_label(summary_label, false, false)
	style_config.apply_label(reason_label, true, false)
	style_config.apply_label(danger_label, true, false)
	style_config.apply_label(routes_label, true, false)
	style_config.apply_label(title_label, false, true)
	style_config.apply_label(opacity_label, true, false)
	root_panel.add_theme_stylebox_override("panel", _make_drawer_style())
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
	for label in [summary_label, reason_label, danger_label, routes_label]:
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY if label == summary_label else TABLE_THEME.TEXT_SECONDARY)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.94))
		label.add_theme_constant_override("outline_size", 3)
	toggle_button.custom_minimum_size = Vector2(88.0, 52.0)
	toggle_button.add_theme_font_size_override("font_size", 22)
	opacity_label.add_theme_font_size_override("font_size", 19)
	opacity_label.add_theme_color_override("font_color", TABLE_THEME.TEXT_SECONDARY)
	_apply_opacity_slider_style()
	recommendation_button.add_theme_font_size_override("font_size", 24)
	var recommendation_normal := _make_recommendation_style(false)
	var recommendation_hover := _make_recommendation_style(false)
	recommendation_hover.bg_color = recommendation_hover.bg_color.lightened(0.08)
	recommendation_button.add_theme_stylebox_override("normal", recommendation_normal)
	recommendation_button.add_theme_stylebox_override("hover", recommendation_hover)
	recommendation_button.add_theme_stylebox_override("focus", recommendation_hover)
	recommendation_button.add_theme_stylebox_override("pressed", _make_recommendation_style(true))
	recommendation_button.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
	for focus_control in [toggle_button, opacity_slider, recommendation_button]:
		focus_control.focus_mode = Control.FOCUS_ALL
	toggle_button.pressed.connect(_on_toggle_pressed)
	opacity_slider.value_changed.connect(_on_opacity_value_changed)
	opacity_slider.drag_ended.connect(_on_opacity_drag_ended)
	# Only the title is a drag handle.  The old full-header handler also caught
	# events bubbling from the toggle and slider, leaving both controls in a
	# half-drag state after moving the drawer.
	drag_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.gui_input.connect(_on_drag_header_gui_input)
	recommendation_button.pressed.connect(_on_recommendation_pressed)
	_apply_glass_opacity()
	set_process_input(false)
	set_expanded(false)


func apply_hint(trainer_hint: Dictionary, can_discard: bool, selected_tile_id: int = -1) -> void:
	last_hint = trainer_hint.duplicate(true)
	var recommended: Dictionary = trainer_hint.get("recommended", {})
	if not can_discard or recommended.is_empty():
		summary_label.text = "等待你的出牌回合"
		recommendation_button.visible = false
		reason_label.text = ""
		danger_label.text = ""
		routes_label.text = ""
		_update_header_text()
		return

	var recommended_tile_id := int(recommended.get("tile", {}).get("id", -1))
	var recommended_tile_name := str(recommended.get("tile_name", "?"))
	summary_label.text = "建议先打：%s" % recommended_tile_name
	var selected_option: Dictionary = {}
	if selected_tile_id != -1 and selected_tile_id != recommended_tile_id:
		selected_option = _find_option_by_tile_id(trainer_hint.get("options", []), selected_tile_id)
		if not selected_option.is_empty():
			summary_label.text += " · 已选%s（%s）" % [
				str(selected_option.get("tile_name", "?")),
				_plain_risk_label(str(selected_option.get("risk_label", "低危"))),
			]

	recommendation_button.visible = expanded and recommended_tile_id != -1
	recommendation_button.text = "点此选中 %s" % recommended_tile_name
	var display_option: Dictionary = selected_option if not selected_option.is_empty() else recommended
	var reasons: Array = display_option.get("reasons", [])
	var posterior_reasons: Array = display_option.get("posterior_reasons", display_option.get("csharp_posterior_reasons", []))
	var reason_parts: Array[String] = []
	if not reasons.is_empty():
		var base_lines: Array[String] = []
		for item in reasons.slice(0, 2):
			base_lines.append(_humanize_reason_text(str(item)))
		reason_parts.append("主要原因：%s" % "；".join(base_lines))
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		var table_lines: Array[String] = []
		for item in posterior_reasons.slice(0, 2):
			table_lines.append(_humanize_reason_text(str(item)))
		reason_parts.append("结合场上情况：%s" % "；".join(table_lines))
	if reason_parts.is_empty():
		reason_parts.append("先顾摸牌顺不顺，也顾一下安全。")
	reason_label.text = "原因：%s" % " ".join(reason_parts)
	var danger_lines: Array = []
	for item in trainer_hint.get("danger_tiles", []).slice(0, 2):
		var line := "%s：%s" % [
			str(item.get("tile_name", "?")),
			_plain_risk_label(str(item.get("risk_label", "低危")))
		]
		var risk_reasons: Array = item.get("risk_reasons", [])
		if not risk_reasons.is_empty():
			line += "，%s" % _humanize_reason_text(str(risk_reasons[0]))
		danger_lines.append(line)
	danger_label.text = "风险：%s" % (" / ".join(danger_lines) if not danger_lines.is_empty() else "暂无明显危险牌")

	var route_text := _format_routes(trainer_hint.get("current_routes", []))
	if route_text.is_empty():
		route_text = "先顾速度，也顾安全"
	routes_label.text = "方向：%s" % route_text
	if not selected_option.is_empty() and selected_tile_id != recommended_tile_id:
			routes_label.text += "\n为什么不先打%s：%s" % [
			str(selected_option.get("tile_name", "?")),
			_build_selected_option_delta_text(recommended, selected_option),
		]
	_update_header_text()


func _format_routes(routes: Array) -> String:
	var labels: Array[String] = []
	for route in routes:
		if route is String:
			if not str(route).is_empty():
				labels.append(str(route))
			continue
		if route is Dictionary:
			var route_data: Dictionary = route
			for key in ["label", "name", "route_name", "display_name", "title"]:
				var candidate := str(route_data.get(key, ""))
				if not candidate.is_empty():
					labels.append(candidate)
					break
	return "、".join(labels)


func _on_toggle_pressed() -> void:
	set_expanded(not expanded)
	toggle_requested.emit(expanded)


func set_expanded(value: bool) -> void:
	expanded = value
	var recommended: Dictionary = last_hint.get("recommended", {})
	recommendation_button.visible = expanded and int(recommended.get("tile", {}).get("id", -1)) != -1
	content.visible = expanded
	opacity_label.visible = expanded
	opacity_slider.visible = expanded
	toggle_button.text = "收起" if expanded else "展开"
	custom_minimum_size = EXPANDED_SIZE if expanded else COLLAPSED_SIZE
	size = custom_minimum_size
	_update_header_text()
	if has_user_position:
		_apply_normalized_position()
	else:
		_clamp_to_drag_bounds()


func is_expanded() -> bool:
	return expanded


func _update_header_text() -> void:
	if title_label == null:
		return
	if expanded:
		title_label.text = "AI 对局提示"
		return
	var recommended: Dictionary = last_hint.get("recommended", {})
	var tile_name := str(recommended.get("tile_name", ""))
	var risk_text := _plain_risk_label(str(recommended.get("risk_label", "低危")))
	title_label.text = "AI建议：%s · %s" % [tile_name, risk_text] if not tile_name.is_empty() else "AI 对局提示"


func set_glass_opacity_index(value: int) -> void:
	var safe_index := clampi(value, 0, GLASS_OPACITY_LEVELS.size() - 1)
	set_glass_opacity(float(GLASS_OPACITY_LEVELS[safe_index]))


func get_glass_opacity_index() -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(GLASS_OPACITY_LEVELS.size()):
		var distance := absf(glass_opacity - float(GLASS_OPACITY_LEVELS[index]))
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func set_glass_opacity(value: float) -> void:
	glass_opacity = clampf(value, GLASS_OPACITY_MIN, GLASS_OPACITY_MAX)
	_apply_glass_opacity()


func get_glass_opacity() -> float:
	return glass_opacity


func _on_opacity_value_changed(value: float) -> void:
	glass_opacity = clampf(value, GLASS_OPACITY_MIN, GLASS_OPACITY_MAX)
	_apply_glass_opacity()
	opacity_changed.emit(glass_opacity)


func _on_opacity_drag_ended(_value_changed: bool) -> void:
	opacity_change_finished.emit(glass_opacity)


func _apply_glass_opacity() -> void:
	if root_panel == null or opacity_slider == null or opacity_label == null:
		return
	root_panel.add_theme_stylebox_override("panel", _make_drawer_style())
	opacity_slider.set_value_no_signal(glass_opacity)
	opacity_label.text = "透明度 %d%%" % int(round(glass_opacity * 100.0))
	opacity_slider.tooltip_text = "拖动调节 AI 建议框背景透明度（0%–100%）"
	_apply_readability_styles()


func get_readability_contract() -> Dictionary:
	return {
		"background_only_opacity": true,
		"text_remains_opaque": true,
		"low_opacity_threshold": LOW_OPACITY_READABILITY_THRESHOLD,
		"medium_opacity_threshold": MEDIUM_OPACITY_READABILITY_THRESHOLD,
		"low_opacity_text_scrim": true,
		"medium_opacity_text_scrim": true,
		"collapsed_size": COLLAPSED_SIZE,
		"expanded_size": EXPANDED_SIZE,
		"collapsed_summary_contains_risk": true,
	}


func _apply_readability_styles() -> void:
	var low_opacity := glass_opacity <= LOW_OPACITY_READABILITY_THRESHOLD
	var medium_opacity := glass_opacity <= MEDIUM_OPACITY_READABILITY_THRESHOLD
	# A 50% drawer is frequently positioned above a busy discard river. Keep a
	# local dark reading strip behind text through the medium setting; this does
	# not alter the user-controlled panel opacity or fade any text/control.
	var scrim_alpha := 0.60 if low_opacity else (0.34 if medium_opacity else 0.0)
	for label in [title_label, summary_label, reason_label, danger_label, routes_label, opacity_label]:
		if label == null:
			continue
		label.self_modulate = Color.WHITE
		label.add_theme_color_override("font_outline_color", Color(0.008, 0.025, 0.020, 0.99))
		label.add_theme_constant_override("outline_size", 4 if low_opacity else (3 if label != opacity_label else 2))
		var scrim := StyleBoxFlat.new()
		scrim.bg_color = Color(0.008, 0.055, 0.046, scrim_alpha)
		scrim.set_corner_radius_all(5)
		scrim.content_margin_left = 5.0 if medium_opacity else 0.0
		scrim.content_margin_right = 5.0 if medium_opacity else 0.0
		scrim.content_margin_top = 2.0 if medium_opacity else 0.0
		scrim.content_margin_bottom = 2.0 if medium_opacity else 0.0
		label.add_theme_stylebox_override("normal", scrim)


func set_drag_bounds(bounds: Rect2) -> void:
	drag_bounds = bounds
	if has_user_position:
		_apply_normalized_position()
	else:
		_clamp_to_drag_bounds()


func place_default_position(default_position: Vector2) -> void:
	if has_user_position:
		_apply_normalized_position()
		return
	position = default_position
	_clamp_to_drag_bounds()


func restore_user_position(normalized_position: Vector2, enabled: bool) -> void:
	user_position_normalized = Vector2(
		clampf(normalized_position.x, 0.0, 1.0),
		clampf(normalized_position.y, 0.0, 1.0)
	)
	has_user_position = enabled
	if has_user_position:
		_apply_normalized_position()


func get_user_position_normalized() -> Vector2:
	return user_position_normalized


func is_user_positioned() -> bool:
	return has_user_position


func _on_drag_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_drag(_pointer_position_in_parent())
			title_label.accept_event()
		else:
			_finish_drag()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag(_viewport_to_parent(touch_event.position))
			title_label.accept_event()
		else:
			_finish_drag()


func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseMotion:
		_drag_to(_pointer_position_in_parent())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		_drag_to(_viewport_to_parent((event as InputEventScreenDrag).position))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_finish_drag()
		get_viewport().set_input_as_handled()


func _begin_drag(pointer_position: Vector2) -> void:
	dragging = true
	drag_offset = pointer_position - position
	set_process_input(true)


func _drag_to(pointer_position: Vector2) -> void:
	position = pointer_position - drag_offset
	_clamp_to_drag_bounds()
	_sync_normalized_position()
	has_user_position = true
	position_changed.emit(user_position_normalized)


func _finish_drag() -> void:
	if not dragging:
		return
	dragging = false
	set_process_input(false)
	_sync_normalized_position()
	has_user_position = true
	position_change_finished.emit(user_position_normalized)


func _pointer_position_in_parent() -> Vector2:
	var parent_control := get_parent() as Control
	return parent_control.get_local_mouse_position() if parent_control != null else get_viewport().get_mouse_position()


func _viewport_to_parent(viewport_position: Vector2) -> Vector2:
	var parent_control := get_parent() as Control
	return viewport_position - parent_control.global_position if parent_control != null else viewport_position


func _clamp_to_drag_bounds() -> void:
	if drag_bounds.size.x <= 0.0 or drag_bounds.size.y <= 0.0:
		return
	var max_position := drag_bounds.end - size
	position = Vector2(
		clampf(position.x, drag_bounds.position.x, maxf(drag_bounds.position.x, max_position.x)),
		clampf(position.y, drag_bounds.position.y, maxf(drag_bounds.position.y, max_position.y))
	)


func _sync_normalized_position() -> void:
	var span := Vector2(
		maxf(1.0, drag_bounds.size.x - size.x),
		maxf(1.0, drag_bounds.size.y - size.y)
	)
	user_position_normalized = Vector2(
		clampf((position.x - drag_bounds.position.x) / span.x, 0.0, 1.0),
		clampf((position.y - drag_bounds.position.y) / span.y, 0.0, 1.0)
	)


func _apply_normalized_position() -> void:
	if drag_bounds.size.x <= 0.0 or drag_bounds.size.y <= 0.0:
		return
	var span := Vector2(
		maxf(0.0, drag_bounds.size.x - size.x),
		maxf(0.0, drag_bounds.size.y - size.y)
	)
	position = drag_bounds.position + user_position_normalized * span
	_clamp_to_drag_bounds()


func _apply_opacity_slider_style() -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.015, 0.08, 0.068, 0.86)
	rail.border_color = Color(TABLE_THEME.AGED_COPPER, 0.72)
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(6)
	rail.content_margin_top = 7
	rail.content_margin_bottom = 7
	var fill := rail.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.05, 0.35, 0.25, 0.94)
	fill.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.88)
	opacity_slider.add_theme_stylebox_override("slider", rail)
	opacity_slider.add_theme_stylebox_override("grabber_area", fill)
	opacity_slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _on_recommendation_pressed() -> void:
	var recommended: Dictionary = last_hint.get("recommended", {})
	var tile_id := int(recommended.get("tile", {}).get("id", -1))
	if tile_id != -1:
		recommendation_requested.emit(tile_id)


func _find_option_by_tile_id(options: Array, tile_id: int) -> Dictionary:
	for option in options:
		var tile: Dictionary = option.get("tile", {})
		if int(tile.get("id", -1)) == tile_id:
			return option
	return {}


func _build_selected_option_delta_text(recommended: Dictionary, selected_option: Dictionary) -> String:
	var delta_shanten := int(selected_option.get("shanten", 8)) - int(recommended.get("shanten", 8))
	var delta_ukeire := int(selected_option.get("live_ukeire", 0)) - int(recommended.get("live_ukeire", 0))
	var delta_risk := int(selected_option.get("risk", 0)) - int(recommended.get("risk", 0))
	var parts: Array[String] = []
	if delta_shanten > 0:
		parts.append("会晚%d步才更接近听牌" % delta_shanten)
	elif delta_shanten < 0:
		parts.append("会快%d步接近听牌" % abs(delta_shanten))
	if delta_ukeire < 0:
		parts.append("后面能接上的牌会少%d张" % abs(delta_ukeire))
	elif delta_ukeire > 0:
		parts.append("后面能接上的牌会多%d张" % delta_ukeire)
	if delta_risk > 0:
		parts.append("而且会更危险一些")
	var posterior_reasons: Array = selected_option.get("posterior_reasons", selected_option.get("csharp_posterior_reasons", []))
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		parts.append(_humanize_reason_text(str(posterior_reasons[0])))
	if parts.is_empty():
		return "综合看没有现在这张合适"
	return "｜".join(parts.slice(0, 3))


func _plain_risk_label(risk_label: String) -> String:
	match risk_label:
		"高危":
			return "危险比较大"
		"中危":
			return "有点危险"
		_:
			return "相对安全"


func _plain_shanten_text(shanten: int) -> String:
	if shanten <= 0:
		return "已经听牌"
	return "离听牌还差%d步" % shanten


func _plain_ukeire_text(ukeire: int) -> String:
	return "后面能接上的牌大约%d张" % maxi(0, ukeire)


func _humanize_reason_text(text: String) -> String:
	var result := text
	var replacements := {
		"向听": "离听牌",
		"活进张": "能接上的牌",
		"进张": "能接上的牌",
		"后验": "结合场上情况再看",
		"压分": "会拉低收益",
		"净分期望": "综合收益",
		"危险度": "危险大小",
		"听形": "听牌后的牌路",
		"两面搭子": "两头都能接的顺子搭子",
		"孤张": "单张",
		"连张": "连着的牌",
		"宽叫": "更容易听牌",
	}
	for key in replacements.keys():
		result = result.replace(key, str(replacements[key]))
	return result


func _make_drawer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var alpha := glass_opacity
	# Match the navy lacquer used by SeatHUD and the utility rail so the helper
	# feels like part of the table system, not a separate green debug overlay.
	style.bg_color = Color(TABLE_THEME.PANEL_JADE_BLACK, alpha)
	style.border_color = Color(TABLE_THEME.BRASS, minf(0.92, 0.12 + alpha * 0.80))
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, alpha * 0.42)
	style.shadow_size = int(round(18.0 * alpha))
	style.shadow_offset = Vector2(7.0, 9.0)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style


func _make_recommendation_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.31, 0.23, 0.98) if not pressed else Color(0.02, 0.22, 0.17, 0.98)
	style.border_color = Color(TABLE_THEME.BRASS, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 6 if not pressed else 2
	style.shadow_offset = Vector2(0.0, 3.0 if not pressed else 1.0)
	return style
