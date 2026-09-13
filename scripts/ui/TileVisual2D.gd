extends Control

class_name TileVisual2D

const TILE_STYLE := preload("res://scripts/ui/table/SichuanTileStyle.gd")

const BASE_SIZE := Vector2(92.0, 140.0)
const BASE_TOP_SKEW := Vector2(3.0, -5.0)
const BASE_FRONT_INSET := Vector2(6.0, 5.8)
const BASE_SHADOW_OFFSET := Vector2(0.0, 4.0)
const SUIT_TEXTURE_Y_OFFSETS := {
	"wan": 0.0,
	"tiao": -1.0,
	"tong": -1.0,
}
const FACE_COLOR := TILE_STYLE.FACE_TOP
const FACE_BACK_COLOR := TILE_STYLE.BACK_TOP
const BORDER_COLOR := TILE_STYLE.FACE_BORDER
const BACK_BORDER_COLOR := TILE_STYLE.BACK_BORDER
const SHADOW_COLOR := TILE_STYLE.CONTACT_SHADOW
const BACK_SHADOW_COLOR := TILE_STYLE.CONTACT_SHADOW
const FACE_INNER_RIM := Color(0.94, 1.0, 0.96, 0.24)
const FACE_INNER_LIGHT := Color(1.0, 1.0, 1.0, 0.22)
const FACE_RIGHT_GLAZE := Color(0.10, 0.24, 0.17, 0.12)
const BACK_INNER_RIM := Color(0.82, 0.94, 0.84, 0.20)
const BACK_INNER_LIGHT := Color(1.0, 1.0, 1.0, 0.11)
const TILE_CORNER_RADIUS := 10
const TILE_FACE_SURFACE_PATH := "res://res/art/ui_3d_cartoon/tile_face_table.png"
const TILE_BACK_SURFACE_PATH := "res://res/art/ui_3d_cartoon/tile_back_table.png"
const TILE_SYMBOL_DIR := "res://res/art/ui_3d_cartoon/tile_symbols"
const HIGHLIGHT_COLOR := Color8(63, 134, 104, 235)
const SELECT_COLOR := Color8(168, 121, 58, 235)
const RECENT_DISCARD_PULSE_SPEED := 0.0048
const RECENT_DISCARD_PULSE_RANGE := 0.018
const INNER_BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const INNER_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.0)

var tile_data: Dictionary = {}
var tile_scale: float = 1.0
var show_back: bool = false
var is_new_draw: bool = false
var is_selected: bool = false
var is_recent_discard: bool = false
var is_winning: bool = false
var reduced_motion := false
var settlement_display := false

static var texture_cache: Dictionary = {}
static var face_stylebox: StyleBoxFlat = _build_face_stylebox()
static var back_stylebox: StyleBoxFlat = _build_back_stylebox()


func configure(tile: Dictionary, scale_factor: float, should_show_back: bool = false, highlight_new_draw: bool = false, highlight_selected: bool = false, highlight_recent_discard: bool = false, highlight_winning: bool = false) -> void:
	tile_data = tile
	tile_scale = scale_factor
	show_back = should_show_back
	is_new_draw = highlight_new_draw
	is_selected = highlight_selected
	is_recent_discard = highlight_recent_discard
	is_winning = highlight_winning
	custom_minimum_size = _visual_size()
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2.ONE * (1.05 if is_selected else 1.0)
	set_process(is_recent_discard)
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if reduced_motion:
		scale = Vector2.ONE * (1.05 if is_selected else 1.0)
	set_process(is_recent_discard and not reduced_motion)
	queue_redraw()


func set_settlement_display(enabled: bool) -> void:
	settlement_display = enabled
	queue_redraw()


