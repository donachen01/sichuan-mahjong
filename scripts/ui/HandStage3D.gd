extends Node3D

class_name HandStage3D

const TILE_SCENE := preload("res://scenes/ui/MahjongTile3D.tscn")
const TILE_WIDTH := 0.4
const BASE_WORLD_Y := 0.34
const SELECTED_LIFT := 0.06
const NEW_DRAW_LIFT := 0.025
const STAGE_DEPTH := 0.0
const SIDE_MARGIN_WORLD := 0.16
const MAX_STEP_WORLD := 0.31
const MIN_STEP_WORLD := 0.255
const CAMERA_HEIGHT := 0.58
const CAMERA_DEPTH := 6.8
const CAMERA_PITCH := -6.5
const CAMERA_SIZE := 2.28

@onready var camera: Camera3D = $Camera3D
@onready var light: DirectionalLight3D = $DirectionalLight3D
@onready var fill_light: DirectionalLight3D = $FillLight3D
@onready var environment: WorldEnvironment = $WorldEnvironment
@onready var tiles_root: Node3D = $TilesRoot

var hand_tiles: Array = []
var selected_tile_id: int = -1
var new_draw_tile_id: int = -1
var viewport_size: Vector2 = Vector2.ZERO
var trainer_markers: Dictionary = {}
var tile_nodes: Array = []
var tile_hit_rects: Array = []
var configure_signature: String = ""


func _ready() -> void:
	_setup_stage()


func configure(tiles: Array, selected_id: int, new_id: int, canvas_size: Vector2, markers: Dictionary = {}) -> void:
	var next_signature := _build_configure_signature(tiles, selected_id, new_id, canvas_size, markers)
	if next_signature == configure_signature:
		return
	configure_signature = next_signature
	hand_tiles = tiles.duplicate(true)
	selected_tile_id = selected_id
	new_draw_tile_id = new_id
	viewport_size = canvas_size
	trainer_markers = markers.duplicate(true)
	_rebuild_tiles()


func _build_configure_signature(tiles: Array, selected_id: int, new_id: int, canvas_size: Vector2, markers: Dictionary) -> String:
	var tile_ids: Array[int] = []
	for tile in tiles:
		var tile_data: Dictionary = tile
		tile_ids.append(int(tile_data.get("id", -1)))
	var danger_ids: Array = markers.get("danger_tile_ids", [])
	return JSON.stringify({
		"tiles": tile_ids,
		"selected": selected_id,
		"new": new_id,
		"size": [int(round(canvas_size.x)), int(round(canvas_size.y))],
		"recommended": int(markers.get("recommended_tile_id", -1)),
		"danger": danger_ids.duplicate(),
	})


func get_tile_id_at_point(point: Vector2) -> int:
	for index in range(tile_hit_rects.size() - 1, -1, -1):
		var item: Dictionary = tile_hit_rects[index]
		var rect: Rect2 = item.get("rect", Rect2())
		if rect.has_point(point):
			return int(item.get("tile_id", -1))
	return -1


func _setup_stage() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DEPTH)
	camera.rotation_degrees = Vector3(CAMERA_PITCH, 0.0, 0.0)
	camera.size = CAMERA_SIZE
	camera.near = 0.1
	camera.far = 20.0

	light.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	light.light_energy = 1.65
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

	fill_light.rotation_degrees = Vector3(-18.0, 150.0, 0.0)
	fill_light.light_energy = 0.82
	fill_light.shadow_enabled = false

	var env := environment.environment
	if env == null:
		env = Environment.new()
		environment.environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0, 1.0)
	env.ambient_light_energy = 0.8
	env.sdfgi_enabled = false
	env.ssao_enabled = false
	env.glow_enabled = false


func _rebuild_tiles() -> void:
	for child in tiles_root.get_children():
		child.queue_free()
	tile_nodes.clear()
	tile_hit_rects.clear()

	if hand_tiles.is_empty():
		return

	var step_world := _compute_step_world()
	var row_width: float = TILE_WIDTH
	if hand_tiles.size() > 1:
		row_width += step_world * float(hand_tiles.size() - 1)
	var start_x: float = -row_width * 0.5 + TILE_WIDTH * 0.5

	for index in range(hand_tiles.size()):
		var tile: Dictionary = hand_tiles[index]
		var tile_id := int(tile.get("id", -1))
		var tile_node := TILE_SCENE.instantiate()
		var is_selected := tile_id == selected_tile_id
		var is_new_draw := tile_id == new_draw_tile_id
		var y_lift := SELECTED_LIFT if is_selected else (NEW_DRAW_LIFT if is_new_draw else 0.0)
		tile_node.position = Vector3(start_x + float(index) * step_world, BASE_WORLD_Y + y_lift, STAGE_DEPTH)
		tile_node.configure(
			tile,
			is_selected,
			is_new_draw,
			int(trainer_markers.get("recommended_tile_id", -1)) == tile_id,
			trainer_markers.get("danger_tile_ids", []).has(tile_id)
		)
		tile_node.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		tiles_root.add_child(tile_node)
		tile_nodes.append(tile_node)

	call_deferred("_refresh_hit_rects")


func _refresh_hit_rects() -> void:
	tile_hit_rects.clear()
	if camera == null:
		return
	for tile_node in tile_nodes:
		if tile_node == null:
			continue
		tile_hit_rects.append({
			"tile_id": int(tile_node.tile_data.get("id", -1)),
			"rect": tile_node.get_face_screen_rect(camera).grow_individual(10.0, 12.0, 10.0, 12.0),
		})


func _compute_step_world() -> float:
	if hand_tiles.size() <= 1:
		return MAX_STEP_WORLD
	var visible_world_width := _orthographic_visible_width()
	var allowance := maxf(0.0, visible_world_width - SIDE_MARGIN_WORLD * 2.0 - TILE_WIDTH)
	var fit_step := allowance / float(hand_tiles.size() - 1)
	return clampf(fit_step, MIN_STEP_WORLD, MAX_STEP_WORLD)


func _orthographic_visible_width() -> float:
	var aspect := maxf(1.0, viewport_size.x / maxf(1.0, viewport_size.y))
	return CAMERA_SIZE * aspect
