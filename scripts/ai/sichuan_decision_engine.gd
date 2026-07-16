extends RefCounted

class_name SichuanDecisionEngine

const ShantenEngineScript := preload("res://scripts/ai/sichuan_shanten_engine.gd")
const DangerEngineScript := preload("res://scripts/ai/sichuan_danger_engine.gd")
const BeliefEngineScript := preload("res://scripts/ai/sichuan_belief_engine.gd")
const CallQualityEngineScript := preload("res://scripts/ai/sichuan_call_quality_engine.gd")
const TileCodecScript := preload("res://scripts/ai/sichuan_tile_codec.gd")

var shanten_engine = ShantenEngineScript.new()
var danger_engine = DangerEngineScript.new()
var belief_engine = BeliefEngineScript.new()
var call_quality_engine = CallQualityEngineScript.new()
var tile_codec = TileCodecScript.new()


func build_support_context(player: Dictionary, players: Array, rules_config, hu_checker, risk_analyzer, ai_config = null, allow_cheat: bool = false) -> Dictionary:
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	var active_suits: Array = tile_codec.resolve_active_suits(rules_config)
	var forced_suit := _forced_discard_suit(player)
	var current_routes := _estimate_routes(hand_tiles, player)
	var current_shanten_info := shanten_engine.analyze_hand(hand_tiles, int(player.get("melds", []).size()), bool(rules_config.enable_qi_dui))
	var current_ting_tiles: Array = hu_checker.get_ting_tiles(hand_tiles, str(player.get("ding_que", "")), rules_config, int(player.get("melds", []).size()), player.get("melds", []))
	var option_support: Dictionary = {}
	var seen := {}
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		if forced_suit != "" and suit != forced_suit:
			continue
		var key := _tile_key(tile)
		if seen.has(key):
			continue
		seen[key] = true
		var remaining_hand := _remove_one(hand_tiles, tile)
		var route_after := _estimate_routes(remaining_hand, player)
		var route_loss := _array_difference(current_routes, route_after)
		var risk_info: Dictionary = danger_engine.evaluate_tile(tile, int(player.get("seat", -1)), players, active_suits)
		if allow_cheat and risk_analyzer != null:
			var cheat_risk: Dictionary = risk_analyzer.analyze_discard_risk(tile, int(player.get("seat", -1)), players, hu_checker, rules_config, true)
			if int(cheat_risk.get("risk", 0)) > int(risk_info.get("risk", 0)):
				risk_info = cheat_risk
		var tile_type: int = tile_codec.tile_type(tile, active_suits)
		if tile_type >= 0:
			option_support[tile_type] = {
				"tile": tile.duplicate(true),
				"tile_name": str(tile.get("display_name", "?")),
				"tile_key": key,
				"routes_after": route_after.duplicate(true),
				"route_loss": route_loss.duplicate(true),
				"risk_reasons": risk_info.get("reasons", []).duplicate(true),
				"shape_score": _build_shape_support(route_after, route_loss),
				"safety_score": _build_safety_support(risk_info),
				"pressure_score": _build_pressure_support(risk_info),
			}
	var two_suit_state := _build_two_suit_state(hand_tiles)
	return {
		"forced_discard_suit": forced_suit,
		"current_routes": current_routes,
		"strategy_profile": {
			"mode_label": _resolve_strategy_mode(current_shanten_info, current_ting_tiles, {}, players),
			"round_stage": _round_stage(players),
			"dingque_state": two_suit_state.duplicate(true),
			"reasons": ["定缺后优先追求最小向听、宽叫与活张", "当前牌形 %s" % str(two_suit_state.get("state_label", "定缺均衡"))],
		},
		"option_support": option_support,
	}


