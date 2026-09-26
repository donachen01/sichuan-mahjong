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
	var toggle_glyph := collapsed_toggle.get_node_or_null("ToggleGlyph") as Control if collapsed_toggle != null else null
	if toggle_glyph == null or not toggle_glyph.has_meta("geometrically_centered_toggle_glyph"):
		failures.append("工具栏展开与收起图标必须使用独立绘制并按几何中心对齐")
	utility_bar.call("set_collapsed", false)
	var details_button: Button = utility_bar.call("get_button", "settlement")
	if details_button == null or not details_button.visible or not details_button.text.contains("对局详情"):
		failures.append("展开工具栏后必须提供统一的对局详情按钮")
	elif not collapsed_toggle.tooltip_text.contains("难度：骨灰") or not collapsed_toggle.tooltip_text.contains("明牌：关"):
		failures.append("缩进入口 tooltip 必须保留当前难度和明牌状态")
	elif collapsed_toggle.size.x < 76.0 or collapsed_toggle.size.y < 76.0:
		failures.append("缩进图标点击区必须至少为 76x76")
	elif collapsed_toggle.size.x > 120.0 or collapsed_toggle.size.y > 120.0:
		failures.append("左上角工具入口必须保持轻量的小尺寸")
	elif collapsed_toggle.focus_mode != Control.FOCUS_ALL:
		failures.append("缩进入口必须支持键盘/手柄焦点")
	var toggle_style := collapsed_toggle.get_theme_stylebox("normal") as StyleBoxFlat
	if toggle_style == null or toggle_style.bg_color.a >= 0.60 \
			or toggle_style.corner_radius_top_left < 40 \
			or toggle_style.border_color.a >= 0.60:
		failures.append("菜单与收起图标必须使用统一的半透明圆形玻璃样式")
	var seat_huds: Dictionary = root_node.get("seat_huds")
	var upper_hud: Control = seat_huds.get(1)
	if upper_hud != null and collapsed_toggle.get_global_rect().intersects(upper_hud.get_global_rect()):
		failures.append("收起状态的左上工具按钮不得遮挡上家铭牌")
	utility_bar.call("set_collapsed", false)
	utility_bar.call("_layout_buttons")
	var drawer_panel := utility_bar.get_node_or_null("DrawerPanel") as Panel
	var drawer_gradient := drawer_panel.get_node_or_null("DrawerGradient") as ColorRect if drawer_panel != null else null
	var drawer_style := drawer_panel.get_theme_stylebox("panel") as StyleBoxFlat if drawer_panel != null else null
	if drawer_gradient == null or drawer_gradient.material == null \
			or not drawer_gradient.has_meta("utility_gradient_shadow"):
		failures.append("左上角工具栏展开后必须显示向牌桌淡出的半透明渐变层")
	if drawer_style == null or drawer_style.shadow_color.a < 0.20 or drawer_style.shadow_size < 10:
		failures.append("左上角工具栏展开背景必须保留柔和半透明黑影")
	for legacy_name in ["top_ai_helper_button", "top_settlement_info_button", "top_next_round_button", "top_exit_button"]:
		var legacy_button: Button = root_node.get(legacy_name)
		if legacy_button != null and legacy_button.visible:
			failures.append("legacy control must stay hidden: %s" % legacy_name)

	var visible_actions := ["ai", "settings", "opponent_hands", "skin", "voice", "settlement", "exit"]
	var visible_rects: Array[Rect2] = []
	var measured_actions: Array[String] = []
	for action in visible_actions:
		var button: Button = utility_bar.call("get_button", action)
		if button == null or not button.visible:
			failures.append("normal-round utility button missing: %s" % action)
			continue
		var rect: Rect2 = utility_bar.call("get_touch_rect", action)
		if rect.size.x < MIN_TOUCH_SIZE.x or rect.size.y < MIN_TOUCH_SIZE.y:
			failures.append("%s touch target is smaller than 76x76" % action)
		if root_node.get_viewport().get_visible_rect().size.is_equal_approx(Vector2(2048.0, 1152.0)) \
				and (rect.size.x < 520.0 or rect.size.y < 164.0 or button.get_theme_font_size("font_size") < 64):
			failures.append("%s 必须保持上一版工具按钮与文字的至少两倍尺寸" % action)
		var normal_style := button.get_theme_stylebox("normal") as StyleBoxFlat
		if normal_style == null or normal_style.bg_color.a > 0.02 \
				or normal_style.border_width_left + normal_style.border_width_top \
				+ normal_style.border_width_right + normal_style.border_width_bottom > 0:
			failures.append("%s 必须显示为无框的图标文字菜单项" % action)
		visible_rects.append(rect)
		measured_actions.append(action)
	var exit_button: Button = utility_bar.call("get_button", "exit")
	if exit_button == null or not exit_button.text.contains("退出牌局"):
		failures.append("牌桌退出入口必须明确使用“退出牌局”文字")
	elif exit_button.size.x < 140.0:
		failures.append("退出牌局按钮必须保留清楚的横向文字点击区")
	if not root_node.has_method("_confirm_exit_game") or not root_node.has_method("get_exit_target_scene_path"):
		failures.append("退出入口缺少退出当前牌局的实现")
	elif str(root_node.call("get_exit_target_scene_path")) != "res://scenes/network/GameModeSelect.tscn":
		failures.append("退出游戏必须返回已有的游戏模式选择页")
	elif root_node.get("exit_confirmation_dialog") != null:
		failures.append("退出游戏不得再创建二次确认对话框")
	# Verify the same explicit pointer-routing path used by native iOS touches.
	# Replace the destructive scene transition temporarily so the runner can
	# prove the visible exit entry emits exactly one request.
	if exit_button != null:
		var production_exit := Callable(root_node, "_on_top_exit_pressed")
		var exit_count := [0]
		var test_exit := func() -> void: exit_count[0] += 1
		if utility_bar.is_connected("exit_pressed", production_exit):
			utility_bar.disconnect("exit_pressed", production_exit)
		utility_bar.connect("exit_pressed", test_exit)
		var exit_handled := bool(root_node.call(
			"_handle_table_utility_click",
			exit_button.get_global_rect().get_center(),
			"direct"
		))
		utility_bar.disconnect("exit_pressed", test_exit)
		utility_bar.connect("exit_pressed", production_exit)
		if not exit_handled or exit_count[0] != 1:
			failures.append("退出游戏按钮必须通过真实指针路由准确触发一次退出请求")

	for first_index in range(visible_rects.size()):
		for second_index in range(first_index + 1, visible_rects.size()):
			if visible_rects[first_index].intersects(visible_rects[second_index]):
				failures.append("utility touch targets overlap: %s / %s" % [
					measured_actions[first_index], measured_actions[second_index]
				])

	# 展开抽屉是顶层覆盖式界面，按产品合同允许覆盖牌桌和铭牌；但所有
	# 入口必须保持在可见区内，不能用覆盖许可掩盖裁切或不可点击问题。
	var root_rect: Rect2 = root_node.get("root_ui").get_global_rect()
	for rect in visible_rects:
		if not root_rect.encloses(rect):
			failures.append("expanded utility control leaves the visible viewport")

	for hidden_action in ["details", "next_round"]:
		var hidden_button: Button = utility_bar.call("get_button", hidden_action)
		if hidden_button != null and hidden_button.visible:
			failures.append("%s must be hidden during a live round" % hidden_action)


