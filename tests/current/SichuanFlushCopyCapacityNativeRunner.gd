extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = root.get_node("GameState")
	var pool: Array[Dictionary] = []
	for t in range(27):
		for copy in range(4):
			pool.append({"id": t * 4 + copy, "suit": ["tiao", "tong", "wan"][t / 9], "rank": t % 9 + 1, "sort_key": t, "display_name": str(t)})
	var hand: Array = []
	for t in [0, 0, 10, 11, 17]:
		hand.append(_take(pool, t))
	var melds: Array = []
	for t in [3, 4, 5]:
		var tiles: Array = []
		for i in range(3):
			tiles.append(_take(pool, t))
		melds.append({"type": "peng", "from_seat": 1, "tiles": tiles})
	var discards: Array = []
	for i in range(pool.size() - 1, -1, -1):
		if str(pool[i]["suit"]) == "tiao":
			discards.append(pool[i])
			pool.remove_at(i)
	var players: Array[Dictionary] = []
	for seat in range(4):
		var tiles: Array = hand if seat == 0 else []
		if seat > 0:
			for i in range(13):
				tiles.append(pool.pop_front())
		players.append({"seat": seat, "nickname": "P%d" % seat, "score": 0, "is_ai": false, "has_won": false, "ding_que": "wan" if seat == 0 else "tiao", "hand_tiles": tiles, "hand_count": tiles.size(), "melds": melds if seat == 0 else [], "discards": discards if seat == 3 else []})
	game.players = players
	game.wall = pool
	game.wall_count = pool.size()
	game.current_phase = 5
	game.current_turn_seat = 0
	game.last_draw_tile = {"seat": 0, "tile": hand.back()}
	game.last_turn_context = {"seat": 0, "draw_reason": "normal_draw"}
	var bridge = preload("res://scripts/ai/csharp_ai_bridge.gd").new()
	var q: Dictionary = bridge.build_discard_transport_payload(game._build_player_state(0), game._build_table_state(), game.rules)
	q["roundId"] = ""
	q["compactResult"] = false
	var failures: Array = []
	var unseen := 0
	for t in range(9):
		unseen += int(q["remaining18"][t])
	if unseen != 0 or pool.size() != 30:
		failures.append("physical capacity fixture not intact")
	var runtime = root.get_node("SichuanCSharpRuntime")
	var result = JSON.parse_string(str(runtime.call("AnalyzeDiscardJson", JSON.stringify(q))))
	var plan: Dictionary = result.get("routePlan", {})
	if not bool(result.get("ok", false)):
		failures.append("actual Native failed")
	for key in plan.get("routeWeights", {}):
		if key in ["清一色", "清对", "清七对", "青龙七对"]:
			failures.append("unreachable flush still available in Native: " + str(key))
	if not JSON.stringify(plan.get("reasons", [])).contains("FLUSH_READY_COPY_CAPACITY"):
		failures.append("Native capacity exit explanation missing")
	var row := {"passed": failures.is_empty(), "failures": failures, "wall_count": pool.size(), "available_target": 11, "minimum_ready": 13, "route_plan": plan, "action": result.get("action"), "tile_type": result.get("tileType"), "grounding": "new synthetic physical108-copy GameState -> public bridge -> real Native; no original-world or strength claim"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var f := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			f.store_string(JSON.stringify(row, "  "))
	print("FLUSH_COPY_NATIVE ", JSON.stringify(row))
	quit(0 if failures.is_empty() else 1)

func _take(pool: Array, t: int) -> Dictionary:
	for i in range(pool.size()):
		if int(pool[i]["id"]) / 4 == t:
			var tile: Dictionary = pool[i]
			pool.remove_at(i)
			return tile
	assert(false, "tile unavailable")
	return {}
