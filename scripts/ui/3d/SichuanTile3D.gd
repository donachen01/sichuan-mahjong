class_name SichuanTile3D
extends Node3D

const TILE_BODY_SCENE := preload("res://res/art/3d/mahjong_tile_body.glb")
const DRAW_MARKER_STYLE_NAMES: Array[String] = []
const SELECTED_MARKER_STYLE_NAMES := ["无选中图案"]

var draw_marker_style_variant := 0

@export_enum("无选中图案")
var selected_marker_style_variant := 0
const TILE_SIZE := Vector3(0.42, 0.24, 0.58)
# Blender 玉白牌体顶面 Y=0.24。所有姿态复用这一个加厚实体，平扣牌不能单独
# 压缩成纸片。亮牌不再叠加不透明白色内框，印刷符号直接落在圆润玉石表面上；
# 暗牌才覆盖一层圆角翡翠面，四周只露极窄象牙唇边。
const FACE_INSET_SIZE := Vector2(0.42 - 0.066, 0.58 - 0.066)
const FACE_SIZE := FACE_INSET_SIZE
# The physical green back layer is only 3mm inset from the ivory shell. The old
# 18mm inset made every opponent flat/meld tile read as a white tile with a
# smaller green card floating inside it. Keep the same footprint as the GLB
# MahjongTileBack so the cap and manufactured layer fuse into one tile.
const CONCEALED_BACK_SIZE := Vector2(0.42 - 0.006, 0.58 - 0.006)
const CONCEALED_BACK_CORNER_RADIUS := 0.022
const FACE_Y := TILE_SIZE.y + 0.001
const MARKER_Y := FACE_Y + 0.013
const LATEST_DISCARD_MARKER_SPEED_DEGREES := 126.0
const SELF_HAND_FACE_WHITE := Color("E7E2D9")
# 上、下家实体背层继续使用翡翠树脂基色与材质参数；它同时保留在平扣牌的
# 侧边厚度中，不能因为正面显示色校准而变成白边或二维贴片。
const NORMAL_TILE_BACK_COLOR := Color("218A3D")
# 平扣牌与立牌/暗杠共用同一套 PBR 参数，但平扣朝上会直接吃到顶灯，必须做
# 一次受光补偿才能在最终 Metal 画面中回到下家立牌的深翡翠目标色。它不是
# 无光照平面，也不是另一套模型；只校准相同树脂材质的源色。
const FLAT_RESULT_JADE_BACK := Color("0C5729")
# 对家仍可按其朝向局部抬高白色牌身，但普通行牌中的三家暗手必须复用同一套
# PBR 翡翠背面。不能再给对家单独设置无光照亮绿大面或亮绿实体层，否则同桌
# 直接读成两副不同颜色的牌。
const FAR_RACK_IVORY_COLOR := Color("EBE7DF")
# 碰、杠和胡牌来源复用中心弃牌黄色菱形的金色高光材质；几何仍是带尖端和杆的
# 箭头，因此醒目但不会丢失“来源方向”信息，也不增加任何座位文字。
const SOURCE_ARROW_COLOR := Color("FFD45A")
# 来源箭头必须落在牌面中心，而不是悬在牌外。箭头自身有实体厚度，底面略高于
# 玉白牌面，顶部由灯光和金色清漆高光读出立体感。
const SOURCE_ARROW_FACE_OFFSET := 0.018
const SOURCE_ARROW_THICKNESS := 0.026

static var material_cache: Dictionary = {}

var tile_data: Dictionary = {}
var tile_id := -1
var pickable := false
var is_selected := false
var showing_face := false

var body_root: Node3D
var face_mesh: MeshInstance3D
var concealed_cap_mesh: MeshInstance3D
var symbol_mesh: MeshInstance3D
var state_marker: MeshInstance3D
var new_draw_rotation_pivot: Node3D
var new_draw_marker: MeshInstance3D
var selected_marker: MeshInstance3D
var latest_marker: MeshInstance3D
var winning_source_marker: MeshInstance3D
var winning_source_label: Label3D
var winning_source_seat := -1
var winner_seat := -1
var source_marker_kind := ""
var using_meld_source_arrow_mesh := false
var face_content_rotation_degrees := 0.0
var front_brightness_boost := false
var concealed_surface_flip := false
var flat_concealed_result := false
var reduced_motion := false
var flat_surface_mesh: ArrayMesh
var beveled_back_surface_mesh: ArrayMesh
var configuration_signature: Array = []
var full_configure_count := 0


