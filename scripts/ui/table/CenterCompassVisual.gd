class_name CenterCompassVisual
extends Control

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const ACTIVE_STATE_COLOR_HEX := "A13D2D"

var active_seat := -1
var reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func configure(seat: int, reduce_motion: bool = false) -> void:
	active_seat = seat if seat >= 0 and seat < 4 else -1
	reduced_motion = reduce_motion
	queue_redraw()


func get_visual_contract() -> Dictionary:
	return {
		"form": "reference_four_way_turn_panel",
		"asset": "two_dimensional_fallback_for_blender_instrument",
		"active_encoding": ["opaque_vivid_red_main_field_and_both_chamfer_fills", "warm_ivory_direction_glyph_with_dark_outline"],
		"active_color_hex": ACTIVE_STATE_COLOR_HEX,
		"center_material": "gloss_smoked_jade_glass_with_clean_outer_edges_and_central_antique_bronze_counter",
		"shape": "flush_chamfered_glass_inlay_with_circular_counter",
		"direction_labels": ["东", "南", "西", "北"],
		"motion": "static_when_reduced_motion",
		"motion_safe": true,
	}


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	# Compatibility fallback mirrors the calm physical 3D panel without adding
	# back the permanent sector seams, coloured side rails or stacked metal bands
	# removed from the main model.
	var center := size * 0.5
	var panel_size := Vector2(minf(size.x * 0.86, size.y * 1.05), size.y * 0.74)
	var panel_rect := Rect2(center - panel_size * 0.5, panel_size)
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("0A3A31")
	shell.set_border_width_all(0)
	shell.corner_radius_top_left = 20
	shell.corner_radius_top_right = 20
	shell.corner_radius_bottom_left = 20
	shell.corner_radius_bottom_right = 20
	draw_style_box(shell, panel_rect)
	var inner := panel_rect.grow(-8.0)
	var dark_face := StyleBoxFlat.new()
	dark_face.bg_color = Color(0.04, 0.20, 0.17, 0.90)
	dark_face.corner_radius_top_left = 14
	dark_face.corner_radius_top_right = 14
	dark_face.corner_radius_bottom_left = 14
	dark_face.corner_radius_bottom_right = 14
	draw_style_box(dark_face, inner)
	var inner_center := inner.get_center()
	var ring_radius := minf(inner.size.x, inner.size.y) * 0.25
	var active_segment := -1
	if active_seat >= 0:
		active_segment = int([2, 3, 0, 1][active_seat])
	var segments: Array[PackedVector2Array] = [
		PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner_center + Vector2(ring_radius, -ring_radius * 0.40), inner_center + Vector2(-ring_radius, -ring_radius * 0.40)]),
		PackedVector2Array([Vector2(inner.end.x, inner.position.y), inner.end, inner_center + Vector2(ring_radius, ring_radius * 0.40), inner_center + Vector2(ring_radius, -ring_radius * 0.40)]),
		PackedVector2Array([Vector2(inner.position.x, inner.end.y), inner.end, inner_center + Vector2(ring_radius, ring_radius * 0.40), inner_center + Vector2(-ring_radius, ring_radius * 0.40)]),
		PackedVector2Array([inner.position, inner_center + Vector2(-ring_radius, -ring_radius * 0.40), inner_center + Vector2(-ring_radius, ring_radius * 0.40), Vector2(inner.position.x, inner.end.y)]),
	]
	if active_segment >= 0:
		draw_colored_polygon(segments[active_segment], Color(ACTIVE_STATE_COLOR_HEX))
	draw_circle(inner_center, ring_radius * 1.12, Color("9D7947"))
	draw_circle(inner_center, ring_radius, Color("0A3A31"))
	draw_line(inner.position + Vector2(18.0, 6.0), Vector2(inner.end.x - 18.0, inner.position.y + 6.0), Color(0.82, 1.0, 0.95, 0.32), 2.0, true)
