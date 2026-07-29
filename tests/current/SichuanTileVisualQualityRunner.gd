extends SceneTree

const TILE_SCRIPT := preload("res://scripts/ui/3d/SichuanTile3D.gd")
const EPSILON := 0.002

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tile: Node3D = TILE_SCRIPT.new()
	get_root().add_child(tile)
	await process_frame
	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		true,
		false,
		false,
		false,
		false,
		false,
		true,
		-1,
		-1
	)
	await process_frame

	var face: MeshInstance3D = tile.get("face_mesh") as MeshInstance3D
	var symbol: MeshInstance3D = tile.get("symbol_mesh") as MeshInstance3D
	var body_root: Node3D = tile.get("body_root") as Node3D
	_check(face != null and symbol != null and body_root != null, "tile visual nodes exist")

	if face != null:
		var face_material := face.get_active_material(0) as StandardMaterial3D
		_check(face_material != null, "front face material exists")
		if face_material != null:
			_check_color(face_material.albedo_color, Color("ECE9E3"), "front source color")
			_check(face_material.roughness >= 0.20 and face_material.roughness <= 0.30, "front roughness is jade-smooth")
		_check(not face.visible, "revealed tile uses the rounded ivory body as its face instead of an opaque white rectangle")
		var face_mesh := face.mesh as ArrayMesh
		_check(face_mesh != null and face_mesh.get_surface_count() == 1, "concealed overlay is a rounded custom mesh")
		if face_mesh != null and face_mesh.get_surface_count() == 1:
			var arrays := face_mesh.surface_get_arrays(0)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			_check(vertices.size() >= 25, "concealed overlay has enough contour vertices for smooth corners")
			var overlay_size := face_mesh.get_aabb().size
			_check(overlay_size.x >= 0.39 and overlay_size.x <= 0.41, "rounded overlay preserves the narrow ivory side lip")
			_check(overlay_size.z >= 0.55 and overlay_size.z <= 0.57, "rounded overlay preserves the narrow ivory end lip")
		_check(absf(face.position.y - 0.181) <= EPSILON, "rounded overlay sits just above the jade-rounded body")

	if symbol != null:
		var symbol_material := symbol.get_active_material(0) as StandardMaterial3D
		_check(symbol.visible, "front glyph is visible")
		_check(symbol_material != null, "glyph material exists")
		if symbol_material != null:
			_check(symbol_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "glyph color is lighting-stable")
			_check(
				symbol_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
				"glyph uses anisotropic mipmap filtering"
			)
			_check(symbol_material.albedo_texture != null, "glyph texture is loaded")
			if symbol_material.albedo_texture != null:
				var glyph_image := symbol_material.albedo_texture.get_image()
				_check(glyph_image != null and glyph_image.has_mipmaps(), "glyph import contains mipmaps")

	var body_mesh := _mesh_named(body_root, "body")
	_check(body_mesh != null, "rounded body mesh exists")
	if body_mesh != null:
		var body_size := _combined_aabb(body_root).size
		_check(absf(body_size.x - 0.42) <= 0.01, "body width is 0.42")
		_check(absf(body_size.y - 0.18) <= 0.01, "body thickness is 0.18")
		_check(absf(body_size.z - 0.58) <= 0.01, "body height is 0.58")
		var body_material := body_mesh.material_override as StandardMaterial3D
		_check(body_material != null, "body material exists")
		if body_material != null:
			_check_color(body_material.albedo_color, Color("ECE9E3"), "jade-ivory shell source color")
			_check(body_material.metallic <= 0.05, "body metallic remains resin-like")
			_check(body_material.roughness >= 0.20 and body_material.roughness <= 0.30, "body roughness is smooth without looking chromed")
			_check(body_material.clearcoat_enabled and body_material.clearcoat >= 0.30 and body_material.clearcoat <= 0.48, "body has a controlled polished-jade clearcoat")
			_check(body_material.clearcoat_roughness <= 0.22, "clearcoat highlight remains soft and rounded")
			_check(body_material.rim_enabled and body_material.rim <= 0.05, "body has restrained edge light instead of a white frame")
			_check(body_material.subsurf_scatter_enabled and body_material.subsurf_scatter_strength >= 0.03 and body_material.subsurf_scatter_strength <= 0.10, "body has a weak jade-like subsurface response")

	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		true,
		false,
		false,
		false,
		false,
		false,
		true,
		-1,
		-1,
		0.0,
		true
	)
	await process_frame
	_check(face.visible, "bright human hand uses a stable rounded white face")
	var bright_face_material := face.get_active_material(0) as StandardMaterial3D
	_check(bright_face_material != null, "bright human face material exists")
	if bright_face_material != null:
		_check_color(bright_face_material.albedo_color, SichuanTile3D.SELF_HAND_FACE_WHITE, "bright human face matches the discard-white source target")
		_check(bright_face_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "bright human face is independent of the rack incidence angle")

	var jade_mesh := _mesh_named(body_root, "back")
	_check(jade_mesh != null, "independent jade back layer exists")
	if jade_mesh != null:
		var jade_size := jade_mesh.get_aabb().size
		_check(jade_size.y >= 0.050 and jade_size.y <= 0.060, "jade back layer occupies the commercial-reference share of tile thickness")
		var jade_material := jade_mesh.material_override as StandardMaterial3D
		_check(jade_material != null, "jade back material exists")
		if jade_material != null:
			_check_color(jade_material.albedo_color, Color("178B32"), "jade layer source color")
			_check(jade_material.roughness >= 0.20 and jade_material.roughness <= 0.32, "jade layer roughness is polished but not plastic")
			_check(jade_material.clearcoat_enabled and jade_material.clearcoat >= 0.30 and jade_material.clearcoat <= 0.40, "jade layer carries the same rounded highlight language")

	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		-1,
		-1
	)
	await process_frame
	_check(not symbol.visible, "concealed tile hides glyph")
	_check(face.visible, "concealed tile keeps the rounded owner-facing ivory front")
	var owner_face_material := face.get_active_material(0) as StandardMaterial3D
	_check(owner_face_material != null, "concealed owner-facing material exists")
	if owner_face_material != null:
		_check_color(owner_face_material.albedo_color, Color("ECE9E3"), "concealed owner-facing source color")
		_check(owner_face_material.roughness >= 0.20 and owner_face_material.roughness <= 0.30, "concealed owner-facing ivory remains jade-smooth")
	var concealed_back := tile.get("concealed_cap_mesh") as MeshInstance3D
	_check(concealed_back != null and concealed_back.visible, "concealed tile shows a physical table-facing jade back")
	var back_material := concealed_back.get_active_material(0) as StandardMaterial3D if concealed_back != null else null
	_check(back_material != null, "table-facing jade back material exists")
	if back_material != null:
		_check_color(back_material.albedo_color, Color("178B32"), "table-facing jade back calibrated source color")
		_check(back_material.roughness >= 0.20 and back_material.roughness <= 0.32, "concealed back is smooth without becoming a neon plastic plate")
		_check(back_material.clearcoat_enabled and back_material.clearcoat <= 0.40, "concealed back highlight stays restrained")

	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		true,
		false,
		true,
		false,
		false,
		false,
		true,
		-1,
		-1
	)
	await process_frame
	var state_marker := tile.get("state_marker") as MeshInstance3D
	var new_draw_marker := tile.get("new_draw_marker") as MeshInstance3D
	_check(state_marker != null and not state_marker.visible, "new draw no longer paints a full-tile color plane")
	_check(new_draw_marker != null and new_draw_marker.visible, "new draw uses one visible themed marker")
	if new_draw_marker != null:
		_check(new_draw_marker.position.z < -0.36, "new draw cone stays beyond the tile glyph area")
		_check(tile.get("draw_marker_style_variant") == 1, "new-draw marker defaults to the selected emerald-ring variant")
		tile.call("set_reduced_motion", false)
		var rotation_before := new_draw_marker.rotation.y
		tile.call("_process", 0.5)
		_check(absf(rad_to_deg(new_draw_marker.rotation.y - rotation_before) - 60.0) <= 0.2, "new draw cone rotates at 120 degrees per second")
		tile.call("set_reduced_motion", true)
		var reduced_rotation := new_draw_marker.rotation.y
		tile.call("_process", 0.5)
		_check(absf(new_draw_marker.rotation.y - reduced_rotation) <= EPSILON, "reduced motion freezes the draw cone without hiding it")

	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		true,
		true,
		false,
		true,
		true,
		false,
		true,
		-1,
		-1
	)
	await process_frame
	var selected_marker := tile.get("selected_marker") as MeshInstance3D
	_check(state_marker != null and not state_marker.visible, "selected tile suppresses every full-tile color plane")
	_check(selected_marker != null and selected_marker.visible, "selected tile uses one visible jade check marker")
	_check(new_draw_marker != null and not new_draw_marker.visible, "selection marker is independent from the new-draw diamond")
	if selected_marker != null:
		_check(selected_marker.name == "SelectedTileMarker", "selection marker has a generic selected-tile node contract")
		_check(tile.get("selected_marker_style_variant") == 1, "selection marker defaults to the jade check variant")
		var selected_mesh := selected_marker.mesh as PlaneMesh
		_check(selected_mesh != null and selected_mesh.size.x >= 0.31, "selection marker uses a selectable themed vector plane")
		var selected_material := selected_marker.get_active_material(0) as StandardMaterial3D
		_check(selected_material != null and selected_material.albedo_texture != null, "selection marker has an independent vector texture")
		if selected_material != null and selected_material.albedo_texture != null:
			_check(selected_material.albedo_texture.resource_path.ends_with("selected_jade_halo.svg"), "default selection marker must use the simple jade check graphic")
		var selection_texture_paths: Dictionary = {}
		for variant in range(5):
			tile.call("set_selected_marker_style_variant", variant)
			var variant_material := selected_marker.get_active_material(0) as StandardMaterial3D
			if variant_material != null and variant_material.albedo_texture != null:
				selection_texture_paths[variant_material.albedo_texture.resource_path] = true
		_check(selection_texture_paths.size() == 5, "five selection styles must use five distinct vector graphics")
		tile.call("set_selected_marker_style_variant", 1)
		tile.call("set_reduced_motion", false)
		var selected_scale_before := selected_marker.scale.x
		tile.call("_process", 0.25)
		_check(absf(selected_marker.scale.x - selected_scale_before) >= 0.005, "selection marker uses a subtle breathing pulse")
		tile.call("set_reduced_motion", true)
		_check(absf(selected_marker.scale.x - 1.0) <= EPSILON, "reduced motion freezes the selection marker at its base scale")

	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		true,
		false,
		false,
		false,
		false,
		true,
		false,
		-1,
		-1
	)
	await process_frame
	var latest_marker := tile.get("latest_marker") as MeshInstance3D
	_check(latest_marker != null and latest_marker.visible, "latest discard uses one visible solid golden diamond")
	if latest_marker != null:
		_check(latest_marker.name == "LatestDiscardRotatingGoldenDiamond", "latest discard exposes the rotating-golden-diamond contract")
		_check(latest_marker.position.z == 0.0 and latest_marker.position.y >= 0.33, "latest diamond floats directly above the tile center")
		var latest_mesh := latest_marker.mesh as ImmediateMesh
		_check(latest_mesh != null and latest_mesh.get_aabb().size.x >= 0.33, "latest diamond is substantially larger than the old yellow chip")
		tile.call("set_reduced_motion", false)
		var latest_rotation_before := latest_marker.rotation.y
		tile.call("_process", 0.5)
		_check(absf(rad_to_deg(latest_marker.rotation.y - latest_rotation_before) - 63.0) <= 0.2, "latest diamond rotates at 126 degrees per second")

	tile.call(
		"configure",
		{"id": 3105, "suit": "wan", "rank": 5},
		true,
		true,
		true,
		false,
		false,
		false,
		true,
		-1,
		-1
	)
	await process_frame
	_check(selected_marker.visible and new_draw_marker.visible, "selection and new-draw markers can coexist")
	_check(selected_marker.position.x < -0.10 and new_draw_marker.position.x > 0.10, "coexisting markers split cleanly without overlap")

	if failures.is_empty():
		print("SICHUAN_TILE_VISUAL_QUALITY_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _mesh_named(node: Node, token: String) -> MeshInstance3D:
	if node is MeshInstance3D and token in node.name.to_lower():
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _mesh_named(child, token)
		if result != null:
			return result
	return null


func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var has_mesh := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var child_aabb := mesh_instance.get_aabb()
		if not has_mesh:
			result = child_aabb
			has_mesh = true
		else:
			result = result.merge(child_aabb)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _check_color(actual: Color, expected: Color, message: String) -> void:
	_check(
		absf(actual.r - expected.r) <= EPSILON
		and absf(actual.g - expected.g) <= EPSILON
		and absf(actual.b - expected.b) <= EPSILON,
		message
	)
