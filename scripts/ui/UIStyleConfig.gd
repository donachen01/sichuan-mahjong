extends Resource

class_name UIStyleConfig

const NAMEPLATE_FONT_PATH := "res://res/fonts/nameplate_calligraphy.ttf"
const BODY_FONT_PATH := "res://res/fonts/NotoSansCJKsc-Regular.otf"

static var _cached_nameplate_font: Font
static var _cached_body_font: Font

@export var table_bg: Color = Color("052820")
@export var panel_bg: Color = Color(0.035, 0.161, 0.137, 0.94)
@export var panel_bg_emphasized: Color = Color(0.012, 0.094, 0.082, 0.98)
@export var panel_border: Color = Color(0.659, 0.475, 0.227, 0.56)
@export var panel_highlight_border: Color = Color(0.773, 0.604, 0.345, 0.82)
@export var cream_panel_bg: Color = Color(0.039, 0.169, 0.141, 0.97)
@export var cream_panel_border: Color = Color(0.725, 0.588, 0.333, 0.58)
@export var warm_panel_bg: Color = Color(0.129, 0.090, 0.074, 0.98)
@export var warm_panel_border: Color = Color(0.659, 0.475, 0.227, 0.72)
@export var primary_button_bg: Color = Color("0A4A3D")
@export var primary_button_bg_2: Color = Color("0D5A3E")
@export var primary_button_text: Color = Color("F4E9C9")
@export var secondary_button_bg: Color = Color(0.012, 0.094, 0.082, 0.96)
@export var secondary_button_text: Color = Color("F4E9C9")
@export var highlight_fill: Color = Color("B99655")
@export var highlight_stroke: Color = Color("7A522C")
@export var text_primary: Color = Color("F4E9C9")
@export var text_secondary: Color = Color("D8C49A")
@export var text_muted: Color = Color(0.78, 0.81, 0.72, 0.94)
@export var text_outline: Color = Color(0.012, 0.055, 0.047, 0.96)
@export var danger: Color = Color("FF3333")
@export var font_title_size: int = 26
@export var font_body_size: int = 18
@export var font_aux_size: int = 14
@export var corner_radius: int = 6
@export var tile_corner_radius: int = 6


func apply_panel(panel: Panel, emphasized: bool = false) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = panel_bg_emphasized if emphasized else panel_bg
	style.border_color = panel_highlight_border if emphasized else panel_border
	style.set_border_width_all(2 if emphasized else 1)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.shadow_color = Color(0.0, 0.05, 0.03, 0.20)
	style.shadow_size = 5 if emphasized else 3
	style.shadow_offset = Vector2(3, 4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.self_modulate = Color(1.0, 1.0, 1.0, 0.98)


func apply_plate_panel(panel: Panel, warm: bool = false, strong: bool = false) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = warm_panel_bg if warm else cream_panel_bg
	style.border_color = warm_panel_border if warm else cream_panel_border
	style.set_border_width_all(2 if strong else 1)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 9
	style.shadow_color = Color(0.05, 0.20, 0.11, 0.18)
	style.shadow_size = 5 if strong else 3
	style.shadow_offset = Vector2(3, 4)
	panel.add_theme_stylebox_override("panel", style)
	panel.self_modulate = Color(1.0, 1.0, 1.0, 0.99)


func apply_clear_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	panel.add_theme_stylebox_override("panel", style)
	panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func apply_tabletop_zone_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)
	panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)


func panel_is_tabletop_zone(panel: Panel) -> bool:
	if panel == null:
		return false
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return false
	return (
		style.bg_color.a <= 0.01
		and style.border_color.a <= 0.01
		and style.get_border_width(SIDE_LEFT) == 0
		and style.get_border_width(SIDE_TOP) == 0
		and style.get_border_width(SIDE_RIGHT) == 0
		and style.get_border_width(SIDE_BOTTOM) == 0
		and style.shadow_size == 0
	)


