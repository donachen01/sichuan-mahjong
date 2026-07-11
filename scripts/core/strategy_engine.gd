extends RefCounted

class_name StrategyEngine

const OpponentModelScript := preload("res://scripts/core/opponent_model.gd")

enum Mode {
	FULL_ATTACK,
	ATTACK_BALANCED,
	BALANCED,
	DEFEND_BALANCED,
	FULL_DEFENSE,
}

var opponent_model = OpponentModelScript.new()


func build_profile(player: Dictionary, players: Array, shanten: int, ting_tiles: Array) -> Dictionary:
	var round_stage: int = _resolve_round_stage(players)
	var dingque_state: Dictionary = _analyze_dingque_state(player, players)
	var hand_state: Dictionary = _analyze_hand_state(player)
	var opponent_state: Dictionary = _analyze_opponents(player, players, round_stage)
	var threat_level: int = int(opponent_state.get("threat_level", 0))
	var score_pressure: int = _resolve_score_pressure(player, players)
	var mode: int = _resolve_mode(shanten, ting_tiles, round_stage, threat_level, score_pressure, dingque_state, hand_state, opponent_state)
	return {
		"mode": mode,
		"mode_label": _mode_label(mode),
		"round_stage": round_stage,
		"round_stage_label": _round_stage_label(round_stage),
		"threat_level": threat_level,
		"score_pressure": score_pressure,
		"dingque_state": dingque_state,
		"hand_state": hand_state,
		"opponent_state": opponent_state,
		"weights": _weights_for_mode(mode, round_stage, threat_level, score_pressure, dingque_state, hand_state, opponent_state, shanten, ting_tiles),
		"reasons": _build_reasons(mode, round_stage, threat_level, score_pressure, shanten, ting_tiles, dingque_state, hand_state, opponent_state),
	}


func _resolve_round_stage(players: Array) -> int:
	var is_two_suit_table := _is_two_suit_table(players)
	var max_discards: int = 0
	for item in players:
		max_discards = maxi(max_discards, int(item.get("discards", []).size()))
	if is_two_suit_table:
		if max_discards <= 5:
			return 0
		if max_discards <= 11:
			return 1
		return 2
	if max_discards <= 7:
		return 0
	if max_discards <= 19:
		return 1
	return 2


func _analyze_dingque_state(player: Dictionary, players: Array) -> Dictionary:
	var self_counts: Dictionary = _count_suits(player.get("hand_tiles", []))
	var tiao_count := int(self_counts.get("tiao", 0))
	var tong_count := int(self_counts.get("tong", 0))
	var dominant_suit: String = "tiao" if tiao_count >= tong_count else "tong"
	var dominant_count: int = maxi(tiao_count, tong_count)
	var support_count: int = mini(tiao_count, tong_count)
	var spread: int = abs(tiao_count - tong_count)
	var state_label: String = "定缺均衡"
	if dominant_count >= support_count + 4:
		state_label = "单门偏重"
	elif dominant_count >= support_count + 2:
		state_label = "轻度偏门"
	return {
		"self_missing_suit": "",
		"suit_counts": {"tiao": 0, "tong": 0, "wan": 0},
		"dominant_missing_suit": "",
		"same_as_self": 0,
		"is_all_same": false,
		"is_three_same": false,
		"is_two_same_self_diff": false,
		"is_two_suit_table": true,
		"dominant_suit": dominant_suit,
		"dominant_count": dominant_count,
		"support_count": support_count,
		"spread": spread,
		"state_label": state_label,
	}


