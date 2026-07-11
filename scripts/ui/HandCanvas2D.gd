extends Node2D

class_name HandCanvas2D

const TILE_FACE_SIZE := Vector2(136.0, 204.0)
const TILE_TOP_HEIGHT := 0.0
const TILE_STEP_MAX := 136.0
const TILE_STEP_MIN := 78.0
const SIDE_MARGIN := 28.0
const BASELINE_BOTTOM := 12.0
const ARC_MAX_LIFT := 0.0
const ARC_MAX_ROTATION := 0.0
const TOP_SKEW := Vector2(1.8, -2.2)
const NEW_DRAW_GAP := 22.0
const WINNING_TILE_GAP := 24.0
const SELECTED_LIFT := 10.0
const NEW_DRAW_LIFT := 8.0
const FRONT_INSET := Vector2(6.2, 6.4)
const SHADOW_OFFSET := Vector2(0.0, 4.8)
const SHADOW_ALPHA := 0.14
const SUIT_TEXTURE_Y_OFFSETS := {
	"wan": 2.0,
	"tiao": -2.0,
	"tong": -3.0,
}
const SUIT_TEXTURE_X_OFFSETS := {
	"wan": -1.5,
	"tiao": -3.0,
	"tong": -3.5,
}
const SUIT_TEXTURE_SCALES := {
	"wan": Vector2(0.78, 0.78),
	"tiao": Vector2(0.75, 0.78),
	"tong": Vector2(0.72, 0.76),
}
const SUIT_RANK_TEXTURE_SCALE_OVERRIDES := {
	"tong_8": Vector2(0.70, 0.73),
	"tong_9": Vector2(0.70, 0.73),
}
const TILE_BORDER_COLOR := Color8(102, 160, 122, 238)
const TILE_FACE_COLOR := Color8(222, 246, 228, 255)
const TILE_CORNER_RADIUS := 10
const HIGHLIGHT_COLOR := Color8(195, 29, 56, 255)
const SELECTED_FACE_TINT := Color8(193, 236, 211, 255)
const SELECTED_EDGE_LIGHT := Color8(195, 29, 56, 225)
const TILE_INNER_BORDER := Color(0.96, 1.0, 0.98, 0.38)
const TILE_INNER_SHADOW := Color(0.08, 0.18, 0.13, 0.14)
const TILE_FACE_SURFACE_PATH := "res://res/art/ui_3d_cartoon/tile_face_table.png"
const TILE_SYMBOL_DIR := "res://res/art/ui_3d_cartoon/tile_symbols"
const USE_SELF_TILE_SURFACE := false
const DANGER_OUTLINE := Color(0.72, 0.28, 0.24, 0.92)
const DANGER_BANNER := Color(0.50, 0.14, 0.12, 0.92)
const BAO_GANG_OUTLINE := Color(1.0, 0.78, 0.34, 0.96)
const BAO_GANG_GLOW := Color(1.0, 0.72, 0.26, 0.14)
const BAO_GANG_BADGE := Color(0.08, 0.30, 0.20, 0.94)
const RECOMMEND_MARKER_RADIUS := 10.5
const RECOMMEND_MARKER_BOB_SPEED := 3.2
const RECOMMEND_MARKER_TOP := Color(1.0, 0.90, 0.48, 0.90)
const RECOMMEND_MARKER_SIDE := Color(0.30, 0.72, 0.54, 0.84)
const RECOMMEND_MARKER_CORE := Color(0.98, 1.0, 0.88, 0.90)
const RECOMMEND_MARKER_SHADOW := Color(0.12, 0.08, 0.02, 0.18)

var hand_tiles: Array = []
var selected_tile_id: int = -1
var new_draw_tile_id: int = -1
var viewport_size: Vector2 = Vector2.ZERO
var tile_layouts: Array = []
var trainer_markers: Dictionary = {}
var embedded_left_width: float = 0.0
var embedded_left_gap: float = 0.0
var embedded_right_width: float = 0.0
var embedded_right_gap: float = 0.0
var recommended_marker_contract: Dictionary = {}
var configure_signature: String = ""

