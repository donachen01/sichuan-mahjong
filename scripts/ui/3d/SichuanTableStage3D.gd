class_name SichuanTableStage3D
extends Node3D

signal tile_pressed(tile_id: int)

const TILE_SCRIPT := preload("res://scripts/ui/3d/SichuanTile3D.gd")
const TABLE_SCENE := preload("res://res/art/3d/sichuan_table_v2.glb")
const CENTER_COMPASS_SCENE := preload("res://res/art/3d/sichuan_center_compass_v2.glb")
const FALLBACK_TABLE_SCENE := preload("res://res/art/3d/sichuan_table.glb")

const HAND_STEP_SELF := 0.80
# 侧家(上/下家)牌沿桌边码放的步距。0.45 太密，牌挤成一条分不清；
# 加大到 0.62 让每张牌之间留出清晰分界，贴合目标图一张一张的层次感。
const HAND_STEP_SIDE := 0.62
const HAND_STEP_FAR := 0.55
const SELF_HAND_SCALE := 1.94
const SIDE_HAND_SCALE := 1.44
const FAR_HAND_SCALE := 1.28
# Standing and flat result tiles use one shared GLB and one uniform runtime
# scale. A rotation changes pose only; it must not compress a winning hand.
const SELF_FLAT_VISUAL_SCALE_FACTOR := 1.0
const SELF_LAYOUT_MAX_TILES := 18
const SELF_LAYOUT_LEFT_X := -5.95
const SELF_LAYOUT_RIGHT_X := 6.15
const SELF_LAYOUT_CENTER_X := 0.10
const SELF_TILE_PITCH_PER_SCALE := HAND_STEP_SELF / SELF_HAND_SCALE
const SELF_MELD_GROUP_GAP_PER_SCALE := 0.12
const SELF_MELD_HAND_GAP_PER_SCALE := 0.10
const SELF_LAYOUT_MIN_SCALE := 1.42
const SIDE_WIN_RESULT_UPSHIFT_Z := 0.72
const SIDE_WINNING_TILE_MAX_LOCAL_Z := 1.65
const MELD_SCALE := 1.12
const DISCARD_SCALE := 1.16
const DISCARD_COLUMN_STEP := 0.56
const DISCARD_ROW_STEP := 0.78
const MAX_VISIBLE_DISCARDS := 18
const TWEEN_SECONDS := 0.18
const PENG_MOTION_SECONDS := 0.22
const GANG_MOTION_SECONDS := 0.26
const WIN_TRANSFER_SECONDS := 0.24
const DRAW_TRAVEL_SECONDS := 0.20
const DRAW_SETTLE_SECONDS := 0.05
const DISCARD_TRAVEL_SECONDS := 0.20
const DISCARD_SETTLE_SECONDS := 0.04
const DISCARD_REFLOW_BEAT_SECONDS := 0.06
# 翻扣只旋转同一块实体牌，不改变缩放。由于 GLB 原点位于背层底面，翻转后
# 必须抬高完整的 0.24 牌厚，才能让底面仍落在原桌面高度。
const CONCEALED_BACK_FLIP_Y_OFFSET := 0.24
const SELF_RACK_TILT_DEGREES := 48.0
# 对家、上家和下家的暗手按用户验收要求严格垂直于桌面，不再向桌心内倾。
# 正负号只决定哪一实体表面朝向牌主；绝对值都必须保持 90°。
const SIDE_RACK_TILT_DEGREES := 90.0
const FAR_RACK_TILT_DEGREES := 90.0
const CENTER_INDICATOR_WORLD_Z := -1.60
const DISCARD_GLOBAL_Z_SHIFT := -1.60
const WALL_COUNT_SURFACE_HEIGHT := 0.64
const CENTER_WALL_SURFACE_RADIUS := 0.72
const CENTER_WALL_SURFACE_HEIGHT := 0.12
const CENTER_WALL_INSET_RADIUS := 0.63
const CENTER_WALL_INSET_HEIGHT := 0.035
const DRAW_MARKER_STYLE_NAMES := ["小号蓝色立体菱形"]
const SELECTED_MARKER_STYLE_NAMES := ["无选中图案"]

@export_enum("小号蓝色立体菱形")
var draw_marker_style_variant := 0

@export_enum("无选中图案")
var selected_marker_style_variant := 0

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
var center_compass_model: Node3D
var center_wall_count_anchor: Node3D
var center_wall_count_label: Label3D
var center_wall_count_surface: MeshInstance3D
var center_wall_count_inset: MeshInstance3D
var center_wall_count_visible := true
var tile_nodes: Dictionary = {}
var self_hand_keys: Array[String] = []
var last_contract: Dictionary = {}
var reduced_motion := false
var interaction_enabled := false
var self_meld_tile_count := 0
var self_meld_group_count := 0
var self_layout_hand_count := 0
var self_layout_scale := SELF_HAND_SCALE
var self_layout_pitch := HAND_STEP_SELF
var self_layout_start_x := 0.0
var self_layout_span := 0.0
var self_layout_is_flat := false
var meld_tile_counts_by_seat: Array[int] = [0, 0, 0, 0]
var discard_slots_by_seat: Array[Dictionary] = [{}, {}, {}, {}]
var active_motion_tweens: Array[Tween] = []
var last_desired_entries: Dictionary = {}


