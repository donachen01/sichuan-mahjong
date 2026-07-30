extends SceneTree

const SEAT_HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const ACTION_BAR_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")
const CENTER_SCENE := preload("res://scenes/ui/table/CenterTurnIndicator.tscn")
const DISCARD_LAYER_SCRIPT := preload("res://scripts/ui/table/TableDiscardLayer.gd")
const HAND_CANVAS_SCRIPT := preload("res://scripts/ui/HandCanvas2D.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _verify_seat_motion_and_text(failures)
	await _verify_action_motion(failures)
	await _verify_discard_motion(failures)
	_verify_hand_motion(failures)
	_verify_center_text(failures)
	if failures.is_empty():
		print("SICHUAN TABLE MOTION CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN TABLE MOTION CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_seat_motion_and_text(failures: Array[String]) -> void:
	var seat_hud := SEAT_HUD_SCENE.instantiate() as Control
	get_root().add_child(seat_hud)
	seat_hud.size = Vector2(238.0, 178.0)
	seat_hud.call("configure_seat", 0)
	var before_size := seat_hud.get_global_rect().size
	seat_hud.call("render", {"nickname": "本家", "score": 100, "ding_que": "wan", "_is_dealer": true, "has_won": false}, 0, true)
	await create_timer(1.02).timeout
	if not seat_hud.get_global_rect().size.is_equal_approx(before_size):
		failures.append("SeatHUD active animation changed layout size")
	var dealer_badge := seat_hud.get_node_or_null("%DealerBadge") as Label
	var ding_badge: Control = seat_hud.call("get_ding_que_badge")
	var ding_text := ding_badge.get_node_or_null("%TextLabel") as Label
	if dealer_badge == null or dealer_badge.text != "庄" or not dealer_badge.visible:
		failures.append("dealer state must include the 庄 text")
	var turn_badge := seat_hud.get_node_or_null("%TurnBadge") as Label
	if turn_badge == null or turn_badge.visible:
		failures.append("current turn must use the nameplate ring instead of a 出牌 text badge")
	if ding_text == null or ding_text.text != "缺万":
		failures.append("ding-que state must include text, not color only")
	seat_hud.call("render", {"nickname": "本家", "score": 100, "ding_que": "wan", "_is_dealer": false, "has_won": true}, 2, true)
	await create_timer(0.32).timeout
	var won_badge := seat_hud.get_node_or_null("%WonBadge") as Label
	if won_badge == null or won_badge.text != "已胡" or not won_badge.visible:
		failures.append("won state must include the 已胡 text")
	if not seat_hud.get_global_rect().size.is_equal_approx(before_size):
		failures.append("SeatHUD won animation changed layout size")
	seat_hud.call("set_reduced_motion", true)
	if not bool(seat_hud.call("is_reduced_motion")):
		failures.append("SeatHUD reduced-motion preference was not applied")
	seat_hud.queue_free()
	await process_frame


func _verify_action_motion(failures: Array[String]) -> void:
	var action_bar := ACTION_BAR_SCENE.instantiate() as Control
	get_root().add_child(action_bar)
	var actions: Array[String] = ["hu", "gang", "peng", "pass"]
	action_bar.call("render", actions, "请选择操作")
	await create_timer(0.26).timeout
	var before_size := action_bar.get_global_rect().size
	var hu_button: Button = action_bar.call("get_button", "hu")
	if hu_button.focus_mode != Control.FOCUS_ALL:
		failures.append("action buttons must support controller/keyboard focus")
	var motion_contract: Dictionary = action_bar.call("get_motion_contract")
	for duration_name in ["entrance_duration", "hover_duration", "press_duration"]:
		if float(motion_contract.get(duration_name, 1.0)) > 0.20:
			failures.append("%s must stay within the 200ms motion-safe limit" % duration_name)
	hu_button.emit_signal("pressed")
	await create_timer(0.18).timeout
	if not action_bar.get_global_rect().size.is_equal_approx(before_size):
		failures.append("action press feedback changed action-bar layout size")
	action_bar.call("set_reduced_motion", true)
	hu_button.emit_signal("pressed")
	if not action_bar.get_global_rect().size.is_equal_approx(before_size):
		failures.append("reduced-motion action feedback changed layout size")
	if not hu_button.scale.is_equal_approx(Vector2.ONE) or not hu_button.modulate.is_equal_approx(Color.WHITE):
		failures.append("reduced motion must reset action button transforms")
	action_bar.queue_free()
	await process_frame


func _verify_discard_motion(failures: Array[String]) -> void:
	var discard_layer := DISCARD_LAYER_SCRIPT.new() as Control
	get_root().add_child(discard_layer)
	var players := [{"seat": 0, "discards": [_tile(100, "wan", 1)]}, {"seat": 1, "discards": []}, {"seat": 2, "discards": []}, {"seat": 3, "discards": []}]
	discard_layer.call("render", players, {"id": 100}, Rect2(Vector2.ZERO, Vector2(1065.0, 772.0)))
	var before_rect: Rect2 = discard_layer.call("get_lane_rect", 0)
	await create_timer(0.28).timeout
	var after_rect: Rect2 = discard_layer.call("get_lane_rect", 0)
	if before_rect != after_rect:
		failures.append("discard landing motion changed lane layout")
	discard_layer.call("set_reduced_motion", true)
	discard_layer.call("render", players, {"id": 100}, Rect2(Vector2.ZERO, Vector2(1065.0, 772.0)))
	if int(discard_layer.call("get_latest_marker_count")) != 1:
		failures.append("reduced motion removed the latest-discard state marker")
	discard_layer.queue_free()
	await process_frame


func _verify_hand_motion(failures: Array[String]) -> void:
	var canvas := HAND_CANVAS_SCRIPT.new()
	var tiles: Array = []
	for index in range(14):
		tiles.append(_tile(index, ["wan", "tong", "tiao"][index % 3], index % 9 + 1))
	canvas.call("configure", tiles, -1, 13, Vector2(1600.0, 240.0), {"recommended_tile_id": 6})
	var layouts: Array = canvas.call("get_layout_contract")
	var regular_y := float((layouts[12].get("front_rect", Rect2()) as Rect2).position.y)
	var new_draw_y := float((layouts[13].get("front_rect", Rect2()) as Rect2).position.y)
	if new_draw_y >= regular_y:
		failures.append("newly drawn tile must keep a subtle lift")
	canvas.call("configure", tiles, 6, 13, Vector2(1600.0, 240.0), {"recommended_tile_id": 6})
	layouts = canvas.call("get_layout_contract")
	var neighbor_y := float((layouts[5].get("front_rect", Rect2()) as Rect2).position.y)
	var selected_y := float((layouts[6].get("front_rect", Rect2()) as Rect2).position.y)
	if neighbor_y - selected_y < 16.0:
		failures.append("selected tile needs at least a 16px lift at standard scale")
	var selection_contract: Dictionary = canvas.call("get_selection_feedback_contract")
	if str(selection_contract.get("shape_backup", "")) != "bottom_copper_keyline":
		failures.append("selected tile needs a non-color-only shape cue")
	var before_bounds: Rect2 = canvas.call("get_layout_bounds")
	canvas.call("set_reduced_motion", true)
	if canvas.call("get_layout_bounds") != before_bounds:
		failures.append("reduced motion changed hand layout bounds")
	canvas.free()


func _verify_center_text(failures: Array[String]) -> void:
	var center := CENTER_SCENE.instantiate() as Control
	get_root().add_child(center)
	center.call("render", 22, 1, "上家出牌中")
	var left_direction := center.get_node_or_null("%LeftDirectionLabel") as Label
	var wall_count := center.get_node_or_null("%TurnChipLabel") as Label
	var countdown := center.get_node_or_null("%CountLabel") as Label
	if left_direction == null or left_direction.visible:
		failures.append("center must not expose highlighted direction text")
	if wall_count == null or wall_count.text != "22":
		failures.append("center must keep wall count as a borderless static number on the center surface")
	elif not wall_count.rotation == 0.0:
		failures.append("2D fallback count must remain still like the 3D center-surface number")
	if countdown == null or countdown.visible:
		failures.append("center compass must not expose a presentation countdown")
	center.queue_free()


func _tile(id: int, suit: String, rank: int) -> Dictionary:
	return {"id": id, "suit": suit, "rank": rank, "display_name": "%d万" % rank}
