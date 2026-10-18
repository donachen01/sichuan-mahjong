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
	var seed_base := _read_int_arg("--seed-base=", 20431007)
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
			for s in range(4):
				variants[s] = "current" if s == seat else opponent
			game.set("test_ai_policy_variants_by_seat", variants)
			game.call("start_new_round")
			_prepare_all_ai_table(game)
			var prefix: Array = []
			var found := false
			for step in range(1500):
				if int(game.get("current_phase")) == 7:
					break
				if int(game.get("current_phase")) == 5 and int(game.get("current_turn_seat")) == seat \
					and str(game.get("last_turn_context").get("draw_reason", "")) == "normal_draw" \
					and bool(game.call("_can_seat_self_hu_now", seat)):
					game.call("_clear_pending_ai_async_state")
					var views: Array = game.call("_agent_views")
					var checkpoints: Array = game.get("ai_manager").capture_round_agent_memories(views)
					if checkpoints.size() != 4:
						push_error("full seat agent checkpoints unavailable")
						quit(1)
						return
					var snapshot := {"seed": seed_base + deal * 1009, "seat": seat, "opponent": opponent,
						"origin": "naturally_reached_ordinary_self_hu", "uses_hidden_for_selection": false,
						"outcome_not_observed_at_selection": true, "views": views, "checkpoints": checkpoints,
						"state": _capture_fields(game), "prefix": prefix, "world_hash": _checkpoint_world_hash(game, seat)}
					var path := output.get_base_dir().path_join("node_%d_%d.json" % [snapshot["seed"], seat])
					_write_report(snapshot, path)
					manifest.append({"seed": snapshot["seed"], "seat": seat, "triggered": true, "path": path,
						"sha256": FileAccess.get_sha256(path), "prefix_steps": prefix.size()})
					found = true
					break
				prefix.append({"phase": int(game.get("current_phase")), "seat": int(game.get("current_turn_seat")),
					"public_event_sha256": JSON.stringify(game.get("ai_public_events")).sha256_text(),
					"world_hash": _checkpoint_world_hash(game, seat)})
				_step(game)
				await process_frame
			if not found:
				manifest.append({"seed": seed_base + deal * 1009, "seat": seat, "triggered": false})
			game.call("abort_agent_round")
			game.queue_free()
			await process_frame
			print("actual_scout seed=", seed_base + deal * 1009, " seat=", seat, " found=", found)
			_write_report({"origin": "natural_opportunity_scan", "criterion": "first ordinary self-Hu of controlled current seat", "rows": manifest}, output)
	quit()

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
	var reference_view: Dictionary = snapshot["views"][seat]
	var actions: Array = [{"action": "hu", "tile_type": -1}, {"action": "hu", "tile_type": -1, "repeat_control": true}]
	for t in range(27):
		if int(reference_view["hand18"][t]) > 0:
			actions.append({"action": "refuse_discard", "tile_type": t})
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
		var executed := false
		if action["action"] == "hu":
			executed = bool(game.call("_execute_self_draw_hu", seat))
		else:
			var selected: Dictionary = {}
			for tile in game.get("players")[seat]["hand_tiles"]:
				if int(game.call("_sichuan_tile_type", tile)) == int(action["tile_type"]):
					selected = tile
					break
			game.get("self_hu_pass_locks")[str(seat)] = int(game.call("_get_last_draw_tile_id_for_seat", seat))
			executed = not selected.is_empty() and bool(game.call("_discard_tile_internal", seat, int(selected["id"])))
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
		rows.append({"root_action": action, "root_world_sha256": snapshot["world_hash"], "completed": true,
			"ledger_balanced": balanced, "seat_delta": _seat_delta(deltas, seat), "trace": trace,
			"result": result, "policy_information_contract": "own-hand and public bridge per seat; exact world used only by rule execution"})
		game.call("abort_agent_round")
		game.queue_free()
		await process_frame
		_write_report({"input_sha256": FileAccess.get_sha256(path), "origin": snapshot["origin"], "rows": rows}, output)
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
