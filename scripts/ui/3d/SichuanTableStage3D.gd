class_name SichuanTableStage3D
extends Node3D

signal tile_pressed(tile_id: int)

const TILE_SCRIPT := preload("res://scripts/ui/3d/SichuanTile3D.gd")
const TABLE_SCENE := preload("res://res/art/3d/sichuan_table.glb")
const PLUSH_FELT_SHADER := preload("res://shaders/table_plush_felt_3d.gdshader")
const RAIL_TEXTURE_SHADER := preload("res://shaders/table_rail_texture_3d.gdshader")

const HAND_STEP_SELF := 0.80
# 侧家(上/下家)牌沿桌边码放的步距。0.45 太密，牌挤成一条分不清；
# 加大到 0.62 让每张牌之间留出清晰分界，贴合目标图一张一张的层次感。
const HAND_STEP_SIDE := 0.62
const HAND_STEP_FAR := 0.55
const SELF_HAND_SCALE := 1.94
const SIDE_HAND_SCALE := 1.44
const FAR_HAND_SCALE := 1.27
const MELD_SCALE := 1.12
const DISCARD_SCALE := 1.16
const DISCARD_COLUMN_STEP := 0.56
const DISCARD_ROW_STEP := 0.78
const MAX_VISIBLE_DISCARDS := 18
const TWEEN_SECONDS := 0.18
const SELF_RACK_TILT_DEGREES := 48.0
# 对家、上家和下家的暗手按用户验收要求严格垂直于桌面，不再向桌心内倾。
# 正负号只决定哪一实体表面朝向牌主；绝对值都必须保持 90°。
const SIDE_RACK_TILT_DEGREES := 90.0
const FAR_RACK_TILT_DEGREES := -90.0
const CENTER_INDICATOR_WORLD_Z := -1.60
const DISCARD_GLOBAL_Z_SHIFT := -1.60

# Named product contract calibrated against the supplied commercial reference.
# The target composition relies on genuine foreground/background scale change
# and a front-wide/back-narrow table trapezoid, so this camera must remain
# perspective rather than merely geometrically balanced in isolation.
const CAMERA_PROFILE := "commercial_reference_perspective_v2"
const CAMERA_FOV := 49.5
const CAMERA_POSITION := Vector3(0.0, 13.0, 13.0)
const CAMERA_TARGET := Vector3(0.0, 0.0, -0.50)

var camera: Camera3D
var tile_root: Node3D
var tile_nodes: Dictionary = {}
var self_hand_keys: Array[String] = []
var last_contract: Dictionary = {}
var reduced_motion := false
var interaction_enabled := false
var self_meld_tile_count := 0


func _ready() -> void:
	_setup_world()
	_setup_table()
	tile_root = Node3D.new()
	tile_root.name = "GameplayTiles"
	add_child(tile_root)


func render_snapshot(
	snapshot: Dictionary,
	all_hands: Array,
	reveal_opponents: bool,
	selected_tile_id: int,
	markers: Dictionary = {}
) -> void:
	if tile_root == null:
		return
	interaction_enabled = bool(snapshot.get("human_can_discard", false))
	self_hand_keys.clear()
	var desired: Dictionary = {}
	var players: Array = snapshot.get("players", [])
	var latest_discard_id := int(snapshot.get("recent_discard_tile_id", -1))
	var new_draw_id := int(snapshot.get("human_last_draw_tile_id", -1))
	var recommended_id := int(markers.get("recommended_tile_id", -1))
	var danger_ids: Array = markers.get("danger_tile_ids", [])
	self_meld_tile_count = _meld_tile_count(_player_by_seat(players, 0).get("melds", []))

	for seat in range(4):
		var player := _player_by_seat(players, seat)
		var hand: Array = all_hands[seat] if seat < all_hands.size() else []
		_append_hand_entries(
			desired,
			seat,
			hand,
			player,
			seat == 0 or reveal_opponents,
			selected_tile_id,
			new_draw_id,
			recommended_id,
			danger_ids
		)
		_append_meld_entries(desired, seat, player.get("melds", []))
		_append_discard_entries(desired, seat, player.get("discards", []), latest_discard_id)

	_apply_entries(desired)
	last_contract = _build_contract(snapshot, all_hands, players, desired)