func _process(_delta: float) -> void:
	if is_recent_discard and not reduced_motion:
		var pulse_phase := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * RECENT_DISCARD_PULSE_SPEED)
		var pulse_scale := 1.0 + pulse_phase * RECENT_DISCARD_PULSE_RANGE
		scale = Vector2.ONE * (1.05 if is_selected else 1.0) * pulse_scale
		queue_redraw()
	else:
		scale = Vector2.ONE * (1.05 if is_selected else 1.0)


func _draw() -> void:
	var front_rect: Rect2 = Rect2(Vector2(0.0, _top_skew().y * -1.0), _face_size())
	var top_points: PackedVector2Array = PackedVector2Array([
		Vector2(front_rect.position.x, front_rect.position.y),
		Vector2(front_rect.end.x, front_rect.position.y),
		Vector2(front_rect.end.x, front_rect.position.y) + _top_skew(),
		Vector2(front_rect.position.x, front_rect.position.y) + _top_skew(),
	])
	var outer_rect: Rect2 = front_rect.expand(top_points[2]).expand(top_points[3])

	var contract := get_visual_contract()
	var shadow_rect: Rect2 = contract["shadow_rect"]
	_draw_contact_shadow(shadow_rect)
	_draw_tile_body_depth(front_rect)
	var surface_texture := _load_tile_surface(show_back)
	if surface_texture != null:
		var surface_rect := front_rect.grow_individual(0.8 * tile_scale, 0.4 * tile_scale, 0.8 * tile_scale, 1.4 * tile_scale)
		draw_texture_rect(surface_texture, surface_rect, false)
		_draw_inset_face_rim(front_rect)
	else:
		draw_style_box(back_stylebox if show_back else face_stylebox, front_rect)
	_draw_face_material(front_rect)
	_draw_inset_face_rim(front_rect)

	var texture: Texture2D = _resolve_texture()
	if texture != null and not show_back:
		var texture_rect := _texture_rect(front_rect)
		draw_texture_rect(texture, texture_rect, false)

	if show_back and surface_texture == null:
		_draw_back_pattern(front_rect)
	elif show_back:
		_draw_back_depth_accents(front_rect)

	if is_selected:
		draw_rect(outer_rect.grow(2.0 * tile_scale), SELECT_COLOR, false, maxf(2.0, 2.0 * tile_scale))
	if is_new_draw:
		draw_rect(outer_rect.grow(2.0 * tile_scale), HIGHLIGHT_COLOR, false, maxf(2.0, 2.0 * tile_scale))
	if is_winning:
		_draw_winning_accent(front_rect, outer_rect)
	if is_recent_discard:
		var blink_phase := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 120.0)
		_draw_recent_discard_accent(outer_rect, blink_phase)


func get_visual_contract() -> Dictionary:
	var front_rect := Rect2(Vector2(0.0, _top_skew().y * -1.0), _face_size())
	var depth := _body_depth()
	var side_rect := Rect2(
		Vector2(front_rect.end.x - 1.0 * tile_scale, front_rect.position.y + 2.0 * tile_scale),
		Vector2(depth.x + 1.0 * tile_scale, front_rect.size.y + depth.y - 2.0 * tile_scale)
	)
	var bottom_rect := Rect2(
		Vector2(front_rect.position.x + 2.0 * tile_scale, front_rect.end.y - 1.0 * tile_scale),
		Vector2(front_rect.size.x + depth.x - 2.0 * tile_scale, depth.y + 1.0 * tile_scale)
	)
	var shadow_rect := front_rect
	shadow_rect.position += Vector2(2.0, 6.0) * tile_scale
	shadow_rect.size += Vector2(depth.x + 5.0 * tile_scale, depth.y + 4.0 * tile_scale)
	var bevel_top_rect := Rect2(
		front_rect.position + Vector2(5.0, 3.0) * tile_scale,
		Vector2(front_rect.size.x - 10.0 * tile_scale, maxf(1.0, 3.2 * tile_scale))
	)
	var bevel_left_rect := Rect2(
		front_rect.position + Vector2(3.0, 6.0) * tile_scale,
		Vector2(maxf(1.0, 2.6 * tile_scale), front_rect.size.y - 12.0 * tile_scale)
	)
	return {
		"face_rect": front_rect,
		"face_inner_rect": front_rect.grow(-3.0 * tile_scale),
		"side_rect": side_rect,
		"bottom_rect": bottom_rect,
		"shadow_rect": shadow_rect,
		"bevel_top_rect": bevel_top_rect,
		"bevel_left_rect": bevel_left_rect,
		"body_depth": depth,
		"light_source": TILE_STYLE.LIGHT_SOURCE,
	}


