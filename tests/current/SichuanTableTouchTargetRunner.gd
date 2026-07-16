extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const UTILITY_BAR_SCRIPT_PATH := "res://scripts/ui/table/TableUtilityBar.gd"
const ACTION_BAR_SCRIPT_PATH := "res://scripts/ui/table/TableActionBar.gd"
const HAND_VIEWPORT_SCENE := preload("res://scenes/ui/PlayerHandViewport.tscn")
const MIN_TOUCH_SIZE := Vector2(76.0, 76.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var root_node := MAIN_SCENE.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame
	await process_frame

	var utility_bar: Control = root_node.get("table_utility_bar")
	if utility_bar == null:
		failures.append("TableUtilityBar was not created")
	elif utility_bar.get_script() == null or utility_bar.get_script().resource_path != UTILITY_BAR_SCRIPT_PATH:
		failures.append("table utility controls must use the shared component")
	else:
		_verify_normal_round(root_node, utility_bar, failures)
		_verify_settlement_visibility(utility_bar, failures)
	await _verify_action_bar(root_node, failures)
	await _verify_hand_layout_pressure(failures)

	root_node.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SICHUAN TABLE TOUCH TARGET CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN TABLE TOUCH TARGET CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_normal_round(root_node: Node, utility_bar: Control, failures: Array[String]) -> void:
	utility_bar.call("render", false, false, false)
	utility_bar.call("_layout_buttons")
	for legacy_name in ["top_ai_helper_button", "top_settlement_info_button", "top_next_round_button", "top_exit_button"]:
		var legacy_button: Button = root_node.get(legacy_name)
		if legacy_button != null and legacy_button.visible:
			failures.append("legacy control must stay hidden: %s" % legacy_name)

	var visible_actions := ["ai", "settings", "opponent_hands", "exit"]
	var visible_rects: Array[Rect2] = []
	for action in visible_actions:
		var button: Button = utility_bar.call("get_button", action)
		if button == null or not button.visible:
			failures.append("normal-round utility button missing: %s" % action)
			continue
		var rect: Rect2 = utility_bar.call("get_touch_rect", action)
		if rect.size.x < MIN_TOUCH_SIZE.x or rect.size.y < MIN_TOUCH_SIZE.y:
			failures.append("%s touch target is smaller than 76x76" % action)
		visible_rects.append(rect)

	for first_index in range(visible_rects.size()):
		for second_index in range(first_index + 1, visible_rects.size()):
			if visible_rects[first_index].intersects(visible_rects[second_index]):
				failures.append("utility touch targets overlap")

	var seat_huds: Dictionary = root_node.get("seat_huds")
	for rect in visible_rects:
		for seat in [0, 1, 2, 3]:
			var seat_hud: Control = seat_huds.get(seat)
			if seat_hud != null and rect.intersects(seat_hud.get_global_rect()):
				failures.append("utility control overlaps SeatHUD%d" % seat)

	for hidden_action in ["settlement", "next_round"]:
		var hidden_button: Button = utility_bar.call("get_button", hidden_action)
		if hidden_button != null and hidden_button.visible:
			failures.append("%s must be hidden during a live round" % hidden_action)


func _verify_settlement_visibility(utility_bar: Control, failures: Array[String]) -> void:
	utility_bar.call("render", false, true, false)
	var next_round_button: Button = utility_bar.call("get_button", "next_round")
	var settlement_button: Button = utility_bar.call("get_button", "settlement")
	if not next_round_button.visible or next_round_button.disabled:
		failures.append("next round must become available after settlement")
	if settlement_button.visible:
		failures.append("settlement reopen must stay hidden while the overlay is open")

	utility_bar.call("render", false, true, true)
	if not settlement_button.visible or settlement_button.disabled:
		failures.append("settlement reopen must appear after the overlay is dismissed")
	for action in ["settlement", "next_round"]:
		var rect: Rect2 = utility_bar.call("get_touch_rect", action)
		if rect.size.x < MIN_TOUCH_SIZE.x or rect.size.y < MIN_TOUCH_SIZE.y:
			failures.append("%s settlement touch target is smaller than 76x76" % action)


func _verify_action_bar(root_node: Node, failures: Array[String]) -> void:
	var action_bar: Control = root_node.get("table_action_bar")
	if action_bar == null or action_bar.get_script() == null or action_bar.get_script().resource_path != ACTION_BAR_SCRIPT_PATH:
		failures.append("shared TableActionBar component missing")
		return
	var actions: Array[String] = ["hu", "gang", "peng", "pass"]
	action_bar.call("render", actions, "响应出牌：胡 / 杠 / 碰 / 过")
	root_node.call("_layout_table_action_bar")
	await process_frame
	var action_rects: Array[Rect2] = []
	for action in actions:
		var rect: Rect2 = action_bar.call("get_touch_rect", action)
		var minimum := Vector2(132.0, 132.0) if action == "hu" else Vector2(108.0, 108.0)
		if rect.size.x < minimum.x or rect.size.y < minimum.y:
			failures.append("%s action target is below its visual/touch contract" % action)
		action_rects.append(rect)
	for first_index in range(action_rects.size()):
		for second_index in range(first_index + 1, action_rects.size()):
			if action_rects[first_index].intersects(action_rects[second_index]):
				failures.append("action button touch targets overlap")
	var self_hand: Control = root_node.get("self_hand_host")
	if self_hand != null and action_bar.get_global_rect().intersects(self_hand.get_global_rect()):
		failures.append("action bar overlaps the self hand")
	if not action_bar.is_connected("action_selected", Callable(root_node, "_on_table_action_selected")):
		failures.append("action bar must dispatch through the existing MainScene callbacks")
	action_bar.call("hide_actions")


func _verify_hand_layout_pressure(failures: Array[String]) -> void:
	var hand_viewport := HAND_VIEWPORT_SCENE.instantiate() as Control
	get_root().add_child(hand_viewport)
	hand_viewport.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand_viewport.size = Vector2(1365.0, 240.0)
	var fourteen_tiles := _make_tiles(14)
	hand_viewport.call("configure_hand", fourteen_tiles, -1, 13, true, {"recommended_tile_id": 6})
	await process_frame
	var bounds: Rect2 = hand_viewport.call("get_hand_layout_bounds")
	if bounds.position.x < 0.0 or bounds.end.x > hand_viewport.size.x or bounds.position.y < 0.0 or bounds.end.y > hand_viewport.size.y:
		failures.append("14-tile hand must stay inside the compact safe width")
	var layouts: Array = hand_viewport.call("get_hand_layout_contract")
	if layouts.size() != 14:
		failures.append("14-tile hand layout count mismatch")
	else:
		var previous_rect: Rect2 = layouts[12].get("front_rect", Rect2())
		var draw_rect: Rect2 = layouts[13].get("front_rect", Rect2())
		var normal_step := float(layouts[12].get("front_rect", Rect2()).position.x - layouts[11].get("front_rect", Rect2()).position.x)
		if draw_rect.position.x - previous_rect.position.x <= normal_step:
			failures.append("newly drawn tile must keep a visible gap")
		if not bool(layouts[6].get("recommended", false)):
			failures.append("recommended tile marker contract was lost")

	var meld_reduced_hand := _make_tiles(5)
	hand_viewport.call("configure_hand", meld_reduced_hand, -1, 4, true, {}, {
		"embedded_left_width": 480.0,
		"embedded_left_gap": 12.0,
	})
	await process_frame
	var meld_bounds: Rect2 = hand_viewport.call("get_hand_layout_bounds")
	if meld_bounds.position.x < 492.0 or meld_bounds.end.x > hand_viewport.size.x:
		failures.append("three-meld reserved band must not push the remaining hand out of bounds")
	hand_viewport.queue_free()
	await process_frame


func _make_tiles(count: int) -> Array:
	var tiles: Array = []
	for index in range(count):
		tiles.append({
			"id": index,
			"suit": ["tiao", "tong", "wan"][index % 3],
			"rank": index % 9 + 1,
			"display_name": "%d万" % (index % 9 + 1),
		})
	return tiles
