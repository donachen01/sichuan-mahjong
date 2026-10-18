extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Every controlled turn/reaction, without outcome or hidden-hand selection.
# Hidden labels are separate files and never passed into the prediction policy.
func _run() -> void:
	var output := _read_string_arg("--output=", "")
	var seed_base := _read_int_arg("--seed-base=", 20561073)
	var deals := _read_int_arg("--rounds=", 16)
	var opponent := _read_string_arg("--opponent-variant=", "frozen_cashflow_claims_v1")
	var rows: Array = []
	var index: Array = []
	var completed: Array = []
	if output.is_empty():
		quit(2)
		return
	for deal in range(deals):
		for seat in range(4):
			var seed := seed_base + deal * 1009
			var game: Node = GAME_STATE_SCRIPT.new()
			root.add_child(game)
			await process_frame
			game.set("ai_agent_generation", 40000 + deal * 4 + seat)
			game.call("set_test_seed", seed)
			game.call("set_ai_preset", "bone_ash")
			var variants := {}
			for other in range(4):
				variants[other] = "current" if other == seat else opponent
			game.set("test_ai_policy_variants_by_seat", variants)
			game.call("start_new_round")
			_prepare_all_ai_table(game)
			var observations := 0
			for step in range(1500):
				var phase := int(game.get("current_phase"))
				if phase == 7:
					break
				var is_controlled := phase == 5 and int(game.get("current_turn_seat")) == seat
				if phase == 6:
					is_controlled = int(game.call("_get_next_ai_reaction_candidate").get("seat", -1)) == seat
				if is_controlled:
					var views: Array = game.call("_agent_views")
					var label := {"seed": seed, "seat": seat, "state": {"wall": game.get("wall").duplicate(true), "players": game.get("players").duplicate(true)}}
					var label_path := output.get_base_dir().path_join("labels/%d_%d_%d.json" % [seed, seat, step])
					_write_data(label, label_path)
					var sha := FileAccess.get_sha256(label_path)
					rows.append({"seed": seed, "seat": seat, "opponent": opponent, "step": step, "phase": phase,
						"input_sha256": sha, "public_input": views[seat].duplicate(true), "measured_before_root_action": true,
						"uses_hidden_for_selection": false, "outcome_not_observed": true})
					index.append({"node": {"path": label_path, "sha256": sha}})
					observations += 1
				if not _step(game) or not _physical_integrity(game)["passed"]:
					push_error("natural posterior distribution failed legal physical continuation")
					quit(1)
					return
				await process_frame
			if int(game.get("current_phase")) != 7:
				push_error("natural posterior original game incomplete")
				quit(1)
				return
			var result := _extract_round_result(game, 1, 0, false)
			var scores: Dictionary = result["score_changes"]
			if _net_sum(scores) != 0:
				push_error("natural posterior final score not balanced")
				quit(1)
				return
			completed.append({"seed": seed, "seat": seat, "observations": observations, "fully_settled": true, "scores": scores})
			game.call("abort_agent_round")
			game.queue_free()
			await process_frame
			print("posterior_distribution seed=", seed, " seat=", seat, " observations=", observations)
	_write_report({"origin": "all_natural_controlled_decisions_public_inputs", "rows": rows, "complete_games": completed}, output)
	_write_data(index, output + ".labels-index.json")
	quit()

func _write_data(data: Variant, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot preserve isolated natural label")
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