static var texture_cache: Dictionary = {}
static var _face_stylebox: StyleBoxFlat = _build_face_stylebox()
static var _inner_border_stylebox: StyleBoxFlat = _build_inner_border_stylebox()
static var _inner_shadow_stylebox: StyleBoxFlat = _build_inner_shadow_stylebox()
static var _selected_stylebox: StyleBoxFlat = _build_selected_stylebox()


func configure(tiles: Array, selected_id: int, new_id: int, canvas_size: Vector2, markers: Dictionary = {}, layout_options: Dictionary = {}) -> void:
	var next_signature := _build_configure_signature(tiles, selected_id, new_id, canvas_size, markers, layout_options)
	if next_signature == configure_signature:
		return
	configure_signature = next_signature
	hand_tiles = tiles.duplicate(true)
	selected_tile_id = selected_id
	new_draw_tile_id = new_id
	viewport_size = canvas_size
	trainer_markers = markers.duplicate(true)
	embedded_left_width = float(layout_options.get("embedded_left_width", 0.0))
	embedded_left_gap = float(layout_options.get("embedded_left_gap", 0.0))
	embedded_right_width = float(layout_options.get("embedded_right_width", 0.0))
	embedded_right_gap = float(layout_options.get("embedded_right_gap", 0.0))
	_rebuild_layout()
	queue_redraw()


func _build_configure_signature(tiles: Array, selected_id: int, new_id: int, canvas_size: Vector2, markers: Dictionary, layout_options: Dictionary) -> String:
	var tile_ids: Array[int] = []
	for tile in tiles:
		var tile_data: Dictionary = tile
		tile_ids.append(int(tile_data.get("id", -1)))
	var marker_ids: Array = markers.get("danger_tile_ids", [])
	var bao_gang_keys: Array = markers.get("bao_gang_keys", [])
	return JSON.stringify({
		"tiles": tile_ids,
		"selected": selected_id,
		"new": new_id,
		"size": [int(round(canvas_size.x)), int(round(canvas_size.y))],
		"recommended": int(markers.get("recommended_tile_id", -1)),
		"danger": marker_ids.duplicate(),
		"bao_gang": bao_gang_keys.duplicate(),
		"winning": int(markers.get("winning_tile_id", -1)),
		"winning_source": int(markers.get("winning_source_seat", -1)),
		"left_width": int(round(float(layout_options.get("embedded_left_width", 0.0)))),
		"left_gap": int(round(float(layout_options.get("embedded_left_gap", 0.0)))),
		"right_width": int(round(float(layout_options.get("embedded_right_width", 0.0)))),
		"right_gap": int(round(float(layout_options.get("embedded_right_gap", 0.0)))),
	})


func get_tile_id_at_point(point: Vector2) -> int:
	for index in range(tile_layouts.size() - 1, -1, -1):
		var layout: Dictionary = tile_layouts[index]
		var hit_rect: Rect2 = layout.get("hit_rect", Rect2())
		if hit_rect.has_point(point):
			return int(layout.get("tile_id", -1))
	return -1


func get_layout_bounds() -> Rect2:
	if tile_layouts.is_empty():
		return Rect2()
	var bounds: Rect2 = tile_layouts[0].get("outer_rect", Rect2())
	for index in range(1, tile_layouts.size()):
		var layout: Dictionary = tile_layouts[index]
		bounds = bounds.merge(layout.get("outer_rect", Rect2()))
	return bounds


func get_recommended_marker_contract() -> Dictionary:
	return recommended_marker_contract.duplicate(true)


func _draw() -> void:
	if tile_layouts.is_empty():
		return

	var selected_layouts: Array = []
	for layout in tile_layouts:
		if bool(layout.get("selected", false)):
			selected_layouts.append(layout)
		else:
			_draw_single_tile(layout)

	for layout in selected_layouts:
		_draw_single_tile(layout)

	if _has_recommended_tile():
		queue_redraw()


