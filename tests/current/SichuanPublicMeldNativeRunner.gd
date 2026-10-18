extends SceneTree

func _init() -> void:
	await process_frame
	var input := "/Volumes/other/SichuanResearchReplays/20261002/actual-actions/development-claims/node_20474046_2_flush_route.json"
	var node: Dictionary = _integers(JSON.parse_string(FileAccess.get_file_as_string(input)))
	var q: Dictionary = node["views"][2].duplicate(true)
	q.merge({"seatIndex": 0, "currentSeat": 0, "dealerSeat": 0, "wallCount": 52,
		"roundId": "", "hostGeneration": 0, "viewVersion": 0, "compactResult": false, "policyVariant": "current",
		"dingQueSuits": [2, 2, 2, 2], "handCounts": [14, 4, 13, 13], "hasHu": [false, false, false, false],
		"activeSeats": [true, true, true, true], "isReady": [false, false, false, false], "isCalled": [false, false, false, false],
		"discards18": [[], [], [], []], "passedHu18": [[], [], [], []], "passedPeng18": [[], [], [], []], "passedGang18": [[], [], [], []],
		"publicEvents": [], "eventVersion": 0, "phase": 5, "turnIndex": 1, "lockedFans": [0, 0, 0, 0],
		"lastDrawTileType": 17, "ownDrawReason": "normal_draw", "lastGangSeat": -1, "lastGangSourceSeat": -1, "lastGangType": ""}, true)
	var h: Array = []; h.resize(27); h.fill(0)
	for t in [9,9,10,10,11,11,12,12,13,13,14,15,16,17]:
		h[t] += 1
	var visible: Array = []; visible.resize(27); visible.fill(0)
	var tiles: Array = []; var typed: Array = []
	for t in range(3):
		visible[t] = 4
		for i in range(4): tiles.append(t)
		typed.append({"type": "ConcealedGang", "tileType": t, "sourceSeat": 1, "eventIndex": 0})
	var remaining: Array = []
	for t in range(27): remaining.append(4 - h[t] - visible[t])
	q["hand18"] = h; q["visible18"] = visible; q["remaining18"] = remaining
	q["melds18"] = [[], tiles, [], []]
	var runtime = root.get_node("SichuanCSharpRuntime")
	var values: Array = []
	var errors: Array = []
	for legacy in [false, true]:
		q["meldViews"] = [[], [] if legacy else typed, [], []]
		var diagnostic: String = runtime.call("DiagnosePublicReadinessCompact", JSON.stringify(q))
		var raw := -1.0; var groups := -1
		for row in diagnostic.split(";"):
			var parts := row.split(",")
			if parts.size() >= 4 and int(parts[0]) == 1:
				raw = float(parts[1]); groups = int(parts[3])
		var result = JSON.parse_string(str(runtime.call("AnalyzeDiscardJson", JSON.stringify(q))))
		var ready := -1.0
		if not result.get("ok", false):
			errors.append("actual native discard failed: " + str(result))
		for row in result.get("beliefSummary", {}).get("ready_posteriors", []):
			if int(row["seat"]) == 1: ready = float(row["ready_posterior"])
		if groups != 3: errors.append("native compact diagnostic did not report3 actual groups")
		if raw < 0 or ready < 0: errors.append("missing actual native ready readout")
		values.append({"legacy_flat": legacy, "groups": groups, "raw_ready": raw, "ready": ready})
	if abs(values[0]["ready"] - values[1]["ready"]) > 0.000000001:
		errors.append("native typed and flat ready probabilities disagree")
	print("PUBLIC_MELD_NATIVE ", JSON.stringify({"passed": errors.is_empty(), "failures": errors, "values": values, "grounding": "synthetic physical108-copy public transfer, not original book world"}))
	quit(0 if errors.is_empty() else 1)

func _integers(v: Variant) -> Variant:
	if v is float and v == floor(v): return int(v)
	if v is Array: return v.map(_integers)
	if v is Dictionary:
		var result := {}
		for k in v: result[k] = _integers(v[k])
		return result
	return v