static func _uses_mobile_gpu_budget() -> bool:
	return OS.has_feature("ios") \
		or OS.has_feature("android") \
		or str(RenderingServer.get_current_rendering_method()) == "mobile"


static func _uses_expensive_mobile_materials() -> bool:
	return bool(ProjectSettings.get_setting("performance/mobile_expensive_materials_enabled", false))


static func _allow_expensive_material_features() -> bool:
	return not _uses_mobile_gpu_budget() or _uses_expensive_mobile_materials()


func _ready() -> void:
	_build_visuals()
	set_process(false)


func _process(delta: float) -> void:
	if reduced_motion:
		return
	if latest_marker != null and latest_marker.visible:
		latest_marker.rotation.y += deg_to_rad(LATEST_DISCARD_MARKER_SPEED_DEGREES) * delta


func configure(
	tile: Dictionary,
	show_face: bool,
	selected: bool,
	new_draw: bool,
	recommended: bool,
	danger: bool,
	latest: bool,
	can_pick: bool,
	winning_source: int = -1,
	winner: int = -1,
	face_rotation_degrees: float = 0.0,
	bright_front: bool = false,
	flip_concealed_surfaces: bool = false,
	use_flat_concealed_result: bool = false,
	meld_source: int = -1,
	meld_owner: int = -1,
	meld_type: String = "",
	show_flat_back_layer: bool = false
) -> void:
	_build_visuals()
	var resolved_winning_source := meld_source if meld_source >= 0 else winning_source
	var resolved_winner := meld_owner if meld_owner >= 0 else winner
	var resolved_source_kind := meld_type if not meld_type.is_empty() else ("win" if winning_source >= 0 else "")
	var requested_signature := [
		int(tile.get("id", -1)),
		str(tile.get("suit", "")),
		int(tile.get("rank", 0)),
		show_face,
		selected,
		new_draw,
		recommended,
		danger,
		latest,
		can_pick,
		resolved_winning_source,
		resolved_winner,
		face_rotation_degrees,
		bright_front,
		flip_concealed_surfaces,
		use_flat_concealed_result,
		resolved_source_kind,
		show_flat_back_layer,
	]
	if requested_signature == configuration_signature:
		return
	configuration_signature = requested_signature
	full_configure_count += 1
	tile_data = tile.duplicate(true)
	tile_id = int(tile_data.get("id", -1))
	pickable = can_pick and tile_id >= 0
	is_selected = selected
	showing_face = show_face
	winning_source_seat = resolved_winning_source
	winner_seat = resolved_winner
	source_marker_kind = resolved_source_kind
	face_content_rotation_degrees = face_rotation_degrees
	front_brightness_boost = bright_front
	concealed_surface_flip = flip_concealed_surfaces
	flat_concealed_result = use_flat_concealed_result
	# 只给隐藏牌背使用树脂倒角；亮牌字面继续使用原平面，避免本轮牌背修复
	# 改变牌面符号、白边或既有排版。
	face_mesh.mesh = beveled_back_surface_mesh if not show_face else flat_surface_mesh
	var use_flat_back_material := not show_face and flat_concealed_result
	var use_far_rack_material := not show_face and not flat_concealed_result and winner_seat == 2
	_apply_ivory_body_material(body_root, front_brightness_boost, use_far_rack_material)
	if not show_face and flat_concealed_result:
		# 平扣结果的真实 GLB 背层也使用同一套受光补偿，避免绿色表面和实体
		# 厚度边缘出现两种颜色；几何、厚度和子节点缩放仍保持原样。
		var flat_physical_back := body_root.find_child("MahjongTileBack", true, false) as MeshInstance3D
		if flat_physical_back != null:
			flat_physical_back.material_override = _flat_concealed_jade_back_material()
	if not show_face and concealed_surface_flip:
		# 对家翻转实体双面以让牌背朝向桌心；胡牌后真正平扣的暗手继续使用
		# PBR 翡翠树脂，只对正对顶灯的入射强度做朝向补偿，不能退回无光照纯色。
		face_mesh.set_surface_override_material(
			0,
			_flat_concealed_jade_back_material() if flat_concealed_result else _jade_back_material()
		)
		concealed_cap_mesh.set_surface_override_material(0, _face_material(false))
	else:
		face_mesh.set_surface_override_material(
			0,
			_far_rack_ivory_material()
			if use_far_rack_material
			else (_bright_front_face_material() if show_face and bright_front else _face_material(show_face))
		)
		concealed_cap_mesh.set_surface_override_material(
			0,
			_flat_concealed_jade_back_material()
			if use_flat_back_material
			else _jade_back_material()
		)
	# 本家站立手牌的受光角度比桌面弃牌更容易落暗。仅在 bright_front 合同下
	# 显示一张紧贴实体圆角牌身的稳定暖白面，使视觉白度与弃牌一致；符号、厚度、
	# 阴影和触控仍来自原 3D 牌，不是 HUD 卡片。
	face_mesh.visible = not show_face or (show_face and bright_front)
	# Face-up discard tiles still rest on a physical green underside. Keep that
	# layer explicit because the imported body alone reads as an all-white base
	# from the tabletop camera. This flag is limited to the discard river.
	concealed_cap_mesh.visible = not show_face or show_flat_back_layer
	symbol_mesh.visible = show_face
	# Rotate only the printed content in its own face plane. Rotating the whole
	# tile would also move the ivory top lip and change the accepted rack pose.
	symbol_mesh.rotation.y = deg_to_rad(face_content_rotation_degrees)
	if show_face:
		symbol_mesh.set_surface_override_material(0, _symbol_material())
	_apply_state_marker(selected, new_draw, recommended, danger)
	if new_draw_marker != null:
		new_draw_marker.visible = false
	# 选中牌只保留 Stage 的实体抬升，不再叠加勾号、光环或任何平面图案。
	# 即便摸牌与选中同一张，蓝色小菱形仍保持正中，避免制造第二个选择符号。
	selected_marker.visible = false
	latest_marker.visible = latest
	# The gold diamond remains an unambiguous latest-discard marker without a
	# perpetual per-frame spin. The discard landing tween already supplies motion;
	# keeping this node static lets mobile low-processor mode actually become idle.
	set_process(false)
	winning_source_marker.visible = (
		winning_source_seat >= 0
		and winner_seat >= 0
		and winning_source_seat != winner_seat
	)
	var is_meld_source := source_marker_kind in ["peng", "gang"]
	if winning_source_marker.visible:
		# 副露和胡牌共用同一套金色实体方向语言；方向 yaw 继承来源座位，箭头
		# 本身压在牌面中心，不再使用悬在牌外的平面标记。
		if is_meld_source != using_meld_source_arrow_mesh:
			winning_source_marker.mesh = (
				_build_meld_source_arrow_mesh()
				if is_meld_source
				else _build_winning_arrow_mesh()
			)
			using_meld_source_arrow_mesh = is_meld_source
		winning_source_marker.rotation.y = _winning_source_local_yaw(winner_seat, winning_source_seat)
		winning_source_marker.scale = Vector3.ONE
		winning_source_marker.position = Vector3(0.0, FACE_Y + SOURCE_ARROW_FACE_OFFSET, 0.0)
		winning_source_marker.set_surface_override_material(
			0,
			_source_arrow_material()
		)
	# 来源只以箭头表达，碰、杠和胡牌都不得显示“上家/下家/对家”等文字。
	winning_source_label.visible = false
	winning_source_label.text = ""


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	set_process(false)


