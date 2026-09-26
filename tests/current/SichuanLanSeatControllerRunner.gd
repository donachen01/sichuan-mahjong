extends SceneTree

const GameStateScript := preload("res://autoload/GameState.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := GameStateScript.new()
	root.add_child(state)
	await process_frame
	assert(state.players.size() == 4)
	assert(not bool(state.players[0].is_ai))
	assert(bool(state.players[1].is_ai))

	for human_count in range(1, 5):
		var members: Array = []
		for seat in range(human_count):
			members.append({"seat": seat, "nickname": "真人%d" % (seat + 1), "player_id": "p%d" % seat})
		assert(state.configure_lan_members(members, true))
		assert(state.players.size() == 4)
		for seat in range(4):
			assert(bool(state.players[seat].is_ai) == (seat >= human_count))
			if seat < human_count:
				assert(state.players[seat].player_id == "p%d" % seat)

	assert(not state.configure_lan_members([{"seat": 0}, {"seat": 0}], false))
	assert(not state.configure_seat_controllers([{"seat": 4}], false))
	print("LAN_SEAT_CONTROLLER_PASS")
	state.queue_free()
	quit(0)
