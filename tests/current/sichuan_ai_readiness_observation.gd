extends "res://tests/current/sichuan_ai_pressure_benchmark.gd"

var readiness_rows: Array = []
var observed: Dictionary = {}
var diagnostic_runtime: Object

func _prepare_all_ai_table(game_state: Node) -> void:
	super._prepare_all_ai_table(game_state)
	if int(game_state.get("current_phase")) != 5:
		return
	var wall: int = int(game_state.get("wall_count"))
	if wall % 4 != 0:
		return
	var observer: int = int(game_state.get("current_turn_seat"))
	var round_id: int = int(game_state.get("round_index"))
	var key := "%d:%d:%d" % [round_id, wall, observer]
	if observed.has(key):
		return
	observed[key] = true
	var manager = game_state.get("ai_manager")
	diagnostic_runtime = manager.native_csharp_runtime
	var payload: Dictionary = manager.csharp_bridge.build_discard_transport_payload(
		game_state.call("_build_player_state", observer), game_state.call("_build_table_state"), game_state.get("rules"))
	var compact: String = str(manager.native_csharp_runtime.call("DiagnosePublicReadinessCompact", JSON.stringify(payload)))
	for line in compact.split(";", false):
		var values := line.split(",")
		if values.size() != 11:
			push_error("Invalid readiness diagnostic transport")
			quit(1)
			return
		var seat := int(values[0])
		# Hidden truth is read only AFTER the public prediction has returned.
		var player: Dictionary = game_state.call("_build_player_state", seat)
		var waits: Array = game_state.get("mahjong_judge").get_ting_tiles(player, game_state.get("rules"))
		var row := {"round": round_id, "observer": observer, "seat": seat,
			"truth": 1 if not waits.is_empty() else 0, "features": []}
		for index in range(1, values.size()):
			row.features.append(float(values[index]))
		readiness_rows.append(row)

func _write_report(stats: Dictionary, output_path: String) -> void:
	if is_instance_valid(diagnostic_runtime) and diagnostic_runtime.has_method("GetContinuationDiagnosticsCompact"):
		stats["continuation_diagnostics"] = diagnostic_runtime.call("GetContinuationDiagnosticsCompact")
	stats["readiness_observations"] = readiness_rows
	stats["readiness_feature_order"] = ["prediction", "wall", "melds", "discards",
		"turns_since_nonmissing", "recent_hand", "recent_draw", "recent_central", "last_missing", "cleared"]
	super._write_report(stats, output_path)
