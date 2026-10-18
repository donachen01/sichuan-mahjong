extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

func _run() -> void:
	var input := _read_string_arg("--input=", "")
	var output := _read_string_arg("--output=", "")
	var snapshot: Dictionary = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(input)))
	var game: Node = GAME_STATE_SCRIPT.new()
	root.add_child(game)
	await process_frame
	_restore_fields(game, snapshot["state"])
	if not _physical_integrity(game)["passed"]:
		quit(1)
		return
	var actual_dealer := int(game.get("current_dealer_seat"))
	# Use the real production policy for every seat in this context fixture.
	game.set("test_ai_policy_variants_by_seat", {})
	# Fresh plans: old incompatible checkpoint versions are never patched.
	game.set("ai_agent_generation", 40000)
	var views: Array = game.call("_agent_views")
	var rows: Array = []
	var passed := true
	for view in views:
		passed = passed and int(view["dealerSeat"]) == actual_dealer
		rows.append({"seat": view["seatIndex"], "actual_dealer": actual_dealer, "transport_dealer": view["dealerSeat"]})
	if not game.get("ai_manager").update_round_agents("begin", views):
		quit(1)
		return
	var memories: Array = game.get("ai_manager").capture_round_agent_memories(views)
	passed = passed and memories.size() == 4
	for i in range(memories.size()):
		var memory: Dictionary = JSON.parse_string(memories[i])
		var fingerprint: String = memory["ViewFingerprint"]
		rows[i]["native_fingerprint_dealer_matches"] = fingerprint.contains("|dealer=%d|" % actual_dealer)
		passed = passed and rows[i]["native_fingerprint_dealer_matches"]
	# The public authority must also prevail over stale per-player visual flags.
	var bridge = preload("res://scripts/ai/csharp_ai_bridge.gd").new()
	var flags: Array = [{"seat": 0, "is_dealer": true}]
	var authority_checks := 0
	for dealer in range(4):
		for seat in range(4):
			passed = passed and int(bridge.call("_resolve_dealer_seat", flags, {"current_dealer_seat": dealer}, seat)) == dealer
			authority_checks += 1
	passed = passed and int(bridge.call("_resolve_dealer_seat", flags, {"dealer_seat": 2}, 1)) == 2
	passed = passed and int(bridge.call("_resolve_dealer_seat", flags, {}, 1)) == 0
	passed = passed and int(bridge.call("_resolve_dealer_seat", [], {}, 1)) == 1
	_write_report({"passed": passed, "rows": rows, "authority_checks": authority_checks + 3,
		"physical108": true, "source_node_sha256": FileAccess.get_sha256(input),
		"scope": "Actual Godot table builder to public bridge and Native checkpoint fingerprint; all 4 seat perspectives. Synthetic resolver conflict cases verify authority and legacy fallback."}, output)
	game.call("abort_agent_round")
	game.queue_free()
	print("DEALER_CONTEXT_NATIVE passed=", passed, " actual seat perspectives=", rows.size(), " authority cases=", authority_checks+3)
	quit(0 if passed else 1)
