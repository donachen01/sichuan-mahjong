extends SceneTree

const TILE_STYLE := preload("res://scripts/ui/table/SichuanTileStyle.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const MATERIAL_OVERLAY := preload("res://scripts/ui/TableMaterialOverlay.gd")
const TILE_SCENE := preload("res://scenes/ui/MahjongTile.tscn")
const HAND_CANVAS := preload("res://scripts/ui/HandCanvas2D.gd")
const DISCARD_LAYER := preload("res://scripts/ui/table/TableDiscardLayer.gd")
const ACTION_BAR_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")
const SEAT_HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")

const SELF_HAND_SIZE := Vector2(2008.0, 262.0)
const BOARD_SIZE := Vector2(1440.0, 710.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_verify_brand_language_contract(failures)
	await _verify_club_palette_and_shader(failures)
	_verify_tile_material_contract(failures)
	_verify_self_hand_clearance(failures)
	await _verify_discard_scale_and_separation(failures)
	await _verify_hud_and_action_materials(failures)
	await _verify_live_hud_tile_separation(failures)
	if failures.is_empty():
		print("SICHUAN PREMIUM TABLE VISUAL CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN PREMIUM TABLE VISUAL CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_brand_language_contract(failures: Array[String]) -> void:
	var contract: Dictionary = TABLE_THEME.brand_contract()
	if str(contract.get("name", "")) != "深翡翠雅局":
		failures.append("牌桌主题必须使用深翡翠雅局品牌语言")
	if str(contract.get("direction", "")) != "deep_emerald_refined_noncommercial_mahjong":
		failures.append("牌桌主题方向必须锁定深翡翠精品非商业化麻将")
	if str(contract.get("shape_motif", "")) != "shu_courtyard_cut_corner":
		failures.append("核心轮廓必须使用蜀院切角母题")
	var materials: Array = contract.get("materials", [])
	for material in ["deep_emerald_short_nap_felt", "ink_green_leather", "black_walnut", "warm_ivory_tiles"]:
		if not materials.has(material):
			failures.append("深翡翠雅局材质合同缺少 %s" % material)
	var hierarchy: Array = contract.get("visual_hierarchy", [])
	var expected_hierarchy := ["tiles", "actions_and_key_text", "player_panels", "brocade_frame_ornament"]
	if hierarchy != expected_hierarchy:
		failures.append("视觉权重必须依次为牌、动作、玩家面板、暗纹装饰")
	if str(contract.get("background_role", "")) != "atmosphere_only":
		failures.append("桌面背景只能承担氛围，不得与牌面竞争")


func _verify_club_palette_and_shader(failures: Array[String]) -> void:
	var expected_colors := {
		"table_center": Color("167A64"),
		"table_base": Color("0F6957"),
		"table_edge": Color("0A4B41"),
		"leather": Color("172621"),
		"walnut": Color("281F1B"),
		"aged_copper": Color("9D743A"),
		"copper_highlight": Color("C49A55"),
		"ivory": Color("F2EBDD"),
	}
	var actual_colors := {
		"table_center": TABLE_THEME.TABLE_CENTER,
		"table_base": TABLE_THEME.TABLE_BASE,
		"table_edge": TABLE_THEME.TABLE_EDGE,
		"leather": TABLE_THEME.LEATHER_RAIL,
		"walnut": TABLE_THEME.WALNUT_DARK,
		"aged_copper": TABLE_THEME.AGED_COPPER,
		"copper_highlight": TABLE_THEME.COPPER_HIGHLIGHT,
		"ivory": TABLE_THEME.IVORY_TEXT,
	}
	for color_name in expected_colors:
		var expected: Color = expected_colors[color_name]
		var actual: Color = actual_colors[color_name]
		if not actual.is_equal_approx(expected):
			failures.append("参考蓝桌主题色 %s 偏离指定色值" % color_name)

	var overlay := MATERIAL_OVERLAY.new() as Control
	overlay.size = Vector2(2048.0, 1152.0)
	get_root().add_child(overlay)
	await process_frame
	var shader_layer := overlay.get_node_or_null("ClubFeltShader") as ColorRect
	if shader_layer == null or not shader_layer.visible:
		failures.append("牌桌必须实际挂载 ClubFeltShader 材质层")
	else:
		var shader_material := shader_layer.material as ShaderMaterial
		if shader_material == null or shader_material.shader == null:
			failures.append("ClubFeltShader 必须使用有效 CanvasItem ShaderMaterial")
		else:
			var shader_path := shader_material.shader.resource_path
			if shader_path != "res://shaders/table_club_felt.gdshader":
				failures.append("ClubFeltShader 使用了错误的 shader: %s" % shader_path)
			var nap_strength: float = shader_material.get_shader_parameter("nap_strength")
			if nap_strength < 0.020 or nap_strength > 0.035:
				failures.append("短绒变化必须保持在 2%-3.5%，当前 %.3f" % nap_strength)
			var brocade_strength: float = shader_material.get_shader_parameter("brocade_strength")
			if brocade_strength < 0.018 or brocade_strength > 0.030:
				failures.append("边缘蜀锦浮雕必须保持在 1.8%-3%，当前 %.3f" % brocade_strength)
			var edge_darkening: float = shader_material.get_shader_parameter("edge_darkening")
			if edge_darkening < 0.05 or edge_darkening > 0.08:
				failures.append("桌面边缘压暗必须保持在 5%-8%，当前 %.3f" % edge_darkening)
			var center_lift: float = shader_material.get_shader_parameter("center_lift")
			if center_lift < 0.03 or center_lift > 0.05:
				failures.append("桌面中央提亮必须保持在 3%-5%，当前 %.3f" % center_lift)
			var shader_source := FileAccess.get_file_as_string("res://shaders/table_club_felt.gdshader")
			for texture_source in ["value_noise", "outer_brocade", "center_lift", "edge_darkening"]:
				if not shader_source.contains(texture_source):
					failures.append("深翡翠短绒材质缺少程序化实现 %s" % texture_source)
			for forbidden_source in ["fine_weave", "cloud_scroll", "ring_line", "centered_spotlight", "shu_medallion_motif", "off_canvas_source"]:
				if shader_source.contains(forbidden_source):
					failures.append("牌桌不得包含高频织线、大团花或径向圆形亮斑实现 %s" % forbidden_source)
	if not overlay.has_method("get_material_contract"):
		failures.append("牌桌材质层必须暴露毛绒与环境灯光合同")
	else:
		var overlay_contract: Dictionary = overlay.call("get_material_contract")
		var base_palette: Array = overlay_contract.get("base_palette", [])
		for color_hex in ["0a4b41", "0f6957", "167a64"]:
			if not base_palette.has(color_hex):
				failures.append("墨玉桌面基础色缺少 #%s" % color_hex)
		var lighting_layers: Array = overlay_contract.get("lighting_layers", [])
		for layer_name in ["broad_center_lift", "edge_vignette"]:
			if not lighting_layers.has(layer_name):
				failures.append("环境灯光合同缺少 %s" % layer_name)
		if str(overlay_contract.get("surface_finish", "")) != "deep_emerald_short_nap_felt":
			failures.append("桌面必须使用深翡翠无规则短绒")
		if str(overlay_contract.get("texture_coverage", "")) != "full_surface":
			failures.append("毛绒纹理必须覆盖完整桌面")
		if str(overlay_contract.get("fiber_directions", "")) != "irregular_multi_scale_nap":
			failures.append("短绒必须使用无规则多尺度方向变化")
		if str(overlay_contract.get("geometric_motifs", "")) != "outer_8_to_10_percent_shu_brocade_only":
			failures.append("蜀锦暗纹只能位于桌面外圈8%-10%")
		if str(overlay_contract.get("reference_target", "")) != "deep_emerald_refined_table_without_logo":
			failures.append("桌面参考合同必须明确为无商标文字的深翡翠精品桌")
		if bool(overlay_contract.get("circular_hotspot", true)):
			failures.append("牌桌光照合同必须明确禁止圆形亮斑")
	overlay.free()


func _verify_tile_material_contract(failures: Array[String]) -> void:
	if not TILE_STYLE.FACE_TOP.is_equal_approx(Color("FFF4D8")):
		failures.append("麻将牌面必须使用暖玉白 #FFF4D8")
	if not TILE_STYLE.FACE_BOTTOM.is_equal_approx(Color("F2E4BD")):
		failures.append("麻将牌底色必须使用 #F2E4BD")
	if TILE_STYLE.FACE_TOP.is_equal_approx(Color.WHITE):
		failures.append("麻将牌不得使用纯白色")
	if not TILE_STYLE.BACK_TOP.is_equal_approx(Color("16704F")) or not TILE_STYLE.BACK_BOTTOM.is_equal_approx(Color("0A4A3D")):
		failures.append("麻将牌背必须使用指定深玉绿渐变")
	var style := TILE_STYLE.new()
	if not style.has_method("material_contract"):
		failures.append("shared tile style must expose a material contract")
	else:
		var material: Dictionary = style.call("material_contract")
		for key in ["light_source", "face_highlight", "face_warmth", "side_mid", "bottom_deep", "contact_shadow", "face_palette", "back_palette", "back_finish", "depth_ratio"]:
			if not material.has(key):
				failures.append("tile material contract missing %s" % key)
		if str(material.get("back_finish", "")) != "matte_malachite_brocade":
			failures.append("牌背必须是亚光孔雀石蜀锦纹，不能使用玻璃高光")
	var tile := TILE_SCENE.instantiate() as Control
	get_root().add_child(tile)
	tile.call("configure", _tile(1, 4), 1.0, false, false, false)
	var contract: Dictionary = tile.call("get_visual_contract")
	for key in ["bevel_top_rect", "bevel_left_rect", "face_inner_rect", "body_depth"]:
		if not contract.has(key):
			failures.append("shared tile depth contract missing %s" % key)
	tile.call("configure", _tile(2, 5), 1.0, false, false, false, true)
	if not tile.has_method("get_feedback_contract"):
		failures.append("public tile must expose latest-discard feedback contract")
	else:
		var feedback: Dictionary = tile.call("get_feedback_contract")
		if not bool(feedback.get("latest_uses_shape", false)) or not bool(feedback.get("latest_uses_color", false)):
			failures.append("latest discard must use both a persistent shape and color")
		if float(feedback.get("pulse_scale", 0.0)) > 0.025:
			failures.append("latest-discard pulse must remain subtle")
	tile.free()
	var selection_canvas := HAND_CANVAS.new()
	var selection_contract: Dictionary = selection_canvas.call("get_selection_feedback_contract")
	if float(selection_contract.get("lift", 0.0)) < 16.0:
		failures.append("selected self tile needs a clearly readable lift")
	if str(selection_contract.get("ground_shadow", "")) != "stays_on_rack_when_tile_lifts":
		failures.append("selected tile shadow must remain grounded on the rack")
	if not bool(selection_contract.get("states_are_visually_distinct", false)):
		failures.append("选中、刚摸、危险和 AI 推荐牌必须使用互不混淆的状态语言")
	if str(selection_contract.get("new_draw", "")) != "jade_corner_notch_and_physical_gap":
		failures.append("刚摸牌不得继续复用红色选中态")
	selection_canvas.free()


func _verify_self_hand_clearance(failures: Array[String]) -> void:
	var hand := HAND_CANVAS.new() as Node2D
	get_root().add_child(hand)
	var tiles: Array = []
	for index in range(14):
		tiles.append(_tile(100 + index, index))
	hand.call("configure", tiles, -1, 113, SELF_HAND_SIZE, {}, {})
	var bounds: Rect2 = hand.call("get_layout_bounds")
	var bottom_clearance := SELF_HAND_SIZE.y - bounds.end.y
	if bottom_clearance < 18.0:
		failures.append("self hand depth needs at least 18px bottom clearance, got %.1f" % bottom_clearance)
	hand.free()


func _verify_discard_scale_and_separation(failures: Array[String]) -> void:
	var layer := DISCARD_LAYER.new() as Control
	get_root().add_child(layer)
	var players: Array = []
	for seat in range(4):
		var discards: Array = []
		for index in range(14):
			discards.append(_tile(seat * 100 + index, index))
		players.append({"seat": seat, "discards": discards})
	layer.call("render", players, {"id": 313}, Rect2(Vector2.ZERO, BOARD_SIZE))
	await process_frame
	var center: Rect2 = layer.call("get_center_reserved_rect")
	for seat in range(4):
		var lane_rect: Rect2 = layer.call("get_lane_rect", seat)
		if lane_rect.intersects(center):
			failures.append("enlarged discard lane %d entered center reserve" % seat)
		var rects: Array = layer.call("get_tile_rects", seat)
		if rects.size() != 14:
			failures.append("seat %d must retain 14 public discards" % seat)
		for left in range(rects.size()):
			for right in range(left + 1, rects.size()):
				if (rects[left] as Rect2).intersects(rects[right] as Rect2):
					failures.append("seat %d enlarged discards overlap" % seat)
					break
	var bottom_rects: Array = layer.call("get_tile_rects", 0)
	if not bottom_rects.is_empty() and (bottom_rects[0] as Rect2).size.y < 116.0:
		failures.append("public discard tiles must be visibly larger; bottom height %.1f" % (bottom_rects[0] as Rect2).size.y)
	layer.free()


func _verify_hud_and_action_materials(failures: Array[String]) -> void:
	var hud := SEAT_HUD_SCENE.instantiate() as Control
	get_root().add_child(hud)
	await process_frame
	if not hud.has_method("get_visual_contract"):
		failures.append("SeatHUD must expose premium nameplate visual contract")
	else:
		var hud_contract: Dictionary = hud.call("get_visual_contract")
		if str(hud_contract.get("material_family", "")) != "unified_smoked_jade_nameplate":
			failures.append("all SeatHUD cards must share one smoked-jade material family")
		if str(hud_contract.get("active_treatment", "")) != "single_thin_antique_gold_edge":
			failures.append("SeatHUD current-turn state must use one restrained antique-gold edge")
		if str(hud_contract.get("default_treatment", "")) != "single_low_contrast_bronze_edge_without_glow":
			failures.append("inactive SeatHUD cards must avoid seat-coloured borders and stacked glows")
		if hud_contract.get("seat_avatar_glyphs", []) != ["旭", "燕", "东", "玲"]:
			failures.append("SeatHUD avatar glyph order must remain self 旭, upper 燕, opposite 东, lower 玲")
	hud.free()

	var action_bar := ACTION_BAR_SCENE.instantiate() as Control
	get_root().add_child(action_bar)
	await process_frame
	if not action_bar.has_method("get_visual_contract"):
		failures.append("action bar must expose tactile tile-button visual contract")
	else:
		var action_contract: Dictionary = action_bar.call("get_visual_contract")
		if str(action_contract.get("primary_shape", "")) != "single_ring_table_badge":
			failures.append("action bar primary controls must use the redesigned single-ring badge")
		if str(action_contract.get("skin_binding", "")) != "active_table_skin_palette_and_material":
			failures.append("action bar must bind its palette to the active table skin")
		if str(action_contract.get("pass_hierarchy", "")) != "secondary":
			failures.append("pass must remain visually secondary")
		if str(action_contract.get("context_surface", "")) != "floating_single_ring_badges":
			failures.append("action bar must present reactions as separate floating single-ring badges")
		if str(action_contract.get("auxiliary_text", "")) != "hidden":
			failures.append("右下角碰杠胡操作区只能显示边框和按钮，不得显示提示文字")
		if str(action_contract.get("motion_language", "")) != "short_scale_and_light_response":
			failures.append("动作按钮必须使用短促缩放与受光反馈")
		if action_bar.has_method("set_table_skin"):
			action_bar.call("set_table_skin", "deep_emerald_crepe")
			var deep_style := (action_bar.call("get_button", "peng") as Button).get_theme_stylebox("normal") as StyleBoxTexture
			action_bar.call("set_table_skin", "champagne_satin")
			var satin_style := (action_bar.call("get_button", "peng") as Button).get_theme_stylebox("normal") as StyleBoxTexture
			if deep_style == null or satin_style == null or deep_style.texture == satin_style.texture:
				failures.append("动作按钮必须随当前桌布皮肤刷新真实材质贴图")
	var motion_contract: Dictionary = action_bar.call("get_motion_contract")
	if float(motion_contract.get("entrance_duration", 1.0)) > 0.20 or float(motion_contract.get("press_duration", 1.0)) > 0.20:
		failures.append("动作按钮动画必须控制在 200ms 内")
	action_bar.free()


func _verify_live_hud_tile_separation(failures: Array[String]) -> void:
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var players: Array = []
	for seat in range(4):
		players.append({
			"seat": seat,
			"nickname": "玩家%d" % seat,
			"score": seat * 3,
			"hand_count": 11,
			"hand_tiles": [],
			"melds": [{
				"type": "peng",
				"tile": _tile(3000 + seat * 10, seat),
				"tiles": [_tile(3000 + seat * 10, seat), _tile(3001 + seat * 10, seat), _tile(3002 + seat * 10, seat)],
				"from_seat": (seat + 1) % 4,
			}],
			"discards": [],
			"ding_que": ["wan", "tong", "tiao", "wan"][seat],
			"has_won": false,
		})
	for pair in [[0, "self_ui"], [1, "left_ui"], [2, "top_ui"], [3, "right_ui"]]:
		var ui: Control = scene.get(str(pair[1])) as Control
		if ui != null:
			ui.call("apply_snapshot", players[int(pair[0])], int(pair[0]) != 0, 0, 0, true)
	scene.call("_update_seat_huds", {
		"players": players,
		"current_dealer_seat": 0,
		"current_turn_seat": 1,
		"rules": {"use_ding_que_phase": true},
	})
	await process_frame
	var huds: Dictionary = scene.get("seat_huds")
	for pair in [[0, "self_ui"], [1, "left_ui"], [2, "top_ui"], [3, "right_ui"]]:
		var seat := int(pair[0])
		var player_ui: Control = scene.get(str(pair[1])) as Control
		var hud: Control = huds.get(seat) as Control
		if player_ui == null or hud == null or not player_ui.has_method("get_visual_tile_rects"):
			continue
		for tile_rect_value in player_ui.call("get_visual_tile_rects"):
			var tile_rect: Rect2 = tile_rect_value
			if hud.get_global_rect().intersects(tile_rect):
				failures.append("seat %d nameplate overlaps a visible Mahjong tile" % seat)
				break
	for pair in [[1, "left_ui"], [3, "right_ui"]]:
		var side_ui: Control = scene.get(str(pair[1])) as Control
		if side_ui != null:
			var slot_plate := side_ui.find_child("SlotPlate", true, false)
			if slot_plate != null and (slot_plate as CanvasItem).visible:
				failures.append("seat %d side hand lane must not contain a full-height dark SlotPlate" % int(pair[0]))
	scene.queue_free()
	await process_frame


func _tile(tile_id: int, index: int) -> Dictionary:
	return {
		"id": tile_id,
		"suit": ["wan", "tiao", "tong"][index % 3],
		"rank": index % 9 + 1,
	}
