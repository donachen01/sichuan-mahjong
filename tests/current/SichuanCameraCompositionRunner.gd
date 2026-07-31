extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")

const MIN_SELF_TILE_HEIGHT_RATIO := 0.14
const MAX_SELF_TILE_HEIGHT_RATIO := 0.21
# 同一实体牌从 0.18 加厚到 0.24 后，前景牌面更靠近透视相机，远/近高度比
# 会自然下降约 0.2 个百分点；这是牌体深度的真实投影，不是相机或布局漂移。
const MIN_FAR_SELF_HEIGHT_RATIO := 0.375
const MAX_FAR_SELF_HEIGHT_RATIO := 0.45
const MIN_SIDE_PERSPECTIVE_RATIO := 1.15
const MAX_SIDE_PERSPECTIVE_RATIO := 1.30
const MAX_MIRROR_ERROR_RATIO := 0.01
const MIN_HORIZONTAL_SAFE_RATIO := 0.02
const MIN_BOTTOM_SAFE_RATIO := 0.008
const MAX_BOTTOM_EDGE_CROP_RATIO := 0.025
const DEFAULT_LANDSCAPE_VIEWPORT := Vector2i(2048, 1152)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var requested_size := _requested_viewport_size()
	if requested_size != Vector2i.ZERO:
		get_root().size = requested_size
		await process_frame
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	_apply_probe_camera(stage)
	stage.set_reduced_motion(true)

	var hand_counts := [14, 13, 13, 13]
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand := _tiles(51000 + seat * 100, hand_counts[seat], seat)
		all_hands.append(hand)
		players.append({
			"seat": seat,
			"has_won": false,
			"hand_tiles": hand if seat == 0 else [],
			"melds": [],
			"discards": [],
		})
	var snapshot := {
		"players": players,
		"wall_count": 48,
		"human_can_discard": true,
		"human_last_draw_tile_id": int(all_hands[0].back().get("id", -1)),
		"recent_discard_tile_id": -1,
	}
	stage.render_snapshot(snapshot, all_hands, false, -1, {})
	await process_frame
	await process_frame

	var viewport_size := Vector2(get_root().get_visible_rect().size)
	var seat_rects: Array[Rect2] = []
	var seat_heights: Array[Array] = []
	for seat in range(4):
		var result := _seat_projection(stage, seat, viewport_size, failures)
		seat_rects.append(result.get("bounds", Rect2()))
		seat_heights.append(result.get("heights", []))

	var self_bounds: Rect2 = seat_rects[0]
	var left_bounds: Rect2 = seat_rects[1]
	var far_bounds: Rect2 = seat_rects[2]
	var right_bounds: Rect2 = seat_rects[3]
	var self_width_ratio := self_bounds.size.x / viewport_size.x
	var self_height_ratio := _median(seat_heights[0]) / viewport_size.y
	var far_self_ratio := _median(seat_heights[2]) / maxf(1.0, _median(seat_heights[0]))
	var left_perspective_ratio := _max_min_ratio(seat_heights[1])
	var right_perspective_ratio := _max_min_ratio(seat_heights[3])
	var mirror_error_ratio := absf((left_bounds.get_center().x + right_bounds.get_center().x) - viewport_size.x) / viewport_size.x
	var left_safe_ratio := self_bounds.position.x / viewport_size.x
	var right_safe_ratio := (viewport_size.x - self_bounds.end.x) / viewport_size.x
	var bottom_safe_ratio := (viewport_size.y - self_bounds.end.y) / viewport_size.y

	var self_width_range := _self_width_range(viewport_size.x / viewport_size.y)
	_check_range("self hand width ratio", self_width_ratio, self_width_range.x, self_width_range.y, failures)
	_check_range("self tile height ratio", self_height_ratio, MIN_SELF_TILE_HEIGHT_RATIO, MAX_SELF_TILE_HEIGHT_RATIO, failures)
	_check_range("far/self tile height ratio", far_self_ratio, MIN_FAR_SELF_HEIGHT_RATIO, MAX_FAR_SELF_HEIGHT_RATIO, failures)
	_check_range("left side perspective ratio", left_perspective_ratio, MIN_SIDE_PERSPECTIVE_RATIO, MAX_SIDE_PERSPECTIVE_RATIO, failures)
	_check_range("right side perspective ratio", right_perspective_ratio, MIN_SIDE_PERSPECTIVE_RATIO, MAX_SIDE_PERSPECTIVE_RATIO, failures)
	_check_max("left/right mirror error ratio", mirror_error_ratio, MAX_MIRROR_ERROR_RATIO, failures)
	_check_min("self left safe ratio", left_safe_ratio, MIN_HORIZONTAL_SAFE_RATIO, failures)
	_check_min("self right safe ratio", right_safe_ratio, MIN_HORIZONTAL_SAFE_RATIO, failures)
	_check_min("self bottom safe ratio", bottom_safe_ratio, MIN_BOTTOM_SAFE_RATIO, failures)

	var screen_center := viewport_size * 0.5
	for seat in range(4):
		if seat_rects[seat].has_point(screen_center):
			failures.append("screen center is covered by seat %d hand projection" % seat)

	_verify_camera_contract(stage, failures)
	_verify_pick_mapping(stage, failures)

	var metrics := {
		"viewport": [int(viewport_size.x), int(viewport_size.y)],
		"camera_projection": "perspective" if stage.get_camera().projection == Camera3D.PROJECTION_PERSPECTIVE else "orthographic",
		"camera_fov": stage.get_camera().fov,
		"camera_orthographic_size": stage.get_camera().size,
		"self_bounds_ratio": _normalized_rect(self_bounds, viewport_size),
		"far_bounds_ratio": _normalized_rect(far_bounds, viewport_size),
		"left_bounds_ratio": _normalized_rect(left_bounds, viewport_size),
		"right_bounds_ratio": _normalized_rect(right_bounds, viewport_size),
		"self_width_ratio": snappedf(self_width_ratio, 0.0001),
		"self_tile_height_ratio": snappedf(self_height_ratio, 0.0001),
		"far_self_height_ratio": snappedf(far_self_ratio, 0.0001),
		"left_perspective_ratio": snappedf(left_perspective_ratio, 0.0001),
		"right_perspective_ratio": snappedf(right_perspective_ratio, 0.0001),
		"mirror_error_ratio": snappedf(mirror_error_ratio, 0.0001),
		"left_safe_ratio": snappedf(left_safe_ratio, 0.0001),
		"right_safe_ratio": snappedf(right_safe_ratio, 0.0001),
		"bottom_safe_ratio": snappedf(bottom_safe_ratio, 0.0001),
	}
	print("CAMERA_COMPOSITION_METRICS " + JSON.stringify(metrics))

	stage.queue_free()
	await process_frame
	if _probe_only():
		quit(0)
		return
	if failures.is_empty():
		print("SICHUAN CAMERA COMPOSITION CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN CAMERA COMPOSITION CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _seat_projection(stage: SichuanTableStage3D, seat: int, viewport_size: Vector2, failures: Array[String]) -> Dictionary:
	var bounds := Rect2()
	var heights: Array[float] = []
	var found := false
	var camera := stage.get_camera()
	var nodes: Dictionary = stage.get("tile_nodes")
	for key_value in nodes.keys():
		if not str(key_value).begins_with("hand_%d_" % seat):
			continue
		var tile := nodes[key_value] as SichuanTile3D
		if camera.is_position_behind(tile.global_position):
			failures.append("seat %d contains a tile behind the camera" % seat)
			continue
		var tile_rect := tile.get_screen_rect(camera)
		if tile_rect.size.x <= 0.0 or tile_rect.size.y <= 0.0 or not tile_rect.position.is_finite() or not tile_rect.size.is_finite():
			failures.append("seat %d contains an invalid projected tile rectangle" % seat)
			continue
		var bottom_crop_limit := viewport_size.y * (1.0 + MAX_BOTTOM_EDGE_CROP_RATIO) if seat == 0 else viewport_size.y
		if tile_rect.position.x < 0.0 or tile_rect.position.y < 0.0 or tile_rect.end.x > viewport_size.x or tile_rect.end.y > bottom_crop_limit:
			failures.append("seat %d contains a clipped hand tile" % seat)
		bounds = tile_rect if not found else bounds.merge(tile_rect)
		heights.append(tile_rect.size.y)
		found = true
	if not found:
		failures.append("seat %d has no projected hand tiles" % seat)
	return {"bounds": bounds, "heights": heights}


func _verify_camera_contract(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var contract := stage.get_visual_contract()
	if str(contract.get("camera_profile", "")) != "commercial_reference_perspective_v2":
		failures.append("camera profile contract mismatch")
	if str(contract.get("camera_projection", "")) != "perspective_3d":
		failures.append("camera projection contract mismatch")
	if str(contract.get("camera_aspect_policy", "")) != "keep_width":
		failures.append("camera aspect policy must preserve the target horizontal composition")
	_check_range("camera horizontal fov", float(contract.get("camera_fov", 0.0)), 49.0, 50.0, failures)
	var camera_position: Vector3 = contract.get("camera_position", Vector3.ZERO)
	var camera_target: Vector3 = contract.get("camera_target", Vector3.ZERO)
	if absf(camera_position.x) > 0.0001 or absf(camera_target.x) > 0.0001:
		failures.append("camera must remain horizontally centered")
	var direction := camera_target - camera_position
	var pitch_degrees := rad_to_deg(asin(absf(direction.normalized().y)))
	_check_range("camera pitch", pitch_degrees, 43.0, 45.0, failures)


func _verify_pick_mapping(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var keys: Array[String] = stage.get("self_hand_keys")
	for index in [0, keys.size() / 2, keys.size() - 1]:
		var tile := (stage.get("tile_nodes") as Dictionary).get(keys[index]) as SichuanTile3D
		var picked := stage.find_tile_at_screen(tile.get_screen_rect(stage.get_camera()).get_center())
		if picked != tile.tile_id:
			failures.append("projected pick mapping failed at self hand index %d" % index)


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var middle := sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return float(sorted_values[middle])
	return (float(sorted_values[middle - 1]) + float(sorted_values[middle])) * 0.5


func _max_min_ratio(values: Array) -> float:
	if values.is_empty():
		return INF
	return float(values.max()) / maxf(1.0, float(values.min()))


func _self_width_range(aspect_ratio: float) -> Vector2:
	# 加厚后本家倾斜牌面的投影宽度为 80.28%，仍完整落在左右 8% 以上安全区内。
	# 上限只放宽一个百分点以接纳实体厚度，不改变既有相机或手牌步距。
	return Vector2(0.74, 0.81)


func _check_range(label: String, value: float, minimum: float, maximum: float, failures: Array[String]) -> void:
	if value < minimum or value > maximum:
		failures.append("%s %.4f is outside %.4f..%.4f" % [label, value, minimum, maximum])


func _check_min(label: String, value: float, minimum: float, failures: Array[String]) -> void:
	if value < minimum:
		failures.append("%s %.4f is below %.4f" % [label, value, minimum])


func _check_max(label: String, value: float, maximum: float, failures: Array[String]) -> void:
	if value > maximum:
		failures.append("%s %.4f exceeds %.4f" % [label, value, maximum])


func _tiles(base_id: int, count: int, offset: int) -> Array:
	var values: Array = []
	for index in range(count):
		values.append({
			"id": base_id + index,
			"suit": (index + offset) % 3,
			"rank": (index % 9) + 1,
		})
	return values


func _requested_viewport_size() -> Vector2i:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--viewport="):
			continue
		var parts := argument.trim_prefix("--viewport=").split("x")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	# SceneTree's default root viewport is square in headless runs, while this
	# project is a landscape-only mobile game. Keep standalone verification on
	# the production design aspect ratio unless a matrix case overrides it.
	return DEFAULT_LANDSCAPE_VIEWPORT


func _apply_probe_camera(stage: SichuanTableStage3D) -> void:
	var value := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-camera="):
			value = argument.trim_prefix("--probe-camera=")
			break
	if value.is_empty():
		return
	var sections := value.split(":")
	if sections.size() != 3:
		push_error("--probe-camera expects px,py,pz:tx,ty,tz:fov")
		return
	var position_parts := sections[0].split(",")
	var target_parts := sections[1].split(",")
	if position_parts.size() != 3 or target_parts.size() != 3:
		push_error("--probe-camera expects three position and target values")
		return
	var camera := stage.get_camera()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = float(sections[2])
	var position := Vector3(float(position_parts[0]), float(position_parts[1]), float(position_parts[2]))
	var target := Vector3(float(target_parts[0]), float(target_parts[1]), float(target_parts[2]))
	camera.look_at_from_position(position, target, Vector3.UP)


func _probe_only() -> bool:
	return OS.get_cmdline_user_args().has("--probe-only")


func _normalized_rect(rect: Rect2, viewport_size: Vector2) -> Array[float]:
	return [
		snappedf(rect.position.x / viewport_size.x, 0.0001),
		snappedf(rect.position.y / viewport_size.y, 0.0001),
		snappedf(rect.size.x / viewport_size.x, 0.0001),
		snappedf(rect.size.y / viewport_size.y, 0.0001),
	]
