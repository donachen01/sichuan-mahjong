class_name CenterCompassVisual
extends Control

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")

var active_seat := 0
var reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func configure(seat: int, reduce_motion: bool = false) -> void:
	active_seat = clampi(seat, 0, 3)
	reduced_motion = reduce_motion
	queue_redraw()


func get_visual_contract() -> Dictionary:
	return {
		"form": "blender_pbr_low_profile_four_way_compass",
		"asset": "res://res/art/3d/sichuan_center_compass_v2.glb",
		"active_encoding": ["direction_text", "copper_wedge_light"],
		"center_material": "physical_pbr_asset_below_control_overlay",
		"radial_divisions": 4,
		"direction_labels": "live_godot_text",
		"motion": "static_when_reduced_motion",
		"motion_safe": true,
	}


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	# The physical jade/walnut/copper body comes from Blender. This transparent
	# Control paints only the current-seat light so the PBR asset stays visible.
	var center := size * 0.5
	var inner_radius := minf(size.x, size.y) * 0.18
	var outer_radius := minf(size.x, size.y) * 0.37
	var angle: float = [PI * 0.5, PI, -PI * 0.5, 0.0][active_seat]
	var spread := 0.48
	var points := PackedVector2Array([
		center + Vector2(cos(angle - spread), sin(angle - spread)) * inner_radius,
		center + Vector2(cos(angle - spread * 0.62), sin(angle - spread * 0.62)) * outer_radius,
		center + Vector2(cos(angle + spread * 0.62), sin(angle + spread * 0.62)) * outer_radius,
		center + Vector2(cos(angle + spread), sin(angle + spread)) * inner_radius,
	])
	draw_colored_polygon(points, Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.23))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.72), 1.8, true)
