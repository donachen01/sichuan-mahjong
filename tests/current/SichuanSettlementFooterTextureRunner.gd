extends SceneTree

const Main := preload("res://scenes/table/MainSceneV2.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Main.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var state = root.get_node("GameState")
	var snapshot: Dictionary = state.get_gameplay_snapshot()
	snapshot["current_phase"] = 7
	scene.call("_render_settlement", snapshot)
	scene.get("settlement_overlay").show()
	scene.call("_layout_settlement_overlay")
	await process_frame
	var close: Button = scene.get("settlement_close_button")
	var next: Button = scene.get("next_round_button")
	for variant in ["normal", "hover", "pressed", "focus"]:
		var left := close.get_theme_stylebox(variant) as StyleBoxTexture
		var right := next.get_theme_stylebox(variant) as StyleBoxTexture
		if left == null or right == null or left.texture != right.texture or left.modulate_color != right.modulate_color:
			failures.append("按钮材质状态不同：" + variant)
	for seat in range(4):
		var row: Button = scene.get("settlement_player_buttons")[seat]
		var marker := row.find_child("SettlementSeatLabel", true, false) as Label
		if marker == null or marker.text != ["本家", "上家", "对家", "下家"][seat]:
			failures.append("结算名字旁座位标注错误：%d" % seat)
	if not close.visible or not next.visible:
		failures.append("离线结算没有同时显示关闭与下一局")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var destination := "res://evidence/bugs_dealer_buttons_single_lane_20260927/settlement_buttons.png"
		root.get_texture().get_image().save_png(destination)
	scene.call("_on_settlement_close_pressed")
	if scene.get("settlement_overlay").visible:
		failures.append("关闭按钮功能未关闭详情")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("SETTLEMENT_FOOTER_TEXTURE_PASS")
		quit(0)
	else:
		push_error("\n".join(failures))
		quit(1)
