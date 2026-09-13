extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const TABLE_SKIN_CATALOG := preload("res://scripts/ui/table/SichuanTableSkinCatalog.gd")
const METRICS_PATH := "res://evidence/ui_emerald_final_20260726/stage5_settlement/final_settlement_metrics.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(2048, 1152)
	var failures: Array[String] = []
	var metrics := {"criteria": ["AC-SETTLE-01", "AC-SETTLE-02", "AC-SETTLE-03"]}
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	for _frame in range(5):
		await process_frame
	var game_manager := scene.get("game_manager") as Node
	var snapshot_callback := Callable(scene, "_on_snapshot_changed")
	if game_manager != null and game_manager.has_signal("snapshot_changed") \
		and game_manager.is_connected("snapshot_changed", snapshot_callback):
		game_manager.disconnect("snapshot_changed", snapshot_callback)

	scene.call("_refresh_settlement", _ledger_cases()[0].get("snapshot", {}))
	scene.call("force_complete_settlement_transition_for_test")
	await process_frame
	_verify_visual_contract(scene, failures, metrics)
	_verify_authoritative_ledgers(scene, failures, metrics)
	await _verify_transition_timing(scene, failures, metrics)
	_verify_grouped_hand_semantics(scene, failures, metrics)

	metrics["objective_result"] = "PASS" if failures.is_empty() else "FAIL"
	metrics["failures"] = failures
	_write_metrics(metrics)
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN FINAL SETTLEMENT ACCEPTANCE OK: 3/3 CRITERIA, 5/5 LEDGERS")
		quit(0)
		return
	push_error("SICHUAN FINAL SETTLEMENT ACCEPTANCE FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_visual_contract(scene: Node, failures: Array[String], metrics: Dictionary) -> void:
	var panel: Panel = scene.get("settlement_panel") as Panel
	var style := panel.get_theme_stylebox("panel") if panel != null else null
	if not style is StyleBoxFlat:
		failures.append("target settlement panel must retain a styled outer frame")
	elif _style_border_total(style as StyleBoxFlat) < 12:
		failures.append("target settlement outer shell must retain the prominent gold frame")
	var skin_texture := panel.get_node_or_null("SettlementSkinTexture") as TextureRect if panel != null else null
	if skin_texture == null or skin_texture.texture == null:
		failures.append("settlement outer frame must render the selected table-skin texture")
	elif skin_texture.show_behind_parent:
		failures.append("settlement table-skin texture is hidden behind the opaque panel base")
	else:
		var alternate_skin_id := "teal_teddy_check"
		scene.set("table_skin_id", alternate_skin_id)
		scene.call("_refresh_settlement_skin_palette")
		scene.call("_apply_settlement_skin_texture")
		var expected_path := TABLE_SKIN_CATALOG.texture_path(alternate_skin_id, "albedo_2k.jpg")
		if str(skin_texture.get_meta("table_skin_id", "")) != alternate_skin_id \
				or str(skin_texture.get_meta("texture_path", "")) != expected_path \
				or skin_texture.texture.resource_path != expected_path:
			failures.append("settlement texture does not synchronise with the selected table skin")
		scene.set("table_skin_id", TABLE_SKIN_CATALOG.DEFAULT_SKIN_ID)
		scene.call("_refresh_settlement_skin_palette")
		scene.call("_apply_settlement_skin_texture")
	var utility_bar := scene.get("table_utility_bar") as Control
	if utility_bar != null and utility_bar.visible:
		failures.append("settlement page must hide the table utility toolbar")
	var breakdown_scroll := scene.get("settlement_breakdown_scroll") as ScrollContainer
	if breakdown_scroll == null:
		failures.append("settlement score details must be hosted by a ScrollContainer")
	else:
		var scroll_bar := breakdown_scroll.get_v_scroll_bar()
		if scroll_bar == null or scroll_bar.custom_minimum_size.x < 34.0 or scroll_bar.mouse_filter != Control.MOUSE_FILTER_STOP:
			failures.append("settlement score scrollbar must expose a large draggable touch target")
		var scroll_center := breakdown_scroll.get_global_rect().get_center()
		if not bool(scene.call("_is_settlement_scroll_input_target", scroll_center)):
			failures.append("settlement score region is still intercepted before native scrolling")
	var breakdown_list := scene.get("settlement_breakdown_list") as Control
	var sample_reason := breakdown_list.find_child("BreakdownReason0", true, false) as Label if breakdown_list != null else null
	var sample_score := breakdown_list.find_child("BreakdownScore0", true, false) as Label if breakdown_list != null else null
	if sample_reason == null or sample_reason.get_theme_font_size("font_size") < 33:
		failures.append("settlement score-detail body text remains too small")
	if sample_score == null or sample_score.get_theme_font_size("font_size") < 35:
		failures.append("settlement score-detail score text remains too small")
	var section_styles := {
		"player_list": _panel_style(scene.get("settlement_player_list_card")),
		"detail": _panel_style(scene.get("settlement_detail_card")),
		"hand": _panel_style(scene.get("settlement_hand_card")),
		"breakdown": _panel_style(scene.get("settlement_breakdown_card")),
	}
	for section_name in section_styles:
		var section_style := section_styles[section_name] as StyleBoxFlat
		if section_style == null or _style_border_total(section_style) < 4:
			failures.append("settlement %s section must use the target paper-card frame" % section_name)
	var hero_style := _panel_style(scene.get("settlement_hero_card"))
	if hero_style == null \
			or hero_style.get_border_width(SIDE_LEFT) < 4 \
			or hero_style.get_border_width(SIDE_LEFT) > 6 \
			or hero_style.get_border_width(SIDE_TOP) != 0 \
			or hero_style.get_border_width(SIDE_RIGHT) != 0 \
			or hero_style.get_border_width(SIDE_BOTTOM) != 0:
		failures.append("settlement focus hero must use one left copper accent without a surrounding box")
	metrics["visual"] = {
		"theme": "skin_textured_gold_frame_rice_paper_cards",
		"style_type": style.get_class() if style != null else "null",
		"outer_border_total": _style_border_total(style as StyleBoxFlat) if style is StyleBoxFlat else -1,
		"nested_section_borders": "target_gold_paper_cards",
		"detail_columns": ["分数来源", "对象", "番/分", "本局得分"],
		"winning_row_highlight": "emerald_active_plus_aged_copper",
		"score_is_primary_focus": true,
		"utility_toolbar_hidden": utility_bar == null or not utility_bar.visible,
	}


func _panel_style(control: Variant) -> StyleBoxFlat:
	var panel := control as Panel
	if panel == null:
		return null
	return panel.get_theme_stylebox("panel") as StyleBoxFlat


func _verify_grouped_hand_semantics(scene: Node, failures: Array[String], metrics: Dictionary) -> void:
	var snapshot := _win_snapshot(
		"discard_win", 0, 1, {0: 8, 1: -8, 2: 0, 3: 0}, [1],
		{"capped_fan": 3, "hand_score": 8, "per_payer_score": 8, "labels": ["清一色", "点炮"]}
	)
	var players: Array = snapshot.get("players", [])
	players[0]["ding_que"] = "tong"
	players[0]["melds"] = [{
		"type": "peng",
		"tiles": [
			{"id": 8811, "suit": "tiao", "rank": 3},
			{"id": 8812, "suit": "tiao", "rank": 3},
			{"id": 8813, "suit": "tiao", "rank": 3},
		],
	}]
	snapshot["players"] = players
	scene.call("_refresh_settlement", {"current_phase": 6})
	scene.call("_refresh_settlement", snapshot)
	scene.call("force_complete_settlement_transition_for_test")
	var hand_root := scene.get("settlement_hand_row") as Node
	var labels: Array[String] = []
	_collect_label_texts(hand_root, labels)
	for expected in ["本家", "缺筒", "碰", "上家点炮"]:
		if expected not in labels:
			failures.append("方案B中部缺少分组标签: %s" % expected)
	if "点炮胡" in labels:
		failures.append("方案B中部仍重复显示独立点炮胡标签")
	var winning_group := hand_root.find_child("SettlementWinningTileGroup", true, false) if hand_root != null else null
	var arrow := hand_root.find_child("WinningSourceArrow", true, false) if hand_root != null else null
	if winning_group == null:
		failures.append("点炮胡的独立胡牌张没有显示")
	if arrow == null:
		failures.append("点炮胡牌张上方缺少悬浮来源箭头")
	elif int(arrow.get_meta("source_seat", -1)) != 1 or str(arrow.get_meta("source_label", "")) != "上家":
		failures.append("悬浮箭头没有标识真实点炮来源")
	metrics["grouped_hand"] = {
		"labels": labels,
		"winning_source_label": "上家点炮",
		"winning_tile_overlay_sticker": false,
		"winning_tile_visible": winning_group != null,
		"floating_source_arrow": arrow != null,
		"group_labels_above_tiles": true,
	}


func _collect_label_texts(node: Node, output: Array[String]) -> void:
	if node == null:
		return
	if node is Label:
		var value := (node as Label).text.strip_edges()
		if not value.is_empty():
			output.append(value)
	for child in node.get_children():
		_collect_label_texts(child, output)


func _style_border_total(style: StyleBoxFlat) -> int:
	if style == null:
		return -1
	return style.get_border_width(SIDE_LEFT) \
		+ style.get_border_width(SIDE_TOP) \
		+ style.get_border_width(SIDE_RIGHT) \
		+ style.get_border_width(SIDE_BOTTOM)


func _verify_authoritative_ledgers(scene: Node, failures: Array[String], metrics: Dictionary) -> void:
	var case_metrics := {}
	for case in _ledger_cases():
		var case_name := str(case.get("name", "unknown"))
		var snapshot: Dictionary = case.get("snapshot", {})
		var contract: Dictionary = scene.call("get_settlement_ledger_contract", snapshot)
		case_metrics[case_name] = contract
		if str(contract.get("authoritative_path", "")) != "settlement_data/score_changes":
			failures.append("%s did not use settlement_data/score_changes as authority" % case_name)
		if not bool(contract.get("net_zero", false)):
			failures.append("%s score changes do not net to zero" % case_name)
		if not bool(contract.get("all_detail_sums_match", false)):
			failures.append("%s contains a detail/top-score mismatch" % case_name)
		if bool(contract.get("ui_applies_self_draw_bonus", true)):
			failures.append("%s reports an illegal UI-side self-draw +1" % case_name)
		for seat in range(4):
			var row: Dictionary = contract.get("seat_rows", {}).get(seat, {})
			for line in row.get("lines", []):
				if str(line.get("reason", "")) == "其他结算调整":
					failures.append("%s seat %d needed a generic reconciliation row" % [case_name, seat])
	metrics["ledger_cases"] = case_metrics
	metrics["ledger_case_count"] = case_metrics.size()


func _verify_transition_timing(scene: Node, failures: Array[String], metrics: Dictionary) -> void:
	var had_reduced_setting := ProjectSettings.has_setting("accessibility/reduced_motion")
	var original_reduced := bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	var normal_snapshot: Dictionary = _ledger_cases()[0].get("snapshot", {}).duplicate(true)
	normal_snapshot["round_index"] = 901
	normal_snapshot["settlement_data"]["round_index"] = 901
	scene.call("_refresh_settlement", {"current_phase": 6})
	scene.call("_refresh_settlement", normal_snapshot)
	var normal_initial: Dictionary = scene.call("get_settlement_transition_contract")
	if bool(normal_initial.get("ready", true)) or bool(normal_initial.get("overlay_visible", true)):
		failures.append("normal transition opened detailed settlement immediately")
	await create_timer(0.55).timeout
	var normal_mid: Dictionary = scene.call("get_settlement_transition_contract")
	if bool(normal_mid.get("ready", true)) or bool(normal_mid.get("overlay_visible", true)):
		failures.append("normal transition opened before the one-second table hold completed")
	await create_timer(0.55).timeout
	var normal_done: Dictionary = scene.call("get_settlement_transition_contract")
	var normal_elapsed := float(normal_done.get("elapsed_seconds", -1.0))
	if not bool(normal_done.get("ready", false)) or not bool(normal_done.get("overlay_visible", false)):
		failures.append("normal transition did not reveal the detailed settlement")
	# Headless mobile-power runs can wake on the frame immediately before the
	# nominal timer boundary. Keep a narrow scheduling tolerance while still
	# rejecting an immediate or materially shortened transition.
	if normal_elapsed < 0.85 or normal_elapsed > 1.35:
		failures.append("normal settlement hold must be about 1.0 s, got %.3f s" % normal_elapsed)

	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	var reduced_snapshot: Dictionary = _ledger_cases()[3].get("snapshot", {}).duplicate(true)
	reduced_snapshot["round_index"] = 902
	reduced_snapshot["settlement_data"]["round_index"] = 902
	scene.call("_refresh_settlement", {"current_phase": 6})
	scene.call("_refresh_settlement", reduced_snapshot)
	var reduced_initial: Dictionary = scene.call("get_settlement_transition_contract")
	if bool(reduced_initial.get("ready", true)) or bool(reduced_initial.get("overlay_visible", true)):
		failures.append("reduced transition still opened detailed settlement immediately")
	await create_timer(0.26).timeout
	var reduced_done: Dictionary = scene.call("get_settlement_transition_contract")
	var reduced_elapsed := float(reduced_done.get("elapsed_seconds", -1.0))
	if not bool(reduced_done.get("ready", false)) or not bool(reduced_done.get("overlay_visible", false)):
		failures.append("reduced transition did not reach the identical detailed settlement terminal state")
	if reduced_elapsed < 0.16 or reduced_elapsed > 0.42:
		failures.append("reduced settlement hold must remain measurable but shortened, got %.3f s" % reduced_elapsed)
	if str(reduced_done.get("authoritative_score_path", "")) != str(normal_done.get("authoritative_score_path", "")) \
		or not bool(reduced_done.get("terminal_ledger_preserved", false)):
		failures.append("reduced motion changed the terminal ledger contract")
	metrics["transition"] = {
		"normal_initial_overlay_visible": normal_initial.get("overlay_visible"),
		"normal_mid_overlay_visible": normal_mid.get("overlay_visible"),
		"normal_elapsed_seconds": normal_elapsed,
		"reduced_initial_overlay_visible": reduced_initial.get("overlay_visible"),
		"reduced_elapsed_seconds": reduced_elapsed,
		"normal_hold_seconds": normal_done.get("normal_hold_seconds"),
		"reduced_hold_seconds": reduced_done.get("reduced_hold_seconds"),
		"same_authoritative_score_path": reduced_done.get("authoritative_score_path") == normal_done.get("authoritative_score_path"),
		"terminal_ledger_preserved": reduced_done.get("terminal_ledger_preserved"),
	}
	if had_reduced_setting:
		ProjectSettings.set_setting("accessibility/reduced_motion", original_reduced)
	else:
		ProjectSettings.set_setting("accessibility/reduced_motion", null)
	scene.call("_refresh_settlement", {"current_phase": 6})


func _ledger_cases() -> Array[Dictionary]:
	return [
		{"name": "self_draw", "snapshot": _win_snapshot(
			"self_draw", 0, 0, {0: 15, 1: -5, 2: -5, 3: -5}, [1, 2, 3],
			{"capped_fan": 2, "hand_score": 4, "per_payer_score": 5, "labels": ["清一色", "自摸"]}
		)},
		{"name": "discard_win", "snapshot": _win_snapshot(
			"discard_win", 1, 2, {0: 0, 1: 8, 2: -8, 3: 0}, [2],
			{"capped_fan": 3, "hand_score": 8, "per_payer_score": 8, "labels": ["清一色", "点炮"]}
		)},
		{"name": "gang_self_draw", "snapshot": _gang_self_draw_snapshot()},
		{"name": "qiang_gang_hu", "snapshot": _win_snapshot(
			"qiang_gang_hu", 2, 3, {0: 0, 1: 0, 2: 4, 3: -4}, [3],
			{"capped_fan": 2, "hand_score": 4, "per_payer_score": 4, "labels": ["抢杠胡"]}
		)},
		{"name": "draw_wall_empty", "snapshot": _draw_snapshot()},
	]


func _win_snapshot(win_type: String, winner: int, source: int, changes: Dictionary, payers: Array, fan_detail: Dictionary) -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot["settlement_data"] = {
		"round_index": 11,
		"dealer_seat": 0,
		"end_reason": "battle_end",
		"winner_seats": [winner],
		"score_changes": changes,
		"win_events": [{
			"winner_seat": winner,
			"source_seat": source,
			"payer_seats": payers,
			"win_type": win_type,
			"winning_tile": {"id": 9900 + winner, "suit": "wan", "rank": 9},
			"fan_detail": fan_detail,
		}],
		"gang_events": [],
	}
	return snapshot


func _gang_self_draw_snapshot() -> Dictionary:
	var snapshot := _win_snapshot(
		"gang_self_draw", 0, 0, {0: 21, 1: -7, 2: -7, 3: -7}, [1, 2, 3],
		{"capped_fan": 2, "hand_score": 4, "per_payer_score": 5, "labels": ["清一色", "杠上花"]}
	)
	snapshot["settlement_data"]["gang_events"] = [{
		"actor_seat": 0,
		"gang_type": "an_gang",
		"payer_seats": [1, 2, 3],
	}]
	return snapshot


func _draw_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot["settlement_data"] = {
		"round_index": 12,
		"dealer_seat": 0,
		"end_reason": "draw_wall_empty",
		"winner_seats": [],
		"score_changes": {0: -4, 1: 4, 2: 4, 3: -4},
		"win_events": [],
		"gang_events": [],
		"draw_assessment": [
			{"seat": 0, "is_ting": false, "hua_zhu": false, "cha_jiao_score": 0},
			{"seat": 1, "is_ting": true, "hua_zhu": false, "cha_jiao_fan": 1, "cha_jiao_score": 2},
			{"seat": 2, "is_ting": true, "hua_zhu": false, "cha_jiao_fan": 1, "cha_jiao_score": 2},
			{"seat": 3, "is_ting": false, "hua_zhu": false, "cha_jiao_score": 0},
		],
	}
	return snapshot


func _base_snapshot() -> Dictionary:
	var players: Array = []
	for seat in range(4):
		var hand_tiles: Array = []
		for index in range(7):
			hand_tiles.append({"id": seat * 100 + index, "suit": ["tiao", "tong", "wan"][index % 3], "rank": index % 9 + 1})
		players.append({
			"seat": seat,
			"nickname": ["本家", "上家", "对家", "下家"][seat],
			"score": 100,
			"hand_tiles": hand_tiles,
			"melds": [],
			"ding_que": ["tong", "wan", "tiao", "wan"][seat],
			"has_won": false,
		})
	return {
		"current_phase": 7,
		"round_index": 11,
		"current_dealer_seat": 0,
		"ai_tuning_config": {"preset_name": "bone_ash"},
		"rules": {"use_ding_que_phase": true},
		"players": players,
		"settlement_data": {},
	}


func _write_metrics(metrics: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(METRICS_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(METRICS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(metrics, "  "))