func analyze_discard_options(player: Dictionary, players: Array, rules_config, hu_checker, risk_analyzer, ai_config = null, allow_cheat: bool = false) -> Dictionary:
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	var active_suits: Array = tile_codec.resolve_active_suits(rules_config)
	var forced_suit := _forced_discard_suit(player)
	var current_routes := _estimate_routes(hand_tiles, player)
	var current_shanten_info := shanten_engine.analyze_hand(hand_tiles, int(player.get("melds", []).size()), bool(rules_config.enable_qi_dui))
	var current_ting_tiles: Array = hu_checker.get_ting_tiles(hand_tiles, str(player.get("ding_que", "")), rules_config, int(player.get("melds", []).size()), player.get("melds", []))
	var options: Array = []
	var seen := {}
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		if forced_suit != "" and suit != forced_suit:
			continue
		var key := _tile_key(tile)
		if seen.has(key):
			continue
		seen[key] = true
		var remaining_hand := _remove_one(hand_tiles, tile)
		var shanten_info := shanten_engine.analyze_hand(remaining_hand, int(player.get("melds", []).size()), bool(rules_config.enable_qi_dui))
		var ting_tiles: Array = hu_checker.get_ting_tiles(remaining_hand, str(player.get("ding_que", "")), rules_config, int(player.get("melds", []).size()), player.get("melds", []))
		var is_ready: bool = not ting_tiles.is_empty()
		if is_ready:
			shanten_info["best"] = 0
			shanten_info["standard"] = min(0, int(shanten_info.get("standard", 0)))
			if shanten_info.has("qi_dui"):
				shanten_info["qi_dui"] = min(0, int(shanten_info.get("qi_dui", 0)))
		var ukeire_info := shanten_engine.calc_ukeire_after_discard(hand_tiles, tile, players, active_suits, int(player.get("melds", []).size()), bool(rules_config.enable_qi_dui))
		if is_ready:
			ukeire_info["shanten"] = 0
			ukeire_info["ukeire"] = ting_tiles.size()
			ukeire_info["improving_tiles"] = ting_tiles.duplicate(true)
			var ready_live_total := 0
			for ready_tile in ting_tiles:
				var visible_count := _count_visible_tile(players, remaining_hand, ready_tile)
				ready_live_total += maxi(0, 4 - visible_count)
			ukeire_info["live_ukeire"] = ready_live_total
		var quality := call_quality_engine.evaluate(ting_tiles, remaining_hand, players, int(player.get("seat", -1)))
		var risk_info: Dictionary = danger_engine.evaluate_tile(tile, int(player.get("seat", -1)), players, active_suits)
		if allow_cheat and risk_analyzer != null:
			var cheat_risk: Dictionary = risk_analyzer.analyze_discard_risk(tile, int(player.get("seat", -1)), players, hu_checker, rules_config, true)
			if int(cheat_risk.get("risk", 0)) > int(risk_info.get("risk", 0)):
				risk_info = cheat_risk
		var route_after := _estimate_routes(remaining_hand, player)
		var route_loss := _array_difference(current_routes, route_after)
		var fast_rank := _resolve_fast_rank(tile, hand_tiles, player, players, forced_suit)
		if is_ready:
			fast_rank = 0 if ting_tiles.size() >= 2 else 1
		var gen_locked: bool = _should_hard_keep_gen(tile, hand_tiles, forced_suit)
		var score_breakdown := _build_score_breakdown(tile, shanten_info, ukeire_info, quality, risk_info, route_after, route_loss, ai_config, players, player)
		var win_probability := _estimate_win_probability(shanten_info, ukeire_info, quality, risk_info, ai_config)
		var option := {
			"tile": tile.duplicate(true),
			"tile_name": str(tile.get("display_name", "?")),
			"tile_key": key,
			"shanten": int(shanten_info.get("best", 8)),
			"ukeire": int(ukeire_info.get("ukeire", 0)),
			"live_ukeire": int(ukeire_info.get("live_ukeire", 0)),
			"fast_ting_discard_rank": fast_rank,
			"risk": int(risk_info.get("risk", 0)),
			"risk_label": str(risk_info.get("label", "低危")),
			"risk_reasons": risk_info.get("reasons", []).duplicate(true),
			"routes_after": route_after.duplicate(true),
			"route_loss": route_loss.duplicate(true),
			"ting_tiles": ting_tiles.duplicate(true),
			"is_ready": is_ready,
			"wait_count": int(quality.get("wait_count", 0)),
			"wait_quality_score": int(quality.get("score", 0)),
			"must_appear_score": int(quality.get("must_appear_bonus", 0)),
			"self_draw_score": int(quality.get("self_draw_bonus", 0)),
			"probability_score": int(score_breakdown.get("probability_score", 0)),
			"tempo_score": int(score_breakdown.get("tempo_score", 0)),
			"fan_value_score": int(score_breakdown.get("fan_value_score", 0)),
			"safety_score": int(score_breakdown.get("safety_score", 0)),
			"global_plan_score": int(score_breakdown.get("global_plan_score", 0)),
			"score": int(score_breakdown.get("total_score", 0)),
			"win_probability": win_probability,
			"tenpai_probability": _estimate_tenpai_probability(shanten_info, ukeire_info),
			"self_draw_probability": _estimate_self_draw_probability(quality, risk_info),
			"discard_hu_probability": maxf(0.0, win_probability - _estimate_self_draw_probability(quality, risk_info)),
			"deal_in_probability": float(risk_info.get("risk", 0)) / 100.0,
			"expected_value": float(score_breakdown.get("total_score", 0)) / 100.0,
			"strategy_mode": _resolve_strategy_mode(current_shanten_info, current_ting_tiles, risk_info, players),
			"gen_locked": gen_locked,
			"reasons": _build_reasons(tile, shanten_info, ukeire_info, quality, risk_info, route_after, route_loss, forced_suit),
		}
		options.append(option)
	var unlocked_options: Array = []
	for option in options:
		if not bool(option.get("gen_locked", false)):
			unlocked_options.append(option)
	if not unlocked_options.is_empty():
		options = unlocked_options
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_ready: bool = bool(a.get("is_ready", false))
		var b_ready: bool = bool(b.get("is_ready", false))
		if a_ready != b_ready:
			return a_ready
		if int(a.get("shanten", 8)) != int(b.get("shanten", 8)):
			return int(a.get("shanten", 8)) < int(b.get("shanten", 8))
		if a_ready and b_ready:
			if int(a.get("wait_count", 0)) != int(b.get("wait_count", 0)):
				return int(a.get("wait_count", 0)) > int(b.get("wait_count", 0))
			if int(a.get("live_ukeire", 0)) != int(b.get("live_ukeire", 0)):
				return int(a.get("live_ukeire", 0)) > int(b.get("live_ukeire", 0))
			if int(a.get("risk", 0)) != int(b.get("risk", 0)):
				return int(a.get("risk", 0)) < int(b.get("risk", 0))
			if int(a.get("score", 0)) != int(b.get("score", 0)):
				return int(a.get("score", 0)) > int(b.get("score", 0))
		if int(a.get("fast_ting_discard_rank", 99)) != int(b.get("fast_ting_discard_rank", 99)):
			return int(a.get("fast_ting_discard_rank", 99)) < int(b.get("fast_ting_discard_rank", 99))
		if int(a.get("live_ukeire", 0)) != int(b.get("live_ukeire", 0)):
			return int(a.get("live_ukeire", 0)) > int(b.get("live_ukeire", 0))
		if int(a.get("wait_quality_score", 0)) != int(b.get("wait_quality_score", 0)):
			return int(a.get("wait_quality_score", 0)) > int(b.get("wait_quality_score", 0))
		if int(a.get("risk", 0)) != int(b.get("risk", 0)):
			return int(a.get("risk", 0)) < int(b.get("risk", 0))
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		return str(a.get("tile_name", "")) < str(b.get("tile_name", ""))
	)
	var danger_tiles := options.duplicate(true)
	danger_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("risk", 0)) > int(b.get("risk", 0))
	)
	var two_suit_state := _build_two_suit_state(hand_tiles)
	return {
		"forced_discard_suit": forced_suit,
		"recommended": options[0] if not options.is_empty() else {},
		"options": options,
		"danger_tiles": danger_tiles.slice(0, mini(3, danger_tiles.size())),
		"current_routes": current_routes,
		"strategy_profile": {
			"mode_label": _resolve_strategy_mode(current_shanten_info, current_ting_tiles, danger_tiles[0] if not danger_tiles.is_empty() else {}, players),
			"round_stage": _round_stage(players),
			"dingque_state": two_suit_state.duplicate(true),
			"reasons": ["定缺后优先追求最小向听、宽叫与活张", "当前牌形 %s" % str(two_suit_state.get("state_label", "定缺均衡"))],
		},
	}


