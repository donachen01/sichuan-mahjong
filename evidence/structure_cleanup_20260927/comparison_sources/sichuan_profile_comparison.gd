extends SceneTree
const Main = preload("res://scenes/table/MainSceneV2.tscn")
const Original = preload("res://evidence/structure_cleanup_20260927/comparison_sources/sichuan_original_snapshot.gd")
const Profiler = preload("res://scripts/diagnostics/pipeline_profiler.gd")
func _initialize():
	call_deferred("_run")
func _run():
	var state = root.get_node("GameState")
	state.set_test_seed(812)
	state.start_new_round()
	var scene = Main.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var timing := {}
	var start := Time.get_ticks_usec()
	for i in range(300):
		Original.build(state)
	timing.original_debug_us = (Time.get_ticks_usec()-start)/300.0
	start = Time.get_ticks_usec()
	for i in range(300):
		state.get_gameplay_snapshot()
	timing.gameplay_us = (Time.get_ticks_usec()-start)/300.0
	var light: Dictionary = state.get_gameplay_snapshot()
	for i in range(5):
		scene._on_snapshot_changed(light)
	start = Time.get_ticks_usec()
	for i in range(30):
		scene._on_snapshot_changed(light)
	timing.ui_refresh_us = (Time.get_ticks_usec()-start)/30.0
	timing.original_bytes = JSON.stringify(Original.build(state)).length()
	timing.gameplay_bytes = JSON.stringify(light).length()
	timing.phase = int(state.current_phase)
	timing.hand_count = state.players[0].hand_tiles.size()
	Profiler.enabled = true
	Profiler.reset()
	scene._on_snapshot_changed(state.get_gameplay_snapshot())
	var event := InputEventScreenTouch.new()
	event.position = Vector2(-10,-10)
	event.pressed = true
	scene._input(event)
	timing.instrumentation = Profiler.summary()
	# This is an explicit synthetic history, not an observed phone workload.
	state.ai_reaction_review_history.clear()
	timing.synthetic_history_entries = state.AI_REACTION_REVIEW_LIMIT
	for i in range(state.AI_REACTION_REVIEW_LIMIT):
		state.ai_reaction_review_history.append({"event": i, "payload": "x".repeat(2048)})
	Profiler.enabled = false
	start = Time.get_ticks_usec()
	for i in range(40):
		Original.build(state)
	timing.synthetic_history_debug_us = (Time.get_ticks_usec()-start)/40.0
	start = Time.get_ticks_usec()
	for i in range(40):
		state.get_gameplay_snapshot()
	timing.synthetic_history_gameplay_us = (Time.get_ticks_usec()-start)/40.0
	var f := FileAccess.open("/tmp/sichuan_profile_comparison.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(timing,"  "))
	f.close()
	print("PIPELINE_COMPARISON ",JSON.stringify(timing))
	scene.queue_free()
	await process_frame
	quit(0)
