extends SceneTree

const StateScript := preload("res://autoload/GameState.gd")
const ManagerScript := preload("res://scripts/ai/AIManager.gd")
var failures: Array[String] = []
var rows: Array = []

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	await process_frame
	var native = root.get_node("SichuanCSharpRuntime")
	var generation := 0
	for compact in [false, true]:
		for preserve_pairs in [false, true]:
			var state = _state(native, compact, preserve_pairs)
			generation += 1
			state.ai_agent_generation = generation
			_check(state._begin_round_agents(), "production seat-agent initialization")
			_check_physical(state)
			var decision: Dictionary = state._build_ai_self_action_decision(2, state._build_player_state(2), state._build_table_state())
			var expected := "discard" if preserve_pairs else "an_gang"
			_check(str(decision.get("action")) == expected, "real runtime decision compact=%s pairs=%s: %s" % [compact, preserve_pairs, decision])
			var planned := int(decision.get("analysis", {}).get("continuation_discard_tile", -1))
			var proposed := _proposal(state, native)
			_check(str(proposed.get("Action", "")) == ("Discard" if preserve_pairs else "Gang"), "agent tracks executable action")
			if preserve_pairs:
				_check(planned in [20, 23], "real Pass plans a singleton, not the quad")
				_check(int(proposed.get("Tile", -1)) == planned, "agent tracks planned discard tile")
				_check(state._sichuan_tile_type(state._tile_by_id_in_hand(2, int(decision.get("tile_id", -1)))) == planned, "planned discard survives transport and tile mapping")
			decision["seat"] = 2
			var executed: bool = state._execute_ai_turn_decision(decision)
			_check(executed, "authoritative execution: " + state.debug_last_message)
			var after_proposal := _proposal(state, native)
			if preserve_pairs:
				_check(after_proposal.get("Id") == proposed.get("Id") and str(after_proposal.get("Status", "")) == "executed", "agent confirms the same planned discard")
			else:
				_check(int(after_proposal.get("ViewVersion", 0)) > int(proposed.get("ViewVersion", 0)), "replacement starts a fresh decision from a newer view")
			if executed and preserve_pairs:
				_check(state._sichuan_tile_type(state.players[2]["discards"][-1]) == planned, "executed discard equals priced continuation")
				var counts := {}
				for tile in state.players[2]["hand_tiles"]:
					var t: int = state._sichuan_tile_type(tile)
					counts[t] = int(counts.get(t, 0)) + 1
				_check(int(counts.get(26, 0)) == 4, "retained four nines")
			elif executed:
				_check(state.players[2]["melds"].size() == 1 and str(state.players[2]["melds"][0].get("gang_subtype")) == "an_gang", "concealed gang actually executes")
				_check(state.settlement_data["gang_events"][0]["payer_seats"] == [0], "only remaining opponent pays")
				_check(str(state.last_turn_context.get("draw_reason")) == "gang_draw", "replacement draw executes")
			_check_physical(state)
			rows.append({"seat_agent_enabled": true, "compact_aot_protocol": compact, "preserve_pairs": preserve_pairs, "action": expected, "planned_discard": planned, "executed": executed, "proposal_before": proposed, "proposal_after": after_proposal})
			state._end_round_agents()
			state.free()
	var output := FileAccess.open("res://research/hand_review_20261018/decision_unification/game-contract-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope": "desktop Godot with real C# runtime; compact AOT transport exercised, not device NativeAOT", "passed": failures.is_empty(), "failures": failures, "rows": rows}, "  "))
	print("GAME_CONTINUATION cases=", rows.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _proposal(state, native) -> Dictionary:
	var payload: Dictionary = state.ai_manager.csharp_bridge.build_discard_transport_payload(state._build_player_state(2), state._build_table_state(), state.rules)
	var inspected = JSON.parse_string(str(native.call("InspectRoundAgentJson", JSON.stringify(payload))))
	return inspected.get("Proposal", {}) if inspected is Dictionary else {}

func _state(native, compact: bool, preserve_pairs: bool):
	var state = StateScript.new()
	state.rules = preload("res://scripts/core/rule_config.gd").new()
	state.mahjong_state = preload("res://scripts/core/mahjong_state.gd").new()
	state.mahjong_judge = preload("res://scripts/core/mahjong_judge.gd").new()
	state.ding_que_resolver = preload("res://scripts/core/ding_que_resolver.gd").new()
	state.score_resolver = preload("res://scripts/core/score_resolver.gd").new()
	state.ai_tuning_config = preload("res://scripts/core/ai_tuning_config.gd").new()
	state.hu_checker = preload("res://scripts/core/hu_checker.gd").new()
	state.ai_manager = ManagerScript.new()
	state.ai_manager.native_csharp_runtime = native
	state.ai_manager.force_mobile_aot_runtime_for_tests = compact
	state.human_trainer_hint_enabled = false
	state.round_index = 1
	state.current_dealer_seat = 2
	var pool: Array[Dictionary] = []
	for t in range(27):
		for copy in range(4):
			pool.append({"id": t * 4 + copy, "suit": ["tiao", "tong", "wan"][t / 9], "rank": t % 9 + 1, "sort_key": t, "display_name": str(t)})
	var tiles := [26,26,26,26,0,0,3,3,6,6,18,18,20,23] if preserve_pairs else [2,2,4,4,5,6,7,7,7,21,26,26,26,26]
	var own: Array = []
	for t in tiles:
		own.append(_take(pool, t))
	for seat in range(4):
		var player: Dictionary = state._create_player_state(seat, "P%d" % seat, seat == 2, 0)
		var hand: Array = own if seat == 2 else []
		if seat != 2:
			for i in range(13):
				hand.append(pool.pop_front())
		player["hand_tiles"] = hand
		player["hand_count"] = hand.size()
		player["ding_que"] = ["wan", "wan", "tong", "tiao"][seat]
		player["has_won"] = seat in [1, 3]
		state.players.append(player)
	state.wall = pool
	state.wall_count = pool.size()
	state.current_phase = 5
	state.current_turn_seat = 2
	state.settlement_data = state._create_empty_settlement_data()
	state.last_draw_tile = {"seat": 2, "tile": own[0] if preserve_pairs else own[-1]}
	state.last_turn_context = {"seat": 2, "draw_reason": "normal_draw"}
	return state

func _take(pool: Array, t: int) -> Dictionary:
	for i in range(pool.size()):
		if int(pool[i]["id"]) / 4 == t:
			var tile: Dictionary = pool[i]
			pool.remove_at(i)
			return tile
	assert(false, "unavailable tile")
	return {}

func _check_physical(state) -> void:
	var ids: Array = []
	for player in state.players:
		for tile in player["hand_tiles"] + player["discards"]:
			ids.append(int(tile["id"]))
		for meld in player["melds"]:
			for tile in meld["tiles"]:
				ids.append(int(tile["id"]))
	for tile in state.wall:
		ids.append(int(tile["id"]))
	var unique := {}
	for id in ids:
		unique[id] = true
	_check(ids.size() == 108 and unique.size() == 108, "physical 108-card conservation")