func get_full_configure_count() -> int:
	return full_configure_count


func set_draw_marker_style_variant(_value: int) -> void:
	draw_marker_style_variant = 0


func set_selected_marker_style_variant(_value: int) -> void:
	selected_marker_style_variant = 0
	if selected_marker == null:
		return
	selected_marker.mesh = null


func get_marker_style_contract() -> Dictionary:
	return {
		"draw_variants": DRAW_MARKER_STYLE_NAMES,
		"selected_draw_variant": draw_marker_style_variant,
		"selection_variants": SELECTED_MARKER_STYLE_NAMES,
		"selected_selection_variant": selected_marker_style_variant,
		"independent_selection": false,
		"selection_overlay": "none_physical_lift_only",
	}


func set_latest_marker_visible(enabled: bool) -> void:
	if latest_marker == null:
		return
	latest_marker.visible = enabled
	set_process(false)


func get_screen_rect(camera: Camera3D) -> Rect2:
	if camera == null or not is_inside_tree():
		return Rect2()
	var corners := [
		Vector3(-TILE_SIZE.x * 0.5, FACE_Y, -TILE_SIZE.z * 0.5),
		Vector3(TILE_SIZE.x * 0.5, FACE_Y, -TILE_SIZE.z * 0.5),
		Vector3(TILE_SIZE.x * 0.5, FACE_Y, TILE_SIZE.z * 0.5),
		Vector3(-TILE_SIZE.x * 0.5, FACE_Y, TILE_SIZE.z * 0.5),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in corners:
		var screen_point := camera.unproject_position(global_transform * corner)
		minimum = minimum.min(screen_point)
		maximum = maximum.max(screen_point)
	return Rect2(minimum, maximum - minimum)


func _build_visuals() -> void:
	if body_root != null:
		return
	body_root = TILE_BODY_SCENE.instantiate() as Node3D
	body_root.name = "ManufacturedTileBody"
	add_child(body_root)
	_apply_ivory_body_material(body_root)

	face_mesh = MeshInstance3D.new()
	face_mesh.name = "TileFace"
	flat_surface_mesh = _build_rounded_plane_mesh(CONCEALED_BACK_SIZE, 0.032, 6)
	beveled_back_surface_mesh = _build_rounded_beveled_back_mesh(CONCEALED_BACK_SIZE, CONCEALED_BACK_CORNER_RADIUS, 6)
	face_mesh.mesh = flat_surface_mesh
	face_mesh.position = Vector3(0.0, FACE_Y, 0.0)
	face_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(face_mesh)

	# 暗手必须是实体双面牌：+Y 玩家侧由 TileFace 保持暖象牙白，-Y 桌心侧
	# 使用这张与 GLB 翡翠背层贴合的圆角面。它不是屏幕 HUD，也不会改变牌的
	# 点击或符号数据。
	concealed_cap_mesh = MeshInstance3D.new()
	concealed_cap_mesh.name = "ConcealedTableJadeBack"
	concealed_cap_mesh.mesh = beveled_back_surface_mesh
	concealed_cap_mesh.position = Vector3(0.0, -0.001, 0.0)
	concealed_cap_mesh.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	concealed_cap_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	concealed_cap_mesh.set_surface_override_material(0, _jade_back_material())
	concealed_cap_mesh.visible = false
	add_child(concealed_cap_mesh)

	symbol_mesh = MeshInstance3D.new()
	symbol_mesh.name = "TileSymbol"
	var symbol_plane := PlaneMesh.new()
	symbol_plane.size = FACE_SIZE
	symbol_mesh.mesh = symbol_plane
	symbol_mesh.position = Vector3(0.0, FACE_Y + 0.003, 0.0)
	symbol_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	symbol_mesh.visible = false
	add_child(symbol_mesh)

	state_marker = MeshInstance3D.new()
	state_marker.name = "StateMarker"
	var marker_plane := PlaneMesh.new()
	marker_plane.size = Vector2(TILE_SIZE.x + 0.11, TILE_SIZE.z + 0.11)
	state_marker.mesh = marker_plane
	state_marker.position = Vector3(0.0, 0.006, 0.0)
	state_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(state_marker)


	# 保留节点仅为旧场景/测试调用兼容；选中视觉完全由桌面 Stage 的实体抬升负责。
	# 它没有 mesh 和材质，因而绝不会再画出勾号或其他图案。
	selected_marker = MeshInstance3D.new()
	selected_marker.name = "SelectionVisualDisabled"
	selected_marker.position = Vector3(0.0, TILE_SIZE.y + 0.065, -TILE_SIZE.z * 0.72)
	selected_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selected_marker.visible = false
	add_child(selected_marker)

	latest_marker = MeshInstance3D.new()
	latest_marker.name = "LatestDiscardRotatingGoldenDiamond"
	latest_marker.mesh = _build_latest_discard_marker_mesh()
	latest_marker.position = Vector3(0.0, MARKER_Y + 0.36, 0.0)
	latest_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	latest_marker.set_surface_override_material(0, _latest_discard_marker_material())
	latest_marker.visible = false
	add_child(latest_marker)

	winning_source_marker = MeshInstance3D.new()
	winning_source_marker.name = "WinningSourceArrow"
	winning_source_marker.mesh = _build_winning_arrow_mesh()
	# The arrow is a diegetic marker: centered on the physical tile face. Its yaw
	# is set from the winner/source seats in configure(), so the 3D arrow points
	# toward the discarder while the beveled side walls catch the table lights.
	winning_source_marker.position = Vector3(0.0, FACE_Y + SOURCE_ARROW_FACE_OFFSET, 0.0)
	winning_source_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	winning_source_marker.set_surface_override_material(0, _source_arrow_material())
	winning_source_marker.visible = false
	add_child(winning_source_marker)

	winning_source_label = Label3D.new()
	winning_source_label.name = "WinningSourceSeatLabel"
	winning_source_label.text = "上家"
	winning_source_label.font_size = 32
	winning_source_label.pixel_size = 0.0052
	winning_source_label.modulate = Color("FFF1C4")
	winning_source_label.outline_modulate = Color("182238")
	winning_source_label.outline_size = 8
	winning_source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winning_source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	winning_source_label.position = Vector3(0.0, MARKER_Y + 0.061, -TILE_SIZE.z * 0.94)
	winning_source_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	winning_source_label.no_depth_test = true
	winning_source_label.visible = false
	add_child(winning_source_label)

	_set_tile_render_layer(self)


func _face_material(show_face: bool) -> StandardMaterial3D:
	var cache_key := "face_base:%s" % ("front" if show_face else "back")
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	if show_face:
		# 亮牌时该平面被隐藏，只保留材质作为状态切换的明确合同。
		result.albedo_color = Color("E7E2D9")
		result.roughness = 0.40
	else:
		# 隐藏手牌的 +Y 面朝各自玩家，必须仍是暖象牙白正面；真正朝桌心的
		# 翡翠牌背在 -Y 的 ConcealedTableJadeBack 上，不能再把两面都染绿。
		result.albedo_color = Color("E7E2D9")
		result.roughness = 0.40
		if _allow_expensive_material_features():
			result.clearcoat_enabled = true
			result.clearcoat = 0.16
			result.clearcoat_roughness = 0.34
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[cache_key] = result
	return result


func _bright_front_face_material() -> StandardMaterial3D:
	const CACHE_KEY := "face:self_hand_discard_white_v2"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	# 本家正面继续使用独立承托层修正立牌入射角，但材质仍接受桌面光照，
	# 不再用无光照白片制造与其他麻将牌割裂的曝光区间。
	result.albedo_color = SELF_HAND_FACE_WHITE
	result.roughness = 0.40
	if _allow_expensive_material_features():
		result.clearcoat_enabled = true
		result.clearcoat = 0.14
		result.clearcoat_roughness = 0.34
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[CACHE_KEY] = result
	return result


func _set_tile_render_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << 1
	for child in node.get_children():
		_set_tile_render_layer(child)


func _symbol_material() -> StandardMaterial3D:
	var suit := str(tile_data.get("suit", ""))
	var rank := int(tile_data.get("rank", 0))
	var texture_path := ""
	if not suit.is_empty() and rank > 0:
		texture_path = "res://res/art/ui_3d_cartoon/tile_symbols/%s_%d.png" % [suit, rank]
	var cache_key := "symbol:%s" % texture_path
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color.WHITE
	# Printed glyph color must remain stable across the four table quadrants.
	# Lighting the transparent symbol plane previously lifted deep green/red
	# into mint and pink, cutting phone contrast almost in half.
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if _uses_mobile_gpu_budget()
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	)
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		result.albedo_texture = load(texture_path) as Texture2D
	material_cache[cache_key] = result
	return result


