extends RefCounted

class_name OpponentModel


func analyze_opponent(opponent: Dictionary) -> Dictionary:
	var melds: Array = opponent.get("melds", [])
	var discards: Array = opponent.get("discards", [])
	var seat := int(opponent.get("seat", -1))
	var discards_count := discards.size()
	var meld_count := melds.size()
	var dangerous_suit := _resolve_dangerous_suit(opponent)
	var flush_probability := _estimate_flush_probability(opponent, dangerous_suit)
	var pung_probability := _estimate_pung_probability(opponent)
	var bao_jiao := bool(opponent.get("bao_jiao", false))
	var ready_pressure := _estimate_ready_pressure(meld_count, discards_count, flush_probability, pung_probability, bao_jiao)
	var stage := _round_stage(discards_count)
	return {
		"seat": seat,
		"meld_count": meld_count,
		"discards_count": discards_count,
		"round_stage": stage,
		"round_stage_label": _round_stage_label(stage),
		"dangerous_suit": dangerous_suit,
		"dangerous_suit_label": _suit_name(dangerous_suit),
		"flush_probability": flush_probability,
		"pung_probability": pung_probability,
		"bao_jiao": bao_jiao,
		"ready_pressure": ready_pressure,
		"threat_score": _build_threat_score(meld_count, discards_count, flush_probability, pung_probability, ready_pressure, bao_jiao),
		"reasons": _build_reasons(opponent, dangerous_suit, flush_probability, pung_probability, ready_pressure, stage, bao_jiao),
	}


func _resolve_dangerous_suit(opponent: Dictionary) -> String:
	var meld_focus := _dominant_meld_suit(opponent)
	if meld_focus != "":
		return meld_focus
	var discard_counts := {"tiao": 0, "tong": 0, "wan": 0}
	for discard in opponent.get("discards", []):
		var suit := str(discard.get("suit", ""))
		if discard_counts.has(suit):
			discard_counts[suit] = int(discard_counts.get(suit, 0)) + 1
	var least_discarded := ""
	var least_count := 999
	for suit in discard_counts.keys():
		var count := int(discard_counts[suit])
		if count < least_count:
			least_count = count
			least_discarded = suit
	return least_discarded


func _estimate_flush_probability(opponent: Dictionary, dangerous_suit: String) -> int:
	if dangerous_suit == "":
		return 0
	var meld_tiles := 0
	var suit_tiles := 0
	for meld in opponent.get("melds", []):
		for tile in meld.get("tiles", []):
			meld_tiles += 1
			if str(tile.get("suit", "")) == dangerous_suit:
				suit_tiles += 1
	var ratio := 0.0 if meld_tiles == 0 else float(suit_tiles) / float(meld_tiles)
	var score := int(round(ratio * 100.0))
	if meld_tiles >= 6 and ratio >= 0.75:
		score += 18
	return clampi(score, 0, 100)


func _estimate_pung_probability(opponent: Dictionary) -> int:
	var score := 0
	for meld in opponent.get("melds", []):
		var meld_type := str(meld.get("type", ""))
		if meld_type == "peng":
			score += 26
		elif meld_type == "gang":
			score += 34
	var discards_count: int = opponent.get("discards", []).size()
	if discards_count >= 8 and score > 0:
		score += 10
	return clampi(score, 0, 100)


func _estimate_ready_pressure(meld_count: int, discards_count: int, flush_probability: int, pung_probability: int, bao_jiao: bool) -> int:
	var pressure := meld_count * 18
	if discards_count >= 10:
		pressure += 18
	elif discards_count >= 7:
		pressure += 10
	pressure += int(round(float(maxi(flush_probability, pung_probability)) * 0.22))
	if bao_jiao:
		pressure += 36
	return clampi(pressure, 0, 100)


func _build_threat_score(meld_count: int, discards_count: int, flush_probability: int, pung_probability: int, ready_pressure: int, bao_jiao: bool) -> int:
	var score := meld_count * 16
	if discards_count >= 10:
		score += 12
	elif discards_count >= 7:
		score += 7
	score += int(round(float(flush_probability) * 0.16))
	score += int(round(float(pung_probability) * 0.14))
	score += int(round(float(ready_pressure) * 0.22))
	if bao_jiao:
		score += 26
	return clampi(score, 0, 100)


func _build_reasons(opponent: Dictionary, dangerous_suit: String, flush_probability: int, pung_probability: int, ready_pressure: int, stage: int, bao_jiao: bool) -> Array[String]:
	var reasons: Array[String] = []
	var meld_count: int = opponent.get("melds", []).size()
	if bao_jiao:
		reasons.append("对手已报叫，进入高压防守区")
	elif meld_count >= 2:
		reasons.append("副露较多，出牌速度快")
	elif meld_count == 1:
		reasons.append("已有副露，需防其提速")
	if dangerous_suit != "":
		reasons.append("危险花色偏向%s" % _suit_name(dangerous_suit))
	if flush_probability >= 65:
		reasons.append("疑似在做%s清" % _suit_name(dangerous_suit))
	if pung_probability >= 55:
		reasons.append("疑似对对胡/杠子路线")
	if ready_pressure >= 55:
		reasons.append("听牌压力较高")
	if stage >= 2:
		reasons.append("已进入后巡，应提高防守权重")
	return reasons


func _round_stage(discards_count: int) -> int:
	if discards_count <= 4:
		return 0
	if discards_count <= 9:
		return 1
	return 2


func _round_stage_label(stage: int) -> String:
	match stage:
		0:
			return "前巡"
		1:
			return "中巡"
		2:
			return "后巡"
		_:
			return "中巡"


func _dominant_meld_suit(opponent: Dictionary) -> String:
	var counts := {}
	for meld in opponent.get("melds", []):
		for tile in meld.get("tiles", []):
			var suit: String = str(tile.get("suit", ""))
			if suit == "":
				continue
			counts[suit] = int(counts.get(suit, 0)) + 1
	var best_suit := ""
	var best_count := 0
	for suit in counts.keys():
		if int(counts[suit]) > best_count:
			best_count = int(counts[suit])
			best_suit = str(suit)
	return best_suit


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