func _build_two_suit_state(hand_tiles: Array) -> Dictionary:
	var tiao_count := 0
	var tong_count := 0
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		if suit == "tiao":
			tiao_count += 1
		elif suit == "tong":
			tong_count += 1
	var dominant_suit: String = "tiao" if tiao_count >= tong_count else "tong"
	var dominant_count: int = maxi(tiao_count, tong_count)
	var support_count: int = mini(tiao_count, tong_count)
	var spread: int = absi(tiao_count - tong_count)
	var state_label: String = "定缺均衡"
	if spread >= 4:
		state_label = "单门偏重"
	elif spread >= 2:
		state_label = "轻度偏门"
	return {
		"is_two_suit_table": true,
		"dominant_suit": dominant_suit,
		"dominant_count": dominant_count,
		"support_count": support_count,
		"spread": spread,
		"state_label": state_label,
	}


func choose_reaction(candidate: Dictionary, player: Dictionary, players: Array, discard_context: Dictionary, rules_config, hu_checker, ai_config = null) -> Dictionary:
	if bool(candidate.get("can_hu", false)):
		return {"action": "hu", "score": 100000, "reasons": ["可胡时直接胡牌"]}
	var active_suits: Array = tile_codec.resolve_active_suits(rules_config)
	var tile: Dictionary = discard_context.get("tile", {})
	var posterior_context := _build_reaction_posterior_context(player, players, tile, active_suits)
	var pass_score := _build_pass_reaction_score(player, players, rules_config, hu_checker, ai_config, posterior_context)
	var best := {"action": "pass", "score": pass_score, "reasons": ["保持当前最优成叫路径"]}
	if tile.is_empty():
		return best
	if bool(candidate.get("can_peng", false)):
		var peng_eval := _evaluate_peng(candidate, player, players, tile, rules_config, hu_checker, ai_config, posterior_context)
		if int(peng_eval.get("score", -999999)) > int(best.get("score", -999999)):
			best = peng_eval
	if bool(candidate.get("can_gang", false)):
		var gang_eval := _evaluate_gang(candidate, player, players, tile, rules_config, hu_checker, ai_config, posterior_context)
		if int(gang_eval.get("score", -999999)) > int(best.get("score", -999999)):
			best = gang_eval
	return best