func _apply_ivory_body_material(
	node: Node,
	bright_front: bool = false,
	use_far_rack_material: bool = false
) -> void:
	# 新分层牌体 GLB 含两块 mesh：MahjongTileBody(象牙白牌身) 与
	# MahjongTileBack(翡翠绿背层)。按名字分别上材质，保留几何自带的绿背层次，
	# 不再把整个牌体无脑染成象牙白。
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if "back" in mesh_instance.name.to_lower():
			# 三家普通暗手的大面与实体绿层必须共享同一缓存材质；对家只允许在
			# 白色牌身上做朝向补偿，不能再拥有第二种牌背颜色。
			mesh_instance.material_override = _jade_back_material()
		else:
			mesh_instance.material_override = (
				_far_rack_ivory_material()
				if use_far_rack_material
				else _ivory_body_material(bright_front)
			)
	for child in node.get_children():
		_apply_ivory_body_material(child, bright_front, use_far_rack_material)


func _jade_back_material() -> StandardMaterial3D:
	# 完整恢复图2的翡翠树脂层：基础漫反射负责绿色体积，低金属度与柔和清漆
	# 共同形成受控高光。所有暗手、暗杠和自摸/胡牌扣牌复用该材质，让朝向变化
	# 产生真实受光差异，同时保留独立绿色背层、象牙牌身和端面层次。
	const CACHE_KEY := "body:integrated_emerald_resin_back_v9"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	result.albedo_color = NORMAL_TILE_BACK_COLOR
	result.roughness = 0.43
	result.metallic = 0.02
	if _allow_expensive_material_features():
		result.clearcoat_enabled = true
		result.clearcoat = 0.18
		result.clearcoat_roughness = 0.34
	material_cache[CACHE_KEY] = result
	return result


