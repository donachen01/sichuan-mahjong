extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var table := MAIN_SCENE.instantiate()
	get_root().add_child(table)
	for _frame in range(5):
		await process_frame

	var manager: Node = table.get("game_manager")
	var state: Node = manager.get("game_state") if manager != null else null
	var action_bar: Control = table.get("table_action_bar")
	for timer in table.find_children("*", "Timer", true, false):
		(timer as Timer).stop()
	table.set("draw_transition_active", false)
	if state == null or action_bar == null:
		failures.append("完整主场景没有创建 GameState 或 TableActionBar")
	else:
		await _verify_live_peng_click(table, manager, state, action_bar, failures)
		await _verify_live_gang_click(table, manager, state, action_bar, failures)

	table.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SICHUAN LIVE REACTION CLICK OK")
		quit(0)
		return
	push_error("SICHUAN LIVE REACTION CLICK FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_live_peng_click(table: Node, manager: Node, state: Node, action_bar: Control, failures: Array[String]) -> void:
	_install_reaction_state(state, false)
	_publish_test_snapshot(table, manager, state)
	for _frame in range(4):
		await process_frame
	var button: Button = action_bar.call("get_button", "peng")
	if button == null or not button.visible or button.disabled:
		failures.append("完整主场景没有显示可点击的碰按钮 state=%s visible=%s" % [
			state.call("get_human_reaction_options", 0),
			action_bar.call("get_visible_actions"),
		])
		return
	await _click_at(button.get_global_rect().get_center())
	var players: Array = state.get("players")
	if players[0].get("melds", []).is_empty() or str(players[0]["melds"][0].get("type", "")) != "peng":
		failures.append("完整主场景真实鼠标点击碰后没有生成碰副露")


func _verify_live_gang_click(table: Node, manager: Node, state: Node, action_bar: Control, failures: Array[String]) -> void:
	_install_reaction_state(state, true)
	_publish_test_snapshot(table, manager, state)
	for _frame in range(4):
		await process_frame
	var button: Button = action_bar.call("get_button", "gang")
	if button == null or not button.visible or button.disabled:
		failures.append("完整主场景没有显示可点击的杠按钮 state=%s visible=%s" % [
			state.call("get_human_reaction_options", 0),
			action_bar.call("get_visible_actions"),
		])
		return
	await _click_at(button.get_global_rect().get_center())
	var players: Array = state.get("players")
	if players[0].get("melds", []).is_empty() or str(players[0]["melds"][0].get("type", "")) != "gang":
		failures.append("完整主场景真实鼠标点击杠后没有生成杠副露")


func _install_reaction_state(state: Node, can_gang: bool) -> void:
	var discarded := _tile(900, "tong", 5)
	var human_hand: Array = [
		_tile(1, "tong", 5),
		_tile(2, "tong", 5),
		_tile(3, "wan", 1),
	]
	if can_gang:
		human_hand.insert(2, _tile(4, "tong", 5))
	var players: Array[Dictionary] = [
		_player(0, false, "tiao", human_hand),
		_player(1, true, "wan", []),
		_player(2, true, "wan", []),
		_player(3, true, "wan", []),
	]
	players[1]["discards"] = [discarded.duplicate(true)]
	state.set("players", players)
	state.set("current_phase", 6)
	state.set("current_turn_seat", 1)
	state.set("current_dealer_seat", 0)
	state.set("current_discard_context", {
		"source_seat": 1,
		"tile": discarded.duplicate(true),
		"reaction_type": "discard",
	})
	state.set("discard_pile", [{"seat": 1, "tile": discarded.duplicate(true)}])
	var pending: Array[Dictionary] = [{
		"seat": 0,
		"can_hu": false,
		"can_gang": can_gang,
		"can_peng": true,
	}]
	state.set("pending_reactions", pending)
	state.set("wall", [_tile(999, "wan", 9)])
	state.set("wall_count", 1)
	state.set("last_draw_tile", {})
	state.call("_clear_pending_ai_async_state")


func _publish_test_snapshot(table: Node, manager: Node, state: Node) -> void:
	# Publish the exact installed reaction snapshot without restarting the
	# scene's normal AI/timer pipeline.  The subsequent input still travels
	# through the real MainScene -> GameManager -> GameState path.
	var snapshot: Dictionary = state.call("get_debug_snapshot")
	manager.set("latest_snapshot", snapshot.duplicate(true))
	table.call("_on_snapshot_changed", snapshot)


func _click_at(global_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	get_root().push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = global_position
	press.global_position = global_position
	get_root().push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_position
	release.global_position = global_position
	get_root().push_input(release, true)
	await process_frame
	await process_frame


func _player(seat: int, is_ai: bool, ding_que: String, hand: Array) -> Dictionary:
	return {
		"seat": seat,
		"nickname": ["陈旭", "舒小燕", "陈东", "舒玲"][seat],
		"score": 0,
		"is_ai": is_ai,
		"hand_tiles": hand.duplicate(true),
		"hand_count": hand.size(),
		"melds": [],
		"discards": [],
		"ding_que": ding_que,
		"has_won": false,
	}


func _tile(id: int, suit: String, rank: int) -> Dictionary:
	return {
		"id": id,
		"suit": suit,
		"rank": rank,
		"sort_key": ["tiao", "tong", "wan"].find(suit) * 100 + rank,
		"display_name": "%d%s" % [rank, {"tiao": "条", "tong": "筒", "wan": "万"}.get(suit, "?")],
	}
