extends Node

signal state_changed(snapshot: Dictionary)
signal opening_roll_started(data: Dictionary)

const RuleConfigScript := preload("res://scripts/core/rule_config.gd")
const MahjongStateScript := preload("res://scripts/core/mahjong_state.gd")
const MahjongJudgeScript := preload("res://scripts/core/mahjong_judge.gd")
const DingQueResolverScript := preload("res://scripts/core/ding_que_resolver.gd")
const ReactionResolverScript := preload("res://scripts/core/reaction_resolver.gd")
const HuCheckerScript := preload("res://scripts/core/hu_checker.gd")
const ScoreResolverScript := preload("res://scripts/core/score_resolver.gd")
const ShantenAnalyzerScript := preload("res://scripts/core/shanten_analyzer.gd")
const DiscardAdvisorScript := preload("res://scripts/core/discard_advisor.gd")
const RiskAnalyzerScript := preload("res://scripts/core/risk_analyzer.gd")
const ReactionAdvisorScript := preload("res://scripts/core/reaction_advisor.gd")
const GangAdvisorScript := preload("res://scripts/core/gang_advisor.gd")
const AITuningConfigScript := preload("res://scripts/core/ai_tuning_config.gd")
const AILearningEngineScript := preload("res://scripts/core/ai_learning_engine.gd")
const OpeningRollResolverScript := preload("res://scripts/core/opening_roll_resolver.gd")
const AIManagerScript := preload("res://scripts/ai/AIManager.gd")

enum RoundPhase {
	BOOT,
	MAIN_MENU,
	TABLE_SETUP,
	DING_QUE,
	DRAW,
	DISCARD,
	REACTION,
	SETTLEMENT
}

enum AILevel {
	BEGINNER,
	INTERMEDIATE,
	ADVANCED,
	CHEATING
}

const DEFAULT_SUITS := ["tiao", "tong", "wan"]
const RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const COPIES_PER_TILE := 4
const STARTING_SCORE := 0
const AI_LEVEL_LABELS := ["初级", "中级", "骨灰级", "作弊级"]
const AI_ASYNC_TIMEOUT_MS := 1000
const AI_TURN_SOFT_TIMEOUT_MS := 2200
const AI_REACTION_SOFT_TIMEOUT_MS := 2200
const AI_REACTION_REVIEW_LIMIT := 24
const HELL_TRAINING_DIR := "res://测试数据统计/hell_training"
const HELL_MARKED_CASE_DIR := "res://测试数据统计/hell_marked_cases"
const HELL_REPLAY_DIR := "res://测试数据统计/hell_replay"
const AI_ANALYSIS_RECORDING_ENABLED := false
const DEBUG_TRAINING_RECORDING_ENABLED := false
const AI_LEARNING_RECORDING_ENABLED := false
const AI_SHADOW_RECORDING_ENABLED := true
const AI_SHADOW_MAX_EVENTS := 1600
const AI_SHADOW_MAX_SESSIONS := 4
const AI_CHAIN_DEBUG_ENABLED := false
const DIAGNOSTIC_EXPORT_ENABLED := false
const AI_ANALYSIS_DIR := "user://ai_analysis"
const DEBUG_DECISION_TRACE_DIR := "user://ai_decision_trace"
const DIAGNOSTIC_EXPORT_DIR := "user://diagnostic_exports"
const DIAGNOSTIC_DOWNLOAD_SUBDIR := "SichuanMahjongLogs"
const DIAGNOSTIC_MAX_DEPTH := 5
const DIAGNOSTIC_MAX_ARRAY_ITEMS := 80
const DIAGNOSTIC_MAX_DICT_KEYS := 120
const DIAGNOSTIC_MAX_STRING_LENGTH := 4000
const DIAGNOSTIC_MAX_TEXT_FILE_CHARS := 120000
const DIAGNOSTIC_MAX_DIR_TEXT_FILES := 160

var current_phase: RoundPhase = RoundPhase.BOOT
var current_dealer_seat: int = 0
var current_turn_seat: int = 0
var players: Array[Dictionary] = []
var wall: Array[Dictionary] = []
var wall_count: int = 0
var discard_pile: Array[Dictionary] = []
var round_winners: Array[int] = []
var previous_dealer_seat: int = -1
var settlement_data: Dictionary = {}
var last_turn_context: Dictionary = {}
var last_gang_context: Dictionary = {}
var pending_qiang_gang_context: Dictionary = {}
var last_draw_tile: Dictionary = {}
var shun_he_locks: Dictionary = {}
var debug_last_message: String = "GameState initialized."
var round_index: int = 1
var rules
var ding_que_resolver
var reaction_resolver
var hu_checker
var score_resolver
var shanten_analyzer
var discard_advisor
var risk_analyzer
var reaction_advisor
var gang_advisor
var ai_tuning_config
var ai_learning_engine
var opening_roll_resolver
var ai_manager
var ai_manual_tuning_overrides: Dictionary = {}
var current_discard_context: Dictionary = {}
var pending_reactions: Array[Dictionary] = []
var ai_level: AILevel = AILevel.ADVANCED
var trainer_history: Array[Dictionary] = []
var human_trainer_hint_enabled: bool = false
var latest_trainer_hint: Dictionary = {}
var latest_trainer_hint_cache_key: String = ""
var pending_trainer_hint_request_id: int = 0
var pending_trainer_hint_request_cache_key: String = ""
var pending_trainer_hint_request_seat: int = -1
var ai_decision_metrics: Dictionary = {}
var ai_reaction_review_history: Array[Dictionary] = []
var latest_ai_reaction_review: Dictionary = {}
var reaction_pass_evidence: Array[Dictionary] = []
var ai_public_events: Array[Dictionary] = []
var ai_public_event_version: int = 0
var self_hu_pass_locks: Dictionary = {}
var opening_roll_data: Dictionary = {}
var opening_roll_pending_completion: bool = false
var mahjong_state
var mahjong_judge
var pending_ai_turn_decision: Dictionary = {}
var pending_ai_reaction_decision: Dictionary = {}
var active_ai_discard_decision: Dictionary = {}
var pending_ai_turn_request_id: int = 0
var pending_ai_reaction_request_id: int = 0
var pending_ai_turn_request_meta: Dictionary = {}
var pending_ai_reaction_request_meta: Dictionary = {}
var ai_chain_debug_history: Array[String] = []
var hell_training_session_id: String = ""
var hell_training_decision_count: int = 0
var hell_training_marked_count: int = 0
var hell_training_category_counts: Dictionary = {}
var hell_training_severity_counts: Dictionary = {}
var latest_hell_decision_snapshot: Dictionary = {}
var hell_last_marked_signature: String = ""
var ai_analysis_session_id: String = ""
var ai_analysis_event_count: int = 0
var latest_ai_analysis_event: Dictionary = {}
var debug_decision_trace_session_id: String = ""
var debug_decision_trace_event_count: int = 0
var latest_debug_decision_trace_event: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var deterministic_seed_enabled: bool = false
var deterministic_seed: int = 0
var test_ai_policy_variants_by_seat: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	rules = RuleConfigScript.new(RuleConfigScript.MODE_SICHUAN_COMPETITIVE_BATTLE_TO_END)
	mahjong_state = MahjongStateScript.new()
	mahjong_judge = MahjongJudgeScript.new()
	ding_que_resolver = DingQueResolverScript.new()
	reaction_resolver = ReactionResolverScript.new()
	hu_checker = HuCheckerScript.new()
	score_resolver = ScoreResolverScript.new()
	shanten_analyzer = ShantenAnalyzerScript.new()
	discard_advisor = DiscardAdvisorScript.new()
	risk_analyzer = RiskAnalyzerScript.new()
	reaction_advisor = ReactionAdvisorScript.new()
	gang_advisor = GangAdvisorScript.new()
	ai_tuning_config = AITuningConfigScript.new()
	ai_tuning_config.apply_preset(AITuningConfigScript.PRESET_BONE_ASH)
	ai_tuning_config.auto_learning_enabled = AI_LEARNING_RECORDING_ENABLED
	ai_tuning_config.set_diagnostics_recording_enabled(_is_ai_analysis_recording_enabled())
	ai_level = AILevel.ADVANCED
	ai_learning_engine = AILearningEngineScript.new()
	ai_learning_engine.set_persistence_enabled(AI_LEARNING_RECORDING_ENABLED)
	ai_learning_engine.load_profile()
	_apply_ai_learning_adjustment()
	opening_roll_resolver = OpeningRollResolverScript.new()
	ai_manager = AIManagerScript.new()
	ai_manager.set_strict_native_runtime_required(true)
	ai_manager.set_prefer_csharp_backend(true)
	_bind_native_csharp_runtime_if_available()
	ai_manager.ai_turn_analysis_ready.connect(_on_ai_turn_analysis_ready)
	ai_manager.ai_reaction_analysis_ready.connect(_on_ai_reaction_analysis_ready)
	if _is_ai_analysis_recording_enabled():
		_ensure_ai_analysis_session()
		if _is_hell_training_mode():
			_ensure_hell_training_session()
	start_new_round()


func set_test_seed(seed_value: int) -> void:
	deterministic_seed_enabled = true
	deterministic_seed = seed_value
	_rng.seed = seed_value


func clear_test_seed() -> void:
	deterministic_seed_enabled = false
	_rng.randomize()


func start_new_round(preserve_dealer: bool = false) -> void:
	current_phase = RoundPhase.TABLE_SETUP
	if deterministic_seed_enabled:
		_rng.seed = deterministic_seed + int(round_index)
	_reload_ai_learning_for_new_round()
	var previous_players: Array[Dictionary] = players.duplicate(true)
	discard_pile.clear()
	round_winners.clear()
	settlement_data = _create_empty_settlement_data()
	last_turn_context.clear()
	last_gang_context.clear()
	pending_qiang_gang_context.clear()
	last_draw_tile = {}
	shun_he_locks.clear()
	current_discard_context.clear()
	pending_reactions.clear()
	trainer_history.clear()
	latest_trainer_hint.clear()
	ai_decision_metrics = _create_empty_ai_decision_metrics()
	ai_reaction_review_history.clear()
	latest_ai_reaction_review.clear()
	reaction_pass_evidence.clear()
	ai_public_events.clear()
	ai_public_event_version = 0
	self_hu_pass_locks.clear()
	pending_ai_turn_decision.clear()
	pending_ai_reaction_decision.clear()
	_clear_pending_ai_async_state()
	opening_roll_data.clear()
	opening_roll_pending_completion = false
	if preserve_dealer and previous_dealer_seat >= 0:
		current_dealer_seat = previous_dealer_seat
	else:
		current_dealer_seat = _select_initial_dealer()
	current_turn_seat = current_dealer_seat
	players = _create_initial_players(previous_players)
	wall = _build_wall()
	_shuffle_wall()
	wall_count = wall.size()
	_resolve_opening_roll()
	current_phase = RoundPhase.TABLE_SETUP
	_record_ai_analysis_event("round_start", {
		"dealer_seat": current_dealer_seat,
		"opening_roll": opening_roll_data.duplicate(true),
		"initial_wall_count": wall_count,
	})
	debug_last_message = "Round %d ready. Dealer seat=%d is rolling dice." % [
		round_index,
		current_dealer_seat,
	]
	_emit_state_changed()
	opening_roll_started.emit(opening_roll_data.duplicate(true))


func get_debug_snapshot() -> Dictionary:
	var rules_debug: Dictionary = {} if rules == null else rules.to_debug_dict()
	var reaction_summary := ""
	if mahjong_judge != null:
		reaction_summary = mahjong_judge.summarize_candidates(pending_reactions)
	var ai_tuning_debug: Dictionary = {} if ai_tuning_config == null else ai_tuning_config.to_debug_dict()
	return {
		"round_index": round_index,
		"current_phase": current_phase,
		"current_dealer_seat": current_dealer_seat,
		"current_turn_seat": current_turn_seat,
		"wall_count": wall_count,
		"discard_count": discard_pile.size(),
		"winner_count": round_winners.size(),
		"round_winners": round_winners.duplicate(),
		"shun_he_locks": shun_he_locks.duplicate(true),
		"settlement_data": settlement_data.duplicate(true),
		"last_gang_context": last_gang_context.duplicate(true),
		"pending_qiang_gang_context": pending_qiang_gang_context.duplicate(true),
		"debug_last_message": debug_last_message,
		"rules": rules_debug,
		"human_can_discard": can_human_discard(0),
		"human_can_self_hu": can_human_self_hu(0),
		"human_can_add_gang": can_human_add_gang(0),
		"human_can_an_gang": can_human_an_gang(0),
		"human_last_draw_tile_id": _get_last_draw_tile_id_for_seat(0),
		"human_ding_que_pending": is_human_ding_que_pending(0),
		"dealer_ding_que_deferred": _is_dealer_ding_que_deferred(),
		"recent_discard_display": _get_recent_discard_display(),
		"recent_discard_tile_id": _get_recent_discard_tile_id(),
		"recent_draw_display": _get_recent_draw_display(),
		"recent_draw_seat": _get_recent_draw_seat(),
		"reaction_summary": reaction_summary,
		"human_reaction_options": get_human_reaction_options(0),
		"discard_context": current_discard_context.duplicate(true),
		"ai_level_index": int(ai_level),
		"ai_level_name": AI_LEVEL_LABELS[int(ai_level)],
		"ai_tuning_config": ai_tuning_debug,
		"ai_learning_profile": {} if ai_learning_engine == null else ai_learning_engine.get_runtime_summary(),
		"ai_decision_metrics": ai_decision_metrics.duplicate(true),
		"latest_ai_reaction_review": latest_ai_reaction_review.duplicate(true),
		"ai_reaction_review_history": ai_reaction_review_history.duplicate(true),
		"pending_ai_reaction_request_id": pending_ai_reaction_request_id,
		"pending_ai_reaction_request_meta": pending_ai_reaction_request_meta.duplicate(true),
		"pending_ai_reaction_decision": pending_ai_reaction_decision.duplicate(true),
		"pending_ai_turn_request_id": pending_ai_turn_request_id,
		"pending_ai_turn_request_meta": pending_ai_turn_request_meta.duplicate(true),
		"pending_ai_turn_decision": pending_ai_turn_decision.duplicate(true),
		"ai_core_debug": _build_ai_core_debug_snapshot(),
		"ai_chain_debug": ai_chain_debug_history.duplicate(),
		"trainer_hint": _get_human_trainer_hint_snapshot() if human_trainer_hint_enabled else {},
		"opening_roll": opening_roll_data.duplicate(true),
		"opening_roll_pending": opening_roll_pending_completion,
		"hell_training": _build_hell_training_debug_snapshot(),
		"ai_analysis_recording": _build_ai_analysis_recording_debug_snapshot(),
		"debug_decision_trace": _build_debug_decision_trace_snapshot(),
		"players": players.duplicate(true),
	}


func get_ai_level_index() -> int:
	return int(ai_level)


func set_human_trainer_hint_enabled(enabled: bool) -> void:
	human_trainer_hint_enabled = enabled
	if ai_manager != null:
		ai_manager.set_compact_runtime_snapshots(not _is_hell_training_mode() and (human_trainer_hint_enabled or not _is_ai_analysis_recording_enabled()))
	if not enabled:
		latest_trainer_hint.clear()
		latest_trainer_hint_cache_key = ""
		_clear_pending_trainer_hint_request()


func set_ai_preset(preset_name: String) -> bool:
	if ai_tuning_config == null:
		return false
	ai_tuning_config.apply_preset(preset_name)
	if str(ai_tuning_config.preset_name) == AITuningConfigScript.PRESET_HELL:
		ai_level = AILevel.CHEATING
		if bool(ai_tuning_config.diagnostics_recording_enabled):
			_ensure_hell_training_session()
	elif str(ai_tuning_config.preset_name) == AITuningConfigScript.PRESET_INTERMEDIATE:
		ai_level = AILevel.INTERMEDIATE
	else:
		ai_level = AILevel.ADVANCED
	for player in players:
		if bool(player.get("is_ai", false)):
			player["ai_level"] = int(ai_level)
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 参数预设已切换为 %s。" % preset_name
	_emit_state_changed()
	return true


func set_hell_diagnostics_recording_enabled(enabled: bool) -> bool:
	if ai_tuning_config == null:
		return false
	if not _is_runtime_recording_enabled():
		ai_tuning_config.set_diagnostics_recording_enabled(false)
		latest_hell_decision_snapshot.clear()
		hell_last_marked_signature = ""
		debug_last_message = "实际使用包已关闭 AI 训练记录。"
		_emit_state_changed()
		return false
	ai_tuning_config.set_diagnostics_recording_enabled(enabled)
	if enabled and str(ai_tuning_config.preset_name) == AITuningConfigScript.PRESET_HELL:
		_ensure_hell_training_session()
	elif not enabled:
		latest_hell_decision_snapshot.clear()
	hell_last_marked_signature = ""
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 训练记录已%s。" % ("开启" if enabled else "关闭")
	_emit_state_changed()
	return true


func get_ai_preset_name() -> String:
	return "" if ai_tuning_config == null else str(ai_tuning_config.preset_name)


func _reload_ai_learning_for_new_round() -> void:
	if ai_tuning_config == null or ai_learning_engine == null:
		return
	ai_learning_engine.set_persistence_enabled(AI_LEARNING_RECORDING_ENABLED)
	ai_learning_engine.load_profile()
	ai_tuning_config.apply_preset(str(ai_tuning_config.preset_name))
	ai_tuning_config.auto_learning_enabled = AI_LEARNING_RECORDING_ENABLED
	_apply_ai_runtime_tuning()


func _build_ai_core_debug_snapshot() -> Dictionary:
	if ai_manager == null:
		return {}
	if not ai_manager.has_method("get_backend_status"):
		return ai_manager.get_debug_snapshot()
	var status: Dictionary = ai_manager.get_backend_status()
	return {
		"backend_status": status,
		"latest_turn_snapshot": ai_manager.latest_turn_snapshot.duplicate(true),
		"latest_reaction_snapshot": ai_manager.latest_reaction_snapshot.duplicate(true),
	}


func _build_full_ai_core_debug_snapshot() -> Dictionary:
	if ai_manager == null:
		return {}
	return ai_manager.get_debug_snapshot()


func _apply_ai_learning_adjustment() -> void:
	if ai_tuning_config == null or ai_learning_engine == null:
		return
	if not bool(ai_tuning_config.auto_learning_enabled):
		return
	ai_tuning_config.apply_learning_adjustment(ai_learning_engine.get_profile())


func _apply_ai_manual_tuning() -> void:
	if ai_tuning_config == null:
		return
	for key in ai_manual_tuning_overrides.keys():
		var value: int = int(ai_manual_tuning_overrides.get(key, 0))
		match str(key):
			"lookahead_candidate_count":
				ai_tuning_config.lookahead_candidate_count = clampi(value, 2, 5)
			"lookahead_draw_samples":
				ai_tuning_config.lookahead_draw_samples = clampi(value, 4, 12)
			"add_gang_min_score":
				ai_tuning_config.add_gang_min_score = clampi(value, 8, 50)
			"an_gang_min_score":
				ai_tuning_config.an_gang_min_score = clampi(value, 12, 60)
			"intermediate_top_pick_count":
				ai_tuning_config.intermediate_top_pick_count = clampi(value, 1, 3)
			"attack_tendency":
				ai_tuning_config.attack_tendency = clampi(value, -3, 3)
			"defense_tendency":
				ai_tuning_config.defense_tendency = clampi(value, -3, 3)
			"fast_ting_priority":
				ai_tuning_config.fast_ting_priority = clampi(value, 0, 4)
			"self_draw_priority":
				ai_tuning_config.self_draw_priority = clampi(value, 0, 4)
			"forced_cleanup_tendency":
				ai_tuning_config.forced_cleanup_tendency = clampi(value, 0, 4)
			"big_hand_tendency":
				ai_tuning_config.big_hand_tendency = clampi(value, 0, 4)
			"opponent_read_tendency":
				ai_tuning_config.opponent_read_tendency = clampi(value, 0, 4)


func _apply_ai_runtime_tuning() -> void:
	_apply_ai_learning_adjustment()
	_apply_ai_manual_tuning()
	if ai_manager != null:
		ai_manager.set_compact_runtime_snapshots(not _is_hell_training_mode() and (human_trainer_hint_enabled or not _is_ai_analysis_recording_enabled()))


func set_ai_tuning_value(key: String, value: int) -> bool:
	if ai_tuning_config == null:
		return false
	match key:
		"lookahead_candidate_count":
			ai_manual_tuning_overrides[key] = clampi(value, 2, 5)
		"lookahead_draw_samples":
			ai_manual_tuning_overrides[key] = clampi(value, 4, 12)
		"add_gang_min_score":
			ai_manual_tuning_overrides[key] = clampi(value, 8, 50)
		"an_gang_min_score":
			ai_manual_tuning_overrides[key] = clampi(value, 12, 60)
		"intermediate_top_pick_count":
			ai_manual_tuning_overrides[key] = clampi(value, 1, 3)
		"attack_tendency":
			ai_manual_tuning_overrides[key] = clampi(value, -3, 3)
		"defense_tendency":
			ai_manual_tuning_overrides[key] = clampi(value, -3, 3)
		"fast_ting_priority":
			ai_manual_tuning_overrides[key] = clampi(value, 0, 4)
		"self_draw_priority":
			ai_manual_tuning_overrides[key] = clampi(value, 0, 4)
		"forced_cleanup_tendency":
			ai_manual_tuning_overrides[key] = clampi(value, 0, 4)
		"big_hand_tendency":
			ai_manual_tuning_overrides[key] = clampi(value, 0, 4)
		"opponent_read_tendency":
			ai_manual_tuning_overrides[key] = clampi(value, 0, 4)
		_:
			return false
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 调参已更新：%s = %d" % [key, int(ai_manual_tuning_overrides.get(key, value))]
	_emit_state_changed()
	return true


func set_ai_prefer_csharp_backend(enabled: bool) -> bool:
	if ai_manager == null:
		return false
	if not enabled:
		ai_manager.set_prefer_csharp_backend(true)
		debug_last_message = "AI 决策已固定为 C# 主判，前端 GDScript 不再作为决策后端。"
		_emit_state_changed()
		return false
	ai_manager.set_prefer_csharp_backend(true)
	debug_last_message = "AI 计算后端已保持为 C# 主判牌。"
	_emit_state_changed()
	return true


func set_ai_csharp_host_mode_enabled(enabled: bool, port: int = 38581) -> bool:
	if ai_manager == null:
		return false
	ai_manager.set_csharp_host_mode_enabled(enabled, port)
	debug_last_message = "C# 常驻 Host 模式已%s（端口 %d）。" % [("开启" if enabled else "关闭"), port]
	_emit_state_changed()
	return true


func set_ai_auto_learning_enabled(enabled: bool) -> bool:
	if ai_tuning_config == null:
		return false
	if not AI_LEARNING_RECORDING_ENABLED:
		ai_tuning_config.auto_learning_enabled = false
		_apply_ai_runtime_tuning()
		debug_last_message = "实际使用包已关闭 AI 自动学习记录。"
		_emit_state_changed()
		return false
	ai_tuning_config.auto_learning_enabled = enabled
	ai_tuning_config.apply_preset(str(ai_tuning_config.preset_name))
	ai_tuning_config.auto_learning_enabled = enabled
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 自动学习调参已%s。" % ("开启" if enabled else "关闭")
	_emit_state_changed()
	return true


func set_ai_endgame_absolute_defense_enabled(enabled: bool) -> bool:
	if ai_tuning_config == null:
		return false
	ai_tuning_config.endgame_absolute_defense = enabled
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 尾盘绝对防炮已%s。" % ("开启" if enabled else "关闭")
	_emit_state_changed()
	return true


func apply_bone_ash_recommended_tuning() -> bool:
	if ai_tuning_config == null:
		return false
	ai_manual_tuning_overrides.clear()
	ai_tuning_config.apply_preset("bone_ash")
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 已恢复骨灰推荐参数。"
	_emit_state_changed()
	return true


func reset_ai_tuning_overrides() -> bool:
	if ai_tuning_config == null:
		return false
	ai_manual_tuning_overrides.clear()
	ai_tuning_config.apply_preset(str(ai_tuning_config.preset_name))
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 手动调参已恢复为预设 + 学习参数。"
	_emit_state_changed()
	return true


func _update_ai_learning_after_round(score_changes: Dictionary) -> void:
	if ai_learning_engine == null:
		return
	if not AI_LEARNING_RECORDING_ENABLED:
		return
	if players.is_empty() or bool(players[0].get("is_ai", false)):
		return
	var round_result := {
		"round_index": round_index,
		"end_reason": str(settlement_data.get("end_reason", "")),
		"score_changes": score_changes.duplicate(true),
		"win_events": settlement_data.get("win_events", []).duplicate(true),
		"gang_events": settlement_data.get("gang_events", []).duplicate(true),
		"winner_seats": settlement_data.get("winner_seats", []).duplicate(),
		"ai_decision_metrics": ai_decision_metrics.duplicate(true),
		"latest_ai_reaction_review": latest_ai_reaction_review.duplicate(true),
		"ai_reaction_review_history": ai_reaction_review_history.duplicate(true),
		"ai_core_debug": _build_full_ai_core_debug_snapshot(),
	}
	ai_learning_engine.record_human_round(round_result)
	ai_tuning_config.apply_preset(str(ai_tuning_config.preset_name))
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 已记录本局结果，并按最新学习数据更新参数。"


func set_ai_level(level: int) -> bool:
	if level < int(AILevel.BEGINNER) or level > int(AILevel.CHEATING):
		return false
	if ai_tuning_config != null:
		var preset_name := AITuningConfigScript.PRESET_INTERMEDIATE
		match level:
			AILevel.CHEATING:
				preset_name = AITuningConfigScript.PRESET_HELL
			AILevel.ADVANCED:
				preset_name = AITuningConfigScript.PRESET_BONE_ASH
			_:
				preset_name = AITuningConfigScript.PRESET_INTERMEDIATE
		ai_tuning_config.apply_preset(preset_name)
		if preset_name == AITuningConfigScript.PRESET_HELL and bool(ai_tuning_config.diagnostics_recording_enabled):
			_ensure_hell_training_session()
	ai_level = level
	for player in players:
		if bool(player.get("is_ai", false)):
			player["ai_level"] = int(ai_level)
	_apply_ai_runtime_tuning()
	debug_last_message = "AI 难度已切换为 %s。" % AI_LEVEL_LABELS[int(ai_level)]
	_emit_state_changed()
	return true


func complete_opening_roll() -> bool:
	if current_phase != RoundPhase.TABLE_SETUP or not opening_roll_pending_completion:
		return false
	_deal_initial_hands()
	wall_count = wall.size()
	opening_roll_pending_completion = false
	debug_last_message = "骰子结果 %d + %d = %d，判定%s，开始发牌。" % [
		int(opening_roll_data.get("die_a", 0)),
		int(opening_roll_data.get("die_b", 0)),
		int(opening_roll_data.get("total", 0)),
		str(opening_roll_data.get("opening_side_label", "自家")),
	]
	_enter_ding_que_phase()
	return true


func choose_ding_que(seat: int, suit: String) -> bool:
	if not rules.requires_ding_que_phase():
		return false
	if not rules.requires_ding_que_phase():
		return false
	if current_phase != RoundPhase.DING_QUE:
		return false
	if suit not in _active_suits():
		return false
	if seat < 0 or seat >= players.size():
		return false
	if players[seat]["ding_que"] != "":
		return false
	if seat == current_dealer_seat and not _must_dealer_choose_now():
		return false

	players[seat]["ding_que"] = suit
	# The iOS AOT runtime can become callable after the opening phase first asks
	# for AI choices. Retry the required C# decisions when the human confirms.
	_auto_select_ai_ding_que()
	debug_last_message = "%s 选择缺门：%s" % [_seat_display_name(seat), _suit_display_name(suit)]
	_emit_state_changed()
	_complete_ding_que_if_ready()
	return true


func get_human_ding_que_options(seat: int) -> Array:
	if not rules.requires_ding_que_phase():
		return []
	if seat < 0 or seat >= players.size():
		return []
	if players[seat]["ding_que"] != "":
		return []
	if seat == current_dealer_seat and not _must_dealer_choose_now():
		return []
	return _active_suits()


func is_human_ding_que_pending(seat: int) -> bool:
	if not rules.requires_ding_que_phase():
		return false
	if current_phase != RoundPhase.DING_QUE:
		return false
	if seat < 0 or seat >= players.size():
		return false
	if players[seat]["is_ai"] or players[seat]["ding_que"] != "":
		return false
	if seat != current_dealer_seat:
		return true
	return _must_dealer_choose_now()


func can_human_discard(seat: int) -> bool:
	if current_phase != RoundPhase.DISCARD:
		return false
	if seat < 0 or seat >= players.size():
		return false
	return current_turn_seat == seat and not players[seat]["is_ai"] and not players[seat]["has_won"]


func is_ai_turn_ready() -> bool:
	if current_phase != RoundPhase.DISCARD:
		return false
	if current_turn_seat < 0 or current_turn_seat >= players.size():
		return false
	return players[current_turn_seat]["is_ai"] and not players[current_turn_seat]["has_won"]


func is_ai_reaction_pending() -> bool:
	if current_phase != RoundPhase.REACTION:
		return false
	# A visible human claim must keep its response window stable. Without this
	# guard, a farther or lower-priority AI candidate can advance the reaction
	# state while the player is trying to press 碰/杠/胡.
	if _has_pending_human_reaction_decision():
		return false
	for candidate in pending_reactions:
		var seat: int = candidate["seat"]
		if seat >= 0 and seat < players.size() and players[seat]["is_ai"]:
			return true
	return false


func _has_pending_human_reaction_decision() -> bool:
	if current_phase != RoundPhase.REACTION:
		return false
	for candidate in pending_reactions:
		var seat := int(candidate.get("seat", -1))
		if seat < 0 or seat >= players.size() or bool(players[seat].get("is_ai", false)):
			continue
		var options := get_human_reaction_options(seat)
		if bool(options.get("can_hu", false)) \
			or bool(options.get("can_gang", false)) \
			or bool(options.get("can_peng", false)):
			return true
	return false


func get_player_hand_tiles(seat: int) -> Array:
	if seat < 0 or seat >= players.size():
		return []
	return players[seat]["hand_tiles"].duplicate(true)


func _build_player_state(seat: int) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	return mahjong_state.build_player_state(players[seat])


func _build_table_state() -> Dictionary:
	var table_state: Dictionary = mahjong_state.build_table_state(
		players,
		current_turn_seat,
		int(current_phase),
		current_discard_context,
		last_draw_tile,
		pending_reactions,
		wall_count
	)
	table_state["reaction_pass_evidence"] = reaction_pass_evidence.duplicate(true)
	table_state["public_ai_events"] = ai_public_events.duplicate(true)
	table_state["event_version"] = ai_public_event_version
	table_state["last_gang_context"] = last_gang_context.duplicate(true)
	table_state["shun_he_locks"] = shun_he_locks.duplicate(true)
	table_state["round_index"] = round_index
	table_state["current_dealer_seat"] = current_dealer_seat
	table_state["total_rounds"] = 0
	table_state["remaining_rounds"] = 0
	table_state["test_ai_policy_variants_by_seat"] = test_ai_policy_variants_by_seat.duplicate(true)
	return table_state