func _draw_single_tile(layout: Dictionary) -> void:
	var outer_rect: Rect2 = layout["outer_rect"]
	var front_rect: Rect2 = layout["front_rect"]
	var tile: Dictionary = layout["tile"]
	var is_selected: bool = layout["selected"]
	var is_new_draw: bool = layout["new_draw"]
	var is_recommended: bool = layout.get("recommended", false)
	var is_danger: bool = layout.get("danger", false)
	var is_bao_gang: bool = layout.get("bao_gang", false)
	var is_winning_tile: bool = layout.get("winning", false)
	var rotation_degrees: float = float(layout.get("rotation", 0.0))
	var pivot := front_rect.get_center()

	var shadow_rect := front_rect
	shadow_rect.position += SHADOW_OFFSET
	shadow_rect.position -= Vector2(2.0, 1.0)
	shadow_rect.size += Vector2(4.0, 5.0)
	var tile_draw_scale := Vector2.ONE * (1.05 if is_selected else 1.0)
	draw_set_transform(pivot, deg_to_rad(rotation_degrees), tile_draw_scale)
	var local_front_rect := Rect2(front_rect.position - pivot, front_rect.size)
	var local_outer_rect := Rect2(outer_rect.position - pivot, outer_rect.size)
	var local_shadow_rect := Rect2(shadow_rect.position - pivot, shadow_rect.size)

	var surface_texture := _load_tile_surface() if USE_SELF_TILE_SURFACE else null
	if surface_texture != null:
		var surface_rect := local_front_rect.grow_individual(-4.0, -3.4, -4.0, -2.2)
		draw_texture_rect(surface_texture, surface_rect, false)
		_draw_asset_tile_warmth(local_front_rect)
		_draw_asset_tile_depth(local_front_rect)
	else:
		draw_rect(local_shadow_rect, Color(0.0, 0.0, 0.0, SHADOW_ALPHA), true)
		draw_style_box(_selected_stylebox if is_selected or is_new_draw else _face_stylebox, local_front_rect)
		_draw_embedded_tile_depth(local_front_rect)

	var texture := _resolve_texture(tile)
	if texture != null:
		var texture_rect := _texture_rect_for_tile(local_front_rect, tile)
		draw_texture_rect(texture, texture_rect, false)

	if surface_texture != null:
		_draw_asset_tile_rim(local_front_rect)
	if is_new_draw:
		_draw_selected_accent(local_front_rect, local_outer_rect)
	if is_danger:
		_draw_danger_hint(local_front_rect)
	if is_recommended:
		_draw_recommended_marker(local_front_rect)
	if is_bao_gang:
		_draw_bao_gang_highlight(local_front_rect, local_outer_rect)
	if is_selected:
		_draw_selected_accent(local_front_rect, local_outer_rect)
	if is_winning_tile:
		_draw_winning_highlight(local_front_rect, local_outer_rect)
		_draw_winning_source_arrow(local_front_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_banner(front_rect: Rect2, text: String, fill_color: Color) -> void:
	var badge_rect := Rect2(front_rect.position + Vector2(6.0, 6.0), Vector2(28.0, 26.0))
	draw_rect(badge_rect, fill_color, true)
	draw_rect(badge_rect, Color(1.0, 0.95, 0.82, 0.85), false, 2.0)
	var font := ThemeDB.fallback_font
	if font != null:
		var text_position := badge_rect.position + Vector2(6.0, 21.0)
		draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1, 1, 1, 1))


func _draw_danger_hint(front_rect: Rect2) -> void:
	var glow_rect := Rect2(
		front_rect.position + Vector2(front_rect.size.x * 0.18, front_rect.size.y - 7.0),
		Vector2(front_rect.size.x * 0.64, 5.0)
	)
	draw_rect(glow_rect, Color(0.98, 0.38, 0.18, 0.32), true)


