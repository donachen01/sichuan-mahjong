extends SceneTree

const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const REACTION_RESOLVER_SCRIPT := preload("res://scripts/core/reaction_resolver.gd")
const MAIN_SCENE_SCRIPT := preload("res://scripts/game/MainSceneV2.gd")


func _init() -> void:
	var failures: Array[String] = []
	_run_test("missing_suit_blocks_peng_and_gang_on_same_suit", _test_missing_suit_blocks_peng_and_gang_on_same_suit, failures)
	_run_test("non_missing_suit_still_allows_peng_and_gang", _test_non_missing_suit_still_allows_peng_and_gang, failures)
	_run_test("counterclockwise_turn_rotation_and_reaction_distance", _test_counterclockwise_turn_rotation_and_reaction_distance, failures)
	_run_test("chi_is_not_available_in_reaction_candidates", _test_chi_is_not_available_in_reaction_candidates, failures)
	_run_test("forced_discard_requires_missing_suit_first", _test_forced_discard_requires_missing_suit_first, failures)
	_run_test("missing_suit_blocks_add_gang_and_an_gang_only_for_missing_suit", _test_missing_suit_blocks_add_gang_and_an_gang_only_for_missing_suit, failures)
	_run_test("cannot_hu_with_missing_suit_still_in_hand", _test_cannot_hu_with_missing_suit_still_in_hand, failures)
	_run_test("qi_dui_is_blocked_when_exposed_meld_exists", _test_qi_dui_is_blocked_when_exposed_meld_exists, failures)
	_run_test("self_draw_hu_with_exposed_meld_is_detected", _test_self_draw_hu_with_exposed_meld_is_detected, failures)
	_run_test("concealed_gang_last_wall_draw_exposes_gang_self_draw_hu", _test_concealed_gang_last_wall_draw_exposes_gang_self_draw_hu, failures)
	_run_test("multi_win_on_discard_keeps_other_hu_candidates", _test_multi_win_on_discard_keeps_other_hu_candidates, failures)
	_run_test("fan_cap_limits_high_value_hands_to_four_fan", _test_fan_cap_limits_high_value_hands_to_four_fan, failures)
	_run_test("shun_he_lock_blocks_same_fan_but_allows_higher_fan", _test_shun_he_lock_blocks_same_fan_but_allows_higher_fan, failures)
	_run_test("battle_to_end_skips_won_players_when_advancing_turn", _test_battle_to_end_skips_won_players_when_advancing_turn, failures)
	_run_test("dealer_starts_with_14_and_others_hold_13_before_first_draw", _test_dealer_starts_with_14_and_others_hold_13_before_first_draw, failures)
	_run_test("draw_assessment_marks_hua_zhu_and_ting_correctly", _test_draw_assessment_marks_hua_zhu_and_ting_correctly, failures)
	_run_test("draw_assessment_builds_cha_jiao_max_score", _test_draw_assessment_builds_cha_jiao_max_score, failures)
	_run_test("display_hand_sorts_missing_suit_to_right", _test_display_hand_sorts_missing_suit_to_right, failures)
	_run_test("qiang_gang_hu_executes_without_finalizing_add_gang", _test_qiang_gang_hu_executes_without_finalizing_add_gang, failures)
	_run_test("added_gang_remains_available_after_draw_tile_is_kept_in_hand", _test_added_gang_remains_available_after_draw_tile_is_kept_in_hand, failures)
	_run_test("competitive_score_table_applies_basic_score_and_self_draw_bottom", _test_competitive_score_table_applies_basic_score_and_self_draw_bottom, failures)
	_run_test("gang_score_table_applies_sichuan_units", _test_gang_score_table_applies_sichuan_units, failures)
	_run_test("round_scores_apply_to_player_totals_and_persist", _test_round_scores_apply_to_player_totals_and_persist, failures)
	_run_test("next_dealer_uses_first_winner_or_shared_discarder", _test_next_dealer_uses_first_winner_or_shared_discarder, failures)
	_run_test("gang_scores_apply_immediately_while_players_remain", _test_gang_scores_apply_immediately_while_players_remain, failures)
	_run_test("hu_jiao_zhuan_yi_transfers_gang_score_to_winner", _test_hu_jiao_zhuan_yi_transfers_gang_score_to_winner, failures)
	_run_test("draw_does_not_refund_immediate_gang_money", _test_draw_does_not_refund_immediate_gang_money, failures)
	_run_test("draw_score_changes_apply_ting_hua_zhu_and_no_ting_payments", _test_draw_score_changes_apply_ting_hua_zhu_and_no_ting_payments, failures)
	_run_test("draw_cha_jiao_excludes_already_won_players", _test_draw_cha_jiao_excludes_already_won_players, failures)
	_run_test("legacy_tui_gang_refunds_are_ignored", _test_legacy_tui_gang_refunds_are_ignored, failures)
	_run_test("fan_combinations_follow_sichuan_table_and_cap", _test_fan_combinations_follow_sichuan_table_and_cap, failures)
	_run_test("sea_bottom_never_adds_fan", _test_sea_bottom_never_adds_fan, failures)
	_run_test("shun_he_lock_clears_on_own_draw", _test_shun_he_lock_clears_on_own_draw, failures)
	_run_test("hu_jiao_zhuan_yi_supports_multiple_payers", _test_hu_jiao_zhuan_yi_supports_multiple_payers, failures)
	_run_test("hu_jiao_zhuan_yi_applies_immediately", _test_hu_jiao_zhuan_yi_applies_immediately, failures)
	_run_test("multi_payer_gang_is_never_refunded", _test_multi_payer_gang_is_never_refunded, failures)

	if failures.is_empty():
		print("RULE REGRESSION OK: 36/36")
		quit(0)
	else:
		push_error("RULE REGRESSION FAILED:\n- " + "\n- ".join(failures))
		quit(1)


func _run_test(name: String, callable: Callable, failures: Array[String]) -> void:
	var result = callable.call()
	if result is bool and result:
		print("PASS ", name)
	else:
		failures.append("%s -> %s" % [name, str(result)])


func _test_missing_suit_blocks_peng_and_gang_on_same_suit():
	var resolver = REACTION_RESOLVER_SCRIPT.new()
	var game_state = _build_test_game_state()
	var rules = game_state.rules
	var players := [
		_make_player(0, "wan", [_make_tile(1, "wan", 1)]),
		_make_player(1, "tiao", [_make_tile(2, "tiao", 5), _make_tile(3, "tiao", 5), _make_tile(4, "tiao", 5)]),
	]
	var discard_context := {
		"source_seat": 0,
		"tile": _make_tile(9, "tiao", 5),
	}
	var candidates: Array = resolver.build_reaction_candidates(players, discard_context, rules)
	if candidates.is_empty():
		return true
	return "expected no reaction candidate on missing suit tile, got %s" % [candidates]


func _test_non_missing_suit_still_allows_peng_and_gang():
	var resolver = REACTION_RESOLVER_SCRIPT.new()
	var game_state = _build_test_game_state()
	var rules = game_state.rules
	var players := [
		_make_player(0, "tiao", [_make_tile(1, "wan", 1)]),
		_make_player(1, "tiao", [_make_tile(2, "wan", 5), _make_tile(3, "wan", 5), _make_tile(4, "wan", 5)]),
	]
	var discard_context := {
		"source_seat": 0,
		"tile": _make_tile(9, "wan", 5),
	}
	var candidates: Array = resolver.build_reaction_candidates(players, discard_context, rules)
	if candidates.size() != 1:
		return "expected one reaction candidate on non-missing suit tile, got %d" % candidates.size()
	var candidate: Dictionary = candidates[0]
	if not bool(candidate.get("can_peng", false)):
		return "expected peng to remain allowed for non-missing suit"
	if not bool(candidate.get("can_gang", false)):
		return "expected gang to remain allowed for non-missing suit"
	return true


