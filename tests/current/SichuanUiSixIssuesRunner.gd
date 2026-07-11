extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var root_node := MAIN_SCENE.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame

	var game_manager = root_node.game_manager
	var game_state = game_manager.game_state
	await _advance_to_ding_que_after_opening_roll(root_node, game_state)

	_check_issue_3_and_4(root_node, game_state, failures)
	await _check_issue_1_and_2(root_node, game_state, failures)
	_check_issue_5(root_node, failures)
	_check_issue_6(root_node, failures)

	if failures.is_empty():
		print("VERIFY SIX ISSUES OK: 6/6")
		quit(0)
		return

	push_error("VERIFY SIX ISSUES FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _advance_to_ding_que_after_opening_roll(root_node: Node, game_state) -> void:
	if int(game_state.current_phase) != int(GAME_STATE_SCRIPT.RoundPhase.TABLE_SETUP):
		return
	if bool(game_state.opening_roll_pending_completion):
		game_state.complete_opening_roll()
		await process_frame
		root_node._on_snapshot_changed(game_state.get_debug_snapshot())
		await process_frame


func _check_issue_3_and_4(root_node: Node, game_state, failures: Array[String]) -> void:
	if int(game_state.current_phase) != int(GAME_STATE_SCRIPT.RoundPhase.DING_QUE):
		failures.append("问题3：开局阶段不是定缺阶段，当前 phase=%s" % [game_state.current_phase])

	if not bool(game_state.is_human_ding_que_pending(0)):
		failures.append("问题3：开局时本家没有处于待选缺门状态")

	if not root_node.ding_que_overlay.visible:
		failures.append("问题3：开局缺门选择界面没有显示")

	if root_node.left_ui.identity_ding_que_label.visible:
		failures.append("问题4：本家未选缺门前，上家缺门已可见")
	if root_node.top_ui.identity_ding_que_label.visible:
		failures.append("问题4：本家未选缺门前，对家缺门已可见")
	if root_node.right_ui.identity_ding_que_label.visible:
		failures.append("问题4：本家未选缺门前，下家缺门已可见")


func _check_issue_1_and_2(root_node: Node, game_state, failures: Array[String]) -> void:
	var choose_ok := await _click_ding_que_button(root_node, game_state, "tong")
	if not choose_ok:
		failures.append("问题3补充：定缺按钮命中路径无法完成本家定缺；%s" % _ding_que_click_debug(root_node, game_state))
		return
	if root_node.ding_que_overlay.visible:
		failures.append("问题3补充：本家点选定缺后，定缺面板仍未关闭")
	if not root_node.left_ui.identity_ding_que_label.visible:
		failures.append("问题4补充：本家选缺后，上家缺门仍不可见")
	if not root_node.top_ui.identity_ding_que_label.visible:
		failures.append("问题4补充：本家选缺后，对家缺门仍不可见")
	if not root_node.right_ui.identity_ding_que_label.visible:
		failures.append("问题4补充：本家选缺后，下家缺门仍不可见")

	var players: Array = game_state.players
	for seat in [1, 2, 3]:
		players[seat]["hand_count"] = 13
		players[seat]["discards"] = _make_discards_for_seat(seat, 8)
	game_state.players = players

	var snapshot: Dictionary = game_state.get_debug_snapshot()
	root_node._on_snapshot_changed(snapshot)
	await process_frame
	await process_frame

	var board_core_rect: Rect2 = root_node.board_core.get_global_rect()
	for lane in [root_node.board_left_lane, root_node.board_right_lane]:
		for child in lane.get_children():
			if child is Control:
				var tile_rect := (child as Control).get_global_rect()
				if tile_rect.intersects(board_core_rect):
					failures.append("问题1：左右弃牌仍侵入中心骰子保留区")
					return

	var top_rect: Rect2 = root_node.top_ui.hand_lane.get_global_rect()
	var left_rect: Rect2 = root_node.left_ui.hand_lane.get_global_rect()
	var right_rect: Rect2 = root_node.right_ui.hand_lane.get_global_rect()
	if top_rect.intersects(left_rect):
		failures.append("问题2：上家与对家手牌区域仍有重叠")
	if top_rect.intersects(right_rect):
		failures.append("问题2：下家与对家手牌区域仍有重叠")


func _check_issue_5(root_node: Node, failures: Array[String]) -> void:
	var previous_players := [_minimal_player(0), _minimal_player(1), _minimal_player(2), _minimal_player(3)]
	var current_players := [_minimal_player(0), _minimal_player(1), _minimal_player(2), _minimal_player(3)]
	current_players[1]["melds"] = [
		{
			"type": "gang",
			"from_seat": 0,
			"tiles": [
				_make_tile(900, "wan", 9),
				_make_tile(901, "wan", 9),
				_make_tile(902, "wan", 9),
				_make_tile(903, "wan", 9),
			],
		},
	]

	root_node.action_voice_player.stream = null
	root_node._play_new_meld_voice(previous_players, current_players)
	if root_node.action_voice_player.stream == null:
		failures.append("问题5：新增杠副露时，杠音效链路没有被触发")


func _check_issue_6(root_node: Node, failures: Array[String]) -> void:
	var left_ui = root_node.left_ui
	var top_ui = root_node.top_ui
	var right_ui = root_node.right_ui

	if left_ui._claim_arrow_text(1, 2) != "↑对家":
		failures.append("问题6：左侧玩家来自对家的碰杠箭头文案错误")
	if left_ui._claim_arrow_text(1, 0) != "↓本家":
		failures.append("问题6：左侧玩家来自本家的碰杠箭头文案错误")
	if top_ui._claim_arrow_text(2, 1) != "←上家":
		failures.append("问题6：顶部玩家来自上家的碰杠箭头文案错误")
	if right_ui._claim_arrow_text(3, 2) != "↑对家":
		failures.append("问题6：右侧玩家来自对家的碰杠箭头文案错误")

	if abs(left_ui._claim_arrow_rotation("←上家") + PI * 0.5) > 0.01:
		failures.append("问题6：左箭头旋转仍不正确")
	if abs(right_ui._claim_arrow_rotation("→下家") - PI * 0.5) > 0.01:
		failures.append("问题6：右箭头旋转仍不正确")
	if abs(top_ui._claim_arrow_rotation("↑对家")) > 0.01:
		failures.append("问题6：上箭头旋转仍不正确")


func _click_ding_que_button(root_node: Node, game_state, suit: String) -> bool:
	root_node._on_snapshot_changed(game_state.get_debug_snapshot())
	await process_frame
	await process_frame
	var button: Button = null
	match suit:
		"tiao":
			button = root_node.ding_que_tiao_button
		"tong":
			button = root_node.ding_que_tong_button
		"wan":
			button = root_node.ding_que_wan_button
	if button == null:
		return false
	if not root_node.ding_que_overlay.visible or not button.visible or button.disabled:
		return false
	var rect := button.get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return false
	await _send_mouse_click(rect.get_center())
	await process_frame
	await process_frame
	if str(game_state.players[0].get("ding_que", "")) != suit and root_node.has_method("_handle_ding_que_overlay_click"):
		root_node.call("_handle_ding_que_overlay_click", rect.get_center())
		await process_frame
		await process_frame
	return str(game_state.players[0].get("ding_que", "")) == suit


func _ding_que_click_debug(root_node: Node, game_state) -> String:
	var button: Button = root_node.ding_que_tong_button
	var overlay_rect: Rect2 = root_node.ding_que_overlay.get_global_rect()
	var button_rect: Rect2 = button.get_global_rect()
	var action_rect: Rect2 = root_node.action_panel.get_global_rect() if root_node.action_panel.visible else Rect2()
	return "phase=%s pending=%s overlay_visible=%s overlay_rect=%s overlay_mouse=%s overlay_top=%s overlay_z=%s button_visible=%s button_disabled=%s button_rect=%s action_visible=%s action_rect=%s chosen=%s" % [
		str(game_state.current_phase),
		str(game_state.is_human_ding_que_pending(0)),
		str(root_node.ding_que_overlay.visible),
		str(overlay_rect),
		str(root_node.ding_que_overlay.mouse_filter),
		str(root_node.ding_que_overlay.top_level),
		str(root_node.ding_que_overlay.z_index),
		str(button.visible),
		str(button.disabled),
		str(button_rect),
		str(root_node.action_panel.visible),
		str(action_rect),
		str(game_state.players[0].get("ding_que", "")),
	]


func _send_mouse_click(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	get_root().push_input(press)
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	get_root().push_input(release)
	Input.parse_input_event(release)


func _make_discards_for_seat(seat: int, count: int) -> Array:
	var suit_cycle := ["wan", "tong", "tiao"]
	var tiles: Array = []
	for index in range(count):
		var suit: String = str(suit_cycle[(seat + index) % suit_cycle.size()])
		var rank := (index % 9) + 1
		tiles.append(_make_tile(seat * 100 + index, suit, rank))
	return tiles


func _make_tile(id_value: int, suit: String, rank: int) -> Dictionary:
	return {
		"id": id_value,
		"suit": suit,
		"rank": rank,
		"sort_key": ["tiao", "tong", "wan"].find(suit) * 100 + rank,
		"display_name": "%d%s" % [rank, _suit_label(suit)],
	}


func _suit_label(suit: String) -> String:
	match suit:
		"wan":
			return "万"
		"tong":
			return "筒"
		"tiao":
			return "条"
		_:
			return "?"


func _minimal_player(seat: int) -> Dictionary:
	return {
		"seat": seat,
		"nickname": "Seat%d" % seat,
		"score": 1000,
		"hand_count": 13,
		"ding_que": "",
		"melds": [],
		"discards": [],
		"has_won": false,
		"winning_tile": {},
		"winning_source_seat": seat,
		"win_type": "",
	}