func _ready() -> void:
	_setup_world()
	_setup_table()
	_setup_center_compass()
	_setup_center_wall_count()
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
	_set_center_wall_count(int(snapshot.get("wall_count", 0)))
	var latest_discard_id := int(snapshot.get("recent_discard_tile_id", -1))
	var new_draw_id := int(snapshot.get("human_last_draw_tile_id", -1))
	var recommended_id := int(markers.get("recommended_tile_id", -1))
	var danger_ids: Array = markers.get("danger_tile_ids", [])
	var self_player := _player_by_seat(players, 0)
	self_meld_tile_count = _meld_tile_count(self_player.get("melds", []))
	_configure_self_row_layout(
		all_hands[0].size() if not all_hands.is_empty() else 0,
		self_player
	)
	for seat in range(4):
		meld_tile_counts_by_seat[seat] = _meld_tile_count(_player_by_seat(players, seat).get("melds", []))

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

	last_desired_entries = desired.duplicate(true)
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
	_stop_and_reset_motion_tweens()
	for tile_value in tile_nodes.values():
		var tile := tile_value as SichuanTile3D
		if tile != null:
			tile.set_reduced_motion(enabled)
	for key in last_desired_entries:
		var tile := tile_nodes.get(key) as SichuanTile3D
		if tile == null:
			continue
		var data: Dictionary = last_desired_entries[key]
		tile.transform = data.get("transform", tile.transform)
		tile.scale = data.get("scale", tile.scale)
		if bool(data.get("latest", false)):
			tile.call("set_latest_marker_visible", true)


func set_center_wall_count_visible(enabled: bool) -> void:
	center_wall_count_visible = enabled
	if center_wall_count_anchor != null:
		center_wall_count_anchor.visible = enabled


func set_draw_marker_style_variant(_value: int) -> void:
	draw_marker_style_variant = 0
	for tile_value in tile_nodes.values():
		var tile := tile_value as SichuanTile3D
		if tile != null:
			tile.set_draw_marker_style_variant(draw_marker_style_variant)


func set_selected_marker_style_variant(_value: int) -> void:
	selected_marker_style_variant = 0
	for tile_value in tile_nodes.values():
		var tile := tile_value as SichuanTile3D
		if tile != null:
			tile.set_selected_marker_style_variant(selected_marker_style_variant)


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
	# Keep ambient fill restrained so the authored #167A64/#0F6957 felt does
	# not wash into cyan under Metal's filmic tonemapper. Mahjong tiles receive
	# their own layer-2 fill below, so reducing table ambient does not cost glyph
	# readability.
	environment.ambient_light_color = Color("8FB3A9")
	environment.ambient_light_energy = 0.18
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
	# A warm-neutral furniture key preserves the reddish walnut grain and keeps
	# the forest-green felt from drifting toward cyan. Tile faces still receive
	# the dedicated layer-2 fill light, so this table calibration does not cost
	# glyph readability.
	key_light.light_color = Color("FFF0E3")
	key_light.light_energy = 0.91
	# DirectionalLight3D shines along local -Z. The -146-degree yaw points the
	# ground component toward the player's right/down screen quadrant, matching
	# the supplied commercial reference instead of the former right/up shadow.
	key_light.rotation_degrees = Vector3(-60.0, -165.0, -8.0)
	key_light.shadow_enabled = true
	# The table occupies a compact plane. Restricting the orthogonal shadow map to
	# the visible play area gives every tile edge more texels, while the mobile
	# project override enables medium soft filtering instead of the jagged hard
	# filter used by Compatibility by default.
	key_light.directional_shadow_max_distance = 22.0
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
	if table == null:
		table = FALLBACK_TABLE_SCENE.instantiate() as Node3D
	if table == null:
		push_error("Deep Emerald table and fallback table both failed to instantiate")
		return
	table.name = "ManufacturedClubTable"
	# Extend only the table depth so the far/opponent rail sits outside the
	# camera crop while the left/right rails still frame the play surface.
	table.scale = Vector3(1.0, 1.0, 1.60)
	table.position.z = -2.30
	add_child(table)
	# The GLB owns the short-nap felt, leather, walnut, seam and aged-copper
	# PBR materials.  Runtime flat-colour overrides are intentionally forbidden:
	# they erase roughness/normal detail and caused the previous plastic table.
	_preserve_imported_pbr_materials(table)


func _setup_center_compass() -> void:
	center_compass_model = CENTER_COMPASS_SCENE.instantiate() as Node3D
	if center_compass_model == null:
		push_error("Deep Emerald center compass failed to instantiate")
		return
	center_compass_model.name = "DeepEmeraldCenterCompass"
	center_compass_model.position = Vector3(0.0, 0.34, CENTER_INDICATOR_WORLD_Z)
	# Keep the direction body deliberately subordinate to the river. At 0.46
	# its visible footprint stays below 55% of the retired central plaque.
	center_compass_model.scale = Vector3.ONE * 0.46
	add_child(center_compass_model)
	_preserve_imported_pbr_materials(center_compass_model)


