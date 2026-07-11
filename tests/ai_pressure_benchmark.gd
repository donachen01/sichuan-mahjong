extends SceneTree

const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const OLD_HAND_SCORER_SCRIPT := preload("res://scripts/ai/sichuan_old_hand_discard_scorer.gd")

const DEFAULT_TOTAL_ROUNDS := 40
const DEFAULT_MAX_STEPS_PER_ROUND := 5000
const SHORT_ROUND_STEP_THRESHOLD := 80

var old_hand_scorer = OLD_HAND_SCORER_SCRIPT.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var total_rounds := _read_int_arg("--rounds=", DEFAULT_TOTAL_ROUNDS)
	var max_steps_per_round := _read_int_arg("--max-steps=", DEFAULT_MAX_STEPS_PER_ROUND)
	var seed_value := _read_int_arg("--seed=", 20260514)
	var preset_name := _read_string_arg("--preset=", "bone_ash")
	var compare_preset_name := _read_string_arg("--compare-preset=", "")
	var output_path := _read_string_arg("--output=", _build_default_report_path(total_rounds, preset_name, compare_preset_name, "json"))
	var csv_output_path := _read_string_arg("--csv-output=", _build_default_report_path(total_rounds, preset_name, compare_preset_name, "csv"))
	var game_state: Node = GAME_STATE_SCRIPT.new()
	get_root().add_child(game_state)
	await process_frame
	if game_state.has_method("set_test_seed"):
		game_state.call("set_test_seed", seed_value)
		game_state.call("start_new_round", true)
		await process_frame

	var report: Dictionary
	if compare_preset_name != "":
		report = await _run_ab_benchmark(game_state, preset_name, compare_preset_name, total_rounds, max_steps_per_round, seed_value)
	else:
		report = await _run_single_preset_benchmark(game_state, preset_name, total_rounds, max_steps_per_round, seed_value)
	_print_summary(report)
	_write_report(report, output_path)
	_write_csv_report(report, csv_output_path)
	quit()


func _run_single_preset_benchmark(game_state: Node, preset_name: String, total_rounds: int, max_steps_per_round: int, seed_value: int) -> Dictionary:
	if game_state.has_method("set_test_seed"):
		game_state.call("set_test_seed", seed_value)
		game_state.call("start_new_round", true)
		await process_frame
	game_state.call("set_ai_preset", preset_name)
	var stats := _create_stats()
	stats["benchmark_mode"] = "single"
	stats["preset_name"] = preset_name
	stats["seed"] = seed_value
	var round_counter := 0
	while round_counter < total_rounds:
		print("benchmark_round_start=", round_counter + 1, " preset=", preset_name)
		_prepare_all_ai_table(game_state)
		var result := await _play_single_round(game_state, round_counter + 1, max_steps_per_round)
		_accumulate_round_stats(stats, result)
		print("benchmark_round_end=", round_counter + 1, " steps=", int(result.get("steps", 0)), " end_reason=", str(result.get("end_reason", "")), " forced=", bool(result.get("forced_stop", false)))
		round_counter += 1
		if not game_state.call("advance_to_next_round"):
			push_error("Failed to advance after round %d" % round_counter)
			break
		await process_frame
	_finalize_stats(stats, game_state)
	return stats


func _run_ab_benchmark(game_state: Node, preset_a: String, preset_b: String, total_rounds: int, max_steps_per_round: int, seed_value: int) -> Dictionary:
	var combined := {
		"benchmark_mode": "ab_compare",
		"preset_a": preset_a,
		"preset_b": preset_b,
		"seed": seed_value,
	}
	var stats_a := await _run_single_preset_benchmark(game_state, preset_a, total_rounds, max_steps_per_round, seed_value)
	game_state.call("start_new_round")
	await process_frame
	var stats_b := await _run_single_preset_benchmark(game_state, preset_b, total_rounds, max_steps_per_round, seed_value)
	combined["report_a"] = stats_a
	combined["report_b"] = stats_b
	combined["comparison"] = _build_comparison(stats_a, stats_b)
	return combined


