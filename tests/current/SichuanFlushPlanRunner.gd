extends SceneTree
const GAME := preload("res://autoload/GameState.gd")
func _init() -> void:
	await process_frame
	var game = GAME.new()
	root.add_child(game)
	await process_frame
	game.set_test_seed(20261001)
	game.start_new_round()
	game.current_dealer_seat = 0
	game.current_turn_seat = 0
	var passed: bool = game.complete_opening_roll()
	var records: Array = []
	for view in game._agent_views():
		var raw := str(game.ai_manager.native_csharp_runtime.call("InspectRoundAgentJson", JSON.stringify(view)))
		var record = JSON.parse_string(raw)
		var routes: Array = record.get("Plan", {}).get("FlushRoutes", [])
		passed = passed and routes.size() == 3
		passed = passed and record.get("Plan", {}).has("RouteContinuations")
		for route in routes:
			passed = passed and route.has("MinimumAdditionalTilesToWin") and route.has("EffectiveDraws") and route.has("Improvements")
		records.append(record)
	var output_path: String = "res://research/round_agents_20260930/flush-audit/runtime.json"
	if not OS.get_cmdline_user_args().is_empty():
		output_path = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "agents": records}, "\t"))
	file.close()
	game.abort_agent_round()
	game.queue_free()
	await process_frame
	print("FLUSH_PLAN_RUNTIME passed=", passed, " agents=", records.size())
	quit(0 if passed else 1)
