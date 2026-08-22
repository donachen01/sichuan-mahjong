extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const UTILITY_BAR_SCRIPT_PATH := "res://scripts/ui/table/TableUtilityBar.gd"
const ACTION_BAR_SCRIPT_PATH := "res://scripts/ui/table/TableActionBar.gd"
const HAND_VIEWPORT_SCENE := preload("res://scenes/ui/PlayerHandViewport.tscn")
const TABLE_STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
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
		await _verify_ios_settlement_close_and_next_round(root_node, utility_bar, failures)
	await _verify_action_bar(root_node, failures)
	_verify_summer_ding_que_controls(root_node, failures)
	await _verify_hand_layout_pressure(failures)
	await _verify_real_3d_hand_touch_projection(failures)

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
	if not utility_bar.has_method("set_collapsed") or not utility_bar.has_method("is_collapsed"):
		failures.append("左上角工具栏必须支持展开/缩进")
		return
	utility_bar.call("set_collapsed", true)
	if not bool(utility_bar.call("is_collapsed")):
		failures.append("左上角工具栏必须能缩进")
	var collapsed_toggle: Button = utility_bar.call("get_button", "toggle")
	if collapsed_toggle == null or not collapsed_toggle.visible:
		failures.append("缩进后必须保留可点击的展开按钮")
	elif collapsed_toggle.text != "☰":
		failures.append("缩进入口必须使用单一菜单图标")
	elif not collapsed_toggle.tooltip_text.contains("难度：骨灰") or not collapsed_toggle.tooltip_text.contains("明牌：关"):
		failures.append("缩进入口 tooltip 必须保留当前难度和明牌状态")
	elif collapsed_toggle.size.x < 76.0 or collapsed_toggle.size.y < 76.0:
		failures.append("缩进图标点击区必须至少为 76x76")
	elif collapsed_toggle.focus_mode != Control.FOCUS_ALL:
		failures.append("缩进入口必须支持键盘/手柄焦点")
	utility_bar.call("set_collapsed", false)
	utility_bar.call("_layout_buttons")
	for legacy_name in ["top_ai_helper_button", "top_settlement_info_button", "top_next_round_button", "top_exit_button"]:
		var legacy_button: Button = root_node.get(legacy_name)
		if legacy_button != null and legacy_button.visible:
			failures.append("legacy control must stay hidden: %s" % legacy_name)

	var visible_actions := ["ai", "settings", "opponent_hands", "skin", "exit"]
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
	var exit_button: Button = utility_bar.call("get_button", "exit")
	if exit_button == null or exit_button.text != "退出游戏":
		failures.append("退出入口必须使用友好的“退出游戏”文字按钮")
	elif exit_button.size.x < 140.0:
		failures.append("退出游戏按钮必须保留清楚的横向文字点击区")
	if not root_node.has_method("_confirm_exit_game"):
		failures.append("iOS 退出入口缺少确认后的平台退出实现")
	else:
		root_node.call("_on_top_exit_pressed")
		var exit_dialog: ConfirmationDialog = root_node.get("exit_confirmation_dialog")
		if exit_dialog == null or exit_dialog.title != "退出游戏" \
				or exit_dialog.get_ok_button().text != "退出游戏" \
				or exit_dialog.get_cancel_button().text != "继续游戏":
			failures.append("退出游戏必须先显示友好的确认对话框")
		elif exit_dialog.visible:
			exit_dialog.hide()

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