func pick_tile(screen_position: Vector2) -> int:
	var tile_id := find_tile_at_screen(screen_position)
	if tile_id >= 0:
		tile_pressed.emit(tile_id)
	return tile_id


func find_tile_at_screen(screen_position: Vector2) -> int:
	if not interaction_enabled or camera == null:
		return -1
	for index in range(self_hand_keys.size() - 1, -1, -1):
		var key: String = self_hand_keys[index]
		var tile := tile_nodes.get(key) as SichuanTile3D
		if tile == null or not tile.pickable:
			continue
		if tile.get_screen_rect(camera).grow(12.0).has_point(screen_position):
			return tile.tile_id
	return -1


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for tile_value in tile_nodes.values():
		var tile := tile_value as SichuanTile3D
		if tile != null:
			tile.set_reduced_motion(enabled)


func get_visual_contract() -> Dictionary:
	return last_contract.duplicate(true)


func get_camera() -> Camera3D:
	return camera


func _setup_world() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ClubWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202A43")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("AEB9CC")
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Small-radius SSAO grounds adjacent tiles without turning the ivory faces
	# grey. This effect is available in the project's iOS Compatibility renderer;
	# SSIL/GI remain off to preserve the mobile budget.
	environment.ssao_enabled = true
	environment.ssao_radius = 0.72
	environment.ssao_intensity = 1.15
	environment.ssao_power = 1.35
	environment.ssao_detail = 0.45
	environment.ssao_horizon = 0.06
	environment.ssao_sharpness = 0.82
	environment.ssao_light_affect = 0.28
	world_environment.environment = environment
	add_child(world_environment)

	camera = Camera3D.new()
	camera.name = "TableCamera"
	# Crop the physical table like a mobile Mahjong client: the play surface fills
	# the screen and the far rail stays outside the composition. This gives the
	# gameplay tiles substantially more pixels without changing the 2D HUD scale.
	camera.position = CAMERA_POSITION
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = CAMERA_FOV
	camera.near = 0.1
	camera.far = 50.0
	camera.look_at_from_position(camera.position, CAMERA_TARGET, Vector3.UP)
	camera.current = true
	add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.name = "UpperLeftWarmKey"
	key_light.light_color = Color("F3F7FF")
	key_light.light_energy = 0.92
	# DirectionalLight3D shines along local -Z. The -146-degree yaw points the
	# ground component toward the player's right/down screen quadrant, matching
	# the supplied commercial reference instead of the former right/up shadow.
	key_light.rotation_degrees = Vector3(-60.0, -165.0, -8.0)
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 24.0
	key_light.shadow_opacity = 0.94
	key_light.shadow_blur = 1.55
	key_light.shadow_bias = 0.035
	key_light.shadow_normal_bias = 0.82
	add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "CenterSoftFill"
	fill_light.position = Vector3(-2.6, 7.8, 8.0)
	fill_light.light_color = Color("9CBAE7")
	fill_light.light_energy = 1.60
	fill_light.omni_range = 18.0
	# Layer 2 is reserved for Mahjong tiles. A camera-side fill preserves glyph
	# readability on upright faces without washing out the blue table or filling
	# the single key shadow.
	fill_light.light_cull_mask = 1 << 1
	fill_light.shadow_enabled = false
	add_child(fill_light)


func _setup_table() -> void:
	var table := TABLE_SCENE.instantiate() as Node3D
	table.name = "ManufacturedClubTable"
	# Extend only the table depth so the far/opponent rail sits outside the
	# camera crop while the left/right rails still frame the play surface.
	table.scale = Vector3(1.0, 1.0, 1.60)
	table.position.z = -2.30
	add_child(table)
	_apply_table_materials(table)

	var plush_felt := MeshInstance3D.new()
	plush_felt.name = "FullSurfacePlushFelt"
	var plane := PlaneMesh.new()
	plane.size = Vector2(13.55, 13.40)
	plush_felt.mesh = plane
	plush_felt.position = Vector3(0.0, 0.051, -2.30)
	plush_felt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = PLUSH_FELT_SHADER
	plush_felt.material_override = material
	add_child(plush_felt)


