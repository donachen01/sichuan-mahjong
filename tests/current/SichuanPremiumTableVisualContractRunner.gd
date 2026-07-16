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
	if str(contract.get("name", "")) != "蜀锦玉案":
		failures.append("牌桌主题必须使用蜀锦玉案品牌语言")
	if str(contract.get("shape_motif", "")) != "shu_courtyard_cut_corner":
		failures.append("核心轮廓必须使用蜀院切角母题")
	var materials: Array = contract.get("materials", [])
	for material in ["ink_jade_felt", "ebony_lacquer", "warm_ceramic_and_jade"]:
		if not materials.has(material):
			failures.append("蜀锦玉案材质合同缺少 %s" % material)


func _verify_club_palette_and_shader(failures: Array[String]) -> void:
	var expected_colors := {
		"ink_jade": Color("052820"),
		"malachite": Color("0B3F34"),
		"ebony": Color("031815"),
		"aged_copper": Color("A8793A"),
		"copper_highlight": Color("C59A58"),
		"ivory": Color("F4E9C9"),
	}
	var actual_colors := {
		"ink_jade": TABLE_THEME.INK_JADE_DEEP,
		"malachite": TABLE_THEME.MALACHITE,
		"ebony": TABLE_THEME.EBONY,
		"aged_copper": TABLE_THEME.AGED_COPPER,
		"copper_highlight": TABLE_THEME.COPPER_HIGHLIGHT,
		"ivory": TABLE_THEME.WARM_CERAMIC,
	}
	for color_name in expected_colors:
		var expected: Color = expected_colors[color_name]
		var actual: Color = actual_colors[color_name]
		if not actual.is_equal_approx(expected):
			failures.append("会所主题色 %s 偏离指定色值" % color_name)

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
			var brocade_opacity := float(shader_material.get_shader_parameter("brocade_opacity"))
			if brocade_opacity < 0.04 or brocade_opacity > 0.10:
				failures.append("蜀锦暗纹透明度必须保持在 4%-10%，当前 %.3f" % brocade_opacity)
			var shader_source := FileAccess.get_file_as_string("res://shaders/table_club_felt.gdshader")
			for motif_name in ["huiwen_motif", "yunlei_motif", "diamond_brocade", "scroll_grass_motif", "intertwined_branch_motif"]:
				if not shader_source.contains(motif_name):
					failures.append("蜀锦暗纹缺少程序化纹样 %s" % motif_name)
			if shader_source.contains("centered_spotlight"):
				failures.append("牌桌不得恢复中央大圆形亮斑")
	overlay.free()


func _verify_tile_material_contract(failures: Array[String]) -> void:
	if not TILE_STYLE.FACE_TOP.is_equal_approx(Color("FFF4D8")):
		failures.append("麻将牌面必须使用暖玉白 #FFF4D8")
	if not TILE_STYLE.FACE_BOTTOM.is_equal_approx(Color("F2E4BD")):
		failures.append("麻将牌底色必须使用 #F2E4BD")
	if not TILE_STYLE.BACK_TOP.is_equal_approx(Color("16704F")) or not TILE_STYLE.BACK_BOTTOM.is_equal_approx(Color("0A4A3D")):
		failures.append("麻将牌背必须使用指定深玉绿渐变")
	var style := TILE_STYLE.new()
	if not style.has_method("material_contract"):
		failures.append("shared tile style must expose a material contract")
	else:
		var material: Dictionary = style.call("material_contract")
		for key in ["light_source", "face_highlight", "face_warmth", "side_mid", "bottom_deep", "contact_shadow", "back_finish", "depth_ratio"]:
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
	tile.free()


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
		if str(hud_contract.get("material_family", "")) != "ebony_lacquer_cut_corner_nameplate":
			failures.append("SeatHUD must use the ebony lacquer cut-corner nameplate material")
		if str(hud_contract.get("active_treatment", "")) != "copper_edge_light":
			failures.append("SeatHUD current-turn state must use a restrained copper edge light")
	hud.free()

	var action_bar := ACTION_BAR_SCENE.instantiate() as Control
	get_root().add_child(action_bar)
	await process_frame
	if not action_bar.has_method("get_visual_contract"):
		failures.append("action bar must expose tactile tile-button visual contract")
	else:
		var action_contract: Dictionary = action_bar.call("get_visual_contract")
		if str(action_contract.get("primary_shape", "")) != "shu_cut_corner_tile":
			failures.append("action bar primary controls must use Shu cut-corner tile geometry")
		if str(action_contract.get("pass_hierarchy", "")) != "secondary":
			failures.append("pass must remain visually secondary")
		if str(action_contract.get("context_surface", "")) != "decision_tile_group":
			failures.append("action bar must present reactions as a contextual decision tile group")
		if str(action_contract.get("auxiliary_text", "")) != "hidden":
			failures.append("右下角碰杠胡操作区只能显示边框和按钮，不得显示提示文字")
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
