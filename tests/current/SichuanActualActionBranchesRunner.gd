extends "res://tests/current/sichuan_ai_pressure_benchmark.gd"

# Offline research only. Full hidden worlds are labels/simulation inputs;
# every policy request still uses its own normal public-information bridge.
func _run() -> void:
	var mode := _read_string_arg("--mode=", "scout")
	var output := _read_string_arg("--output=", "")
	if output.is_empty():
		quit(2)
		return
	if mode == "scout":
		await _scout(output)
	else:
		await _branches(output)

func _step(game: Node) -> bool:
	match int(game.get("current_phase")):
		2:
			if bool(game.get("opening_roll_pending_completion")):
				return bool(game.call("complete_opening_roll"))
		3:
			game.call("_auto_select_ai_ding_que")
			game.call("_complete_ding_que_if_ready")
			return true
		5:
			return bool(game.call("run_ai_turn"))
		6:
			if bool(game.call("is_ai_reaction_pending")):
				return bool(game.call("run_ai_reaction"))
			game.call("_finalize_reaction_without_claim")
			return true
	return false

func _scout(output: String) -> void:
	var manifest: Array = []
	var seed_base := _read_int_arg("--seed-base=", 20453017)
	var deals := _read_int_arg("--rounds=", 1)
	var only_seat := int(_read_string_arg("--seat=", "-1"))
	var opponent := _read_string_arg("--opponent-variant=", "frozen_cashflow_claims_v1")
	for deal in range(deals):
		for seat in range(4):
			if only_seat >= 0 and seat != only_seat:
				continue
			var game: Node = GAME_STATE_SCRIPT.new()
			root.add_child(game)
			await process_frame
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
			manifest.append({"seed": seed_base + deal * 1009, "seat": seat, "nodes": selected.values(), "original_completed": true})
			game.call("abort_agent_round")
			game.queue_free()
			await process_frame
			_write_report({"origin": "natural_actual_action_scan", "rows": manifest}, output)
			print("actual_action_scout seed=", seed_base + deal * 1009, " seat=", seat, " kinds=", selected.keys())
	quit()

func _natural_kinds(game: Node, seat: int) -> Array:
	var kinds: Array = []
	var phase: int = game.get("current_phase")
	if phase == 6:
		var reaction: Dictionary = game.call("_get_next_ai_reaction_candidate")
		if int(reaction.get("seat", -1)) != seat:
			return kinds
		if reaction.get("can_hu", false):
			kinds.append("hu_reaction")
		if reaction.get("can_peng", false) or reaction.get("can_gang", false):
			kinds.append("meld_reaction")
		return kinds
	if phase != 5 or game.get("current_turn_seat") != seat:
		return kinds
	if not game.call("_find_all_an_gang_options", seat).is_empty() or not game.call("_find_all_add_gang_options", seat).is_empty():
		kinds.append("self_gang")
	if game.call("_can_seat_self_hu_now", seat):
		return kinds
	var player: Dictionary = game.get("players")[seat]
	var counts := {}
	var suit_counts := {}
	var missing := false
	for tile in player["hand_tiles"]:
		var t: int = game.call("_sichuan_tile_type", tile)
		counts[t] = int(counts.get(t, 0)) + 1
		suit_counts[t / 9] = int(suit_counts.get(t / 9, 0)) + 1
		missing = missing or tile["suit"] == player["ding_que"]
	if missing or counts.size() < 2:
		return kinds
	var pairs := 0
	var triplets := 0
	for n in counts.values():
		pairs += int(n) / 2
		triplets += 1 if n >= 3 else 0
	if player["melds"].is_empty() and pairs >= 4:
		kinds.append("pair_route")
	if triplets > 0:
		kinds.append("triplet_route")
	for suit in suit_counts:
		var compatible := true
		for meld in player["melds"]:
			compatible = compatible and int(game.call("_sichuan_tile_type", meld["tiles"][0])) / 9 == int(suit)
		if compatible and int(suit_counts[suit]) * 4 >= player["hand_tiles"].size() * 3:
			kinds.append("flush_route")
			break
	if int(game.get("wall_count")) <= 16:
		kinds.append("endgame_discard")
	var ready_options := 0
	for t in counts:
		var after: Array = player["hand_tiles"].duplicate(true)
		for i in range(after.size()):
			if int(game.call("_sichuan_tile_type", after[i])) == int(t):
				after.remove_at(i)
				break
		var waits: Array = game.get("hu_checker").get_ting_tiles(after, player["ding_que"], game.get("rules"), player["melds"].size(), player["melds"])
		if not waits.is_empty():
			ready_options += 1
	if ready_options >= 2:
		kinds.append("multiwait_discard")
	return kinds