func _apply_table_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var node_name := mesh_instance.name.to_lower()
		if "frame" in node_name:
			var rail_material := ShaderMaterial.new()
			rail_material.shader = RAIL_TEXTURE_SHADER
			mesh_instance.material_override = rail_material
		else:
			var color := Color("3A5787")
			var roughness := 0.86
			var metallic := 0.0
			if "copper" in node_name:
				color = Color("52647F")
				roughness = 0.38
				metallic = 0.42
			elif "felt" not in node_name:
				color = Color("3A5787")
			var table_material := StandardMaterial3D.new()
			table_material.albedo_color = color
			table_material.roughness = roughness
			table_material.metallic = metallic
			mesh_instance.material_override = table_material
	for child in node.get_children():
		_apply_table_materials(child)


func _append_hand_entries(
	desired: Dictionary,
	seat: int,
	hand: Array,
	player: Dictionary,
	show_face: bool,
	selected_id: int,
	new_draw_id: int,
	recommended_id: int,
	danger_ids: Array
) -> void:
	var has_won := bool(player.get("has_won", false))
	var winning_tile: Dictionary = player.get("winning_tile", {})
	var winning_tile_id := int(winning_tile.get("id", -1))
	var winning_source_seat := int(player.get("winning_source_seat", seat))
	# 自摸牌本来就在手牌中：必须与全部手牌一起倒下，不能先抽出再当成点炮牌附加。
	# 自摸结算时整手扣在桌面，只展示统一翡翠牌背，不能泄露全部牌面。
	# 只有点炮胡才在原手牌旁附加一张外来胡牌，AI 点炮胡同时保留原站立手牌。
	var self_draw_win := has_won and not winning_tile.is_empty() and winning_source_seat == seat
	var discard_win := has_won and not winning_tile.is_empty() and winning_source_seat != seat
	var ai_discard_win := seat != 0 and has_won and not winning_tile.is_empty() and winning_source_seat != seat
	# 三家明牌时统一平放正面，避免严格 90° 的侧家牌面与相机视线近乎平行，
	# 看起来仍像牌背。胡牌展示与主动明牌共用真实 3D 牌，不引入额外 HUD 贴图。
	var reveal_opponent_hand := show_face and seat != 0 and not has_won
	var conceal_self_draw_result := self_draw_win and seat != 0
	var lay_down_hand := (has_won and not ai_discard_win) or reveal_opponent_hand
	var display_hand: Array = hand.duplicate(true)
	if seat == 0:
		display_hand = _sort_human_hand_for_display(display_hand, str(player.get("ding_que", "")))
	if discard_win and winning_tile_id >= 0:
		var winning_index := -1
		for index in range(display_hand.size()):
			if int((display_hand[index] as Dictionary).get("id", -1)) == winning_tile_id:
				winning_index = index
				break
		if winning_index >= 0:
			display_hand.remove_at(winning_index)
	var count := display_hand.size()
	var step := _hand_step_for_seat(seat)
	var scale_value := _hand_scale_for_seat(seat)
	for index in range(count):
		var tile: Dictionary = display_hand[index]
		var tile_id := int(tile.get("id", -1))
		var position := _hand_position(seat, index, count, step)
		if lay_down_hand:
			position.y = 0.09
		var selected := seat == 0 and tile_id == selected_id
		if selected:
			position.y += 0.11
		var hand_basis := _flat_basis_for_seat(seat) if lay_down_hand else _standing_basis_for_seat(seat)
		var key := "hand_%d_%d" % [seat, tile_id if tile_id >= 0 else index]
		desired[key] = _entry(
			tile,
			(show_face or lay_down_hand) and not conceal_self_draw_result,
			Transform3D(hand_basis, position),
			selected,
			seat == 0 and (
				tile_id == new_draw_id
				or (self_draw_win and tile_id == winning_tile_id)
			),
			seat == 0 and tile_id == recommended_id,
			seat == 0 and danger_ids.has(tile_id),
			false,
			seat == 0 and not has_won,
			Vector3.ONE * scale_value,
			-1,
			seat,
			180.0 if seat != 0 else 0.0,
			seat == 0,
			conceal_self_draw_result or (seat == 2 and not show_face),
			conceal_self_draw_result
		)
		if seat == 0 and not has_won:
			self_hand_keys.append(key)
	if discard_win:
		var source_seat := winning_source_seat
		var winning_position := _hand_position(seat, count, count + 1, step)
		# The winning tile is a separate result token, not another compressed hand
		# tile. Point-winning AI racks need a larger break because the upright hand
		# projects farther along the rail than a flat tile; human laid-down results
		# retain the tighter established spacing.
		if count > 0:
			var edge_break := (2.60 if seat in [1, 3] else 1.75) if ai_discard_win else 0.85
			match seat:
				0:
					winning_position.x += step * edge_break
				1:
					winning_position.z -= step * edge_break
				2:
					winning_position.x -= step * edge_break
				3:
					winning_position.z += step * edge_break
		winning_position.y = 0.09
		var winning_key := "winning_%d_%d" % [seat, winning_tile_id]
		desired[winning_key] = _entry(
			winning_tile,
			true,
			Transform3D(_flat_basis_for_seat(seat), winning_position),
			false,
			false,
			false,
			false,
			false,
			false,
			Vector3.ONE * scale_value,
			source_seat if source_seat != seat else -1,
			seat
		)


