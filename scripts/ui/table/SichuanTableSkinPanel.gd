class_name SichuanTableSkinPanel
extends Control

signal skin_selected(skin_id: String)
signal closed

const CATALOG := preload("res://scripts/ui/table/SichuanTableSkinCatalog.gd")
const BODY_FONT := preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
const CARD_SIZE := Vector2(420.0, 176.0)
const AUTHORED_SIZE := Vector2(940.0, 752.0)
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
	z_index = 320
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
	safe_margins = value
	_apply_safe_layout()


func set_avoid_rect(value: Rect2) -> void:
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
	shade.color = Color(0.008, 0.020, 0.018, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
	add_child(shade)

	panel = PanelContainer.new()
	panel.name = "TableSkinChooser"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
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
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color("FFF1CF"))
	header.add_child(title_label)
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(132.0, 68.0)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_override("font", BODY_FONT)
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.add_theme_stylebox_override("normal", _button_style(Color("173D31"), Color("B88943"), 1))
	close_button.add_theme_stylebox_override("hover", _button_style(Color("245A42"), Color("E2BC6A"), 2))
	close_button.add_theme_stylebox_override("pressed", _button_style(Color("102E27"), Color("E2BC6A"), 2))
	close_button.add_theme_stylebox_override("focus", _button_style(Color("245A42"), Color("FFE29A"), 3))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var description := Label.new()
	description.text = "六套 Poly Haven 实体布料材质，只改变桌布外观，不改变麻将玩法与操作。"
	description.add_theme_font_override("font", BODY_FONT)
	description.add_theme_font_size_override("font_size", 24)
	description.add_theme_color_override("font_color", Color("D8CFB7"))
	column.add_child(description)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
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
	button.text = "%s\n%s" % [str(skin.get("name", skin_id)), str(skin.get("subtitle", ""))]
	button.icon = ResourceLoader.load(CATALOG.texture_path(skin_id, "preview.jpg")) as Texture2D
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 29)
	button.add_theme_color_override("font_color", Color("F4E9D0"))
	button.add_theme_color_override("font_hover_color", Color("FFF4D8"))
	button.add_theme_color_override("font_pressed_color", Color("FFF4D8"))
	button.add_theme_constant_override("icon_separation", 22)
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
			Color("245A42") if active else Color("102F29"),
			Color("F1C968") if active else Color("5D7B65"),
			3 if active else 1,
			14
		))
		button.add_theme_stylebox_override("hover", _button_style(Color("286A4C"), Color("F1C968"), 2, 14))
		button.add_theme_stylebox_override("pressed", _button_style(Color("153F33"), Color("FFE29A"), 3, 14))
		button.add_theme_stylebox_override("focus", _button_style(Color("286A4C"), Color("FFF0A5"), 4, 14))
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
		var sibling_index := row * 2 + (1 - column)
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
	var fit_scale := minf(1.0, minf(available.x / AUTHORED_SIZE.x, available.y / AUTHORED_SIZE.y))
	panel.size = AUTHORED_SIZE
	panel.scale = Vector2.ONE * maxf(0.58, fit_scale)
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
	style.bg_color = Color("0B2823")
	style.border_color = Color("C79A45")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 7.0)
	return style


func _button_style(fill: Color, border: Color, border_width: int, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10)
	return style
