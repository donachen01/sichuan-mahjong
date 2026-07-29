class_name SichuanTile3D
extends Node3D

const TILE_BODY_SCENE := preload("res://res/art/3d/mahjong_tile_body.glb")
const SELECTED_HAND_TEXTURE := preload("res://res/art/ui_3d_cartoon/markers/selected_hand_pointer.svg")
const SELECTED_HALO_TEXTURE := preload("res://res/art/ui_3d_cartoon/markers/selected_jade_halo.svg")
const SELECTED_ARROW_TEXTURE := preload("res://res/art/ui_3d_cartoon/markers/selected_copper_arrow.svg")
const SELECTED_CROWN_TEXTURE := preload("res://res/art/ui_3d_cartoon/markers/selected_ink_crown.svg")
const SELECTED_FOCUS_TEXTURE := preload("res://res/art/ui_3d_cartoon/markers/selected_amber_focus.svg")
const DRAW_MARKER_STYLE_NAMES := ["铜玉菱标", "翡翠环印", "金芒星签", "青黛双折", "琥珀方印"]
const SELECTED_MARKER_STYLE_NAMES := ["象牙手印", "翡翠勾选", "鎏金箭翎", "青黛冠标", "琥珀定位印"]

@export_enum("铜玉菱标", "翡翠环印", "金芒星签", "青黛双折", "琥珀方印")
var draw_marker_style_variant := 1

@export_enum("象牙手印", "翡翠勾选", "鎏金箭翎", "青黛冠标", "琥珀定位印")
var selected_marker_style_variant := 1
const TILE_SIZE := Vector3(0.42, 0.18, 0.58)
# Blender 玉白牌体顶面 Y=0.18。亮牌不再叠加不透明白色内框，印刷符号直接落在
# 圆润玉石表面上；暗牌才覆盖一层圆角翡翠面，四周只露极窄象牙唇边。
const FACE_INSET_SIZE := Vector2(0.42 - 0.066, 0.58 - 0.066)
const FACE_SIZE := FACE_INSET_SIZE
const CONCEALED_BACK_SIZE := Vector2(0.42 - 0.018, 0.58 - 0.018)
const FACE_Y := 0.181
const MARKER_Y := 0.194
const NEW_DRAW_MARKER_SPEED_DEGREES := 120.0
const LATEST_DISCARD_MARKER_SPEED_DEGREES := 126.0
const SELECTED_MARKER_PULSE_SPEED := 3.6
const SELECTED_MARKER_FADE_SECONDS := 0.14
const DUAL_MARKER_OFFSET_X := 0.115
const SELF_HAND_FACE_WHITE := Color("FAF8F3")
const FLAT_RESULT_JADE_BACK := Color("0F6957")

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
var new_draw_marker: MeshInstance3D
var selected_marker: MeshInstance3D
var latest_marker: MeshInstance3D
var winning_source_marker: MeshInstance3D
var winning_source_label: Label3D
var winning_source_seat := -1
var winner_seat := -1
var source_marker_kind := ""
var face_content_rotation_degrees := 0.0
var front_brightness_boost := false
var concealed_surface_flip := false
var flat_concealed_result := false
var reduced_motion := false
var marker_animation_time := 0.0


func _ready() -> void:
	_build_visuals()
	set_process(false)


