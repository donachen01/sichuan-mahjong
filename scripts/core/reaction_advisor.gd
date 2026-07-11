extends RefCounted

class_name ReactionAdvisor

const NeijiangDecisionEngineScript := preload("res://scripts/ai/sichuan_decision_engine.gd")

var neijiang_decision_engine = NeijiangDecisionEngineScript.new()


func choose_action(
	candidate: Dictionary,
	player: Dictionary,
	players: Array,
	discard_context: Dictionary,
	rules_config,
	mahjong_judge,
	allow_cheat: bool = false
) -> Dictionary:
	if rules_config != null and bool(rules_config.is_neijiang_mode()):
		return {}
	var discarded_tile: Dictionary = discard_context.get("tile", {})
	if discarded_tile.is_empty():
		return {"action": "pass", "score": -9999, "reasons": ["无可用弃牌上下文"]}

	if bool(candidate.get("can_hu", false)):
		return {
			"action": "hu",
			"score": 100000,
			"reasons": ["可胡时直接胡牌，优先级最高"],
		}

	var current_shape: Dictionary = _analyze_fast_shape(player, players, rules_config, mahjong_judge)
	var current_best_score: int = int(current_shape.get("score", 0))
	var current_best_shanten: int = int(current_shape.get("shanten", 8))
	var actions: Array[Dictionary] = []

	if bool(candidate.get("can_gang", false)):
		actions.append(_evaluate_gang(player, players, discarded_tile, rules_config, mahjong_judge, allow_cheat, current_best_score, current_best_shanten))
	if bool(candidate.get("can_peng", false)):
		actions.append(_evaluate_peng(player, players, discarded_tile, rules_config, mahjong_judge, allow_cheat, current_best_score, current_best_shanten))

	actions.append(_evaluate_pass(player, players, current_shape))
	actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", -9999)) > int(b.get("score", -9999))
	)
	return actions[0] if not actions.is_empty() else {"action": "pass", "score": -9999, "reasons": ["无反应动作"]}


func _evaluate_peng(
	player: Dictionary,
	players: Array,
	discarded_tile: Dictionary,
	rules_config,
	mahjong_judge,
	allow_cheat: bool,
	current_best_score: int,
	current_best_shanten: int
) -> Dictionary:
	var simulated_player := player.duplicate(true)
	var remaining_hand := _remove_matching_tiles(player.get("hand_tiles", []), discarded_tile, 2)
	var melds: Array = simulated_player.get("melds", []).duplicate(true)
	melds.append(
		{
			"type": "peng",
			"from_seat": int(player.get("seat", -1)),
			"tiles": [
				discarded_tile.duplicate(true),
				discarded_tile.duplicate(true),
				discarded_tile.duplicate(true),
			],
		}
	)
	simulated_player["hand_tiles"] = remaining_hand
	simulated_player["hand_count"] = remaining_hand.size()
	simulated_player["melds"] = melds

	var shape: Dictionary = _analyze_fast_shape(simulated_player, players, rules_config, mahjong_judge)
	var best_score: int = int(shape.get("score", -9999))
	var best_shanten: int = int(shape.get("shanten", 8))
	var strategy_mode := str(shape.get("mode_label", "定缺速听"))

	var score := 0
	var reasons: Array[String] = []
	var round_stage: int = int(shape.get("round_stage", 1))
	var fast_call_count: int = int(shape.get("fast_call_count", 0))
	var is_neijiang: bool = rules_config != null and bool(rules_config.is_neijiang_mode())
	if best_shanten < current_best_shanten:
		score += 180
		reasons.append("碰后向听下降，明显提速")
	elif best_shanten == current_best_shanten:
		score += 48
		reasons.append("碰后不降速，可保持节奏")
	else:
		score -= 160
		reasons.append("碰后向听变差，不宜轻碰")

	if is_neijiang and best_shanten <= 0:
		score += 160
		reasons.append("碰后可直接成叫，四川血战优先尽快成叫")
	elif is_neijiang and current_best_shanten > 1 and best_shanten == 1:
		score += 96
		reasons.append("碰后可快速逼近成叫，允许主动提速")
	elif is_neijiang and current_best_shanten == 1 and best_shanten == 1:
		score += 42
		reasons.append("当前已接近听牌，碰后可稳住一向听")

	score += int(round(float(best_score - current_best_score) * 0.35))
	if strategy_mode in ["全攻", "进攻平衡"] and best_shanten <= 1:
		score += 28
		reasons.append("当前偏进攻，碰后有利于压缩和牌距离")
	if not is_neijiang and int(shape.get("dingque_count", 0)) > _count_dingque_tiles(player.get("hand_tiles", []), str(player.get("ding_que", ""))):
		score -= 52
		reasons.append("碰后缺门处理变慢")
	if int(shape.get("isolated_count", 0)) >= 3:
		score -= 24
		reasons.append("碰后孤张仍多，价值有限")
	if is_neijiang and round_stage == 0 and best_shanten > current_best_shanten:
		score -= 68
		reasons.append("四川前期碰后变慢，不轻碰")
	var pair_count := _count_pairs(player.get("hand_tiles", []), discarded_tile)
	if is_neijiang and pair_count >= 3 and best_shanten <= current_best_shanten:
		score += 120
		reasons.append("对子冗余较多且碰后不降速，老手主动碰牌定型")
	if is_neijiang and current_best_shanten <= 1 and best_shanten <= current_best_shanten:
		score += 24
		reasons.append("已接近成叫，碰牌可直接压缩和牌距离")
	if round_stage >= 2 or fast_call_count >= 2:
		score -= 36
		reasons.append("尾盘或多人提速时，不为无收益碰牌暴露手型")

	return {
		"action": "peng",
		"score": score,
		"reasons": reasons,
	}


