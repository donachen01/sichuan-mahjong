extends RefCounted

class_name AITuningConfig

const PRESET_INTERMEDIATE := "intermediate"
const PRESET_BONE_ASH := "bone_ash"
const PRESET_HELL := "hell"

var lookahead_candidate_count: int = 4
var lookahead_draw_samples: int = 11
var add_gang_min_score: int = 10
var an_gang_min_score: int = 18
var beginner_random_pool_start_ratio: float = 0.5
var intermediate_top_pick_count: int = 2
var attack_tendency: int = 2
var defense_tendency: int = 1
var fast_ting_priority: int = 4
var self_draw_priority: int = 4
var forced_cleanup_tendency: int = 3
var big_hand_tendency: int = 0
var opponent_read_tendency: int = 3
var endgame_absolute_defense: bool = true
var auto_learning_enabled: bool = true
var hell_ai_share_ai_hands: bool = false
var hell_ai_can_see_human_hand: bool = false
var hell_ai_can_see_wall: bool = false
var hell_record_oracle: bool = false
var hell_execute_oracle_action: bool = false
var hell_log_marked_cases: bool = false
var diagnostics_recording_enabled: bool = false
var preset_name: String = PRESET_BONE_ASH
var learning_adjustment: Dictionary = {}


func apply_preset(name: String) -> void:
	preset_name = name
	learning_adjustment = {}
	hell_ai_share_ai_hands = false
	hell_ai_can_see_human_hand = false
	hell_ai_can_see_wall = false
	hell_record_oracle = false
	hell_execute_oracle_action = false
	hell_log_marked_cases = false
	match name:
		PRESET_INTERMEDIATE:
			lookahead_candidate_count = 2
			lookahead_draw_samples = 5
			add_gang_min_score = 18
			an_gang_min_score = 28
			beginner_random_pool_start_ratio = 0.60
			intermediate_top_pick_count = 3
			attack_tendency = 0
			defense_tendency = 2
			fast_ting_priority = 4
			self_draw_priority = 4
			forced_cleanup_tendency = 2
			big_hand_tendency = 0
			opponent_read_tendency = 2
			endgame_absolute_defense = true
		PRESET_HELL:
			lookahead_candidate_count = 5
			lookahead_draw_samples = 12
			add_gang_min_score = 8
			an_gang_min_score = 16
			beginner_random_pool_start_ratio = 0.0
			intermediate_top_pick_count = 1
			attack_tendency = 3
			defense_tendency = 3
			fast_ting_priority = 4
			self_draw_priority = 4
			forced_cleanup_tendency = 4
			big_hand_tendency = 0
			opponent_read_tendency = 4
			endgame_absolute_defense = true
			hell_ai_share_ai_hands = true
			hell_ai_can_see_human_hand = true
			hell_ai_can_see_wall = true
			hell_record_oracle = diagnostics_recording_enabled
			hell_execute_oracle_action = true
			hell_log_marked_cases = diagnostics_recording_enabled
		_:
			preset_name = PRESET_BONE_ASH
			lookahead_candidate_count = 4
			lookahead_draw_samples = 8
			add_gang_min_score = 10
			an_gang_min_score = 18
			beginner_random_pool_start_ratio = 0.50
			intermediate_top_pick_count = 2
			attack_tendency = 2
			defense_tendency = 2
			fast_ting_priority = 4
			self_draw_priority = 4
			forced_cleanup_tendency = 3
			big_hand_tendency = 0
			opponent_read_tendency = 3
			endgame_absolute_defense = true


func apply_learning_adjustment(learning_profile: Dictionary) -> void:
	if learning_profile.is_empty():
		return
	var bias: Dictionary = learning_profile.get("parameter_bias", {})
	var direct_adjustments: Dictionary = learning_profile.get("parameter_adjustments", {})
	var risk_bias := int(bias.get("risk_bias", 0))
	var attack_bias := int(bias.get("attack_bias", 0))
	var gang_bias := int(bias.get("gang_bias", 0))
	var lookahead_bias := int(bias.get("lookahead_bias", 0))

	lookahead_candidate_count = clampi(lookahead_candidate_count + int(floor(float(lookahead_bias) / 3.0)), 2, 5)
	lookahead_draw_samples = clampi(lookahead_draw_samples + lookahead_bias + attack_bias, 4, 12)
	add_gang_min_score = clampi(add_gang_min_score + risk_bias * 4 - attack_bias * 2 - gang_bias * 3, 8, 50)
	an_gang_min_score = clampi(an_gang_min_score + risk_bias * 3 - attack_bias * 2 - gang_bias * 2, 12, 60)
	intermediate_top_pick_count = clampi(intermediate_top_pick_count - int(floor(float(lookahead_bias) / 4.0)), 1, 3)
	fast_ting_priority = clampi(fast_ting_priority + attack_bias + lookahead_bias, 0, 4)
	self_draw_priority = clampi(self_draw_priority + attack_bias + lookahead_bias / 2, 0, 4)
	forced_cleanup_tendency = clampi(forced_cleanup_tendency + risk_bias, 0, 4)
	big_hand_tendency = clampi(big_hand_tendency + attack_bias - risk_bias, 0, 4)
	opponent_read_tendency = clampi(opponent_read_tendency + risk_bias + int(round(float(lookahead_bias) * 0.5)), 0, 4)
	_apply_direct_learning_adjustments(direct_adjustments)
	learning_adjustment = {
		"total_human_rounds": int(learning_profile.get("total_human_rounds", 0)),
		"parameter_bias": bias.duplicate(true),
		"parameter_adjustments": direct_adjustments.duplicate(true),
		"last_adjustment_reasons": learning_profile.get("last_adjustment_reasons", []).duplicate(),
	}


