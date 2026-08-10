extends SceneTree

const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const OLD_HAND_SCORER_SCRIPT := preload("res://scripts/ai/sichuan_old_hand_discard_scorer.gd")

const DEFAULT_TOTAL_ROUNDS := 40
const DEFAULT_MAX_STEPS_PER_ROUND := 5000

var old_hand_scorer = OLD_HAND_SCORER_SCRIPT.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var total_rounds := _read_int_arg("--rounds=", DEFAULT_TOTAL_ROUNDS)
	var max_steps_per_round := _read_int_arg("--max-steps=", DEFAULT_MAX_STEPS_PER_ROUND)
	var preset_name := _read_string_arg("--preset=", "bone_ash")
	var compare_preset_name := _read_string_arg("--compare-preset=", "")
	var seed_base := _read_int_arg("--seed-base=", 20260712)
	var record_discard_audit := _read_bool_arg("--record-discard-audit=", false)
	var paired_policy := _read_bool_arg("--paired-policy=", false)
	var output_path := _read_string_arg("--output=", _build_default_report_path(total_rounds, preset_name, compare_preset_name, "json"))
	var csv_output_path := _read_string_arg("--csv-output=", _build_default_report_path(total_rounds, preset_name, compare_preset_name, "csv"))
	var discard_audit_output_path := _read_string_arg("--discard-audit-output=", _build_default_audit_path(total_rounds, preset_name, compare_preset_name, "jsonl"))
	var discard_audit_csv_output_path := _read_string_arg("--discard-audit-csv-output=", _build_default_audit_path(total_rounds, preset_name, compare_preset_name, "csv"))
	var game_state: Node = GAME_STATE_SCRIPT.new()
	get_root().add_child(game_state)
	await process_frame
	game_state.call("set_test_seed", seed_base)

	var discard_audit_records: Array = []
	var report: Dictionary
	if paired_policy:
		game_state.queue_free()
		await process_frame
		report = await _run_policy_rotation_benchmark(total_rounds, max_steps_per_round, seed_base)
	elif compare_preset_name != "":
		report = await _run_ab_benchmark(game_state, preset_name, compare_preset_name, total_rounds, max_steps_per_round, record_discard_audit, discard_audit_records, seed_base)
	else:
		report = await _run_single_preset_benchmark(game_state, preset_name, total_rounds, max_steps_per_round, record_discard_audit, discard_audit_records)
	if record_discard_audit:
		_write_discard_audit(discard_audit_records, discard_audit_output_path)
		_write_discard_audit_csv(discard_audit_records, discard_audit_csv_output_path)
		report["discard_audit"] = _build_discard_audit_summary(discard_audit_records, discard_audit_output_path, discard_audit_csv_output_path, game_state)
	if not paired_policy:
		report["acceptance_metrics"] = _build_acceptance_metrics(report)
	_print_summary(report)
	_write_report(report, output_path)
	if not paired_policy:
		_write_csv_report(report, csv_output_path)
	quit()


func _run_single_preset_benchmark(game_state: Node, preset_name: String, total_rounds: int, max_steps_per_round: int, record_discard_audit: bool = false, discard_audit_records: Array = []) -> Dictionary:
	game_state.call("set_ai_preset", preset_name)
	var stats := _create_stats()
	stats["benchmark_mode"] = "single"
	stats["preset_name"] = preset_name
	var round_counter := 0
	while round_counter < total_rounds:
		print("benchmark_round_start=", round_counter + 1, " preset=", preset_name)
		_prepare_all_ai_table(game_state)
		var round_audit_records: Array = []
		var result := await _play_single_round(game_state, round_counter + 1, max_steps_per_round, preset_name, record_discard_audit, round_audit_records)
		if record_discard_audit:
			_finalize_round_discard_audit(round_audit_records, result)
			discard_audit_records.append_array(round_audit_records)
		_accumulate_round_stats(stats, result)
		print("benchmark_round_end=", round_counter + 1, " steps=", int(result.get("steps", 0)), " end_reason=", str(result.get("end_reason", "")), " forced=", bool(result.get("forced_stop", false)))
		round_counter += 1
		if not game_state.call("advance_to_next_round"):
			push_error("Failed to advance after round %d" % round_counter)
			break
		await process_frame
	_finalize_stats(stats, game_state)
	return stats


func _run_ab_benchmark(game_state: Node, preset_a: String, preset_b: String, total_rounds: int, max_steps_per_round: int, record_discard_audit: bool = false, discard_audit_records: Array = [], seed_base: int = 20260712) -> Dictionary:
	var combined := {
		"benchmark_mode": "ab_compare",
		"preset_a": preset_a,
		"preset_b": preset_b,
		"seed_base": seed_base,
		"paired_seed_rounds": total_rounds,
	}
	var stats_a := await _run_single_preset_benchmark(game_state, preset_a, total_rounds, max_steps_per_round, record_discard_audit, discard_audit_records)
	game_state.queue_free()
	await process_frame
	var baseline_state: Node = GAME_STATE_SCRIPT.new()
	get_root().add_child(baseline_state)
	await process_frame
	baseline_state.call("set_test_seed", seed_base)
	var stats_b := await _run_single_preset_benchmark(baseline_state, preset_b, total_rounds, max_steps_per_round, record_discard_audit, discard_audit_records)
	combined["report_a"] = stats_a
	combined["report_b"] = stats_b
	combined["comparison"] = _build_comparison(stats_a, stats_b)
	return combined


