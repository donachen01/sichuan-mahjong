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
	if collapsed_size.y < 100.0 or collapsed_size.x < 780.0:
		failures.append("AI 紧凑提示条未达到手机可读尺寸")
	if collapsed_size.y > 120.0 or collapsed_size.x > 860.0:
		failures.append("AI 紧凑提示条超出约定的可移动尺寸")
	var collapsed_opacity_label: Label = drawer.get_node_or_null("RootPanel/Margin/VBox/Header/OpacityLabel") as Label
	var collapsed_opacity_slider: HSlider = drawer.get_node_or_null("RootPanel/Margin/VBox/Header/OpacitySlider") as HSlider
	if collapsed_opacity_label == null or collapsed_opacity_slider == null:
		failures.append("AI 提示面板缺少透明度控件")
	elif collapsed_opacity_label.visible or collapsed_opacity_slider.visible:
		failures.append("AI 提示面板缩进后只应保留摘要和展开入口")
	drawer.call("set_expanded", true)
	drawer.call("apply_hint", _trainer_hint(), true, -1)
	drawer.call("apply_hint", _reaction_hint("peng"), false, -1)
	var summary_label := drawer.get_node_or_null("RootPanel/Margin/VBox/Content/SummaryLabel") as Label
	var reason_label := drawer.get_node_or_null("RootPanel/Margin/VBox/Content/ReasonLabel") as Label
	var available_label := drawer.get_node_or_null("RootPanel/Margin/VBox/Content/DangerLabel") as Label
	if summary_label == null or not summary_label.text.contains("建议碰") or not summary_label.text.contains("6筒"):
		failures.append("AI 提示框没有显示碰牌建议及响应牌")
	if reason_label == null or not reason_label.text.contains("碰后更快成叫"):
		failures.append("AI 碰牌提示没有显示核心判断原因")
	if available_label == null or not available_label.text.contains("碰") or not available_label.text.contains("过"):
		failures.append("AI 响应提示没有列出当前可选操作")
	drawer.call("set_expanded", false)
	var action_header := drawer.get_node_or_null("RootPanel/Margin/VBox/Header/Title") as Label
	if action_header == null or not action_header.text.contains("碰"):
		failures.append("AI 提示框收起后没有保留碰牌建议摘要")
	drawer.call("set_expanded", true)
	drawer.call("apply_hint", _self_action_hint(), false, -1)
	if summary_label == null or not summary_label.text.contains("建议：暗杠5筒"):
		failures.append("AI 提示框没有显示暗杠建议和对应牌")
	if reason_label == null or not reason_label.text.contains("不损速度"):
		failures.append("AI 暗杠提示没有显示判断原因")
	# Restore the discard example before the remaining placement/readability checks.
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
	var player_list: HBoxContainer = scene.get("settlement_player_list")
	var hand_row: VBoxContainer = scene.get("settlement_hand_row")
	var breakdown_list: VBoxContainer = scene.get("settlement_breakdown_list")
	if player_list == null or player_list.get_child_count() != 4:
		failures.append("结算必须展示四家总分与本局增减")
	elif _contains_exact_label_text(player_list, ["本", "对", "上", "下"]):
		failures.append("四家信息不应再显示本、对、上、下方位徽章，直接使用玩家名字")
	if hand_row == null or _count_nodes_with_script_path(hand_row, "res://scripts/ui/MahjongTile.gd") < 4:
		failures.append("结算必须使用麻将牌图展示手牌/副露，不能只显示文字列表")
	if breakdown_list == null or breakdown_list.get_child_count() < 4:
		failures.append("结算必须显示分数来源、对象、番/分与本局得分明细")
	var round_label: Label = scene.get("settlement_round_label")
	var page_header := scene.get_node_or_null("%SettlementPageHeaderBand") as Control
	var breakdown_title: Label = scene.get("settlement_breakdown_title")
	if round_label == null or page_header == null or page_header.visible:
		failures.append("精简结算页必须去掉重复的本局标题、局数和庄家标题带")
	if breakdown_title == null or breakdown_title.visible:
		failures.append("手牌下方应直接进入分数表格，不应再显示分数明细标签")
	var panel: Control = scene.get("settlement_panel")
	var root_ui: Control = scene.get("root_ui")
	var shade: ColorRect = scene.get("settlement_shade")
	if shade == null or shade.material == null or not shade.has_meta("settlement_blue_gradient"):
		failures.append("结算页必须使用全屏蓝白渐变背景，不得透出实时牌桌")
	if panel != null and root_ui != null and (panel.size.x > root_ui.size.x + 1.0 or panel.size.y > root_ui.size.y + 1.0):
		failures.append("结算面板不得超出屏幕")
	var panel_style := panel.get_theme_stylebox("panel") if panel != null else null
	if not panel_style is StyleBoxFlat:
		failures.append("结算主面板必须使用蓝白玻璃卡片样式")
	else:
		var flat_style := panel_style as StyleBoxFlat
		var border_total := flat_style.get_border_width(SIDE_LEFT) \
			+ flat_style.get_border_width(SIDE_TOP) \
			+ flat_style.get_border_width(SIDE_RIGHT) \
			+ flat_style.get_border_width(SIDE_BOTTOM)
		if border_total < 4 or border_total > 12 or flat_style.bg_color.get_luminance() < 0.72:
			failures.append("结算主面板必须保持细描边、高明度的蓝白玻璃观感")
	var ornament := panel.get_node_or_null("SettlementOrnamentOverlay") as TextureRect if panel != null else null
	if ornament != null and ornament.visible and ornament.modulate.a > 0.01:
		failures.append("蓝白结算页不得显示旧云纹、山水和竹叶装饰层")
	for card_name in ["settlement_detail_card"]:
		var section := scene.get(card_name) as Panel
		var section_style := section.get_theme_stylebox("panel") as StyleBoxFlat if section != null else null
		if section_style == null:
			failures.append("结算区域 %s 缺少透明样式" % card_name)
			continue
		var section_border_total := section_style.get_border_width(SIDE_LEFT) \
			+ section_style.get_border_width(SIDE_TOP) \
			+ section_style.get_border_width(SIDE_RIGHT) \
			+ section_style.get_border_width(SIDE_BOTTOM)
		if section_border_total != 0 or section_style.bg_color.a > 0.01:
			failures.append("上下结算区不得再添加独立外框，只保留主透明外框")
	var unified_surface := panel.get_node_or_null("UnifiedContentSurface") as Panel if panel != null else null
	var unified_style := unified_surface.get_theme_stylebox("panel") as StyleBoxFlat if unified_surface != null else null
	if unified_style == null or unified_style.bg_color.a > 0.01 \
			or unified_style.get_border_width(SIDE_LEFT) + unified_style.get_border_width(SIDE_TOP) \
			+ unified_style.get_border_width(SIDE_RIGHT) + unified_style.get_border_width(SIDE_BOTTOM) != 0:
		failures.append("统一内容层必须透明无边框，避免与主外框重叠")
	var detail_tabs: HBoxContainer = scene.get("settlement_details_tabs")
	if detail_tabs == null or detail_tabs.get_child_count() != 4:
		failures.append("结算页必须保留四个等宽页签")
	else:
		var active_tab := detail_tabs.get_child(0) as Button
		var active_style := active_tab.get_theme_stylebox("normal") as StyleBoxFlat
		if active_style == null or active_style.bg_color.b <= active_style.bg_color.r:
			failures.append("当前结算页签必须使用鲜明蓝色选中态")
	var player_list_card := scene.get("settlement_player_list_card") as Panel
	var player_list_style := player_list_card.get_theme_stylebox("panel") as StyleBoxFlat if player_list_card != null else null
	if player_list_style == null or player_list_style.bg_color.a > 0.01 \
			or player_list_style.get_border_width(SIDE_LEFT) + player_list_style.get_border_width(SIDE_TOP) \
			+ player_list_style.get_border_width(SIDE_RIGHT) + player_list_style.get_border_width(SIDE_BOTTOM) != 0:
		failures.append("上方四家玩家模块外不得再包一层整体外框")
	for card_name in ["settlement_hand_card", "settlement_breakdown_card"]:
		var inner_section := scene.get(card_name) as Panel
		var inner_style := inner_section.get_theme_stylebox("panel") as StyleBoxFlat if inner_section != null else null
		if inner_style == null:
			failures.append("结算内层 %s 缺少透明样式" % card_name)
			continue
		var inner_border_total := inner_style.get_border_width(SIDE_LEFT) \
			+ inner_style.get_border_width(SIDE_TOP) \
			+ inner_style.get_border_width(SIDE_RIGHT) \
			+ inner_style.get_border_width(SIDE_BOTTOM)
		if inner_border_total != 0 or inner_style.bg_color.a > 0.01:
			failures.append("结算内层 %s 不得拆分手牌与分数明细的共同外框" % card_name)
	var connected_frame := panel.get_node_or_null("ConnectedSelectionFrame") as Line2D if panel != null else null
	if connected_frame != null:
		failures.append("结算页不得保留连通式选中外框")
	# A completed local round must be available immediately in both detail tabs.
	scene.call("_remember_completed_round", snapshot)
	scene.call("_update_rich_settlement_match_details")
	if (scene.get("settlement_details_history") as Array).is_empty():
		failures.append("结算后对局排行和流水没有即时记录本局数据")
	for tab_index in [1, 2]:
		scene.call("_select_rich_settlement_tab", tab_index)
		await process_frame
		var page := (scene.get("settlement_details_page_nodes") as Array)[tab_index - 1] as ScrollContainer
		var cards := page.get_node("Cards") as VBoxContainer
		var expected_text := "第1名" if tab_index == 1 else "第3局"
		if cards.get_child_count() == 0 or not _contains_label_fragment(cards, expected_text):
			failures.append("对局详情第%d页未显示已完成局的排行或流水" % tab_index)
		if cards.find_child("DetailsTable", true, false) == null:
			failures.append("对局详情第%d页缺少可读的多列表格" % tab_index)
		if panel.size.x < root_ui.size.x * 0.88:
			failures.append("对局详情内容框没有充分利用横屏宽度")
		if page.get_v_scroll_bar().custom_minimum_size.x < 30.0:
			failures.append("对局详情滚动条触控宽度不足")
	var blank_press := Vector2(8, 8)
	if not scene.call("_handle_settlement_overlay_click", blank_press) or not rich_overlay.visible:
		failures.append("对局详情空白处点击不得退出")
	scene.call("_select_rich_settlement_tab", 0)

	# Exercise the same explicit ScreenTouch path used on iOS. The full-screen
	# overlay must route a player-row press before it consumes the event.
	scene.set("last_snapshot", snapshot)
	var player_buttons: Dictionary = scene.get("settlement_player_buttons")
	var target_button := player_buttons.get(2) as Button
	if target_button == null:
		failures.append("结算玩家行没有暴露可点击的对家按钮")
	else:
		var player_touch := InputEventScreenTouch.new()
		player_touch.position = target_button.get_global_rect().get_center()
		player_touch.pressed = true
		scene.call("_input", player_touch)
		await process_frame
		await process_frame
		var hero_name: Label = scene.get("settlement_hero_name")
		if int(scene.get("settlement_selected_seat")) != 2 or hero_name == null or not hero_name.text.contains("对家"):
			failures.append("点击任一玩家后必须切换到该家的手牌与具体分数来源")

	await _verify_settlement_responsive_bounds(scene, failures)

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
		10
	)
	var wall_draw_total := int(scene.call("_sum_settlement_breakdown_scores", wall_draw_lines))
	if wall_draw_total != 10:
		failures.append("已胡玩家不得重复查叫：胡牌与杠分合计期望 +10，实际 %+d" % wall_draw_total)
	var has_winner_cha_jiao := false
	var has_generic_reconciliation := false
	for line in wall_draw_lines:
		has_winner_cha_jiao = has_winner_cha_jiao or str(line.get("reason", "")).contains("查大叫收益（已胡）")
		has_generic_reconciliation = has_generic_reconciliation or str(line.get("reason", "")) == "其他结算调整"
	if has_winner_cha_jiao:
		failures.append("已胡玩家的分数明细不得再次出现查大叫收益")
	if has_generic_reconciliation:
		failures.append("修正后的权威总账不得依赖无法解释的其他结算调整")


