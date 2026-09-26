extends SceneTree

const Manager := preload("res://scripts/game/GameManager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sent := {"items": []}
	var manager = Manager.new()
	root.add_child(manager)
	await process_frame
	assert(manager.configure_network_client(2, func(command: String, arguments: Dictionary):
		sent.items.append([command, arguments.duplicate(true)])
		return true))
	var snapshot := {
		"schema_version": 1,
		"local_seat_id": 0,
		"players": [{"seat": 0, "hand_tiles": [{"id": 77}]}, {"seat": 1, "hand_count": 13}],
		"human_ding_que_options": ["tiao", "tong", "wan"],
		"settlement_data": {"score_changes": {"0": -4, "1": 8, "2": -2, "3": -2}, "preapplied_score_changes": {"0": -1, "1": 3, "2": -1, "3": -1}},
		"own_actions": {"can_add_gang": true, "can_an_gang": false, "reaction": {"can_peng": true}},
	}
	assert(manager.apply_private_snapshot(snapshot))
	manager._on_state_changed({"players": [{"seat": 0, "hand_tiles": [{"id": 999}]}]})
	assert(manager.get_local_hand_tiles()[0].id == 77)
	assert(manager.get_snapshot().settlement_data.score_changes == {0: -4, 1: 8, 2: -2, 3: -2})
	assert(manager.get_human_reaction_options().can_peng)
	assert(manager.get_local_ding_que_options() == ["tiao", "tong", "wan"])
	assert(manager.can_human_add_gang() and not manager.can_human_an_gang())
	assert(not manager.is_ai_turn_ready() and not manager.run_ai_turn())
	assert(manager.discard_tile(77))
	assert(not bool(manager.get_snapshot().get("human_can_discard", true)))
	manager.apply_network_command_result({"ok": false, "sequence": 1, "error": "ILLEGAL_ACTION"})
	assert(manager.get_local_hand_tiles()[0].id == 77)
	assert(manager.choose_ding_que("wan"))
	manager.apply_network_command_result({"ok": true, "sequence": 2, "error": ""})
	assert(manager.apply_private_snapshot(snapshot))
	assert(manager.execute_action("peng"))
	assert(manager.get_human_reaction_options().is_empty())
	assert(sent.items == [["discard", {"tile_id": 77}], ["ding_que", {"suit": "wan"}], ["action", {"action": "peng"}]])
	print("CLIENT_GAME_MANAGER_PASS")
	manager.queue_free()
	quit(0)