func _flat_concealed_jade_back_material() -> StandardMaterial3D:
	# 平扣仍使用与立牌完全相同的树脂 PBR 参数；仅降低源色，抵消朝上平面的
	# 顶灯入射，避免最终画面变成亮绿。禁止退回 unshaded 或二维覆盖材质。
	const CACHE_KEY := "body:flat_emerald_resin_compensated_v1"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := _jade_back_material().duplicate() as StandardMaterial3D
	result.albedo_color = FLAT_RESULT_JADE_BACK
	material_cache[CACHE_KEY] = result
	return result


func _far_rack_ivory_material() -> StandardMaterial3D:
	# 对家立牌顶部使用同一组暖象牙 PBR 参数，靠牌面朝向与全局补光获得可读性，
	# 不再用自发光制造独立于现场光照的白边。
	const CACHE_KEY := "body:far_rack_ivory_v5"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := _ivory_body_material(false).duplicate() as StandardMaterial3D
	result.albedo_color = FAR_RACK_IVORY_COLOR
	result.emission_enabled = false
	material_cache[CACHE_KEY] = result
	return result


func _ivory_body_material(bright_front: bool = false) -> StandardMaterial3D:
	var cache_key := "body:integrated_ivory_shell_v6:%s" % ("bright" if bright_front else "standard")
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	# 主牌身必须是有厚度的暖象牙壳；绿色只属于独立的 MahjongTileBack 层。
	# 过去把整个主体覆盖成深绿，亮牌只剩一张白色平面，是“扁贴图感”的根因。
	result.albedo_color = Color("EBE6DD") if bright_front else Color("E7E2D9")
	result.roughness = 0.40
	result.metallic = 0.01
	if _allow_expensive_material_features():
		result.clearcoat_enabled = true
		result.clearcoat = 0.16
		result.clearcoat_roughness = 0.34
		result.rim_enabled = true
		result.rim = 0.035
		result.rim_tint = 0.10
		result.subsurf_scatter_enabled = true
		result.subsurf_scatter_strength = 0.06
	result.emission_enabled = false
	material_cache[cache_key] = result
	return result


