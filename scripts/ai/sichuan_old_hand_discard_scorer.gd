extends RefCounted

class_name SichuanOldHandDiscardScorer


func score_analysis(analysis: Dictionary, actual_tile_type: int, seat: int = -1, round_no: int = 0, step: int = 0) -> Dictionary:
	var options: Array = _candidate_options_for_current_rule_context(analysis)
	if options.is_empty() or actual_tile_type < 0:
		return {}
	var sorted_options := options.duplicate(true)
	sorted_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var judge_a := _independent_judge_score(a)
		var judge_b := _independent_judge_score(b)
		if judge_a != judge_b:
			return judge_a > judge_b
		return int(a.get("csharp_tile_type", -1)) < int(b.get("csharp_tile_type", -1))
	)
	var actual := _find_candidate(sorted_options, actual_tile_type)
	if actual.is_empty():
		return {}
	var best: Dictionary = sorted_options[0]
	var actual_score := _independent_judge_score(actual)
	var best_score := _independent_judge_score(best)
	var score_gap := best_score - actual_score
	var actual_rank := _candidate_rank(sorted_options, actual_tile_type)
	var actual_shanten := int(actual.get("shanten", 8))
	var best_shanten := int(best.get("shanten", actual_shanten))
	var actual_live := int(actual.get("live_ukeire", actual.get("csharp_live_ukeire", 0)))
	var best_live := int(best.get("live_ukeire", best.get("csharp_live_ukeire", actual_live)))
	var actual_wait := int(actual.get("wait_count", actual.get("csharp_wait_count", 0)))
	var best_wait := int(best.get("wait_count", best.get("csharp_wait_count", actual_wait)))
	var actual_risk := int(actual.get("risk", 0))
	var best_risk := int(best.get("risk", actual_risk))
	var rating := 100
	rating -= mini(45, max(0, score_gap) / 160)
	rating -= mini(18, max(0, actual_shanten - best_shanten) * 12)
	rating -= mini(14, max(0, best_live - actual_live) / 2)
	rating -= mini(10, max(0, best_wait - actual_wait) * 4)
	rating -= mini(18, max(0, actual_risk - best_risk) / 3)
	rating -= mini(10, max(0, actual_rank - 1) * 3)
	rating = clampi(rating, 0, 100)
	return {
		"round_no": round_no,
		"step": step,
		"seat": seat,
		"actual_tile_type": actual_tile_type,
		"actual_tile_name": str(actual.get("tile_name", _tile_type_name(actual_tile_type))),
		"best_tile_type": int(best.get("csharp_tile_type", -1)),
		"best_tile_name": str(best.get("tile_name", _tile_type_name(int(best.get("csharp_tile_type", -1))))),
		"rank": actual_rank,
		"rating": rating,
		"score_gap_to_best": score_gap,
		"actual_score": actual_score,
		"best_score": best_score,
		"score_source": "independent_rule_judge_v2",
		"actual_shanten": actual_shanten,
		"best_shanten": best_shanten,
		"actual_live_ukeire": actual_live,
		"best_live_ukeire": best_live,
		"actual_wait_count": actual_wait,
		"best_wait_count": best_wait,
		"actual_risk": actual_risk,
		"best_risk": best_risk,
		"backend_mode": str(analysis.get("backend_mode", "")),
		"strategy_mode": str(actual.get("strategy_mode", actual.get("csharp_strategy_mode", ""))),
		"reason": _build_reason(actual, best, actual_rank, score_gap),
		"judge_reasons": _independent_judge_reasons(actual),
	}


