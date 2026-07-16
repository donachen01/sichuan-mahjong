extends SceneTree

const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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

	root_node.queue_free()
	await process_frame
	await process_frame

	if failures.is_empty():
		print("SICHUAN IOS FONT REGRESSION OK")
		quit(0)
		return

	push_error("SICHUAN IOS FONT REGRESSION FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _check_font_coverage(font: Font, failures: Array[String]) -> void:
	var sample := "本家0分庄缺万缺条缺筒展开收起建议先打等待你的出牌回合请选择缺门余牌当前四川麻将新版"
	for index in range(sample.length()):
		var code := sample.unicode_at(index)
		if not font.has_char(code):
			failures.append("embedded UI font missing char: %s" % char(code))


func _check_control_font_override(control: Control, label: String, failures: Array[String]) -> void:
	if control == null:
		failures.append("%s control missing" % label)
		return
	if not control.has_theme_font_override("font"):
		failures.append("%s missing embedded font override" % label)


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