func _verify_ios_settlement_close_and_next_round(root_node: Node, utility_bar: Control, failures: Array[String]) -> void:
	var manager: Node = root_node.get("game_manager")
	var game_state: Node = manager.get("game_state") if manager != null else null
	var overlay: Control = root_node.get("settlement_overlay")
	var close_button: Button = root_node.get("settlement_close_button")
	if game_state == null or overlay == null or close_button == null:
		failures.append("iOS 结算触控测试缺少 GameState 或结算按钮")
		return
	game_state.set("current_phase", 7)
	manager.set("latest_snapshot", {})
	manager.call("get_fresh_snapshot")
	root_node.set("settlement_dismissed", false)
	overlay.visible = true
	utility_bar.call("set_collapsed", true)
	root_node.call("_layout_settlement_overlay")
	await process_frame

	var close_touch := InputEventScreenTouch.new()
	close_touch.position = close_button.get_global_rect().get_center()
	close_touch.pressed = true
	root_node.call("_input", close_touch)
	await process_frame
	if overlay.visible:
		failures.append("iOS 原生触摸没有关闭积分结算层")
	if bool(utility_bar.call("is_collapsed")):
		failures.append("关闭积分后必须自动展开工具栏并露出下一局入口")
	var next_round_button: Button = utility_bar.call("get_button", "next_round")
	if next_round_button == null or not next_round_button.is_visible_in_tree() or next_round_button.disabled:
		failures.append("关闭积分后下一局按钮不可见或不可点击")
		return

	var round_before := int(game_state.get("round_index"))
	var next_touch := InputEventScreenTouch.new()
	next_touch.position = next_round_button.get_global_rect().get_center()
	next_touch.pressed = true
	root_node.call("_input", next_touch)
	await process_frame
	if int(game_state.get("round_index")) != round_before + 1:
		failures.append("iOS 原生触摸下一局后 round_index 没有推进")
	if int(game_state.get("current_phase")) != 2:
		failures.append("iOS 下一局触摸没有进入新一局投骰阶段")


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
		var minimum := Vector2(264.0, 264.0) if action == "hu" else Vector2(216.0, 216.0)
		if rect.size.x < minimum.x or rect.size.y < minimum.y:
			failures.append("%s action target is below its visual/touch contract" % action)
		action_rects.append(rect)
	for first_index in range(action_rects.size()):
		for second_index in range(first_index + 1, action_rects.size()):
			if action_rects[first_index].intersects(action_rects[second_index]):
				failures.append("action button touch targets overlap")
	var self_hand: Control = root_node.get("self_hand_host")
	if self_hand != null and self_hand.visible and action_bar.get_global_rect().intersects(self_hand.get_global_rect()):
		failures.append("action bar overlaps the self hand")
	if not action_bar.is_connected("action_selected", Callable(root_node, "_on_table_action_selected")):
		failures.append("action bar must dispatch through the existing MainScene callbacks")
	action_bar.call("hide_actions")

	var players := [
		{"seat": 0, "has_won": false},
		{"seat": 1, "has_won": false},
		{"seat": 2, "has_won": false},
		{"seat": 3, "has_won": false},
	]
	var self_hu_snapshot := {
		"players": players,
		"current_phase": 3,
		"human_can_self_hu": true,
		"human_reaction_options": {},
	}
	root_node.call("_refresh_table_action_bar", self_hu_snapshot)
	await process_frame
	if action_bar.call("get_visible_actions") != ["hu", "pass"]:
		failures.append("自摸快照必须同时显示胡与取消")
	var self_hu_button: Button = action_bar.call("get_button", "hu")
	var self_cancel_button: Button = action_bar.call("get_button", "pass")
	if self_hu_button == null or self_hu_button.text != "自摸" or self_hu_button.disabled:
		failures.append("自摸权限未映射为可用的自摸按钮")
	if self_cancel_button == null or self_cancel_button.text != "取消" or self_cancel_button.disabled:
		failures.append("自摸权限缺少可用的取消按钮")
	if not root_node.get("root_ui").get_global_rect().encloses(action_bar.get_global_rect()):
		failures.append("3D 模式胡/取消按钮超出手机可见区")

	var reaction_hu_snapshot := self_hu_snapshot.duplicate(true)
	reaction_hu_snapshot["human_can_self_hu"] = false
	reaction_hu_snapshot["human_reaction_options"] = {"can_hu": true, "can_pass": true}
	root_node.call("_refresh_table_action_bar", reaction_hu_snapshot)
	await process_frame
	if action_bar.call("get_visible_actions") != ["hu", "pass"]:
		failures.append("点炮胡响应必须同时显示胡与取消")
	if (action_bar.call("get_button", "hu") as Button).text != "胡" or (action_bar.call("get_button", "pass") as Button).text != "取消":
		failures.append("点炮胡响应的按钮文案回归")
	root_node.set("last_action_input_action", "")
	root_node.set("last_action_input_source", "")
	root_node.set("last_action_input_msec", -1)
	if bool(root_node.call("_is_duplicate_action_cross_input", "hu", "touch")):
		failures.append("第一个胡触摸不得被当作重复事件")
	if not bool(root_node.call("_is_duplicate_action_cross_input", "hu", "mouse")):
		failures.append("iOS 同一次胡的模拟鼠标事件必须被去重")
	action_bar.call("hide_actions")


