extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/table/MainSceneV2.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var ui: Node = scene.find_child("LanRoomUI", true, false)
	assert(ui != null)
	assert(ui.get_parent() is CanvasLayer and int(ui.get_parent().layer) >= 900)
	ui._open_room_overlay()
	assert(ui.room_overlay.visible)
	ui.nickname_edit.text = "UI测试"
	ui._create_room()
	await process_frame
	assert(ui.lobby_overlay.visible and not ui.room_overlay.visible)
	assert(ui.ready_button.custom_minimum_size.x >= 700 and ui.ready_button.custom_minimum_size.y >= 130)
	assert(ui.start_button.custom_minimum_size.x >= 700 and ui.start_button.custom_minimum_size.y >= 130)
	assert(ui.ready_button.custom_minimum_size == ui.start_button.custom_minimum_size)
	assert(ui.start_button.custom_minimum_size == ui.leave_button.custom_minimum_size)
	assert(ui.ready_button.visible and not ui.start_button.visible)
	assert(ui.theme != null and ui.theme.default_font != null)
	var glass_panel := ui.lobby_panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert(glass_panel != null and glass_panel.texture.resource_path.ends_with("lan_lobby_panel_glass.png"))
	var pane_image := glass_panel.texture.get_image()
	assert(pane_image.get_pixel(430, 215).a < 0.12)
	assert(pane_image.get_pixel(4, 215).a > 0.75)
	for button in [ui.ready_button, ui.start_button, ui.leave_button]:
		var glass_button := button.get_theme_stylebox("normal") as StyleBoxTexture
		assert(glass_button != null and glass_button.texture != null)
	assert((ui.ready_button.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.ends_with("lan_lobby_ready_glass.png"))
	assert((ui.leave_button.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.ends_with("lan_lobby_leave_glass.png"))
	scene.ai_helper_enabled = true
	scene._update_ai_assistant_drawer({}, false)
	assert(not scene.ai_assistant_drawer.visible)
	var runtime: Node = root.get_node("LanRuntime")
	assert(str(runtime.session.current_room_state.get("room_number", "")).length() == 6)
	assert(runtime.session.current_room_state.get("controllers", []).size() == 4)
	var self_hud: Node = scene.find_child("SeatHUD0", true, false)
	var self_ready_button: Button = self_hud.find_child("RoomReadyButton", true, false)
	var self_ready_badge: Label = self_hud.find_child("TurnBadge", true, false)
	assert(self_ready_button != null and not self_ready_button.visible)
	assert(self_ready_badge.visible and "未准备" in self_ready_badge.text)
	runtime.match_active = true
	runtime.room_history.clear()
	runtime.room_history.append({"round_index": 1, "score_changes": {0: 1, 1: -1}})
	scene._remember_completed_round({
		"current_phase": 7, "round_index": 2,
		"players": [{"seat": 0, "nickname": "本家", "score": 3}],
		"settlement_data": {"ledger_valid": true, "score_changes": {0: 2, 1: -2}},
	})
	scene._update_rich_settlement_match_details()
	assert(int(scene.settlement_details_history.back().get("round_index", 0)) == 2)
	runtime.room_history.append({"round_index": 2, "score_changes": {0: 2, 1: -2}, "authority_marker": true})
	scene._update_rich_settlement_match_details()
	assert(bool(scene.settlement_details_history.back().get("authority_marker", false)))
	scene._update_ai_assistant_drawer({}, false)
	assert(scene.ai_assistant_drawer.visible)
	scene.table_utility_bar.set_collapsed(false)
	scene._on_settlement_close_pressed()
	assert(scene.table_utility_bar.is_collapsed())
	scene._refresh_lan_round_controls({"current_phase": 7})
	assert(scene.lan_round_action_bar.visible)
	assert(scene.lan_round_ready_button.text == "准备")
	var round_panel := scene.lan_round_action_bar.get_theme_stylebox("panel") as StyleBoxTexture
	var round_button := scene.lan_round_ready_button.get_theme_stylebox("normal") as StyleBoxTexture
	assert(round_panel != null and round_panel.texture.resource_path.ends_with("lan_round_ready_panel_glass.png"))
	assert(round_button != null and round_button.texture.resource_path.ends_with("lan_lobby_ready_glass.png"))
	assert(round_panel.texture.get_image().get_pixel(210, 52).a < 0.12)
	assert(scene.lan_round_ready_button.custom_minimum_size == Vector2(414, 98))
	var seat_button := self_hud.find_child("RoomReadyButton", true, false) as Button
	assert((seat_button.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.ends_with("lan_lobby_ready_glass.png"))
	scene._refresh_opening_roll_ui({"current_phase": 7, "players": [], "opening_roll_pending": false})
	assert(not scene.dice_overlay_layer.visible)
	assert(not scene.table_stage_3d.center_wall_count_anchor.visible)
	scene._refresh_opening_roll_ui({"current_phase": 2, "players": [], "opening_roll_pending": false})
	assert(not scene.dice_overlay_layer.visible)
	assert(not scene.table_stage_3d.center_wall_count_anchor.visible)
	scene._refresh_opening_roll_ui({"current_phase": 2, "players": [], "opening_roll_pending": true})
	assert(scene.dice_overlay_layer.visible)
	assert(scene.lan_round_action_bar.find_children("*", "Button", true, false).size() == 1)
	assert(scene.lan_round_action_bar.z_index < scene.settlement_overlay.z_index)
	assert(runtime.set_ready(true))
	scene._refresh_lan_round_controls({"current_phase": 7})
	assert(scene.lan_round_ready_button.text == "取消准备")
	assert(runtime.set_ready(false))
	scene._refresh_lan_round_controls({"current_phase": 7})
	assert(scene.lan_round_ready_button.text == "准备")
	# The host history broadcast can arrive after the guest already opened the
	# phase-7 settlement. The active ledger must refresh on history_changed.
	scene._select_rich_settlement_tab(2)
	assert(int(scene.settlement_details_history.back().get("round_index", 0)) == 2)
	runtime.room_history.assign([{
		"round_index": 1,
		"player_names": {0: "UI测试", 1: "电脑一", 2: "电脑二", 3: "电脑三"},
		"score_changes": {0: 3, 1: -1, 2: -1, 3: -1},
	}, {
		"round_index": 2,
		"player_names": {0: "UI测试", 1: "电脑一", 2: "电脑二", 3: "电脑三"},
		"score_changes": {0: 2, 1: -2, 2: 0, 3: 0},
	}])
	runtime.history_changed.emit()
	assert(scene.settlement_details_history.size() == 2)
	var ledger_text := ""
	for ledger_label in scene.settlement_details_page_nodes[1].find_children("*", "Label", true, false):
		ledger_text += (ledger_label as Label).text
	assert("第1局" in ledger_text and "+3 分" in ledger_text)
	scene._select_rich_settlement_tab(3)
	var rule_buttons := scene.find_children("RuleOption_*", "Button", true, false)
	assert(not rule_buttons.is_empty())
	for rule_button in rule_buttons:
		assert((rule_button as Button).get_theme_font("font") != null)
	ui._open_details()
	assert(ui.details_overlay.visible and ui.detail_tabs.get_tab_count() == 3)
	scene.table_utility_bar.set_collapsed(false)
	scene._begin_opening_roll_animation({"round_index": 99, "die_a": 2, "die_b": 5})
	assert(scene.table_utility_bar.is_collapsed())
	scene.opening_roll_timer.stop()
	scene.opening_roll_commit_timer.stop()
	ui.show_player_disconnected({"nickname": "玩家二", "seat": 2, "is_host": false})
	assert(ui.disconnected_overlay.visible and "玩家二 已掉线" in ui.disconnected_label.text)
	assert(ui.end_disconnected_game_button.visible)
	assert(ui.end_disconnected_game_button.get_theme_stylebox("normal") is StyleBoxTexture)
	ui.end_disconnected_game_button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.scene_file_path == "res://scenes/network/GameModeSelect.tscn")
	assert(runtime.session.current_room_state.is_empty() and not runtime.match_active)
	print("LAN_ROOM_UI_PASS")
	quit(0)
