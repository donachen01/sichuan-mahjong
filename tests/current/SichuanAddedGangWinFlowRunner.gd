extends SceneTree

const STATE := preload("res://autoload/GameState.gd")
const MAIN := preload("res://scenes/table/MainSceneV2.tscn")
var failures: Array[String] = []
var rows: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := MAIN.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for timer in scene.find_children("*", "Timer", true, false):
		timer.stop()
	var native = root.get_node("SichuanCSharpRuntime")
	var bridge = preload("res://scripts/ai/csharp_ai_bridge.gd").new()
	for groups in [1, 3, 4]:
		for last_tile in [false, true]:
			for cancel_rob in [false, true]:
				var state = _state(groups, last_tile, cancel_rob)
				_check_physical_tiles(state)
				var manager = scene.get("game_manager")
				manager.set("game_state", state)
				manager.set("latest_snapshot", {})
				# Independent fixture: end the previous case's next-seat draw animation.
				scene.call("_clear_draw_transition_block", "new_independent_fixture")
				state.state_changed.connect(manager._on_state_changed)
				scene.call("_on_snapshot_changed", manager.get_fresh_snapshot())
				await process_frame
				var before_gang_button: Button = scene.get("table_action_bar").get_button("gang")
				_check(before_gang_button.is_visible_in_tree(), "real supplement gang button")
				_check(bool(scene.call("_handle_table_action_click", before_gang_button.get_global_rect().get_center(), "direct")), "actual button submits add gang")
				_check(state.players[0]["melds"][0]["type"] == "gang" or not state.pending_qiang_gang_context.is_empty(), "add gang executes from UI")
				if cancel_rob:
					_check(state.current_phase == 6 and state.pending_reactions.size() == 1, "real rob window")
					_check(state.pass_human_reaction(1), "rob cancelled")
				_check_physical_tiles(state)
				_check(state.can_human_self_hu(0), "actual supplement hand can hu")
				_check(str(state.last_turn_context.get("draw_reason")) == "gang_draw", "actual gang draw context")
				var snapshot: Dictionary = manager.get_fresh_snapshot()
				_check(bool(snapshot.get("human_can_self_hu", false)), "snapshot grants hu")
				var player: Dictionary = state._build_player_state(0)
				var payload: Dictionary = bridge.build_self_action_transport_payload(player, state._build_table_state(), state.rules, state.can_human_self_hu(0), [], [])
				var answer: String = str(native.call("AnalyzeSelfActionAotCompact", JSON.stringify(payload)))
				_check(answer.begins_with("ok|hu|"), "real native self action: " + answer.left(100))
				scene.call("_begin_draw_transition", 0, snapshot)
				scene.call("_refresh_table_action_bar", snapshot)
				await process_frame
				var bar = scene.get("table_action_bar")
				_check(bar.get_visible_actions().has("hu") and bar.get_visible_actions().has("pass"), "hu/cancel available during interrupted animation")
				scene.get("draw_transition_timer").stop()
				scene.call("_on_snapshot_changed", snapshot)
				await process_frame
				_check(bar.get_visible_actions().has("hu") and bar.get_visible_actions().has("pass"), "hu/cancel after stopped animation")
				var winning_id: int = state._get_last_draw_tile_id_for_seat(0)
				_check(state.pass_human_self_hu(0), "cancel offered hu")
				_check(not state.can_human_self_hu(0) and state.can_human_discard(0), "cancel locks this draw, allows discard")
				# Reload identical physical state to exercise accept rather than the cancelled path.
				state.free()
				state = _state(groups, last_tile, cancel_rob)
				_check(state.execute_human_add_gang(0), "second add gang")
				if cancel_rob:
					_check(state.pass_human_reaction(1), "second rob cancel")
				manager.set("game_state", state)
				state.state_changed.connect(manager._on_state_changed)
				scene.call("_on_snapshot_changed", manager.get_fresh_snapshot())
				await process_frame
				var hu_button: Button = bar.get_button("hu")
				_check(hu_button.is_visible_in_tree() and not hu_button.disabled, "actual enabled Hu button")
				_check(bool(scene.call("_handle_table_action_click", hu_button.get_global_rect().get_center(), "direct")), "actual Hu click dispatch")
				_check(bool(state.players[0]["has_won"]), "accept authoritative hu via UI")
				_check_physical_tiles(state)
				_check(state.players[0].get("win_type") == "gang_self_draw", "accepted gang flower")
				rows.append({"groups": groups, "last_wall_tile": last_tile, "rob_cancel": cancel_rob, "winning_id": winning_id, "native_action": answer.get_slice("|", 1)})
				manager.set("game_state", root.get_node("GameState"))
				state.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var f := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "rows": rows}, "  "))
	print("ADDED_GANG_WIN_FLOW cases=", rows.size(), " failures=", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _check_physical_tiles(state) -> void:
	var ids: Array = []
	for tile in state.wall:
		ids.append(int(tile["id"]))
	for player in state.players:
		_check(int(player["hand_count"]) == Array(player["hand_tiles"]).size(), "hand count matches actual cards")
		for tile in player["hand_tiles"]:
			ids.append(int(tile["id"]))
		for meld in player["melds"]:
			for tile in meld["tiles"]:
				ids.append(int(tile["id"]))
		for tile in player["discards"]:
			ids.append(int(tile["id"]))
	ids.sort()
	_check(ids == range(108), "108 distinct physical cards remain conserved")

func _state(groups: int, last_tile: bool, cancel_rob: bool):
	var state = STATE.new()
	state.rules = preload("res://scripts/core/rule_config.gd").new()
	state.mahjong_state = preload("res://scripts/core/mahjong_state.gd").new()
	state.mahjong_judge = preload("res://scripts/core/mahjong_judge.gd").new()
	state.ding_que_resolver = preload("res://scripts/core/ding_que_resolver.gd").new()
	state.score_resolver = preload("res://scripts/core/score_resolver.gd").new()
	state.ai_tuning_config = preload("res://scripts/core/ai_tuning_config.gd").new()
	state.hu_checker = preload("res://scripts/core/hu_checker.gd").new()
	state.human_trainer_hint_enabled = false
	var pool: Array[Dictionary] = []
	for t in range(27):
		for copy in range(4):
			pool.append({"id": t * 4 + copy, "suit": ["tiao", "tong", "wan"][t / 9], "rank": t % 9 + 1, "sort_key": t, "display_name": "%d%s" % [t % 9 + 1, ["条", "筒", "万"][t / 9]]})
	var peng: Array = []
	for i in range(3):
		peng.append(_take(pool, 9))
	var own: Array = [_take(pool, 9)]
	var melds: Array = [{"type": "peng", "from_seat": 1, "tiles": peng}]
	for g in range(groups - 1):
		var quad: Array = []
		for i in range(4):
			quad.append(_take(pool, 12 + g))
		melds.append({"type": "gang", "from_seat": 0, "gang_subtype": "an_gang", "tiles": quad})
	for t in range(18, 18 + (4 - groups) * 3):
		own.append(_take(pool, t))
	own.append(_take(pool, 15))
	var replacement := _take(pool, 15)
	for seat in range(4):
		var hand: Array = own if seat == 0 else []
		if seat == 1 and cancel_rob:
			for t in [10, 11, 18, 19, 20, 21, 22, 23, 24, 25, 26, 25, 25]:
				hand.append(_take(pool, t))
		elif seat > 0:
			for i in range(13):
				hand.append(pool.pop_front())
		state.players.append({"seat": seat, "nickname": "P%d" % seat, "is_ai": false, "score": 0, "ding_que": "tiao" if seat == 0 or (seat == 1 and cancel_rob) else "tong", "has_won": false, "melds": melds if seat == 0 else [], "hand_tiles": hand, "hand_count": hand.size(), "discards": []})
	if last_tile:
		# Unseen remainder is historical discards, not silently removed copies.
		for tile in pool:
			state.players[3]["discards"].append(tile)
		pool.clear()
	pool.append(replacement)
	state.wall = pool
	state.wall_count = pool.size()
	state.current_phase = 5
	state.current_turn_seat = 0
	state.settlement_data = state._create_empty_settlement_data()
	state.last_draw_tile = {"seat": 0, "tile": own[0]}
	state.last_turn_context = {"seat": 0, "draw_reason": "normal_draw"}
	state.self_hu_pass_locks["0"] = int(own[0]["id"])
	return state

func _take(pool: Array, t: int) -> Dictionary:
	for i in range(pool.size()):
		if int(pool[i]["id"]) / 4 == t:
			var tile: Dictionary = pool[i]
			pool.remove_at(i)
			return tile
	assert(false, "unavailable tile type %d" % t)
	return {}