func _build_rounded_plane_mesh(size: Vector2, radius: float, corner_segments: int) -> ArrayMesh:
	# 亮牌字面的圆角承托面保持平整，不改变现有文字和符号视觉。
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	var half := size * 0.5
	var clamped_radius := minf(radius, minf(half.x, half.y))
	var centers: Array[Vector2] = [
		Vector2(half.x - clamped_radius, -half.y + clamped_radius),
		Vector2(half.x - clamped_radius, half.y - clamped_radius),
		Vector2(-half.x + clamped_radius, half.y - clamped_radius),
		Vector2(-half.x + clamped_radius, -half.y + clamped_radius),
	]
	var start_angles: Array[float] = [-90.0, 0.0, 90.0, 180.0]
	for corner_index in range(4):
		for segment in range(corner_segments + 1):
			var angle: float = deg_to_rad(start_angles[corner_index] + 90.0 * float(segment) / float(corner_segments))
			var point: Vector2 = centers[corner_index] + Vector2(cos(angle), sin(angle)) * clamped_radius
			vertices.append(Vector3(point.x, 0.0, point.y))
			normals.append(Vector3.UP)
	var indices := PackedInt32Array()
	var rim_count := vertices.size() - 1
	for index in range(rim_count):
		indices.append(0)
		indices.append(index + 1)
		indices.append((index + 1) % rim_count + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_rounded_beveled_back_mesh(size: Vector2, radius: float, corner_segments: int) -> ArrayMesh:
	# 隐藏牌背使用一圈真实下沉倒角，不再只是一张所有法线都朝上的平面。
	# 中心面负责深绿树脂主体，斜面法线接受方向光和清漆高光，由此在平扣、
	# 竖立和侧立三种朝向中都能看到图2那种亮边与层次。
	const BEVEL_WIDTH := 0.018
	const BEVEL_DEPTH := 0.012
	var perimeter := PackedVector2Array()
	var perimeter_normals := PackedVector2Array()
	var half := size * 0.5
	var clamped_radius := minf(radius, minf(half.x, half.y))
	var centers: Array[Vector2] = [
		Vector2(half.x - clamped_radius, -half.y + clamped_radius),
		Vector2(half.x - clamped_radius, half.y - clamped_radius),
		Vector2(-half.x + clamped_radius, half.y - clamped_radius),
		Vector2(-half.x + clamped_radius, -half.y + clamped_radius),
	]
	var start_angles: Array[float] = [-90.0, 0.0, 90.0, 180.0]
	for corner_index in range(4):
		for segment in range(corner_segments + 1):
			var angle: float = deg_to_rad(start_angles[corner_index] + 90.0 * float(segment) / float(corner_segments))
			var outward := Vector2(cos(angle), sin(angle))
			perimeter.append(centers[corner_index] + outward * clamped_radius)
			perimeter_normals.append(outward)
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	for index in range(perimeter.size()):
		var inner_point := perimeter[index] - perimeter_normals[index] * BEVEL_WIDTH
		vertices.append(Vector3(inner_point.x, 0.0, inner_point.y))
		normals.append(Vector3.UP)
	for index in range(perimeter.size()):
		var point := perimeter[index]
		var outward := perimeter_normals[index]
		vertices.append(Vector3(point.x, -BEVEL_DEPTH, point.y))
		normals.append(Vector3(outward.x * 0.72, 0.69, outward.y * 0.72).normalized())
	var indices := PackedInt32Array()
	var rim_count := perimeter.size()
	for index in range(rim_count):
		indices.append(0)
		indices.append(index + 1)
		indices.append((index + 1) % rim_count + 1)
	for index in range(rim_count):
		var inner_current := index + 1
		var inner_next := (index + 1) % rim_count + 1
		var outer_current := rim_count + index + 1
		var outer_next := rim_count + (index + 1) % rim_count + 1
		indices.append(inner_current)
		indices.append(outer_current)
		indices.append(outer_next)
		indices.append(inner_current)
		indices.append(outer_next)
		indices.append(inner_next)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _apply_state_marker(selected: bool, new_draw: bool, recommended: bool, danger: bool) -> void:
	var marker_color := Color(0.0, 0.0, 0.0, 0.0)
	var marker_key := "none"
	# 选中的牌永远不再使用整牌底色，即使它同时带建议或风险状态；由 Stage
	# 的实体抬升负责表达选择，避免勾选图案或“大块背板”重新出现。
	if selected:
		pass
	elif danger:
		marker_color = Color(0.72, 0.12, 0.10, 0.62)
		marker_key = "danger"
	elif recommended:
		marker_color = Color(0.28, 0.68, 0.43, 0.62)
		marker_key = "recommended"
	# New draws use physical right-edge separation in the table stage and do
	# not add another color plane or icon to the tile itself.
	state_marker.visible = marker_color.a > 0.0
	if state_marker.visible:
		state_marker.set_surface_override_material(0, _flat_material(marker_key, marker_color))


func _build_latest_discard_marker_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var pointer := Vector3(0.0, -0.205, 0.0)
	var crown := [
		Vector3(0.0, 0.155, -0.180),
		Vector3(0.170, 0.155, 0.0),
		Vector3(0.0, 0.155, 0.180),
		Vector3(-0.170, 0.155, 0.0),
	]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(4):
		var next_index := (index + 1) % 4
		for vertex in [
			Vector3(0.0, 0.155, 0.0), crown[index], crown[next_index],
			pointer, crown[next_index], crown[index],
		]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	return mesh


func _latest_discard_marker_material() -> StandardMaterial3D:
	const CACHE_KEY := "marker:latest_solid_golden_diamond_v3"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color("FFD45A")
	result.metallic = 0.34
	result.roughness = 0.26
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.emission_enabled = true
	result.emission = Color("E79512")
	result.emission_energy_multiplier = 0.52
	result.clearcoat_enabled = true
	result.clearcoat = 0.36
	result.clearcoat_roughness = 0.18
	material_cache[CACHE_KEY] = result
	return result


func _flat_material(key: String, color: Color) -> StandardMaterial3D:
	var cache_key := "flat:%s" % key
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.albedo_color = color
	material_cache[cache_key] = result
	return result


func _source_arrow_material() -> StandardMaterial3D:
	# Keep one exact material contract with the centre latest-discard diamond:
	# warm yellow albedo, restrained metallic/clearcoat and a small emission lift.
	return _latest_discard_marker_material()


func _build_winning_arrow_mesh() -> ArrayMesh:
	return _build_extruded_arrow_mesh(0.120, 0.078, 0.026, SOURCE_ARROW_THICKNESS)


func _build_meld_source_arrow_mesh() -> ArrayMesh:
	return _build_extruded_arrow_mesh(0.100, 0.066, 0.024, SOURCE_ARROW_THICKNESS)


func _build_extruded_arrow_mesh(length: float, head_width: float, stem_half_width: float, thickness: float) -> ArrayMesh:
	# Local -Z is the arrow tip. Extruding the same silhouette above/below the
	# tile face gives the marker real side walls instead of a yellow polygon.
	var outline := PackedVector2Array([
		Vector2(0.0, -length),
		Vector2(head_width, -0.010),
		Vector2(stem_half_width, -0.010),
		Vector2(stem_half_width, length * 0.96),
		Vector2(-stem_half_width, length * 0.96),
		Vector2(-stem_half_width, -0.010),
		Vector2(-head_width, -0.010),
	])
	var vertices := PackedVector3Array()
	for point in outline:
		vertices.append(Vector3(point.x, thickness * 0.5, point.y))
	for point in outline:
		vertices.append(Vector3(point.x, -thickness * 0.5, point.y))
	var indices := PackedInt32Array()
	# Top and bottom caps (winding is opposite).
	for index in range(1, outline.size() - 1):
		indices.append(0); indices.append(index); indices.append(index + 1)
		indices.append(outline.size()); indices.append(outline.size() + index + 1); indices.append(outline.size() + index)
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		indices.append(index); indices.append(outline.size() + index); indices.append(outline.size() + next)
		indices.append(index); indices.append(outline.size() + next); indices.append(next)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _winning_source_local_yaw(winner: int, source: int) -> float:
	var tile_yaws := [0.0, -PI * 0.5, PI, PI * 0.5]
	# Arrow geometry initially points toward table top (-Z). Convert the source
	# seat's absolute screen direction into the winner tile's local space.
	var source_arrow_yaws := [PI, PI * 0.5, 0.0, -PI * 0.5]
	var winner_yaw: float = float(tile_yaws[clampi(winner, 0, 3)])
	var source_yaw: float = float(source_arrow_yaws[clampi(source, 0, 3)])
	return source_yaw - winner_yaw


func _source_seat_color(source: int) -> Color:
	# 四个绝对座位使用稳定且高区分度的颜色；颜色只服务于来源辨识，
	# 箭头方向与中文座位标签仍同时保留，避免仅靠色觉判断。
	var colors := [
		Color("43D3FF"),
		Color("FF9F43"),
		Color("D874FF"),
		Color("50E391"),
	]
	return colors[clampi(source, 0, 3)]
