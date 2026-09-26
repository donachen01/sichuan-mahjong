class_name SichuanTableSkinPanel
extends Control

signal skin_selected(skin_id: String)
signal closed

const CATALOG := preload("res://scripts/ui/table/SichuanTableSkinCatalog.gd")
const BODY_FONT := preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
const CARD_SIZE := Vector2(610.0, 168.0)
const AUTHORED_SIZE := Vector2(1320.0, 972.0)
const AVOID_GAP := 24.0

var selected_skin_id := SichuanTableSkinCatalog.DEFAULT_SKIN_ID
var safe_margins := Vector4(18.0, 14.0, 18.0, 18.0)
var avoid_rect := Rect2()
var panel: PanelContainer
var grid: GridContainer
var close_button: Button
var skin_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 610
	_build_ui()
	visible = false
	set_process_unhandled_key_input(true)


func open(current_skin_id: String) -> void:
	selected_skin_id = current_skin_id if CATALOG.has_skin(current_skin_id) else CATALOG.DEFAULT_SKIN_ID
	# The user must see the chooser as a direct consequence of the first press.
	# Six lightweight style updates are cheaper than deferring the entire visible
	# layout and making iOS appear to have ignored the tap.
	visible = true
	_refresh_selection()
	_apply_safe_layout()
	call_deferred("_focus_selected")


func _finish_open() -> void:
	if not visible:
		return
	_refresh_selection()
	_apply_safe_layout()
	_focus_selected()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func set_safe_margins(value: Vector4) -> void:
	if safe_margins == value:
		return
	safe_margins = value
	_apply_safe_layout()


func set_avoid_rect(value: Rect2) -> void:
	if avoid_rect == value:
		return
	avoid_rect = value
	_apply_safe_layout()


func get_visual_contract() -> Dictionary:
	return {
		"skin_count": skin_buttons.size(),
		"selected_skin_id": selected_skin_id,
		"safe_area_aware": true,
		"columns": 2,
		"touch_target": CARD_SIZE,
		"modal": true,
		"blocks_gameplay_input": true,
		"avoids_toolbar": true,
		"authored_size": AUTHORED_SIZE,
	}


func handle_pointer_press(global_position: Vector2) -> bool:
	if not visible:
		return false
	if close_button != null and close_button.visible and close_button.get_global_rect().has_point(global_position):
		close_button.emit_signal("pressed")
		return true
	for skin_id_value in skin_buttons:
		var button := skin_buttons.get(str(skin_id_value)) as Button
		if button != null and button.visible and button.get_global_rect().has_point(global_position):
			button.emit_signal("pressed")
			return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.name = "TableSkinShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.075, 0.16, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
	add_child(shade)

	panel = PanelContainer.new()
	panel.name = "TableSkinChooser"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var title_label := Label.new()
	title_label.text = "桌布皮肤"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", BODY_FONT)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color("F7FCFF"))
	header.add_child(title_label)
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(176.0, 76.0)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_override("font", BODY_FONT)
	close_button.add_theme_font_size_override("font_size", 32)
	close_button.add_theme_color_override("font_color", Color("F7FCFF"))
	close_button.add_theme_stylebox_override("normal", _button_style(Color(0.19, 0.57, 0.89, 0.55), Color(0.94, 0.99, 1.0, 0.84), 2))
	close_button.add_theme_stylebox_override("hover", _button_style(Color(0.25, 0.68, 0.98, 0.72), Color.WHITE, 3))
	close_button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.36, 0.72, 0.78), Color.WHITE, 3))
	close_button.add_theme_stylebox_override("focus", _button_style(Color(0.25, 0.68, 0.98, 0.72), Color.WHITE, 3))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var description := Label.new()
	description.text = "选择牌桌材质与色彩 · 仅改变外观，不影响玩法"
	description.add_theme_font_override("font", BODY_FONT)
	description.add_theme_font_size_override("font_size", 30)
	description.add_theme_color_override("font_color", Color("DCEEF9"))
	column.add_child(description)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	column.add_child(grid)
	for skin in CATALOG.all_skins():
		_create_skin_card(skin)
	_apply_focus_navigation()
	_apply_safe_layout()


