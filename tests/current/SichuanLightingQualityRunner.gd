extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")) == "forward_plus", "mobile renderer is the accepted Forward+ path")
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame

	var world := stage.get_node_or_null("ClubWorldEnvironment") as WorldEnvironment
	_check(world != null and world.environment != null, "world environment exists")
	if world != null and world.environment != null:
		var environment := world.environment
		_check(environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "Filmic tonemap remains enabled")
		_check(environment.ambient_light_energy >= 0.22 and environment.ambient_light_energy <= 0.42, "ambient energy stays inside the mobile gate")
		_check(environment.ssao_enabled, "SSAO is enabled")
		_check(environment.ssao_radius >= 0.45 and environment.ssao_radius <= 1.0, "SSAO radius is local")
		_check(environment.ssao_intensity >= 0.65 and environment.ssao_intensity <= 1.25, "SSAO intensity is restrained")
		_check(environment.ssao_power >= 0.8 and environment.ssao_power <= 1.5, "SSAO power is restrained")
		_check(environment.ssao_detail >= 0.25 and environment.ssao_detail <= 0.7, "SSAO detail avoids noise")
		_check(not environment.ssil_enabled, "SSIL remains disabled for mobile")
		_check(not environment.glow_enabled, "full-screen glow remains disabled")

	var key := stage.get_node_or_null("UpperLeftWarmKey") as DirectionalLight3D
	var fill := stage.get_node_or_null("CenterSoftFill") as OmniLight3D
	_check(key != null, "single directional key exists")
	_check(fill != null, "single fill exists")
	if key != null:
		_check(key.shadow_enabled, "key light casts the only real-time shadow")
		_check(key.light_energy >= 0.90 and key.light_energy <= 1.35, "key energy stays inside gate")
		_check(key.shadow_opacity >= 0.88 and key.shadow_opacity <= 1.0, "key shadow opacity stays inside gate")
		_check(key.shadow_blur >= 1.1 and key.shadow_blur <= 2.2, "Compatibility shadow blur is explicit")
		_check(key.light_angular_distance == 0.0, "lighting does not rely on Forward+-only directional PCSS")
		_check(key.directional_shadow_max_distance >= 20.0 and key.directional_shadow_max_distance <= 26.0, "shadow range covers the table only")
		var ray_direction := key.global_basis * Vector3(0.0, 0.0, -1.0)
		_check(ray_direction.y < -0.70, "key light points down onto the table")
		_check(ray_direction.x > 0.05 and ray_direction.z > 0.25, "shadow travel points toward screen right/down")
	if fill != null:
		_check(not fill.shadow_enabled, "fill light never creates a second shadow")
		_check(fill.light_energy >= 1.0 and fill.light_energy <= 2.2, "tile-only fill energy stays inside gate")
		_check(fill.light_cull_mask == 1 << 1, "fill affects the Mahjong tile layer only")

	var light_count := 0
	var shadow_count := 0
	for child in stage.get_children():
		if child is Light3D:
			light_count += 1
			if (child as Light3D).shadow_enabled:
				shadow_count += 1
	_check(light_count == 2, "mobile light budget remains exactly two lights")
	_check(shadow_count == 1, "mobile shadow budget remains exactly one caster")

	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN_LIGHTING_QUALITY_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
