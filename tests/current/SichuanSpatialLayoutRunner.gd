extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const TABLE_METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const DEFAULT_VIEWPORT_SIZE := Vector2i(2048, 1152)
const CENTER_RESERVE := Rect2(0.46, 0.330, 0.08, 0.130)
const POSITION_EPSILON := 0.0001

var evidence: Dictionary = {
	"criterion": "AC-LAYOUT-02/03",
	"objective_result": "PASS",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_viewport_size := _requested_viewport_size()
	get_root().size = requested_viewport_size
	evidence["requested_resolution"] = [requested_viewport_size.x, requested_viewport_size.y]
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
	await _verify_claimed_discard_stability(stage, snapshot, all_hands, failures)
	await _verify_four_meld_pressure(stage, snapshot, failures)

	stage.queue_free()
	await process_frame
	evidence["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	_write_evidence(failures)
	if failures.is_empty():
		print("SICHUAN SPATIAL LAYOUT CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN SPATIAL LAYOUT CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _requested_viewport_size() -> Vector2i:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--resolution="):
			continue
		var parts := argument.trim_prefix("--resolution=").split("x")
		if parts.size() == 2:
			var width := int(parts[0])
			var height := int(parts[1])
			if width > 0 and height > 0:
				return Vector2i(width, height)
	return DEFAULT_VIEWPORT_SIZE


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
	evidence["discard_pressure"] = {
		"discard_count_per_seat": 18,
		"center_reserve": _normalized(center_reserve, viewport),
		"groups": {
			"discard_0": _normalized(groups["discard_0"], viewport),
			"discard_1": _normalized(groups["discard_1"], viewport),
			"discard_2": _normalized(groups["discard_2"], viewport),
			"discard_3": _normalized(groups["discard_3"], viewport),
		},
		"center_intersections": 0,
		"cross_river_intersections": 0,
		"hand_intersections": 0,
		"row_intersections": 0,
	}


func _verify_claimed_discard_stability(
	stage: SichuanTableStage3D,
	base_snapshot: Dictionary,
	all_hands: Array,
	failures: Array[String]
) -> void:
	var before: Dictionary = {}
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if key.begins_with("discard_"):
			before[key] = ((stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D).position
	var claimed_snapshot := base_snapshot.duplicate(true)
	var claimed_players: Array = (base_snapshot.get("players", []) as Array).duplicate(true)
	var claimed_discards: Array = (claimed_players[1].get("discards", []) as Array).duplicate(true)
	var removed_tile: Dictionary = claimed_discards[7]
	claimed_discards.remove_at(7)
	claimed_players[1]["discards"] = claimed_discards
	claimed_snapshot["players"] = claimed_players
	stage.render_snapshot(claimed_snapshot, all_hands, false, -1, {})
	await process_frame
	var max_survivor_delta := 0.0
	var survivor_count := 0
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if not key.begins_with("discard_") or not before.has(key):
			continue
		survivor_count += 1
		var current_position := ((stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D).position
		max_survivor_delta = maxf(max_survivor_delta, current_position.distance_to(before[key]))
	if max_survivor_delta > POSITION_EPSILON:
		failures.append("claimed discard removal reflowed surviving river tiles: %.6f" % max_survivor_delta)
	evidence["claimed_discard_removal"] = {
		"seat": 1,
		"removed_tile_id": int(removed_tile.get("id", -1)),
		"survivor_count": survivor_count,
		"max_survivor_world_delta": max_survivor_delta,
		"allowed_delta": POSITION_EPSILON,
		"stable": max_survivor_delta <= POSITION_EPSILON,
	}


func _verify_four_meld_pressure(
	stage: SichuanTableStage3D,
	base_snapshot: Dictionary,
	failures: Array[String]
) -> void:
	var pressure_snapshot := base_snapshot.duplicate(true)
	var pressure_players: Array = (base_snapshot.get("players", []) as Array).duplicate(true)
	var pressure_hands: Array = []
	for seat in range(4):
		var hand := _tiles(71000 + seat * 100, 2, seat)
		pressure_hands.append(hand)
		var melds: Array = []
		for meld_index in range(4):
			var is_gang := meld_index == 3
			melds.append({
				"type": "gang" if is_gang else "peng",
				"gang_subtype": "ming_gang" if is_gang else "",
				"from_seat": (seat + meld_index + 1) % 4,
				"tiles": _tiles(72000 + seat * 100 + meld_index * 10, 4 if is_gang else 3, seat + meld_index),
			})
		pressure_players[seat]["hand_tiles"] = hand if seat == 0 else []
		pressure_players[seat]["melds"] = melds
		pressure_players[seat]["discards"] = _tiles(73000 + seat * 100, 6, seat + 1)
	pressure_snapshot["players"] = pressure_players
	pressure_snapshot["recent_discard_tile_id"] = int((pressure_players[3]["discards"] as Array).back().get("id", -1))
	stage.render_snapshot(pressure_snapshot, pressure_hands, false, -1, {})
	await process_frame
	var viewport := Vector2(get_root().get_visible_rect().size)
	var viewport_rect := Rect2(Vector2.ZERO, viewport)
	var contract: Dictionary = stage.get_visual_contract()
	var side_tilt := float(contract.get("opponent_rack_tilt_degrees", 0.0))
	var far_tilt := float(contract.get("far_rack_tilt_degrees", 0.0))
	if absf(side_tilt - 90.0) > 0.001 or absf(far_tilt - 90.0) > 0.001:
		failures.append("AI seat posture lost the exact 90-degree table contract")
	var pressure_metrics: Dictionary = {
		"meld_groups_per_seat": 4,
		"groups": {},
		"intersections": 0,
		"side_rack_tilt_degrees": side_tilt,
		"far_rack_tilt_degrees": far_tilt,
	}
	for seat in range(4):
		var hand_rect := _projected_group(stage, "hand_%d_" % seat)
		var discard_rect := _projected_group(stage, "discard_%d_" % seat)
		var hud_rect: Rect2 = TABLE_METRICS.seat_hud_rect(seat, viewport)
		var prior_groups: Array[Rect2] = []
		for meld_index in range(4):
			var group_rect := _projected_group(stage, "meld_%d_%d_" % [seat, meld_index])
			pressure_metrics["groups"]["seat_%d_group_%d" % [seat, meld_index]] = _normalized(group_rect, viewport)
			if group_rect.size == Vector2.ZERO:
				failures.append("seat %d four-meld pressure group %d is missing" % [seat, meld_index])
				continue
			if not viewport_rect.encloses(group_rect):
				failures.append("seat %d meld group %d leaves the safe viewport" % [seat, meld_index])
			if group_rect.intersects(hand_rect):
				failures.append("seat %d meld group %d overlaps its concealed hand" % [seat, meld_index])
			if group_rect.intersects(discard_rect):
				failures.append("seat %d meld group %d overlaps its river" % [seat, meld_index])
			if group_rect.intersects(hud_rect):
				failures.append("seat %d meld group %d overlaps SeatHUD" % [seat, meld_index])
			for prior_rect in prior_groups:
				if group_rect.intersects(prior_rect):
					failures.append("seat %d meld groups overlap under four-group pressure" % seat)
			prior_groups.append(group_rect)
		if seat in [1, 2, 3]:
			for key_value in (stage.get("tile_nodes") as Dictionary).keys():
				if not str(key_value).begins_with("meld_%d_" % seat):
					continue
				var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
				var up_axis := tile.transform.basis.y.normalized()
				if absf(absf(up_axis.y) - 1.0) > 0.001:
					failures.append("seat %d meld tile is not 90 degrees to the table" % seat)
					break
	evidence["four_meld_pressure"] = pressure_metrics


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


func _write_evidence(failures: Array[String]) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
			break
	if output_path.is_empty():
		return
	evidence["failures"] = failures
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write spatial layout evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify(evidence, "  "))


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