func _test_counterclockwise_turn_rotation_and_reaction_distance():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	if int(game_state._find_next_active_seat_after(0)) != 3:
		return "expected next active seat after self to be seat 3 in counterclockwise order"
	if int(game_state._find_next_active_seat_after(3)) != 2:
		return "expected next active seat after seat 3 to be seat 2 in counterclockwise order"
	if int(game_state._reaction_distance_from_source(0, 3)) != 1:
		return "expected seat 3 to have first reaction priority after seat 0 discard"
	if int(game_state._reaction_distance_from_source(0, 2)) != 2:
		return "expected seat 2 to have second reaction priority after seat 0 discard"
	if int(game_state._reaction_distance_from_source(0, 1)) != 3:
		return "expected seat 1 to have third reaction priority after seat 0 discard"
	return true


func _test_chi_is_not_available_in_reaction_candidates():
	var resolver = REACTION_RESOLVER_SCRIPT.new()
	var game_state = _build_test_game_state()
	var rules = game_state.rules
	var players := [
		_make_player(0, "tiao", [_make_tile(5, "wan", 4)]),
		_make_player(1, "tong", [_make_tile(6, "wan", 2), _make_tile(7, "wan", 3)]),
		_make_player(2, "wan", []),
		_make_player(3, "tiao", []),
	]
	var discard_context := {
		"source_seat": 0,
		"tile": _make_tile(8, "wan", 1),
	}
	var candidates: Array = resolver.build_reaction_candidates(players, discard_context, rules)
	for candidate in candidates:
		if candidate.has("can_chi"):
			return "expected reaction candidates not to expose chi in Sichuan rules"
	return true


func _test_forced_discard_requires_missing_suit_first():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(10, "tiao", 2),
				_make_tile(11, "wan", 3),
			]
		),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.players[0]["hand_count"] = 2
	var blocked := bool(game_state.discard_tile_by_id(0, 11))
	if blocked:
		return "expected non-missing suit discard to be blocked while missing suit remains"
	var allowed := bool(game_state.discard_tile_by_id(0, 10))
	if not allowed:
		return "expected missing suit discard to be allowed"
	return true


func _test_missing_suit_blocks_add_gang_and_an_gang_only_for_missing_suit():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(20, "tiao", 7),
				_make_tile(21, "tong", 9),
				_make_tile(22, "tong", 9),
				_make_tile(23, "tong", 9),
				_make_tile(24, "tong", 9),
			],
			[
				{
					"type": "peng",
					"from_seat": 1,
					"tiles": [
						_make_tile(25, "tiao", 7),
						_make_tile(26, "tiao", 7),
						_make_tile(27, "tiao", 7),
					],
				},
			]
		),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.players[0]["hand_count"] = 5
	if bool(game_state.can_human_add_gang(0)):
		return "expected add gang on missing suit peng to be blocked"
	if not bool(game_state.can_human_an_gang(0)):
		return "expected an gang on non-missing suit to remain allowed"
	return true


func _test_display_hand_sorts_missing_suit_to_right():
	var main_scene_logic = MAIN_SCENE_SCRIPT.new()
	var hand_tiles := [
		_make_tile(30, "tiao", 2),
		_make_tile(31, "wan", 5),
		_make_tile(32, "tong", 3),
		_make_tile(33, "tiao", 7),
	]
	var display: Array = main_scene_logic._build_display_hand_tiles(hand_tiles, -1, "tiao")
	if display.size() != 4:
		return "expected 4 tiles after display sorting"
	if str(display[display.size() - 1].get("suit", "")) != "tiao":
		return "expected last tile suit to be ding-que suit tiao"
	if str(display[display.size() - 2].get("suit", "")) != "tiao":
		return "expected second last tile suit to be ding-que suit tiao"
	return true


func _test_dealer_starts_with_14_and_others_hold_13_before_first_draw():
	var game_state = _build_test_game_state()
	game_state.previous_dealer_seat = 1
	game_state.start_new_round(true)
	if not bool(game_state.complete_opening_roll()):
		return "expected opening roll completion to deal initial hands"
	if int(game_state.current_phase) != int(GAME_STATE_SCRIPT.RoundPhase.DING_QUE):
		return "expected round to enter ding que after opening roll completion"
	for seat in range(4):
		var expected_count := 14 if seat == int(game_state.current_dealer_seat) else 13
		var hand_tiles: Array = game_state.players[seat]["hand_tiles"]
		if hand_tiles.size() != expected_count:
			return "expected seat %d to hold %d tiles after dealing, got %d" % [seat, expected_count, hand_tiles.size()]
	for seat in range(1, 4):
		game_state.players[seat]["ding_que"] = "tiao"
	if not bool(game_state.choose_ding_que(0, "tong")):
		return "expected human player to be able to finish opening ding que"
	if int(game_state.current_phase) != int(GAME_STATE_SCRIPT.RoundPhase.DISCARD):
		return "expected opening ding que completion to enter discard phase, got %s" % game_state.current_phase
	for seat in range(4):
		var expected_count := 14 if seat == int(game_state.current_dealer_seat) else 13
		var hand_tiles: Array = game_state.players[seat]["hand_tiles"]
		if hand_tiles.size() != expected_count:
			return "expected seat %d to still hold %d tiles before first draw/discard handoff, got %d" % [seat, expected_count, hand_tiles.size()]
	if not game_state.last_draw_tile.is_empty():
		return "expected no opening extra draw to be recorded for dealer"
	return true


func _test_cannot_hu_with_missing_suit_still_in_hand():
	var game_state = _build_test_game_state()
	var can_hu := bool(
		game_state.hu_checker.can_hu_with_full_hand(
			[
				_make_tile(40, "wan", 1), _make_tile(41, "wan", 1),
				_make_tile(42, "wan", 2), _make_tile(43, "wan", 3), _make_tile(44, "wan", 4),
				_make_tile(45, "wan", 2), _make_tile(46, "wan", 3), _make_tile(47, "wan", 4),
				_make_tile(48, "tong", 5), _make_tile(49, "tong", 6), _make_tile(50, "tong", 7),
				_make_tile(51, "tiao", 8), _make_tile(52, "tiao", 8), _make_tile(53, "tiao", 8),
			],
			"tiao",
			game_state.rules
		)
	)
	if can_hu:
		return "expected hu to be blocked while missing suit tiles remain in hand"
	return true


func _test_qi_dui_is_blocked_when_exposed_meld_exists():
	var game_state = _build_test_game_state()
	var can_hu := bool(
		game_state.hu_checker.can_hu_with_full_hand(
			[
				_make_tile(200, "wan", 1), _make_tile(201, "wan", 1),
				_make_tile(202, "wan", 2), _make_tile(203, "wan", 2),
				_make_tile(204, "wan", 3), _make_tile(205, "wan", 3),
				_make_tile(206, "tong", 4), _make_tile(207, "tong", 4),
				_make_tile(208, "tong", 5), _make_tile(209, "tong", 5),
				_make_tile(210, "tong", 6),
			],
			"tiao",
			game_state.rules,
			1,
			[
				{
					"type": "peng",
					"from_seat": 1,
					"tiles": [
						_make_tile(211, "wan", 9),
						_make_tile(212, "wan", 9),
						_make_tile(213, "wan", 9),
					],
				},
			]
		)
	)
	if can_hu:
		return "expected qi dui to be invalid when exposed melds already exist"
	return true