func _root_actions(game: Node, seat: int) -> Array:
	var actions: Array = [{"action": "baseline", "tile_type": -1}, {"action": "baseline", "tile_type": -1, "repeat_control": true}]
	if int(game.get("current_phase")) == 6:
		var c: Dictionary = game.call("_get_reaction_candidate_for_seat", seat)
		actions.append({"action": "pass", "tile_type": -1})
		for kind in ["hu", "peng", "gang"]:
			if bool(c.get("can_" + kind, false)) and (kind == "hu" or not game.call("_has_higher_priority_candidate_than", seat, kind)):
				actions.append({"action": kind, "tile_type": -1})
		return actions
	if bool(game.call("_can_seat_self_hu_now", seat)):
		actions.append({"action": "self_hu", "tile_type": -1})
	var player: Dictionary = game.get("players")[seat]
	var has_missing := false
	for tile in player["hand_tiles"]:
		has_missing = has_missing or tile["suit"] == player["ding_que"]
	var seen := {}
	for tile in player["hand_tiles"]:
		if has_missing and tile["suit"] != player["ding_que"]:
			continue
		var t: int = game.call("_sichuan_tile_type", tile)
		if not seen.has(t):
			actions.append({"action": "discard", "tile_type": t})
			seen[t] = true
	for option in game.call("_find_all_an_gang_options", seat):
		actions.append({"action": "an_gang", "tile_type": int(game.call("_sichuan_tile_type", option["tiles"][0])), "option": option})
	for option in game.call("_find_all_add_gang_options", seat):
		actions.append({"action": "add_gang", "tile_type": int(game.call("_sichuan_tile_type", option["tile"])), "option": option})
	return actions

func _execute_root(game: Node, seat: int, action: Dictionary) -> bool:
	match action["action"]:
		"baseline":
			return _step(game)
		"self_hu":
			return bool(game.call("_execute_self_draw_hu", seat))
		"hu":
			return bool(game.call("_execute_hu_on_discard", seat))
		"pass":
			return bool(game.call("_pass_ai_reaction", seat))
		"peng":
			return bool(game.call("_execute_peng", seat))
		"gang":
			return bool(game.call("_execute_gang", seat))
		"an_gang":
			return bool(game.call("_execute_an_gang", seat, action["option"]))
		"add_gang":
			return bool(game.call("_start_add_gang", seat, action["option"]))
		"discard":
			for tile in game.get("players")[seat]["hand_tiles"]:
				if int(game.call("_sichuan_tile_type", tile)) == int(action["tile_type"]):
					if game.call("_can_seat_self_hu_now", seat):
						game.get("self_hu_pass_locks")[str(seat)] = int(game.call("_get_last_draw_tile_id_for_seat", seat))
					return bool(game.call("_discard_tile_internal", seat, int(tile["id"])))
	return false