func _apply_direct_learning_adjustments(adjustments: Dictionary) -> void:
	if adjustments.is_empty():
		return
	lookahead_candidate_count = clampi(lookahead_candidate_count + int(adjustments.get("lookahead_candidate_count", 0)), 2, 5)
	lookahead_draw_samples = clampi(lookahead_draw_samples + int(adjustments.get("lookahead_draw_samples", 0)), 4, 12)
	add_gang_min_score = clampi(add_gang_min_score + int(adjustments.get("add_gang_min_score", 0)), 8, 50)
	an_gang_min_score = clampi(an_gang_min_score + int(adjustments.get("an_gang_min_score", 0)), 12, 60)
	intermediate_top_pick_count = clampi(intermediate_top_pick_count + int(adjustments.get("intermediate_top_pick_count", 0)), 1, 3)
	attack_tendency = clampi(attack_tendency + int(adjustments.get("attack_tendency", 0)), -3, 3)
	defense_tendency = clampi(defense_tendency + int(adjustments.get("defense_tendency", 0)), -3, 3)
	fast_ting_priority = clampi(fast_ting_priority + int(adjustments.get("fast_ting_priority", 0)), 0, 4)
	self_draw_priority = clampi(self_draw_priority + int(adjustments.get("self_draw_priority", 0)), 0, 4)
	forced_cleanup_tendency = clampi(forced_cleanup_tendency + int(adjustments.get("forced_cleanup_tendency", 0)), 0, 4)
	big_hand_tendency = clampi(big_hand_tendency + int(adjustments.get("big_hand_tendency", 0)), 0, 4)
	opponent_read_tendency = clampi(opponent_read_tendency + int(adjustments.get("opponent_read_tendency", 0)), 0, 4)


func set_diagnostics_recording_enabled(enabled: bool) -> void:
	diagnostics_recording_enabled = enabled
	hell_record_oracle = enabled and preset_name == PRESET_HELL
	hell_log_marked_cases = enabled and preset_name == PRESET_HELL


func to_debug_dict() -> Dictionary:
	return {
		"preset_name": preset_name,
		"lookahead_candidate_count": lookahead_candidate_count,
		"lookahead_draw_samples": lookahead_draw_samples,
		"add_gang_min_score": add_gang_min_score,
		"an_gang_min_score": an_gang_min_score,
		"beginner_random_pool_start_ratio": beginner_random_pool_start_ratio,
		"intermediate_top_pick_count": intermediate_top_pick_count,
		"attack_tendency": attack_tendency,
		"defense_tendency": defense_tendency,
		"fast_ting_priority": fast_ting_priority,
		"self_draw_priority": self_draw_priority,
		"forced_cleanup_tendency": forced_cleanup_tendency,
		"big_hand_tendency": big_hand_tendency,
		"opponent_read_tendency": opponent_read_tendency,
		"endgame_absolute_defense": endgame_absolute_defense,
		"auto_learning_enabled": auto_learning_enabled,
		"hell_ai_share_ai_hands": hell_ai_share_ai_hands,
		"hell_ai_can_see_human_hand": hell_ai_can_see_human_hand,
		"hell_ai_can_see_wall": hell_ai_can_see_wall,
		"hell_record_oracle": hell_record_oracle,
		"hell_execute_oracle_action": hell_execute_oracle_action,
		"hell_log_marked_cases": hell_log_marked_cases,
		"diagnostics_recording_enabled": diagnostics_recording_enabled,
		"learning_adjustment": learning_adjustment.duplicate(true),
	}