func _test_self_draw_hu_with_exposed_meld_is_detected():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(54, "wan", 2), _make_tile(55, "wan", 3), _make_tile(56, "wan", 4),
				_make_tile(57, "wan", 5), _make_tile(58, "wan", 6), _make_tile(59, "wan", 7),
				_make_tile(60, "tong", 3), _make_tile(61, "tong", 4), _make_tile(62, "tong", 5),
				_make_tile(63, "tong", 8), _make_tile(64, "tong", 8),
			],
			[
				{
					"type": "peng",
					"from_seat": 1,
					"tiles": [
						_make_tile(65, "wan", 9),
						_make_tile(66, "wan", 9),
						_make_tile(67, "wan", 9),
					],
				},
			]
		),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.players[0]["hand_count"] = 11
	game_state.last_draw_tile = {
		"seat": 0,
		"tile": _make_tile(64, "tong", 8),
	}
	if not bool(game_state.can_human_self_hu(0)):
		return "expected self-draw hu to be detected even with an exposed peng"
	return true


func _test_concealed_gang_last_wall_draw_exposes_gang_self_draw_hu():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var existing_melds := [
		{
			"type": "peng",
			"from_seat": 1,
			"tiles": [
				_make_tile(680, "tong", 7),
				_make_tile(681, "tong", 7),
				_make_tile(682, "tong", 7),
			],
		},
		{
			"type": "peng",
			"from_seat": 3,
			"tiles": [
				_make_tile(683, "tong", 8),
				_make_tile(684, "tong", 8),
				_make_tile(685, "tong", 8),
			],
		},
	]
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"wan",
			[
				_make_tile(686, "tiao", 2),
				_make_tile(687, "tiao", 2),
				_make_tile(688, "tiao", 2),
				_make_tile(689, "tiao", 2),
				_make_tile(690, "tiao", 1),
				_make_tile(691, "tiao", 3),
				_make_tile(692, "tiao", 4),
				_make_tile(693, "tiao", 5),
			],
			existing_melds
		),
		_make_player(1, "wan", []),
		_make_player(2, "wan", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	# pop_back() makes this the last physical wall tile. The zero wall count
	# after the supplement draw must not suppress the player's Hu action.
	var wall: Array[Dictionary] = [_make_tile(694, "tiao", 1)]
	game_state.wall = wall
	game_state.wall_count = 1
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state.last_draw_tile = {
		"seat": 0,
		"tile": _make_tile(689, "tiao", 2),
	}
	game_state.last_turn_context = {
		"seat": 0,
		"draw_reason": "normal_draw",
	}

	if not bool(game_state.can_human_an_gang(0)):
		return "expected concealed 2-tiao gang to be actionable before the supplement draw"
	if not bool(game_state.execute_human_an_gang(0)):
		return "expected concealed gang execution to succeed"
	if int(game_state.wall_count) != 0:
		return "expected supplement draw to consume the final wall tile"
	if str(game_state.last_turn_context.get("draw_reason", "")) != "gang_draw":
		return "expected supplement draw to preserve gang_draw context"
	if not bool(game_state.can_human_self_hu(0)):
		return "expected Hu action after last-wall gang supplement completed 1-1 / 3-4-5"
	var snapshot: Dictionary = game_state.get_debug_snapshot()
	if not bool(snapshot.get("human_can_self_hu", false)):
		return "expected emitted/public snapshot to expose the Hu action after gang supplement"
	if not bool(game_state.execute_human_self_hu(0)):
		return "expected gang supplement self-draw action to execute"
	if str(game_state.players[0].get("win_type", "")) != "gang_self_draw":
		return "expected the resolved win type to be gang_self_draw"
	var win_events: Array = game_state.settlement_data.get("win_events", [])
	if win_events.size() != 1:
		return "expected one gang-self-draw settlement event"
	var fan_detail: Dictionary = win_events[0].get("fan_detail", {})
	if int(fan_detail.get("capped_fan", -1)) != 2 \
		or int(fan_detail.get("hand_score", -1)) != 4 \
		or int(fan_detail.get("per_payer_score", -1)) != 5:
		return "expected ping-hu exposed-root plus gang-shang-hua to be 2 fan, 4 base + fixed 1 per payer, got %s" % fan_detail
	# The physical last wall tile also triggers the separate draw audit for
	# unresolved players. Strip that audit here to verify the Hu and gang
	# transactions themselves: +15 self-draw and independent +6 gang money.
	var direct_event_data: Dictionary = game_state.settlement_data.duplicate(true)
	direct_event_data["draw_assessment"] = []
	var direct_score_changes: Dictionary = game_state.score_resolver.build_score_changes(
		game_state.players,
		direct_event_data,
		game_state.rules
	)
	if int(direct_score_changes.get(0, 0)) != 21:
		return "expected +15 gang-self-draw and independent +6 concealed-gang money, got %s" % direct_score_changes
	for payer_seat in [1, 2, 3]:
		if int(direct_score_changes.get(payer_seat, 0)) != -7:
			return "expected each payer to pay 5 for Hu plus 2 concealed-gang money, got %s" % direct_score_changes
	return true


func _test_multi_win_on_discard_keeps_other_hu_candidates():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.REACTION
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(0, "tiao", []),
		_make_player(
			1,
			"tiao",
			[
				_make_tile(214, "wan", 2), _make_tile(215, "wan", 3), _make_tile(216, "wan", 4),
				_make_tile(217, "wan", 2), _make_tile(218, "wan", 3), _make_tile(219, "wan", 4),
				_make_tile(220, "tong", 5), _make_tile(221, "tong", 6), _make_tile(222, "tong", 7),
				_make_tile(223, "tong", 1), _make_tile(224, "tong", 2),
				_make_tile(225, "wan", 5), _make_tile(226, "wan", 5),
			]
		),
		_make_player(
			2,
			"tiao",
			[
				_make_tile(227, "wan", 4), _make_tile(228, "wan", 5), _make_tile(229, "wan", 6),
				_make_tile(230, "wan", 4), _make_tile(231, "wan", 5), _make_tile(232, "wan", 6),
				_make_tile(233, "tong", 6), _make_tile(234, "tong", 7), _make_tile(235, "tong", 8),
				_make_tile(236, "tong", 1), _make_tile(237, "tong", 2),
				_make_tile(238, "wan", 9), _make_tile(239, "wan", 9),
			]
		),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.players[0]["discards"] = [_make_tile(240, "tong", 3)]
	var discard_pile: Array[Dictionary] = [
		{
			"seat": 0,
			"tile": _make_tile(240, "tong", 3),
		},
	]
	game_state.discard_pile = discard_pile
	game_state.current_discard_context = {
		"source_seat": 0,
		"tile": _make_tile(240, "tong", 3),
		"reaction_type": "discard",
	}
	var pending_reactions: Array[Dictionary] = [
		{"seat": 3, "can_hu": false, "can_gang": true, "can_peng": false},
		{"seat": 2, "can_hu": true, "can_gang": false, "can_peng": false},
		{"seat": 1, "can_hu": true, "can_gang": false, "can_peng": false},
	]
	game_state.pending_reactions = pending_reactions
	if not bool(game_state.execute_human_hu(1)):
		return "expected first discard hu to succeed"
	var remaining_hu_seat := int(game_state.pending_reactions[0].get("seat", -1)) if not game_state.pending_reactions.is_empty() else -1
	if remaining_hu_seat != 2:
		return "expected second hu candidate to remain after first winner, got %s" % [game_state.pending_reactions]
	if not bool(game_state.call("_execute_hu_on_discard", 2)):
		return "expected second discard hu candidate to resolve after first winner"
	if game_state.round_winners.size() != 2:
		return "expected two winners after one-pao-duo-xiang resolution"
	if not game_state.round_winners.has(1) or not game_state.round_winners.has(2):
		return "expected seats 1 and 2 to both be winners"
	return true


func _test_fan_cap_limits_high_value_hands_to_four_fan():
	var game_state = _build_test_game_state()
	var player := _make_player(
		0,
		"tiao",
		[
			_make_tile(241, "wan", 1), _make_tile(242, "wan", 1), _make_tile(243, "wan", 1), _make_tile(244, "wan", 1),
			_make_tile(245, "wan", 2), _make_tile(246, "wan", 2), _make_tile(247, "wan", 2), _make_tile(248, "wan", 2),
			_make_tile(249, "wan", 3), _make_tile(250, "wan", 3),
			_make_tile(251, "wan", 4), _make_tile(252, "wan", 4),
			_make_tile(253, "wan", 5), _make_tile(254, "wan", 5),
		]
	)
	var fan_detail: Dictionary = game_state.score_resolver.build_event_fan_detail(
		player,
		player["hand_tiles"][0],
		"gang_self_draw",
		game_state.rules
	)
	if int(fan_detail.get("uncapped_fan", 0)) <= int(game_state.rules.fan_cap):
		return "expected uncapped fan to exceed fan cap for high value hand"
	if int(fan_detail.get("capped_fan", 0)) != int(game_state.rules.fan_cap):
		return "expected capped fan to equal configured fan cap"
	return true


func _test_shun_he_lock_blocks_same_fan_but_allows_higher_fan():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(256, "wan", 2), _make_tile(257, "wan", 3), _make_tile(258, "wan", 4),
				_make_tile(259, "wan", 2), _make_tile(260, "wan", 3), _make_tile(261, "wan", 4),
				_make_tile(262, "tong", 5), _make_tile(263, "tong", 6), _make_tile(264, "tong", 7),
				_make_tile(265, "tong", 1), _make_tile(266, "tong", 2),
				_make_tile(267, "wan", 5), _make_tile(268, "wan", 5),
			]
		),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.shun_he_locks[0] = {"min_fan": 1}
	game_state.current_discard_context = {
		"source_seat": 3,
		"tile": _make_tile(269, "tong", 3),
		"reaction_type": "discard",
	}
	var first_candidates: Array[Dictionary] = [
		{"seat": 0, "can_hu": true, "can_gang": false, "can_peng": false},
	]
	game_state.pending_reactions = first_candidates
	game_state._apply_shun_he_lock_filter()
	if not game_state.pending_reactions.is_empty():
		return "expected same-fan hu candidate to be blocked by shun-he lock"

	game_state.players[0]["hand_tiles"] = [
		_make_tile(270, "wan", 1), _make_tile(271, "wan", 1), _make_tile(272, "wan", 1),
		_make_tile(273, "wan", 2), _make_tile(274, "wan", 3), _make_tile(275, "wan", 4),
		_make_tile(276, "wan", 2), _make_tile(277, "wan", 3), _make_tile(278, "wan", 4),
		_make_tile(279, "wan", 5), _make_tile(280, "wan", 6), _make_tile(281, "wan", 7),
		_make_tile(282, "wan", 9),
	]
	game_state.players[0]["hand_count"] = 13
	game_state.current_discard_context = {
		"source_seat": 3,
		"tile": _make_tile(283, "wan", 9),
		"reaction_type": "discard",
	}
	var second_candidates: Array[Dictionary] = [
		{"seat": 0, "can_hu": true, "can_gang": false, "can_peng": false},
	]
	game_state.pending_reactions = second_candidates
	game_state._apply_shun_he_lock_filter()
	if game_state.pending_reactions.is_empty():
		return "expected higher-fan hu candidate to remain allowed under shun-he lock"
	return true