func _capture_fields(game: Node) -> Dictionary:
	var fields := {}
	for prop in game.get_script().get_script_property_list():
		var name: String = prop["name"]
		var value = game.get(name)
		if typeof(value) == TYPE_OBJECT or typeof(value) == TYPE_CALLABLE or typeof(value) == TYPE_SIGNAL:
			continue
		fields[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return fields

func _restore_fields(game: Node, fields: Dictionary) -> void:
	for name in fields:
		var saved = fields[name]
		var value = saved.duplicate(true) if saved is Array or saved is Dictionary else saved
		var template = game.get(name)
		if template is Array and value is Array:
			template.assign(value)
			game.set(name, template)
		else:
			game.set(name, value)
	game.set("ai_agents_started", false)
	game.call("_clear_pending_ai_async_state")

func _branches(output: String) -> void:
	var path := _read_string_arg("--input=", "")
	var snapshot: Dictionary = _integer_values(JSON.parse_string(FileAccess.get_file_as_string(path)))
	var seat := int(snapshot["seat"])
	var actions: Array = snapshot["root_actions"]
	var rows: Array = []
	for action in actions:
		var game: Node = GAME_STATE_SCRIPT.new()
		root.add_child(game)
		await process_frame
		_restore_fields(game, snapshot["state"])
		var physical := _physical_integrity(game)
		if not physical["passed"] or _checkpoint_world_hash(game, seat) != snapshot["world_hash"]:
			_write_report({"physical": physical, "expected": snapshot["world_hash"], "actual": _checkpoint_world_hash(game, seat), "restored": _capture_fields(game)}, output + ".restore-failure.json")
			push_error("restored world differs from original legal node")
			quit(1)
			return
		var views: Array = snapshot["views"].duplicate(true)
		var generation := 10000 + rows.size()
		for view in views:
			view["hostGeneration"] = generation
		game.set("ai_agent_generation", generation)
		var restored: bool = game.get("ai_manager").update_round_agents("restore", views, "", 0, snapshot["checkpoints"])
		if not restored:
			quit(1)
			return
		game.set("ai_agents_started", true)
		var actual_views: Array = game.call("_agent_views")
		for i in range(4):
			var expected_view: Dictionary = views[i].duplicate(true)
			var actual_view: Dictionary = _integer_values(JSON.parse_string(JSON.stringify(actual_views[i])))
			expected_view.erase("hostGeneration")
			actual_view.erase("hostGeneration")
			if expected_view != actual_view:
				var changed_fields: Array = []
				for key in expected_view:
					if expected_view[key] != actual_view.get(key):
						changed_fields.append(key)
				_write_report({"seat": i, "changed_fields": changed_fields}, output + ".public-restore-failure.json")
				push_error("restored public policy input differs from original")
				quit(1)
				return
		game.get("ai_manager").set_compact_runtime_snapshots(false)
		var root_phase: int = game.get("current_phase")
		var root_public_before: Array = game.get("ai_public_events").duplicate(true)
		var executed := _execute_root(game, seat, action)
		var root_public_after: Array = game.get("ai_public_events").duplicate(true)
		var root_diagnostic: Dictionary = {}
		if action["action"] == "baseline":
			root_diagnostic = game.get("ai_manager").get("latest_reaction_snapshot" if root_phase == 6 else "latest_turn_snapshot").duplicate(true)
		if not executed:
			push_error("research root action not legally executable")
			quit(1)
			return
		var trace: Array = []
		for step in range(1500):
			if not _physical_integrity(game)["passed"]:
				push_error("counterfactual continuation violated physical/group invariant")
				quit(1)
				return
			if int(game.get("current_phase")) == 7:
				break
			trace.append({"phase": int(game.get("current_phase")), "seat": int(game.get("current_turn_seat")),
				"world_hash": _checkpoint_world_hash(game, seat), "public_sha256": JSON.stringify(game.get("ai_public_events")).sha256_text()})
			_step(game)
			await process_frame
		var result := _extract_round_result(game, 1, trace.size(), int(game.get("current_phase")) != 7)
		var deltas: Dictionary = result["score_changes"]
		var balanced := _net_sum(deltas) == 0
		if result["forced_stop"] or not balanced:
			push_error("counterfactual did not reach valid complete settlement")
			quit(1)
			return
		rows.append({"root_action": action, "root_public_events": root_public_after.slice(root_public_before.size()), "root_policy_diagnostic": root_diagnostic, "root_world_sha256": snapshot["world_hash"], "completed": true,
			"ledger_balanced": balanced, "seat_delta": _seat_delta(deltas, seat), "trace": trace,
			"result": result, "policy_information_contract": "own-hand and public bridge per seat; exact world used only by rule execution"})
		game.call("abort_agent_round")
		game.queue_free()
		await process_frame
		_write_report({"input_sha256": FileAccess.get_sha256(path), "origin": snapshot["origin"], "kind": snapshot["kind"], "root_actions_sha256": JSON.stringify(actions).sha256_text(), "rows": rows}, output)
		print("actual_branch action=", action, " score=", rows.back()["seat_delta"])
	if rows[0]["seat_delta"] != rows[1]["seat_delta"] or rows[0]["trace"] != rows[1]["trace"]:
		push_error("identical restored control branches diverged")
		quit(1)
		return
	quit()

func _physical_integrity(game: Node) -> Dictionary:
	var ids := {}
	var reasons: Array = []
	for tile in game.get("wall"):
		ids[tile["id"]] = true
	var count: int = game.get("wall").size()
	for player in game.get("players"):
		if player["hand_count"] != player["hand_tiles"].size():
			reasons.append("concealed count mismatch")
		var tiles: Array = player["hand_tiles"].duplicate()
		tiles.append_array(player["discards"])
		for meld in player["melds"]:
			var n: int = meld["tiles"].size()
			if n != (3 if meld["type"] == "peng" else 4):
				reasons.append("invalid individual meld group")
			tiles.append_array(meld["tiles"])
		for tile in tiles:
			count += 1
			if ids.has(tile["id"]):
				reasons.append("duplicate physical tile")
			ids[tile["id"]] = true
	for player in game.get("players"):
		var won_tile: Dictionary = player.get("winning_tile", {})
		if bool(player.get("has_won", false)) and not won_tile.is_empty() and not ids.has(won_tile["id"]):
			ids[won_tile["id"]] = true
			count += 1
	if count != 108 or ids.size() != 108 or game.get("wall_count") != game.get("wall").size():
		reasons.append("108 tile/wall mismatch")
	return {"passed": reasons.is_empty(), "reasons": reasons}

func _integer_values(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		return value.map(_integer_values)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _integer_values(value[key])
		return result
	return value