func _play_single_round(game_state: Node, round_no: int, max_steps_per_round: int) -> Dictionary:
	var step := 0
	var phase_counts := {}
	var old_hand_records: Array = []
	while step < max_steps_per_round:
		_prepare_all_ai_table(game_state)
		if game_state.has_method("pump_ai_background_requests"):
			game_state.call("pump_ai_background_requests")
		var phase := int(game_state.get("current_phase"))
		phase_counts[phase] = int(phase_counts.get(phase, 0)) + 1
		if phase == int(GAME_STATE_SCRIPT.RoundPhase.TABLE_SETUP):
			if bool(game_state.get("opening_roll_pending_completion")):
				game_state.call("complete_opening_roll")
		elif phase == int(GAME_STATE_SCRIPT.RoundPhase.DING_QUE):
			game_state.call("_auto_select_ai_ding_que")
			game_state.call("_complete_ding_que_if_ready")
		elif phase == int(GAME_STATE_SCRIPT.RoundPhase.DRAW):
			game_state.call("_begin_turn")
		elif phase == int(GAME_STATE_SCRIPT.RoundPhase.DISCARD):
			if bool(game_state.call("is_ai_turn_ready")):
				var seat_before := int(game_state.get("current_turn_seat"))
				var discard_count_before := int(game_state.get("discard_pile").size())
				var executed := bool(game_state.call("run_ai_turn"))
				if executed:
					var score_record := _capture_old_hand_discard_record(game_state, seat_before, discard_count_before, round_no, step)
					if not score_record.is_empty():
						old_hand_records.append(score_record)
		elif phase == int(GAME_STATE_SCRIPT.RoundPhase.REACTION):
			if bool(game_state.call("is_ai_reaction_pending")):
				game_state.call("run_ai_reaction")
			else:
				game_state.call("_finalize_reaction_without_claim")
		elif phase == int(GAME_STATE_SCRIPT.RoundPhase.SETTLEMENT):
			var result := _extract_round_result(game_state, round_no, step)
			result["phase_counts"] = phase_counts.duplicate(true)
			result["final_debug_snapshot"] = _extract_benchmark_debug_snapshot(game_state)
			result["old_hand_discard_records"] = old_hand_records.duplicate(true)
			return result
		step += 1
		await process_frame

	push_error("Round %d exceeded max steps %d" % [round_no, max_steps_per_round])
	var forced_result := _extract_round_result(game_state, round_no, step, true)
	forced_result["phase_counts"] = phase_counts.duplicate(true)
	forced_result["final_debug_snapshot"] = _extract_benchmark_debug_snapshot(game_state)
	forced_result["old_hand_discard_records"] = old_hand_records.duplicate(true)
	return forced_result


func _capture_old_hand_discard_record(game_state: Node, seat: int, discard_count_before: int, round_no: int, step: int) -> Dictionary:
	var discard_pile: Array = game_state.get("discard_pile")
	if discard_pile.size() <= discard_count_before:
		return {}
	var latest: Dictionary = discard_pile[discard_pile.size() - 1]
	if int(latest.get("seat", -1)) != seat:
		return {}
	var tile: Dictionary = latest.get("tile", {})
	var tile_type := _tile_type_from_tile(tile)
	if tile_type < 0:
		return {}
	var core_debug: Dictionary = game_state.call("_build_ai_core_debug_snapshot")
	var latest_turn: Dictionary = core_debug.get("latest_turn_snapshot", {})
	var analysis: Dictionary = latest_turn.get("analysis", {})
	var record: Dictionary = old_hand_scorer.score_analysis(analysis, tile_type, seat, round_no, step)
	if not record.is_empty():
		record["tile_id"] = int(tile.get("id", -1))
		record["tile_display_name"] = str(tile.get("display_name", record.get("actual_tile_name", "")))
	return record


func _tile_type_from_tile(tile: Dictionary) -> int:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	if rank < 1 or rank > 9:
		return -1
	match suit:
		"tiao":
			return rank - 1
		"tong":
			return 9 + rank - 1
		"wan":
			return 18 + rank - 1
		_:
			return -1


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
		"end_reason": str(settlement_data.get("end_reason", "")),
		"winner_seats": round_winners.duplicate(),
		"score_changes": score_changes.duplicate(true),
		"win_events": win_events.duplicate(true),
		"gang_events": gang_events.duplicate(true),
		"players": players,
		"ai_decision_metrics": game_state.get("ai_decision_metrics").duplicate(true),
	}