func _analyze_hand_state(player: Dictionary) -> Dictionary:
	var hand_tiles: Array = player.get("hand_tiles", [])
	var counts := {}
	var pair_count: int = 0
	var triplet_count: int = 0
	var adjacency_score: int = 0
	var isolated_count: int = 0
	var suit_counts := {"tiao": 0, "tong": 0, "wan": 0}
	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		var rank: int = int(tile.get("rank", 0))
		var key: String = "%s_%d" % [suit, rank]
		counts[key] = int(counts.get(key, 0)) + 1
		if suit_counts.has(suit):
			suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	for key in counts.keys():
		var count: int = int(counts[key])
		if count >= 2:
			pair_count += 1
		if count >= 3:
			triplet_count += 1
	for suit in suit_counts.keys():
		var ranks: Array[int] = []
		for tile in hand_tiles:
			if str(tile.get("suit", "")) == str(suit):
				ranks.append(int(tile.get("rank", 0)))
		ranks.sort()
		for index in range(ranks.size()):
			var rank: int = ranks[index]
			var near_count: int = 0
			for other_rank in ranks:
				if abs(other_rank - rank) == 1:
					near_count += 1
				elif abs(other_rank - rank) == 2:
					near_count += 1
			if near_count <= 0:
				isolated_count += 1
			adjacency_score += near_count
	var dominant_suit: String = ""
	var dominant_count: int = 0
	for suit in suit_counts.keys():
		var suit_count: int = int(suit_counts[suit])
		if suit_count > dominant_count:
			dominant_count = suit_count
			dominant_suit = str(suit)
	var hand_label: String = "防守型"
	if pair_count >= 3 and adjacency_score >= 10:
		hand_label = "进攻型"
	elif isolated_count >= 5 and adjacency_score <= 6:
		hand_label = "摆烂型"
	elif adjacency_score >= 8:
		hand_label = "均衡型"
	var qidui_ready: bool = pair_count >= 4 and player.get("melds", []).is_empty()
	var big_hand_focus: bool = dominant_count >= 6 or qidui_ready or pair_count >= 5
	return {
		"pair_count": pair_count,
		"triplet_count": triplet_count,
		"adjacency_score": adjacency_score,
		"isolated_count": isolated_count,
		"dominant_suit": dominant_suit,
		"dominant_count": dominant_count,
		"hand_label": hand_label,
		"qidui_ready": qidui_ready,
		"big_hand_focus": big_hand_focus,
	}


func _analyze_opponents(player: Dictionary, players: Array, round_stage: int) -> Dictionary:
	var self_seat: int = int(player.get("seat", -1))
	var threat_level: int = 0
	var fast_call_count: int = 0
	var silent_big_hand_count: int = 0
	var flush_watch_count: int = 0
	var pung_watch_count: int = 0
	var top_threat_profile: Dictionary = {}
	var profiles: Array[Dictionary] = []
	for item in players:
		var seat: int = int(item.get("seat", -1))
		if seat == self_seat or bool(item.get("has_won", false)):
			continue
		var profile: Dictionary = opponent_model.analyze_opponent(item)
		profiles.append(profile)
		var meld_count: int = int(item.get("melds", []).size())
		var discard_count: int = int(item.get("discards", []).size())
		if meld_count >= 3 or (meld_count >= 2 and discard_count >= 6):
			fast_call_count += 1
			threat_level += 2
		elif meld_count >= 1:
			threat_level += 1
		if meld_count == 0 and discard_count >= 8:
			silent_big_hand_count += 1
			threat_level += 1
		if round_stage >= 2 and discard_count >= 12:
			threat_level += 1
		if int(profile.get("flush_probability", 0)) >= 65:
			flush_watch_count += 1
			threat_level += 1
		if int(profile.get("pung_probability", 0)) >= 55:
			pung_watch_count += 1
		if top_threat_profile.is_empty() or int(profile.get("threat_score", 0)) > int(top_threat_profile.get("threat_score", -1)):
			top_threat_profile = profile
	return {
		"threat_level": clampi(threat_level, 0, 5),
		"fast_call_count": fast_call_count,
		"silent_big_hand_count": silent_big_hand_count,
		"flush_watch_count": flush_watch_count,
		"pung_watch_count": pung_watch_count,
		"top_threat_profile": top_threat_profile,
		"profiles": profiles,
	}


func _resolve_score_pressure(player: Dictionary, players: Array) -> int:
	var self_score: int = int(player.get("score", 0))
	var best_score: int = self_score
	for item in players:
		best_score = maxi(best_score, int(item.get("score", 0)))
	var deficit: int = best_score - self_score
	if deficit >= 8:
		return 2
	if deficit >= 3:
		return 1
	if deficit <= -8:
		return -2
	if deficit <= -3:
		return -1
	return 0


