extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _payload(tiles: Array, safe_exit: bool = false) -> Dictionary:
	var hand: Array = []; hand.resize(27); hand.fill(0)
	var visible: Array = []; visible.resize(27); visible.fill(0)
	for tile in tiles:
		hand[tile] += 1
	var discards: Array = [[], [], [], []]
	var events: Array = []
	if safe_exit:
		visible[10] = 3
		for seat in range(1, 4):
			discards[seat].append(10)
			events.append({"eventIndex": seat, "turnIndex": seat, "seat": seat, "type": "discard", "tileType": 10, "origin": "hand", "sourceSeat": seat})
	var remaining: Array = []
	for tile in range(27):
		remaining.append(4 - hand[tile] - visible[tile])
	return {
		"seatIndex": 0, "dealerSeat": 0, "currentSeat": 0, "roundIndex": 27,
		"wallCount": 52 if safe_exit else 55, "phase": 5,
		"hand18": hand, "visible18": visible, "remaining18": remaining,
		"dingQueSuits": [2, 0, 0, 0], "handCounts": [14, 13, 13, 13],
		"scores": [0, 0, 0, 0], "activeSeats": [true, true, true, true],
		"informationMode": "public", "mobileSpeedMode": false,
		"discards18": discards, "melds18": [[], [], [], []], "publicEvents": events,
	}

func _run() -> void:
	var runtime := root.get_node_or_null("SichuanCSharpRuntime")
	if runtime == null:
		push_error("真实 C# runtime 未加载")
		quit(1)
		return
	var strong := _payload([0, 0, 1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 9, 10], true)
	var started := Time.get_ticks_msec()
	var result: Dictionary = JSON.parse_string(str(runtime.call("AnalyzeDiscardJson", JSON.stringify(strong))))
	if not bool(result.get("ok", false)) or int(result.get("tileType", -1)) not in [9, 10]:
		failures.append("真实 native 没有保留强单行道路线")
	if not JSON.stringify(result.get("reasons", [])).contains("单行道"):
		failures.append("真实 native 结果缺少单行道解释")
	var elapsed := Time.get_ticks_msec() - started
	var compact := str(runtime.call("AnalyzeDiscardAotCompact", JSON.stringify(strong), false)).split("|", true)
	if compact.size() < 3 or compact[0] != "ok" or int(compact[2]) not in [9, 10]:
		failures.append("移动端 compact 接口没有保留单行道路线")
	var weak := _payload([0, 8, 9, 9, 10, 11, 12, 13, 14, 15, 15, 16, 17, 17])
	var weak_result: Dictionary = JSON.parse_string(str(runtime.call("AnalyzeDiscardJson", JSON.stringify(weak))))
	if int(weak_result.get("tileType", -1)) not in [0, 8]:
		failures.append("真实 native 弱路线没有普通胡退路")
	print("SINGLE_LANE_NATIVE strong_tile=%d weak_tile=%d compact_tile=%s elapsed_ms=%d" % [int(result.get("tileType", -1)), int(weak_result.get("tileType", -1)), compact[2] if compact.size() >= 3 else "error", elapsed])
	if failures.is_empty():
		print("SINGLE_LANE_NATIVE_PASS")
		quit(0)
	else:
		push_error("\n".join(failures))
		quit(1)