func _append_meld_entries(desired: Dictionary, seat: int, melds: Array) -> void:
	var flat_index := 0
	for meld_index in range(melds.size()):
		var meld: Dictionary = melds[meld_index]
		var meld_tiles: Array = meld.get("tiles", [])
		var source_seat := int(meld.get("from_seat", seat))
		# 碰的中间张、杠的第二张固定承载来源箭头。来源座位仍由 from_seat
		# 决定箭头方向和文字，不再因为来源方向把箭头挪到牌组两端。
		var claim_index := mini(1, meld_tiles.size() - 1)
		var meld_type := str(meld.get("type", ""))
		for tile_index in range(meld_tiles.size()):
			var tile_value = meld_tiles[tile_index]
			var tile: Dictionary = tile_value
			var tile_id := int(tile.get("id", flat_index))
			var position := _meld_position(seat, tile_index, meld_index, flat_index)
			var key := "meld_%d_%d_%d" % [seat, meld_index, tile_id]
			var show_face := not _is_concealed_gang(meld)
			var is_claim_tile := show_face and source_seat != seat and tile_index == claim_index
			desired[key] = _entry(
				tile,
				show_face,
				Transform3D(_flat_basis_for_seat(seat), position),
				false,
				false,
				false,
				false,
				false,
				false,
				Vector3.ONE * MELD_SCALE,
				-1,
				seat,
				180.0 if seat != 0 else 0.0,
				false,
				not show_face,
				false,
				source_seat if is_claim_tile else -1,
				seat,
				meld_type if is_claim_tile else ""
			)
			flat_index += 1


func _claim_tile_index_for_meld(tile_count: int, owner_seat: int, source_seat: int) -> int:
	if tile_count <= 0:
		return 0
	if source_seat == owner_seat:
		return tile_count - 1
	# 沿用旧 2D 牌组的来源牌落位习惯：横向座位按上/下家分左右，
	# 纵向座位按对/本家分两端；对面来源落在组中，箭头再给出精确方向。
	if owner_seat in [0, 2]:
		if source_seat == 1:
			return 0
		if source_seat == 3:
			return tile_count - 1
	else:
		if source_seat == 2:
			return 0
		if source_seat == 0:
			return tile_count - 1
	return mini(1, tile_count - 1)


