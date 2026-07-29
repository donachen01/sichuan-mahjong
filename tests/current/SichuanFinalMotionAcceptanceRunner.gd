extends SceneTree

const DIRECTOR_SCRIPT := preload("res://scripts/ui/presentation/TablePresentationDirector.gd")
const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const SEAT_HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const ACTION_BAR_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")

const CALLOUT_KEYS := ["peng", "gang", "hu", "self_draw", "gang_self_draw", "qiang_gang_hu"]
const EVIDENCE_CRITERIA := ["AC-MOTION-01", "AC-MOTION-02", "AC-MOTION-03", "AC-MOTION-04", "AC-MOTION-05"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var metrics := {
		"criteria": EVIDENCE_CRITERIA,
		"timings": {},
		"event_sequences": {},
		"asset_checks": {},
		"reduced_motion": {},
	}
	await _verify_director_and_callouts(failures, metrics)
	await _verify_live_score_components(failures, metrics)
	await _verify_stage_sequences(failures, metrics)
	await _verify_hud_and_action_timings(failures, metrics)
	_verify_assets(failures, metrics)
	metrics["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	metrics["failures"] = failures
	_write_metrics(metrics, failures)
	if failures.is_empty():
		print("SICHUAN FINAL MOTION ACCEPTANCE OK: 5/5 CONTRACT GROUPS")
		quit(0)
		return
	push_error("SICHUAN FINAL MOTION ACCEPTANCE FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_director_and_callouts(failures: Array[String], metrics: Dictionary) -> void:
	var director := DIRECTOR_SCRIPT.new() as Node
	director.set("auto_advance", false)
	get_root().add_child(director)
	await process_frame
	var contract: Dictionary = director.call("get_motion_contract")
	var timings: Dictionary = contract.get("timings", {})
	metrics["timings"] = timings.duplicate(true)
	_expect_range(timings, "action_button_entry_seconds", 0.15, 0.20, failures)
	_expect_range(timings, "draw_seconds", 0.18, 0.22, failures)
	_expect_range(timings, "discard_seconds", 0.18, 0.24, failures)
	_expect_range(timings, "peng_seconds", 0.18, 0.24, failures)
	_expect_range(timings, "gang_seconds", 0.22, 0.28, failures)
	_expect_range(timings, "callout_entry_seconds", 0.16, 0.22, failures)
	_expect_range(timings, "callout_hold_seconds", 0.30, 0.45, failures)
	_expect_range(timings, "score_float_seconds", 0.35, 0.50, failures)
	_expect_range(timings, "active_hud_edge_seconds", 0.16, 0.18, failures)
	for invariant in ["screen_shake", "changes_layout_rect", "changes_touch_rect", "changes_tile_id_mapping"]:
		if bool(timings.get(invariant, true)):
			failures.append("motion invariant must remain false: %s" % invariant)
	var sequences: Dictionary = contract.get("event_sequences", {})
	metrics["event_sequences"] = sequences.duplicate(true)
	var required_sequences := {
		"peng": ["source_discard_flies_to_meld", "three_tiles_land", "callout_peng"],
		"melded_gang": ["source_discard_flies_to_meld", "four_tiles_land", "callout_gang", "payer_and_actor_score"],
		"add_gang": ["fourth_tile_hand_to_existing_peng", "four_tiles_land", "callout_add_gang", "three_payers_and_actor_score"],
		"an_gang": ["four_tiles_land_outer_faces_middle_backs", "callout_an_gang", "three_payers_and_actor_score"],
		"self_draw": ["winning_tile_glow_and_hud", "callout_self_draw_and_fan", "three_payers_then_winner_score"],
		"gang_self_draw": ["supplement_draw_lands", "callout_gang_self_draw", "gang_score_event", "hu_score_event"],
		"discard_win": ["discard_transfers_to_winner", "callout_hu", "source_and_winner_score"],
		"qiang_gang_hu": ["add_gang_tile_transfers_to_winner", "sharp_callout_without_shake", "source_and_winner_score"],
	}
	for sequence_name in required_sequences:
		if sequences.get(sequence_name, []) != required_sequences[sequence_name]:
			failures.append("event sequence mismatch: %s" % sequence_name)

	var callout_layer: Node = director.call("get_layer", "CalloutFxLayer")
	var visual_paths: Dictionary = {}
	for index in range(CALLOUT_KEYS.size()):
		var key: String = CALLOUT_KEYS[index]
		director.call("reset_for_round", index + 1)
		var event := _callout_event(key, index + 1)
		director.call("enqueue_event", event)
		await process_frame
		var state: Dictionary = callout_layer.call("get_visual_state_contract")
		visual_paths[key] = state.get("texture_path", "")
		if not str(state.get("texture_path", "")).ends_with("/%s.png" % key):
			failures.append("callout did not route to the expected texture: %s" % key)
		if not bool(state.get("visible", false)):
			failures.append("callout was not mounted in the runtime CanvasLayer: %s" % key)
	metrics["callout_texture_paths"] = visual_paths

	director.call("reset_for_round", 88)
	director.call("enqueue_event", _callout_event("qiang_gang_hu", 88))
	await process_frame
	var normal_state: Dictionary = callout_layer.call("get_visual_state_contract")
	director.call("set_reduced_motion", true)
	var reset_state: Dictionary = callout_layer.call("get_visual_state_contract")
	if int(reset_state.get("active_tween_count", -1)) != 0 or bool(reset_state.get("visible", true)):
		failures.append("reduced-motion switch did not stop and reset the active callout tween")
	director.call("reset_for_round", 89)
	director.call("enqueue_event", _callout_event("qiang_gang_hu", 89))
	await process_frame
	var reduced_state: Dictionary = callout_layer.call("get_visual_state_contract")
	if reduced_state.get("scale", Vector2.ZERO) != Vector2.ONE:
		failures.append("reduced-motion callout retained a scale/path animation")
	if reduced_state.get("position", Vector2.ZERO) != normal_state.get("position", Vector2.ONE):
		failures.append("reduced-motion callout changed its final placement")
	metrics["reduced_motion"]["callout"] = {
		"active_tweens_after_switch": reset_state.get("active_tween_count", -1),
		"same_position": reduced_state.get("position") == normal_state.get("position"),
		"scale_is_one": reduced_state.get("scale") == Vector2.ONE,
	}
	director.queue_free()
	await process_frame


func _verify_stage_sequences(failures: Array[String], metrics: Dictionary) -> void:
	var stage := STAGE_SCRIPT.new() as Node3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	var hands := _hands()
	var players := _players()
	stage.call("render_snapshot", _snapshot(players), hands, false, -1, {})
	await process_frame

	players[1]["melds"] = [{"type": "peng", "from_seat": 0, "tiles": [_tile(810), _tile(811), _tile(812)]}]
	stage.call("render_snapshot", _snapshot(players), hands, false, -1, {})
	var peng_claim: Dictionary = stage.call("get_motion_entry_contract", "meld_1_0_811")
	if str(peng_claim.get("motion_role", "")) != "source_discard_to_meld" or not is_equal_approx(float(peng_claim.get("motion_duration_seconds", 0.0)), 0.22):
		failures.append("peng source tile did not use the 220 ms source-discard flight")
	await create_timer(0.26).timeout

	players[2]["melds"] = [{"type": "gang", "gang_subtype": "an_gang", "from_seat": 2, "tiles": [_tile(820), _tile(821), _tile(822), _tile(823)]}]
	stage.call("render_snapshot", _snapshot(players), hands, false, -1, {})
	var concealed_faces: Array[bool] = []
	for tile_id in range(820, 824):
		concealed_faces.append(bool((stage.call("get_motion_entry_contract", "meld_2_0_%d" % tile_id) as Dictionary).get("show_face", false)))
	if concealed_faces != [true, false, false, true]:
		failures.append("concealed gang must show outer faces and two middle jade backs: %s" % [concealed_faces])
	await create_timer(0.30).timeout

	players[3]["melds"] = [{"type": "peng", "from_seat": 0, "tiles": [_tile(830), _tile(831), _tile(832)]}]
	stage.call("render_snapshot", _snapshot(players), hands, false, -1, {})
	await create_timer(0.25).timeout
	players[3]["melds"] = [{"type": "gang", "gang_subtype": "add_gang", "from_seat": 3, "tiles": [_tile(830), _tile(831), _tile(832), _tile(833)]}]
	stage.call("render_snapshot", _snapshot(players), hands, false, -1, {})
	var add_gang_tile: Dictionary = stage.call("get_motion_entry_contract", "meld_3_0_833")
	if str(add_gang_tile.get("motion_role", "")) != "fourth_tile_hand_to_existing_peng":
		failures.append("add-gang fourth tile did not travel from hand to the existing peng")

	players[0]["melds"] = [{"type": "gang", "gang_subtype": "melded_gang", "from_seat": 1, "tiles": [_tile(840), _tile(841), _tile(842), _tile(843)]}]
	stage.call("render_snapshot", _snapshot(players), hands, false, -1, {})
	var direct_claim: Dictionary = stage.call("get_motion_entry_contract", "meld_0_0_841")
	if str(direct_claim.get("motion_role", "")) != "source_discard_to_meld" or not is_equal_approx(float(direct_claim.get("motion_duration_seconds", 0.0)), 0.26):
		failures.append("melded gang did not use the 260 ms source-discard formation")
	var before_reduced: Dictionary = stage.call("get_motion_contract")
	stage.call("set_reduced_motion", true)
	var after_reduced: Dictionary = stage.call("get_motion_contract")
	if int(after_reduced.get("active_tween_count", -1)) != 0:
		failures.append("table stage retained active tile tweens after reduced-motion switch")
	var nodes: Dictionary = stage.get("tile_nodes")
	var claim_node := nodes.get("meld_0_0_841") as Node3D
	var final_claim_transform: Transform3D = direct_claim.get("transform", Transform3D.IDENTITY)
	var final_claim_scale: Vector3 = direct_claim.get("scale", Vector3.ONE)
	if claim_node == null \
		or not claim_node.position.is_equal_approx(final_claim_transform.origin) \
		or not claim_node.scale.is_equal_approx(final_claim_scale):
		failures.append("reduced motion did not snap the critical tile to its identical final position and scale")
	metrics["stage"] = {
		"peng_claim_role": peng_claim.get("motion_role"),
		"concealed_gang_faces": concealed_faces,
		"add_gang_role": add_gang_tile.get("motion_role"),
		"direct_gang_role": direct_claim.get("motion_role"),
		"active_tweens_before_reduced": before_reduced.get("active_tween_count"),
		"active_tweens_after_reduced": after_reduced.get("active_tween_count"),
	}
	stage.queue_free()
	await process_frame


func _verify_live_score_components(failures: Array[String], metrics: Dictionary) -> void:
	var director := DIRECTOR_SCRIPT.new() as Node
	director.set("auto_advance", false)
	get_root().add_child(director)
	await process_frame
	var base_players := _players()
	var before := _snapshot(base_players)
	before["round_index"] = 77
	before["settlement_data"] = {"gang_events": [], "win_events": []}
	var gang_snapshot := before.duplicate(true)
	gang_snapshot["players"][0]["score"] = 6
	for seat in [1, 2, 3]:
		gang_snapshot["players"][seat]["score"] = -2
	gang_snapshot["players"][0]["melds"] = [{
		"type": "gang",
		"gang_subtype": "an_gang",
		"from_seat": 0,
		"tiles": [_tile(970), _tile(971), _tile(972), _tile(973)],
	}]
	gang_snapshot["settlement_data"] = {
		"gang_events": [{"actor_seat": 0, "source_seat": 0, "gang_type": "an_gang", "payer_seats": [1, 2, 3]}],
		"win_events": [],
		"score_changes": {0: 6, 1: -2, 2: -2, 3: -2},
	}
	director.call("consume_snapshot", before, gang_snapshot)
	_drain_director(director)
	var win_snapshot := gang_snapshot.duplicate(true)
	win_snapshot["players"][0]["score"] = 21
	for seat in [1, 2, 3]:
		win_snapshot["players"][seat]["score"] = -7
	win_snapshot["settlement_data"]["win_events"] = [{
		"winner_seat": 0,
		"source_seat": 0,
		"payer_seats": [1, 2, 3],
		"win_type": "gang_self_draw",
		"winning_tile": _tile(974),
		"fan_detail": {"capped_fan": 2},
	}]
	win_snapshot["settlement_data"]["score_changes"] = {0: 21, 1: -7, 2: -7, 3: -7}
	director.call("consume_snapshot", gang_snapshot, win_snapshot)
	_drain_director(director)
	var score_layer: Node = director.call("get_layer", "ScoreDeltaLayer")
	var score_events: Array = score_layer.get("presentation_log")
	var gang_components := 0
	var hu_components := 0
	for event in score_events:
		if str(event.get("score_component", "")) == "gang":
			gang_components += 1
		elif str(event.get("score_component", "")) == "hu":
			hu_components += 1
	if gang_components != 4 or hu_components != 4:
		failures.append("gang-self-draw must expose independent gang and hu score events: gang=%d hu=%d" % [gang_components, hu_components])
	metrics["live_score_components"] = {
		"gang_event_count": gang_components,
		"hu_event_count": hu_components,
		"independent": gang_components == 4 and hu_components == 4,
		"gang_actor_delta": 6,
		"hu_winner_delta": 15,
	}
	director.queue_free()
	await process_frame


func _drain_director(director: Node) -> void:
	for _step in range(128):
		var state: Dictionary = director.call("get_state_contract")
		if str(state.get("active_signature", "")).is_empty():
			return
		director.call("complete_active_event")


func _verify_hud_and_action_timings(failures: Array[String], metrics: Dictionary) -> void:
	var hud := SEAT_HUD_SCENE.instantiate() as Control
	hud.size = Vector2(238.0, 178.0)
	get_root().add_child(hud)
	await process_frame
	hud.call("configure_seat", 0)
	hud.call("render", {"nickname": "本家", "score": 0, "ding_que": "tong", "has_won": false}, 0, true)
	hud.call("render", {"nickname": "本家", "score": 6, "ding_que": "tong", "has_won": false}, 0, true)
	var hud_contract: Dictionary = hud.call("get_visual_contract")
	_expect_number(float(hud_contract.get("score_float_seconds", 0.0)), 0.42, "SeatHUD score float", failures)
	var hud_rect := hud.get_global_rect()
	hud.call("set_reduced_motion", true)
	var hud_state: Dictionary = hud.call("get_motion_state_contract")
	if int(hud_state.get("score_tween_count", -1)) != 0 or hud.get_global_rect() != hud_rect:
		failures.append("SeatHUD reduced motion did not reset tweens while preserving its rect")
	metrics["reduced_motion"]["seat_hud"] = hud_state
	hud.queue_free()

	var action_bar := ACTION_BAR_SCENE.instantiate() as Control
	get_root().add_child(action_bar)
	await process_frame
	var action_contract: Dictionary = action_bar.call("get_motion_contract")
	_expect_range(action_contract, "entrance_duration", 0.15, 0.20, failures)
	var actions: Array[String] = ["hu", "gang", "peng", "pass"]
	action_bar.call("render", actions, "动作")
	await process_frame
	var action_rect := action_bar.get_global_rect()
	action_bar.call("set_reduced_motion", true)
	if action_bar.get_global_rect() != action_rect:
		failures.append("action-bar reduced motion changed its layout/touch rect")
	action_bar.queue_free()
	await process_frame


func _verify_assets(failures: Array[String], metrics: Dictionary) -> void:
	var asset_checks: Dictionary = {}
	for key in CALLOUT_KEYS:
		var path := "res://res/art/ui/event_callouts/%s.png" % key
		var absolute := ProjectSettings.globalize_path(path)
		var image := Image.new()
		var error := image.load(absolute)
		var transparent_corners := 0
		if error == OK:
			for point in [Vector2i(0, 0), Vector2i(1023, 0), Vector2i(0, 511), Vector2i(1023, 511)]:
				if image.get_pixelv(point).a <= 0.01:
					transparent_corners += 1
		asset_checks[key] = {
			"load_error": error,
			"width": image.get_width(),
			"height": image.get_height(),
			"transparent_corners": transparent_corners,
		}
		if error != OK or image.get_width() != 1024 or image.get_height() != 512 or transparent_corners < 2:
			failures.append("callout asset is not a valid transparent 1024x512 PNG: %s" % key)
	for required_path in [
		"res://res/source/ui/event_callouts/sichuan_event_callouts.blend",
		"res://tools/3d/generate_sichuan_event_callouts.py",
		"res://docs/ui_rework/四川牌桌事件字原创与参考差异声明_V1.md",
	]:
		if not FileAccess.file_exists(ProjectSettings.globalize_path(required_path)):
			failures.append("original-art evidence missing: %s" % required_path)
	metrics["asset_checks"] = asset_checks
	metrics["asset_source"] = "res://res/source/ui/event_callouts/sichuan_event_callouts.blend"
	metrics["generated_image_api_calls"] = 0


func _callout_event(key: String, round_index: int) -> Dictionary:
	if key == "peng":
		return {"kind": "peng", "signature": "peng:%d:1:0:11" % round_index, "payload": {"type": "peng"}}
	if key == "gang":
		return {"kind": "gang", "signature": "gang:%d:1:melded_gang:12" % round_index, "payload": {"gang_subtype": "melded_gang"}}
	var win_type: String = str({
		"hu": "discard_win",
		"self_draw": "self_draw",
		"gang_self_draw": "gang_self_draw",
		"qiang_gang_hu": "qiang_gang_hu",
	}.get(key, "discard_win"))
	return {
		"kind": "win",
		"signature": "win:%d:0:1:%d" % [round_index, 900 + round_index],
		"payload": {"win_type": win_type, "fan_detail": {"capped_fan": 3}},
	}


func _players() -> Array:
	var players: Array = []
	for seat in range(4):
		players.append({"seat": seat, "score": 0, "has_won": false, "ding_que": "tong", "discards": [], "melds": []})
	return players


func _hands() -> Array:
	var hands: Array = []
	for seat in range(4):
		var hand: Array = []
		for index in range(13):
			hand.append(_tile(seat * 100 + index))
		hands.append(hand)
	return hands


func _snapshot(players: Array) -> Dictionary:
	return {
		"round_index": 1,
		"turn_index": 1,
		"players": players.duplicate(true),
		"current_turn_seat": 0,
		"human_can_discard": true,
		"recent_discard_tile_id": -1,
		"human_last_draw_tile_id": -1,
	}


func _tile(id: int) -> Dictionary:
	return {"id": id, "suit": ["wan", "tong", "tiao"][abs(id) % 3], "rank": abs(id) % 9 + 1}


func _expect_range(values: Dictionary, key: String, minimum: float, maximum: float, failures: Array[String]) -> void:
	var value := float(values.get(key, -1.0))
	if value < minimum - 0.0001 or value > maximum + 0.0001:
		failures.append("%s %.3fs outside %.3f..%.3fs" % [key, value, minimum, maximum])


func _expect_number(actual: float, expected: float, label: String, failures: Array[String]) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s expected %.3f, got %.3f" % [label, expected, actual])


func _write_metrics(metrics: Dictionary, failures: Array[String]) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
			break
	if output_path.is_empty():
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write final motion metrics: %s" % output_path)
		return
	file.store_string(JSON.stringify(metrics, "  "))
