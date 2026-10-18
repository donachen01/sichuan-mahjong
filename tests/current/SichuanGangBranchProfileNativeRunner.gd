extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Fresh current plans at physical roots. Old checkpoints are never relabelled.
# This checks actual Native entry/reason/score parity, not natural-prefix strength.
func _run() -> void:
	var input := _read_string_arg("--input=", "")
	var output := _read_string_arg("--output=", "")
	var baseline := _read_string_arg("--baseline=", "")
	var require_profile := _read_bool_arg("--require-profile=", true)
	var before: Array = []
	if not baseline.is_empty():
		before = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(baseline)))["rows"]
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var rows: Array = []
	var failures: Array = []
	for entry in index:
		var source: String = entry["node"]["path"]
		assert(FileAccess.get_sha256(source) == entry["node"]["sha256"])
		var snapshot: Dictionary = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(source)))
		var game: Node = GAME_STATE_SCRIPT.new()
		root.add_child(game)
		await process_frame
		_restore_fields(game, snapshot["state"])
		assert(_physical_integrity(game)["passed"])
		assert(_checkpoint_world_hash(game, snapshot["seat"]) == snapshot["world_hash"])
		game.set("test_ai_policy_variants_by_seat", {})
		var generation := 50000 + rows.size()
		game.set("ai_agent_generation", generation)
		var stamps: Array = snapshot["views"].duplicate(true)
		for stamp in stamps:
			stamp["hostGeneration"] = generation
			stamp["policyVariant"] = "current"
		game.get("ai_manager").get("csharp_bridge").restore_agent_view_stamps(stamps)
		var views: Array = game.call("_agent_views")
		for i in range(4):
			assert(_integer_values(JSON.parse_string(JSON.stringify(views[i]))) == stamps[i])
		assert(game.get("ai_manager").update_round_agents("begin", views))
		game.set("ai_agents_started", true)
		game.get("ai_manager").set_compact_runtime_snapshots(false)
		var prepared: Dictionary = game.call("_build_ai_turn_decision")
		var native: Dictionary = game.get("ai_manager").get("latest_turn_snapshot").get("analysis", {}).get("csharp_result", {})
		assert(not prepared.is_empty() and bool(native.get("ok", false)))
		var row := {"input_sha256": entry["node"]["sha256"], "seed": snapshot["seed"], "seat": snapshot["seat"],
			"action": native["action"], "tile": int(native["tileType"]), "scores": _integer_values(native["actionScores"]), "reasons": native["reasons"]}
		if not before.is_empty():
			var old: Dictionary = before[rows.size()]
			if old["input_sha256"] != row["input_sha256"] or old["action"] != row["action"] or old["tile"] != row["tile"] or old["scores"] != row["scores"]:
				failures.append({"kind": "actual_native_score_action_parity", "row": row})
		if require_profile and native["action"] == "gang":
			var key := str(native["gangSubtype"]) + ":" + str(int(native["tileType"]))
			var bounds: Array = entry["branch_ranges"][key]
			var marker := "GANG_REPLACEMENT_SHANTEN_RANGE_%d_%d" % [bounds[0], bounds[1]]
			if not "GANG_REPLACEMENT_BRANCH_PROFILE" in native["reasons"] or not marker in native["reasons"]:
				failures.append({"kind": "actual_branch_range", "expected": marker, "row": row})
		rows.append(row)
		game.call("abort_agent_round")
		game.queue_free()
		await process_frame
	_write_report({"passed": failures.is_empty(), "rows": rows, "failures": failures,
		"scope": "Fresh current plans at exact physical/public roots; only generation and policy stamps updated. Real Native marker and exact scores/action parity; not strength."}, output)
	print("GANG_BRANCH_PROFILE_NATIVE roots=", rows.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
