extends SceneTree
const GAME := preload("res://autoload/GameState.gd")
func _init() -> void:
	await process_frame
	var game = GAME.new()
	root.add_child(game)
	await process_frame
	var runtime: Object = game.ai_manager.native_csharp_runtime
	var passed := not bool(runtime.get("DecisionAuditEnabled")) and not game._is_runtime_recording_enabled()
	game.set_test_seed(20261002)
	game.start_new_round()
	game.current_dealer_seat = 0
	game.current_turn_seat = 0
	passed = passed and game.complete_opening_roll()
	for view in game._agent_views():
		var data = JSON.parse_string(str(runtime.call("InspectRoundAgentJson", JSON.stringify(view))))
		passed = passed and data.get("Decisions", []).is_empty() and data.get("Plan") != null and data.get("Proposal") != null
	passed = passed and str(runtime.call("GetDecisionAuditPath")).is_empty()
	passed = passed and game.debug_decision_trace_event_count == 0
	game.abort_agent_round()
	print("PRODUCTION_RECORDING default_off_no_file_no_research_trace_necessary_plan_preserved=", passed)
	game.queue_free()
	quit(0 if passed else 1)