func _extract_benchmark_debug_snapshot(game_state: Node) -> Dictionary:
	return {
		"current_phase": int(game_state.get("current_phase")),
		"current_turn_seat": int(game_state.get("current_turn_seat")),
		"current_dealer_seat": int(game_state.get("current_dealer_seat")),
		"wall_count": int(game_state.get("wall_count")),
		"discard_count": game_state.get("discard_pile").size(),
		"opening_roll_pending_completion": bool(game_state.get("opening_roll_pending_completion")),
		"opening_bao_jiao_pending": bool(game_state.get("opening_bao_jiao_pending")),
		"opening_bao_jiao_current_seat": int(game_state.get("opening_bao_jiao_current_seat")),
		"is_ai_turn_ready": bool(game_state.call("is_ai_turn_ready")),
		"is_ai_reaction_pending": bool(game_state.call("is_ai_reaction_pending")),
		"debug_last_message": str(game_state.get("debug_last_message")),
	}


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
		}
	return {
		"total_rounds": 0,
		"forced_stop_rounds": 0,
		"draw_rounds": 0,
		"draw_wall_empty_rounds": 0,
		"battle_end_rounds": 0,
		"short_rounds": 0,
		"short_draw_rounds": 0,
		"short_battle_end_rounds": 0,
		"draw_nonzero_score_rounds": 0,
		"draw_zero_score_rounds": 0,
		"terminal_type_counts": {},
		"terminal_metrics_raw": {},
		"terminal_metrics": {},
		"total_steps": 0,
		"seat_stats": seats,
		"ai_metrics_total": {},
		"old_hand_discard_records": [],
		"old_hand_scorer": old_hand_scorer.summarize([]),
		"round_summaries": [],
		"generated_at_unix": Time.get_unix_time_from_system(),
	}


func _accumulate_round_stats(stats: Dictionary, result: Dictionary) -> void:
	stats["total_rounds"] = int(stats.get("total_rounds", 0)) + 1
	stats["total_steps"] = int(stats.get("total_steps", 0)) + int(result.get("steps", 0))
	if bool(result.get("forced_stop", false)):
		stats["forced_stop_rounds"] = int(stats.get("forced_stop_rounds", 0)) + 1
	var end_reason := str(result.get("end_reason", ""))
	var steps := int(result.get("steps", 0))
	var is_short_round := steps <= SHORT_ROUND_STEP_THRESHOLD
	var score_changes: Dictionary = result.get("score_changes", {})
	var has_nonzero_score_change := _has_nonzero_score_change(score_changes)
	var terminal_type_counts: Dictionary = stats.get("terminal_type_counts", {})
	terminal_type_counts[end_reason] = int(terminal_type_counts.get(end_reason, 0)) + 1
	stats["terminal_type_counts"] = terminal_type_counts
	if is_short_round:
		stats["short_rounds"] = int(stats.get("short_rounds", 0)) + 1
	if end_reason.begins_with("draw"):
		stats["draw_rounds"] = int(stats.get("draw_rounds", 0)) + 1
		if end_reason == "draw_wall_empty":
			stats["draw_wall_empty_rounds"] = int(stats.get("draw_wall_empty_rounds", 0)) + 1
		if is_short_round:
			stats["short_draw_rounds"] = int(stats.get("short_draw_rounds", 0)) + 1
		if has_nonzero_score_change:
			stats["draw_nonzero_score_rounds"] = int(stats.get("draw_nonzero_score_rounds", 0)) + 1
		else:
			stats["draw_zero_score_rounds"] = int(stats.get("draw_zero_score_rounds", 0)) + 1
	elif end_reason == "battle_end":
		stats["battle_end_rounds"] = int(stats.get("battle_end_rounds", 0)) + 1
		if is_short_round:
			stats["short_battle_end_rounds"] = int(stats.get("short_battle_end_rounds", 0)) + 1
	_accumulate_terminal_bucket(stats, "combined", result)
	_accumulate_terminal_bucket(stats, end_reason, result)

	var seat_stats: Dictionary = stats.get("seat_stats", {})
	for seat_key in seat_stats.keys():
		var seat := int(seat_key)
		var item: Dictionary = seat_stats[seat]
		var delta := _score_delta_for_seat(score_changes, seat)
		item["total_delta"] = int(item.get("total_delta", 0)) + delta
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
					source_item["deal_in_loss_total"] = int(source_item.get("deal_in_loss_total", 0)) + _score_delta_for_seat(score_changes, source_seat)
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
	_accumulate_old_hand_scores(stats, result.get("old_hand_discard_records", []))
	stats["round_summaries"].append(
		{
			"round_no": int(result.get("round_no", 0)),
			"steps": steps,
			"end_reason": end_reason,
			"is_short_round": is_short_round,
			"score_change_nonzero": has_nonzero_score_change,
			"winner_seats": result.get("winner_seats", []).duplicate(),
			"score_changes": score_changes.duplicate(true),
			"ai_decision_metrics": result.get("ai_decision_metrics", {}).duplicate(true),
			"old_hand_discard_count": int(Array(result.get("old_hand_discard_records", [])).size()),
			"old_hand_discard_records": Array(result.get("old_hand_discard_records", [])).duplicate(true),
			"phase_counts": result.get("phase_counts", {}).duplicate(true),
			"final_debug_snapshot": result.get("final_debug_snapshot", {}).duplicate(true),
		}
	)


