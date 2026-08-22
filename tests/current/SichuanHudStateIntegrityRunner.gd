extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1365, 768)
	var failures: Array[String] = []
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	for _frame in range(5):
		await process_frame
	for timer in scene.find_children("*", "Timer", true, false):
		(timer as Timer).stop()
	scene.set("draw_transition_active", false)

	await _verify_ding_que_modal(scene, failures)
	_verify_opening_roll_phase_contract(scene, failures)
	await _verify_hud_and_center(scene, failures)
	await _verify_hu_and_cancel(scene, failures)
	await _verify_utility_reliability(scene, failures)
	await _verify_ai_drawer_after_drag(scene, failures)
	await _verify_reveal_and_won_states(scene, failures)

	scene.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SICHUAN HUD STATE INTEGRITY OK: DINGQUE + HUD + HU/CANCEL + REVEAL + WON + UTILITY + AI")
		quit(0)
		return
	push_error("SICHUAN HUD STATE INTEGRITY FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_ding_que_modal(scene: Node, failures: Array[String]) -> void:
	var overlay: Control = scene.get("ding_que_overlay")
	var buttons: Array[Button] = [
		scene.get("ding_que_tiao_button"),
		scene.get("ding_que_tong_button"),
		scene.get("ding_que_wan_button"),
	]
	if overlay == null or buttons.size() != 3:
		failures.append("定缺模态层或三个圆印按钮缺失")
		return
	var was_visible := overlay.visible
	overlay.visible = true
	overlay.move_to_front()
	await process_frame
	await process_frame
	if not overlay.top_level or overlay.z_index < 400 or overlay.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("定缺模态层没有阻断牌桌穿透输入")
	var status_label: Label = scene.get("ding_que_status_label")
	var hint_label: Label = scene.get("ding_que_hint_label")
	if status_label == null or hint_label == null or status_label.visible or hint_label.visible:
		failures.append("定缺阶段必须只展示条/筒/万三个选项，不得保留标题或提示文字")
	var panel: Panel = scene.get("ding_que_panel")
	var card: Panel = scene.get("ding_que_button_card")
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
	var card_style := card.get_theme_stylebox("panel") as StyleBoxFlat if card != null else null
	if panel_style == null or card_style == null or panel_style.bg_color.a > 0.01 or card_style.bg_color.a > 0.01:
		failures.append("定缺三枚玉印必须直接浮在桌面上，不能残留外层提示卡")
	var expected_texts := ["条", "筒", "万"]
	var rects: Array[Rect2] = []
	scene.call("_reset_ding_que_visual_state")
	for index in range(buttons.size()):
		var button := buttons[index]
		if button == null or button.text != expected_texts[index]:
			failures.append("定缺圆印文案顺序不是条/筒/万")
			continue
		if button.custom_minimum_size.x < 220.0 or button.custom_minimum_size.y < 220.0:
			failures.append("定缺圆印未达到 220×220 设计门槛")
		var style := button.get_theme_stylebox("normal") as StyleBoxTexture
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		if style == null or style.texture == null or focus == null \
				or focus.corner_radius_top_left < 108 or focus.get_border_width(SIDE_TOP) < 4:
			failures.append("定缺按钮必须使用 Blender 翡翠印章外壳和 Godot 聚焦光环")
		if style != null and absf((style.content_margin_top - style.content_margin_bottom) + 14.0) > 0.01:
			failures.append("定缺文字必须按 CJK 字面重心向上补偿 7px，确保条/筒/万在圆内视觉居中")
		if button.has_focus():
			failures.append("定缺出现时不得预先给任一选项亮圈")
		if button.get_theme_font_size("font_size") < 68 or button.get_theme_constant("outline_size") < 2:
			failures.append("定缺文字字号或深色描边低于可读门槛")
		rects.append(button.get_global_rect())
	for first in range(rects.size()):
		for second in range(first + 1, rects.size()):
			if rects[first].intersects(rects[second], true):
				failures.append("定缺圆印真实点击区发生重叠")
	overlay.visible = was_visible


func _verify_opening_roll_phase_contract(scene: Node, failures: Array[String]) -> void:
	var contract: Dictionary = scene.call("get_opening_roll_visual_contract")
	var visual_seconds := float(contract.get("total_visual_seconds", 0.0))
	var audio_seconds := float(contract.get("audio_seconds", 0.0))
	if not bool(contract.get("hidden_during_ding_que", false)):
		failures.append("骰子必须在定缺阶段开始前隐藏")
	if str(contract.get("completion_clock", "")) != "monotonic_deadline_independent_of_rendered_tick_count":
		failures.append("投骰结束必须使用与帧率无关的单调时钟截止时间")
	if visual_seconds < audio_seconds or visual_seconds - audio_seconds > 0.08:
		failures.append("骰子动画结束时刻必须与3秒投骰声音对齐")
	var commit_timer: Timer = scene.get("opening_roll_commit_timer")
	if commit_timer == null or not commit_timer.one_shot or absf(commit_timer.wait_time - visual_seconds) > 0.001:
		failures.append("投骰完成计时器必须在动画开始时独立锁定3.05秒截止点")
	var tick_timer: Timer = scene.get("opening_roll_timer")
	if tick_timer != null:
		scene.set("opening_roll_payload", {"die_a": 2, "die_b": 5})
		scene.set("opening_roll_animation_started_msec", Time.get_ticks_msec() - int((audio_seconds - 0.20) * 1000.0))
		tick_timer.start()
		scene.call("_on_opening_roll_timer_timeout")
		if not tick_timer.is_stopped():
			failures.append("低帧率跳过换点回调时，骰子没有按单调时钟切到最终点数")

	var opening_snapshot := {
		"current_phase": int(contract.get("visible_phase", 2)),
		"players": [{"seat": 0, "ding_que": ""}],
		"rules": {"use_ding_que_phase": true},
		"opening_roll": {"die_a": 2, "die_b": 5},
		"wall_count": 55,
	}
	scene.call("_refresh_opening_roll_ui", opening_snapshot)
	var dice_layer: Control = scene.get("dice_overlay_layer")
	if dice_layer == null or not dice_layer.visible:
		failures.append("开局投骰阶段必须显示骰子")
	var ding_que_snapshot := opening_snapshot.duplicate(true)
	ding_que_snapshot["current_phase"] = 3
	scene.call("_refresh_opening_roll_ui", ding_que_snapshot)
	if dice_layer != null and dice_layer.visible:
		failures.append("投骰声音和动画完成进入定缺后，骰子仍然可见")
	var center_indicator: Control = scene.get("center_turn_indicator")
	if center_indicator != null and center_indicator.visible:
		failures.append("等待玩家定缺时不得用中央余牌数遮挡三个选项")


func _verify_hud_and_center(scene: Node, failures: Array[String]) -> void:
	var seat_huds: Dictionary = scene.get("seat_huds")
	if seat_huds.size() != 4:
		failures.append("座位 HUD 数量必须为 4")
		return
	var players: Array = []
	for seat in range(4):
		players.append({
			"seat": seat,
			"nickname": ["陈旭", "舒燕", "陈东", "舒玲"][seat],
			"score": [8, -2, -3, -3][seat],
			"ding_que": ["tiao", "tong", "wan", "tiao"][seat],
			"has_won": seat == 0,
		})
	var snapshot := {
		"players": players,
		"current_turn_seat": 1,
		"current_dealer_seat": 2,
		"human_reaction_options": {},
		"human_can_self_hu": false,
	}
	scene.call("_update_seat_huds", snapshot)
	for seat in range(4):
		var hud: Control = seat_huds.get(seat)
		if hud == null:
			failures.append("SeatHUD%d 缺失" % seat)
			continue
		var name_label := hud.get_node_or_null("%NameLabel") as Label
		var avatar_glyph := hud.get_node_or_null("%AvatarGlyph") as Label
		var score_label := hud.get_node_or_null("%ScoreLabel") as Label
		var ding_badge: Control = hud.call("get_ding_que_badge")
		if name_label == null or name_label.text != players[seat]["nickname"]:
			failures.append("SeatHUD%d 没有消费 nickname" % seat)
		if avatar_glyph == null or avatar_glyph.text != ["旭", "燕", "东", "玲"][seat]:
			failures.append("SeatHUD%d 的姓名缩写圆圈映射错误" % seat)
		if score_label == null or score_label.text != "%d分" % players[seat]["score"]:
			failures.append("SeatHUD%d 没有消费 score" % seat)
		if ding_badge == null or not ding_badge.visible:
			failures.append("SeatHUD%d 没有显示定缺状态" % seat)
		if seat != 1 and hud.is_processing():
			failures.append("SeatHUD%d 非活动状态仍在执行逐帧动画" % seat)
	await create_timer(0.22).timeout
	for seat in range(4):
		var hud: Control = seat_huds.get(seat)
		if hud != null and hud.is_processing():
			failures.append("SeatHUD%d 的 180ms 活动边缘入场结束后仍在逐帧处理" % seat)
	var self_won := (seat_huds.get(0) as Control).get_node_or_null("%WonBadge") as Label
	var dealer := (seat_huds.get(2) as Control).get_node_or_null("%DealerBadge") as Label
	var turn := (seat_huds.get(1) as Control).get_node_or_null("%TurnBadge") as Label
	if self_won == null or not self_won.visible or self_won.text != "自摸":
		failures.append("自摸 HUD 缺少文字状态")
	if dealer == null or not dealer.visible or dealer.text != "庄":
		failures.append("庄家 HUD 缺少文字状态")
	if turn == null or turn.visible:
		failures.append("当前行动 HUD 不应再显示出牌文字状态")
	var center: Control = scene.get("center_turn_indicator")
	if center == null:
		failures.append("中央余牌组件缺失")
		return
	var center_contract: Dictionary = center.call("get_visual_contract")
	var directions: Array = center_contract.get("direction_labels", [])
	if directions != ["东", "南", "西", "北"]:
		failures.append("中央区必须按参考图提供东/南/西/北四向")
	if center_contract.get("active_encoding", []) != ["opaque_vivid_red_main_field_and_both_chamfer_fills", "warm_ivory_direction_glyph_with_dark_outline"]:
		failures.append("中央当前方位必须同时使用红色梯形和亮色文字，不得只靠颜色")
	if str(center_contract.get("active_color_hex", "")) != "A13D2D":
		failures.append("中央当前方位的 2D 降级色必须保持为 #A13D2D")
	if str(center_contract.get("concept", "")) != "reference_four_way_turn_panel" \
			or bool(center_contract.get("persistent_long_status_text", true)):
		failures.append("中央区必须使用参考图四向仪表盘，且不得常驻长状态句")
	var wall_count := center.get_node_or_null("%TurnChipLabel") as Label
	if wall_count == null or not wall_count.visible or not wall_count.text.is_valid_int():
		failures.append("余牌必须使用贴在中心图形上的纯数字")
	var background := center.get_node_or_null("%BackgroundPanel") as Panel
	var compass_overlay := center.get_node_or_null("%CompassVisual") as Control
	if background == null or background.visible or compass_overlay == null or not compass_overlay.visible:
		failures.append("中央组件必须保留完整 2D 四向回退；3D 模式由父节点整体隐藏而不是破坏回退内容")


func _verify_hu_and_cancel(scene: Node, failures: Array[String]) -> void:
	var action_bar: Control = scene.get("table_action_bar")
	if action_bar == null:
		failures.append("TableActionBar 缺失")
		return
	var players := [{"seat": 0, "has_won": false}, {"seat": 1, "has_won": false}, {"seat": 2, "has_won": false}, {"seat": 3, "has_won": false}]
	var self_snapshot := {
		"players": players,
		"current_phase": 3,
		"human_can_self_hu": true,
		"human_reaction_options": {},
	}
	scene.call("_refresh_table_action_bar", self_snapshot)
	await process_frame
	_verify_action_pair(action_bar, "自摸", failures)
	var reaction_snapshot := self_snapshot.duplicate(true)
	reaction_snapshot["human_can_self_hu"] = false
	reaction_snapshot["human_reaction_options"] = {"can_hu": true, "can_pass": true}
	scene.call("_refresh_table_action_bar", reaction_snapshot)
	await process_frame
	_verify_action_pair(action_bar, "胡", failures)
	var observed: Array[String] = []
	action_bar.connect("action_selected", func(action: String) -> void: observed.append(action))
	for action in ["hu", "pass"]:
		scene.call("_refresh_table_action_bar", reaction_snapshot)
		await process_frame
		var rect: Rect2 = action_bar.call("get_touch_rect", action)
		if not bool(scene.call("_handle_table_action_click", rect.get_center(), "direct")):
			failures.append("%s 真实点击区未响应" % action)
		await process_frame
	if observed != ["hu", "pass"]:
		failures.append("胡/取消没有通过既有 action_selected 通路，actual=%s" % [observed])
	action_bar.call("hide_actions")


func _verify_action_pair(action_bar: Control, hu_label: String, failures: Array[String]) -> void:
	if action_bar.call("get_visible_actions") != ["hu", "pass"]:
		failures.append("%s状态必须同时显示胡与取消" % hu_label)
		return
	var hu_button := action_bar.call("get_button", "hu") as Button
	var pass_button := action_bar.call("get_button", "pass") as Button
	if hu_button == null or hu_button.text != hu_label or hu_button.disabled:
		failures.append("%s按钮文案或启用状态错误" % hu_label)
	if pass_button == null or pass_button.text != "取消" or pass_button.disabled:
		failures.append("%s状态缺少可用的取消按钮" % hu_label)
	var hu_rect: Rect2 = action_bar.call("get_touch_rect", "hu")
	var pass_rect: Rect2 = action_bar.call("get_touch_rect", "pass")
	if hu_rect.size.x < 132.0 or hu_rect.size.y < 132.0 or pass_rect.size.x < 108.0 or pass_rect.size.y < 108.0:
		failures.append("%s/取消真实点击区低于动作圆印门槛" % hu_label)
	if hu_rect.intersects(pass_rect, true):
		failures.append("%s与取消点击区发生重叠" % hu_label)


func _verify_utility_reliability(scene: Node, failures: Array[String]) -> void:
	var utility: Control = scene.get("table_utility_bar")
	if utility == null:
		failures.append("左上工具栏缺失")
		return
	utility.call("render", false, false, false, "骨灰", false)
	utility.call("set_collapsed", true)
	for index in range(20):
		var toggle: Button = utility.call("get_button", "toggle")
		var expected := not bool(utility.call("is_collapsed"))
		if not bool(scene.call("_handle_table_utility_click", toggle.get_global_rect().get_center(), "touch")):
			failures.append("左上入口第 %d 次独立触摸未命中" % (index + 1))
			break
		await process_frame
		if bool(utility.call("is_collapsed")) != expected:
			failures.append("左上入口第 %d 次独立触摸没有执行一次" % (index + 1))
			break
	utility.call("set_collapsed", false)
	for action in ["ai", "settings", "opponent_hands", "exit"]:
		var rect: Rect2 = utility.call("get_touch_rect", action)
		var minimum := Vector2(76.0, 76.0) if action == "exit" else Vector2(184.0, 76.0)
		if rect.size.x < minimum.x or rect.size.y < minimum.y:
			failures.append("左上 %s 点击区低于 %s" % [action, minimum])
	utility.call("set_collapsed", true)


func _verify_ai_drawer_after_drag(scene: Node, failures: Array[String]) -> void:
	var drawer: Control = scene.get("ai_assistant_drawer")
	if drawer == null:
		failures.append("AI 提示窗缺失")
		return
	var previous_visible := drawer.visible
	var previous_expanded := bool(drawer.call("is_expanded"))
	var previous_opacity := float(drawer.call("get_glass_opacity"))
	var previous_normalized := drawer.call("get_user_position_normalized") as Vector2
	var previous_positioned := bool(drawer.call("is_user_positioned"))
	# Exercise the drawer's finish event without writing a test corner into the
	# real desktop ui_prefs.cfg through MainSceneV2's persistence callbacks.
	var changed_callback := Callable(scene, "_on_ai_drawer_position_changed")
	var finished_callback := Callable(scene, "_on_ai_drawer_position_change_finished")
	var changed_was_connected := drawer.is_connected("position_changed", changed_callback)
	var finished_was_connected := drawer.is_connected("position_change_finished", finished_callback)
	if changed_was_connected:
		drawer.disconnect("position_changed", changed_callback)
	if finished_was_connected:
		drawer.disconnect("position_change_finished", finished_callback)
	drawer.visible = true
	var root_rect: Rect2 = scene.get("root_ui").get_global_rect()
	drawer.call("set_drag_bounds", root_rect)
	var corners := [root_rect.position, Vector2(root_rect.end.x, root_rect.position.y), root_rect.end, Vector2(root_rect.position.x, root_rect.end.y)]
	for corner in corners:
		drawer.call("_begin_drag", drawer.position)
		drawer.call("_drag_to", corner)
		drawer.call("_finish_drag")
		for _toggle in range(5):
			drawer.call("set_expanded", not bool(drawer.call("is_expanded")))
			if not root_rect.encloses(drawer.get_global_rect()):
				failures.append("AI 提示窗拖到边界后展开/收起越出安全区")
				break
	for opacity in [0.0, 0.25, 0.50, 0.75, 1.0]:
		drawer.call("set_glass_opacity", opacity)
		if not is_equal_approx(float(drawer.call("get_glass_opacity")), opacity):
			failures.append("AI 提示窗透明度无法设置为 %d%%" % int(opacity * 100.0))
	var contract: Dictionary = drawer.call("get_readability_contract")
	if not bool(contract.get("background_only_opacity", false)) or not bool(contract.get("text_remains_opaque", false)):
		failures.append("AI 透明度错误地影响了文字可读性")
	if not bool(contract.get("medium_opacity_text_scrim", false)) or float(contract.get("medium_opacity_threshold", 0.0)) < 0.50:
		failures.append("AI 提示窗 50% 背景下缺少正文可读性暗底")
	drawer.call("set_glass_opacity", 0.50)
	var summary: Label = drawer.get("summary_label")
	var medium_scrim := summary.get_theme_stylebox("normal") as StyleBoxFlat if summary != null else null
	if medium_scrim == null or medium_scrim.bg_color.a < 0.20:
		failures.append("AI 提示窗 50% 背景下正文暗底强度不足")
	drawer.call("set_glass_opacity", 0.0)
	var title: Label = drawer.get("title_label")
	var slider: HSlider = drawer.get("opacity_slider")
	if title == null or slider == null or title.mouse_filter != Control.MOUSE_FILTER_STOP or slider.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("AI 提示窗拖动热区仍可能吞掉展开或透明度操作")
	drawer.call("set_glass_opacity", previous_opacity)
	drawer.call("set_expanded", previous_expanded)
	drawer.call("restore_user_position", previous_normalized, previous_positioned)
	drawer.visible = previous_visible
	if changed_was_connected:
		drawer.connect("position_changed", changed_callback)
	if finished_was_connected:
		drawer.connect("position_change_finished", finished_callback)


func _verify_reveal_and_won_states(scene: Node, failures: Array[String]) -> void:
	var stage: Node3D = scene.get("table_stage_3d")
	if stage == null:
		failures.append("3D 牌桌层缺失")
		return
	stage.call("set_reduced_motion", true)
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand := _tiles(1000 + seat * 100, 11, seat)
		all_hands.append(hand)
		players.append({"seat": seat, "hand_tiles": hand if seat == 0 else [], "hand_count": hand.size(), "melds": [], "discards": [], "has_won": false})
	var snapshot := {"players": players, "wall_count": 40, "human_can_discard": true, "human_last_draw_tile_id": int(all_hands[0].back()["id"])}
	stage.call("render_snapshot", snapshot, all_hands, false, -1, {})
	await process_frame
	var initial_nodes: Dictionary = stage.get("tile_nodes")
	var initial_ids: Dictionary = {}
	for key in initial_nodes:
		initial_ids[key] = (initial_nodes[key] as Node).get_instance_id()
	for cycle in range(20):
		var reveal := cycle % 2 == 0
		stage.call("render_snapshot", snapshot, all_hands, reveal, -1, {})
		await process_frame
		var nodes: Dictionary = stage.get("tile_nodes")
		if nodes.size() != initial_nodes.size():
			failures.append("明牌连续切换导致 3D 牌节点数量增长")
			break
		for key in nodes:
			if initial_ids.get(key, -1) != (nodes[key] as Node).get_instance_id():
				failures.append("明牌连续切换错误地重建稳定牌节点")
				return
			if str(key).begins_with("hand_") and not str(key).begins_with("hand_0_"):
				var tile = nodes[key]
				if bool(tile.showing_face) != reveal:
					failures.append("稳定牌节点没有刷新明牌状态")
					return
	var won_players: Array = players.duplicate(true)
	won_players[0]["has_won"] = true
	won_players[0]["winning_tile"] = all_hands[0].back()
	won_players[0]["winning_source_seat"] = 1
	var won_snapshot := snapshot.duplicate(true)
	won_snapshot["players"] = won_players
	won_snapshot["human_can_discard"] = false
	stage.call("render_snapshot", won_snapshot, all_hands, false, -1, {})
	await process_frame
	var flat_revealed := 0
	var arrow_count := 0
	for key in (stage.get("tile_nodes") as Dictionary):
		if not (str(key).begins_with("hand_0_") or str(key).begins_with("winning_0_")):
			continue
		var tile = (stage.get("tile_nodes") as Dictionary)[key]
		if tile.showing_face and absf(tile.transform.basis.z.y) < 0.05:
			flat_revealed += 1
		if tile.winning_source_marker != null and tile.winning_source_marker.visible:
			arrow_count += 1
			if tile.winner_seat != 0 or tile.winning_source_seat != 1:
				failures.append("点炮箭头丢失赢家/来源座位身份")
	if flat_revealed != all_hands[0].size():
		failures.append("已胡手牌没有 %d/%d 全部倒下明牌" % [flat_revealed, all_hands[0].size()])
	if arrow_count != 1:
		failures.append("点炮胡来源箭头必须恰好一个，actual=%d" % arrow_count)
	var compact_badge: Node = scene.call("_create_winning_source_badge", Vector2(84, 112), 1)
	if compact_badge == null or compact_badge.get_child_count() != 1:
		failures.append("2D 胡牌来源必须只保留一个简单箭头图形")
	else:
		var arrow := compact_badge.get_child(0) as Polygon2D
		if arrow == null or not arrow.color.is_equal_approx(SichuanTile3D.SOURCE_ARROW_COLOR) or arrow.polygon.size() != 7:
			failures.append("2D 胡牌来源箭头不是统一的金黄色简化轮廓")
	compact_badge.free()
	if not (stage.get("self_hand_keys") as Array).is_empty():
		failures.append("已胡手牌仍暴露出牌点击目标")


func _tiles(start_id: int, count: int, offset: int) -> Array:
	var result: Array = []
	var suits := ["tiao", "tong", "wan"]
	for index in range(count):
		result.append({"id": start_id + index, "suit": suits[(index + offset) % suits.size()], "rank": (index * 2 + offset) % 9 + 1})
	return result
