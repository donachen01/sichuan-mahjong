class_name TableDiscardLayer
extends Control

const TILE_SCENE := preload("res://scenes/ui/MahjongTile.tscn")

const REFERENCE_SIZE := Vector2(1440.0, 710.0)
const TILE_BASE_SIZE := Vector2(92.0, 140.0)
const TILE_VISUAL_EXTRA := Vector2(8.0, 16.0)
const DISCARD_SCALE := 0.87
const TILE_GAP := 5.0
const FIT_PADDING := 4.0
const MAX_DISCARDS_PER_SEAT := 14

const LANE_RECTS := {
	0: Rect2(80.0, 565.0, 1280.0, 145.0),
	1: Rect2(230.0, 175.0, 340.0, 380.0),
	2: Rect2(80.0, 30.0, 1280.0, 145.0),
	3: Rect2(870.0, 175.0, 340.0, 380.0),
}
const CENTER_RECT := Rect2(590.0, 250.0, 260.0, 210.0)

var lanes: Dictionary = {}
var latest_marker_count := 0
var reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	clip_contents = false
	_ensure_lanes()
	queue_redraw()


func render(players: Array, latest_discard: Dictionary, board_rect: Rect2) -> void:
	_ensure_lanes()
	_apply_board_rect(board_rect)
	latest_marker_count = 0
	var latest_id := int(latest_discard.get("id", -1))
	for seat in range(4):
		_render_lane(seat, _player_by_seat(players, seat).get("discards", []), latest_id)


func set_board_rect(board_rect: Rect2) -> void:
	_ensure_lanes()
	_apply_board_rect(board_rect)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


func get_lane(seat: int) -> Control:
	_ensure_lanes()
	return lanes.get(clampi(seat, 0, 3))


func get_lane_rect(seat: int) -> Rect2:
	var lane := get_lane(seat)
	return Rect2(lane.position, lane.size) if lane != null else Rect2()


