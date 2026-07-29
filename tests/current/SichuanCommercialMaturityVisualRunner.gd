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
		"nickname": "舒燕",
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
		if glyph.text != "燕":
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
	if str(visual_contract.get("concept", "")) != "floating_wall_count_above_physical_center":
		failures.append("中央必须使用图形上方的悬浮余牌文字")
	if str(visual_contract.get("physical_asset", "")) != "res://res/art/3d/sichuan_center_compass_v2.glb":
		failures.append("中央四向器必须声明可复现的 Blender 实体资产")
	if str(visual_contract.get("visual_density", "")) != "low":
		failures.append("中央方向器必须保持低信息密度")
	if bool(visual_contract.get("persistent_long_status_text", true)):
		failures.append("中央不得常驻显示出牌中等长句")
	var compass := indicator.get_node_or_null("%CompassVisual") as Control
	if compass == null:
		failures.append("中央余牌区缺少简洁底板图形层")
	else:
		if not compass.has_method("get_visual_contract"):
			failures.append("中央简洁底板图形脚本必须正常加载")
		else:
			var compass_contract: Dictionary = compass.call("get_visual_contract")
			if str(compass_contract.get("form", "")) != "blender_pbr_low_profile_four_way_compass":
				failures.append("中央图形层必须与 Blender PBR 四向器匹配")
			if int(compass_contract.get("radial_divisions", -1)) != 4:
				failures.append("中央图形层必须保留四向形状编码")
			if not bool(compass_contract.get("motion_safe", false)):
				failures.append("中央四向器必须提供 reduced-motion 合同")
		if compass.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("中央仪表图形层不得拦截弃牌与按钮触控")
		if compass.visible:
			failures.append("中央方向高亮框必须随方向文字一并隐藏")
	var turn_chip := indicator.get_node_or_null("%TurnChipLabel") as Label
	if turn_chip == null or turn_chip.text != "余34":
		failures.append("余牌数必须是中心图形上方的单行悬浮文字")
	if str(visual_contract.get("overlay_frames", "")) != "removed":
		failures.append("中央悬浮余牌不得保留背景暗框")
	var caption := indicator.get_node_or_null("%CaptionLabel") as Label
	if caption == null or caption.visible:
		failures.append("四向器顶部不应显示对家文字方向")
	var count := indicator.get_node_or_null("%CountLabel") as Label
	var status := indicator.get_node_or_null("%StatusLabel") as Label
	if count == null or count.visible:
		failures.append("中央不应显示本地表现倒计时")
	if status == null or status.visible:
		failures.append("四向器底部不应显示本家文字方向")
	var left_label := indicator.get_node_or_null("%LeftDirectionLabel") as Label
	var right_label := indicator.get_node_or_null("%RightDirectionLabel") as Label
	if left_label == null or left_label.visible or right_label == null or right_label.visible:
		failures.append("四向器左右不应显示上/下文字编码")
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