func _accumulate_old_hand_scores(stats: Dictionary, records: Array) -> void:
	if records.is_empty():
		stats["old_hand_scorer"] = old_hand_scorer.summarize(stats.get("old_hand_discard_records", []))
		return
	var all_records: Array = stats.get("old_hand_discard_records", [])
	for item in records:
		all_records.append(item)
	stats["old_hand_discard_records"] = all_records
	stats["old_hand_scorer"] = old_hand_scorer.summarize(all_records)


func _create_terminal_bucket() -> Dictionary:
	var seat_deltas := {}
	for seat in range(4):
		seat_deltas[seat] = 0
	return {
		"rounds": 0,
		"forced_stop_rounds": 0,
		"short_rounds": 0,
		"total_steps": 0,
		"score_nonzero_rounds": 0,
		"score_zero_rounds": 0,
		"win_events": 0,
		"self_draw_wins": 0,
		"discard_wins": 0,
		"qiang_gang_hu_wins": 0,
		"deal_in_count": 0,
		"deal_in_loss_abs_total": 0,
		"seat_deltas": seat_deltas,
	}


func _has_nonzero_score_change(score_changes: Dictionary) -> bool:
	for value in score_changes.values():
		if int(value) != 0:
			return true
	return false


func _score_delta_for_seat(score_changes: Dictionary, seat: int) -> int:
	if score_changes.has(seat):
		return int(score_changes.get(seat, 0))
	return int(score_changes.get(str(seat), 0))


func _accumulate_terminal_bucket(stats: Dictionary, bucket_key: String, result: Dictionary) -> void:
	var key := bucket_key if bucket_key != "" else "unknown"
	var buckets: Dictionary = stats.get("terminal_metrics_raw", {})
	if not buckets.has(key):
		buckets[key] = _create_terminal_bucket()
	var bucket: Dictionary = buckets[key]
	var steps := int(result.get("steps", 0))
	var score_changes: Dictionary = result.get("score_changes", {})
	bucket["rounds"] = int(bucket.get("rounds", 0)) + 1
	bucket["total_steps"] = int(bucket.get("total_steps", 0)) + steps
	if bool(result.get("forced_stop", false)):
		bucket["forced_stop_rounds"] = int(bucket.get("forced_stop_rounds", 0)) + 1
	if steps <= SHORT_ROUND_STEP_THRESHOLD:
		bucket["short_rounds"] = int(bucket.get("short_rounds", 0)) + 1
	if _has_nonzero_score_change(score_changes):
		bucket["score_nonzero_rounds"] = int(bucket.get("score_nonzero_rounds", 0)) + 1
	else:
		bucket["score_zero_rounds"] = int(bucket.get("score_zero_rounds", 0)) + 1

	var seat_deltas: Dictionary = bucket.get("seat_deltas", {})
	for seat in range(4):
		seat_deltas[seat] = int(seat_deltas.get(seat, 0)) + _score_delta_for_seat(score_changes, seat)
	bucket["seat_deltas"] = seat_deltas

	for event in result.get("win_events", []):
		bucket["win_events"] = int(bucket.get("win_events", 0)) + 1
		var win_type := str(event.get("win_type", ""))
		match win_type:
			"self_draw", "gang_self_draw":
				bucket["self_draw_wins"] = int(bucket.get("self_draw_wins", 0)) + 1
			"qiang_gang_hu":
				bucket["qiang_gang_hu_wins"] = int(bucket.get("qiang_gang_hu_wins", 0)) + 1
			_:
				bucket["discard_wins"] = int(bucket.get("discard_wins", 0)) + 1
		var source_seat := int(event.get("source_seat", -1))
		if source_seat >= 0:
			match win_type:
				"discard_win", "gang_discard_win", "qiang_gang_hu":
					bucket["deal_in_count"] = int(bucket.get("deal_in_count", 0)) + 1
					bucket["deal_in_loss_abs_total"] = int(bucket.get("deal_in_loss_abs_total", 0)) + absi(_score_delta_for_seat(score_changes, source_seat))

	buckets[key] = bucket
	stats["terminal_metrics_raw"] = buckets


