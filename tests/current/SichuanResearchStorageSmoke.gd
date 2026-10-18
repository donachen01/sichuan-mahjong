extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var configured := OS.get_environment("SICHUAN_RESEARCH_RECORD_ROOT")
	if configured.is_empty():
		push_error("explicit research root required")
		quit(1)
		return
	var state = load("res://autoload/GameState.gd").new()
	get_root().add_child(state)
	if state.call("_research_recording_path", "user://ai_analysis") != "user://ai_analysis":
		push_error("environment alone enabled research storage")
		quit(1)
		return
	state.call("set_research_recording_enabled", true)
	if not bool(state.get("research_recording_enabled")):
		push_error("desktop research opt-in failed")
		quit(1)
		return
	for path in ["user://ai_analysis", "user://ai_decision_trace", "user://ai_chain_debug.log"]:
		if str(state.call("_research_recording_path", path)) != configured.path_join(path.get_file()):
			push_error("research recorder still uses default path")
			quit(1)
			return
	var artifact: String = state.call("_ai_analysis_session_path")
	state.call("_write_json_file", artifact, {"research_storage_probe": true})
	if not FileAccess.file_exists(artifact):
		push_error("external research artifact was not written")
		quit(1)
		return
	state.call("set_research_recording_enabled", false)
	if state.call("_research_recording_path", "user://ai_analysis") != "user://ai_analysis":
		push_error("disabled recording retained research override")
		quit(1)
		return
	print("RESEARCH_STORAGE PASS: explicit desktop opt-in, analysis/trace/chain paths isolated, actual external write, default remains off")
	state.queue_free()
	quit()
