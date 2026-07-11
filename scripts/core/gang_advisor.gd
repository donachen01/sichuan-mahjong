extends RefCounted

class_name GangAdvisor

const BeliefEngineScript := preload("res://scripts/ai/sichuan_belief_engine.gd")

var belief_engine = BeliefEngineScript.new()


func evaluate_an_gang(
	player: Dictionary,
	players: Array,
	option: Dictionary,
	rules_config,
	mahjong_judge,
	ai_config = null,
	allow_cheat: bool = false
) -> Dictionary:
	var current_analysis: Dictionary = mahjong_judge.analyze_discard_options(player, {"players": players}, rules_config, allow_cheat, false)
	var current_best: Dictionary = current_analysis.get("recommended", {})
	var current_score := int(current_best.get("score", 0))
	var current_shanten := int(current_best.get("shanten", 8))

	var simulated_player := player.duplicate(true)
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	var gang_tiles: Array = option.get("tiles", [])
	if gang_tiles.is_empty():
		return {"score": -9999, "reasons": ["无有效暗杠候选"]}
	var reduced_hand := _remove_matching_tiles(hand_tiles, gang_tiles[0], 4)
	var simulated_melds: Array = player.get("melds", []).duplicate(true)
	simulated_melds.append(
		{
			"type": "gang",
			"from_seat": int(player.get("seat", -1)),
			"tiles": gang_tiles.duplicate(true),
			"gang_subtype": "an_gang",
		}
	)
	simulated_player["hand_tiles"] = reduced_hand
	simulated_player["hand_count"] = reduced_hand.size()
	simulated_player["melds"] = simulated_melds

	var simulated_players := _replace_player(players, simulated_player)
	var after_analysis: Dictionary = mahjong_judge.analyze_discard_options(simulated_player, {"players": simulated_players}, rules_config, allow_cheat, false)
	var after_best: Dictionary = after_analysis.get("recommended", {})
	var after_score := int(after_best.get("score", 0))
	var after_shanten := int(after_best.get("shanten", 8))
	var strategy_profile: Dictionary = after_analysis.get("strategy_profile", {})
	var strategy_mode := str(strategy_profile.get("mode_label", "定缺速听"))
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	var threat_level: int = int(strategy_profile.get("threat_level", 0))
	var posterior_penalty: int = _estimate_posterior_gang_penalty(player, players, gang_tiles[0], rules_config, ai_config, true)
	var gui_bonus: int = _estimate_gui_bonus_from_option(gang_tiles, rules_config)
	var endgame_penalty: int = _estimate_endgame_gang_penalty(strategy_profile, current_shanten, after_shanten)

	var score := 102
	var reasons: Array[String] = ["暗杠默认优先，稳定加分且能补牌"]
	if after_shanten < current_shanten:
		score += 88
		reasons.append("暗杠后结构更清晰")
	elif after_shanten == current_shanten:
		score += 42
		reasons.append("暗杠后不损速度")
	else:
		score -= 96
		reasons.append("暗杠后向听变差，不宜贸然开杠")
	score += int(round(float(after_score - current_score) * 0.22))
	score += gui_bonus
	if gui_bonus > 0:
		reasons.append("暗杠顺带放大归收益")
	if round_stage >= 2 and threat_level >= 3:
		score -= 24
		reasons.append("尾盘且威胁高，暗杠收益下降")
	elif strategy_mode in ["全守", "防守平衡"]:
		score -= 8
		reasons.append("当前偏防守，但暗杠仍可接受")
	if posterior_penalty > 0:
		score -= posterior_penalty
		reasons.append("后验显示尾盘听牌/持张压力偏高，暗杠收益需让位防守")
	if endgame_penalty > 0:
		score -= endgame_penalty
		reasons.append("未成叫且后巡临近，杠牌优先让位给防炮/查叫")
	return {
		"score": score,
		"reasons": reasons,
	}