func get_feedback_contract() -> Dictionary:
	return {
		"latest_marker": "copper_diamond_and_chevron",
		"latest_uses_shape": true,
		"latest_uses_color": true,
		"pulse_scale": RECENT_DISCARD_PULSE_RANGE,
		"reduced_motion": reduced_motion,
		"shadow_layers": ["ambient_soft", "contact_tight", "body_depth"],
	}


func _draw_tile_body_depth(front_rect: Rect2) -> void:
	var depth := _body_depth()
	var right_points := PackedVector2Array([
		Vector2(front_rect.end.x - 1.0 * tile_scale, front_rect.position.y + 2.0 * tile_scale),
		Vector2(front_rect.end.x + depth.x, front_rect.position.y + depth.y),
		Vector2(front_rect.end.x + depth.x, front_rect.end.y + depth.y),
		Vector2(front_rect.end.x - 1.0 * tile_scale, front_rect.end.y),
	])
	var bottom_points := PackedVector2Array([
		Vector2(front_rect.position.x + 2.0 * tile_scale, front_rect.end.y - 1.0 * tile_scale),
		Vector2(front_rect.end.x - 1.0 * tile_scale, front_rect.end.y - 1.0 * tile_scale),
		Vector2(front_rect.end.x + depth.x, front_rect.end.y + depth.y),
		Vector2(front_rect.position.x + depth.x, front_rect.end.y + depth.y),
	])
	draw_colored_polygon(right_points, TILE_STYLE.side_color(show_back))
	draw_colored_polygon(bottom_points, TILE_STYLE.bottom_color(show_back))
	var right_inner := PackedVector2Array([
		right_points[0] + Vector2(1.3, 3.0) * tile_scale,
		right_points[1] + Vector2(-1.0, 1.0) * tile_scale,
		right_points[2] + Vector2(-1.0, -4.0) * tile_scale,
		right_points[3] + Vector2(1.3, -2.0) * tile_scale,
	])
	var bottom_inner := PackedVector2Array([
		bottom_points[0] + Vector2(4.0, 1.2) * tile_scale,
		bottom_points[1] + Vector2(-2.0, 1.2) * tile_scale,
		bottom_points[2] + Vector2(-2.0, -1.2) * tile_scale,
		bottom_points[3] + Vector2(2.0, -1.2) * tile_scale,
	])
	draw_colored_polygon(right_inner, Color(TILE_STYLE.SIDE_LIGHT, 0.42) if not show_back else Color(0.40, 0.72, 0.36, 0.28))
	draw_colored_polygon(bottom_inner, Color(TILE_STYLE.SIDE_DARK, 0.36) if not show_back else Color(0.02, 0.30, 0.12, 0.34))
	draw_line(right_points[0], right_points[1], TILE_STYLE.INNER_HIGHLIGHT, maxf(1.0, 1.2 * tile_scale))
	draw_line(bottom_points[0], bottom_points[1], Color(0.94, 1.0, 0.91, 0.18), maxf(1.0, tile_scale))


func _body_depth() -> Vector2:
	return Vector2(6.2, 8.0) * tile_scale