func _create_skin_card(skin: Dictionary) -> void:
	var skin_id := str(skin.get("id", ""))
	var button := Button.new()
	button.name = "TableSkin_%s" % skin_id
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.text = "%s\n%s" % [str(skin.get("name", skin_id)), str(skin.get("chooser_subtitle", skin.get("subtitle", "")))]
	button.clip_text = true
	button.icon = ResourceLoader.load(CATALOG.texture_path(skin_id, "preview.jpg")) as Texture2D
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color("F7FCFF"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_constant_override("icon_separation", 24)
	button.pressed.connect(_select_skin.bind(skin_id))
	grid.add_child(button)
	skin_buttons[skin_id] = button


func _select_skin(skin_id: String) -> void:
	if not CATALOG.has_skin(skin_id):
		return
	selected_skin_id = skin_id
	_refresh_selection()
	skin_selected.emit(skin_id)


func _refresh_selection() -> void:
	for skin_id_value in skin_buttons:
		var skin_id := str(skin_id_value)
		var button := skin_buttons.get(skin_id) as Button
		if button == null:
			continue
		var active := skin_id == selected_skin_id
		button.add_theme_stylebox_override("normal", _button_style(
			Color(0.14, 0.50, 0.86, 0.58) if active else Color(0.82, 0.94, 1.0, 0.14),
			Color(0.96, 1.0, 1.0, 0.96) if active else Color(0.88, 0.97, 1.0, 0.65),
			3 if active else 2,
			20
		))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.20, 0.62, 0.94, 0.65), Color.WHITE, 3, 20))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.43, 0.84, 0.75), Color.WHITE, 3, 20))
		button.add_theme_stylebox_override("focus", _button_style(Color(0.20, 0.62, 0.94, 0.65), Color.WHITE, 3, 20))
		button.tooltip_text = "%s%s" % ["当前使用 · " if active else "切换为 · ", button.text.replace("\n", " ")]


func _focus_selected() -> void:
	var button := skin_buttons.get(selected_skin_id) as Button
	if button != null and visible:
		button.grab_focus()


func _apply_focus_navigation() -> void:
	var ordered: Array[Button] = []
	for skin in CATALOG.all_skins():
		var button := skin_buttons.get(str(skin.get("id", ""))) as Button
		if button != null:
			ordered.append(button)
	for index in range(ordered.size()):
		var row := floori(float(index) / 2.0)
		var column := index % 2
		var sibling_index := mini(ordered.size() - 1, row * 2 + (1 - column))
		var up_index := maxi(0, index - 2)
		var down_index := mini(ordered.size() - 1, index + 2)
		ordered[index].focus_neighbor_left = ordered[index].get_path_to(ordered[sibling_index])
		ordered[index].focus_neighbor_right = ordered[index].get_path_to(ordered[sibling_index])
		ordered[index].focus_neighbor_top = ordered[index].get_path_to(ordered[up_index])
		ordered[index].focus_neighbor_bottom = ordered[index].get_path_to(ordered[down_index])
	if not ordered.is_empty() and close_button != null:
		close_button.focus_neighbor_bottom = close_button.get_path_to(ordered[0])
		ordered[0].focus_neighbor_top = ordered[0].get_path_to(close_button)


func _apply_safe_layout() -> void:
	if panel == null:
		return
	var available := size - Vector2(safe_margins.x + safe_margins.z, safe_margins.y + safe_margins.w)
	var fit_scale := minf(1.18, minf(available.x / AUTHORED_SIZE.x, available.y / AUTHORED_SIZE.y))
	panel.size = AUTHORED_SIZE
	panel.scale = Vector2.ONE * maxf(0.48, fit_scale)
	var visual_size := AUTHORED_SIZE * panel.scale
	var safe_rect := Rect2(Vector2(safe_margins.x, safe_margins.y), available)
	var local_avoid := Rect2(avoid_rect.position - global_position, avoid_rect.size)
	var target_area := safe_rect
	if local_avoid.size.x > 1.0 and local_avoid.intersects(safe_rect):
		var right_start := maxf(safe_rect.position.x, local_avoid.end.x + AVOID_GAP)
		var right_area := Rect2(
			Vector2(right_start, safe_rect.position.y),
			Vector2(maxf(0.0, safe_rect.end.x - right_start), safe_rect.size.y)
		)
		if right_area.size.x >= visual_size.x:
			target_area = right_area
	panel.position = target_area.position + Vector2(
		maxf(0.0, (target_area.size.x - visual_size.x) * 0.5),
		maxf(0.0, (target_area.size.y - visual_size.y) * 0.5)
	)


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.27, 0.44, 0.72)
	style.border_color = Color(0.95, 0.99, 1.0, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	style.shadow_color = Color(0.02, 0.13, 0.28, 0.42)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0.0, 10.0)
	style.anti_aliasing = true
	return style


func _button_style(fill: Color, border: Color, border_width: int, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0.01, 0.12, 0.29, 0.27)
	style.shadow_size = 10
	style.shadow_offset = Vector2(3.0, 5.0)
	style.anti_aliasing = true
	return style
