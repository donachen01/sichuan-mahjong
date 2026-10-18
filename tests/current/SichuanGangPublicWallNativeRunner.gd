extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = root.get_node("GameState")
	var runtime = root.get_node("SichuanCSharpRuntime")
	var bridge = preload("res://scripts/ai/csharp_ai_bridge.gd").new()
	var expect_rebuilt := not "--expect-rebuilt=false" in OS.get_cmdline_user_args()
	var rows: Array = []
	for rotation in range(3):
		var pool: Array[Dictionary] = []
		for t in range(27):
			for copy in range(4):
				pool.append({"id": t * 4 + copy, "suit": ["tiao", "tong", "wan"][t / 9], "rank": t % 9 + 1,
					"sort_key": t, "display_name": str(t)})
		var own: Array = []
		for t in [0, 0, 0, 0, 2, 2, 2, 3, 4, 5, 5, 6, 7, 15]:
			own.append(_take(pool, (t + rotation * 9) % 27))
		var wall: Array[Dictionary] = []
		for t in [2, 7, 10, 19, 25]:
			wall.append(_take(pool, (t + rotation * 9) % 27))
		var players: Array[Dictionary] = []
		for seat in range(4):
			var hand: Array = own if seat == 0 else []
			if seat > 0:
				for i in range(13):
					for original in range(27):
						var t: int = (original + rotation * 9) % 27
						if t / 9 != rotation and _contains(pool, t):
							hand.append(_take(pool, t))
							break
			players.append({"seat": seat, "nickname": "P%d" % seat, "score": 0, "is_ai": false, "has_won": false,
				"ding_que": ["tiao", "tong", "wan"][(rotation + 2) % 3] if seat == 0 else ["tiao", "tong", "wan"][rotation],
				"hand_tiles": hand, "hand_count": hand.size(), "melds": [], "discards": []})
		for i in range(pool.size()):
			players[i % 4]["discards"].append(pool[i])
		game.players = players
		game.wall = wall
		game.wall_count = wall.size()
		game.current_phase = 5
		game.current_turn_seat = 0
		game.last_draw_tile = {"seat": 0, "tile": own.back()}
		game.last_turn_context = {"seat": 0, "draw_reason": "normal_draw"}
		game.ai_public_events.clear()
		var ids: Array = []
		for tile in wall:
			ids.append(int(tile["id"]))
		for player in players:
			for tile in player["hand_tiles"] + player["discards"]:
				ids.append(int(tile["id"]))
		ids.sort()
		_check(ids == range(108), "108 physical copies")
		_check(not game.can_human_self_hu(0), "fixture hides no legal self Hu")
		var q: Dictionary = bridge.build_self_action_transport_payload(game._build_player_state(0), game._build_table_state(),
			game.rules, game.can_human_self_hu(0), [rotation * 9], [])
		q["roundId"] = ""
		q["compactResult"] = false
		var result: Dictionary = JSON.parse_string(str(runtime.call("AnalyzeSelfActionJson", JSON.stringify(q))))
		_check(bool(result.get("ok", false)), "actual Native self-action")
		_check(str(result.get("action")) == "gang", "fixture selected actual Gang")
		_check(result.get("reasons", []).has("GANG_REPLACEMENT_PUBLIC_WALL_REBUILT") == expect_rebuilt,
			"actual Native selected mechanism binding")
		rows.append({"rotation": rotation, "public_input_sha256": JSON.stringify(q).sha256_text(),
			"action": result.get("action"), "score": result.get("score"), "reasons": result.get("reasons"),
			"physical108": true, "synthetic_transfer": true})
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if not output.is_empty():
		var f := FileAccess.open(output, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "rows": rows,
			"scope": "Synthetic physical108 GameState -> public bridge -> real Native self-action; not natural strength"}, "  "))
	print("GANG_PUBLIC_WALL_NATIVE cases=", rows.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, why: String) -> void:
	if not ok:
		failures.append(why)

func _take(pool: Array, t: int) -> Dictionary:
	for i in range(pool.size()):
		if int(pool[i]["id"]) / 4 == t:
			var tile: Dictionary = pool[i]
			pool.remove_at(i)
			return tile
	assert(false, "Unavailable physical tile")
	return {}

func _contains(pool: Array, t: int) -> bool:
	for tile in pool:
		if int(tile["id"]) / 4 == t:
			return true
	return false
