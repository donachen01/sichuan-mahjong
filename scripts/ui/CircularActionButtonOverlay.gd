extends Control

class_name CircularActionButtonOverlay

const ACTION_LABEL_FONT := preload("res://res/fonts/nameplate_calligraphy.ttf")
const TEXT_FILL := Color(1.0, 1.0, 1.0, 1.0)

# Kept as a fixed phase so the existing highlight placement is unchanged.
# This overlay is intentionally event-driven and no longer animates every frame.
var phase := 0.0

@export var primary: bool = true:
	set(value):
		primary = value
		queue_redraw()

@export var center_color: Color = Color("FFF176"):
	set(value):
		center_color = value
		queue_redraw()

@export var edge_color: Color = Color("FF8F00"):
	set(value):
		edge_color = value
		queue_redraw()

@export var outline_color: Color = Color("FFD54F"):
	set(value):
		outline_color = value
		queue_redraw()

@export var label_text: String = "":
	set(value):
		label_text = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The former per-frame redraw advanced an unused phase value while rebuilding
	# dozens of circles/arcs every frame. The visual is static; property setters
	# and button state changes are the only reasons it needs another draw.
	set_process(false)
	var button := get_parent() as BaseButton
	if button != null:
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)
		button.toggled.connect(func(_pressed: bool) -> void: queue_redraw())


func _draw() -> void:
	if size.x <= 12.0 or size.y <= 12.0:
		return
	var diameter := minf(size.x, size.y) - 10.0
	if diameter <= 8.0:
		return
	var radius := diameter * 0.5
	var center := size * 0.5
	var pressed_offset := 1.5 if _is_pressed() else 0.0
	center.y += pressed_offset
	_draw_drop_shadow(center, radius)
	_draw_radial_button(center, radius)
	_draw_outline(center, radius)
	_draw_highlight(center, radius)
	_draw_inner_bevel(center, radius)
	_draw_embossed_label(center, radius)


func _is_pressed() -> bool:
	var parent_button := get_parent() as Button
	return parent_button != null and parent_button.button_pressed


func _is_hovered() -> bool:
	var parent_control := get_parent() as Control
	return parent_control != null and parent_control.get_global_rect().has_point(parent_control.get_global_mouse_position())


func _draw_drop_shadow(center: Vector2, radius: float) -> void:
	var shadow_alpha := 0.30 if primary else 0.22
	var shadow_center := center + Vector2(0.0, radius * 0.12)
	for index in range(7):
		var t := float(index) / 6.0
		var shadow_radius := Vector2(radius * (0.86 + t * 0.18), radius * (0.30 + t * 0.09))
		var color := Color(0.0, 0.0, 0.0, shadow_alpha * (1.0 - t) * 0.42)
		_draw_filled_ellipse(shadow_center + Vector2(0.0, t * 2.0), shadow_radius, color, 48)


func _draw_radial_button(center: Vector2, radius: float) -> void:
	var rings := 38
	var hover_lift := 0.08 if _is_hovered() else 0.0
	var pressed_dim := 0.10 if _is_pressed() else 0.0
	for index in range(rings, 0, -1):
		var t := float(index) / float(rings)
		var blend := pow(t, 0.74)
		var color := center_color.lerp(edge_color, blend)
		color = color.lightened(hover_lift).darkened(pressed_dim)
		draw_circle(center, radius * t, color)


func _draw_outline(center: Vector2, radius: float) -> void:
	var width := 2.0 if primary else 1.5
	var hover_bonus := 0.18 if _is_hovered() else 0.0
	for index in range(4):
		var alpha := (0.22 + hover_bonus) / float(index + 1)
		draw_arc(center, radius + float(index) * 1.2, 0.0, TAU, 96, Color(outline_color.r, outline_color.g, outline_color.b, alpha), width + float(index), true)
	draw_arc(center, radius, 0.0, TAU, 128, Color(outline_color.r, outline_color.g, outline_color.b, 1.0), width, true)