func _independent_judge_score(option: Dictionary) -> int:
	var shanten := int(option.get("shanten", option.get("csharp_shanten", 8)))
	var live := int(option.get("live_ukeire", option.get("csharp_live_ukeire", 0)))
	var wait_count := int(option.get("wait_count", option.get("csharp_wait_count", 0)))
	var risk := int(option.get("risk", option.get("csharp_risk", 50)))
	var expected_net := float(option.get("expected_net_score", option.get("csharp_expected_net_score", 0.0)))
	var expected_deal_in_loss := float(option.get("expected_deal_in_loss", option.get("csharp_expected_deal_in_loss", 0.0)))
	var good_shape := int(option.get("good_shape_count", option.get("csharp_good_shape_count", 0)))
	var bad_shape := int(option.get("bad_shape_count", option.get("csharp_bad_shape_count", 0)))
	var wait_shape_score := float(option.get("wait_shape_score", option.get("csharp_wait_shape_score", 0.0)))
	var set_preservation_score := float(option.get("set_preservation_score", option.get("csharp_set_preservation_score", 0.0)))
	var route_plan_score := int(option.get("route_plan_score", option.get("csharp_route_plan_score", 0)))
	var route_loss: Array = option.get("route_loss", option.get("csharp_route_loss", []))
	var score := 12000
	score -= maxi(0, shanten) * 2600
	if shanten <= 0:
		score += 3200 + wait_count * 520 + mini(18, live) * 75
	elif shanten == 1:
		score += mini(28, live) * 105
	else:
		score += mini(36, live) * 45
	score += int(round(expected_net * 180.0))
	score -= int(round(expected_deal_in_loss * 240.0))
	score += good_shape * 55
	score -= bad_shape * 45
	score += int(round(wait_shape_score * 34.0))
	score += int(round(set_preservation_score * 70.0))
	score += clampi(route_plan_score, -1200, 1200) / 3
	score -= route_loss.size() * 220
	if bool(option.get("breaks_triplet", option.get("csharp_breaks_triplet", false))):
		score -= 900
	if bool(option.get("breaks_pair", option.get("csharp_breaks_pair", false))) and shanten > 0:
		score -= 260
	if shanten <= 0 and live <= 0:
		# 查叫仍有价值，但死叫不能被当成普通活叫重复奖励。
		score -= 520
	var exact_deal_in := bool(option.get("exact_deal_in", option.get("csharp_exact_deal_in", false)))
	var feeds_human_hu := bool(option.get("feeds_human_hu", option.get("csharp_feeds_human_hu", false)))
	var feeds_human_gang := bool(option.get("feeds_human_gang", option.get("csharp_feeds_human_gang", false)))
	var feeds_human_peng := bool(option.get("feeds_human_peng", option.get("csharp_feeds_human_peng", false)))
	var human_peng_threat := int(option.get("human_peng_threat", option.get("csharp_human_peng_threat", 0)))
	if exact_deal_in or feeds_human_hu:
		score -= 50000
	elif feeds_human_gang:
		score -= 14000
	elif feeds_human_peng:
		score -= human_peng_threat * 900
	var risk_weight := 12
	if shanten <= 0:
		risk_weight = 20
	elif shanten >= 2:
		risk_weight = 8
	score -= risk * risk_weight
	# 老手不会把“成叫”当成冲极危险牌的通行证；高危区使用非线性损失。
	# 这项独立于线上总分，用于识别点根、清一色目标门和高听牌后验下的冒进。
	if risk >= 78:
		score -= (risk - 77) * (190 if shanten <= 0 else 120)
	return score


