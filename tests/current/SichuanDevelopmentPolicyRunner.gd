extends SceneTree

var failed: Array[String] = []

func check_ok(condition: bool, label: String) -> void:
	if not condition:
		failed.append(label)

func _init() -> void:
	await process_frame
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/development_policy_20261001/book_reaction.json"))
	var full = JSON.parse_string(str(runtime.call("AnalyzeReactionJson", JSON.stringify(integer_payload(payload)))))
	var compact := str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(integer_payload(payload)), false))
	check_ok(bool(full.get("ok", false)) and JSON.stringify(full).contains("SINGLE_LANE_HU_DISCIPLINE"), "native development policy")
	check_ok(JSON.stringify(full).contains("HU_STRATEGY_CURRENT_STATE"), "native current-state strategy")
	check_ok(compact.begins_with("ok|" + str(full.get("action", "")) + "|"), "compact same action")
	print("DEVELOPMENT_POLICY_RUNTIME ", JSON.stringify({"passed": failed.is_empty(), "failures": failed, "action": full.get("action", ""), "compact": compact}))
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