func _test_battle_to_end_skips_won_players_when_advancing_turn():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(284, "wan", 2), _make_tile(285, "wan", 3), _make_tile(286, "wan", 4),
				_make_tile(287, "wan", 2), _make_tile(288, "wan", 3), _make_tile(289, "wan", 4),
				_make_tile(290, "tong", 5), _make_tile(291, "tong", 6), _make_tile(292, "tong", 7),
				_make_tile(293, "tong", 3), _make_tile(294, "tong", 3),
			]
		),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.players[3]["has_won"] = true
	var wall: Array[Dictionary] = [
		_make_tile(295, "wan", 8),
		_make_tile(296, "tong", 1),
	]
	game_state.wall = wall
	game_state.wall_count = game_state.wall.size()
	game_state.last_draw_tile = {
		"seat": 0,
		"tile": _make_tile(294, "tong", 3),
	}
	game_state.last_turn_context = {
		"seat": 0,
		"draw_reason": "normal_draw",
	}
	if not bool(game_state._execute_self_draw_hu(0)):
		return "expected self-draw hu to succeed for seat 0"
	if int(game_state.current_turn_seat) != 2:
		return "expected turn to skip already-won seat 3 and advance to seat 2"
	if not game_state.players[0]["has_won"]:
		return "expected seat 0 to remain marked as winner"
	return true


func _test_draw_assessment_marks_hua_zhu_and_ting_correctly():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(60, "tiao", 1),
				_make_tile(61, "wan", 1), _make_tile(62, "wan", 1),
				_make_tile(63, "wan", 2), _make_tile(64, "wan", 3), _make_tile(65, "wan", 4),
				_make_tile(66, "wan", 2), _make_tile(67, "wan", 3), _make_tile(68, "wan", 4),
				_make_tile(69, "tong", 5), _make_tile(70, "tong", 6), _make_tile(71, "tong", 7),
				_make_tile(72, "wan", 8),
			]
		),
		_make_player(
			1,
			"tiao",
			[
				_make_tile(73, "wan", 1), _make_tile(74, "wan", 1),
				_make_tile(75, "wan", 2), _make_tile(76, "wan", 3), _make_tile(77, "wan", 4),
				_make_tile(78, "wan", 2), _make_tile(79, "wan", 3), _make_tile(80, "wan", 4),
				_make_tile(81, "tong", 5), _make_tile(82, "tong", 6), _make_tile(83, "tong", 7),
				_make_tile(84, "wan", 8), _make_tile(85, "wan", 8),
			]
		),
	]
	game_state.players = players
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state._build_draw_settlement_assessment()
	var assessment: Array = game_state.settlement_data.get("draw_assessment", [])
	if assessment.size() != 2:
		return "expected 2 draw assessment items, got %d" % assessment.size()
	var seat0: Dictionary = assessment[0]
	var seat1: Dictionary = assessment[1]
	if not bool(seat0.get("hua_zhu", false)):
		return "expected seat 0 to be marked hua_zhu because missing suit remains"
	if bool(seat1.get("hua_zhu", false)):
		return "expected seat 1 not to be hua_zhu"
	if not bool(seat1.get("is_ting", false)):
		return "expected seat 1 to be marked ting"
	return true


func _test_draw_assessment_builds_cha_jiao_max_score():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(860, "wan", 1), _make_tile(861, "wan", 1),
				_make_tile(862, "wan", 2), _make_tile(863, "wan", 3), _make_tile(864, "wan", 4),
				_make_tile(865, "wan", 2), _make_tile(866, "wan", 3), _make_tile(867, "wan", 4),
				_make_tile(868, "tong", 5), _make_tile(869, "tong", 6), _make_tile(870, "tong", 7),
				_make_tile(871, "wan", 8), _make_tile(872, "wan", 8),
			]
		),
		_make_player(1, "wan", []),
	]
	game_state.players = players
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state._build_draw_settlement_assessment()
	var assessment: Array = game_state.settlement_data.get("draw_assessment", [])
	if assessment.is_empty():
		return "expected draw assessment items"
	var seat0: Dictionary = assessment[0]
	if not bool(seat0.get("is_ting", false)):
		return "expected seat 0 to be ting"
	if int(seat0.get("cha_jiao_score", 0)) < 1:
		return "expected ting player to have cha_jiao_score"
	if int(seat0.get("cha_jiao_fan", -1)) < 0:
		return "expected ting player to expose a non-negative cha_jiao_fan"
	return true


