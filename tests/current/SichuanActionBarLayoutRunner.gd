extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const VIEWPORT_SIZE := Vector2i(2048, 1152)
const PRIMARY_MIN := Vector2(264.0, 264.0)
const SECONDARY_MIN := Vector2(216.0, 216.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = VIEWPORT_SIZE
	await process_frame
	var failures: Array[String] = []
	var evidence: Dictionary = {
		"criterion": "AC-LAYOUT-04",
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"states": [],
		"objective_result": "PASS",
	}
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	for timer in scene.find_children("*", "Timer", true, false):
		(timer as Timer).stop()

	var action_bar: Control = scene.get("table_action_bar")
	var root_ui: Control = scene.get("root_ui")
	_render_hand_fixture(scene)
	await process_frame
	var hand_rect := _projected_hand_rect(scene)
	if action_bar == null or root_ui == null:
		failures.append("action bar or root UI missing")
	else:
		var states: Array[Array] = [
			["pass"],
			["peng", "pass"],
			["gang", "peng", "pass"],
			["hu", "gang", "peng", "pass"],
		]
		for actions_value in states:
			var actions: Array[String] = []
			for action_value in actions_value:
				actions.append(str(action_value))
			action_bar.call("render", actions, "")
			scene.call("_layout_table_action_bar")
			await process_frame
			var visible_actions: Array[String] = action_bar.call("get_visible_actions")
			if visible_actions != actions:
				failures.append("%d-action state exposed non-executable or reordered actions: %s" % [actions.size(), visible_actions])
			var button_rects: Dictionary = {}
			var ordered_rects: Array[Rect2] = []
			for action in actions:
				var rect: Rect2 = action_bar.call("get_touch_rect", action)
				button_rects[action] = _rect_array(rect)
				ordered_rects.append(rect)
				var required := PRIMARY_MIN if action == "hu" else SECONDARY_MIN
				if rect.size.x < required.x or rect.size.y < required.y:
					failures.append("%s touch rect below contract in %d-action state: %s" % [action, actions.size(), rect])
			for first_index in range(ordered_rects.size()):
				for second_index in range(first_index + 1, ordered_rects.size()):
					if ordered_rects[first_index].intersects(ordered_rects[second_index]):
						failures.append("touch rects overlap in %d-action state" % actions.size())
			var bar_rect := action_bar.get_global_rect()
			if not root_ui.get_global_rect().encloses(bar_rect):
				failures.append("%d-action bar leaves the root safe viewport" % actions.size())
			if hand_rect.size != Vector2.ZERO and bar_rect.intersects(hand_rect):
				failures.append("%d-action bar overlaps the 3D human hand" % actions.size())
			if bar_rect.get_center().x < root_ui.get_global_rect().get_center().x:
				failures.append("%d-action bar is not in the hand's upper-right decision zone" % actions.size())
			if actions.has("hu"):
				var hu_rect: Rect2 = action_bar.call("get_touch_rect", "hu")
				for secondary in ["gang", "peng", "pass"]:
					if actions.has(secondary):
						var secondary_rect: Rect2 = action_bar.call("get_touch_rect", secondary)
						if hu_rect.size.x * hu_rect.size.y <= secondary_rect.size.x * secondary_rect.size.y:
							failures.append("Hu lost strongest size hierarchy against %s" % secondary)
			(evidence["states"] as Array).append({
				"action_count": actions.size(),
				"visible_actions": visible_actions,
				"bar_rect": _rect_array(bar_rect),
				"button_rects": button_rects,
				"inside_root": root_ui.get_global_rect().encloses(bar_rect),
				"overlaps_hand": hand_rect.size != Vector2.ZERO and bar_rect.intersects(hand_rect),
			})

	evidence["human_hand_rect"] = _rect_array(hand_rect)
	evidence["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	evidence["failures"] = failures
	_write_evidence(evidence, failures)
	scene.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SICHUAN ACTION BAR LAYOUT CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN ACTION BAR LAYOUT CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _projected_hand_rect(scene: Node) -> Rect2:
	var stage := scene.get("table_stage_3d") as SichuanTableStage3D
	if stage == null:
		return Rect2()
	var result := Rect2()
	var found := false
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with("hand_0_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		var rect := tile.get_screen_rect(stage.get_camera())
		result = rect if not found else result.merge(rect)
		found = true
	return result


func _render_hand_fixture(scene: Node) -> void:
	var stage := scene.get("table_stage_3d") as SichuanTableStage3D
	if stage == null:
		return
	stage.set_reduced_motion(true)
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand: Array = []
		for index in range(11 if seat == 0 else 10):
			hand.append({
				"id": 81000 + seat * 100 + index,
				"suit": ["tiao", "tong", "wan"][index % 3],
				"rank": index % 9 + 1,
			})
		all_hands.append(hand)
		players.append({
			"seat": seat,
			"has_won": false,
			"hand_tiles": hand if seat == 0 else [],
			"melds": [],
			"discards": [],
		})
	stage.render_snapshot({
		"players": players,
		"wall_count": 40,
		"human_can_discard": true,
		"human_last_draw_tile_id": int((all_hands[0] as Array).back().get("id", -1)),
		"recent_discard_tile_id": -1,
	}, all_hands, false, -1, {})


func _rect_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _write_evidence(evidence: Dictionary, failures: Array[String]) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
			break
	if output_path.is_empty():
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write action layout evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify(evidence, "  "))
