extends Node

class_name GameManager

signal snapshot_changed(snapshot: Dictionary)
signal opening_roll_started(data: Dictionary)

@onready var game_state: Node = get_node("/root/GameState")

var latest_snapshot: Dictionary = {}


func _ready() -> void:
	if game_state != null and game_state.has_signal("state_changed"):
		game_state.state_changed.connect(_on_state_changed)
	if game_state != null and game_state.has_signal("opening_roll_started"):
		game_state.opening_roll_started.connect(_on_opening_roll_started)
		_emit_snapshot()


func get_snapshot() -> Dictionary:
	if game_state == null:
		return {}
	if not latest_snapshot.is_empty():
		return latest_snapshot.duplicate(true)
	return game_state.call("get_debug_snapshot")


func get_fresh_snapshot() -> Dictionary:
	if game_state == null:
		return {}
	latest_snapshot = game_state.call("get_debug_snapshot")
	return latest_snapshot.duplicate(true)


func set_human_trainer_hint_enabled(enabled: bool) -> void:
	if game_state == null:
		return
	game_state.call("set_human_trainer_hint_enabled", enabled)


func set_ai_level(level: int) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_level", level))


func set_ai_preset(preset_name: String) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_preset", preset_name))


func mark_current_hell_training_case(reason: String = "manual_mark") -> bool:
	return false if game_state == null else bool(game_state.call("mark_current_hell_training_case", reason))


func set_hell_diagnostics_recording_enabled(enabled: bool) -> bool:
	return false if game_state == null else bool(game_state.call("set_hell_diagnostics_recording_enabled", enabled))


func export_diagnostic_package() -> Dictionary:
	if game_state == null or not game_state.has_method("export_diagnostic_package"):
		return {"ok": false, "error": "game_state_export_unavailable"}
	return game_state.call("export_diagnostic_package")


func set_ai_tuning_value(key: String, value: int) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_tuning_value", key, value))


func reset_ai_tuning_overrides() -> bool:
	return false if game_state == null else bool(game_state.call("reset_ai_tuning_overrides"))


func set_ai_auto_learning_enabled(enabled: bool) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_auto_learning_enabled", enabled))


func set_ai_endgame_absolute_defense_enabled(enabled: bool) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_endgame_absolute_defense_enabled", enabled))


func apply_bone_ash_recommended_tuning() -> bool:
	return false if game_state == null else bool(game_state.call("apply_bone_ash_recommended_tuning"))


func set_ai_prefer_csharp_backend(enabled: bool) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_prefer_csharp_backend", enabled))


func set_ai_csharp_host_mode_enabled(enabled: bool, port: int = 38581) -> bool:
	return false if game_state == null else bool(game_state.call("set_ai_csharp_host_mode_enabled", enabled, port))


func advance_to_next_round() -> bool:
	return false if game_state == null else bool(game_state.call("advance_to_next_round"))


func complete_opening_roll() -> bool:
	return false if game_state == null else bool(game_state.call("complete_opening_roll"))


func discard_tile(tile_id: int) -> bool:
	return false if game_state == null else bool(game_state.call("discard_tile_by_id", 0, tile_id))


func choose_ding_que(suit: String) -> bool:
	return false if game_state == null else bool(game_state.call("choose_ding_que", 0, suit))


func get_human_reaction_options() -> Dictionary:
	return {} if game_state == null else game_state.call("get_human_reaction_options", 0)


func can_human_add_gang() -> bool:
	return false if game_state == null else bool(game_state.call("can_human_add_gang", 0))


func can_human_an_gang() -> bool:
	return false if game_state == null else bool(game_state.call("can_human_an_gang", 0))


func can_human_bao_jiao() -> bool:
	return false if game_state == null else bool(game_state.call("can_human_bao_jiao", 0))


func execute_action(action: String) -> bool:
	if game_state == null:
		return false
	match action:
		"hu":
			return bool(game_state.call("execute_human_hu", 0))
		"self_hu":
			return bool(game_state.call("execute_human_self_hu", 0))
		"pass_self_hu":
			return bool(game_state.call("pass_human_self_hu", 0))
		"peng":
			return bool(game_state.call("execute_human_peng", 0))
		"gang":
			return bool(game_state.call("execute_human_gang", 0))
		"add_gang":
			return bool(game_state.call("execute_human_add_gang", 0))
		"an_gang":
			return bool(game_state.call("execute_human_an_gang", 0))
		"bao_jiao":
			return bool(game_state.call("execute_human_bao_jiao", 0))
		"pass_opening_bao_jiao":
			return bool(game_state.call("pass_human_opening_bao_jiao", 0))
		"pass":
			return bool(game_state.call("pass_human_reaction", 0))
		_:
			return false


func is_ai_turn_ready() -> bool:
	return false if game_state == null else bool(game_state.call("is_ai_turn_ready"))


func is_ai_reaction_pending() -> bool:
	return false if game_state == null else bool(game_state.call("is_ai_reaction_pending"))


func run_ai_turn() -> bool:
	return false if game_state == null else bool(game_state.call("run_ai_turn"))


func prepare_ai_turn_decision() -> bool:
	return false if game_state == null else bool(game_state.call("prepare_ai_turn_decision"))


func prepare_ai_reaction_decision() -> bool:
	return false if game_state == null else bool(game_state.call("prepare_ai_reaction_decision"))


func run_ai_reaction() -> bool:
	return false if game_state == null else bool(game_state.call("run_ai_reaction"))


func pump_ai_background_requests() -> int:
	return 0 if game_state == null else int(game_state.call("pump_ai_background_requests"))


func _on_state_changed(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	snapshot_changed.emit(latest_snapshot.duplicate(true))


func _on_opening_roll_started(data: Dictionary) -> void:
	opening_roll_started.emit(data)


func _emit_snapshot() -> void:
	if game_state == null:
		return
	latest_snapshot = game_state.call("get_debug_snapshot")
	snapshot_changed.emit(latest_snapshot.duplicate(true))
