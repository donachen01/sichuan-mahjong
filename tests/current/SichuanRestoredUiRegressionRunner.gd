extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


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
	await _verify_glass_ai_hint(scene, failures)
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
	var difficulty_button: Button = utility_bar.call("get_button", "settings")
	var reveal_button: Button = utility_bar.call("get_button", "opponent_hands")
	if difficulty_button == null or not difficulty_button.visible or not difficulty_button.text.contains("难度"):
		failures.append("左上角必须显示可点击的 AI 难度")
	else:
		difficulty_button.emit_signal("pressed")
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
	for action in ["ai", "settings", "opponent_hands", "exit"]:
		var rect: Rect2 = utility_bar.call("get_touch_rect", action)
		if rect.size.x < 64.0 or rect.size.y < 64.0:
			failures.append("左上角 %s 点击区过小" % action)


func _verify_glass_ai_hint(scene: Node, failures: Array[String]) -> void:
	var drawer: Control = scene.get("ai_assistant_drawer")
	var hand: Control = scene.get("self_hand_host")
	var root_ui: Control = scene.get("root_ui")
	if drawer == null or hand == null or root_ui == null:
		failures.append("AI 提示面板或本家手牌区不存在")
		return
	var previous_ai_helper := bool(scene.get("ai_helper_enabled"))
	scene.set("ai_helper_enabled", true)
	drawer.visible = true
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
	if absf(drawer_rect.get_center().x - hand_rect.get_center().x) > 160.0:
		failures.append("AI 提示面板应与本家手牌居中对齐")
	var opacity_slider: HSlider = drawer.get_node_or_null("RootPanel/Margin/VBox/Header/OpacitySlider") as HSlider
	var old_opacity := float(drawer.call("get_glass_opacity"))
	if opacity_slider == null:
		failures.append("AI 玻璃提示缺少可任意拖动的清透比例条")
	else:
		if opacity_slider.min_value > 0.40 or opacity_slider.max_value < 0.90 or opacity_slider.step > 0.01:
			failures.append("AI 清透比例条可调范围或精度不足")
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
	scene.set("ai_helper_enabled", previous_ai_helper)


func _verify_rich_settlement(scene: Node, failures: Array[String]) -> void:
	var snapshot := _settlement_snapshot()
	scene.set("last_snapshot", {"current_phase": 6})
	scene.call("_refresh_settlement", snapshot)
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