func apply_label(label: Control, use_aux: bool = false, large: bool = false) -> void:
	if label == null:
		return
	var target_size := font_title_size if large else (font_aux_size if use_aux else font_body_size)
	var target_color := text_muted if use_aux else text_primary
	if label is Label:
		var typed := label as Label
		typed.add_theme_color_override("font_color", target_color)
		typed.add_theme_color_override("font_outline_color", text_outline)
		typed.add_theme_constant_override("outline_size", 2 if large else 1)
		typed.add_theme_font_size_override("font_size", target_size)
		typed.add_theme_font_override("font", _display_font() if large else _body_font())
	elif label is Button:
		var button := label as Button
		button.add_theme_color_override("font_color", target_color)
		button.add_theme_color_override("font_outline_color", text_outline)
		button.add_theme_constant_override("outline_size", 2 if large else 1)
		button.add_theme_font_size_override("font_size", target_size)
		button.add_theme_font_override("font", _display_font() if large else _body_font())


func apply_font_tree(root: Node) -> void:
	if root == null:
		return
	_apply_font_to_node(root)
	for child in root.get_children():
		apply_font_tree(child)


func ui_font() -> Font:
	return _body_font()


func apply_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = primary_button_bg_2 if primary else secondary_button_bg
	normal.border_color = Color("C59A58") if primary else Color(0.659, 0.475, 0.227, 0.70)
	normal.set_border_width_all(2 if primary else 1)
	normal.corner_radius_top_left = corner_radius
	normal.corner_radius_top_right = corner_radius
	normal.corner_radius_bottom_left = corner_radius
	normal.corner_radius_bottom_right = corner_radius
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 11
	normal.content_margin_bottom = 11
	normal.shadow_color = Color(0.0, 0.015, 0.010, 0.42)
	normal.shadow_size = 4 if primary else 2
	normal.shadow_offset = Vector2(4, 5)

	var hover := normal.duplicate()
	hover.bg_color = Color(primary_button_bg if primary else secondary_button_bg.lightened(0.08), normal.bg_color.a)
	hover.shadow_size = normal.shadow_size + 3

	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(2, 2)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", primary_button_text if primary else secondary_button_text)
	button.add_theme_color_override("font_outline_color", text_outline)
	button.add_theme_constant_override("outline_size", 2 if primary else 1)
	button.add_theme_font_size_override("font_size", font_body_size)
	button.add_theme_font_override("font", _body_font())


func _display_font() -> Font:
	if _cached_nameplate_font != null:
		return _cached_nameplate_font
	if ResourceLoader.exists(NAMEPLATE_FONT_PATH):
		var loaded := ResourceLoader.load(NAMEPLATE_FONT_PATH)
		if loaded is Font:
			_cached_nameplate_font = loaded
			return _cached_nameplate_font
	return _body_font()


func _body_font() -> Font:
	if _cached_body_font != null:
		return _cached_body_font
	if ResourceLoader.exists(BODY_FONT_PATH):
		var loaded := ResourceLoader.load(BODY_FONT_PATH)
		if loaded is Font:
			_cached_body_font = loaded
			return _cached_body_font
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC",
		"Hiragino Sans GB",
		"Microsoft YaHei",
		"Noto Sans CJK SC",
		"Source Han Sans SC",
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	_cached_body_font = font
	return _cached_body_font


func _apply_font_to_node(node: Node) -> void:
	var font := _body_font()
	if node is Label:
		(node as Label).add_theme_font_override("font", font)
	elif node is Button:
		(node as Button).add_theme_font_override("font", font)
	elif node is RichTextLabel:
		var rich_label := node as RichTextLabel
		rich_label.add_theme_font_override("normal_font", font)
		rich_label.add_theme_font_override("bold_font", font)
		rich_label.add_theme_font_override("italics_font", font)
		rich_label.add_theme_font_override("bold_italics_font", font)
	elif node is LineEdit:
		(node as LineEdit).add_theme_font_override("font", font)
	elif node is TextEdit:
		(node as TextEdit).add_theme_font_override("font", font)