func _run_policy_rotation_benchmark(deals: int, max_steps_per_round: int, seed_base: int) -> Dictionary:
	var candidate_deltas: Array[float] = []
	var games: Array[Dictionary] = []
	var forced_stops := 0
	var ledger_failures := 0
	for deal in range(deals):
		var deal_seed := seed_base + deal * 1009
		for candidate_seat in range(4):
			print("paired_policy_start deal=", deal + 1, " candidate_seat=", candidate_seat, " seed=", deal_seed)
			var game_state: Node = GAME_STATE_SCRIPT.new()
			get_root().add_child(game_state)
			await process_frame
			game_state.call("set_test_seed", deal_seed)
			game_state.call("set_ai_preset", "bone_ash")
			var variants := {}
			for seat in range(4):
				variants[seat] = "current" if seat == candidate_seat else "frozen_hard_tier_v1"
			game_state.set("test_ai_policy_variants_by_seat", variants)
			game_state.call("start_new_round")
			await process_frame
			_prepare_all_ai_table(game_state)
			var result := await _play_single_round(
				game_state, deal * 4 + candidate_seat + 1, max_steps_per_round,
				"paired_candidate_seat_%d" % candidate_seat)
			var score_changes: Dictionary = result.get("score_changes", {})
			var gang_net := _build_gang_net(result)
			var cha_jiao_net := _build_cha_jiao_net(result.get("draw_assessment", []))
			var score_sum := _net_sum(score_changes)
			var gang_sum := _net_sum(gang_net)
			var cha_jiao_sum := _net_sum(cha_jiao_net)
			var balanced := score_sum == 0 and gang_sum == 0 and cha_jiao_sum == 0
			if not balanced:
				ledger_failures += 1
			if bool(result.get("forced_stop", false)):
				forced_stops += 1
			var candidate_delta := float(_seat_delta(score_changes, candidate_seat))
			candidate_deltas.append(candidate_delta)
			games.append({
				"deal": deal + 1,
				"seed": deal_seed,
				"candidate_seat": candidate_seat,
				"candidate_delta": candidate_delta,
				"score_changes": score_changes.duplicate(true),
				"gang_net": gang_net.duplicate(true),
				"cha_jiao_net": cha_jiao_net.duplicate(true),
				"score_sum": score_sum,
				"gang_sum": gang_sum,
				"cha_jiao_sum": cha_jiao_sum,
				"ledger_balanced": balanced,
				"forced_stop": bool(result.get("forced_stop", false)),
				"steps": int(result.get("steps", 0)),
				"end_reason": str(result.get("end_reason", "")),
			})
			print("paired_policy_end delta=", candidate_delta, " balanced=", balanced, " forced=", bool(result.get("forced_stop", false)))
			game_state.queue_free()
			await process_frame

	var ci := _bootstrap_mean_ci(candidate_deltas, seed_base ^ 0x5A17)
	var average_delta := 0.0 if candidate_deltas.is_empty() else _float_mean(candidate_deltas)
	var gate_reasons: Array[String] = []
	if forced_stops > 0:
		gate_reasons.append("存在强制结束对局")
	if ledger_failures > 0:
		gate_reasons.append("存在收支账本不守恒对局")
	if float(ci.get("low", 0.0)) <= 0.0:
		gate_reasons.append("候选平均净分 95% 置信区间下界未高于 0")
	if candidate_deltas.size() < 40:
		gate_reasons.append("有效轮换对局不足 40 局，仅作烟雾或趋势证据")
	if gate_reasons.is_empty():
		gate_reasons.append("整局配对晋级门槛通过")
	return {
		"benchmark_mode": "paired_policy_rotation",
		"candidate_policy": "bone_ash_current",
		"baseline_policy": "frozen_hard_tier_v1",
		"deals": deals,
		"games": candidate_deltas.size(),
		"seed_base": seed_base,
		"candidate_average_delta": average_delta,
		"candidate_positive_rate": _positive_rate(candidate_deltas),
		"candidate_delta_ci_low": float(ci.get("low", 0.0)),
		"candidate_delta_ci_high": float(ci.get("high", 0.0)),
		"forced_stop_games": forced_stops,
		"ledger_failure_games": ledger_failures,
		"promotion_gate_passed": gate_reasons.size() == 1 and gate_reasons[0].begins_with("整局配对晋级"),
		"gate_reasons": gate_reasons,
		"game_results": games,
	}


