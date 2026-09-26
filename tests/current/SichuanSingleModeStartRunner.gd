extends SceneTree

const MODE_SCENE := preload("res://scenes/network/GameModeSelect.tscn")
const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime := root.get_node("LanRuntime")
	runtime.leave_room()
	var state := root.get_node("GameState")
	var controllers := [
		{"seat": 0, "nickname": "旧房主", "is_ai": false, "player_id": "old-host"},
		{"seat": 1, "nickname": "旧电脑一", "is_ai": true, "player_id": ""},
		{"seat": 2, "nickname": "旧电脑二", "is_ai": true, "player_id": ""},
		{"seat": 3, "nickname": "旧电脑三", "is_ai": true, "player_id": ""},
	]
	assert(state.prepare_lan_table(controllers))
	assert(state.players.size() == 4 and state.wall_count == 0)
	var mode := MODE_SCENE.instantiate()
	root.add_child(mode)
	current_scene = mode
	await process_frame
	mode._choose_single()
	assert(state.seat_controllers.is_empty())
	assert(state.round_index == 1 and state.wall_count == 108)
	assert(state.opening_roll_pending_completion)
	for seat in range(4):
		assert(str(state.players[seat].nickname) == ["玩家", "电脑一", "电脑二", "电脑三"][seat])
	await process_frame
	await process_frame
	var table := current_scene
	assert(table != null and table.scene_file_path == "res://scenes/table/MainSceneV2.tscn")
	assert(table.opening_roll_commit_timer.time_left > 0.0)
	table._on_opening_roll_commit_timer_timeout()
	assert(not state.opening_roll_pending_completion)
	assert(int(state.current_phase) != int(GAME_STATE_SCRIPT.RoundPhase.TABLE_SETUP))
	var dealt := 0
	for seat in range(4):
		dealt += state.get_player_hand_tiles(seat).size()
	assert(dealt == 53)
	print("SINGLE_MODE_START_PASS")
	quit(0)