func _test_qiang_gang_hu_executes_without_finalizing_add_gang():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(100, "wan", 5),
				_make_tile(101, "wan", 1),
			],
			[
				{
					"type": "peng",
					"from_seat": 2,
					"tiles": [
						_make_tile(102, "wan", 5),
						_make_tile(103, "wan", 5),
						_make_tile(104, "wan", 5),
					],
				},
			]
		),
		_make_player(
			1,
			"tiao",
			[
				_make_tile(105, "wan", 1), _make_tile(106, "wan", 1),
				_make_tile(107, "wan", 2), _make_tile(108, "wan", 2),
				_make_tile(109, "wan", 3), _make_tile(110, "wan", 3),
				_make_tile(111, "tong", 4), _make_tile(112, "tong", 4),
				_make_tile(113, "tong", 5), _make_tile(114, "tong", 5),
				_make_tile(115, "tong", 6), _make_tile(116, "tong", 6),
				_make_tile(117, "wan", 5),
			]
		),
		_make_player(2, "wan", []),
		_make_player(3, "tong", []),
	]
	game_state.players = players
	game_state.last_draw_tile = {
		"seat": 0,
		"tile": players[0]["hand_tiles"][0].duplicate(true),
	}
	if not bool(game_state._start_add_gang(0)):
		return "expected add gang attempt to start"
	if not bool(game_state._execute_hu_on_discard(1)):
		return "expected qiang gang hu to succeed"
	var win_events: Array = game_state.settlement_data.get("win_events", [])
	if win_events.is_empty():
		return "expected qiang gang hu win event"
	if str(win_events[0].get("win_type", "")) != "qiang_gang_hu":
		return "expected qiang_gang_hu win type"
	var fan_detail: Dictionary = win_events[0].get("fan_detail", {})
	if int(fan_detail.get("bonus_fan", 0)) != 1:
		return "expected qiang gang hu to add exactly one fan"
	if int(fan_detail.get("capped_fan", 0)) != 3:
		return "expected mixed-suit seven-pairs plus qiang-gang to total 3 fan"
	var score_changes: Dictionary = game_state.score_resolver.build_score_changes(
		game_state.players,
		{"win_events": [win_events[0]]},
		game_state.rules
	)
	if int(score_changes.get(1, 0)) != 8 or int(score_changes.get(0, 0)) != -8:
		return "expected 3-fan qiang-gang basic score +/-8, got %s" % [score_changes]
	var melds: Array = game_state.players[0].get("melds", [])
	if melds.is_empty() or str(melds[0].get("type", "")) != "peng":
		return "expected robbed add gang to remain a peng meld"
	if game_state.players[0].get("hand_tiles", []).size() != 1:
		return "expected robbed tile to be removed from add-gang actor hand"
	if _hand_contains_tile_id(game_state.players[0].get("hand_tiles", []), 100):
		return "expected robbed tile id 100 to leave add-gang actor hand"
	if int(game_state.players[0].get("hand_count", -1)) != 1:
		return "expected add-gang actor hand_count to update after robbed tile removal"
	var winning_tile: Dictionary = game_state.players[1].get("winning_tile", {})
	if int(winning_tile.get("id", -1)) != 100:
		return "expected hu player to record robbed tile as winning tile"
	if not game_state.settlement_data.get("gang_events", []).is_empty():
		return "expected no gang event to be recorded for robbed add gang"
	return true


func _test_added_gang_remains_available_after_draw_tile_is_kept_in_hand():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[_make_tile(120, "wan", 5), _make_tile(121, "wan", 1)],
			[{
				"type": "peng",
				"from_seat": 1,
				"tiles": [_make_tile(122, "wan", 5), _make_tile(123, "wan", 5), _make_tile(124, "wan", 5)],
			}]
		),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	# The fourth tile was drawn earlier and kept in the hand; it is no longer
	# required to be the current last_draw_tile for a legal later-turn add gang.
	game_state.last_draw_tile = {}
	if not bool(game_state.can_human_add_gang(0)):
		return "expected a kept fourth tile to expose the add-gang action"
	if not bool(game_state.execute_human_add_gang(0)):
		return "expected kept fourth tile add-gang execution to succeed"
	var melds: Array = game_state.players[0].get("melds", [])
	if melds.is_empty() or str(melds[0].get("type", "")) != "gang" or not bool(melds[0].get("gang_upgrade", false)) or Array(melds[0].get("tiles", [])).size() != 4:
		return "expected peng to upgrade to a four-tile add-gang meld"
	var gang_events: Array = game_state.settlement_data.get("gang_events", [])
	if gang_events.size() != 1 or str(gang_events[0].get("gang_type", "")) != "add_gang":
		return "expected add-gang settlement event to be recorded"
	var changes: Dictionary = game_state.settlement_data.get("preapplied_score_changes", {})
	if int(changes.get(0, 0)) != 3 or int(changes.get(1, 0)) != -1 or int(changes.get(2, 0)) != -1 or int(changes.get(3, 0)) != -1:
		return "expected add-gang to pay one point from each active payer, got %s" % [changes]
	return true


func _test_competitive_score_table_applies_basic_score_and_self_draw_bottom():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players

	var one_fan_discard: Dictionary = game_state.score_resolver.build_score_changes(
		players,
		{
			"win_events": [
				{
					"winner_seat": 0,
					"payer_seats": [1],
					"win_type": "discard_win",
					"fan_detail": {"capped_fan": 1},
				},
			],
		},
		game_state.rules
	)
	if int(one_fan_discard.get(0, 0)) != 2 or int(one_fan_discard.get(1, 0)) != -2:
		return "expected 1-fan discard win to score +/-2, got %s" % [one_fan_discard]

	var two_fan_discard: Dictionary = game_state.score_resolver.build_score_changes(
		players,
		{
			"win_events": [
				{
					"winner_seat": 0,
					"payer_seats": [1],
					"win_type": "discard_win",
					"fan_detail": {"capped_fan": 2},
				},
			],
		},
		game_state.rules
	)
	if int(two_fan_discard.get(0, 0)) != 4 or int(two_fan_discard.get(1, 0)) != -4:
		return "expected 2-fan discard win to score +/-4, got %s" % [two_fan_discard]

	var four_fan_self_draw: Dictionary = game_state.score_resolver.build_score_changes(
		players,
		{
			"win_events": [
				{
					"winner_seat": 0,
					"payer_seats": [1, 2, 3],
					"win_type": "self_draw",
					"fan_detail": {"capped_fan": 4},
				},
			],
		},
		game_state.rules
	)
	if int(four_fan_self_draw.get(0, 0)) != 51:
		return "expected 4-fan self draw to score +(16+1)x3 = 51, got %s" % [four_fan_self_draw]
	if int(four_fan_self_draw.get(1, 0)) != -17 or int(four_fan_self_draw.get(2, 0)) != -17 or int(four_fan_self_draw.get(3, 0)) != -17:
		return "expected each payer to lose 17 on capped self draw, got %s" % [four_fan_self_draw]
	return true