func _evaluate_gang(
	player: Dictionary,
	players: Array,
	discarded_tile: Dictionary,
	rules_config,
	mahjong_judge,
	allow_cheat: bool,
	current_best_score: int,
	current_best_shanten: int
) -> Dictionary:
	var simulated_player := player.duplicate(true)
	var remaining_hand := _remove_matching_tiles(player.get("hand_tiles", []), discarded_tile, 3)
	var melds: Array = simulated_player.get("melds", []).duplicate(true)
	melds.append(
		{
			"type": "gang",
			"from_seat": int(player.get("seat", -1)),
			"tiles": [
				discarded_tile.duplicate(true),
				discarded_tile.duplicate(true),
				discarded_tile.duplicate(true),
				discarded_tile.duplicate(true),
			],
		}
	)
	simulated_player["hand_tiles"] = remaining_hand
	simulated_player["hand_count"] = remaining_hand.size()
	simulated_player["melds"] = melds

	var shape: Dictionary = _analyze_fast_shape(simulated_player, players, rules_config, mahjong_judge)
	var strategy_mode := str(shape.get("mode_label", "定缺速听"))
	var best_score: int = int(shape.get("score", current_best_score))
	var best_shanten: int = int(shape.get("shanten", current_best_shanten))
	var round_stage: int = int(shape.get("round_stage", 1))
	var threat_level: int = int(shape.get("threat_level", 0))

	var score := 36
	var reasons: Array[String] = ["明杠自带杠分收益"]
	if best_shanten < current_best_shanten:
		score += 110
		reasons.append("杠后手牌结构更清晰")
	elif best_shanten == current_best_shanten:
		score += 24
		reasons.append("杠后不损速度")
	else:
		score -= 120
		reasons.append("杠后结构变差，需谨慎")

	score += int(round(float(best_score - current_best_score) * 0.25))
	if strategy_mode in ["全守", "防守平衡"]:
		score -= 42
		reasons.append("当前偏防守，不宜轻易开杠")
	if int(shape.get("pair_count", 0)) <= 0 and best_shanten > 0:
		score -= 28
		reasons.append("杠后缺少将牌支撑")
	if round_stage >= 1 and threat_level >= 3:
		score -= 54
		reasons.append("中后期对手压力高，明杠风险过大")
	return {
		"action": "gang",
		"score": score,
		"reasons": reasons,
	}



func _count_pairs(hand_tiles: Array, include_tile: Dictionary = {}) -> int:
	var counts := {}
	for tile in hand_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		counts[key] = int(counts.get(key, 0)) + 1
	if not include_tile.is_empty():
		var key := "%s_%d" % [str(include_tile.get("suit", "")), int(include_tile.get("rank", 0))]
		counts[key] = int(counts.get(key, 0)) + 1
	var pairs := 0
	for key in counts.keys():
		if int(counts[key]) >= 2:
			pairs += 1
	return pairs

func _evaluate_pass(player: Dictionary, players: Array, current_shape: Dictionary) -> Dictionary:
	var score := 0
	var reasons: Array[String] = ["保留手型，继续按当前最优路线推进"]
	var strategy_mode := str(current_shape.get("mode_label", "定缺速听"))
	if strategy_mode in ["全守", "防守平衡"]:
		score += 42
		reasons.append("当前偏防守，过更稳妥")
	elif strategy_mode == "定缺速听":
		score += 12
	var threat_level := int(current_shape.get("threat_level", 0))
	score += threat_level * 6
	if int(current_shape.get("shanten", 8)) <= 1:
		score += 18
		reasons.append("当前手牌已接近听牌，过更利于保持好形")
	return {
		"action": "pass",
		"score": score,
		"reasons": reasons,
	}


