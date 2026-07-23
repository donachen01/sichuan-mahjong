class_name CenterCompassVisual
extends Control

# 旧版中央余牌牌匾的程序化复刻：深青黑底、暗金双线、克制切角。
# 方向和回合只由下方状态文字表达，不再绘制东南西北、彩色角块或放射分区。

var active_seat := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)
	queue_redraw()


func configure(seat: int, _reduce_motion: bool = false) -> void:
	active_seat = clampi(seat, 0, 3)
	queue_redraw()


func get_visual_contract() -> Dictionary:
	return {
		"form": "dark_cut_corner_remaining_plaque",
		"active_encoding": ["status_text"],
		"center_material": "deep_teal_black",
		"radial_divisions": 0,
		"corner_accents": 0,
		"direction_labels": "none",
		"border_lines": 2,
		"motion": "static",
		"motion_safe": true,
	}


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var cut := radius * 0.115

	# 右下接触影只负责把牌匾压在桌面上，不制造发光或浮夸光晕。
	var shadow := _cut_corner_points(center + Vector2(4.0, 6.0), radius, cut)
	draw_colored_polygon(shadow, Color(0.01, 0.025, 0.026, 0.44))

	var outer := _cut_corner_points(center, radius, cut)
	draw_colored_polygon(outer, Color("8E6731"))

	var outer_inset := _cut_corner_points(center, radius - 3.0, maxf(2.0, cut - 1.0))
	draw_colored_polygon(outer_inset, Color("071F1B"))

	var middle := _cut_corner_points(center, radius - 7.0, maxf(2.0, cut - 2.0))
	_draw_outline(middle, Color("BC8D48"), 1.8)

	var inner := _cut_corner_points(center, radius - 12.0, maxf(2.0, cut - 3.0))
	draw_colored_polygon(inner, Color("031512"))
	_draw_outline(inner, Color(0.38, 0.27, 0.13, 0.78), 1.1)

	# 左上极轻玉色反光，保持旧面板的厚度和统一光源方向。
	var highlight := PackedVector2Array([
		outer[0] + Vector2(3.0, 4.0),
		outer[1] + Vector2(-2.0, 4.0),
		outer[1] + Vector2(-2.0, 5.8),
		outer[0] + Vector2(3.0, 5.8),
	])
	draw_colored_polygon(highlight, Color(0.96, 0.78, 0.42, 0.22))


func _cut_corner_points(center: Vector2, radius: float, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-radius + cut, -radius),
		center + Vector2(radius - cut, -radius),
		center + Vector2(radius, -radius + cut),
		center + Vector2(radius, radius - cut),
		center + Vector2(radius - cut, radius),
		center + Vector2(-radius + cut, radius),
		center + Vector2(-radius, radius - cut),
		center + Vector2(-radius, -radius + cut),
	])


func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)
