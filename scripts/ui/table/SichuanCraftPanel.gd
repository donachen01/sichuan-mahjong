class_name SichuanCraftPanel
extends Control

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")

@export_enum("hud", "center", "action") var variant := "hud":
	set(value):
		variant = value
		queue_redraw()
@export var cut_size := 14.0:
	set(value):
		cut_size = maxf(4.0, value)
		queue_redraw()

var active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	queue_redraw()


func get_visual_contract() -> Dictionary:
	return {
		"shape_motif": "shu_courtyard_cut_corner",
		"material_family": _material_family(),
		"active_treatment": "copper_edge_light",
		"cut_corners": ["top_right", "bottom_left"],
	}


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var outer_rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	var shadow_points := _shape_points(outer_rect, cut_size)
	for index in range(shadow_points.size()):
		shadow_points[index] += Vector2(4.0, 6.0)
	draw_colored_polygon(shadow_points, Color(0.0, 0.010, 0.008, 0.48))

	var outer_points := _shape_points(outer_rect, cut_size)
	draw_colored_polygon(outer_points, _border_color())
	var body_rect := outer_rect.grow(-3.5)
	var body_points := _shape_points(body_rect, maxf(3.0, cut_size - 3.0))
	draw_colored_polygon(body_points, _fill_color())

	var upper_points := PackedVector2Array([
		body_points[0] + Vector2(2.0, 2.0),
		body_points[1] + Vector2(-1.0, 2.0),
		body_points[2] + Vector2(-2.0, 3.0),
	])
	draw_polyline(upper_points, Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.58), 1.4, true)

	var inner_rect := outer_rect.grow(-7.0)
	if inner_rect.size.x > 14.0 and inner_rect.size.y > 14.0:
		_draw_outline(_shape_points(inner_rect, maxf(3.0, cut_size - 5.0)), Color(TABLE_THEME.COPPER_SHADOW, 0.64), 1.1)

	# Two small stepped brackets make the silhouette read as carved Shu lacquer
	# furniture instead of a generic rounded rectangle.
	var bracket_color := Color(TABLE_THEME.COPPER_MID, 0.62)
	draw_polyline(PackedVector2Array([
		Vector2(8.0, 18.0), Vector2(8.0, 8.0), Vector2(24.0, 8.0),
		Vector2(28.0, 4.0), Vector2(42.0, 4.0),
	]), bracket_color, 1.6, true)
	draw_polyline(PackedVector2Array([
		Vector2(size.x - 8.0, size.y - 18.0), Vector2(size.x - 8.0, size.y - 8.0),
		Vector2(size.x - 24.0, size.y - 8.0), Vector2(size.x - 28.0, size.y - 4.0),
		Vector2(size.x - 42.0, size.y - 4.0),
	]), bracket_color, 1.6, true)

	if active:
		var light_height := maxf(14.0, size.y - cut_size * 1.5)
		var light_x := 3.5
		draw_line(
			Vector2(light_x, (size.y - light_height) * 0.5),
			Vector2(light_x, (size.y + light_height) * 0.5),
			Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.92),
			3.0,
			true
		)


func _shape_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var minor := minf(6.0, cut * 0.42)
	var safe_cut := minf(cut, minf(rect.size.x, rect.size.y) * 0.28)
	return PackedVector2Array([
		Vector2(rect.position.x + minor, rect.position.y),
		Vector2(rect.end.x - safe_cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + safe_cut),
		Vector2(rect.end.x, rect.end.y - minor),
		Vector2(rect.end.x - minor, rect.end.y),
		Vector2(rect.position.x + safe_cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - safe_cut),
		Vector2(rect.position.x, rect.position.y + minor),
	])


func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _fill_color() -> Color:
	match variant:
		"center":
			return Color("031815", 0.975)
		"action":
			return Color("031815", 0.975)
		_:
			# HUD nameplates are translucent smoked jade glass. Keep the center and
			# action panels opaque because they carry gameplay-critical controls.
			return Color(TABLE_THEME.PANEL_JADE_BLACK, 0.34)


func _border_color() -> Color:
	var alpha := 0.94 if variant == "center" else 0.86
	if active:
		alpha = 0.94
	return Color(TABLE_THEME.AGED_COPPER, alpha * 0.92)


func _material_family() -> String:
	match variant:
		"center":
			return "ink_jade_direction_compass"
		"action":
			return "ebony_lacquer_decision_group"
		_:
			return "ebony_lacquer_cut_corner_nameplate"