func _test_round_scores_apply_to_player_totals_and_persist():
	var game_state = _build_test_game_state()
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.SETTLEMENT
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state.settlement_data["end_reason"] = "battle_end"
	game_state.settlement_data["win_events"] = [
		{
			"winner_seat": 0,
			"source_seat": 1,
			"winning_tile": _make_tile(901, "wan", 9),
			"win_type": "discard_win",
			"payer_seats": [1],
			"fan_detail": {"capped_fan": 2, "hand_type": "ping_hu", "labels": ["平和"]},
		},
	]
	var round_winners: Array[int] = [0]
	game_state.round_winners = round_winners
	game_state._rebuild_settlement_summary()
	if int(game_state.players[0].get("score", 0)) != 1004 or int(game_state.players[1].get("score", 0)) != 996:
		return "expected first settlement to apply deltas to player totals, got %s" % [game_state.players]
	if not bool(game_state.settlement_data.get("scores_applied", false)):
		return "expected settlement data to mark scores_applied"

	if not bool(game_state.advance_to_next_round()):
		return "expected advance_to_next_round to succeed from settlement"
	if int(game_state.players[0].get("score", 0)) != 1004 or int(game_state.players[1].get("score", 0)) != 996:
		return "expected next round to preserve cumulative totals, got %s" % [game_state.players]
	return true


func _test_next_dealer_uses_first_winner_or_shared_discarder():
	var game_state = _build_test_game_state()
	game_state.current_dealer_seat = 0
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state.settlement_data["win_events"] = [
		{"winner_seat": 2, "source_seat": 2, "win_type": "self_draw"},
		{"winner_seat": 3, "source_seat": 1, "win_type": "discard_win"},
	]
	if int(game_state._resolve_next_dealer_seat()) != 2:
		return "expected first self-draw winner seat 2 to become dealer"
	game_state.settlement_data["win_events"] = [
		{"winner_seat": 3, "source_seat": 1, "win_type": "discard_win"},
		{"winner_seat": 2, "source_seat": 1, "win_type": "discard_win"},
	]
	if int(game_state._resolve_next_dealer_seat()) != 1:
		return "expected shared discarder seat 1 to become dealer after one-discard two-win"
	game_state.settlement_data["win_events"] = [
		{"winner_seat": 1, "source_seat": 0, "win_type": "discard_win"},
		{"winner_seat": 2, "source_seat": 0, "win_type": "discard_win"},
		{"winner_seat": 3, "source_seat": 0, "win_type": "discard_win"},
	]
	if int(game_state._resolve_next_dealer_seat()) != 0:
		return "expected shared discarder seat 0 to become dealer after one-discard three-win"
	return true


func _test_gang_score_table_applies_sichuan_units():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	for player in players:
		player["has_won"] = true
	game_state.players = players
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	settlement_data["gang_events"] = [
		{
			"actor_seat": 0,
			"source_seat": 1,
			"tile": _make_tile(401, "wan", 1),
			"gang_type": "melded_gang",
			"related_outcome": "",
			"payer_seats": [1],
		},
		{
			"actor_seat": 0,
			"source_seat": 0,
			"tile": _make_tile(402, "wan", 2),
			"gang_type": "an_gang",
			"related_outcome": "",
			"payer_seats": [1, 2, 3],
		},
		{
			"actor_seat": 0,
			"source_seat": 2,
			"tile": _make_tile(403, "wan", 3),
			"gang_type": "add_gang",
			"related_outcome": "",
			"payer_seats": [1, 2, 3],
		},
	]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(players, settlement_data, game_state.rules)
	if int(changes.get(0, 0)) != 11 or int(changes.get(1, 0)) != -5 or int(changes.get(2, 0)) != -3 or int(changes.get(3, 0)) != -3:
		return "expected melded=2 from discarder, an=2 each, add=1 each, got %s" % [changes]
	return true


func _test_gang_scores_apply_immediately_while_players_remain():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.players[0]["has_won"] = true
	game_state.players[1]["has_won"] = true
	game_state.players[2]["has_won"] = true
	game_state.players[3]["has_won"] = false
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state._append_settlement_gang_event(0, 1, _make_tile(118, "wan", 9), "melded_gang", [1])
	if int(game_state.players[0].get("score", 0)) != 1002 or int(game_state.players[1].get("score", 0)) != 998:
		return "expected direct-gang money to update player totals immediately, got %s" % [game_state.players]
	var preapplied: Dictionary = game_state.settlement_data.get("preapplied_score_changes", {})
	if int(preapplied.get(0, 0)) != 2 or int(preapplied.get(1, 0)) != -2:
		return "expected immediate gang ledger to retain the preapplied delta, got %s" % [preapplied]
	game_state.current_phase = GAME_STATE_SCRIPT.RoundPhase.SETTLEMENT
	game_state.settlement_data["end_reason"] = "battle_end"
	game_state._rebuild_settlement_summary()
	if int(game_state.players[0].get("score", 0)) != 1002 or int(game_state.players[1].get("score", 0)) != 998:
		return "expected final settlement not to apply the already-paid gang money twice"
	return true


func _test_hu_jiao_zhuan_yi_transfers_gang_score_to_winner():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	for player in game_state.players:
		player["has_won"] = true
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	settlement_data["gang_events"] = [
		{
			"actor_seat": 0,
			"source_seat": 1,
			"tile": _make_tile(119, "tong", 7),
			"gang_type": "melded_gang",
			"related_outcome": "gang_discard_win",
			"payer_seats": [1],
		},
	]
	settlement_data["transfer_events"] = [
		{
			"from_seat": 0,
			"to_seat": 2,
			"tile": _make_tile(120, "wan", 3),
			"transfer_type": "hu_jiao_zhuan_yi",
			"reason": "test",
			"gang_type": "melded_gang",
			"payer_seats": [1],
			"related_actor_seat": 0,
		},
	]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(game_state.players, settlement_data, game_state.rules)
	if int(changes.get(2, 0)) != 2 or int(changes.get(1, 0)) != -2 or int(changes.get(0, 0)) != 0:
		return "expected transferred gang score to winner, got %s" % [changes]
	return true


func _test_draw_does_not_refund_immediate_gang_money():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(
			0,
			"tiao",
			[
				_make_tile(121, "tiao", 1),
				_make_tile(122, "wan", 1), _make_tile(123, "wan", 1),
				_make_tile(124, "wan", 2), _make_tile(125, "wan", 3), _make_tile(126, "wan", 4),
				_make_tile(127, "wan", 2), _make_tile(128, "wan", 3), _make_tile(129, "wan", 4),
				_make_tile(130, "tong", 5), _make_tile(131, "tong", 6), _make_tile(132, "tong", 7),
				_make_tile(133, "wan", 8),
			]
		),
		_make_player(
			1,
			"tiao",
			[
				_make_tile(134, "wan", 1), _make_tile(135, "wan", 1),
				_make_tile(136, "wan", 2), _make_tile(137, "wan", 3), _make_tile(138, "wan", 4),
				_make_tile(139, "wan", 2), _make_tile(140, "wan", 3), _make_tile(141, "wan", 4),
				_make_tile(142, "tong", 5), _make_tile(143, "tong", 6), _make_tile(144, "tong", 7),
				_make_tile(145, "wan", 8), _make_tile(146, "tiao", 8),
			]
		),
	]
	game_state.players = players
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state.settlement_data["gang_events"] = [
		{
			"actor_seat": 1,
			"source_seat": 0,
			"tile": _make_tile(147, "tong", 9),
			"gang_type": "melded_gang",
			"related_outcome": "",
			"payer_seats": [0],
		},
	]
	game_state._build_draw_settlement_assessment()
	var assessment: Array = game_state.settlement_data.get("draw_assessment", [])
	var actor_item := {}
	for item in assessment:
		if int(item.get("seat", -1)) == 1:
			actor_item = item
	if actor_item.is_empty() or not bool(actor_item.get("hua_zhu", false)):
		return "expected unresolved gang actor to be marked hua_zhu before tui-gang refund, got %s" % [assessment]
	var refunds: Array = game_state.settlement_data.get("tui_gang_refunds", [])
	if not refunds.is_empty():
		return "expected draw settlement to preserve independent gang money without refund, got %s" % [refunds]
	return true