func _evaluate_peng(candidate: Dictionary, player: Dictionary, players: Array, tile: Dictionary, rules_config, hu_checker, ai_config, posterior_context: Dictionary = {}) -> Dictionary:
	var simulated_hand: Array = player.get("hand_tiles", []).duplicate(true)
	var removed := 0
	for index in range(simulated_hand.size() - 1, -1, -1):
		var item: Dictionary = simulated_hand[index]
		if str(item.get("suit", "")) == str(tile.get("suit", "")) and int(item.get("rank", 0)) == int(tile.get("rank", 0)):
			simulated_hand.remove_at(index)
			removed += 1
			if removed >= 2:
				break
	var melds: Array = player.get("melds", []).duplicate(true)
	melds.append({"type": "peng", "tiles": [tile.duplicate(true), tile.duplicate(true), tile.duplicate(true)]})
	var shanten: int = shanten_engine.calc_best_shanten(simulated_hand, melds.size(), bool(rules_config.enable_qi_dui))
	var ting_tiles: Array = hu_checker.get_ting_tiles(simulated_hand, str(player.get("ding_que", "")), rules_config, melds.size(), melds)
	var score: int = -8 - shanten * 24 + ting_tiles.size() * 42
	var posterior_penalty: int = _reaction_posterior_penalty(posterior_context, shanten, ting_tiles.size(), false, ai_config)
	var reasons: Array[String] = ["碰后向听=%d" % shanten, "听口数=%d" % ting_tiles.size()]
	if ting_tiles.is_empty():
		score -= 120
		reasons.append("碰后无听口，直接降权")
	if shanten <= 0 and not ting_tiles.is_empty():
		score += 108
		reasons.append("碰后直接成叫")
	if shanten <= 1 and not ting_tiles.is_empty():
		score += 42
		reasons.append("碰后接近成叫")
	if posterior_penalty > 0:
		score -= posterior_penalty
		reasons.append("后验显示尾盘/对手听牌压力偏高，非必要不碰")
	return {
		"action": "peng",
		"score": score,
		"reasons": reasons,
	}