func _draw_asset_tile_depth(front_rect: Rect2) -> void:
	var body := front_rect.grow_individual(-3.0, -2.0, -3.0, -1.0)
	var top_wash := StyleBoxFlat.new()
	top_wash.bg_color = Color(1.0, 1.0, 1.0, 0.18)
	top_wash.corner_radius_top_left = TILE_CORNER_RADIUS - 2
	top_wash.corner_radius_top_right = TILE_CORNER_RADIUS - 2
	draw_style_box(top_wash, Rect2(
		body.position + Vector2(7.0, 5.0),
		Vector2(body.size.x - 14.0, 9.0)
	))

	var contact_shadow := StyleBoxFlat.new()
	contact_shadow.bg_color = Color(0.0, 0.0, 0.0, 0.16)
	contact_shadow.corner_radius_bottom_left = TILE_CORNER_RADIUS
	contact_shadow.corner_radius_bottom_right = TILE_CORNER_RADIUS
	draw_style_box(contact_shadow, Rect2(
		body.position + Vector2(9.0, body.size.y + 1.0),
		Vector2(body.size.x - 18.0, 4.0)
	))


func _draw_asset_tile_warmth(front_rect: Rect2) -> void:
	var body := front_rect.grow_individual(-5.0, -4.0, -5.0, -2.0)
	var warm_wash := StyleBoxFlat.new()
	warm_wash.bg_color = Color(0.95, 0.92, 0.84, 0.035)
	warm_wash.corner_radius_top_left = TILE_CORNER_RADIUS - 2
	warm_wash.corner_radius_top_right = TILE_CORNER_RADIUS - 2
	warm_wash.corner_radius_bottom_left = TILE_CORNER_RADIUS - 2
	warm_wash.corner_radius_bottom_right = TILE_CORNER_RADIUS - 2
	draw_style_box(warm_wash, body.grow_individual(3.0, 5.0, 3.0, 4.0))

	var lower_shade := StyleBoxFlat.new()
	lower_shade.bg_color = Color(0.22, 0.18, 0.12, 0.025)
	lower_shade.corner_radius_bottom_left = TILE_CORNER_RADIUS - 2
	lower_shade.corner_radius_bottom_right = TILE_CORNER_RADIUS - 2
	draw_style_box(lower_shade, Rect2(
		body.position + Vector2(8.0, body.size.y * 0.72),
		Vector2(body.size.x - 16.0, body.size.y * 0.24)
	))


func _draw_asset_tile_rim(front_rect: Rect2) -> void:
	var body := front_rect.grow_individual(-3.0, -2.0, -3.0, -1.0)
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	rim.border_color = TILE_BORDER_COLOR
	rim.set_border_width_all(2)
	rim.corner_radius_top_left = TILE_CORNER_RADIUS - 1
	rim.corner_radius_top_right = TILE_CORNER_RADIUS - 1
	rim.corner_radius_bottom_left = TILE_CORNER_RADIUS - 1
	rim.corner_radius_bottom_right = TILE_CORNER_RADIUS - 1
	draw_style_box(rim, body.grow_individual(-1.0, -1.0, -1.0, -1.0))


func _draw_embedded_tile_depth(front_rect: Rect2) -> void:
	var radius := TILE_CORNER_RADIUS
	var body_rect := front_rect.grow_individual(-2.0, -1.0, -2.0, -1.0)

	var top_glow := StyleBoxFlat.new()
	top_glow.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	top_glow.corner_radius_top_left = radius - 2
	top_glow.corner_radius_top_right = radius - 2
	draw_style_box(top_glow, Rect2(
		body_rect.position + Vector2(10.0, 7.0),
		Vector2(body_rect.size.x - 20.0, 2.0)
	))

	var contact_shadow := StyleBoxFlat.new()
	contact_shadow.bg_color = Color(0.0, 0.0, 0.0, 0.07)
	contact_shadow.corner_radius_bottom_left = radius - 1
	contact_shadow.corner_radius_bottom_right = radius - 1
	draw_style_box(contact_shadow, Rect2(
		body_rect.position + Vector2(10.0, body_rect.size.y + 1.0),
		Vector2(body_rect.size.x - 20.0, 3.0)
	))


func _draw_polyline_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		draw_line(points[index], points[next_index], color, width)


