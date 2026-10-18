extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = get_root().get_node("GameState")
	var runtime = get_root().get_node("SichuanCSharpRuntime")
	var bridge = preload("res://scripts/ai/csharp_ai_bridge.gd").new()
	var failures: Array[String] = []
	var checks := 0
	for kind in ["melded_gang", "an_gang", "add_gang"]:
		for draw_reason in ["normal_draw", "gang_draw"]:
			for payer_count in [1, 2, 3]:
				var pool: Array[Dictionary] = []
				for t in range(27):
					for copy in range(4):
						pool.append(_tile(t * 4 + copy, t))
				var own: Array = []
				for t in range(18, 27):
					own.append(_take(pool, t))
				own.append(_take(pool, 15))
				own.append(_take(pool, 15))
				var quad: Array = []
				for i in range(4):
					quad.append(_take(pool, 9))
				var players: Array[Dictionary] = []
				for seat in range(4):
					var hand: Array = own if seat == 0 else []
					if seat > 0:
						for i in range(13):
							hand.append(pool.pop_back())
					players.append({"seat": seat, "nickname": "P%d" % seat, "score": 0, "is_ai": false, "is_dealer": seat == 0,
						"hand_tiles": hand, "hand_count": hand.size(), "discards": [], "ding_que": "tiao", "has_won": seat > payer_count,
						"melds": [{"type": "gang", "gang_subtype": kind, "from_seat": 1 if kind == "melded_gang" else 0, "tiles": quad}] if seat == 0 else []})
				state.set("players", players)
				state.set("wall", pool)
				state.set("wall_count", pool.size())
				state.set("current_turn_seat", 0)
				state.set("last_draw_tile", {"seat": 0, "tile": own.back()})
				state.set("last_turn_context", {"seat": 0, "draw_reason": draw_reason})
				state.set("last_gang_context", {"seat": 0, "source_seat": 1 if kind == "melded_gang" else 0, "tile": quad[0], "gang_type": kind, "resolved": true})
				var table: Dictionary = state.call("_build_table_state")
				var player: Dictionary = state.call("_build_player_state", 0)
				var payload: Dictionary = bridge.build_self_action_transport_payload(player, table, state.get("rules"), true, [], [])
				if checks == 0:
					print("probe own=", player.get("hand_count"), " melds=", payload.get("meldViews")[0], " active=", payload.get("activeSeats"), " hand=", payload.get("hand18"))
				var answer := str(runtime.call("AnalyzeSelfActionAotCompact", JSON.stringify(payload))).split("|", true)
				var win_type: String = state.call("_resolve_self_draw_win_type", 0)
				players[0]["has_won"] = true
				state.set("players", players)
				var source := 1 if win_type == "dian_gang_hua" else -1
				var payers: Array = state.call("_get_payer_seats_for_win", win_type, source)
				var resolver = state.get("score_resolver")
				var fan: Dictionary = resolver.build_event_fan_detail(players[0], own.back(), win_type, state.get("rules"))
				var changes: Dictionary = resolver.build_score_changes(players, {"win_events": [{"winner_seat": 0, "payer_seats": payers, "win_type": win_type, "fan_detail": fan}]}, state.get("rules"))
				if answer.size() < 9 or answer[0] != "ok" or answer[1] != "hu" or int(answer[3]) != int(changes[0]) * 1000:
					failures.append("%s/%s/%d answer=%s settlement=%s" % [kind, draw_reason, payer_count, answer, changes])
				if str(payload.get("ownDrawReason", "")) != draw_reason or int(payload.get("lastGangSourceSeat", -1)) != (1 if kind == "melded_gang" else 0):
					failures.append("current own context lost")
				table["last_turn_context"] = {"seat": 2, "draw_reason": "gang_draw", "private_tile": _tile(999, 2)}
				var other: Dictionary = bridge.build_self_action_transport_payload(player, table, state.get("rules"), true, [], [])
				if other.get("ownDrawReason") != "" or other.has("private_tile"):
					failures.append("opponent private current draw context leaked")
				checks += 1
	print("SELF_DRAW_GAME_BRIDGE checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _tile(id: int, t: int) -> Dictionary:
	return {"id": id, "suit": ["tiao", "tong", "wan"][int(t / 9)], "rank": t % 9 + 1}

func _take(pool: Array, t: int) -> Dictionary:
	for index in range(pool.size()):
		if pool[index]["suit"] == ["tiao", "tong", "wan"][int(t / 9)] and pool[index]["rank"] == t % 9 + 1:
			var tile: Dictionary = pool[index]
			pool.remove_at(index)
			return tile
	assert(false, "tile unavailable")
	return {}