func _setup_center_wall_count() -> void:
	# The compass and remaining-wall value form one diegetic counter. The
	# shallow octagonal surface sits on the physical compass face and the number
	# is its face marking, rather than a separate floating status label.
	center_wall_count_anchor = Node3D.new()
	center_wall_count_anchor.name = "CenterWallCount3DAnchor"
	center_wall_count_anchor.position = Vector3(0.0, WALL_COUNT_SURFACE_HEIGHT, CENTER_INDICATOR_WORLD_Z)
	center_wall_count_anchor.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(center_wall_count_anchor)

	center_wall_count_surface = _make_center_counter_mesh(
		"CenterWallCount3DUnifiedSurface",
		CENTER_WALL_SURFACE_RADIUS,
		CENTER_WALL_SURFACE_HEIGHT,
		Color("B8863B"),
		-0.055
	)
	center_wall_count_anchor.add_child(center_wall_count_surface)
	center_wall_count_inset = _make_center_counter_mesh(
		"CenterWallCount3DUnifiedInset",
		CENTER_WALL_INSET_RADIUS,
		CENTER_WALL_INSET_HEIGHT,
		Color("184A3A"),
		0.018
	)
	center_wall_count_anchor.add_child(center_wall_count_inset)

	center_wall_count_label = Label3D.new()
	center_wall_count_label.name = "CenterWallCount3DText"
	center_wall_count_label.text = "55"
	center_wall_count_label.font_size = 96
	center_wall_count_label.pixel_size = 0.0062
	center_wall_count_label.modulate = Color("F6F5E9")
	center_wall_count_label.outline_modulate = Color("123D30")
	center_wall_count_label.outline_size = 12
	center_wall_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_wall_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_wall_count_label.no_depth_test = false
	# The inset is a physical face layer; lift the glyph a few millimetres above
	# it so the count is readable without becoming a floating HUD element.
	center_wall_count_label.position = Vector3(0.0, 0.0, 0.045)
	center_wall_count_anchor.add_child(center_wall_count_label)


