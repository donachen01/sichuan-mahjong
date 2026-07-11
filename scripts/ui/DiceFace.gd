extends Control

class_name DiceFace

@export_range(1, 6) var value: int = 1:
	set(new_value):
		value = clampi(new_value, 1, 6)
		queue_redraw()

@export var pip_color: Color = Color(0.18, 0.14, 0.10, 1.0):
	set(new_value):
		pip_color = new_value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var shadow_rect := rect.grow(-4)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.18), true)

	var main_rect := rect.grow(-6)
	draw_style_box(_build_face_style(Color(0.95, 0.88, 0.63, 1.0), Color(0.55, 0.38, 0.14, 0.82)), main_rect)
	var inner_rect := Rect2(main_rect.position + Vector2(2, 2), main_rect.size - Vector2(4, 4))
	draw_style_box(_build_face_style(Color(1.0, 0.95, 0.78, 0.94), Color(1.0, 0.98, 0.90, 0.55)), inner_rect)

	for pip_position in _pip_positions_for_value(value):
		draw_circle(_map_pip_point(inner_rect, pip_position), inner_rect.size.x * 0.08, pip_color)


func _build_face_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style


func _map_pip_point(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		rect.position.x + rect.size.x * point.x,
		rect.position.y + rect.size.y * point.y
	)


func _pip_positions_for_value(face_value: int) -> Array[Vector2]:
	var left := 0.28
	var center := 0.5
	var right := 0.72
	var top := 0.28
	var middle := 0.5
	var bottom := 0.72
	match face_value:
		1:
			return [Vector2(center, middle)]
		2:
			return [Vector2(left, top), Vector2(right, bottom)]
		3:
			return [Vector2(left, top), Vector2(center, middle), Vector2(right, bottom)]
		4:
			return [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]
		5:
			return [
				Vector2(left, top),
				Vector2(right, top),
				Vector2(center, middle),
				Vector2(left, bottom),
				Vector2(right, bottom),
			]
		6:
			return [
				Vector2(left, top),
				Vector2(right, top),
				Vector2(left, middle),
				Vector2(right, middle),
				Vector2(left, bottom),
				Vector2(right, bottom),
			]
		_:
			return [Vector2(center, middle)]
