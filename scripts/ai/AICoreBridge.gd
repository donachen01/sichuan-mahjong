extends RefCounted

class_name AICoreBridge

const DecisionEngineScript := preload("res://scripts/ai/sichuan_decision_engine.gd")

var decision_engine = DecisionEngineScript.new()


func build_discard_payload(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, allow_cheat: bool = false) -> Dictionary:
	return {
		"player": player_state.duplicate(true),
		"players": table_state.get("players", []).duplicate(true),
		"rules": rules_config,
		"ai_config": ai_config,
		"allow_cheat": allow_cheat,
	}


func request_discard(payload: Dictionary, hu_checker, risk_analyzer) -> Dictionary:
	return decision_engine.analyze_discard_options(
		payload.get("player", {}),
		payload.get("players", []),
		payload.get("rules"),
		hu_checker,
		risk_analyzer,
		payload.get("ai_config"),
		bool(payload.get("allow_cheat", false))
	)


func request_discard_support(payload: Dictionary, hu_checker, risk_analyzer) -> Dictionary:
	return decision_engine.build_support_context(
		payload.get("player", {}),
		payload.get("players", []),
		payload.get("rules"),
		hu_checker,
		risk_analyzer,
		payload.get("ai_config"),
		bool(payload.get("allow_cheat", false))
	)


func build_reaction_payload(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, allow_cheat: bool = false) -> Dictionary:
	return {
		"candidate": candidate.duplicate(true),
		"player": player_state.duplicate(true),
		"players": table_state.get("players", []).duplicate(true),
		"discard_context": discard_context.duplicate(true),
		"rules": rules_config,
		"ai_config": ai_config,
		"allow_cheat": allow_cheat,
	}


func request_reaction(payload: Dictionary, hu_checker) -> Dictionary:
	return decision_engine.choose_reaction(
		payload.get("candidate", {}),
		payload.get("player", {}),
		payload.get("players", []),
		payload.get("discard_context", {}),
		payload.get("rules"),
		hu_checker,
		payload.get("ai_config")
	)