func _make_center_counter_mesh(
	node_name: String,
	radius: float,
	height: float,
	color: Color,
	local_z_offset: float
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.035
	mesh.height = height
	mesh.radial_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.28 if color == Color("B8863B") else 0.05
	material.roughness = 0.38 if color == Color("B8863B") else 0.46
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	# The parent anchor remains flat for the text contract. Rotate the mesh back
	# so the cylinder's Y axis stays the physical tabletop normal.
	instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.position = Vector3(0.0, 0.0, local_z_offset)
	return instance


func _set_center_wall_count(wall_count: int) -> void:
	var display_text := str(maxi(0, wall_count))
	if center_wall_count_label != null:
		center_wall_count_label.text = display_text


func _preserve_imported_pbr_materials(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = null
	for child in node.get_children():
		_preserve_imported_pbr_materials(child)


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
	# AI 自摸和点炮胡后的保留手牌都整手扣在桌面，统一展示图 1 的明亮牌背；
	# 只有点炮胡会在整手旁附加一张外来明牌。
	var self_draw_win := has_won and not winning_tile.is_empty() and winning_source_seat == seat
	var discard_win := has_won and not winning_tile.is_empty() and winning_source_seat != seat
	var ai_discard_win := seat != 0 and has_won and not winning_tile.is_empty() and winning_source_seat != seat
	# 三家明牌时统一平放正面，避免严格 90° 的侧家牌面与相机视线近乎平行，
	# 看起来仍像牌背。胡牌展示与主动明牌共用真实 3D 牌，不引入额外 HUD 贴图。
	var reveal_opponent_hand := show_face and seat != 0 and not has_won
	var conceal_ai_win_result := has_won and not winning_tile.is_empty() and seat != 0
	var lay_down_hand := has_won or reveal_opponent_hand
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
		# 侧家点炮胡的平扣结果继续沿用既有安全位移，给本家手牌与附加胡牌留出
		# 保护带；这只是整条结果的平移，不改变牌距或桌面布局合同。
		if ai_discard_win and seat in [1, 3]:
			position.z -= SIDE_WIN_RESULT_UPSHIFT_Z
		if lay_down_hand:
			position.y = 0.09
		if conceal_ai_win_result:
			# 牌体 GLB 的原点位于背层底面。绕本地 X 轴物理翻扣后，必须抬高
			# 一整块牌的 0.24 高度，才能让实体翡翠层落在桌面上而不是沉入桌布。
			position.y += CONCEALED_BACK_FLIP_Y_OFFSET
		var selected := seat == 0 and tile_id == selected_id
		if selected:
			position.y += 0.11
		var hand_basis := (
			_concealed_back_up_basis_for_seat(seat)
			if conceal_ai_win_result
			else (_flat_basis_for_seat(seat) if lay_down_hand else _standing_basis_for_seat(seat))
		)
		var key := "hand_%d_%d" % [seat, tile_id if tile_id >= 0 else index]
		desired[key] = _entry(
			tile,
			(show_face or lay_down_hand) and not conceal_ai_win_result,
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
			false,
			conceal_ai_win_result
		)
		if seat == 0 and not has_won:
			self_hand_keys.append(key)
	if discard_win:
		var source_seat := winning_source_seat
		var winning_position := _hand_position(seat, count, count + 1, step)
		# 下家的 +Z 端紧邻本家安全区。点炮胡时把外来胡牌放到其牌列的 -Z 端，
		# 与上家使用同一远离本家的安全侧，避免平扣整手后被 1.65 保护线压回牌列。
		if ai_discard_win and seat == 3:
			winning_position = _hand_position(seat, -1, count + 1, step)
		if ai_discard_win and seat in [1, 3]:
			winning_position.z -= SIDE_WIN_RESULT_UPSHIFT_Z
		# The winning tile is a separate result token, not another compressed hand
		# tile. Both human and AI point-win results are now flat, so they share the
		# tighter established spacing while keeping one visible separation gap.
		if count > 0:
			var edge_break := 0.85
			match seat:
				0:
					winning_position.x += step * edge_break
				1:
					winning_position.z -= step * edge_break
				2:
					winning_position.x -= step * edge_break
				3:
					winning_position.z += step * (-edge_break if ai_discard_win else edge_break)
		# 下家原先沿 +Z 继续外摆，会侵入本家手牌。上下两家都受同一世界坐标
		# 保护线约束，保持结果牌邻近自己的牌轨但绝不进入本家手牌区。
		if ai_discard_win and seat in [1, 3]:
			winning_position.z = minf(winning_position.z, SIDE_WINNING_TILE_MAX_LOCAL_Z)
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
		desired[winning_key]["motion_kind"] = "win_transfer"
		desired[winning_key]["motion_role"] = "source_tile_to_winner"
		desired[winning_key]["motion_source_seat"] = source_seat
		desired[winning_key]["motion_duration_seconds"] = WIN_TRANSFER_SECONDS


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
		var gang_subtype := str(meld.get("gang_subtype", meld.get("gang_type", "melded_gang")))
		for tile_index in range(meld_tiles.size()):
			var tile_value = meld_tiles[tile_index]
			var tile: Dictionary = tile_value
			var tile_id := int(tile.get("id", flat_index))
			var concealed_gang := _is_concealed_gang(meld)
			var position := _meld_position(seat, tile_index, meld_index, flat_index, concealed_gang)
			var key := "meld_%d_%d_%d" % [seat, meld_index, tile_id]
			# 本轮暗杠视觉合同：两边明示、中间两张扣背。暗杠没有来源牌，
			# 因此外侧正面也不会错误出现碰/杠来源箭头。
			var show_face := not concealed_gang or tile_index == 0 or tile_index == meld_tiles.size() - 1
			var is_claim_tile := not concealed_gang and source_seat != seat and tile_index == claim_index
			if not show_face:
				position.y += CONCEALED_BACK_FLIP_Y_OFFSET
			var meld_basis := (
				_flat_basis_for_seat(seat)
				if show_face
				else _concealed_back_up_basis_for_seat(seat)
			)
			desired[key] = _entry(
				tile,
				show_face,
				Transform3D(meld_basis, position),
				false,
				false,
				false,
				false,
				false,
				false,
				Vector3.ONE * (self_layout_scale if seat == 0 else MELD_SCALE),
				-1,
				seat,
				180.0 if seat != 0 else 0.0,
				false,
				false,
				concealed_gang and not show_face,
				source_seat if is_claim_tile else -1,
				seat,
				meld_type if is_claim_tile else ""
			)
			var motion_kind := "peng" if meld_type == "peng" else "gang"
			desired[key]["motion_kind"] = motion_kind
			desired[key]["gang_subtype"] = gang_subtype if motion_kind == "gang" else ""
			desired[key]["motion_duration_seconds"] = PENG_MOTION_SECONDS if motion_kind == "peng" else GANG_MOTION_SECONDS
			if is_claim_tile:
				desired[key]["motion_role"] = "source_discard_to_meld"
				desired[key]["motion_source_seat"] = source_seat
			elif motion_kind == "gang" and gang_subtype == "add_gang" and tile_index == meld_tiles.size() - 1:
				desired[key]["motion_role"] = "fourth_tile_hand_to_existing_peng"
				desired[key]["motion_source_seat"] = seat
			elif motion_kind == "gang" and gang_subtype == "an_gang":
				desired[key]["motion_role"] = "concealed_gang_outer_faces_middle_backs"
			else:
				desired[key]["motion_role"] = "group_formation"
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
	var slots := discard_slots_by_seat[clampi(seat, 0, 3)]
	var visible_ids: Dictionary = {}
	for index in range(visible_discards.size()):
		visible_ids[int((visible_discards[index] as Dictionary).get("id", index))] = true
	for tracked_id in slots.keys():
		if not visible_ids.has(tracked_id):
			slots.erase(tracked_id)
	var used_slots: Dictionary = {}
	for tracked_slot in slots.values():
		used_slots[int(tracked_slot)] = true
	for index in range(visible_discards.size()):
		var tile: Dictionary = visible_discards[index]
		var tile_id := int(tile.get("id", index))
		if not slots.has(tile_id):
			var free_slot := 0
			while free_slot < MAX_VISIBLE_DISCARDS and used_slots.has(free_slot):
				free_slot += 1
			# visible_discards is capped at MAX_VISIBLE_DISCARDS, so a slot is
			# always available after absent ids are pruned. Keep this fallback
			# deterministic if malformed duplicate ids ever violate that contract.
			free_slot = mini(free_slot, MAX_VISIBLE_DISCARDS - 1)
			slots[tile_id] = free_slot
			used_slots[free_slot] = true
		var position := _discard_position(seat, int(slots[tile_id]))
		var key := "discard_%d_%d" % [seat, tile_id]
		desired[key] = _entry(tile, true, Transform3D(_flat_basis_for_seat(seat), position), false, false, false, false, tile_id == latest_id, false, Vector3.ONE * DISCARD_SCALE, -1, seat, 0.0, false, false, false, -1, -1, "", true)


func _apply_entries(desired: Dictionary) -> void:
	var discard_landing_delay_by_seat: Dictionary = {}
	for desired_key in desired.keys():
		var desired_data: Dictionary = desired[desired_key]
		if bool(desired_data.get("latest", false)) and not tile_nodes.has(desired_key):
			discard_landing_delay_by_seat[int(desired_data.get("winner_seat", -1))] = \
				DISCARD_TRAVEL_SECONDS + DISCARD_SETTLE_SECONDS + DISCARD_REFLOW_BEAT_SECONDS
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
		tile.draw_marker_style_variant = clampi(draw_marker_style_variant, 0, DRAW_MARKER_STYLE_NAMES.size() - 1)
		tile.selected_marker_style_variant = clampi(selected_marker_style_variant, 0, SELECTED_MARKER_STYLE_NAMES.size() - 1)
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
			str(data.get("meld_source_type", "")),
			bool(data.get("show_flat_back_layer", false))
		)
		var target_transform: Transform3D = data.get("transform", Transform3D.IDENTITY)
		var target_scale: Vector3 = data.get("scale", Vector3.ONE)
		if is_new and not reduced_motion:
			var motion_kind := str(data.get("motion_kind", ""))
			var motion_role := str(data.get("motion_role", ""))
			var motion_duration := float(data.get("motion_duration_seconds", TWEEN_SECONDS))
			tile.transform = _motion_start_transform(target_transform, motion_role, int(data.get("motion_source_seat", -1)))
			if bool(data.get("latest", false)):
				# The latest marker becomes visible only after the tile reaches and
				# settles into its immutable river cell. No layout or camera shake is
				# used; the 2.5% scale overshoot supplies the restrained table contact.
				tile.call("set_latest_marker_visible", false)
				tile.scale = target_scale * 0.86
				var discard_tween := _track_tween(tile.create_tween())
				discard_tween.tween_property(tile, "transform", target_transform, DISCARD_TRAVEL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				discard_tween.parallel().tween_property(tile, "scale", target_scale * 1.025, DISCARD_TRAVEL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				discard_tween.tween_property(tile, "scale", target_scale, DISCARD_SETTLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				discard_tween.tween_callback(Callable(tile, "set_latest_marker_visible").bind(true))
			elif bool(data.get("new_draw", false)):
				# The draw token travels for 200 ms, then settles for 50 ms. Keeping
				# the two phases explicit makes the animation measurable and leaves the
				# accepted 22 px hand gap/physical target transform untouched.
				tile.scale = target_scale * 0.82
				var draw_tween := _track_tween(tile.create_tween())
				draw_tween.tween_property(tile, "transform", target_transform, DRAW_TRAVEL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				draw_tween.parallel().tween_property(tile, "scale", target_scale * 1.025, DRAW_TRAVEL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				draw_tween.tween_property(tile, "scale", target_scale, DRAW_SETTLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			elif motion_kind in ["peng", "gang", "win_transfer"]:
				tile.scale = target_scale * 0.82
				var event_tween := _track_tween(tile.create_tween())
				event_tween.tween_property(tile, "transform", target_transform, motion_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				event_tween.parallel().tween_property(tile, "scale", target_scale, motion_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				tile.scale = target_scale * 0.82
				var enter_tween := _track_tween(tile.create_tween()).set_parallel(true)
				enter_tween.tween_property(tile, "transform", target_transform, TWEEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				enter_tween.tween_property(tile, "scale", target_scale, TWEEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not reduced_motion and tile.transform != target_transform:
			var move_tween := _track_tween(tile.create_tween())
			var hand_seat := -1
			if str(key).begins_with("hand_"):
				hand_seat = int(str(key).split("_")[1])
			var reflow_delay := float(discard_landing_delay_by_seat.get(hand_seat, 0.0))
			if reflow_delay > 0.0:
				move_tween.tween_interval(reflow_delay)
			move_tween.tween_property(tile, "transform", target_transform, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			move_tween.parallel().tween_property(tile, "scale", target_scale, 0.14)
		else:
			tile.transform = target_transform
			tile.scale = target_scale


func get_motion_contract() -> Dictionary:
	return {
		"peng_seconds": PENG_MOTION_SECONDS,
		"gang_seconds": GANG_MOTION_SECONDS,
		"win_transfer_seconds": WIN_TRANSFER_SECONDS,
		"concealed_gang_presentation": "outer_faces_middle_jade_backs",
		"melded_gang_sequence": ["source_discard_to_meld", "four_tiles_land", "callout_then_scores"],
		"add_gang_sequence": ["fourth_tile_hand_to_existing_peng", "callout_then_three_payers_and_actor"],
		"an_gang_sequence": ["outer_faces_middle_jade_backs", "callout_then_three_payers_and_actor"],
		"discard_win_sequence": ["source_tile_to_winner", "callout_then_scores"],
		"screen_shake": false,
		"active_tween_count": _active_motion_tween_count(),
		"reduced_motion": reduced_motion,
	}


func get_motion_entry_contract(key: String) -> Dictionary:
	return (last_desired_entries.get(key, {}) as Dictionary).duplicate(true)


func _motion_start_transform(target: Transform3D, role: String, source_seat: int) -> Transform3D:
	if role == "source_discard_to_meld" or role == "source_tile_to_winner":
		var offset := Vector3.ZERO
		match source_seat:
			0:
				offset = Vector3(0.0, 0.62, 2.45)
			1:
				offset = Vector3(-2.85, 0.62, 0.0)
			2:
				offset = Vector3(0.0, 0.62, -2.45)
			3:
				offset = Vector3(2.85, 0.62, 0.0)
		return Transform3D(target.basis, target.origin + offset)
	if role == "fourth_tile_hand_to_existing_peng":
		return target.translated_local(Vector3(0.0, 0.78, 0.72))
	return target.translated_local(Vector3(0.0, 0.42, 0.0))


func _track_tween(tween: Tween) -> Tween:
	active_motion_tweens.append(tween)
	return tween


func _active_motion_tween_count() -> int:
	var count := 0
	for tween in active_motion_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			count += 1
	return count


func _stop_and_reset_motion_tweens() -> void:
	for tween in active_motion_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	active_motion_tweens.clear()


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
	meld_source_type: String = "",
	show_flat_back_layer: bool = false
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
		"show_flat_back_layer": show_flat_back_layer,
	}


func _hand_position(seat: int, index: int, count: int, step: float) -> Vector3:
	var centered := (float(index) - float(count - 1) * 0.5) * step
	match seat:
		0:
			return Vector3(_self_hand_tile_x(index), 0.25, _self_hand_depth())
		1:
			# 左家沿导轨排成世界空间直线：X 固定，仅 Z 随牌位变化。之前的
			# `- centered * 0.044` 横向斜移让每张牌左右错开，在透视下呈锯齿边；
			# 去掉后牌列边缘整齐连续，贴合目标图的一条直墙观感。
			return Vector3(-5.92, 0.36, -centered - 1.22)
		2:
			# 目标图的对家牌墙略偏左，右侧为其碰杠留出一段清楚的横向副露带。
			# 四组副露时只剩很短的暗手；让短手继续沿对家导轨向左收缩，避免
			# 最后一组副露穿入暗手，同时不改变零/一组副露的常规构图。
			var far_meld_pressure := maxi(0, meld_tile_counts_by_seat[2] - 4)
			var far_hand_center_x := -1.40 - minf(float(far_meld_pressure) * 0.22, 2.0)
			return Vector3(-centered + far_hand_center_x, 0.36, -6.00)
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
		return self_layout_pitch
	if seat == 2:
		return HAND_STEP_FAR
	return HAND_STEP_SIDE


func _hand_scale_for_seat(seat: int) -> float:
	if seat == 0:
		return self_layout_scale
	if seat == 2:
		return FAR_HAND_SCALE
	return SIDE_HAND_SCALE


func _self_hand_center_x() -> float:
	if self_layout_hand_count <= 0:
		return SELF_LAYOUT_CENTER_X
	return (_self_hand_tile_x(0) + _self_hand_tile_x(self_layout_hand_count - 1)) * 0.5


func _configure_self_row_layout(hand_count: int, player: Dictionary) -> void:
	self_layout_hand_count = maxi(0, hand_count)
	var melds: Array = player.get("melds", [])
	self_meld_group_count = melds.size()
	self_layout_is_flat = bool(player.get("has_won", false))
	var base_scale := SELF_HAND_SCALE * (SELF_FLAT_VISUAL_SCALE_FACTOR if self_layout_is_flat else 1.0)
	var total_tile_count := self_layout_hand_count + self_meld_tile_count
	var group_gap_count := maxi(0, self_meld_group_count - 1)
	var has_meld_hand_gap := self_meld_tile_count > 0 and self_layout_hand_count > 0
	var span_per_scale := 0.0
	if total_tile_count > 0:
		span_per_scale = SichuanTile3D.TILE_SIZE.x \
			+ float(maxi(0, total_tile_count - 1)) * SELF_TILE_PITCH_PER_SCALE \
			+ float(group_gap_count) * SELF_MELD_GROUP_GAP_PER_SCALE \
			+ (SELF_MELD_HAND_GAP_PER_SCALE if has_meld_hand_gap else 0.0)
	var available_width := SELF_LAYOUT_RIGHT_X - SELF_LAYOUT_LEFT_X
	self_layout_scale = base_scale
	if span_per_scale > 0.0:
		self_layout_scale = minf(base_scale, available_width / span_per_scale)
	# The rules contract caps the combined physical row at 18 tiles. The lower
	# bound is only a defensive guard for malformed debug snapshots beyond that
	# contract; legal 18-tile rows still fit without crossing it.
	self_layout_scale = maxf(SELF_LAYOUT_MIN_SCALE, self_layout_scale)
	self_layout_pitch = SELF_TILE_PITCH_PER_SCALE * self_layout_scale
	self_layout_span = span_per_scale * self_layout_scale
	var tile_width := SichuanTile3D.TILE_SIZE.x * self_layout_scale
	self_layout_start_x = SELF_LAYOUT_CENTER_X - self_layout_span * 0.5 + tile_width * 0.5


func _self_meld_tile_x(flat_index: int, meld_index: int) -> float:
	return self_layout_start_x \
		+ float(flat_index) * self_layout_pitch \
		+ float(meld_index) * SELF_MELD_GROUP_GAP_PER_SCALE * self_layout_scale


func _self_hand_tile_x(index: int) -> float:
	var x := self_layout_start_x
	if self_meld_tile_count > 0:
		x += float(self_meld_tile_count) * self_layout_pitch
		x += float(maxi(0, self_meld_group_count - 1)) * SELF_MELD_GROUP_GAP_PER_SCALE * self_layout_scale
		if self_layout_hand_count > 0:
			x += SELF_MELD_HAND_GAP_PER_SCALE * self_layout_scale
	return x + float(index) * self_layout_pitch


func _meld_position(seat: int, tile_index: int, meld_index: int, flat_index: int, concealed_gang: bool = false) -> Vector3:
	# Exposed sets use a slightly tighter physical pitch than river tiles. This
	# mirrors the commercial target's compact lower-left set rail and keeps four
	# complete groups inside the left 27% without touching the concealed rack.
	match seat:
		0:
			# 本家副露与剩余手牌共用一条最多 18 张的连续牌轨。牌组间距和
			# 副露/手牌间距都随统一三轴缩放变化，既不会形成截图中的大空洞，
			# 也不会通过压薄牌体来挤进安全区。
			return Vector3(_self_meld_tile_x(flat_index, meld_index), 0.09, _self_hand_depth())
		1:
			# 侧家所有碰杠沿同一条手牌方向的副露导轨连续摆放；组间加 0.10 缝。
			# 这样第二至第四组不会横向侵入对家副露带，座位归属始终清楚。
			var concealed_spacing := float(tile_index) * 0.06 if concealed_gang else 0.0
			return Vector3(-4.85, 0.09, -5.25 + float(flat_index) * 0.50 + float(meld_index) * 0.10 + concealed_spacing)
		2:
			var concealed_spacing := float(tile_index) * 0.06 if concealed_gang else 0.0
			var far_offset := float(flat_index) * 0.46 + float(meld_index) * 0.08 + concealed_spacing
			# 对家副露上移到对家手牌带下方，并收进中上部。旧锚点从 X=5.45
			# 开始，会与下家 X=4.85 的竖向碰杠列真实相交，视觉上像一组错误的横杠。
			return Vector3(3.90 - far_offset, 0.09, -5.45)
		3:
			# 下家碰/杠与下家手牌共用右侧竖向轨道；多组继续沿 Z 方向排列，
			# 不向对家区域横向展开。
			var concealed_spacing := float(tile_index) * 0.06 if concealed_gang else 0.0
			return Vector3(4.85, 0.09, -5.25 + float(flat_index) * 0.50 + float(meld_index) * 0.10 + concealed_spacing)
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
			# Left player faces toward +X. Their personal right is +Z and
			# their down direction is -X, so the upper-left slot is the
			# inner/far corner and subsequent tiles advance toward +Z.
			position = Vector3(-2.55 - z, 0.09, x)
		2:
			position = Vector3(-x, 0.09, -1.52 - z)
		3:
			# Right player faces toward -X. Their personal right is -Z and
			# their down direction is +X, mirroring the left player's rail.
			position = Vector3(2.55 + z, 0.09, -x)
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


func _concealed_back_up_basis_for_seat(seat: int) -> Basis:
	# GLB 的实体 MahjongTileBack 位于本地 -Y 面。暗杠和 AI 自摸的扣牌必须
	# 真正把整块牌翻到背层朝上，不能只给 +Y 覆盖面换一张绿色材质。
	return _flat_basis_for_seat(seat) * Basis(Vector3.RIGHT, PI)


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
		"center_compass_asset": "res://res/art/3d/sichuan_center_compass_v2.glb",
		"center_compass_pbr_preserved": center_compass_model != null,
		"discard_global_z_shift": DISCARD_GLOBAL_Z_SHIFT,
		"discard_row_step": DISCARD_ROW_STEP,
		"wall_count": int(snapshot.get("wall_count", 0)),
		"rendered_wall_tile_count": 0,
		"wall_representation": "static_numeric_count_embedded_on_center_compass",
		"wall_count_surface": "flat_label3d_on_physical_center_compass",
		"center_display_asset": "unified_octagonal_wall_count_tile",
		"center_display_nodes": ["CenterWallCount3DUnifiedSurface", "CenterWallCount3DUnifiedInset", "CenterWallCount3DText"],
		"wall_count_format": "%d",
		"wall_count_motion": "none_static_on_table_surface",
		"wall_count_surface_height": WALL_COUNT_SURFACE_HEIGHT,
		"wall_count_surface_rotation_degrees": -90.0,
		"wall_count_3d_node": center_wall_count_label != null,
		"hand_counts": hand_counts,
		"discard_counts": discard_counts,
		"meld_tile_counts": meld_tile_counts,
		"rendered_tile_nodes": desired.size(),
		"self_pickable_count": self_hand_keys.size(),
		"self_hand_scale": self_layout_scale,
		"opponent_hand_scale": SIDE_HAND_SCALE,
		"far_hand_scale": FAR_HAND_SCALE,
		"meld_scale": MELD_SCALE,
		"self_meld_scale": self_layout_scale,
		"self_flat_visual_scale_factor": SELF_FLAT_VISUAL_SCALE_FACTOR,
		"self_layout_max_tiles": SELF_LAYOUT_MAX_TILES,
		"self_layout_total_tiles": self_layout_hand_count + self_meld_tile_count,
		"self_layout_span": self_layout_span,
		"self_layout_available_width": SELF_LAYOUT_RIGHT_X - SELF_LAYOUT_LEFT_X,
		"self_layout_is_flat": self_layout_is_flat,
		"discard_scale": DISCARD_SCALE,
		"tile_physical_size": SichuanTile3D.TILE_SIZE,
		"tile_pose_geometry": "one_shared_0_42x0_24x0_58_model_uniform_scale_rotation_only",
		"meld_model_geometry": "peng_ming_gang_an_gang_add_gang_share_one_model_uniform_scale_only",
		"self_hand_pose": "standing_concealed",
		"opponent_hand_pose": "standing_concealed",
		"opponent_hand_face_rotation_degrees": 180.0,
		"opponent_rack_tilt_degrees": absf(SIDE_RACK_TILT_DEGREES),
		"far_rack_tilt_degrees": absf(FAR_RACK_TILT_DEGREES),
		"opponent_concealed_surface": "jade_back_with_ivory_rim",
		"opponent_concealed_owner_surface": "warm_ivory_sides_target_white_far",
		"side_concealed_top_tilt": "perpendicular_to_table",
		"self_hand_lighting": "unshaded_discard_white_face",
		"won_hand_pose": "human_self_draw_revealed_ai_self_draw_concealed",
		"self_draw_hand_pose": "human_face_up_with_draw_marker_ai_flat_concealed_back",
		"opponent_reveal_pose": "three_flat_face_up_hands",
		"opponent_back_material": "all_three_shared_pbr_emerald_back",
		"discard_win_hand_pose": "flat_revealed_for_human",
		"ai_discard_win_presentation": "flat_concealed_back_plus_adjacent_winning_tile_outside_self_hand_safe_zone",
		"side_win_result_upshift_z": SIDE_WIN_RESULT_UPSHIFT_Z,
		"side_winning_tile_max_local_z": SIDE_WINNING_TILE_MAX_LOCAL_Z,
		"self_meld_zone": "continuous_left_segment_of_shared_18_tile_row",
		"self_meld_tile_count": self_meld_tile_count,
		"self_hand_center_x": _self_hand_center_x(),
		"human_ding_que_sort": "rightmost_then_rank_then_tile_id",
		"new_draw_feedback": "small_flat_blue_3d_diamond_with_world_yaw_tight_to_drawn_tile",
		"new_draw_rotation": "world_vertical_axis_and_rate_match_latest_discard",
		"new_draw_travel_seconds": DRAW_TRAVEL_SECONDS,
		"new_draw_settle_seconds": DRAW_SETTLE_SECONDS,
		"new_draw_marker_variants": DRAW_MARKER_STYLE_NAMES,
		"selected_new_draw_marker_variant": draw_marker_style_variant,
		"selected_tile_feedback": "physical_lift_without_overlay_graphic",
		"selected_marker_variants": SELECTED_MARKER_STYLE_NAMES,
		"selected_selection_marker_variant": selected_marker_style_variant,
		"marker_variant_selection": "fixed_blue_draw_diamond_and_no_selection_overlay",
		"latest_discard_feedback": "rotating_solid_golden_3d_diamond_directly_above_tile",
		"discard_travel_seconds": DISCARD_TRAVEL_SECONDS,
		"discard_settle_seconds": DISCARD_SETTLE_SECONDS,
		"discard_reflow_beat_seconds": DISCARD_REFLOW_BEAT_SECONDS,
		"discard_slot_policy": "persistent_per_tile_until_removed_no_survivor_reflow",
		"discard_origin_policy": "upper_left_from_each_player_perspective",
		"discard_flow_by_seat": ["right_then_down", "right_then_down", "right_then_down", "right_then_down"],
		"discard_local_axes_by_seat": {
			"0": "right=+X,down=+Z",
			"1": "right=+Z,down=-X",
			"2": "right=-X,down=-Z",
			"3": "right=-Z,down=+X",
		},
		"latest_marker_timing": "after_river_landing",
		"hand_reflow_timing": "after_discard_landing",
		"side_meld_layout": "single_side_rail_with_group_gaps",
		"right_meld_axis": "same_yaw_and_z_flow_as_right_hand",
		"far_meld_zone": "below_far_hand_not_right_player_band",
		"winning_source_markers": true,
		"meld_source_feedback": "compact_sky_blue_flat_face_arrow_on_second_tile_without_seat_label",
		"winning_source_feedback": "compact_sky_blue_flat_face_arrow_without_seat_label",
		"winning_source_text": false,
		"tile_back_color": SichuanTile3D.NORMAL_TILE_BACK_COLOR.to_html(false),
		"season_theme": "deep_emerald_refined_table",
		"table_asset": "sichuan_table_v2_pbr",
		"table_material_pipeline": "blender_pbr_preserved_without_flat_overrides",
		"table_surface_finish": "dense_directional_microfibre_velvet_with_restrained_shu_brocade_edge",
		"concealed_gang_presentation": "outer_faces_middle_jade_backs",
		"light_count": 2,
		"shadow_casting_light_count": 1,
		"directional_shadow_max_distance": 22.0,
		"mobile_directional_shadow_size": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size.mobile", 0)),
		"mobile_soft_shadow_filter_quality": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile", 0)),
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
