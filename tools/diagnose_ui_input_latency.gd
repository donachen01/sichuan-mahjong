extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	for _frame in range(3):
		await process_frame
	var utility := scene.get("table_utility_bar") as TableUtilityBar
	var skin_panel := scene.get("table_skin_panel") as SichuanTableSkinPanel
	var voice_panel := scene.get("voice_select_panel") as SichuanVoiceSelectPanel
	var manager := scene.get("game_manager") as Node
	if utility == null or skin_panel == null or voice_panel == null or manager == null:
		push_error("Missing UI components for latency diagnosis")
		quit(1)
		return
	utility.set_collapsed(false)
	var skin_button := utility.get_button("skin")
	var miss := Vector2(-100.0, -100.0)
	var start := Time.get_ticks_usec()
	for _index in range(100):
		scene.call("_handle_table_utility_click", miss)
	var hit_test_us := float(Time.get_ticks_usec() - start) / 100.0
	start = Time.get_ticks_usec()
	for _index in range(20):
		utility.call("render", false, false, false, "骨灰", false, "mandarin")
	var unchanged_render_us := float(Time.get_ticks_usec() - start) / 20.0
	start = Time.get_ticks_usec()
	for _index in range(5):
		voice_panel.open("", "mandarin")
		voice_panel.close()
	var voice_open_us := float(Time.get_ticks_usec() - start) / 5.0
	start = Time.get_ticks_usec()
	for _index in range(5):
		skin_panel.open(SichuanTableSkinCatalog.DEFAULT_SKIN_ID)
		skin_panel.close()
	var skin_open_us := float(Time.get_ticks_usec() - start) / 5.0
	var snapshot: Dictionary = manager.call("get_snapshot")
	start = Time.get_ticks_usec()
	for _index in range(30):
		snapshot.duplicate(true)
	var snapshot_copy_us := float(Time.get_ticks_usec() - start) / 30.0
	start = Time.get_ticks_usec()
	for _index in range(3):
		scene.call("_update_3d_table", snapshot)
	var table_refresh_us := float(Time.get_ticks_usec() - start) / 3.0
	start = Time.get_ticks_usec()
	for _index in range(3):
		scene.call("_update_self_area", snapshot, manager.call("get_local_hand_tiles"))
	var self_area_us := float(Time.get_ticks_usec() - start) / 3.0
	var players: Array = snapshot.get("players", [])
	var self_player: Dictionary = scene.call("_player_by_seat", players, 0)
	var sections := {
		"seat_huds": _time_call(scene, "_update_seat_huds", [snapshot]),
		"top_bar": _time_call(scene, "_update_top_bar", [snapshot]),
		"center_area": _time_call(scene, "_update_center_area", [snapshot, players, self_player]),
		"action_panel": _time_call(scene, "_refresh_action_panel", [snapshot]),
		"ding_que": _time_call(scene, "_refresh_ding_que_panel", [snapshot]),
		"settlement": _time_call(scene, "_refresh_settlement", [snapshot]),
		"ai_tuning": _time_call(scene, "_refresh_ai_tuning_panel", [snapshot]),
		"round_result": _time_call(scene, "_refresh_round_result_overlay", [snapshot]),
		"action_layout": _time_call(scene, "_layout_table_action_bar", []),
		"opening_roll": _time_call(scene, "_refresh_opening_roll_ui", [snapshot]),
	}
	start = Time.get_ticks_usec()
	for _index in range(3):
		scene.call("_on_snapshot_changed", snapshot)
	var snapshot_us := float(Time.get_ticks_usec() - start) / 3.0
	var active_snapshot_us := -1.0
	var game_state := root.get_node_or_null("GameState")
	if game_state != null and not (game_state.get("players") as Array).is_empty():
		var state_players: Array = game_state.get("players")
		var first_player: Dictionary = state_players[0]
		first_player["ding_que"] = "tong"
		state_players[0] = first_player
		game_state.set("players", state_players)
		game_state.call("_auto_select_ai_ding_que")
		if bool(game_state.get("opening_roll_pending_completion")):
			game_state.call("complete_opening_roll")
		else:
			game_state.call("_complete_ding_que_if_ready")
		var active_snapshot: Dictionary = manager.call("get_fresh_snapshot")
		start = Time.get_ticks_usec()
		for _index in range(3):
			scene.call("_on_snapshot_changed", active_snapshot)
		active_snapshot_us = float(Time.get_ticks_usec() - start) / 3.0
	print("UI_LATENCY_CPU_US ", {
		"platform": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"utility_hit_test": hit_test_us,
		"unchanged_utility_render": unchanged_render_us,
		"voice_open": voice_open_us,
		"skin_open": skin_open_us,
		"snapshot_deep_copy": snapshot_copy_us,
		"table_refresh": table_refresh_us,
		"self_area_refresh": self_area_us,
		"snapshot_refresh": snapshot_us,
		"active_snapshot_refresh": active_snapshot_us,
		"section_cpu_us": sections,
		"skin_button_rect": skin_button.get_global_rect(),
	})
	scene.queue_free()
	await process_frame
	quit(0)


func _time_call(target: Object, method: String, arguments: Array, repetitions: int = 3) -> float:
	var start := Time.get_ticks_usec()
	for _index in range(repetitions):
		target.callv(method, arguments)
	return float(Time.get_ticks_usec() - start) / float(repetitions)