func _evaluate_gang(candidate: Dictionary, player: Dictionary, players: Array, tile: Dictionary, rules_config, hu_checker, ai_config, posterior_context: Dictionary = {}) -> Dictionary:
	var simulated_hand: Array = player.get("hand_tiles", []).duplicate(true)
	var removed := 0
	for index in range(simulated_hand.size() - 1, -1, -1):
		var item: Dictionary = simulated_hand[index]
		if str(item.get("suit", "")) == str(tile.get("suit", "")) and int(item.get("rank", 0)) == int(tile.get("rank", 0)):
			simulated_hand.remove_at(index)
			removed += 1
			if removed >= 3:
				break
	var melds: Array = player.get("melds", []).duplicate(true)
	melds.append({"type": "gang", "tiles": [tile.duplicate(true), tile.duplicate(true), tile.duplicate(true), tile.duplicate(true)]})
	var shanten: int = shanten_engine.calc_best_shanten(simulated_hand, melds.size(), false)
	var score: int = -26 - shanten * 24
	var reasons: Array[String] = ["杠后向听=%d" % shanten, "仅在不拖慢速度时考虑杠牌"]
	var posterior_penalty: int = _reaction_posterior_penalty(posterior_context, shanten, 0, true, ai_config)
	if shanten <= 0:
		score += 42
		reasons.append("杠后仍保持成叫")
	if _round_stage(players) <= 0:
		score += 10
		reasons.append("前巡尚可争收益")
	if posterior_penalty > 0:
		score -= posterior_penalty
		reasons.append("后验显示有人高概率已听/持张，明杠风险放大")
	return {
		"action": "gang",
		"score": score,
		"reasons": reasons,
	}


func _build_pass_reaction_score(player: Dictionary, players: Array, rules_config, hu_checker, ai_config = null, posterior_context: Dictionary = {}) -> int:
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	var ting_tiles: Array = hu_checker.get_ting_tiles(hand_tiles, str(player.get("ding_que", "")), rules_config, int(player.get("melds", []).size()), player.get("melds", []))
	var shanten: int = shanten_engine.calc_best_shanten(hand_tiles, int(player.get("melds", []).size()), bool(rules_config.enable_qi_dui))
	return 4 - shanten * 8 + ting_tiles.size() * 12 + _reaction_pass_posterior_bonus(posterior_context, shanten, ai_config)


func _build_reaction_posterior_context(player: Dictionary, players: Array, tile: Dictionary, active_suits: Array) -> Dictionary:
	if tile.is_empty():
		return {}
	var seat := int(player.get("seat", -1))
	var belief: Dictionary = belief_engine.build_snapshot(players, seat, active_suits)
	var max_ready := 0.0
	var top_holder := -1
	var top_hold := 0.0
	var tile_danger := danger_engine.evaluate_tile(tile, seat, players, active_suits)
	var suit := str(tile.get("suit", ""))
	var tile_rank := int(tile.get("rank", 0))
	for other in players:
		var other_seat := int(other.get("seat", -1))
		if other_seat == seat or bool(other.get("has_won", false)):
			continue
		max_ready = maxf(max_ready, float(belief.get("seat_pressure", {}).get(other_seat, 0.0)))
		var seat_demand: Dictionary = belief.get("seat_tile_demand", {}).get(other_seat, {})
		var suit_info: Dictionary = seat_demand.get(suit, {})
		var hold_like := float(suit_info.get("ranks", {}).get(tile_rank, 0.0)) * 0.55 + float(suit_info.get("heat", 0.0)) * 0.45
		if hold_like > top_hold:
			top_hold = hold_like
			top_holder = other_seat
	return {
		"max_ready_posterior": clampf(max_ready, 0.0, 1.0),
		"top_hold_posterior": clampf(top_hold, 0.0, 1.0),
		"top_holder_seat": top_holder,
		"tile_risk": int(tile_danger.get("risk", 0)),
		"round_stage": _round_stage(players),
	}


func _reaction_posterior_penalty(posterior_context: Dictionary, shanten: int, ting_count: int, is_gang: bool, ai_config = null) -> int:
	if posterior_context.is_empty():
		return 0
	var defense := 2 if ai_config == null else clampi(int(ai_config.defense_tendency), -3, 3)
	var tile_risk := int(posterior_context.get("tile_risk", 0))
	var max_ready := float(posterior_context.get("max_ready_posterior", 0.0))
	var top_hold := float(posterior_context.get("top_hold_posterior", 0.0))
	var round_stage := int(posterior_context.get("round_stage", 1))
	var penalty := 0
	if round_stage >= 2:
		penalty += 26 + defense * 4
	if max_ready >= 0.56:
		penalty += 34 + int(round((max_ready - 0.56) * 80.0))
	if top_hold >= 0.52:
		penalty += 22 + int(round((top_hold - 0.52) * 70.0))
	if tile_risk >= 56:
		penalty += 36 + int(round(float(tile_risk - 56) * 0.9))
	if is_gang:
		penalty += 22
	if shanten <= 0 and ting_count >= 2:
		penalty = int(round(float(penalty) * 0.35))
	elif shanten <= 0 and ting_count >= 1:
		penalty = int(round(float(penalty) * 0.55))
	elif shanten <= 1 and ting_count >= 1 and not is_gang:
		penalty = int(round(float(penalty) * 0.72))
	return maxi(penalty, 0)


