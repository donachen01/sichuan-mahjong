extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const DRAW_TRAVEL_MS := 200
const DRAW_SETTLE_MS := 50


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var timeline: Array[Dictionary] = []
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	for timer in scene.find_children("*", "Timer", true, false):
		(timer as Timer).stop()

	var action_bar: Control = scene.get("table_action_bar")
	if action_bar == null:
		failures.append("TableActionBar missing")
	else:
		var snapshot := _gang_self_hu_snapshot()
		var started_ms := Time.get_ticks_msec()
		scene.call("_begin_draw_transition", 0, snapshot)
		scene.call("_refresh_table_action_bar", snapshot)
		await process_frame
		timeline.append(_timeline_entry("supplement_draw_started", started_ms, scene, action_bar))
		if action_bar.call("get_visible_actions") != []:
			failures.append("self-hu action appeared when supplement draw started")

		await create_timer(float(DRAW_TRAVEL_MS + DRAW_SETTLE_MS + 30) / 1000.0).timeout
		scene.call("_refresh_table_action_bar", snapshot)
		await process_frame
		timeline.append(_timeline_entry("draw_tile_landed", started_ms, scene, action_bar))
		if action_bar.call("get_visible_actions") != []:
			failures.append("self-hu action appeared before the draw transition release beat")
		if not bool(scene.get("draw_transition_active")):
			failures.append("draw transition released before its authoritative presentation timer")

		var transition_timer: Timer = scene.get("draw_transition_timer")
		if transition_timer == null:
			failures.append("draw transition timer missing")
		else:
			while bool(scene.get("draw_transition_active")) and Time.get_ticks_msec() - started_ms < 1400:
				await create_timer(0.02).timeout
			scene.call("_refresh_table_action_bar", snapshot)
			await process_frame
			timeline.append(_timeline_entry("self_hu_actions_released", started_ms, scene, action_bar))
			var visible_actions: Array[String] = action_bar.call("get_visible_actions")
			if bool(scene.get("draw_transition_active")):
				failures.append("draw transition did not release after the 1.0s presentation timer")
			if visible_actions != ["hu", "pass"]:
				failures.append("self-hu actions were not released after supplement draw settled: %s" % [visible_actions])
			var hu_button: Button = action_bar.call("get_button", "hu")
			if hu_button == null or hu_button.text != "自摸" or hu_button.disabled:
				failures.append("released hu action is not an enabled 自摸 button")
			var release_ms := Time.get_ticks_msec() - started_ms
			if release_ms < DRAW_TRAVEL_MS + DRAW_SETTLE_MS:
				failures.append("self-hu action released before draw travel+settle completed: %dms" % release_ms)

	scene.queue_free()
	await process_frame
	await process_frame
	_write_timeline(timeline, failures)
	if failures.is_empty():
		print("SICHUAN GANG SELF-HU SEQUENCE OK")
		quit(0)
		return
	push_error("SICHUAN GANG SELF-HU SEQUENCE FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _gang_self_hu_snapshot() -> Dictionary:
	var players: Array[Dictionary] = []
	for seat in range(4):
		players.append({"seat": seat, "has_won": false})
	return {
		"players": players,
		"current_phase": 3,
		"current_turn_seat": 0,
		"human_can_discard": true,
		"human_can_self_hu": true,
		"human_can_add_gang": false,
		"human_can_an_gang": false,
		"human_reaction_options": {},
		"recent_discard_display": "-",
	}


func _timeline_entry(event: String, started_ms: int, scene: Node, action_bar: Control) -> Dictionary:
	return {
		"event": event,
		"elapsed_ms": Time.get_ticks_msec() - started_ms,
		"draw_transition_active": bool(scene.get("draw_transition_active")),
		"visible_actions": action_bar.call("get_visible_actions"),
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
		failures.append("could not write gang self-hu sequence evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify({
		"criterion": "AC-HAND-04",
		"scenario": "supplement_draw_then_gang_self_hu",
		"draw_travel_contract_ms": DRAW_TRAVEL_MS,
		"draw_settle_contract_ms": DRAW_SETTLE_MS,
		"action_release_contract_ms": 1000,
		"timeline": timeline,
		"objective_result": "PASS" if failures.is_empty() else "FAIL",
	}, "  "))