func _net_sum(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func _float_mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(maxi(1, values.size()))


func _positive_rate(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var positive := 0
	for value in values:
		if value > 0:
			positive += 1
	return float(positive) / float(values.size())


func _bootstrap_mean_ci(values: Array[float], seed: int) -> Dictionary:
	if values.is_empty():
		return {"low": 0.0, "high": 0.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var means: Array[float] = []
	for _sample in range(800):
		var sum := 0.0
		for _index in range(values.size()):
			sum += values[rng.randi_range(0, values.size() - 1)]
		means.append(sum / float(values.size()))
	means.sort()
	return {
		"low": means[int(floor(means.size() * 0.025))],
		"high": means[int(floor(means.size() * 0.975))],
	}


func _play_single_round(game_state: Node, round_no: int, max_steps_per_round: int, preset_name: String, record_discard_audit: bool = false, discard_audit_records: Array = []) -> Dictionary:
	var step := 0
	while step < max_steps_per_round:
		_prepare_all_ai_table(game_state)
		var before_discard_count := int(game_state.get("discard_pile").size())
		var before_scores := _seat_scores(game_state)
		var phase := int(game_state.get("current_phase"))
		match phase:
			2:
				if bool(game_state.get("opening_roll_pending_completion")):
					game_state.call("complete_opening_roll")
			3:
				game_state.call("_auto_select_ai_ding_que")
				game_state.call("_complete_ding_que_if_ready")
			5:
				if bool(game_state.call("is_ai_turn_ready")):
					var turn_ok := bool(game_state.call("run_ai_turn"))
					if not turn_ok and step % 20 == 0:
						_print_turn_stall_debug(game_state, step)
			6:
				if bool(game_state.call("is_ai_reaction_pending")):
					var reaction_ok := bool(game_state.call("run_ai_reaction"))
					if not reaction_ok and step % 20 == 0:
						print("reaction_stall step=", step, " debug=", str(game_state.get("debug_last_message")))
				else:
					game_state.call("_finalize_reaction_without_claim")
			7:
				return _extract_round_result(game_state, round_no, step)
			_:
				pass
		if record_discard_audit:
			_append_new_discard_audit_records(discard_audit_records, game_state, round_no, step, preset_name, before_discard_count, before_scores)
		step += 1
		await process_frame

	push_error("Round %d exceeded max steps %d" % [round_no, max_steps_per_round])
	return _extract_round_result(game_state, round_no, step, true)


func _print_turn_stall_debug(game_state: Node, step: int) -> void:
	var turn_seat := int(game_state.get("current_turn_seat"))
	var players: Array = game_state.get("players")
	var player: Dictionary = players[turn_seat] if turn_seat >= 0 and turn_seat < players.size() else {}
	print(
		"turn_stall step=", step,
		" phase=", int(game_state.get("current_phase")),
		" seat=", turn_seat,
		" hand_count=", int(player.get("hand_count", -1)),
		" ding_que=", str(player.get("ding_que", "")),
		" debug=", str(game_state.get("debug_last_message"))
	)


func _prepare_all_ai_table(game_state: Node) -> void:
	var players: Array = game_state.get("players")
	if players.is_empty():
		return
	var ai_level := int(game_state.get("ai_level"))
	for index in range(players.size()):
		var player: Dictionary = players[index]
		player["is_ai"] = true
		player["ai_level"] = ai_level
		players[index] = player
	game_state.set("players", players)


func _extract_round_result(game_state: Node, round_no: int, steps: int, forced_stop: bool = false) -> Dictionary:
	var settlement_data: Dictionary = game_state.get("settlement_data").duplicate(true)
	var players: Array = game_state.get("players").duplicate(true)
	var score_changes: Dictionary = settlement_data.get("score_changes", {})
	var win_events: Array = settlement_data.get("win_events", [])
	var gang_events: Array = settlement_data.get("gang_events", [])
	var round_winners: Array = game_state.get("round_winners")
	return {
		"round_no": round_no,
		"steps": steps,
		"forced_stop": forced_stop,
		"current_phase": int(game_state.get("current_phase")),
		"current_turn_seat": int(game_state.get("current_turn_seat")),
		"debug_last_message": str(game_state.get("debug_last_message")),
		"backend": game_state.call("_build_full_ai_core_debug_snapshot"),
		"opening_roll_pending_completion": bool(game_state.get("opening_roll_pending_completion")),
		"pending_reaction_count": int(game_state.get("pending_reactions").size()),
		"end_reason": str(settlement_data.get("end_reason", "")),
		"winner_seats": round_winners.duplicate(),
		"score_changes": score_changes.duplicate(true),
		"win_events": win_events.duplicate(true),
		"gang_events": gang_events.duplicate(true),
		"tui_gang_refunds": settlement_data.get("tui_gang_refunds", []).duplicate(true),
		"transfer_events": settlement_data.get("transfer_events", []).duplicate(true),
		"draw_assessment": settlement_data.get("draw_assessment", []).duplicate(true),
		"players": players,
		"ai_decision_metrics": game_state.get("ai_decision_metrics").duplicate(true),
		"debug_decision_trace": game_state.call("_build_debug_decision_trace_snapshot"),
	}


func _append_new_discard_audit_records(records: Array, game_state: Node, round_no: int, step: int, preset_name: String, before_discard_count: int, before_scores: Dictionary) -> void:
	var discard_pile: Array = game_state.get("discard_pile")
	if discard_pile.size() <= before_discard_count:
		return
	var players: Array = game_state.get("players")
	var after_scores := _seat_scores(game_state)
	var fallback_analysis := _latest_turn_analysis(game_state)
	var trace_snapshot: Dictionary = game_state.call("_build_debug_decision_trace_snapshot")
	for index in range(before_discard_count, discard_pile.size()):
		var discard_entry: Dictionary = discard_pile[index]
		var seat := int(discard_entry.get("seat", -1))
		var player := _player_by_seat(players, seat)
		var tile: Dictionary = discard_entry.get("tile", {})
		var record := {
			"schema_version": 2,
			"record_type": "discard",
			"round_no": round_no,
			"step": step,
			"preset": preset_name,
			"discard_index": index + 1,
			"seat": seat,
			"seat_name": str(player.get("nickname", "")),
			"tile_id": int(tile.get("id", -1)),
			"tile_name": str(tile.get("display_name", "?")),
			"suit": str(tile.get("suit", "")),
			"rank": int(tile.get("rank", 0)),
			"tile_type": _tile_type(tile),
			"ding_que": str(player.get("ding_que", "")),
			"hand_count_after": int(player.get("hand_count", 0)),
			"wall_count_after": int(game_state.get("wall_count")),
			"current_phase_after": int(game_state.get("current_phase")),
			"debug_last_message": str(game_state.get("debug_last_message")),
			"scores_before": before_scores.duplicate(true),
			"scores_after_step": after_scores.duplicate(true),
			"ai_trace_session_id": str(trace_snapshot.get("session_id", "")),
			"ai_trace_event_count": int(trace_snapshot.get("event_count", 0)),
			"ai_trace_events_path": str(trace_snapshot.get("events_path_absolute", "")),
		}
		if discard_entry.has("ai_decision"):
			record["ai_decision_source"] = "discard_record"
			record["ai_decision"] = _compact_ai_decision(discard_entry.get("ai_decision", {}))
		else:
			record["ai_decision_source"] = "latest_snapshot"
		var analysis: Dictionary = discard_entry.get("ai_analysis", {})
		if analysis.is_empty():
			analysis = fallback_analysis
		_apply_decision_audit_fields(record, analysis, tile)
		records.append(record)


func _compact_ai_decision(source: Dictionary) -> Dictionary:
	return {
		"round_index": int(source.get("round_index", 0)),
		"seat": int(source.get("seat", -1)),
		"phase": int(source.get("phase", -1)),
		"wall_count": int(source.get("wall_count", 0)),
		"hand_count": int(source.get("hand_count", 0)),
		"action": str(source.get("action", "discard")),
		"tile_id": int(source.get("tile_id", -1)),
		"state_signature": str(source.get("state_signature", "")),
	}


func _latest_turn_analysis(game_state: Node) -> Dictionary:
	var ai_manager = game_state.get("ai_manager")
	if ai_manager == null:
		return {}
	var snapshot = ai_manager.get("latest_turn_snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {}
	var analysis = snapshot.get("analysis", {})
	return analysis.duplicate(true) if typeof(analysis) == TYPE_DICTIONARY else {}


func _apply_decision_audit_fields(record: Dictionary, analysis: Dictionary, tile: Dictionary) -> void:
	record["decision_backend"] = str(analysis.get("backend_mode", analysis.get("backend", "")))
	record["decision_action"] = str(analysis.get("action", "discard"))
	var options: Array = _candidate_options_for_current_rule_context(analysis)
	record["decision_option_count"] = options.size()
	var recommended: Dictionary = analysis.get("recommended", {})
	if not recommended.is_empty():
		record["recommended_tile_name"] = str(recommended.get("tile_name", recommended.get("display_name", recommended.get("tile", {}).get("display_name", ""))))
		record["recommended_score"] = _first_present(recommended, ["score", "csharp_score"])
	var selected := _find_decision_option_for_tile(options, tile)
	if selected.is_empty():
		selected = recommended
	record["decision_matched_actual_discard"] = not selected.is_empty() and _decision_option_matches_tile(selected, tile)
	record["decision_tile_id"] = int(selected.get("tile", {}).get("id", selected.get("tile_id", -1))) if selected.has("tile") else int(selected.get("tile_id", -1))
	record["decision_tile_name"] = str(selected.get("tile_name", selected.get("display_name", selected.get("tile", {}).get("display_name", ""))))
	record["decision_score"] = _first_present(selected, ["score", "csharp_score"])
	record["decision_expected_net_score"] = _first_present(selected, ["expected_net_score", "csharp_expected_net_score"])
	record["decision_self_draw_probability"] = _first_present(selected, ["self_draw_probability", "csharp_self_draw_probability"])
	record["decision_win_probability"] = _first_present(selected, ["win_probability", "csharp_win_probability"])
	record["decision_tenpai_probability"] = _first_present(selected, ["tenpai_probability", "csharp_tenpai_probability"])
	record["decision_expected_fan"] = _first_present(selected, ["expected_fan", "csharp_expected_fan"])
	record["decision_deal_in_probability"] = _first_present(selected, ["deal_in_probability", "csharp_deal_in_probability"])
	record["decision_danger"] = _first_present(selected, ["danger", "csharp_danger"])
	record["decision_risk_label"] = str(selected.get("risk_label", selected.get("csharp_risk_label", "")))
	record["decision_shanten"] = _first_present(selected, ["shanten", "csharp_shanten"])
	record["decision_live_ukeire"] = _first_present(selected, ["live_ukeire", "csharp_live_ukeire"])
	record["decision_reasons"] = selected.get("reasons", selected.get("csharp_reasons", []))
	record["decision_route"] = str(selected.get("route_plan_primary", selected.get("csharp_route_plan_primary", analysis.get("route_plan", {}).get("primary_route", ""))))
	record["decision_routes_after"] = selected.get("routes_after", []).duplicate(true)
	record["decision_route_loss"] = selected.get("route_loss", []).duplicate(true)
	if options.size() > 0:
		var best := _best_score_option(options)
		record["best_candidate_tile_name"] = str(best.get("tile_name", best.get("display_name", best.get("tile", {}).get("display_name", ""))))
		record["best_candidate_score"] = _first_present(best, ["score", "csharp_score"])
		record["decision_score_gap_to_best"] = _score_gap(record.get("decision_score", ""), record.get("best_candidate_score", ""))
	var old_hand_score := old_hand_scorer.score_analysis(
		analysis,
		int(record.get("tile_type", -1)),
		int(record.get("seat", -1)),
		int(record.get("round_no", 0)),
		int(record.get("step", 0))
	)
	if not old_hand_score.is_empty():
		record["old_hand_rating"] = int(old_hand_score.get("rating", 0))
		record["old_hand_rank"] = int(old_hand_score.get("rank", 0))
		record["old_hand_score_gap_to_best"] = int(old_hand_score.get("score_gap_to_best", 0))
		record["old_hand_actual_risk"] = int(old_hand_score.get("actual_risk", 0))
		record["old_hand_best_risk"] = int(old_hand_score.get("best_risk", 0))
		record["old_hand_reason"] = str(old_hand_score.get("reason", ""))
		record["old_hand_score_record"] = old_hand_score.duplicate(true)


func _find_decision_option_for_tile(options: Array, tile: Dictionary) -> Dictionary:
	var tile_id := int(tile.get("id", -1))
	var tile_type := _tile_type(tile)
	for item in options:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = item
		var option_tile: Dictionary = option.get("tile", {})
		if int(option_tile.get("id", option.get("tile_id", -2))) == tile_id:
			return option
		if int(option.get("tile_type", option.get("csharp_tile_type", -2))) == tile_type:
			return option
	return {}


func _candidate_options_for_current_rule_context(analysis: Dictionary) -> Array:
	var options: Array = analysis.get("options", [])
	var forced_suit := str(analysis.get("forced_discard_suit", ""))
	if forced_suit == "" or not bool(analysis.get("forced_ding_que_cleanup", false)):
		return options
	var filtered: Array = []
	for item in options:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = item
		var option_tile: Dictionary = option.get("tile", {})
		if str(option_tile.get("suit", "")) == forced_suit:
			filtered.append(option)
	return filtered if not filtered.is_empty() else options


func _decision_option_matches_tile(option: Dictionary, tile: Dictionary) -> bool:
	if option.is_empty() or tile.is_empty():
		return false
	var tile_id := int(tile.get("id", -1))
	var tile_type := _tile_type(tile)
	var option_tile: Dictionary = option.get("tile", {})
	if tile_id != -1 and int(option_tile.get("id", option.get("tile_id", -2))) == tile_id:
		return true
	return tile_type >= 0 and int(option.get("tile_type", option.get("csharp_tile_type", -2))) == tile_type


func _best_score_option(options: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for item in options:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = item
		var raw_score = _first_present(option, ["score", "csharp_score"])
		if not _is_numeric(raw_score):
			continue
		var score := float(raw_score)
		if best.is_empty() or score > best_score:
			best = option
			best_score = score
	return best


func _first_present(source: Dictionary, keys: Array) -> Variant:
	for key in keys:
		if source.has(key) and source[key] != null and str(source[key]) != "":
			return source[key]
	return ""


func _score_gap(selected_score, best_score) -> Variant:
	if not _is_numeric(selected_score) or not _is_numeric(best_score):
		return ""
	return float(best_score) - float(selected_score)


func _is_numeric(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] or (typeof(value) == TYPE_STRING and str(value).is_valid_float())


func _tile_type(tile: Dictionary) -> int:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var suit_index: int = int({"tiao": 0, "tong": 1, "wan": 2}.get(suit, -1))
	if suit_index < 0 or rank <= 0:
		return -1
	return int(suit_index) * 9 + rank - 1


func _player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if typeof(player) == TYPE_DICTIONARY and int(player.get("seat", -1)) == seat:
			return player
	return {}


func _seat_scores(game_state: Node) -> Dictionary:
	var scores := {}
	for player in game_state.get("players"):
		var seat := int(player.get("seat", -1))
		if seat >= 0:
			scores[str(seat)] = int(player.get("score", 0))
	return scores


func _finalize_round_discard_audit(records: Array, result: Dictionary) -> void:
	var score_changes: Dictionary = result.get("score_changes", {})
	var winner_seats: Array = result.get("winner_seats", [])
	var qing_winner_seats: Array = []
	for event in result.get("win_events", []):
		var fan_detail: Dictionary = event.get("fan_detail", {})
		if str(fan_detail.get("hand_type", "")) == "qing_yi_se":
			qing_winner_seats.append(int(event.get("winner_seat", -1)))
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var seat := int(record.get("seat", -1))
		record["round_end_reason"] = str(result.get("end_reason", ""))
		record["round_forced_stop"] = bool(result.get("forced_stop", false))
		record["round_winner_seats"] = winner_seats.duplicate()
		record["round_qing_winner_seats"] = qing_winner_seats.duplicate()
		record["decision_actual_round_win"] = seat in winner_seats
		var predicted_win = record.get("decision_win_probability", "")
		if _is_numeric(predicted_win):
			var actual_win := 1.0 if seat in winner_seats else 0.0
			record["decision_round_win_brier"] = pow(float(predicted_win) - actual_win, 2.0)
		record["round_score_changes"] = score_changes.duplicate(true)
		record["seat_round_delta"] = _seat_delta(score_changes, seat)
		records[index] = record


func _seat_delta(score_changes: Dictionary, seat: int) -> int:
	if score_changes.has(seat):
		return int(score_changes.get(seat, 0))
	return int(score_changes.get(str(seat), 0))


func _build_gang_net(result: Dictionary) -> Dictionary:
	var net := {0: 0, 1: 0, 2: 0, 3: 0}
	for event in result.get("gang_events", []):
		if str(event.get("related_outcome", "")) == "gang_discard_win":
			continue
		_apply_gang_payment(net, int(event.get("actor_seat", -1)), event.get("payer_seats", []), _gang_unit_score(str(event.get("gang_type", ""))))
	for refund in result.get("tui_gang_refunds", []):
		_apply_gang_payment(net, int(refund.get("actor_seat", -1)), refund.get("payer_seats", []), -_gang_unit_score(str(refund.get("gang_type", ""))))
	for event in result.get("transfer_events", []):
		if str(event.get("transfer_type", "")) != "hu_jiao_zhuan_yi":
			continue
		_apply_gang_payment(net, int(event.get("to_seat", -1)), event.get("payer_seats", []), _gang_unit_score(str(event.get("gang_type", ""))))
	return net


func _apply_gang_payment(net: Dictionary, receiver: int, payer_seats: Array, unit_score: int) -> void:
	if not net.has(receiver):
		return
	for payer_value in payer_seats:
		var payer := int(payer_value)
		if not net.has(payer):
			continue
		net[receiver] = int(net.get(receiver, 0)) + unit_score
		net[payer] = int(net.get(payer, 0)) - unit_score


func _gang_unit_score(gang_type: String) -> int:
	return 1 if gang_type == "add_gang" else 2


func _build_cha_jiao_net(draw_assessment: Array) -> Dictionary:
	var net := {0: 0, 1: 0, 2: 0, 3: 0}
	var ting_items: Array = []
	var payer_seats: Array = []
	for item_value in draw_assessment:
		var item: Dictionary = item_value
		if bool(item.get("is_ting", false)) and not bool(item.get("hua_zhu", false)):
			ting_items.append(item)
		else:
			payer_seats.append(int(item.get("seat", -1)))
	for payer in payer_seats:
		if not net.has(payer):
			continue
		for item in ting_items:
			var receiver := int(item.get("seat", -1))
			if not net.has(receiver):
				continue
			var payment := maxi(1, int(item.get("cha_jiao_score", 1)))
			net[receiver] = int(net.get(receiver, 0)) + payment
			net[payer] = int(net.get(payer, 0)) - payment
	return net


func _create_stats() -> Dictionary:
	var seats := {}
	for seat in range(4):
		seats[seat] = {
			"wins": 0,
			"self_draw_wins": 0,
			"discard_wins": 0,
			"qiang_gang_hu_wins": 0,
			"gang_count": 0,
			"an_gang_count": 0,
			"add_gang_count": 0,
			"melded_gang_count": 0,
			"total_delta": 0,
			"positive_rounds": 0,
			"negative_rounds": 0,
			"zero_rounds": 0,
			"max_single_round_gain": 0,
			"max_single_round_loss": 0,
			"deal_in_count": 0,
			"deal_in_loss_total": 0,
			"dealt_win_count": 0,
			"self_draw_loss_rounds": 0,
			"fan_total": 0,
			"qing_yi_se_wins": 0,
			"gang_net": 0,
			"cha_jiao_net": 0,
		}
	return {
		"total_rounds": 0,
		"forced_stop_rounds": 0,
		"draw_rounds": 0,
		"battle_end_rounds": 0,
		"total_steps": 0,
		"seat_stats": seats,
		"ai_metrics_total": {},
		"round_summaries": [],
		"generated_at_unix": Time.get_unix_time_from_system(),
	}


func _accumulate_round_stats(stats: Dictionary, result: Dictionary) -> void:
	stats["total_rounds"] = int(stats.get("total_rounds", 0)) + 1
	stats["total_steps"] = int(stats.get("total_steps", 0)) + int(result.get("steps", 0))
	if bool(result.get("forced_stop", false)):
		stats["forced_stop_rounds"] = int(stats.get("forced_stop_rounds", 0)) + 1
	var end_reason := str(result.get("end_reason", ""))
	if end_reason.begins_with("draw"):
		stats["draw_rounds"] = int(stats.get("draw_rounds", 0)) + 1
	else:
		stats["battle_end_rounds"] = int(stats.get("battle_end_rounds", 0)) + 1

	var seat_stats: Dictionary = stats.get("seat_stats", {})
	var score_changes: Dictionary = result.get("score_changes", {})
	var gang_net := _build_gang_net(result)
	var cha_jiao_net := _build_cha_jiao_net(result.get("draw_assessment", []))
	for seat_key in seat_stats.keys():
		var seat := int(seat_key)
		var item: Dictionary = seat_stats[seat]
		var delta := int(score_changes.get(seat, 0))
		item["total_delta"] = int(item.get("total_delta", 0)) + delta
		item["gang_net"] = int(item.get("gang_net", 0)) + int(gang_net.get(seat, 0))
		item["cha_jiao_net"] = int(item.get("cha_jiao_net", 0)) + int(cha_jiao_net.get(seat, 0))
		if delta > 0:
			item["positive_rounds"] = int(item.get("positive_rounds", 0)) + 1
		elif delta < 0:
			item["negative_rounds"] = int(item.get("negative_rounds", 0)) + 1
		else:
			item["zero_rounds"] = int(item.get("zero_rounds", 0)) + 1
		item["max_single_round_gain"] = maxi(int(item.get("max_single_round_gain", 0)), delta)
		item["max_single_round_loss"] = mini(int(item.get("max_single_round_loss", 0)), delta)
		seat_stats[seat] = item

	for event in result.get("win_events", []):
		var winner := int(event.get("winner_seat", -1))
		if not seat_stats.has(winner):
			continue
		var item: Dictionary = seat_stats[winner]
		item["wins"] = int(item.get("wins", 0)) + 1
		var fan_detail: Dictionary = event.get("fan_detail", {})
		item["fan_total"] = int(item.get("fan_total", 0)) + int(fan_detail.get("capped_fan", 0))
		if str(fan_detail.get("hand_type", "")) == "qing_yi_se":
			item["qing_yi_se_wins"] = int(item.get("qing_yi_se_wins", 0)) + 1
		var win_type := str(event.get("win_type", ""))
		match win_type:
			"self_draw", "gang_self_draw":
				item["self_draw_wins"] = int(item.get("self_draw_wins", 0)) + 1
			"qiang_gang_hu":
				item["qiang_gang_hu_wins"] = int(item.get("qiang_gang_hu_wins", 0)) + 1
			_:
				item["discard_wins"] = int(item.get("discard_wins", 0)) + 1
				item["dealt_win_count"] = int(item.get("dealt_win_count", 0)) + 1
		seat_stats[winner] = item

		var source_seat := int(event.get("source_seat", -1))
		if source_seat >= 0 and seat_stats.has(source_seat):
			var source_item: Dictionary = seat_stats[source_seat]
			match win_type:
				"discard_win", "gang_discard_win", "qiang_gang_hu":
					source_item["deal_in_count"] = int(source_item.get("deal_in_count", 0)) + 1
					source_item["deal_in_loss_total"] = int(source_item.get("deal_in_loss_total", 0)) + int(score_changes.get(source_seat, 0))
				"self_draw", "gang_self_draw":
					source_item["self_draw_loss_rounds"] = int(source_item.get("self_draw_loss_rounds", 0)) + 1 if source_seat != winner else int(source_item.get("self_draw_loss_rounds", 0))
			seat_stats[source_seat] = source_item

	for event in result.get("gang_events", []):
		var actor := int(event.get("actor_seat", -1))
		if not seat_stats.has(actor):
			continue
		var item: Dictionary = seat_stats[actor]
		item["gang_count"] = int(item.get("gang_count", 0)) + 1
		var gang_type := str(event.get("gang_type", ""))
		match gang_type:
			"an_gang":
				item["an_gang_count"] = int(item.get("an_gang_count", 0)) + 1
			"melded_gang":
				item["melded_gang_count"] = int(item.get("melded_gang_count", 0)) + 1
			"add_gang":
				item["add_gang_count"] = int(item.get("add_gang_count", 0)) + 1
		seat_stats[actor] = item

	stats["seat_stats"] = seat_stats
	_accumulate_ai_metrics(stats, result.get("ai_decision_metrics", {}))
	stats["round_summaries"].append(
		{
			"round_no": int(result.get("round_no", 0)),
			"steps": int(result.get("steps", 0)),
			"forced_stop": bool(result.get("forced_stop", false)),
			"current_phase": int(result.get("current_phase", -1)),
			"current_turn_seat": int(result.get("current_turn_seat", -1)),
			"debug_last_message": str(result.get("debug_last_message", "")),
			"opening_roll_pending_completion": bool(result.get("opening_roll_pending_completion", false)),
			"pending_reaction_count": int(result.get("pending_reaction_count", 0)),
			"end_reason": end_reason,
			"winner_seats": result.get("winner_seats", []).duplicate(),
			"score_changes": score_changes.duplicate(true),
			"ai_decision_metrics": result.get("ai_decision_metrics", {}).duplicate(true),
		}
	)


func _finalize_stats(stats: Dictionary, game_state: Node) -> void:
	var players: Array = game_state.get("players")
	for player in players:
		var seat := int(player.get("seat", -1))
		var seat_stats: Dictionary = stats.get("seat_stats", {})
		if seat_stats.has(seat):
			var item: Dictionary = seat_stats[seat]
			item["final_score"] = int(player.get("score", 0))
			item["avg_delta_per_round"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(item.get("total_delta", 0)) / float(stats.get("total_rounds", 0))
			item["win_rate"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(item.get("wins", 0)) / float(stats.get("total_rounds", 0))
			item["deal_in_rate"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(item.get("deal_in_count", 0)) / float(stats.get("total_rounds", 0))
			item["average_fan"] = 0.0 if int(item.get("wins", 0)) <= 0 else float(item.get("fan_total", 0)) / float(item.get("wins", 0))
			item["qing_yi_se_win_rate"] = 0.0 if int(item.get("wins", 0)) <= 0 else float(item.get("qing_yi_se_wins", 0)) / float(item.get("wins", 0))
			seat_stats[seat] = item
			stats["seat_stats"] = seat_stats
	stats["avg_steps_per_round"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(stats.get("total_steps", 0)) / float(stats.get("total_rounds", 0))
	stats["report_version"] = 2


func _print_summary(stats: Dictionary) -> void:
	if str(stats.get("benchmark_mode", "")) == "paired_policy_rotation":
		print("=== AI PAIRED POLICY ROTATION ===")
		print("games=", stats.get("games", 0), " avg_delta=", stats.get("candidate_average_delta", 0.0))
		print("ci=[", stats.get("candidate_delta_ci_low", 0.0), ", ", stats.get("candidate_delta_ci_high", 0.0), "]")
		print("ledger_failures=", stats.get("ledger_failure_games", 0), " forced_stops=", stats.get("forced_stop_games", 0))
		print("promotion=", stats.get("promotion_gate_passed", false), " reasons=", stats.get("gate_reasons", []))
		return
	if str(stats.get("benchmark_mode", "")) == "ab_compare":
		print("=== AI PRESSURE BENCHMARK A/B ===")
		print("preset_a=", stats.get("preset_a", ""))
		print("preset_b=", stats.get("preset_b", ""))
		var comparison: Dictionary = stats.get("comparison", {})
		for key in comparison.keys():
			print("%s=%s" % [str(key), str(comparison.get(key))])
		return
	print("=== AI PRESSURE BENCHMARK ===")
	print("total_rounds=", stats.get("total_rounds", 0))
	print("forced_stop_rounds=", stats.get("forced_stop_rounds", 0))
	print("draw_rounds=", stats.get("draw_rounds", 0))
	print("battle_end_rounds=", stats.get("battle_end_rounds", 0))
	print("avg_steps_per_round=", "%.2f" % float(stats.get("avg_steps_per_round", 0.0)))
	var acceptance: Dictionary = stats.get("acceptance_metrics", {})
	if not acceptance.is_empty():
		print("acceptance win_rate=%.4f self_draw_share=%.4f deal_in_rate=%.4f avg_fan=%.3f regret=%.3f severe=%.5f brier=%.5f" % [
			float(acceptance.get("win_rate_per_seat_round", 0.0)),
			float(acceptance.get("self_draw_share_of_wins", 0.0)),
			float(acceptance.get("deal_in_rate_per_seat_round", 0.0)),
			float(acceptance.get("average_fan", 0.0)),
			float(acceptance.get("average_regret_score_gap", 0.0)),
			float(acceptance.get("severe_error_rate", 0.0)),
			float(acceptance.get("round_win_brier", 0.0)),
		])
	var seat_stats: Dictionary = stats.get("seat_stats", {})
	for seat_key in seat_stats.keys():
		var seat := int(seat_key)
		var item: Dictionary = seat_stats[seat]
		print("--- seat %d ---" % seat)
		print("wins=%d self_draw=%d discard=%d qiang_gang_hu=%d" % [
			int(item.get("wins", 0)),
			int(item.get("self_draw_wins", 0)),
			int(item.get("discard_wins", 0)),
			int(item.get("qiang_gang_hu_wins", 0)),
		])
		print("gang_total=%d an_gang=%d add_gang=%d melded_gang=%d" % [
			int(item.get("gang_count", 0)),
			int(item.get("an_gang_count", 0)),
			int(item.get("add_gang_count", 0)),
			int(item.get("melded_gang_count", 0)),
		])
		print("delta_total=%d positive_rounds=%d negative_rounds=%d final_score=%d" % [
			int(item.get("total_delta", 0)),
			int(item.get("positive_rounds", 0)),
			int(item.get("negative_rounds", 0)),
			int(item.get("final_score", 0)),
		])
		print("win_rate=%.3f avg_delta=%.3f max_gain=%d max_loss=%d" % [
			float(item.get("win_rate", 0.0)),
			float(item.get("avg_delta_per_round", 0.0)),
			int(item.get("max_single_round_gain", 0)),
			int(item.get("max_single_round_loss", 0)),
		])
		print("deal_in_rate=%.3f deal_in_count=%d deal_in_loss_total=%d" % [
			float(item.get("deal_in_rate", 0.0)),
			int(item.get("deal_in_count", 0)),
			int(item.get("deal_in_loss_total", 0)),
		])
	print("--- ai_metrics_total ---")
	for key in stats.get("ai_metrics_total", {}).keys():
		print("%s=%d" % [str(key), int(stats["ai_metrics_total"].get(key, 0))])


func _write_report(stats: Dictionary, output_path: String) -> void:
	var serialized := JSON.stringify(stats, "\t", false)
	var resolved_path := ProjectSettings.globalize_path(output_path)
	var dir_path := resolved_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open benchmark report path: %s" % resolved_path)
		return
	file.store_string(serialized)
	file.flush()
	file.close()
	print("benchmark_report_path=", resolved_path)


func _write_csv_report(stats: Dictionary, output_path: String) -> void:
	if str(stats.get("benchmark_mode", "")) == "ab_compare":
		_write_ab_csv_report(stats, output_path)
		return
	var resolved_path := ProjectSettings.globalize_path(output_path)
	var dir_path := resolved_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open benchmark csv path: %s" % resolved_path)
		return
	var lines: Array[String] = []
	lines.append("seat,wins,self_draw_wins,discard_wins,qiang_gang_hu_wins,gang_count,an_gang_count,add_gang_count,melded_gang_count,total_delta,avg_delta_per_round,win_rate,deal_in_count,deal_in_rate,deal_in_loss_total,positive_rounds,negative_rounds,zero_rounds,max_single_round_gain,max_single_round_loss,final_score")
	var seat_stats: Dictionary = stats.get("seat_stats", {})
	var sorted_seats := seat_stats.keys()
	sorted_seats.sort()
	for seat_key in sorted_seats:
		var seat := int(seat_key)
		var item: Dictionary = seat_stats[seat]
		lines.append(",".join([
			str(seat),
			str(int(item.get("wins", 0))),
			str(int(item.get("self_draw_wins", 0))),
			str(int(item.get("discard_wins", 0))),
			str(int(item.get("qiang_gang_hu_wins", 0))),
			str(int(item.get("gang_count", 0))),
			str(int(item.get("an_gang_count", 0))),
			str(int(item.get("add_gang_count", 0))),
			str(int(item.get("melded_gang_count", 0))),
			str(int(item.get("total_delta", 0))),
			str(float(item.get("avg_delta_per_round", 0.0))),
			str(float(item.get("win_rate", 0.0))),
			str(int(item.get("deal_in_count", 0))),
			str(float(item.get("deal_in_rate", 0.0))),
			str(int(item.get("deal_in_loss_total", 0))),
			str(int(item.get("positive_rounds", 0))),
			str(int(item.get("negative_rounds", 0))),
			str(int(item.get("zero_rounds", 0))),
			str(int(item.get("max_single_round_gain", 0))),
			str(int(item.get("max_single_round_loss", 0))),
			str(int(item.get("final_score", 0))),
		]))
	file.store_string("\n".join(lines))
	file.flush()
	file.close()
	print("benchmark_csv_report_path=", resolved_path)


func _write_discard_audit(records: Array, output_path: String) -> void:
	var resolved_path := ProjectSettings.globalize_path(output_path)
	var dir_path := resolved_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open discard audit path: %s" % resolved_path)
		return
	for record in records:
		file.store_line(JSON.stringify(record, "", false))
	file.flush()
	file.close()
	print("discard_audit_jsonl_path=", resolved_path)


func _write_discard_audit_csv(records: Array, output_path: String) -> void:
	var resolved_path := ProjectSettings.globalize_path(output_path)
	var dir_path := resolved_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open discard audit csv path: %s" % resolved_path)
		return
	var fields := [
		"round_no",
		"step",
		"preset",
		"discard_index",
		"seat",
		"seat_name",
		"tile_name",
		"suit",
		"rank",
		"ding_que",
		"wall_count_after",
		"decision_backend",
		"recommended_tile_name",
		"recommended_score",
		"decision_tile_name",
		"decision_matched_actual_discard",
		"decision_score",
		"best_candidate_score",
		"decision_score_gap_to_best",
		"old_hand_rating",
		"old_hand_rank",
		"old_hand_score_gap_to_best",
		"old_hand_actual_risk",
		"old_hand_reason",
		"decision_expected_net_score",
		"decision_deal_in_probability",
		"decision_risk_label",
		"seat_round_delta",
		"round_end_reason",
	]
	file.store_line(",".join(fields))
	for record in records:
		var row: Array[String] = []
		for field in fields:
			row.append(_csv_escape(record.get(field, "")))
		file.store_line(",".join(row))
	file.flush()
	file.close()
	print("discard_audit_csv_path=", resolved_path)


func _csv_escape(value) -> String:
	var text := str(value)
	if text.find("\"") != -1:
		text = text.replace("\"", "\"\"")
	if text.find(",") != -1 or text.find("\n") != -1 or text.find("\"") != -1:
		return "\"%s\"" % text
	return text


func _build_discard_audit_summary(records: Array, jsonl_output_path: String, csv_output_path: String, game_state: Node) -> Dictionary:
	var by_seat := {}
	var by_suit := {}
	var decision_score_sum := 0.0
	var decision_score_count := 0
	var expected_fan_sum := 0.0
	var expected_fan_count := 0
	var round_win_brier_sum := 0.0
	var round_win_brier_count := 0
	var route_transition_count := 0
	var route_switch_count := 0
	var last_route_by_round_seat := {}
	var qing_route_rounds := {}
	var qing_route_wins := {}
	var old_hand_records: Array = []
	for record in records:
		var seat_key := str(record.get("seat", -1))
		var suit_key := str(record.get("suit", ""))
		by_seat[seat_key] = int(by_seat.get(seat_key, 0)) + 1
		by_suit[suit_key] = int(by_suit.get(suit_key, 0)) + 1
		var score = record.get("decision_score", "")
		if _is_numeric(score):
			decision_score_sum += float(score)
			decision_score_count += 1
		var expected_fan = record.get("decision_expected_fan", "")
		if _is_numeric(expected_fan):
			expected_fan_sum += float(expected_fan)
			expected_fan_count += 1
		var brier = record.get("decision_round_win_brier", "")
		if _is_numeric(brier):
			round_win_brier_sum += float(brier)
			round_win_brier_count += 1
		var route := str(record.get("decision_route", ""))
		var round_seat_key := "%d:%d" % [int(record.get("round_no", 0)), int(record.get("seat", -1))]
		if route != "":
			if last_route_by_round_seat.has(round_seat_key):
				route_transition_count += 1
				if str(last_route_by_round_seat.get(round_seat_key, "")) != route:
					route_switch_count += 1
			last_route_by_round_seat[round_seat_key] = route
			if _is_qing_route(route, record.get("decision_routes_after", [])):
				qing_route_rounds[round_seat_key] = true
				if int(record.get("seat", -1)) in record.get("round_qing_winner_seats", []):
					qing_route_wins[round_seat_key] = true
		var old_hand_score: Dictionary = record.get("old_hand_score_record", {})
		if not old_hand_score.is_empty():
			old_hand_records.append(old_hand_score)
	return {
		"enabled": true,
		"record_count": records.size(),
		"by_seat": by_seat,
		"by_suit": by_suit,
		"avg_decision_score": 0.0 if decision_score_count <= 0 else decision_score_sum / float(decision_score_count),
		"avg_expected_fan": 0.0 if expected_fan_count <= 0 else expected_fan_sum / float(expected_fan_count),
		"round_win_brier": 0.0 if round_win_brier_count <= 0 else round_win_brier_sum / float(round_win_brier_count),
		"round_win_calibration_samples": round_win_brier_count,
		"route_transition_count": route_transition_count,
		"route_switch_count": route_switch_count,
		"route_switch_rate": 0.0 if route_transition_count <= 0 else float(route_switch_count) / float(route_transition_count),
		"qing_route_rounds": qing_route_rounds.size(),
		"qing_route_wins": qing_route_wins.size(),
		"qing_route_success_rate": 0.0 if qing_route_rounds.is_empty() else float(qing_route_wins.size()) / float(qing_route_rounds.size()),
		"old_hand_scorer": old_hand_scorer.summarize(old_hand_records),
		"jsonl_path": jsonl_output_path,
		"jsonl_path_absolute": ProjectSettings.globalize_path(jsonl_output_path),
		"csv_path": csv_output_path,
		"csv_path_absolute": ProjectSettings.globalize_path(csv_output_path),
		"debug_decision_trace": game_state.call("_build_debug_decision_trace_snapshot"),
	}


func _is_qing_route(primary_route: String, routes_after: Array) -> bool:
	if primary_route.findn("qing") >= 0 or primary_route.find("清一色") >= 0:
		return true
	for route in routes_after:
		var text := str(route)
		if text.findn("qing") >= 0 or text.find("清一色") >= 0:
			return true
	return false


func _build_acceptance_metrics(stats: Dictionary) -> Dictionary:
	if str(stats.get("benchmark_mode", "")) == "ab_compare":
		return {}
	var seat_stats: Dictionary = stats.get("seat_stats", {})
	var rounds := int(stats.get("total_rounds", 0))
	var wins := 0
	var self_draw_wins := 0
	var deal_in_count := 0
	var total_delta := 0
	var absolute_delta := 0
	var fan_total := 0
	var qing_wins := 0
	var gang_net_by_seat := {}
	var cha_jiao_net_by_seat := {}
	var average_net_by_seat := {}
	for seat_key in seat_stats.keys():
		var item: Dictionary = seat_stats[seat_key]
		wins += int(item.get("wins", 0))
		self_draw_wins += int(item.get("self_draw_wins", 0))
		deal_in_count += int(item.get("deal_in_count", 0))
		total_delta += int(item.get("total_delta", 0))
		absolute_delta += absi(int(item.get("total_delta", 0)))
		fan_total += int(item.get("fan_total", 0))
		qing_wins += int(item.get("qing_yi_se_wins", 0))
		gang_net_by_seat[str(seat_key)] = int(item.get("gang_net", 0))
		cha_jiao_net_by_seat[str(seat_key)] = int(item.get("cha_jiao_net", 0))
		average_net_by_seat[str(seat_key)] = float(item.get("avg_delta_per_round", 0.0))
	var seat_rounds := rounds * 4
	var audit: Dictionary = stats.get("discard_audit", {})
	var judge: Dictionary = audit.get("old_hand_scorer", {})
	return {
		"average_net_by_seat": average_net_by_seat,
		"zero_sum_average_net_per_seat_round": 0.0 if seat_rounds <= 0 else float(total_delta) / float(seat_rounds),
		"average_absolute_final_net_per_seat": 0.0 if seat_stats.is_empty() else float(absolute_delta) / float(seat_stats.size()),
		"win_rate_per_seat_round": 0.0 if seat_rounds <= 0 else float(wins) / float(seat_rounds),
		"self_draw_share_of_wins": 0.0 if wins <= 0 else float(self_draw_wins) / float(wins),
		"deal_in_rate_per_seat_round": 0.0 if seat_rounds <= 0 else float(deal_in_count) / float(seat_rounds),
		"cha_jiao_net_by_seat": cha_jiao_net_by_seat,
		"gang_net_by_seat": gang_net_by_seat,
		"average_fan": 0.0 if wins <= 0 else float(fan_total) / float(wins),
		"qing_yi_se_win_share": 0.0 if wins <= 0 else float(qing_wins) / float(wins),
		"qing_route_success_rate": float(audit.get("qing_route_success_rate", 0.0)),
		"route_switch_rate": float(audit.get("route_switch_rate", 0.0)),
		"average_regret_score_gap": float(judge.get("average_score_gap", 0.0)),
		"severe_error_rate": float(judge.get("severe_miss_rate", 0.0)),
		"round_win_brier": float(audit.get("round_win_brier", 0.0)),
		"calibration_sample_count": int(audit.get("round_win_calibration_samples", 0)),
	}


func _write_ab_csv_report(stats: Dictionary, output_path: String) -> void:
	var resolved_path := ProjectSettings.globalize_path(output_path)
	var dir_path := resolved_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open benchmark csv path: %s" % resolved_path)
		return
	var comparison: Dictionary = stats.get("comparison", {})
	var lines: Array[String] = []
	lines.append("metric,preset_a,preset_b")
	for key in comparison.keys():
		var value: Dictionary = comparison.get(key, {})
		lines.append("%s,%s,%s" % [str(key), str(value.get("a", "")), str(value.get("b", ""))])
	file.store_string("\n".join(lines))
	file.flush()
	file.close()
	print("benchmark_csv_report_path=", resolved_path)


func _accumulate_ai_metrics(stats: Dictionary, metrics: Dictionary) -> void:
	var totals: Dictionary = stats.get("ai_metrics_total", {})
	for key in metrics.keys():
		totals[key] = int(totals.get(key, 0)) + int(metrics.get(key, 0))
	stats["ai_metrics_total"] = totals


func _build_comparison(stats_a: Dictionary, stats_b: Dictionary) -> Dictionary:
	return {
		"avg_steps_per_round": {
			"a": stats_a.get("avg_steps_per_round", 0.0),
			"b": stats_b.get("avg_steps_per_round", 0.0),
		},
		"draw_rounds": {
			"a": stats_a.get("draw_rounds", 0),
			"b": stats_b.get("draw_rounds", 0),
		},
		"battle_end_rounds": {
			"a": stats_a.get("battle_end_rounds", 0),
			"b": stats_b.get("battle_end_rounds", 0),
		},
		"reaction_hu": {
			"a": int(stats_a.get("ai_metrics_total", {}).get("reaction_hu", 0)),
			"b": int(stats_b.get("ai_metrics_total", {}).get("reaction_hu", 0)),
		},
		"reaction_peng": {
			"a": int(stats_a.get("ai_metrics_total", {}).get("reaction_peng", 0)),
			"b": int(stats_b.get("ai_metrics_total", {}).get("reaction_peng", 0)),
		},
		"reaction_gang": {
			"a": int(stats_a.get("ai_metrics_total", {}).get("reaction_gang", 0)),
			"b": int(stats_b.get("ai_metrics_total", {}).get("reaction_gang", 0)),
		},
		"strategy_full_attack": {
			"a": int(stats_a.get("ai_metrics_total", {}).get("discard_strategy_全攻", 0)),
			"b": int(stats_b.get("ai_metrics_total", {}).get("discard_strategy_全攻", 0)),
		},
		"strategy_full_defense": {
			"a": int(stats_a.get("ai_metrics_total", {}).get("discard_strategy_全守", 0)),
			"b": int(stats_b.get("ai_metrics_total", {}).get("discard_strategy_全守", 0)),
		},
	}


func _read_int_arg(prefix: String, fallback: int) -> int:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with(prefix):
			return maxi(1, int(String(arg).trim_prefix(prefix)))
	return fallback


func _read_string_arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var arg_text := String(arg)
		if arg_text.begins_with(prefix):
			return arg_text.trim_prefix(prefix)
	return fallback


func _read_bool_arg(prefix: String, fallback: bool) -> bool:
	var bare_arg := prefix.substr(0, prefix.length() - 1) if prefix.ends_with("=") else prefix
	for arg in OS.get_cmdline_user_args():
		var arg_text := String(arg)
		if arg_text == bare_arg:
			return true
		if arg_text.begins_with(prefix):
			var value := arg_text.trim_prefix(prefix).strip_edges().to_lower()
			return value in ["1", "true", "yes", "y", "on", "开启"]
	return fallback


func _build_default_report_path(total_rounds: int, preset_name: String, compare_preset_name: String, extension: String) -> String:
	var timestamp := _build_timestamp_slug()
	var mode_slug := "single_%s" % preset_name if compare_preset_name == "" else "ab_%s_vs_%s" % [preset_name, compare_preset_name]
	var file_name := "ai压测_%s_%d局_%s.%s" % [timestamp, total_rounds, mode_slug, extension]
	return "res://测试数据统计/%s" % file_name


func _build_default_audit_path(total_rounds: int, preset_name: String, compare_preset_name: String, extension: String) -> String:
	var timestamp := _build_timestamp_slug()
	var mode_slug := "single_%s" % preset_name if compare_preset_name == "" else "ab_%s_vs_%s" % [preset_name, compare_preset_name]
	var file_name := "ai逐张出牌_%s_%d局_%s.%s" % [timestamp, total_rounds, mode_slug, extension]
	return "res://测试数据统计/ai_discard_audit/%s" % file_name


func _build_timestamp_slug() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0)),
	]
