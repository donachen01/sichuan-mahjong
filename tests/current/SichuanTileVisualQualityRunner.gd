extends SceneTree

const TILE_SCRIPT := preload("res://scripts/ui/3d/SichuanTile3D.gd")
const EPSILON := 0.002
const SELF_HAND_RACK_TILT_DEGREES := 48.0

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
		_check(absf(face.position.y - 0.241) <= EPSILON, "rounded overlay sits just above the jade-rounded body")

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
		_check(absf(body_size.y - 0.24) <= 0.01, "body thickness is the shared 0.24 physical depth")
		_check(absf(body_size.z - 0.58) <= 0.01, "body height is 0.58")
		_check(body_size.y / body_size.z >= 0.40, "shared tile proportions remain substantial when laid flat instead of reading as paper")
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
		_check(jade_size.y >= 0.070 and jade_size.y <= 0.078, "jade back layer preserves its share of the thicker physical tile")
		var jade_material := jade_mesh.material_override as StandardMaterial3D
		_check(jade_material != null, "jade back material exists")
		if jade_material != null:
			_check_color(jade_material.albedo_color, SichuanTile3D.NORMAL_TILE_BACK_COLOR, "jade layer restores the original emerald-resin source color")
			_check(jade_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "jade layer restores directional table-light response")
			_check(jade_material.roughness >= 0.26 and jade_material.roughness <= 0.28, "jade layer restores the original resin roughness")
			_check(jade_material.metallic <= 0.03, "jade layer remains resin-like instead of metallic")
			_check(jade_material.clearcoat_enabled and jade_material.clearcoat >= 0.33 and jade_material.clearcoat <= 0.35, "jade layer restores the original controlled clearcoat")
			_check(jade_material.clearcoat_roughness >= 0.19 and jade_material.clearcoat_roughness <= 0.21, "jade clearcoat keeps a soft highlight rolloff")
			_check(not jade_material.emission_enabled, "jade layer receives light without artificial glow")

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
	if concealed_back != null and concealed_back.mesh != null:
		_check(concealed_back.mesh.get_aabb().size.y >= 0.01, "concealed jade back keeps a physical resin-edge bevel")
	var back_material := concealed_back.get_active_material(0) as StandardMaterial3D if concealed_back != null else null
	_check(back_material != null, "table-facing jade back material exists")
	if back_material != null:
		_check_color(back_material.albedo_color, SichuanTile3D.NORMAL_TILE_BACK_COLOR, "table-facing concealed back matches the original emerald-resin source color")
		_check(back_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "concealed back restores directional table-light response")
		_check(back_material.roughness >= 0.26 and back_material.roughness <= 0.28, "concealed back restores the original resin roughness")
		_check(back_material.metallic <= 0.03, "concealed back remains resin-like instead of metallic")
		_check(back_material.clearcoat_enabled and back_material.clearcoat >= 0.33 and back_material.clearcoat <= 0.35, "concealed back restores the original controlled clearcoat")
		_check(back_material.clearcoat_roughness >= 0.19 and back_material.clearcoat_roughness <= 0.21, "concealed back clearcoat keeps a soft highlight rolloff")
		_check(not back_material.emission_enabled, "concealed back receives light without artificial glow")

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
		2,
		0.0,
		false,
		false,
		false
	)
	await process_frame
	var far_owner_material := face.get_active_material(0) as StandardMaterial3D
	_check(far_owner_material != null, "far rack keeps a locally bright owner-facing ivory cap")
	if far_owner_material != null:
		_check_color(far_owner_material.albedo_color, SichuanTile3D.FAR_RACK_IVORY_COLOR, "far rack owner-facing cap uses the figure-2 ivory source color")
		_check(far_owner_material.emission_enabled and far_owner_material.emission_energy_multiplier >= 0.20, "far rack owner-facing cap stays white at the accepted vertical pose")
	var far_back_material := concealed_back.get_active_material(0) as StandardMaterial3D
	_check(far_back_material != null, "far rack display back material exists")
	if far_back_material != null:
		_check_color(far_back_material.albedo_color, SichuanTile3D.NORMAL_TILE_BACK_COLOR, "far rack uses the same emerald source color as both side opponents")
		_check(far_back_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "far rack uses the shared PBR back instead of a special unshaded green")
		_check(far_back_material.clearcoat_enabled, "far rack shared green face retains resin clearcoat")
	var far_jade_mesh := _mesh_named(body_root, "back")
	var far_jade_material := far_jade_mesh.material_override as StandardMaterial3D if far_jade_mesh != null else null
	_check(far_jade_material != null, "far rack keeps an independent physical jade lip")
	if far_jade_material != null:
		_check(far_jade_material == far_back_material, "far rack physical jade lip and display back share the exact cached material")
		_check_color(far_jade_material.albedo_color, SichuanTile3D.NORMAL_TILE_BACK_COLOR, "far rack physical jade lip uses the shared emerald source color")
		_check(far_jade_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "far rack physical jade lip retains PBR lighting")
		_check(far_jade_material.clearcoat_enabled, "far rack physical jade lip retains resin clearcoat")
	var far_body_mesh := _mesh_named(body_root, "body")
	var far_body_material := far_body_mesh.material_override as StandardMaterial3D if far_body_mesh != null else null
	_check(far_body_material != null, "far rack keeps an independent ivory body")
	if far_body_material != null:
		_check_color(far_body_material.albedo_color, SichuanTile3D.FAR_RACK_IVORY_COLOR, "far rack top body uses the figure-2 ivory source color")
		_check(far_body_material.emission_enabled and far_body_material.emission_energy_multiplier >= 0.20, "far rack top body has a local white floor without changing table exposure")

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
	_check(new_draw_marker != null and new_draw_marker.visible, "new draw uses one visible small blue 3D diamond")
	if new_draw_marker != null:
		_check(new_draw_marker.name == "NewDrawRotatingBlueDiamond", "new draw exposes the blue-diamond node contract")
		var draw_yaw_pivot := new_draw_marker.get_parent() as Node3D
		_check(draw_yaw_pivot != null and draw_yaw_pivot.name == "NewDrawWorldYawPivot", "new draw diamond owns a dedicated world-yaw pivot")
		if draw_yaw_pivot != null:
			_check(absf(rad_to_deg(draw_yaw_pivot.rotation.x) + SELF_HAND_RACK_TILT_DEGREES) <= EPSILON, "new draw yaw pivot counteracts the self-hand tilt")
		_check(new_draw_marker.position.z >= -0.14 and new_draw_marker.position.z <= -0.10, "new draw diamond stays tight to the drawn tile instead of floating toward the table")
		_check(new_draw_marker.position.y >= 0.33 and new_draw_marker.position.y <= 0.36, "new draw diamond sits directly above the thicker drawn tile")
		_check(tile.get("draw_marker_style_variant") == 0, "new-draw marker is the fixed blue-diamond style")
		var draw_mesh := new_draw_marker.mesh as ImmediateMesh
		_check(draw_mesh != null, "new draw uses solid 3D diamond geometry")
		if draw_mesh != null:
			_check(draw_mesh.get_aabb().size.x >= 0.15 and draw_mesh.get_aabb().size.x <= 0.17, "new draw diamond is compact")
		var draw_material := new_draw_marker.get_active_material(0) as StandardMaterial3D
		_check(draw_material != null, "new draw blue material exists")
		if draw_material != null:
			_check_color(draw_material.albedo_color, Color("42A5FF"), "new draw diamond is blue")
			_check(draw_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "new draw diamond uses one flat blue without lighting gradients")
			_check(not draw_material.emission_enabled and not draw_material.clearcoat_enabled, "new draw diamond has no glow or clearcoat gradient")
		tile.call("set_reduced_motion", false)
		var rotation_before := new_draw_marker.rotation.y
		tile.call("_process", 0.5)
		_check(absf(rad_to_deg(new_draw_marker.rotation.y - rotation_before) - 63.0) <= 0.2, "new draw diamond matches the latest-discard 126-degree-per-second rotation")
		tile.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(SELF_HAND_RACK_TILT_DEGREES))
		await process_frame
		var world_yaw_axis := new_draw_marker.global_transform.basis.y.normalized()
		_check(world_yaw_axis.dot(Vector3.UP) >= 0.999, "new draw diamond rotates around the same world-vertical axis as the latest discard")
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
	_check(selected_marker != null and not selected_marker.visible, "selected tile does not show a checkmark or any overlay graphic")
	_check(new_draw_marker != null and not new_draw_marker.visible, "selection marker is independent from the new-draw diamond")
	if selected_marker != null:
		_check(selected_marker.name == "SelectionVisualDisabled", "selection compatibility node cannot render an icon")
		_check(selected_marker.mesh == null, "selected tile has no checkmark mesh or texture plane")
		_check(tile.get("selected_marker_style_variant") == 0, "selection icon style is fixed to none")

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
		if latest_mesh != null and new_draw_marker != null and new_draw_marker.mesh is ImmediateMesh:
			_check(
				(new_draw_marker.mesh as ImmediateMesh).get_aabb().size.x < latest_mesh.get_aabb().size.x,
				"new draw blue diamond stays smaller than the latest-discard diamond"
			)
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
	_check(not selected_marker.visible and new_draw_marker.visible, "selected drawn tile preserves only the blue new-draw diamond")
	_check(absf(new_draw_marker.position.x) <= EPSILON, "blue diamond remains centred when its tile is selected")

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