func _rebuild_layout() -> void:
	tile_layouts.clear()
	recommended_marker_contract = {}
	if hand_tiles.is_empty():
		return

	var step: float = _compute_step()
	var row_width: float = TILE_FACE_SIZE.x
	if hand_tiles.size() > 1:
		row_width += step * float(hand_tiles.size() - 1)
	if _should_apply_new_draw_gap():
		row_width += NEW_DRAW_GAP
	if _should_apply_winning_tile_gap():
		row_width += WINNING_TILE_GAP
	var left_reserved := embedded_left_width + (embedded_left_gap if embedded_left_width > 0.0 and row_width > 0.0 else 0.0)
	var right_reserved := embedded_right_width + (embedded_right_gap if embedded_right_width > 0.0 and row_width > 0.0 else 0.0)
	var has_embedded_hosts := left_reserved > 0.0 or right_reserved > 0.0
	var start_x: float
	if has_embedded_hosts:
		var total_group_width: float = left_reserved + row_width + right_reserved
		var group_left: float = SIDE_MARGIN if embedded_left_width > 0.0 else floor((viewport_size.x - total_group_width) * 0.5)
		var min_group_left: float = SIDE_MARGIN
		var max_group_left: float = viewport_size.x - SIDE_MARGIN - total_group_width
		if max_group_left < min_group_left:
			group_left = min_group_left
		else:
			group_left = clampf(group_left, min_group_left, max_group_left)
		start_x = group_left + left_reserved
	else:
		start_x = floor((viewport_size.x - row_width) * 0.5)
	var front_top_y: float = viewport_size.y - BASELINE_BOTTOM - TILE_FACE_SIZE.y

	for index in range(hand_tiles.size()):
		var tile: Dictionary = hand_tiles[index]
		var tile_id := int(tile.get("id", -1))
		var x: float = start_x + float(index) * step
		if _should_apply_new_draw_gap() and index == hand_tiles.size() - 1:
			x += NEW_DRAW_GAP
		if _should_apply_winning_tile_gap() and index == hand_tiles.size() - 1:
			x += WINNING_TILE_GAP

		var arc_factor := 0.0
		var arc_lift := 0.0
		var lift := arc_lift
		if tile_id == selected_tile_id:
			lift = arc_lift + SELECTED_LIFT
		elif tile_id == new_draw_tile_id:
			lift = arc_lift + NEW_DRAW_LIFT

		var front_rect := Rect2(
			Vector2(x, front_top_y - lift),
			TILE_FACE_SIZE
		)
		var outer_rect := front_rect
		tile_layouts.append({
			"tile": tile,
			"tile_id": tile_id,
			"selected": tile_id == selected_tile_id,
			"new_draw": tile_id == new_draw_tile_id,
			"recommended": int(trainer_markers.get("recommended_tile_id", -1)) == tile_id,
			"danger": trainer_markers.get("danger_tile_ids", []).has(tile_id),
			"bao_gang": _is_bao_gang_tile(tile),
			"winning": index == hand_tiles.size() - 1 and int(trainer_markers.get("winning_tile_id", -1)) == tile_id,
			"rotation": 0.0,
			"front_rect": front_rect,
			"outer_rect": outer_rect,
			"hit_rect": outer_rect.grow_individual(18.0, 18.0, 18.0, 18.0),
		})
		if int(trainer_markers.get("recommended_tile_id", -1)) == tile_id:
			var marker_center := _recommended_marker_center(front_rect, 0.0)
			recommended_marker_contract = {
				"mode": "hovering_jade_marker",
				"uses_outline": false,
				"is_animating": true,
				"center": marker_center,
				"front_rect": front_rect,
				"tile_id": tile_id,
			}


func _has_recommended_tile() -> bool:
	return int(trainer_markers.get("recommended_tile_id", -1)) != -1


func _is_bao_gang_tile(tile: Dictionary) -> bool:
	var bao_gang_keys: Array = trainer_markers.get("bao_gang_keys", [])
	if bao_gang_keys.is_empty() or tile.is_empty():
		return false
	return bao_gang_keys.has(_tile_key(tile))


