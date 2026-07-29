extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const EPSILON := 0.0001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var timeline: Array[Dictionary] = []
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	stage.set_reduced_motion(false)

	var original_hand := [_tile(100, "wan", 1), _tile(101, "wan", 2), _tile(102, "wan", 3)]
	var original_players := _players(original_hand, [])
	stage.render_snapshot(_snapshot(original_players, -1), [original_hand, [], [], []], false, -1, {})
	await create_timer(0.34).timeout
	var nodes: Dictionary = stage.get("tile_nodes")
	var surviving_tile := nodes.get("hand_0_100") as SichuanTile3D
	if surviving_tile == null:
		failures.append("initial surviving hand tile missing")
	else:
		var hand_transform_before := surviving_tile.transform
		var discarded: Dictionary = original_hand[2]
		var next_hand := [original_hand[0], original_hand[1]]
		var next_players := _players(next_hand, [discarded])
		stage.render_snapshot(_snapshot(next_players, 102), [next_hand, [], [], []], false, -1, {})
		var motion_started_ms := Time.get_ticks_msec()
		nodes = stage.get("tile_nodes")
		var discard_tile := nodes.get("discard_0_102") as SichuanTile3D
		if discard_tile == null:
			failures.append("latest discard tile missing at motion start")
		else:
			timeline.append(_timeline_entry("motion_start", motion_started_ms, discard_tile, surviving_tile, hand_transform_before))
			if discard_tile.latest_marker.visible:
				failures.append("latest marker appeared before the discard landed")
			await create_timer(0.21).timeout
			timeline.append(_timeline_entry("travel_complete_settle_active", motion_started_ms, discard_tile, surviving_tile, hand_transform_before))
			if discard_tile.latest_marker.visible:
				failures.append("latest marker appeared during the 40ms landing settle")
			if not _transform_close(surviving_tile.transform, hand_transform_before):
				failures.append("remaining hand reflowed before discard landing completed: distance=%.6f" % surviving_tile.transform.origin.distance_to(hand_transform_before.origin))
			await create_timer(0.06).timeout
			timeline.append(_timeline_entry("landing_complete", motion_started_ms, discard_tile, surviving_tile, hand_transform_before))
			if not discard_tile.latest_marker.visible:
				failures.append("latest marker did not appear after river landing")
			if not _transform_close(surviving_tile.transform, hand_transform_before):
				failures.append("remaining hand reflowed in the marker's first visible beat")
			await create_timer(0.18).timeout
			timeline.append(_timeline_entry("hand_reflow_complete", motion_started_ms, discard_tile, surviving_tile, hand_transform_before))
			if _transform_close(surviving_tile.transform, hand_transform_before):
				failures.append("remaining hand did not reflow after discard landing")

	stage.queue_free()
	await process_frame
	_write_timeline(timeline, failures)
	if failures.is_empty():
		print("SICHUAN DISCARD LANDING SEQUENCE OK")
		quit(0)
		return
	push_error("SICHUAN DISCARD LANDING SEQUENCE FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _players(hand: Array, discards: Array) -> Array:
	var players: Array = []
	for seat in range(4):
		players.append({
			"seat": seat,
			"hand_tiles": hand if seat == 0 else [],
			"hand_count": hand.size() if seat == 0 else 0,
			"melds": [],
			"discards": discards if seat == 0 else [],
			"has_won": false,
			"ding_que": "tong",
		})
	return players


func _snapshot(players: Array, latest_id: int) -> Dictionary:
	return {
		"players": players,
		"wall_count": 40,
		"human_can_discard": true,
		"human_last_draw_tile_id": -1,
		"recent_discard_tile_id": latest_id,
	}


func _tile(id: int, suit: String, rank: int) -> Dictionary:
	return {"id": id, "suit": suit, "rank": rank, "display_name": "%d万" % rank}


func _transform_close(left: Transform3D, right: Transform3D) -> bool:
	return left.origin.distance_to(right.origin) <= EPSILON and left.basis.is_equal_approx(right.basis)


func _timeline_entry(
	event: String,
	started_ms: int,
	discard_tile: SichuanTile3D,
	surviving_tile: SichuanTile3D,
	hand_transform_before: Transform3D
) -> Dictionary:
	return {
		"event": event,
		"elapsed_ms": Time.get_ticks_msec() - started_ms,
		"latest_marker_visible": discard_tile.latest_marker.visible,
		"discard_position": [discard_tile.position.x, discard_tile.position.y, discard_tile.position.z],
		"discard_scale": [discard_tile.scale.x, discard_tile.scale.y, discard_tile.scale.z],
		"surviving_hand_reflowed": not _transform_close(surviving_tile.transform, hand_transform_before),
	}


func _write_timeline(timeline: Array[Dictionary], failures: Array[String]) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
			break
	if output_path.is_empty():
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write discard sequence evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify({
		"criterion": "AC-HAND-03",
		"travel_contract_ms": 200,
		"settle_contract_ms": 40,
		"marker_before_reflow_beat_ms": 60,
		"hand_reflow_contract": "after_discard_landing",
		"latest_marker_contract": "after_discard_landing",
		"timeline": timeline,
		"objective_result": "PASS" if failures.is_empty() else "FAIL",
	}, "  "))