func _draw_contact_shadow(shadow_rect: Rect2) -> void:
	var ambient := StyleBoxFlat.new()
	ambient.bg_color = TILE_STYLE.AMBIENT_SHADOW
	ambient.set_corner_radius_all(maxi(4, int(round(TILE_CORNER_RADIUS * tile_scale))))
	ambient.shadow_color = Color(0.0, 0.02, 0.01, 0.32)
	ambient.shadow_size = maxi(3, int(round(7.0 * tile_scale)))
	ambient.shadow_offset = Vector2(4.0, 5.5) * tile_scale
	draw_style_box(ambient, shadow_rect.grow(2.2 * tile_scale))
	if settlement_display:
		return
	var contact_rect := Rect2(
		shadow_rect.position + Vector2(5.0, shadow_rect.size.y - 8.0) * tile_scale,
		Vector2(maxf(2.0, shadow_rect.size.x - 10.0 * tile_scale), maxf(2.0, 7.0 * tile_scale))
	)
	draw_rect(contact_rect, BACK_SHADOW_COLOR if show_back else SHADOW_COLOR, true)


func _draw_face_material(front_rect: Rect2) -> void:
	if show_back:
		_draw_matte_back_material(front_rect)
		return
	var inner := front_rect.grow(-2.0 * tile_scale)
	for band in range(7):
		var t := float(band) / 6.0
		var band_rect := Rect2(
			inner.position + Vector2(2.0 * tile_scale, inner.size.y * t),
			Vector2(inner.size.x - 4.0 * tile_scale, inner.size.y / 6.0 + 1.0)
		)
		draw_rect(band_rect, Color(TILE_STYLE.FACE_BOTTOM, 0.010 + t * 0.022), true)
	var upper_wash := StyleBoxFlat.new()
	upper_wash.bg_color = Color(TILE_STYLE.FACE_HIGHLIGHT, 0.10 if show_back else 0.18)
	upper_wash.corner_radius_top_left = maxi(3, int(round(7.0 * tile_scale)))
	upper_wash.corner_radius_top_right = maxi(3, int(round(7.0 * tile_scale)))
	draw_style_box(upper_wash, Rect2(inner.position + Vector2(2.0, 2.0) * tile_scale, Vector2(inner.size.x - 4.0 * tile_scale, inner.size.y * 0.20)))
	var warm_band := Rect2(
		inner.position + Vector2(4.0, inner.size.y * 0.66),
		Vector2(inner.size.x - 8.0, inner.size.y * 0.24)
	)
	draw_rect(warm_band, Color(TILE_STYLE.FACE_WARMTH, 0.025 if show_back else 0.075), true)
	var top_bevel: Rect2 = get_visual_contract()["bevel_top_rect"]
	var left_bevel: Rect2 = get_visual_contract()["bevel_left_rect"]
	draw_rect(top_bevel, Color(TILE_STYLE.FACE_HIGHLIGHT, 0.34 if show_back else 0.58), true)
	draw_rect(left_bevel, Color(TILE_STYLE.FACE_HIGHLIGHT, 0.20 if show_back else 0.42), true)
	var right_shade := Rect2(
		Vector2(front_rect.end.x - 5.0 * tile_scale, front_rect.position.y + 6.0 * tile_scale),
		Vector2(2.6 * tile_scale, front_rect.size.y - 12.0 * tile_scale)
	)
	draw_rect(right_shade, Color(TILE_STYLE.FACE_INNER_SHADE, 0.18 if show_back else 0.32), true)


func _draw_matte_back_material(front_rect: Rect2) -> void:
	var inner := front_rect.grow(-2.5 * tile_scale)
	# Keep the requested jade palette while lowering the display luminance of
	# concealed hands so ivory public tiles remain the first visual layer.
	draw_rect(inner, Color(0.0, 0.055, 0.040, 0.13), true)
	var upper := Rect2(
		inner.position + Vector2(4.0, 4.0) * tile_scale,
		Vector2(inner.size.x - 8.0 * tile_scale, inner.size.y * 0.34)
	)
	draw_rect(upper, Color(TILE_STYLE.SIDE_LIGHT, 0.055), true)
	var lower := Rect2(
		inner.position + Vector2(4.0 * tile_scale, inner.size.y * 0.68),
		Vector2(inner.size.x - 8.0 * tile_scale, inner.size.y * 0.25)
	)
	draw_rect(lower, Color(TILE_STYLE.BACK_BOTTOM, 0.12), true)
	var top_line := Rect2(
		inner.position + Vector2(7.0, 4.0) * tile_scale,
		Vector2(inner.size.x - 14.0 * tile_scale, maxf(1.0, 1.5 * tile_scale))
	)
	draw_rect(top_line, Color(0.86, 0.96, 0.88, 0.11), true)

