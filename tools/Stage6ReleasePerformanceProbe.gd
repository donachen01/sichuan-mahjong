extends Node

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const WARMUP_SECONDS := 60.0
const SAMPLE_FRAMES := 600


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var table := MAIN_SCENE.instantiate()
	get_tree().root.add_child(table)
	for _frame in range(12):
		await get_tree().process_frame
	var stage := table.get("table_stage_3d") as SichuanTableStage3D
	if stage == null:
		push_error("Stage 6 release performance probe requires the 3D table stage")
		get_tree().quit(1)
		return
	stage.set_reduced_motion(true)
	var pressure := _pressure_snapshot()
	stage.render_snapshot(pressure.snapshot, pressure.hands, true, -1, {})
	for _frame in range(8):
		await get_tree().process_frame

	var warmup_started_usec := Time.get_ticks_usec()
	await get_tree().create_timer(WARMUP_SECONDS).timeout
	var warmup_elapsed_seconds := float(Time.get_ticks_usec() - warmup_started_usec) / 1000000.0

	var frame_times_ms: Array[float] = []
	var previous_usec := Time.get_ticks_usec()
	for _sample in range(SAMPLE_FRAMES):
		await get_tree().process_frame
		var current_usec := Time.get_ticks_usec()
		frame_times_ms.append(float(current_usec - previous_usec) / 1000.0)
		previous_usec = current_usec
	frame_times_ms.sort()
	var total_ms := 0.0
	for frame_ms in frame_times_ms:
		total_ms += frame_ms
	var slow_count := maxi(1, int(ceil(float(frame_times_ms.size()) * 0.01)))
	var slow_total_ms := 0.0
	for index in range(frame_times_ms.size() - slow_count, frame_times_ms.size()):
		slow_total_ms += frame_times_ms[index]
	var average_frame_ms := total_ms / float(frame_times_ms.size())
	var one_percent_frame_ms := slow_total_ms / float(slow_count)
	var light_count := 0
	var shadow_light_count := 0
	var rigid_body_count := 0
	for descendant in _all_descendants(stage):
		if descendant is Light3D:
			light_count += 1
			if (descendant as Light3D).shadow_enabled:
				shadow_light_count += 1
		elif descendant is RigidBody3D:
			rigid_body_count += 1
	var average_fps := 1000.0 / maxf(0.001, average_frame_ms)
	var one_percent_low_fps := 1000.0 / maxf(0.001, one_percent_frame_ms)
	var peak_static_memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0
	var payload := {
		"criterion": "AC-ENG-03",
		"release_build": not OS.is_debug_build(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")),
		"godot_version": Engine.get_version_info(),
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"model_name": OS.get_model_name(),
		"processor_name": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"viewport": [get_viewport().size.x, get_viewport().size.y],
		"warmup_target_seconds": WARMUP_SECONDS,
		"warmup_elapsed_seconds": warmup_elapsed_seconds,
		"frames": frame_times_ms.size(),
		"average_fps": average_fps,
		"one_percent_low_fps": one_percent_low_fps,
		"median_frame_ms": frame_times_ms[frame_times_ms.size() / 2],
		"p99_frame_ms": frame_times_ms[frame_times_ms.size() - slow_count],
		"maximum_frame_ms": frame_times_ms.back(),
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"static_memory_peak_mb": peak_static_memory_mb,
		"render_objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_draw_calls_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"pressure_scene": {
			"hand_tile_counts": pressure.hand_counts,
			"meld_groups_per_seat": 4,
			"meld_tile_counts": pressure.meld_counts,
			"discard_counts": pressure.discard_counts,
			"reveal_opponents": true,
		},
		"static_contract": {
			"light_count": light_count,
			"shadow_casting_light_count": shadow_light_count,
			"rigid_body_count": rigid_body_count,
			"tile_material_cache": "SichuanTile3D.static.material_cache",
		},
		"thresholds": {
			"average_fps_min": 55.0,
			"one_percent_low_fps_min": 45.0,
			"static_memory_peak_mb_max": 1200.0,
			"light_count_max": 2,
			"shadow_casting_light_count_max": 1,
			"rigid_body_count_max": 0,
		},
	}
	payload["passed"] = bool(payload.release_build) \
		and payload.renderer == "metal" \
		and payload.rendering_method == "forward_plus" \
		and warmup_elapsed_seconds >= WARMUP_SECONDS - 0.1 \
		and frame_times_ms.size() == SAMPLE_FRAMES \
		and average_fps >= 55.0 \
		and one_percent_low_fps >= 45.0 \
		and peak_static_memory_mb <= 1200.0 \
		and light_count <= 2 \
		and shadow_light_count <= 1 \
		and rigid_body_count == 0
	var output_path := _output_path()
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write Stage 6 performance evidence: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	print(JSON.stringify(payload))
	get_tree().quit(0 if bool(payload.passed) else 1)


func _pressure_snapshot() -> Dictionary:
	var hands: Array = []
	var players: Array = []
	var hand_counts: Array[int] = []
	var meld_counts: Array[int] = []
	var discard_counts: Array[int] = []
	for seat in range(4):
		var hand := _tiles(81000 + seat * 100, 2, seat)
		var discards := _tiles(82000 + seat * 100, 18, seat + 1)
		var melds: Array = []
		var meld_tile_count := 0
		for meld_index in range(4):
			var tile_count := 4 if meld_index == 3 else 3
			melds.append({
				"type": "gang" if tile_count == 4 else "peng",
				"gang_subtype": "ming_gang" if tile_count == 4 else "",
				"from_seat": (seat + meld_index + 1) % 4,
				"tiles": _tiles(83000 + seat * 100 + meld_index * 10, tile_count, seat + meld_index),
			})
			meld_tile_count += tile_count
		hands.append(hand)
		players.append({
			"seat": seat,
			"has_won": false,
			"ding_que": ["wan", "tong", "tiao", "wan"][seat],
			"hand_tiles": hand if seat == 0 else [],
			"melds": melds,
			"discards": discards,
		})
		hand_counts.append(hand.size())
		meld_counts.append(meld_tile_count)
		discard_counts.append(discards.size())
	return {
		"hands": hands,
		"hand_counts": hand_counts,
		"meld_counts": meld_counts,
		"discard_counts": discard_counts,
		"snapshot": {
			"players": players,
			"wall_count": 8,
			"human_can_discard": true,
			"human_last_draw_tile_id": int(hands[0].back().get("id", -1)),
			"recent_discard_tile_id": int(players[3].discards.back().get("id", -1)),
		},
	}


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


func _all_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		result.append(current)
		for child in current.get_children():
			pending.append(child)
	return result


func _output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-output="):
			return argument.trim_prefix("--profile-output=")
	return "user://stage6_release_performance.json"