func _verify_settlement_responsive_bounds(scene: Node, failures: Array[String]) -> void:
	var original_size := get_root().size
	for viewport_size in [Vector2i(1365, 768), Vector2i(2048, 1152), Vector2i(2400, 1080), Vector2i(2556, 1179)]:
		get_root().size = viewport_size
		await process_frame
		scene.call("_layout_settlement_overlay")
		await process_frame
		await process_frame
		var root_ui: Control = scene.get("root_ui")
		var panel: Control = scene.get("settlement_panel")
		var content: Control = scene.get("settlement_content")
		var next_button: Control = scene.get("next_round_button")
		var tabs: Control = scene.get("settlement_details_tabs")
		var player_list: HBoxContainer = scene.get("settlement_player_list")
		var breakdown_list: VBoxContainer = scene.get("settlement_breakdown_list")
		if root_ui == null or panel == null or content == null or next_button == null or tabs == null:
			failures.append("结算四档布局验证缺少必要控件")
			break
		var root_rect := root_ui.get_global_rect()
		var panel_rect := panel.get_global_rect()
		if not _rect_contains_with_tolerance(root_rect, panel_rect, 1.0):
			failures.append("结算面板在 %dx%d 超出界面：%s / %s" % [viewport_size.x, viewport_size.y, panel_rect, root_rect])
		for entry in [
			{"name": "主体内容", "rect": content.get_global_rect()},
		]:
			if not _rect_contains_with_tolerance(panel_rect, entry.get("rect"), 1.0):
				failures.append("结算%s在 %dx%d 超出主面板" % [entry.get("name"), viewport_size.x, viewport_size.y])
		if not _rect_contains_with_tolerance(root_rect, next_button.get_global_rect(), 1.0):
			failures.append("结算关闭按钮在 %dx%d 超出全屏背景" % [viewport_size.x, viewport_size.y])
		if tabs.get_global_rect().end.y >= panel_rect.position.y:
			failures.append("结算页签在 %dx%d 未独立位于中央内容框外上方" % [viewport_size.x, viewport_size.y])
		if next_button.get_global_rect().position.y <= panel_rect.end.y:
			failures.append("结算关闭按钮在 %dx%d 未独立位于中央内容框外下方" % [viewport_size.x, viewport_size.y])
		var width_ratio := panel.size.x / root_ui.size.x
		var height_ratio := panel.size.y / root_ui.size.y
		if width_ratio < 0.55 or width_ratio > 0.82 or height_ratio < 0.62 or height_ratio > 0.94:
			failures.append("结算面板在 %dx%d 未保持非全屏悬浮卡片比例（%.3f x %.3f）" % [viewport_size.x, viewport_size.y, width_ratio, height_ratio])
		if player_list != null and _children_width_ratio(player_list) < 0.88:
			failures.append("结算四家横排卡在 %dx%d 未充分利用横向空间" % [viewport_size.x, viewport_size.y])
		if breakdown_list != null and _children_height_ratio(breakdown_list) < 0.72:
			failures.append("结算明细区域在 %dx%d 留白过多" % [viewport_size.x, viewport_size.y])
	get_root().size = original_size
	await process_frame
	scene.call("_layout_settlement_overlay")
	await process_frame