func _reaction_pass_posterior_bonus(posterior_context: Dictionary, shanten: int, ai_config = null) -> int:
	if posterior_context.is_empty():
		return 0
	var defense := 2 if ai_config == null else clampi(int(ai_config.defense_tendency), -3, 3)
	var bonus := 0
	if int(posterior_context.get("round_stage", 1)) >= 2:
		bonus += 12 + defense * 4
	if float(posterior_context.get("max_ready_posterior", 0.0)) >= 0.56:
		bonus += 20
	if int(posterior_context.get("tile_risk", 0)) >= 56:
		bonus += 18
	if shanten <= 1:
		bonus += 12
	return bonus


func _build_shape_support(route_after: Array, route_loss: Array) -> int:
	var score := route_after.size() * 12 - route_loss.size() * 14
	if route_after.is_empty() and route_loss.is_empty():
		return -4
	return score


func _build_safety_support(risk_info: Dictionary) -> int:
	return 50 - int(risk_info.get("risk", 0))


func _build_pressure_support(risk_info: Dictionary) -> int:
	return -int(risk_info.get("risk", 0))


func _build_score_breakdown(tile: Dictionary, shanten_info: Dictionary, ukeire_info: Dictionary, quality: Dictionary, risk_info: Dictionary, route_after: Array, route_loss: Array, ai_config, players: Array, player: Dictionary) -> Dictionary:
	var fast_ting := 4 if ai_config == null else clampi(int(ai_config.fast_ting_priority), 0, 4)
	var self_draw := 4 if ai_config == null else clampi(int(ai_config.self_draw_priority), 0, 4)
	var read_weight := 3 if ai_config == null else clampi(int(ai_config.opponent_read_tendency), 0, 4)
	var big_hand := 0 if ai_config == null else clampi(int(ai_config.big_hand_tendency), 0, 4)
	var defense := 2 if ai_config == null else clampi(int(ai_config.defense_tendency), -3, 3)
	var attack := 2 if ai_config == null else clampi(int(ai_config.attack_tendency), -3, 3)
	var shanten := int(shanten_info.get("best", 8))
	var tempo_score := (8 - shanten) * (26 + fast_ting * 8) + int(ukeire_info.get("ukeire", 0)) * (10 + fast_ting * 2) + int(ukeire_info.get("live_ukeire", 0)) * (4 + fast_ting)
	var probability_score := int(round(_estimate_tenpai_probability(shanten_info, ukeire_info) * 120.0 + _estimate_self_draw_probability(quality, risk_info) * (80.0 + self_draw * 18.0)))
	var fan_value_score := route_after.size() * (10 + big_hand * 3) - route_loss.size() * (12 + fast_ting)
	var safety_score := -int(round(float(risk_info.get("risk", 0)) * (0.70 + float(read_weight) * 0.12 + float(defense) * 0.08)))
	var global_plan_score := int(quality.get("score", 0)) * (2 + self_draw) + _two_suit_balance_bonus(tile, player.get("hand_tiles", []), route_after) + attack * 12
	global_plan_score += _gen_preserve_bonus(tile, player.get("hand_tiles", []), route_after)
	var total_score := tempo_score + probability_score + fan_value_score + safety_score + global_plan_score
	return {
		"tempo_score": tempo_score,
		"probability_score": probability_score,
		"fan_value_score": fan_value_score,
		"safety_score": safety_score,
		"global_plan_score": global_plan_score,
		"total_score": total_score,
	}


func _estimate_tenpai_probability(shanten_info: Dictionary, ukeire_info: Dictionary) -> float:
	var shanten := int(shanten_info.get("best", 8))
	var live_ukeire := int(ukeire_info.get("live_ukeire", 0))
	if shanten <= 0:
		return 0.94
	if shanten == 1:
		return clampf(0.36 + float(live_ukeire) * 0.04, 0.18, 0.90)
	if shanten == 2:
		return clampf(0.16 + float(live_ukeire) * 0.02, 0.06, 0.72)
	return clampf(0.04 + float(live_ukeire) * 0.01, 0.02, 0.50)


