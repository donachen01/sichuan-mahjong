extends SceneTree

const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const ACTION_BAR_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")


class TrainerAIStub extends RefCounted:
	var last_candidate: Dictionary = {}

	func analyze_reaction_lightweight(
		candidate: Dictionary,
		_player_state: Dictionary,
		_table_state: Dictionary,
		_discard_context: Dictionary,
		_rules_config,
		_ai_config,
		_hu_checker,
		_allow_cheat: bool = false
	) -> Dictionary:
		last_candidate = candidate.duplicate(true)
		if bool(candidate.get("can_hu", false)):
			return {"action": "hu", "score": 100000, "reasons": ["可胡时直接胡牌"]}
		if bool(candidate.get("can_gang", false)):
			return {"action": "gang", "score": 88, "reasons": ["杠后收益更高"]}
		if bool(candidate.get("can_peng", false)):
			return {"action": "peng", "score": 66, "reasons": ["碰后更快成叫"]}
		return {"action": "pass", "score": 0, "reasons": ["当前不宜鸣牌"]}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _verify_action_bar_dispatch(failures)
	_verify_human_peng_blocks_lower_priority_ai(failures)
	_verify_human_gang_blocks_lower_priority_ai(failures)
	_verify_higher_priority_ai_still_runs(failures)
	_verify_ai_hint_covers_hu_gang_peng(failures)
	_verify_native_csharp_hu_hint(failures)
	_verify_direct_peng_execution(failures)
	_verify_direct_gang_execution(failures)

	if failures.is_empty():
		print("SICHUAN HUMAN REACTION ACTIONS OK")
		quit(0)
		return
	push_error("SICHUAN HUMAN REACTION ACTIONS FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_ai_hint_covers_hu_gang_peng(failures: Array[String]) -> void:
	for expected_action in ["hu", "gang", "peng"]:
		var state = _build_reaction_state(expected_action == "gang")
		var candidate: Dictionary = state.pending_reactions[0]
		candidate["can_hu"] = expected_action == "hu"
		candidate["can_gang"] = expected_action == "gang"
		candidate["can_peng"] = expected_action == "peng"
		var pending: Array[Dictionary] = [candidate]
		state.pending_reactions = pending
		state.ai_manager = TrainerAIStub.new()
		state.human_trainer_hint_enabled = true
		var hint: Dictionary = state._get_human_trainer_hint_snapshot()
		if str(hint.get("hint_kind", "")) != "reaction":
			failures.append("%s 响应窗口没有生成 reaction 类型 AI 提示" % expected_action)
			continue
		var advice: Dictionary = hint.get("reaction_advice", {})
		if str(advice.get("action", "")) != expected_action:
			failures.append("%s 响应没有沿 AI 链路给出对应建议：%s" % [expected_action, advice])
		if str(advice.get("source_tile_name", "")) != "6筒":
			failures.append("%s 建议没有保留响应牌上下文" % expected_action)
		if Array(advice.get("reasons", [])).is_empty():
			failures.append("%s 建议缺少判断原因" % expected_action)


func _verify_native_csharp_hu_hint(failures: Array[String]) -> void:
	var live_game_state := get_root().get_node_or_null("GameState")
	var live_ai_manager = live_game_state.get("ai_manager") if live_game_state != null else null
	if live_ai_manager == null or not bool(live_ai_manager.call("has_native_csharp_runtime")):
		failures.append("真实 Native C# AI 不可用，无法验证胡牌建议链路")
		return
	var state = _build_reaction_state(false)
	var candidate: Dictionary = state.pending_reactions[0]
	candidate["can_hu"] = true
	candidate["can_gang"] = false
	candidate["can_peng"] = false
	var pending: Array[Dictionary] = [candidate]
	state.pending_reactions = pending
	state.ai_manager = live_ai_manager
	state.human_trainer_hint_enabled = true
	var hint: Dictionary = state._get_human_trainer_hint_snapshot()
	var advice: Dictionary = hint.get("reaction_advice", {})
	if str(advice.get("action", "")) != "hu":
		failures.append("真实 Native C# AI 没有把可胡响应传入提示：%s" % [advice])
	if not str(advice.get("backend_mode", "")).contains("csharp"):
		failures.append("胡牌提示没有来自真实 C# 后端：%s" % str(advice.get("backend_mode", "")))


func _verify_action_bar_dispatch(failures: Array[String]) -> void:
	var action_bar := ACTION_BAR_SCENE.instantiate()
	get_root().add_child(action_bar)
	await process_frame
	var visible_actions: Array[String] = ["gang", "peng", "pass"]
	action_bar.call("render", visible_actions, "响应出牌：杠 / 碰 / 过")
	await process_frame
	var dispatched: Array[String] = []
	action_bar.connect("action_selected", func(action: String) -> void: dispatched.append(action))
	for action in ["gang", "peng", "pass"]:
		var button: Button = action_bar.call("get_button", action)
		if button == null or not button.visible or button.disabled:
			failures.append("%s 按钮在可响应状态下不可用" % action)
			continue
		await _click_at(button.get_global_rect().get_center())
	if dispatched != ["gang", "peng", "pass"]:
		failures.append("真实指针点击没有按原动作分发：%s" % [dispatched])
	action_bar.queue_free()
	await process_frame


func _click_at(global_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	get_root().push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = global_position
	press.global_position = global_position
	get_root().push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = global_position
	release.global_position = global_position
	get_root().push_input(release, true)
	await process_frame


func _verify_human_peng_blocks_lower_priority_ai(failures: Array[String]) -> void:
	var state = _build_reaction_state(false)
	var options: Dictionary = state.get_human_reaction_options(0)
	if not bool(options.get("can_peng", false)):
		failures.append("真人近位碰候选没有出现在响应窗口")
	if state.is_ai_reaction_pending():
		failures.append("真人可碰时，远位 AI 仍会抢先推进响应计时器")
	if not state._get_next_ai_reaction_candidate().is_empty():
		failures.append("真人可碰时，后台仍会创建远位 AI 响应任务")


func _verify_human_gang_blocks_lower_priority_ai(failures: Array[String]) -> void:
	var state = _build_reaction_state(true)
	var options: Dictionary = state.get_human_reaction_options(0)
	if not bool(options.get("can_gang", false)):
		failures.append("真人明杠候选没有出现在响应窗口")
	if state.is_ai_reaction_pending():
		failures.append("真人可杠时，低优先级 AI 仍会抢先推进响应计时器")
	if not state._get_next_ai_reaction_candidate().is_empty():
		failures.append("真人可杠时，后台仍会创建低优先级 AI 响应任务")


func _verify_higher_priority_ai_still_runs(failures: Array[String]) -> void:
	var state = _build_state()
	var discarded := _tile(915, "tong", 6)
	var players: Array[Dictionary] = [
		_player(0, false, "tiao", [_tile(14, "tong", 6), _tile(15, "tong", 6)]),
		_player(1, true, "wan", []),
		_player(2, true, "wan", []),
		_player(3, true, "wan", []),
	]
	var pending_reactions: Array[Dictionary] = [
		{"seat": 0, "can_hu": false, "can_gang": false, "can_peng": true},
		{"seat": 3, "can_hu": true, "can_gang": false, "can_peng": false},
	]
	state.players = players
	state.current_phase = 6
	state.current_discard_context = {"source_seat": 1, "tile": discarded, "reaction_type": "discard"}
	state.pending_reactions = pending_reactions
	if bool(state.get_human_reaction_options(0).get("can_peng", false)):
		failures.append("AI 可胡时不应继续向真人显示低优先级碰操作")
	if not state.is_ai_reaction_pending():
		failures.append("AI 具有更高优先级胡牌时被真人低优先级候选错误冻结")
	var ai_candidate: Dictionary = state._get_next_ai_reaction_candidate()
	if int(ai_candidate.get("seat", -1)) != 3:
		failures.append("更高优先级 AI 胡牌候选没有继续进入响应链路")


func _verify_direct_peng_execution(failures: Array[String]) -> void:
	var state = _build_state()
	var discarded := _tile(900, "tong", 5)
	var players: Array[Dictionary] = [
		_player(0, false, "tiao", [_tile(1, "tong", 5), _tile(2, "tong", 5), _tile(3, "wan", 1)]),
		_player(1, true, "wan", []),
		_player(2, true, "wan", []),
		_player(3, true, "wan", []),
	]
	state.players = players
	state.players[1]["discards"] = [discarded.duplicate(true)]
	state.current_phase = 6
	state.current_turn_seat = 1
	state.current_discard_context = {"source_seat": 1, "tile": discarded.duplicate(true), "reaction_type": "discard"}
	var discard_pile: Array[Dictionary] = [{"seat": 1, "tile": discarded.duplicate(true)}]
	var pending_reactions: Array[Dictionary] = [{"seat": 0, "can_hu": false, "can_gang": false, "can_peng": true}]
	state.discard_pile = discard_pile
	state.pending_reactions = pending_reactions
	if not state.execute_human_peng(0):
		failures.append("真人碰按钮到真实规则执行链路失败")
		return
	if state.players[0]["melds"].is_empty() or str(state.players[0]["melds"][0].get("type", "")) != "peng":
		failures.append("真人碰执行后没有生成碰副露")


func _verify_direct_gang_execution(failures: Array[String]) -> void:
	var state = _build_state()
	var discarded := _tile(920, "tong", 7)
	var players: Array[Dictionary] = [
		_player(0, false, "tiao", [_tile(21, "tong", 7), _tile(22, "tong", 7), _tile(23, "tong", 7)]),
		_player(1, true, "wan", []),
		_player(2, true, "wan", []),
		_player(3, true, "wan", []),
	]
	var discard_pile: Array[Dictionary] = [{"seat": 1, "tile": discarded.duplicate(true)}]
	var pending_reactions: Array[Dictionary] = [{"seat": 0, "can_hu": false, "can_gang": true, "can_peng": true}]
	var wall: Array[Dictionary] = [_tile(929, "wan", 9)]
	state.players = players
	state.players[1]["discards"] = [discarded.duplicate(true)]
	state.current_phase = 6
	state.current_turn_seat = 1
	state.current_discard_context = {"source_seat": 1, "tile": discarded.duplicate(true), "reaction_type": "discard"}
	state.discard_pile = discard_pile
	state.pending_reactions = pending_reactions
	state.wall = wall
	state.wall_count = wall.size()
	if not state.execute_human_gang(0):
		failures.append("真人杠按钮到真实规则执行链路失败")
		return
	if state.players[0]["melds"].is_empty() or str(state.players[0]["melds"][0].get("type", "")) != "gang":
		failures.append("真人杠执行后没有生成杠副露")


func _build_reaction_state(human_can_gang: bool):
	var state = _build_state()
	var discarded := _tile(910, "tong", 6)
	var players: Array[Dictionary] = [
		_player(0, false, "tiao", [_tile(11, "tong", 6), _tile(12, "tong", 6), _tile(13, "tong", 6)]),
		_player(1, true, "wan", []),
		_player(2, true, "wan", []),
		_player(3, true, "wan", [_tile(31, "tong", 6), _tile(32, "tong", 6)]),
	]
	state.players = players
	state.current_phase = 6
	state.current_turn_seat = 1
	state.current_discard_context = {"source_seat": 1, "tile": discarded, "reaction_type": "discard"}
	var pending_reactions: Array[Dictionary] = [
		{"seat": 0, "can_hu": false, "can_gang": human_can_gang, "can_peng": true},
		{"seat": 3, "can_hu": false, "can_gang": false, "can_peng": true},
	]
	state.pending_reactions = pending_reactions
	return state


func _build_state():
	var state = GAME_STATE_SCRIPT.new()
	state.rules = load("res://scripts/core/rule_config.gd").new()
	state.mahjong_state = load("res://scripts/core/mahjong_state.gd").new()
	state.mahjong_judge = load("res://scripts/core/mahjong_judge.gd").new()
	state.ding_que_resolver = load("res://scripts/core/ding_que_resolver.gd").new()
	state.reaction_resolver = load("res://scripts/core/reaction_resolver.gd").new()
	state.hu_checker = load("res://scripts/core/hu_checker.gd").new()
	state.score_resolver = load("res://scripts/core/score_resolver.gd").new()
	state.shanten_analyzer = load("res://scripts/core/shanten_analyzer.gd").new()
	state.risk_analyzer = load("res://scripts/core/risk_analyzer.gd").new()
	return state


func _player(seat: int, is_ai: bool, ding_que: String, hand: Array) -> Dictionary:
	return {
		"seat": seat,
		"nickname": "Seat %d" % seat,
		"score": 0,
		"is_ai": is_ai,
		"hand_tiles": hand.duplicate(true),
		"hand_count": hand.size(),
		"melds": [],
		"discards": [],
		"ding_que": ding_que,
		"has_won": false,
	}


func _tile(id: int, suit: String, rank: int) -> Dictionary:
	return {
		"id": id,
		"suit": suit,
		"rank": rank,
		"sort_key": ["tiao", "tong", "wan"].find(suit) * 100 + rank,
		"display_name": "%d%s" % [rank, {"tiao": "条", "tong": "筒", "wan": "万"}.get(suit, "?")],
	}
