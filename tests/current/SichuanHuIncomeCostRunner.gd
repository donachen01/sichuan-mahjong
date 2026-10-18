extends SceneTree

func _init() -> void:
	await process_frame
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	var payload := FileAccess.get_file_as_string("res://evidence/hu_income_cost_20260930/book_reaction.json")
	var full = JSON.parse_string(str(runtime.call("AnalyzeReactionJson", payload)))
	var compact := str(runtime.call("AnalyzeReactionAotCompact", payload, false))
	var confirmed := full is Dictionary and bool(full.get("ok", false)) \
		and JSON.stringify(full).contains("HU_STRATEGY_CURRENT_STATE") \
		and compact.begins_with("ok|") and compact.split("|")[1] == str(full.get("action", ""))
	print("HU_INCOME_COST_RUNTIME ", JSON.stringify({"passed": confirmed, "action": full.get("action", "error"), "compact": compact}))
	runtime.queue_free()
	quit(0 if confirmed else 1)
