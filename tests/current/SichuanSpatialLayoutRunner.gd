extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const VIEWPORT_SIZE := Vector2i(2048, 1152)
const CENTER_RESERVE := Rect2(0.46, 0.330, 0.08, 0.130)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = VIEWPORT_SIZE
	await process_frame
	var failures: Array[String] = []
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	stage.set_reduced_motion(true)

	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		# A four-tile meld leaves ten concealed tiles. Keeping the stress snapshot
		# rule-valid is essential when evaluating the shared lower rail.
		var hand := _tiles(61000 + seat * 100, 10 if seat == 0 else 13, seat)
		var discards := _tiles(62000 + seat * 100, 18, seat + 1)
		var meld_tiles := _tiles(63000 + seat * 100, 4, seat + 2)
		all_hands.append(hand)
		players.append({
			"seat": seat,
			"has_won": false,
			"hand_tiles": hand if seat == 0 else [],
			"melds": [{"type": "gang", "gang_subtype": "ming_gang", "tiles": meld_tiles}],
			"discards": discards,
		})
	var snapshot := {
		"players": players,
		"wall_count": 12,
		"human_can_discard": true,
		"human_last_draw_tile_id": int(all_hands[0].back().get("id", -1)),
		"recent_discard_tile_id": int(players[3]["discards"].back().get("id", -1)),
	}
	stage.render_snapshot(snapshot, all_hands, false, -1, {})
	await process_frame
	await process_frame
	_verify_layout(stage, failures)

	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN SPATIAL LAYOUT CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN SPATIAL LAYOUT CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_layout(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	# The project uses a 2560×1440 design viewport with canvas expansion.  Query
	# the live viewport instead of assuming the requested host-window size so the
	# projection contract measures the same coordinate space as Camera3D.
	var viewport := Vector2(get_root().get_visible_rect().size)
	var groups: Dictionary = {}
	for seat in range(4):
		groups["hand_%d" % seat] = _projected_group(stage, "hand_%d_" % seat)
		groups["meld_%d" % seat] = _projected_group(stage, "meld_%d_" % seat)
		groups["discard_%d" % seat] = _projected_group(stage, "discard_%d_" % seat)

	var center_reserve := Rect2(
		Vector2(CENTER_RESERVE.position.x * viewport.x, CENTER_RESERVE.position.y * viewport.y),
		Vector2(CENTER_RESERVE.size.x * viewport.x, CENTER_RESERVE.size.y * viewport.y)
	)
	for seat in range(4):
		var discard_rect: Rect2 = groups["discard_%d" % seat]
		if discard_rect.size == Vector2.ZERO:
			failures.append("seat %d discard group is empty" % seat)
		elif discard_rect.intersects(center_reserve):
			failures.append("seat %d discards intrude into the center indicator reserve: %s" % [seat, discard_rect])
		var hand_rect: Rect2 = groups["hand_%d" % seat]
		if discard_rect.intersects(hand_rect):
			failures.append("seat %d discards overlap the concealed hand" % seat)
		var meld_rect: Rect2 = groups["meld_%d" % seat]
		if meld_rect.intersects(hand_rect) and (seat != 2 or _prefix_tiles_overlap(stage, "meld_2_", "hand_2_")):
			failures.append("seat %d melds overlap the concealed hand" % seat)
		if meld_rect.intersects(discard_rect) and (seat != 2 or _prefix_tiles_overlap(stage, "meld_2_", "discard_2_")):
			failures.append("seat %d melds overlap its discard zone" % seat)
		for row in range(2):
			if _discard_rows_overlap(stage, seat, row, row + 1):
				failures.append("seat %d discard rows %d and %d overlap under 18-tile pressure" % [seat, row + 1, row + 2])
	for first in range(4):
		for second in range(first + 1, 4):
			if (groups["discard_%d" % first] as Rect2).intersects(groups["discard_%d" % second] as Rect2):
				failures.append("seat %d and seat %d discard zones overlap" % [first, second])
	if (groups["meld_2"] as Rect2).intersects(groups["meld_3"] as Rect2):
		failures.append("far-player meld overlaps the right-player meld rail")

	var self_meld: Rect2 = groups["meld_0"]
	if self_meld.end.y > viewport.y * 0.94:
		failures.append("human meld row falls outside the lower-left safe rail")
	var self_hand: Rect2 = groups["hand_0"]
	if self_hand.size.x / viewport.x < 0.52:
		failures.append("human hand lost first-level visual weight")
	print("SPATIAL_LAYOUT_METRICS " + JSON.stringify({
		"center_reserve": _normalized(center_reserve, viewport),
		"self_hand": _normalized(self_hand, viewport),
		"hand_1": _normalized(groups["hand_1"], viewport),
		"hand_2": _normalized(groups["hand_2"], viewport),
		"hand_3": _normalized(groups["hand_3"], viewport),
		"self_meld": _normalized(self_meld, viewport),
		"meld_1": _normalized(groups["meld_1"], viewport),
		"meld_2": _normalized(groups["meld_2"], viewport),
		"meld_3": _normalized(groups["meld_3"], viewport),
		"discard_0": _normalized(groups["discard_0"], viewport),
		"discard_1": _normalized(groups["discard_1"], viewport),
		"discard_2": _normalized(groups["discard_2"], viewport),
		"discard_3": _normalized(groups["discard_3"], viewport),
	}))


func _projected_group(stage: SichuanTableStage3D, prefix: String) -> Rect2:
	var result := Rect2()
	var found := false
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with(prefix):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		var rect := tile.get_screen_rect(stage.get_camera())
		result = rect if not found else result.merge(rect)
		found = true
	return result


func _prefix_tiles_overlap(stage: SichuanTableStage3D, first_prefix: String, second_prefix: String) -> bool:
	var first_tiles: Array[SichuanTile3D] = []
	var second_tiles: Array[SichuanTile3D] = []
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if key.begins_with(first_prefix):
			first_tiles.append((stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D)
		elif key.begins_with(second_prefix):
			second_tiles.append((stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D)
	for first_tile in first_tiles:
		for second_tile in second_tiles:
			if first_tile.get_screen_rect(stage.get_camera()).intersects(second_tile.get_screen_rect(stage.get_camera())):
				return true
	return false


func _discard_rows_overlap(stage: SichuanTableStage3D, seat: int, first_row: int, second_row: int) -> bool:
	for column in range(6):
		var first_id := 62000 + seat * 100 + first_row * 6 + column
		var second_id := 62000 + seat * 100 + second_row * 6 + column
		var first_tile := (stage.get("tile_nodes") as Dictionary).get("discard_%d_%d" % [seat, first_id]) as SichuanTile3D
		var second_tile := (stage.get("tile_nodes") as Dictionary).get("discard_%d_%d" % [seat, second_id]) as SichuanTile3D
		if first_tile == null or second_tile == null:
			continue
		if first_tile.get_screen_rect(stage.get_camera()).intersects(second_tile.get_screen_rect(stage.get_camera())):
			return true
	return false


func _normalized(rect: Rect2, viewport: Vector2) -> Array[float]:
	return [
		snappedf(rect.position.x / viewport.x, 0.0001),
		snappedf(rect.position.y / viewport.y, 0.0001),
		snappedf(rect.size.x / viewport.x, 0.0001),
		snappedf(rect.size.y / viewport.y, 0.0001),
	]


func _tiles(start_id: int, count: int, offset: int) -> Array:
	var result: Array = []
	var suits := ["tiao", "tong", "wan"]
	for index in range(count):
		result.append({
			"id": start_id + index,
			"suit": suits[(index + offset) % suits.size()],
			"rank": (index * 2 + offset) % 9 + 1,
		})
	return result