func _test_draw_score_changes_apply_ting_hua_zhu_and_no_ting_payments():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "tiao", []),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
	]
	game_state.players = players
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	settlement_data["draw_assessment"] = [
		{"seat": 0, "hua_zhu": false, "is_ting": true, "ting_tiles": [_make_tile(300, "wan", 9)], "cha_jiao_score": 2},
		{"seat": 1, "hua_zhu": false, "is_ting": false, "ting_tiles": []},
		{"seat": 2, "hua_zhu": true, "is_ting": false, "ting_tiles": []},
	]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(players, settlement_data, game_state.rules)
	if int(changes.get(0, 0)) != 18:
		return "expected ting seat to receive 16 from hua_zhu and 2 from no_ting, got %s" % [changes]
	if int(changes.get(1, 0)) != -2:
		return "expected no_ting seat to pay 2, got %s" % [changes]
	if int(changes.get(2, 0)) != -16:
		return "expected hua_zhu seat to pay fixed capped 16, got %s" % [changes]
	return true


func _test_draw_cha_jiao_excludes_already_won_players():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "tiao", []),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	players[0]["has_won"] = true
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	# Retain a real win event so this fixture catches any future attempt to turn
	# winners back into draw-settlement targets. Its payer list is intentionally
	# empty so only the cha-jiao adjustment is measured below.
	settlement_data["win_events"] = [{
		"winner_seat": 0,
		"payer_seats": [],
		"win_type": "discard_win",
		"fan_detail": {"capped_fan": 2, "hand_score": 4},
	}]
	settlement_data["draw_assessment"] = [
		{"seat": 1, "hua_zhu": false, "is_ting": true, "cha_jiao_score": 2},
		{"seat": 2, "hua_zhu": false, "is_ting": false, "cha_jiao_score": 0},
		{"seat": 3, "hua_zhu": false, "is_ting": false, "cha_jiao_score": 0},
	]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(players, settlement_data, game_state.rules)
	if int(changes.get(0, 99)) != 0:
		return "already-won seat must not receive cha-jiao again, got %s" % [changes]
	if int(changes.get(1, 0)) != 4 or int(changes.get(2, 0)) != -2 or int(changes.get(3, 0)) != -2:
		return "cha-jiao must settle only among unresolved seats, got %s" % [changes]
	return true


func _test_legacy_tui_gang_refunds_are_ignored():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "tiao", []),
		_make_player(1, "wan", []),
	]
	for player in players:
		player["has_won"] = true
	game_state.players = players
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	settlement_data["gang_events"] = [
		{
			"actor_seat": 0,
			"source_seat": 1,
			"tile": _make_tile(301, "tong", 9),
			"gang_type": "melded_gang",
			"related_outcome": "",
			"payer_seats": [1],
		},
	]
	settlement_data["tui_gang_refunds"] = [
		{
			"actor_seat": 0,
			"gang_type": "melded_gang",
			"payer_seats": [1],
			"refund_reason": "draw_tui_gang",
		},
	]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(players, settlement_data, game_state.rules)
	if int(changes.get(0, 99)) != 2 or int(changes.get(1, 99)) != -2:
		return "expected disabled legacy refund record not to reverse gang money, got %s" % [changes]
	return true


func _test_fan_combinations_follow_sichuan_table_and_cap():
	var game_state = _build_test_game_state()
	var cases: Array[Dictionary] = [
		{
			"name": "qi_dui",
			"player": _make_player(0, "tiao", [
				_make_tile(1000, "wan", 1), _make_tile(1001, "wan", 1),
				_make_tile(1002, "wan", 2), _make_tile(1003, "wan", 2),
				_make_tile(1004, "wan", 3), _make_tile(1005, "wan", 3),
				_make_tile(1006, "tong", 4), _make_tile(1007, "tong", 4),
				_make_tile(1008, "tong", 5), _make_tile(1009, "tong", 5),
				_make_tile(1010, "tong", 6), _make_tile(1011, "tong", 6),
				_make_tile(1012, "tong", 7), _make_tile(1013, "tong", 7),
			]),
			"hand_type": "qi_dui",
			"required_labels": ["小七对"],
			"uncapped_fan": 2,
		},
		{
			"name": "da_dui_zi",
			"player": _make_player(0, "tiao", [
				_make_tile(1020, "wan", 1), _make_tile(1021, "wan", 1), _make_tile(1022, "wan", 1),
				_make_tile(1023, "wan", 3), _make_tile(1024, "wan", 3), _make_tile(1025, "wan", 3),
				_make_tile(1026, "tong", 5), _make_tile(1027, "tong", 5), _make_tile(1028, "tong", 5),
				_make_tile(1029, "tong", 7), _make_tile(1030, "tong", 7), _make_tile(1031, "tong", 7),
				_make_tile(1032, "wan", 9), _make_tile(1033, "wan", 9),
			]),
			"hand_type": "da_dui_zi",
			"required_labels": ["大对子"],
			"uncapped_fan": 1,
		},
		{
			"name": "qing_jin_gou_gen_gang_hua",
			"player": _make_player(0, "tiao", [
				_make_tile(1040, "wan", 9), _make_tile(1041, "wan", 9),
			], [
				{"type": "gang", "tiles": [_make_tile(1042, "wan", 1), _make_tile(1043, "wan", 1), _make_tile(1044, "wan", 1), _make_tile(1045, "wan", 1)]},
				{"type": "peng", "tiles": [_make_tile(1046, "wan", 2), _make_tile(1047, "wan", 2), _make_tile(1048, "wan", 2)]},
				{"type": "peng", "tiles": [_make_tile(1049, "wan", 3), _make_tile(1050, "wan", 3), _make_tile(1051, "wan", 3)]},
				{"type": "peng", "tiles": [_make_tile(1052, "wan", 4), _make_tile(1053, "wan", 4), _make_tile(1054, "wan", 4)]},
			]),
			"hand_type": "qing_jin_gou_diao",
			"required_labels": ["清金钩钓", "杠上花", "自摸"],
			"uncapped_fan": 6,
		},
	]
	for case_data in cases:
		var detail: Dictionary = game_state.score_resolver.build_event_fan_detail(
			case_data["player"],
			Array(case_data["player"].get("hand_tiles", []))[0],
			"gang_self_draw" if str(case_data["name"]) == "qing_jin_gou_gen_gang_hua" else "self_draw",
			game_state.rules
		)
		if str(detail.get("hand_type", "")) != str(case_data["hand_type"]):
			return "%s expected hand type %s, got %s" % [case_data["name"], case_data["hand_type"], detail]
		if int(detail.get("uncapped_fan", 0)) != int(case_data["uncapped_fan"]):
			return "%s expected uncapped fan %d, got %s" % [case_data["name"], case_data["uncapped_fan"], detail]
		if int(detail.get("capped_fan", 0)) != mini(int(case_data["uncapped_fan"]), int(game_state.rules.fan_cap)):
			return "%s fan cap mismatch: %s" % [case_data["name"], detail]
		var labels: Array = detail.get("labels", [])
		for required_label in case_data["required_labels"]:
			if not labels.has(required_label):
				return "%s missing label %s: %s" % [case_data["name"], required_label, labels]
	return true


