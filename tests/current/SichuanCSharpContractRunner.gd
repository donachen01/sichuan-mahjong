extends SceneTree

const BRIDGE_SCRIPT := preload("res://scripts/ai/csharp_ai_bridge.gd")
const RULE_CONFIG_SCRIPT := preload("res://scripts/core/rule_config.gd")


func _init() -> void:
	await process_frame
	var failures: Array[String] = []
	var bridge = BRIDGE_SCRIPT.new()
	var rules = RULE_CONFIG_SCRIPT.new()
	var player_state := _player(1, "wan", [
		_tile(1, "wan", 1), _tile(2, "wan", 1), _tile(3, "wan", 2),
		_tile(4, "tiao", 1), _tile(5, "tiao", 2), _tile(6, "tiao", 3),
		_tile(7, "tiao", 4), _tile(8, "tiao", 5), _tile(9, "tiao", 6),
		_tile(10, "tong", 2), _tile(11, "tong", 3), _tile(12, "tong", 4),
		_tile(13, "tong", 8), _tile(14, "tong", 8),
	])
	var players: Array = [
		_player(0, "tiao", [], [_meld("peng", "wan", 5, 1)]),
		player_state,
		_player(2, "tong", []),
		_player(3, "wan", []),
	]
	players[0]["discards"] = [_tile(31, "wan", 9)]
	players[2]["discards"] = [_tile(32, "tiao", 9)]
	var table_state := {
		"players": players,
		"dealer_seat": 0,
		"current_turn_seat": 1,
		"wall_count": 42,
		"round_index": 7,
		"total_rounds": 8,
		"remaining_rounds": 1,
		"event_version": 12,
		"last_draw_tile": {"seat": 1, "tile": _tile(40, "wan", 2)},
		"shun_he_locks": {1: {"locked_fan": 2, "lock_turn": 11, "unlock_on_own_draw": true}},
		"last_gang_context": {"seat": 0, "tile": _tile(41, "wan", 5), "gang_type": "melded_gang"},
		"public_ai_events": [
			{"eventIndex": 10, "turnIndex": 4, "seat": 0, "type": "discard", "tile": _tile(42, "wan", 9), "origin": "hand", "wallCountAfter": 44},
			{"eventIndex": 11, "turnIndex": 5, "seat": 2, "type": "discard", "tile": _tile(43, "tiao", 9), "origin": "draw", "wallCountAfter": 43},
			{"eventIndex": 12, "turnIndex": 6, "seat": 2, "type": "draw", "tile": _tile(45, "wan", 7), "origin": "draw", "wallCountAfter": 42},
		],
		"reaction_pass_evidence": [
			{"seat": 2, "tile": _tile(44, "wan", 3), "can_hu": true, "can_peng": false, "can_gang": false},
		],
	}

	var discard_payload: Dictionary = bridge.build_discard_transport_payload(player_state, table_state, rules)
	_expect(discard_payload.get("hand18", []).size() == 27, "hand18 不是 27 张合同", failures)
	_expect(int(discard_payload["hand18"][18]) == 2 and int(discard_payload["hand18"][19]) == 1, "万字没有编码到 18..26", failures)
	_expect(str(discard_payload.get("informationMode", "")) == "public", "非透视合同不是 public", failures)
	_expect(not discard_payload.has("allHands18") and not discard_payload.has("exactWall18"), "公开合同泄露隐藏手牌或精确牌墙", failures)
	_expect(int(discard_payload.get("eventVersion", -1)) >= 0, "公开事件指纹丢失", failures)
	var changed_private_version := table_state.duplicate(true)
	changed_private_version["event_version"] = 999
	var version_probe: Dictionary = bridge.build_discard_transport_payload(player_state, changed_private_version, rules)
	_expect(version_probe == discard_payload, "内部事件计数泄漏到公开输入", failures)
	_expect(discard_payload.get("publicEvents", []).size() == 3, "公开事件序列丢失", failures)
	_expect(str(discard_payload["publicEvents"][0].get("origin", "")) == "hand", "手切来源丢失", failures)
	_expect(str(discard_payload["publicEvents"][1].get("origin", "")) == "draw", "摸切来源丢失", failures)
	_expect(int(discard_payload["publicEvents"][2].get("tileType", -2)) == -1, "公开合同泄露对手摸牌", failures)
	_expect(discard_payload.get("meldViews", [])[0].size() == 1, "副露视图丢失", failures)
	_expect(int(discard_payload.get("lockedFans", [])[1]) == 2, "顺胡锁番值丢失", failures)
	_expect(int(discard_payload.get("passedHu18", [])[2][20]) == 0, "对手私有过胡权限泄漏", failures)
	var own_pass_table := table_state.duplicate(true)
	own_pass_table["reaction_pass_evidence"] = [{"seat": 1, "tile": _tile(44, "wan", 3), "can_hu": true}]
	var own_pass_payload: Dictionary = bridge.build_discard_transport_payload(player_state, own_pass_table, rules)
	_expect(int(own_pass_payload["passedHu18"][1][20]) == 1, "自身已知过胡记录丢失", failures)

	var reaction_payload: Dictionary = bridge.build_reaction_transport_payload(
		{"can_hu": true, "can_peng": true, "can_gang": false, "source_seat": 0},
		player_state,
		table_state,
		{"tile": _tile(50, "wan", 1), "source_seat": 0, "reaction_type": "discard"},
		rules
	)
	_expect(int(reaction_payload.get("reactionTileType", -1)) == 18, "万字反应牌编码错误", failures)
	_expect(bool(reaction_payload.get("canHu", false)) and bool(reaction_payload.get("canPeng", false)), "胡碰合法标志丢失", failures)

	var self_payload: Dictionary = bridge.build_self_action_transport_payload(player_state, table_state, rules, false, [18], [19], {19: 1}, [18])
	_expect(self_payload.get("anGangTileTypes", []) == [18], "暗杠候选丢失", failures)
	_expect(self_payload.get("addGangTileTypes", []) == [19], "补杠候选丢失", failures)
	_expect(self_payload.get("addGangQiangGangCounts", {}).is_empty(), "精确可抢杠人数泄漏", failures)

	var runtime := get_root().get_node_or_null("SichuanCSharpRuntime")
	_expect(runtime != null and runtime.has_method("AnalyzeDiscardAotCompact"), "iOS AOT 出牌接口不存在", failures)
	if runtime != null and runtime.has_method("AnalyzeDiscardAotCompact"):
		var aot_discard_raw := str(runtime.call("AnalyzeDiscardAotCompact", JSON.stringify(discard_payload), false))
		var aot_discard := aot_discard_raw.split("|", true)
		print("aot_discard_contract=", aot_discard_raw)
		_expect(aot_discard.size() >= 15 and aot_discard[0] == "ok" and int(aot_discard[2]) >= 0, "iOS AOT 普通出牌接口没有返回动作和核心解释", failures)
		var hell_payload := discard_payload.duplicate(true)
		hell_payload["allHands18"] = [discard_payload.get("hand18", []), [], [], []]
		hell_payload["exactWall18"] = _filled_counts(4)
		hell_payload["currentScores"] = [0, 0, 0, 0]
		var aot_hell_raw := str(runtime.call("AnalyzeDiscardAotCompact", JSON.stringify(hell_payload), true))
		var aot_hell := aot_hell_raw.split("|", true)
		print("aot_hell_contract=", aot_hell_raw)
		_expect(aot_hell.size() >= 10 and aot_hell[0] == "ok" and int(aot_hell[2]) >= 0, "iOS AOT 地狱模式没有返回可执行牌", failures)
		var aot_reaction := str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(reaction_payload), false)).split("|", true)
		_expect(aot_reaction.size() >= 11 and aot_reaction[0] == "ok", "iOS AOT 响应接口没有返回动作", failures)

		var peng_payload := reaction_payload.duplicate(true)
		peng_payload["canHu"] = false
		peng_payload["canPeng"] = true
		peng_payload["canGang"] = false
		var aot_peng := str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(peng_payload), false)).split("|", true)
		_expect(aot_peng.size() >= 11 and aot_peng[0] == "ok" and aot_peng[1] in ["pass", "peng"], "iOS AOT 碰/过合同无合法动作", failures)

		var direct_gang_payload := reaction_payload.duplicate(true)
		direct_gang_payload["canHu"] = false
		direct_gang_payload["canPeng"] = true
		direct_gang_payload["canGang"] = true
		direct_gang_payload["mandatoryGang"] = true
		var direct_gang_hand: Array = Array(discard_payload["hand18"]).duplicate()
		direct_gang_hand[18] = 3
		direct_gang_payload["hand18"] = direct_gang_hand
		var aot_direct_gang := str(runtime.call("AnalyzeReactionAotCompact", JSON.stringify(direct_gang_payload), false)).split("|", true)
		_expect(aot_direct_gang.size() >= 11 and aot_direct_gang[0] == "ok" and aot_direct_gang[1] == "gang", "iOS AOT 直杠合同未执行强制杠", failures)

		var self_hu_payload := self_payload.duplicate(true)
		self_hu_payload["canSelfHu"] = true
		self_hu_payload["anGangTileTypes"] = []
		self_hu_payload["addGangTileTypes"] = []
		self_hu_payload["mandatoryGangTileTypes"] = []
		var aot_self_hu := str(runtime.call("AnalyzeSelfActionAotCompact", JSON.stringify(self_hu_payload))).split("|", true)
		_expect(aot_self_hu.size() >= 8 and aot_self_hu[0] == "ok" and aot_self_hu[1] == "hu", "iOS AOT 自摸合同没有优先胡牌", failures)

		var an_gang_payload := self_payload.duplicate(true)
		var an_gang_hand: Array = Array(discard_payload["hand18"]).duplicate()
		an_gang_hand[18] = 4
		an_gang_payload["hand18"] = an_gang_hand
		an_gang_payload["canSelfHu"] = false
		an_gang_payload["anGangTileTypes"] = [18]
		an_gang_payload["addGangTileTypes"] = []
		an_gang_payload["mandatoryGangTileTypes"] = [18]
		var aot_an_gang := str(runtime.call("AnalyzeSelfActionAotCompact", JSON.stringify(an_gang_payload))).split("|", true)
		_expect(aot_an_gang.size() >= 8 and aot_an_gang[0] == "ok" and aot_an_gang[1] == "gang" and aot_an_gang[4] == "an_gang", "iOS AOT 暗杠合同未执行", failures)

		var add_gang_payload := self_payload.duplicate(true)
		add_gang_payload["canSelfHu"] = false
		add_gang_payload["anGangTileTypes"] = []
		add_gang_payload["addGangTileTypes"] = [19]
		add_gang_payload["mandatoryGangTileTypes"] = [19]
		var add_gang_melds: Array = Array(add_gang_payload.get("melds18", [[], [], [], []])).duplicate(true)
		add_gang_melds[1] = [19, 19, 19]
		add_gang_payload["melds18"] = add_gang_melds
		var add_gang_views: Array = Array(add_gang_payload.get("meldViews", [[], [], [], []])).duplicate(true)
		add_gang_views[1] = [{"type": "peng", "tileType": 19, "sourceSeat": 0, "actorSeat": 1}]
		add_gang_payload["meldViews"] = add_gang_views
		var aot_add_gang := str(runtime.call("AnalyzeSelfActionAotCompact", JSON.stringify(add_gang_payload))).split("|", true)
		_expect(aot_add_gang.size() >= 8 and aot_add_gang[0] == "ok" and aot_add_gang[1] == "gang" and aot_add_gang[4] == "add_gang", "iOS AOT 补杠合同未执行", failures)

		_expect(str(runtime.call("DecideDingQueSuit", 2, 5, 6)) == "tiao", "iOS AOT 定缺合同没有选择最少门", failures)

	if not bridge.is_available():
		failures.append("C# CLI 产物不存在，无法验证真实运行链路")
	else:
		var result: Dictionary = bridge.analyze_discard(player_state, table_state, rules, "contract")
		_expect(not result.is_empty(), "真实 C# CLI 没有返回出牌结果", failures)
		_expect(result.has("tileType") and result.has("candidates"), "C# 出牌结果缺少动作或候选合同", failures)
		_expect(str(result.get("informationMode", "public")) != "oracle", "公开调用意外进入透视模式", failures)

	if failures.is_empty():
		print("SICHUAN CSHARP CONTRACT OK: 29/29")
		quit(0)
		return
	push_error("SICHUAN CSHARP CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _player(seat: int, ding_que: String, hand: Array, melds: Array = []) -> Dictionary:
	return {
		"seat": seat,
		"nickname": "P%d" % seat,
		"score": 0,
		"is_ai": seat != 0,
		"is_dealer": seat == 0,
		"hand_tiles": hand.duplicate(true),
		"hand_count": hand.size(),
		"melds": melds.duplicate(true),
		"discards": [],
		"ding_que": ding_que,
		"has_won": false,
		"is_ting": false,
	}


func _meld(type_name: String, suit: String, rank: int, from_seat: int) -> Dictionary:
	return {
		"type": type_name,
		"from_seat": from_seat,
		"tiles": [_tile(60, suit, rank), _tile(61, suit, rank), _tile(62, suit, rank)],
	}


func _tile(id: int, suit: String, rank: int) -> Dictionary:
	return {"id": id, "suit": suit, "rank": rank, "display_name": "%d%s" % [rank, suit]}


func _filled_counts(value: int) -> Array:
	var result: Array = []
	result.resize(27)
	result.fill(value)
	return result
