extends SceneTree

const SEAT_HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")

var evidence: Dictionary = {
	"criterion": "AC-TYPE-02",
	"measurement": "WCAG 2 relative luminance; normal text >=4.5:1, text >=24px >=3:1",
	"contrast_checks": [],
	"semantic_states": {},
	"objective_result": "PASS",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_measure_required_pairs(failures)
	await _verify_state_encodings(failures)
	evidence["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	evidence["failures"] = failures
	_write_evidence(failures)
	if failures.is_empty():
		print("SICHUAN TYPOGRAPHY CONTRAST OK")
		quit(0)
		return
	push_error("SICHUAN TYPOGRAPHY CONTRAST FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _measure_required_pairs(failures: Array[String]) -> void:
	var panel := TABLE_THEME.PANEL_JADE_BLACK
	var table_edge := TABLE_THEME.TABLE_EDGE
	var pairs: Array[Dictionary] = [
		{"label": "玩家姓名", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": panel, "font_size": 30},
		{"label": "玩家总分", "foreground": TABLE_THEME.TEXT_SECONDARY, "background": panel, "font_size": 32},
		{"label": "庄家文字", "foreground": Color("F6D66B"), "background": Color("4A1B13"), "font_size": 34},
		{"label": "当前回合文字", "foreground": Color("FFF1C4"), "background": Color("123F35"), "font_size": 21},
		{"label": "已胡文字", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": Color("9A2D28"), "font_size": 28},
		{"label": "缺万", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": TABLE_THEME.make_badge_style("wan").bg_color, "font_size": 28},
		{"label": "缺筒", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": TABLE_THEME.make_badge_style("tong").bg_color, "font_size": 28},
		{"label": "缺条", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": TABLE_THEME.make_badge_style("tiao").bg_color, "font_size": 28},
		{"label": "工具按钮", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": TABLE_THEME.LEATHER_RAIL, "font_size": 32},
		{"label": "中央余牌数字", "foreground": TABLE_THEME.IVORY_TEXT, "background": table_edge, "font_size": 64},
		{"label": "正分变化", "foreground": TABLE_THEME.POSITIVE_SCORE, "background": table_edge, "font_size": 30},
		{"label": "负分变化", "foreground": TABLE_THEME.NEGATIVE_SCORE, "background": table_edge, "font_size": 30},
		{"label": "结算正文", "foreground": TABLE_THEME.TEXT_PRIMARY, "background": Color("031815"), "font_size": 24},
		{"label": "结算正分", "foreground": Color("FFE27A"), "background": Color("031815"), "font_size": 72},
		{"label": "结算负分", "foreground": Color("F3B4AD"), "background": Color("031815"), "font_size": 72},
	]
	for entry in pairs:
		_measure_pair(entry, failures)


func _measure_pair(entry: Dictionary, failures: Array[String]) -> void:
	var foreground: Color = entry.get("foreground", Color.WHITE)
	var background: Color = entry.get("background", Color.BLACK)
	var font_size := int(entry.get("font_size", 0))
	var threshold := 3.0 if font_size >= 24 else 4.5
	var ratio := _contrast_ratio(foreground, background)
	var result := {
		"label": str(entry.get("label", "")),
		"foreground": foreground.to_html(false),
		"background": background.to_html(false),
		"font_size": font_size,
		"threshold": threshold,
		"ratio": snappedf(ratio, 0.001),
		"result": "PASS" if ratio + 0.0001 >= threshold else "FAIL",
	}
	(evidence["contrast_checks"] as Array).append(result)
	if ratio + 0.0001 < threshold:
		failures.append("%s contrast %.3f:1 below %.1f:1" % [entry.get("label"), ratio, threshold])


func _verify_state_encodings(failures: Array[String]) -> void:
	var hud := SEAT_HUD_SCENE.instantiate() as Control
	get_root().add_child(hud)
	hud.size = Vector2(238.0, 178.0)
	hud.call("configure_seat", 0)
	hud.call("set_reduced_motion", true)
	hud.call("render", {
		"nickname": "本家",
		"score": 100,
		"ding_que": "tong",
		"_is_dealer": true,
		"_interaction_label": "出牌",
		"has_won": false,
	}, 0, true)
	await process_frame
	var dealer := hud.get_node_or_null("%DealerBadge") as Label
	var turn := hud.get_node_or_null("%TurnBadge") as Label
	var ding_badge: Control = hud.call("get_ding_que_badge")
	var ding := ding_badge.get_node_or_null("%TextLabel") as Label
	var score_delta := hud.get_node_or_null("%ScoreDeltaLabel") as Label
	var state_results := {
		"ding_que": ding != null and ding.visible and ding.text == "缺筒",
		"dealer": dealer != null and dealer.visible and dealer.text == "庄",
		"current_turn": turn != null and not turn.visible,
	}

	hud.call("render", {
		"nickname": "本家", "score": 116, "ding_que": "tong",
		"_is_dealer": true, "_interaction_label": "出牌", "has_won": false,
	}, 0, true)
	await process_frame
	var positive_text := score_delta.text if score_delta != null else ""
	var positive_color := score_delta.get_theme_color("font_color") if score_delta != null else Color.TRANSPARENT
	state_results["positive_score"] = positive_text.begins_with("+") and positive_color == TABLE_THEME.POSITIVE_SCORE
	await create_timer(0.40).timeout

	hud.call("render", {
		"nickname": "本家", "score": 102, "ding_que": "tong",
		"_is_dealer": false, "_interaction_label": "出牌", "has_won": false,
	}, 0, true)
	await process_frame
	var negative_text := score_delta.text if score_delta != null else ""
	var negative_color := score_delta.get_theme_color("font_color") if score_delta != null else Color.TRANSPARENT
	state_results["negative_score"] = negative_text.begins_with("-") and negative_color == TABLE_THEME.NEGATIVE_SCORE
	state_results["score_sign_and_color"] = bool(state_results["positive_score"]) \
		and bool(state_results["negative_score"]) and positive_color != negative_color

	hud.call("render", {
		"nickname": "本家", "score": 102, "ding_que": "tong",
		"_is_dealer": false, "has_won": true,
	}, 2, true)
	await process_frame
	var won := hud.get_node_or_null("%WonBadge") as Label
	state_results["won"] = won != null and won.visible and won.text == "已胡"
	state_results["observed_positive_text"] = positive_text
	state_results["observed_negative_text"] = negative_text
	evidence["semantic_states"] = state_results
	for key in ["ding_que", "dealer", "current_turn", "positive_score", "negative_score", "score_sign_and_color", "won"]:
		if not bool(state_results.get(key, false)):
			failures.append("semantic state lacks text/shape plus colour encoding: %s" % key)
	hud.queue_free()
	await process_frame


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) \
		/ (minf(first_luminance, second_luminance) + 0.05)


func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) \
		+ 0.7152 * _linear_channel(color.g) \
		+ 0.0722 * _linear_channel(color.b)


func _linear_channel(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


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
		failures.append("could not write contrast evidence: %s" % output_path)
		return
	file.store_string(JSON.stringify(evidence, "  "))
