extends SceneTree

func _init() -> void:
	await process_frame
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/hu_income_cost_20260930/book_reaction.json"))
	var hand: Array = []
	hand.resize(27)
	hand.fill(0)
	for tile in [0, 1, 2, 3, 4, 6, 7, 9, 10, 11, 13, 14, 16, 17]:
		hand[tile] += 1
	var visible: Array = []
	visible.resize(27)
	visible.fill(0)
	payload["hand18"] = hand
	payload["visible18"] = visible
	payload["remaining18"] = hand.map(func(count): return 4 - count)
	payload["handCounts"] = [14, 13, 13, 13]
	payload["dingQueSuits"] = [2, 0, 1, 2]
	payload["currentSeat"] = 0
	payload["discards18"] = [[], [], [], []]
	payload["publicEvents"] = []
	payload["canHu"] = false
	var results: Array = []
	var passed := true
	for run in range(2):
		var started := Time.get_ticks_msec()
		var raw := str(runtime.call("AnalyzeDiscardJson", JSON.stringify(integer_payload(payload))))
		var elapsed := Time.get_ticks_msec() - started
		var response = JSON.parse_string(raw)
		var tile := int(response.get("tileType", -1)) if response is Dictionary else -1
		var legal: bool = response is Dictionary and bool(response.get("ok", false)) and tile >= 0 and tile < 27 and hand[tile] > 0
		var no_terminal := not raw.contains('"BucketContinuation"') and not raw.contains('"CriticalContinuation"') and not raw.contains("HU_INCOME_COST_FULL_CONTINUATION")
		passed = passed and legal and no_terminal and not response.get("reasons", []).is_empty()
		results.append({"run": run, "elapsed_ms": elapsed, "tile": tile, "legal": legal, "no_terminal": no_terminal})
	print("LIVE_STRATEGY_RUNTIME ", JSON.stringify({"passed": passed, "results": results}))
	runtime.queue_free()
	quit(0 if passed else 1)

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
