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
	_check_control_font_override(root_node.self_score_label, "本家积分", failures)
	_check_control_font_override(root_node.self_ding_que_label, "本家缺门", failures)
	_check_control_font_override(root_node.self_ui.identity_name_label, "本家姓名", failures)
	_check_control_font_override(root_node.self_ui.identity_dealer_badge, "庄家标记", failures)
	_check_ai_helper_idle_status(root_node, failures)
	_check_opponent_ding_que_badge_style(root_node, failures)

	if failures.is_empty():
		print("SICHUAN IOS FONT REGRESSION OK")
		quit(0)
		return

	push_error("SICHUAN IOS FONT REGRESSION FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _check_font_coverage(font: Font, failures: Array[String]) -> void:
	var sample := "本家0分庄缺万缺条缺筒展开收起建议先打当前不是你的主动出牌回合四川麻将新版"
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
	var panel: Control = root_node.get("discard_helper_panel")
	var summary: Label = root_node.get("discard_helper_summary")
	if panel == null or not panel.visible:
		failures.append("AI辅助开启后应显示状态提示面板")
	if summary == null or not summary.text.contains("AI辅助已开启"):
		failures.append("AI辅助开启后应显示可读提示文案")


func _check_opponent_ding_que_badge_style(root_node: Node, failures: Array[String]) -> void:
	var badge := Label.new()
	root_node.call("_apply_v17_ding_que_badge_style", badge, "wan")
	badge.text = "缺万"
	if badge.get_theme_font_size("font_size") < 32:
		failures.append("其他家缺门徽章字号过小")
	if badge.custom_minimum_size.x < 176.0 or badge.custom_minimum_size.y < 64.0:
		failures.append("其他家缺门徽章尺寸过小")
	if not badge.has_theme_stylebox_override("normal"):
		failures.append("其他家缺门徽章缺少背景样式")
