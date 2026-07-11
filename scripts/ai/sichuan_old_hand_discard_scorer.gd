extends RefCounted

class_name SichuanOldHandDiscardScorer


func score_analysis(analysis: Dictionary, actual_tile_type: int, seat: int = -1, round_no: int = 0, step: int = 0) -> Dictionary:
	var options: Array = _candidate_options_for_current_rule_context(analysis)
	if options.is_empty() or actual_tile_type < 0:
		return {}
	var sorted_options := options.duplicate(true)
	sorted_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		if int(a.get("shanten", 8)) != int(b.get("shanten", 8)):
			return int(a.get("shanten", 8)) < int(b.get("shanten", 8))
		if int(a.get("risk", 0)) != int(b.get("risk", 0)):
			return int(a.get("risk", 0)) < int(b.get("risk", 0))
		return int(a.get("csharp_tile_type", -1)) < int(b.get("csharp_tile_type", -1))
	)
	var actual := _find_candidate(sorted_options, actual_tile_type)
	if actual.is_empty():
		return {}
	var best: Dictionary = sorted_options[0]
	var actual_score := int(actual.get("score", 0))
	var best_score := int(best.get("score", actual_score))
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
	}


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
