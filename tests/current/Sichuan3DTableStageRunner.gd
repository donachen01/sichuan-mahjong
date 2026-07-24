extends SceneTree

const STAGE_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var stage := STAGE_SCRIPT.new() as SichuanTableStage3D
	get_root().add_child(stage)
	await process_frame
	await process_frame
	stage.set_reduced_motion(true)

	var hand_counts := [11, 10, 10, 10]
	var discard_counts := [10, 9, 10, 9]
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand := _tiles(10000 + seat * 100, hand_counts[seat], seat)
		var discards := _tiles(20000 + seat * 100, discard_counts[seat], seat + 1)
		var meld_tile_count := 4 if seat == 2 else 3
		var meld_tiles := _tiles(30000 + seat * 100, meld_tile_count, seat + 2)
		all_hands.append(hand)
		players.append({
			"seat": seat,
			"has_won": false,
			"ding_que": "wan" if seat == 0 else "",
			"hand_tiles": hand if seat == 0 else [],
			"melds": [{
				"type": "gang" if seat == 2 else "peng",
				"gang_subtype": "an_gang" if seat == 2 else "",
				"from_seat": seat if seat == 2 else (seat + 1) % 4,
				"tiles": meld_tiles,
			}],
			"discards": discards,
		})
	var latest: Dictionary = players[3]["discards"].back()
	var snapshot := {
		"players": players,
		"wall_count": 40,
		"human_can_discard": true,
		"human_last_draw_tile_id": int(all_hands[0].back().get("id", -1)),
		"recent_discard_tile_id": int(latest.get("id", -1)),
	}
	stage.render_snapshot(snapshot, all_hands, false, int(all_hands[0][1].get("id", -1)), {
		"recommended_tile_id": int(all_hands[0][2].get("id", -1)),
		"danger_tile_ids": [int(all_hands[0][8].get("id", -1))],
	})
	await process_frame
	_verify_contract(stage, hand_counts, discard_counts, failures)
	_verify_hidden_hands(stage, failures)
	_verify_hand_surface_and_upright_pose(stage, failures)
	_verify_no_physical_wall(stage, failures)
	_verify_readability_geometry(stage, failures)
	_verify_human_orientation(stage, failures)
	_verify_concealed_gang(stage, failures)
	_verify_target_reference_hand_anchors(stage, failures)
	_verify_latest_marker(stage, failures)
	_verify_new_draw_marker(stage, snapshot["human_last_draw_tile_id"], failures)
	_verify_selected_marker(stage, int(all_hands[0][1].get("id", -1)), failures)
	_verify_human_ding_que_rightmost(stage, "wan", failures)
	_verify_side_meld_axes(stage, failures)
	_verify_meld_source_arrows(stage, failures)
	_verify_right_meld_matches_hand_direction(stage, failures)
	_verify_far_meld_ownership_zone(stage, failures)
	_verify_discard_row_clearance(stage, discard_counts, failures)
	_verify_pick_mapping(stage, failures)
	_verify_assets(failures)

	for ding_que_suit in ["tiao", "tong", "wan"]:
		var sort_players: Array = players.duplicate(true)
		sort_players[0]["ding_que"] = ding_que_suit
		var sort_snapshot := snapshot.duplicate(true)
		sort_snapshot["players"] = sort_players
		stage.render_snapshot(sort_snapshot, all_hands, false, -1, {})
		await process_frame
		_verify_human_ding_que_rightmost(stage, ding_que_suit, failures)
		_verify_pick_mapping(stage, failures)

	await _verify_side_meld_pressure(stage, snapshot, all_hands, failures)
	stage.render_snapshot(snapshot, all_hands, false, -1, {})
	await process_frame

	stage.render_snapshot(snapshot, all_hands, true, -1, {})
	await process_frame
	_verify_revealed_hands(stage, failures)
	_verify_ai_face_orientation(stage, failures)
	_verify_dynamic_snapshot_reconfiguration(stage, failures)

	var won_players: Array = players.duplicate(true)
	won_players[0]["has_won"] = true
	won_players[0]["winning_tile"] = all_hands[0].back()
	won_players[0]["winning_source_seat"] = 1
	var won_snapshot := snapshot.duplicate(true)
	won_snapshot["players"] = won_players
	won_snapshot["human_can_discard"] = false
	stage.render_snapshot(won_snapshot, all_hands, false, -1, {})
	await process_frame
	_verify_won_hand_and_source_arrow(stage, hand_counts[0], failures)

	var self_draw_players: Array = players.duplicate(true)
	self_draw_players[0]["has_won"] = true
	self_draw_players[0]["winning_tile"] = all_hands[0].back()
	self_draw_players[0]["winning_source_seat"] = 0
	var self_draw_snapshot := snapshot.duplicate(true)
	self_draw_snapshot["players"] = self_draw_players
	self_draw_snapshot["human_can_discard"] = false
	stage.render_snapshot(self_draw_snapshot, all_hands, false, -1, {})
	await process_frame
	_verify_human_self_draw_full_hand(stage, all_hands[0], failures)

	for ai_self_draw_seat in [1, 2, 3]:
		var ai_self_draw_players: Array = players.duplicate(true)
		ai_self_draw_players[ai_self_draw_seat]["has_won"] = true
		ai_self_draw_players[ai_self_draw_seat]["winning_tile"] = all_hands[ai_self_draw_seat].back()
		ai_self_draw_players[ai_self_draw_seat]["winning_source_seat"] = ai_self_draw_seat
		var ai_self_draw_snapshot := snapshot.duplicate(true)
		ai_self_draw_snapshot["players"] = ai_self_draw_players
		ai_self_draw_snapshot["human_can_discard"] = false
		stage.render_snapshot(ai_self_draw_snapshot, all_hands, false, -1, {})
		await process_frame
		_verify_ai_self_draw_full_hand(stage, ai_self_draw_seat, all_hands[ai_self_draw_seat], failures)

	var ai_won_players: Array = players.duplicate(true)
	ai_won_players[1]["has_won"] = true
	ai_won_players[1]["winning_tile"] = all_hands[1].back()
	ai_won_players[1]["winning_source_seat"] = 0
	var ai_won_snapshot := snapshot.duplicate(true)
	ai_won_snapshot["players"] = ai_won_players
	ai_won_snapshot["human_can_discard"] = false
	stage.render_snapshot(ai_won_snapshot, all_hands, false, -1, {})
	await process_frame
	_verify_ai_discard_win_with_preserved_hand(stage, 1, hand_counts[1] - 1, failures)
	await _verify_ai_discard_win_stress(stage, snapshot, ai_won_snapshot, all_hands, failures)
	for ai_seat in [2, 3]:
		var another_won_players: Array = players.duplicate(true)
		another_won_players[ai_seat]["has_won"] = true
		another_won_players[ai_seat]["winning_tile"] = all_hands[ai_seat].back()
		another_won_players[ai_seat]["winning_source_seat"] = 0
		var another_snapshot := snapshot.duplicate(true)
		another_snapshot["players"] = another_won_players
		another_snapshot["human_can_discard"] = false
		stage.render_snapshot(another_snapshot, all_hands, false, -1, {})
		await process_frame
		_verify_ai_discard_win_with_preserved_hand(stage, ai_seat, hand_counts[ai_seat] - 1, failures)

	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN 3D TABLE STAGE CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN 3D TABLE STAGE CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_contract(stage: SichuanTableStage3D, hand_counts: Array, discard_counts: Array, failures: Array[String]) -> void:
	var contract := stage.get_visual_contract()
	if str(contract.get("mode", "")) != "hybrid_3d_world_2d_hud":
		failures.append("3D stage mode contract mismatch")
	if contract.get("hand_counts", []) != hand_counts:
		failures.append("four-seat hand counts were not rendered exactly")
	if contract.get("discard_counts", []) != discard_counts:
		failures.append("four-seat discard counts were not rendered exactly")
	if contract.get("meld_tile_counts", []) != [3, 3, 4, 3]:
		failures.append("four-seat meld tiles were not rendered exactly")
	if int(contract.get("wall_count", -1)) != 40:
		failures.append("numeric wall count does not match snapshot")
	if int(contract.get("rendered_wall_tile_count", -1)) != 0 or str(contract.get("wall_representation", "")) != "numeric_counter_only":
		failures.append("undrawn wall must be represented by the center number only")
	if int(contract.get("self_pickable_count", -1)) != hand_counts[0]:
		failures.append("every self-hand tile must remain pickable")
	if int(contract.get("light_count", -1)) != 2 or int(contract.get("shadow_casting_light_count", -1)) != 1:
		failures.append("mobile lighting budget must be two lights with one shadow caster")
	if int(contract.get("physics_tiles", -1)) != 0:
		failures.append("tile presentation must not use per-tile physics")
	if int(contract.get("tripo_calls", -1)) != 0:
		failures.append("V1 precise core assets must consume zero Tripo calls")
	if float(contract.get("self_hand_scale", 0.0)) < 1.60 or float(contract.get("opponent_hand_scale", 0.0)) < 1.40:
		failures.append("mobile readability scale is below the enlarged tile threshold")
	if str(contract.get("opponent_hand_pose", "")) != "standing_concealed":
		failures.append("AI concealed hands must use a standing presentation")
	var opponent_tilt := float(contract.get("opponent_rack_tilt_degrees", 0.0))
	var far_tilt := float(contract.get("far_rack_tilt_degrees", 0.0))
	if absf(opponent_tilt - 90.0) > 0.01 or absf(far_tilt - 90.0) > 0.01:
		failures.append("all three AI racks must remain exactly 90 degrees to the table")
	if str(contract.get("self_hand_pose", "")) != "standing_concealed":
		failures.append("human concealed hand must use a standing presentation")
	if str(contract.get("self_draw_hand_pose", "")) != "human_face_up_with_draw_marker_ai_flat_concealed_back":
		failures.append("self-draw hand must distinguish human reveal from AI concealed results")
	if str(contract.get("opponent_reveal_pose", "")) != "three_flat_face_up_hands":
		failures.append("opponent reveal mode must expose all three hands face-up")
	if str(contract.get("opponent_back_material", "")) != "shared_shaded_jade":
		failures.append("three opponent backs must share one shaded jade material")
	if str(contract.get("discard_win_hand_pose", "")) != "flat_revealed_for_human":
		failures.append("human discard-win hand must preserve the revealed result contract")
	if str(contract.get("ai_discard_win_presentation", "")) != "standing_hand_plus_adjacent_winning_tile":
		failures.append("AI discard wins must preserve the rack and append the claimed tile")
	if absf(float(contract.get("opponent_hand_face_rotation_degrees", 0.0)) - 180.0) > 0.01:
		failures.append("AI hand face content must be rotated 180 degrees toward its owner")
	if str(contract.get("opponent_concealed_owner_surface", "")) != "warm_ivory_front":
		failures.append("AI concealed owner-facing surface must remain warm ivory")
	if str(contract.get("side_concealed_top_tilt", "")) != "perpendicular_to_table":
		failures.append("AI concealed hands must remain perpendicular to the table")
	if str(contract.get("self_hand_lighting", "")) != "unshaded_discard_white_face":
		failures.append("human hand lost its discard-white brightness contract")
	if str(contract.get("self_meld_zone", "")) != "left_of_concealed_hand":
		failures.append("human melds must occupy the lower-left slot beside the concealed hand")
	if int(contract.get("self_meld_tile_count", -1)) != 3:
		failures.append("human meld pressure was not included in the hand anchor")
	if absf(float(contract.get("self_hand_center_x", 0.0)) - 1.39) > 0.01:
		failures.append("human hand did not shift right by the accepted meld-space formula")
	if str(contract.get("human_ding_que_sort", "")) != "rightmost_then_rank_then_tile_id":
		failures.append("3D human hand lost the rightmost ding-que sort contract")
	if str(contract.get("new_draw_feedback", "")) != "rotating_gold_cone_only":
		failures.append("3D hand still uses a color block instead of the draw cone contract")
	if str(contract.get("selected_tile_feedback", "")) != "floating_warm_jade_hand_only":
		failures.append("selected tile does not expose the hand-pointer contract")
	if str(contract.get("latest_discard_feedback", "")) != "rotating_green_diamond_directly_above_tile":
		failures.append("latest discard does not expose the green-diamond contract")
	if str(contract.get("side_meld_layout", "")) != "single_side_rail_with_group_gaps":
		failures.append("side melds lost the single owner-aligned rail contract")
	var discard_row_step := float(contract.get("discard_row_step", 0.0))
	if discard_row_step < 0.72 or discard_row_step > 0.78:
		failures.append("discard row pitch does not clear the 1.16x tile footprint")
	if str(contract.get("right_meld_axis", "")) != "same_yaw_and_z_flow_as_right_hand":
		failures.append("right-player meld direction contract is missing")
	if str(contract.get("far_meld_zone", "")) != "below_far_hand_not_right_player_band":
		failures.append("far-player meld ownership zone contract is missing")
	if str(contract.get("meld_source_feedback", "")) != "compact_blue_second_tile_arrow_and_seat_label":
		failures.append("peng/gang source feedback must use the compact blue centre-arrow contract")
	if str(contract.get("season_theme", "")) != "reference_emerald_mobile":
		failures.append("3D stage did not expose the reference-emerald visual contract")
	if str(contract.get("concealed_gang_presentation", "")) != "four_distinct_face_down_jade_tiles":
		failures.append("concealed kong contract must guarantee four distinct face-down tiles")
	if str(contract.get("camera_profile", "")) != "commercial_reference_perspective_v2":
		failures.append("3D stage camera profile contract mismatch")
	if str(contract.get("camera_projection", "")) != "perspective_3d":
		failures.append("3D stage camera projection contract mismatch")
	if str(contract.get("camera_aspect_policy", "")) != "keep_width":
		failures.append("3D stage camera must preserve the target horizontal composition")
	var center_world_z := float(contract.get("center_indicator_world_z", 0.0))
	var discard_shift := float(contract.get("discard_global_z_shift", 0.0))
	if center_world_z > -1.45 or center_world_z < -1.75:
		failures.append("center indicator is outside the target-reference upward anchor")
	if absf(discard_shift - center_world_z) > 0.01:
		failures.append("all discard regions must share the center panel's upward translation")
	var camera_fov := float(contract.get("camera_fov", 0.0))
	if camera_fov < 49.0 or camera_fov > 50.0:
		failures.append("3D stage horizontal FOV is outside the camera reconstruction gate")


