extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# A new research sample, not a change to the frozen historical scout. Chapter
# 6.3/6.4's 9/14 and 10/14 decision points are below its previous 75% trigger.
# Selection observes this seat's own hand and publicly declared missing suits.
func _natural_kinds(game: Node, seat: int) -> Array:
	if int(game.get("current_phase")) != 5 or int(game.get("current_turn_seat")) != seat:
		return []
	if bool(game.call("_can_seat_self_hu_now", seat)):
		return []
	var player: Dictionary = game.get("players")[seat]
	if player.get("discards", []).size() >= 6:
		return []
	var suit_counts := {}
	for tile in player["hand_tiles"]:
		if tile["suit"] == player["ding_que"]:
			return []
		var suit: String = tile["suit"]
		suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	for suit in suit_counts:
		if int(suit_counts[suit]) < 9 or int(suit_counts[suit]) > 10:
			continue
		var compatible := true
		for meld in player["melds"]:
			compatible = compatible and meld["tiles"][0]["suit"] == suit
		if not compatible:
			continue
		var suppliers := 0
		for other in game.get("players"):
			if int(other["seat"]) != seat and not bool(other["has_won"]) and other["ding_que"] == suit:
				suppliers += 1
		if suppliers >= 2:
			return ["book_flush_9_10_tempo"]
	return []


# Preserve complete research records from the beginning of each original round.
func _scout(output: String) -> void:
	var manifest: Array = []
	var seed_base := _read_int_arg("--seed-base=", 20453017)
	var deals := _read_int_arg("--rounds=", 1)
	var only_seat := int(_read_string_arg("--seat=", "-1"))
	var opponent := _read_string_arg("--opponent-variant=", "frozen_cashflow_claims_v1")
	var resume := _read_string_arg("--resume=", "")
	var complete_keys := {}
	if not resume.is_empty():
		var saved: Dictionary = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(resume)))
		for entry in saved["rows"]:
			if only_seat >= 0 and int(entry["seat"]) != only_seat:
				continue
			if not entry["original_completed"] or not entry["ledger_balanced"] or not entry["physical_integrity"]["passed"]:
				push_error("cannot resume from an incomplete original")
				quit(1)
				return
			manifest.append(entry)
			complete_keys["%d:%d" % [entry["seed"], entry["seat"]]] = true
	for deal in range(deals):
		for seat in range(4):
			if only_seat >= 0 and seat != only_seat:
				continue
			if complete_keys.has("%d:%d" % [seed_base + deal * 1009, seat]):
				continue
			var game: Node = GAME_STATE_SCRIPT.new()
			root.add_child(game)
			await process_frame
			if _read_bool_arg("--research-recording=", false):
				game.call("set_research_recording_enabled", true)
			game.set("ai_agent_generation", 1000 + deal * 4 + seat)
			game.call("set_test_seed", seed_base + deal * 1009)
			game.call("set_ai_preset", "bone_ash")
			var variants := {}
			for other in range(4):
				variants[other] = "current" if other == seat else opponent
			game.set("test_ai_policy_variants_by_seat", variants)
			game.call("start_new_round")
			_prepare_all_ai_table(game)
			var selected := {}
			var prefix: Array = []
			for step in range(1500):
				if int(game.get("current_phase")) == 7:
					break
				for kind in _natural_kinds(game, seat):
					if selected.has(kind):
						continue
					game.call("_clear_pending_ai_async_state")
					var views: Array = game.call("_agent_views")
					var memories: Array = game.get("ai_manager").capture_round_agent_memories(views)
					if memories.size() != 4:
						push_error("missing complete agent memories")
						quit(1)
						return
					var actions: Array = _root_actions(game, seat)
					var node := {"seed": seed_base + deal * 1009, "seat": seat, "opponent": opponent,
						"kind": kind, "origin": "natural_actual_action_node", "uses_hidden_for_selection": false,
						"outcome_not_observed_at_selection": true, "views": views, "checkpoints": memories,
						"root_actions": actions, "state": _capture_fields(game), "prefix": prefix.duplicate(true),
						"world_hash": _checkpoint_world_hash(game, seat)}
					var path := output.get_base_dir().path_join("node_%d_%d_%s.json" % [node["seed"], seat, kind])
					_write_report(node, path)
					selected[kind] = {"kind": kind, "path": path, "sha256": FileAccess.get_sha256(path), "prefix_steps": prefix.size()}
				prefix.append({"phase": int(game.get("current_phase")), "seat": int(game.get("current_turn_seat")),
					"public_event_sha256": JSON.stringify(game.get("ai_public_events")).sha256_text(),
					"world_hash": _checkpoint_world_hash(game, seat)})
				_step(game)
				await process_frame
			if int(game.get("current_phase")) != 7 or not _physical_integrity(game)["passed"]:
				push_error("scout failed full legal original continuation")
				quit(1)
				return
			var result := _extract_round_result(game, 1, prefix.size())
			var ledger_balanced := _net_sum(result["score_changes"]) == 0
			var native_runtime: Object = game.get("ai_manager").get("native_csharp_runtime")
			var replay: String = str(native_runtime.call("GetDecisionAuditPath"))
			if not ledger_balanced or not FileAccess.file_exists(replay):
				push_error("book scout requires full settlement and research-only native replay")
				quit(1)
				return
			manifest.append({"seed": seed_base + deal * 1009, "seat": seat, "nodes": selected.values(), "original_completed": true,
				"ledger_balanced": true, "physical_integrity": _physical_integrity(game), "score_changes": result["score_changes"],
				"native_replay_path": replay, "native_replay_prefix_sha256": FileAccess.get_sha256(replay)})
			game.call("abort_agent_round")
			game.queue_free()
			await process_frame
			_write_report({"origin": "natural_actual_action_scan", "rows": manifest}, output)
			print("actual_action_scout seed=", seed_base + deal * 1009, " seat=", seat, " kinds=", selected.keys())
	quit()


func _restore_fields(game: Node, fields: Dictionary) -> void:
	super._restore_fields(game, fields)
	if _read_bool_arg("--research-recording=", false):
		game.call("set_research_recording_enabled", true)
