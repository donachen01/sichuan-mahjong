extends Node3D

class_name MahjongTile3D

const TILE_WIDTH := 0.4
const TILE_HEIGHT := 0.6
const TILE_DEPTH := 0.1
const FACE_MARGIN := 0.045
const TOP_MARGIN := 0.028

const BODY_COLOR := Color(0.955, 0.948, 0.92, 1.0)
const TOP_COLOR := Color(0.99, 0.986, 0.964, 1.0)
const EDGE_TINT := Color(0.86, 0.84, 0.78, 1.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.1)
const NEW_DRAW_GLOW := Color(1.0, 0.86, 0.34, 0.3)
const RECOMMEND_GLOW := Color(0.32, 1.0, 0.58, 0.24)
const DANGER_GLOW := Color(1.0, 0.38, 0.32, 0.24)

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var top_mesh: MeshInstance3D = $TopMesh
@onready var face_mesh: MeshInstance3D = $FaceMesh
@onready var glow_mesh: MeshInstance3D = $GlowMesh

var tile_data: Dictionary = {}
var is_selected: bool = false
var is_new_draw: bool = false
var is_recommended: bool = false
var is_danger: bool = false

static var _texture_cache: Dictionary = {}


func _ready() -> void:
	_setup_meshes()


func configure(tile: Dictionary, selected: bool, new_draw: bool, recommended: bool, danger: bool) -> void:
	tile_data = tile.duplicate(true)
	is_selected = selected
	is_new_draw = new_draw
	is_recommended = recommended
	is_danger = danger
	_setup_meshes()


func set_visual_state(selected: bool, new_draw: bool, recommended: bool, danger: bool) -> void:
	is_selected = selected
	is_new_draw = new_draw
	is_recommended = recommended
	is_danger = danger
	_apply_state()


func get_face_screen_rect(camera: Camera3D) -> Rect2:
	var top_left := camera.unproject_position(global_transform * Vector3(-TILE_WIDTH * 0.5 + FACE_MARGIN, TILE_HEIGHT - FACE_MARGIN, TILE_DEPTH * 0.5 + 0.005))
	var bottom_right := camera.unproject_position(global_transform * Vector3(TILE_WIDTH * 0.5 - FACE_MARGIN, FACE_MARGIN, TILE_DEPTH * 0.5 + 0.005))
	return Rect2(top_left, bottom_right - top_left).abs()


func _setup_meshes() -> void:
	if body_mesh == null:
		return

	var body_box := body_mesh.mesh as BoxMesh
	if body_box == null:
		body_box = BoxMesh.new()
		body_mesh.mesh = body_box
	body_box.size = Vector3(TILE_WIDTH, TILE_HEIGHT, TILE_DEPTH)

	var top_plane := top_mesh.mesh as PlaneMesh
	if top_plane == null:
		top_plane = PlaneMesh.new()
		top_mesh.mesh = top_plane
	top_plane.size = Vector2(TILE_WIDTH - TOP_MARGIN, TILE_DEPTH - TOP_MARGIN)
	top_mesh.position = Vector3(0.0, TILE_HEIGHT + 0.001, 0.0)
	top_mesh.rotation_degrees = Vector3(0.0, 0.0, 0.0)

	var face_plane := face_mesh.mesh as PlaneMesh
	if face_plane == null:
		face_plane = PlaneMesh.new()
		face_mesh.mesh = face_plane
	face_plane.size = Vector2(TILE_WIDTH - FACE_MARGIN * 2.0, TILE_HEIGHT - FACE_MARGIN * 2.0)
	face_mesh.position = Vector3(0.0, TILE_HEIGHT * 0.5, TILE_DEPTH * 0.5 + 0.003)
	face_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var glow_plane := glow_mesh.mesh as PlaneMesh
	if glow_plane == null:
		glow_plane = PlaneMesh.new()
		glow_mesh.mesh = glow_plane
	glow_plane.size = Vector2(TILE_WIDTH + 0.1, TILE_HEIGHT + 0.1)
	glow_mesh.position = Vector3(0.0, TILE_HEIGHT * 0.5, TILE_DEPTH * 0.5 + 0.001)
	glow_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	body_mesh.position = Vector3(0.0, TILE_HEIGHT * 0.5, 0.0)
	_apply_materials()
	_apply_state()


func _apply_materials() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = BODY_COLOR
	body_material.roughness = 0.42
	body_material.metallic = 0.0
	body_material.uv1_scale = Vector3.ONE
	body_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	body_material.rim_enabled = true
	body_material.rim = 0.04
	body_material.rim_tint = 0.12
	body_mesh.set_surface_override_material(0, body_material)

	var top_material := StandardMaterial3D.new()
	top_material.albedo_color = TOP_COLOR
	top_material.roughness = 0.22
	top_material.metallic = 0.0
	top_material.rim_enabled = true
	top_material.rim = 0.06
	top_material.rim_tint = 0.16
	top_mesh.set_surface_override_material(0, top_material)

	var face_material := StandardMaterial3D.new()
	face_material.albedo_color = Color.WHITE
	face_material.roughness = 0.3
	face_material.cull_mode = BaseMaterial3D.CULL_BACK
	face_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var face_texture := _resolve_tile_texture()
	if face_texture != null:
		face_material.albedo_texture = face_texture
		face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		face_material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		face_material.uv1_offset = Vector3.ZERO
	face_mesh.set_surface_override_material(0, face_material)

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_material.no_depth_test = true
	glow_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	glow_mesh.set_surface_override_material(0, glow_material)


func _apply_state() -> void:
	var hover_scale := 1.0
	if is_selected:
		hover_scale = 1.08
	elif is_new_draw:
		hover_scale = 1.03
	scale = Vector3.ONE * hover_scale

	var body_material := body_mesh.get_active_material(0) as StandardMaterial3D
	if body_material != null:
		body_material.emission_enabled = is_selected or is_new_draw
		body_material.emission = EDGE_TINT
		body_material.emission_energy_multiplier = 0.45 if is_selected else (0.2 if is_new_draw else 0.0)

	var glow_material := glow_mesh.get_active_material(0) as StandardMaterial3D
	if glow_material != null:
		var glow_color := Color(1.0, 1.0, 1.0, 0.0)
		if is_danger:
			glow_color = DANGER_GLOW
		elif is_recommended:
			glow_color = RECOMMEND_GLOW
		elif is_new_draw:
			glow_color = NEW_DRAW_GLOW
		elif is_selected:
			glow_color = Color(1.0, 0.96, 0.72, 0.24)
		glow_material.albedo_color = glow_color
		glow_mesh.visible = glow_color.a > 0.0


func _resolve_tile_texture() -> Texture2D:
	var suit := str(tile_data.get("suit", ""))
	var rank := int(tile_data.get("rank", 0))
	if suit == "" or rank <= 0:
		return null
	var cache_key := "%s_%d" % [suit, rank]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var paths := [
		"res://res/art/tiles/%s_%d.png" % [suit, rank],
		"res://res/art/tiles/%s_%d.jpg" % [suit, rank],
	]
	for path in paths:
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture == null:
				texture = _load_texture_from_image(path)
			if texture != null:
				_texture_cache[cache_key] = texture
				return texture
	return null


func _load_texture_from_image(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)
