extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Current production plans are freshly initialized at historical physical roots.
# No old checkpoint is relabelled; these are Native correctness fixtures only.
func _run() -> void:
	var input := _read_string_arg("--input=", "")
	var output := _read_string_arg("--output=", "")
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var rows: Array = []
	var failures: Array = []
	var expression := RegEx.new()
	expression.compile("门宽度：(\\d+) 家定缺，竞争 (\\d+) 家")
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
		var generation := 40000 + rows.size()
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
		var diagnostic: Dictionary = game.get("ai_manager").get("latest_turn_snapshot")
		var native: Dictionary = diagnostic.get("analysis", {}).get("csharp_result", {})
		assert(not prepared.is_empty() and bool(native.get("ok", false)))
		var seat := int(snapshot["seat"])
		assert(int(diagnostic["seat"]) == seat)
		var target := int(native["routePlan"]["targetSuit"])
		var supply := 0
		var competition := 0
		for other in range(4):
			if other == seat or not views[seat]["activeSeats"][other] or views[seat]["hasHu"][other]:
				continue
			if int(views[seat]["dingQueSuits"][other]) == target:
				supply += 1
			else:
				competition += 1
		var matched := false
		var reason := ""
		for message in native["routePlan"]["reasons"]:
			var parsed := expression.search(message)
			if parsed != null:
				reason = message
				matched = int(parsed.get_string(1)) == supply and int(parsed.get_string(2)) == competition
		var row := {"input_sha256": entry["node"]["sha256"], "seed": snapshot["seed"], "seat": seat,
			"target": target, "expected_supply": supply, "expected_competition": competition,
			"reason": reason, "matched": matched, "actual_action": native["action"], "actual_tile": native["tileType"]}
		rows.append(row)
		if not matched:
			failures.append(row)
		game.call("abort_agent_round")
		game.queue_free()
		await process_frame
	_write_report({"passed": failures.is_empty(), "rows": rows, "failures": failures,
		"scope": "Physical original roots, unchanged public fields except host generation and all-current policy. Fresh production plans; no strength or natural current-prefix claim."}, output)
	print("ACTIVE_FLUSH_SUPPLY_NATIVE roots=", rows.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