func can_human_self_hu(seat: int) -> bool:
	if current_phase != RoundPhase.DISCARD:
		return false
	if seat < 0 or seat >= players.size():
		return false
	if current_turn_seat != seat or players[seat]["has_won"]:
		return false
	if not _can_seat_self_hu_now(seat):
		return false
	var lock_key := str(seat)
	if self_hu_pass_locks.has(lock_key):
		var locked_tile_id := int(self_hu_pass_locks.get(lock_key, -1))
		if locked_tile_id == _get_last_draw_tile_id_for_seat(seat):
			return false
	return true


func can_human_add_gang(seat: int) -> bool:
	if current_phase != RoundPhase.DISCARD:
		return false
	if seat < 0 or seat >= players.size():
		return false
	if current_turn_seat != seat or players[seat]["has_won"]:
		return false
	return _find_add_gang_option(seat).size() > 0


func can_human_an_gang(seat: int) -> bool:
	if current_phase != RoundPhase.DISCARD:
		return false
	if seat < 0 or seat >= players.size():
		return false
	if current_turn_seat != seat or players[seat]["has_won"]:
		return false
	return _find_an_gang_option(seat).size() > 0


func _can_seat_self_hu_now(seat: int) -> bool:
	if seat < 0 or seat >= players.size():
		return false
	if current_phase != RoundPhase.DISCARD:
		return false
	if current_turn_seat != seat or players[seat]["has_won"]:
		return false
	if _get_last_draw_tile_id_for_seat(seat) == -1:
		if not _is_opening_self_hu_window(seat):
			return false
	return mahjong_judge.can_player_self_hu(_build_player_state(seat), rules)


func _is_opening_self_hu_window(seat: int) -> bool:
	if seat != current_dealer_seat:
		return false
	if str(last_turn_context.get("draw_reason", "")) != "opening_discard":
		return false
	if int(last_turn_context.get("seat", -1)) != seat:
		return false
	if not discard_pile.is_empty():
		return false
	return int(players[seat].get("hand_count", 0)) == 14


func get_human_reaction_options(seat: int) -> Dictionary:
	var candidate: Dictionary = _get_reaction_candidate_for_seat(seat)
	if candidate.is_empty():
		return {
			"can_peng": false,
			"can_gang": false,
			"can_hu": false,
			"can_pass": false,
		}
	var reaction_tile: Dictionary = current_discard_context.get("tile", {})
	var ding_que_claim_blocked := not reaction_tile.is_empty() and _is_ding_que_tile_for_seat(seat, reaction_tile)
	var can_peng := bool(candidate["can_peng"])
	var can_gang := bool(candidate["can_gang"])
	if ding_que_claim_blocked:
		can_peng = false
		can_gang = false
	var can_hu := bool(candidate["can_hu"])
	return {
		"can_peng": can_peng and not _has_higher_priority_candidate_than(seat, "peng"),
		"can_gang": can_gang and not _has_higher_priority_candidate_than(seat, "gang"),
		"can_hu": can_hu,
		"can_pass": true,
	}


func advance_to_next_round() -> bool:
	if current_phase != RoundPhase.SETTLEMENT:
		return false
	previous_dealer_seat = _resolve_next_dealer_seat()
	round_index += 1
	start_new_round(true)
	return true


func execute_human_peng(seat: int) -> bool:
	if current_phase != RoundPhase.REACTION:
		debug_last_message = "当前不在响应阶段，不能碰。"
		return false
	var candidate: Dictionary = _get_reaction_candidate_for_seat(seat)
	if candidate.is_empty() or not candidate["can_peng"]:
		debug_last_message = "%s 当前没有可碰候选。" % _seat_display_name(seat)
		return false
	if _has_higher_priority_candidate_than(seat, "peng"):
		debug_last_message = "%s 碰牌需等待更高优先级响应处理。" % _seat_display_name(seat)
		return false
	return _execute_peng(seat)


func execute_human_gang(seat: int) -> bool:
	if current_phase != RoundPhase.REACTION:
		return false
	var candidate: Dictionary = _get_reaction_candidate_for_seat(seat)
	if candidate.is_empty() or not candidate["can_gang"]:
		return false
	if _has_higher_priority_candidate_than(seat, "gang"):
		return false
	return _execute_gang(seat)


func execute_human_hu(seat: int) -> bool:
	if current_phase != RoundPhase.REACTION:
		return false
	var candidate: Dictionary = _get_reaction_candidate_for_seat(seat)
	if candidate.is_empty() or not candidate["can_hu"]:
		return false
	return _execute_hu_on_discard(seat)


func execute_human_self_hu(seat: int) -> bool:
	if not can_human_self_hu(seat):
		return false
	return _execute_self_draw_hu(seat)


func pass_human_self_hu(seat: int) -> bool:
	if current_phase != RoundPhase.DISCARD:
		return false
	if not can_human_discard(seat):
		return false
	var draw_tile_id := _get_last_draw_tile_id_for_seat(seat)
	if draw_tile_id == -1:
		return false
	if not mahjong_judge.can_player_self_hu(_build_player_state(seat), rules):
		return false
	self_hu_pass_locks[str(seat)] = draw_tile_id
	debug_last_message = "%s 本巡放弃自摸，需继续出牌。" % _seat_display_name(seat)
	_emit_state_changed()
	return true


func execute_human_add_gang(seat: int) -> bool:
	if not can_human_add_gang(seat):
		return false
	return _start_add_gang(seat)


func execute_human_an_gang(seat: int) -> bool:
	if not can_human_an_gang(seat):
		return false
	return _execute_an_gang(seat)


func pass_human_reaction(seat: int) -> bool:
	if current_phase != RoundPhase.REACTION:
		return false
	var candidate: Dictionary = _get_reaction_candidate_for_seat(seat)
	if candidate.is_empty():
		return false
	_record_reaction_pass_evidence(seat, candidate)
	_remove_reaction_candidate_for_seat(seat)
	_apply_passed_hu_lock_if_needed(seat, candidate)
	debug_last_message = "%s 选择过牌。剩余可响应：%s" % [_seat_display_name(seat), mahjong_judge.summarize_candidates(pending_reactions)]
	if pending_reactions.is_empty():
		if str(current_discard_context.get("reaction_type", "discard")) == "qiang_gang_hu":
			_finalize_qiang_gang_after_hu_or_pass()
		else:
			_finalize_reaction_after_hu_or_pass()
	else:
		_emit_state_changed()
	return true


func discard_tile_by_id(seat: int, tile_id: int) -> bool:
	if not can_human_discard(seat):
		return false
	return _discard_tile_internal(seat, tile_id)


func run_ai_turn() -> bool:
	if not is_ai_turn_ready():
		return false
	_pump_ai_background_requests()

	var decision: Dictionary = _get_or_prepare_ai_turn_decision()
	if decision.is_empty():
		debug_last_message = "C# AI 正在计算当前出牌，等待后台结果。"
		return false
	pending_ai_turn_decision.clear()
	_clear_pending_ai_turn_request()
	if _execute_ai_turn_decision(decision):
		return true
	debug_last_message = "C# AI seat %d 返回了不可执行决策，已拒绝本地替代出牌。" % current_turn_seat
	_emit_state_changed()
	return false


func prepare_ai_turn_decision() -> bool:
	if not is_ai_turn_ready():
		return false
	_pump_ai_background_requests()
	if not _get_or_prepare_ai_turn_decision().is_empty():
		return true
	return _is_pending_ai_turn_request_valid()


func prepare_ai_reaction_decision() -> bool:
	if not is_ai_reaction_pending():
		return false
	_pump_ai_background_requests()
	if not _get_or_prepare_ai_reaction_decision().is_empty():
		return true
	return _is_pending_ai_reaction_request_valid()


func _get_or_prepare_ai_turn_decision() -> Dictionary:
	if _is_pending_ai_turn_decision_valid():
		return pending_ai_turn_decision.duplicate(true)
	if _is_pending_ai_turn_request_valid():
		return {}
	if _start_ai_turn_background_request():
		_pump_ai_background_requests()
		if _is_pending_ai_turn_decision_valid():
			return pending_ai_turn_decision.duplicate(true)
		return {}
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"):
		debug_last_message = "C# AI 运行时未就绪，严格模式下暂停 AI 出牌。"
		return {}
	return {}


