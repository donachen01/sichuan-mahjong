extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1365, 768)
	var scene = MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	var options: Array = [
		_option(1, "3万", 12, 5.4, "低危", "清一色"),
		_option(2, "6万", 10, 4.8, "中危", "清一色"),
		_option(3, "9筒", 8, 3.6, "低危", "平胡"),
		_option(4, "1条", 4, 1.2, "高危", "防守"),
	]
	var text: String = scene._build_helper_top_candidates_text(options)
	_expect(text.contains("1.3万") and text.contains("2.6万") and text.contains("3.9筒"), "没有显示前三候选", failures)
	_expect(not text.contains("4.1条"), "候选列表超过三项", failures)
	_expect(text.contains("净5.4") and text.contains("相对安全") and text.contains("清一色"), "候选缺少净收益、风险或路线", failures)
	_expect(text.contains("胡62%/叫78%") and text.contains("3.0番") and text.contains("保留清一色主路线"), "候选缺少胡牌/成叫、预计番或核心理由", failures)
	_expect(not text.contains("csharp") and not text.contains("posterior") and not text.contains("score="), "玩家界面泄露内部技术字段", failures)

	scene.ai_helper_enabled = true
	var snapshot := {
		"players": [{"seat": 0, "hand_tiles": [{"id": 1, "suit": "wan", "rank": 3}]}],
		"phase_name": "DISCARD",
	}
	var hint := {
		"recommended": options[0].merged({"tile": {"id": 1, "suit": "wan", "rank": 3}}),
		"options": options,
	}
	scene._update_discard_helper_panel(snapshot, hint, true)
	await process_frame
	var drawer: Control = scene.ai_assistant_drawer
	_expect(drawer != null and drawer.visible, "AI 辅助抽屉未显示", failures)
	_expect(not bool(drawer.call("is_expanded")), "AI 辅助抽屉默认必须收起", failures)
	# 视觉合同验证的是默认布局，不应被 user:// 中上一次手动拖动的偏好污染。
	drawer.call("restore_user_position", Vector2(0.5, 0.5), false)
	drawer.call("set_expanded", true)
	scene.call("_layout_ai_assistant_drawer")
	await process_frame
	var summary_label: Label = drawer.get("summary_label")
	var reason_label: Label = drawer.get("reason_label")
	var danger_label: Label = drawer.get("danger_label")
	var routes_label: Label = drawer.get("routes_label")
	_expect(summary_label.text == "建议先打：3万", "推荐动作和 C# 候选首项不一致", failures)
	var drawer_text := "\n".join([summary_label.text, reason_label.text, danger_label.text, routes_label.text])
	_expect(drawer_text.contains("原因：") and drawer_text.contains("风险：") and drawer_text.contains("方向："), "抽屉缺少简短原因、风险或策略方向", failures)
	_expect(not drawer_text.contains("csharp") and not drawer_text.contains("posterior") and not drawer_text.contains("score="), "AI 抽屉泄露内部技术字段", failures)
	var panel_rect: Rect2 = drawer.get_global_rect()
	var root_rect: Rect2 = scene.root_ui.get_global_rect()
	var hand_rect: Rect2 = scene.self_hand_host.get_global_rect()
	_expect(root_rect.encloses(panel_rect), "1365x768 下 AI 抽屉超出视口", failures)
	_expect(not panel_rect.intersects(hand_rect, true), "AI 抽屉遮挡本家手牌", failures)

	if failures.is_empty():
		print("SICHUAN AI EXPLANATION UI OK: 12/12")
		scene.queue_free()
		quit(0)
		return
	scene.queue_free()
	push_error("SICHUAN AI EXPLANATION UI FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _option(id: int, tile_name: String, live: int, net: float, risk: String, route: String) -> Dictionary:
	return {
		"tile_name": tile_name,
		"tile": {"id": id},
		"live_ukeire": live,
		"expected_net_score": net,
		"risk_label": risk,
		"route_plan_primary": route,
		"win_probability": 0.62,
		"tenpai_probability": 0.78,
		"expected_fan": 3.0,
		"explanation_hint": "保留清一色主路线",
		"csharp_internal_score": 999999,
		"posterior_adjustment": 0.5,
	}


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
