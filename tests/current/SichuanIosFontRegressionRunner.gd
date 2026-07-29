extends SceneTree

const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const BODY_FONT_PATH := "res://res/fonts/NotoSansCJKsc-Regular.otf"
const DISPLAY_FONT_PATH := "res://res/fonts/nameplate_calligraphy.ttf"

var evidence: Dictionary = {
	"criterion": "AC-TYPE-01",
	"body_font": BODY_FONT_PATH,
	"display_font": DISPLAY_FONT_PATH,
	"objective_result": "PASS",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(2048, 1152)
	var failures: Array[String] = []
	var font: Font = STYLE_CONFIG.ui_font()
	if font == null:
		failures.append("expected embedded UI font to load")
	else:
		_check_font_coverage(font, failures)

	var root_node := MAIN_SCENE.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame

	_check_control_font_override(root_node.ding_que_wan_button, "定缺万按钮", failures)
	_check_control_font_override(root_node.ding_que_tiao_button, "定缺条按钮", failures)
	_check_control_font_override(root_node.ding_que_tong_button, "定缺筒按钮", failures)
	_check_shared_seat_huds(root_node, failures)
	_check_ai_helper_idle_status(root_node, failures)
	_check_required_typography_roles(root_node, failures)
	await _check_rich_settlement_typography(root_node, failures)

	root_node.queue_free()
	await process_frame
	await process_frame
	evidence["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	evidence["failures"] = failures
	_write_evidence(failures)

	if failures.is_empty():
		print("SICHUAN IOS FONT REGRESSION OK")
		quit(0)
		return

	push_error("SICHUAN IOS FONT REGRESSION FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _check_font_coverage(font: Font, failures: Array[String]) -> void:
	if font.resource_path != BODY_FONT_PATH:
		failures.append("UI body font resolved outside embedded Noto CJK: %s" % font.resource_path)
	var sample := "本家0分庄缺万缺条缺筒展开收起建议先打等待你的出牌回合请选择缺门余牌当前四川麻将新版胡杠碰过取消自摸已胡四家得分明细下一局+-0123456789"
	var covered_count := 0
	for index in range(sample.length()):
		var code := sample.unicode_at(index)
		if not font.has_char(code):
			failures.append("embedded UI font missing char: %s" % char(code))
		else:
			covered_count += 1
	evidence["coverage_sample"] = sample
	evidence["coverage_count"] = covered_count
	evidence["coverage_expected"] = sample.length()


func _check_control_font_override(control: Control, label: String, failures: Array[String]) -> void:
	if control == null:
		failures.append("%s control missing" % label)
		return
	if not control.has_theme_font_override("font"):
		failures.append("%s missing embedded font override" % label)


func _check_control_font_path(control: Control, label: String, expected_path: String, failures: Array[String]) -> void:
	_check_control_font_override(control, label, failures)
	if control == null or not control.has_theme_font_override("font"):
		return
	var font := control.get_theme_font("font")
	if font == null or font.resource_path != expected_path:
		failures.append("%s uses wrong font: %s" % [label, "<null>" if font == null else font.resource_path])


func _check_ai_helper_idle_status(root_node: Node, failures: Array[String]) -> void:
	root_node.set("ai_helper_enabled", true)
	root_node.call("_update_discard_helper_panel", {
		"human_ding_que_pending": true,
		"current_turn_seat": 0,
	}, {}, false)
	var drawer: Control = root_node.get("ai_assistant_drawer")
	if drawer == null or not drawer.visible:
		failures.append("AI辅助开启后应显示按需抽屉")
		return
	var summary: Label = drawer.get("summary_label")
	var title: Label = drawer.get("title_label")
	var toggle: Button = drawer.get("toggle_button")
	_check_control_font_override(title, "AI抽屉标题", failures)
	_check_control_font_override(summary, "AI抽屉状态", failures)
	_check_control_font_override(toggle, "AI抽屉展开按钮", failures)
	if summary == null or not summary.text.contains("等待你的出牌回合"):
		failures.append("AI辅助开启后应显示可读提示文案")


func _check_shared_seat_huds(root_node: Node, failures: Array[String]) -> void:
	var seat_huds: Dictionary = root_node.get("seat_huds")
	if seat_huds.size() != 4:
		failures.append("四家共享身份 HUD 未完整创建")
		return
	var suits := ["wan", "tong", "tiao", "wan"]
	var expected_text := ["缺万", "缺筒", "缺条", "缺万"]
	for seat in [0, 1, 2, 3]:
		var seat_hud: Control = seat_huds.get(seat)
		var name_label := seat_hud.get_node_or_null("%NameLabel") as Label
		var score_label := seat_hud.get_node_or_null("%ScoreLabel") as Label
		var dealer_badge := seat_hud.get_node_or_null("%DealerBadge") as Label
		var won_badge := seat_hud.get_node_or_null("%WonBadge") as Label
		_check_control_font_override(name_label, "SeatHUD%d 姓名" % seat, failures)
		_check_control_font_override(score_label, "SeatHUD%d 积分" % seat, failures)
		_check_control_font_override(dealer_badge, "SeatHUD%d 庄家" % seat, failures)
		_check_control_font_override(won_badge, "SeatHUD%d 已胡" % seat, failures)

		var ding_que_badge: Control = seat_hud.call("get_ding_que_badge")
		var text_label := ding_que_badge.get_node_or_null("%TextLabel") as Label
		ding_que_badge.call("configure", suits[seat], seat in [1, 3])
		ding_que_badge.call("set_revealed", true)
		_check_control_font_override(text_label, "SeatHUD%d 定缺" % seat, failures)
		if text_label.text != expected_text[seat]:
			failures.append("SeatHUD%d 定缺文案错误: %s" % [seat, text_label.text])
		if text_label.get_theme_font_size("font_size") < 26:
			failures.append("SeatHUD%d 定缺字号过小" % seat)
		var expected_minimum := Vector2(104.0, 44.0) if seat in [1, 3] else Vector2(112.0, 48.0)
		if ding_que_badge.custom_minimum_size.x < expected_minimum.x or ding_que_badge.custom_minimum_size.y < expected_minimum.y:
			failures.append("SeatHUD%d 定缺徽章尺寸过小" % seat)
		if not seat_hud.get_global_rect().encloses(ding_que_badge.get_global_rect()):
			failures.append("SeatHUD%d 定缺徽章越出玩家姓名框" % seat)
		if not ding_que_badge.has_theme_stylebox_override("panel"):
			failures.append("SeatHUD%d 定缺徽章缺少背景样式" % seat)


func _check_required_typography_roles(root_node: Node, failures: Array[String]) -> void:
	var sizes: Dictionary = {}
	var seat_huds: Dictionary = root_node.get("seat_huds")
	var self_hud: Control = seat_huds.get(0)
	var name_label := self_hud.get_node_or_null("%NameLabel") as Label
	var score_label := self_hud.get_node_or_null("%ScoreLabel") as Label
	var ding_que_label := (self_hud.call("get_ding_que_badge") as Control).get_node_or_null("%TextLabel") as Label
	for entry in [
		{"control": name_label, "label": "玩家姓名", "minimum": 30},
		{"control": score_label, "label": "玩家总分", "minimum": 32},
		{"control": ding_que_label, "label": "定缺标签", "minimum": 28},
	]:
		var control := entry.get("control") as Control
		_check_control_font_path(control, str(entry.get("label")), BODY_FONT_PATH, failures)
		var size := control.get_theme_font_size("font_size") if control != null else 0
		sizes[str(entry.get("label"))] = size
		if size < int(entry.get("minimum", 0)):
			failures.append("%s font size below standard minimum: %d" % [entry.get("label"), size])

	var action_bar: Control = root_node.get("table_action_bar")
	var all_actions: Array[String] = ["hu", "gang", "peng", "pass"]
	action_bar.call("render", all_actions, "")
	for action in ["hu", "gang", "peng", "pass"]:
		var button: Button = action_bar.call("get_button", action)
		_check_control_font_path(button, "动作%s" % action, BODY_FONT_PATH, failures)
		var minimum := 58 if action == "hu" else 50
		var size := button.get_theme_font_size("font_size")
		sizes["action_%s" % action] = size
		if size < minimum:
			failures.append("action %s font size below standard minimum: %d" % [action, size])

	var utility_bar: Control = root_node.get("table_utility_bar")
	var utility_button: Button = utility_bar.call("get_button", "exit")
	_check_control_font_path(utility_button, "工具按钮", BODY_FONT_PATH, failures)
	var utility_size := utility_button.get_theme_font_size("font_size")
	sizes["utility"] = utility_size
	if utility_size < 32:
		failures.append("utility font size below standard minimum: %d" % utility_size)

	var center_indicator: Control = root_node.get("center_turn_indicator")
	var wall_count := center_indicator.get_node_or_null("%TurnChipLabel") as Label
	_check_control_font_path(wall_count, "中央悬浮余牌文字", BODY_FONT_PATH, failures)
	var wall_count_size := wall_count.get_theme_font_size("font_size")
	sizes["wall_count"] = wall_count_size
	if wall_count_size < 30:
		failures.append("floating wall count font size below standard minimum: %d" % wall_count_size)

	var settlement: Control = root_node.get("settlement_overlay_v2")
	var round_label := settlement.get_node_or_null("%RoundLabel") as Label
	var result_badge := settlement.get_node_or_null("%ResultBadge") as Label
	var settlement_score := settlement.get_node_or_null("%ScoreLabel") as Label
	var hand_label := settlement.get_node_or_null("%HandLabel") as Label
	var breakdown_label := settlement.get_node_or_null("%BreakdownLabel") as Label
	_check_control_font_path(round_label, "结算标题", DISPLAY_FONT_PATH, failures)
	_check_control_font_path(result_badge, "结算结果短标题", DISPLAY_FONT_PATH, failures)
	for entry in [
		{"control": settlement_score, "label": "结算焦点分数", "minimum": 72},
		{"control": hand_label, "label": "结算手牌正文", "minimum": 24},
		{"control": breakdown_label, "label": "结算明细", "minimum": 24},
	]:
		var control := entry.get("control") as Control
		_check_control_font_path(control, str(entry.get("label")), BODY_FONT_PATH, failures)
		var size := control.get_theme_font_size("font_size") if control != null else 0
		sizes[str(entry.get("label"))] = size
		if size < int(entry.get("minimum", 0)):
			failures.append("%s font size below standard minimum: %d" % [entry.get("label"), size])
	evidence["font_sizes"] = sizes


func _check_rich_settlement_typography(root_node: Node, failures: Array[String]) -> void:
	var manager: Node = root_node.get("game_manager") as Node
	if manager == null:
		failures.append("rich settlement font audit missing game manager")
		return
	var snapshot: Dictionary = manager.call("get_snapshot").duplicate(true)
	var players: Array = snapshot.get("players", [])
	if players.size() < 4:
		failures.append("rich settlement font audit missing four-player fixture")
		return
	for seat in range(4):
		var player: Dictionary = players[seat]
		player["nickname"] = ["本家", "上家", "对家", "下家"][seat]
		player["score"] = [15, 3, -11, -7][seat]
		player["has_won"] = seat == 0
		players[seat] = player
	var winning_tile: Dictionary = players[0].get("hand_tiles", [{}]).back() \
		if not players[0].get("hand_tiles", []).is_empty() else {"id": 9999, "suit": "wan", "rank": 9}
	snapshot["current_phase"] = 7
	snapshot["players"] = players
	snapshot["settlement_data"] = {
		"round_index": 5,
		"dealer_seat": 1,
		"end_reason": "draw_wall_empty",
		"winner_seats": [0],
		"score_changes": {0: 11, 1: -2, 2: -2, 3: -7},
		"win_events": [{
			"winner_seat": 0,
			"source_seat": 0,
			"payer_seats": [1, 2, 3],
			"win_type": "self_draw",
			"winning_tile": winning_tile,
			"fan_detail": {"capped_fan": 0, "hand_score": 1, "per_payer_score": 2, "labels": ["平胡", "自摸"]},
		}],
	}
	root_node.set("last_snapshot", {"current_phase": 6})
	root_node.call("_refresh_settlement", snapshot)
	await process_frame
	await process_frame

	var title := root_node.find_child("SettlementTitle", true, false) as Label
	var round_label := root_node.get("settlement_round_label") as Label
	var hero_badge := root_node.get("settlement_hero_badge") as Label
	var hero_name := root_node.get("settlement_hero_name") as Label
	var hero_hu := root_node.get("settlement_hero_hu") as Label
	var hero_fan := root_node.get("settlement_hero_fan") as Label
	var hero_score := root_node.get("settlement_hero_score") as Label
	var breakdown_title := root_node.get("settlement_breakdown_title") as Label
	for entry in [
		{"control": title, "label": "运行时结算主标题", "path": DISPLAY_FONT_PATH, "minimum": 34, "maximum": 40},
		{"control": hero_badge, "label": "运行时结算短标题", "path": DISPLAY_FONT_PATH, "minimum": 18, "maximum": 30},
		{"control": breakdown_title, "label": "运行时结算明细标题", "path": DISPLAY_FONT_PATH, "minimum": 30, "maximum": 36},
		{"control": round_label, "label": "运行时结算局数正文", "path": BODY_FONT_PATH, "minimum": 22, "maximum": 28},
		{"control": hero_name, "label": "运行时结算玩家名", "path": BODY_FONT_PATH, "minimum": 24, "maximum": 34},
		{"control": hero_hu, "label": "运行时结算胡牌统计", "path": BODY_FONT_PATH, "minimum": 22, "maximum": 28},
		{"control": hero_fan, "label": "运行时结算番数统计", "path": BODY_FONT_PATH, "minimum": 22, "maximum": 28},
		{"control": hero_score, "label": "运行时结算焦点分数", "path": BODY_FONT_PATH, "minimum": 60, "maximum": 72},
	]:
		var control := entry.get("control") as Control
		var label_text := str(entry.get("label"))
		_check_control_font_path(control, label_text, str(entry.get("path")), failures)
		var size := control.get_theme_font_size("font_size") if control != null else 0
		if size < int(entry.get("minimum")) or size > int(entry.get("maximum")):
			failures.append("%s size outside standard range: %d" % [label_text, size])

	var dynamic_roots: Array[Node] = [
		root_node.get("settlement_player_list") as Node,
		root_node.get("settlement_hand_row") as Node,
		root_node.get("settlement_breakdown_list") as Node,
	]
	var audited_dynamic_labels := 0
	for dynamic_root in dynamic_roots:
		if dynamic_root == null:
			continue
		for node in dynamic_root.find_children("*", "Label", true, false):
			var label := node as Label
			var expected_path := DISPLAY_FONT_PATH if label.text == "本局最佳" or label.text in ["本", "上", "对", "下"] else BODY_FONT_PATH
			_check_control_font_path(label, "运行时结算动态文字 %s" % label.text, expected_path, failures)
			audited_dynamic_labels += 1
	evidence["rich_settlement"] = {
		"audited_dynamic_labels": audited_dynamic_labels,
		"title_size": title.get_theme_font_size("font_size") if title != null else 0,
		"hero_score_size": hero_score.get_theme_font_size("font_size") if hero_score != null else 0,
		"body_font": BODY_FONT_PATH,
		"display_font_scope": ["结算主标题", "装饰短标题", "单字座位章"],
	}


func _write_evidence(failures: Array[String]) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
			break
	if output_path.is_empty():
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write typography evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify(evidence, "  "))
