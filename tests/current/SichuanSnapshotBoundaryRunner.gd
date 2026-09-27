extends SceneTree

const Manager := preload("res://scripts/game/GameManager.gd")
const Projector := preload("res://scripts/network/snapshot_projector.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, reason: String) -> void:
	if not condition:
		failures.append(reason)


func _run() -> void:
	var state = root.get_node("GameState")
	state.set_test_seed(812)
	state.start_new_round()
	var manager := Manager.new()
	root.add_child(manager)
	await process_frame
	var projector := Projector.new()
	var original_phase: int = state.current_phase
	for phase in [2, 3, 5, 6, 7]:
		state.current_phase = phase
		for seat in range(4):
			var full: Dictionary = state.get_debug_snapshot(seat)
			var gameplay: Dictionary = state.get_gameplay_snapshot(seat)
			for key in gameplay:
				if key != "hell_training":
					_check(gameplay[key] == full[key], "phase %d seat %d gameplay field differs: %s" % [phase, seat, key])
			_check(not gameplay.has("ai_core_debug") and not gameplay.has("pending_ai_turn_decision"), "gameplay carries private diagnostic payload")
			_check(full.has("ai_core_debug") and full.has("pending_ai_turn_decision"), "diagnostic API lost fields")
			_check(projector.project(full, seat) == projector.project(gameplay, seat), "LAN projection changed for phase %d seat %d" % [phase, seat])
	state.current_phase = original_phase
	var detached: Dictionary = state.get_gameplay_snapshot()
	var original_hand_count: int = state.players[0].hand_tiles.size()
	detached.players[0].hand_tiles.append({"id": -100, "suit": "wan", "rank": 1})
	_check(state.players[0].hand_tiles.size() == original_hand_count, "snapshot mutation changed authority hand")
	var invalid_viewer: Dictionary = state.get_gameplay_snapshot(-1)
	_check(invalid_viewer == state.get_gameplay_snapshot(0), "invalid viewer no longer resolves to seat zero")
	state._emit_state_changed()
	var before: Dictionary = manager.get_snapshot()
	before.players.clear()
	_check(not manager.get_snapshot().players.is_empty(), "caller mutation changed manager snapshot")
	_check(not manager.get_snapshot().has("ai_core_debug"), "manager normal path still uses diagnostics")
	_check(manager.get_diagnostic_snapshot().has("ai_core_debug"), "explicit diagnostic request unavailable")
	manager.free()
	if failures.is_empty():
		print("SICHUAN_SNAPSHOT_BOUNDARY_PASS")
		quit(0)
	else:
		push_error("Snapshot boundary failures: " + "\n".join(failures))
		quit(1)