func _tile_key(tile: Dictionary) -> String:
	return "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


func _draw_bao_gang_highlight(front_rect: Rect2, outer_rect: Rect2) -> void:
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow.border_color = BAO_GANG_OUTLINE
	glow.set_border_width_all(3)
	glow.corner_radius_top_left = TILE_CORNER_RADIUS + 3
	glow.corner_radius_top_right = TILE_CORNER_RADIUS + 3
	glow.corner_radius_bottom_left = TILE_CORNER_RADIUS + 3
	glow.corner_radius_bottom_right = TILE_CORNER_RADIUS + 3
	glow.shadow_color = BAO_GANG_GLOW
	glow.shadow_size = 8
	glow.shadow_offset = Vector2.ZERO
	draw_style_box(glow, outer_rect.grow(4.0))
	_draw_banner(front_rect, "杠", BAO_GANG_BADGE)


func _draw_recommended_marker(front_rect: Rect2) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var bob := sin(time * RECOMMEND_MARKER_BOB_SPEED) * 2.6
	var center := _recommended_marker_center(front_rect, bob)
	var radius := RECOMMEND_MARKER_RADIUS
	var shadow_center := center + Vector2(0.0, 4.8)
	draw_colored_polygon(_ellipse_points(shadow_center, radius * 1.18, radius * 0.26, 32), RECOMMEND_MARKER_SHADOW)

	var body := _ellipse_points(center, radius, radius * 0.62, 40)
	var lower := _ellipse_points(center + Vector2(0.0, 2.4), radius * 0.92, radius * 0.42, 40)
	draw_colored_polygon(lower, RECOMMEND_MARKER_SIDE.darkened(0.18))
	draw_colored_polygon(body, RECOMMEND_MARKER_TOP)
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.74, 0.42, 0.04, 0.72), 1.7)

	var core_radius := radius * 0.46
	draw_colored_polygon(_ellipse_points(center + Vector2(0.0, -0.8), core_radius, core_radius * 0.62, 28), RECOMMEND_MARKER_CORE)
	draw_colored_polygon(
		_ellipse_points(center + Vector2(-4.6, -4.8), radius * 0.26, radius * 0.10, 18),
		Color(1.0, 1.0, 0.94, 0.54)
	)
	draw_arc(center, radius * 0.58, 0.0, TAU, 36, Color(0.30, 0.64, 0.46, 0.46), 1.4)


func _recommended_marker_center(front_rect: Rect2, bob: float) -> Vector2:
	return Vector2(front_rect.get_center().x, front_rect.position.y + 13.0 + bob)


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(8, segments)):
		var angle := TAU * float(index) / float(maxi(8, segments))
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _arc_factor_for_index(index: int) -> float:
	if hand_tiles.size() <= 1:
		return 0.0
	var center := float(hand_tiles.size() - 1) * 0.5
	var half_span := maxf(1.0, center)
	return (float(index) - center) / half_span


func _compute_step() -> float:
	if hand_tiles.size() <= 1:
		return TILE_STEP_MAX
	var extra_gap := 0.0
	if _should_apply_new_draw_gap():
		extra_gap += NEW_DRAW_GAP
	if _should_apply_winning_tile_gap():
		extra_gap += WINNING_TILE_GAP
	var left_reserved := embedded_left_width + (embedded_left_gap if embedded_left_width > 0.0 else 0.0)
	var right_reserved := embedded_right_width + (embedded_right_gap if embedded_right_width > 0.0 else 0.0)
	var row_allowance := maxf(0.0, viewport_size.x - SIDE_MARGIN * 2.0 - TILE_FACE_SIZE.x - extra_gap - left_reserved - right_reserved)
	var fit_step := row_allowance / float(hand_tiles.size() - 1)
	return clampf(fit_step, TILE_STEP_MIN, TILE_STEP_MAX)


