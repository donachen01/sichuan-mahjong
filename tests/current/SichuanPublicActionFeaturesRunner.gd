extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Extract before executing any action. The base runner's post-execution manager
# snapshot can already belong to a subsequent seat, and is not a root predictor.
func _run() -> void:
	var input := _read_string_arg("--input=", "")
	var output := _read_string_arg("--output=", "")
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var rows: Array = []
	for entry in index:
		var node_path: String = entry["node"]["path"]
		var snapshot: Dictionary = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(node_path)))
		var seat := int(snapshot["seat"])
		var game: Node = GAME_STATE_SCRIPT.new()
		root.add_child(game)
		await process_frame
		_restore_fields(game, snapshot["state"])
		var views: Array = snapshot["views"].duplicate(true)
		var generation := 20000 + rows.size()
		for view in views:
			view["hostGeneration"] = generation
		game.set("ai_agent_generation", generation)
		if not game.get("ai_manager").update_round_agents("restore", views, "", 0, snapshot["checkpoints"]):
			quit(1)
			return
		game.set("ai_agents_started", true)
		game.get("ai_manager").set_compact_runtime_snapshots(false)
		var actual_views: Array = game.call("_agent_views")
		for i in range(4):
			var expected_view: Dictionary = views[i].duplicate(true)
			var actual_view: Dictionary = _integer_values(JSON.parse_string(JSON.stringify(actual_views[i])))
			expected_view.erase("hostGeneration")
			actual_view.erase("hostGeneration")
			if expected_view != actual_view:
				push_error("public feature restore changed input")
				quit(1)
				return
		var phase: int = game.get("current_phase")
		var prepared: Dictionary = game.call("_get_or_prepare_ai_reaction_decision") if phase == 6 else game.call("_build_ai_turn_decision")
		var diagnostic: Dictionary = game.get("ai_manager").get("latest_reaction_snapshot" if phase == 6 else "latest_turn_snapshot").duplicate(true)
		if prepared.is_empty() or int(diagnostic.get("seat", -1)) != seat or not diagnostic.get("analysis", {}).get("csharp_result", {}).get("ok", false):
			_write_report({"prepared": prepared, "diagnostic": diagnostic, "source": node_path}, output + ".failure.json")
			push_error("missing real root native public features")
			quit(1)
			return
		var public_view: Dictionary = snapshot["views"][seat].duplicate(true)
		var actions: Array = []
		for action in snapshot["root_actions"]:
			actions.append({"action": action["action"], "tile_type": action["tile_type"]})
		rows.append({"seed": snapshot["seed"], "seat": seat, "opponent": snapshot["opponent"], "prefix_steps": entry["prefix_steps"],
			"kinds": entry["kinds"], "input_path": node_path, "input_sha256": FileAccess.get_sha256(node_path),
			"public_input": public_view, "legal_root_actions": actions, "native_public_predictor": diagnostic["analysis"]["csharp_result"],
			"measured_before_root_action": true, "no_future_labels_loaded": true, "not_blind_or_calibrated": true})
		game.call("abort_agent_round")
		game.queue_free()
		await process_frame
		_write_report({"origin": "restored_actual_public_node_before_action", "rows": rows}, output)
		print("public_features node=", rows.size(), " kinds=", entry["kinds"])
	quit()
