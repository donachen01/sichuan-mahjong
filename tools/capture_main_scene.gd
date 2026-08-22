extends SceneTree

const DEFAULT_OUTPUT_PATH := "user://capture_main_scene.png"
const SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"
const CALLOUT_LAYER_SCRIPT := preload("res://scripts/ui/presentation/CalloutFxLayer.gd")
const AUTO_DING_QUE_SUIT := "tong"
const MAX_AI_STEPS := 24
const CALLOUT_MODES: Array[String] = [
	"callout-peng",
	"callout-gang",
	"callout-hu",
	"callout-self-draw",
	"callout-gang-self-draw",
	"callout-qiang-gang-hu",
]
const MOTION_RECORD_MODES: Array[String] = [
	"motion-peng",
	"motion-melded-gang",
	"motion-add-gang",
	"motion-an-gang",
	"motion-self-draw",
	"motion-gang-self-draw",
	"motion-discard-win",
	"motion-qiang-gang-hu",
]
const MOTION_CAPTURE_FPS := 30
const MOTION_CAPTURE_SECONDS := 1.40
const PERFORMANCE_WARMUP_SECONDS := 60.0
const SETTLEMENT_TRANSITION_MODES: Array[String] = [
	"settlement-transition-normal",
	"settlement-transition-reduced",
]
const DEMO_DISCARDS := {
	0: [["tiao", 1], ["tiao", 3], ["tiao", 5], ["tong", 2], ["tong", 4], ["tong", 6], ["wan", 2], ["wan", 4], ["wan", 6], ["wan", 8]],
	1: [["wan", 1], ["wan", 2], ["wan", 3], ["tong", 5], ["tong", 6], ["tong", 7], ["tiao", 6], ["tiao", 7]],
	2: [["tong", 1], ["tong", 2], ["tong", 3], ["wan", 4], ["wan", 5], ["wan", 6], ["tiao", 7], ["tiao", 8], ["tiao", 9]],
	3: [["tiao", 2], ["tiao", 4], ["tiao", 6], ["tong", 7], ["tong", 8], ["tong", 9], ["wan", 7], ["wan", 9]],
}

var motion_evidence_snapshot: Dictionary = {}
var motion_evidence_hands: Array = []


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output_path := _capture_output_path()
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)

	await process_frame
	_force_playable_snapshot()
	_force_discard_demo()
	_log_self_hand_debug(root_node)

	await process_frame
	await process_frame
	_force_tabletop_polish_preview(root_node)
	_force_3d_full_table_preview(root_node)
	_force_self_hand_preview(root_node)
	_apply_choice_style_preview(root_node)
	_force_table_overlays_hidden(root_node)
	if _capture_mode() == "settlement":
		_force_settlement_preview(root_node)
	elif _capture_mode() in SETTLEMENT_TRANSITION_MODES:
		_force_clean_table_preview(root_node)
	elif _capture_mode() in ["ding-que", "ding-que-selected", "ding-que-reduced"]:
		_force_ding_que_preview(root_node)
	elif _capture_mode() in ["won", "self-draw", "ai-self-draw-1", "ai-self-draw-2", "ai-self-draw-3", "ai-discard-win", "ai-discard-win-1", "ai-discard-win-2", "ai-discard-win-3", "an-gang-static", "max-meld", "right-meld", "meld-pressure", "meld-source-matrix", "discard-pressure", "hud-current", "hud-current-reduced", "hud-won", "hud-score-plus", "hud-score-minus"]:
		_force_clean_table_preview(root_node)
		_force_hud_state_preview(root_node)
	elif _capture_mode() in ["response-hu", "self-hu", "gang-self-hu", "action-1", "action-2", "action-3", "action-4"]:
		_force_clean_table_preview(root_node)
		_force_action_bar_preview(root_node)
	elif _capture_mode() == "utility-expanded":
		_force_clean_table_preview(root_node)
		_force_utility_expanded_preview(root_node)
	elif _capture_mode() in ["clean", "camera"]:
		_force_clean_table_preview(root_node)
		if _capture_mode() == "clean":
			_force_action_bar_preview(root_node)
	elif _capture_mode() in CALLOUT_MODES or _capture_mode() in MOTION_RECORD_MODES:
		_force_clean_table_preview(root_node)
	else:
		_force_ai_helper_preview(root_node)
		_force_action_bar_preview(root_node)

	# Metal can expose a partially initialized frame on the first viewport read.
	# Warm the complete UI tree before collecting the evidence image.
	for _frame in range(12):
		await process_frame
	if _capture_mode() == "settlement":
		_force_settlement_preview(root_node)
		for _frame in range(4):
			await process_frame
	elif _capture_mode() in SETTLEMENT_TRANSITION_MODES:
		_force_clean_table_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["ding-que", "ding-que-selected", "ding-que-reduced"]:
		_force_ding_que_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["clean", "camera"]:
		_force_clean_table_preview(root_node)
		if _capture_mode() == "clean":
			_force_action_bar_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["won", "self-draw", "ai-self-draw-1", "ai-self-draw-2", "ai-self-draw-3", "ai-discard-win", "ai-discard-win-1", "ai-discard-win-2", "ai-discard-win-3", "an-gang-static", "max-meld", "right-meld", "meld-pressure", "meld-source-matrix", "discard-pressure", "hud-current", "hud-current-reduced", "hud-won", "hud-score-plus", "hud-score-minus"]:
		_force_clean_table_preview(root_node)
		_force_hud_state_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["response-hu", "self-hu", "gang-self-hu", "action-1", "action-2", "action-3", "action-4"]:
		_force_clean_table_preview(root_node)
		_force_action_bar_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() == "utility-expanded":
		_force_clean_table_preview(root_node)
		_force_utility_expanded_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in CALLOUT_MODES or _capture_mode() in MOTION_RECORD_MODES:
		_force_clean_table_preview(root_node)
		for _frame in range(2):
			await process_frame
	else:
		_force_ai_helper_preview(root_node)
		_force_action_bar_preview(root_node)
		for _frame in range(2):
			await process_frame
	_apply_choice_style_preview(root_node)
	_force_3d_full_table_preview(root_node)
	_apply_requested_table_skin(root_node)
	if _capture_mode() == "skin-panel":
		var skin_panel := root_node.get("table_skin_panel") as Control
		if skin_panel != null:
			skin_panel.call("open", _requested_table_skin_id())
			await process_frame
			await process_frame
	if _capture_mode() == "camera":
		_force_clean_table_preview(root_node)
	elif _capture_mode() in SETTLEMENT_TRANSITION_MODES:
		_force_clean_table_preview(root_node)
		await _record_settlement_transition(root_node)
		quit()
		return
	elif _capture_mode() in MOTION_RECORD_MODES:
		_force_clean_table_preview(root_node)
		_force_table_overlays_hidden(root_node)
		await _record_motion_evidence(root_node)
		quit()
		return
	elif _capture_mode() in ["hud-current", "hud-current-reduced", "hud-won", "hud-score-plus", "hud-score-minus"]:
		# The final 3D refresh reapplies its deterministic table snapshot, including
		# HUD scores. Restore the requested HUD evidence state after that refresh so
		# the captured signed delta and total score describe the same event.
		_force_hud_state_preview(root_node)
	elif _capture_mode() in CALLOUT_MODES:
		_force_clean_table_preview(root_node)
		_force_callout_preview(root_node)
		await create_timer(0.50).timeout
		_force_table_overlays_hidden(root_node)
		var preview_layer := root_node.get_node_or_null("EvidenceCalloutFxLayer")
		if preview_layer != null:
			print("callout_capture_state=", preview_layer.call("get_visual_state_contract"))
	RenderingServer.force_draw()
	await process_frame
	if _capture_mode() == "perf":
		await _profile_real_metal_frame_pacing(root_node)
		quit()
		return

	var image: Image = await _capture_stable_image()
	if image == null:
		push_error("Failed to capture viewport image")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(output_path)
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save capture: %s" % path)
		quit(1)
		return

	print(path)
	quit()