func _is_pending_ai_turn_decision_valid() -> bool:
	if pending_ai_turn_decision.is_empty():
		return false
	var seat := int(pending_ai_turn_decision.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return false
	var state_signature := str(pending_ai_turn_decision.get("state_signature", ""))
	if state_signature != "" and state_signature != _ai_turn_state_signature(seat):
		return false
	return int(pending_ai_turn_decision.get("round_index", -1)) == round_index \
		and int(pending_ai_turn_decision.get("seat", -1)) == current_turn_seat \
		and int(pending_ai_turn_decision.get("phase", -1)) == int(current_phase) \
		and int(pending_ai_turn_decision.get("wall_count", -1)) == wall_count \
		and int(pending_ai_turn_decision.get("hand_count", -1)) == int(players[current_turn_seat].get("hand_count", -1)) \
		and _is_ai_turn_decision_still_executable(pending_ai_turn_decision)


func _is_ai_turn_decision_still_executable(decision: Dictionary) -> bool:
	var seat := int(decision.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return false
	match str(decision.get("action", "")):
		"discard":
			var requested_tile_id := int(decision.get("tile_id", -1))
			return requested_tile_id != -1 and not _tile_by_id_in_hand(seat, requested_tile_id).is_empty()
	return true


func _is_pending_ai_turn_request_valid() -> bool:
	if pending_ai_turn_request_id <= 0 or pending_ai_turn_request_meta.is_empty():
		return false
	var seat := int(pending_ai_turn_request_meta.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return false
	var state_signature := str(pending_ai_turn_request_meta.get("state_signature", ""))
	if state_signature != "" and state_signature != _ai_turn_state_signature(seat):
		return false
	var state_matches := int(pending_ai_turn_request_meta.get("round_index", -1)) == round_index \
		and int(pending_ai_turn_request_meta.get("seat", -1)) == current_turn_seat \
		and int(pending_ai_turn_request_meta.get("phase", -1)) == int(current_phase) \
		and int(pending_ai_turn_request_meta.get("wall_count", -1)) == wall_count \
		and int(pending_ai_turn_request_meta.get("hand_count", -1)) == int(players[current_turn_seat].get("hand_count", -1))
	if not state_matches:
		return false
	if _pending_ai_turn_request_elapsed_ms() > AI_TURN_SOFT_TIMEOUT_MS:
		debug_last_message = "C# AI 出牌计算较慢，继续等待当前后台结果。"
		if not bool(pending_ai_turn_request_meta.get("soft_timeout_logged", false)):
			_record_ai_chain_debug("turn_request_slow_wait id=%d elapsed=%d meta=%s" % [
				pending_ai_turn_request_id,
				_pending_ai_turn_request_elapsed_ms(),
				JSON.stringify(pending_ai_turn_request_meta).left(500),
			])
			pending_ai_turn_request_meta["soft_timeout_logged"] = true
	return true


func _pending_ai_turn_request_elapsed_ms() -> int:
	var started_at_ms := int(pending_ai_turn_request_meta.get("started_at_ms", 0))
	if started_at_ms <= 0:
		return 0
	return maxi(0, Time.get_ticks_msec() - started_at_ms)


func _build_ai_turn_decision(force_lightweight: bool = false) -> Dictionary:
	if not is_ai_turn_ready():
		_record_ai_chain_debug("turn_build_skip_not_ready phase=%s turn=%s" % [str(current_phase), str(current_turn_seat)])
		return {}
	var seat: int = current_turn_seat
	var base := {
		"round_index": round_index,
		"seat": seat,
		"phase": int(current_phase),
		"wall_count": wall_count,
		"hand_count": int(players[seat].get("hand_count", 0)),
		"state_signature": _ai_turn_state_signature(seat),
	}
	var table_state := _build_table_state()
	var player_state := _build_player_state(seat)
	_record_ai_chain_debug("turn_build_start seat=%d hand=%d wall=%d native=%s" % [
		seat,
		int(players[seat].get("hand_count", 0)),
		wall_count,
		str(_has_native_csharp_runtime()),
	])
	var allow_cheat: bool = int(players[seat].get("ai_level", int(ai_level))) == int(AILevel.CHEATING)
	var self_action: Dictionary = _build_ai_self_action_decision(seat, player_state, table_state)
	if not self_action.is_empty():
		for key in self_action.keys():
			base[key] = self_action[key]
		_record_ai_analysis_event("turn_decision_built", {
			"seat": seat,
			"decision": base.duplicate(true),
			"decision_path": "self_action",
			"self_action_diagnostic": _build_self_action_diagnostic_profile(seat, self_action),
			"player_state": player_state.duplicate(true),
			"table_state": table_state.duplicate(true),
		})
		_record_ai_decision_trace_event("turn_decision_built", {
			"seat": seat,
			"decision": base.duplicate(true),
			"decision_path": "self_action",
			"self_action_diagnostic": _build_self_action_diagnostic_profile(seat, self_action),
			"player_state": player_state.duplicate(true),
			"table_state": table_state.duplicate(true),
		})
		return base
	var analysis: Dictionary = {}
	if ai_manager != null:
		if _is_hell_challenge_mode() and ai_manager.has_native_hell_challenge_runtime():
			analysis = ai_manager.analyze_hell_challenge_discard(player_state, table_state, rules, _build_hell_challenge_payload())
		else:
			analysis = ai_manager.analyze_turn_lightweight(player_state, table_state, rules, ai_tuning_config, hu_checker, risk_analyzer, allow_cheat) if force_lightweight else ai_manager.analyze_turn(player_state, table_state, rules, ai_tuning_config, hu_checker, risk_analyzer, allow_cheat)
	if analysis.is_empty():
		var native_error := ""
		if ai_manager != null:
			native_error = str(ai_manager.get_backend_status().get("last_native_turn_error", ""))
		debug_last_message = "C# AI 未返回有效出牌结果：%s" % (native_error if native_error != "" else "empty_analysis")
		_record_ai_chain_debug("turn_build_empty_analysis seat=%d err=%s" % [seat, debug_last_message])
		return {}
	analysis = _apply_ding_que_priority_to_discard_analysis(seat, analysis)
	_sync_latest_turn_snapshot_analysis(analysis)
	var selected_tile: Dictionary = analysis.get("recommended", {}).get("tile", {})
	if selected_tile.is_empty():
		debug_last_message = "C# AI 已返回，但推荐牌未映射到当前手牌。"
		_record_ai_chain_debug("turn_build_map_failed seat=%d analysis=%s" % [seat, JSON.stringify(analysis).left(900)])
		return {}
	var analysis_action := str(analysis.get("action", "")).strip_edges().to_lower()
	if analysis_action == "gang":
		var gang_decision := _build_ai_turn_gang_decision_from_analysis(base, seat, analysis)
		if not gang_decision.is_empty():
			_record_ai_analysis_event("turn_decision_built", {
				"seat": seat,
				"decision": gang_decision.duplicate(true),
				"decision_path": "turn_gang",
				"turn_diagnostic": _build_turn_diagnostic_profile(seat, analysis, selected_tile, {}),
				"player_state": player_state.duplicate(true),
				"table_state": table_state.duplicate(true),
			})
			_record_ai_decision_trace_event("turn_decision_built", {
				"seat": seat,
				"decision": gang_decision.duplicate(true),
				"decision_path": "turn_gang",
				"turn_diagnostic": _build_turn_diagnostic_profile(seat, analysis, selected_tile, {}),
				"player_state": player_state.duplicate(true),
				"table_state": table_state.duplicate(true),
			})
			return gang_decision
		debug_last_message = "C# AI 返回杠牌动作，但当前牌面未找到可执行杠选项。"
		_record_ai_chain_debug("turn_build_gang_map_failed seat=%d analysis=%s" % [seat, JSON.stringify(analysis).left(900)])
		return {}
	var hell_decision := _apply_hell_oracle_to_discard_decision(
		base,
		seat,
		player_state,
		table_state,
		analysis,
		selected_tile
	)
	selected_tile = hell_decision.get("selected_tile", selected_tile)
	var hell_oracle: Dictionary = hell_decision.get("oracle", {})
	_record_ai_chain_debug("turn_build_ok seat=%d tile=%s id=%d backend=%s" % [
		seat,
		str(selected_tile.get("display_name", selected_tile.get("tile_name", "?"))),
		int(selected_tile.get("id", -1)),
		str(analysis.get("backend_mode", "")),
	])
	base = hell_decision.get("decision", base)
	_record_ai_analysis_event("turn_decision_built", {
		"seat": seat,
		"decision": base.duplicate(true),
		"decision_path": "discard",
		"selected_tile": selected_tile.duplicate(true),
		"turn_diagnostic": _build_turn_diagnostic_profile(seat, analysis, selected_tile, hell_oracle),
		"player_state": player_state.duplicate(true),
		"table_state": table_state.duplicate(true),
	})
	_record_ai_decision_trace_event("turn_decision_built", {
		"seat": seat,
		"decision": base.duplicate(true),
		"decision_path": "discard",
		"selected_tile": selected_tile.duplicate(true),
		"turn_diagnostic": _build_turn_diagnostic_profile(seat, analysis, selected_tile, hell_oracle),
		"player_state": player_state.duplicate(true),
		"table_state": table_state.duplicate(true),
	})
	return base


func _build_ai_turn_gang_decision_from_analysis(base: Dictionary, seat: int, analysis: Dictionary) -> Dictionary:
	var tile_type := int(analysis.get("tile_type", analysis.get("recommended", {}).get("csharp_tile_type", -1)))
	var gang_subtype := str(analysis.get("gang_subtype", analysis.get("gangSubtype", ""))).strip_edges()
	var option: Dictionary = {}
	if gang_subtype == "add_gang":
		option = _find_option_by_tile_type(_find_all_add_gang_options(seat), tile_type, "tile")
		if not option.is_empty():
			var decision := base.duplicate(true)
			decision["action"] = "add_gang"
			decision["gang_option"] = option.duplicate(true)
			decision["analysis"] = analysis.duplicate(true)
			return decision
	if gang_subtype == "an_gang" or option.is_empty():
		option = _find_option_by_tile_type(_find_all_an_gang_options(seat), tile_type, "tiles")
		if not option.is_empty():
			var decision := base.duplicate(true)
			decision["action"] = "an_gang"
			decision["gang_option"] = option.duplicate(true)
			decision["analysis"] = analysis.duplicate(true)
			return decision
	return {}


func _build_ai_self_action_decision(seat: int, player_state: Dictionary, table_state: Dictionary) -> Dictionary:
	if ai_manager == null:
		return {}
	var an_options := _find_all_an_gang_options(seat)
	var add_options := _find_all_add_gang_options(seat)
	var an_types := _tile_types_from_options(an_options, "tiles")
	var add_types := _tile_types_from_options(add_options, "tile")
	var add_qiang_counts := _add_gang_qiang_counts_by_tile_type(seat, add_options)
	var can_self_hu := _can_seat_self_hu_now(seat)
	if not can_self_hu and an_types.is_empty() and add_types.is_empty():
		return {}
	var csharp_decision: Dictionary = ai_manager.analyze_self_action(player_state, table_state, rules, can_self_hu, an_types, add_types, add_qiang_counts, [])
	if csharp_decision.is_empty():
		debug_last_message = "C# AI 未返回有效自摸动作结果，当前等待重试。"
		return {}
	var action := str(csharp_decision.get("action", "pass")).strip_edges().to_lower()
	if action == "hu" and can_self_hu:
		return {
			"action": "self_hu",
			"analysis": csharp_decision.duplicate(true),
		}
	if action == "gang":
		var tile_type := int(csharp_decision.get("tile_type", -1))
		var subtype := str(csharp_decision.get("gang_subtype", csharp_decision.get("gangSubtype", "")))
		var option: Dictionary = {}
		if subtype == "add_gang":
			option = _find_option_by_tile_type(add_options, tile_type, "tile")
			if not option.is_empty():
				return {
					"action": "add_gang",
					"gang_option": option.duplicate(true),
					"analysis": csharp_decision.duplicate(true),
				}
		if subtype == "an_gang" or option.is_empty():
			option = _find_option_by_tile_type(an_options, tile_type, "tiles")
			if not option.is_empty():
				return {
					"action": "an_gang",
					"gang_option": option.duplicate(true),
					"analysis": csharp_decision.duplicate(true),
				}
	return {}


func _add_gang_qiang_counts_by_tile_type(seat: int, add_options: Array) -> Dictionary:
	var result := {}
	for option in add_options:
		var tile: Dictionary = option.get("tile", {})
		var tile_type := _sichuan_tile_type(tile)
		if tile_type < 0:
			continue
		result[str(tile_type)] = _build_qiang_gang_hu_candidates(seat, tile).size()
	return result


func _build_ai_turn_forced_decision() -> Dictionary:
	return {}


func _execute_ai_turn_decision(decision: Dictionary) -> bool:
	if not is_ai_turn_ready():
		_record_ai_chain_debug("turn_execute_skip_not_ready decision=%s phase=%s turn=%s" % [
			JSON.stringify(decision).left(500),
			str(current_phase),
			str(current_turn_seat),
		])
		return false
	var seat: int = int(decision.get("seat", -1))
	if seat != current_turn_seat:
		_record_ai_chain_debug("turn_execute_seat_mismatch decision_seat=%d turn=%d" % [seat, current_turn_seat])
		return false
	match str(decision.get("action", "")):
		"self_hu":
			_record_ai_metric("self_hu_actions")
			_record_hell_decision_snapshot(decision, "self_hu")
			var self_hu_ok := _execute_self_draw_hu(seat)
			_record_ai_analysis_event("turn_action_executed", {
				"seat": seat,
				"action": "self_hu",
				"executed": self_hu_ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			_record_ai_decision_trace_event("turn_action_executed", {
				"seat": seat,
				"action": "self_hu",
				"executed": self_hu_ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			return self_hu_ok
		"an_gang":
			_record_ai_metric("an_gang_attempts")
			_record_hell_decision_snapshot(decision, "an_gang")
			var an_gang_ok := _execute_an_gang(seat, decision.get("gang_option", {}))
			_record_ai_analysis_event("turn_action_executed", {
				"seat": seat,
				"action": "an_gang",
				"executed": an_gang_ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			_record_ai_decision_trace_event("turn_action_executed", {
				"seat": seat,
				"action": "an_gang",
				"executed": an_gang_ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			return an_gang_ok
		"add_gang":
			_record_ai_metric("add_gang_attempts")
			_record_hell_decision_snapshot(decision, "add_gang")
			var add_gang_ok := _start_add_gang(seat, decision.get("gang_option", {}))
			_record_ai_analysis_event("turn_action_executed", {
				"seat": seat,
				"action": "add_gang",
				"executed": add_gang_ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			_record_ai_decision_trace_event("turn_action_executed", {
				"seat": seat,
				"action": "add_gang",
				"executed": add_gang_ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			return add_gang_ok
		"discard":
			var requested_tile_id := int(decision.get("tile_id", -1))
			var tile_id := _resolve_legal_ai_discard_tile_id(seat, requested_tile_id)
			if tile_id == -1:
				_record_ai_chain_debug("turn_execute_discard_blocked seat=%d requested_tile_id=%d msg=%s" % [
					seat,
					requested_tile_id,
					debug_last_message,
				])
				_record_ai_analysis_event("turn_action_executed", {
					"seat": seat,
					"action": "discard",
					"tile_id": requested_tile_id,
					"executed": false,
					"decision": decision.duplicate(true),
					"debug_last_message": debug_last_message,
				})
				_record_ai_decision_trace_event("turn_action_executed", {
					"seat": seat,
					"action": "discard",
					"tile_id": requested_tile_id,
					"executed": false,
					"decision": decision.duplicate(true),
					"debug_last_message": debug_last_message,
				})
				return false
			var tile_type := _sichuan_tile_type(_tile_by_id_in_hand(seat, tile_id))
			_record_hell_decision_snapshot(decision, "discard", tile_type)
			active_ai_discard_decision = decision.duplicate(true)
			var ok := _discard_tile_internal(seat, tile_id)
			active_ai_discard_decision.clear()
			_record_ai_chain_debug("turn_execute_discard seat=%d tile_id=%d ok=%s msg=%s" % [
				seat,
				tile_id,
				str(ok),
				debug_last_message,
			])
			_record_ai_analysis_event("turn_action_executed", {
				"seat": seat,
				"action": "discard",
				"tile_id": tile_id,
				"tile_type": tile_type,
				"executed": ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			_record_ai_decision_trace_event("turn_action_executed", {
				"seat": seat,
				"action": "discard",
				"tile_id": tile_id,
				"tile_type": tile_type,
				"executed": ok,
				"decision": decision.duplicate(true),
				"debug_last_message": debug_last_message,
			})
			return ok
	_record_ai_chain_debug("turn_execute_unknown_action decision=%s" % JSON.stringify(decision).left(500))
	_record_ai_analysis_event("turn_action_executed", {
		"seat": seat,
		"action": str(decision.get("action", "")),
		"executed": false,
		"decision": decision.duplicate(true),
		"debug_last_message": "unknown_action",
	})
	_record_ai_decision_trace_event("turn_action_executed", {
		"seat": seat,
		"action": str(decision.get("action", "")),
		"executed": false,
		"decision": decision.duplicate(true),
		"debug_last_message": "unknown_action",
	})
	return false


func _resolve_legal_ai_discard_tile_id(seat: int, requested_tile_id: int) -> int:
	if seat < 0 or seat >= players.size():
		return -1
	return requested_tile_id if not _tile_by_id_in_hand(seat, requested_tile_id).is_empty() else -1


func run_ai_reaction() -> bool:
	if current_phase != RoundPhase.REACTION:
		return false

	var prepared: Dictionary = _get_or_prepare_ai_reaction_decision()
	if prepared.is_empty():
		return false

	var candidate: Dictionary = prepared.get("candidate", {})
	var decision: Dictionary = prepared.get("decision", {})
	var seat: int = int(prepared.get("seat", -1))
	if candidate.is_empty() or decision.is_empty() or seat < 0 or seat >= players.size():
		pending_ai_reaction_decision.clear()
		_clear_pending_ai_reaction_request()
		return false
	pending_ai_reaction_decision.clear()
	_clear_pending_ai_reaction_request()
	var requested_action := str(decision.get("action", "pass")).strip_edges().to_lower()
	var resolved_action := _resolve_ai_reaction_action(seat, candidate, requested_action)
	_record_ai_metric("reaction_total")
	_record_ai_metric("reaction_" + resolved_action)
	_record_ai_reaction_review(seat, candidate, decision, requested_action, resolved_action)
	_record_hell_reaction_snapshot(seat, candidate, decision, requested_action, resolved_action)
	var executed := false
	if resolved_action == "hu":
		executed = _execute_hu_on_discard(seat)
	elif resolved_action == "gang":
		executed = _execute_gang(seat)
	elif resolved_action == "peng":
		executed = _execute_peng(seat)
	else:
		var pass_executed := _pass_ai_reaction(seat)
		_record_ai_analysis_event("reaction_action_executed", {
			"seat": seat,
			"candidate": candidate.duplicate(true),
			"decision": decision.duplicate(true),
			"requested_action": requested_action,
			"resolved_action": resolved_action,
			"reaction_diagnostic": _build_reaction_diagnostic_profile(seat, candidate, decision, requested_action, resolved_action),
			"executed": pass_executed,
			"discard_context": current_discard_context.duplicate(true),
		})
		_record_ai_decision_trace_event("reaction_action_executed", {
			"seat": seat,
			"candidate": candidate.duplicate(true),
			"decision": decision.duplicate(true),
			"requested_action": requested_action,
			"resolved_action": resolved_action,
			"reaction_diagnostic": _build_reaction_diagnostic_profile(seat, candidate, decision, requested_action, resolved_action),
			"executed": pass_executed,
			"discard_context": current_discard_context.duplicate(true),
		})
		return pass_executed
	if executed:
		_record_ai_analysis_event("reaction_action_executed", {
			"seat": seat,
			"candidate": candidate.duplicate(true),
			"decision": decision.duplicate(true),
			"requested_action": requested_action,
			"resolved_action": resolved_action,
			"reaction_diagnostic": _build_reaction_diagnostic_profile(seat, candidate, decision, requested_action, resolved_action),
			"executed": true,
			"discard_context": current_discard_context.duplicate(true),
		})
		_record_ai_decision_trace_event("reaction_action_executed", {
			"seat": seat,
			"candidate": candidate.duplicate(true),
			"decision": decision.duplicate(true),
			"requested_action": requested_action,
			"resolved_action": resolved_action,
			"reaction_diagnostic": _build_reaction_diagnostic_profile(seat, candidate, decision, requested_action, resolved_action),
			"executed": true,
			"discard_context": current_discard_context.duplicate(true),
		})
		return true
	debug_last_message = "AI %s 响应 %s 执行失败，严格模式下保留现场并停止自动动作。" % [
		_seat_display_name(seat),
		{"hu": "胡", "gang": "杠", "peng": "碰"}.get(resolved_action, resolved_action),
	]
	_record_ai_analysis_event("reaction_action_executed", {
		"seat": seat,
		"candidate": candidate.duplicate(true),
		"decision": decision.duplicate(true),
		"requested_action": requested_action,
		"resolved_action": resolved_action,
		"reaction_diagnostic": _build_reaction_diagnostic_profile(seat, candidate, decision, requested_action, resolved_action),
		"executed": false,
		"discard_context": current_discard_context.duplicate(true),
		"debug_last_message": debug_last_message,
	})
	_record_ai_decision_trace_event("reaction_action_executed", {
		"seat": seat,
		"candidate": candidate.duplicate(true),
		"decision": decision.duplicate(true),
		"requested_action": requested_action,
		"resolved_action": resolved_action,
		"reaction_diagnostic": _build_reaction_diagnostic_profile(seat, candidate, decision, requested_action, resolved_action),
		"executed": false,
		"discard_context": current_discard_context.duplicate(true),
		"debug_last_message": debug_last_message,
	})
	return false


func _get_or_prepare_ai_reaction_decision() -> Dictionary:
	if _is_pending_ai_reaction_decision_valid():
		return pending_ai_reaction_decision.duplicate(true)
	if _is_pending_ai_reaction_request_valid():
		return {}
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"):
		if not _has_native_csharp_runtime():
			debug_last_message = "C# AI 运行时未就绪，严格模式下暂停 AI 响应。"
			return {}
	if _start_ai_reaction_background_request():
		_pump_ai_background_requests()
		if _is_pending_ai_reaction_decision_valid():
			return pending_ai_reaction_decision.duplicate(true)
		return {}
	debug_last_message = "C# AI 响应请求启动失败，严格模式下不执行本地碰杠替代。"
	return {}


func _is_pending_ai_reaction_decision_valid() -> bool:
	if pending_ai_reaction_decision.is_empty():
		return false
	var seat := int(pending_ai_reaction_decision.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return false
	var state_signature := str(pending_ai_reaction_decision.get("state_signature", ""))
	if state_signature != "" and state_signature != _ai_reaction_state_signature(seat):
		return false
	var tile: Dictionary = current_discard_context.get("tile", {})
	return int(pending_ai_reaction_decision.get("round_index", -1)) == round_index \
		and int(pending_ai_reaction_decision.get("phase", -1)) == int(current_phase) \
		and int(pending_ai_reaction_decision.get("source_seat", -1)) == int(current_discard_context.get("source_seat", -1)) \
		and int(pending_ai_reaction_decision.get("tile_id", -1)) == int(tile.get("id", -1)) \
		and int(pending_ai_reaction_decision.get("pending_count", -1)) == pending_reactions.size()


func _is_pending_ai_reaction_request_valid() -> bool:
	if pending_ai_reaction_request_id <= 0 or pending_ai_reaction_request_meta.is_empty():
		return false
	var tile: Dictionary = current_discard_context.get("tile", {})
	var seat := int(pending_ai_reaction_request_meta.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return false
	var state_signature := str(pending_ai_reaction_request_meta.get("state_signature", ""))
	if state_signature != "" and state_signature != _ai_reaction_state_signature(seat):
		return false
	var state_matches := int(pending_ai_reaction_request_meta.get("round_index", -1)) == round_index \
		and int(pending_ai_reaction_request_meta.get("phase", -1)) == int(current_phase) \
		and int(pending_ai_reaction_request_meta.get("source_seat", -1)) == int(current_discard_context.get("source_seat", -1)) \
		and int(pending_ai_reaction_request_meta.get("tile_id", -1)) == int(tile.get("id", -1)) \
		and int(pending_ai_reaction_request_meta.get("pending_count", -1)) == pending_reactions.size()
	if not state_matches:
		return false
	if _is_pending_ai_reaction_request_stale():
		debug_last_message = "C# AI 响应计算较慢，继续等待当前后台结果。"
		if not bool(pending_ai_reaction_request_meta.get("soft_timeout_logged", false)):
			_record_ai_chain_debug("reaction_request_slow_wait id=%d elapsed=%d meta=%s" % [
				pending_ai_reaction_request_id,
				_pending_ai_reaction_request_elapsed_ms(),
				JSON.stringify(pending_ai_reaction_request_meta).left(500),
			])
			pending_ai_reaction_request_meta["soft_timeout_logged"] = true
	return true


func _is_pending_ai_reaction_request_stale() -> bool:
	return _pending_ai_reaction_request_elapsed_ms() > AI_REACTION_SOFT_TIMEOUT_MS


func _pending_ai_reaction_request_elapsed_ms() -> int:
	var started_at_ms := int(pending_ai_reaction_request_meta.get("started_at_ms", 0))
	if started_at_ms <= 0:
		return 0
	return maxi(0, Time.get_ticks_msec() - started_at_ms)


func _build_ai_reaction_decision(force_lightweight: bool = false) -> Dictionary:
	if current_phase != RoundPhase.REACTION:
		return {}
	var candidate: Dictionary = _get_next_ai_reaction_candidate()
	if candidate.is_empty():
		return {}
	var seat: int = int(candidate.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return {}
	var allow_cheat: bool = int(players[seat].get("ai_level", int(ai_level))) == int(AILevel.CHEATING)
	var player_state := _build_player_state(seat)
	var table_state := _build_table_state()
	var decision: Dictionary = {}
	if ai_manager != null:
		if _is_hell_challenge_mode() and ai_manager.has_native_hell_challenge_reaction_runtime():
			decision = ai_manager.analyze_hell_challenge_reaction(candidate, player_state, table_state, current_discard_context, rules, _build_hell_challenge_payload())
		else:
			decision = ai_manager.analyze_reaction_lightweight(candidate, player_state, table_state, current_discard_context, rules, ai_tuning_config, hu_checker, allow_cheat) if force_lightweight else ai_manager.analyze_reaction(candidate, player_state, table_state, current_discard_context, rules, ai_tuning_config, hu_checker, allow_cheat)
	if decision.is_empty():
		debug_last_message = "C# AI 未返回有效响应结果，当前等待重试。"
		return {}
	var tile: Dictionary = current_discard_context.get("tile", {})
	return {
		"round_index": round_index,
		"phase": int(current_phase),
		"source_seat": int(current_discard_context.get("source_seat", -1)),
		"tile_id": int(tile.get("id", -1)),
		"pending_count": pending_reactions.size(),
		"seat": seat,
		"state_signature": _ai_reaction_state_signature(seat),
		"candidate": candidate.duplicate(true),
		"decision": decision.duplicate(true),
	}


func _start_ai_turn_background_request() -> bool:
	if not is_ai_turn_ready():
		return false
	if _has_native_csharp_runtime():
		var native_seat: int = current_turn_seat
		var native_player_state := _build_player_state(native_seat)
		var native_table_state := _build_table_state()
		var self_action := _build_ai_self_action_decision(native_seat, native_player_state, native_table_state)
		if not self_action.is_empty():
			var base := {
				"round_index": round_index,
				"seat": native_seat,
				"phase": int(current_phase),
				"wall_count": wall_count,
				"hand_count": int(players[native_seat].get("hand_count", 0)),
				"state_signature": _ai_turn_state_signature(native_seat),
			}
			for key in self_action.keys():
				base[key] = self_action[key]
			pending_ai_turn_decision = base
			_record_ai_chain_debug("turn_self_action_ready seat=%d action=%s" % [
				native_seat,
				str(self_action.get("action", "")),
			])
			_clear_pending_ai_turn_request()
			return true
	if _is_pending_ai_turn_request_valid():
		return true
	var seat: int = current_turn_seat
	var player_state := _build_player_state(seat)
	var table_state := _build_table_state()
	var allow_cheat: bool = int(players[seat].get("ai_level", int(ai_level))) == int(AILevel.CHEATING)
	_record_ai_chain_debug("turn_async_request_start seat=%d hand=%d wall=%d native=%s" % [
		seat,
		int(players[seat].get("hand_count", 0)),
		wall_count,
		str(_has_native_csharp_runtime()),
	])
	var request_id: int = 0 if ai_manager == null else ai_manager.start_turn_analysis_background(
		player_state,
		table_state,
		rules,
		ai_tuning_config,
		hu_checker,
		risk_analyzer,
		allow_cheat,
		_build_hell_challenge_payload() if _is_hell_challenge_mode() and ai_manager.has_native_hell_challenge_runtime() else {}
	)
	if request_id <= 0:
		_record_ai_chain_debug("turn_async_request_failed seat=%d" % seat)
		return false
	pending_ai_turn_request_id = request_id
	pending_ai_turn_request_meta = {
		"round_index": round_index,
		"seat": seat,
		"phase": int(current_phase),
		"wall_count": wall_count,
		"hand_count": int(players[seat].get("hand_count", 0)),
		"state_signature": _ai_turn_state_signature(seat),
		"started_at_ms": Time.get_ticks_msec(),
	}
	_record_ai_chain_debug("turn_async_request_queued id=%d seat=%d wall=%d" % [
		request_id,
		seat,
		wall_count,
	])
	return true


func _start_ai_reaction_background_request() -> bool:
	if current_phase != RoundPhase.REACTION:
		return false
	if _is_pending_ai_reaction_request_valid():
		return true
	var candidate: Dictionary = _get_next_ai_reaction_candidate()
	if candidate.is_empty():
		return false
	var seat: int = int(candidate.get("seat", -1))
	if seat < 0 or seat >= players.size():
		return false
	var allow_cheat: bool = int(players[seat].get("ai_level", int(ai_level))) == int(AILevel.CHEATING)
	var player_state := _build_player_state(seat)
	var table_state := _build_table_state()
	var tile: Dictionary = current_discard_context.get("tile", {})
	_record_ai_chain_debug("reaction_async_request_start seat=%d source=%d tile=%s pending=%d native=%s" % [
		seat,
		int(current_discard_context.get("source_seat", -1)),
		str(tile.get("display_name", tile.get("id", ""))),
		pending_reactions.size(),
		str(_has_native_csharp_runtime()),
	])
	var request_id: int = 0 if ai_manager == null else ai_manager.start_reaction_analysis_background(
		candidate,
		player_state,
		table_state,
		current_discard_context,
		rules,
		ai_tuning_config,
		hu_checker,
		allow_cheat,
		_build_hell_challenge_payload() if _is_hell_challenge_mode() and ai_manager.has_native_hell_challenge_reaction_runtime() else {}
	)
	if request_id <= 0:
		_record_ai_chain_debug("reaction_async_request_failed seat=%d" % seat)
		return false
	pending_ai_reaction_request_id = request_id
	pending_ai_reaction_request_meta = {
		"round_index": round_index,
		"phase": int(current_phase),
		"source_seat": int(current_discard_context.get("source_seat", -1)),
		"tile_id": int(tile.get("id", -1)),
		"pending_count": pending_reactions.size(),
		"seat": seat,
		"state_signature": _ai_reaction_state_signature(seat),
		"candidate": candidate.duplicate(true),
		"started_at_ms": Time.get_ticks_msec(),
	}
	_record_ai_chain_debug("reaction_async_request_queued id=%d seat=%d tile_id=%d pending=%d" % [
		request_id,
		seat,
		int(tile.get("id", -1)),
		pending_reactions.size(),
	])
	return true


func _discard_tile_internal(seat: int, tile_id: int) -> bool:
	if seat < 0 or seat >= players.size():
		return false
	if players[seat]["has_won"]:
		return false
	if seat == current_dealer_seat and players[seat]["ding_que"] == "":
		if not _lock_dealer_ding_que_from_first_discard(tile_id):
			return false

	var hand_tiles: Array = players[seat]["hand_tiles"]
	var remove_index := -1
	for index in range(hand_tiles.size()):
		if hand_tiles[index]["id"] == tile_id:
			remove_index = index
			break

	if remove_index == -1:
		return false

	var discarded_tile: Dictionary = hand_tiles[remove_index]
	var forced_discard_suit: String = _get_forced_discard_suit(players[seat])
	if forced_discard_suit != "" and str(discarded_tile.get("suit", "")) != forced_discard_suit:
		debug_last_message = "%s 需先打出缺门牌 %s。" % [_seat_display_name(seat), _suit_display_name(forced_discard_suit)]
		_emit_state_changed()
		return false

	hand_tiles.remove_at(remove_index)
	players[seat]["hand_tiles"] = hand_tiles
	players[seat]["hand_count"] = hand_tiles.size()
	players[seat]["discards"].append(discarded_tile)
	var discard_origin := "draw" if int(last_draw_tile.get("seat", -1)) == seat and int(last_draw_tile.get("tile", {}).get("id", -2)) == int(discarded_tile.get("id", -1)) else "hand"
	_append_ai_public_event("discard", seat, discarded_tile, seat, discard_origin)
	var discard_record := {
		"seat": seat,
		"tile": discarded_tile,
	}
	if not active_ai_discard_decision.is_empty() and int(active_ai_discard_decision.get("seat", -1)) == seat:
		discard_record["ai_decision"] = active_ai_discard_decision.duplicate(true)
		var ai_analysis: Dictionary = active_ai_discard_decision.get("analysis", {})
		if not ai_analysis.is_empty():
			discard_record["ai_analysis"] = ai_analysis.duplicate(true)
	discard_pile.append(discard_record)
	current_phase = RoundPhase.REACTION
	_prepare_reaction_context(seat, discarded_tile)
	if pending_reactions.is_empty():
		debug_last_message = "%s 打出 %s，无人可响应，轮到下一家。" % [
			_seat_display_name(seat),
			discarded_tile["display_name"],
		]
		_finalize_reaction_without_claim()
	else:
		debug_last_message = "%s 打出 %s。可响应：%s" % [
			_seat_display_name(seat),
			discarded_tile["display_name"],
			mahjong_judge.summarize_candidates(pending_reactions),
		]
	_emit_state_changed()
	return true


func _tile_key(tile: Dictionary) -> String:
	return "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


func _format_tile_name_list(tiles: Array) -> String:
	if tiles.is_empty():
		return "-"
	var parts: Array[String] = []
	for tile in tiles:
		parts.append(str(tile.get("display_name", "?")))
	return "/".join(parts)


func _build_rule_marks_for_player(player: Dictionary) -> Array:
	return []


func _apply_special_rule_marks_for_win(_seat: int, _win_type: String) -> void:
	# 四川规则基线不包含内江天和、地胡、海底等附加标记。
	return


func _should_mark_tian_he(seat: int, win_type: String) -> bool:
	if win_type != "self_draw" and win_type != "gang_self_draw":
		return false
	if seat != current_dealer_seat:
		return false
	if not discard_pile.is_empty():
		return false
	if not round_winners.is_empty():
		return false
	return str(last_turn_context.get("draw_reason", "")) == "opening_discard"


func _should_mark_di_hu(seat: int, win_type: String) -> bool:
	if seat < 0 or seat >= players.size():
		return false
	if win_type != "discard_win":
		return false
	if not round_winners.is_empty():
		return false
	if _should_mark_tian_he(seat, win_type):
		return false
	if seat == current_dealer_seat:
		return false
	var source_seat := int(current_discard_context.get("source_seat", -1))
	if source_seat != current_dealer_seat:
		return false
	if int(last_turn_context.get("seat", -1)) != current_dealer_seat:
		return false
	if str(last_turn_context.get("draw_reason", "")) != "opening_discard":
		return false
	for other_seat in range(players.size()):
		if other_seat == current_dealer_seat:
			continue
		if not Array(players[other_seat].get("discards", [])).is_empty():
			return false
	return true


func _should_mark_hai_di(win_type: String) -> bool:
	if win_type == "":
		return false
	return wall_count == 0


func _get_forced_discard_suit(player: Dictionary) -> String:
	if rules == null or not bool(rules.requires_ding_que_phase()):
		return ""
	var ding_que_suit: String = str(player.get("ding_que", ""))
	if ding_que_suit == "":
		return ""
	for tile in player.get("hand_tiles", []):
		if str(tile.get("suit", "")) == ding_que_suit:
			return ding_que_suit
	return ""


func _build_trainer_hint_for_seat(seat: int) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	var player: Dictionary = players[seat]
	var table_state := _build_table_state()
	var analysis: Dictionary = mahjong_judge.analyze_discard_options(
		player,
		table_state,
		rules,
		int(ai_level) == int(AILevel.CHEATING),
		true,
		ai_tuning_config
	)
	if analysis.is_empty():
		return {}
	analysis = _apply_ding_que_priority_to_discard_analysis(seat, analysis)
	var recommended: Dictionary = analysis.get("recommended", {})
	var can_add_gang_now: bool = seat == 0 and can_human_add_gang(seat)
	var can_an_gang_now: bool = seat == 0 and can_human_an_gang(seat)
	latest_trainer_hint = {
		"recommended": recommended.duplicate(true),
		"options": analysis.get("options", []).duplicate(true),
		"danger_tiles": analysis.get("danger_tiles", []).duplicate(true),
		"recommended_tile_id": int(recommended.get("tile", {}).get("id", -1)),
		"danger_tile_ids": _extract_trainer_tile_ids(analysis.get("danger_tiles", [])),
		"current_routes": analysis.get("current_routes", []).duplicate(true),
		"forced_discard_suit": analysis.get("forced_discard_suit", ""),
		"strategy_profile": analysis.get("strategy_profile", {}).duplicate(true),
		"situation_label": _resolve_trainer_situation_label(player, analysis.get("strategy_profile", {})),
		"can_add_gang": can_add_gang_now,
		"can_an_gang": can_an_gang_now,
		"can_self_hu": seat == 0 and can_human_self_hu(seat),
		"review_count": trainer_history.size(),
	}
	return latest_trainer_hint.duplicate(true)


func _resolve_trainer_situation_label(player: Dictionary, strategy_profile: Dictionary) -> String:
	var dingque_state: Dictionary = strategy_profile.get("dingque_state", {})
	var state_label := str(dingque_state.get("state_label", ""))
	if state_label != "":
		return state_label
	return "定缺均衡"


func _get_human_trainer_hint_snapshot() -> Dictionary:
	if not human_trainer_hint_enabled:
		latest_trainer_hint.clear()
		latest_trainer_hint_cache_key = ""
		_clear_pending_trainer_hint_request()
		return {}
	var seat: int = 0
	if seat < 0 or seat >= players.size():
		latest_trainer_hint.clear()
		latest_trainer_hint_cache_key = ""
		_clear_pending_trainer_hint_request()
		return {}
	var can_show_hint: bool = can_human_discard(seat) or can_human_add_gang(seat) or can_human_an_gang(seat) or can_human_self_hu(seat)
	if not can_show_hint:
		latest_trainer_hint.clear()
		latest_trainer_hint_cache_key = ""
		_clear_pending_trainer_hint_request()
		return {}
	var cache_key: String = _build_trainer_hint_cache_key(seat)
	if cache_key == latest_trainer_hint_cache_key and not latest_trainer_hint.is_empty():
		return latest_trainer_hint.duplicate(true)
	if pending_trainer_hint_request_id > 0 and pending_trainer_hint_request_cache_key == cache_key:
		var pending_snapshot := latest_trainer_hint.duplicate(true)
		if not pending_snapshot.is_empty():
			pending_snapshot["request_pending"] = true
			return pending_snapshot
		return {
			"request_pending": true,
			"request_id": pending_trainer_hint_request_id,
		}
	latest_trainer_hint_cache_key = cache_key
	if _start_human_trainer_hint_request(seat, cache_key):
		if not latest_trainer_hint.is_empty():
			var pending_snapshot := latest_trainer_hint.duplicate(true)
			pending_snapshot["request_pending"] = true
			return pending_snapshot
		return {
			"request_pending": true,
			"request_id": pending_trainer_hint_request_id,
		}
	return _build_trainer_hint_for_seat(seat)


func _build_trainer_hint_cache_key(seat: int) -> String:
	var player: Dictionary = players[seat]
	var hand_ids: PackedStringArray = []
	for tile in player.get("hand_tiles", []):
		hand_ids.append(str(int(tile.get("id", -1))))
	hand_ids.sort()
	return "%d|%d|%s|%s|%d|%d|%d|%d" % [
		int(current_phase),
		int(current_turn_seat),
		str(player.get("ding_que", "")),
		",".join(hand_ids),
		int(_get_last_draw_tile_id_for_seat(seat)),
		int(_get_recent_discard_tile_id()),
		int(can_human_add_gang(seat)),
		int(can_human_an_gang(seat)),
	]


func _start_human_trainer_hint_request(seat: int, cache_key: String) -> bool:
	if ai_manager == null or rules == null:
		return false
	var player_state := _build_player_state(seat)
	var table_state := _build_table_state()
	var allow_cheat := int(players[seat].get("ai_level", int(ai_level))) == int(AILevel.CHEATING)
	var request_id: int = ai_manager.start_turn_analysis_background(
		player_state,
		table_state,
		rules,
		ai_tuning_config,
		hu_checker,
		risk_analyzer,
		allow_cheat,
		{},
		false,
		true,
		true,
		false
	)
	if request_id <= 0:
		return false
	pending_trainer_hint_request_id = request_id
	pending_trainer_hint_request_cache_key = cache_key
	pending_trainer_hint_request_seat = seat
	return true


func _clear_pending_trainer_hint_request() -> void:
	pending_trainer_hint_request_id = 0
	pending_trainer_hint_request_cache_key = ""
	pending_trainer_hint_request_seat = -1


func _apply_trainer_hint_analysis(seat: int, analysis: Dictionary) -> bool:
	if seat < 0 or seat >= players.size() or analysis.is_empty():
		return false
	analysis = _apply_ding_que_priority_to_discard_analysis(seat, analysis)
	var player: Dictionary = players[seat]
	var recommended: Dictionary = analysis.get("recommended", {})
	var can_add_gang_now: bool = seat == 0 and can_human_add_gang(seat)
	var can_an_gang_now: bool = seat == 0 and can_human_an_gang(seat)
	latest_trainer_hint = {
		"recommended": recommended.duplicate(true),
		"options": analysis.get("options", []).duplicate(true),
		"danger_tiles": analysis.get("danger_tiles", []).duplicate(true),
		"recommended_tile_id": int(recommended.get("tile", {}).get("id", -1)),
		"danger_tile_ids": _extract_trainer_tile_ids(analysis.get("danger_tiles", [])),
		"current_routes": analysis.get("current_routes", []).duplicate(true),
		"forced_discard_suit": analysis.get("forced_discard_suit", ""),
		"strategy_profile": analysis.get("strategy_profile", {}).duplicate(true),
		"situation_label": _resolve_trainer_situation_label(player, analysis.get("strategy_profile", {})),
		"can_add_gang": can_add_gang_now,
		"can_an_gang": can_an_gang_now,
		"can_self_hu": seat == 0 and can_human_self_hu(seat),
		"review_count": trainer_history.size(),
	}
	return true


func _extract_trainer_tile_ids(items: Array) -> Array[int]:
	var ids: Array[int] = []
	for item in items:
		var tile: Dictionary = item.get("tile", {})
		var tile_id: int = int(tile.get("id", -1))
		if tile_id != -1:
			ids.append(tile_id)
	return ids


func _apply_ding_que_priority_to_discard_analysis(seat: int, analysis: Dictionary) -> Dictionary:
	if seat < 0 or seat >= players.size() or analysis.is_empty():
		return analysis
	var forced_suit := _get_forced_discard_suit(players[seat])
	if forced_suit == "":
		return analysis
	var current_recommended: Dictionary = analysis.get("recommended", {})
	var current_tile: Dictionary = current_recommended.get("tile", {})
	if str(current_tile.get("suit", "")) == forced_suit and _hand_contains_tile(seat, current_tile):
		var marked := analysis.duplicate(true)
		marked["forced_discard_suit"] = forced_suit
		marked["forced_ding_que_cleanup"] = true
		return marked
	var forced_option := _select_forced_ding_que_option(seat, analysis, forced_suit)
	if forced_option.is_empty():
		return analysis
	var forced_tile: Dictionary = forced_option.get("tile", {})
	if forced_tile.is_empty():
		return analysis
	var normalized := analysis.duplicate(true)
	var recommended := forced_option.duplicate(true)
	var tile_name := str(recommended.get("tile_name", forced_tile.get("display_name", "?")))
	var cleanup_text := "定缺优先：手上还有%s牌，必须先打缺门牌；清完缺门后再考虑其它推荐。" % _suit_display_name(forced_suit)
	recommended["tile"] = forced_tile.duplicate(true)
	recommended["tile_name"] = tile_name
	recommended["forced_ding_que_cleanup"] = true
	recommended["explanation_hint"] = cleanup_text
	recommended["reason"] = cleanup_text
	if not current_recommended.is_empty():
		recommended["original_recommended"] = current_recommended.duplicate(true)
	normalized["recommended"] = recommended
	normalized["forced_discard_suit"] = forced_suit
	normalized["forced_ding_que_cleanup"] = true
	normalized["action"] = "discard"
	return normalized


func _select_forced_ding_que_option(seat: int, analysis: Dictionary, forced_suit: String) -> Dictionary:
	var best_option: Dictionary = {}
	var best_score := -999999
	for option in analysis.get("options", []):
		var option_tile: Dictionary = option.get("tile", {})
		if str(option_tile.get("suit", "")) != forced_suit:
			continue
		var hand_tile := _find_matching_hand_tile(seat, option_tile)
		if hand_tile.is_empty():
			continue
		var score := int(option.get("score", option.get("total_score", option.get("shape_score", 0))))
		if best_option.is_empty() or score > best_score:
			best_score = score
			best_option = option.duplicate(true)
			best_option["tile"] = hand_tile.duplicate(true)
	if not best_option.is_empty():
		return best_option
	var forced_tile := _first_hand_tile_by_suit(seat, forced_suit)
	if forced_tile.is_empty():
		return {}
	return {
		"tile": forced_tile.duplicate(true),
		"tile_name": str(forced_tile.get("display_name", "?")),
		"score": 0,
		"risk": 0,
	}


func _hand_contains_tile(seat: int, tile: Dictionary) -> bool:
	return not _find_matching_hand_tile(seat, tile).is_empty()


func _find_matching_hand_tile(seat: int, tile: Dictionary) -> Dictionary:
	if seat < 0 or seat >= players.size() or tile.is_empty():
		return {}
	var hand_tiles: Array = players[seat].get("hand_tiles", [])
	var tile_id := int(tile.get("id", -1))
	if tile_id != -1:
		for hand_tile in hand_tiles:
			if int(hand_tile.get("id", -1)) == tile_id:
				return hand_tile.duplicate(true)
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", -1))
	if suit == "" or rank <= 0:
		return {}
	for hand_tile in hand_tiles:
		if str(hand_tile.get("suit", "")) == suit and int(hand_tile.get("rank", -1)) == rank:
			return hand_tile.duplicate(true)
	return {}


func _first_hand_tile_by_suit(seat: int, suit: String) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	for tile in players[seat].get("hand_tiles", []):
		if str(tile.get("suit", "")) == suit:
			return tile.duplicate(true)
	return {}


func _record_human_discard_review(discarded_tile: Dictionary, trainer_context: Dictionary) -> void:
	if trainer_context.is_empty():
		return
	var options: Array = trainer_context.get("options", [])
	if options.is_empty():
		return
	var chosen_option: Dictionary = {}
	var best_option: Dictionary = options[0]
	for option in options:
		var tile: Dictionary = option.get("tile", {})
		if str(tile.get("suit", "")) == str(discarded_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(discarded_tile.get("rank", 0)):
			chosen_option = option
			break
	if chosen_option.is_empty():
		return

	var severity := maxi(0, int(best_option.get("score", 0)) - int(chosen_option.get("score", 0)))
	severity += int(chosen_option.get("risk", 0))
	severity += int(chosen_option.get("route_loss", []).size()) * 12
	if bool(trainer_context.get("can_add_gang", false)) or bool(trainer_context.get("can_an_gang", false)):
		severity += 18

	var reasons: Array[String] = []
	if discarded_tile.get("display_name", "") != best_option.get("tile_name", ""):
		reasons.append("更优出牌应为 %s" % str(best_option.get("tile_name", "?")))
	if int(chosen_option.get("risk", 0)) >= 35:
		reasons.append("该张防守危险度为%s" % str(chosen_option.get("risk_label", "中危")))
	if not chosen_option.get("route_loss", []).is_empty():
		reasons.append("这一打会丢失 %s" % "/".join(chosen_option.get("route_loss", [])))
	if bool(trainer_context.get("can_add_gang", false)):
		reasons.append("此处存在补杠机会，值得复盘是否错过")
	elif bool(trainer_context.get("can_an_gang", false)):
		reasons.append("此处存在暗杠机会，值得复盘是否错过")
	if reasons.is_empty():
		reasons.append("这手整体处理较稳，没有明显失误")

	trainer_history.append(
		{
			"discard": discarded_tile.get("display_name", "?"),
			"best_discard": best_option.get("tile_name", "?"),
			"severity": severity,
			"reasons": reasons,
			"chosen_option": chosen_option.duplicate(true),
			"best_option": best_option.duplicate(true),
		}
	)


func _build_trainer_review_lines() -> Array[String]:
	var lines: Array[String] = []
	if trainer_history.is_empty():
		lines.append("训练复盘：本局尚未记录到明显失误。")
		return lines

	var sorted_history: Array = trainer_history.duplicate(true)
	sorted_history.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("severity", 0)) > int(b.get("severity", 0))
	)
	var limit := mini(3, sorted_history.size())
	lines.append("训练复盘：本局最值得回看的 %d 手" % limit)
	for index in range(limit):
		var item: Dictionary = sorted_history[index]
		lines.append("%d. 打出 %s | 更优 %s | %s" % [
			index + 1,
			str(item.get("discard", "?")),
			str(item.get("best_discard", "?")),
			"；".join(item.get("reasons", [])),
		])
	return lines


func _select_initial_dealer() -> int:
	return _rng.randi_range(0, 3)


func _create_initial_players(previous_players: Array = []) -> Array[Dictionary]:
	return [
		_create_player_state(0, "陈旭", false, _seed_score_for_seat(previous_players, 0)),
		_create_player_state(1, "舒燕", true, _seed_score_for_seat(previous_players, 1)),
		_create_player_state(2, "陈东", true, _seed_score_for_seat(previous_players, 2)),
		_create_player_state(3, "舒玲", true, _seed_score_for_seat(previous_players, 3)),
	]


func _create_player_state(seat: int, nickname: String, is_ai: bool, score: int = STARTING_SCORE) -> Dictionary:
	return {
		"seat": seat,
		"nickname": nickname,
		"score": score,
		"is_ai": is_ai,
		"ai_level": int(ai_level) if is_ai else -1,
		"ding_que": "",
		"rule_marks": [],
		"hand_tiles": [],
		"hand_count": 0,
		"melds": [],
		"discards": [],
		"has_won": false,
	}


func _seed_score_for_seat(previous_players: Array, seat: int) -> int:
	for player in previous_players:
		if int(player.get("seat", -1)) == seat:
			return int(player.get("score", STARTING_SCORE))
	return STARTING_SCORE


func _build_wall() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next_id: int = 1

	for suit in _active_suits():
		for rank in RANKS:
			for copy_index in range(COPIES_PER_TILE):
				result.append(
					{
						"id": next_id,
						"suit": suit,
						"rank": rank,
						"display_name": "%d%s" % [rank, _suit_display_name(suit)],
						"sort_key": _sort_key_for(suit, rank),
						"copy_index": copy_index,
					}
				)
				next_id += 1

	return result


func _active_suits() -> Array:
	if rules == null:
		return DEFAULT_SUITS.duplicate()
	return Array(rules.available_suits).duplicate()


func _shuffle_wall() -> void:
	for index in range(wall.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp: Dictionary = wall[index]
		wall[index] = wall[swap_index]
		wall[swap_index] = temp


func _deal_initial_hands() -> void:
	for seat in range(players.size()):
		var tile_count := 14 if seat == current_dealer_seat else 13
		var hand_tiles: Array[Dictionary] = []

		for _i in range(tile_count):
			hand_tiles.append(_draw_from_wall())

		_sort_tiles_in_place(hand_tiles)
		players[seat]["hand_tiles"] = hand_tiles
		players[seat]["hand_count"] = hand_tiles.size()


func _resolve_opening_roll() -> void:
	opening_roll_data = opening_roll_resolver.build_opening_roll(current_dealer_seat, _rng)
	opening_roll_data["round_index"] = round_index
	opening_roll_pending_completion = true


func _enter_ding_que_phase() -> void:
	if not rules.requires_ding_que_phase():
		debug_last_message = "当前规则无需定缺，直接进入庄家首打。"
		_begin_opening_discard_phase()
		_emit_state_changed()
		return
	current_phase = RoundPhase.DING_QUE
	_auto_select_ai_ding_que()
	_complete_ding_que_if_ready()
	_emit_state_changed()


func _auto_select_ai_ding_que() -> void:
	if not rules.requires_ding_que_phase():
		return
	for player in players:
		if not player["is_ai"] or player["ding_que"] != "":
			continue
		if player["seat"] == current_dealer_seat and not _must_dealer_choose_now():
			continue
		var decision := _build_ai_ding_que_decision(player["hand_tiles"])
		var suit := str(decision.get("suit", ""))
		if suit == "" or not _active_suits().has(suit):
			debug_last_message = "C# AI 未返回有效定缺结果，暂停自动定缺。"
			continue
		player["ding_que"] = suit


func _build_ai_ding_que_decision(hand_tiles: Array) -> Dictionary:
	if ai_manager != null and ai_manager.has_method("analyze_ding_que"):
		var decision: Dictionary = ai_manager.analyze_ding_que(hand_tiles, _active_suits())
		if not decision.is_empty():
			return decision
	return {}


func _complete_ding_que_if_ready() -> void:
	if not rules.requires_ding_que_phase():
		_begin_opening_discard_phase()
		return
	if not ding_que_resolver.can_finish_opening_ding_que(players, current_dealer_seat):
		return

	if _is_dealer_ding_que_deferred():
		debug_last_message = "Non-dealers finished ding que. Dealer seat %d will lock ding que on first discard and discard first with 14 tiles." % current_turn_seat
	else:
		debug_last_message = "All required ding que choices are done. Dealer seat %d will discard first." % current_turn_seat
	_begin_opening_discard_phase()
	_emit_state_changed()


func _advance_turn_after_discard() -> void:
	var next_seat := _find_next_active_seat_after(current_turn_seat)
	if next_seat == -1:
		_enter_settlement_due_to_battle_end()
		return
	current_turn_seat = next_seat
	_begin_turn()


func _begin_opening_discard_phase() -> void:
	if _should_enter_battle_end_settlement():
		_enter_settlement_due_to_battle_end()
		return
	var seat: int = current_turn_seat
	if seat < 0 or seat >= players.size() or players[seat]["has_won"]:
		var next_seat := _find_next_active_seat_after(seat)
		if next_seat == -1:
			_enter_settlement_due_to_battle_end()
			return
		current_turn_seat = next_seat
		seat = current_turn_seat
	last_draw_tile = {}
	last_turn_context = {
		"seat": seat,
		"draw_reason": "opening_discard",
	}
	self_hu_pass_locks.erase(str(seat))
	current_phase = RoundPhase.DISCARD
	debug_last_message = "%s 进入庄家首打。" % _seat_display_name(seat)
	_emit_state_changed()


func _begin_turn() -> void:
	_clear_pending_ai_turn_request()
	if _should_enter_battle_end_settlement():
		_enter_settlement_due_to_battle_end()
		return
	if wall.is_empty():
		_enter_settlement_due_to_draw()
		return

	var seat: int = current_turn_seat
	if seat < 0 or seat >= players.size() or players[seat]["has_won"]:
		var next_seat := _find_next_active_seat_after(seat)
		if next_seat == -1:
			_enter_settlement_due_to_battle_end()
			return
		current_turn_seat = next_seat
		seat = current_turn_seat
	var draw_tile: Dictionary = _draw_from_wall()
	if draw_tile.is_empty():
		_enter_settlement_due_to_draw()
		return
	_clear_shun_he_lock_for_seat(seat)

	var hand_tiles: Array = players[seat]["hand_tiles"]
	hand_tiles.append(draw_tile)
	_sort_tiles_in_place(hand_tiles)
	players[seat]["hand_tiles"] = hand_tiles
	players[seat]["hand_count"] = hand_tiles.size()
	last_draw_tile = {
		"seat": seat,
		"tile": draw_tile,
	}
	_append_ai_public_event("draw", seat, draw_tile, seat, "draw")
	last_turn_context = {
		"seat": seat,
		"draw_reason": _consume_next_draw_reason(),
	}
	self_hu_pass_locks.erase(str(seat))
	current_phase = RoundPhase.DISCARD
	var draw_reason_text := "补牌" if last_turn_context["draw_reason"] == "gang_draw" else "摸牌"
	if _can_seat_self_hu_now(seat):
		debug_last_message = "%s 摸到 %s，可直接自摸。" % [
			_seat_display_name(seat),
			draw_tile["display_name"],
		]
	else:
		debug_last_message = "%s %s %s，等待出牌。" % [
			_seat_display_name(seat),
			draw_reason_text,
			draw_tile["display_name"],
		]
	if bool(players[seat].get("is_ai", false)):
		_start_ai_turn_background_request()


func _enter_settlement_due_to_draw() -> void:
	current_phase = RoundPhase.SETTLEMENT
	settlement_data["end_reason"] = "draw_wall_empty"
	_build_draw_settlement_assessment()
	_rebuild_settlement_summary()
	debug_last_message = "牌墙摸完，已进入流局查叫/退税结算。"


func _enter_settlement_due_to_battle_end() -> void:
	current_phase = RoundPhase.SETTLEMENT
	last_draw_tile = {}
	_clear_reaction_context()
	settlement_data["end_reason"] = "battle_end"
	_build_draw_settlement_assessment()
	_rebuild_settlement_summary()
	debug_last_message = "血战终局，已进入结算。赢家：%s" % [_format_winner_list()]


func _draw_from_wall() -> Dictionary:
	if wall.is_empty():
		push_error("Attempted to draw from an empty wall.")
		return {}

	var tile: Dictionary = wall.pop_back()
	wall_count = wall.size()
	return tile


func _sort_tiles_in_place(tiles: Array) -> void:
	tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["sort_key"] == b["sort_key"]:
			return a["id"] < b["id"]
		return a["sort_key"] < b["sort_key"]
	)


func _sort_key_for(suit: String, rank: int) -> int:
	var suit_index := _active_suits().find(suit)
	return suit_index * 100 + rank


func _suit_display_name(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return "?"


func _get_recent_discard_display() -> String:
	if discard_pile.is_empty():
		return "-"
	var recent: Dictionary = discard_pile[discard_pile.size() - 1]
	return "%s：%s" % [_seat_display_name(int(recent["seat"])), recent["tile"]["display_name"]]


func _get_recent_draw_display() -> String:
	if last_draw_tile.is_empty():
		return "-"
	return "%s：%s" % [_seat_display_name(int(last_draw_tile["seat"])), last_draw_tile["tile"]["display_name"]]


func _get_recent_draw_seat() -> int:
	if last_draw_tile.is_empty():
		return -1
	return int(last_draw_tile.get("seat", -1))


func _get_recent_discard_tile_id() -> int:
	if discard_pile.is_empty():
		return -1
	var recent: Dictionary = discard_pile[discard_pile.size() - 1]
	return int(recent.get("tile", {}).get("id", -1))


func _get_last_draw_tile_id_for_seat(seat: int) -> int:
	if last_draw_tile.is_empty():
		return -1
	if last_draw_tile["seat"] != seat:
		return -1
	return last_draw_tile["tile"]["id"]


func _must_dealer_choose_now() -> bool:
	if current_dealer_seat < 0 or current_dealer_seat >= players.size():
		return false
	return ding_que_resolver.must_choose_before_first_discard(players[current_dealer_seat], current_dealer_seat)


func _is_dealer_ding_que_deferred() -> bool:
	if current_phase != RoundPhase.DING_QUE:
		return false
	if current_dealer_seat < 0 or current_dealer_seat >= players.size():
		return false
	return players[current_dealer_seat]["ding_que"] == "" and not _must_dealer_choose_now()


func _lock_dealer_ding_que_from_first_discard(tile_id: int) -> bool:
	var hand_tiles: Array = players[current_dealer_seat]["hand_tiles"]
	for tile in hand_tiles:
		if tile["id"] == tile_id:
			players[current_dealer_seat]["ding_que"] = tile["suit"]
			return true
	return false


func _emit_state_changed() -> void:
	_pump_ai_background_requests()
	state_changed.emit(get_debug_snapshot())


func _record_ai_chain_debug(message: String) -> void:
	if not _is_ai_chain_debug_enabled():
		return
	var line := "%d R%d P%s T%s %s" % [
		Time.get_ticks_msec(),
		round_index,
		str(current_phase),
		str(current_turn_seat),
		message,
	]
	ai_chain_debug_history.append(line)
	while ai_chain_debug_history.size() > 80:
		ai_chain_debug_history.pop_front()
	var log_path := "user://ai_chain_debug.log"
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


func export_diagnostic_package(copy_to_downloads: bool = true) -> Dictionary:
	if not _is_diagnostic_export_enabled():
		return {
			"ok": false,
			"error": "diagnostic_export_disabled",
		}
	_record_ai_chain_debug("diagnostic_export_requested")
	var file_name := "sichuan_diagnostic_%s_r%03d.json" % [_hell_timestamp_slug(), round_index]
	var internal_path := "%s/%s" % [DIAGNOSTIC_EXPORT_DIR, file_name]
	var package := _build_diagnostic_export_package(internal_path, file_name)
	if not _write_json_file(internal_path, package):
		var write_error := FileAccess.get_open_error()
		debug_last_message = "诊断包导出失败：内部文件写入失败（%s）。" % str(write_error)
		_record_ai_chain_debug("diagnostic_export_failed path=%s err=%s" % [internal_path, str(write_error)])
		return {
			"ok": false,
			"error": "internal_write_failed",
			"error_code": write_error,
			"path": internal_path,
			"path_absolute": ProjectSettings.globalize_path(internal_path),
		}
	var download_copy := _copy_diagnostic_package_to_downloads(internal_path, file_name) if copy_to_downloads else {
		"ok": false,
		"error": "downloads_copy_disabled",
	}
	var result := {
		"ok": true,
		"path": internal_path,
		"path_absolute": ProjectSettings.globalize_path(internal_path),
		"file_name": file_name,
		"download_copy": download_copy,
	}
	if bool(download_copy.get("ok", false)):
		debug_last_message = "诊断包已导出：%s" % str(download_copy.get("path", internal_path))
	else:
		debug_last_message = "诊断包已导出到内部目录：%s；复制到下载目录失败：%s" % [
			ProjectSettings.globalize_path(internal_path),
			str(download_copy.get("error", "unknown")),
		]
	_record_ai_chain_debug("diagnostic_export_done internal=%s external_ok=%s" % [
		internal_path,
		str(download_copy.get("ok", false)),
	])
	return result


func _build_diagnostic_export_package(internal_path: String, file_name: String) -> Dictionary:
	return {
		"kind": "sichuan_diagnostic_export",
		"schema_version": 1,
		"created_at": Time.get_datetime_string_from_system(),
		"ticks_msec": Time.get_ticks_msec(),
		"app": {
			"name": str(ProjectSettings.get_setting("application/config/name", "")),
			"version": str(ProjectSettings.get_setting("application/config/version", "")),
			"package": str(ProjectSettings.get_setting("application/config/package_name", "")),
		},
		"runtime": {
			"os_name": OS.get_name(),
			"locale": OS.get_locale(),
			"model": OS.get_model_name(),
			"processor_count": OS.get_processor_count(),
			"is_android": OS.has_feature("android"),
			"is_debug_build": OS.is_debug_build(),
		},
		"export": {
			"file_name": file_name,
			"internal_path": internal_path,
			"internal_path_absolute": ProjectSettings.globalize_path(internal_path),
			"downloads_subdir": DIAGNOSTIC_DOWNLOAD_SUBDIR,
		},
		"snapshot": _compact_diagnostic_value(get_debug_snapshot()),
		"ai_chain_debug_history": ai_chain_debug_history.duplicate(),
		"text_files": _collect_diagnostic_text_files([
			"user://ai_chain_debug.log",
			"user://ui_prefs.cfg",
		]),
		"training_files": {
			"ai_analysis": _collect_diagnostic_dir_text_files(AI_ANALYSIS_DIR, DIAGNOSTIC_MAX_DIR_TEXT_FILES),
			"hell_training": _collect_diagnostic_dir_text_files(HELL_TRAINING_DIR, DIAGNOSTIC_MAX_DIR_TEXT_FILES),
			"hell_marked_cases": _collect_diagnostic_dir_text_files(HELL_MARKED_CASE_DIR, DIAGNOSTIC_MAX_DIR_TEXT_FILES),
		},
	}


func _copy_diagnostic_package_to_downloads(internal_path: String, file_name: String) -> Dictionary:
	var downloads_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS, true)
	if downloads_dir.is_empty():
		return {"ok": false, "error": "downloads_dir_unavailable"}
	var export_dir := downloads_dir.path_join(DIAGNOSTIC_DOWNLOAD_SUBDIR)
	var dir_err := DirAccess.make_dir_recursive_absolute(export_dir)
	if dir_err != OK:
		return {
			"ok": false,
			"error": "downloads_dir_create_failed",
			"error_code": dir_err,
			"path": export_dir,
		}
	var text := FileAccess.get_file_as_string(internal_path)
	if text.is_empty():
		return {"ok": false, "error": "internal_package_empty", "path": internal_path}
	var external_path := export_dir.path_join(file_name)
	var file := FileAccess.open(external_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "downloads_write_failed",
			"error_code": FileAccess.get_open_error(),
			"path": external_path,
		}
	file.store_string(text)
	file.close()
	return {
		"ok": true,
		"path": external_path,
		"downloads_dir": export_dir,
	}


func _collect_diagnostic_text_files(paths: Array) -> Dictionary:
	var result := {}
	for item in paths:
		var path := str(item)
		result[path] = _read_diagnostic_text_file(path)
	return result


func _collect_diagnostic_dir_text_files(root_path: String, max_files: int) -> Dictionary:
	var result := {
		"root": root_path,
		"root_absolute": ProjectSettings.globalize_path(root_path),
		"files": {},
		"truncated": false,
	}
	var paths: Array[String] = []
	_collect_diagnostic_dir_paths(root_path, paths, max_files)
	if paths.size() > max_files:
		result["truncated"] = true
		paths = paths.slice(0, max_files)
	for path in paths:
		result["files"][path] = _read_diagnostic_text_file(path)
	return result


func _collect_diagnostic_dir_paths(path: String, paths: Array[String], max_files: int) -> void:
	if paths.size() > max_files:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path := path.path_join(entry)
		if dir.current_is_dir():
			_collect_diagnostic_dir_paths(child_path, paths, max_files)
		elif entry.ends_with(".json") or entry.ends_with(".jsonl") or entry.ends_with(".csv") or entry.ends_with(".md") or entry.ends_with(".log"):
			paths.append(child_path)
			if paths.size() > max_files:
				break
	dir.list_dir_end()


func _read_diagnostic_text_file(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {
			"exists": false,
			"path": path,
			"path_absolute": ProjectSettings.globalize_path(path),
		}
	var text := FileAccess.get_file_as_string(path)
	var truncated := text.length() > DIAGNOSTIC_MAX_TEXT_FILE_CHARS
	if truncated:
		text = text.right(DIAGNOSTIC_MAX_TEXT_FILE_CHARS)
	return {
		"exists": true,
		"path": path,
		"path_absolute": ProjectSettings.globalize_path(path),
		"char_count": text.length(),
		"truncated_from_start": truncated,
		"content": text,
	}


func _compact_diagnostic_value(value, depth: int = 0):
	if depth >= DIAGNOSTIC_MAX_DEPTH:
		return _compact_diagnostic_leaf(value)
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var output := {}
			var count := 0
			for key in source.keys():
				if count >= DIAGNOSTIC_MAX_DICT_KEYS:
					output["_truncated_keys"] = maxi(0, source.size() - count)
					break
				output[str(key)] = _compact_diagnostic_value(source[key], depth + 1)
				count += 1
			return output
		TYPE_ARRAY:
			var source_array: Array = value
			var output_array := []
			var limit := mini(source_array.size(), DIAGNOSTIC_MAX_ARRAY_ITEMS)
			for index in range(limit):
				output_array.append(_compact_diagnostic_value(source_array[index], depth + 1))
			if source_array.size() > limit:
				output_array.append({"_truncated_items": source_array.size() - limit})
			return output_array
		TYPE_STRING:
			var text := str(value)
			if text.length() > DIAGNOSTIC_MAX_STRING_LENGTH:
				return text.left(DIAGNOSTIC_MAX_STRING_LENGTH) + "...<truncated>"
			return text
		_:
			return value


func _compact_diagnostic_leaf(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			return {"_truncated_dictionary_keys": dictionary.size()}
		TYPE_ARRAY:
			var array: Array = value
			return {"_truncated_array_items": array.size()}
		TYPE_STRING:
			var text := str(value)
			if text.length() > DIAGNOSTIC_MAX_STRING_LENGTH:
				return text.left(DIAGNOSTIC_MAX_STRING_LENGTH) + "...<truncated>"
			return text
		_:
			return value


func _pump_ai_background_requests() -> int:
	var delivered := 0 if ai_manager == null else int(ai_manager.pump_async_requests())
	if delivered > 0:
		_record_ai_chain_debug("ai_pump_delivered count=%d" % delivered)
	return delivered


func pump_ai_background_requests() -> int:
	return _pump_ai_background_requests()


func _clear_pending_ai_turn_request() -> void:
	pending_ai_turn_request_id = 0
	pending_ai_turn_request_meta.clear()


func _clear_pending_ai_reaction_request() -> void:
	pending_ai_reaction_request_id = 0
	pending_ai_reaction_request_meta.clear()


func _clear_pending_ai_async_state() -> void:
	_clear_pending_ai_turn_request()
	_clear_pending_ai_reaction_request()
	pending_ai_turn_decision.clear()
	pending_ai_reaction_decision.clear()


func _has_native_csharp_runtime() -> bool:
	_bind_native_csharp_runtime_if_available()
	return ai_manager != null and ai_manager.has_native_csharp_runtime()


func _bind_native_csharp_runtime_if_available() -> bool:
	if ai_manager == null:
		return false
	if ai_manager.has_native_csharp_runtime():
		return true
	if not is_inside_tree():
		return false
	var native_csharp_runtime := get_node_or_null("/root/SichuanCSharpRuntime")
	if native_csharp_runtime == null:
		return false
	ai_manager.set_native_csharp_runtime(native_csharp_runtime)
	if ai_learning_engine != null:
		ai_learning_engine.set_native_csharp_runtime(native_csharp_runtime)
	print("[GameState] bound native C# runtime ready=", ai_manager.has_native_csharp_runtime())
	return ai_manager.has_native_csharp_runtime()


func _on_ai_turn_analysis_ready(request_id: int, seat_index: int, analysis: Dictionary) -> void:
	if request_id == pending_trainer_hint_request_id:
		if seat_index == pending_trainer_hint_request_seat and human_trainer_hint_enabled:
			_apply_trainer_hint_analysis(seat_index, analysis)
		_clear_pending_trainer_hint_request()
		_emit_state_changed()
		return
	if request_id != pending_ai_turn_request_id:
		_record_ai_chain_debug("turn_async_ready_ignored id=%d pending=%d seat=%d" % [
			request_id,
			pending_ai_turn_request_id,
			seat_index,
		])
		return
	if not _is_pending_ai_turn_request_valid():
		_record_ai_chain_debug("turn_async_ready_invalid id=%d seat=%d" % [request_id, seat_index])
		_clear_pending_ai_turn_request()
		return
	analysis = _apply_ding_que_priority_to_discard_analysis(seat_index, analysis)
	_sync_latest_turn_snapshot_analysis(analysis)
	var selected_tile: Dictionary = _resolve_analysis_recommended_tile(seat_index, analysis)
	if selected_tile.is_empty():
		debug_last_message = "后台 C# AI 已返回，但推荐牌未成功映射到手牌，等待下一次计算。"
		_record_ai_chain_debug("turn_async_ready_unmapped id=%d seat=%d backend=%s" % [
			request_id,
			seat_index,
			str(analysis.get("backend", "")),
		])
		_clear_pending_ai_turn_request()
		_emit_state_changed()
		return
	var analysis_action := str(analysis.get("action", "")).strip_edges().to_lower()
	if analysis_action == "gang":
		var base := {
			"round_index": round_index,
			"seat": seat_index,
			"phase": int(current_phase),
			"wall_count": wall_count,
			"hand_count": int(players[seat_index].get("hand_count", 0)),
			"state_signature": str(pending_ai_turn_request_meta.get("state_signature", _ai_turn_state_signature(seat_index))),
		}
		var gang_decision := _build_ai_turn_gang_decision_from_analysis(base, seat_index, analysis)
		if gang_decision.is_empty():
			debug_last_message = "后台 C# AI 返回杠牌动作，但当前牌面未找到可执行杠选项。"
			_record_ai_chain_debug("turn_async_ready_gang_unmapped id=%d seat=%d analysis=%s" % [
				request_id,
				seat_index,
				JSON.stringify(analysis).left(900),
			])
			_clear_pending_ai_turn_request()
			_emit_state_changed()
			return
		pending_ai_turn_decision = gang_decision
		_record_ai_chain_debug("turn_async_ready_gang id=%d seat=%d action=%s subtype=%s" % [
			request_id,
			seat_index,
			str(gang_decision.get("action", "")),
			str(analysis.get("gang_subtype", "")),
		])
		_record_ai_analysis_event("turn_analysis_ready", {
			"request_id": request_id,
			"seat": seat_index,
			"decision": pending_ai_turn_decision.duplicate(true),
			"request_meta": pending_ai_turn_request_meta.duplicate(true),
			"turn_diagnostic": _build_turn_diagnostic_profile(seat_index, analysis, selected_tile, {}),
		})
		_record_ai_decision_trace_event("turn_analysis_ready", {
			"request_id": request_id,
			"seat": seat_index,
			"decision": pending_ai_turn_decision.duplicate(true),
			"request_meta": pending_ai_turn_request_meta.duplicate(true),
			"turn_diagnostic": _build_turn_diagnostic_profile(seat_index, analysis, selected_tile, {}),
		})
		_clear_pending_ai_turn_request()
		_emit_state_changed()
		return
	pending_ai_turn_decision = {
		"round_index": round_index,
		"seat": seat_index,
		"phase": int(current_phase),
		"wall_count": wall_count,
		"hand_count": int(players[seat_index].get("hand_count", 0)),
		"state_signature": str(pending_ai_turn_request_meta.get("state_signature", _ai_turn_state_signature(seat_index))),
		"action": "discard",
		"tile_id": int(selected_tile.get("id", -1)),
		"analysis": analysis.duplicate(true),
	}
	var hell_decision := _apply_hell_oracle_to_discard_decision(
		pending_ai_turn_decision,
		seat_index,
		_build_player_state(seat_index),
		_build_table_state(),
		analysis,
		selected_tile
	)
	pending_ai_turn_decision = hell_decision.get("decision", pending_ai_turn_decision)
	selected_tile = hell_decision.get("selected_tile", selected_tile)
	var hell_oracle: Dictionary = hell_decision.get("oracle", {})
	_record_ai_chain_debug("turn_async_ready id=%d seat=%d backend=%s tile=%s" % [
		request_id,
		seat_index,
		str(analysis.get("backend", "")),
		str(selected_tile.get("display_name", selected_tile.get("id", ""))),
	])
	_record_ai_analysis_event("turn_analysis_ready", {
		"request_id": request_id,
		"seat": seat_index,
		"decision": pending_ai_turn_decision.duplicate(true),
		"request_meta": pending_ai_turn_request_meta.duplicate(true),
		"turn_diagnostic": _build_turn_diagnostic_profile(seat_index, analysis, selected_tile, hell_oracle),
	})
	_record_ai_decision_trace_event("turn_analysis_ready", {
		"request_id": request_id,
		"seat": seat_index,
		"decision": pending_ai_turn_decision.duplicate(true),
		"request_meta": pending_ai_turn_request_meta.duplicate(true),
		"turn_diagnostic": _build_turn_diagnostic_profile(seat_index, analysis, selected_tile, hell_oracle),
	})
	_clear_pending_ai_turn_request()
	_emit_state_changed()


func _sync_latest_turn_snapshot_analysis(analysis: Dictionary) -> void:
	if ai_manager == null or analysis.is_empty():
		return
	var snapshot = ai_manager.get("latest_turn_snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var updated: Dictionary = snapshot.duplicate(true)
	updated["analysis"] = analysis.duplicate(true)
	ai_manager.set("latest_turn_snapshot", updated)


func _resolve_analysis_recommended_tile(seat: int, analysis: Dictionary) -> Dictionary:
	var selected_tile: Dictionary = analysis.get("recommended", {}).get("tile", {})
	if seat < 0 or seat >= players.size():
		return selected_tile
	var hand_tiles: Array = players[seat].get("hand_tiles", [])
	var selected_id := int(selected_tile.get("id", -1))
	if selected_id != -1:
		for hand_tile in hand_tiles:
			if int(hand_tile.get("id", -1)) == selected_id:
				return hand_tile.duplicate(true)
	var target_suit := str(selected_tile.get("suit", ""))
	var target_rank := int(selected_tile.get("rank", -1))
	if target_suit == "" or target_rank <= 0:
		return {}
	for hand_tile in hand_tiles:
		if str(hand_tile.get("suit", "")) == target_suit and int(hand_tile.get("rank", -1)) == target_rank:
			return hand_tile.duplicate(true)
	return {}


func _on_ai_reaction_analysis_ready(request_id: int, seat_index: int, analysis: Dictionary) -> void:
	if request_id != pending_ai_reaction_request_id:
		_record_ai_chain_debug("reaction_async_ready_ignored id=%d pending=%d seat=%d action=%s" % [
			request_id,
			pending_ai_reaction_request_id,
			seat_index,
			str(analysis.get("action", "")),
		])
		return
	if not _is_pending_ai_reaction_request_valid():
		_record_ai_chain_debug("reaction_async_ready_invalid id=%d seat=%d action=%s" % [
			request_id,
			seat_index,
			str(analysis.get("action", "")),
		])
		_clear_pending_ai_reaction_request()
		return
	var candidate: Dictionary = pending_ai_reaction_request_meta.get("candidate", {}).duplicate(true)
	var tile: Dictionary = current_discard_context.get("tile", {})
	pending_ai_reaction_decision = {
		"round_index": round_index,
		"phase": int(current_phase),
		"source_seat": int(current_discard_context.get("source_seat", -1)),
		"tile_id": int(tile.get("id", -1)),
		"pending_count": pending_reactions.size(),
		"seat": seat_index,
		"state_signature": str(pending_ai_reaction_request_meta.get("state_signature", _ai_reaction_state_signature(seat_index))),
		"candidate": candidate,
		"decision": analysis.duplicate(true),
	}
	_record_ai_chain_debug("reaction_async_ready id=%d seat=%d action=%s backend=%s" % [
		request_id,
		seat_index,
		str(analysis.get("action", "")),
		str(analysis.get("backend", "")),
	])
	_record_ai_analysis_event("reaction_analysis_ready", {
		"request_id": request_id,
		"seat": seat_index,
		"decision": pending_ai_reaction_decision.duplicate(true),
		"request_meta": pending_ai_reaction_request_meta.duplicate(true),
		"reaction_diagnostic": _build_reaction_diagnostic_profile(
			seat_index,
			candidate,
			analysis,
			str(analysis.get("action", "pass")),
			_resolve_ai_reaction_action(seat_index, candidate, str(analysis.get("action", "pass")).strip_edges().to_lower())
		),
	})
	_record_ai_decision_trace_event("reaction_analysis_ready", {
		"request_id": request_id,
		"seat": seat_index,
		"candidate": candidate.duplicate(true),
		"decision": pending_ai_reaction_decision.duplicate(true),
		"request_meta": pending_ai_reaction_request_meta.duplicate(true),
		"reaction_diagnostic": _build_reaction_diagnostic_profile(
			seat_index,
			candidate,
			analysis,
			str(analysis.get("action", "pass")),
			_resolve_ai_reaction_action(seat_index, candidate, str(analysis.get("action", "pass")).strip_edges().to_lower())
		),
	})
	_clear_pending_ai_reaction_request()
	_emit_state_changed()


func _prepare_reaction_context(source_seat: int, discarded_tile: Dictionary) -> void:
	pending_ai_turn_decision.clear()
	pending_ai_reaction_decision.clear()
	_clear_pending_ai_reaction_request()
	current_discard_context = {
		"source_seat": source_seat,
		"tile": discarded_tile.duplicate(true),
		"reaction_type": "discard",
		"allow_chi": rules.allow_chi,
		"winner_seats": [],
	}
	pending_reactions = mahjong_judge.build_reaction_candidates(_build_table_state(), current_discard_context, rules)
	_apply_shun_he_lock_filter()


func _clear_reaction_context() -> void:
	current_discard_context.clear()
	pending_reactions.clear()
	pending_ai_reaction_decision.clear()
	_clear_pending_ai_reaction_request()


func _record_reaction_pass_evidence(seat: int, candidate: Dictionary) -> void:
	var tile: Dictionary = current_discard_context.get("tile", {})
	if tile.is_empty():
		return
	reaction_pass_evidence.append({
		"round_index": round_index,
		"seat": seat,
		"tile": tile.duplicate(true),
		"can_hu": bool(candidate.get("can_hu", false)),
		"can_peng": bool(candidate.get("can_peng", false)),
		"can_gang": bool(candidate.get("can_gang", false)),
		"reaction_type": str(current_discard_context.get("reaction_type", "discard")),
	})
	_append_ai_public_event("pass", seat, tile, int(current_discard_context.get("source_seat", -1)), "unknown", candidate)
	while reaction_pass_evidence.size() > 96:
		reaction_pass_evidence.remove_at(0)


func _append_ai_public_event(event_type: String, seat: int, tile: Dictionary = {}, source_seat: int = -1, origin: String = "unknown", legal: Dictionary = {}) -> void:
	ai_public_event_version += 1
	ai_public_events.append({
		"eventIndex": ai_public_event_version,
		"turnIndex": discard_pile.size(),
		"seat": seat,
		"type": event_type,
		"tile": tile.duplicate(true),
		"origin": origin,
		"sourceSeat": source_seat,
		"wallCountAfter": wall_count,
		"canHu": bool(legal.get("can_hu", false)),
		"canPeng": bool(legal.get("can_peng", false)),
		"canGang": bool(legal.get("can_gang", false)),
	})
	while ai_public_events.size() > 256:
		ai_public_events.remove_at(0)


func _apply_passed_hu_lock_if_needed(seat: int, candidate: Dictionary) -> void:
	if not candidate.get("can_hu", false):
		return
	if current_discard_context.is_empty():
		return
	var tile: Dictionary = current_discard_context.get("tile", {})
	if tile.is_empty():
		return
	var fan_detail: Dictionary = score_resolver.build_event_fan_detail(players[seat], tile, _resolve_discard_win_type(int(current_discard_context.get("source_seat", -1)), str(current_discard_context.get("reaction_type", "discard"))), rules)
	shun_he_locks[seat] = {
		"min_fan": int(fan_detail.get("capped_fan", 1)),
		"locked_fan": int(fan_detail.get("capped_fan", 1)),
		"lock_turn": discard_pile.size(),
		"unlock_on_own_draw": true,
		"tile": tile.duplicate(true),
	}


func _clear_shun_he_lock_for_seat(seat: int) -> void:
	if shun_he_locks.has(seat):
		shun_he_locks.erase(seat)


func _apply_shun_he_lock_filter() -> void:
	var filtered: Array[Dictionary] = []
	var source_seat: int = int(current_discard_context.get("source_seat", -1))
	var reaction_type: String = str(current_discard_context.get("reaction_type", "discard"))
	var tile: Dictionary = current_discard_context.get("tile", {})
	for candidate in pending_reactions:
		var seat: int = int(candidate.get("seat", -1))
		if candidate.get("can_hu", false) and shun_he_locks.has(seat):
			var lock_info: Dictionary = shun_he_locks[seat]
			var win_type := _resolve_discard_win_type(source_seat, reaction_type)
			var fan_detail: Dictionary = score_resolver.build_event_fan_detail(players[seat], tile, win_type, rules)
			if int(fan_detail.get("capped_fan", 1)) <= int(lock_info.get("min_fan", 0)):
				candidate["can_hu"] = false
		if candidate.get("can_hu", false) or candidate.get("can_gang", false) or candidate.get("can_peng", false):
			filtered.append(candidate)
	pending_reactions = filtered


func _find_add_gang_option(seat: int) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	var hand_tiles: Array = players[seat]["hand_tiles"]
	var melds: Array = players[seat]["melds"]
	for meld_index in range(melds.size()):
		var meld: Dictionary = melds[meld_index]
		if meld.get("type", "") != "peng":
			continue
		var meld_tiles: Array = meld.get("tiles", [])
		if meld_tiles.is_empty():
			continue
		var target_tile: Dictionary = meld_tiles[0]
		# Only the ding-que suit is blocked; other suits remain gang-eligible.
		if _is_ding_que_tile_for_seat(seat, target_tile):
			continue
		for hand_tile in hand_tiles:
			if hand_tile["suit"] == target_tile["suit"] and hand_tile["rank"] == target_tile["rank"]:
				if _is_ding_que_tile_for_seat(seat, hand_tile):
					continue
				return {
					"meld_index": meld_index,
					"tile": hand_tile.duplicate(true),
					"source_seat": int(meld.get("from_seat", seat)),
				}
	return {}


func _find_an_gang_option(seat: int) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	var hand_tiles: Array = players[seat]["hand_tiles"]
	var counts := {}
	for tile in hand_tiles:
		var key := "%s_%d" % [tile["suit"], tile["rank"]]
		if not counts.has(key):
			counts[key] = []
		counts[key].append(tile)
	for key in counts.keys():
		var tiles: Array = counts[key]
		if tiles.size() >= 4:
			# Only the ding-que suit is blocked; other suits remain gang-eligible.
			if _is_ding_que_tile_for_seat(seat, tiles[0]):
				continue
			return {
				"tiles": tiles.slice(0, 4),
			}
	return {}


func _tile_types_from_options(options: Array, tile_field: String) -> Array:
	var result: Array = []
	for option in options:
		var tile: Dictionary = {}
		if tile_field == "tiles":
			var tiles: Array = Array(option.get("tiles", []))
			if not tiles.is_empty():
				tile = tiles[0]
		else:
			tile = option.get(tile_field, {})
		var tile_type := _sichuan_tile_type(tile)
		if tile_type >= 0 and not result.has(tile_type):
			result.append(tile_type)
	return result


func _find_option_by_tile_type(options: Array, tile_type: int, tile_field: String) -> Dictionary:
	for option in options:
		var tile: Dictionary = {}
		if tile_field == "tiles":
			var tiles: Array = Array(option.get("tiles", []))
			if not tiles.is_empty():
				tile = tiles[0]
		else:
			tile = option.get(tile_field, {})
		if _sichuan_tile_type(tile) == tile_type:
			return option.duplicate(true)
	return {}


func _sichuan_tile_type(tile: Dictionary) -> int:
	if tile.is_empty():
		return -1
	var rank := int(tile.get("rank", 0))
	if rank < 1 or rank > 9:
		return -1
	match str(tile.get("suit", "")):
		"tiao":
			return rank - 1
		"tong":
			return 9 + rank - 1
		"wan":
			return 18 + rank - 1
		_:
			return -1


func _should_ai_add_gang(seat: int) -> bool:
	return not _choose_ai_add_gang_option(seat).is_empty()


func _should_ai_an_gang(seat: int) -> bool:
	return not _choose_ai_an_gang_option(seat).is_empty()


func _start_add_gang(seat: int, selected_option: Dictionary = {}) -> bool:
	var option: Dictionary = selected_option.duplicate(true) if not selected_option.is_empty() else ({} if bool(players[seat].get("is_ai", false)) else _find_add_gang_option(seat))
	if option.is_empty():
		return false

	var gang_tile: Dictionary = option["tile"]
	var meld_index: int = int(option["meld_index"])
	pending_qiang_gang_context = {
		"actor_seat": seat,
		"tile": gang_tile.duplicate(true),
		"meld_index": meld_index,
		"source_seat": int(option.get("source_seat", seat)),
		"placeholder_type": "add_gang_qiang_gang_hu",
		"status": "awaiting_reactions",
		"winner_seats": [],
	}
	current_phase = RoundPhase.REACTION
	current_discard_context = {
		"source_seat": seat,
		"tile": gang_tile.duplicate(true),
		"reaction_type": "qiang_gang_hu",
		"winner_seats": [],
	}
	pending_reactions = _build_qiang_gang_hu_candidates(seat, gang_tile)
	_register_qiang_gang_context(seat, gang_tile, "add_gang_qiang_gang_hu")

	if pending_reactions.is_empty():
		return _finalize_add_gang_without_qiang()

	debug_last_message = "%s 尝试补杠 %s。可抢杠：%s" % [
		_seat_display_name(seat),
		gang_tile["display_name"],
		mahjong_judge.summarize_candidates(pending_reactions),
	]
	_emit_state_changed()
	return true


func _execute_an_gang(seat: int, selected_option: Dictionary = {}) -> bool:
	var option: Dictionary = selected_option.duplicate(true) if not selected_option.is_empty() else ({} if bool(players[seat].get("is_ai", false)) else _find_an_gang_option(seat))
	if option.is_empty():
		return false

	var tiles: Array = option["tiles"]
	var first_tile: Dictionary = tiles[0]
	var removed_tiles: Array[Dictionary] = _remove_matching_tiles_from_hand(seat, first_tile, 4)
	if removed_tiles.size() != 4:
		return false

	players[seat]["melds"].append(
		{
			"type": "gang",
			"from_seat": seat,
			"tiles": removed_tiles.duplicate(true),
			"gang_subtype": "an_gang",
		}
	)
	current_turn_seat = seat
	last_gang_context = {
		"seat": seat,
		"source_seat": seat,
		"tile": first_tile.duplicate(true),
		"gang_type": "an_gang",
		"resolved": false,
	}
	_append_settlement_gang_event(seat, seat, first_tile, "an_gang", _get_active_non_winner_seats_excluding(seat))
	_append_ai_public_event("concealed_gang", seat, first_tile, seat)
	debug_last_message = "%s 暗杠 %s，开始补牌。" % [
		_seat_display_name(seat),
		first_tile["display_name"],
	]
	_begin_turn()
	_emit_state_changed()
	return true


func _choose_ai_add_gang_option(seat: int) -> Dictionary:
	var options := _find_all_add_gang_options(seat)
	if options.is_empty():
		return {}
	if ai_manager == null:
		return {}
	var decision: Dictionary = ai_manager.analyze_self_action(
		_build_player_state(seat),
		_build_table_state(),
		rules,
		false,
		[],
		_tile_types_from_options(options, "tile"),
		_add_gang_qiang_counts_by_tile_type(seat, options)
	)
	if str(decision.get("action", "")).strip_edges().to_lower() != "gang":
		return {}
	if str(decision.get("csharp_result", {}).get("gangSubtype", "")) != "add_gang":
		return {}
	var option := _find_option_by_tile_type(options, int(decision.get("tile_type", -1)), "tile")
	if not option.is_empty():
		option["evaluation"] = decision.duplicate(true)
	return option


func _choose_ai_an_gang_option(seat: int) -> Dictionary:
	var options := _find_all_an_gang_options(seat)
	if options.is_empty():
		return {}
	if ai_manager == null:
		return {}
	var decision: Dictionary = ai_manager.analyze_self_action(
		_build_player_state(seat),
		_build_table_state(),
		rules,
		false,
		_tile_types_from_options(options, "tiles"),
		[],
		{}
	)
	if str(decision.get("action", "")).strip_edges().to_lower() != "gang":
		return {}
	if str(decision.get("csharp_result", {}).get("gangSubtype", "")) != "an_gang":
		return {}
	var option := _find_option_by_tile_type(options, int(decision.get("tile_type", -1)), "tiles")
	if not option.is_empty():
		option["evaluation"] = decision.duplicate(true)
	return option


func _can_aggressive_gang_override(seat: int, reasons: Array, is_an_gang: bool) -> bool:
	if seat < 0 or seat >= players.size():
		return false
	if wall_count <= 6:
		return false
	var has_speed_hold := false
	var has_speed_drop := false
	var has_qiang_gang_risk := false
	for item in reasons:
		var text := str(item)
		if text.find("不损速度") != -1 or text.find("不明显降速") != -1 or text.find("仍保持成叫") != -1 or text.find("结构更清晰") != -1 or text.find("结构变优") != -1:
			has_speed_hold = true
		if text.find("向听变差") != -1 or text.find("结构变差") != -1 or text.find("拖慢速度") != -1:
			has_speed_drop = true
		if text.find("抢杠胡风险") != -1:
			has_qiang_gang_risk = true
	if has_speed_drop:
		return false
	if not is_an_gang and has_qiang_gang_risk:
		return false
	return has_speed_hold


func _create_empty_ai_decision_metrics() -> Dictionary:
	return {
		"reaction_total": 0,
		"reaction_hu": 0,
		"reaction_gang": 0,
		"reaction_peng": 0,
		"reaction_pass": 0,
		"self_hu_actions": 0,
		"an_gang_attempts": 0,
		"add_gang_attempts": 0,
		"discard_strategy_全攻": 0,
		"discard_strategy_进攻平衡": 0,
		"discard_strategy_均衡": 0,
		"discard_strategy_防守平衡": 0,
		"discard_strategy_全守": 0,
	}


func _record_ai_metric(key: String, amount: int = 1) -> void:
	ai_decision_metrics[key] = int(ai_decision_metrics.get(key, 0)) + amount

func _resolve_ai_reaction_action(seat: int, candidate: Dictionary, requested_action: String) -> String:
	if requested_action == "hu" and bool(candidate.get("can_hu", false)):
		return "hu"
	if requested_action == "gang" and bool(candidate.get("can_gang", false)) and not _has_higher_priority_candidate_than(seat, "gang"):
		return "gang"
	if requested_action == "peng" and bool(candidate.get("can_peng", false)) and not _has_higher_priority_candidate_than(seat, "peng"):
		return "peng"
	return "pass"


func _record_ai_reaction_review(seat: int, candidate: Dictionary, decision: Dictionary, requested_action: String, resolved_action: String) -> void:
	var tile: Dictionary = current_discard_context.get("tile", {}).duplicate(true)
	var source_seat := int(current_discard_context.get("source_seat", -1))
	var review := {
		"round_index": round_index,
		"phase": int(current_phase),
		"phase_name": _phase_debug_name(current_phase),
		"wall_count": wall_count,
		"seat": seat,
		"seat_name": _seat_display_name(seat),
		"source_seat": source_seat,
		"source_name": _seat_display_name(source_seat),
		"reaction_type": str(current_discard_context.get("reaction_type", "discard")),
		"tile": tile,
		"tile_name": str(tile.get("display_name", "")),
		"candidate": candidate.duplicate(true),
		"requested_action": requested_action,
		"action": resolved_action,
		"action_scores": decision.get("action_scores", {}).duplicate(true),
		"reasons": Array(decision.get("reasons", [])).duplicate(true),
		"posterior_summary": Array(decision.get("posterior_summary", [])).duplicate(true),
		"future_summary": Array(decision.get("future_summary", [])).duplicate(true),
		"search_used": bool(decision.get("search_used", false)),
		"search_simulations": int(decision.get("search_simulations", 0)),
		"search_bonus": float(decision.get("search_bonus", 0.0)),
		"current_shanten": int(decision.get("current_shanten", -1)),
		"backend_mode": str(decision.get("backend_mode", "")),
	}
	latest_ai_reaction_review = review.duplicate(true)
	ai_reaction_review_history.append(review)
	while ai_reaction_review_history.size() > AI_REACTION_REVIEW_LIMIT:
		ai_reaction_review_history.remove_at(0)


func _build_turn_diagnostic_profile(seat: int, analysis: Dictionary, selected_tile: Dictionary, hell_oracle: Dictionary = {}) -> Dictionary:
	var options: Array = analysis.get("options", [])
	var selected_type := int(analysis.get("recommended", {}).get("csharp_tile_type", _sichuan_tile_type(selected_tile)))
	var selected_candidate := _find_candidate_by_tile_type(options, selected_type)
	if selected_candidate.is_empty():
		selected_candidate = analysis.get("recommended", {}).duplicate(true)
	var score_sorted := _sort_turn_candidates_by_score(options)
	var speed_sorted := _sort_turn_candidates_by_speed(options)
	var selected_rank := _candidate_rank_by_tile_type(score_sorted, selected_type)
	var best_score_candidate: Dictionary = score_sorted[0].duplicate(true) if not score_sorted.is_empty() else {}
	var selected_shanten := int(selected_candidate.get("shanten", 8))
	var best_safe_alternative := _find_turn_candidate_alternative(options, selected_type, 18, selected_shanten + 1)
	var best_speed_alternative: Dictionary = speed_sorted[0].duplicate(true) if not speed_sorted.is_empty() else {}
	var best_big_route_alternative := _find_big_route_candidate_alternative(options, selected_type)
	var strategy_profile: Dictionary = analysis.get("strategy_profile", {})
	var csharp_result: Dictionary = analysis.get("csharp_result", {})
	var flags := _build_turn_diagnostic_flags(
		selected_candidate,
		best_score_candidate,
		best_safe_alternative,
		best_speed_alternative,
		best_big_route_alternative,
		selected_rank,
		strategy_profile
	)
	var quality_metrics := _build_turn_quality_metrics(
		selected_candidate,
		best_score_candidate,
		best_safe_alternative,
		best_speed_alternative,
		best_big_route_alternative,
		strategy_profile
	)
	for flag in Array(quality_metrics.get("quality_flags", [])):
		_append_unique_string(flags, str(flag))
	return {
		"schema_version": 3,
		"seat": seat,
		"selected": _compact_turn_candidate_for_training(selected_candidate),
		"selected_tile": selected_tile.duplicate(true),
		"selected_rank_by_score": selected_rank,
		"candidate_count": options.size(),
		"top_score_candidates": _compact_turn_candidates_for_training(score_sorted, 8),
		"top_speed_candidates": _compact_turn_candidates_for_training(speed_sorted, 5),
		"best_safe_alternative": _compact_turn_candidate_for_training(best_safe_alternative),
		"best_speed_alternative": _compact_turn_candidate_for_training(best_speed_alternative),
		"best_big_route_alternative": _compact_turn_candidate_for_training(best_big_route_alternative),
		"score_gap_to_best": int(best_score_candidate.get("score", 0)) - int(selected_candidate.get("score", 0)),
		"quality_metrics": quality_metrics,
		"selected_score_components": _build_candidate_score_components(selected_candidate),
		"strategy_profile": strategy_profile.duplicate(true),
		"belief_summary": analysis.get("belief_summary", {}).duplicate(true),
		"backend": {
			"mode": str(analysis.get("backend_mode", "")),
			"elapsed_ms": int(csharp_result.get("elapsedMs", -1)),
			"mobile_speed_mode": bool(csharp_result.get("mobileSpeedMode", false)),
			"cache": csharp_result.get("cache", {}).duplicate(true),
			"belief_metrics": csharp_result.get("beliefMetrics", {}).duplicate(true),
		},
		"diagnostic_flags": flags,
		"hell_oracle": hell_oracle.duplicate(true),
	}


func _build_reaction_diagnostic_profile(seat: int, candidate: Dictionary, decision: Dictionary, requested_action: String, resolved_action: String) -> Dictionary:
	var action_scores: Dictionary = decision.get("action_scores", {})
	var score_table := _build_action_score_table(action_scores)
	var best_action := str(score_table[0].get("action", "")) if not score_table.is_empty() else ""
	var resolved_score := int(action_scores.get(resolved_action, decision.get("score", 0)))
	var best_score := int(score_table[0].get("score", resolved_score)) if not score_table.is_empty() else resolved_score
	var flags: Array[String] = []
	if requested_action != resolved_action:
		_append_unique_string(flags, "frontend_resolution_changed_backend_request")
	if resolved_action != best_action and not best_action.is_empty():
		_append_unique_string(flags, "resolved_action_not_top_score")
	if abs(int(action_scores.get("peng", -999999)) - int(action_scores.get("gang", -999999))) <= 160 and action_scores.has("peng") and action_scores.has("gang"):
		_append_unique_string(flags, "peng_gang_close_score")
	if int(decision.get("current_shanten", 8)) <= 0 and resolved_action == "peng":
		_append_unique_string(flags, "peng_from_ready_hand")
	if int(decision.get("threat_level", 0)) >= 3:
		_append_unique_string(flags, "high_table_threat")
	return {
		"schema_version": 2,
		"seat": seat,
		"candidate": candidate.duplicate(true),
		"requested_action": requested_action,
		"resolved_action": resolved_action,
		"best_action_by_score": best_action,
		"score_gap_to_best": best_score - resolved_score,
		"action_score_table": score_table,
		"current_shanten": int(decision.get("current_shanten", -1)),
		"current_live_ukeire": int(decision.get("current_live_ukeire", 0)),
		"shanten_after": int(decision.get("shanten_after", -1)),
		"live_ukeire_after": int(decision.get("live_ukeire_after", 0)),
		"round_stage": int(decision.get("round_stage", -1)),
		"round_stage_label": str(decision.get("round_stage_label", "")),
		"threat_level": int(decision.get("threat_level", 0)),
		"max_ready_posterior": float(decision.get("max_ready_posterior", 0.0)),
		"posterior_summary": Array(decision.get("posterior_summary", [])).duplicate(true),
		"future_summary": Array(decision.get("future_summary", [])).duplicate(true),
		"search": {
			"used": bool(decision.get("search_used", false)),
			"simulations": int(decision.get("search_simulations", 0)),
			"bonus": float(decision.get("search_bonus", 0.0)),
		},
		"diagnostic_flags": flags,
		"reasons": Array(decision.get("reasons", [])).duplicate(true),
	}


func _build_self_action_diagnostic_profile(seat: int, decision: Dictionary) -> Dictionary:
	return {
		"schema_version": 2,
		"seat": seat,
		"action": str(decision.get("action", "pass")),
		"tile_type": int(decision.get("tile_type", -1)),
		"gang_subtype": str(decision.get("gang_subtype", "")),
		"action_score_table": _build_action_score_table(decision.get("analysis", {}).get("action_scores", decision.get("action_scores", {}))),
		"reasons": Array(decision.get("analysis", {}).get("reasons", decision.get("reasons", []))).duplicate(true),
	}


func _build_round_diagnostic_summary() -> Dictionary:
	var ai_core_debug := _build_full_ai_core_debug_snapshot()
	var backend_status: Dictionary = ai_core_debug.get("backend_status", {})
	return {
		"schema_version": 2,
		"round_index": round_index,
		"scores": _hell_score_snapshot(),
		"ai_decision_metrics": ai_decision_metrics.duplicate(true),
		"reaction_review_count": ai_reaction_review_history.size(),
		"latest_reaction_review": latest_ai_reaction_review.duplicate(true),
		"hell_training": _build_hell_training_debug_snapshot(),
		"ai_core_performance": ai_core_debug.get("performance_metrics", {}).duplicate(true),
		"ai_core_requests": ai_core_debug.get("request_state", {}).duplicate(true),
		"backend_status": backend_status.duplicate(true),
	}


func _sort_turn_candidates_by_score(options: Array) -> Array:
	var sorted := options.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("score", 0))
		var score_b := int(b.get("score", 0))
		if score_a != score_b:
			return score_a > score_b
		return int(a.get("live_ukeire", 0)) > int(b.get("live_ukeire", 0))
	)
	return sorted


func _sort_turn_candidates_by_speed(options: Array) -> Array:
	var sorted := options.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var shanten_a := int(a.get("shanten", 8))
		var shanten_b := int(b.get("shanten", 8))
		if shanten_a != shanten_b:
			return shanten_a < shanten_b
		var wait_a := int(a.get("wait_count", 0))
		var wait_b := int(b.get("wait_count", 0))
		if wait_a != wait_b:
			return wait_a > wait_b
		return int(a.get("live_ukeire", 0)) > int(b.get("live_ukeire", 0))
	)
	return sorted


func _find_candidate_by_tile_type(options: Array, tile_type: int) -> Dictionary:
	for option_item in options:
		var option: Dictionary = option_item
		if int(option.get("csharp_tile_type", option.get("tile_type", -1))) == tile_type:
			return option.duplicate(true)
	return {}


func _candidate_rank_by_tile_type(options: Array, tile_type: int) -> int:
	for index in range(options.size()):
		var option: Dictionary = options[index]
		if int(option.get("csharp_tile_type", option.get("tile_type", -1))) == tile_type:
			return index + 1
	return 0


func _find_turn_candidate_alternative(options: Array, excluded_tile_type: int, max_danger: int, max_shanten: int) -> Dictionary:
	var best := {}
	for option_item in options:
		var option: Dictionary = option_item
		if int(option.get("csharp_tile_type", option.get("tile_type", -1))) == excluded_tile_type:
			continue
		if int(option.get("risk", 100)) > max_danger:
			continue
		if int(option.get("shanten", 8)) > max_shanten:
			continue
		if best.is_empty() or int(option.get("score", 0)) > int(best.get("score", 0)):
			best = option.duplicate(true)
	return best


func _find_big_route_candidate_alternative(options: Array, excluded_tile_type: int) -> Dictionary:
	var best := {}
	for option_item in options:
		var option: Dictionary = option_item
		if int(option.get("csharp_tile_type", option.get("tile_type", -1))) == excluded_tile_type:
			continue
		if not _candidate_has_big_route(option):
			continue
		if best.is_empty() or int(option.get("score", 0)) > int(best.get("score", 0)):
			best = option.duplicate(true)
	return best


func _candidate_has_big_route(option: Dictionary) -> bool:
	for route in Array(option.get("routes_after", [])):
		var text := str(route)
		if text == "七对" or text == "对对胡" or text == "清一色":
			return true
	return false


func _build_turn_diagnostic_flags(
	selected: Dictionary,
	best_score: Dictionary,
	best_safe: Dictionary,
	best_speed: Dictionary,
	best_big_route: Dictionary,
	selected_rank: int,
	strategy_profile: Dictionary
) -> Array[String]:
	var flags: Array[String] = []
	if selected_rank > 1:
		_append_unique_string(flags, "selected_not_top_score")
	if int(selected.get("risk", 0)) >= 60:
		_append_unique_string(flags, "selected_high_risk")
	if int(selected.get("shanten", 8)) > 0 and int(selected.get("live_ukeire", 0)) <= 4:
		_append_unique_string(flags, "selected_narrow_live_ukeire")
	if not Array(selected.get("route_loss", [])).is_empty():
		_append_unique_string(flags, "selected_loses_route")
	if not best_safe.is_empty() and int(best_safe.get("score", 0)) + 450 >= int(selected.get("score", 0)):
		_append_unique_string(flags, "safe_alternative_close")
	if not best_speed.is_empty() and int(best_speed.get("shanten", 8)) < int(selected.get("shanten", 8)):
		_append_unique_string(flags, "faster_alternative_exists")
	if not best_big_route.is_empty() and not _candidate_has_big_route(selected):
		_append_unique_string(flags, "big_route_alternative_exists")
	if int(strategy_profile.get("threat_level", 0)) >= 3:
		_append_unique_string(flags, "high_table_threat")
	if int(best_score.get("score", 0)) - int(selected.get("score", 0)) >= 900:
		_append_unique_string(flags, "large_score_gap_to_best")
	return flags


func _build_turn_quality_metrics(
	selected: Dictionary,
	best_score: Dictionary,
	best_safe: Dictionary,
	best_speed: Dictionary,
	best_big_route: Dictionary,
	strategy_profile: Dictionary
) -> Dictionary:
	var selected_score := int(selected.get("score", 0))
	var best_score_value := int(best_score.get("score", selected_score))
	var score_gap := maxi(0, best_score_value - selected_score)
	var selected_expected_net := float(selected.get("expected_net_score", 0.0))
	var best_expected_net := float(best_score.get("expected_net_score", selected_expected_net))
	var expected_net_gap := maxf(0.0, best_expected_net - selected_expected_net)
	var selected_danger := int(selected.get("risk", 0))
	var selected_shanten := int(selected.get("shanten", 8))
	var safe_score_gap := 0
	var safe_danger_gap := 0
	if not best_safe.is_empty():
		safe_score_gap = selected_score - int(best_safe.get("score", selected_score))
		safe_danger_gap = selected_danger - int(best_safe.get("risk", selected_danger))
	var speed_shanten_gap := 0
	if not best_speed.is_empty():
		speed_shanten_gap = selected_shanten - int(best_speed.get("shanten", selected_shanten))
	var big_route_score_gap := 0
	if not best_big_route.is_empty():
		big_route_score_gap = int(best_big_route.get("score", selected_score)) - selected_score

	var mode := str(selected.get("strategy_mode", strategy_profile.get("strategy_mode", strategy_profile.get("mode", ""))))
	var flags: Array[String] = []
	var opportunity_loss := minf(100.0, float(score_gap) / 18.0 + expected_net_gap * 16.0)
	var mode_consistency := 100.0
	if mode in ["defense", "fold"] and selected_danger >= 58 and not best_safe.is_empty() and safe_score_gap <= 500 and safe_danger_gap >= 24:
		_append_unique_string(flags, "defense_mode_ignored_safe_alternative")
		opportunity_loss += 18.0
		mode_consistency -= 28.0
	if mode == "chase" and not best_big_route.is_empty() and not _candidate_has_big_route(selected) and big_route_score_gap >= -200:
		_append_unique_string(flags, "chase_mode_missed_big_route_value")
		opportunity_loss += 14.0
		mode_consistency -= 20.0
	if mode in ["attack", "chase"] and speed_shanten_gap > 0 and score_gap < 450:
		_append_unique_string(flags, "attack_mode_missed_speed_without_score_gain")
		opportunity_loss += 10.0
		mode_consistency -= 16.0
	if score_gap >= 900:
		_append_unique_string(flags, "large_ev_opportunity_loss")
	if expected_net_gap >= 2.0:
		_append_unique_string(flags, "expected_net_opportunity_loss")

	opportunity_loss = clampf(opportunity_loss, 0.0, 100.0)
	return {
		"quality_score": int(round(100.0 - opportunity_loss)),
		"opportunity_loss_score": int(round(opportunity_loss)),
		"mode_consistency_score": int(round(clampf(mode_consistency, 0.0, 100.0))),
		"expected_net_gap_to_best": snappedf(expected_net_gap, 0.001),
		"score_gap_to_best": score_gap,
		"risk_gap_to_best_safe": safe_danger_gap,
		"speed_shanten_gap": speed_shanten_gap,
		"big_route_score_gap": big_route_score_gap,
		"quality_flags": flags,
	}


func _compact_turn_candidates_for_training(candidates: Array, limit: int) -> Array:
	var result: Array = []
	for index in range(mini(limit, candidates.size())):
		var candidate: Dictionary = candidates[index]
		result.append(_compact_turn_candidate_for_training(candidate))
	return result


func _compact_turn_candidate_for_training(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {}
	var tile_type := int(candidate.get("csharp_tile_type", candidate.get("tile_type", -1)))
	return {
		"tile_type": tile_type,
		"tile_label": _sichuan_tile_type_label(tile_type),
		"tile_name": str(candidate.get("tile_name", candidate.get("tile", {}).get("display_name", ""))),
		"score": int(candidate.get("score", 0)),
		"shanten": int(candidate.get("shanten", 8)),
		"ukeire": int(candidate.get("ukeire", 0)),
		"live_ukeire": int(candidate.get("live_ukeire", 0)),
		"wait_count": int(candidate.get("wait_count", 0)),
		"danger": int(candidate.get("risk", 0)),
		"risk_label": str(candidate.get("risk_label", "")),
		"strategy_tag": str(candidate.get("strategy_tag", "")),
		"strategy_mode": str(candidate.get("strategy_mode", "")),
		"keeps_ready": bool(candidate.get("keeps_ready", false)),
		"exact_deal_in": bool(candidate.get("exact_deal_in", false)),
		"feeds_human_hu": bool(candidate.get("feeds_human_hu", false)),
		"feeds_human_peng": bool(candidate.get("feeds_human_peng", false)),
		"feeds_human_gang": bool(candidate.get("feeds_human_gang", false)),
		"human_peng_threat": int(candidate.get("human_peng_threat", 0)),
		"human_peng_penalty": int(candidate.get("human_peng_penalty", 0)),
		"tempo_peng_allowance_bonus": int(candidate.get("tempo_peng_allowance_bonus", 0)),
		"peng_only_interaction_bonus": int(candidate.get("peng_only_interaction_bonus", 0)),
		"exact_wall_remaining": int(candidate.get("exact_wall_remaining", 0)),
		"deal_in_target_seats": Array(candidate.get("deal_in_target_seats", [])).duplicate(true),
		"routes_after": Array(candidate.get("routes_after", [])).duplicate(true),
		"route_loss": Array(candidate.get("route_loss", [])).duplicate(true),
		"score_components": _build_candidate_score_components(candidate),
		"reasons": Array(candidate.get("reasons", [])).slice(0, 8),
	}


func _build_candidate_score_components(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {}
	return {
		"expected_net_score": float(candidate.get("expected_net_score", 0.0)),
		"expected_win_gain": float(candidate.get("expected_win_gain", 0.0)),
		"expected_deal_in_loss": float(candidate.get("expected_deal_in_loss", 0.0)),
		"expected_draw_risk_loss": float(candidate.get("expected_draw_risk_loss", 0.0)),
		"expected_ready_value": float(candidate.get("expected_ready_value", 0.0)),
		"posterior_adjustment": float(candidate.get("posterior_adjustment", 0.0)),
		"defense_adjustment": float(candidate.get("defense_adjustment", 0.0)),
		"shape_score": float(candidate.get("shape_score", 0.0)),
		"wait_shape_score": float(candidate.get("wait_shape_score", 0.0)),
		"limited_lookahead_score": float(candidate.get("limited_lookahead_score", 0.0)),
		"search_bonus": float(candidate.get("search_bonus", 0.0)),
		"set_preservation_score": float(candidate.get("set_preservation_score", 0.0)),
		"breaks_pair": bool(candidate.get("breaks_pair", false)),
		"breaks_triplet": bool(candidate.get("breaks_triplet", false)),
		"good_shape_count": int(candidate.get("good_shape_count", 0)),
		"bad_shape_count": int(candidate.get("bad_shape_count", 0)),
		"pair_pressure": int(candidate.get("pair_pressure", 0)),
		"taatsu_overflow": int(candidate.get("taatsu_overflow", 0)),
		"same_shanten_improvement_count": int(candidate.get("same_shanten_improvement_count", 0)),
		"middle_tile_flexibility": int(candidate.get("middle_tile_flexibility", 0)),
		"human_peng_penalty": float(candidate.get("human_peng_penalty", 0.0)),
		"tempo_peng_allowance_bonus": float(candidate.get("tempo_peng_allowance_bonus", 0.0)),
		"peng_only_interaction_bonus": float(candidate.get("peng_only_interaction_bonus", 0.0)),
	}


func _build_action_score_table(action_scores: Dictionary) -> Array:
	var rows: Array = []
	for key in action_scores.keys():
		rows.append({
			"action": str(key),
			"score": int(action_scores.get(key, 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	return rows


func _append_unique_string(values: Array[String], value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	values.append(value)


func _sichuan_tile_type_label(tile_type: int) -> String:
	if tile_type < 0:
		return ""
	var rank := tile_type % 9 + 1
	var suit_name := "条" if tile_type < 9 else ("筒" if tile_type < 18 else "万")
	return "%d%s" % [rank, suit_name]


func _phase_debug_name(phase_value: int) -> String:
	match phase_value:
		RoundPhase.BOOT:
			return "BOOT"
		RoundPhase.MAIN_MENU:
			return "MAIN_MENU"
		RoundPhase.TABLE_SETUP:
			return "TABLE_SETUP"
		RoundPhase.DING_QUE:
			return "DING_QUE"
		RoundPhase.DRAW:
			return "DRAW"
		RoundPhase.DISCARD:
			return "DISCARD"
		RoundPhase.REACTION:
			return "REACTION"
		RoundPhase.SETTLEMENT:
			return "SETTLEMENT"
		_:
			return str(phase_value)



func _find_all_add_gang_options(seat: int) -> Array:
	var results: Array = []
	if seat < 0 or seat >= players.size():
		return results
	var hand_tiles: Array = players[seat]["hand_tiles"]
	var melds: Array = players[seat]["melds"]
	for meld_index in range(melds.size()):
		var meld: Dictionary = melds[meld_index]
		if meld.get("type", "") != "peng":
			continue
		var meld_tiles: Array = meld.get("tiles", [])
		if meld_tiles.is_empty():
			continue
		var target_tile: Dictionary = meld_tiles[0]
		if _is_ding_que_tile_for_seat(seat, target_tile):
			continue
		for hand_tile in hand_tiles:
			if hand_tile["suit"] == target_tile["suit"] and hand_tile["rank"] == target_tile["rank"]:
				if _is_ding_que_tile_for_seat(seat, hand_tile):
					continue
				results.append(
					{
						"meld_index": meld_index,
						"tile": hand_tile.duplicate(true),
						"source_seat": int(meld.get("from_seat", seat)),
					}
				)
	return results


func _find_all_an_gang_options(seat: int) -> Array:
	var results: Array = []
	if seat < 0 or seat >= players.size():
		return results
	var hand_tiles: Array = players[seat]["hand_tiles"]
	var counts := {}
	for tile in hand_tiles:
		var key := "%s_%d" % [tile["suit"], tile["rank"]]
		if not counts.has(key):
			counts[key] = []
		counts[key].append(tile)
	for key in counts.keys():
		var tiles: Array = counts[key]
		if tiles.size() >= 4:
			if _is_ding_que_tile_for_seat(seat, tiles[0]):
				continue
			results.append({"tiles": tiles.slice(0, 4)})
	return results


func _build_qiang_gang_hu_candidates(actor_seat: int, gang_tile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in players:
		var seat: int = player["seat"]
		if seat == actor_seat or player.get("has_won", false):
			continue
		if mahjong_judge.can_hu_on_discard(_build_player_state(seat), gang_tile, rules):
			result.append(
				{
					"seat": seat,
					"can_hu": true,
					"can_gang": false,
					"can_peng": false,
				}
			)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _reaction_distance_from_source(actor_seat, int(a["seat"])) < _reaction_distance_from_source(actor_seat, int(b["seat"]))
	)
	return result


func _finalize_add_gang_without_qiang() -> bool:
	if pending_qiang_gang_context.is_empty():
		return false
	var seat: int = int(pending_qiang_gang_context["actor_seat"])
	var tile: Dictionary = pending_qiang_gang_context["tile"]
	if not pending_qiang_gang_context.has("meld_index"):
		debug_last_message = "ADD GANG context missing meld_index for seat %d." % seat
		pending_qiang_gang_context.clear()
		_clear_reaction_context()
		_emit_state_changed()
		return false
	var meld_index: int = int(pending_qiang_gang_context["meld_index"])
	if not _remove_tile_from_hand_by_id(seat, int(tile["id"])):
		return false
	if not _upgrade_peng_to_gang(seat, meld_index, tile):
		return false

	last_gang_context = {
		"seat": seat,
		"source_seat": int(pending_qiang_gang_context.get("source_seat", seat)),
		"tile": tile.duplicate(true),
		"gang_type": "add_gang",
		"resolved": false,
	}
	_append_settlement_gang_event(seat, int(pending_qiang_gang_context.get("source_seat", seat)), tile, "add_gang", _get_active_non_winner_seats_excluding(seat))
	_append_ai_public_event("added_gang", seat, tile, int(pending_qiang_gang_context.get("source_seat", seat)))
	_clear_reaction_context()
	pending_qiang_gang_context.clear()
	current_turn_seat = seat
	debug_last_message = "%s 完成补杠 %s，开始补牌。" % [
		_seat_display_name(seat),
		tile["display_name"],
	]
	_begin_turn()
	_emit_state_changed()
	return true


func _remove_tile_from_hand_by_id(seat: int, tile_id: int) -> bool:
	var hand_tiles: Array = players[seat]["hand_tiles"]
	for index in range(hand_tiles.size()):
		if hand_tiles[index]["id"] == tile_id:
			hand_tiles.remove_at(index)
			players[seat]["hand_tiles"] = hand_tiles
			players[seat]["hand_count"] = hand_tiles.size()
			return true
	return false


func _upgrade_peng_to_gang(seat: int, meld_index: int, extra_tile: Dictionary) -> bool:
	var melds: Array = players[seat]["melds"]
	if meld_index < 0 or meld_index >= melds.size():
		return false
	var meld: Dictionary = melds[meld_index]
	if meld.get("type", "") != "peng":
		return false
	var tiles: Array = meld.get("tiles", []).duplicate(true)
	tiles.append(extra_tile.duplicate(true))
	meld["type"] = "gang"
	meld["tiles"] = tiles
	meld["gang_upgrade"] = true
	melds[meld_index] = meld
	players[seat]["melds"] = melds
	return true


func _execute_peng(seat: int) -> bool:
	if current_discard_context.is_empty():
		return false

	_clear_pending_ai_async_state()
	var source_seat: int = current_discard_context["source_seat"]
	var discarded_tile: Dictionary = current_discard_context["tile"]
	# Ding-que blocks claiming the missing suit itself, but not other suits.
	if _is_ding_que_tile_for_seat(seat, discarded_tile):
		debug_last_message = "%s 定缺 %s，不能碰 %s。" % [
			_seat_display_name(seat),
			_suit_display_name(str(discarded_tile.get("suit", ""))),
			str(discarded_tile.get("display_name", "?")),
		]
		return false
	var claimed_pair: Array[Dictionary] = _remove_matching_tiles_from_hand(seat, discarded_tile, 2)
	if claimed_pair.size() != 2:
		return false
	_consume_claimed_discard(source_seat, discarded_tile)

	players[seat]["melds"].append(
		{
			"type": "peng",
			"from_seat": source_seat,
			"tiles": [
				claimed_pair[0],
				claimed_pair[1],
				discarded_tile.duplicate(true),
			],
		}
	)
	_append_ai_public_event("peng", seat, discarded_tile, source_seat)
	current_turn_seat = seat
	current_phase = RoundPhase.DISCARD
	last_draw_tile = {}
	debug_last_message = "%s 碰了 %s（来自 %s），等待出牌。" % [
		_seat_display_name(seat),
		discarded_tile["display_name"],
		_seat_display_name(source_seat),
	]
	_clear_reaction_context()
	if bool(players[seat].get("is_ai", false)):
		pending_ai_turn_decision.clear()
		_start_ai_turn_background_request()
	_emit_state_changed()
	return true


func _execute_gang(seat: int) -> bool:
	if current_discard_context.is_empty():
		return false

	_clear_pending_ai_async_state()
	var source_seat: int = current_discard_context["source_seat"]
	var discarded_tile: Dictionary = current_discard_context["tile"]
	# Ding-que blocks claiming the missing suit itself, but not other suits.
	if _is_ding_que_tile_for_seat(seat, discarded_tile):
		return false
	var claimed_tiles: Array[Dictionary] = _remove_matching_tiles_from_hand(seat, discarded_tile, 3)
	if claimed_tiles.size() != 3:
		return false
	_consume_claimed_discard(source_seat, discarded_tile)

	var meld_tiles: Array[Dictionary] = claimed_tiles.duplicate(true)
	meld_tiles.append(discarded_tile.duplicate(true))
	players[seat]["melds"].append(
		{
			"type": "gang",
			"from_seat": source_seat,
			"tiles": meld_tiles,
		}
	)
	_append_ai_public_event("melded_gang", seat, discarded_tile, source_seat)
	current_turn_seat = seat
	_clear_reaction_context()
	last_gang_context = {
		"seat": seat,
		"source_seat": source_seat,
		"tile": discarded_tile.duplicate(true),
		"gang_type": "melded_gang",
		"resolved": false,
	}
	_append_settlement_gang_event(seat, source_seat, discarded_tile, "melded_gang", [source_seat])
	debug_last_message = "%s 明杠 %s（来自 %s），开始补牌。" % [
		_seat_display_name(seat),
		discarded_tile["display_name"],
		_seat_display_name(source_seat),
	]
	_begin_turn()
	_emit_state_changed()
	return true


func _is_ding_que_tile_for_seat(seat: int, tile: Dictionary) -> bool:
	if seat < 0 or seat >= players.size():
		return false
	var ding_que: String = str(players[seat].get("ding_que", ""))
	if ding_que == "":
		return false
	return str(tile.get("suit", "")) == ding_que


func _execute_hu_on_discard(seat: int) -> bool:
	if current_discard_context.is_empty():
		return false

	_clear_pending_ai_async_state()
	var source_seat: int = current_discard_context["source_seat"]
	var discarded_tile: Dictionary = current_discard_context["tile"]
	var reaction_type: String = str(current_discard_context.get("reaction_type", "discard"))
	if not mahjong_judge.can_hu_on_discard(_build_player_state(seat), discarded_tile, rules):
		return false
	_consume_claimed_discard(source_seat, discarded_tile)

	players[seat]["has_won"] = true
	players[seat]["winning_tile"] = discarded_tile.duplicate(true)
	_append_ai_public_event("hu", seat, discarded_tile, source_seat)
	players[seat]["winning_source_seat"] = source_seat
	var win_type := _resolve_discard_win_type(source_seat, reaction_type)
	players[seat]["win_type"] = win_type
	_apply_special_rule_marks_for_win(seat, win_type)
	if not round_winners.has(seat):
		round_winners.append(seat)
		_append_settlement_win_event(seat, source_seat, discarded_tile, win_type, _get_payer_seats_for_win(win_type, source_seat))
	var current_winner_seats: Array = current_discard_context.get("winner_seats", [])
	if not current_winner_seats.has(seat):
		current_winner_seats.append(seat)
	current_discard_context["winner_seats"] = current_winner_seats
	if reaction_type == "qiang_gang_hu":
		var qiang_winner_seats: Array = pending_qiang_gang_context.get("winner_seats", [])
		if not qiang_winner_seats.has(seat):
			qiang_winner_seats.append(seat)
		pending_qiang_gang_context["winner_seats"] = qiang_winner_seats
	if win_type == "gang_discard_win":
		_mark_latest_gang_outcome("gang_discard_win")
		_append_hu_jiao_zhuan_yi_event(source_seat, seat, discarded_tile)
	elif win_type == "qiang_gang_hu":
		_consume_qiang_gang_robbed_tile()
		_mark_pending_qiang_gang_resolution("claimed_by_hu")
	_remove_reaction_candidate_for_seat(seat)
	_filter_pending_reactions_after_hu()
	debug_last_message = "%s 胡了 %s（来自 %s）。当前胡牌：%s" % [
		_seat_display_name(seat),
		discarded_tile["display_name"],
		_seat_display_name(source_seat),
		_format_winner_list(),
	]
	if _should_enter_battle_end_settlement():
		_enter_settlement_due_to_battle_end()
		_emit_state_changed()
	elif pending_reactions.is_empty():
		if reaction_type == "qiang_gang_hu":
			_finalize_qiang_gang_after_hu_or_pass()
		else:
			_finalize_reaction_after_hu_or_pass()
	else:
		current_phase = RoundPhase.REACTION
		_emit_state_changed()
	return true


func _execute_self_draw_hu(seat: int) -> bool:
	if seat < 0 or seat >= players.size():
		return false
	if players[seat]["has_won"]:
		return false

	var winning_tile: Dictionary = {}
	if not last_draw_tile.is_empty() and last_draw_tile["seat"] == seat:
		winning_tile = last_draw_tile["tile"].duplicate(true)
	elif not players[seat]["hand_tiles"].is_empty():
		winning_tile = players[seat]["hand_tiles"][players[seat]["hand_tiles"].size() - 1].duplicate(true)

	players[seat]["has_won"] = true
	players[seat]["winning_tile"] = winning_tile.duplicate(true)
	_append_ai_public_event("hu", seat, winning_tile, seat)
	players[seat]["winning_source_seat"] = seat
	var win_type := _resolve_self_draw_win_type(seat)
	players[seat]["win_type"] = win_type
	_apply_special_rule_marks_for_win(seat, win_type)
	if not round_winners.has(seat):
		round_winners.append(seat)
		_append_settlement_win_event(seat, seat, winning_tile, win_type, _get_payer_seats_for_win(win_type, seat))
	if win_type == "gang_self_draw":
		_mark_latest_gang_outcome("gang_self_draw")

	debug_last_message = "%s 自摸成功。当前胡牌：%s" % [
		_seat_display_name(seat),
		_format_winner_list(),
	]

	if _should_enter_battle_end_settlement():
		_enter_settlement_due_to_battle_end()
		_emit_state_changed()
		return true

	var next_seat := _find_next_active_seat_after(seat)
	if next_seat == -1:
		_enter_settlement_due_to_battle_end()
	else:
		current_turn_seat = next_seat
		last_draw_tile = {}
		_begin_turn()
	_emit_state_changed()
	return true


func _consume_claimed_discard(source_seat: int, tile: Dictionary) -> void:
	if source_seat < 0 or source_seat >= players.size():
		return
	var source_discards: Array = players[source_seat].get("discards", [])
	for index in range(source_discards.size() - 1, -1, -1):
		var discard: Dictionary = source_discards[index]
		if int(discard.get("id", -1)) == int(tile.get("id", -1)):
			source_discards.remove_at(index)
			break
	players[source_seat]["discards"] = source_discards

	for index in range(discard_pile.size() - 1, -1, -1):
		var item: Dictionary = discard_pile[index]
		if int(item.get("seat", -1)) == source_seat and int(item.get("tile", {}).get("id", -1)) == int(tile.get("id", -1)):
			discard_pile.remove_at(index)
			break


func _consume_qiang_gang_robbed_tile() -> void:
	if pending_qiang_gang_context.is_empty():
		return
	if bool(pending_qiang_gang_context.get("robbed_tile_removed", false)):
		return
	var actor_seat: int = int(pending_qiang_gang_context.get("actor_seat", -1))
	var tile: Dictionary = pending_qiang_gang_context.get("tile", {})
	if actor_seat < 0 or actor_seat >= players.size() or tile.is_empty():
		return
	if _remove_tile_from_hand_by_id(actor_seat, int(tile.get("id", -1))):
		pending_qiang_gang_context["robbed_tile_removed"] = true


func _remove_matching_tiles_from_hand(seat: int, target_tile: Dictionary, count_needed: int) -> Array[Dictionary]:
	var removed_tiles: Array[Dictionary] = []
	var hand_tiles: Array = players[seat]["hand_tiles"]
	var remove_indices: Array[int] = []

	for index in range(hand_tiles.size()):
		var tile: Dictionary = hand_tiles[index]
		if tile["suit"] == target_tile["suit"] and tile["rank"] == target_tile["rank"]:
			remove_indices.append(index)
			removed_tiles.append(tile)
			if removed_tiles.size() == count_needed:
				break

	if removed_tiles.size() != count_needed:
		return []

	remove_indices.reverse()
	for index in remove_indices:
		hand_tiles.remove_at(index)
	players[seat]["hand_tiles"] = hand_tiles
	players[seat]["hand_count"] = hand_tiles.size()
	return removed_tiles


func _get_reaction_candidate_for_seat(seat: int) -> Dictionary:
	for candidate in pending_reactions:
		if candidate["seat"] == seat:
			return candidate
	return {}


func _get_next_ai_reaction_candidate() -> Dictionary:
	if _has_pending_human_reaction_decision():
		return {}
	var best_candidate: Dictionary = {}
	var best_priority := -1
	var best_distance := 99
	var source_seat: int = int(current_discard_context.get("source_seat", -1))

	for candidate in pending_reactions:
		var seat: int = candidate["seat"]
		if seat < 0 or seat >= players.size() or not players[seat]["is_ai"]:
			continue

		var priority: int = mahjong_judge.get_candidate_priority(candidate)
		var distance := _reaction_distance_from_source(source_seat, seat)
		if priority > best_priority or (priority == best_priority and distance < best_distance):
			best_candidate = candidate
			best_priority = priority
			best_distance = distance

	return best_candidate


func _remove_reaction_candidate_for_seat(seat: int) -> void:
	for index in range(pending_reactions.size()):
		if pending_reactions[index]["seat"] == seat:
			pending_reactions.remove_at(index)
			return


func _pass_ai_reaction(seat: int) -> bool:
	var candidate: Dictionary = _get_reaction_candidate_for_seat(seat)
	if not candidate.is_empty():
		_record_reaction_pass_evidence(seat, candidate)
	_remove_reaction_candidate_for_seat(seat)
	debug_last_message = "AI seat %d passed. Remaining reactions: %s" % [
		seat,
		mahjong_judge.summarize_candidates(pending_reactions),
	]
	if pending_reactions.is_empty():
		if str(current_discard_context.get("reaction_type", "discard")) == "qiang_gang_hu":
			_finalize_qiang_gang_after_hu_or_pass()
		else:
			_finalize_reaction_after_hu_or_pass()
	else:
		_emit_state_changed()
	return true


func _has_higher_priority_candidate_than(seat: int, action: String) -> bool:
	var current_priority := _priority_for_action(action)
	var source_seat: int = int(current_discard_context.get("source_seat", -1))
	var current_distance := _reaction_distance_from_source(source_seat, seat)

	for candidate in pending_reactions:
		if candidate["seat"] == seat:
			continue
		var priority: int = mahjong_judge.get_candidate_priority(candidate)
		if priority > current_priority:
			return true
		if priority == current_priority and priority > 0:
			var distance := _reaction_distance_from_source(source_seat, candidate["seat"])
			if distance < current_distance:
				return true
	return false


func _priority_for_action(action: String) -> int:
	match action:
		"hu":
			return 3
		"gang":
			return 2
		"peng":
			return 1
		_:
			return 0


func _reaction_distance_from_source(source_seat: int, target_seat: int) -> int:
	if source_seat == -1:
		return 99
	return posmod(source_seat - target_seat, players.size())


func _finalize_reaction_without_claim() -> void:
	pending_ai_reaction_decision.clear()
	pending_ai_turn_decision.clear()
	_clear_pending_ai_async_state()
	_clear_reaction_context()
	_advance_turn_after_discard()
	_emit_state_changed()


func _finalize_reaction_after_hu_or_pass() -> void:
	if _should_enter_battle_end_settlement():
		_enter_settlement_due_to_battle_end()
		_emit_state_changed()
		return

	var source_seat: int = int(current_discard_context.get("source_seat", current_turn_seat))
	var winner_seats: Array = current_discard_context.get("winner_seats", [])
	pending_ai_reaction_decision.clear()
	pending_ai_turn_decision.clear()
	_clear_pending_ai_async_state()
	_clear_reaction_context()
	var next_seat := _resolve_resume_seat_after_discard_hu(source_seat, winner_seats)
	if next_seat == -1:
		_enter_settlement_due_to_battle_end()
	else:
		current_turn_seat = next_seat
		_begin_turn()
	_emit_state_changed()


func _finalize_qiang_gang_after_hu_or_pass() -> void:
	if pending_qiang_gang_context.is_empty():
		_finalize_reaction_after_hu_or_pass()
		return

	if _should_enter_battle_end_settlement():
		_enter_settlement_due_to_battle_end()
		_emit_state_changed()
		return

	var qiang_status: String = str(pending_qiang_gang_context.get("status", ""))
	if qiang_status == "claimed_by_hu":
		var actor_seat: int = int(pending_qiang_gang_context.get("actor_seat", current_turn_seat))
		var winner_seats: Array = pending_qiang_gang_context.get("winner_seats", [])
		pending_qiang_gang_context.clear()
		_clear_reaction_context()
		var next_seat := _resolve_resume_seat_after_discard_hu(actor_seat, winner_seats)
		if next_seat == -1:
			_enter_settlement_due_to_battle_end()
		else:
			current_turn_seat = next_seat
			_begin_turn()
		_emit_state_changed()
		return

	if round_winners.has(int(pending_qiang_gang_context.get("actor_seat", -1))):
		_mark_pending_qiang_gang_resolution("actor_already_won")
		pending_qiang_gang_context.clear()
		_clear_reaction_context()
		_emit_state_changed()
		return

	_mark_pending_qiang_gang_resolution("no_claim_then_add_gang")
	_finalize_add_gang_without_qiang()


func _filter_pending_reactions_after_hu() -> void:
	var filtered: Array[Dictionary] = []
	for candidate in pending_reactions:
		if not candidate.get("can_hu", false):
			continue
		if players[candidate["seat"]]["has_won"]:
			continue
		filtered.append(candidate)
	pending_reactions = filtered
	if not rules.allow_multi_win_on_discard:
		pending_reactions.clear()


func _should_enter_battle_end_settlement() -> bool:
	if round_winners.size() >= rules.max_winners_per_round:
		return true
	return _count_active_players() <= 1


func _count_active_players() -> int:
	var count := 0
	for player in players:
		if not player["has_won"]:
			count += 1
	return count


func _find_next_active_seat_after(from_seat: int) -> int:
	if players.is_empty():
		return -1
	for step in range(1, players.size() + 1):
		var seat := posmod(from_seat - step, players.size())
		if not players[seat]["has_won"]:
			return seat
	return -1


func _resolve_resume_seat_after_discard_hu(source_seat: int, winner_seats: Array) -> int:
	if winner_seats.is_empty():
		return _find_next_active_seat_after(source_seat)
	var last_winner := source_seat
	for step in range(1, players.size() + 1):
		var seat := posmod(source_seat - step, players.size())
		if winner_seats.has(seat):
			last_winner = seat
	return _find_next_active_seat_after(last_winner)


func _get_active_non_winner_seats_excluding(seat: int) -> Array:
	var result: Array = []
	for player in players:
		var target_seat: int = player["seat"]
		if target_seat == seat or player.get("has_won", false):
			continue
		result.append(target_seat)
	return result


func _get_payer_seats_for_win(win_type: String, source_seat: int) -> Array:
	match win_type:
		"self_draw", "gang_self_draw":
			return _get_active_non_winner_seats_excluding(int(current_turn_seat))
		"discard_win", "gang_discard_win", "qiang_gang_hu":
			return [source_seat]
		_:
			return [source_seat]


func _build_draw_settlement_assessment() -> void:
	var assessment: Array = []
	var ting_seats: Array[int] = []
	var no_ting_seats: Array[int] = []
	var hua_zhu_seats: Array[int] = []
	var use_hua_zhu := false if rules == null else bool(rules.enable_hua_zhu)

	for player in players:
		if player.get("has_won", false):
			continue
		var hand_tiles: Array = player.get("hand_tiles", [])
		var suit_count: int = _count_distinct_suits(hand_tiles)
		var has_ding_que_tiles: bool = _contains_ding_que_tiles(player)
		var hua_zhu: bool = use_hua_zhu and (suit_count == 3 or has_ding_que_tiles)
		var ting_tiles: Array = mahjong_judge.get_ting_tiles(_build_player_state(int(player.get("seat", -1))), rules)
		var is_ting: bool = not hua_zhu and not ting_tiles.is_empty()
		var cha_jiao_detail := _resolve_cha_jiao_detail(player, ting_tiles)
		var item := {
			"seat": player["seat"],
			"hua_zhu": hua_zhu,
			"is_ting": is_ting,
			"ting_tiles": ting_tiles,
			"cha_jiao_fan": int(cha_jiao_detail.get("fan", 0)),
			"cha_jiao_score": int(cha_jiao_detail.get("score", 0)),
			"cha_jiao_tile": cha_jiao_detail.get("tile", {}).duplicate(true),
			"distinct_suit_count": suit_count,
			"has_ding_que_tiles": has_ding_que_tiles,
		}
		assessment.append(item)
		if hua_zhu:
			hua_zhu_seats.append(player["seat"])
		elif is_ting:
			ting_seats.append(player["seat"])
		else:
			no_ting_seats.append(player["seat"])

	settlement_data["draw_assessment"] = assessment
	settlement_data["tui_gang_refunds"] = _build_tui_gang_refunds(ting_seats, no_ting_seats, hua_zhu_seats)


func _resolve_cha_jiao_detail(player: Dictionary, ting_tiles: Array) -> Dictionary:
	var best_fan := 0
	var best_score := 0
	var best_tile: Dictionary = {}
	for tile in ting_tiles:
		var fan_detail: Dictionary = score_resolver.build_event_fan_detail(player, tile, "discard_win", rules)
		var capped_fan: int = int(fan_detail.get("capped_fan", 0))
		var basic_score := _resolve_basic_score_from_fan(capped_fan)
		if basic_score > best_score or (basic_score == best_score and capped_fan > best_fan):
			best_fan = capped_fan
			best_score = basic_score
			best_tile = tile.duplicate(true)
	return {
		"fan": best_fan,
		"score": best_score,
		"tile": best_tile,
	}


func _resolve_basic_score_from_fan(capped_fan: int) -> int:
	var bottom_score := 1 if rules == null else maxi(1, int(rules.base_score))
	return bottom_score * int(pow(2.0, maxi(0, capped_fan)))


func _count_distinct_suits(hand_tiles: Array) -> int:
	var suits := {}
	for tile in hand_tiles:
		suits[tile.get("suit", "")] = true
	return suits.size()


func _contains_ding_que_tiles(player: Dictionary) -> bool:
	var ding_que: String = player.get("ding_que", "")
	if ding_que == "":
		return false
	for tile in player.get("hand_tiles", []):
		if tile.get("suit", "") == ding_que:
			return true
	return false


func _build_tui_gang_refunds(ting_seats: Array, no_ting_seats: Array, hua_zhu_seats: Array) -> Array:
	var refunds: Array = []
	# 本规则集的杠钱独立即时结算，流局不退税。
	if rules == null or not bool(rules.enable_tui_shui):
		return refunds
	if no_ting_seats.is_empty() and hua_zhu_seats.is_empty():
		return refunds

	var refund_actor_seats := {}
	for seat in no_ting_seats:
		refund_actor_seats[int(seat)] = true
	for seat in hua_zhu_seats:
		refund_actor_seats[int(seat)] = true

	for event in settlement_data.get("gang_events", []):
		var outcome: String = str(event.get("related_outcome", ""))
		if outcome != "":
			continue
		var actor_seat: int = int(event.get("actor_seat", -1))
		if not refund_actor_seats.has(actor_seat):
			continue
		refunds.append(
			{
				"actor_seat": actor_seat,
				"gang_type": str(event.get("gang_type", "")),
				"payer_seats": event.get("payer_seats", []).duplicate(),
				"refund_reason": "draw_tui_gang",
			}
		)
	return refunds


func _format_winner_list() -> String:
	if round_winners.is_empty():
		return "-"
	var parts: Array[String] = []
	for seat in round_winners:
		parts.append(_seat_display_name(int(seat)))
	return ", ".join(parts)


func _seat_display_name(seat: int) -> String:
	if seat >= 0 and seat < players.size():
		var player: Dictionary = players[seat]
		var nickname := str(player.get("nickname", ""))
		if not nickname.is_empty():
			return nickname
	match seat:
		0:
			return "本家"
		1:
			return "上家"
		2:
			return "对家"
		3:
			return "下家"
		_:
			return "座位%d" % seat


func _resolve_next_dealer_seat() -> int:
	var end_reason: String = str(settlement_data.get("end_reason", ""))
	if end_reason == "draw_wall_empty":
		return posmod(current_dealer_seat - 1, players.size())
	var win_events: Array = settlement_data.get("win_events", [])
	if win_events.is_empty():
		return posmod(current_dealer_seat - 1, players.size())
	var dealer_keeps := false
	for event in win_events:
		if int(event.get("winner_seat", -1)) == current_dealer_seat:
			dealer_keeps = true
			break
	if dealer_keeps:
		return current_dealer_seat
	return posmod(current_dealer_seat - 1, players.size())


func _consume_next_draw_reason() -> String:
	if not last_gang_context.is_empty() and not last_gang_context.get("resolved", false):
		last_gang_context["resolved"] = true
		return "gang_draw"
	return "normal_draw"


func _resolve_self_draw_win_type(seat: int) -> String:
	if last_turn_context.get("seat", -1) == seat and last_turn_context.get("draw_reason", "") == "gang_draw":
		return "gang_self_draw"
	return "self_draw"


func _resolve_discard_win_type(source_seat: int, reaction_type: String = "discard") -> String:
	if reaction_type == "qiang_gang_hu":
		return "qiang_gang_hu"
	if last_turn_context.get("seat", -1) == source_seat and last_turn_context.get("draw_reason", "") == "gang_draw":
		return "gang_discard_win"
	return "discard_win"


func _create_empty_settlement_data() -> Dictionary:
	return {
		"round_index": round_index,
		"dealer_seat": current_dealer_seat,
		"end_reason": "",
		"winner_seats": [],
		"win_events": [],
		"gang_events": [],
		"kong_resolution_events": [],
		"transfer_events": [],
		"qiang_gang_hu_placeholders": [],
		"draw_assessment": [],
		"tui_gang_refunds": [],
		"score_changes": {},
		"preapplied_score_changes": {},
		"scores_applied": false,
		"notes": [
			"胡牌分按底分×2^番数计算，累计最高 4 番；自摸每家固定另加 1 底分。",
			"杠钱独立即时结算且不受封顶限制；杠上炮时该次全部杠钱从开杠者转给胡牌者。",
			"流局执行花猪与查大叫；本规则集无海底捞月加番、无流局退税。",
		],
		"pending_features": [],
		"summary_text": "",
	}


func _append_settlement_win_event(winner_seat: int, source_seat: int, winning_tile: Dictionary, win_type: String, payer_seats: Array) -> void:
	var events: Array = settlement_data.get("win_events", [])
	var fan_detail: Dictionary = score_resolver.build_event_fan_detail(players[winner_seat], winning_tile, win_type, rules)
	events.append(
		{
			"winner_seat": winner_seat,
			"source_seat": source_seat,
			"winning_tile": winning_tile.duplicate(true),
			"win_type": win_type,
			"payer_seats": payer_seats.duplicate(),
			"fan_detail": fan_detail,
		}
	)
	settlement_data["win_events"] = events
	settlement_data["winner_seats"] = round_winners.duplicate()
	_rebuild_settlement_summary()


func _append_settlement_gang_event(actor_seat: int, source_seat: int, tile: Dictionary, gang_type: String, payer_seats: Array) -> void:
	var events: Array = settlement_data.get("gang_events", [])
	var event := {
		"actor_seat": actor_seat,
		"source_seat": source_seat,
		"tile": tile.duplicate(true),
		"gang_type": gang_type,
		"related_outcome": "",
		"payer_seats": payer_seats.duplicate(),
	}
	events.append(event)
	settlement_data["gang_events"] = events
	_apply_immediate_settlement_score_changes(
		score_resolver.build_gang_event_score_changes(players, event)
	)
	_append_kong_resolution_event(actor_seat, source_seat, tile, gang_type, "pending_review")
	_rebuild_settlement_summary()


func _mark_latest_gang_outcome(outcome: String) -> void:
	var events: Array = settlement_data.get("gang_events", [])
	if events.is_empty():
		return
	var last_index := events.size() - 1
	var event: Dictionary = events[last_index]
	event["related_outcome"] = outcome
	events[last_index] = event
	settlement_data["gang_events"] = events
	_mark_latest_kong_resolution_outcome(outcome)
	_rebuild_settlement_summary()


func _append_kong_resolution_event(actor_seat: int, source_seat: int, tile: Dictionary, gang_type: String, resolution_state: String) -> void:
	var events: Array = settlement_data.get("kong_resolution_events", [])
	events.append(
		{
			"actor_seat": actor_seat,
			"source_seat": source_seat,
			"tile": tile.duplicate(true),
			"gang_type": gang_type,
			"resolution_state": resolution_state,
			"related_outcome": "",
		}
	)
	settlement_data["kong_resolution_events"] = events


func _mark_latest_kong_resolution_outcome(outcome: String) -> void:
	var events: Array = settlement_data.get("kong_resolution_events", [])
	if events.is_empty():
		return
	var last_index := events.size() - 1
	var event: Dictionary = events[last_index]
	event["related_outcome"] = outcome
	if outcome == "gang_discard_win":
		event["resolution_state"] = "needs_tui_gang_and_transfer_review"
	elif outcome == "gang_self_draw":
		event["resolution_state"] = "gang_shang_hua_pending_score"
	events[last_index] = event
	settlement_data["kong_resolution_events"] = events


func _append_transfer_event(from_seat: int, to_seat: int, tile: Dictionary, transfer_type: String, reason: String) -> void:
	var events: Array = settlement_data.get("transfer_events", [])
	events.append(
		{
			"from_seat": from_seat,
			"to_seat": to_seat,
			"tile": tile.duplicate(true),
			"transfer_type": transfer_type,
			"reason": reason,
		}
	)
	settlement_data["transfer_events"] = events
	_rebuild_settlement_summary()


func _append_hu_jiao_zhuan_yi_event(from_seat: int, to_seat: int, tile: Dictionary) -> void:
	var gang_event := _find_latest_transferable_gang_event(from_seat)
	if gang_event.is_empty():
		_append_transfer_event(from_seat, to_seat, tile, "hu_jiao_zhuan_yi", "杠后打出的补牌被胡，按呼叫转移处理。")
		return
	var events: Array = settlement_data.get("transfer_events", [])
	var event := {
		"from_seat": from_seat,
		"to_seat": to_seat,
		"tile": tile.duplicate(true),
		"transfer_type": "hu_jiao_zhuan_yi",
		"reason": "杠上炮：该次开杠获得的全部杠钱从开杠者转给胡牌玩家。",
		"gang_type": str(gang_event.get("gang_type", "")),
		"payer_seats": Array(gang_event.get("payer_seats", [])).duplicate(),
		"related_actor_seat": int(gang_event.get("actor_seat", -1)),
		"transfer_score": score_resolver.resolve_gang_total_score(gang_event),
	}
	events.append(event)
	settlement_data["transfer_events"] = events
	_apply_immediate_settlement_score_changes(
		score_resolver.build_transfer_event_score_changes(players, event)
	)
	_rebuild_settlement_summary()


func _apply_immediate_settlement_score_changes(changes: Dictionary) -> void:
	var preapplied: Dictionary = settlement_data.get("preapplied_score_changes", {})
	for player in players:
		var seat := int(player.get("seat", -1))
		var delta := int(changes.get(seat, 0))
		if delta == 0:
			continue
		player["score"] = int(player.get("score", STARTING_SCORE)) + delta
		preapplied[seat] = int(preapplied.get(seat, 0)) + delta
	settlement_data["preapplied_score_changes"] = preapplied


func _append_qiang_gang_hu_placeholder(actor_seat: int, tile: Dictionary, placeholder_type: String) -> void:
	var items: Array = settlement_data.get("qiang_gang_hu_placeholders", [])
	items.append(
		{
			"actor_seat": actor_seat,
			"tile": tile.duplicate(true),
			"placeholder_type": placeholder_type,
			"status": "registered",
		}
	)
	settlement_data["qiang_gang_hu_placeholders"] = items
	_rebuild_settlement_summary()


func _register_qiang_gang_context(actor_seat: int, tile: Dictionary, placeholder_type: String) -> void:
	var preserved_context: Dictionary = pending_qiang_gang_context.duplicate(true)
	pending_qiang_gang_context = preserved_context
	pending_qiang_gang_context["actor_seat"] = actor_seat
	pending_qiang_gang_context["tile"] = tile.duplicate(true)
	pending_qiang_gang_context["placeholder_type"] = placeholder_type
	pending_qiang_gang_context["status"] = "waiting_for_add_gang_flow"
	_append_qiang_gang_hu_placeholder(actor_seat, tile, placeholder_type)


func _mark_pending_qiang_gang_resolution(status: String) -> void:
	if pending_qiang_gang_context.is_empty():
		return
	pending_qiang_gang_context["status"] = status
	var items: Array = settlement_data.get("qiang_gang_hu_placeholders", [])
	if items.is_empty():
		return
	var last_index := items.size() - 1
	var item: Dictionary = items[last_index]
	item["status"] = status
	items[last_index] = item
	settlement_data["qiang_gang_hu_placeholders"] = items
	_rebuild_settlement_summary()


func _rebuild_settlement_summary() -> void:
	settlement_data["round_index"] = round_index
	settlement_data["dealer_seat"] = current_dealer_seat
	settlement_data["winner_seats"] = round_winners.duplicate()
	settlement_data["score_changes"] = score_resolver.build_score_changes(players, settlement_data, rules)
	_apply_settlement_scores_once()

	var lines: Array[String] = []
	lines.append("第 %d 局｜庄家 %s" % [round_index, _seat_display_name(current_dealer_seat)])

	var end_reason: String = str(settlement_data.get("end_reason", ""))
	match end_reason:
		"battle_end":
			lines.append("结束原因：四川血战终局条件")
		"draw_wall_empty":
			lines.append("结束原因：牌墙摸完流局")
		_:
			lines.append("结束原因：进行中或未定")

	if round_winners.is_empty():
		lines.append("胡牌结果：暂无胡牌者")
	else:
		lines.append("胡牌结果：%s" % _format_winner_list())
	lines.append("下局庄家：%s" % _seat_display_name(_resolve_next_dealer_seat()))

	var events: Array = settlement_data.get("win_events", [])
	if events.is_empty():
		lines.append("胡牌事件：暂无")
	else:
		for event in events:
			var winner_seat: int = int(event.get("winner_seat", -1))
			var source_seat: int = int(event.get("source_seat", -1))
			var tile_name := "?"
			var winning_tile: Dictionary = event.get("winning_tile", {})
			if not winning_tile.is_empty():
				tile_name = winning_tile.get("display_name", "?")
			var win_type: String = str(event.get("win_type", "discard_win"))
			var fan_detail: Dictionary = event.get("fan_detail", {})
			var hand_type: String = _hand_type_display_name(str(fan_detail.get("hand_type", "ping_hu")))
			var fan_text := _format_fan_score_text(fan_detail, win_type)
			var labels: Array = fan_detail.get("labels", [])
			var label_text := "/".join(labels)
			if win_type == "self_draw" or win_type == "gang_self_draw":
				lines.append("胡牌事件：%s %s %s｜%s｜%s｜%s" % [
					_seat_display_name(winner_seat),
					_win_type_display_name(win_type),
					tile_name,
					hand_type,
					fan_text,
					label_text,
				])
			else:
				lines.append("胡牌事件：%s %s %s 的 %s｜%s｜%s｜%s" % [
					_seat_display_name(winner_seat),
					_win_type_display_name(win_type),
					_seat_display_name(source_seat),
					tile_name,
					hand_type,
					fan_text,
					label_text,
				])

	var gang_events: Array = settlement_data.get("gang_events", [])
	if gang_events.is_empty():
		lines.append("杠事件：暂无")
	else:
		for event in gang_events:
			var actor_seat: int = int(event.get("actor_seat", -1))
			var source_seat: int = int(event.get("source_seat", -1))
			var tile_name := "?"
			var tile: Dictionary = event.get("tile", {})
			if not tile.is_empty():
				tile_name = tile.get("display_name", "?")
			var gang_type: String = str(event.get("gang_type", "melded_gang"))
			var outcome: String = str(event.get("related_outcome", ""))
			var line := "杠事件：%s %s %s" % [_seat_display_name(actor_seat), _gang_type_display_name(gang_type), tile_name]
			if source_seat != actor_seat and source_seat != -1:
				line += "（来自 %s）" % _seat_display_name(source_seat)
			if outcome != "":
				line += " -> %s" % _win_type_display_name(outcome)
			lines.append(line)

	var kong_resolution_events: Array = settlement_data.get("kong_resolution_events", [])
	if kong_resolution_events.is_empty():
		lines.append("杠结算审查：暂无")
	else:
		for event in kong_resolution_events:
			var actor_seat: int = int(event.get("actor_seat", -1))
			var state_text: String = _resolution_state_display_name(str(event.get("resolution_state", "pending_review")))
			lines.append("杠结算审查：%s -> %s" % [_seat_display_name(actor_seat), state_text])

	var transfer_events: Array = settlement_data.get("transfer_events", [])
	if transfer_events.is_empty():
		lines.append("转移事件：暂无")
	else:
		for event in transfer_events:
			var from_seat: int = int(event.get("from_seat", -1))
			var to_seat: int = int(event.get("to_seat", -1))
			lines.append("转移事件：%s -> %s｜%s" % [
				_seat_display_name(from_seat),
				_seat_display_name(to_seat),
				_transfer_type_display_name(str(event.get("transfer_type", ""))),
			])

	var qiang_gang_items: Array = settlement_data.get("qiang_gang_hu_placeholders", [])
	if qiang_gang_items.is_empty():
		lines.append("抢杠胡占位：暂无")
	else:
		for item in qiang_gang_items:
			lines.append("抢杠胡占位：%s｜%s｜%s" % [
				_seat_display_name(int(item.get("actor_seat", -1))),
				str(item.get("placeholder_type", "")),
				str(item.get("status", "")),
			])

	if not shun_he_locks.is_empty():
		for seat in shun_he_locks.keys():
			var info: Dictionary = shun_he_locks[seat]
			lines.append("顺和限制：%s｜锁定至高于 %d 番" % [_seat_display_name(int(seat)), int(info.get("min_fan", 0))])

	var draw_assessment: Array = settlement_data.get("draw_assessment", [])
	if not draw_assessment.is_empty():
		for item in draw_assessment:
			var seat: int = int(item.get("seat", -1))
			var tags: Array[String] = []
			if item.get("hua_zhu", false):
				tags.append("花猪")
			elif item.get("is_ting", false):
				tags.append("有叫")
			else:
				tags.append("未叫")
			if bool(item.get("is_ting", false)):
				tags.append("%d番/%d分" % [
					maxi(0, int(item.get("cha_jiao_fan", 0))),
					maxi(1, int(item.get("cha_jiao_score", 0))),
				])
			var ting_tiles: Array = item.get("ting_tiles", [])
			if not ting_tiles.is_empty():
				var names: Array[String] = []
				for tile in ting_tiles:
					names.append(tile.get("display_name", "?"))
				tags.append("听%s" % "/".join(names))
			lines.append("流局判定：%s｜%s" % [_seat_display_name(seat), "｜".join(tags)])

	var tui_gang_refunds: Array = settlement_data.get("tui_gang_refunds", [])
	if tui_gang_refunds.is_empty():
		lines.append("退税：暂无")
	else:
		for refund in tui_gang_refunds:
			lines.append("退税：%s 的 %s 需退回给 %s" % [
				_seat_display_name(int(refund.get("actor_seat", -1))),
				_gang_type_display_name(str(refund.get("gang_type", ""))),
				_refund_payers_display(refund.get("payer_seats", [])),
			])

	lines.append("积分变化：%s" % _format_score_change_summary(settlement_data["score_changes"]))
	for review_line in _build_trainer_review_lines():
		lines.append(review_line)
	settlement_data["summary_text"] = "\n".join(lines)


func _apply_settlement_scores_once() -> void:
	if current_phase != RoundPhase.SETTLEMENT:
		return
	if bool(settlement_data.get("scores_applied", false)):
		return
	var score_changes: Dictionary = settlement_data.get("score_changes", {})
	var preapplied: Dictionary = settlement_data.get("preapplied_score_changes", {})
	for player in players:
		var seat: int = int(player.get("seat", -1))
		var remaining_delta := int(score_changes.get(seat, 0)) - int(preapplied.get(seat, 0))
		player["score"] = int(player.get("score", STARTING_SCORE)) + remaining_delta
	settlement_data["scores_applied"] = true
	_record_ai_analysis_event("round_end", {
		"score_changes": score_changes.duplicate(true),
		"settlement_data": settlement_data.duplicate(true),
		"ai_decision_metrics": ai_decision_metrics.duplicate(true),
		"latest_ai_reaction_review": latest_ai_reaction_review.duplicate(true),
		"ai_reaction_review_history": ai_reaction_review_history.duplicate(true),
		"round_diagnostic": _build_round_diagnostic_summary(),
	})
	_update_ai_learning_after_round(score_changes)
	_write_hell_training_report()


func mark_current_hell_training_case(reason: String = "manual_mark") -> bool:
	if not _is_hell_training_mode():
		debug_last_message = "当前不是地狱训练模式，无法标记训练手牌。"
		_emit_state_changed()
		return false
	_ensure_hell_training_session()
	var mark_signature := _current_hell_mark_signature()
	if mark_signature != "" and mark_signature == hell_last_marked_signature:
		debug_last_message = "当前训练手牌已经标记过。"
		_emit_state_changed()
		return true
	hell_training_marked_count += 1
	var snapshot := _build_hell_case_snapshot("manual_mark", -1, {}, {}, {}, {
		"reason": reason,
		"latest_decision": latest_hell_decision_snapshot.duplicate(true),
	})
	snapshot["marked_index"] = hell_training_marked_count
	var path := "%s/%s_mark_%04d.json" % [HELL_MARKED_CASE_DIR, hell_training_session_id, hell_training_marked_count]
	var ok := _write_json_file(path, snapshot)
	if ok:
		hell_last_marked_signature = mark_signature
		debug_last_message = "已标记当前训练手牌：%s" % ProjectSettings.globalize_path(path)
		_write_hell_training_report()
	else:
		debug_last_message = "标记训练手牌失败：%s" % path
	_emit_state_changed()
	return ok


func _current_hell_mark_signature() -> String:
	var visible: Dictionary = _build_hell_visible_state_snapshot()
	var player_discards := []
	for player in Array(visible.get("players", [])):
		var player_data: Dictionary = player
		player_discards.append(Array(player_data.get("discards", [])).size())
	return JSON.stringify({
		"latest_index": int(latest_hell_decision_snapshot.get("decision_index", -1)),
		"latest_type": str(latest_hell_decision_snapshot.get("decision_type", "")),
		"round_index": int(round_index),
		"phase": int(current_phase),
		"turn": int(current_turn_seat),
		"wall": int(wall_count),
		"discards": player_discards,
	})


func _is_hell_training_mode() -> bool:
	return ai_tuning_config != null \
		and str(ai_tuning_config.preset_name) == "hell" \
		and bool(ai_tuning_config.diagnostics_recording_enabled) \
		and bool(ai_tuning_config.hell_record_oracle)


func _is_hell_challenge_mode() -> bool:
	return ai_tuning_config != null \
		and str(ai_tuning_config.preset_name) == "hell" \
		and bool(ai_tuning_config.hell_execute_oracle_action) \
		and bool(ai_tuning_config.hell_ai_can_see_wall)


func _is_ai_analysis_recording_enabled() -> bool:
	if not _is_runtime_recording_enabled():
		return false
	return AI_ANALYSIS_RECORDING_ENABLED or _is_debug_training_recording_enabled()


func _is_ai_chain_debug_enabled() -> bool:
	return AI_CHAIN_DEBUG_ENABLED or _is_ai_analysis_recording_enabled()


func _is_diagnostic_export_enabled() -> bool:
	return DIAGNOSTIC_EXPORT_ENABLED or _is_ai_analysis_recording_enabled()


func _is_runtime_recording_enabled() -> bool:
	return AI_ANALYSIS_RECORDING_ENABLED \
		or _is_debug_training_recording_enabled() \
		or AI_LEARNING_RECORDING_ENABLED \
		or AI_SHADOW_RECORDING_ENABLED \
		or DIAGNOSTIC_EXPORT_ENABLED \
		or AI_CHAIN_DEBUG_ENABLED


func _is_debug_training_recording_enabled() -> bool:
	return DEBUG_TRAINING_RECORDING_ENABLED \
		and OS.is_debug_build() \
		and not OS.has_feature("android") \
		and not OS.has_feature("ios") \
		and not OS.has_feature("web")


func _ensure_hell_training_session() -> void:
	if not hell_training_session_id.is_empty():
		_ensure_hell_output_dirs()
		return
	hell_training_session_id = "%s_seed%s" % [_hell_timestamp_slug(), str(deterministic_seed if deterministic_seed_enabled else "live")]
	hell_training_decision_count = 0
	hell_training_marked_count = 0
	hell_training_category_counts.clear()
	hell_training_severity_counts.clear()
	latest_hell_decision_snapshot.clear()
	hell_last_marked_signature = ""
	_ensure_hell_output_dirs()


func _ensure_hell_output_dirs() -> void:
	for path in [HELL_TRAINING_DIR, HELL_MARKED_CASE_DIR, HELL_REPLAY_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _hell_timestamp_slug() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]


func _build_hell_training_debug_snapshot() -> Dictionary:
	return {
		"enabled": _is_hell_training_mode(),
		"challenge_enabled": _is_hell_challenge_mode(),
		"session_id": hell_training_session_id,
		"decision_count": hell_training_decision_count,
		"marked_count": hell_training_marked_count,
		"category_counts": hell_training_category_counts.duplicate(true),
		"severity_counts": hell_training_severity_counts.duplicate(true),
		"latest_decision": latest_hell_decision_snapshot.duplicate(true),
		"output_dirs": {
			"training": HELL_TRAINING_DIR,
			"marked_cases": HELL_MARKED_CASE_DIR,
			"replay": HELL_REPLAY_DIR,
		},
	}


func _ensure_ai_analysis_session() -> void:
	if not _is_ai_analysis_recording_enabled():
		return
	if not ai_analysis_session_id.is_empty():
		_ensure_ai_analysis_output_dirs()
		return
	ai_analysis_session_id = "%s_seed%s" % [_hell_timestamp_slug(), str(deterministic_seed if deterministic_seed_enabled else "live")]
	ai_analysis_event_count = 0
	latest_ai_analysis_event.clear()
	_ensure_ai_analysis_output_dirs()
	_write_json_file(_ai_analysis_session_path(), {
		"schema_version": 1,
		"session_id": ai_analysis_session_id,
		"created_at": Time.get_datetime_string_from_system(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"recording_dir": AI_ANALYSIS_DIR,
		"recording_dir_absolute": ProjectSettings.globalize_path(AI_ANALYSIS_DIR),
		"events_path": _ai_analysis_events_path(),
		"events_path_absolute": ProjectSettings.globalize_path(_ai_analysis_events_path()),
		"hell_training_dir": HELL_TRAINING_DIR,
		"hell_training_dir_absolute": ProjectSettings.globalize_path(HELL_TRAINING_DIR),
		"preset": "" if ai_tuning_config == null else str(ai_tuning_config.preset_name),
		"tuning": {} if ai_tuning_config == null else ai_tuning_config.to_debug_dict(),
		"note": "Analysis package: copy this whole ai_analysis folder and the hell_training folder after enough rounds.",
	})


func _ensure_ai_analysis_output_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_ai_analysis_session_dir()))


func _ai_analysis_session_dir() -> String:
	return "%s/%s" % [AI_ANALYSIS_DIR, ai_analysis_session_id if not ai_analysis_session_id.is_empty() else "pending"]


func _ai_analysis_session_path() -> String:
	return "%s/session.json" % _ai_analysis_session_dir()


func _ai_analysis_events_path() -> String:
	return "%s/events.jsonl" % _ai_analysis_session_dir()


func _build_ai_analysis_recording_debug_snapshot() -> Dictionary:
	return {
		"enabled": _is_ai_analysis_recording_enabled(),
		"session_id": ai_analysis_session_id,
		"event_count": ai_analysis_event_count,
		"latest_event": latest_ai_analysis_event.duplicate(true),
		"output_dir": _ai_analysis_session_dir(),
		"output_dir_absolute": ProjectSettings.globalize_path(_ai_analysis_session_dir()),
		"events_path": _ai_analysis_events_path(),
		"events_path_absolute": ProjectSettings.globalize_path(_ai_analysis_events_path()),
	}


func _record_ai_analysis_event(event_type: String, payload: Dictionary) -> void:
	if not _is_ai_analysis_recording_enabled():
		return
	_ensure_ai_analysis_session()
	ai_analysis_event_count += 1
	var event := {
		"schema_version": 1,
		"session_id": ai_analysis_session_id,
		"event_index": ai_analysis_event_count,
		"event_type": event_type,
		"created_at": Time.get_datetime_string_from_system(),
		"ticks_msec": Time.get_ticks_msec(),
		"round_index": round_index,
		"phase": int(current_phase),
		"phase_name": _phase_debug_name(current_phase),
		"current_turn_seat": current_turn_seat,
		"dealer_seat": current_dealer_seat,
		"wall_count": wall_count,
		"discard_count": discard_pile.size(),
		"preset": "" if ai_tuning_config == null else str(ai_tuning_config.preset_name),
		"tuning": {} if ai_tuning_config == null else ai_tuning_config.to_debug_dict(),
		"ai_metrics": ai_decision_metrics.duplicate(true),
		"backend": _build_full_ai_core_debug_snapshot(),
		"visible_state": _build_hell_visible_state_snapshot(),
		"hidden_state": _build_hell_hidden_state_snapshot(),
		"payload": payload.duplicate(true),
	}
	latest_ai_analysis_event = {
		"event_index": ai_analysis_event_count,
		"event_type": event_type,
		"created_at": str(event.get("created_at", "")),
		"round_index": round_index,
		"phase_name": str(event.get("phase_name", "")),
	}
	_append_jsonl_file(_ai_analysis_events_path(), event)
	if ai_analysis_event_count % 20 == 0 or event_type == "round_end":
		_write_ai_analysis_summary()


func _write_ai_analysis_summary() -> void:
	if ai_analysis_session_id.is_empty():
		return
	_write_json_file("%s/summary.json" % _ai_analysis_session_dir(), {
		"schema_version": 1,
		"session_id": ai_analysis_session_id,
		"updated_at": Time.get_datetime_string_from_system(),
		"event_count": ai_analysis_event_count,
		"round_index": round_index,
		"current_scores": _hell_score_snapshot(),
		"ai_decision_metrics": ai_decision_metrics.duplicate(true),
		"latest_event": latest_ai_analysis_event.duplicate(true),
		"events_path": _ai_analysis_events_path(),
		"events_path_absolute": ProjectSettings.globalize_path(_ai_analysis_events_path()),
		"hell_training_session_id": hell_training_session_id,
	})


func _is_debug_decision_trace_enabled() -> bool:
	return AI_SHADOW_RECORDING_ENABLED or _is_ai_analysis_recording_enabled()


func _ensure_debug_decision_trace_session() -> void:
	if not _is_debug_decision_trace_enabled():
		return
	if not debug_decision_trace_session_id.is_empty():
		_ensure_debug_decision_trace_output_dirs()
		return
	debug_decision_trace_session_id = "%s_debug_%s" % [_hell_timestamp_slug(), str(OS.get_unique_id()).substr(0, 8)]
	debug_decision_trace_event_count = 0
	latest_debug_decision_trace_event.clear()
	_ensure_debug_decision_trace_output_dirs()
	_prune_debug_decision_trace_sessions()
	_write_json_file(_debug_decision_trace_session_path(), {
		"schema_version": 2,
		"session_id": debug_decision_trace_session_id,
		"created_at": Time.get_datetime_string_from_system(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"recording_dir": DEBUG_DECISION_TRACE_DIR,
		"recording_dir_absolute": ProjectSettings.globalize_path(DEBUG_DECISION_TRACE_DIR),
		"events_path": _debug_decision_trace_events_path(),
		"events_path_absolute": ProjectSettings.globalize_path(_debug_decision_trace_events_path()),
		"package_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"privacy": "public_information_and_deciding_seat_hand_only",
		"max_events": AI_SHADOW_MAX_EVENTS,
		"note": "实战 AI 影子日志：只记录当时可见信息、决策座位自己的手牌、候选净值和执行结果；不记录公平模式下的隐藏手牌或精确牌墙。",
	})


func _ensure_debug_decision_trace_output_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_debug_decision_trace_session_dir()))


func _prune_debug_decision_trace_sessions() -> void:
	var root := ProjectSettings.globalize_path(DEBUG_DECISION_TRACE_DIR)
	DirAccess.make_dir_recursive_absolute(root)
	var sessions := DirAccess.get_directories_at(root)
	sessions.sort()
	while sessions.size() >= AI_SHADOW_MAX_SESSIONS:
		var oldest := str(sessions[0])
		sessions.remove_at(0)
		if oldest == debug_decision_trace_session_id:
			continue
		var old_dir := root.path_join(oldest)
		for filename in DirAccess.get_files_at(old_dir):
			DirAccess.remove_absolute(old_dir.path_join(str(filename)))
		DirAccess.remove_absolute(old_dir)


func _debug_decision_trace_session_dir() -> String:
	return "%s/%s" % [DEBUG_DECISION_TRACE_DIR, debug_decision_trace_session_id if not debug_decision_trace_session_id.is_empty() else "pending"]


func _debug_decision_trace_session_path() -> String:
	return "%s/session.json" % _debug_decision_trace_session_dir()


func _debug_decision_trace_events_path() -> String:
	return "%s/events.jsonl" % _debug_decision_trace_session_dir()


func _build_debug_decision_trace_snapshot() -> Dictionary:
	return {
		"enabled": _is_debug_decision_trace_enabled(),
		"session_id": debug_decision_trace_session_id,
		"event_count": debug_decision_trace_event_count,
		"latest_event": latest_debug_decision_trace_event.duplicate(true),
		"output_dir": _debug_decision_trace_session_dir(),
		"output_dir_absolute": ProjectSettings.globalize_path(_debug_decision_trace_session_dir()),
		"events_path": _debug_decision_trace_events_path(),
		"events_path_absolute": ProjectSettings.globalize_path(_debug_decision_trace_events_path()),
	}


func _record_ai_decision_trace_event(event_type: String, payload: Dictionary) -> void:
	if not _is_debug_decision_trace_enabled():
		return
	_ensure_debug_decision_trace_session()
	if debug_decision_trace_event_count >= AI_SHADOW_MAX_EVENTS:
		return
	debug_decision_trace_event_count += 1
	var event := {
		"schema_version": 2,
		"session_id": debug_decision_trace_session_id,
		"event_index": debug_decision_trace_event_count,
		"event_type": event_type,
		"created_at": Time.get_datetime_string_from_system(),
		"ticks_msec": Time.get_ticks_msec(),
		"round_index": round_index,
		"phase": int(current_phase),
		"phase_name": _phase_debug_name(current_phase),
		"current_turn_seat": current_turn_seat,
		"dealer_seat": current_dealer_seat,
		"wall_count": wall_count,
		"discard_count": discard_pile.size(),
		"scores": _hell_score_snapshot(),
		"own_hand18": _build_shadow_hand18(int(payload.get("seat", -1))),
		"ai_metrics": ai_decision_metrics.duplicate(true),
		"backend": _build_shadow_backend_snapshot(),
		"visible_state": _build_hell_visible_state_snapshot(),
		"hidden_state": _build_hell_hidden_state_snapshot() if _is_debug_training_recording_enabled() else {},
		"payload": _compact_shadow_trace_payload(payload),
	}
	latest_debug_decision_trace_event = {
		"event_index": debug_decision_trace_event_count,
		"event_type": event_type,
		"created_at": str(event.get("created_at", "")),
		"round_index": round_index,
		"phase_name": str(event.get("phase_name", "")),
		"seat": int(payload.get("seat", -1)),
	}
	_append_jsonl_file(_debug_decision_trace_events_path(), event)
	if debug_decision_trace_event_count % 20 == 0 or debug_decision_trace_event_count == AI_SHADOW_MAX_EVENTS:
		_write_debug_decision_trace_summary()


func _build_shadow_backend_snapshot() -> Dictionary:
	if ai_manager == null:
		return {}
	var status: Dictionary = ai_manager.get_backend_status()
	return {
		"native_runtime_available": bool(status.get("native_runtime_available", false)),
		"native_runtime_healthy": bool(status.get("native_runtime_healthy", false)),
		"backend_mode": str(status.get("backend_mode", "")),
		"last_native_turn_error": str(status.get("last_native_turn_error", "")),
		"last_native_reaction_error": str(status.get("last_native_reaction_error", "")),
	}


func _compact_shadow_trace_payload(payload: Dictionary) -> Dictionary:
	var compact: Dictionary = {}
	for key in [
		"request_id", "seat", "action", "executed", "requested_action", "resolved_action",
		"decision_path", "tile_id", "tile_type", "debug_last_message"
	]:
		if payload.has(key):
			compact[key] = payload.get(key)
	if payload.has("selected_tile"):
		compact["selected_tile"] = _compact_shadow_tile(payload.get("selected_tile", {}))
	if payload.has("candidate"):
		compact["candidate"] = _compact_shadow_candidate(payload.get("candidate", {}))
	for diagnostic_key in ["turn_diagnostic", "reaction_diagnostic", "self_action_diagnostic"]:
		if payload.has(diagnostic_key):
			compact[diagnostic_key] = _compact_shadow_diagnostic(payload.get(diagnostic_key, {}))
	if payload.has("decision"):
		var decision: Dictionary = payload.get("decision", {})
		compact["decision"] = {
			"seat": int(decision.get("seat", payload.get("seat", -1))),
			"action": str(decision.get("action", decision.get("resolved_action", ""))),
			"tile_id": int(decision.get("tile_id", -1)),
			"tile_type": int(decision.get("tile_type", -1)),
			"gang_subtype": str(decision.get("gang_subtype", "")),
			"state_signature": str(decision.get("state_signature", "")),
		}
	return compact


func _build_shadow_hand18(seat: int) -> Array:
	var counts: Array = []
	counts.resize(27)
	counts.fill(0)
	if seat < 0 or seat >= players.size():
		return counts
	for tile in Array(players[seat].get("hand_tiles", [])):
		var tile_type := _sichuan_tile_type(tile)
		if tile_type >= 0:
			counts[tile_type] = int(counts[tile_type]) + 1
	return counts


func _compact_shadow_tile(tile_value: Variant) -> Dictionary:
	if not tile_value is Dictionary:
		return {}
	var tile: Dictionary = tile_value
	return {
		"id": int(tile.get("id", -1)),
		"tile_type": _sichuan_tile_type(tile),
		"name": str(tile.get("display_name", tile.get("tile_name", ""))),
	}


func _compact_shadow_candidate(candidate_value: Variant) -> Dictionary:
	if not candidate_value is Dictionary:
		return {}
	var candidate: Dictionary = candidate_value
	var result: Dictionary = {}
	for key in [
		"tile_type", "csharp_tile_type", "score", "shanten", "ukeire", "live_ukeire",
		"wait_count", "risk", "danger", "risk_label", "strategy_tag", "strategy_mode",
		"expected_net_score", "expected_win_gain", "expected_deal_in_loss", "expected_ready_value",
		"unified_action_value", "strategic_residual", "breaks_pair", "breaks_triplet",
		"set_preservation_score", "route_plan_primary", "search_bonus"
	]:
		if candidate.has(key):
			result[key] = candidate.get(key)
	return result


func _compact_shadow_diagnostic(diagnostic_value: Variant) -> Dictionary:
	if not diagnostic_value is Dictionary:
		return {}
	var diagnostic: Dictionary = diagnostic_value
	var result: Dictionary = {}
	for key in [
		"schema_version", "seat", "selected_rank_by_score", "candidate_count", "score_gap_to_best",
		"requested_action", "resolved_action", "best_action_by_score", "current_shanten",
		"current_live_ukeire", "shanten_after", "live_ukeire_after", "round_stage",
		"round_stage_label", "threat_level", "max_ready_posterior", "action", "tile_type", "gang_subtype"
	]:
		if diagnostic.has(key):
			result[key] = diagnostic.get(key)
	if diagnostic.has("selected"):
		result["selected"] = _compact_shadow_candidate(diagnostic.get("selected", {}))
	if diagnostic.has("top_score_candidates"):
		var candidates: Array = []
		for candidate in Array(diagnostic.get("top_score_candidates", [])).slice(0, 5):
			candidates.append(_compact_shadow_candidate(candidate))
		result["top_score_candidates"] = candidates
	if diagnostic.has("action_score_table"):
		result["action_score_table"] = Array(diagnostic.get("action_score_table", [])).slice(0, 8)
	if diagnostic.has("diagnostic_flags"):
		result["diagnostic_flags"] = Array(diagnostic.get("diagnostic_flags", [])).slice(0, 8)
	if diagnostic.has("reasons"):
		result["reasons"] = Array(diagnostic.get("reasons", [])).slice(0, 8)
	if diagnostic.has("backend"):
		var backend: Dictionary = diagnostic.get("backend", {})
		result["backend"] = {
			"mode": str(backend.get("mode", "")),
			"elapsed_ms": int(backend.get("elapsed_ms", -1)),
			"mobile_speed_mode": bool(backend.get("mobile_speed_mode", false)),
		}
	return result


func _write_debug_decision_trace_summary() -> void:
	if debug_decision_trace_session_id.is_empty():
		return
	_write_json_file("%s/summary.json" % _debug_decision_trace_session_dir(), {
		"schema_version": 2,
		"session_id": debug_decision_trace_session_id,
		"updated_at": Time.get_datetime_string_from_system(),
		"event_count": debug_decision_trace_event_count,
		"round_index": round_index,
		"current_scores": _hell_score_snapshot(),
		"ai_decision_metrics": ai_decision_metrics.duplicate(true),
		"latest_event": latest_debug_decision_trace_event.duplicate(true),
		"events_path": _debug_decision_trace_events_path(),
		"events_path_absolute": ProjectSettings.globalize_path(_debug_decision_trace_events_path()),
		"max_events": AI_SHADOW_MAX_EVENTS,
		"truncated": debug_decision_trace_event_count >= AI_SHADOW_MAX_EVENTS,
	})


func _record_hell_decision_snapshot(decision: Dictionary, decision_type: String, actual_tile_type: int = -1) -> void:
	if not _is_hell_training_mode():
		return
	_ensure_hell_training_session()
	hell_training_decision_count += 1
	var seat := int(decision.get("seat", current_turn_seat))
	var fair_ai: Dictionary = decision.get("analysis", {}).duplicate(true)
	var enriched_decision := decision.duplicate(true)
	if decision_type == "discard" and not fair_ai.has("turn_diagnostic"):
		var selected_tile: Dictionary = fair_ai.get("recommended", {}).get("tile", {})
		if selected_tile.is_empty() and actual_tile_type >= 0:
			selected_tile = _find_hand_tile_by_tile_type(seat, actual_tile_type)
		fair_ai["turn_diagnostic"] = _build_turn_diagnostic_profile(
			seat,
			fair_ai,
			selected_tile,
			decision.get("hell_oracle", {}).duplicate(true)
		)
		enriched_decision["analysis"] = fair_ai.duplicate(true)
	var snapshot := _build_hell_case_snapshot(
		decision_type,
		seat,
		fair_ai,
		decision.get("hell_oracle", {}).duplicate(true),
		decision.get("actual_action", {}).duplicate(true),
		{
			"decision": enriched_decision,
			"actual_tile_type": actual_tile_type,
		}
	)
	snapshot["decision_index"] = hell_training_decision_count
	latest_hell_decision_snapshot = snapshot.duplicate(true)
	_update_hell_training_summary(snapshot)
	var path := "%s/%s_decision_%06d.json" % [HELL_TRAINING_DIR, hell_training_session_id, hell_training_decision_count]
	_write_json_file(path, snapshot)


func _record_hell_reaction_snapshot(seat: int, candidate: Dictionary, decision: Dictionary, requested_action: String, resolved_action: String) -> void:
	if not _is_hell_training_mode():
		return
	var action_snapshot := {
		"requested_action": requested_action,
		"resolved_action": resolved_action,
		"reaction_tile_type": _sichuan_tile_type(current_discard_context.get("tile", {})),
		"source_seat": int(current_discard_context.get("source_seat", -1)),
	}
	_record_hell_decision_snapshot({
		"seat": seat,
		"analysis": decision.duplicate(true),
		"actual_action": action_snapshot,
		"reaction_candidate": candidate.duplicate(true),
	}, "reaction", int(action_snapshot.get("reaction_tile_type", -1)))


func _build_hell_case_snapshot(decision_type: String, seat: int, fair_ai: Dictionary, oracle_ai: Dictionary, actual_action: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var category := str(oracle_ai.get("category", "not_evaluated"))
	var severity := str(oracle_ai.get("severity", "none"))
	return {
		"schema_version": 1,
		"session_id": hell_training_session_id,
		"created_at": Time.get_datetime_string_from_system(),
		"round_index": round_index,
		"phase": int(current_phase),
		"decision_type": decision_type,
		"seat": seat,
		"preset": "" if ai_tuning_config == null else str(ai_tuning_config.preset_name),
		"hell_flags": _hell_flags_snapshot(),
		"visible_state": _build_hell_visible_state_snapshot(),
		"hidden_state": _build_hell_hidden_state_snapshot(),
		"fair_ai": fair_ai.duplicate(true),
		"oracle_ai": oracle_ai.duplicate(true),
		"actual_action": actual_action.duplicate(true),
		"difference": {
			"category": category,
			"severity": severity,
		},
		"extra": extra.duplicate(true),
	}


func _hell_flags_snapshot() -> Dictionary:
	if ai_tuning_config == null:
		return {}
	return {
		"share_ai_hands": bool(ai_tuning_config.hell_ai_share_ai_hands),
		"can_see_human_hand": bool(ai_tuning_config.hell_ai_can_see_human_hand),
		"can_see_wall": bool(ai_tuning_config.hell_ai_can_see_wall),
		"record_oracle": bool(ai_tuning_config.hell_record_oracle),
		"execute_oracle_action": bool(ai_tuning_config.hell_execute_oracle_action),
		"log_marked_cases": bool(ai_tuning_config.hell_log_marked_cases),
	}


func _build_hell_visible_state_snapshot() -> Dictionary:
	var player_summaries: Array = []
	for player in players:
		var meld_summaries: Array = []
		for meld_value in Array(player.get("melds", [])):
			if meld_value is Dictionary:
				var meld: Dictionary = meld_value
				var meld_tiles: Array = []
				for tile in Array(meld.get("tiles", [])):
					meld_tiles.append(_sichuan_tile_type(tile))
				meld_summaries.append({"type": str(meld.get("type", "")), "tiles": meld_tiles})
		var summary := {
			"seat": int(player.get("seat", -1)),
			"nickname": str(player.get("nickname", "")),
			"score": int(player.get("score", 0)),
			"is_ai": bool(player.get("is_ai", false)),
			"hand_count": int(player.get("hand_count", 0)),
			"has_won": bool(player.get("has_won", false)),
			"melds": meld_summaries,
			"discards": Array(player.get("discards", [])).map(func(tile): return _sichuan_tile_type(tile)),
		}
		player_summaries.append(summary)
	return {
		"current_turn_seat": current_turn_seat,
		"current_dealer_seat": current_dealer_seat,
		"wall_count": wall_count,
		"discard_pile": discard_pile.map(func(tile): return _sichuan_tile_type(tile)),
		"current_discard_context": {
			"source_seat": int(current_discard_context.get("source_seat", -1)),
			"reaction_type": str(current_discard_context.get("reaction_type", "")),
			"tile_type": _sichuan_tile_type(current_discard_context.get("tile", {})),
		},
		"last_draw_tile": _compact_shadow_tile(last_draw_tile),
		"players": player_summaries,
	}


func _build_hell_hidden_state_snapshot() -> Dictionary:
	return {
		"all_hands18": _all_hands18_for_hell(),
		"exact_wall18": _exact_wall18_for_hell(),
		"human_hand_visible_to_ai": ai_tuning_config != null and bool(ai_tuning_config.hell_ai_can_see_human_hand),
		"raw_wall_count": wall.size(),
	}


func _build_hell_challenge_payload() -> Dictionary:
	return {
		"allHands18": _all_hands18_for_hell(),
		"exactWall18": _exact_wall18_for_hell(),
		"currentScores": _hell_scores_array(),
	}


func _all_hands18_for_hell() -> Array:
	var result: Array = []
	for player in players:
		var seat := int(player.get("seat", -1))
		var can_include := true
		if seat == 0 and ai_tuning_config != null and not bool(ai_tuning_config.hell_ai_can_see_human_hand):
			can_include = false
		if bool(player.get("is_ai", false)) and ai_tuning_config != null and not bool(ai_tuning_config.hell_ai_share_ai_hands):
			can_include = false
		result.append(_tile_counts18(Array(player.get("hand_tiles", []))) if can_include else _zero_counts18())
	while result.size() < 4:
		result.append(_zero_counts18())
	return result


func _exact_wall18_for_hell() -> Array:
	if ai_tuning_config == null or not bool(ai_tuning_config.hell_ai_can_see_wall):
		return _zero_counts18()
	return _tile_counts18(wall)


func _tile_counts18(tiles: Array) -> Array:
	var counts := _zero_counts18()
	for tile in tiles:
		var item: Dictionary = tile
		var tile_type := _sichuan_tile_type(item)
		if tile_type >= 0 and tile_type < counts.size():
			counts[tile_type] = int(counts[tile_type]) + 1
	return counts


func _zero_counts18() -> Array:
	var counts: Array[int] = []
	for _i in range(DEFAULT_SUITS.size() * RANKS.size()):
		counts.append(0)
	return counts


func _ai_turn_state_signature(seat: int) -> String:
	if seat < 0 or seat >= players.size():
		return ""
	var player: Dictionary = players[seat]
	return "r=%d|ph=%d|turn=%d|dealer=%d|wall=%d|hand=%s|draw=%s|pub=%s|pass=%s" % [
		round_index,
		int(current_phase),
		current_turn_seat,
		current_dealer_seat,
		wall_count,
		_counts18_signature(_tile_counts18(Array(player.get("hand_tiles", [])))),
		_ai_last_draw_signature(seat),
		_public_state_signature(),
		_reaction_pass_evidence_signature(),
	]


func _ai_last_draw_signature(seat: int) -> String:
	var draw_seat := int(last_draw_tile.get("seat", -1))
	if draw_seat != seat:
		return "-"
	var tile: Dictionary = last_draw_tile.get("tile", {})
	return "%d:%d:%d" % [
		draw_seat,
		int(tile.get("id", -1)),
		_sichuan_tile_type(tile),
	]


func _ai_reaction_state_signature(seat: int) -> String:
	var tile: Dictionary = current_discard_context.get("tile", {})
	return "%s|src=%d|rtile=%d:%d|pending=%s" % [
		_ai_turn_state_signature(seat),
		int(current_discard_context.get("source_seat", -1)),
		int(tile.get("id", -1)),
		_sichuan_tile_type(tile),
		_pending_reactions_signature(),
	]


func _public_state_signature() -> String:
	var parts: Array[String] = []
	for index in range(players.size()):
		var player: Dictionary = players[index]
		parts.append("%d:d%s:m%s:w%d" % [
			index,
			_counts18_signature(_tile_counts18(Array(player.get("discards", [])))),
			_melds_signature(Array(player.get("melds", []))),
			1 if bool(player.get("has_won", false)) else 0,
		])
	return "/".join(parts)


func _melds_signature(melds: Array) -> String:
	var parts: Array[String] = []
	for meld_item in melds:
		var meld: Dictionary = meld_item
		var tile_parts: Array[String] = []
		for tile_item in Array(meld.get("tiles", [])):
			var tile: Dictionary = tile_item
			tile_parts.append(str(_sichuan_tile_type(tile)))
		if meld.has("tile"):
			tile_parts.append(str(_sichuan_tile_type(meld.get("tile", {}))))
		parts.append("%s:%s:%s" % [
			str(meld.get("type", "")),
			",".join(tile_parts),
			str(meld.get("from_seat", "")),
		])
	return ";".join(parts)


func _reaction_pass_evidence_signature() -> String:
	var parts: Array[String] = []
	for evidence_item in reaction_pass_evidence:
		var evidence: Dictionary = evidence_item
		parts.append("%s:%s:%s:%s" % [
			str(evidence.get("seat", "")),
			str(evidence.get("source_seat", "")),
			str(evidence.get("tile_type", "")),
			str(evidence.get("action", "")),
		])
	return ";".join(parts)


func _pending_reactions_signature() -> String:
	var parts: Array[String] = []
	for reaction_item in pending_reactions:
		var reaction: Dictionary = reaction_item
		parts.append("%d:%d:%d:%d" % [
			int(reaction.get("seat", -1)),
			1 if bool(reaction.get("can_hu", false)) else 0,
			1 if bool(reaction.get("can_gang", false)) else 0,
			1 if bool(reaction.get("can_peng", false)) else 0,
		])
	return ";".join(parts)


func _counts18_signature(counts: Array) -> String:
	var parts: Array[String] = []
	for count in counts:
		parts.append(str(int(count)))
	return ",".join(parts)


func _try_apply_hell_oracle_to_discard(seat: int, player_state: Dictionary, table_state: Dictionary, analysis: Dictionary, selected_tile: Dictionary) -> Dictionary:
	if not (_is_hell_training_mode() or _is_hell_challenge_mode()) or ai_manager == null:
		return {
			"selected_tile": selected_tile.duplicate(true),
			"oracle": {},
		}
	var fair_tile_type := int(analysis.get("recommended", {}).get("csharp_tile_type", _sichuan_tile_type(selected_tile)))
	var payload: Dictionary = ai_manager.csharp_bridge.build_discard_transport_payload(player_state, table_state, rules)
	payload["allHands18"] = _all_hands18_for_hell()
	payload["exactWall18"] = _exact_wall18_for_hell()
	payload["currentScores"] = _hell_scores_array()
	payload["fairTileType"] = fair_tile_type
	payload["actualTileType"] = fair_tile_type
	var oracle: Dictionary = ai_manager.analyze_hell_oracle_discard(payload)
	var final_tile := selected_tile.duplicate(true)
	if not oracle.is_empty() and bool(ai_tuning_config.hell_execute_oracle_action):
		var oracle_tile_type := int(oracle.get("tileType", -1))
		var oracle_tile := _find_hand_tile_by_tile_type(seat, oracle_tile_type)
		if not oracle_tile.is_empty():
			final_tile = oracle_tile
			oracle["actualTileType"] = oracle_tile_type
	return {
		"selected_tile": final_tile,
		"oracle": oracle,
	}


func _apply_hell_oracle_to_discard_decision(
	base_decision: Dictionary,
	seat: int,
	player_state: Dictionary,
	table_state: Dictionary,
	analysis: Dictionary,
	selected_tile: Dictionary
) -> Dictionary:
	var decision := base_decision.duplicate(true)
	if _is_direct_hell_challenge_analysis(analysis):
		var challenge := _build_direct_hell_challenge_diagnostic(analysis, selected_tile)
		decision["action"] = "discard"
		decision["tile_id"] = int(selected_tile.get("id", -1))
		decision["analysis"] = analysis.duplicate(true)
		decision["hell_oracle"] = challenge.duplicate(true)
		decision["actual_action"] = {
			"action": "discard",
			"tile_id": int(selected_tile.get("id", -1)),
			"tile_type": _sichuan_tile_type(selected_tile),
			"source": "hell_challenge_direct",
		}
		return {
			"decision": decision,
			"selected_tile": selected_tile.duplicate(true),
			"oracle": challenge,
		}
	var hell_result := _try_apply_hell_oracle_to_discard(seat, player_state, table_state, analysis, selected_tile)
	var final_tile: Dictionary = hell_result.get("selected_tile", selected_tile)
	var hell_oracle: Dictionary = hell_result.get("oracle", {})
	decision["action"] = "discard"
	decision["tile_id"] = int(final_tile.get("id", -1))
	decision["analysis"] = analysis.duplicate(true)
	if not hell_oracle.is_empty():
		decision["hell_oracle"] = hell_oracle.duplicate(true)
		decision["fair_tile_id"] = int(analysis.get("recommended", {}).get("tile", {}).get("id", -1))
		decision["fair_tile_type"] = int(analysis.get("recommended", {}).get("csharp_tile_type", -1))
		decision["actual_action"] = {
			"action": "discard",
			"tile_id": int(final_tile.get("id", -1)),
			"tile_type": _sichuan_tile_type(final_tile),
			"source": "hell_oracle" if ai_tuning_config != null and bool(ai_tuning_config.hell_execute_oracle_action) else "fair_ai",
		}
	return {
		"decision": decision,
		"selected_tile": final_tile,
		"oracle": hell_oracle,
	}


func _is_direct_hell_challenge_analysis(analysis: Dictionary) -> bool:
	var backend := str(analysis.get("backend_mode", ""))
	return backend == "hell_challenge_direct" \
		or backend == "hell_challenge_direct_async" \
		or backend == "hell_challenge_direct_sync_delivery"


func _build_direct_hell_challenge_diagnostic(analysis: Dictionary, selected_tile: Dictionary) -> Dictionary:
	var native: Dictionary = analysis.get("csharp_result", {}).duplicate(true)
	native["decisionType"] = "discard"
	native["category"] = str(native.get("category", "hell_challenge_direct"))
	native["severity"] = str(native.get("severity", "none"))
	native["actualTileType"] = _sichuan_tile_type(selected_tile)
	native["fairTileType"] = int(native.get("fairTileType", -1))
	return native


func _find_hand_tile_by_tile_type(seat: int, tile_type: int) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	for tile in Array(players[seat].get("hand_tiles", [])):
		var item: Dictionary = tile
		if _sichuan_tile_type(item) == tile_type:
			return item.duplicate(true)
	return {}


func _tile_by_id_in_hand(seat: int, tile_id: int) -> Dictionary:
	if seat < 0 or seat >= players.size():
		return {}
	for tile in Array(players[seat].get("hand_tiles", [])):
		var item: Dictionary = tile
		if int(item.get("id", -1)) == tile_id:
			return item.duplicate(true)
	return {}


func _update_hell_training_summary(snapshot: Dictionary) -> void:
	var diff: Dictionary = snapshot.get("difference", {})
	var category := str(diff.get("category", "not_evaluated"))
	var severity := str(diff.get("severity", "none"))
	hell_training_category_counts[category] = int(hell_training_category_counts.get(category, 0)) + 1
	hell_training_severity_counts[severity] = int(hell_training_severity_counts.get(severity, 0)) + 1


func _write_hell_training_report() -> void:
	if hell_training_session_id.is_empty() or not _is_hell_training_mode():
		return
	_ensure_hell_output_dirs()
	var summary := {
		"schema_version": 1,
		"session_id": hell_training_session_id,
		"updated_at": Time.get_datetime_string_from_system(),
		"round_index": round_index,
		"decision_count": hell_training_decision_count,
		"marked_count": hell_training_marked_count,
		"category_counts": hell_training_category_counts.duplicate(true),
		"severity_counts": hell_training_severity_counts.duplicate(true),
		"current_scores": _hell_score_snapshot(),
		"calibration_suggestions": _build_hell_calibration_suggestions(),
		"replay_manifest_path": "%s/%s_replay_manifest.json" % [HELL_REPLAY_DIR, hell_training_session_id],
	}
	_write_json_file("%s/%s_summary.json" % [HELL_TRAINING_DIR, hell_training_session_id], summary)
	_write_text_file("%s/%s_summary.csv" % [HELL_TRAINING_DIR, hell_training_session_id], _build_hell_summary_csv(summary))
	_write_text_file("%s/%s_report.md" % [HELL_TRAINING_DIR, hell_training_session_id], _build_hell_report_md(summary))
	_write_json_file(str(summary.get("replay_manifest_path", "")), _build_hell_replay_manifest(summary))


func _hell_score_snapshot() -> Dictionary:
	var result := {}
	for player in players:
		result[str(int(player.get("seat", -1)))] = int(player.get("score", 0))
	return result


func _hell_scores_array() -> Array:
	var scores: Array[int] = []
	for seat in range(4):
		var score := 0
		if seat >= 0 and seat < players.size():
			score = int(players[seat].get("score", 0))
		scores.append(score)
	return scores


func _build_hell_summary_csv(summary: Dictionary) -> String:
	var lines: Array[String] = ["kind,key,count"]
	for key in Dictionary(summary.get("category_counts", {})).keys():
		lines.append("category,%s,%d" % [str(key), int(summary["category_counts"].get(key, 0))])
	for key in Dictionary(summary.get("severity_counts", {})).keys():
		lines.append("severity,%s,%d" % [str(key), int(summary["severity_counts"].get(key, 0))])
	lines.append("total,decisions,%d" % int(summary.get("decision_count", 0)))
	lines.append("total,marked,%d" % int(summary.get("marked_count", 0)))
	return "\n".join(lines) + "\n"


func _build_hell_report_md(summary: Dictionary) -> String:
	var lines: Array[String] = [
		"# Hell Training Report",
		"",
		"- Session: `%s`" % str(summary.get("session_id", "")),
		"- Decisions: %d" % int(summary.get("decision_count", 0)),
		"- Marked cases: %d" % int(summary.get("marked_count", 0)),
		"- Round index: %d" % int(summary.get("round_index", 0)),
		"",
		"## Category Counts",
	]
	for key in Dictionary(summary.get("category_counts", {})).keys():
		lines.append("- `%s`: %d" % [str(key), int(summary["category_counts"].get(key, 0))])
	lines.append("")
	lines.append("## Severity Counts")
	for key in Dictionary(summary.get("severity_counts", {})).keys():
		lines.append("- `%s`: %d" % [str(key), int(summary["severity_counts"].get(key, 0))])
	lines.append("")
	lines.append("## Calibration Notes")
	var suggestions: Array = summary.get("calibration_suggestions", [])
	if suggestions.is_empty():
		lines.append("- No calibration suggestion yet. Continue collecting hell-mode decisions.")
	else:
		for suggestion in suggestions:
			var item: Dictionary = suggestion
			lines.append("- `%s`: %s" % [str(item.get("target", "")), str(item.get("reason", ""))])
	lines.append("")
	lines.append("## Replay")
	lines.append("- Manifest: `%s`" % str(summary.get("replay_manifest_path", "")))
	lines.append("- Use high-severity marked JSON cases first. Do not auto-apply weight changes without replaying the same seed or marked case.")
	return "\n".join(lines) + "\n"


func _build_hell_calibration_suggestions() -> Array:
	var suggestions: Array = []
	var high_count := int(hell_training_severity_counts.get("high", 0))
	var risk_count := int(hell_training_category_counts.get("risk_underestimated", 0))
	var hand_eff_count := int(hell_training_category_counts.get("hand_efficiency_error", 0))
	var wait_shape_count := int(hell_training_category_counts.get("wait_shape_error", 0))
	var wall_count_errors := int(hell_training_category_counts.get("wall_posterior_error", 0))
	var situation_count := int(hell_training_category_counts.get("situation_goal_error", 0))
	if risk_count > 0:
		suggestions.append({
			"target": "defense_weight / deal_in_loss",
			"reason": "%d 个风险低估差异，优先检查对手听口后验与点炮损失。" % risk_count,
			"severity": "high" if high_count > 0 else "medium",
		})
	if hand_eff_count > 0:
		suggestions.append({
			"target": "shape_score / live_ukeire / limited_lookahead",
			"reason": "%d 个牌效差异，优先看候选牌的向听、活张、3-5巡前瞻。" % hand_eff_count,
			"severity": "medium",
		})
	if wait_shape_count > 0:
		suggestions.append({
			"target": "wait_shape_score",
			"reason": "%d 个听口形状差异，优先检查两面/坎张/边张/单骑分类。" % wait_shape_count,
			"severity": "medium",
		})
	if wall_count_errors > 0:
		suggestions.append({
			"target": "wall_posterior",
			"reason": "%d 个牌墙后验差异，优先检查 remaining18 与 exact wall 的偏差。" % wall_count_errors,
			"severity": "medium",
		})
	if situation_count > 0:
		suggestions.append({
			"target": "situation_goal",
			"reason": "%d 个局势目标差异，优先检查领先/落后/庄闲/后期守攻切换。" % situation_count,
			"severity": "medium",
		})
	return suggestions


func _build_hell_replay_manifest(summary: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"session_id": hell_training_session_id,
		"created_at": Time.get_datetime_string_from_system(),
		"deterministic_seed_enabled": deterministic_seed_enabled,
		"deterministic_seed": deterministic_seed,
		"round_index": round_index,
		"training_dir": HELL_TRAINING_DIR,
		"marked_case_dir": HELL_MARKED_CASE_DIR,
		"summary_path": "%s/%s_summary.json" % [HELL_TRAINING_DIR, hell_training_session_id],
		"decision_count": int(summary.get("decision_count", 0)),
		"marked_count": int(summary.get("marked_count", 0)),
		"acceptance_note": "Replay this session after code changes and compare category/severity counts before accepting calibration.",
	}


func _write_json_file(path: String, data: Dictionary) -> bool:
	return _write_text_file(path, JSON.stringify(data, "\t"))


func _append_jsonl_file(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(data))
	file.close()
	return true


func _write_text_file(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _format_score_change_summary(score_changes: Dictionary) -> String:
	var parts: Array[String] = []
	for player in players:
		var seat: int = player["seat"]
		var delta: int = int(score_changes.get(seat, 0))
		var prefix := "+" if delta > 0 else ""
		parts.append("%s %s%d" % [_seat_display_name(seat), prefix, delta])
	return " | ".join(parts)


func _format_fan_score_text(fan_detail: Dictionary, win_type: String = "") -> String:
	var capped_fan := int(fan_detail.get("capped_fan", 0))
	var hand_score := int(fan_detail.get("hand_score", _resolve_basic_score_from_fan(capped_fan)))
	var basic_score := int(fan_detail.get("per_payer_score", hand_score))
	if (win_type == "self_draw" or win_type == "gang_self_draw") and not fan_detail.has("per_payer_score"):
		basic_score += 1
	var fan_text := "%d番" % capped_fan
	if basic_score != hand_score and (win_type == "self_draw" or win_type == "gang_self_draw"):
		return "%s/%d+自摸1=%d分" % [fan_text, hand_score, basic_score]
	return "%s/%d分" % [fan_text, basic_score]


func _gang_type_display_name(gang_type: String) -> String:
	match gang_type:
		"melded_gang":
			return "明杠"
		"add_gang":
			return "补杠"
		"an_gang":
			return "暗杠"
		_:
			return gang_type


func _win_type_display_name(win_type: String) -> String:
	match win_type:
		"self_draw":
			return "自摸胡"
		"gang_self_draw":
			return "杠上花"
		"gang_discard_win":
			return "杠上炮"
		"qiang_gang_hu":
			return "抢杠胡"
		"discard_win":
			return "点炮胡"
		_:
			return win_type


func _hand_type_display_name(hand_type: String) -> String:
	match hand_type:
		"shi_ba_luo_han":
			return "十八罗汉"
		"qing_jin_gou_diao":
			return "清金钩钓"
		"jin_gou_diao":
			return "金钩钓"
		"jiang_dui":
			return "将对"
		"qing_yi_se":
			return "清一色"
		"qi_dui":
			return "小七对"
		"long_qi_dui":
			return "龙七对"
		"qing_dui":
			return "清对"
		"qing_qi_dui":
			return "清七对"
		"qing_long_qi_dui":
			return "清龙七对"
		"da_dui_zi":
			return "大对子"
		"ping_hu":
			return "平胡"
		_:
			return hand_type


func _resolution_state_display_name(state: String) -> String:
	match state:
		"pending_review":
			return "待结算审查"
		"needs_tui_gang_and_transfer_review":
			return "待退税/呼叫转移审查"
		"gang_shang_hua_pending_score":
			return "杠上花待记分"
		_:
			return state


func _transfer_type_display_name(transfer_type: String) -> String:
	match transfer_type:
		"hu_jiao_zhuan_yi":
			return "呼叫转移"
		_:
			return transfer_type


func _find_latest_transferable_gang_event(actor_seat: int) -> Dictionary:
	var events: Array = settlement_data.get("gang_events", [])
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if int(event.get("actor_seat", -1)) != actor_seat:
			continue
		return event
	return {}


func _refund_payers_display(payer_seats: Array) -> String:
	if payer_seats.is_empty():
		return "-"
	var parts: Array[String] = []
	for payer in payer_seats:
		parts.append(_seat_display_name(int(payer)))
	return ", ".join(parts)


func _create_player_stub(seat: int, nickname: String, is_ai: bool) -> Dictionary:
	return {
		"seat": seat,
		"nickname": nickname,
		"score": STARTING_SCORE,
		"is_ai": is_ai,
		"ding_que": "",
		"hand_count": 13 if seat != current_dealer_seat else 14,
		"melds": [],
		"discards": [],
	}