func _draw_inset_face_rim(front_rect: Rect2) -> void:
	var radius := maxi(4, int(round((TILE_CORNER_RADIUS - 5) * tile_scale)))
	var inset := maxf(1.8, 2.8 * tile_scale)
	var rim_rect := front_rect.grow(-inset)
	if rim_rect.size.x <= 0.0 or rim_rect.size.y <= 0.0:
		return

	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	rim.border_color = BACK_INNER_RIM if show_back else FACE_INNER_RIM
	rim.set_border_width_all(maxi(1, int(round(1.35 * tile_scale))))
	rim.corner_radius_top_left = radius
	rim.corner_radius_top_right = radius
	rim.corner_radius_bottom_left = radius
	rim.corner_radius_bottom_right = radius
	rim.anti_aliasing = true
	rim.anti_aliasing_size = 1.2
	draw_style_box(rim, rim_rect)

	var top_highlight := Rect2(
		rim_rect.position + Vector2(2.0, 1.4) * tile_scale,
		Vector2(rim_rect.size.x - 4.0 * tile_scale, maxf(1.0, 2.2 * tile_scale))
	)
	var lower_shade := Rect2(
		rim_rect.position + Vector2(3.0, rim_rect.size.y - 4.0 * tile_scale),
		Vector2(rim_rect.size.x - 6.0 * tile_scale, maxf(1.0, 3.2 * tile_scale))
	)
	draw_rect(top_highlight, BACK_INNER_LIGHT if show_back else FACE_INNER_LIGHT, true)
	draw_rect(lower_shade, BACK_INNER_RIM if show_back else FACE_RIGHT_GLAZE, true)


func _draw_recent_discard_accent(outer_rect: Rect2, pulse_phase: float) -> void:
	var glow_rect := outer_rect.grow(4.0 * tile_scale)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.66, 0.44, 0.18, 0.012 + pulse_phase * 0.012)
	glow.border_color = Color(0.78, 0.60, 0.34, 0.72 + pulse_phase * 0.16)
	glow.set_border_width_all(maxi(2, int(round(2.2 * tile_scale))))
	glow.corner_radius_top_left = TILE_CORNER_RADIUS + 2
	glow.corner_radius_top_right = TILE_CORNER_RADIUS + 2
	glow.corner_radius_bottom_left = TILE_CORNER_RADIUS + 2
	glow.corner_radius_bottom_right = TILE_CORNER_RADIUS + 2
	glow.shadow_color = Color(0.66, 0.45, 0.18, 0.15 + pulse_phase * 0.06)
	glow.shadow_size = maxi(4, int(round(7.0 * tile_scale)))
	glow.shadow_offset = Vector2.ZERO
	draw_style_box(glow, glow_rect)

	# Persistent geometric marker keeps “latest” readable without relying on
	# red/amber color alone. It remains visible when reduced motion disables the
	# pulse and when the tile is viewed in a side-seat rotation.
	var marker_center := Vector2(outer_rect.get_center().x, outer_rect.position.y + 10.0 * tile_scale)
	var marker_radius := maxf(4.0, 6.5 * tile_scale)
	var diamond := PackedVector2Array([
		marker_center + Vector2(0.0, -marker_radius),
		marker_center + Vector2(marker_radius, 0.0),
		marker_center + Vector2(0.0, marker_radius),
		marker_center + Vector2(-marker_radius, 0.0),
	])
	draw_colored_polygon(diamond, Color(0.78, 0.60, 0.34, 0.98))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(1.0, 0.94, 0.70, 0.94), maxf(1.0, 1.4 * tile_scale), true)
	var chevron := PackedVector2Array([
		marker_center + Vector2(-marker_radius * 0.52, marker_radius * 0.15),
		marker_center + Vector2(0.0, marker_radius * 0.70),
		marker_center + Vector2(marker_radius * 0.52, marker_radius * 0.15),
	])
	draw_polyline(chevron, Color(0.34, 0.09, 0.06, 0.92), maxf(1.0, 1.7 * tile_scale), true)