func _resolve_mode(
	shanten: int,
	ting_tiles: Array,
	round_stage: int,
	threat_level: int,
	score_pressure: int,
	dingque_state: Dictionary,
	hand_state: Dictionary,
	opponent_state: Dictionary
) -> int:
	var spread := int(dingque_state.get("spread", 0))
	if shanten <= 0:
		if ting_tiles.size() >= 2:
			return Mode.FULL_ATTACK
		if round_stage >= 2 and threat_level >= 4:
			return Mode.DEFEND_BALANCED
		return Mode.ATTACK_BALANCED
	if round_stage >= 2 and threat_level >= 4 and shanten >= 2:
		return Mode.FULL_DEFENSE
	if shanten <= 1 and spread >= 3 and bool(hand_state.get("big_hand_focus", false)):
		return Mode.FULL_ATTACK
	if score_pressure >= 2:
		return Mode.FULL_ATTACK
	if shanten <= 1:
		return Mode.ATTACK_BALANCED
	if int(opponent_state.get("fast_call_count", 0)) >= 2 and round_stage >= 2 and shanten >= 2:
		return Mode.DEFEND_BALANCED
	if spread >= 2 or bool(hand_state.get("big_hand_focus", false)):
		return Mode.ATTACK_BALANCED
	return Mode.ATTACK_BALANCED


func _weights_for_mode(
	mode: int,
	round_stage: int,
	threat_level: int,
	score_pressure: int,
	dingque_state: Dictionary,
	hand_state: Dictionary,
	opponent_state: Dictionary,
	shanten: int,
	ting_tiles: Array
) -> Dictionary:
	var weights := {
		"shanten_weight": 1.0,
		"ukeire_weight": 1.0,
		"wait_weight": 1.0,
		"fan_weight": 1.0,
		"shape_weight": 1.0,
		"risk_weight": 1.0,
		"pressure_weight": 1.0,
		"route_loss_weight": 1.0,
	}
	match mode:
		Mode.FULL_ATTACK:
			weights["shanten_weight"] = 1.64
			weights["ukeire_weight"] = 1.52
			weights["wait_weight"] = 1.36
			weights["fan_weight"] = 1.34
			weights["shape_weight"] = 1.14
			weights["risk_weight"] = 0.62
			weights["pressure_weight"] = 0.74
			weights["route_loss_weight"] = 1.24
		Mode.ATTACK_BALANCED:
			weights["shanten_weight"] = 1.46
			weights["ukeire_weight"] = 1.34
			weights["wait_weight"] = 1.18
			weights["fan_weight"] = 1.10
			weights["shape_weight"] = 1.08
			weights["risk_weight"] = 0.78
			weights["route_loss_weight"] = 1.08
		Mode.BALANCED:
			weights["shanten_weight"] = 1.34
			weights["ukeire_weight"] = 1.24
			weights["wait_weight"] = 1.10
			weights["fan_weight"] = 1.02
			weights["risk_weight"] = 0.90
		Mode.DEFEND_BALANCED:
			weights["shanten_weight"] = 1.08
			weights["ukeire_weight"] = 1.00
			weights["wait_weight"] = 0.98
			weights["fan_weight"] = 0.88
			weights["shape_weight"] = 0.96
			weights["risk_weight"] = 1.22
			weights["pressure_weight"] = 1.18
			weights["route_loss_weight"] = 0.92
		Mode.FULL_DEFENSE:
			weights["shanten_weight"] = 0.84
			weights["ukeire_weight"] = 0.78
			weights["wait_weight"] = 0.76
			weights["fan_weight"] = 0.72
			weights["shape_weight"] = 0.82
			weights["risk_weight"] = 1.82
			weights["pressure_weight"] = 1.66
			weights["route_loss_weight"] = 0.74
	if bool(dingque_state.get("is_two_suit_table", false)):
		weights["shanten_weight"] = float(weights["shanten_weight"]) + 0.18
		weights["ukeire_weight"] = float(weights["ukeire_weight"]) + 0.16
		weights["wait_weight"] = float(weights["wait_weight"]) + 0.14
		if int(dingque_state.get("spread", 0)) >= 3:
			weights["fan_weight"] = float(weights["fan_weight"]) + 0.18
			weights["route_loss_weight"] = float(weights["route_loss_weight"]) + 0.12
		else:
			weights["fan_weight"] = float(weights["fan_weight"]) - 0.02
			weights["risk_weight"] = float(weights["risk_weight"]) + 0.02
	if bool(hand_state.get("qidui_ready", false)):
		weights["fan_weight"] = float(weights["fan_weight"]) + 0.12
		weights["route_loss_weight"] = float(weights["route_loss_weight"]) + 0.16
	if round_stage >= 2:
		weights["risk_weight"] = float(weights["risk_weight"]) + 0.12
		weights["pressure_weight"] = float(weights["pressure_weight"]) + 0.10
	if threat_level >= 4:
		weights["risk_weight"] = float(weights["risk_weight"]) + 0.16
	if int(opponent_state.get("fast_call_count", 0)) >= 2 and round_stage >= 2:
		weights["risk_weight"] = float(weights["risk_weight"]) + 0.12
	if score_pressure >= 2:
		weights["fan_weight"] = float(weights["fan_weight"]) + 0.10
		weights["shanten_weight"] = float(weights["shanten_weight"]) + 0.08
	if shanten <= 0 and not ting_tiles.is_empty():
		weights["wait_weight"] = float(weights["wait_weight"]) + 0.12
	if shanten == 1:
		weights["shanten_weight"] = float(weights["shanten_weight"]) + 0.12
		weights["ukeire_weight"] = float(weights["ukeire_weight"]) + 0.10
	return weights