func _analyze_fast_shape(player: Dictionary, players: Array, rules_config, mahjong_judge) -> Dictionary:
	var hand_tiles: Array = player.get("hand_tiles", [])
	var shanten_info: Dictionary = mahjong_judge.analyze_shanten(player, rules_config)
	var shanten: int = int(shanten_info.get("shanten", 8))
	var counts: Dictionary = _build_tile_counts(hand_tiles)
	var pair_count: int = 0
	var triplet_count: int = 0
	for key in counts.keys():
		var count: int = int(counts[key])
		if count >= 2:
			pair_count += 1
		if count >= 3:
			triplet_count += 1
	var isolated_count: int = _count_isolated_tiles(hand_tiles, counts)
	var dingque_count: int = _count_dingque_tiles(hand_tiles, str(player.get("ding_que", "")))
	var meld_count: int = int(player.get("melds", []).size())
	var round_stage: int = _estimate_round_stage(players)
	var fast_call_count: int = _estimate_fast_call_count(player, players)
	var score: int = 220 - shanten * 58 + int(shanten_info.get("ukeire", 0)) * 4
	score += pair_count * 12 + triplet_count * 24 + meld_count * 18
	score -= isolated_count * 10 + dingque_count * 42
	return {
		"shanten": shanten,
		"score": score,
		"pair_count": pair_count,
		"triplet_count": triplet_count,
		"isolated_count": isolated_count,
		"dingque_count": dingque_count,
		"threat_level": _estimate_threat_level(players),
		"round_stage": round_stage,
		"fast_call_count": fast_call_count,
		"mode_label": _resolve_fast_mode(shanten, _estimate_threat_level(players)),
	}


func _build_tile_counts(hand_tiles: Array) -> Dictionary:
	var counts: Dictionary = {}
	for tile in hand_tiles:
		var key: String = _tile_key(tile)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _count_dingque_tiles(hand_tiles: Array, dingque: String) -> int:
	if dingque.is_empty():
		return 0
	var count: int = 0
	for tile in hand_tiles:
		if str(tile.get("suit", "")) == dingque:
			count += 1
	return count


func _count_isolated_tiles(hand_tiles: Array, counts: Dictionary) -> int:
	var isolated_count: int = 0
	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		var rank: int = int(tile.get("rank", 0))
		if int(counts.get(_tile_key(tile), 0)) >= 2:
			continue
		var has_neighbor: bool = false
		for delta in [-2, -1, 1, 2]:
			if int(counts.get("%s:%d" % [suit, rank + delta], 0)) > 0:
				has_neighbor = true
				break
		if not has_neighbor:
			isolated_count += 1
	return isolated_count


func _estimate_threat_level(players: Array) -> int:
	var threat_level: int = 0
	for other in players:
		if bool(other.get("has_won", false)):
			threat_level += 2
			continue
		if int(other.get("hand_count", 14)) <= 4:
			threat_level += 1
		if int(other.get("melds", []).size()) >= 3:
			threat_level += 1
	return min(threat_level, 4)


func _resolve_fast_mode(shanten: int, threat_level: int) -> String:
	if threat_level >= 3 and shanten >= 2:
		return "防守平衡"
	if shanten <= 1:
		return "进攻平衡"
	return "定缺速听"


func _tile_key(tile: Dictionary) -> String:
	return "%s:%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


func _estimate_round_stage(players: Array) -> int:
	var max_discards: int = 0
	for player in players:
		max_discards = maxi(max_discards, int(player.get("discards", []).size()))
	if max_discards <= 7:
		return 0
	if max_discards <= 19:
		return 1
	return 2


func _estimate_fast_call_count(self_player: Dictionary, players: Array) -> int:
	var self_seat: int = int(self_player.get("seat", -1))
	var count: int = 0
	for player in players:
		if int(player.get("seat", -1)) == self_seat:
			continue
		if int(player.get("melds", []).size()) >= 2:
			count += 1
	return count


func _remove_matching_tiles(hand_tiles: Array, target_tile: Dictionary, count: int) -> Array:
	var removed := 0
	var result: Array = []
	for tile in hand_tiles:
		if removed < count and str(tile.get("suit", "")) == str(target_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(target_tile.get("rank", 0)):
			removed += 1
			continue
		result.append(tile.duplicate(true))
	return result


func _replace_player(players: Array, simulated_player: Dictionary) -> Array:
	var result: Array = players.duplicate(true)
	var target_seat := int(simulated_player.get("seat", -1))
	for index in range(result.size()):
		if int(result[index].get("seat", -1)) == target_seat:
			result[index] = simulated_player.duplicate(true)
			break
	return result