func _finalize_terminal_metrics(stats: Dictionary) -> void:
	var raw_buckets: Dictionary = stats.get("terminal_metrics_raw", {})
	var terminal_metrics := {}
	for key in raw_buckets.keys():
		terminal_metrics[key] = _finalize_single_terminal_metric(raw_buckets[key])
	stats["terminal_metrics"] = terminal_metrics

	var battle_metric: Dictionary = terminal_metrics.get("battle_end", {})
	var draw_metric: Dictionary = terminal_metrics.get("draw_wall_empty", {})
	var effective_battle_metric := battle_metric.duplicate(true)
	effective_battle_metric["definition"] = "Only battle_end rounds are treated as the primary old-hand discard-strength sample; draw_wall_empty is reported separately as draw/cha-jiao pressure."
	effective_battle_metric["target_avg_delta_per_battle_round"] = float(effective_battle_metric.get("target_avg_delta_per_round", 0.0))
	stats["effective_battle_metrics"] = effective_battle_metric

	var draw_settlement_metric := draw_metric.duplicate(true)
	draw_settlement_metric["definition"] = "draw_wall_empty rounds are normal wall-empty draw settlements; score_nonzero_rounds tracks whether cha-jiao/tui-gang settlement changed scores."
	draw_settlement_metric["target_avg_delta_per_draw_round"] = float(draw_settlement_metric.get("target_avg_delta_per_round", 0.0))
	stats["draw_settlement_metrics"] = draw_settlement_metric
	stats["evaluation_policy"] = {
		"primary_discard_strength_metric": "effective_battle_metrics.target_avg_delta_per_battle_round",
		"draw_pressure_metric": "draw_settlement_metrics.target_avg_delta_per_draw_round",
		"combined_metric": "long_term_score_metrics.target_avg_delta_per_round",
		"short_round_step_threshold": SHORT_ROUND_STEP_THRESHOLD,
		"note": "combined_metric is retained for continuity; split terminal metrics should be used before judging long-term AI discard strength.",
	}


func _finalize_single_terminal_metric(bucket: Dictionary) -> Dictionary:
	var rounds := int(bucket.get("rounds", 0))
	var seat_deltas: Dictionary = bucket.get("seat_deltas", {})
	return {
		"rounds": rounds,
		"forced_stop_rounds": int(bucket.get("forced_stop_rounds", 0)),
		"short_rounds": int(bucket.get("short_rounds", 0)),
		"short_round_rate": _safe_ratio(int(bucket.get("short_rounds", 0)), rounds),
		"avg_steps_per_round": _safe_ratio(float(bucket.get("total_steps", 0)), rounds),
		"score_nonzero_rounds": int(bucket.get("score_nonzero_rounds", 0)),
		"score_zero_rounds": int(bucket.get("score_zero_rounds", 0)),
		"score_nonzero_rate": _safe_ratio(int(bucket.get("score_nonzero_rounds", 0)), rounds),
		"win_events": int(bucket.get("win_events", 0)),
		"self_draw_wins": int(bucket.get("self_draw_wins", 0)),
		"discard_wins": int(bucket.get("discard_wins", 0)),
		"qiang_gang_hu_wins": int(bucket.get("qiang_gang_hu_wins", 0)),
		"deal_in_count": int(bucket.get("deal_in_count", 0)),
		"deal_in_rate": _safe_ratio(int(bucket.get("deal_in_count", 0)), rounds),
		"deal_in_loss_abs_per_round": _safe_ratio(int(bucket.get("deal_in_loss_abs_total", 0)), rounds),
		"target_seat": 0,
		"target_total_delta": int(seat_deltas.get(0, 0)),
		"target_avg_delta_per_round": _safe_ratio(int(seat_deltas.get(0, 0)), rounds),
		"seat_deltas": seat_deltas.duplicate(true),
	}