func _draw_winning_accent(front_rect: Rect2, outer_rect: Rect2) -> void:
	var glow_rect := outer_rect.grow(3.0 * tile_scale)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow.border_color = Color(0.78, 0.24, 0.32, 0.34)
	glow.set_border_width_all(maxi(1, int(round(1.8 * tile_scale))))
	glow.corner_radius_top_left = TILE_CORNER_RADIUS + 1
	glow.corner_radius_top_right = TILE_CORNER_RADIUS + 1
	glow.corner_radius_bottom_left = TILE_CORNER_RADIUS + 1
	glow.corner_radius_bottom_right = TILE_CORNER_RADIUS + 1
	glow.shadow_color = Color(0.76, 0.20, 0.30, 0.08)
	glow.shadow_size = maxi(2, int(round(4.0 * tile_scale)))
	glow.shadow_offset = Vector2.ZERO
	draw_style_box(glow, glow_rect)

	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	inner.border_color = Color(1.0, 0.97, 0.92, 0.16)
	inner.set_border_width_all(1)
	inner.corner_radius_top_left = TILE_CORNER_RADIUS - 2
	inner.corner_radius_top_right = TILE_CORNER_RADIUS - 2
	inner.corner_radius_bottom_left = TILE_CORNER_RADIUS - 2
	inner.corner_radius_bottom_right = TILE_CORNER_RADIUS - 2
	draw_style_box(inner, front_rect.grow(0.4 * tile_scale))

func _draw_back_pattern(front_rect: Rect2) -> void:
	var edge_inset := 5.0 * tile_scale
	var top_line := Rect2(front_rect.position + Vector2(edge_inset, 4.2 * tile_scale), Vector2(front_rect.size.x - edge_inset * 2.0, 1.0 * tile_scale))
	var bottom_line := Rect2(front_rect.position + Vector2(edge_inset, front_rect.size.y - 5.5 * tile_scale), Vector2(front_rect.size.x - edge_inset * 2.0, 1.5 * tile_scale))
	draw_rect(top_line, BACK_INNER_LIGHT, true)
	draw_rect(bottom_line, BACK_INNER_RIM, true)
	var pattern_rect := front_rect.grow(-9.0 * tile_scale)
	var gap := maxf(13.0 * tile_scale, 6.0)
	var radius := maxf(2.3 * tile_scale, 1.1)
	var columns := maxi(1, int(pattern_rect.size.x / gap))
	var rows := maxi(1, int(pattern_rect.size.y / gap))
	for row in range(rows):
		for column in range(columns):
			var center := pattern_rect.position + Vector2((float(column) + 0.5) * gap, (float(row) + 0.5) * gap)
			if center.x + radius >= pattern_rect.end.x or center.y + radius >= pattern_rect.end.y:
				continue
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
				center + Vector2(0.0, -radius),
			])
			draw_polyline(diamond, Color(0.78, 0.93, 0.80, 0.028), maxf(0.7, 0.8 * tile_scale), true)