func _build_reasons(
	mode: int,
	round_stage: int,
	threat_level: int,
	score_pressure: int,
	shanten: int,
	ting_tiles: Array,
	dingque_state: Dictionary,
	hand_state: Dictionary,
	opponent_state: Dictionary
) -> Array[String]:
	var reasons: Array[String] = []
	reasons.append("当前策略 %s" % _mode_label(mode))
	reasons.append("牌局阶段 %s" % _round_stage_label(round_stage))
	reasons.append("定缺后浅牌墙，优先速度与成叫")
	reasons.append("当前牌形 %s" % str(dingque_state.get("state_label", "定缺均衡")))
	reasons.append("起手牌型 %s" % str(hand_state.get("hand_label", "均衡型")))
	if int(dingque_state.get("spread", 0)) >= 3:
		reasons.append("单门已明显偏重，可保留染手与高番弹性")
	else:
		reasons.append("双门分布接近，宽叫与活张优先")
	if int(opponent_state.get("fast_call_count", 0)) >= 1:
		reasons.append("有人频繁副露，需重点提防快听")
	if int(opponent_state.get("silent_big_hand_count", 0)) >= 1:
		reasons.append("有人长时间不碰，警惕清一色或七对")
	if int(opponent_state.get("flush_watch_count", 0)) >= 1:
		var top_profile: Dictionary = opponent_state.get("top_threat_profile", {})
		reasons.append("有人疑似做%s清，避免乱放其主花色" % str(top_profile.get("dangerous_suit_label", "")))
	if int(opponent_state.get("pung_watch_count", 0)) >= 1:
		reasons.append("有人像对对胡/将对路线，2/5/8 需更谨慎")
	if score_pressure >= 2:
		reasons.append("当前落后，优先抢听追分")
	elif score_pressure <= -2:
		reasons.append("当前领先，也不轻易放慢成叫速度")
	if round_stage >= 2:
		reasons.append("尾盘才适度收缩，前中盘优先进攻")
	if shanten <= 0 and not ting_tiles.is_empty():
		reasons.append("已经听牌，不轻易改叫贪更大")
	return reasons


func _is_two_suit_table(players: Array) -> bool:
	for item in players:
		var hand_tiles: Array = item.get("hand_tiles", [])
		for tile in hand_tiles:
			if str(tile.get("suit", "")) == "wan":
				return false
		for meld in item.get("melds", []):
			for tile in meld.get("tiles", []):
				if str(tile.get("suit", "")) == "wan":
					return false
		for discard in item.get("discards", []):
			if str(discard.get("suit", "")) == "wan":
				return false
	return true


func _count_suits(hand_tiles: Array) -> Dictionary:
	var counts := {"tiao": 0, "tong": 0, "wan": 0}
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		if counts.has(suit):
			counts[suit] = int(counts.get(suit, 0)) + 1
	return counts


func _mode_label(mode: int) -> String:
	match mode:
		Mode.FULL_ATTACK:
			return "速攻压分"
		Mode.ATTACK_BALANCED:
			return "抢听推进"
		Mode.BALANCED:
			return "定缺速听"
		Mode.DEFEND_BALANCED:
			return "稳听控险"
		Mode.FULL_DEFENSE:
			return "全守"
		_:
			return "定缺速听"


func _round_stage_label(stage: int) -> String:
	match stage:
		0:
			return "前期"
		1:
			return "中期"
		2:
			return "后期"
		_:
			return "中期"
