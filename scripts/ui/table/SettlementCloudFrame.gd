extends Control

class_name SettlementCloudFrame

@export var square_mode := false
@export var dark_fill := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if bounds.size.x < 12 or bounds.size.y < 12:
		return
	var radius := minf(bounds.size.y * 0.28, 22.0)
	draw_style_box(_box(Color.TRANSPARENT, Color("7A4A1E"), 5, radius), bounds)
	draw_style_box(_box(Color.TRANSPARENT, Color("E5C77C"), 3, radius - 3), bounds.grow(-5))
	draw_style_box(_box(Color.TRANSPARENT, Color("9B642A"), 1, radius - 6), bounds.grow(-10))
	var gold := Color("E6C979")
	var deep := Color("86501F")
	var cloud_size := minf(22.0, bounds.size.y * 0.23)
	_draw_corner_cloud(Vector2(bounds.position.x + 7, bounds.position.y + 7), Vector2.ONE, cloud_size, deep, gold)
	_draw_corner_cloud(Vector2(bounds.end.x - 7, bounds.position.y + 7), Vector2(-1, 1), cloud_size, deep, gold)
	_draw_corner_cloud(Vector2(bounds.position.x + 7, bounds.end.y - 7), Vector2(1, -1), cloud_size, deep, gold)
	_draw_corner_cloud(Vector2(bounds.end.x - 7, bounds.end.y - 7), Vector2(-1, -1), cloud_size, deep, gold)
	if not square_mode:
		var center_y := bounds.get_center().y
		var wing := minf(38.0, bounds.size.x * 0.11)
		draw_polyline(PackedVector2Array([Vector2(bounds.position.x + 9, center_y), Vector2(bounds.position.x + wing, center_y - 7), Vector2(bounds.position.x + wing + 12, center_y)]), gold, 3, true)
		draw_polyline(PackedVector2Array([Vector2(bounds.end.x - 9, center_y), Vector2(bounds.end.x - wing, center_y - 7), Vector2(bounds.end.x - wing - 12, center_y)]), gold, 3, true)


func _draw_corner_cloud(origin: Vector2, direction: Vector2, extent: float, deep: Color, gold: Color) -> void:
	# Open ruyi-cloud curls replace the former four closed rings. Keeping the path
	# open and tucked into the corner makes the ornament read as a corner motif.
	var points := PackedVector2Array([
		origin,
		origin + Vector2(0, extent * 0.58) * direction,
		origin + Vector2(extent * 0.24, extent * 0.78) * direction,
		origin + Vector2(extent * 0.48, extent * 0.62) * direction,
		origin + Vector2(extent * 0.42, extent * 0.39) * direction,
		origin + Vector2(extent * 0.68, extent * 0.25) * direction,
		origin + Vector2(extent, extent * 0.25) * direction,
	])
	draw_polyline(points, deep, 6, true)
	draw_polyline(points, gold, 2.5, true)


func _box(fill: Color, border: Color, width: int, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(maxi(1, int(round(radius))))
	style.anti_aliasing = true
	return style