func _independent_judge_reasons(option: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var shanten := int(option.get("shanten", option.get("csharp_shanten", 8)))
	var live := int(option.get("live_ukeire", option.get("csharp_live_ukeire", 0)))
	var wait_count := int(option.get("wait_count", option.get("csharp_wait_count", 0)))
	var risk := int(option.get("risk", option.get("csharp_risk", 50)))
	result.append("向听%d" % shanten)
	result.append("活张%d" % live)
	if shanten <= 0:
		result.append("听口%d门" % wait_count)
	result.append("风险%d" % risk)
	if bool(option.get("breaks_triplet", option.get("csharp_breaks_triplet", false))):
		result.append("拆刻子")
	if bool(option.get("breaks_pair", option.get("csharp_breaks_pair", false))):
		result.append("拆对子")
	var route_plan_score := int(option.get("route_plan_score", option.get("csharp_route_plan_score", 0)))
	if route_plan_score >= 600:
		result.append("符合本局主路线")
	elif route_plan_score <= -600:
		result.append("偏离本局主路线")
	var wait_shape_score := float(option.get("wait_shape_score", option.get("csharp_wait_shape_score", 0.0)))
	if wait_shape_score >= 8.0:
		result.append("听形较宽")
	elif shanten <= 0 and wait_shape_score <= -4.0:
		result.append("听形偏窄")
	if bool(option.get("exact_deal_in", option.get("csharp_exact_deal_in", false))):
		result.append("透视点炮")
	elif bool(option.get("feeds_human_gang", option.get("csharp_feeds_human_gang", false))):
		result.append("喂明杠")
	elif bool(option.get("feeds_human_peng", option.get("csharp_feeds_human_peng", false))):
		result.append("喂碰威胁%d" % int(option.get("human_peng_threat", option.get("csharp_human_peng_threat", 0))))
	return result


func _candidate_options_for_current_rule_context(analysis: Dictionary) -> Array:
	var options: Array = analysis.get("options", [])
	var forced_suit := str(analysis.get("forced_discard_suit", ""))
	if forced_suit == "" or not bool(analysis.get("forced_ding_que_cleanup", false)):
		return options
	var filtered: Array = []
	for option in options:
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = option
		var tile: Dictionary = item.get("tile", {})
		if str(tile.get("suit", "")) == forced_suit:
			filtered.append(item)
	return filtered if not filtered.is_empty() else options


func summarize(records: Array) -> Dictionary:
	var count := records.size()
	if count <= 0:
		return {
			"discard_count": 0,
			"average_rating": 0.0,
			"average_rank": 0.0,
			"average_score_gap": 0.0,
			"top1_rate": 0.0,
			"dangerous_discard_rate": 0.0,
		}
	var rating_total := 0
	var rank_total := 0
	var gap_total := 0
	var top1 := 0
	var dangerous := 0
	var severe_miss := 0
	for item in records:
		var record: Dictionary = item
		rating_total += int(record.get("rating", 0))
		rank_total += int(record.get("rank", 0))
		gap_total += int(record.get("score_gap_to_best", 0))
		if int(record.get("rank", 0)) == 1:
			top1 += 1
		if int(record.get("actual_risk", 0)) >= 70:
			dangerous += 1
		if int(record.get("rating", 0)) < 72 or int(record.get("score_gap_to_best", 0)) >= 2400:
			severe_miss += 1
	return {
		"discard_count": count,
		"average_rating": float(rating_total) / float(count),
		"average_rank": float(rank_total) / float(count),
		"average_score_gap": float(gap_total) / float(count),
		"top1_rate": float(top1) / float(count),
		"dangerous_discard_rate": float(dangerous) / float(count),
		"severe_miss_rate": float(severe_miss) / float(count),
		"severe_miss_count": severe_miss,
	}


func _find_candidate(options: Array, tile_type: int) -> Dictionary:
	for option in options:
		var item: Dictionary = option
		if int(item.get("csharp_tile_type", -1)) == tile_type:
			return item
	return {}


func _candidate_rank(options: Array, tile_type: int) -> int:
	for index in range(options.size()):
		var item: Dictionary = options[index]
		if int(item.get("csharp_tile_type", -1)) == tile_type:
			return index + 1
	return options.size() + 1


func _build_reason(actual: Dictionary, best: Dictionary, rank: int, score_gap: int) -> String:
	if rank == 1:
		return "命中最高分候选"
	if int(actual.get("risk", 0)) > int(best.get("risk", 0)) + 18:
		return "比最佳候选更危险"
	if int(actual.get("shanten", 8)) > int(best.get("shanten", 8)):
		return "比最佳候选慢一档"
	if int(actual.get("live_ukeire", 0)) + 3 < int(best.get("live_ukeire", 0)):
		return "活进张明显少于最佳候选"
	return "候选排名第%d，分差%d" % [rank, score_gap]


func _tile_type_name(tile_type: int) -> String:
	if tile_type < 0:
		return "?"
	var suit := "条"
	if tile_type >= 18:
		suit = "万"
	elif tile_type >= 9:
		suit = "筒"
	return "%d%s" % [tile_type % 9 + 1, suit]
