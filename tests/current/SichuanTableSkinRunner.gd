extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const CATALOG := preload("res://scripts/ui/table/SichuanTableSkinCatalog.gd")
const PANEL_SCRIPT := preload("res://scripts/ui/table/SichuanTableSkinPanel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _verify_assets_panel_and_stage(failures)
	await _verify_production_path(failures)
	if failures.is_empty():
		print("SICHUAN_TABLE_SKIN_PASS")
		quit(0)
		return
	push_error("SICHUAN_TABLE_SKIN_FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_assets_panel_and_stage(failures: Array[String]) -> void:
	var skins: Array[Dictionary] = CATALOG.all_skins()
	if skins.size() != 6:
		failures.append("桌布目录必须精确包含六套皮肤")
	var ids: Dictionary = {}
	for skin in skins:
		var skin_id := str(skin.get("id", ""))
		if skin_id.is_empty() or ids.has(skin_id):
			failures.append("桌布皮肤 ID 为空或重复: %s" % skin_id)
			continue
		ids[skin_id] = true
		for filename in ["albedo_2k.jpg", "normal_2k.png", "roughness_2k.png", "preview.jpg"]:
			var path := CATALOG.texture_path(skin_id, filename)
			if not ResourceLoader.exists(path):
				failures.append("缺少桌布发布资源: %s" % path)
			elif ResourceLoader.load(path) as Texture2D == null:
				failures.append("桌布资源不能作为 Texture2D 加载: %s" % path)

	var panel := PANEL_SCRIPT.new() as SichuanTableSkinPanel
	get_root().add_child(panel)
	await process_frame
	panel.size = Vector2(1365.0, 768.0)
	panel.set_safe_margins(Vector4(24.0, 18.0, 24.0, 22.0))
	panel.open(CATALOG.DEFAULT_SKIN_ID)
	await process_frame
	var panel_contract := panel.get_visual_contract()
	if int(panel_contract.get("skin_count", 0)) != 6:
		failures.append("换肤面板没有显示六套预览卡")
	if not bool(panel_contract.get("safe_area_aware", false)) \
			or not bool(panel_contract.get("modal", false)) \
			or not bool(panel_contract.get("blocks_gameplay_input", false)):
		failures.append("换肤面板丢失安全区或模态输入合同")
	var emitted_ids: Array[String] = []
	panel.skin_selected.connect(func(skin_id: String) -> void: emitted_ids.append(skin_id))
	for skin in skins:
		var skin_id := str(skin.get("id", ""))
		var button := panel.skin_buttons.get(skin_id) as Button
		if button == null or button.icon == null:
			failures.append("换肤面板缺少真实预览卡: %s" % skin_id)
			continue
		if button.custom_minimum_size.x < 88.0 or button.custom_minimum_size.y < 88.0:
			failures.append("换肤预览卡触控目标过小: %s" % skin_id)
		button.pressed.emit()
	var expected_ids: Array[String] = []
	for skin in skins:
		expected_ids.append(str(skin.get("id", "")))
	if emitted_ids != expected_ids:
		failures.append("换肤面板选择事件与六套目录不一致")
	panel.queue_free()
	await process_frame

	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	var table := stage.get_node_or_null("ManufacturedClubTable") as Node3D
	if table == null:
		failures.append("3D 牌桌没有生产桌体")
		stage.queue_free()
		return
	var original_transform := table.transform
	var skin_contract := stage.get_table_skin_contract()
	if int(skin_contract.get("felt_material_count", 0)) < 1:
		failures.append("运行时没有绑定 TableFelt PBR 材质")
	if bool(skin_contract.get("uses_displacement", true)):
		failures.append("桌布皮肤不得使用位移并改变接触面")
	for skin in skins:
		var skin_id := str(skin.get("id", ""))
		if not stage.apply_table_skin(skin_id):
			failures.append("3D 牌桌无法应用皮肤: %s" % skin_id)
			continue
		if stage.get_table_skin_id() != skin_id:
			failures.append("3D 牌桌没有保留当前皮肤 ID: %s" % skin_id)
		if table.transform != original_transform:
			failures.append("应用皮肤改变了牌桌几何或 Transform: %s" % skin_id)
	stage.queue_free()
	await process_frame


func _verify_production_path(failures: Array[String]) -> void:
	var main_scene := MAIN_SCENE.instantiate()
	get_root().add_child(main_scene)
	await process_frame
	await process_frame
	await process_frame
	var utility_bar := main_scene.get("table_utility_bar") as Control
	var panel := main_scene.get("table_skin_panel") as SichuanTableSkinPanel
	var stage := main_scene.get("table_stage_3d") as SichuanTableStage3D
	if utility_bar == null or panel == null or stage == null:
		failures.append("生产主场景缺少工具栏、换肤面板或 3D 牌桌")
		main_scene.queue_free()
		return
	utility_bar.call("set_collapsed", false)
	utility_bar.call("_layout_buttons")
	var skin_button := utility_bar.call("get_button", "skin") as Button
	if skin_button == null or not skin_button.visible:
		failures.append("牌桌工具栏没有可见的桌布皮肤入口")
		main_scene.queue_free()
		return
	if skin_button.size.x < 76.0 or skin_button.size.y < 76.0:
		failures.append("桌布皮肤入口小于 76x76 触控下限")
	var original_skin_id := str(main_scene.get("table_skin_id"))
	var alternate_skin_id := "emerald_linen" if original_skin_id != "emerald_linen" else CATALOG.DEFAULT_SKIN_ID
	var game_manager := main_scene.get("game_manager") as Node
	var state_before: Variant = game_manager.get("game_state") if game_manager != null else null
	var table := stage.get_node_or_null("ManufacturedClubTable") as Node3D
	var transform_before: Transform3D = table.transform if table != null else Transform3D.IDENTITY
	skin_button.pressed.emit()
	if not panel.visible:
		failures.append("桌布皮肤入口没有打开模态选择面板")
	if bool(utility_bar.call("is_collapsed")):
		failures.append("桌布皮肤入口不应强制收回工具栏")
	var alternate_button := panel.skin_buttons.get(alternate_skin_id) as Button
	if alternate_button == null:
		failures.append("生产换肤路径缺少备用皮肤卡片")
	else:
		# Exercise the real modal GUI path: a touch is followed by the emulated
		# mouse press/release that iOS sends for Control buttons.
		var card_center := alternate_button.get_global_rect().get_center()
		var card_touch := InputEventScreenTouch.new()
		card_touch.index = 0
		card_touch.position = card_center
		card_touch.pressed = true
		get_root().push_input(card_touch, true)
		await process_frame
		var card_mouse_press := InputEventMouseButton.new()
		card_mouse_press.button_index = MOUSE_BUTTON_LEFT
		card_mouse_press.position = card_center
		card_mouse_press.global_position = card_center
		card_mouse_press.pressed = true
		get_root().push_input(card_mouse_press, true)
		await process_frame
		var card_mouse_release := InputEventMouseButton.new()
		card_mouse_release.button_index = MOUSE_BUTTON_LEFT
		card_mouse_release.position = card_center
		card_mouse_release.global_position = card_center
		card_mouse_release.pressed = false
		get_root().push_input(card_mouse_release, true)
		await process_frame
		if str(main_scene.get("table_skin_id")) != alternate_skin_id:
			failures.append("真实触摸/模拟鼠标路径没有应用备用皮肤")
	if str(main_scene.get("table_skin_id")) != alternate_skin_id or stage.get_table_skin_id() != alternate_skin_id:
		failures.append("选择皮肤没有贯通主场景与 3D 材质")
	if game_manager != null and game_manager.get("game_state") != state_before:
		failures.append("换肤替换了牌局 GameState")
	if table != null and table.transform != transform_before:
		failures.append("生产换肤路径改变了牌桌 Transform")
	panel.skin_selected.emit(original_skin_id)
	if str(main_scene.get("table_skin_id")) != original_skin_id or stage.get_table_skin_id() != original_skin_id:
		failures.append("生产换肤测试没有恢复原皮肤偏好")
	panel.close()
	main_scene.queue_free()
	await process_frame
	await process_frame
