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

	var scene := load("res://res/art/3d/sichuan_center_compass_v2.glb") as PackedScene
	if scene == null:
		push_error("Packaged center model could not be loaded")
		quit(1)
		return
	var instance := scene.instantiate() as Node3D
	get_root().add_child(instance)
	await process_frame

	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var active_sector_count := 0
	var triangle_count := 0
	var minimum_active_vertex_radius := INF
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		triangle_count += mesh_instance.mesh.get_faces().size() / 3
		if not str(mesh_instance.name).begins_with("DirectionActive"):
			continue
		active_sector_count += 1
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for local_vertex in vertices:
				var world_vertex: Vector3 = mesh_instance.global_transform * local_vertex
				minimum_active_vertex_radius = minf(
					minimum_active_vertex_radius,
					Vector2(world_vertex.x, world_vertex.z).length()
				)

	print("PACKAGED_IOS_CENTER_OBJECTS ", meshes.size())
	print("PACKAGED_IOS_CENTER_TRIANGLES ", triangle_count)
	print("PACKAGED_IOS_CENTER_ACTIVE_MIN_RADIUS %.4f" % minimum_active_vertex_radius)
	if meshes.size() != 9 \
			or triangle_count != 1044 \
			or active_sector_count != 4 \
			or minimum_active_vertex_radius < 0.458 \
			or instance.find_child("CounterBronzeBezel", true, false) == null \
			or instance.find_child("CenterBronzeKeyline", true, false) != null:
		push_error("Packaged iOS center model lost its circular counter clearance contract")
		quit(1)
		return
	print("PACKAGED_IOS_CENTER_MODEL_PASS")
	quit(0)
