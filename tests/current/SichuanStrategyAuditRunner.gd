extends SceneTree

const GAME := preload("res://autoload/GameState.gd")
var failures: Array[String] = []
var checks: Array[Dictionary] = []

func check_case(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})
	if not passed:
		failures.append(label)

func _init() -> void:
	await process_frame
	var game = GAME.new()
	root.add_child(game)
	await process_frame
	game.set_research_recording_enabled(true)
	game.set_test_seed(20260930)
	game.start_new_round()
	game.current_dealer_seat = 0
	game.current_turn_seat = 0
	check_case("deal_initializes_agents", game.complete_opening_roll())
	var runtime: Object = game.ai_manager.native_csharp_runtime
	check_case("exactly_three_native_agents", int(runtime.call("GetActiveRoundAgentCount")) == 3)
	var old_id: String = game.ai_agent_round_id
	var old_views: Array = game._agent_views()
	var records: Array = []
	for view in old_views:
		var item = JSON.parse_string(str(runtime.call("InspectRoundAgentJson", JSON.stringify(view))))
		records.append(item)
		check_case("seat_%d_confirmed_plan_phase" % int(view["seatIndex"]), str(item.get("Plan", {}).get("HandPhase", "")) != "opening")
		check_case("seat_%d_has_plan_and_dingque" % int(view["seatIndex"]), item.get("Plan") != null and item.get("OpeningDecision") != null)
		check_case("seat_%d_three_opponents" % int(view["seatIndex"]), item.get("Opponents", []).size() == 3)
	game._sync_round_agents()
	var same = JSON.parse_string(str(runtime.call("InspectRoundAgentJson", JSON.stringify(old_views[0]))))
	check_case("repeated_sync_does_not_repeat_history", same.get("ConfirmedHistory", []) == records[0].get("ConfirmedHistory", []))
	var checkpoints: Array = game.ai_manager.capture_round_agent_memories(old_views)
	var end_message := {"operation": "end", "roundId": old_id, "hostGeneration": game.ai_agent_generation}
	var ended = JSON.parse_string(str(runtime.call("UpdateRoundAgentsJson", JSON.stringify(end_message))))
	check_case("native_checkpoint_close", bool(ended.get("ok", false)))
	game.ai_agent_generation += 1
	var restore_views: Array = old_views.duplicate(true)
	for view in restore_views:
		view["hostGeneration"] = game.ai_agent_generation
	var restored: bool = game.ai_manager.update_round_agents("restore", restore_views, "", 0, checkpoints)
	check_case("native_checkpoint_json_restore", restored and int(runtime.call("GetActiveRoundAgentCount")) == 3)
	game._sync_round_agents()
	check_case("restored_generation_accepts_live_observations", str(game.ai_manager.last_native_turn_error).is_empty())
	game.start_new_round()
	check_case("restart_disposes_old_agents_before_deal", int(runtime.call("GetActiveRoundAgentCount")) == 0)
	game.current_dealer_seat = 0
	game.current_turn_seat = 0
	check_case("next_deal_recreates_three", game.complete_opening_roll() and int(runtime.call("GetActiveRoundAgentCount")) == 3)
	check_case("new_unique_round", game.ai_agent_round_id != old_id)
	var stale = JSON.parse_string(str(runtime.call("InspectRoundAgentJson", JSON.stringify(old_views[0]))))
	check_case("old_identity_rejected", str(stale.get("error", "")) == "inactive_or_stale_round")
	game.abort_agent_round()
	check_case("exit_disposes_all", int(runtime.call("GetActiveRoundAgentCount")) == 0)
	var baseline: Dictionary = integer_payload(JSON.parse_string(FileAccess.get_file_as_string("res://evidence/hu_income_cost_20260930/book_reaction.json")))
	baseline["dingQueSuits"] = [0,1,1,0]
	for index in range(2):
		baseline["publicEvents"].append({"eventIndex": index+2, "turnIndex": index+2, "seat": 0, "type": "pass", "tileType": 11, "sourceSeat": 1, "canHu": true})
	var reaction = JSON.parse_string(str(runtime.call("AnalyzeReactionJson", JSON.stringify(baseline))))
	var compact: String = str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(baseline), false))
	check_case("shared_exit_native_hu", reaction.get("action", "") == "hu" and compact.begins_with("ok|hu|"))
	var discard := baseline.duplicate(true)
	discard["hand18"][0] = 1
	discard["remaining18"][0] = 3
	discard["handCounts"][0] = 14
	discard["currentSeat"] = 0
	var discard_result: String = str(runtime.call("AnalyzeDiscardAotCompact", JSON.stringify(discard), false))
	check_case("forced_discard_native_compact", discard_result.begins_with("ok|discard|0|"))
	var audit_path: String = str(runtime.call("GetDecisionAuditPath"))
	check_case("audit_file_exists", FileAccess.file_exists(audit_path))
	check_case("audit_storage_no_error", str(runtime.call("GetDecisionAuditError")).is_empty())
	var replay = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(replay)
	replay.set("DecisionAuditEnabled", false)
	var audit_file := FileAccess.open(audit_path, FileAccess.READ)
	var replay_count := 0
	var saw_confirmed := false
	while audit_file != null and not audit_file.eof_reached():
		var line := audit_file.get_line()
		if line.is_empty():
			continue
		var entry = JSON.parse_string(line)
		var raw_response: String = str(replay.call("ReplayDecisionAuditEntry", line))
		var response = JSON.parse_string(raw_response) if not str(entry["method"]).ends_with("Compact") else {"compact_action": "|".join(raw_response.split("|").slice(0,3))}
		var expected = JSON.parse_string(str(entry["response"])) if not str(entry["method"]).ends_with("Compact") else {"compact_action": "|".join(str(entry["response"]).split("|").slice(0,3))}
		var agrees: bool = typeof(response) == TYPE_DICTIONARY and typeof(expected) == TYPE_DICTIONARY
		for key in ["ok", "error", "suit", "action", "actionType", "tileType", "gangSubtype", "compact_action"]:
			if expected.has(key):
				agrees = agrees and response.get(key) == expected[key]
		check_case("replay_%d_%s" % [replay_count, entry["method"]], agrees)
		saw_confirmed = saw_confirmed or str(entry["snapshotsBefore"]).contains('"Status":"executed"') or str(entry["snapshotsAfter"]).contains('"Status":"executed"')
		replay_count += 1
	check_case("replay_has_real_decisions", replay_count > 5)
	check_case("journal_contains_execution_confirmation", saw_confirmed)
	if audit_file != null:
		audit_file.close()
	print("STRATEGY_AUDIT replay_entries=%d path=%s" % [replay_count, audit_path])
	replay.queue_free()
	var output_path: String = "res://evidence/strategy_unification_20261001/runtime.json"
	if not OS.get_cmdline_user_args().is_empty():
		output_path = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "opening_agents": records}, "\t"))
	file.close()
	print("ROUND_AGENT_RUNTIME checks=%d failures=%s" % [checks.size(), str(failures)])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func integer_payload(value):
	if value is float:
		return int(value)
	if value is Array:
		return value.map(integer_payload)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = integer_payload(value[key])
		return result
	return value
