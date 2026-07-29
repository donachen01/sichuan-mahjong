extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const AI_PRESET_ORDER := ["intermediate", "bone_ash", "hell"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(2048, 1152)
	var failures: Array[String] = []
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	for _frame in range(4):
		await process_frame

	await _verify_top_left_controls(scene, failures)
	await _verify_ios_utility_dual_event_stability(scene, failures)
	await _verify_glass_ai_hint(scene, failures)
	await _verify_interaction_status(scene, failures)
	await _verify_rich_settlement(scene, failures)

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN RESTORED UI REGRESSION OK: SETTLEMENT + DIFFICULTY + REVEAL + GLASS HINT")
		quit(0)
		return
	push_error("SICHUAN RESTORED UI REGRESSION FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_top_left_controls(scene: Node, failures: Array[String]) -> void:
	var utility_bar: Control = scene.get("table_utility_bar")
	var manager: Node = scene.get("game_manager")
	if utility_bar == null or manager == null:
		failures.append("左上角工具栏或 GameManager 未创建")
		return
	var snapshot: Dictionary = manager.call("get_snapshot")
	var preset_name := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
	utility_bar.call("render", bool(scene.get("ai_helper_enabled")), false, false, "骨灰", bool(scene.get("opponent_hands_enabled")))
	var toggle_button: Button = utility_bar.call("get_button", "toggle")
	if toggle_button == null or not bool(utility_bar.call("is_collapsed")):
		failures.append("左上角工具栏默认必须处于缩进状态并保留入口")
	else:
		var toggle_rect := toggle_button.get_global_rect()
		if not bool(scene.call("_handle_table_utility_click", toggle_rect.get_center())):
			failures.append("左上角展开按钮的真实点击区没有响应")
		await process_frame
		if bool(utility_bar.call("is_collapsed")):
			failures.append("点击展开后左上角工具栏仍处于缩进状态")
	var difficulty_button: Button = utility_bar.call("get_button", "settings")
	var reveal_button: Button = utility_bar.call("get_button", "opponent_hands")
	if difficulty_button == null or not difficulty_button.visible or not difficulty_button.text.contains("难度"):
		failures.append("左上角必须显示可点击的 AI 难度")
	else:
		if not bool(scene.call("_handle_table_utility_click", difficulty_button.get_global_rect().get_center())):
			failures.append("难度按钮的真实点击区没有响应")
		await process_frame
		var changed_name := str(manager.call("get_snapshot").get("ai_tuning_config", {}).get("preset_name", ""))
		if changed_name == preset_name:
			failures.append("点击难度按钮后 AI 预设没有切换")
		manager.call("set_ai_preset", preset_name)
	var reveal_before := bool(scene.get("opponent_hands_enabled"))
	if reveal_button == null or not reveal_button.visible or not reveal_button.text.contains("明牌"):
		failures.append("左上角必须显示明牌开关")
	else:
		var reveal_rect := reveal_button.get_global_rect()
		if not bool(scene.call("_handle_table_utility_click", reveal_rect.get_center())):
			failures.append("明牌开关的真实点击区没有响应")
		await process_frame
		if bool(scene.get("opponent_hands_enabled")) == reveal_before:
			failures.append("通过真实点击区点击明牌后，对手手牌状态没有切换")
		else:
			scene.call("_handle_table_utility_click", reveal_rect.get_center())
			await process_frame
	var ai_button: Button = utility_bar.call("get_button", "ai")
	var ai_before := bool(scene.get("ai_helper_enabled"))
	if ai_button == null or not bool(scene.call("_handle_table_utility_click", ai_button.get_global_rect().get_center())):
		failures.append("AI 提示按钮的真实点击区没有响应")
	else:
		await process_frame
		if bool(scene.get("ai_helper_enabled")) == ai_before:
			failures.append("点击 AI 提示后开关状态没有切换")
		else:
			scene.call("_handle_table_utility_click", ai_button.get_global_rect().get_center())
			await process_frame
	for action in ["ai", "settings", "opponent_hands", "exit"]:
		var rect: Rect2 = utility_bar.call("get_touch_rect", action)
		if rect.size.x < 64.0 or rect.size.y < 64.0:
			failures.append("左上角 %s 点击区过小" % action)
	if toggle_button != null:
		var expanded_toggle_rect := toggle_button.get_global_rect()
		scene.call("_handle_table_utility_click", expanded_toggle_rect.get_center())
		await process_frame
		if not bool(utility_bar.call("is_collapsed")):
			failures.append("点击收起后左上角工具栏没有缩进")


func _verify_ios_utility_dual_event_stability(scene: Node, failures: Array[String]) -> void:
	var utility_bar: Control = scene.get("table_utility_bar")
	var manager: Node = scene.get("game_manager")
	if utility_bar == null or manager == null:
		failures.append("iOS 双事件压力回归缺少左上工具栏或 GameManager")
		return
	var initial_preset := str(manager.call("get_snapshot").get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
	var initial_ai := bool(scene.get("ai_helper_enabled"))
	var initial_reveal := bool(scene.get("opponent_hands_enabled"))
	utility_bar.call("set_collapsed", true)
	for cycle in range(12):
		var toggle_button: Button = utility_bar.call("get_button", "toggle")
		await _send_ios_dual_press(scene, toggle_button.get_global_rect().get_center())
		if bool(utility_bar.call("is_collapsed")):
			failures.append("iOS 双事件第 %d 轮：展开按钮被同一触摸执行两次" % [cycle + 1])
			break

		var ai_before := bool(scene.get("ai_helper_enabled"))
		var ai_button: Button = utility_bar.call("get_button", "ai")
		await _send_ios_dual_press(scene, ai_button.get_global_rect().get_center())
		if bool(scene.get("ai_helper_enabled")) == ai_before:
			failures.append("iOS 双事件第 %d 轮：AI 提示按钮被同一触摸执行两次" % [cycle + 1])
			break

		var preset_before := str(manager.call("get_snapshot").get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
		var preset_index := AI_PRESET_ORDER.find(preset_before)
		var expected_preset := str(AI_PRESET_ORDER[(preset_index + 1) % AI_PRESET_ORDER.size()])
		var settings_button: Button = utility_bar.call("get_button", "settings")
		await _send_ios_dual_press(scene, settings_button.get_global_rect().get_center())
		var preset_after := str(manager.call("get_snapshot").get("ai_tuning_config", {}).get("preset_name", ""))
		if preset_after != expected_preset:
			failures.append("iOS 双事件第 %d 轮：难度应只切换一次，实际 %s -> %s" % [cycle + 1, preset_before, preset_after])
			break

		var reveal_before := bool(scene.get("opponent_hands_enabled"))
		var reveal_button: Button = utility_bar.call("get_button", "opponent_hands")
		await _send_ios_dual_press(scene, reveal_button.get_global_rect().get_center())
		if bool(scene.get("opponent_hands_enabled")) == reveal_before:
			failures.append("iOS 双事件第 %d 轮：明牌按钮被同一触摸执行两次" % [cycle + 1])
			break

		toggle_button = utility_bar.call("get_button", "toggle")
		await _send_ios_dual_press(scene, toggle_button.get_global_rect().get_center())
		if not bool(utility_bar.call("is_collapsed")):
			failures.append("iOS 双事件第 %d 轮：缩进按钮被同一触摸执行两次" % [cycle + 1])
			break

	# 去重只允许拦截同一次物理点击产生的跨来源事件；连续的真实触摸
	# 必须仍然逐次生效，否则快速展开/缩进仍会表现为“偶尔按不动”。
	var touch_only_toggle: Button = utility_bar.call("get_button", "toggle")
	await _send_touch_press(scene, touch_only_toggle.get_global_rect().get_center())
	if bool(utility_bar.call("is_collapsed")):
		failures.append("连续真实触摸第 1 次没有展开左上工具栏")
	touch_only_toggle = utility_bar.call("get_button", "toggle")
	await _send_touch_press(scene, touch_only_toggle.get_global_rect().get_center())
	if not bool(utility_bar.call("is_collapsed")):
		failures.append("连续真实触摸第 2 次没有缩进左上工具栏")

	manager.call("set_ai_preset", initial_preset)
	if bool(scene.get("ai_helper_enabled")) != initial_ai:
		scene.call("_on_top_ai_helper_button_pressed")
	if bool(scene.get("opponent_hands_enabled")) != initial_reveal:
		scene.call("_on_top_opponent_hand_button_pressed")
	utility_bar.call("set_collapsed", true)


func _send_ios_dual_press(scene: Node, position: Vector2) -> void:
	# This stress case targets the normal-round utility drawer. The live scene's
	# opening timers can enter the modal DingQue phase while the 12-cycle loop is
	# running; hide that modal here so a correct modal block is not misreported
	# as an intermittent utility-button failure.
	var ding_que_overlay: Control = scene.get("ding_que_overlay")
	if ding_que_overlay != null:
		ding_que_overlay.visible = false
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.position = position
	touch_press.pressed = true
	scene.call("_input", touch_press)
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.position = position
	mouse_press.global_position = position
	mouse_press.pressed = true
	scene.call("_input", mouse_press)
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.position = position
	touch_release.pressed = false
	scene.call("_input", touch_release)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.position = position
	mouse_release.global_position = position
	mouse_release.pressed = false
	scene.call("_input", mouse_release)
	await process_frame


func _send_touch_press(scene: Node, position: Vector2) -> void:
	var ding_que_overlay: Control = scene.get("ding_que_overlay")
	if ding_que_overlay != null:
		ding_que_overlay.visible = false
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.position = position
	touch_press.pressed = true
	scene.call("_input", touch_press)
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.position = position
	touch_release.pressed = false
	scene.call("_input", touch_release)
	await process_frame


func _verify_glass_ai_hint(scene: Node, failures: Array[String]) -> void:
	var drawer: Control = scene.get("ai_assistant_drawer")
	var hand: Control = scene.get("self_hand_host")
	var root_ui: Control = scene.get("root_ui")
	if drawer == null or hand == null or root_ui == null:
		failures.append("AI 提示面板或本家手牌区不存在")
		return
	var previous_ai_helper := bool(scene.get("ai_helper_enabled"))
	var previous_visible := drawer.visible
	var previous_expanded := bool(drawer.call("is_expanded"))
	var previous_positioned := bool(drawer.call("is_user_positioned"))
	var previous_normalized := drawer.call("get_user_position_normalized") as Vector2
	scene.set("ai_helper_enabled", true)
	drawer.visible = true
	# Preferences are intentionally persistent in production.  Reset them here
	# so this assertion verifies the designed default placement, not whichever
	# location a developer last dragged to on their machine.
	drawer.call("restore_user_position", Vector2(0.5, 0.5), false)
	drawer.call("set_expanded", false)
	drawer.call("apply_hint", _trainer_hint(), true, -1)
	var readability_contract: Dictionary = drawer.call("get_readability_contract")
	if not bool(readability_contract.get("background_only_opacity", false)) or not bool(readability_contract.get("text_remains_opaque", false)):
		failures.append("AI 透明度只能作用于背景，文字和控件必须保持可读")
	if not bool(readability_contract.get("collapsed_summary_contains_risk", false)):
		failures.append("AI 紧凑提示必须同时显示推荐牌和风险摘要")
	var collapsed_size: Vector2 = readability_contract.get("collapsed_size", Vector2.ZERO)
	if collapsed_size.y > 76.0 or collapsed_size.x > 580.0:
		failures.append("AI 紧凑提示条仍然过大")
	var collapsed_opacity_label: Label = drawer.get_node_or_null("RootPanel/Margin/VBox/Header/OpacityLabel") as Label
	var collapsed_opacity_slider: HSlider = drawer.get_node_or_null("RootPanel/Margin/VBox/Header/OpacitySlider") as HSlider
	if collapsed_opacity_label == null or collapsed_opacity_slider == null:
		failures.append("AI 提示面板缺少透明度控件")
	elif collapsed_opacity_label.visible or collapsed_opacity_slider.visible:
		failures.append("AI 提示面板缩进后只应保留摘要和展开入口")
	drawer.call("set_expanded", true)
	drawer.call("apply_hint", _trainer_hint(), true, -1)
	scene.call("_layout_ai_assistant_drawer")
	await process_frame
	var drawer_rect := drawer.get_global_rect()
	var hand_rect := hand.get_global_rect()
	if drawer_rect.intersects(hand_rect):
		failures.append("AI 玻璃提示面板不得遮挡本家手牌")
	if drawer_rect.end.y > hand_rect.position.y + 1.0:
		failures.append("AI 提示面板必须位于本家手牌上方")
	var center_indicator: Control = scene.get("center_indicator")
	if center_indicator != null and drawer_rect.intersects(center_indicator.get_global_rect()):
		failures.append("AI 展开面板不得遮挡中央余牌与回合状态")
	var opacity_slider: HSlider = drawer.get_node_or_null("RootPanel/Margin/VBox/Header/OpacitySlider") as HSlider
	var old_opacity := float(drawer.call("get_glass_opacity"))
	if opacity_slider == null:
		failures.append("AI 玻璃提示缺少可任意拖动的清透比例条")
	else:
		if not opacity_slider.visible:
			failures.append("AI 提示面板展开后透明度滑杆必须恢复显示")
		if opacity_slider.min_value > 0.0 or opacity_slider.max_value < 1.0 or opacity_slider.step > 0.01:
			failures.append("AI 背景透明度必须支持 0%-100% 连续调节")
		opacity_slider.value = 0.0
		await process_frame
		if absf(float(drawer.call("get_glass_opacity"))) > 0.001:
			failures.append("AI 背景透明度无法调到 0%")
		var title_label := drawer.get_node_or_null("RootPanel/Margin/VBox/Header/Title") as Label
		if title_label == null or title_label.get_theme_constant("outline_size") < 4:
			failures.append("AI 背景低透明度时文字没有进入高对比可读模式")
		opacity_slider.value = 1.0
		await process_frame
		if absf(float(drawer.call("get_glass_opacity")) - 1.0) > 0.001:
			failures.append("AI 背景透明度无法调到 100%")
		opacity_slider.value = 0.57
		await process_frame
		if absf(float(drawer.call("get_glass_opacity")) - 0.57) > 0.001:
			failures.append("AI 清透比例条无法连续调节到 57%")
		drawer.call("set_glass_opacity", old_opacity)
		scene.call("_on_ai_glass_opacity_changed", old_opacity)

	drawer.call("restore_user_position", Vector2(0.5, 0.5), false)
	scene.call("_layout_ai_assistant_drawer")
	await process_frame
	var drag_start := drawer.position
	var changed_callback := Callable(scene, "_on_ai_drawer_position_changed")
	var finished_callback := Callable(scene, "_on_ai_drawer_position_change_finished")
	var changed_was_connected := drawer.is_connected("position_changed", changed_callback)
	var finished_was_connected := drawer.is_connected("position_change_finished", finished_callback)
	if changed_was_connected:
		drawer.disconnect("position_changed", changed_callback)
	if finished_was_connected:
		drawer.disconnect("position_change_finished", finished_callback)
	drawer.call("_begin_drag", drag_start + Vector2(80.0, 24.0))
	drawer.call("_drag_to", drag_start + Vector2(200.0, 104.0))
	drawer.call("_finish_drag")
	var dragged_position := drawer.position
	if dragged_position.distance_to(drag_start) < 20.0:
		failures.append("AI 决策建议框无法任意拖动位置")
	scene.call("_layout_ai_assistant_drawer")
	await process_frame
	if drawer.position.distance_to(dragged_position) > 2.0:
		failures.append("AI 决策建议框拖动后被布局刷新强制复位")
	if not root_ui.get_global_rect().encloses(drawer.get_global_rect()):
		failures.append("AI 决策建议框拖动后超出可见桌面")
	drawer.call("set_expanded", false)
	drawer.call("_on_toggle_pressed")
	await process_frame
	if not bool(drawer.call("is_expanded")):
		failures.append("AI 决策建议框拖动后无法再次展开")
	if opacity_slider != null:
		opacity_slider.value = 0.33
		await process_frame
		if absf(float(drawer.call("get_glass_opacity")) - 0.33) > 0.001:
			failures.append("AI 决策建议框拖动后透明度滑杆失效")
	if changed_was_connected:
		drawer.connect("position_changed", changed_callback)
	if finished_was_connected:
		drawer.connect("position_change_finished", finished_callback)
	drawer.call("set_glass_opacity", old_opacity)
	drawer.call("set_expanded", previous_expanded)
	drawer.call("restore_user_position", previous_normalized, previous_positioned)
	drawer.visible = previous_visible
	scene.set("ai_helper_enabled", previous_ai_helper)


func _verify_rich_settlement(scene: Node, failures: Array[String]) -> void:
	var snapshot := _settlement_snapshot()
	scene.set("last_snapshot", {"current_phase": 6})
	scene.call("_refresh_settlement", snapshot)
	scene.call("force_complete_settlement_transition_for_test")
	await process_frame
	var rich_overlay: Control = scene.get("settlement_overlay")
	var simplified_overlay: Control = scene.get("settlement_overlay_v2")
	if rich_overlay == null or not rich_overlay.visible:
		failures.append("本局结束时必须显示原完整结算面板")
	if simplified_overlay != null and simplified_overlay.visible:
		failures.append("简化结算面板不得覆盖原完整结算")
	var player_list: VBoxContainer = scene.get("settlement_player_list")
	var hand_row: VBoxContainer = scene.get("settlement_hand_row")
	var breakdown_list: VBoxContainer = scene.get("settlement_breakdown_list")
	if player_list == null or player_list.get_child_count() != 4:
		failures.append("结算必须展示四家总分与本局增减")
	if hand_row == null or _count_nodes_with_script_path(hand_row, "res://scripts/ui/MahjongTile.gd") < 4:
		failures.append("结算必须使用麻将牌图展示手牌/副露，不能只显示文字列表")
	if breakdown_list == null or breakdown_list.get_child_count() < 4:
		failures.append("结算必须显示分数来源、对象、番/分与本局得分明细")
	var round_label: Label = scene.get("settlement_round_label")
	if round_label == null or not round_label.text.contains("庄家"):
		failures.append("结算必须保留局数、庄家和结束原因")
	var panel: Control = scene.get("settlement_panel")
	var root_ui: Control = scene.get("root_ui")
	if panel != null and root_ui != null and (panel.size.x > root_ui.size.x + 1.0 or panel.size.y > root_ui.size.y + 1.0):
		failures.append("结算面板不得超出屏幕")
	var panel_style := panel.get_theme_stylebox("panel") if panel != null else null
	if not panel_style is StyleBoxTexture:
		failures.append("结算主面板必须使用 Blender 生成的深翡翠九宫格资源")
	else:
		var textured_style := panel_style as StyleBoxTexture
		if textured_style.texture == null or not textured_style.texture.resource_path.ends_with("settlement_panel_9slice.png"):
			failures.append("结算主面板九宫格资源路径不正确")

	var wall_draw_after_win := {
		"end_reason": "draw_wall_empty",
		"winner_seats": [0],
		"win_events": [{
			"winner_seat": 0,
			"source_seat": 0,
			"payer_seats": [2, 3],
			"win_type": "self_draw",
			"fan_detail": {
				"capped_fan": 0,
				"hand_score": 1,
				"per_payer_score": 2,
				"labels": ["平胡", "自摸"],
			},
		}],
		"gang_events": [{
			"actor_seat": 0,
			"gang_type": "an_gang",
			"payer_seats": [1, 2, 3],
		}],
		"draw_assessment": [
			{"seat": 2, "is_ting": true, "hua_zhu": false, "cha_jiao_score": 2},
			{"seat": 3, "is_ting": false, "hua_zhu": false, "cha_jiao_score": 0},
		],
	}
	var wall_draw_lines: Array[Dictionary] = scene.call(
		"_build_settlement_breakdown_lines",
		snapshot.get("players", []),
		wall_draw_after_win,
		0,
		11
	)
	var wall_draw_total := int(scene.call("_sum_settlement_breakdown_scores", wall_draw_lines))
	if wall_draw_total != 11:
		failures.append("结算明细合计必须严格等于最终收分：期望 +11，实际 %+d" % wall_draw_total)
	var has_winner_cha_jiao := false
	var has_generic_reconciliation := false
	for line in wall_draw_lines:
		has_winner_cha_jiao = has_winner_cha_jiao or str(line.get("reason", "")).contains("查大叫收益（已胡）")
		has_generic_reconciliation = has_generic_reconciliation or str(line.get("reason", "")) == "其他结算调整"
	if not has_winner_cha_jiao:
		failures.append("牌墙流局后已胡玩家收到的查大叫必须作为独立明细显示")
	if has_generic_reconciliation:
		failures.append("已知查大叫收益不得退化成无法解释的其他结算调整")


func _verify_interaction_status(scene: Node, failures: Array[String]) -> void:
	var players: Array = []
	for seat in range(4):
		players.append({
			"seat": seat,
			"nickname": ["本家", "上家", "对家", "下家"][seat],
			"score": 0,
			"ding_que": "wan",
			"has_won": false,
		})
	var reaction_snapshot := {
		"players": players,
		"current_turn_seat": 1,
		"current_dealer_seat": 3,
		"human_reaction_options": {"can_peng": true, "can_pass": true},
		"rules": {"use_ding_que_phase": true},
	}
	if int(scene.call("_active_interaction_seat", reaction_snapshot)) != 0:
		failures.append("碰/杠/胡响应阶段必须把本家标为当前操作方")
	if str(scene.call("_center_interaction_status", reaction_snapshot)) != "等待本家响应":
		failures.append("响应阶段中央状态不得继续显示上家出牌中")
	scene.call("_update_seat_huds", reaction_snapshot)
	await process_frame
	var seat_huds: Dictionary = scene.get("seat_huds")
	var self_hud: Control = seat_huds.get(0)
	var upper_hud: Control = seat_huds.get(1)
	var self_turn_badge := self_hud.get_node_or_null("%TurnBadge") as Label if self_hud != null else null
	var upper_turn_badge := upper_hud.get_node_or_null("%TurnBadge") as Label if upper_hud != null else null
	if self_turn_badge == null or self_turn_badge.visible:
		failures.append("响应阶段本家信息框不应显示响应文字徽标，应使用铭牌亮圈")
	if upper_turn_badge != null and upper_turn_badge.visible:
		failures.append("响应阶段不得同时把上家和本家都标成当前操作方")


func _trainer_hint() -> Dictionary:
	return {
		"recommended": {
			"tile": {"id": 9009, "suit": "tiao", "rank": 9},
			"tile_name": "9条",
			"shanten": 1,
			"live_ukeire": 8,
			"risk_label": "低危",
			"reasons": ["边九孤张，先拆掉", "保留两面搭子"],
		},
		"options": [],
		"danger_tiles": [{"tile_name": "7万", "risk_label": "中危", "risk_reasons": ["下家连续舍相邻牌"]}],
		"current_routes": ["做清一色", "保留两面进张"],
	}


func _settlement_snapshot() -> Dictionary:
	var players: Array = []
	for seat in range(4):
		var hand_tiles: Array = []
		for index in range(7):
			hand_tiles.append({
				"id": seat * 100 + index,
				"suit": ["tiao", "tong", "wan"][index % 3],
				"rank": index % 9 + 1,
			})
		players.append({
			"seat": seat,
			"nickname": ["本家", "上家", "对家", "下家"][seat],
			"score": [18, -4, -8, -6][seat],
			"hand_tiles": hand_tiles,
			"melds": [{
				"type": "peng",
				"tile": {"id": 8000 + seat, "suit": "tong", "rank": 3},
				"tiles": [
					{"id": 8100 + seat * 10, "suit": "tong", "rank": 3},
					{"id": 8101 + seat * 10, "suit": "tong", "rank": 3},
					{"id": 8102 + seat * 10, "suit": "tong", "rank": 3},
				],
				"from_seat": (seat + 1) % 4,
			}],
			"ding_que": ["tong", "wan", "tiao", "wan"][seat],
			"has_won": seat == 0,
		})
	return {
		"current_phase": 7,
		"round_index": 3,
		"current_dealer_seat": 1,
		"ai_tuning_config": {"preset_name": "bone_ash"},
		"rules": {"use_ding_que_phase": true},
		"players": players,
		"settlement_data": {
			"round_index": 3,
			"dealer_seat": 1,
			"end_reason": "battle_end",
			"winner_seats": [0],
			"score_changes": {0: 18, 1: -4, 2: -8, 3: -6},
			"win_events": [{
				"winner_seat": 0,
				"source_seat": 2,
				"payer_seats": [2],
				"win_type": "discard_win",
				"winning_tile": {"id": 9999, "suit": "wan", "rank": 9},
				"fan_detail": {"capped_fan": 3, "hand_score": 8, "labels": ["清一色", "平胡"]},
			}],
			"gang_events": [{"actor_seat": 0, "gang_type": "melded_gang", "payer_seats": [1, 2, 3]}],
			"tui_gang_refunds": [{"actor_seat": 0, "gang_type": "melded_gang", "payer_seats": [1, 2, 3]}],
			"transfer_events": [{"transfer_type": "hu_jiao_zhuan_yi", "to_seat": 0, "gang_type": "melded_gang", "payer_seats": [2]}],
		},
	}


func _count_nodes_named(root: Node, node_name: String) -> int:
	var count := 1 if root.name == node_name else 0
	for child in root.get_children():
		count += _count_nodes_named(child, node_name)
	return count


func _count_nodes_with_script_path(root: Node, script_path: String) -> int:
	var script: Script = root.get_script() as Script
	var count := 1 if script != null and script.resource_path == script_path else 0
	for child in root.get_children():
		count += _count_nodes_with_script_path(child, script_path)
	return count
