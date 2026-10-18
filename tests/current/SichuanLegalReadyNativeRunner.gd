extends "res://tests/current/SichuanGangPublicWallNativeRunner.gd"

func _run() -> void:
	var game = root.get_node("GameState")
	var runtime = root.get_node("SichuanCSharpRuntime")
	var bridge = preload("res://scripts/ai/csharp_ai_bridge.gd").new()
	var rows: Array = []
	for rotation in range(3):
		for fifth in [false, true]:
			var pool: Array[Dictionary] = []
			for t in range(27):
				for copy in range(4):
					pool.append({"id": t * 4 + copy, "suit": ["tiao", "tong", "wan"][t / 9], "rank": t % 9 + 1, "sort_key": t, "display_name": str(t)})
			var own: Array = []
			for t in ([1, 2, 5, 5, 12] if fifth else [4, 12]):
				own.append(_take(pool, (t + rotation * 9) % 27))
			var melds: Array = []
			for spec in ([[0, 4], [3, 4], [8, 3]] if fifth else [[0, 3], [1, 3], [2, 3], [3, 3]]):
				var tiles: Array = []
				for i in range(spec[1]):
					tiles.append(_take(pool, (spec[0] + rotation * 9) % 27))
				melds.append({"type": "gang" if spec[1] == 4 else "peng", "gang_subtype": "an_gang", "from_seat": 0, "tiles": tiles})
			var players: Array[Dictionary] = []
			for seat in range(4):
				var hand: Array = own if seat == 0 else []
				var missing: int = (rotation + seat - 1) % 3 if seat > 0 else (rotation + 2) % 3
				if seat > 0:
					for i in range(13):
						for original in range(27):
							var t: int = (original + rotation * 9) % 27
							if t / 9 != missing and (fifth or t != (4 + rotation * 9) % 27) and _contains(pool, t):
								hand.append(_take(pool, t))
								break
				players.append({"seat": seat, "nickname": "P%d" % seat, "score": 0, "is_ai": false, "has_won": false,
					"ding_que": ["tiao", "tong", "wan"][missing], "hand_tiles": hand, "hand_count": hand.size(),
					"melds": melds if seat == 0 else [], "discards": []})
			for i in range(pool.size()):
				players[i % 4]["discards"].append(pool[i])
			game.players = players
			game.wall.clear()
			game.wall_count = 0
			game.current_phase = 5
			game.current_turn_seat = 0
			game.last_draw_tile = {"seat": 0, "tile": own.back()}
			game.last_turn_context = {"seat": 0, "draw_reason": "normal_draw"}
			game.ai_public_events.clear()
			var ids: Array = []
			for player in players:
				for tile in player["hand_tiles"] + player["discards"]:
					ids.append(int(tile["id"]))
				for meld in player["melds"]:
					for tile in meld["tiles"]:
						ids.append(int(tile["id"]))
			ids.sort()
			_check(ids == range(108), "physical108 legal-ready fixture")
			var after: Array = own.duplicate(true)
			after.pop_back()
			var waits: Array = game.hu_checker.get_ting_tiles(after, players[0]["ding_que"], game.rules, melds.size(), melds)
			_check(waits.is_empty() == fifth, "independent Godot legal wait classification")
			var after_player: Dictionary = players[0].duplicate(true)
			after_player["hand_tiles"] = after
			after_player["hand_count"] = after.size()
			var actual_price: Dictionary = game._resolve_cha_jiao_detail(after_player, waits)
			_check((int(actual_price["score"]) > 0) != fifth, "independent actual cha-jiao pricing")
			var q: Dictionary = bridge.build_discard_transport_payload(game._build_player_state(0), game._build_table_state(), game.rules)
			q["roundId"] = ""
			q["compactResult"] = false
			var result: Dictionary = JSON.parse_string(str(runtime.call("AnalyzeDiscardJson", JSON.stringify(q))))
			_check(bool(result.get("ok", false)), "actual Native discard legal-ready")
			var candidate := {}
			for c in result.get("candidates", []):
				if int(c["tileType"]) == (12 + rotation * 9) % 27:
					candidate = c
			_check(not candidate.is_empty(), "actual candidate present")
			_check(int(candidate.get("shanten", 0)) > 0 if fifth else int(candidate.get("shanten", -1)) == 0, "actual Native legal distance")
			_check(candidate.get("reasons", []).has("STRUCTURAL_READY_NOT_LEGAL" if fifth else "LEGAL_READY_DEAD_WAIT_CHA_JIAO"), "actual Native mechanism explanation")
			rows.append({"rotation": rotation, "owned_fifth_copy_pseudo_wait": fifth, "actual_godot_cha_jiao_score": actual_price["score"],
				"native_shanten": candidate.get("shanten"), "public_input_sha256": JSON.stringify(q).sha256_text(), "physical108": true})
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if not output.is_empty():
		var f := FileAccess.open(output, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "rows": rows,
			"scope": "Synthetic physical108; independent Godot legality/cha-jiao and real Native ranking; not reconstructed book world or strength"}, "  "))
	print("LEGAL_READY_NATIVE cases=", rows.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)