func _verify_summer_ding_que_controls(root_node: Node, failures: Array[String]) -> void:
	var overlay: Control = root_node.get("ding_que_overlay")
	if overlay == null or not overlay.top_level or overlay.z_index < 400 or overlay.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("定缺层必须是高于牌桌工具的真正模态层")
	var buttons: Array[Button] = [
		root_node.get("ding_que_tiao_button"),
		root_node.get("ding_que_tong_button"),
		root_node.get("ding_que_wan_button"),
	]
	var expected_texts := ["条", "筒", "万"]
	var expected_shells := ["ding_que_tiao.png", "ding_que_tong.png", "ding_que_wan.png"]
	for index in range(buttons.size()):
		var button := buttons[index]
		if button == null:
			failures.append("定缺大圆印按钮缺失")
			continue
		if button.text != expected_texts[index] or not button.tooltip_text.begins_with("定缺"):
			failures.append("定缺圆印文案或辅助说明不完整")
		if button.custom_minimum_size.x < 230.0 or button.custom_minimum_size.y < 230.0:
			failures.append("定缺圆印的手机触控面积必须至少为230x230")
		var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
		if normal == null or normal.texture == null or not normal.texture.resource_path.ends_with(expected_shells[index]):
			failures.append("定缺选择必须使用 Blender 烘焙的翡翠印章外壳")
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		if focus == null or focus.corner_radius_top_left < 108 or focus.get_border_width(SIDE_TOP) < 4:
			failures.append("定缺选择缺少独立的圆形聚焦光环")
		if button.focus_mode != Control.FOCUS_ALL:
			failures.append("定缺圆印必须保留原生焦点与可点击性")
	var status_label: Label = root_node.get("ding_que_status_label")
	var hint_label: Label = root_node.get("ding_que_hint_label")
	if status_label.visible or hint_label.visible:
		failures.append("定缺阶段只能展示三枚选择，不得显示大标题或说明")
	var shade: ColorRect = root_node.get("ding_que_shade")
	if shade == null or shade.color.a < 0.10 or shade.color.a > 0.15:
		failures.append("定缺桌面压暗必须保持在10%-15%")
	var visual_contract: Dictionary = root_node.call("get_ding_que_visual_contract")
	if str(visual_contract.get("shell_pipeline", "")) != "blender_orthographic_baked_jade_seals":
		failures.append("定缺必须声明 Blender 正交烘焙印章管线")
	if float(visual_contract.get("selected_visual_lift_px", 0.0)) < 8.0 \
			or float(visual_contract.get("selected_visual_lift_px", 0.0)) > 12.0:
		failures.append("定缺选中印章的视觉抬升必须为8-12px")
	if bool(visual_contract.get("extra_confirmation_step", true)):
		failures.append("定缺不得增加二次确认步骤")
	if str(visual_contract.get("initial_focus_ring", "")) != "none":
		failures.append("定缺出现时不得预选条并只给条显示亮圈")
	root_node.call("_reset_ding_que_visual_state")
	for button in buttons:
		var normal_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		if button.has_focus():
			failures.append("定缺初始状态仍有单个选项获得亮圈")
		if normal_style != null and absf((normal_style.content_margin_top - normal_style.content_margin_bottom) + 14.0) > 0.01:
			failures.append("定缺文字没有按 CJK 字面重心在圆印内视觉居中")
	root_node.call("_apply_ding_que_selection_state", "tong")
	if not buttons[1].has_focus() or buttons[0].has_focus() or buttons[2].has_focus():
		failures.append("只有用户明确选择后，亮圈才应跟随被选中的筒")
	var selected_style := buttons[1].get_theme_stylebox("normal") as StyleBoxTexture
	if selected_style == null or selected_style.expand_margin_top < 8.0 or selected_style.expand_margin_top > 12.0:
		failures.append("定缺选中印章没有按合同向上抬升")
	if buttons[1].modulate.r <= 1.0 or buttons[0].modulate.a >= 0.90 or buttons[2].modulate.a >= 0.90:
		failures.append("定缺选中项必须提亮，其他两项必须降低饱和/存在感")
	root_node.call("_reset_ding_que_visual_state")
	for button in buttons:
		var reset_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		if reset_style == null or reset_style.expand_margin_top > 2.1 or button.modulate != Color.WHITE:
			failures.append("定缺提交或失败后必须完整复位印章状态")
	var utility_bar: Control = root_node.get("table_utility_bar")
	if overlay != null and utility_bar != null:
		utility_bar.call("set_collapsed", true)
		overlay.visible = true
		var utility_toggle: Button = utility_bar.call("get_button", "toggle")
		var blocked_touch := InputEventScreenTouch.new()
		blocked_touch.position = utility_toggle.get_global_rect().get_center()
		blocked_touch.pressed = true
		root_node.call("_input", blocked_touch)
		if not bool(utility_bar.call("is_collapsed")):
			failures.append("定缺模态层期间左上工具不得穿透点击")
		overlay.visible = false


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
		var first_rect: Rect2 = layouts[0].get("front_rect", Rect2())
		if first_rect.size.x < 100.0 or first_rect.size.y < 150.0:
			failures.append("compact self-hand tiles must remain readable at at least 100x150")
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


