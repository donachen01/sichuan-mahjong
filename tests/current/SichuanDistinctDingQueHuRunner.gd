extends SceneTree

var failed: Array[String] = []

func check_ok(condition: bool, label: String) -> void:
	if not condition:
		failed.append(label)

func _init() -> void:
	await process_frame
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/hu_income_cost_20260930/book_reaction.json"))
	payload["dingQueSuits"] = [0, 0, 1, 2]
	for index in [2, 3]:
		payload["publicEvents"].append({"eventIndex": index, "turnIndex": index, "seat": 0, "type": "pass", "tileType": 11, "sourceSeat": 1, "canHu": true})
	var full = JSON.parse_string(str(runtime.call("AnalyzeReactionJson", JSON.stringify(integer_payload(payload)))))
	var compact := str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(integer_payload(payload)), false))
	check_ok(bool(full.get("ok", false)) and str(full.get("action", "")) == "hu" and JSON.stringify(full).contains("DISTINCT_DINGQUE_TAKE_HU"), "native budget gate")
	check_ok(compact.begins_with("ok|hu|"), "compact budget gate")
	for gang in [false, true]:
		check_claim_record(gang)
	print("DISTINCT_DINGQUE_HU_RUNTIME ", JSON.stringify({"passed": failed.is_empty(), "failures": failed, "action": full.get("action", ""), "compact": compact}))
	runtime.queue_free()
	quit(0 if failed.is_empty() else 1)

func tile(id: int, t: int) -> Dictionary:
	return {"id": id, "suit": ["tiao", "tong", "wan"][t / 9], "rank": t % 9 + 1, "sort_key": t, "display_name": str(t)}

func check_claim_record(gang: bool) -> void:
	var game = load("res://autoload/GameState.gd").new()
	for pair in [["rules", "rule_config"], ["mahjong_state", "mahjong_state"], ["mahjong_judge", "mahjong_judge"], ["ding_que_resolver", "ding_que_resolver"], ["reaction_resolver", "reaction_resolver"], ["hu_checker", "hu_checker"], ["score_resolver", "score_resolver"], ["shanten_analyzer", "shanten_analyzer"], ["risk_analyzer", "risk_analyzer"]]:
		game.set(pair[0], load("res://scripts/core/" + pair[1] + ".gd").new())
	var players: Array[Dictionary] = []
	var hand: Array[Dictionary] = []
	for t in [9, 9, 9, 10, 11, 12, 13, 14, 18, 19, 20, 21, 21]:
		hand.append(tile(hand.size() + 1, t))
	var offered := tile(99, 9)
	for seat in range(4):
		players.append({"seat": seat, "nickname": str(seat), "score": 0, "is_ai": false, "hand_tiles": hand.duplicate(true) if seat == 0 else [], "hand_count": 13 if seat == 0 else 0, "melds": [], "discards": [offered] if seat == 1 else [], "ding_que": ["tiao", "tiao", "tong", "wan"][seat], "has_won": false})
	game.players = players
	game.current_phase = 6
	game.current_turn_seat = 1
	game.current_discard_context = {"source_seat": 1, "tile": offered, "reaction_type": "discard"}
	var pending: Array[Dictionary] = [{"seat": 0, "can_hu": true, "can_peng": true, "can_gang": gang}]
	game.pending_reactions = pending
	var river: Array[Dictionary] = [{"seat": 1, "tile": offered}]
	game.discard_pile = river
	var wall: Array[Dictionary] = [tile(100, 23)]
	game.wall = wall
	game.wall_count = 1
	var succeeded: bool = game.execute_human_gang(0) if gang else game.execute_human_peng(0)
	check_ok(succeeded, "claim execution " + str(gang))
	var events: Array = game.ai_public_events.filter(func(e): return e["type"] == ("melded_gang" if gang else "peng"))
	check_ok(events.size() == 1 and bool(events[0].get("canHu", false)), "confirmed claim remembers refused Hu " + str(gang))
	var bridge = load("res://scripts/ai/csharp_ai_bridge.gd").new()
	var own: Array = bridge._encode_public_events(game.ai_public_events, ["tiao", "tong", "wan"], 0)
	var other: Array = bridge._encode_public_events(game.ai_public_events, ["tiao", "tong", "wan"], 2)
	check_ok(own.any(func(e): return bool(e.get("canHu", false))) and not other.any(func(e): return bool(e.get("canHu", false))), "private claim legality stays with own agent")
	game.free()

# This fixture contains integer numeric fields. Godot JSON.parse_string returns
# floats; restore their declared transport types before sending to .NET.
func integer_payload(value):
	if value is float:
		return int(value)
	if value is Array:
		return value.map(integer_payload)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = integer_payload(value[key])
		return result
	return value
