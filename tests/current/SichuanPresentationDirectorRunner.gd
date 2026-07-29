extends SceneTree

const DIRECTOR_SCRIPT := preload("res://scripts/ui/presentation/TablePresentationDirector.gd")
const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")

var evidence: Dictionary = {
	"criteria": ["AC-PRES-01", "AC-PRES-02", "AC-PRES-03"],
	"objective_result": "PASS",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var director := DIRECTOR_SCRIPT.new() as Node
	director.set("auto_advance", false)
	get_root().add_child(director)
	await process_frame

	_verify_read_only_architecture(director, failures)
	_verify_twenty_refresh_dedup(director, failures)
	_verify_priority_and_non_interruptible_motion(director, failures)
	_verify_round_reset(director, failures)
	await _verify_main_scene_integration(failures)

	director.queue_free()
	await process_frame
	evidence["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	evidence["failures"] = failures
	_write_evidence(failures)
	if failures.is_empty():
		print("SICHUAN PRESENTATION DIRECTOR OK: READ-ONLY + 20/20 DEDUP + PRIORITY")
		quit(0)
		return
	push_error("SICHUAN PRESENTATION DIRECTOR FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_read_only_architecture(director: Node, failures: Array[String]) -> void:
	var contract: Dictionary = director.call("get_dependency_contract")
	var layers: Dictionary = contract.get("layers", {})
	var required_layers := ["TileMotionLayer", "CalloutFxLayer", "ScoreDeltaLayer", "TurnIndicatorLayer", "ResultTransitionLayer"]
	if str(contract.get("direction", "")) != "snapshot_to_presentation_only" \
		or bool(contract.get("writes_game_state", true)) \
		or bool(contract.get("writes_score_state", true)) \
		or bool(contract.get("writes_ai_state", true)):
		failures.append("presentation dependency contract is not strictly read-only")
	for layer_name in required_layers:
		if not layers.has(layer_name):
			failures.append("missing presentation responsibility layer: %s" % layer_name)
			continue
		var layer_contract: Dictionary = layers[layer_name]
		if bool(layer_contract.get("writes_game_state", true)) \
			or bool(layer_contract.get("writes_score_state", true)) \
			or bool(layer_contract.get("writes_ai_state", true)):
			failures.append("layer can write gameplay state: %s" % layer_name)
	var source := FileAccess.get_file_as_string("res://scripts/ui/presentation/TablePresentationDirector.gd")
	var forbidden_mutation_tokens: Array[String] = [
		"game_manager.",
		".game_state",
		"score_resolver",
		"discard_tile(",
		"choose_ding_que(",
		"resolve_reaction(",
		"perform_ai_",
	]
	var forbidden_hits: Array[String] = []
	for token in forbidden_mutation_tokens:
		if source.contains(token):
			forbidden_hits.append(token)
	if not forbidden_hits.is_empty():
		failures.append("presentation director source imports gameplay mutation APIs: %s" % forbidden_hits)
	evidence["architecture"] = contract
	evidence["source_audit"] = {
		"path": "res://scripts/ui/presentation/TablePresentationDirector.gd",
		"forbidden_mutation_tokens": forbidden_mutation_tokens,
		"hits": forbidden_hits,
		"result": "PASS" if forbidden_hits.is_empty() else "FAIL",
	}


func _verify_twenty_refresh_dedup(director: Node, failures: Array[String]) -> void:
	var previous := _base_snapshot(1)
	var current := previous.duplicate(true)
	current["turn_index"] = 7
	current["discard_count"] = 1
	current["players"][0]["discards"] = [_tile(101)]
	current["players"][1]["melds"] = [{
		"type": "peng", "source_seat": 0, "source_tile_id": 202,
		"tiles": [_tile(201), _tile(202), _tile(203)],
	}]
	current["players"][2]["melds"] = [{
		"type": "gang", "gang_subtype": "an_gang", "source_seat": 2, "source_tile_id": 303,
		"tiles": [_tile(301), _tile(302), _tile(303), _tile(304)],
	}]
	current["settlement_data"] = {
		"event_index": 5,
		"score_changes": {0: 11, 1: -2, 2: -2, 3: -7},
		"win_events": [{
			"winner_seat": 3,
			"source_seat": 0,
			"winning_tile": _tile(404),
			"win_type": "discard_win",
		}],
	}
	var stable_refresh := current.duplicate(true)
	director.call("consume_snapshot", previous, current)
	# Mutating the caller-owned dictionary after consumption must not change any
	# pending presentation payload.
	current["settlement_data"]["win_events"][0]["winning_tile"]["id"] = 999
	for _refresh in range(20):
		director.call("consume_snapshot", stable_refresh, stable_refresh)

	var expected_signatures: Array[String] = [
		"discard:1:7:0:101",
		"peng:1:1:0:202",
		"gang:1:2:an_gang:303",
		"win:1:3:0:404",
		"score:1:5:0:11",
		"score:1:5:1:-2",
		"score:1:5:2:-2",
		"score:1:5:3:-7",
	]
	var state: Dictionary = director.call("get_state_contract")
	var played: Array = state.get("played_signatures", [])
	for signature in expected_signatures:
		if played.count(signature) != 1:
			failures.append("signature was not persisted exactly once after 20 refreshes: %s" % signature)
	if played.size() != expected_signatures.size():
		failures.append("20/20 dedup produced unexpected signature count: %d" % played.size())
	_drain_director(director)
	var start_counts: Dictionary = {}
	for entry in director.call("get_event_log"):
		if str(entry.get("phase", "")) != "started":
			continue
		var signature := str(entry.get("signature", ""))
		start_counts[signature] = int(start_counts.get(signature, 0)) + 1
	for signature in expected_signatures:
		if int(start_counts.get(signature, 0)) != 1:
			failures.append("event played more or less than once: %s" % signature)
	var result_layer: Node = director.call("get_layer", "ResultTransitionLayer")
	var result_log: Array = result_layer.get("presentation_log")
	if result_log.size() != 1 or int(result_log[0].get("tile_id", -1)) != 404 \
		or int(result_log[0].get("payload", {}).get("winning_tile", {}).get("id", -1)) != 404:
		failures.append("director retained a mutable caller snapshot reference")
	evidence["dedup_20_refreshes"] = {
		"refresh_count": 20,
		"expected_signatures": expected_signatures,
		"played_signature_count": played.size(),
		"start_counts": start_counts,
		"result_payload_tile_id_after_caller_mutation": int(result_log[0].get("tile_id", -1)) if not result_log.is_empty() else -1,
	}


func _verify_priority_and_non_interruptible_motion(director: Node, failures: Array[String]) -> void:
	director.call("reset_for_round", 10)
	director.call("enqueue_event", {"kind": "tip", "signature": "tip:10:idle"})
	director.call("enqueue_event", {"kind": "discard", "signature": "discard:10:1:0:501"})
	var state: Dictionary = director.call("get_state_contract")
	if str(state.get("active_signature", "")) != "discard:10:1:0:501":
		failures.append("high-priority discard did not interrupt a low decorative tip")
	director.call("enqueue_event", {"kind": "win", "signature": "win:10:3:0:601"})
	state = director.call("get_state_contract")
	if str(state.get("active_signature", "")) != "discard:10:1:0:501" \
		or not bool(state.get("active_is_critical_motion", false)):
		failures.append("win interrupted an in-flight critical tile displacement")
	for event in [
		{"kind": "gang", "signature": "gang:10:2:add_gang:602"},
		{"kind": "peng", "signature": "peng:10:1:0:603"},
		{"kind": "draw", "signature": "draw:10:2:2:604"},
		{"kind": "score", "signature": "score:10:1:0:4"},
		{"kind": "tip", "signature": "tip:10:tail"},
	]:
		director.call("enqueue_event", event)
	director.call("complete_active_event")
	var ordered_after_critical: Array[String] = []
	while true:
		state = director.call("get_state_contract")
		var active_signature := str(state.get("active_signature", ""))
		if active_signature.is_empty():
			break
		ordered_after_critical.append(str(state.get("active_kind", "")))
		director.call("complete_active_event")
	var expected_order: Array[String] = ["win", "gang", "peng", "draw", "score", "tip"]
	if ordered_after_critical != expected_order:
		failures.append("presentation priority order mismatch: %s" % ordered_after_critical)
	director.call("enqueue_event", {"kind": "draw", "signature": "draw:10:9:0:700"})
	director.call("enqueue_event", {"kind": "score", "signature": "score:10:9:0:1"})
	director.call("clear_queue_stably")
	state = director.call("get_state_contract")
	if not str(state.get("active_signature", "")).is_empty() or not (state.get("pending_signatures", []) as Array).is_empty():
		failures.append("queue clear left an unstable active or pending node state")
	evidence["priority"] = {
		"declared_order": state.get("priority_order", []),
		"observed_after_critical_discard": ordered_after_critical,
		"critical_discard_was_not_interrupted": true,
		"stable_after_clear": true,
	}


func _verify_round_reset(director: Node, failures: Array[String]) -> void:
	director.call("consume_snapshot", _base_snapshot(10), _base_snapshot(11))
	var state: Dictionary = director.call("get_state_contract")
	if int(state.get("active_round", -1)) != 11 or not (state.get("played_signatures", []) as Array).is_empty():
		failures.append("new round did not safely clear persistent presentation signatures")
	evidence["new_round_reset"] = {
		"active_round": state.get("active_round"),
		"played_signature_count": (state.get("played_signatures", []) as Array).size(),
	}


func _verify_main_scene_integration(failures: Array[String]) -> void:
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var director := scene.get("table_presentation_director") as Node
	if director == null or director.name != "TablePresentationDirector":
		failures.append("MainSceneV2 did not mount the read-only presentation director")
	else:
		var contract: Dictionary = director.call("get_dependency_contract")
		if str(contract.get("direction", "")) != "snapshot_to_presentation_only":
			failures.append("MainSceneV2 mounted a director without the read-only contract")
	scene.queue_free()
	await process_frame
	await process_frame


func _drain_director(director: Node) -> void:
	while true:
		var state: Dictionary = director.call("get_state_contract")
		if str(state.get("active_signature", "")).is_empty():
			return
		director.call("complete_active_event")


func _base_snapshot(round_index: int) -> Dictionary:
	var players: Array = []
	for seat in range(4):
		players.append({"seat": seat, "discards": [], "melds": []})
	return {
		"round_index": round_index,
		"turn_index": 0,
		"discard_count": 0,
		"recent_draw_display": "",
		"players": players,
		"settlement_data": {},
	}


func _tile(id: int) -> Dictionary:
	return {"id": id, "suit": "wan", "rank": id % 9 + 1}


func _write_evidence(failures: Array[String]) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
			break
	if output_path.is_empty():
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write presentation director evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify(evidence, "  "))
