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
		"current_turn_seat": 0,
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
	await _verify_center_wall_count_3d(stage, failures)
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
	_verify_meld_tile_model_consistency(stage, "base_peng_and_an_gang", failures)
	_verify_meld_source_arrows(stage, failures)
	_verify_right_meld_matches_hand_direction(stage, failures)
	_verify_far_meld_ownership_zone(stage, failures)
	_verify_discard_row_clearance(stage, discard_counts, failures)
	_verify_discard_back_layer(stage, failures)
	_verify_pick_mapping(stage, failures)
	_verify_assets(failures)
	await _verify_four_source_meld_matrix(stage, snapshot, all_hands, failures)
	await _verify_concealed_gang_matrix(stage, snapshot, all_hands, failures)
	stage.render_snapshot(snapshot, all_hands, false, -1, {})
	await process_frame

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
	await _verify_self_row_pressure(stage, snapshot, all_hands, failures)
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
	if int(contract.get("rendered_wall_tile_count", -1)) != 0 or str(contract.get("wall_representation", "")) != "static_numeric_count_on_blender_four_way_instrument":
		failures.append("undrawn wall must use the static numeric count in the Blender center instrument")
	if str(contract.get("wall_count_motion", "")) != "none_static_on_table_surface" \
			or not bool(contract.get("wall_count_3d_node", false)):
		failures.append("wall count must be a static physical 3D text node on the table surface")
	if int(contract.get("self_pickable_count", -1)) != hand_counts[0]:
		failures.append("every self-hand tile must remain pickable")
	if int(contract.get("light_count", -1)) != 2 or int(contract.get("shadow_casting_light_count", -1)) != 1:
		failures.append("mobile lighting budget must be two lights with one shadow caster")
	if int(contract.get("mobile_directional_shadow_size", 0)) != 2048 \
			or int(contract.get("mobile_soft_shadow_filter_quality", -1)) != 0 \
			or float(contract.get("directional_shadow_max_distance", 0.0)) < 20.0 \
			or float(contract.get("directional_shadow_max_distance", 99.0)) > 26.0:
		failures.append("mobile tile shadows must use Godot's 2048/quality-0 mobile budget and the bounded table range")
	if int(contract.get("physics_tiles", -1)) != 0:
		failures.append("tile presentation must not use per-tile physics")
	if int(contract.get("tripo_calls", -1)) != 0:
		failures.append("V1 precise core assets must consume zero Tripo calls")
	if float(contract.get("self_hand_scale", 0.0)) < 1.60 or float(contract.get("opponent_hand_scale", 0.0)) < 1.40:
		failures.append("mobile readability scale is below the enlarged tile threshold")
	if not (contract.get("tile_physical_size", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0.42, 0.24, 0.58)):
		failures.append("standing and flat poses do not share the thicker physical tile dimensions")
	var flat_back_cover_size := contract.get("flat_back_cover_size", Vector2.ZERO) as Vector2
	if flat_back_cover_size.x < 0.413 or flat_back_cover_size.x > 0.415 \
			or flat_back_cover_size.y < 0.573 or flat_back_cover_size.y > 0.575:
		failures.append("flat/meld jade back cover must nearly fill the shared tile footprint")
	if str(contract.get("flat_back_cover_contract", "")) != "shared_jade_back_nearly_full_footprint_with_3mm_ivory_lip":
		failures.append("flat/meld jade back cover contract is missing the coherent 3D rim")
	if str(contract.get("tile_pose_geometry", "")) != "one_shared_0_42x0_24x0_58_model_uniform_scale_rotation_only":
		failures.append("tile pose contract must rotate one shared model without pose-specific compression")
	if str(contract.get("meld_model_geometry", "")) != "peng_ming_gang_an_gang_add_gang_share_one_model_uniform_scale_only":
		failures.append("peng and all gang variants must share one uniformly scaled tile model")
	var expected_self_meld_scale := float(contract.get("self_hand_scale", 0.0)) * SichuanTableStage3D.SELF_MELD_VISUAL_SCALE_FACTOR
	if absf(float(contract.get("self_meld_scale", 0.0)) - expected_self_meld_scale) > 0.001:
		failures.append("human melds must expose the reduced but still uniform runtime scale")
	if absf(float(contract.get("self_meld_visual_scale_factor", 0.0)) - SichuanTableStage3D.SELF_MELD_VISUAL_SCALE_FACTOR) > 0.001:
		failures.append("human meld visual scale factor contract drifted")
	if int(contract.get("self_layout_max_tiles", -1)) != 18 \
			or int(contract.get("self_layout_total_tiles", -1)) != hand_counts[0] + 3:
		failures.append("human row must expose the legal 18-tile shared-layout contract")
	if float(contract.get("self_layout_span", INF)) > float(contract.get("self_layout_available_width", 0.0)) + 0.001:
		failures.append("human hand and melds exceed the shared lower rail")
	if absf(float(contract.get("self_flat_visual_scale_factor", 0.0)) - 1.0) > 0.001:
		failures.append("standing and flat human hands must use one uniform scale")
	if absf(float(contract.get("flat_concealed_result_scale_factor", 0.0)) - SichuanTableStage3D.FLAT_CONCEALED_RESULT_SCALE_FACTOR) > 0.001:
		failures.append("flat concealed results must expose the fixed uniform readability scale factor")
	if absf(float(contract.get("side_flat_concealed_result_scale", 0.0)) - SichuanTableStage3D.SIDE_FLAT_CONCEALED_RESULT_SCALE) > 0.001 \
			or absf(float(contract.get("far_flat_concealed_result_scale", 0.0)) - SichuanTableStage3D.FAR_FLAT_CONCEALED_RESULT_SCALE) > 0.001:
		failures.append("AI flat winning hands must expose the seat-specific perspective scale compensation")
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
	if str(contract.get("opponent_back_material", "")) != "all_three_shared_pbr_emerald_back":
		failures.append("all three opponent racks must share one PBR emerald back material")
	if str(contract.get("discard_win_hand_pose", "")) != "flat_revealed_for_human":
		failures.append("human discard-win hand must preserve the revealed result contract")
	if str(contract.get("ai_discard_win_presentation", "")) != "flat_concealed_back_plus_adjacent_winning_tile_outside_self_hand_safe_zone":
		failures.append("AI discard wins must lay the hand face-down and keep the claimed tile outside the self-hand safe zone")
	if float(contract.get("side_winning_tile_max_local_z", 99.0)) > 1.65:
		failures.append("side discard-winning tiles do not expose the local-hand protection boundary")
	if absf(float(contract.get("opponent_hand_face_rotation_degrees", 0.0)) - 180.0) > 0.01:
		failures.append("AI hand face content must be rotated 180 degrees toward its owner")
	if str(contract.get("opponent_concealed_owner_surface", "")) != "warm_ivory_sides_target_white_far":
		failures.append("AI owner-facing surfaces must preserve side ivory and the figure-2 far white cap")
	if str(contract.get("side_concealed_top_tilt", "")) != "perpendicular_to_table":
		failures.append("AI concealed hands must remain perpendicular to the table")
	if str(contract.get("self_hand_lighting", "")) != "shared_warm_ivory_pbr_without_emission":
		failures.append("human hand must share the table's warm-ivory physical exposure without emission")
	if str(contract.get("self_meld_zone", "")) != "continuous_left_segment_of_shared_18_tile_row":
		failures.append("human melds must occupy the continuous left segment of the shared 18-tile row")
	if int(contract.get("self_meld_tile_count", -1)) != 3:
		failures.append("human meld pressure was not included in the hand anchor")
	if float(contract.get("self_hand_center_x", INF)) > SichuanTableStage3D.SELF_LAYOUT_RIGHT_X:
		failures.append("human concealed hand departed from the shared lower rail")
	if str(contract.get("human_ding_que_sort", "")) != "rightmost_then_rank_then_tile_id":
		failures.append("3D human hand lost the rightmost ding-que sort contract")
	if str(contract.get("new_draw_feedback", "")) != "small_flat_blue_3d_diamond_with_world_yaw_tight_to_drawn_tile":
		failures.append("new draw must use the flat pure-blue diamond tight to the drawn tile with latest-discard world yaw")
	if str(contract.get("new_draw_rotation", "")) != "world_vertical_axis_126_degrees_per_second":
		failures.append("new draw must retain its accessible world-vertical 126-degree rotation contract")
	if (contract.get("new_draw_marker_variants", []) as Array).size() != 1:
		failures.append("draw-marker contract must expose one fixed blue-diamond presentation")
	if absf(float(contract.get("new_draw_travel_seconds", 0.0)) - 0.20) > 0.001 \
			or absf(float(contract.get("new_draw_settle_seconds", 0.0)) - 0.05) > 0.001:
		failures.append("draw animation must use a 200ms travel plus 50ms settle")
	if str(contract.get("selected_tile_feedback", "")) != "physical_lift_without_overlay_graphic":
		failures.append("selected tile must keep only its physical lift without a checkmark graphic")
	if (contract.get("selected_marker_variants", []) as Array).size() != 1:
		failures.append("selection-marker contract must expose only the no-icon presentation")
	if str(contract.get("latest_discard_feedback", "")) != "static_low_profile_antique_bronze_chevron_close_to_tile":
		failures.append("latest discard does not expose the integrated low-profile bronze-chevron contract")
	if absf(float(contract.get("discard_travel_seconds", 0.0)) - 0.20) > 0.001 \
			or absf(float(contract.get("discard_settle_seconds", 0.0)) - 0.04) > 0.001 \
			or float(contract.get("discard_reflow_beat_seconds", 0.0)) < 0.05 \
			or str(contract.get("latest_marker_timing", "")) != "after_river_landing" \
			or str(contract.get("hand_reflow_timing", "")) != "after_discard_landing":
		failures.append("discard landing/marker/reflow event ordering contract mismatch")
	if str(contract.get("side_meld_layout", "")) != "single_side_rail_with_group_gaps":
		failures.append("side melds lost the single owner-aligned rail contract")
	var discard_row_step := float(contract.get("discard_row_step", 0.0))
	if discard_row_step < 0.72 or discard_row_step > 0.78:
		failures.append("discard row pitch does not clear the 1.16x tile footprint")
	if str(contract.get("right_meld_axis", "")) != "same_yaw_and_z_flow_as_right_hand":
		failures.append("right-player meld direction contract is missing")
	if str(contract.get("far_meld_zone", "")) != "below_far_hand_not_right_player_band":
		failures.append("far-player meld ownership zone contract is missing")
	if str(contract.get("meld_source_feedback", "")) != "compact_sky_blue_flat_face_arrow_on_second_tile_without_seat_label":
		failures.append("peng/gang source feedback must use the compact sky-blue face arrow without a seat label")
	if str(contract.get("winning_source_feedback", "")) != "compact_sky_blue_flat_face_arrow_without_seat_label" \
			or bool(contract.get("winning_source_text", true)):
		failures.append("winning-source feedback must be a compact sky-blue arrow with no discarder text")
	if str(contract.get("tile_back_color", "")).to_upper() != SichuanTile3D.NORMAL_TILE_BACK_COLOR.to_html(false).to_upper():
		failures.append("result and concealed-kong backs must use the normal dark-emerald tile-back color")
	if str(contract.get("season_theme", "")) != "deep_emerald_refined_table":
		failures.append("3D stage did not expose the Deep Emerald visual contract")
	if str(contract.get("table_asset", "")) != "sichuan_table_v2_pbr":
		failures.append("3D stage did not expose the Blender V2 table asset contract")
	if str(contract.get("table_material_pipeline", "")) != "blender_pbr_preserved_without_flat_overrides":
		failures.append("3D stage must preserve Blender PBR materials without runtime flat overrides")
	if str(contract.get("discard_origin_policy", "")) != "upper_left_from_each_player_perspective":
		failures.append("discard rivers must start from the upper-left in each player's perspective")
	if str(contract.get("center_display_asset", "")) != "blender_authored_flush_glass_four_way_inlay":
		failures.append("center graphic must expose the Blender-authored flush glass four-way inlay contract")
	if str(contract.get("center_display_shape", "")) != "flush_chamfered_glass_inlay_with_circular_counter" \
			or str(contract.get("center_display_material", "")) != "imported_blender_pbr_glass_matte_counter_graphite_bronze_and_vivid_red_lacquer":
		failures.append("center display must use the flush imported Blender PBR glass inlay")
	if str(contract.get("center_display_detail", "")) != "continuous_smoked_glass_with_matte_counter_graphite_hairlines_bronze_and_arc_cutout_vivid_red_active_sector" \
			or str(contract.get("center_display_mobile_cost", "")) != "static_shadowless_imported_glb_no_process_animation_under_3000_triangles":
		failures.append("center display must retain glossy glass detail within its static mobile budget")
	if str(contract.get("center_display_source", "")) != "res://tools/3d/generate_sichuan_center_compass_v2.py" \
			or int(contract.get("center_display_triangle_budget", -1)) != 1044 \
			or int(contract.get("center_display_material_count", -1)) != 5 \
			or int(contract.get("center_display_object_count", -1)) != 9 \
			or bool(contract.get("center_display_runtime_mesh_generation", true)):
		failures.append("center display Blender provenance or mobile geometry budget contract mismatch")
	if str(contract.get("center_glass_finish", "")) != "low_gloss_smoked_jade_alpha_blend_with_restrained_transmission" \
			or str(contract.get("center_counter_finish", "")) != "opaque_matte_smoked_jade_without_emission_or_transmission" \
			or str(contract.get("center_outer_keyline", "")) != "removed_clean_glass_and_recess_silhouette" \
			or float(contract.get("center_inlay_max_rise_world", INF)) > 0.0061 \
			or str(contract.get("wall_count_surface_plane", "")) != "flush_coplanar_glass_inlay_without_visible_sidewalls_at_felt_y_0_155":
		failures.append("center display must remain a glossy glass inlay flush with the felt")
	if contract.get("center_direction_labels", []) != ["东", "南", "西", "北"] \
			or str(contract.get("center_component_boundaries", "")) != "continuous_glass_plane_separated_by_coplanar_graphite_hairlines_without_colour_overlap" \
			or contract.get("center_active_encoding", []) != ["opaque_vivid_red_main_field_and_both_chamfer_fills", "warm_ivory_direction_glyph_with_dark_outline"] \
			or str(contract.get("center_active_color_hex", "")) != "A13D2D" \
			or str(contract.get("center_active_geometry", "")) != "segmented_coplanar_top_faces_with_circular_counter_cutout_without_extrusion_or_dark_sidewalls" \
			or absf(float(contract.get("center_counter_bezel_radius", 0.0)) - 0.455) > 0.0001 \
			or absf(float(contract.get("center_active_counter_cutout_radius", 0.0)) - 0.460) > 0.0001 \
			or absf(float(contract.get("center_separator_corner_angle_degrees", 0.0)) - 27.75854) > 0.0001 \
			or contract.get("center_active_sector_spans_degrees", []) != [124.48292, 55.51708, 124.48292, 55.51708] \
			or str(contract.get("center_counter_highlight", "")) != "restrained_antique_bronze_high_roughness_low_clearcoat":
		failures.append("center turn panel lost its four directions, separator-aligned coverage, or redundant active-turn encoding")
	if str(contract.get("self_hand_pitch_policy", "")) != "compact_visible_seam_0_83" \
			or absf(float(contract.get("self_hand_world_pitch", 0.0)) - 0.83) > 0.001:
		failures.append("human hand must use the compact 0.83 centre pitch with a visible seam")
	var self_hand_gap := float(contract.get("self_hand_world_gap", INF))
	if self_hand_gap < 0.010 or self_hand_gap > 0.022:
		failures.append("human hand compact pitch must retain a restrained positive physical gap")
	if str(contract.get("table_divider_finish", "")) != "subsurface_low_contrast_outer_boundary_with_fragmented_center_corners":
		failures.append("table dividers must use a quiet outer boundary and fragmented center corners")
	if str(contract.get("opponent_hand_contact_policy", "")) != "shared_glb_half_height_plus_12mm_felt_clearance" \
			or absf(float(contract.get("opponent_hand_contact_clearance", 0.0)) - 0.012) > 0.001 \
			or str(contract.get("opponent_hand_shadow", "")) != "physical_body_casts_short_soft_single_key_contact_shadow":
		failures.append("opponent racks must sit above the felt with a short soft contact-shadow contract")
	if str(contract.get("concealed_gang_presentation", "")) != "outer_faces_middle_jade_backs":
		failures.append("concealed kong contract must expose the two outer faces and conceal the two middle tiles")
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
	if str(contract.get("center_compass_asset", "")) != "res://res/art/3d/sichuan_center_compass_v2.glb" \
			or not bool(contract.get("center_compass_pbr_preserved", false)):
		failures.append("center compass provenance asset must remain available")
	var camera_fov := float(contract.get("camera_fov", 0.0))
	if camera_fov < 49.0 or camera_fov > 50.0:
		failures.append("3D stage horizontal FOV is outside the camera reconstruction gate")


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
				failures.append("human hand tile does not request the shared warm-ivory face layer")
				return
			var human_body := human_tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
			var human_material := human_body.material_override as StandardMaterial3D if human_body != null else null
			if human_material == null or human_material.emission_enabled \
					or human_material.roughness < 0.36 or human_material.clearcoat > 0.22:
				failures.append("human hand ivory material does not share the broad-highlight physical exposure")
				return
			var human_face_material := human_tile.face_mesh.get_active_material(0) as StandardMaterial3D
			if not human_tile.face_mesh.visible or human_face_material == null \
					or human_face_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
					or human_face_material.emission_enabled \
					or not human_face_material.albedo_color.is_equal_approx(SichuanTile3D.SELF_HAND_FACE_WHITE):
				failures.append("human hand face does not use the shared non-emissive warm-ivory target")
				return
			break
	var shared_opponent_back_material: StandardMaterial3D
	for seat in [1, 2, 3]:
		var found := false
		for key_value in nodes.keys():
			if not str(key_value).begins_with("hand_%d_" % seat):
				continue
			found = true
			var tile := nodes[key_value] as SichuanTile3D
			var owner_mesh := tile.face_mesh
			var back_mesh := tile.concealed_cap_mesh
			var owner_material := owner_mesh.get_surface_override_material(0) as StandardMaterial3D
			var back_material := back_mesh.get_surface_override_material(0) as StandardMaterial3D
			if tile.concealed_surface_flip:
				failures.append("AI seat %d still swaps cover materials instead of orienting the physical back layer" % seat)
				return
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
			var physical_back := tile.body_root.find_child("MahjongTileBack", true, false) as MeshInstance3D
			var physical_body := tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
			var centre_direction := Vector3(-tile.global_position.x, 0.0, -tile.global_position.z).normalized()
			if physical_back == null or physical_body == null:
				failures.append("AI seat %d lost the manufactured body/back mesh pair" % seat)
				return
			var physical_back_material := physical_back.material_override as StandardMaterial3D
			var physical_body_material := physical_body.material_override as StandardMaterial3D
			if physical_body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				failures.append("AI seat %d manufactured body cannot cast its physical contact shadow" % seat)
				return
			if not _is_reference_normal_tile_back_material(back_material) \
					or physical_back_material != back_material:
				failures.append("AI seat %d physical jade layer and table-facing cover do not share one PBR material" % seat)
				return
			if shared_opponent_back_material == null:
				shared_opponent_back_material = back_material
			elif back_material != shared_opponent_back_material:
				failures.append("all three opponents do not share the exact cached PBR back material")
				return
			if seat == 2:
				if not _is_far_rack_ivory_material(owner_material):
					failures.append("far hand owner-facing cap is not the figure-2 ivory material")
					return
				if not _is_far_rack_ivory_material(physical_body_material):
					failures.append("far hand top body is not locally lifted to the figure-2 ivory white")
					return
			var physical_layer_offset := (
				_mesh_world_center(physical_back) - _mesh_world_center(physical_body)
			).dot(centre_direction)
			if physical_layer_offset <= 0.001:
				failures.append(
					"AI seat %d physical jade layer remains on the owner/outside edge instead of the table-centre edge (offset=%.5f)"
					% [seat, physical_layer_offset]
				)
				return
			var top_axis := tile.transform.basis.z.normalized()
			var horizontal_top := Vector3(top_axis.x, 0.0, top_axis.z)
			if absf(absf(top_axis.y) - 1.0) > 0.001 or horizontal_top.length() > 0.001:
				failures.append(
					"AI seat %d concealed tile is not exactly perpendicular to the table (top=%s horizontal=%.5f)"
					% [seat, top_axis, horizontal_top.length()]
				)
				return
			var half_height := SichuanTile3D.TILE_SIZE.z * tile.scale.y * 0.5
			var physical_bottom_y := tile.global_position.y - half_height
			var expected_bottom_y := SichuanTableStage3D.TABLETOP_CONTACT_Y + SichuanTableStage3D.UPRIGHT_HAND_CLEARANCE_Y
			if absf(physical_bottom_y - expected_bottom_y) > 0.002:
				failures.append(
					"AI seat %d upright rack is embedded or floating (bottom=%.4f expected=%.4f)"
					% [seat, physical_bottom_y, expected_bottom_y]
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
	var groups: Dictionary = {}
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if not key.begins_with("meld_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile == null:
			continue
		var parts := key.split("_")
		if parts.size() < 4:
			continue
		var group_prefix := "meld_%s_%s_" % [parts[1], parts[2]]
		if not groups.has(group_prefix):
			groups[group_prefix] = []
		(groups[group_prefix] as Array).append(tile)
	# Only concealed-gang groups have the layered flat-result flag. Keep the two
	# outer face-up tiles in the group so the four-tile contract can validate the
	# complete physical formation, not just the two middle backs.
	for group_prefix in groups.keys().duplicate():
		var has_flat_middle := false
		for tile_value in groups[group_prefix] as Array:
			if (tile_value as SichuanTile3D).flat_concealed_result:
				has_flat_middle = true
				break
		if not has_flat_middle:
			groups.erase(group_prefix)
	if groups.is_empty():
		failures.append("concealed kong matrix has no physical middle jade-back tiles")
		return
	for group_prefix in groups.keys():
		_verify_concealed_gang_group(str(group_prefix), groups[group_prefix] as Array, failures)


func _verify_concealed_gang_group(group_prefix: String, gang_tiles: Array, failures: Array[String]) -> void:
	if gang_tiles.size() != 4:
		failures.append("%s concealed kong must contain four distinct tiles, count=%d" % [group_prefix, gang_tiles.size()])
		return
	gang_tiles.sort_custom(func(a: SichuanTile3D, b: SichuanTile3D) -> bool: return a.tile_id < b.tile_id)
	for index in range(gang_tiles.size()):
		var tile := gang_tiles[index] as SichuanTile3D
		var should_show_face := index == 0 or index == gang_tiles.size() - 1
		if tile.showing_face != should_show_face:
			failures.append("%s tile %d face state violates outer-face/middle-back contract" % [group_prefix, index])
		if not should_show_face and not tile.flat_concealed_result:
			failures.append("%s middle tile %d must use the layered jade-back surface" % [group_prefix, index])
		if not should_show_face:
			if tile.concealed_surface_flip:
				failures.append("%s middle tile %d still fakes the back by swapping cover materials" % [group_prefix, index])
				continue
			if tile.position.y < 0.32:
				failures.append("%s middle tile %d sinks into the table after the physical back flip" % [group_prefix, index])
			var back_material := tile.concealed_cap_mesh.get_surface_override_material(0) as StandardMaterial3D
			if not _is_reference_flat_tile_back_material(back_material):
				failures.append("%s middle tile %d does not use the compensated deep-emerald PBR back material" % [group_prefix, index])
			elif tile.concealed_cap_mesh.mesh == null or tile.concealed_cap_mesh.mesh.get_aabb().size.y < 0.01:
				failures.append("%s middle tile %d lost the physical resin-edge bevel" % [group_prefix, index])
			var physical_back := tile.body_root.find_child("MahjongTileBack", true, false) as MeshInstance3D
			var physical_body := tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
			var physical_material := physical_back.material_override as StandardMaterial3D if physical_back != null else null
			if physical_back == null or physical_body == null \
					or not _is_reference_flat_tile_back_material(physical_material):
				failures.append("%s middle tile %d physical jade layer is missing or still white" % [group_prefix, index])
			elif _mesh_world_center(physical_back).y <= _mesh_world_center(physical_body).y + 0.001:
				failures.append("%s middle tile %d physical jade layer is not facing upward" % [group_prefix, index])


func _verify_concealed_gang_matrix(
	stage: SichuanTableStage3D,
	base_snapshot: Dictionary,
	all_hands: Array,
	failures: Array[String]
) -> void:
	var matrix_snapshot := base_snapshot.duplicate(true)
	var matrix_players: Array = (base_snapshot.get("players", []) as Array).duplicate(true)
	for seat in range(4):
		matrix_players[seat]["melds"] = [{
			"type": "gang",
			"gang_subtype": "an_gang",
			"from_seat": seat,
			"tiles": _tiles(62000 + seat * 100, 4, seat + 2),
		}]
	matrix_snapshot["players"] = matrix_players
	stage.render_snapshot(matrix_snapshot, all_hands, false, -1, {})
	await process_frame
	_verify_concealed_gang(stage, failures)


func _verify_meld_tile_model_consistency(
	stage: SichuanTableStage3D,
	fixture_name: String,
	failures: Array[String]
) -> void:
	var reference_body_mesh: Mesh
	var reference_back_mesh: Mesh
	var meld_count := 0
	var contract := stage.get_visual_contract()
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		if not str(key_value).begins_with("meld_"):
			continue
		meld_count += 1
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		var owner_seat := int(str(key_value).split("_")[1])
		var expected_scalar := float(contract.get("self_meld_scale", 0.0)) if owner_seat == 0 else SichuanTableStage3D.MELD_SCALE
		var group_prefix := "meld_%d_%d_" % [owner_seat, int(str(key_value).split("_")[2])]
		var flat_group := false
		for sibling_key in (stage.get("tile_nodes") as Dictionary).keys():
			if str(sibling_key).begins_with(group_prefix) and ((stage.get("tile_nodes") as Dictionary)[sibling_key] as SichuanTile3D).flat_concealed_result:
				flat_group = true
				break
		# 暗杠中间两张翻扣只改变姿态；副露组仍沿用座位原有的统一倍率。
		var expected_scale := Vector3.ONE * expected_scalar
		var expected_world_size := SichuanTile3D.TILE_SIZE * expected_scalar
		if not tile.scale.is_equal_approx(expected_scale):
			failures.append("%s %s uses non-uniform or wrong settled meld scale: %s" % [fixture_name, key_value, tile.scale])
			continue
		var world_size := SichuanTile3D.TILE_SIZE * tile.scale
		if not world_size.is_equal_approx(expected_world_size):
			failures.append("%s %s changes tile width/thickness/length proportions: %s" % [fixture_name, key_value, world_size])
		if tile.flat_concealed_result:
			var flat_bounds := _flat_physical_world_aabb(tile)
			if flat_bounds.position.y < 0.085:
				failures.append("%s %s concealed tile body is embedded in the table (min_y=%.3f)" % [fixture_name, key_value, flat_bounds.position.y])
			if flat_bounds.size.y < SichuanTile3D.TILE_SIZE.y * expected_scalar - 0.006:
				failures.append("%s %s concealed tile lost physical thickness after the flip (height=%.3f)" % [fixture_name, key_value, flat_bounds.size.y])
		var physical_body := tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
		var physical_back := tile.body_root.find_child("MahjongTileBack", true, false) as MeshInstance3D
		if physical_body == null or physical_back == null:
			failures.append("%s %s does not instantiate the shared body/back GLB hierarchy" % [fixture_name, key_value])
			continue
		if reference_body_mesh == null:
			reference_body_mesh = physical_body.mesh
			reference_back_mesh = physical_back.mesh
		elif physical_body.mesh != reference_body_mesh or physical_back.mesh != reference_back_mesh:
			failures.append("%s %s substitutes a different mesh for a peng/gang tile" % [fixture_name, key_value])
		if not physical_body.scale.is_equal_approx(Vector3.ONE) or not physical_back.scale.is_equal_approx(Vector3.ONE):
			failures.append("%s %s applies child-level compression to the shared tile model" % [fixture_name, key_value])
	if meld_count == 0:
		failures.append("%s has no meld tiles for model-consistency verification" % fixture_name)


func _verify_target_reference_hand_anchors(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var nodes: Dictionary = stage.get("tile_nodes")
	var contract := stage.get_visual_contract()
	var expected_centers := [
		Vector3(float(contract.get("self_hand_center_x", 0.0)), 0.25, 3.57),
		Vector3(-5.92, SichuanTableStage3D.TABLETOP_CONTACT_Y + SichuanTile3D.TILE_SIZE.z * SichuanTableStage3D.SIDE_HAND_SCALE * 0.5 + SichuanTableStage3D.UPRIGHT_HAND_CLEARANCE_Y, -1.22),
		Vector3(-1.40, SichuanTableStage3D.TABLETOP_CONTACT_Y + SichuanTile3D.TILE_SIZE.z * SichuanTableStage3D.FAR_HAND_SCALE * 0.5 + SichuanTableStage3D.UPRIGHT_HAND_CLEARANCE_Y, -6.00),
		Vector3(5.92, SichuanTableStage3D.TABLETOP_CONTACT_Y + SichuanTile3D.TILE_SIZE.z * SichuanTableStage3D.SIDE_HAND_SCALE * 0.5 + SichuanTableStage3D.UPRIGHT_HAND_CLEARANCE_Y, -1.22),
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
	if self_meld_z.is_empty() or self_meld_z.min() < 3.52 or self_meld_z.max() > 3.62:
		failures.append("human melds are not aligned with the lower-left hand rail")
	var self_hand_left := INF
	var self_meld_right := -INF
	for key_value in nodes.keys():
		var key := str(key_value)
		if key.begins_with("hand_0_"):
			self_hand_left = minf(self_hand_left, (nodes[key_value] as Node3D).position.x)
		elif key.begins_with("meld_0_"):
			self_meld_right = maxf(self_meld_right, (nodes[key_value] as Node3D).position.x)
	var tile_width := SichuanTile3D.TILE_SIZE.x * float(contract.get("self_hand_scale", 0.0))
	var edge_gap := self_hand_left - self_meld_right - tile_width
	if edge_gap < 0.04 or edge_gap > 0.35:
		failures.append("human meld/hand edge gap is not compact and readable: %.3f" % edge_gap)


func _verify_latest_marker(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var marker_count := 0
	for tile_value in (stage.get("tile_nodes") as Dictionary).values():
		var tile := tile_value as SichuanTile3D
		if tile.latest_marker != null and tile.latest_marker.visible:
			marker_count += 1
	if marker_count != 1:
		failures.append("exactly one latest-discard marker must remain visible")


func _verify_center_wall_count_3d(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var anchor := stage.get_node_or_null("CenterWallCount3DAnchor") as Node3D
	var label := stage.get_node_or_null("CenterWallCount3DAnchor/CenterWallCount3DText") as Label3D
	if anchor == null or label == null:
		failures.append("center wall count must instantiate its table-surface 3D text hierarchy")
		return
	if label.text != "40":
		failures.append("center 3D wall count text does not match the current wall")
	if not label.modulate.is_equal_approx(Color("E8DFC8")) \
			or not label.outline_modulate.is_equal_approx(Color("071713")) \
			or label.outline_size < 4 or label.outline_size > 6:
		failures.append("center wall count must use warm ivory with a restrained dark 4-6px outline")
	if stage.get_node_or_null("CenterWallCount3DAnchor/CenterWallCount3DRotor") != null:
		failures.append("center wall count must not retain the rotating rotor")
	var model := stage.get_node_or_null("CenterWallCount3DAnchor/PremiumBlenderCenterPanel") as Node3D
	if model == null:
		failures.append("center panel must mount the imported Blender instrument as its physical hierarchy")
		return
	for mesh_name in [
		"CenterRecessBed", "CenterGlassInlay", "DirectionSeparatorHairlines",
		"CounterBronzeBezel", "CounterGlassLens",
	]:
		if model.find_child(mesh_name, true, false) as MeshInstance3D == null:
			failures.append("Blender center instrument is missing authored mesh %s" % mesh_name)
	var imported_meshes: Array[MeshInstance3D] = []
	_collect_center_meshes(model, imported_meshes)
	if model.find_child("CenterBronzeKeyline", true, false) != null:
		failures.append("center instrument outer bronze/yellow keyline must remain removed")
	if imported_meshes.size() != 9:
		failures.append("Blender center instrument must retain its simplified 9-object mobile render budget")
	var highest_surface_y := -INF
	var restrained_smoked_glass_count := 0
	var found_matte_counter := false
	var found_flat_recess_bed := false
	var found_integrated_recess_material := false
	var found_restrained_bronze_material := false
	var flat_active_sector_count := 0
	var exact_active_red_sector_count := 0
	var counter_clear_active_sector_count := 0
	var separator_aligned_active_sector_count := 0
	var minimum_active_vertex_radius := INF
	var first_active_red_diagnostic := "missing"
	for mesh_instance in imported_meshes:
		if mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				or mesh_instance.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
			failures.append("Blender center meshes must not add mobile shadow or GI cost: %s" % mesh_instance.name)
			break
		if mesh_instance.material_override != null:
			failures.append("Blender center PBR material must not be replaced at runtime: %s" % mesh_instance.name)
			break
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() < 1 \
				or not (mesh_instance.mesh.surface_get_material(0) is BaseMaterial3D):
			failures.append("Blender center mesh must retain an imported PBR surface material: %s" % mesh_instance.name)
			break
		var material := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
		if mesh_instance.name == &"CenterGlassInlay" \
				and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				and Color(material.albedo_color, 1.0).is_equal_approx(Color("123E35")) \
				and absf(material.albedo_color.a - 0.92) <= 0.01 \
				and absf(material.roughness - 0.18) <= 0.01 \
				and absf(material.metallic - 0.02) <= 0.01:
			restrained_smoked_glass_count += 1
		if mesh_instance.name == &"CounterGlassLens" \
				and material.resource_name == "CenterMatteSmokedJadeCounter" \
				and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
				and material.albedo_color.is_equal_approx(Color("163B32")) \
				and absf(material.albedo_color.a - 1.0) <= 0.001 \
				and material.roughness >= 0.68 and material.roughness <= 0.76 \
				and material.metallic <= 0.03 \
				and not material.emission_enabled:
			found_matte_counter = true
		if mesh_instance.name == &"CenterRecessBed" \
				and material.albedo_color.is_equal_approx(Color("0B2C26")) \
				and absf(material.roughness - 0.58) <= 0.01 \
				and absf(material.metallic - 0.06) <= 0.01:
			found_integrated_recess_material = true
		if mesh_instance.name == &"CounterBronzeBezel" \
				and material.albedo_color.is_equal_approx(Color("8F744B")) \
				and absf(material.roughness - 0.58) <= 0.01 \
				and absf(material.metallic - 0.42) <= 0.01:
			found_restrained_bronze_material = true
		var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if mesh_instance.name == &"CenterRecessBed" and world_bounds.size.y <= 0.0005:
			found_flat_recess_bed = true
		if str(mesh_instance.name).begins_with("DirectionActive"):
			if first_active_red_diagnostic == "missing":
				first_active_red_diagnostic = "albedo=%s shading=%d emission=%s clearcoat=%s" % [
					material.albedo_color,
					material.shading_mode,
					material.emission_enabled,
					material.clearcoat_enabled,
				]
			if world_bounds.size.y <= 0.0005:
				flat_active_sector_count += 1
			var sector_minimum_radius := INF
			var near_counter_angles: Array[float] = []
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for local_vertex in vertices:
					var world_vertex: Vector3 = mesh_instance.global_transform * local_vertex
					var center_offset := world_vertex - anchor.global_position
					sector_minimum_radius = minf(
						sector_minimum_radius,
						Vector2(center_offset.x, center_offset.z).length()
					)
					var radial_distance := Vector2(center_offset.x, center_offset.z).length()
					if radial_distance >= 0.455 and radial_distance <= 0.465:
						near_counter_angles.append(fposmod(atan2(center_offset.z, center_offset.x), TAU))
			minimum_active_vertex_radius = minf(minimum_active_vertex_radius, sector_minimum_radius)
			if sector_minimum_radius >= 0.458:
				counter_clear_active_sector_count += 1
			var sector_index := int(str(mesh_instance.name).trim_prefix("DirectionActive"))
			var expected_span := 124.48292 if sector_index % 2 == 0 else 55.51708
			var actual_span := _smallest_circular_span_degrees(near_counter_angles)
			if absf(actual_span - expected_span) <= 0.25:
				separator_aligned_active_sector_count += 1
			var expected_active_red := Color("7F3226")
			if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
					and material.albedo_color.is_equal_approx(expected_active_red) \
					and not material.emission_enabled \
					and not material.clearcoat_enabled:
				exact_active_red_sector_count += 1
		highest_surface_y = maxf(highest_surface_y, world_bounds.end.y)
	if restrained_smoked_glass_count != 1:
		failures.append("the outer center inlay must retain its restrained smoked-jade glass")
	if not found_matte_counter:
		failures.append("the wall-count lens must use the separate opaque matte smoked-jade material")
	if not found_integrated_recess_material:
		failures.append("center recess must retain the lighter high-roughness graphite-jade material")
	if not found_restrained_bronze_material:
		failures.append("center counter bezel must retain restrained high-roughness antique bronze")
	if not found_flat_recess_bed:
		failures.append("center recess bed must be a coplanar face without an outer dark side wall")
	if flat_active_sector_count != 4:
		failures.append("all four active sectors must be coplanar top faces without dark side walls")
	if counter_clear_active_sector_count != 4:
		failures.append("all four active sectors must remain outside the counter bezel (minimum vertex radius %.4f)" % minimum_active_vertex_radius)
	if separator_aligned_active_sector_count != 4:
		failures.append("all four active sectors must span the exact separator-defined region instead of equal 90-degree wedges")
	if exact_active_red_sector_count != 4:
		failures.append("all four active sectors must import the unlit filmic-compensated #A13D2D material without emission or clearcoat drift (%s)" % first_active_red_diagnostic)
	if highest_surface_y > SichuanTableStage3D.TABLETOP_CONTACT_Y + 0.0101:
		failures.append("center inlay rises too far above the felt plane: %.4f" % highest_surface_y)
	if absf(anchor.position.y - SichuanTableStage3D.TABLETOP_CONTACT_Y) > 0.001 \
			or not anchor.rotation_degrees.is_zero_approx():
		failures.append("center turn panel must be fitted at the physical tabletop plane")
	var segments: Array[MeshInstance3D] = stage.get("center_direction_active_overlays")
	var direction_labels: Array[Label3D] = stage.get("center_direction_labels")
	if segments.size() != 4 or direction_labels.size() != 4:
		failures.append("center turn panel must expose exactly four Blender lacquer overlays and labels")
	else:
		for index in range(4):
			if direction_labels[index].text != ["东", "南", "西", "北"][index]:
				failures.append("center direction label order does not match the supplied reference")
		var expected_segments := [2, 3, 0, 1]
		var expected_directions := ["西", "北", "东", "南"]
		for seat in range(4):
			stage.call("_set_center_panel_state", 40, seat)
			var expected_segment: int = expected_segments[seat]
			if int(stage.get("center_active_turn_seat")) != seat:
				failures.append("3D center did not retain current seat %d" % seat)
			for index in range(4):
				var should_be_active := index == expected_segment
				var expected_color := Color("FFF4E0") if should_be_active else Color.WHITE
				var expected_outline := Color("2A090B") if should_be_active else Color("071713")
				if segments[index].visible != should_be_active \
						or segments[index].material_override != null \
						or direction_labels[index].modulate != expected_color \
						or direction_labels[index].outline_modulate != expected_outline:
					failures.append("seat %d must activate only the %s segment in the 3D center" % [seat, expected_directions[seat]])
		stage.call("_set_center_panel_state", 40, -1)
		if int(stage.get("center_active_turn_seat")) != -1:
			failures.append("3D center must preserve a neutral state when no turn seat exists")
		for index in range(4):
			if segments[index].visible or direction_labels[index].modulate != Color.WHITE \
					or direction_labels[index].outline_modulate != Color("071713"):
				failures.append("3D center neutral state must not falsely highlight a direction")
				break
		stage.call("_set_center_panel_state", 40, 0)
	stage.set_reduced_motion(false)
	var transform_before := anchor.transform
	for _frame in range(4):
		await process_frame
	if not anchor.transform.is_equal_approx(transform_before):
		failures.append("center wall count must remain static without rotation or bobbing")
	stage.set_reduced_motion(true)


func _collect_center_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_center_meshes(child, result)


func _verify_new_draw_marker(stage: SichuanTableStage3D, draw_tile_id: int, failures: Array[String]) -> void:
	var marker_count := 0
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile.new_draw_marker != null and tile.new_draw_marker.visible:
			marker_count += 1
			if tile.tile_id != draw_tile_id:
				failures.append("new-draw marker is attached to the wrong tile id")
			if tile.state_marker != null and tile.state_marker.visible:
				failures.append("new-draw tile still carries a full-tile color plane")
			if tile.new_draw_marker.name != "NewDrawRotatingBlueDiamond":
				failures.append("new-draw tile does not expose the blue-diamond marker")
			var draw_yaw_pivot := tile.new_draw_marker.get_parent() as Node3D
			if draw_yaw_pivot == null or draw_yaw_pivot.name != "NewDrawWorldYawPivot":
				failures.append("new-draw marker does not isolate its table-world yaw from the self-hand tilt")
			else:
				var world_yaw_axis := tile.new_draw_marker.global_transform.basis.y.normalized()
				if world_yaw_axis.dot(Vector3.UP) < 0.999:
					failures.append("new-draw marker does not rotate around the same world-vertical axis as the latest discard")
			if tile.new_draw_marker.position.y < 0.33 or tile.new_draw_marker.position.y > 0.36:
				failures.append("new-draw diamond is not seated tightly above the drawn tile")
			if tile.new_draw_marker.position.z < -0.14 or tile.new_draw_marker.position.z > -0.10:
				failures.append("new-draw diamond still sits too far toward the table")
			var mesh := tile.new_draw_marker.mesh as ImmediateMesh
			if mesh == null or mesh.get_aabb().size.x < 0.15 or mesh.get_aabb().size.x > 0.17:
				failures.append("new-draw diamond is not the requested compact solid geometry")
			var material := tile.new_draw_marker.get_surface_override_material(0) as StandardMaterial3D
			if material == null or not material.albedo_color.is_equal_approx(Color("42A5FF")):
				failures.append("new-draw diamond is not blue")
			elif material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or material.emission_enabled or material.clearcoat_enabled:
				failures.append("new-draw diamond must remain pure blue without a lighting gradient")
	if marker_count != 1:
		failures.append("exactly one new-draw marker must be visible")


func _verify_selected_marker(stage: SichuanTableStage3D, selected_tile_id: int, failures: Array[String]) -> void:
	var selected_count := 0
	for tile_value in (stage.get("tile_nodes") as Dictionary).values():
		var tile := tile_value as SichuanTile3D
		if tile.tile_id != selected_tile_id:
			continue
		selected_count += 1
		if tile.selected_marker != null and tile.selected_marker.visible:
			failures.append("selected tile still shows a checkmark or overlay graphic")
		if tile.selected_marker != null and tile.selected_marker.mesh != null:
			failures.append("selected tile retains a renderable selection-icon mesh")
		if tile.state_marker != null and tile.state_marker.visible:
			failures.append("selected tile still carries a full-tile color plane")
		if absf(tile.position.y - 0.36) > 0.01:
			failures.append("selected human tile lost its 0.11 physical lift")
	if selected_count != 1:
		failures.append("selected tile id must resolve to exactly one physical hand tile")


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
		if tile.winning_source_label == null or tile.winning_source_label.visible:
			failures.append("meld source marker must not show a seat label beside the peng/gang tiles")
		var material := tile.winning_source_marker.get_surface_override_material(0) as StandardMaterial3D
		if material == null or not material.albedo_color.is_equal_approx(SichuanTile3D.SOURCE_ARROW_COLOR):
			failures.append("meld source marker is not the requested sky-blue direction arrow")
		elif material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or material.emission_enabled:
			failures.append("meld source arrow must stay a flat sky-blue face marker without a lighting gradient")
		if not tile.winning_source_marker.scale.is_equal_approx(Vector3.ONE):
			failures.append("meld source arrow must retain its compact reference proportions")
		var arrow_mesh := tile.winning_source_marker.mesh
		if arrow_mesh == null or arrow_mesh.get_aabb().size.x > 0.10 or arrow_mesh.get_aabb().size.z > 0.13:
			failures.append("meld source arrow must use the compact flat short-stem reference silhouette")
		if tile.winning_source_marker.position.y < 0.375 or tile.winning_source_marker.position.y > 0.380:
			failures.append("meld source arrow is not seated immediately above the marked tile face")
		if absf(tile.winning_source_marker.position.z) > 0.08:
			failures.append("meld source arrow is not centred above the marked tile")
		var expected_tile_id := 30000 + owner_seat * 100 + 1
		if tile.tile_id != expected_tile_id:
			failures.append("seat %d meld arrow must be attached to the second/centre tile" % owner_seat)
	if marker_count != 3:
		failures.append("three exposed fixture melds must each show one colored source arrow, got %d" % marker_count)


func _verify_four_source_meld_matrix(
	stage: SichuanTableStage3D,
	base_snapshot: Dictionary,
	all_hands: Array,
	failures: Array[String]
) -> void:
	var matrix_snapshot := base_snapshot.duplicate(true)
	var matrix_players: Array = (base_snapshot.get("players", []) as Array).duplicate(true)
	for seat in range(4):
		var is_gang := seat in [1, 2]
		matrix_players[seat]["melds"] = [{
			"type": "gang" if is_gang else "peng",
			"gang_subtype": "ming_gang" if seat == 1 else ("bu_gang" if seat == 2 else ""),
			"from_seat": (seat + 1) % 4,
			"tiles": _tiles(61000 + seat * 100, 4 if is_gang else 3, seat + 2),
		}]
	matrix_snapshot["players"] = matrix_players
	stage.render_snapshot(matrix_snapshot, all_hands, false, -1, {})
	await process_frame
	var source_seats := {}
	var owner_seats := {}
	var marker_count := 0
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if not key.begins_with("meld_"):
			continue
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if tile.winning_source_marker == null or not tile.winning_source_marker.visible:
			continue
		marker_count += 1
		var owner_seat := int(key.split("_")[1])
		owner_seats[owner_seat] = true
		source_seats[tile.winning_source_seat] = true
		var expected_tile_id := 61000 + owner_seat * 100 + 1
		if tile.tile_id != expected_tile_id:
			failures.append("four-source matrix owner %d arrow is not attached to tile 2" % owner_seat)
	if marker_count != 4 or owner_seats.size() != 4 or source_seats.size() != 4:
		failures.append(
			"four-source meld matrix incomplete: arrows=%d owners=%s sources=%s"
			% [marker_count, owner_seats.keys(), source_seats.keys()]
		)
	_verify_meld_tile_model_consistency(stage, "peng_ming_gang_and_add_gang_matrix", failures)
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


func _verify_discard_back_layer(stage: SichuanTableStage3D, failures: Array[String]) -> void:
	var found := false
	var nodes: Dictionary = stage.get("tile_nodes")
	var desired: Dictionary = stage.get("last_desired_entries")
	for key_value in nodes.keys():
		if not str(key_value).begins_with("discard_"):
			continue
		found = true
		var tile := nodes[key_value] as SichuanTile3D
		if not tile.showing_face or tile.symbol_mesh == null or not tile.symbol_mesh.visible:
			failures.append("discard river tiles must remain face-up")
			return
		if tile.concealed_cap_mesh == null or not tile.concealed_cap_mesh.visible:
			failures.append("discard river tiles lost the explicit green underside layer")
			return
		var back_material := tile.concealed_cap_mesh.get_surface_override_material(0) as StandardMaterial3D
		if back_material == null or back_material.albedo_color.g <= back_material.albedo_color.r * 1.5:
			failures.append("discard river underside is not the jade back material")
			return
		if not bool(desired.get(key_value, {}).get("show_flat_back_layer", false)):
			failures.append("discard river entry does not declare its physical green underside")
			return
		break
	if not found:
		failures.append("discard river visual contract had no tiles to inspect")


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


func _verify_self_row_pressure(stage: SichuanTableStage3D, base_snapshot: Dictionary, base_hands: Array, failures: Array[String]) -> void:
	var pressure_snapshot := base_snapshot.duplicate(true)
	var pressure_players: Array = pressure_snapshot.get("players", []).duplicate(true)
	var pressure_hands: Array = base_hands.duplicate(true)
	pressure_hands[0] = _tiles(57000, 2, 0)
	var melds: Array = []
	for meld_index in range(4):
		melds.append({
			"type": "gang",
			"gang_subtype": "ming_gang",
			"from_seat": (meld_index + 1) % 4,
			"tiles": _tiles(57100 + meld_index * 10, 4, meld_index),
		})
	pressure_players[0]["melds"] = melds
	pressure_snapshot["players"] = pressure_players
	stage.render_snapshot(pressure_snapshot, pressure_hands, false, -1, {})
	await process_frame

	var contract := stage.get_visual_contract()
	var layout_scale := float(contract.get("self_hand_scale", 0.0))
	if int(contract.get("self_layout_total_tiles", -1)) != 18 \
			or int(contract.get("self_layout_max_tiles", -1)) != 18:
		failures.append("four gangs plus two concealed tiles must exercise exactly the 18-tile layout limit")
	if float(contract.get("self_layout_span", INF)) > float(contract.get("self_layout_available_width", 0.0)) + 0.001:
		failures.append("18-tile human pressure layout overflows the available lower rail")
	if layout_scale >= SichuanTableStage3D.SELF_HAND_SCALE \
			or layout_scale < SichuanTableStage3D.SELF_LAYOUT_MIN_SCALE:
		failures.append("18-tile pressure layout did not apply the bounded automatic scale: %.3f" % layout_scale)
	var pressure_meld_scale := float(contract.get("self_meld_scale", 0.0))

	var hand_left := INF
	var meld_right := -INF
	var self_tile_count := 0
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if not key.begins_with("hand_0_") and not key.begins_with("meld_0_"):
			continue
		self_tile_count += 1
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		var expected_tile_scale := layout_scale if key.begins_with("hand_0_") else pressure_meld_scale
		if not tile.scale.is_equal_approx(Vector3.ONE * expected_tile_scale):
			failures.append("18-tile pressure row contains a differently scaled tile: %s" % key)
		if key.begins_with("hand_0_"):
			hand_left = minf(hand_left, tile.position.x)
		else:
			meld_right = maxf(meld_right, tile.position.x)
	if self_tile_count != 18:
		failures.append("18-tile pressure fixture rendered %d human row tiles" % self_tile_count)
	var tile_width := SichuanTile3D.TILE_SIZE.x * layout_scale
	var edge_gap := hand_left - meld_right - tile_width
	if edge_gap < 0.04 or edge_gap > 0.35:
		failures.append("18-tile pressure row meld/hand edge gap is not compact: %.3f" % edge_gap)


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
				if tile.winning_source_label == null or tile.winning_source_label.visible or tile.winning_source_label.text != "":
					failures.append("winning-source arrow must not include discarder seat text")
				var arrow_material := tile.winning_source_marker.get_surface_override_material(0) as StandardMaterial3D
				if arrow_material == null or not arrow_material.albedo_color.is_equal_approx(SichuanTile3D.SOURCE_ARROW_COLOR):
					failures.append("winning-source arrow must use the same sky-blue color as meld arrows")
				var arrow_mesh := tile.winning_source_marker.mesh
				if arrow_mesh == null or arrow_mesh.get_aabb().size.x > 0.12 or arrow_mesh.get_aabb().size.z > 0.18:
					failures.append("winning-source arrow is not the compact simplified silhouette")
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
	var contract := stage.get_visual_contract()
	var expected_scale := float(contract.get("self_hand_scale", 0.0))
	if not bool(contract.get("self_layout_is_flat", false)):
		failures.append("human self-draw result did not activate the flat-row layout contract")
	if absf(expected_scale - SichuanTableStage3D.SELF_HAND_SCALE) > 0.01:
		failures.append("human flat hand did not preserve the standing tile scale")
	for key_value in (stage.get("tile_nodes") as Dictionary).keys():
		var key := str(key_value)
		if key.begins_with("winning_0_"):
			winning_count += 1
			continue
		if not key.begins_with("hand_0_"):
			continue
		hand_count += 1
		var tile := (stage.get("tile_nodes") as Dictionary)[key_value] as SichuanTile3D
		if not tile.scale.is_equal_approx(Vector3.ONE * expected_scale):
			failures.append("human flat hand uses a different/non-uniform scale at %s" % key)
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
		if tile.concealed_surface_flip or not tile.flat_concealed_result \
				or not tile.concealed_cap_mesh.visible or tile.symbol_mesh.visible:
			failures.append("AI seat %d self-draw did not physically turn the concealed jade layer upward" % seat)
			return
		if tile.position.y < 0.32:
			failures.append("AI seat %d self-draw hand sinks into the table after the physical back flip" % seat)
			return
		var expected_scale := SichuanTableStage3D.FAR_FLAT_CONCEALED_RESULT_SCALE if seat == 2 else SichuanTableStage3D.SIDE_FLAT_CONCEALED_RESULT_SCALE
		if not tile.scale.is_equal_approx(Vector3.ONE * expected_scale):
			failures.append("AI seat %d flat result lost its uniform readability scale" % seat)
			return
		var physical_bounds := _flat_physical_world_aabb(tile)
		if physical_bounds.position.y < 0.085:
			failures.append("AI seat %d self-draw physical tile is embedded in the table (min_y=%.3f)" % [seat, physical_bounds.position.y])
		if physical_bounds.size.y < SichuanTile3D.TILE_SIZE.y * expected_scale - 0.006:
			failures.append("AI seat %d self-draw physical tile is thinner than its shared GLB thickness (height=%.3f)" % [seat, physical_bounds.size.y])
		var back_material := tile.concealed_cap_mesh.get_surface_override_material(0) as StandardMaterial3D
		if not _is_reference_flat_tile_back_material(back_material):
			failures.append("AI seat %d self-draw backs do not use the compensated deep-emerald PBR back material" % seat)
			return
		if tile.concealed_cap_mesh.mesh == null or tile.concealed_cap_mesh.mesh.get_aabb().size.y < 0.01:
			failures.append("AI seat %d self-draw backs lost the physical resin-edge bevel" % seat)
			return
		var physical_back := tile.body_root.find_child("MahjongTileBack", true, false) as MeshInstance3D
		var physical_body := tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
		var physical_material := physical_back.material_override as StandardMaterial3D if physical_back != null else null
		if physical_back == null or physical_body == null \
				or not _is_reference_flat_tile_back_material(physical_material):
			failures.append("AI seat %d self-draw physical jade layer is missing or still white" % seat)
			return
		if _mesh_world_center(physical_back).y <= _mesh_world_center(physical_body).y + 0.001:
			failures.append("AI seat %d self-draw physical jade layer is not facing upward" % seat)
			return
	if hand_count != expected_tiles.size():
		failures.append("AI seat %d self-draw must show all %d backs, got %d" % [seat, expected_tiles.size(), hand_count])


func _is_far_rack_ivory_material(material: StandardMaterial3D) -> bool:
	return material != null \
		and material.albedo_color.is_equal_approx(SichuanTile3D.FAR_RACK_IVORY_COLOR) \
		and not material.emission_enabled \
		and material.roughness >= 0.36


func _is_reference_normal_tile_back_material(material: StandardMaterial3D) -> bool:
	return material != null \
		and material.albedo_color.is_equal_approx(SichuanTile3D.NORMAL_TILE_BACK_COLOR) \
		and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
		and absf(material.roughness - 0.43) <= 0.01 \
		and material.metallic <= 0.03 \
		and material.clearcoat_enabled \
		and absf(material.clearcoat - 0.18) <= 0.01 \
		and absf(material.clearcoat_roughness - 0.34) <= 0.01 \
		and not material.emission_enabled


func _is_reference_flat_tile_back_material(material: StandardMaterial3D) -> bool:
	return material != null \
		and material.albedo_color.is_equal_approx(SichuanTile3D.FLAT_RESULT_JADE_BACK) \
		and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
		and absf(material.roughness - 0.43) <= 0.01 \
		and material.metallic <= 0.03 \
		and material.clearcoat_enabled \
		and absf(material.clearcoat - 0.18) <= 0.01 \
		and absf(material.clearcoat_roughness - 0.34) <= 0.01 \
		and not material.emission_enabled


func _mesh_world_center(mesh_instance: MeshInstance3D) -> Vector3:
	return mesh_instance.global_transform * mesh_instance.get_aabb().get_center()


func _flat_physical_world_aabb(tile: SichuanTile3D) -> AABB:
	var back := tile.body_root.find_child("MahjongTileBack", true, false) as MeshInstance3D
	var body := tile.body_root.find_child("MahjongTileBody", true, false) as MeshInstance3D
	return _mesh_world_aabb(back).merge(_mesh_world_aabb(body))


func _mesh_world_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var local := mesh_instance.get_aabb()
	var corners: Array[Vector3] = []
	for x in [local.position.x, local.end.x]:
		for y in [local.position.y, local.end.y]:
			for z in [local.position.z, local.end.z]:
				corners.append(mesh_instance.global_transform * Vector3(x, y, z))
	var result := AABB(corners[0], Vector3.ZERO)
	for corner in corners.slice(1):
		result = result.expand(corner)
	return result


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
			if absf(hand_tile.transform.basis.z.y) >= 0.05:
				failures.append("AI point-win preserved hand must lie flat")
			if not hand_tile.flat_concealed_result or hand_tile.concealed_surface_flip:
				failures.append("AI point-win preserved hand must use the physical flat-back result")
			var expected_scale := SichuanTableStage3D.FAR_FLAT_CONCEALED_RESULT_SCALE if seat == 2 else SichuanTableStage3D.SIDE_FLAT_CONCEALED_RESULT_SCALE
			if not hand_tile.scale.is_equal_approx(Vector3.ONE * expected_scale):
				failures.append("AI point-win preserved hand did not use the uniform flat-result scale")
			var physical_bounds := _flat_physical_world_aabb(hand_tile)
			if physical_bounds.position.y < 0.085:
				failures.append("AI seat %d point-win physical tile is embedded in the table (min_y=%.3f)" % [seat, physical_bounds.position.y])
			if physical_bounds.size.y < SichuanTile3D.TILE_SIZE.y * expected_scale - 0.006:
				failures.append("AI seat %d point-win physical tile is thinner than its shared GLB thickness (height=%.3f)" % [seat, physical_bounds.size.y])
			var back_material := hand_tile.concealed_cap_mesh.get_surface_override_material(0) as StandardMaterial3D
			if not _is_reference_flat_tile_back_material(back_material):
				failures.append("AI point-win preserved hand lost the compensated deep-emerald PBR back")
			if hand_tile.position.y < 0.32:
				failures.append("AI point-win preserved hand sinks into the table after the physical back flip")
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
			if seat in [1, 3] and tile.position.z > 1.65:
				failures.append("AI seat %d winning tile entered the protected local-hand zone (z=%.3f)" % [seat, tile.position.z])
	if concealed_or_revealed_hand_count != expected_hand_count:
		failures.append("AI discard win must preserve %d flat concealed hand tiles, got %d" % [expected_hand_count, concealed_or_revealed_hand_count])
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
	for path in [
		"res://res/art/3d/mahjong_tile_body.glb",
		"res://res/art/3d/sichuan_table_v2.glb",
		"res://res/art/3d/sichuan_center_compass_v2.glb",
		"res://res/art/3d/sichuan_table.glb",
		"res://shaders/table_plush_felt_3d.gdshader",
	]:
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
