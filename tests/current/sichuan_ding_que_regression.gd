extends SceneTree

const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const REACTION_RESOLVER_SCRIPT := preload("res://scripts/core/reaction_resolver.gd")
const MAIN_SCENE_SCRIPT := preload("res://scripts/game/MainSceneV2.gd")


func _init() -> void:
	var failures: Array[String] = []
	_run_test("missing_suit_blocks_peng_and_gang_on_same_suit", _test_missing_suit_blocks_peng_and_gang_on_same_suit, failures)
	_run_test("non_missing_suit_still_allows_peng_and_gang", _test_non_missing_suit_still_allows_peng_and_gang, failures)
	_run_test("forced_discard_requires_missing_suit_first", _test_forced_discard_requires_missing_suit_first, failures)
	_run_test("trainer_hint_forces_missing_suit_first", _test_trainer_hint_forces_missing_suit_first, failures)
	_run_test("missing_suit_blocks_add_gang_and_an_gang_only_for_missing_suit", _test_missing_suit_blocks_add_gang_and_an_gang_only_for_missing_suit, failures)
	_run_test("display_hand_sorts_missing_suit_to_right", _test_display_hand_sorts_missing_suit_to_right, failures)

	if failures.is_empty():
		print("RULE REGRESSION OK: 6/6")
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


func _test_forced_discard_requires_missing_suit_first():
	var game_state = _build_test_game_state()
	game_state.current_phase = game_state.RoundPhase.DISCARD
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


func _test_trainer_hint_forces_missing_suit_first():
	var game_state = _build_test_game_state()
	game_state.current_phase = game_state.RoundPhase.DISCARD
	game_state.current_turn_seat = 0
	game_state.human_trainer_hint_enabled = true
	var players: Array[Dictionary] = [
		_make_player(0, "wan", [
			_make_tile(11, "wan", 1),
			_make_tile(12, "wan", 3),
			_make_tile(13, "tong", 5),
			_make_tile(14, "tiao", 8),
		]),
		_make_player(1, "tiao", []),
		_make_player(2, "tong", []),
		_make_player(3, "wan", []),
	]
	game_state.players = players
	var analysis := {
		"recommended": {
			"tile": _make_tile(13, "tong", 5),
			"tile_name": "5筒",
			"score": 99,
			"explanation_hint": "原始推荐",
		},
		"options": [
			{
				"tile": _make_tile(13, "tong", 5),
				"tile_name": "5筒",
				"score": 99,
			},
			{
				"tile": _make_tile(12, "wan", 3),
				"tile_name": "3万",
				"score": 12,
			},
			{
				"tile": _make_tile(11, "wan", 1),
				"tile_name": "1万",
				"score": 5,
			},
		],
		"danger_tiles": [],
		"current_routes": [],
		"strategy_profile": {},
	}
	if not bool(game_state._apply_trainer_hint_analysis(0, analysis)):
		return "expected trainer hint analysis to apply"
	var hint: Dictionary = game_state.latest_trainer_hint
	if str(hint.get("forced_discard_suit", "")) != "wan":
		return "expected trainer hint forced suit wan, got %s" % str(hint.get("forced_discard_suit", ""))
	var recommended: Dictionary = hint.get("recommended", {})
	var tile: Dictionary = recommended.get("tile", {})
	if str(tile.get("suit", "")) != "wan":
		return "expected trainer hint to recommend wan first, got %s" % str(tile)
	if int(hint.get("recommended_tile_id", -1)) != 12:
		return "expected best wan option tile id 12, got %d" % int(hint.get("recommended_tile_id", -1))
	if not bool(recommended.get("forced_ding_que_cleanup", false)):
		return "expected recommended option to mark forced ding-que cleanup"
	return true


func _test_missing_suit_blocks_add_gang_and_an_gang_only_for_missing_suit():
	var game_state = _build_test_game_state()
	game_state.current_phase = game_state.RoundPhase.DISCARD
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
	game_state.ai_tuning_config = load("res://scripts/core/ai_tuning_config.gd").new()
	game_state.ai_tuning_config.apply_preset("bone_ash")
	game_state.ai_learning_engine = load("res://scripts/core/ai_learning_engine.gd").new()
	game_state.opening_roll_resolver = load("res://scripts/core/opening_roll_resolver.gd").new()
	game_state.pending_reactions.clear()
	game_state.current_discard_context.clear()
	game_state.shun_he_locks.clear()
	game_state.round_winners.clear()
	game_state.discard_pile.clear()
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


func _make_tile(id: int, suit: String, rank: int) -> Dictionary:
	return {
		"id": id,
		"suit": suit,
		"rank": rank,
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
