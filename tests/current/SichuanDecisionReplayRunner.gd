extends SceneTree

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("需要一个 ai_replays/*.jsonl 文件路径")
		quit(2)
		return
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	runtime.set("DecisionAuditEnabled", false)
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		printerr("无法读取复盘文件")
		quit(2)
		return
	var rows: Array = []
	var mismatches := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var entry = JSON.parse_string(line)
		if typeof(entry) != TYPE_DICTIONARY:
			mismatches += 1
			rows.append({"status": "damaged_record"})
			continue
		var expected = JSON.parse_string(str(entry["response"])) if not str(entry["method"]).ends_with("Compact") else {}
		var raw_actual: String = str(runtime.call("ReplayDecisionAuditEntry", line))
		var actual = JSON.parse_string(raw_actual) if not str(entry["method"]).ends_with("Compact") else {"compact_action": "|".join(raw_actual.split("|").slice(0,3))}
		if str(entry["method"]).ends_with("Compact"):
			expected = {"compact_action": "|".join(str(entry["response"]).split("|").slice(0,3))}
		var equal := typeof(expected) == TYPE_DICTIONARY and typeof(actual) == TYPE_DICTIONARY
		var differences: Array = []
		for key in ["ok", "error", "suit", "action", "actionType", "tileType", "gangSubtype", "discardTile", "compact_action"]:
			if typeof(expected) == TYPE_DICTIONARY and expected.has(key) and (typeof(actual) != TYPE_DICTIONARY or expected[key] != actual.get(key)):
				equal = false
				differences.append(key)
		if not equal:
			mismatches += 1
		rows.append({"sequence": entry["sequence"], "method": entry["method"], "same_action": equal, "differences": differences})
	file.close()
	var output := args[0] + ".review.json"
	var report := FileAccess.open(output, FileAccess.WRITE)
	report.store_string(JSON.stringify({"rows": rows, "mismatches": mismatches,
		"meaning": "重放一致性验证；不代表所选动作已证明最优"}, "\t"))
	report.close()
	print("DECISION_REPLAY entries=%d mismatches=%d report=%s" % [rows.size(), mismatches, output])
	runtime.queue_free()
	quit(0 if mismatches == 0 else 1)