func _verify_hidden_hands(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	for seat in range(4):
		for key_value in nodes.keys():
			var key := str(key_value)
			if not key.begins_with("hand_%d_" % seat):
				continue
			var tile := nodes[key_value] as SichuanTile3D
			var expected := seat == 0
			if tile.showing_face != expected:
				failures.append("opponent reveal-off state mismatch for seat %d" % seat)
				return


func _verify_revealed_hands(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	for key_value in nodes.keys():
		var key := str(key_value)
		if not key.begins_with("hand_"):
			continue
		var tile := nodes[key_value] as SichuanTile3D
		if not tile.showing_face:
			failures.append("reveal-on state must show all four hands")
			return
		var seat := int(key.split("_")[1])
		if seat != 0:
			if absf(tile.transform.basis.z.y) >= 0.05:
				failures.append("revealed opponent seat %d must lay face-up instead of showing a 90-degree edge/back" % seat)
				return
			if not tile.symbol_mesh.visible:
				failures.append("revealed opponent seat %d did not expose its tile symbol" % seat)
				return


func _verify_ai_face_orientation(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	for seat in range(4):
		for key_value in nodes.keys():
			if not str(key_value).begins_with("hand_%d_" % seat):
				continue
			var tile := nodes[key_value] as SichuanTile3D
			var expected := 0.0 if seat == 0 else PI
			if absf(tile.symbol_mesh.rotation.y - expected) > 0.01:
				failures.append("seat %d hand face content is not oriented toward its owner" % seat)
			break


func _verify_hand_surface_and_upright_pose(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	for key_value in nodes.keys():
		if str(key_value).begins_with("hand_0_"):
			var human_tile := nodes[key_value] as SichuanTile3D
			if not human_tile.front_brightness_boost:
				failures.append("human hand tile does not request the local brightness floor")
				return
			var human_body := human_tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
			var human_material := human_body.material_override as StandardMaterial3D if human_body != null else null
			if human_material == null or not human_material.emission_enabled or human_material.emission_energy_multiplier < 0.15:
				failures.append("human hand ivory material is still allowed to fall into a dark face")
				return
			var human_face_material := human_tile.face_mesh.get_active_material(0) as StandardMaterial3D
			if not human_tile.face_mesh.visible or human_face_material == null \
					or human_face_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
					or absf(human_face_material.albedo_color.r - Color("E4E2DE").r) > 0.002:
				failures.append("human hand face is not locked to the discard-white brightness target")
				return
			break
	var shared_back_material: StandardMaterial3D
	for seat in [1, 2, 3]:
		var found := false
		for key_value in nodes.keys():
			if not str(key_value).begins_with("hand_%d_" % seat):
				continue
			found = true
			var tile := nodes[key_value] as SichuanTile3D
			var owner_mesh := tile.concealed_cap_mesh if seat == 2 else tile.face_mesh
			var back_mesh := tile.face_mesh if seat == 2 else tile.concealed_cap_mesh
			var owner_material := owner_mesh.get_surface_override_material(0) as StandardMaterial3D
			var back_material := back_mesh.get_surface_override_material(0) as StandardMaterial3D
			if owner_mesh.mesh == null or not owner_mesh.visible or owner_material == null:
				failures.append(
					"AI seat %d concealed tile has no physical owner-facing ivory surface (mesh=%s visible=%s material=%s)"
					% [seat, owner_mesh.mesh != null, owner_mesh.visible, owner_material != null]
				)
				return
			if owner_material.albedo_color.r < 0.75 or owner_material.albedo_color.g < 0.75 or owner_material.albedo_color.b < 0.75:
				failures.append("AI seat %d owner-facing concealed surface is not ivory white" % seat)
				return
			if back_mesh.mesh == null or not back_mesh.visible or back_material == null \
					or back_material.albedo_color.g <= back_material.albedo_color.r * 1.5:
				failures.append("AI seat %d table-facing concealed surface lost its jade back" % seat)
				return
			if shared_back_material == null:
				shared_back_material = back_material
			elif not back_material.albedo_color.is_equal_approx(shared_back_material.albedo_color) \
					or absf(back_material.roughness - shared_back_material.roughness) > 0.001 \
					or back_material.shading_mode != shared_back_material.shading_mode:
				failures.append("AI seat %d back material differs from the other opponent jade backs" % seat)
				return
			var top_axis := tile.transform.basis.z.normalized()
			var horizontal_top := Vector3(top_axis.x, 0.0, top_axis.z)
			if absf(absf(top_axis.y) - 1.0) > 0.001 or horizontal_top.length() > 0.001:
				failures.append(
					"AI seat %d concealed tile is not exactly perpendicular to the table (top=%s horizontal=%.5f)"
					% [seat, top_axis, horizontal_top.length()]
				)
				return
			break
		if not found:
			failures.append("AI seat %d concealed hand was not rendered for surface verification" % seat)


func _verify_no_physical_wall(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if str(key_value).begins_with("wall_"):
			failures.append("physical undrawn wall still consumes the center play surface")
			return


func _verify_readability_geometry(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	if stage.get_camera().projection != Camera3D.PROJECTION_PERSPECTIVE:
		failures.append("camera must use the accepted commercial-reference perspective composition")
	if stage.get_camera().keep_aspect != Camera3D.KEEP_WIDTH:
		failures.append("perspective camera must keep horizontal composition across mobile aspect ratios")
	if stage.get_camera().fov < 49.0 or stage.get_camera().fov > 50.0:
		failures.append("perspective camera horizontal FOV is outside the mobile readability range")
	var nodes: Dictionary = stage.get("tile_nodes")
	for seat in [1, 2, 3]:
		for key_value in nodes.keys():
			if not str(key_value).begins_with("hand_%d_" % seat):
				continue
			var tile := nodes[key_value] as SichuanTile3D
			if absf(tile.transform.basis.z.y) < 0.94:
				failures.append("AI seat %d concealed rack is not near-vertical" % seat)
				return
			if tile.concealed_cap_mesh == null or not tile.concealed_cap_mesh.visible:
				failures.append("AI seat %d concealed tile lost its ivory top lip" % seat)
				return
			if tile.position.y < 0.30:
				failures.append("AI seat %d standing hand sinks into the table" % seat)
				return


func _verify_human_orientation(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	for key_value in nodes.keys():
		if str(key_value).begins_with("hand_0_"):
			var hand_tile := nodes[key_value] as SichuanTile3D
			if absf(hand_tile.transform.basis.z.y) < 0.70:
				failures.append("human concealed hand is not standing upright")
			return
	for key_value in nodes.keys():
		if str(key_value).begins_with("discard_0_"):
			var discard_tile := nodes[key_value] as SichuanTile3D
			if discard_tile.transform.basis.x.x < 0.98 or discard_tile.transform.basis.z.z < 0.98:
				failures.append("human discard glyph orientation remains inverted")
			return


func _verify_concealed_gang(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var concealed_count := 0
	var positions: Array[float] = []
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with("meld_2_0_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if not tile.showing_face:
			concealed_count += 1
			positions.append(tile.position.x)
			if not tile.flat_concealed_result:
				failures.append("concealed kong tile must use the stable jade-back surface")
	if concealed_count != 4:
		failures.append("concealed kong must be the face-down meld, count=%d" % concealed_count)
	positions.sort()
	if positions.size() == 4:
		for index in range(1, positions.size()):
			if positions[index] - positions[index - 1] < 0.50:
				failures.append("concealed kong middle tiles still overlap instead of showing four boundaries")
				break


func _verify_target_reference_hand_anchors(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	var expected_centers := [
		Vector3(1.39, 0.25, 3.57),
		Vector3(-5.92, 0.36, -1.22),
		Vector3(-1.40, 0.36, -6.00),
		Vector3(5.92, 0.36, -1.22),
	]
	for seat in range(4):
		var positions: Array[Vector3] = []
		for key_value in nodes.keys():
			if str(key_value).begins_with("hand_%d_" % seat):
				positions.append((nodes[key_value] as Node3D).position)
		var average := Vector3.ZERO
		for position in positions:
			average += position
		if not positions.is_empty():
			average /= float(positions.size())
		if average.distance_to(expected_centers[seat]) > 0.08:
			failures.append("seat %d hand departed from the accepted target-reference anchor: actual=%s expected=%s" % [seat, average, expected_centers[seat]])
	var self_meld_z: Array[float] = []
	for key_value in nodes.keys():
		if str(key_value).begins_with("meld_0_"):
			self_meld_z.append((nodes[key_value] as Node3D).position.z)
	if self_meld_z.is_empty() or self_meld_z.min() < 3.1 or self_meld_z.max() > 3.3:
		failures.append("human melds are not aligned with the lower-left hand rail")
	var self_hand_left := INF
	var self_meld_right := -INF
	for key_value in nodes.keys():
		var key := str(key_value)
		if key.begins_with("hand_0_"):
			self_hand_left = minf(self_hand_left, (nodes[key_value] as Node3D).position.x)
		elif key.begins_with("meld_0_"):
			self_meld_right = maxf(self_meld_right, (nodes[key_value] as Node3D).position.x)
	if self_meld_right >= self_hand_left - 0.45:
		failures.append("human melds do not leave a clear gap before the concealed hand")


func _verify_latest_marker(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var marker_count := 0
	for tile_value in (stage.get("tile_nodes") as Dictionary).values():
		var tile := tile_value as SichuanTile3D
		if tile.latest_marker != null and tile.latest_marker.visible:
			marker_count += 1
	if marker_count != 1:
		failures.append("exactly one latest-discard marker must remain visible")


func _verify_new_draw_marker(stage: SichuanTableStage3D, draw_tile_id: int, failures: Array[String]) -> void:
	var marker_count := 0
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile.new_draw_marker != null and tile.new_draw_marker.visible:
			marker_count += 1
			if tile.tile_id != draw_tile_id:
				failures.append("new-draw cone is attached to the wrong tile id")
			if tile.state_marker != null and tile.state_marker.visible:
				failures.append("new-draw tile still carries a full-tile color plane")
	if marker_count != 1:
		failures.append("exactly one new-draw cone marker must be visible")


func _verify_selected_marker(stage: SichuanTableStage3D, selected_tile_id: int, failures: Array[String]) -> void:
	var marker_count := 0
	for tile_value in (stage.get("tile_nodes") as Dictionary).values():
		var tile := tile_value as SichuanTile3D
		if tile.selected_marker != null and tile.selected_marker.visible:
			marker_count += 1
			if tile.tile_id != selected_tile_id:
				failures.append("selection hand is attached to the wrong tile id")
			if tile.state_marker != null and tile.state_marker.visible:
				failures.append("selected tile still carries a full-tile color plane")
			if tile.selected_marker.name != "SelectedHandPointerMarker":
				failures.append("selected tile does not expose the hand-pointer shape")
	if marker_count != 1:
		failures.append("exactly one selection hand marker must be visible")


func _verify_human_ding_que_rightmost(stage: SichuanTableStage3D, ding_que_suit: String, failures: Array[String]) -> void:
	var keys: Array[String] = stage.get("self_hand_keys")
	var reached_ding_que := false
	var previous_rank := -1
	var previous_id := -1
	for key in keys:
		var tile := (stage.get("tile_nodes") as Dictionary).get(key) as SichuanTile3D
		if tile == null:
			continue
		var is_ding_que := str(tile.tile_data.get("suit", "")) == ding_que_suit
		if is_ding_que:
			reached_ding_que = true
			var rank := int(tile.tile_data.get("rank", 0))
			if rank < previous_rank or (rank == previous_rank and previous_id >= 0 and tile.tile_id < previous_id):
				failures.append("rightmost ding-que block is not stably sorted by rank and tile id")
			previous_rank = rank
			previous_id = tile.tile_id
		elif reached_ding_que:
			failures.append("non-ding-que tile appears after the rightmost ding-que block")
			return


func _verify_side_meld_axes(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	for seat in [1, 3]:
		var positions: Array[Vector3] = []
		for key_value in (stage.get("tile_nodes") as Dictionary).keys():
			if not str(key_value).begins_with("meld_%d_0_" % seat):
				continue
			var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
			positions.append(tile.position)
			if absf(tile.symbol_mesh.rotation.y - PI) > 0.01:
				failures.append("seat %d meld glyphs are not oriented toward their owner" % seat)
		if positions.size() < 3:
			failures.append("seat %d side meld fixture is incomplete" % seat)
			continue
		var fixed_x := positions[0].x
		var z_values: Array[float] = []
		for position in positions:
			if absf(position.x - fixed_x) > 0.03:
				failures.append("seat %d meld is not parallel to its standing hand rail" % seat)
			z_values.append(position.z)
		z_values.sort()
		for index in range(1, z_values.size()):
			if absf((z_values[index] - z_values[index - 1]) - 0.50) > 0.02:
				failures.append("seat %d gang/peng pitch is inconsistent" % seat)


func _verify_meld_source_arrows(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var marker_count := 0
	var expected_sources := {0: 1, 1: 2, 3: 0}
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if not key.begins_with("meld_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile.winning_source_marker == null or not tile.winning_source_marker.visible:
			continue
		marker_count += 1
		var owner_seat := int(key.split("_")[1])
		if not expected_sources.has(owner_seat):
			failures.append("concealed/self-sourced gang must not show a source arrow")
			continue
		if tile.winner_seat != owner_seat or tile.winning_source_seat != int(expected_sources[owner_seat]):
			failures.append("meld source arrow lost owner/source identity for seat %d" % owner_seat)
		if tile.source_marker_kind not in ["peng", "gang"]:
			failures.append("meld source arrow does not identify a peng/gang marker")
		if tile.winning_source_label == null or "出" not in tile.winning_source_label.text:
			failures.append("meld source marker is missing the explicit seat label")
		var material := tile.winning_source_marker.get_surface_override_material(0) as StandardMaterial3D
		if material == null or not material.albedo_color.is_equal_approx(Color("42A5FF")):
			failures.append("meld source marker is not the requested blue cartoon arrow")
		if tile.winning_source_marker.scale.x > 0.95:
			failures.append("meld source arrow is still oversized")
		if absf(tile.winning_source_marker.position.z) > 0.08:
			failures.append("meld source arrow is not centred above the marked tile")
		var expected_tile_id := 30000 + owner_seat * 100 + 1
		if tile.tile_id != expected_tile_id:
			failures.append("seat %d meld arrow must be attached to the second/centre tile" % owner_seat)
	if marker_count != 3:
		failures.append("three exposed fixture melds must each show one colored source arrow, got %d" % marker_count)


func _verify_right_meld_matches_hand_direction(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var hand_tile: SichuanTile3D
	var meld_tile: SichuanTile3D
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if hand_tile == null and key.begins_with("hand_3_"):
			hand_tile = (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		elif meld_tile == null and key.begins_with("meld_3_"):
			meld_tile = (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
	if hand_tile == null or meld_tile == null:
		failures.append("right-player hand/meld direction fixture is incomplete")
		return
	var hand_axis := Vector2(hand_tile.transform.basis.x.x, hand_tile.transform.basis.x.z).normalized()
	var meld_axis := Vector2(meld_tile.transform.basis.x.x, meld_tile.transform.basis.x.z).normalized()
	if absf(hand_axis.dot(meld_axis)) < 0.995:
		failures.append("right-player meld yaw is not aligned with the right standing hand")
	if absf(meld_tile.position.x - 4.85) > 0.03:
		failures.append("right-player first meld group left the accepted side rail")


func _verify_far_meld_ownership_zone(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with("meld_2_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile.position.z < -5.55 or tile.position.z > -5.35:
			failures.append("far-player meld is not parked directly below the far hand")
			return
	var far_rect := _projected_prefix_rect(stage, "meld_2_")
	var right_rect := _projected_prefix_rect(stage, "meld_3_")
	if far_rect.size != Vector2.ZERO and right_rect.size != Vector2.ZERO and far_rect.intersects(right_rect):
		failures.append("far-player meld overlaps the right-player meld rail and obscures seat ownership")


func _verify_discard_row_clearance(stage: SichuanTableStage3D, discard_counts: Array, failures: Array[String]) -> void:
	for seat in range(4):
		for column in range(6):
			if 6 + column >= int(discard_counts[seat]):
				continue
			var first_key := "discard_%d_%d" % [seat, 20000 + seat * 100 + column]
			var second_key := "discard_%d_%d" % [seat, 20000 + seat * 100 + 6 + column]
			var first_tile := (stage.get("tile_nodes") as Dictionary).get(first_key) as SichuanTile3D
			var second_tile := (stage.get("tile_nodes") as Dictionary).get(second_key) as SichuanTile3D
			if first_tile != null and second_tile != null and first_tile.get_screen_rect(stage.get_camera()).intersects(second_tile.get_screen_rect(stage.get_camera())):
				failures.append("seat %d discard rows 1 and 2 overlap at column %d" % [seat, column + 1])


func _verify_side_meld_pressure(stage: SichuanTableStage3D, base_snapshot: Dictionary, base_hands: Array, failures: Array[String]) -> void:
	var pressure_snapshot := base_snapshot.duplicate(true)
	var pressure_players: Array = pressure_snapshot.get("players", []).duplicate(true)
	var pressure_hands: Array = base_hands.duplicate(true)
	for seat in [1, 3]:
		pressure_hands[seat] = _tiles(50000 + seat * 100, 1, seat)
		var melds: Array = []
		for meld_index in range(4):
			melds.append({
				"type": "gang" if meld_index % 2 == 1 else "peng",
				"gang_subtype": "ming_gang" if meld_index % 2 == 1 else "",
				"from_seat": (seat + 1 + meld_index) % 4,
				"tiles": _tiles(51000 + seat * 100 + meld_index * 10, 4 if meld_index % 2 == 1 else 3, seat + meld_index),
			})
		pressure_players[seat]["melds"] = melds
	pressure_snapshot["players"] = pressure_players
	stage.render_snapshot(pressure_snapshot, pressure_hands, false, -1, {})
	await process_frame
	for seat in [1, 3]:
		var hand_rect := _projected_prefix_rect(stage, "hand_%d_" % seat)
		var discard_rect := _projected_prefix_rect(stage, "discard_%d_" % seat)
		var far_meld_rect := _projected_prefix_rect(stage, "meld_2_")
		var group_rects: Array[Rect2] = []
		for meld_index in range(4):
			var group_rect := _projected_prefix_rect(stage, "meld_%d_%d_" % [seat, meld_index])
			if group_rect.size == Vector2.ZERO:
				failures.append("seat %d pressure meld group %d is missing" % [seat, meld_index])
				continue
			if group_rect.intersects(hand_rect):
				failures.append("seat %d pressure meld group %d overlaps the concealed hand" % [seat, meld_index])
			if group_rect.intersects(discard_rect):
				failures.append("seat %d pressure meld group %d overlaps the discard zone" % [seat, meld_index])
			if seat == 3 and group_rect.intersects(far_meld_rect):
				failures.append("right-player pressure meld group %d overlaps the far-player meld" % meld_index)
			for previous_rect in group_rects:
				if group_rect.intersects(previous_rect):
					failures.append("seat %d pressure meld groups overlap on the owner-aligned rail" % seat)
			group_rects.append(group_rect)


func _projected_prefix_rect(stage: SichuanTableStage3D, prefix: String) -> Rect2:
	var result := Rect2()
	var found := false
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with(prefix):
			continue
		var rect := ((stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D).get_screen_rect(stage.get_camera())
		result = rect if not found else result.merge(rect)
		found = true
	return result


func _verify_pick_mapping(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var keys: Array[String] = stage.get("self_hand_keys")
	if keys.is_empty():
		failures.append("self hand has no projected pick targets")
		return
	var target := (stage.get("tile_nodes") as Dictionary).get(keys.back()) as SichuanTile3D
	var screen_point := target.get_screen_rect(stage.get_camera()).get_center()
	var picked := stage.find_tile_at_screen(screen_point)
	if picked != target.tile_id:
		failures.append("3D screen projection did not map back to the expected self tile")


func _verify_dynamic_snapshot_reconfiguration(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with("hand_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if not tile.showing_face:
			failures.append("stable tile nodes did not refresh reveal state from the new snapshot")
			return


func _verify_won_hand_and_source_arrow(stage: SichuanTableStage3D, original_count: int, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	var flat_revealed_count := 0
	var arrow_count := 0
	for key_value in nodes.keys():
		var key := str(key_value)
		if key.begins_with("hand_0_") or key.begins_with("winning_0_"):
			var tile := nodes[key_value] as SichuanTile3D
			if tile.showing_face and absf(tile.transform.basis.z.y) < 0.05:
				flat_revealed_count += 1
			if tile.winning_source_marker != null and tile.winning_source_marker.visible:
				arrow_count += 1
				if tile.winning_source_seat != 1 or tile.winner_seat != 0:
					failures.append("winning-source arrow lost winner/source seat identity")
				if absf(tile.winning_source_marker.rotation.y - PI * 0.5) > 0.01:
					failures.append("seat-1 discard arrow does not point toward the upper/left player")
	if flat_revealed_count != original_count:
		failures.append("won human hand must lay down all %d tiles, got %d" % [original_count, flat_revealed_count])
	if arrow_count != 1:
		failures.append("discard win must show exactly one source arrow, got %d" % arrow_count)
	if not (stage.get("self_hand_keys") as Array).is_empty():
		failures.append("won human hand must no longer expose discard pick targets")


func _verify_human_self_draw_full_hand(stage: SichuanTableStage3D, expected_tiles: Array, failures: Array[String]) -> void:
	var expected_ids: Dictionary = {}
	for tile_value in expected_tiles:
		expected_ids[int((tile_value as Dictionary).get("id", -1))] = 0
	var hand_count := 0
	var winning_count := 0
	var source_arrow_count := 0
	var draw_marker_count := 0
	var winning_tile_id := int((expected_tiles.back() as Dictionary).get("id", -1))
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if key.begins_with("winning_0_"):
			winning_count += 1
			continue
		if not key.begins_with("hand_0_"):
			continue
		hand_count += 1
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if expected_ids.has(tile.tile_id):
			expected_ids[tile.tile_id] = int(expected_ids[tile.tile_id]) + 1
		else:
			failures.append("self-draw result contains an unexpected hand tile id %d" % tile.tile_id)
		if not tile.showing_face or absf(tile.transform.basis.z.y) >= 0.05:
			failures.append("human self-draw result must lay every hand tile flat and face-up")
		if tile.concealed_surface_flip or not tile.symbol_mesh.visible:
			failures.append("human self-draw result must reveal the actual hand symbols")
		if tile.new_draw_marker != null and tile.new_draw_marker.visible:
			draw_marker_count += 1
			if tile.tile_id != winning_tile_id:
				failures.append("human self-draw marker is attached to the wrong winning tile")
		if tile.winning_source_marker != null and tile.winning_source_marker.visible:
			source_arrow_count += 1
	for tile_id_value in expected_ids.keys():
		if int(expected_ids[tile_id_value]) != 1:
			failures.append("self-draw tile id %d must appear exactly once, got %d" % [int(tile_id_value), int(expected_ids[tile_id_value])])
	if hand_count != expected_tiles.size():
		failures.append("self-draw must display the complete %d-tile hand, got %d" % [expected_tiles.size(), hand_count])
	if winning_count != 0:
		failures.append("self-draw must not extract a separate winning tile node")
	if source_arrow_count != 0:
		failures.append("self-draw must not display a discard-source arrow")
	if draw_marker_count != 1:
		failures.append("human self-draw must mark exactly one winning tile, got %d" % draw_marker_count)
	if not (stage.get("self_hand_keys") as Array).is_empty():
		failures.append("self-draw result must disable all discard pick targets")


func _verify_ai_self_draw_full_hand(
	stage: SichuanTableStage3D,
	seat: int,
	expected_tiles: Array,
	failures: Array[String]
) -> void:
	var hand_count := 0
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if not key.begins_with("hand_%d_" % seat):
			continue
		hand_count += 1
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile.showing_face or absf(tile.transform.basis.z.y) >= 0.05:
			failures.append("AI seat %d self-draw must remain flat and face-down" % seat)
			return
		if not tile.concealed_surface_flip or not tile.flat_concealed_result \
				or not tile.face_mesh.visible or tile.symbol_mesh.visible:
			failures.append("AI seat %d self-draw did not preserve the concealed jade-back result" % seat)
			return
		var back_material := tile.face_mesh.get_surface_override_material(0) as StandardMaterial3D
		if back_material == null or back_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			failures.append("AI seat %d self-draw backs do not share the stable result material" % seat)
			return
	if hand_count != expected_tiles.size():
		failures.append("AI seat %d self-draw must show all %d backs, got %d" % [seat, expected_tiles.size(), hand_count])


func _verify_ai_discard_win_with_preserved_hand(stage: SichuanTableStage3D, seat: int, expected_hand_count: int, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	var concealed_or_revealed_hand_count := 0
	var winning_tile_count := 0
	var source_arrow_count := 0
	var hand_rect := Rect2()
	var winning_rect := Rect2()
	var found_hand := false
	for key_value in nodes.keys():
		var key := str(key_value)
		if key.begins_with("hand_%d_" % seat):
			concealed_or_revealed_hand_count += 1
			var hand_tile := nodes[key_value] as SichuanTile3D
			var tile_rect := hand_tile.get_screen_rect(stage.get_camera())
			hand_rect = tile_rect if not found_hand else hand_rect.merge(tile_rect)
			found_hand = true
			if hand_tile.showing_face:
				failures.append("AI point-win must preserve the concealed hand information")
			if absf(hand_tile.transform.basis.z.y) < 0.70:
				failures.append("AI point-win must preserve the standing hand pose")
		elif key.begins_with("winning_%d_" % seat):
			winning_tile_count += 1
			var tile := nodes[key_value] as SichuanTile3D
			winning_rect = tile.get_screen_rect(stage.get_camera())
			if not tile.showing_face:
				failures.append("AI discard-winning tile must be face-up")
			if tile.winning_source_marker != null and tile.winning_source_marker.visible:
				source_arrow_count += 1
				if tile.winner_seat != seat or tile.winning_source_seat != 0:
					failures.append("AI discard-win source identity mismatch")
	if concealed_or_revealed_hand_count != expected_hand_count:
		failures.append("AI discard win must preserve %d standing hand tiles, got %d" % [expected_hand_count, concealed_or_revealed_hand_count])
	if winning_tile_count != 1:
		failures.append("AI discard win must show exactly one claimed tile, got %d" % winning_tile_count)
	if source_arrow_count != 1:
		failures.append("AI discard win must show exactly one source arrow, got %d" % source_arrow_count)
	if found_hand and winning_tile_count == 1:
		if hand_rect.intersects(winning_rect):
			failures.append("AI seat %d winning tile overlaps the preserved hand" % seat)
		var edge_gap := hand_rect.get_center().distance_to(winning_rect.get_center())
		var maximum_adjacent_distance := maxf(hand_rect.size.x, hand_rect.size.y) + maxf(winning_rect.size.x, winning_rect.size.y) * 2.5
		if edge_gap > maximum_adjacent_distance:
			failures.append("AI seat %d winning tile is not adjacent to the preserved hand" % seat)


func _verify_ai_discard_win_stress(
	stage: SichuanTableStage3D,
	base_snapshot: Dictionary,
	ai_won_snapshot: Dictionary,
	all_hands: Array,
	failures: Array[String]
) -> void:
	for cycle in range(20):
		var use_ai_win := cycle % 2 == 0
		stage.render_snapshot(ai_won_snapshot if use_ai_win else base_snapshot, all_hands, false, -1, {})
		await process_frame
		var nodes: Dictionary = stage.get("tile_nodes")
		var hand_count := 0
		var winning_count := 0
		for key_value in nodes.keys():
			var key := str(key_value)
			if key.begins_with("hand_1_"):
				hand_count += 1
			elif key.begins_with("winning_1_"):
				winning_count += 1
		var expected_hand_count: int = int(all_hands[1].size()) - 1 if use_ai_win else int(all_hands[1].size())
		var expected_winning_count: int = 1 if use_ai_win else 0
		if hand_count != expected_hand_count or winning_count != expected_winning_count:
			failures.append(
				"AI point-win stress cycle %d leaked stale nodes: hand=%d/%d winning=%d/%d" % [
					cycle,
					hand_count,
					expected_hand_count,
					winning_count,
					expected_winning_count,
				]
			)
			return


func _verify_assets(failures: Array[String]) -> void:
	for path in ["res://res/art/3d/mahjong_tile_body.glb", "res://res/art/3d/sichuan_table.glb", "res://shaders/table_plush_felt_3d.gdshader"]:
		if not ResourceLoader.exists(path):
			failures.append("missing 3D core asset: %s" % path)
	for suit in ["tiao", "tong", "wan"]:
		for rank in range(1, 10):
			var path := "res://res/art/ui_3d_cartoon/tile_symbols/%s_%d.png" % [suit, rank]
			if not ResourceLoader.exists(path):
				failures.append("missing tile face texture: %s" % path)


func _tiles(start_id: int, count: int, offset: int) -> Array:
	var result: Array = []
	var suits := ["tiao", "tong", "wan"]
	for index in range(count):
		result.append({
			"id": start_id + index,
			"suit": suits[(index + offset) % suits.size()],
			"rank": (index * 2 + offset) % 9 + 1,
		})
	return result