func _process(delta: float) -> void:
	if reduced_motion:
		return
	if new_draw_marker != null and new_draw_marker.visible:
		new_draw_marker.rotation.y += deg_to_rad(NEW_DRAW_MARKER_SPEED_DEGREES) * delta
	if selected_marker != null and selected_marker.visible:
		marker_animation_time += delta
		var pulse := 1.0 + sin(marker_animation_time * SELECTED_MARKER_PULSE_SPEED) * 0.055
		selected_marker.scale = Vector3.ONE * pulse
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
	meld_type: String = ""
) -> void:
	var was_selected := is_selected
	tile_data = tile.duplicate(true)
	tile_id = int(tile_data.get("id", -1))
	pickable = can_pick and tile_id >= 0
	is_selected = selected
	showing_face = show_face
	winning_source_seat = meld_source if meld_source >= 0 else winning_source
	winner_seat = meld_owner if meld_owner >= 0 else winner
	source_marker_kind = meld_type if not meld_type.is_empty() else ("win" if winning_source >= 0 else "")
	face_content_rotation_degrees = face_rotation_degrees
	front_brightness_boost = bright_front
	concealed_surface_flip = flip_concealed_surfaces
	flat_concealed_result = use_flat_concealed_result
	_build_visuals()
	_apply_ivory_body_material(body_root, front_brightness_boost)
	if not show_face and concealed_surface_flip:
		# 对家仅翻转实体双面以让牌背朝向桌心，材质必须与上/下家共用同一
		# 受光翡翠材质；只有胡牌后真正平扣的 AI 自摸结果才使用稳定不受光材质。
		face_mesh.set_surface_override_material(
			0,
			_flat_concealed_jade_back_material() if flat_concealed_result else _jade_back_material()
		)
		concealed_cap_mesh.set_surface_override_material(0, _face_material(false))
	else:
		face_mesh.set_surface_override_material(
			0,
			_bright_front_face_material() if show_face and bright_front else _face_material(show_face)
		)
		concealed_cap_mesh.set_surface_override_material(0, _jade_back_material())
	# 本家站立手牌的受光角度比桌面弃牌更容易落暗。仅在 bright_front 合同下
	# 显示一张紧贴实体圆角牌身的稳定暖白面，使视觉白度与弃牌一致；符号、厚度、
	# 阴影和触控仍来自原 3D 牌，不是 HUD 卡片。
	face_mesh.visible = not show_face or (show_face and bright_front)
	concealed_cap_mesh.visible = not show_face
	symbol_mesh.visible = show_face
	# Rotate only the printed content in its own face plane. Rotating the whole
	# tile would also move the ivory top lip and change the accepted rack pose.
	symbol_mesh.rotation.y = deg_to_rad(face_content_rotation_degrees)
	if show_face:
		symbol_mesh.set_surface_override_material(0, _symbol_material())
	_apply_state_marker(selected, new_draw, recommended, danger)
	new_draw_marker.visible = new_draw
	selected_marker.visible = selected
	if selected:
		if reduced_motion or was_selected:
			selected_marker.transparency = 0.0
		else:
			selected_marker.transparency = 1.0
			var marker_fade := selected_marker.create_tween()
			marker_fade.tween_property(selected_marker, "transparency", 0.0, SELECTED_MARKER_FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		selected_marker.transparency = 0.0
	_update_status_marker_positions(selected, new_draw)
	latest_marker.visible = latest
	set_process((new_draw or selected or latest) and not reduced_motion)
	winning_source_marker.visible = (
		winning_source_seat >= 0
		and winner_seat >= 0
		and winning_source_seat != winner_seat
	)
	if winning_source_marker.visible:
		winning_source_marker.rotation.y = _winning_source_local_yaw(winner_seat, winning_source_seat)
		var is_meld_source := source_marker_kind in ["peng", "gang"]
		winning_source_marker.scale = Vector3.ONE * (0.90 if is_meld_source else 1.0)
		winning_source_marker.position = (
			Vector3(0.0, MARKER_Y + 0.125, -TILE_SIZE.z * 0.10)
			if is_meld_source
			else Vector3(0.0, MARKER_Y + 0.055, -TILE_SIZE.z * 0.66)
		)
		var marker_color := Color("42A5FF") if is_meld_source else Color("F3B83E")
		winning_source_marker.set_surface_override_material(
			0,
			_cartoon_source_arrow_material() if is_meld_source else _flat_material("winning_source", marker_color)
		)
	winning_source_label.visible = winning_source_marker.visible
	if winning_source_label.visible:
		var is_meld_source := source_marker_kind in ["peng", "gang"]
		var seat_name: String = str(["本家", "上家", "对家", "下家"][clampi(winning_source_seat, 0, 3)])
		winning_source_label.text = "%s出" % seat_name if is_meld_source else seat_name
		winning_source_label.modulate = Color("D9EEFF") if is_meld_source else Color("FFF1C4")
		winning_source_label.font_size = 25 if is_meld_source else 32
		winning_source_label.pixel_size = 0.0044 if is_meld_source else 0.0052
		winning_source_label.position = (
			Vector3(0.0, MARKER_Y + 0.128, -TILE_SIZE.z * 0.48)
			if is_meld_source
			else Vector3(0.0, MARKER_Y + 0.061, -TILE_SIZE.z * 0.94)
		)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	var has_rotating_marker := (new_draw_marker != null and new_draw_marker.visible) \
		or (selected_marker != null and selected_marker.visible) \
		or (latest_marker != null and latest_marker.visible)
	if reduced_motion and selected_marker != null:
		selected_marker.scale = Vector3.ONE
	set_process(has_rotating_marker and not reduced_motion)


func set_draw_marker_style_variant(value: int) -> void:
	draw_marker_style_variant = clampi(value, 0, DRAW_MARKER_STYLE_NAMES.size() - 1)
	if new_draw_marker == null:
		return
	new_draw_marker.mesh = _build_new_draw_marker_mesh()
	new_draw_marker.set_surface_override_material(0, _gold_marker_material())


func set_selected_marker_style_variant(value: int) -> void:
	selected_marker_style_variant = clampi(value, 0, SELECTED_MARKER_STYLE_NAMES.size() - 1)
	if selected_marker == null:
		return
	selected_marker.mesh = _build_selected_marker_mesh()
	selected_marker.set_surface_override_material(0, _selected_marker_material())


func get_marker_style_contract() -> Dictionary:
	return {
		"draw_variants": DRAW_MARKER_STYLE_NAMES,
		"selected_draw_variant": draw_marker_style_variant,
		"selection_variants": SELECTED_MARKER_STYLE_NAMES,
		"selected_selection_variant": selected_marker_style_variant,
		"independent_selection": true,
	}


func set_latest_marker_visible(enabled: bool) -> void:
	if latest_marker == null:
		return
	latest_marker.visible = enabled
	var has_animated_marker := (new_draw_marker != null and new_draw_marker.visible) \
		or (selected_marker != null and selected_marker.visible) \
		or latest_marker.visible
	set_process(has_animated_marker and not reduced_motion)


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
	face_mesh.mesh = _build_rounded_plane_mesh(CONCEALED_BACK_SIZE, 0.032, 6)
	face_mesh.position = Vector3(0.0, FACE_Y, 0.0)
	face_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(face_mesh)

	# 暗手必须是实体双面牌：+Y 玩家侧由 TileFace 保持暖象牙白，-Y 桌心侧
	# 使用这张与 GLB 翡翠背层贴合的圆角面。它不是屏幕 HUD，也不会改变牌的
	# 点击或符号数据。
	concealed_cap_mesh = MeshInstance3D.new()
	concealed_cap_mesh.name = "ConcealedTableJadeBack"
	concealed_cap_mesh.mesh = _build_rounded_plane_mesh(CONCEALED_BACK_SIZE, 0.032, 6)
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

	# 摸牌反馈使用独立的金色立体锥形/钻石，不再用整张半透明底色。
	# 标记位于本家站立牌的上沿之外，旋转时不遮挡任何牌面符号。
	new_draw_marker = MeshInstance3D.new()
	new_draw_marker.name = "NewDrawConeMarker"
	new_draw_marker.mesh = _build_new_draw_marker_mesh()
	new_draw_marker.position = Vector3(0.0, 0.245, -TILE_SIZE.z * 0.72)
	new_draw_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	new_draw_marker.set_surface_override_material(0, _gold_marker_material())
	new_draw_marker.visible = false
	add_child(new_draw_marker)

	# 默认选牌反馈采用翡翠圆印加白色勾号，含义直接且不再出现手型。
	# 它轻微呼吸悬浮，与摸牌旋转标记明确区分，也不会遮挡牌面。
	selected_marker = MeshInstance3D.new()
	selected_marker.name = "SelectedTileMarker"
	selected_marker.mesh = _build_selected_marker_mesh()
	selected_marker.position = Vector3(0.0, 0.245, -TILE_SIZE.z * 0.72)
	selected_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selected_marker.set_surface_override_material(0, _selected_marker_material())
	selected_marker.visible = false
	add_child(selected_marker)

	latest_marker = MeshInstance3D.new()
	# 最新弃牌只保留一枚实心的鎏金立体菱锥。它是落在牌面正上方的
	# 真实 3D 几何，而不是平面的翡翠描边环；金色与桌面的深翡翠形成清楚
	# 的即时对比，并通过慢速自转表达“刚刚打出”。
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
	# Keep the source arrow clear of the tile glyphs. On a laid-flat winning
	# tile it sits just beyond the table-side edge, like the mature reference's
	# yellow directional marker, so its direction remains legible on a phone.
	winning_source_marker.position = Vector3(0.0, MARKER_Y + 0.055, -TILE_SIZE.z * 0.66)
	winning_source_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	winning_source_marker.set_surface_override_material(0, _flat_material("winning_source", Color("F3B83E")))
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
		result.albedo_color = Color("ECE9E3")
		result.roughness = 0.26
	else:
		# 隐藏手牌的 +Y 面朝各自玩家，必须仍是暖象牙白正面；真正朝桌心的
		# 翡翠牌背在 -Y 的 ConcealedTableJadeBack 上，不能再把两面都染绿。
		result.albedo_color = Color("ECE9E3")
		result.roughness = 0.25
		result.clearcoat_enabled = true
		result.clearcoat = 0.30
		result.clearcoat_roughness = 0.22
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[cache_key] = result
	return result


func _bright_front_face_material() -> StandardMaterial3D:
	const CACHE_KEY := "face:self_hand_discard_white_v2"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	# 桌面弃牌正面在当前电影色调映射下接近这一暖白。使用不受局部入射角影响的
	# 牌面层，只校正本家正面白度，不抬高全桌曝光，也不漂白牌面字色。
	result.albedo_color = SELF_HAND_FACE_WHITE
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		result.albedo_texture = load(texture_path) as Texture2D
	material_cache[cache_key] = result
	return result


func _apply_ivory_body_material(node: Node, bright_front: bool = false) -> void:
	# 新分层牌体 GLB 含两块 mesh：MahjongTileBody(象牙白牌身) 与
	# MahjongTileBack(翡翠绿背层)。按名字分别上材质，保留几何自带的绿背层次，
	# 不再把整个牌体无脑染成象牙白。
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if "back" in mesh_instance.name.to_lower():
			mesh_instance.material_override = _jade_back_material()
		else:
			mesh_instance.material_override = _ivory_body_material(bright_front)
	for child in node.get_children():
		_apply_ivory_body_material(child, bright_front)


func _jade_back_material() -> StandardMaterial3D:
	# 牌背翡翠绿实体层材质。轻微清漆高光让绿背有注塑光泽，符合目标图牌背质感。
	const CACHE_KEY := "body:jade_back_layer_v1"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color("178B32")
	result.roughness = 0.27
	result.metallic = 0.02
	result.clearcoat_enabled = true
	result.clearcoat = 0.34
	result.clearcoat_roughness = 0.20
	material_cache[CACHE_KEY] = result
	return result


func _flat_concealed_jade_back_material() -> StandardMaterial3D:
	const CACHE_KEY := "body:flat_result_jade_back_v2"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	# 自摸后整手平扣，牌背必须在横跨整条牌轨的不同受光位置仍保持
	# 同一深翡翠色。旧色 #168B32 在无光照材质上会变成荧光绿，破坏
	# 深翡翠桌面的克制层级；这里与 TABLE_BASE 使用同一色值语义。
	result.albedo_color = FLAT_RESULT_JADE_BACK
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[CACHE_KEY] = result
	return result


func _ivory_body_material(bright_front: bool = false) -> StandardMaterial3D:
	var cache_key := "body:jade_ivory_shell_v5:%s" % ("bright" if bright_front else "standard")
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	# 主牌身必须是有厚度的暖象牙壳；绿色只属于独立的 MahjongTileBack 层。
	# 过去把整个主体覆盖成深绿，亮牌只剩一张白色平面，是“扁贴图感”的根因。
	result.albedo_color = Color("F1EEE8") if bright_front else Color("ECE9E3")
	result.roughness = 0.25
	result.metallic = 0.01
	result.clearcoat_enabled = true
	result.clearcoat = 0.40
	result.clearcoat_roughness = 0.18
	result.rim_enabled = true
	result.rim = 0.035
	result.rim_tint = 0.10
	result.subsurf_scatter_enabled = true
	result.subsurf_scatter_strength = 0.06
	if bright_front:
		# 只给本家手牌抬高材质亮度下限，不碰全局曝光、桌布或其他牌区。
		# 保留真实受光与接触阴影，避免退化成无阴影的纯白平面。
		result.emission_enabled = true
		result.emission = Color("34312C")
		result.emission_energy_multiplier = 0.18
	material_cache[cache_key] = result
	return result


func _build_rounded_plane_mesh(size: Vector2, radius: float, corner_segments: int) -> ArrayMesh:
	# 隐藏牌背用真实圆角轮廓，不再把一张直角 PlaneMesh 贴在玉白壳上。
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


func _apply_state_marker(selected: bool, new_draw: bool, recommended: bool, danger: bool) -> void:
	var marker_color := Color(0.0, 0.0, 0.0, 0.0)
	var marker_key := "none"
	# 选中的牌永远不再使用整牌底色，即使它同时带建议或风险状态；悬浮勾选标记
	# 负责表达选择，避免多个状态叠成用户指出的“大块背板”。
	if selected:
		pass
	elif danger:
		marker_color = Color(0.72, 0.12, 0.10, 0.62)
		marker_key = "danger"
	elif recommended:
		marker_color = Color(0.28, 0.68, 0.43, 0.62)
		marker_key = "recommended"
	# new_draw 刻意不进入整牌底色分支；由 NewDrawConeMarker 独立表达。
	state_marker.visible = marker_color.a > 0.0
	if state_marker.visible:
		state_marker.set_surface_override_material(0, _flat_material(marker_key, marker_color))


func _gold_marker_material() -> StandardMaterial3D:
	var colors := [
		Color("F4B72E"),
		Color("63D9A6"),
		Color("F3C96A"),
		Color("79B8B0"),
		Color("DDAE5E"),
	]
	var marker_color: Color = colors[clampi(draw_marker_style_variant, 0, colors.size() - 1)]
	var cache_key := "marker:new_draw_%d" % clampi(draw_marker_style_variant, 0, colors.size() - 1)
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	result.albedo_color = marker_color
	result.metallic = 0.18
	result.roughness = 0.28
	result.emission_enabled = true
	result.emission = marker_color.darkened(0.42)
	result.emission_energy_multiplier = 0.32
	material_cache[cache_key] = result
	return result


func _selected_marker_material() -> StandardMaterial3D:
	var colors := [
		Color("F8D98E"),
		Color("C7F0D9"),
		Color("FFE8A6"),
		Color("B7E7DC"),
		Color("F6C978"),
	]
	var textures: Array[Texture2D] = [
		SELECTED_HAND_TEXTURE,
		SELECTED_HALO_TEXTURE,
		SELECTED_ARROW_TEXTURE,
		SELECTED_CROWN_TEXTURE,
		SELECTED_FOCUS_TEXTURE,
	]
	var variant := clampi(selected_marker_style_variant, 0, colors.size() - 1)
	var marker_color: Color = colors[variant]
	var cache_key := "marker:selected_vector_%d" % variant
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var result := StandardMaterial3D.new()
	result.albedo_color = marker_color
	result.albedo_texture = textures[variant]
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material_cache[cache_key] = result
	return result


func _build_new_draw_marker_mesh() -> ImmediateMesh:
	match clampi(draw_marker_style_variant, 0, 4):
		1:
			return _build_flat_marker_ring_mesh()
		2:
			return _build_four_point_star_mesh()
		3:
			return _build_double_chevron_mesh()
		4:
			return _build_square_seal_mesh()
	var mesh := ImmediateMesh.new()
	var top := Vector3(0.0, 0.10, 0.0)
	var bottom := Vector3(0.0, -0.12, 0.0)
	var ring := [
		Vector3(0.072, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.072),
		Vector3(-0.072, 0.0, 0.0),
		Vector3(0.0, 0.0, -0.072),
	]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(4):
		var next_index := (index + 1) % 4
		mesh.surface_add_vertex(top)
		mesh.surface_add_vertex(ring[index])
		mesh.surface_add_vertex(ring[next_index])
		mesh.surface_add_vertex(bottom)
		mesh.surface_add_vertex(ring[next_index])
		mesh.surface_add_vertex(ring[index])
	mesh.surface_end()
	return mesh


func _build_selected_marker_mesh() -> PlaneMesh:
	var mesh := PlaneMesh.new()
	var sizes := [
		Vector2(0.34, 0.25),
		Vector2(0.32, 0.24),
		Vector2(0.36, 0.27),
		Vector2(0.31, 0.28),
		Vector2(0.33, 0.26),
	]
	mesh.size = sizes[clampi(selected_marker_style_variant, 0, sizes.size() - 1)]
	return mesh


func _build_flat_marker_ring_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var outer := [Vector3(0.0, 0.02, -0.11), Vector3(0.11, 0.02, 0.0), Vector3(0.0, 0.02, 0.11), Vector3(-0.11, 0.02, 0.0)]
	var inner := [Vector3(0.0, 0.022, -0.055), Vector3(0.055, 0.022, 0.0), Vector3(0.0, 0.022, 0.055), Vector3(-0.055, 0.022, 0.0)]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(4):
		var next_index := (index + 1) % 4
		mesh.surface_add_vertex(outer[index])
		mesh.surface_add_vertex(outer[next_index])
		mesh.surface_add_vertex(inner[next_index])
		mesh.surface_add_vertex(outer[index])
		mesh.surface_add_vertex(inner[next_index])
		mesh.surface_add_vertex(inner[index])
	mesh.surface_end()
	return mesh


func _build_four_point_star_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var center := Vector3(0.0, 0.12, 0.0)
	var points: Array[Vector3] = []
	for index in range(8):
		var angle := -PI * 0.5 + float(index) * TAU / 8.0
		var radius := 0.12 if index % 2 == 0 else 0.045
		points.append(Vector3(cos(angle) * radius, 0.12, sin(angle) * radius))
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		mesh.surface_add_vertex(center)
		mesh.surface_add_vertex(points[index])
		mesh.surface_add_vertex(points[next_index])
	mesh.surface_end()
	return mesh


func _build_double_chevron_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for offset in [-0.07, 0.07]:
		mesh.surface_add_vertex(Vector3(offset - 0.045, 0.09, -0.09))
		mesh.surface_add_vertex(Vector3(offset + 0.045, 0.09, 0.0))
		mesh.surface_add_vertex(Vector3(offset - 0.045, 0.09, 0.09))
	mesh.surface_end()
	return mesh


func _build_square_seal_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half := 0.085
	var y := 0.08
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [
		Vector3(-half, y, -half), Vector3(half, y, -half), Vector3(half, y, half),
		Vector3(-half, y, -half), Vector3(half, y, half), Vector3(-half, y, half),
	]:
		mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	return mesh


func _build_latest_discard_marker_mesh() -> ImmediateMesh:
	# A compact solid pointer: a diamond-shaped golden crown funnels to one lower
	# point. The crown reads as a bright rhombus from the camera while the four
	# sloped facets make the depth explicit, matching the reference's 3D marker
	# rather than reverting to a flat outline ring.
	var mesh := ImmediateMesh.new()
	var pointer := Vector3(0.0, -0.205, 0.0)
	var crown := [
		Vector3(0.0, 0.155, -0.180), Vector3(0.170, 0.155, 0.0),
		Vector3(0.0, 0.155, 0.180), Vector3(-0.170, 0.155, 0.0),
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


func _update_status_marker_positions(selected: bool, new_draw: bool) -> void:
	var selected_marker_z := -TILE_SIZE.z * 0.59
	var draw_marker_z := -TILE_SIZE.z * 0.72
	if selected and new_draw:
		selected_marker.position = Vector3(-DUAL_MARKER_OFFSET_X, 0.245, selected_marker_z)
		new_draw_marker.position = Vector3(DUAL_MARKER_OFFSET_X, 0.245, draw_marker_z)
	else:
		selected_marker.position = Vector3(0.0, 0.245, selected_marker_z)
		new_draw_marker.position = Vector3(0.0, 0.245, draw_marker_z)


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


func _cartoon_source_arrow_material() -> StandardMaterial3D:
	const CACHE_KEY := "marker:compact_blue_meld_source_v1"
	if material_cache.has(CACHE_KEY):
		return material_cache[CACHE_KEY]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color("42A5FF")
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.emission_enabled = true
	result.emission = Color("1264C7")
	result.emission_energy_multiplier = 0.32
	material_cache[CACHE_KEY] = result
	return result


func _build_winning_arrow_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Arrow tip points to local -Z; the stage rotates it toward the discarder.
	for vertex in [
		Vector3(0.0, 0.0, -0.22), Vector3(0.12, 0.0, -0.035), Vector3(-0.12, 0.0, -0.035),
		Vector3(-0.040, 0.0, -0.035), Vector3(0.040, 0.0, -0.035), Vector3(0.040, 0.0, 0.15),
		Vector3(-0.040, 0.0, -0.035), Vector3(0.040, 0.0, 0.15), Vector3(-0.040, 0.0, 0.15),
	]:
		mesh.surface_add_vertex(vertex)
	mesh.surface_end()
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
