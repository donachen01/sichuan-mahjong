extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const EPSILON := 0.025
const TEXTURE_ROOT := "res://res/art/materials/table_v2/"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_texture_kit()
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame

	var table := stage.get_node_or_null("ManufacturedClubTable") as Node3D
	_check(table != null, "Deep Emerald manufactured table exists")
	if table != null:
		_check_vector3(table.scale, Vector3(1.0, 1.0, 1.60), "accepted table scale")
		_check(absf(table.position.z + 2.30) <= EPSILON, "accepted table depth position")
		_verify_mesh(table, "TableWalnutBase", Vector3(14.8, 0.56, 9.6), "WarmWalnutFrame")
		_verify_mesh(table, "TableFelt", Vector3(13.38, 0.31, 8.18), "DeepEmeraldShortNapFelt")
		_verify_material_family(table, "WalnutApronRing", "WarmWalnutFrame")
		_check(table.find_child("WalnutLongitudinalGrain", true, false) == null, "raised dark grain lines are removed from the walnut frame")
		_verify_material_family(table, "LeatherGasketRing", "InkGreenLeather")
		for retired_trim_name in [
			"WalnutApronTop", "WalnutApronBottom", "WalnutApronLeft", "WalnutApronRight",
			"CopperInlayTop", "CopperInlayBottom", "CopperInlayLeft", "CopperInlayRight",
			"LeatherStitchesTop", "LeatherStitchesBottom", "LeatherStitchesLeft", "LeatherStitchesRight"
		]:
			_check(table.find_child(retired_trim_name, true, false) == null, "%s retired without leaving a visible seam" % retired_trim_name)
		for groove_name in [
			"PlayfieldGrooveTop", "PlayfieldGrooveBottom", "PlayfieldGrooveLeft", "PlayfieldGrooveRight",
			"CenterGrooveTop", "CenterGrooveBottom", "CenterGrooveLeft", "CenterGrooveRight"
		]:
			_verify_material_family(table, groove_name, "PlayfieldRecessedGroove")
			var groove := table.find_child(groove_name, true, false) as MeshInstance3D
			if groove != null:
				var groove_top := groove.position.y + groove.get_aabb().size.y * 0.5
				_check(groove_top <= 0.157, "%s must remain embedded as a felt dark-weave hairline" % groove_name)
		_verify_triangle_budget(table)
		_verify_no_flat_overrides(table)

	_check(stage.get_node_or_null("FullSurfaceReferenceGreenFelt") == null, "legacy procedural felt overlay is removed")
	var contract: Dictionary = stage.call("get_last_contract") if stage.has_method("get_last_contract") else {}
	if contract.is_empty():
		stage.call("render_snapshot", {"players": [], "wall_count": 55}, [[], [], [], []], false, -1)
		contract = stage.call("get_last_contract") if stage.has_method("get_last_contract") else stage.get("last_contract")
	_check(str(contract.get("table_asset", "")) == "sichuan_table_v2_pbr", "stage exposes the V2 PBR asset")
	_check(str(contract.get("table_material_pipeline", "")) == "blender_pbr_preserved_without_flat_overrides", "stage exposes preserved Blender PBR pipeline")
	_check(
		str(contract.get("table_surface_finish", "")) == "clean_uniform_short_nap_felt_with_directional_microfibre_normals",
		"stage exposes the dense directional velvet surface contract"
	)
	_check(
		str(contract.get("table_divider_finish", "")) == "subsurface_low_contrast_felt_dark_weave",
		"stage exposes the subdued felt-divider contract"
	)

	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN_TABLE_MATERIAL_QUALITY_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_texture_kit() -> void:
	var specs := {
		"felt_basecolor.png": Vector2i(2048, 2048),
		"felt_normal.png": Vector2i(2048, 2048),
		"felt_orm.png": Vector2i(2048, 2048),
		"brocade_mask.png": Vector2i(2048, 2048),
		"leather_basecolor.png": Vector2i(1024, 1024),
		"leather_normal.png": Vector2i(1024, 1024),
		"leather_orm.png": Vector2i(1024, 1024),
		"walnut_basecolor.png": Vector2i(1024, 1024),
		"walnut_normal.png": Vector2i(1024, 1024),
		"walnut_orm.png": Vector2i(1024, 1024),
	}
	for file_name in specs:
		var path := TEXTURE_ROOT + str(file_name)
		_check(ResourceLoader.exists(path), "%s is imported" % path)
		var texture := load(path) as Texture2D
		if texture == null:
			failures.append("%s failed to load as Texture2D" % path)
			continue
		var expected: Vector2i = specs[file_name]
		_check(texture.get_width() == expected.x and texture.get_height() == expected.y, "%s size is %s" % [file_name, expected])


func _verify_mesh(root: Node, mesh_name: String, expected_size: Vector3, material_family: String) -> void:
	var mesh := _find_mesh(root, mesh_name)
	_check(mesh != null, "%s mesh exists" % mesh_name)
	if mesh == null:
		return
	_check_vector3(mesh.mesh.get_aabb().size, expected_size, "%s physical dimensions" % mesh_name)
	_verify_surface_material(mesh, material_family)


func _verify_material_family(root: Node, mesh_name: String, family: String) -> void:
	var mesh := _find_mesh(root, mesh_name)
	_check(mesh != null, "%s mesh exists" % mesh_name)
	if mesh != null:
		_verify_surface_material(mesh, family)


func _verify_surface_material(mesh: MeshInstance3D, expected_family: String) -> void:
	_check(mesh.material_override == null, "%s has no runtime material override" % mesh.name)
	var material := mesh.mesh.surface_get_material(0)
	_check(material != null, "%s has an imported surface material" % mesh.name)
	if material != null:
		_check(expected_family.to_lower() in material.resource_name.to_lower(), "%s material family is %s" % [mesh.name, expected_family])


func _verify_no_flat_overrides(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			_check((child as MeshInstance3D).material_override == null, "%s does not flatten imported PBR" % child.name)
		_verify_no_flat_overrides(child)


func _verify_triangle_budget(root: Node) -> void:
	var triangles := _triangle_count(root)
	_check(triangles >= 8000 and triangles <= 20000, "continuous-ring table triangle budget is 8k-20k, actual=%d" % triangles)


func _triangle_count(root: Node) -> int:
	var total := 0
	if root is MeshInstance3D:
		var mesh := (root as MeshInstance3D).mesh
		for surface in range(mesh.get_surface_count()):
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var index_count: int = mesh.surface_get_array_index_len(surface)
			total += index_count / 3 if index_count > 0 else mesh.surface_get_array_len(surface) / 3
	for child in root.get_children():
		total += _triangle_count(child)
	return total


func _find_mesh(root: Node, target_name: String) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == target_name:
		return root as MeshInstance3D
	for child in root.get_children():
		var result := _find_mesh(child, target_name)
		if result != null:
			return result
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _check_vector3(actual: Vector3, expected: Vector3, message: String) -> void:
	_check(
		absf(actual.x - expected.x) <= EPSILON
		and absf(actual.y - expected.y) <= EPSILON
		and absf(actual.z - expected.z) <= EPSILON,
		"%s: actual=%s expected=%s" % [message, actual, expected]
	)
