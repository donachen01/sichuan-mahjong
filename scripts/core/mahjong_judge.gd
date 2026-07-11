extends RefCounted

class_name MahjongJudge

const HuCheckerScript := preload("res://scripts/core/hu_checker.gd")
const ReactionResolverScript := preload("res://scripts/core/reaction_resolver.gd")
const ShantenAnalyzerScript := preload("res://scripts/core/shanten_analyzer.gd")
const DiscardAdvisorScript := preload("res://scripts/core/discard_advisor.gd")
const RiskAnalyzerScript := preload("res://scripts/core/risk_analyzer.gd")

var hu_checker = HuCheckerScript.new()
var reaction_resolver = ReactionResolverScript.new()
var shanten_analyzer = ShantenAnalyzerScript.new()
var discard_advisor = DiscardAdvisorScript.new()
var risk_analyzer = RiskAnalyzerScript.new()


func can_player_self_hu(player_state: Dictionary, rules_config) -> bool:
	return hu_checker.can_hu_with_player_state(player_state, rules_config)


func can_hu_on_discard(player_state: Dictionary, discarded_tile: Dictionary, rules_config) -> bool:
	return hu_checker.can_hu_on_discard(player_state, discarded_tile, rules_config)


func build_reaction_candidates(table_state: Dictionary, discard_context: Dictionary, rules_config) -> Array[Dictionary]:
	return reaction_resolver.build_reaction_candidates(table_state.get("players", []), discard_context, rules_config)


func summarize_candidates(candidates: Array) -> String:
	return reaction_resolver.summarize_candidates(candidates)


func get_candidate_priority(candidate: Dictionary) -> int:
	return reaction_resolver.get_candidate_priority(candidate)


func get_ting_tiles(player_state: Dictionary, rules_config) -> Array:
	return hu_checker.get_ting_tiles(
		player_state.get("hand_tiles", []),
		str(player_state.get("ding_que", "")),
		rules_config,
		int(player_state.get("melds", []).size()),
		player_state.get("melds", [])
	)


func analyze_shanten(player_state: Dictionary, rules_config) -> Dictionary:
	return shanten_analyzer.analyze_hand(
		player_state.get("hand_tiles", []),
		int(player_state.get("melds", []).size()),
		bool(rules_config.enable_qi_dui)
	)


func analyze_discard_options(
	player_state: Dictionary,
	table_state: Dictionary,
	rules_config,
	allow_cheat: bool = false,
	enable_lookahead: bool = true,
	ai_config = null
) -> Dictionary:
	return discard_advisor.analyze_discard_options(
		player_state,
		table_state.get("players", []),
		rules_config,
		hu_checker,
		shanten_analyzer,
		risk_analyzer,
		allow_cheat,
		enable_lookahead,
		ai_config
	)


func analyze_discard_risk(
	tile: Dictionary,
	discarder_seat: int,
	table_state: Dictionary,
	rules_config,
	allow_cheat: bool = false
) -> Dictionary:
	return risk_analyzer.analyze_discard_risk(
		tile,
		discarder_seat,
		table_state.get("players", []),
		hu_checker,
		rules_config,
		allow_cheat
	)
