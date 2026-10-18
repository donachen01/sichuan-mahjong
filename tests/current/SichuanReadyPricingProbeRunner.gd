extends SceneTree

func _init() -> void:
	await process_frame
	var input := "/Volumes/other/SichuanResearchReplays/20261002/actual-actions/development-claims/node_20474046_2_flush_route.json"
	var node: Dictionary = _integers(JSON.parse_string(FileAccess.get_file_as_string(input)))
	var seat := int(node["seat"])
	var payload: Dictionary = node["views"][seat]
	payload["compactResult"] = false
	# Isolated diagnostic facade pricing, not replay of original agent memory.
	payload["roundId"] = ""
	payload["hostGeneration"] = 0
	payload["viewVersion"] = 0
	var runtime = root.get_node("SichuanCSharpRuntime")
	var state = root.get_node("GameState")
	var result = JSON.parse_string(str(runtime.call("AnalyzeDiscardJson", JSON.stringify(payload))))
	var candidate := {}
	for c in result.get("candidates", []):
		if int(c["tileType"]) == 13:
			candidate = c
	var failures: Array = []
	var fan_checks: Array = []
	if candidate.is_empty():
		failures.append("missing requested actual ready candidate: " + str(result.get("error", "")))
	else:
		for wait in candidate["improvingTiles"]:
			var hand: Array = []
			for tile_type in range(27):
				var count := int(payload["hand18"][tile_type]) - (1 if tile_type == 13 else 0)
				for i in range(count):
					hand.append(_tile(hand.size(), tile_type))
			var winning := _tile(999, int(wait))
			hand.append(winning)
			var player := {"seat": seat, "hand_tiles": hand, "hand_count": hand.size(), "melds": [], "ding_que": "tiao"}
			var price: Dictionary = state.get("score_resolver").build_event_fan_detail(player, winning, "self_draw", state.get("rules"))
			fan_checks.append({"wait": int(wait), "godot_fan": price["capped_fan"], "godot_hand_score": price["hand_score"]})
			if int(price["capped_fan"]) != 0:
				failures.append("independent rule fixture premise wrong")
		if float(candidate["expectedFan"]) != 0:
			failures.append("actual ready candidate still priced as future high-fan route")
		if not candidate["reasons"].has("READY_WAIT_RULE_PRICING"):
			failures.append("exact pricing did not reach native explanation")
	print("READY_PRICE_GAME_NATIVE ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "candidate_fan": candidate.get("expectedFan"), "actual_rule_prices": fan_checks, "input_sha256": FileAccess.get_sha256(input)}))
	quit(0 if failures.is_empty() else 1)

func _tile(id: int, t: int) -> Dictionary:
	return {"id": id, "suit": ["tiao", "tong", "wan"][int(t / 9)], "rank": t % 9 + 1}

func _integers(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		return value.map(_integers)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _integers(value[key])
		return result
	return value