func _test_sea_bottom_never_adds_fan():
	var game_state = _build_test_game_state()
	var player := _make_player(0, "tiao", [
		_make_tile(1100, "wan", 1), _make_tile(1101, "wan", 1), _make_tile(1102, "wan", 1),
		_make_tile(1103, "wan", 2), _make_tile(1104, "wan", 3), _make_tile(1105, "wan", 4),
		_make_tile(1106, "wan", 2), _make_tile(1107, "wan", 3), _make_tile(1108, "wan", 4),
		_make_tile(1109, "wan", 5), _make_tile(1110, "wan", 6), _make_tile(1111, "wan", 7),
		_make_tile(1112, "wan", 9), _make_tile(1113, "wan", 9),
	])
	var detail: Dictionary = game_state.score_resolver.build_event_fan_detail(player, _make_tile(1114, "wan", 9), "self_draw", game_state.rules)
	var labels: Array = detail.get("labels", [])
	for label in labels:
		if str(label).contains("海底"):
			return "expected no sea-bottom label or multiplier, got %s" % [detail]
	var flags: Dictionary = detail.get("flags", {})
	if flags.has("hai_di") or flags.has("sea_bottom"):
		return "expected fan resolver contract to exclude sea-bottom flags, got %s" % [flags]
	return true


func _test_shun_he_lock_clears_on_own_draw():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "tiao", [_make_tile(1120, "wan", 1)]),
		_make_player(1, "wan", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.current_turn_seat = 0
	game_state.shun_he_locks[0] = {"locked_fan": 2, "min_fan": 2, "lock_turn": 4, "unlock_on_own_draw": true}
	var wall: Array[Dictionary] = [_make_tile(1121, "wan", 2)]
	game_state.wall = wall
	game_state.wall_count = 1
	game_state._begin_turn()
	if game_state.shun_he_locks.has(0):
		return "expected shun-he lock to clear when the same seat draws"
	return true


func _test_hu_jiao_zhuan_yi_supports_multiple_payers():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []), _make_player(1, "tiao", []),
		_make_player(2, "tong", []), _make_player(3, "wan", []),
	]
	for player in players:
		player["has_won"] = true
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	settlement_data["transfer_events"] = [{
		"from_seat": 0, "to_seat": 2, "transfer_type": "hu_jiao_zhuan_yi",
		"gang_type": "add_gang", "payer_seats": [0, 1, 3],
	}]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(players, settlement_data, game_state.rules)
	if int(changes.get(2, 0)) != 3 or int(changes.get(0, 0)) != -3 or int(changes.get(1, 0)) != 0 or int(changes.get(3, 0)) != 0:
		return "expected all three points of add-gang money to move from gang actor to winner, got %s" % [changes]
	return true


func _test_hu_jiao_zhuan_yi_applies_immediately():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []), _make_player(1, "tiao", []),
		_make_player(2, "tong", []), _make_player(3, "wan", []),
	]
	game_state.players = players
	game_state.settlement_data = game_state._create_empty_settlement_data()
	game_state._append_settlement_gang_event(0, 1, _make_tile(1180, "wan", 6), "melded_gang", [1])
	game_state._append_hu_jiao_zhuan_yi_event(0, 2, _make_tile(1181, "tong", 7))
	if int(game_state.players[0].get("score", 0)) != 1000:
		return "expected gang actor to surrender the full two-point gang gain immediately"
	if int(game_state.players[1].get("score", 0)) != 998 or int(game_state.players[2].get("score", 0)) != 1002:
		return "expected original payer to stay paid and winner to receive transfer immediately, got %s" % [game_state.players]
	var preapplied: Dictionary = game_state.settlement_data.get("preapplied_score_changes", {})
	if int(preapplied.get(0, 0)) != 0 or int(preapplied.get(1, 0)) != -2 or int(preapplied.get(2, 0)) != 2:
		return "expected immediate gang and transfer ledgers to net correctly, got %s" % [preapplied]
	return true


func _test_multi_payer_gang_is_never_refunded():
	var game_state = _build_test_game_state()
	var players: Array[Dictionary] = [
		_make_player(0, "wan", []), _make_player(1, "tiao", []),
		_make_player(2, "tong", []), _make_player(3, "wan", []),
	]
	for player in players:
		player["has_won"] = true
	var settlement_data: Dictionary = game_state._create_empty_settlement_data()
	settlement_data["gang_events"] = [{
		"actor_seat": 0, "gang_type": "an_gang", "related_outcome": "", "payer_seats": [1, 2, 3],
	}]
	settlement_data["tui_gang_refunds"] = [{
		"actor_seat": 0, "gang_type": "an_gang", "payer_seats": [1, 2, 3], "refund_reason": "draw_tui_gang",
	}]
	var changes: Dictionary = game_state.score_resolver.build_score_changes(players, settlement_data, game_state.rules)
	if int(changes.get(0, 0)) != 6 \
			or int(changes.get(1, 0)) != -2 \
			or int(changes.get(2, 0)) != -2 \
			or int(changes.get(3, 0)) != -2:
		return "expected disabled tui-gang record to leave all immediate concealed-gang money intact, got %s" % [changes]
	return true


func _build_test_game_state():
	var game_state = GAME_STATE_SCRIPT.new()
	game_state.rules = load("res://scripts/core/rule_config.gd").new()
	game_state.mahjong_state = load("res://scripts/core/mahjong_state.gd").new()
	game_state.mahjong_judge = load("res://scripts/core/mahjong_judge.gd").new()
	game_state.ding_que_resolver = load("res://scripts/core/ding_que_resolver.gd").new()
	game_state.reaction_resolver = REACTION_RESOLVER_SCRIPT.new()
	game_state.hu_checker = load("res://scripts/core/hu_checker.gd").new()
	game_state.score_resolver = load("res://scripts/core/score_resolver.gd").new()
	game_state.shanten_analyzer = load("res://scripts/core/shanten_analyzer.gd").new()
	game_state.discard_advisor = load("res://scripts/core/discard_advisor.gd").new()
	game_state.risk_analyzer = load("res://scripts/core/risk_analyzer.gd").new()
	game_state.reaction_advisor = load("res://scripts/core/reaction_advisor.gd").new()
	game_state.gang_advisor = load("res://scripts/core/gang_advisor.gd").new()
	game_state.ai_tuning_config = load("res://scripts/core/ai_tuning_config.gd").new()
	game_state.ai_tuning_config.apply_preset("bone_ash")
	game_state.ai_learning_engine = load("res://scripts/core/ai_learning_engine.gd").new()
	game_state.opening_roll_resolver = load("res://scripts/core/opening_roll_resolver.gd").new()
	game_state._rng = RandomNumberGenerator.new()
	game_state._rng.randomize()
	return game_state


func _make_player(seat: int, ding_que: String, hand_tiles: Array, melds: Array = []) -> Dictionary:
	return {
		"seat": seat,
		"nickname": "Seat %d" % seat,
		"score": 1000,
		"is_ai": seat != 0,
		"hand_tiles": hand_tiles.duplicate(true),
		"hand_count": hand_tiles.size(),
		"melds": melds.duplicate(true),
		"discards": [],
		"ding_que": ding_que,
		"has_won": false,
	}


func _hand_contains_tile_id(hand_tiles: Array, tile_id: int) -> bool:
	for tile in hand_tiles:
		if int(tile.get("id", -1)) == tile_id:
			return true
	return false


func _make_tile(id: int, suit: String, rank: int) -> Dictionary:
	var suit_index := ["tiao", "tong", "wan"].find(suit)
	return {
		"id": id,
		"suit": suit,
		"rank": rank,
		"sort_key": suit_index * 100 + rank,
		"display_name": "%d%s" % [rank, _suit_name(suit)],
	}


func _suit_name(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return "?"