func _should_apply_new_draw_gap() -> bool:
	if hand_tiles.is_empty():
		return false
	return int(hand_tiles.back().get("id", -1)) == new_draw_tile_id


func _should_apply_winning_tile_gap() -> bool:
	if hand_tiles.is_empty():
		return false
	return int(trainer_markers.get("winning_tile_id", -1)) == int(hand_tiles.back().get("id", -1))


func _draw_winning_highlight(front_rect: Rect2, outer_rect: Rect2) -> void:
	var glow_rect := outer_rect.grow(3.0)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow.border_color = Color(0.78, 0.24, 0.32, 0.34)
	glow.set_border_width_all(2)
	glow.corner_radius_top_left = 10
	glow.corner_radius_top_right = 10
	glow.corner_radius_bottom_left = 10
	glow.corner_radius_bottom_right = 10
	glow.shadow_color = Color(0.76, 0.20, 0.30, 0.08)
	glow.shadow_size = 4
	glow.shadow_offset = Vector2.ZERO
	draw_style_box(glow, glow_rect)

	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	inner.border_color = Color(1.0, 0.97, 0.92, 0.18)
	inner.set_border_width_all(1)
	inner.corner_radius_top_left = 7
	inner.corner_radius_top_right = 7
	inner.corner_radius_bottom_left = 7
	inner.corner_radius_bottom_right = 7
	draw_style_box(inner, front_rect.grow(0.5))


func _draw_winning_source_arrow(front_rect: Rect2) -> void:
	var source_seat := int(trainer_markers.get("winning_source_seat", -1))
	if source_seat <= 0:
		return
	var badge_size := Vector2(30.0, 24.0)
	var center := front_rect.get_center() + Vector2(0.0, 12.0)
	var rotation := _winning_source_arrow_rotation(source_seat)
	var points := PackedVector2Array([
		Vector2(0.0, -badge_size.y * 0.5),
		Vector2(badge_size.x * 0.56, badge_size.y * 0.46),
		Vector2(0.0, badge_size.y * 0.18),
		Vector2(-badge_size.x * 0.56, badge_size.y * 0.46),
	])
	var shadow_points := _transform_points(points, center + Vector2(0.0, 2.0), rotation)
	var arrow_points := _transform_points(points, center, rotation)
	var highlight_points := _transform_points(PackedVector2Array([
		Vector2(0.0, -badge_size.y * 0.42),
		Vector2(badge_size.x * 0.28, badge_size.y * 0.12),
		Vector2(-badge_size.x * 0.28, badge_size.y * 0.12),
	]), center + Vector2(0.0, -1.0), rotation)
	draw_colored_polygon(shadow_points, Color(0.34, 0.22, 0.02, 0.18))
	draw_colored_polygon(arrow_points, Color(1.0, 0.84, 0.18, 0.72))
	draw_colored_polygon(highlight_points, Color(1.0, 0.97, 0.70, 0.36))
	_draw_polyline_closed(arrow_points, Color(0.70, 0.48, 0.04, 0.76), 1.6)


func _winning_source_arrow_rotation(source_seat: int) -> float:
	match source_seat:
		1:
			return -PI * 0.5
		2:
			return 0.0
		3:
			return PI * 0.5
		_:
			return PI


func _transform_points(points: PackedVector2Array, center: Vector2, rotation: float) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(center + point.rotated(rotation))
	return transformed


func _resolve_texture(tile: Dictionary) -> Texture2D:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	if suit == "" or rank <= 0:
		return null
	var cache_key := "%s_%d" % [suit, rank]
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]
	var texture := _load_preferred_texture([
		"%s/%s_%d.png" % [TILE_SYMBOL_DIR, suit, rank],
		"res://res/art/tiles/%s_%d.png" % [suit, rank],
		"res://res/art/tiles/%s_%d.jpg" % [suit, rank],
	])
	if texture != null:
		texture_cache[cache_key] = texture
	return texture


