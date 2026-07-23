extends SceneTree

const PLAYER_UI_SCENE := preload("res://scenes/ui/PlayerUI.tscn")
const DISCARD_LAYER_SCRIPT := preload("res://scripts/ui/table/TableDiscardLayer.gd")
const HAND_CANVAS_SCRIPT := preload("res://scripts/ui/HandCanvas2D.gd")
const TILE_SCENE := preload("res://scenes/ui/MahjongTile.tscn")

const PLAYER_UI_SIZE := Vector2(390.0, 700.0)
const BOARD_SIZE := Vector2(1440.0, 710.0)
const SELF_HAND_SIZE := Vector2(2008.0, 262.0)
const MIN_TILE_GAP := 0.5


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _verify_side_player_tracks(failures)
	await _verify_top_player_track(failures)
	await _verify_discard_tracks(failures)
	_verify_self_hand_track(failures)
	_verify_tile_depth_contract(failures)
	if failures.is_empty():
		print("SICHUAN DENSE TABLE LAYOUT OK")
		quit(0)
		return
	push_error("SICHUAN DENSE TABLE LAYOUT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_side_player_tracks(failures: Array[String]) -> void:
	for side_case in [
		{"dock": 2, "seat": 1, "label": "left"},
		{"dock": 3, "seat": 3, "label": "right"},
	]:
		var dock := int(side_case["dock"])
		for meld_count in range(5):
			var player_ui := PLAYER_UI_SCENE.instantiate() as Control
			player_ui.set("seat_dock", dock)
			get_root().add_child(player_ui)
			player_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			player_ui.position = Vector2(40.0 if dock == 2 else 500.0, 30.0)
			player_ui.size = PLAYER_UI_SIZE
			await process_frame
			var hand_count := 14 - meld_count * 3
			player_ui.call("apply_snapshot", _player_snapshot(int(side_case["seat"]), hand_count, meld_count), true, 0, 0, true)
			await process_frame
			var label := "%s melds=%d" % [str(side_case["label"]), meld_count]
			_verify_player_contract(player_ui, label, failures)
			player_ui.free()


func _verify_top_player_track(failures: Array[String]) -> void:
	var player_ui := PLAYER_UI_SCENE.instantiate() as Control
	player_ui.set("seat_dock", 1)
	get_root().add_child(player_ui)
	player_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	player_ui.position = Vector2(20.0, 20.0)
	player_ui.size = Vector2(1360.0, 144.0)
	await process_frame
	player_ui.call("apply_snapshot", _player_snapshot(2, 11, 1), true, 0, 0, true)
	await process_frame
	_verify_player_contract(player_ui, "top", failures)
	var top_bounds := player_ui.get_global_rect()
	if top_bounds.size.y > 150.0:
		failures.append("top opponent track must stay within 150 px")
	player_ui.free()


func _verify_player_contract(player_ui: Control, label: String, failures: Array[String]) -> void:
	if not player_ui.has_method("get_visual_tile_rects"):
		failures.append("%s PlayerUI missing get_visual_tile_rects" % label)
		return
	var tile_rects: Array = player_ui.call("get_visual_tile_rects")
	if tile_rects.is_empty():
		failures.append("%s PlayerUI returned no visible tile rects" % label)
		return
	_assert_non_overlapping(tile_rects, "%s tiles" % label, failures)
	var host_rect := player_ui.get_global_rect().grow(1.0)
	for index in range(tile_rects.size()):
		var rect: Rect2 = tile_rects[index]
		var minimum_edge := minf(rect.size.x, rect.size.y)
		var required_edge := 70.0 if label == "top" else 76.0
		if minimum_edge < required_edge:
			failures.append("%s tile %d is too small for phone readability: %.1f < %.1f" % [label, index, minimum_edge, required_edge])
		if not host_rect.encloses(rect):
			failures.append("%s tile %d escaped player host: %s not in %s" % [label, index, rect, host_rect])
	if label.begins_with("left") or label.begins_with("right"):
		var side_hand_grid := player_ui.find_child("SideHandGrid", true, false) as Control
		if side_hand_grid == null:
			failures.append("%s missing centered SideHandGrid" % label)
		elif absf(side_hand_grid.get_global_rect().get_center().y - player_ui.get_global_rect().get_center().y) > 1.0:
			failures.append(
				"%s hand must be vertically centered: hand=%.2f host=%.2f" % [
					label,
					side_hand_grid.get_global_rect().get_center().y,
					player_ui.get_global_rect().get_center().y,
				]
			)
	if not player_ui.has_method("get_track_rects"):
		failures.append("%s PlayerUI missing get_track_rects" % label)
		return
	var tracks: Dictionary = player_ui.call("get_track_rects")
	var track_names := tracks.keys()
	for left in range(track_names.size()):
		for right in range(left + 1, track_names.size()):
			var left_rect: Rect2 = tracks[track_names[left]]
			var right_rect: Rect2 = tracks[track_names[right]]
			if left_rect.has_area() and right_rect.has_area() and left_rect.intersects(right_rect):
				failures.append("%s tracks overlap: %s/%s" % [label, track_names[left], track_names[right]])


func _verify_discard_tracks(failures: Array[String]) -> void:
	var layer := DISCARD_LAYER_SCRIPT.new() as Control
	get_root().add_child(layer)
	layer.call("set_reduced_motion", true)
	var players: Array = []
	for seat in range(4):
		var discards: Array = []
		for index in range(14):
			discards.append(_tile(seat * 100 + index, index))
		players.append({"seat": seat, "discards": discards})
	layer.call("render", players, {"id": 313}, Rect2(Vector2(20.0, 20.0), BOARD_SIZE))
	await process_frame
	var all_discard_rects: Array = []
	for seat in range(4):
		if not layer.has_method("get_tile_rects"):
			failures.append("discard layer missing get_tile_rects")
			break
		var rects: Array = layer.call("get_tile_rects", seat)
		if rects.size() != 14:
			failures.append("seat %d expected 14 discard rects, got %d" % [seat, rects.size()])
		_assert_non_overlapping(rects, "seat %d discards" % seat, failures)
		all_discard_rects.append_array(rects)
		var lane: Control = layer.call("get_lane", seat)
		var lane_rect := lane.get_global_rect().grow(1.0)
		for rect_value in rects:
			var rect: Rect2 = rect_value
			if not lane_rect.encloses(rect):
				failures.append("seat %d discard escaped lane" % seat)
	_assert_non_overlapping(all_discard_rects, "all seat discards", failures)
	layer.free()


func _verify_self_hand_track(failures: Array[String]) -> void:
	var hand := HAND_CANVAS_SCRIPT.new() as Node2D
	get_root().add_child(hand)
	var tiles: Array = []
	for index in range(14):
		tiles.append(_tile(800 + index, index))
	hand.call("configure", tiles, -1, 813, SELF_HAND_SIZE, {}, {})
	var layouts: Array = hand.call("get_layout_contract")
	var rects: Array = []
	for layout in layouts:
		rects.append(layout.get("front_rect", Rect2()))
	_assert_non_overlapping(rects, "self hand", failures)
	var bounds: Rect2 = hand.call("get_layout_bounds")
	if bounds.position.x < 0.0 or bounds.end.x > SELF_HAND_SIZE.x:
		failures.append("self hand escaped full-width track: %s" % bounds)
	hand.free()


func _verify_tile_depth_contract(failures: Array[String]) -> void:
	var tile := TILE_SCENE.instantiate() as Control
	get_root().add_child(tile)
	tile.call("configure", _tile(990, 5), 1.0, false, false, false)
	if not tile.has_method("get_visual_contract"):
		failures.append("shared tile missing get_visual_contract")
	else:
		var contract: Dictionary = tile.call("get_visual_contract")
		for key in ["face_rect", "side_rect", "bottom_rect", "shadow_rect", "light_source"]:
			if not contract.has(key):
				failures.append("shared tile visual contract missing %s" % key)
	tile.free()


func _assert_non_overlapping(rects: Array, label: String, failures: Array[String]) -> void:
	for left in range(rects.size()):
		var left_rect: Rect2 = rects[left]
		if not left_rect.has_area():
			failures.append("%s rect %d has no area" % [label, left])
			continue
		for right in range(left + 1, rects.size()):
			var right_rect: Rect2 = rects[right]
			var separation := _rect_separation(left_rect, right_rect)
			if left_rect.intersects(right_rect) or separation < MIN_TILE_GAP:
				failures.append("%s overlap/insufficient gap %d/%d: %.2f" % [label, left, right, separation])


func _rect_separation(left: Rect2, right: Rect2) -> float:
	var horizontal := maxf(0.0, maxf(right.position.x - left.end.x, left.position.x - right.end.x))
	var vertical := maxf(0.0, maxf(right.position.y - left.end.y, left.position.y - right.end.y))
	if horizontal <= 0.0:
		return vertical
	if vertical <= 0.0:
		return horizontal
	return Vector2(horizontal, vertical).length()


func _player_snapshot(seat: int, hand_count: int, meld_count: int) -> Dictionary:
	var melds: Array = []
	for meld_index in range(meld_count):
		var tiles: Array = []
		var tile_count := 4 if meld_index % 2 == 1 else 3
		for tile_index in range(tile_count):
			tiles.append(_tile(2000 + seat * 100 + meld_index * 10 + tile_index, meld_index + tile_index))
		melds.append({
			"type": "gang" if tile_count == 4 else "peng",
			"tiles": tiles,
			"tile": tiles[0],
			"from_seat": (seat + 1) % 4,
		})
	return {
		"seat": seat,
		"nickname": "测试玩家%d" % seat,
		"score": 10,
		"hand_count": hand_count,
		"hand_tiles": [],
		"melds": melds,
		"ding_que": "wan",
		"has_won": false,
	}


func _tile(tile_id: int, index: int) -> Dictionary:
	return {
		"id": tile_id,
		"suit": ["wan", "tiao", "tong"][index % 3],
		"rank": index % 9 + 1,
	}