func _requested_table_skin_id() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--table-skin="):
			return argument.trim_prefix("--table-skin=")
	return "deep_emerald_crepe"


func _apply_requested_table_skin(root_node: Node) -> void:
	var requested_skin_id := _requested_table_skin_id()
	var stage := root_node.get("table_stage_3d") as Node3D
	if stage == null or not stage.has_method("apply_table_skin") \
			or not bool(stage.call("apply_table_skin", requested_skin_id)):
		push_error("Failed to apply requested table skin: %s" % requested_skin_id)
		return
	root_node.set("table_skin_id", requested_skin_id)
	var action_bar := root_node.get("table_action_bar") as Control
	if action_bar != null and action_bar.has_method("set_table_skin"):
		action_bar.call("set_table_skin", requested_skin_id)


func _profile_real_metal_frame_pacing(root_node: Node) -> void:
	# Measure the same dense 3D scene used by the screenshot runner in a real
	# window/Metal process.  Frame deltas include presentation pacing, so a 60 Hz
	# VSync build should settle close to 60 rather than reporting an artificial
	# uncapped headless number.
	var warmup_started_usec := Time.get_ticks_usec()
	await create_timer(PERFORMANCE_WARMUP_SECONDS).timeout
	var warmup_elapsed_seconds := float(Time.get_ticks_usec() - warmup_started_usec) / 1000000.0
	var frame_times_ms: Array[float] = []
	var previous_usec := Time.get_ticks_usec()
	for _sample in range(600):
		await process_frame
		var current_usec := Time.get_ticks_usec()
		frame_times_ms.append(float(current_usec - previous_usec) / 1000.0)
		previous_usec = current_usec
	frame_times_ms.sort()
	var total_ms := 0.0
	for frame_ms in frame_times_ms:
		total_ms += frame_ms
	var slow_count := maxi(1, int(ceil(float(frame_times_ms.size()) * 0.01)))
	var slow_total_ms := 0.0
	for index in range(frame_times_ms.size() - slow_count, frame_times_ms.size()):
		slow_total_ms += frame_times_ms[index]
	var average_frame_ms := total_ms / float(maxi(1, frame_times_ms.size()))
	var one_percent_frame_ms := slow_total_ms / float(slow_count)
	var profile := {
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")),
		"release_build": not OS.is_debug_build(),
		"godot_version": Engine.get_version_info(),
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"model_name": OS.get_model_name(),
		"processor_name": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"viewport": [get_root().size.x, get_root().size.y],
		"warmup_target_seconds": PERFORMANCE_WARMUP_SECONDS,
		"warmup_elapsed_seconds": warmup_elapsed_seconds,
		"frames": frame_times_ms.size(),
		"average_fps": 1000.0 / maxf(0.001, average_frame_ms),
		"one_percent_low_fps": 1000.0 / maxf(0.001, one_percent_frame_ms),
		"median_frame_ms": frame_times_ms[frame_times_ms.size() / 2],
		"p99_frame_ms": frame_times_ms[frame_times_ms.size() - slow_count],
		"maximum_frame_ms": frame_times_ms.back(),
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"static_memory_peak_mb": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0,
		"render_objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_draw_calls_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"table_stage_present": root_node.get("table_stage_3d") != null,
		"passed": not OS.is_debug_build() \
			and warmup_elapsed_seconds >= PERFORMANCE_WARMUP_SECONDS - 0.1 \
			and 1000.0 / maxf(0.001, average_frame_ms) >= 55.0 \
			and 1000.0 / maxf(0.001, one_percent_frame_ms) >= 45.0 \
			and Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0 <= 1200.0,
	}
	var output_path := _profile_output_path()
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write performance profile: %s" % absolute_path)
		return
	file.store_string(JSON.stringify(profile, "  ") + "\n")
	file.close()
	print(JSON.stringify(profile))
	print(absolute_path)


func _profile_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-output="):
			var value := argument.trim_prefix("--profile-output=")
			if not value.is_empty():
				return value
	return "user://sichuan_stage7_performance.json"


func _capture_stable_image() -> Image:
	var fallback: Image
	for attempt in range(8):
		for _frame in range(8):
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		fallback = get_root().get_texture().get_image()
		var black_ratio := _sample_near_black_ratio(fallback)
		if black_ratio <= 0.025:
			return fallback
		print("capture_retry=", attempt + 1, " sampled_black_ratio=", black_ratio)
	return fallback