func _verify_settlement_visibility(utility_bar: Control, failures: Array[String]) -> void:
	utility_bar.call("render", false, true, false)
	var next_round_button: Button = utility_bar.call("get_button", "next_round")
	var settlement_button: Button = utility_bar.call("get_button", "settlement")
	if next_round_button.visible:
		failures.append("工具栏不得再提供重复的下一局按钮")
	if not settlement_button.visible:
		failures.append("统一对局详情入口必须始终可见")

	utility_bar.call("render", false, true, true)
	if not settlement_button.visible or settlement_button.disabled:
		failures.append("settlement reopen must appear after the overlay is dismissed")
	for action in ["settlement"]:
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
	root_node.call("_on_top_settlement_info_pressed")
	utility_bar.call("set_collapsed", true)
	await process_frame
	var tabs: Array = root_node.get("settlement_details_tab_buttons")
	var original_content: Control = root_node.get("settlement_content")
	var tab_bar: Control = root_node.get("settlement_details_tabs")
	var pages_host: Control = root_node.get("settlement_details_pages")
	var footer_button: Button = root_node.get("next_round_button")
	if footer_button == null or not footer_button.visible or footer_button.text.replace(" ", "") != "下一局":
		failures.append("单机结算页必须直接显示下一局按钮")
	if not close_button.visible:
		failures.append("单机结算页必须保留独立的关闭按钮")
	var header_spacer: Control = root_node.get("settlement_header_left_spacer")
	var page_header: Control = root_node.get_node_or_null("%SettlementPageHeaderBand") as Control
	if page_header == null and header_spacer != null:
		page_header = header_spacer.get_parent()
	if tabs.size() != 4:
		failures.append("原结算页必须包含当前局结算、排行、流水、规则四个页签")
	var settlement_panel: Control = root_node.get("settlement_panel")
	if tab_bar == null or settlement_panel == null \
			or tab_bar.get_global_rect().end.y >= settlement_panel.get_global_rect().position.y:
		failures.append("四个页签必须独立位于中央内容框外上方")
	if page_header == null or page_header.visible:
		failures.append("精简结算页不应再显示重复的本局标题和局数副标题")
	if pages_host == null or footer_button == null \
			or settlement_panel == null or footer_button.get_global_rect().position.y <= settlement_panel.get_global_rect().end.y:
		failures.append("关闭按钮必须独立位于中央内容框外下方")
	if original_content == null or not original_content.visible:
		failures.append("默认页签必须保留并显示原有完整结算内容")
	if tabs.size() == 4:
		root_node.set("settlement_details_history", [
			{"round_index": 1, "score_changes": {0: 3, 1: -1, 2: -1, 3: -1}},
			{"round_index": 2, "score_changes": {0: -2, 1: 4, 2: -1, 3: -1}},
		])
		root_node.set("settlement_details_controllers", [
			{"seat": 0, "nickname": "玩家一"}, {"seat": 1, "nickname": "玩家二"},
			{"seat": 2, "nickname": "电脑一"}, {"seat": 3, "nickname": "电脑二"},
		])
		for tab_index in range(1, 4):
			var tab_button := tabs[tab_index] as Button
			var touch_rect := tab_button.get_global_rect()
			if touch_rect.size.x < MIN_TOUCH_SIZE.x or touch_rect.size.y < MIN_TOUCH_SIZE.y:
				failures.append("%s真机触控区域不足" % tab_button.text)
			var consumed := bool(root_node.call("_handle_settlement_overlay_click", touch_rect.get_center()))
			await process_frame
			if not consumed or int(root_node.get("settlement_details_selected_tab")) != tab_index:
				failures.append("%s无法通过真机原生触摸路由打开" % tab_button.text)
			if original_content.visible:
				failures.append("切换附加页签时应隐藏原结算内容，但不能删除或替换它")
			var pages: Array = root_node.get("settlement_details_page_nodes")
			var cards := pages[tab_index - 1].get_node("Cards") as VBoxContainer if pages.size() >= tab_index else null
			var page_scroll := pages[tab_index - 1] as ScrollContainer if pages.size() >= tab_index else null
			if cards == null or cards.get_child_count() == 0:
				failures.append("%s页签必须采用结算风格卡片呈现完整内容" % (tabs[tab_index] as Button).text)
			if page_scroll == null:
				failures.append("%s页签缺少纵向滚动容器" % (tabs[tab_index] as Button).text)
			else:
				var page_bar := page_scroll.get_v_scroll_bar()
				if page_scroll.mouse_filter != Control.MOUSE_FILTER_STOP \
						or page_bar == null or page_bar.mouse_filter != Control.MOUSE_FILTER_STOP:
					failures.append("%s的滚动容器和滚动条必须接收鼠标与真机拖拽" % (tabs[tab_index] as Button).text)
				elif not bool(root_node.call("_is_settlement_scroll_input_target", page_scroll.get_global_rect().get_center())):
					failures.append("%s未进入结算层滚动输入白名单" % (tabs[tab_index] as Button).text)
				elif page_bar.max_value > page_bar.page:
					var target_value := minf(page_bar.max_value - page_bar.page, maxf(1.0, page_bar.page * 0.35))
					page_bar.value = target_value
					await process_frame
					if page_scroll.scroll_vertical <= 0:
						failures.append("%s滚动条值未驱动页面内容滚动" % (tabs[tab_index] as Button).text)
					page_bar.value = 0.0
			if tab_index == 2:
				var ledger_text := ""
				for label_node in cards.find_children("*", "Label", true, false) if cards != null else []:
					ledger_text += str((label_node as Label).text)
				if not ledger_text.contains("本局加减") or not ledger_text.contains("局后累计") \
					or not ledger_text.contains("第1局") or not ledger_text.contains("第2局"):
					failures.append("对局流水必须按局数显示每位玩家的本局加减分和局后累计值")
			if tab_index == 3:
				var rule_options := root_node.find_children("RuleOption_*", "Button", true, false)
				if rule_options.size() < 10:
					failures.append("玩法规则必须按局数、人数、模式、计分和番型展示可扩展配置项")
				for rule_option in rule_options:
					if not rule_option.has_meta("rule_key"):
						failures.append("玩法规则选项必须保留后续建房规则选择所需的规则键")
						break
				var rules_bar := page_scroll.get_v_scroll_bar() if page_scroll != null else null
				if rules_bar == null or rules_bar.max_value <= rules_bar.page:
					failures.append("玩法规则内容未形成可拖动的纵向滚动范围")
		root_node.call("_handle_settlement_overlay_click", (tabs[0] as Button).get_global_rect().get_center())
		await process_frame
		if not original_content.visible:
			failures.append("返回当前局结算后原有结算内容必须完整恢复")
		var breakdown_scroll: ScrollContainer = root_node.get("settlement_breakdown_scroll")
		if breakdown_scroll == null or breakdown_scroll.mouse_filter != Control.MOUSE_FILTER_STOP:
			failures.append("当前局分数明细缺少可拖动滚动容器")
		elif not bool(root_node.call("_is_settlement_scroll_input_target", breakdown_scroll.get_global_rect().get_center())):
			failures.append("当前局分数明细未进入结算层滚动输入白名单")

	close_button.pressed.emit()
	await process_frame
	if overlay.visible:
		failures.append("iOS 原生触摸没有关闭积分结算层")
	if close_button.text.replace(" ", "") != "关闭":
		failures.append("结算页关闭按钮文案错误")
	var round_action_bar := root_node.get("lan_round_action_bar") as Control
	var round_action_button := root_node.get("lan_round_ready_button") as Button
	if round_action_bar == null or round_action_button == null \
			or not round_action_bar.visible or round_action_button.text != "下一局":
		failures.append("单机结算关闭后必须出现底部下一局玻璃按钮")
	elif round_action_button.get_global_rect().size.x < MIN_TOUCH_SIZE.x \
			or round_action_button.get_global_rect().size.y < MIN_TOUCH_SIZE.y:
		failures.append("单机下一局按钮的触控区域不足")
	if not bool(utility_bar.call("is_collapsed")):
		failures.append("结算关闭后工具栏不应自动展开")


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
	root_node.set("draw_transition_active", true)
	root_node.call("_refresh_table_action_bar", self_hu_snapshot)
	await process_frame
	if action_bar.call("get_visible_actions") != ["hu", "pass"]:
		failures.append("摸牌演出不得遮挡已生效的自摸/取消按钮")
	root_node.set("draw_transition_active", false)

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
		if absf(button.size.x - button.size.y) > 1.0:
			failures.append("定缺圆按钮被容器拉成椭圆")
		var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
		if normal == null or normal.texture == null or not normal.texture.resource_path.ends_with(expected_shells[index]):
			failures.append("定缺选择必须使用碰、取消同款圆形渐变玻璃按钮")
		elif normal.texture.get_width() != normal.texture.get_height():
			failures.append("定缺玻璃素材必须是正圆画布")
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
	if str(visual_contract.get("shell_pipeline", "")) != "recoloured_action_glass_badge":
		failures.append("定缺必须声明与碰、取消一致的玻璃按钮来源")
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
		if normal_style != null and absf((normal_style.content_margin_top - normal_style.content_margin_bottom) + 28.0) > 0.01:
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
		var utility_touch := InputEventScreenTouch.new()
		utility_touch.position = utility_toggle.get_global_rect().get_center()
		utility_touch.pressed = true
		root_node.call("_input", utility_touch)
		if bool(utility_bar.call("is_collapsed")):
			failures.append("定缺阶段左上角工具必须仍能展开")
		else:
			utility_touch.position = utility_toggle.get_global_rect().get_center()
			root_node.call("_input", utility_touch)
			if not bool(utility_bar.call("is_collapsed")):
				failures.append("定缺阶段左上角工具必须仍能缩进")
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