func _estimate_self_draw_probability(quality: Dictionary, risk_info: Dictionary) -> float:
	var wait_count := int(quality.get("wait_count", 0))
	var live_count := int(quality.get("live_count", 0))
	var risk := int(risk_info.get("risk", 0))
	return clampf(0.06 + float(wait_count) * 0.05 + float(live_count) * 0.015 - float(risk) * 0.0012, 0.01, 0.82)


func _estimate_win_probability(shanten_info: Dictionary, ukeire_info: Dictionary, quality: Dictionary, risk_info: Dictionary, ai_config) -> float:
	var tenpai := _estimate_tenpai_probability(shanten_info, ukeire_info)
	var self_draw := _estimate_self_draw_probability(quality, risk_info)
	return clampf(tenpai * 0.58 + self_draw * 0.42, 0.01, 0.95)


func _build_reasons(tile: Dictionary, shanten_info: Dictionary, ukeire_info: Dictionary, quality: Dictionary, risk_info: Dictionary, route_after: Array, route_loss: Array, forced_suit: String) -> Array[String]:
	var reasons: Array[String] = []
	if forced_suit != "":
		reasons.append("当前存在强制清理门：%s" % _suit_name(forced_suit))
	reasons.append("打后向听 %d" % int(shanten_info.get("best", 8)))
	if int(ukeire_info.get("live_ukeire", 0)) > 0:
		reasons.append("活进张 %d" % int(ukeire_info.get("live_ukeire", 0)))
	if int(quality.get("wait_count", 0)) > 0:
		reasons.append("宽叫 %d 门" % int(quality.get("wait_count", 0)))
	if not route_after.is_empty():
		reasons.append("保留牌型 %s" % "/".join(route_after))
	if not route_loss.is_empty():
		reasons.append("会丢失 %s" % "/".join(route_loss))
	if int(risk_info.get("risk", 0)) >= 35:
		reasons.append("危险度 %s" % str(risk_info.get("label", "中危")))
	return reasons


func _resolve_strategy_mode(current_shanten_info: Dictionary, current_ting_tiles: Array, risk_info: Dictionary, players: Array) -> String:
	var shanten := int(current_shanten_info.get("best", 8))
	var stage := _round_stage(players)
	if stage >= 2 and int(risk_info.get("risk", 0)) >= 56:
		return "收守"
	if shanten <= 0 and current_ting_tiles.size() >= 2:
		return "宽叫压制"
	if shanten <= 1:
		return "快速成叫"
	return "缩门提速"


func _estimate_routes(hand_tiles: Array, player: Dictionary) -> Array:
	var routes: Array = []
	var melds: Array = player.get("melds", [])
	var suit_counts := {}
	var pair_count := 0
	var triple_like := 0
	var counts := {}
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
		var key := _tile_key(tile)
		counts[key] = int(counts.get(key, 0)) + 1
	for meld in melds:
		var tiles: Array = meld.get("tiles", [])
		if not tiles.is_empty():
			var meld_suit := str(tiles[0].get("suit", ""))
			suit_counts[meld_suit] = int(suit_counts.get(meld_suit, 0)) + tiles.size()
	for key in counts.keys():
		var count := int(counts[key])
		if count >= 2:
			pair_count += 1
		if count >= 3:
			triple_like += 1
	if counts.size() <= 7 and melds.is_empty() and pair_count >= 4:
		routes.append("七对")
	if triple_like + melds.size() >= 3:
		routes.append("对对胡")
	if suit_counts.size() == 1 and not suit_counts.is_empty():
		routes.append("清一色")
	return routes


func _forced_discard_suit(player: Dictionary) -> String:
	var ding_que := str(player.get("ding_que", ""))
	if ding_que == "":
		return ""
	for tile in player.get("hand_tiles", []):
		if str(tile.get("suit", "")) == ding_que:
			return ding_que
	return ""


func _resolve_fast_rank(tile: Dictionary, hand_tiles: Array, player: Dictionary, players: Array, forced_suit: String) -> int:
	var suit := str(tile.get("suit", ""))
	if forced_suit != "" and suit == forced_suit:
		return 0
	if _is_isolated_tile(tile, hand_tiles):
		return 1
	if _is_edge_shape(tile, hand_tiles):
		return 2
	if _is_weak_gap(tile, hand_tiles):
		return 3
	if int(tile.get("rank", 0)) in [1, 9]:
		return 4
	if int(tile.get("rank", 0)) in [2, 8]:
		return 5
	return 6