func _rect_contains_with_tolerance(outer: Rect2, inner: Rect2, tolerance: float) -> bool:
	return inner.position.x >= outer.position.x - tolerance \
		and inner.position.y >= outer.position.y - tolerance \
		and inner.end.x <= outer.end.x + tolerance \
		and inner.end.y <= outer.end.y + tolerance


func _children_width_ratio(container: Container) -> float:
	if container == null or container.size.x <= 1.0:
		return 0.0
	var occupied := 0.0
	for child in container.get_children():
		if child is Control and (child as Control).visible:
			occupied += (child as Control).size.x
	return occupied / container.size.x


func _children_height_ratio(container: Control) -> float:
	if container == null or container.size.y <= 1.0:
		return 0.0
	var occupied := 0.0
	for child in container.get_children():
		var control := child as Control
		if control != null and control.visible:
			occupied += control.size.y
	return occupied / container.size.y


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


func _reaction_hint(action: String) -> Dictionary:
	return {
		"hint_kind": "reaction",
		"reaction_advice": {
			"action": action,
			"reasons": ["碰后更快成叫", "保持当前牌路"],
			"source_tile_name": "6筒",
			"source_seat": 1,
		},
		"available_reactions": {"can_peng": true, "can_pass": true},
	}


func _self_action_hint() -> Dictionary:
	return {
		"hint_kind": "self_action",
		"self_action_advice": {
			"action": "gang",
			"gang_subtype": "an_gang",
			"tile_name": "5筒",
			"reasons": ["暗杠后不损速度", "杠牌收益可接受"],
			"can_self_hu": false,
			"can_an_gang": true,
			"can_add_gang": false,
		},
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


func _contains_exact_label_text(root: Node, values: Array[String]) -> bool:
	if root is Label and values.has((root as Label).text):
		return true
	for child in root.get_children():
		if _contains_exact_label_text(child, values):
			return true
	return false


func _contains_label_fragment(root: Node, fragment: String) -> bool:
	if root is Label and (root as Label).text.contains(fragment):
		return true
	for child in root.get_children():
		if _contains_label_fragment(child, fragment):
			return true
	return false


func _count_nodes_with_script_path(root: Node, script_path: String) -> int:
	var script: Script = root.get_script() as Script
	var count := 1 if script != null and script.resource_path == script_path else 0
	for child in root.get_children():
		count += _count_nodes_with_script_path(child, script_path)
	return count