func evaluate_add_gang(
	player: Dictionary,
	players: Array,
	option: Dictionary,
	rules_config,
	mahjong_judge,
	qiang_gang_candidate_count: int,
	ai_config = null,
	allow_cheat: bool = false
) -> Dictionary:
	var current_analysis: Dictionary = mahjong_judge.analyze_discard_options(player, {"players": players}, rules_config, allow_cheat, false)
	var current_best: Dictionary = current_analysis.get("recommended", {})
	var current_score := int(current_best.get("score", 0))
	var current_shanten := int(current_best.get("shanten", 8))

	var simulated_player := player.duplicate(true)
	var reduced_hand := _remove_matching_tiles(player.get("hand_tiles", []).duplicate(true), option.get("tile", {}), 1)
	var simulated_melds: Array = player.get("melds", []).duplicate(true)
	var meld_index := int(option.get("meld_index", -1))
	if meld_index < 0 or meld_index >= simulated_melds.size():
		return {"score": -9999, "reasons": ["无有效补杠候选"]}
	var target_meld: Dictionary = simulated_melds[meld_index]
	var target_tiles: Array = target_meld.get("tiles", []).duplicate(true)
	target_tiles.append(option.get("tile", {}).duplicate(true))
	target_meld["type"] = "gang"
	target_meld["tiles"] = target_tiles
	target_meld["gang_upgrade"] = true
	simulated_melds[meld_index] = target_meld
	simulated_player["hand_tiles"] = reduced_hand
	simulated_player["hand_count"] = reduced_hand.size()
	simulated_player["melds"] = simulated_melds

	var simulated_players := _replace_player(players, simulated_player)
	var after_analysis: Dictionary = mahjong_judge.analyze_discard_options(simulated_player, {"players": simulated_players}, rules_config, allow_cheat, false)
	var after_best: Dictionary = after_analysis.get("recommended", {})
	var after_score := int(after_best.get("score", 0))
	var after_shanten := int(after_best.get("shanten", 8))
	var strategy_profile: Dictionary = after_analysis.get("strategy_profile", {})
	var strategy_mode := str(strategy_profile.get("mode_label", "定缺速听"))
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	var threat_level: int = int(strategy_profile.get("threat_level", 0))
	var posterior_penalty: int = _estimate_posterior_gang_penalty(player, players, option.get("tile", {}), rules_config, ai_config, false)
	var gui_bonus: int = _estimate_gui_bonus_from_option([option.get("tile", {})], rules_config)
	var endgame_penalty: int = _estimate_endgame_gang_penalty(strategy_profile, current_shanten, after_shanten)

	var score := 64
	var reasons: Array[String] = ["补杠可提升番外收益"]
	if after_shanten < current_shanten:
		score += 74
		reasons.append("补杠后结构变优")
	elif after_shanten == current_shanten:
		score += 46
		reasons.append("补杠后不明显降速")
	else:
		score -= 92
		reasons.append("补杠后结构变差")
	score += int(round(float(after_score - current_score) * 0.20))
	score += gui_bonus
	if gui_bonus > 0:
		reasons.append("补杠能放大归/杠收益")
	if qiang_gang_candidate_count > 0:
		score -= 180 * qiang_gang_candidate_count
		reasons.append("存在抢杠胡风险，强烈降权")
	if round_stage >= 2 or threat_level >= 3:
		score -= 24
		reasons.append("中后期威胁高，补杠容易放大风险")
	elif strategy_mode in ["全守", "防守平衡"]:
		score -= 12
		reasons.append("当前偏防守，不宜补杠")
	if posterior_penalty > 0:
		score -= posterior_penalty
		reasons.append("后验显示有人高概率已听/持张，补杠风险进一步放大")
	if endgame_penalty > 0:
		score -= endgame_penalty
		reasons.append("尾盘未成叫时，补杠优先级明显下降")
	return {
		"score": score,
		"reasons": reasons,
	}


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


func _estimate_gui_bonus_from_option(tiles: Array, rules_config) -> int:
	if rules_config == null or not bool(rules_config.is_neijiang_mode()) or not bool(rules_config.enable_gui):
		return 0
	if tiles.is_empty():
		return 0
	return 18


func _estimate_endgame_gang_penalty(strategy_profile: Dictionary, current_shanten: int, after_shanten: int) -> int:
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	if round_stage < 2:
		return 0
	if after_shanten <= 0:
		return 0
	if current_shanten <= 1 and after_shanten <= 1:
		return 20
	return 48


func _estimate_posterior_gang_penalty(player: Dictionary, players: Array, tile: Dictionary, rules_config, ai_config = null, is_an_gang: bool = false) -> int:
	if tile.is_empty() or rules_config == null or not bool(rules_config.is_neijiang_mode()):
		return 0
	var active_suits: Array = rules_config.available_suits.duplicate()
	var belief: Dictionary = belief_engine.build_snapshot(players, int(player.get("seat", -1)), active_suits)
	var defense := 2 if ai_config == null else clampi(int(ai_config.defense_tendency), -3, 3)
	var max_ready := 0.0
	var top_hold := 0.0
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	for other in players:
		var seat := int(other.get("seat", -1))
		if seat == int(player.get("seat", -1)) or bool(other.get("has_won", false)):
			continue
		max_ready = maxf(max_ready, float(belief.get("seat_pressure", {}).get(seat, 0.0)))
		var suit_info: Dictionary = belief.get("seat_tile_demand", {}).get(seat, {}).get(suit, {})
		var hold_like := float(suit_info.get("ranks", {}).get(rank, 0.0)) * 0.55 + float(suit_info.get("heat", 0.0)) * 0.45
		if bool(other.get("bao_jiao", false)):
			hold_like += 0.18
		top_hold = maxf(top_hold, hold_like)
	var penalty := 0
	var round_stage := 0
	for other in players:
		round_stage = maxi(round_stage, int(other.get("discards", []).size()))
	if round_stage >= 10:
		penalty += 24 + defense * 4
	if max_ready >= 0.56:
		penalty += 34 + int(round((max_ready - 0.56) * 80.0))
	if top_hold >= 0.52:
		penalty += 24 + int(round((top_hold - 0.52) * 72.0))
	if is_an_gang:
		penalty = int(round(float(penalty) * 0.72))
	return maxi(penalty, 0)
