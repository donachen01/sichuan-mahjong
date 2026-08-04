extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pack_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="):
			pack_path = argument.trim_prefix("--pack=")
	if pack_path.is_empty() or not ProjectSettings.load_resource_pack(pack_path, true, 0):
		push_error("Could not mount exported iOS PCK: %s" % pack_path)
		quit(1)
		return

	var failures: Array[String] = []
	_verify_center_model(failures)
	_verify_settlement_design(failures)
	if not failures.is_empty():
		push_error("PACKAGED_IOS_2_6_29_FAILED:\n- " + "\n- ".join(failures))
		quit(1)
		return
	print("PACKAGED_IOS_2_6_29_PASS CENTER + SETTLEMENT")
	quit(0)


func _verify_center_model(failures: Array[String]) -> void:
	var scene := load("res://res/art/3d/sichuan_center_compass_v2.glb") as PackedScene
	if scene == null:
		failures.append("center model could not be loaded")
		return
	var instance := scene.instantiate() as Node3D
	get_root().add_child(instance)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var active_sector_count := 0
	var separator_aligned_sector_count := 0
	var triangle_count := 0
	var minimum_active_vertex_radius := INF
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		triangle_count += mesh_instance.mesh.get_faces().size() / 3
		if not str(mesh_instance.name).begins_with("DirectionActive"):
			continue
		active_sector_count += 1
		var near_counter_angles: Array[float] = []
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for local_vertex in vertices:
				var world_vertex: Vector3 = mesh_instance.global_transform * local_vertex
				var radius := Vector2(world_vertex.x, world_vertex.z).length()
				minimum_active_vertex_radius = minf(minimum_active_vertex_radius, radius)
				if radius >= 0.455 and radius <= 0.465:
					near_counter_angles.append(fposmod(atan2(world_vertex.z, world_vertex.x), TAU))
		var sector_index := int(str(mesh_instance.name).trim_prefix("DirectionActive"))
		var expected_span := 124.48292 if sector_index % 2 == 0 else 55.51708
		if absf(_smallest_circular_span_degrees(near_counter_angles) - expected_span) <= 0.25:
			separator_aligned_sector_count += 1
	print("PACKAGED_IOS_CENTER_OBJECTS ", meshes.size())
	print("PACKAGED_IOS_CENTER_TRIANGLES ", triangle_count)
	print("PACKAGED_IOS_CENTER_ACTIVE_MIN_RADIUS %.4f" % minimum_active_vertex_radius)
	print("PACKAGED_IOS_CENTER_SEPARATOR_ALIGNED ", separator_aligned_sector_count)
	if meshes.size() != 9 \
			or triangle_count != 1044 \
			or active_sector_count != 4 \
			or separator_aligned_sector_count != 4 \
			or minimum_active_vertex_radius < 0.458 \
			or instance.find_child("CounterBronzeBezel", true, false) == null \
			or instance.find_child("CenterBronzeKeyline", true, false) != null:
		failures.append("center model lost full separator-aligned coverage or counter clearance")
	instance.queue_free()


func _verify_settlement_design(failures: Array[String]) -> void:
	var scene := load("res://scenes/table/MainSceneV2.tscn") as PackedScene
	if scene == null:
		failures.append("main scene could not be loaded")
		return
	var instance := scene.instantiate()
	if not instance.has_method("_build_settlement_panel_style"):
		failures.append("packaged settlement redesign methods are missing")
		instance.queue_free()
		return
	var outer := instance.call("_build_settlement_panel_style") as StyleBoxFlat
	var side := instance.call("_build_settlement_side_style") as StyleBoxFlat
	var detail := instance.call("_build_settlement_detail_style") as StyleBoxFlat
	var hand := instance.call("_build_settlement_hand_style") as StyleBoxFlat
	var hero := instance.call("_build_settlement_hero_style", 10) as StyleBoxFlat
	if outer == null or _border_total(outer) != 4:
		failures.append("settlement outer shell is not the one-pixel single frame")
	for section_style in [side, detail, hand]:
		if section_style == null or _border_total(section_style) != 0:
			failures.append("settlement nested section regained a surrounding frame")
			break
	if hero == null \
			or hero.get_border_width(SIDE_LEFT) != 6 \
			or hero.get_border_width(SIDE_TOP) != 0 \
			or hero.get_border_width(SIDE_RIGHT) != 0 \
			or hero.get_border_width(SIDE_BOTTOM) != 0:
		failures.append("settlement hero lost its single left accent")
	print("PACKAGED_IOS_SETTLEMENT_SINGLE_SHELL ", outer != null and _border_total(outer) == 4)
	print("PACKAGED_IOS_SETTLEMENT_BORDERLESS_SECTIONS ", side != null and detail != null and hand != null and _border_total(side) == 0 and _border_total(detail) == 0 and _border_total(hand) == 0)
	instance.queue_free()


func _border_total(style: StyleBoxFlat) -> int:
	return style.get_border_width(SIDE_LEFT) \
		+ style.get_border_width(SIDE_TOP) \
		+ style.get_border_width(SIDE_RIGHT) \
		+ style.get_border_width(SIDE_BOTTOM)


func _smallest_circular_span_degrees(angles: Array[float]) -> float:
	if angles.size() < 2:
		return 0.0
	angles.sort()
	var largest_gap := 0.0
	for index in range(angles.size()):
		var current_angle := angles[index]
		var next_angle := angles[(index + 1) % angles.size()]
		if index == angles.size() - 1:
			next_angle += TAU
		largest_gap = maxf(largest_gap, next_angle - current_angle)
	return rad_to_deg(TAU - largest_gap)