func _texture_rect_for_tile(front_rect: Rect2, tile: Dictionary) -> Rect2:
	var base_rect := Rect2(
		front_rect.position + FRONT_INSET,
		front_rect.size - FRONT_INSET * 2.0
	)
	base_rect = base_rect.grow_individual(0.4, 0.4, 0.4, 0.4)
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var texture_scale: Vector2 = SUIT_TEXTURE_SCALES.get(suit, Vector2.ONE)
	var suit_rank_key := "%s_%d" % [suit, rank]
	if SUIT_RANK_TEXTURE_SCALE_OVERRIDES.has(suit_rank_key):
		texture_scale = SUIT_RANK_TEXTURE_SCALE_OVERRIDES[suit_rank_key]
	var scaled_size := Vector2(
		base_rect.size.x * texture_scale.x,
		base_rect.size.y * texture_scale.y
	)
	var texture_rect := Rect2(
		base_rect.position + (base_rect.size - scaled_size) * 0.5,
		scaled_size
	)
	texture_rect.position.x += float(SUIT_TEXTURE_X_OFFSETS.get(suit, 0.0))
	var y_offset := float(SUIT_TEXTURE_Y_OFFSETS.get(suit, 0.0))
	texture_rect.position.y += y_offset
	return texture_rect


func _load_preferred_texture(paths: Array) -> Texture2D:
	for path in paths:
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
		if texture == null:
			texture = _load_texture_from_image(path)
		if texture != null:
			return texture
	return null


func _load_texture_from_image(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _load_tile_surface() -> Texture2D:
	return _load_preferred_texture([TILE_FACE_SURFACE_PATH])


static func _build_face_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TILE_FACE_COLOR
	style.border_color = TILE_BORDER_COLOR
	style.set_border_width_all(1)
	style.corner_radius_top_left = TILE_CORNER_RADIUS
	style.corner_radius_top_right = TILE_CORNER_RADIUS
	style.corner_radius_bottom_left = TILE_CORNER_RADIUS
	style.corner_radius_bottom_right = TILE_CORNER_RADIUS
	style.shadow_color = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	style.shadow_size = 3
	style.shadow_offset = SHADOW_OFFSET
	return style


static func _build_inner_border_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = TILE_INNER_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = TILE_CORNER_RADIUS - 2
	style.corner_radius_top_right = TILE_CORNER_RADIUS - 2
	style.corner_radius_bottom_left = TILE_CORNER_RADIUS - 2
	style.corner_radius_bottom_right = TILE_CORNER_RADIUS - 2
	return style


static func _build_inner_shadow_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = TILE_INNER_SHADOW
	style.set_border_width_all(1)
	style.corner_radius_top_left = TILE_CORNER_RADIUS - 1
	style.corner_radius_top_right = TILE_CORNER_RADIUS - 1
	style.corner_radius_bottom_left = TILE_CORNER_RADIUS - 1
	style.corner_radius_bottom_right = TILE_CORNER_RADIUS - 1
	return style


static func _build_selected_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SELECTED_FACE_TINT
	style.border_color = SELECTED_EDGE_LIGHT
	style.set_border_width_all(1)
	style.corner_radius_top_left = TILE_CORNER_RADIUS
	style.corner_radius_top_right = TILE_CORNER_RADIUS
	style.corner_radius_bottom_left = TILE_CORNER_RADIUS
	style.corner_radius_bottom_right = TILE_CORNER_RADIUS
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _draw_selected_accent(front_rect: Rect2, outer_rect: Rect2) -> void:
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow.border_color = SELECTED_EDGE_LIGHT
	glow.set_border_width_all(2)
	glow.corner_radius_top_left = TILE_CORNER_RADIUS + 2
	glow.corner_radius_top_right = TILE_CORNER_RADIUS + 2
	glow.corner_radius_bottom_left = TILE_CORNER_RADIUS + 2
	glow.corner_radius_bottom_right = TILE_CORNER_RADIUS + 2
	glow.shadow_color = Color(0.76, 0.20, 0.30, 0.08)
	glow.shadow_size = 4
	glow.shadow_offset = Vector2.ZERO
	draw_style_box(glow, outer_rect.grow(3.0))
