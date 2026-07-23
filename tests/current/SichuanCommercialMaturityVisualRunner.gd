extends SceneTree

const MATERIAL_OVERLAY := preload("res://scripts/ui/TableMaterialOverlay.gd")
const SEAT_HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const CENTER_INDICATOR_SCENE := preload("res://scenes/ui/table/CenterTurnIndicator.tscn")
const ACTION_BAR_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _verify_perspective_surface(failures)
	await _verify_identity_hud(failures)
	await _verify_center_compass(failures)
	await _verify_decision_seals(failures)
	if failures.is_empty():
		print("SICHUAN COMMERCIAL MATURITY VISUAL CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN COMMERCIAL MATURITY VISUAL CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_perspective_surface(failures: Array[String]) -> void:
	var overlay := MATERIAL_OVERLAY.new() as Control
	overlay.size = Vector2(2048.0, 1152.0)
	get_root().add_child(overlay)
	await process_frame
	var contract: Dictionary = overlay.call("get_material_contract")
	if str(contract.get("spatial_structure", "")) != "fixed_camera_shallow_perspective":
		failures.append("桌面必须暴露固定视角浅透视空间合同")
	if str(contract.get("rail_depth", "")) != "ebony_side_rails_with_copper_inner_edge":
		failures.append("桌面必须有深色厚边和旧铜内沿")
	if int(contract.get("seat_zones", 0)) != 4:
		failures.append("桌面必须建立四家围合区")
	if overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		failures.append("全屏桌面装饰层不得拦截触控")
	overlay.queue_free()
	await process_frame


func _verify_identity_hud(failures: Array[String]) -> void:
	var hud := SEAT_HUD_SCENE.instantiate() as Control
	# The production scene configures seat identity before adding the HUD to the
	# tree. This must remain safe because @onready children are not assigned yet.
	hud.call("configure_seat", 1)
	hud.size = Vector2(218.0, 150.0)
	get_root().add_child(hud)
	await process_frame
	hud.call("render", {
		"nickname": "舒小燕",
		"score": 16,
		"ding_que": "wan",
		"_is_dealer": false,
		"_interaction_label": "响应",
		"has_won": false,
	}, 1, true)
	await process_frame
	var avatar := hud.get_node_or_null("%AvatarMedallion") as Control
	var glyph := hud.get_node_or_null("%AvatarGlyph") as Label
	if avatar == null or glyph == null:
		failures.append("玩家 HUD 必须包含原创头像徽章和座位字印")
	else:
		if not avatar.has_method("get_visual_contract"):
			failures.append("玩家头像徽章脚本必须正常加载")
		else:
			var avatar_contract: Dictionary = avatar.call("get_visual_contract")
			if not bool(avatar_contract.get("portrait_replaceable", false)):
				failures.append("程序化头像必须保留替换正式人物资产的接口")
		if avatar.mouse_filter != Control.MOUSE_FILTER_IGNORE or glyph.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("头像装饰不得吞掉牌桌触控")
		if glyph.text != "锦":
			failures.append("上家座位字印必须可辨识")
	var hud_contract: Dictionary = hud.call("get_visual_contract")
	if str(hud_contract.get("identity_surface", "")) != "original_jade_seal_medallion":
		failures.append("玩家 HUD 身份层必须使用原创玉印徽章")
	var identity_encoding: Array = hud_contract.get("identity_encoding", [])
	for encoding in ["seat_glyph", "material_palette", "shape_motif"]:
		if not identity_encoding.has(encoding):
			failures.append("玩家身份不能只依赖颜色，缺少 %s" % encoding)
	hud.queue_free()
	await process_frame


func _verify_center_compass(failures: Array[String]) -> void:
	var indicator := CENTER_INDICATOR_SCENE.instantiate() as Control
	indicator.size = Vector2(210.0, 210.0)
	get_root().add_child(indicator)
	await process_frame
	indicator.call("render", 34, 3, "下家出牌中")
	await process_frame
	var visual_contract: Dictionary = indicator.call("get_visual_contract")
	# 用户指定恢复旧版余牌牌匾：不再显示方位字，同时继续禁止放射分区和循环脉冲。
	if str(visual_contract.get("direction_labels", "")) != "none":
		failures.append("恢复后的中央余牌牌匾不得显示东南西北方位字")
	if str(visual_contract.get("visual_density", "")) != "low":
		failures.append("中央余牌区必须保持低信息密度")
	if int(visual_contract.get("decorative_divisions", -1)) != 0:
		failures.append("中央余牌区不得保留放射分区")
	var encodings: Array = visual_contract.get("active_encoding", [])
	for encoding in ["status_text"]:
		if not encodings.has(encoding):
			failures.append("中央当前玩家反馈缺少 %s" % encoding)
	var compass := indicator.get_node_or_null("%CompassVisual") as Control
	if compass == null:
		failures.append("中央余牌区缺少简洁底板图形层")
	else:
		if not compass.has_method("get_visual_contract"):
			failures.append("中央简洁底板图形脚本必须正常加载")
		else:
			var compass_contract: Dictionary = compass.call("get_visual_contract")
			if str(compass_contract.get("form", "")) != "dark_cut_corner_remaining_plaque":
				failures.append("中央余牌区必须使用旧版深色切角牌匾结构")
			if int(compass_contract.get("radial_divisions", -1)) != 0:
				failures.append("中央底板不得绘制四向放射分区")
			if str(compass_contract.get("motion", "")) != "static":
				failures.append("中央底板不得用循环脉冲制造视觉干扰")
		if compass.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("中央仪表图形层不得拦截弃牌与按钮触控")
	var turn_chip := indicator.get_node_or_null("%TurnChipLabel") as Label
	if turn_chip == null or turn_chip.visible or not turn_chip.text.is_empty():
		failures.append("中央余牌区方向标签必须隐藏且清空")
	var caption := indicator.get_node_or_null("%CaptionLabel") as Label
	if caption == null or caption.text != "余牌" or caption.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		failures.append("余牌标题必须在中央水平居中")
	var count := indicator.get_node_or_null("%CountLabel") as Label
	var status := indicator.get_node_or_null("%StatusLabel") as Label
	for label_value in [caption, count, status]:
		var label := label_value as Label
		if label == null or absf(label.position.x + label.size.x * 0.5 - indicator.size.x * 0.5) > 2.0:
			failures.append("中央余牌牌匾三段文字必须保持 2px 内水平居中")
	if count == null or count.text != "34":
		failures.append("中央余牌数字没有消费 wall_count")
	if status == null or status.text != "下家出牌中":
		failures.append("中央余牌底部没有显示当前出牌状态")
	for legacy_label_name in ["NorthLabel", "EastLabel", "SouthLabel", "WestLabel"]:
		if indicator.get_node_or_null("%%%s" % legacy_label_name) != null:
			failures.append("中央余牌区不应残留四向文字 %s" % legacy_label_name)
	indicator.queue_free()
	await process_frame


func _verify_decision_seals(failures: Array[String]) -> void:
	var action_bar := ACTION_BAR_SCENE.instantiate() as Control
	get_root().add_child(action_bar)
	await process_frame
	var contract: Dictionary = action_bar.call("get_visual_contract")
	if str(contract.get("primary_shape", "")) != "round_jade_seal":
		failures.append("操作按钮必须使用移动麻将常用的大型圆印轮廓")
	if str(contract.get("context_surface", "")) != "floating_decision_seals":
		failures.append("碰杠胡必须是分离的浮空决策按钮")
	var craft := action_bar.get_node_or_null("%CraftPanel") as Control
	if craft == null or craft.visible:
		failures.append("操作区不得再显示整块工具面板外框")
	for action in ["hu", "gang", "peng", "pass"]:
		var button := action_bar.call("get_button", action) as Button
		if button == null or minf(button.custom_minimum_size.x, button.custom_minimum_size.y) < 108.0:
			failures.append("操作按钮 %s 必须保持大于移动端最小触控目标" % action)
	action_bar.queue_free()
	await process_frame