func _draw_highlight(center: Vector2, radius: float) -> void:
	var highlight_alpha := 0.30 if primary else 0.24
	if _is_pressed():
		highlight_alpha *= 0.62
	var top_center := center + Vector2(-radius * 0.08, -radius * 0.10)
	var arc_color := Color(1.0, 1.0, 1.0, highlight_alpha)
	var glow_color := Color(1.0, 1.0, 1.0, highlight_alpha * 0.26)
	draw_arc(top_center, radius * 0.70, PI * 1.10, PI * 1.86, 80, glow_color, 7.0, true)
	draw_arc(top_center, radius * 0.70, PI * 1.10, PI * 1.86, 80, arc_color, 2.2, true)
	draw_arc(center + Vector2(-radius * 0.08, -radius * 0.02), radius * 0.56, PI * 1.08, PI * 1.76, 72, Color(1.0, 1.0, 1.0, highlight_alpha * 0.16), 1.4, true)
	var glint_start := center + Vector2(-radius * 0.48, -radius * 0.50)
	var glint_end := center + Vector2(-radius * 0.24, -radius * 0.57)
	draw_line(glint_start, glint_end, Color(1.0, 1.0, 1.0, highlight_alpha * 0.88), 2.4, true)
	draw_circle(center + Vector2(-radius * 0.40, -radius * 0.42), radius * 0.045, Color(1.0, 1.0, 1.0, highlight_alpha * 0.55))


func _draw_inner_bevel(center: Vector2, radius: float) -> void:
	var top_color := Color(1.0, 1.0, 1.0, 0.16 if primary else 0.12)
	var bottom_color := Color(0.20, 0.08, 0.0, 0.14) if primary else Color(0.0, 0.14, 0.04, 0.13)
	draw_arc(center + Vector2(0.0, -1.0), radius * 0.78, PI * 1.04, PI * 1.96, 72, top_color, 1.2, true)
	draw_arc(center + Vector2(0.0, 1.0), radius * 0.78, 0.10, PI * 0.90, 72, bottom_color, 1.4, true)
	var glint_x := center.x - radius * 0.10 + sin(phase * TAU) * radius * 0.08
	draw_line(Vector2(glint_x - radius * 0.18, center.y - radius * 0.66), Vector2(glint_x + radius * 0.18, center.y - radius * 0.66), Color(1.0, 1.0, 1.0, 0.16), 1.0, true)


func _draw_embossed_label(center: Vector2, radius: float) -> void:
	var text := label_text.strip_edges()
	if text.is_empty():
		return
	var font := ACTION_LABEL_FONT
	var target_height := radius * 2.0 * 0.72
	var font_size := int(round(target_height))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	if text_size.x > radius * 2.0 * 0.78 and text_size.x > 0.0:
		font_size = int(round(float(font_size) * ((radius * 2.0 * 0.78) / text_size.x)))
		text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var secondary_offset := Vector2(-radius * 0.050, radius * 0.065) if not primary else Vector2.ZERO
	var baseline_y := center.y + secondary_offset.y + (ascent - descent) * 0.5 - radius * 0.03
	var base_pos := Vector2(
		center.x + secondary_offset.x - text_size.x * 0.5,
		baseline_y
	)
	var inner_shadow := Color(0.0, 0.0, 0.0, 0.20)
	var outer_glow := Color(1.0, 1.0, 1.0, 0.30 if primary else 0.25)
	var dark_bevel := Color(0.16, 0.07, 0.01, 0.62) if primary else Color(0.02, 0.14, 0.04, 0.58)
	draw_string(font, base_pos + Vector2(0.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, inner_shadow)
	draw_string(font, base_pos + Vector2(0.0, -1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outer_glow)
	draw_string(font, base_pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, dark_bevel)
	draw_string(font, base_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_FILL)


func _draw_filled_ellipse(center: Vector2, ellipse_radius: Vector2, color: Color, segments: int) -> void:
	if ellipse_radius.x <= 0.0 or ellipse_radius.y <= 0.0:
		return
	var points := PackedVector2Array()
	points.append(center)
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * ellipse_radius.x, sin(angle) * ellipse_radius.y))
	draw_colored_polygon(points, color)