func _append_discard_entries(desired: Dictionary, seat: int, discards: Array, latest_id: int) -> void:
	var visible_discards: Array = discards.slice(maxi(0, discards.size() - MAX_VISIBLE_DISCARDS), discards.size())
	for index in range(visible_discards.size()):
		var tile: Dictionary = visible_discards[index]
		var tile_id := int(tile.get("id", index))
		var position := _discard_position(seat, index)
		var key := "discard_%d_%d" % [seat, tile_id]
		desired[key] = _entry(tile, true, Transform3D(_flat_basis_for_seat(seat), position), false, false, false, false, tile_id == latest_id, false, Vector3.ONE * DISCARD_SCALE, -1, seat)


func _apply_entries(desired: Dictionary) -> void:
	for existing_key in tile_nodes.keys():
		if desired.has(existing_key):
			continue
		var obsolete := tile_nodes[existing_key] as Node3D
		if obsolete != null:
			obsolete.queue_free()
		tile_nodes.erase(existing_key)

	for key in desired.keys():
		var data: Dictionary = desired[key]
		var tile := tile_nodes.get(key) as SichuanTile3D
		var is_new := tile == null
		if is_new:
			tile = TILE_SCRIPT.new() as SichuanTile3D
			tile.name = _safe_node_name(str(key))
			tile_root.add_child(tile)
			tile_nodes[key] = tile
		tile.set_reduced_motion(reduced_motion)
		# Snapshot state is dynamic even when the tile id is stable. Reconfigure
		# every frame so reveal, win, selection and latest-discard state cannot
		# get stuck on the value from the node's creation frame.
		tile.configure(
			data.get("tile", {}),
			bool(data.get("show_face", false)),
			bool(data.get("selected", false)),
			bool(data.get("new_draw", false)),
			bool(data.get("recommended", false)),
			bool(data.get("danger", false)),
			bool(data.get("latest", false)),
			bool(data.get("pickable", false)),
			int(data.get("winning_source_seat", -1)),
			int(data.get("winner_seat", -1)),
			float(data.get("face_rotation_degrees", 0.0)),
			bool(data.get("bright_front", false)),
			bool(data.get("concealed_surface_flip", false)),
			bool(data.get("flat_concealed_result", false)),
			int(data.get("meld_source_seat", -1)),
			int(data.get("meld_owner_seat", -1)),
			str(data.get("meld_source_type", ""))
		)
		var target_transform: Transform3D = data.get("transform", Transform3D.IDENTITY)
		var target_scale: Vector3 = data.get("scale", Vector3.ONE)
		if is_new and not reduced_motion:
			tile.transform = target_transform.translated_local(Vector3(0.0, 0.42, 0.0))
			tile.scale = target_scale * 0.82
			var enter_tween := tile.create_tween().set_parallel(true)
			enter_tween.tween_property(tile, "transform", target_transform, TWEEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			enter_tween.tween_property(tile, "scale", target_scale, TWEEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not reduced_motion and tile.transform != target_transform:
			var move_tween := tile.create_tween().set_parallel(true)
			move_tween.tween_property(tile, "transform", target_transform, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			move_tween.tween_property(tile, "scale", target_scale, 0.14)
		else:
			tile.transform = target_transform
			tile.scale = target_scale


func _entry(
	tile: Dictionary,
	show_face: bool,
	transform: Transform3D,
	selected: bool,
	new_draw: bool,
	recommended: bool,
	danger: bool,
	latest: bool,
	pickable: bool,
	scale_value: Vector3,
	winning_source_seat: int,
	winner_seat: int,
	face_rotation_degrees: float = 0.0,
	bright_front: bool = false,
	concealed_surface_flip: bool = false,
	flat_concealed_result: bool = false,
	meld_source_seat: int = -1,
	meld_owner_seat: int = -1,
	meld_source_type: String = ""
) -> Dictionary:
	return {
		"tile": tile,
		"show_face": show_face,
		"transform": transform,
		"selected": selected,
		"new_draw": new_draw,
		"recommended": recommended,
		"danger": danger,
		"latest": latest,
		"pickable": pickable,
		"scale": scale_value,
		"winning_source_seat": winning_source_seat,
		"winner_seat": winner_seat,
		"face_rotation_degrees": face_rotation_degrees,
		"bright_front": bright_front,
		"concealed_surface_flip": concealed_surface_flip,
		"flat_concealed_result": flat_concealed_result,
		"meld_source_seat": meld_source_seat,
		"meld_owner_seat": meld_owner_seat,
		"meld_source_type": meld_source_type,
	}


func _hand_position(seat: int, index: int, count: int, step: float) -> Vector3:
	var centered := (float(index) - float(count - 1) * 0.5) * step
	match seat:
		0:
			return Vector3(centered + _self_hand_center_x(), 0.25, _self_hand_depth())
		1:
			# 左家沿导轨排成世界空间直线：X 固定，仅 Z 随牌位变化。之前的
			# `- centered * 0.044` 横向斜移让每张牌左右错开，在透视下呈锯齿边；
			# 去掉后牌列边缘整齐连续，贴合目标图的一条直墙观感。
			return Vector3(-5.92, 0.36, -centered - 1.22)
		2:
			# 目标图的对家牌墙略偏左，右侧为其碰杠留出一段清楚的横向副露带。
			return Vector3(-centered - 1.40, 0.36, -6.00)
		3:
			# 右家镜像左家：同样保持 X 固定消除锯齿。
			return Vector3(5.92, 0.36, centered - 1.22)
	return Vector3.ZERO


func _self_hand_depth() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
	# KEEP_WIDTH magnifies vertical composition on ultra-wide phones. Pull the
	# local rack slightly toward the table centre so its resin base remains fully
	# inside the bottom safe edge instead of losing 0.5%–1.8% of the tile.
	return 3.35 if aspect >= 2.0 else 3.57


func _hand_step_for_seat(seat: int) -> float:
	if seat == 0:
		# 1.94 倍牌宽约 0.815；0.80 只保留约 1.8% 的轻微搭接，让圆角分界仍
		# 清楚可见，同时把 14 张满手稳定在目标图 74%–80% 画宽和手机可读高度。
		return HAND_STEP_SELF
	if seat == 2:
		return HAND_STEP_FAR
	return HAND_STEP_SIDE


func _hand_scale_for_seat(seat: int) -> float:
	if seat == 0:
		return SELF_HAND_SCALE
	if seat == 2:
		return FAR_HAND_SCALE
	return SIDE_HAND_SCALE


func _self_hand_center_x() -> float:
	# The reference layout reserves the lower-left rail for exposed sets and lets
	# the remaining concealed hand slide right as more sets are formed. The cap
	# keeps short end-game hands away from the action buttons and right safe edge.
	return clampf(0.25 + float(self_meld_tile_count) * 0.38, 0.25, 3.10)


func _meld_position(seat: int, _tile_index: int, meld_index: int, flat_index: int) -> Vector3:
	# Exposed sets use a slightly tighter physical pitch than river tiles. This
	# mirrors the commercial target's compact lower-left set rail and keeps four
	# complete groups inside the left 27% without touching the concealed rack.
	match seat:
		0:
			var self_offset := float(flat_index) * 0.40 + float(meld_index) * 0.04
			return Vector3(-5.95 + self_offset, 0.09, 3.20)
		1:
			# 侧家所有碰杠沿同一条手牌方向的副露导轨连续摆放；组间加 0.10 缝。
			# 这样第二至第四组不会横向侵入对家副露带，座位归属始终清楚。
			return Vector3(-4.85, 0.09, -5.25 + float(flat_index) * 0.50 + float(meld_index) * 0.10)
		2:
			var far_offset := float(flat_index) * 0.46 + float(meld_index) * 0.08
			# 对家副露上移到对家手牌带下方，并收进中上部。旧锚点从 X=5.45
			# 开始，会与下家 X=4.85 的竖向碰杠列真实相交，视觉上像一组错误的横杠。
			return Vector3(3.90 - far_offset, 0.09, -5.45)
		3:
			# 下家碰/杠与下家手牌共用右侧竖向轨道；多组继续沿 Z 方向排列，
			# 不向对家区域横向展开。
			return Vector3(4.85, 0.09, -5.25 + float(flat_index) * 0.50 + float(meld_index) * 0.10)
	return Vector3.ZERO


func _discard_position(seat: int, index: int) -> Vector3:
	var column := index % 6
	var row := index / 6
	var x := (float(column) - 2.5) * DISCARD_COLUMN_STEP
	# 缩放后平放牌长约 0.58*1.16=0.673。旧行距 0.50 必然让第一/二行几何相交。
	# 0.78 留出约 0.107 的真实桌布缝隙，并覆盖侧家第三行的透视压缩，同时仍容纳 18 张三行弃牌。
	var z := float(row) * DISCARD_ROW_STEP
	var position := Vector3.ZERO
	match seat:
		0:
			position = Vector3(x, 0.09, 1.52 + z)
		1:
			position = Vector3(-2.55 - z, 0.09, -x)
		2:
			position = Vector3(-x, 0.09, -1.52 - z)
		3:
			position = Vector3(2.55 + z, 0.09, x)
	# A common negative-Z translation is a common upward screen translation for
	# all four seats under the accepted perspective camera. Keeping it outside
	# the seat-specific formulas prevents the four discard zones from drifting
	# apart while matching the commercial reference's higher play cluster.
	position.z += DISCARD_GLOBAL_Z_SHIFT
	return position


func _flat_basis_for_seat(seat: int) -> Basis:
	# Seat zero faces the local viewer. The previous PI rotation inverted the
	# human hand and discard glyphs on iPhone.
	var rotation: float = float([0.0, -PI * 0.5, PI, PI * 0.5][clampi(seat, 0, 3)])
	return Basis(Vector3.UP, rotation)


func _standing_basis_for_seat(seat: int) -> Basis:
	# 本家保留便于读牌的 48° 牌架角；三家 AI 暗手严格 90° 正放在桌面上。
	var yaw: float = float([0.0, -PI * 0.5, PI, PI * 0.5][clampi(seat, 0, 3)])
	var rack_tilt_degrees := SELF_RACK_TILT_DEGREES
	if seat in [1, 3]:
		rack_tilt_degrees = SIDE_RACK_TILT_DEGREES
	elif seat == 2:
		rack_tilt_degrees = FAR_RACK_TILT_DEGREES
	var rack_tilt := deg_to_rad(rack_tilt_degrees)
	# 90° 时本地牌高轴与世界 Y 轴重合，不存在朝桌心或朝外的水平分量。
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rack_tilt)


func _is_concealed_gang(meld: Dictionary) -> bool:
	return str(meld.get("type", "")) == "gang" and str(meld.get("gang_subtype", "")) == "an_gang"


func _meld_tile_count(melds: Array) -> int:
	var count := 0
	for meld_value in melds:
		count += Array((meld_value as Dictionary).get("tiles", [])).size()
	return count


func _sort_human_hand_for_display(hand: Array, ding_que_suit: String) -> Array:
	var result := hand.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_is_ding_que := ding_que_suit != "" and str(a.get("suit", "")) == ding_que_suit
		var b_is_ding_que := ding_que_suit != "" and str(b.get("suit", "")) == ding_que_suit
		if a_is_ding_que != b_is_ding_que:
			return not a_is_ding_que
		var suit_order := {"tiao": 0, "tong": 1, "wan": 2}
		var a_suit := int(suit_order.get(str(a.get("suit", "")), 99))
		var b_suit := int(suit_order.get(str(b.get("suit", "")), 99))
		if a_suit != b_suit:
			return a_suit < b_suit
		var a_rank := int(a.get("rank", 0))
		var b_rank := int(b.get("rank", 0))
		if a_rank != b_rank:
			return a_rank < b_rank
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	return result


func _build_contract(snapshot: Dictionary, all_hands: Array, players: Array, desired: Dictionary) -> Dictionary:
	var hand_counts: Array[int] = []
	var discard_counts: Array[int] = []
	var meld_tile_counts: Array[int] = []
	for seat in range(4):
		hand_counts.append(all_hands[seat].size() if seat < all_hands.size() else 0)
		var player := _player_by_seat(players, seat)
		discard_counts.append(mini(MAX_VISIBLE_DISCARDS, Array(player.get("discards", [])).size()))
		var meld_tile_count := 0
		for meld in player.get("melds", []):
			meld_tile_count += Array(meld.get("tiles", [])).size()
		meld_tile_counts.append(meld_tile_count)
	return {
		"mode": "hybrid_3d_world_2d_hud",
		"camera_profile": CAMERA_PROFILE,
		"camera_projection": "perspective_3d",
		"camera_aspect_policy": "keep_width",
		"camera_fov": camera.fov,
		"camera_position": CAMERA_POSITION,
		"camera_target": CAMERA_TARGET,
		"center_indicator_world_z": CENTER_INDICATOR_WORLD_Z,
		"discard_global_z_shift": DISCARD_GLOBAL_Z_SHIFT,
		"discard_row_step": DISCARD_ROW_STEP,
		"wall_count": int(snapshot.get("wall_count", 0)),
		"rendered_wall_tile_count": 0,
		"wall_representation": "numeric_counter_only",
		"hand_counts": hand_counts,
		"discard_counts": discard_counts,
		"meld_tile_counts": meld_tile_counts,
		"rendered_tile_nodes": desired.size(),
		"self_pickable_count": self_hand_keys.size(),
		"self_hand_scale": SELF_HAND_SCALE,
		"opponent_hand_scale": SIDE_HAND_SCALE,
		"far_hand_scale": FAR_HAND_SCALE,
		"self_hand_pose": "standing_concealed",
		"opponent_hand_pose": "standing_concealed",
		"opponent_hand_face_rotation_degrees": 180.0,
		"opponent_rack_tilt_degrees": absf(SIDE_RACK_TILT_DEGREES),
		"far_rack_tilt_degrees": absf(FAR_RACK_TILT_DEGREES),
		"opponent_concealed_surface": "jade_back_with_ivory_rim",
		"opponent_concealed_owner_surface": "warm_ivory_front",
		"side_concealed_top_tilt": "perpendicular_to_table",
		"self_hand_lighting": "unshaded_discard_white_face",
		"won_hand_pose": "human_self_draw_revealed_ai_self_draw_concealed",
		"self_draw_hand_pose": "human_face_up_with_draw_marker_ai_flat_concealed_back",
		"opponent_reveal_pose": "three_flat_face_up_hands",
		"opponent_back_material": "shared_shaded_jade",
		"discard_win_hand_pose": "flat_revealed_for_human",
		"ai_discard_win_presentation": "standing_hand_plus_adjacent_winning_tile",
		"self_meld_zone": "left_of_concealed_hand",
		"self_meld_tile_count": self_meld_tile_count,
		"self_hand_center_x": _self_hand_center_x(),
		"human_ding_que_sort": "rightmost_then_rank_then_tile_id",
		"new_draw_feedback": "rotating_gold_cone_only",
		"selected_tile_feedback": "floating_warm_jade_hand_only",
		"latest_discard_feedback": "rotating_green_diamond_directly_above_tile",
		"side_meld_layout": "single_side_rail_with_group_gaps",
		"right_meld_axis": "same_yaw_and_z_flow_as_right_hand",
		"far_meld_zone": "below_far_hand_not_right_player_band",
		"winning_source_markers": true,
		"meld_source_feedback": "compact_blue_second_tile_arrow_and_seat_label",
		"season_theme": "reference_blue_mobile",
		"light_count": 2,
		"shadow_casting_light_count": 1,
		"physics_tiles": 0,
		"tripo_calls": 0,
	}


func _player_by_seat(players: Array, seat: int) -> Dictionary:
	for player_value in players:
		var player: Dictionary = player_value
		if int(player.get("seat", -1)) == seat:
			return player
	return {}


func _safe_node_name(value: String) -> String:
	return value.replace("/", "_").replace(":", "_").replace(".", "_")