func _is_isolated_tile(tile: Dictionary, hand_tiles: Array) -> bool:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	for other in hand_tiles:
		if int(other.get("id", -1)) == int(tile.get("id", -1)):
			continue
		if str(other.get("suit", "")) != suit:
			continue
		var other_rank := int(other.get("rank", 0))
		if abs(other_rank - rank) <= 2:
			return false
	return true


func _is_edge_shape(tile: Dictionary, hand_tiles: Array) -> bool:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var has_neighbor := false
	for other in hand_tiles:
		if int(other.get("id", -1)) == int(tile.get("id", -1)):
			continue
		if str(other.get("suit", "")) != suit:
			continue
		var delta: int = abs(int(other.get("rank", 0)) - rank)
		if delta == 1:
			has_neighbor = true
	return has_neighbor and rank in [1, 2, 8, 9]


func _is_weak_gap(tile: Dictionary, hand_tiles: Array) -> bool:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var has_gap := false
	for other in hand_tiles:
		if int(other.get("id", -1)) == int(tile.get("id", -1)):
			continue
		if str(other.get("suit", "")) != suit:
			continue
		if abs(int(other.get("rank", 0)) - rank) == 2:
			has_gap = true
	return has_gap


func _should_hard_keep_gen(tile: Dictionary, hand_tiles: Array, forced_suit: String) -> bool:
	if forced_suit != "":
		return false
	var same_count := 0
	for item in hand_tiles:
		if str(item.get("suit", "")) == str(tile.get("suit", "")) and int(item.get("rank", 0)) == int(tile.get("rank", 0)):
			same_count += 1
	return same_count >= 4


func _gen_preserve_bonus(tile: Dictionary, hand_tiles: Array, route_after: Array) -> int:
	var same_count := 0
	for item in hand_tiles:
		if str(item.get("suit", "")) == str(tile.get("suit", "")) and int(item.get("rank", 0)) == int(tile.get("rank", 0)):
			same_count += 1
	if same_count >= 4:
		return -1200
	if same_count == 3 and not route_after.has("七对"):
		return -96
	return 0


func _two_suit_balance_bonus(tile: Dictionary, hand_tiles: Array, route_after: Array) -> int:
	var suit_counts := {}
	for item in hand_tiles:
		var suit := str(item.get("suit", ""))
		suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	var non_zero: Array = []
	for suit in suit_counts.keys():
		if int(suit_counts[suit]) > 0:
			non_zero.append(int(suit_counts[suit]))
	if non_zero.size() < 2:
		var single_route_bonus: int = 10 if route_after.has("清一色") else -12
		return single_route_bonus
	non_zero.sort()
	var gap: int = abs(int(non_zero[0]) - int(non_zero[1]))
	var balance_bonus: int = 18 if gap <= 2 else (6 if gap <= 4 else -8)
	return balance_bonus


func _remove_one(hand_tiles: Array, tile: Dictionary) -> Array:
	var result := hand_tiles.duplicate(true)
	for index in range(result.size()):
		var item: Dictionary = result[index]
		if int(item.get("id", -1)) != -1 and int(item.get("id", -1)) == int(tile.get("id", -1)):
			result.remove_at(index)
			return result
		if str(item.get("suit", "")) == str(tile.get("suit", "")) and int(item.get("rank", 0)) == int(tile.get("rank", 0)):
			result.remove_at(index)
			return result
	return result


func _array_difference(source: Array, target: Array) -> Array:
	var diff: Array = []
	for item in source:
		if not target.has(item):
			diff.append(item)
	return diff


func _round_stage(players: Array) -> int:
	var max_discards := 0
	for player in players:
		max_discards = maxi(max_discards, int(player.get("discards", []).size()))
	if max_discards <= 7:
		return 0
	if max_discards <= 18:
		return 1
	return 2


func _tile_key(tile: Dictionary) -> String:
	return "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


func _count_visible_tile(players: Array, hand_tiles: Array, tile: Dictionary) -> int:
	var key := _tile_key(tile)
	var count := 0
	for hand_tile in hand_tiles:
		if _tile_key(hand_tile) == key:
			count += 1
	for player in players:
		for discard_tile in player.get("discards", []):
			if _tile_key(discard_tile) == key:
				count += 1
		for meld in player.get("melds", []):
			for meld_tile in meld.get("tiles", []):
				if _tile_key(meld_tile) == key:
					count += 1
	return count


func _suit_name(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return suit
