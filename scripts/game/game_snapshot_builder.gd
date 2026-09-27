extends RefCounted

const PipelineProfiler := preload("res://scripts/diagnostics/pipeline_profiler.gd")

# Detached display data. GameState remains the authority for legality and rules.
static func build(state, viewer_seat: int, include_diagnostics: bool = false) -> Dictionary:
	var started := PipelineProfiler.begin()
	var result: Dictionary = _profiled_build(state, viewer_seat, include_diagnostics)
	PipelineProfiler.record("snapshot_build", started)
	return result


static func _profiled_build(state, viewer_seat: int, include_diagnostics: bool = false) -> Dictionary:
	if viewer_seat < 0 or viewer_seat >= state.players.size():
		viewer_seat = 0
	var rules_debug: Dictionary = {} if state.rules == null else state.rules.to_debug_dict()
	var reaction_summary: String = ""
	if state.mahjong_judge != null:
		reaction_summary = state.mahjong_judge.summarize_candidates(state.pending_reactions)
	var ai_tuning_debug: Dictionary = {} if state.ai_tuning_config == null else state.ai_tuning_config.to_debug_dict()
	var snapshot: Dictionary = {
		"round_index": state.round_index,
		"current_phase": state.current_phase,
		"current_dealer_seat": state.current_dealer_seat,
		"current_turn_seat": state.current_turn_seat,
		"wall_count": state.wall_count,
		"discard_count": state.discard_pile.size(),
		"winner_count": state.round_winners.size(),
		"round_winners": state.round_winners.duplicate(),
		"shun_he_locks": state.shun_he_locks.duplicate(true),
		"settlement_data": state.settlement_data.duplicate(true),
		"last_gang_context": state.last_gang_context.duplicate(true),
		"pending_qiang_gang_context": state.pending_qiang_gang_context.duplicate(true),
		"debug_last_message": state.debug_last_message,
		"rules": rules_debug,
		"human_can_discard": state.can_human_discard(viewer_seat),
		"human_can_self_hu": state.can_human_self_hu(viewer_seat),
		"human_can_add_gang": state.can_human_add_gang(viewer_seat),
		"human_can_an_gang": state.can_human_an_gang(viewer_seat),
		"human_last_draw_tile_id": state._get_last_draw_tile_id_for_seat(viewer_seat),
		"human_ding_que_pending": state.is_human_ding_que_pending(viewer_seat),
		"human_ding_que_options": state.get_human_ding_que_options(viewer_seat),
		"dealer_ding_que_deferred": state._is_dealer_ding_que_deferred(),
		"recent_discard_display": state._get_recent_discard_display(),
		"recent_discard_tile_id": state._get_recent_discard_tile_id(),
		"recent_draw_display": state._get_recent_draw_display(),
		"recent_draw_seat": state._get_recent_draw_seat(),
		"reaction_summary": reaction_summary,
		"human_reaction_options": state.get_human_reaction_options(viewer_seat),
		"discard_context": state.current_discard_context.duplicate(true),
		"ai_level_index": int(state.ai_level),
		"ai_level_name": state.AI_LEVEL_LABELS[int(state.ai_level)],
		"ai_tuning_config": ai_tuning_debug,
		"ai_learning_profile": {} if state.ai_learning_engine == null else state.ai_learning_engine.get_runtime_summary(),
		"trainer_hint": state._get_human_trainer_hint_snapshot() if state.human_trainer_hint_enabled else {},
		"opening_roll": state.opening_roll_data.duplicate(true),
		"opening_roll_pending": state.opening_roll_pending_completion,
		"players": state.players.duplicate(true),
	}
	if include_diagnostics:
		snapshot.merge(_diagnostics(state))
	else:
		# The toolbar only needs the training mode flag, never the decision history.
		snapshot["hell_training"] = {"enabled": state._is_hell_training_mode()}
	return snapshot


static func _diagnostics(state) -> Dictionary:
	return {
		"ai_decision_metrics": state.ai_decision_metrics.duplicate(true),
		"latest_ai_reaction_review": state.latest_ai_reaction_review.duplicate(true),
		"ai_reaction_review_history": state.ai_reaction_review_history.duplicate(true),
		"pending_ai_reaction_request_id": state.pending_ai_reaction_request_id,
		"pending_ai_reaction_request_meta": state.pending_ai_reaction_request_meta.duplicate(true),
		"pending_ai_reaction_decision": state.pending_ai_reaction_decision.duplicate(true),
		"pending_ai_turn_request_id": state.pending_ai_turn_request_id,
		"pending_ai_turn_request_meta": state.pending_ai_turn_request_meta.duplicate(true),
		"pending_ai_turn_decision": state.pending_ai_turn_decision.duplicate(true),
		"ai_core_debug": state._build_ai_core_debug_snapshot(),
		"ai_chain_debug": state.ai_chain_debug_history.duplicate(),
		"hell_training": state._build_hell_training_debug_snapshot(),
		"ai_analysis_recording": state._build_ai_analysis_recording_debug_snapshot(),
		"debug_decision_trace": state._build_debug_decision_trace_snapshot(),
	}