func _finalize_stats(stats: Dictionary, game_state: Node) -> void:
	var players: Array = game_state.get("players")
	var win_rates: Array[float] = []
	var deal_in_rates: Array[float] = []
	var final_scores: Array[int] = []
	var total_deal_in_loss_abs := 0
	for player in players:
		var seat := int(player.get("seat", -1))
		var seat_stats: Dictionary = stats.get("seat_stats", {})
		if seat_stats.has(seat):
			var item: Dictionary = seat_stats[seat]
			item["final_score"] = int(player.get("score", 0))
			item["avg_delta_per_round"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(item.get("total_delta", 0)) / float(stats.get("total_rounds", 0))
			item["win_rate"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(item.get("wins", 0)) / float(stats.get("total_rounds", 0))
			item["deal_in_rate"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(item.get("deal_in_count", 0)) / float(stats.get("total_rounds", 0))
			win_rates.append(float(item.get("win_rate", 0.0)))
			deal_in_rates.append(float(item.get("deal_in_rate", 0.0)))
			final_scores.append(int(item.get("final_score", 0)))
			total_deal_in_loss_abs += absi(int(item.get("deal_in_loss_total", 0)))
			seat_stats[seat] = item
			stats["seat_stats"] = seat_stats
	stats["avg_steps_per_round"] = 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(stats.get("total_steps", 0)) / float(stats.get("total_rounds", 0))
	var score_spread := 0
	if not final_scores.is_empty():
		var min_score := final_scores[0]
		var max_score := final_scores[0]
		for score in final_scores:
			min_score = mini(min_score, score)
			max_score = maxi(max_score, score)
		score_spread = max_score - min_score
	var seat_stats: Dictionary = stats.get("seat_stats", {})
	var target_seat: Dictionary = seat_stats.get(0, {})
	stats["long_term_score_metrics"] = {
		"target_seat": 0,
		"target_avg_delta_per_round": float(target_seat.get("avg_delta_per_round", 0.0)),
		"target_win_rate": float(target_seat.get("win_rate", 0.0)),
		"target_deal_in_rate": float(target_seat.get("deal_in_rate", 0.0)),
		"target_final_score": int(target_seat.get("final_score", 0)),
		"avg_win_rate_across_seats": _average_float(win_rates),
		"avg_deal_in_rate_across_seats": _average_float(deal_in_rates),
		"deal_in_loss_abs_per_round": 0.0 if int(stats.get("total_rounds", 0)) <= 0 else float(total_deal_in_loss_abs) / float(stats.get("total_rounds", 0)),
		"final_score_spread": score_spread,
	}
	stats["report_version"] = 3
	_finalize_terminal_metrics(stats)


func _print_summary(stats: Dictionary) -> void:
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
	print("draw_wall_empty_rounds=", stats.get("draw_wall_empty_rounds", 0))
	print("battle_end_rounds=", stats.get("battle_end_rounds", 0))
	print("short_rounds=", stats.get("short_rounds", 0))
	print("short_draw_rounds=", stats.get("short_draw_rounds", 0))
	print("short_battle_end_rounds=", stats.get("short_battle_end_rounds", 0))
	print("draw_nonzero_score_rounds=", stats.get("draw_nonzero_score_rounds", 0))
	print("draw_zero_score_rounds=", stats.get("draw_zero_score_rounds", 0))
	print("avg_steps_per_round=", "%.2f" % float(stats.get("avg_steps_per_round", 0.0)))
	var long_term: Dictionary = stats.get("long_term_score_metrics", {})
	print("target_avg_delta_per_round=", "%.3f" % float(long_term.get("target_avg_delta_per_round", 0.0)))
	print("avg_deal_in_rate_across_seats=", "%.3f" % float(long_term.get("avg_deal_in_rate_across_seats", 0.0)))
	print("deal_in_loss_abs_per_round=", "%.3f" % float(long_term.get("deal_in_loss_abs_per_round", 0.0)))
	var effective_battle: Dictionary = stats.get("effective_battle_metrics", {})
	print("effective_battle_rounds=", int(effective_battle.get("rounds", 0)))
	print("effective_battle_target_avg_delta=", "%.3f" % float(effective_battle.get("target_avg_delta_per_battle_round", 0.0)))
	print("effective_battle_deal_in_rate=", "%.3f" % float(effective_battle.get("deal_in_rate", 0.0)))
	var draw_settlement: Dictionary = stats.get("draw_settlement_metrics", {})
	print("draw_settlement_target_avg_delta=", "%.3f" % float(draw_settlement.get("target_avg_delta_per_draw_round", 0.0)))
	print("draw_settlement_score_nonzero_rate=", "%.3f" % float(draw_settlement.get("score_nonzero_rate", 0.0)))
	var old_hand: Dictionary = stats.get("old_hand_scorer", {})
	print("old_hand_discard_count=", int(old_hand.get("discard_count", 0)))
	print("old_hand_average_rating=", "%.3f" % float(old_hand.get("average_rating", 0.0)))
	print("old_hand_top1_rate=", "%.3f" % float(old_hand.get("top1_rate", 0.0)))
	print("old_hand_average_score_gap=", "%.3f" % float(old_hand.get("average_score_gap", 0.0)))
	print("old_hand_dangerous_discard_rate=", "%.3f" % float(old_hand.get("dangerous_discard_rate", 0.0)))
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
	lines.append("metric,preset_a,preset_b,delta_b_minus_a")
	for key in comparison.keys():
		var value: Dictionary = comparison.get(key, {})
		lines.append("%s,%s,%s,%s" % [str(key), str(value.get("a", "")), str(value.get("b", "")), str(value.get("delta_b_minus_a", ""))])
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
	var comparison := {
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
		"short_rounds": {
			"a": stats_a.get("short_rounds", 0),
			"b": stats_b.get("short_rounds", 0),
		},
		"draw_nonzero_score_rounds": {
			"a": stats_a.get("draw_nonzero_score_rounds", 0),
			"b": stats_b.get("draw_nonzero_score_rounds", 0),
		},
		"draw_zero_score_rounds": {
			"a": stats_a.get("draw_zero_score_rounds", 0),
			"b": stats_b.get("draw_zero_score_rounds", 0),
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
	var score_a: Dictionary = stats_a.get("long_term_score_metrics", {})
	var score_b: Dictionary = stats_b.get("long_term_score_metrics", {})
	for key in [
		"target_avg_delta_per_round",
		"target_win_rate",
		"target_deal_in_rate",
		"target_final_score",
		"avg_deal_in_rate_across_seats",
		"deal_in_loss_abs_per_round",
		"final_score_spread",
	]:
		comparison[key] = {
			"a": score_a.get(key, 0.0),
			"b": score_b.get(key, 0.0),
			"delta_b_minus_a": float(score_b.get(key, 0.0)) - float(score_a.get(key, 0.0)),
		}
	for metric in [
		"target_avg_delta_per_battle_round",
		"deal_in_rate",
		"deal_in_loss_abs_per_round",
		"short_round_rate",
	]:
		var battle_a_value: float = float(_nested_metric(stats_a, ["effective_battle_metrics", metric], 0.0))
		var battle_b_value: float = float(_nested_metric(stats_b, ["effective_battle_metrics", metric], 0.0))
		comparison["battle_%s" % metric] = {
			"a": battle_a_value,
			"b": battle_b_value,
			"delta_b_minus_a": battle_b_value - battle_a_value,
		}
	for metric in [
		"target_avg_delta_per_draw_round",
		"score_nonzero_rate",
		"short_round_rate",
	]:
		var draw_a_value: float = float(_nested_metric(stats_a, ["draw_settlement_metrics", metric], 0.0))
		var draw_b_value: float = float(_nested_metric(stats_b, ["draw_settlement_metrics", metric], 0.0))
		comparison["draw_%s" % metric] = {
			"a": draw_a_value,
			"b": draw_b_value,
			"delta_b_minus_a": draw_b_value - draw_a_value,
		}
	return comparison


func _nested_metric(source: Dictionary, keys: Array, fallback) -> Variant:
	var cursor: Variant = source
	for key in keys:
		if typeof(cursor) != TYPE_DICTIONARY:
			return fallback
		var dict: Dictionary = cursor
		if not dict.has(key):
			return fallback
		cursor = dict[key]
	return cursor


func _safe_ratio(numerator: float, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return numerator / float(denominator)


func _average_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


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


func _build_default_report_path(total_rounds: int, preset_name: String, compare_preset_name: String, extension: String) -> String:
	var timestamp := _build_timestamp_slug()
	var mode_slug := "single_%s" % preset_name if compare_preset_name == "" else "ab_%s_vs_%s" % [preset_name, compare_preset_name]
	var file_name := "ai压测_%s_%d局_%s.%s" % [timestamp, total_rounds, mode_slug, extension]
	return "res://测试数据统计/%s" % file_name


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