func _draw_back_depth_accents(front_rect: Rect2) -> void:
	var top_highlight := Rect2(
		front_rect.position + Vector2(6.0, 3.0) * tile_scale,
		Vector2(front_rect.size.x - 12.0 * tile_scale, maxf(1.0, 2.0 * tile_scale))
	)
	var lower_side := Rect2(
		front_rect.position + Vector2(4.0, front_rect.size.y - 6.0 * tile_scale),
		Vector2(front_rect.size.x - 8.0 * tile_scale, maxf(2.0, 4.0 * tile_scale))
	)
	draw_rect(top_highlight, Color(1.0, 0.98, 0.88, 0.20), true)
	draw_rect(lower_side, Color(0.0, 0.16, 0.08, 0.28), true)


func _draw_polygon_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(points.size()):
		var next_index: int = (index + 1) % points.size()
		draw_line(points[index], points[next_index], color, width)


func _visual_size() -> Vector2:
	var depth := _body_depth()
	return Vector2(
		_face_size().x + maxf(absf(_top_skew().x), depth.x),
		_face_size().y + absf(_top_skew().y) + depth.y
	)


func _face_size() -> Vector2:
	return BASE_SIZE * tile_scale


func _top_skew() -> Vector2:
	return BASE_TOP_SKEW * tile_scale


func _shadow_offset() -> Vector2:
	return BASE_SHADOW_OFFSET * tile_scale


func _front_inset() -> Vector2:
	return BASE_FRONT_INSET * tile_scale


func _texture_rect(front_rect: Rect2) -> Rect2:
	var inset: Vector2 = _front_inset()
	var texture_rect := Rect2(front_rect.position + inset, front_rect.size - inset * 2.0)
	texture_rect = texture_rect.grow_individual(0.9 * tile_scale, 1.1 * tile_scale, 0.9 * tile_scale, 0.8 * tile_scale)
	var suit: String = str(tile_data.get("suit", ""))
	texture_rect.position.y += float(SUIT_TEXTURE_Y_OFFSETS.get(suit, 0.0)) * tile_scale
	texture_rect.position.x -= 0.15 * tile_scale
	return texture_rect


func _resolve_texture() -> Texture2D:
	if show_back:
		return null
	var suit: String = str(tile_data.get("suit", ""))
	var rank: int = int(tile_data.get("rank", 0))
	if suit == "" or rank <= 0:
		return null
	return _load_preferred_texture([
		"%s/%s_%d.png" % [TILE_SYMBOL_DIR, suit, rank],
		"res://res/art/tiles/%s_%d.png" % [suit, rank],
		"res://res/art/tiles/%s_%d.jpg" % [suit, rank],
	])


func _load_tile_surface(back: bool) -> Texture2D:
	# The old bitmap surfaces carried a broad glass highlight and a mint cast.
	# The Shu Brocade Jade Table material is rendered procedurally so every size
	# keeps the same matte back, warm ceramic face and single top-left light.
	return null


func _load_texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		texture = _load_texture_from_image(path)
	if texture != null:
		texture_cache[path] = texture
	return texture


func _load_preferred_texture(paths: Array) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return _load_texture(path)
	return null


func _load_texture_from_image(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func _build_face_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FACE_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.corner_radius_top_left = TILE_CORNER_RADIUS
	style.corner_radius_top_right = TILE_CORNER_RADIUS
	style.corner_radius_bottom_left = TILE_CORNER_RADIUS
	style.corner_radius_bottom_right = TILE_CORNER_RADIUS
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = 3
	style.shadow_offset = BASE_SHADOW_OFFSET
	return style


static func _build_back_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FACE_BACK_COLOR
	style.border_color = BACK_BORDER_COLOR
	style.set_border_width_all(1)
	style.corner_radius_top_left = TILE_CORNER_RADIUS
	style.corner_radius_top_right = TILE_CORNER_RADIUS
	style.corner_radius_bottom_left = TILE_CORNER_RADIUS
	style.corner_radius_bottom_right = TILE_CORNER_RADIUS
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 3
	style.shadow_offset = BASE_SHADOW_OFFSET
	return style