func _verify_real_3d_hand_touch_projection(failures: Array[String]) -> void:
	var original_viewport_size := get_root().size
	get_root().size = Vector2i(1365, 768)
	await process_frame
	await process_frame
	var stage := TABLE_STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	stage.set_reduced_motion(true)
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand := _make_tiles(14 if seat == 0 else 13)
		for tile_index in range(hand.size()):
			hand[tile_index]["id"] = 1000 + seat * 100 + tile_index
		all_hands.append(hand)
		players.append({
			"seat": seat,
			"has_won": false,
			"ding_que": "tong" if seat == 0 else "",
			"melds": [],
			"discards": [],
		})
	var selected_tile_id := int(all_hands[0][6].get("id", -1))
	stage.render_snapshot({
		"players": players,
		"human_can_discard": true,
		"human_last_draw_tile_id": int(all_hands[0].back().get("id", -1)),
		"recent_discard_tile_id": -1,
	}, all_hands, false, selected_tile_id, {})
	await process_frame
	await process_frame
	var selected_rect := Rect2()
	var measured_count := 0
	for key_value in stage.get("self_hand_keys") as Array:
		var tile := (stage.get("tile_nodes") as Dictionary).get(key_value) as SichuanTile3D
		if tile == null:
			continue
		var projected_rect := tile.get_screen_rect(stage.get_camera())
		var real_pick_rect := projected_rect.grow(12.0)
		measured_count += 1
		if minf(real_pick_rect.size.x, real_pick_rect.size.y) < 44.0:
			failures.append("3D self-hand tile %d real projected pick target is below 44pt: %s" % [tile.tile_id, real_pick_rect])
		if tile.tile_id == selected_tile_id:
			selected_rect = projected_rect
	if measured_count != 14:
		failures.append("compact 3D touch projection must measure all 14 self-hand tiles")
	if selected_rect.size == Vector2.ZERO:
		failures.append("selected 3D tile projection is missing")
	elif stage.find_tile_at_screen(selected_rect.get_center()) != selected_tile_id:
		failures.append("selected/lifted 3D tile must still resolve to its original tile_id")
	stage.queue_free()
	await process_frame
	get_root().size = original_viewport_size
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
