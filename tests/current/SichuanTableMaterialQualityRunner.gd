extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const EPSILON := 0.02

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame

	var table := stage.get_node_or_null("ManufacturedClubTable") as Node3D
	_check(table != null, "manufactured table exists")
	if table != null:
		_check_vector3(table.scale, Vector3(1.0, 1.0, 1.60), "accepted elongated table scale")
		_check(absf(table.position.z + 2.30) <= EPSILON, "accepted table depth position")
		_verify_textured_frame(table, "TableFrame", Vector3(14.8, 0.56, 9.6))
		_verify_mesh(table, "TableFelt", Vector3(13.9, 0.34, 8.7), Color("08705A"), 0.86, 0.0)
		for inset_name in ["CopperTop", "CopperBottom", "CopperLeft", "CopperRight"]:
			_verify_inset(table, inset_name)

	var woven_felt := stage.get_node_or_null("FullSurfaceReferenceGreenFelt") as MeshInstance3D
	_check(woven_felt != null, "full-surface reference-green woven felt layer exists")
	if woven_felt != null:
		var plane := woven_felt.mesh as PlaneMesh
		_check(plane != null, "woven felt uses a real plane mesh")
		if plane != null:
			_check_vector2(plane.size, Vector2(13.55, 13.40), "woven texture covers the complete felt")
		_check(woven_felt.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "woven overlay never casts shadows")
		_check(absf(woven_felt.position.y - 0.051) <= 0.002, "woven overlay sits above the felt without z-fighting")
		var material := woven_felt.material_override as ShaderMaterial
		_check(material != null and material.shader != null, "reference-green felt shader material exists")
		if material != null and material.shader != null:
			var code := material.shader.code
			_check("0.86, 0.94" in code, "woven felt roughness remains inside the 0.86-0.94 gate")
			_check("fine_weave" in code and "warp" in code and "weft" in code, "tabletop uses crossed Retina-scale threads")
			_check("cloud_scroll" in code and "ring_line" in code and "edge_mask" in code, "tabletop includes restrained peripheral embossed cloud scrolls")
			_check("centre_lift" in code and "edge_emerald" in code and "center_emerald" in code, "reference emerald centre-to-edge colour model is present")
			_check("微乐" not in code, "reference material must not contain the source logo text")

	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN_TABLE_MATERIAL_QUALITY_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_mesh(
	root: Node,
	mesh_name: String,
	expected_size: Vector3,
	expected_color: Color,
	expected_roughness: float,
	expected_metallic: float
) -> void:
	var mesh_instance := _find_mesh(root, mesh_name)
	_check(mesh_instance != null, "%s mesh exists" % mesh_name)
	if mesh_instance == null:
		return
	var actual_size := mesh_instance.mesh.get_aabb().size
	_check_vector3(actual_size, expected_size, "%s physical dimensions" % mesh_name)
	var material := mesh_instance.material_override as StandardMaterial3D
	_check(material != null, "%s material override exists" % mesh_name)
	if material != null:
		_check_color(material.albedo_color, expected_color, "%s calibrated source color" % mesh_name)
		_check(absf(material.roughness - expected_roughness) <= 0.01, "%s roughness" % mesh_name)
		_check(absf(material.metallic - expected_metallic) <= 0.01, "%s metallic" % mesh_name)


func _verify_textured_frame(root: Node, mesh_name: String, expected_size: Vector3) -> void:
	var mesh_instance := _find_mesh(root, mesh_name)
	_check(mesh_instance != null, "%s mesh exists" % mesh_name)
	if mesh_instance == null:
		return
	_check_vector3(mesh_instance.mesh.get_aabb().size, expected_size, "%s physical dimensions" % mesh_name)
	var material := mesh_instance.material_override as ShaderMaterial
	_check(material != null and material.shader != null, "%s uses the dedicated high-resolution rail shader" % mesh_name)
	if material != null and material.shader != null:
		var code := material.shader.code
		_check("rail_local_position * vec3(46.0, 62.0, 46.0)" in code, "%s texture density is resolution-independent" % mesh_name)
		_check("leather_grain" in code and "crossed_thread" in code, "%s combines grain and woven-thread relief" % mesh_name)
		_check("0.018, 0.160, 0.126" in code, "%s preserves the calibrated deep-emerald source color" % mesh_name)


func _verify_inset(root: Node, mesh_name: String) -> void:
	var mesh_instance := _find_mesh(root, mesh_name)
	_check(mesh_instance != null, "%s inset exists" % mesh_name)
	if mesh_instance == null:
		return
	var material := mesh_instance.material_override as StandardMaterial3D
	_check(material != null, "%s material override exists" % mesh_name)
	if material != null:
		_check_color(material.albedo_color, Color("075845"), "%s restrained emerald-metal color" % mesh_name)
		_check(material.metallic >= 0.25 and material.metallic <= 0.55, "%s metallic is restrained" % mesh_name)
		_check(absf(material.roughness - 0.38) <= 0.01, "%s roughness" % mesh_name)


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


func _check_color(actual: Color, expected: Color, message: String) -> void:
	_check(
		absf(actual.r - expected.r) <= 0.002
		and absf(actual.g - expected.g) <= 0.002
		and absf(actual.b - expected.b) <= 0.002,
		message
	)


func _check_vector2(actual: Vector2, expected: Vector2, message: String) -> void:
	_check(absf(actual.x - expected.x) <= EPSILON and absf(actual.y - expected.y) <= EPSILON, message)


func _check_vector3(actual: Vector3, expected: Vector3, message: String) -> void:
	_check(
		absf(actual.x - expected.x) <= EPSILON
		and absf(actual.y - expected.y) <= EPSILON
		and absf(actual.z - expected.z) <= EPSILON,
		"%s: actual=%s expected=%s" % [message, actual, expected]
	)