func get_center_reserved_rect() -> Rect2:
	var scale := Vector2(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	return Rect2(CENTER_RECT.position * scale, CENTER_RECT.size * scale)


func get_tile_rects(seat: int) -> Array:
	var rects: Array = []
	var lane := get_lane(seat)
	if lane == null:
		return rects
	for child in lane.get_children():
		if child is Control and (child as Control).visible:
			rects.append((child as Control).get_global_rect())
	return rects


func get_latest_marker_count() -> int:
	return latest_marker_count


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var scale := size / REFERENCE_SIZE
	for seat in range(4):
		var lane_rect: Rect2 = LANE_RECTS[seat]
		draw_style_box(_zone_style(0.035), Rect2(lane_rect.position * scale, lane_rect.size * scale))


func _ensure_lanes() -> void:
	if lanes.size() == 4:
		return
	for seat in range(4):
		var lane := Control.new()
		lane.name = "DiscardLane%d" % seat
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane.clip_contents = true
		add_child(lane)
		lanes[seat] = lane
	_layout_lanes()


func _apply_board_rect(board_rect: Rect2) -> void:
	position = board_rect.position
	size = board_rect.size
	custom_minimum_size = board_rect.size
	_layout_lanes()
	queue_redraw()


func _layout_lanes() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var scale := Vector2(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	for seat in range(4):
		var lane: Control = lanes.get(seat)
		var reference_rect: Rect2 = LANE_RECTS[seat]
		lane.position = reference_rect.position * scale
		lane.size = reference_rect.size * scale
		lane.custom_minimum_size = lane.size


func _render_lane(seat: int, discards: Array, latest_id: int) -> void:
	var lane: Control = lanes.get(seat)
	for child in lane.get_children():
		child.free()
	var visible_discards := discards.slice(maxi(0, discards.size() - MAX_DISCARDS_PER_SEAT), discards.size())
	if visible_discards.is_empty():
		return
	var items_per_row := 5 if seat in [1, 3] else 14
	var render_scale := _fit_scale(seat, lane.size, visible_discards.size(), items_per_row)
	var face_size := TILE_BASE_SIZE * render_scale
	var visual_size := (TILE_BASE_SIZE + TILE_VISUAL_EXTRA) * render_scale
	var oriented_size := face_size
	var oriented_visual_size := visual_size
	var rotation_degrees := 0.0
	if seat == 1:
		rotation_degrees = 90.0
		oriented_size = Vector2(face_size.y, face_size.x)
		oriented_visual_size = Vector2(visual_size.y, visual_size.x)
	elif seat == 3:
		rotation_degrees = -90.0
		oriented_size = Vector2(face_size.y, face_size.x)
		oriented_visual_size = Vector2(visual_size.y, visual_size.x)
	var col_step := _column_step(seat, oriented_size, oriented_visual_size, lane.size, visible_discards.size(), items_per_row)
	var row_step := _row_step(seat, oriented_visual_size)
	var origin := _origin(seat, lane.size, oriented_visual_size, visible_discards.size(), items_per_row, col_step)
	for index in range(visible_discards.size()):
		var tile_data: Dictionary = visible_discards[index]
		var is_latest := latest_marker_count == 0 and latest_id >= 0 and int(tile_data.get("id", -1)) == latest_id
		var tile_host := _create_tile_host(tile_data, render_scale, rotation_degrees, is_latest)
		var row := index / items_per_row
		var column := index % items_per_row
		var target_position := origin + col_step * float(column) + row_step * float(row)
		tile_host.position = target_position
		lane.add_child(tile_host)
		if is_latest:
			latest_marker_count += 1
			if not reduced_motion:
				tile_host.modulate = Color(1.0, 0.88, 0.62, 0.72)
				tile_host.position = target_position + Vector2(0.0, -7.0)
				var tween := tile_host.create_tween()
				tween.set_parallel(true)
				tween.tween_property(tile_host, "modulate", Color.WHITE, 0.22)
				tween.tween_property(tile_host, "position", target_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fit_scale(seat: int, container_size: Vector2, display_count: int, items_per_row: int) -> float:
	if seat in [1, 3]:
		var visible_rows := mini(display_count, items_per_row)
		var available_height := container_size.y - FIT_PADDING * 2.0 - TILE_GAP * float(maxi(0, visible_rows - 1))
		var group_count := maxi(1, ceili(float(display_count) / float(maxi(1, items_per_row))))
		var available_width := container_size.x - FIT_PADDING * 2.0 - TILE_GAP * float(maxi(0, group_count - 1))
		var height_scale := available_height / ((TILE_BASE_SIZE.x + TILE_VISUAL_EXTRA.x) * float(visible_rows))
		var width_scale := available_width / ((TILE_BASE_SIZE.y + TILE_VISUAL_EXTRA.y) * float(group_count))
		return minf(DISCARD_SCALE, maxf(0.1, minf(height_scale, width_scale)))
	var rows := maxi(1, ceili(float(display_count) / float(maxi(1, items_per_row))))
	var available_height := container_size.y - FIT_PADDING * 2.0 - TILE_GAP * float(maxi(0, rows - 1))
	return minf(DISCARD_SCALE, maxf(0.1, available_height / ((TILE_BASE_SIZE.y + TILE_VISUAL_EXTRA.y) * float(rows))))


func _column_step(seat: int, tile_size: Vector2, visual_size: Vector2, container_size: Vector2, discard_count: int, items_per_row: int) -> Vector2:
	match seat:
		0:
			return Vector2(_horizontal_step(visual_size, container_size, discard_count, items_per_row), 0.0)
		1:
			return Vector2(0.0, visual_size.y + TILE_GAP)
		2:
			return Vector2(-_horizontal_step(visual_size, container_size, discard_count, items_per_row), 0.0)
		3:
			return Vector2(0.0, -(visual_size.y + TILE_GAP))
		_:
			return Vector2.ZERO


func _row_step(seat: int, visual_size: Vector2) -> Vector2:
	match seat:
		0:
			return Vector2(0.0, visual_size.y + TILE_GAP)
		1:
			return Vector2(-(visual_size.x + TILE_GAP), 0.0)
		2:
			return Vector2(0.0, -(visual_size.y + TILE_GAP))
		3:
			return Vector2(visual_size.x + TILE_GAP, 0.0)
		_:
			return Vector2.ZERO


func _origin(seat: int, container_size: Vector2, visual_size: Vector2, discard_count: int, items_per_row: int, col_step: Vector2) -> Vector2:
	var first_row_count := mini(discard_count, items_per_row)
	var first_row_width := absf(col_step.x) * float(maxi(0, first_row_count - 1)) + visual_size.x
	match seat:
		0:
			return Vector2(maxf(FIT_PADDING, (container_size.x - first_row_width) * 0.5), FIT_PADDING)
		1:
			return Vector2(container_size.x - visual_size.x - FIT_PADDING, FIT_PADDING)
		2:
			return Vector2(minf(container_size.x - visual_size.x - FIT_PADDING, maxf(FIT_PADDING, (container_size.x + first_row_width) * 0.5 - visual_size.x)), container_size.y - visual_size.y - FIT_PADDING)
		3:
			return Vector2(FIT_PADDING, container_size.y - visual_size.y - FIT_PADDING)
		_:
			return Vector2(FIT_PADDING, FIT_PADDING)


func _horizontal_step(visual_size: Vector2, container_size: Vector2, discard_count: int, items_per_row: int) -> float:
	var columns := mini(maxi(1, discard_count), maxi(1, items_per_row))
	var natural_step := visual_size.x + TILE_GAP
	if columns <= 1:
		return natural_step
	var available_step := (container_size.x - FIT_PADDING * 2.0 - visual_size.x) / float(columns - 1)
	return minf(available_step, natural_step)


func _create_tile_host(tile_data: Dictionary, scale: float, rotation_degrees: float, is_latest: bool) -> Control:
	var tile := TILE_SCENE.instantiate()
	tile.call("configure", tile_data, scale, false, false, false, is_latest)
	var host: Control = tile
	if absf(rotation_degrees) >= 0.01:
		var tile_size: Vector2 = tile.custom_minimum_size
		var wrapper := Control.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.custom_minimum_size = Vector2(tile_size.y, tile_size.x)
		wrapper.size = wrapper.custom_minimum_size
		tile.pivot_offset = tile_size * 0.5
		tile.position = (wrapper.custom_minimum_size - tile_size) * 0.5
		tile.rotation_degrees = rotation_degrees
		wrapper.add_child(tile)
		host = wrapper
	host.set_meta("latest_discard", is_latest)
	return host


func _player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if int(player.get("seat", -1)) == seat:
			return player
	return {}


func _zone_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.18, 0.13, alpha)
	style.border_color = Color(0.73, 0.61, 0.31, alpha * 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	return style
