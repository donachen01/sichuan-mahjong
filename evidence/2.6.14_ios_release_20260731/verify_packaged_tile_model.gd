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
	var scene := load("res://res/art/3d/mahjong_tile_body.glb") as PackedScene
	if scene == null:
		push_error("Packaged Mahjong tile model could not be loaded")
		quit(1)
		return
	var instance := scene.instantiate()
	get_root().add_child(instance)
	await process_frame
	var bounds := AABB()
	var has_mesh := false
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var child_bounds := mesh_instance.get_aabb()
		bounds = child_bounds if not has_mesh else bounds.merge(child_bounds)
		has_mesh = true
	var size := bounds.size
	print("PACKAGED_IOS_TILE_SIZE ", size)
	if not has_mesh or not size.is_equal_approx(Vector3(0.42, 0.24, 0.58)):
		push_error("Packaged iOS tile model is not the shared 0.42x0.24x0.58 geometry")
		quit(1)
		return
	print("PACKAGED_IOS_TILE_MODEL_PASS")
	quit(0)