func _sample_near_black_ratio(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var sample_step := 24
	var black_count := 0
	var sample_count := 0
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			var pixel := image.get_pixel(x, y)
			sample_count += 1
			if pixel.a >= 0.9 and pixel.r <= 0.03 and pixel.g <= 0.03 and pixel.b <= 0.03:
				black_count += 1
	return float(black_count) / float(maxi(1, sample_count))


func _capture_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			var value := argument.trim_prefix("--capture-output=")
			if value != "":
				return value
	return DEFAULT_OUTPUT_PATH


func _capture_mode() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-mode="):
			return argument.trim_prefix("--capture-mode=")
	return "table"


func _capture_turn_seat() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--turn-seat="):
			return clampi(int(argument.trim_prefix("--turn-seat=")), 0, 3)
	return -1


func _choice_variant(argument_name: String, default_value: int) -> int:
	for argument in OS.get_cmdline_user_args():
		var prefix := "--%s=" % argument_name
		if argument.begins_with(prefix):
			return clampi(int(argument.trim_prefix(prefix)), 0, 4)
	return default_value


func _apply_choice_style_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var nameplate_variant := _choice_variant("nameplate-style", 0)
	var draw_variant := _choice_variant("draw-style", 1)
	var selected_variant := _choice_variant("selected-style", 1)
	var huds: Dictionary = root_node.get("seat_huds") as Dictionary
	for hud_value in huds.values():
		var hud := hud_value as Control
		if hud != null and hud.has_method("set_nameplate_style_variant"):
			hud.call("set_nameplate_style_variant", nameplate_variant)
	var stage := root_node.get("table_stage_3d") as Node3D
	if stage != null:
		if stage.has_method("set_draw_marker_style_variant"):
			stage.call("set_draw_marker_style_variant", draw_variant)
		if stage.has_method("set_selected_marker_style_variant"):
			stage.call("set_selected_marker_style_variant", selected_variant)


func _force_callout_preview(root_node: Node) -> void:
	_force_table_overlays_hidden(root_node)
	var director: Node = root_node.get("table_presentation_director") as Node
	if director == null:
		return
	var action_bar: Control = root_node.get("table_action_bar") as Control
	if action_bar != null:
		action_bar.call("hide_actions")
	director.set("auto_advance", false)
	director.call("set_reduced_motion", false)
	director.call("reset_for_round", 900)
	var key := _capture_mode().trim_prefix("callout-")
	var event: Dictionary
	if key == "peng":
		event = {"kind": "peng", "signature": "peng:900:1:0:9001", "payload": {"type": "peng"}}
	elif key == "gang":
		event = {"kind": "gang", "signature": "gang:900:1:melded_gang:9002", "payload": {"gang_subtype": "melded_gang"}}
	else:
		var win_type: String = str({
			"hu": "discard_win",
			"self-draw": "self_draw",
			"gang-self-draw": "gang_self_draw",
			"qiang-gang-hu": "qiang_gang_hu",
		}.get(key, "discard_win"))
		event = {
			"kind": "win",
			"signature": "win:900:0:1:9003",
			"payload": {"win_type": win_type, "fan_detail": {"capped_fan": 3}},
		}
	# Drive the real mounted CalloutFxLayer directly for deterministic evidence.
	# GameState continues emitting snapshots during capture and may legitimately
	# reset the director queue; the visual layer itself is the runtime target being
	# verified here and still receives the same immutable normalized event shape.
	event["callout_delay_seconds"] = 0.22 if key == "peng" else (0.26 if key == "gang" else 0.24)
	# Use a fresh instance of the production layer so subsequent background
	# GameState snapshots cannot reset the deterministic evidence frame.
	var callout_layer := CALLOUT_LAYER_SCRIPT.new() as Node
	callout_layer.name = "EvidenceCalloutFxLayer"
	var accepted_kinds: Array[String] = ["peng", "gang", "win", "tip"]
	callout_layer.call("configure", "deterministic capture of production callout", accepted_kinds)
	root_node.add_child(callout_layer)
	callout_layer.call("present", event)


func _record_motion_evidence(root_node: Node) -> void:
	var stage := root_node.get("table_stage_3d") as Node3D
	if stage == null or motion_evidence_snapshot.is_empty() or motion_evidence_hands.is_empty():
		push_error("Motion evidence baseline is unavailable")
		return
	# Stop the live demo manager from advancing to settlement while the bounded
	# evidence sequence is recorded. The visual mutation below still uses the
	# production table stage, SeatHUDs and callout layer.
	var game_manager := root_node.get("game_manager") as Node
	var snapshot_callback := Callable(root_node, "_on_snapshot_changed")
	if game_manager != null and game_manager.has_signal("snapshot_changed") \
		and game_manager.is_connected("snapshot_changed", snapshot_callback):
		game_manager.disconnect("snapshot_changed", snapshot_callback)
	for timer_property in [
		"ai_turn_timer",
		"ai_reaction_timer",
		"ai_watchdog_timer",
		"opening_roll_timer",
		"opening_roll_commit_timer",
		"draw_transition_timer",
	]:
		var timer := root_node.get(timer_property) as Timer
		if timer != null:
			timer.stop()
	stage.call("set_reduced_motion", true)
	stage.call("render_snapshot", motion_evidence_snapshot, motion_evidence_hands, false, -1, {})
	stage.call("set_reduced_motion", false)
	_prime_score_huds(root_node, motion_evidence_snapshot)
	if root_node.has_method("_update_seat_huds"):
		root_node.call("_update_seat_huds", motion_evidence_snapshot)
	_force_table_overlays_hidden(root_node)
	RenderingServer.force_draw()
	await process_frame
	await process_frame
	var mode := _capture_mode()
	var target_snapshot := motion_evidence_snapshot.duplicate(true)
	var target_hands: Array = motion_evidence_hands.duplicate(true)
	var players: Array = target_snapshot.get("players", [])
	var event: Dictionary = {}
	var callout_frame := 12
	var event_frame := 4
	var score_frame := 13
	var first_score_frame := -1
	var first_score_snapshot: Dictionary = {}
	var subtype := ""
	match mode:
		"motion-peng":
			players[1]["melds"] = [{"type": "peng", "from_seat": 0, "tiles": _make_3d_demo_tiles(41000, 3, 1)}]
			event = {"kind": "peng", "signature": "peng:901:1:0:41001", "payload": {"type": "peng"}}
			callout_frame = event_frame + 7
		"motion-melded-gang":
			subtype = "melded_gang"
			players[1]["melds"] = [{"type": "gang", "gang_subtype": subtype, "from_seat": 0, "tiles": _make_3d_demo_tiles(42000, 4, 2)}]
			_apply_score_delta(players, {0: -2, 1: 2})
			event = {"kind": "gang", "signature": "gang:902:1:melded_gang:42001", "payload": {"gang_subtype": subtype}}
			callout_frame = event_frame + 8
		"motion-add-gang":
			subtype = "add_gang"
			players[3]["melds"] = [{"type": "gang", "gang_subtype": subtype, "from_seat": 3, "tiles": _make_3d_demo_tiles(30300, 4, 5)}]
			_apply_score_delta(players, {0: -2, 1: -2, 2: -2, 3: 6})
			event = {"kind": "gang", "signature": "gang:903:3:add_gang:30303", "payload": {"gang_subtype": subtype}}
			callout_frame = event_frame + 8
		"motion-an-gang":
			subtype = "an_gang"
			players[2]["melds"] = [{"type": "gang", "gang_subtype": subtype, "from_seat": 2, "tiles": _make_3d_demo_tiles(44000, 4, 4)}]
			_apply_score_delta(players, {0: -2, 1: -2, 2: 6, 3: -2})
			event = {"kind": "gang", "signature": "gang:904:2:an_gang:44001", "payload": {"gang_subtype": subtype}}
			callout_frame = event_frame + 8
		"motion-self-draw":
			var winning_tile: Dictionary = target_hands[0].back()
			players[0]["has_won"] = true
			players[0]["winning_tile"] = winning_tile
			players[0]["winning_source_seat"] = 0
			_apply_score_delta(players, {0: 15, 1: -5, 2: -5, 3: -5})
			event = _motion_win_event(905, "self_draw", 0, 0, int(winning_tile.get("id", -1)))
			callout_frame = event_frame + 7
		"motion-gang-self-draw":
			var supplement := {"id": 45099, "suit": "tong", "rank": 5}
			target_hands[0].append(supplement)
			players[0]["hand_count"] = target_hands[0].size()
			target_snapshot["human_last_draw_tile_id"] = 45099
			players[0]["has_won"] = true
			players[0]["winning_tile"] = supplement
			players[0]["winning_source_seat"] = 0
			event = _motion_win_event(906, "gang_self_draw", 0, 0, 45099)
			callout_frame = event_frame + 8
			var gang_score_players: Array = (motion_evidence_snapshot.get("players", []) as Array).duplicate(true)
			_apply_score_delta(gang_score_players, {0: 6, 1: -2, 2: -2, 3: -2})
			first_score_snapshot = motion_evidence_snapshot.duplicate(true)
			first_score_snapshot["players"] = gang_score_players
			first_score_frame = callout_frame
			_apply_score_delta(players, {0: 21, 1: -7, 2: -7, 3: -7})
			score_frame = callout_frame + 5
		"motion-discard-win":
			var discard_tile: Dictionary = (players[0].get("discards", []) as Array).back()
			players[1]["has_won"] = true
			players[1]["winning_tile"] = discard_tile
			players[1]["winning_source_seat"] = 0
			_apply_score_delta(players, {0: -5, 1: 5})
			event = _motion_win_event(907, "discard_win", 1, 0, int(discard_tile.get("id", -1)))
			callout_frame = event_frame + 8
		"motion-qiang-gang-hu":
			var robbed_tile := _make_3d_demo_tiles(30000, 4, 2)[3] as Dictionary
			players[0]["melds"] = [{"type": "gang", "gang_subtype": "add_gang", "from_seat": 0, "tiles": _make_3d_demo_tiles(30000, 4, 2)}]
			players[1]["has_won"] = true
			players[1]["winning_tile"] = robbed_tile
			players[1]["winning_source_seat"] = 0
			_apply_score_delta(players, {0: -5, 1: 5})
			event = _motion_win_event(908, "qiang_gang_hu", 1, 0, int(robbed_tile.get("id", -1)))
			callout_frame = event_frame + 8
		_:
			push_error("Unsupported motion evidence mode: %s" % mode)
			return
	target_snapshot["players"] = players

	var callout_layer := CALLOUT_LAYER_SCRIPT.new() as Node
	callout_layer.name = "EvidenceMotionCalloutFxLayer"
	var accepted_kinds: Array[String] = ["peng", "gang", "win", "tip"]
	callout_layer.call("configure", "production motion recording", accepted_kinds)
	root_node.add_child(callout_layer)
	var output_dir := ProjectSettings.globalize_path(_capture_output_path())
	var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK:
		push_error("Failed to create motion evidence directory: %s" % output_dir)
		return
	var frame_count := int(ceil(MOTION_CAPTURE_SECONDS * MOTION_CAPTURE_FPS))
	for frame_index in range(frame_count):
		_force_table_overlays_hidden(root_node)
		if frame_index < event_frame:
			stage.call("set_reduced_motion", true)
			stage.call("render_snapshot", motion_evidence_snapshot, motion_evidence_hands, false, -1, {})
		if frame_index == event_frame:
			stage.call("set_reduced_motion", false)
			stage.call("render_snapshot", target_snapshot, target_hands, false, -1, {})
		if frame_index == callout_frame:
			event["callout_delay_seconds"] = 0.0
			callout_layer.call("present", event)
		if frame_index == first_score_frame and not first_score_snapshot.is_empty() \
			and root_node.has_method("_update_seat_huds"):
			_prime_score_huds(root_node, motion_evidence_snapshot)
			root_node.call("_update_seat_huds", first_score_snapshot)
		if frame_index == score_frame and root_node.has_method("_update_seat_huds"):
			_prime_score_huds(root_node, first_score_snapshot if not first_score_snapshot.is_empty() else motion_evidence_snapshot)
			root_node.call("_update_seat_huds", target_snapshot)
		RenderingServer.force_draw()
		await process_frame
		var image := get_root().get_viewport().get_texture().get_image()
		var frame_path := output_dir.path_join("frame_%03d.png" % frame_index)
		if image.save_png(frame_path) != OK:
			push_error("Failed to save motion frame: %s" % frame_path)
			return
		await create_timer(1.0 / float(MOTION_CAPTURE_FPS)).timeout
	print("motion_capture=", mode, " frames=", frame_count, " fps=", MOTION_CAPTURE_FPS, " output=", output_dir)


func _record_settlement_transition(root_node: Node) -> void:
	var game_manager := root_node.get("game_manager") as Node
	var snapshot_callback := Callable(root_node, "_on_snapshot_changed")
	if game_manager != null and game_manager.has_signal("snapshot_changed") \
		and game_manager.is_connected("snapshot_changed", snapshot_callback):
		game_manager.disconnect("snapshot_changed", snapshot_callback)
	for timer_property in [
		"ai_turn_timer",
		"ai_reaction_timer",
		"ai_watchdog_timer",
		"opening_roll_timer",
		"opening_roll_commit_timer",
		"draw_transition_timer",
	]:
		var timer := root_node.get(timer_property) as Timer
		if timer != null:
			timer.stop()
	# Build the same audited four-player detailed settlement used by the static
	# beauty shot, then restart its production transition from a phase-6 table.
	_force_settlement_preview(root_node)
	var snapshot: Dictionary = root_node.get("settlement_transition_pending_snapshot").duplicate(true)
	if snapshot.is_empty():
		push_error("Settlement transition evidence snapshot is unavailable")
		return
	var reduced := _capture_mode() == "settlement-transition-reduced"
	ProjectSettings.set_setting("accessibility/reduced_motion", reduced)
	var director := root_node.get("table_presentation_director") as Node
	if director != null:
		director.call("set_reduced_motion", reduced)
		director.call("reset_for_round", int(snapshot.get("round_index", 5)))
	var previous := snapshot.duplicate(true)
	previous["current_phase"] = 6
	previous["settlement_data"] = {}
	var previous_players: Array = previous.get("players", [])
	for seat in range(previous_players.size()):
		previous_players[seat]["has_won"] = false
	previous["players"] = previous_players
	root_node.call("_refresh_settlement", {"current_phase": 6})
	root_node.set("last_snapshot", previous)
	if director != null:
		director.call("consume_snapshot", previous, snapshot)
	if root_node.has_method("_update_seat_huds"):
		_prime_score_huds(root_node, previous)
		root_node.call("_update_seat_huds", snapshot)
	root_node.set("last_snapshot", snapshot)
	root_node.call("_refresh_settlement", snapshot)
	var output_dir := ProjectSettings.globalize_path(_capture_output_path())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Failed to create settlement transition evidence directory: %s" % output_dir)
		return
	var frame_count := int(ceil(MOTION_CAPTURE_SECONDS * MOTION_CAPTURE_FPS))
	var captured_frames: Array[Image] = []
	for frame_index in range(frame_count):
		RenderingServer.force_draw()
		await process_frame
		captured_frames.append(get_root().get_viewport().get_texture().get_image())
		await create_timer(1.0 / float(MOTION_CAPTURE_FPS)).timeout
	var contract: Dictionary = root_node.call("get_settlement_transition_contract")
	for frame_index in range(captured_frames.size()):
		var image := captured_frames[frame_index]
		var frame_path := output_dir.path_join("frame_%03d.png" % frame_index)
		if image.save_png(frame_path) != OK:
			push_error("Failed to save settlement transition frame: %s" % frame_path)
			return
	print("settlement_transition_capture=", _capture_mode(), " frames=", frame_count, " fps=", MOTION_CAPTURE_FPS, " contract=", contract, " output=", output_dir)


func _motion_win_event(round_index: int, win_type: String, winner: int, source: int, tile_id: int) -> Dictionary:
	return {
		"kind": "win",
		"signature": "win:%d:%d:%d:%d" % [round_index, winner, source, tile_id],
		"payload": {"win_type": win_type, "fan_detail": {"capped_fan": 3}},
	}


func _apply_score_delta(players: Array, deltas: Dictionary) -> void:
	for seat_variant in deltas:
		var seat := int(seat_variant)
		if seat < 0 or seat >= players.size():
			continue
		players[seat]["score"] = int(players[seat].get("score", 0)) + int(deltas[seat_variant])


func _prime_score_huds(root_node: Node, snapshot: Dictionary) -> void:
	var players: Array = snapshot.get("players", [])
	var seat_huds: Dictionary = root_node.get("seat_huds")
	for player_variant in players:
		var player := player_variant as Dictionary
		var seat := int(player.get("seat", -1))
		var seat_hud := seat_huds.get(seat) as Control
		if seat_hud == null:
			continue
		seat_hud.call("set_reduced_motion", true)
		seat_hud.set("previous_score", int(player.get("score", 0)))
		seat_hud.set("has_rendered_score", true)
		seat_hud.call("set_reduced_motion", false)


func _force_playable_snapshot() -> void:
	var game_state: Node = get_root().get_node_or_null("GameState")
	if game_state == null:
		return

	var players: Array = game_state.get("players")
	if players.is_empty():
		return

	for index in range(players.size()):
		var player: Dictionary = players[index]
		if str(player.get("ding_que", "")) == "":
			if index == 0:
				player["ding_que"] = AUTO_DING_QUE_SUIT
			players[index] = player
	game_state.set("players", players)
	game_state.call("_auto_select_ai_ding_que")
	if bool(game_state.get("opening_roll_pending_completion")):
		game_state.call("complete_opening_roll")
	else:
		game_state.call("_complete_ding_que_if_ready")

	var step_count := 0
	while step_count < MAX_AI_STEPS and not bool(game_state.call("can_human_discard", 0)):
		if bool(game_state.call("is_ai_reaction_pending")):
			game_state.call("run_ai_reaction")
		elif bool(game_state.call("is_ai_turn_ready")):
			game_state.call("run_ai_turn")
		else:
			break
		step_count += 1
		await process_frame


func _log_self_hand_debug(root_node: Node) -> void:
	var hand_host := root_node.get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/SelfSection/SelfSectionMargin/SelfSectionVBox/SelfHandHost")
	if hand_host is Control:
		var control := hand_host as Control
		print("SelfHandHost size=", control.size, " position=", control.global_position)


func _force_discard_demo() -> void:
	var game_state: Node = get_root().get_node_or_null("GameState")
	if game_state == null:
		return

	var players: Array = game_state.get("players")
	var wall: Array = game_state.get("wall")
	var discard_pile: Array = []

	for seat in range(players.size()):
		var player: Dictionary = players[seat]
		player["discards"] = []
		var requests: Array = DEMO_DISCARDS.get(seat, [])
		for request in requests:
			var tile := _take_tile_from_wall(wall, str(request[0]), int(request[1]))
			if tile.is_empty():
				continue
			player["discards"].append(tile)
			discard_pile.append(
				{
					"seat": seat,
					"tile": tile,
				}
			)
		while player["discards"].size() < 14 and not wall.is_empty():
			var pressure_tile: Dictionary = wall.pop_back()
			player["discards"].append(pressure_tile)
			discard_pile.append({"seat": seat, "tile": pressure_tile})
		players[seat] = player

	game_state.set("players", players)
	game_state.set("wall", wall)
	game_state.set("discard_pile", discard_pile)
	game_state.set("wall_count", wall.size())
	game_state.call("_emit_state_changed")


func _force_ai_helper_preview(root_node: Node) -> void:
	if root_node == null:
		return
	root_node.set("ai_helper_enabled", true)
	var drawer: Control = root_node.get("ai_assistant_drawer") as Control
	if drawer != null:
		# Evidence capture must not inherit a developer-machine drag preference;
		# use the product's deterministic default position for every resolution.
		root_node.set("ai_drawer_positioned", false)
		drawer.call("restore_user_position", Vector2(0.5, 0.5), false)
		# Capture the shipped default (70%).  The 50% setting remains covered by
		# the interaction contract, but it is not the product's first impression.
		drawer.call("set_glass_opacity", 0.70)
		drawer.call("set_expanded", _capture_mode() == "ai-expanded")
	root_node.call("_update_discard_helper_panel", {
		"players": [
			{
				"seat": 0,
				"nickname": "本家",
				"score": 0,
				"hand_tiles": [
					{"id": 9001, "suit": "tiao", "rank": 1},
					{"id": 9002, "suit": "tiao", "rank": 2},
					{"id": 9003, "suit": "tiao", "rank": 3},
					{"id": 9004, "suit": "tong", "rank": 5},
					{"id": 9005, "suit": "wan", "rank": 7},
					{"id": 9006, "suit": "wan", "rank": 8},
				],
			},
		],
	}, {
		"recommended": {
			"tile": {"id": 9009, "suit": "tiao", "rank": 9},
			"tile_name": "9条",
			"shanten": 1,
			"ukeire": 8,
			"win_probability": 0.24,
			"risk_label": "低危",
			"score": 120,
			"explanation_hint": "边九孤张，先拆掉",
		},
		"recommended_tile_id": 9009,
		"options": [],
		"strategy_profile": {"mode_label": "快攻"},
		"situation_label": "缺门",
	}, true)
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar != null:
		utility_bar.call("render", true, false, false, "骨灰", false)
	root_node.call_deferred("_layout_ai_assistant_drawer")


func _force_clean_table_preview(root_node: Node) -> void:
	# Presentation capture only: keep the real AI drawer implementation intact,
	# but remove it from the beauty shot so the table/tiles hierarchy is visible.
	if root_node == null:
		return
	var drawer: Control = root_node.get("ai_assistant_drawer") as Control
	if drawer != null:
		drawer.visible = false
	var helper_panel: Control = root_node.get("discard_helper_panel") as Control
	if helper_panel != null:
		helper_panel.visible = false
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar != null:
		utility_bar.call("render", false, false, false)


func _force_settlement_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var manager: Node = root_node.get("game_manager") as Node
	if manager == null:
		return
	var snapshot: Dictionary = manager.call("get_snapshot").duplicate(true)
	var players: Array = snapshot.get("players", [])
	if players.size() < 4:
		return
	for index in range(players.size()):
		var player: Dictionary = players[index]
		player["nickname"] = ["陈旭", "舒燕", "陈东", "舒玲"][index]
		player["score"] = [14, 3, -11, -6][index]
		player["has_won"] = index == 0
		players[index] = player
	var winning_tile: Dictionary = players[0].get("hand_tiles", [{}]).back() if not players[0].get("hand_tiles", []).is_empty() else {"id": 9999, "suit": "wan", "rank": 9}
	snapshot["current_phase"] = 7
	snapshot["current_dealer_seat"] = 1
	snapshot["players"] = players
	snapshot["settlement_data"] = {
		"round_index": 5,
		"dealer_seat": 1,
		"end_reason": "draw_wall_empty",
		"winner_seats": [0],
		"score_changes": {0: 10, 1: -2, 2: -2, 3: -6},
		"win_events": [{
			"winner_seat": 0,
			"source_seat": 0,
			"payer_seats": [2, 3],
			"win_type": "self_draw",
			"winning_tile": winning_tile,
			"fan_detail": {"capped_fan": 0, "hand_score": 1, "per_payer_score": 2, "labels": ["平胡", "自摸"]},
		}],
		"gang_events": [{"actor_seat": 0, "gang_type": "an_gang", "payer_seats": [1, 2, 3]}],
		"draw_assessment": [
			{"seat": 2, "is_ting": true, "hua_zhu": false, "cha_jiao_fan": 1, "cha_jiao_score": 2},
			{"seat": 3, "is_ting": false, "hua_zhu": false, "cha_jiao_fan": 0, "cha_jiao_score": 0},
		],
	}
	root_node.set("last_snapshot", {"current_phase": 6})
	root_node.call("_refresh_settlement", snapshot)
	root_node.call("force_complete_settlement_transition_for_test")


func _force_self_hand_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var self_hand_host: Node = root_node.get("self_hand_host") as Node
	if self_hand_host == null:
		return
	var preview_tiles: Array = []
	for index in range(11):
		preview_tiles.append({
			"id": 9001 + index,
			"suit": ["tiao", "tong", "wan"][index % 3],
			"rank": index % 9 + 1,
		})
	self_hand_host.call(
		"configure_hand",
		preview_tiles,
		-1,
		9011,
		false,
		{"recommended_tile_id": 9002},
		{}
	)


func _force_self_hu_preview(root_node: Node) -> void:
	if root_node == null:
		return
	root_node.call(
		"_update_self_area",
		{
			"players": [
				{
					"seat": 0,
					"nickname": "本家",
					"score": 0,
					"hand_tiles": [
						{"id": 9101, "suit": "tiao", "rank": 1},
						{"id": 9102, "suit": "tiao", "rank": 2},
						{"id": 9103, "suit": "tiao", "rank": 3},
						{"id": 9104, "suit": "tong", "rank": 5},
						{"id": 9105, "suit": "wan", "rank": 7},
						{"id": 9106, "suit": "wan", "rank": 8},
					],
					"hand_count": 6,
					"melds": [],
					"discards": [],
					"ding_que": "tong",
					"has_won": true,
					"win_type": "discard_win",
					"winning_tile": {"id": 9199, "suit": "tong", "rank": 8},
					"winning_source_seat": 1,
				},
			],
			"rules": {"use_ding_que_phase": true},
			"human_can_discard": false,
			"human_last_draw_tile_id": -1,
		},
		[
			{"id": 9101, "suit": "tiao", "rank": 1},
			{"id": 9102, "suit": "tiao", "rank": 2},
			{"id": 9103, "suit": "tiao", "rank": 3},
			{"id": 9104, "suit": "tong", "rank": 5},
			{"id": 9105, "suit": "wan", "rank": 7},
			{"id": 9106, "suit": "wan", "rank": 8},
		]
	)


func _force_table_overlays_hidden(root_node: Node) -> void:
	for property_name in ["settlement_overlay_v2", "settlement_overlay", "ding_que_overlay"]:
		var overlay: Control = root_node.get(property_name) as Control
		if overlay != null:
			overlay.visible = false
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar != null:
		utility_bar.call("render", false, false, false)


func _force_ding_que_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var drawer: Control = root_node.get("ai_assistant_drawer") as Control
	if drawer != null:
		drawer.visible = false
	var overlay: Control = root_node.get("ding_que_overlay") as Control
	if overlay != null:
		overlay.visible = true
		overlay.move_to_front()
	var action_bar: Control = root_node.get("table_action_bar") as Control
	if action_bar != null:
		action_bar.call("hide_actions")
	if _capture_mode() == "ding-que-reduced":
		ProjectSettings.set_setting("accessibility/reduced_motion", true)
	if _capture_mode() in ["ding-que-selected", "ding-que-reduced"]:
		root_node.call("_apply_ding_que_selection_state", "tong")


func _force_hud_state_preview(root_node: Node) -> void:
	if root_node == null or _capture_mode() not in ["hud-current", "hud-current-reduced", "hud-won", "hud-score-plus", "hud-score-minus"]:
		return
	var reduced_preview := _capture_mode() == "hud-current-reduced"
	if reduced_preview:
		ProjectSettings.set_setting("accessibility/reduced_motion", true)
	var players := [
		{"seat": 0, "nickname": "本家", "score": 3, "ding_que": "tong", "has_won": false},
		{"seat": 1, "nickname": "舒燕", "score": -5, "ding_que": "wan", "has_won": _capture_mode() == "hud-won"},
		{"seat": 2, "nickname": "陈东", "score": 6, "ding_que": "tong", "has_won": false},
		{"seat": 3, "nickname": "舒玲", "score": 2, "ding_que": "wan", "has_won": false},
	]
	if _capture_mode() == "hud-score-plus":
		players[1]["score"] = -1
	elif _capture_mode() == "hud-score-minus":
		players[3]["score"] = -4
	var seat_huds: Dictionary = root_node.get("seat_huds")
	for seat in range(4):
		var hud: Control = seat_huds.get(seat)
		if hud == null:
			continue
		if hud.has_method("set_reduced_motion"):
			hud.call("set_reduced_motion", reduced_preview)
		var baseline_score := int(players[seat].get("score", 0))
		if _capture_mode() == "hud-score-plus" and seat == 1:
			baseline_score = -5
		elif _capture_mode() == "hud-score-minus" and seat == 3:
			baseline_score = 2
		hud.set("previous_score", baseline_score)
		hud.set("has_rendered_score", true)
		var existing_delta := hud.get_node_or_null("%ScoreDeltaLabel") as Label
		if existing_delta != null:
			existing_delta.visible = false
	root_node.call("_update_seat_huds", {
		"players": players,
		"current_dealer_seat": 2,
		"current_turn_seat": 1,
		"rules": {"use_ding_que_phase": true},
	})


func _force_action_bar_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var action_bar: Control = root_node.get("table_action_bar") as Control
	if action_bar == null:
		return
	var preview_actions: Array[String]
	var status_text := "响应 3筒 · 可选：碰 / 取消"
	match _capture_mode():
		"action-1":
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["pass"]
			status_text = "可选：取消"
		"action-2":
			action_bar.call("set_action_label", "peng", "碰")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["peng", "pass"]
			status_text = "可选：碰 / 取消"
		"action-3":
			action_bar.call("set_action_label", "gang", "杠")
			action_bar.call("set_action_label", "peng", "碰")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["gang", "peng", "pass"]
			status_text = "可选：杠 / 碰 / 取消"
		"action-4":
			action_bar.call("set_action_label", "hu", "胡")
			action_bar.call("set_action_label", "gang", "杠")
			action_bar.call("set_action_label", "peng", "碰")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["hu", "gang", "peng", "pass"]
			status_text = "可选：胡 / 杠 / 碰 / 取消"
		"response-hu":
			action_bar.call("set_action_label", "hu", "胡")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["hu", "pass"]
			status_text = "响应 9筒 · 可选：胡 / 取消"
		"self-hu", "gang-self-hu":
			action_bar.call("set_action_label", "hu", "自摸")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["hu", "pass"]
			status_text = "轮到你 · 可选：自摸 / 取消"
		_:
			action_bar.call("set_action_label", "peng", "碰")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["peng", "pass"]
	action_bar.call("render", preview_actions, status_text)
	var center_indicator: Control = root_node.get("center_turn_indicator") as Control
	if center_indicator != null:
		center_indicator.call("render", 40, 0, "等待本家响应")
	root_node.call_deferred("_layout_table_action_bar")


func _force_utility_expanded_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar == null:
		return
	utility_bar.call("render", true, false, false, "骨灰", true)
	utility_bar.call("set_collapsed", false)
	root_node.call_deferred("_layout_table_utility_bar")


func _force_tabletop_polish_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var players := [
		{
			"seat": 0,
			"nickname": "本家",
			"score": 3,
			"hand_count": 10,
			"hand_tiles": [
				{"id": 9301, "suit": "tiao", "rank": 1},
				{"id": 9302, "suit": "tiao", "rank": 2},
				{"id": 9303, "suit": "tiao", "rank": 3},
				{"id": 9304, "suit": "tong", "rank": 5},
				{"id": 9305, "suit": "tong", "rank": 6},
				{"id": 9306, "suit": "wan", "rank": 7},
			],
			"melds": [
				{"type": "peng", "tile": {"id": 9311, "suit": "tong", "rank": 2}, "tiles": [
					{"id": 9311, "suit": "tong", "rank": 2},
					{"id": 9312, "suit": "tong", "rank": 2},
					{"id": 9313, "suit": "tong", "rank": 2},
				], "from_seat": 1},
			],
			"discards": [],
			"ding_que": "tong",
			"has_won": false,
		},
		{
			"seat": 1,
			"nickname": "舒燕",
			"score": -5,
			"hand_count": 11,
			"hand_tiles": [],
			"melds": [
				{"type": "gang", "tile": {"id": 9411, "suit": "tong", "rank": 3}, "tiles": [
					{"id": 9411, "suit": "tong", "rank": 3},
					{"id": 9412, "suit": "tong", "rank": 3},
					{"id": 9413, "suit": "tong", "rank": 3},
					{"id": 9414, "suit": "tong", "rank": 3},
				], "from_seat": 0},
			],
			"discards": [],
			"ding_que": "wan",
			"has_won": false,
		},
		{
			"seat": 2,
			"nickname": "陈东",
			"score": 6,
			"hand_count": 11,
			"hand_tiles": [],
			"melds": [
				{"type": "peng", "tile": {"id": 9511, "suit": "tiao", "rank": 6}, "tiles": [
					{"id": 9511, "suit": "tiao", "rank": 6},
					{"id": 9512, "suit": "tiao", "rank": 6},
					{"id": 9513, "suit": "tiao", "rank": 6},
				], "from_seat": 3},
			],
			"discards": [],
			"ding_que": "tong",
			"has_won": false,
		},
		{
			"seat": 3,
			"nickname": "舒玲",
			"score": 2,
			"hand_count": 11,
			"hand_tiles": [],
			"melds": [
				{"type": "peng", "tile": {"id": 9611, "suit": "wan", "rank": 5}, "tiles": [
					{"id": 9611, "suit": "wan", "rank": 5},
					{"id": 9612, "suit": "wan", "rank": 5},
					{"id": 9613, "suit": "wan", "rank": 5},
				], "from_seat": 2},
			],
			"discards": [],
			"ding_que": "wan",
			"has_won": false,
		},
	]
	var snapshot := {
		"players": players,
		"current_turn_seat": 0,
		"current_dealer_seat": 0,
		"rules": {"use_ding_que_phase": true},
		"human_can_discard": true,
		"human_reaction_options": {"can_peng": true, "can_pass": true},
		"human_last_draw_tile_id": -1,
	}
	if root_node.get("self_ui") != null:
		root_node.get("self_ui").apply_snapshot(players[0], false, 0, 0, true)
	if root_node.get("left_ui") != null:
		root_node.get("left_ui").apply_snapshot(players[1], true, 0, 0, true)
	if root_node.get("top_ui") != null:
		root_node.get("top_ui").apply_snapshot(players[2], true, 0, 0, true)
	if root_node.get("right_ui") != null:
		root_node.get("right_ui").apply_snapshot(players[3], true, 0, 0, true)
	root_node.call("_update_seat_huds", snapshot)
	root_node.call("_update_self_area", snapshot, players[0]["hand_tiles"])


func _force_3d_full_table_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var stage := root_node.get("table_stage_3d") as Node3D
	if stage == null or not stage.has_method("render_snapshot"):
		return
	if _capture_mode() == "camera":
		root_node.set("opponent_hands_enabled", false)
		root_node.set("ai_helper_enabled", false)
	var motion_recording := _capture_mode() in MOTION_RECORD_MODES
	var hand_counts := [14, 13, 13, 13] if _capture_mode() == "camera" else ([2, 10, 10, 10] if _capture_mode() == "max-meld" else ([2, 2, 2, 2] if _capture_mode() == "meld-pressure" else [11, 10, 10, 10]))
	# The camera-reference frame mirrors the supplied ding-que screenshot: four
	# concealed hands, no discards and no melds. Dense gameplay remains covered
	# by the contract runner and the normal beauty-shot modes.
	var discard_counts := [0, 0, 0, 0] if _capture_mode() == "camera" else ([18, 18, 18, 18] if _capture_mode() == "discard-pressure" else ([6, 6, 6, 6] if _capture_mode() == "meld-pressure" else ([4, 4, 4, 4] if motion_recording else [10, 9, 10, 9])))
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand := _make_3d_demo_tiles(10000 + seat * 100, hand_counts[seat], seat)
		var discards := _make_3d_demo_tiles(20000 + seat * 100, discard_counts[seat], seat + 1)
		var source_matrix_gang := _capture_mode() == "meld-source-matrix" and seat in [1, 2]
		var meld_tile_count := 13 if _capture_mode() == "meld-pressure" else (16 if seat == 0 and _capture_mode() == "max-meld" else (7 if seat == 3 and _capture_mode() == "right-meld" else (4 if seat == 2 or source_matrix_gang else 3)))
		var meld_tiles := _make_3d_demo_tiles(30000 + seat * 100, meld_tile_count, seat + 2)
		all_hands.append(hand)
		var preview_melds: Array = []
		if _capture_mode() == "an-gang-static":
			preview_melds = [{
				"type": "gang",
				"gang_subtype": "an_gang",
				"tiles": meld_tiles,
				"from_seat": seat,
			}]
		elif motion_recording:
			if _capture_mode() == "motion-add-gang" and seat == 3:
				preview_melds = [{
					"type": "peng",
					"tiles": meld_tiles.slice(0, 3),
					"from_seat": 0,
				}]
			elif _capture_mode() == "motion-qiang-gang-hu" and seat == 0:
				preview_melds = [{
					"type": "peng",
					"tiles": meld_tiles.slice(0, 3),
					"from_seat": 1,
				}]
		elif _capture_mode() != "camera":
			if _capture_mode() == "meld-pressure":
				for group_index in range(4):
					var group_size := 4 if group_index == 3 else 3
					var group_start := group_index * 3
					preview_melds.append({
						"type": "gang" if group_index == 3 else "peng",
						"gang_subtype": "ming_gang" if group_index == 3 else "",
						"tiles": meld_tiles.slice(group_start, group_start + group_size),
						"from_seat": (seat + group_index + 1) % 4,
					})
			elif seat == 0 and _capture_mode() == "max-meld":
				# Four gangs plus two concealed tiles exercise the legal 18-tile
				# pressure limit on the shared lower rail.
				for group_index in range(4):
					var group_tiles: Array = []
					for tile_index in range(group_index * 4, group_index * 4 + 4):
						group_tiles.append(meld_tiles[tile_index])
					preview_melds.append({
						"type": "gang",
						"gang_subtype": "ming_gang",
						"tiles": group_tiles,
						"from_seat": (seat + group_index + 1) % 4,
					})
			elif seat == 3 and _capture_mode() == "right-meld":
				preview_melds = [
					{
						"type": "peng",
						"tiles": meld_tiles.slice(0, 3),
						"from_seat": 0,
					},
					{
						"type": "gang",
						"gang_subtype": "ming_gang",
						"tiles": meld_tiles.slice(3, 7),
						"from_seat": 2,
					},
				]
			elif _capture_mode() == "meld-source-matrix":
				var subtype := ""
				if seat == 1:
					subtype = "ming_gang"
				elif seat == 2:
					subtype = "bu_gang"
				preview_melds = [{
					"type": "gang" if seat in [1, 2] else "peng",
					"gang_subtype": subtype,
					"tiles": meld_tiles,
					"from_seat": (seat + 1) % 4,
				}]
			else:
				preview_melds = [{
					"type": "gang" if seat == 2 else "peng",
					"gang_subtype": "an_gang" if seat == 2 else "",
					"tiles": meld_tiles,
					"from_seat": (seat + 1) % 4,
				}]
		players.append({
			"seat": seat,
			"nickname": ["陈旭", "舒燕", "陈东", "舒玲"][seat],
			"score": [3, -5, 6, 2][seat],
			"hand_count": hand_counts[seat],
			"hand_tiles": hand if seat == 0 else [],
			"melds": preview_melds,
			"discards": discards,
			"ding_que": ["tong", "wan", "tong", "wan"][seat],
			"has_won": false,
		})
	if _capture_mode() == "won":
		players[0]["has_won"] = true
		players[0]["winning_tile"] = all_hands[0].back()
		players[0]["winning_source_seat"] = 1
	elif _capture_mode() == "self-draw":
		players[0]["has_won"] = true
		players[0]["winning_tile"] = all_hands[0].back()
		players[0]["winning_source_seat"] = 0
	elif _capture_mode().begins_with("ai-self-draw-"):
		var ai_self_draw_seat := clampi(int(_capture_mode().trim_prefix("ai-self-draw-")), 1, 3)
		players[ai_self_draw_seat]["has_won"] = true
		players[ai_self_draw_seat]["winning_tile"] = all_hands[ai_self_draw_seat].back()
		players[ai_self_draw_seat]["winning_source_seat"] = ai_self_draw_seat
	elif _capture_mode().begins_with("ai-discard-win"):
		var discard_win_seat := 1
		if _capture_mode().begins_with("ai-discard-win-"):
			discard_win_seat = clampi(int(_capture_mode().trim_prefix("ai-discard-win-")), 1, 3)
		players[discard_win_seat]["has_won"] = true
		players[discard_win_seat]["winning_tile"] = all_hands[discard_win_seat].back()
		players[discard_win_seat]["winning_source_seat"] = 0
	var recent_tile: Dictionary = {}
	if not (players[3]["discards"] as Array).is_empty():
		recent_tile = players[3]["discards"].back()
	var snapshot := {
		"players": players,
		"wall_count": 40,
		"current_turn_seat": 2 if _capture_mode().begins_with("ai-discard-win") else (1 if _capture_mode() == "won" else 0),
		"current_dealer_seat": 0,
		"human_can_discard": _capture_mode() not in ["won", "self-draw", "ai-self-draw-1", "ai-self-draw-2", "ai-self-draw-3", "ai-discard-win", "ai-discard-win-1", "ai-discard-win-3", "gang-self-hu"],
		"human_last_draw_tile_id": int(all_hands[0].back().get("id", -1)),
		"recent_discard_tile_id": int(recent_tile.get("id", -1)),
	}
	if motion_recording:
		motion_evidence_snapshot = snapshot.duplicate(true)
		motion_evidence_hands = all_hands.duplicate(true)
	# Evidence states must obey the same interaction contract as runtime state.
	# Previously the action bar was forced after the HUD snapshot, producing
	# impossible frames such as 已胡 + 本家出牌中 or 响应按钮 + 出牌徽章.
	match _capture_mode():
		"response-hu":
			snapshot["human_can_discard"] = false
			snapshot["human_reaction_options"] = {"can_hu": true, "can_pass": true}
		"self-hu", "gang-self-hu":
			snapshot["human_can_discard"] = false
			snapshot["human_can_self_hu"] = true
		"ai-expanded", "table":
			snapshot["human_can_discard"] = false
			snapshot["human_reaction_options"] = {"can_peng": true, "can_pass": true}
	var reveal_opponents := _capture_mode() == "3d-reveal"
	var selected_tile_id := int(all_hands[0][4].get("id", -1)) if _capture_mode() in ["selection", "selection-reduced"] else -1
	# Normal selection evidence keeps the check-marker breath and draw-marker
	# rotation enabled; the paired reduced mode proves the same semantic state
	# survives with every loop frozen.
	stage.call("set_reduced_motion", _capture_mode() != "selection" and not motion_recording)
	var self_hand_for_markers: Array = all_hands[0]
	var recommended_index := mini(2, self_hand_for_markers.size() - 1)
	var danger_index := mini(8, self_hand_for_markers.size() - 1)
	stage.call("render_snapshot", snapshot, all_hands, reveal_opponents, selected_tile_id, {
		"recommended_tile_id": int(self_hand_for_markers[recommended_index].get("id", -1)),
		"danger_tile_ids": [int(self_hand_for_markers[danger_index].get("id", -1))],
	})
	# The synthetic fixture bypasses MainSceneV2's normal phase visibility refresh.
	# Make the live-game center surface explicit so beauty shots verify the actual
	# glass diamond and wall number instead of inheriting opening-roll visibility.
	stage.call("set_center_wall_count_visible", true)
	if root_node.has_method("_update_seat_huds"):
		root_node.call("_update_seat_huds", snapshot)
	var center_indicator := root_node.get("center_turn_indicator") as Control
	var evidence_turn_seat := _capture_turn_seat()
	if center_indicator != null and center_indicator.has_method("render"):
		if evidence_turn_seat >= 0:
			center_indicator.call("render", 40, evidence_turn_seat)
		elif _capture_mode() == "won":
			center_indicator.call("render", 40, 1, "上家出牌中")
		elif _capture_mode() == "self-draw":
			center_indicator.call("render", 40, 0, "本家已自摸")
		elif _capture_mode() == "ai-discard-win":
			center_indicator.call("render", 40, 2, "对家出牌中")
		elif _capture_mode() in ["response-hu", "self-hu", "ai-expanded", "table"]:
			center_indicator.call("render", 40, 0, "等待本家响应" if _capture_mode() != "self-hu" else "本家操作中")
		else:
			center_indicator.call("render", 40, int(snapshot.get("current_turn_seat", 0)))
	# The 3D stage owns the visible production panel. Drive it explicitly for
	# direction-state evidence instead of only changing the hidden 2D fallback.
	if evidence_turn_seat >= 0:
		stage.call("_set_center_panel_state", 40, evidence_turn_seat)
	root_node.call("_layout_3d_center_indicator")


func _make_3d_demo_tiles(start_id: int, count: int, offset: int) -> Array:
	var result: Array = []
	var suits := ["tiao", "tong", "wan"]
	for index in range(count):
		result.append({
			"id": start_id + index,
			"suit": suits[(index + offset) % suits.size()],
			"rank": (index * 2 + offset) % 9 + 1,
		})
	return result


func _take_tile_from_wall(wall: Array, suit: String, rank: int) -> Dictionary:
	for index in range(wall.size()):
		var tile: Dictionary = wall[index]
		if str(tile.get("suit", "")) == suit and int(tile.get("rank", 0)) == rank:
			wall.remove_at(index)
			return tile
	return {}
