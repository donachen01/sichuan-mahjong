extends SceneTree

var failed: Array[String] = []

func check_ok(condition: bool, label: String) -> void:
	if not condition:
		failed.append(label)

func _init() -> void:
	await process_frame
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/hu_income_cost_20260930/book_reaction.json"))
	var results: Array = []
	for scenario in ["two_eligible", "two_exhausted", "four_exhausted"]:
		var payload = baseline.duplicate(true)
		payload["dingQueSuits"] = [0, 1, 1, 0] if scenario.begins_with("two_") else [0, 0, 0, 0]
		var spent = 2 if scenario == "two_exhausted" else 1 if scenario == "four_exhausted" else 0
		for index in range(spent):
			payload["publicEvents"].append({"eventIndex": index + 2, "turnIndex": index + 2, "seat": 0, "type": "pass", "tileType": 11, "sourceSeat": 1, "canHu": true})
		var full = JSON.parse_string(str(runtime.call("AnalyzeReactionJson", JSON.stringify(integer_payload(payload)))))
		var compact := str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(integer_payload(payload)), false))
		check_ok(bool(full.get("ok", false)) and JSON.stringify(full).contains("REPRESENTATIVE_HU_DISCIPLINE"), scenario + " native policy")
		if spent == 0:
			check_ok(JSON.stringify(full).contains("HU_STRATEGY_CURRENT_STATE"), scenario + " current-state strategy")
		else:
			check_ok(str(full.get("action", "")) == "hu" and JSON.stringify(full).contains("REPRESENTATIVE_TAKE_HU"), scenario + " exhausted gate")
		check_ok(compact.begins_with("ok|" + str(full.get("action", "")) + "|"), scenario + " compact agreement")
		results.append({"scenario": scenario, "action": full.get("action", ""), "compact": compact})
	print("REPRESENTATIVE_HU_RUNTIME ", JSON.stringify({"passed": failed.is_empty(), "failures": failed, "results": results}))
	runtime.queue_free()
	quit(0 if failed.is_empty() else 1)

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
