extends Control

class_name WallCountDisc

@export var outer_ring_color: Color = Color(0.67, 0.55, 0.31, 0.96):
	set(value):
		outer_ring_color = value
		queue_redraw()

@export var inner_ring_color: Color = Color(0.18, 0.36, 0.31, 0.98):
	set(value):
		inner_ring_color = value
		queue_redraw()

@export var core_color: Color = Color(0.09, 0.20, 0.17, 0.98):
	set(value):
		core_color = value
		queue_redraw()

@export var shadow_color: Color = Color(0.01, 0.03, 0.03, 0.24):
	set(value):
		shadow_color = value
		queue_redraw()

@export var glow_color: Color = Color(0.36, 0.30, 0.16, 0.08):
	set(value):
		glow_color = value
		queue_redraw()

@export var hotspot_glow_color: Color = Color(0.84, 0.76, 0.48, 0.06):
	set(value):
		hotspot_glow_color = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var center := rect.size * 0.5
	var radius := minf(rect.size.x, rect.size.y) * 0.5 - 5.0
	if radius <= 0.0:
		return

	draw_circle(center + Vector2(0, 5), radius * 1.02, shadow_color)
	_draw_glow_ring(center, radius * 1.26, glow_color, 0.055, 5)
	_draw_glow_ring(center, radius * 1.10, hotspot_glow_color, 0.045, 3)
	draw_circle(center, radius * 1.03, Color(0.03, 0.07, 0.08, 0.22))
	draw_circle(center, radius, outer_ring_color)
	draw_circle(center, radius * 0.95, Color(0.98, 0.95, 0.84, 0.06))
	draw_circle(center + Vector2(0, -0.5), radius * 0.88, inner_ring_color)
	draw_circle(center + Vector2(0, -0.5), radius * 0.71, core_color)
	draw_circle(center + Vector2(0, -1.0), radius * 0.54, core_color.lightened(0.08))

	_draw_arc(center + Vector2(0, -0.5), radius * 0.99, -PI * 0.96, PI * 0.96, Color(0.96, 0.88, 0.62, 0.20), 3.8)
	_draw_arc(center + Vector2(0, -1.0), radius * 0.93, -PI * 0.90, -PI * 0.16, Color(1.0, 0.96, 0.84, 0.18), 2.2)
	_draw_arc(center + Vector2(0, 1.0), radius * 0.84, PI * 0.10, PI * 0.90, Color(0.02, 0.16, 0.12, 0.28), 3.0)
	_draw_arc(center + Vector2(0, -1.0), radius * 0.64, -PI * 0.92, -PI * 0.28, Color(1.0, 0.96, 0.86, 0.08), 1.7)
	_draw_arc(center + Vector2(0, 0.5), radius * 0.68, PI * 0.10, PI * 0.84, Color(0.10, 0.28, 0.22, 0.20), 1.8)

	var gloss := PackedVector2Array([
		center + Vector2(-radius * 0.40, -radius * 0.36),
		center + Vector2(-radius * 0.02, -radius * 0.48),
		center + Vector2(radius * 0.12, -radius * 0.22),
		center + Vector2(-radius * 0.24, -radius * 0.10),
	])
	draw_colored_polygon(gloss, Color(1.0, 0.97, 0.88, 0.08))

	var lower_glow := PackedVector2Array([
		center + Vector2(-radius * 0.30, radius * 0.18),
		center + Vector2(radius * 0.28, radius * 0.14),
		center + Vector2(radius * 0.18, radius * 0.40),
		center + Vector2(-radius * 0.22, radius * 0.38),
	])
	draw_colored_polygon(lower_glow, Color(0.16, 0.34, 0.26, 0.08))


func _draw_arc(center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var angle := lerpf(from_angle, to_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, width, true)


func _draw_glow_ring(center: Vector2, radius: float, color: Color, base_alpha: float, layers: int) -> void:
	for index in range(layers, 0, -1):
		var t := float(index) / float(maxi(1, layers))
		var layer_radius := radius * (0.78 + t * 0.22)
		var layer_alpha := base_alpha * t * t
		draw_circle(center, layer_radius, Color(color.r, color.g, color.b, layer_alpha))
