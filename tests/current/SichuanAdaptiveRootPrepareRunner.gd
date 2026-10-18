extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Research-only cold-start counterfactual roots. Never relabel historical agent
# checkpoints as compatible. Preserve original physical/public worlds and record
# that current plans were freshly initialized at these already-observed roots.
func _run() -> void:
	var input := _read_string_arg("--input=", "")
	var output := _read_string_arg("--output=", "")
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var prepared: Array = []
	for entry in index:
		var source: String = entry["node"]["path"]
		if FileAccess.get_sha256(source) != entry["node"]["sha256"]:
			push_error("historical source node changed")
			quit(1)
			return
		var snapshot: Dictionary = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(source)))
		var game: Node = GAME_STATE_SCRIPT.new()
		root.add_child(game)
		await process_frame
		_restore_fields(game, snapshot["state"])
		if not _physical_integrity(game)["passed"] or _checkpoint_world_hash(game, snapshot["seat"]) != snapshot["world_hash"]:
			push_error("historical physical world changed")
			quit(1)
			return
		game.set("ai_agent_generation", 30000 + prepared.size())
		var stamps: Array = snapshot["views"].duplicate(true)
		for stamp in stamps:
			stamp["hostGeneration"] = 30000 + prepared.size()
		game.get("ai_manager").get("csharp_bridge").restore_agent_view_stamps(stamps)
		var views: Array = game.call("_agent_views")
		for i in range(4):
			var previous: Dictionary = snapshot["views"][i].duplicate(true)
			var current: Dictionary = _integer_values(JSON.parse_string(JSON.stringify(views[i])))
			previous.erase("hostGeneration")
			current.erase("hostGeneration")
			if previous != current:
				var changed: Array = []
				for key in previous:
					if previous[key] != current.get(key):
						changed.append(key)
				_write_report({"seat": i, "changed_public_fields": changed}, output + ".public-failure.json")
				push_error("cold start changed historical public input")
				quit(1)
				return
		if not game.get("ai_manager").update_round_agents("begin", views):
			quit(1)
			return
		game.set("ai_agents_started", true)
		var checkpoints: Array = game.get("ai_manager").capture_round_agent_memories(views)
		if checkpoints.size() != 4:
			quit(1)
			return
		snapshot["views"] = views
		snapshot["checkpoints"] = checkpoints
		snapshot["origin"] = "historical_natural_world_current_plan_cold_start_development_only"
		snapshot["initialization"] = {"historical_node": source, "historical_node_sha256": FileAccess.get_sha256(source),
			"old_checkpoint_not_restored": true, "current_plan_begins_at_root": true,
			"not_current_policy_natural_prefix": true, "not_heldout": true}
		var path := output.get_base_dir().path_join("node_%d_%d_%d.json" % [snapshot["seed"], snapshot["seat"], entry["prefix_steps"]])
		_write_report(snapshot, path)
		var updated: Dictionary = entry.duplicate(true)
		updated["node"] = {"path": path, "sha256": FileAccess.get_sha256(path), "kind": snapshot["kind"], "prefix_steps": entry["prefix_steps"]}
		updated["initialization"] = snapshot["initialization"]
		prepared.append(updated)
		game.call("abort_agent_round")
		game.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var index_file := FileAccess.open(output, FileAccess.WRITE)
	if index_file == null:
		push_error("cannot preserve current root index")
		quit(1)
		return
	index_file.store_string(JSON.stringify(prepared, "\t"))
	index_file.close()
	print("ADAPTIVE_COLD_START_ROOTS count=", prepared.size(), " original public/physical worlds preserved; no checkpoint version bypass")
	quit()
