extends RefCounted

class_name RiskAnalyzer

const OpponentModelScript := preload("res://scripts/core/opponent_model.gd")

var opponent_model = OpponentModelScript.new()


func analyze_discard_risk(tile: Dictionary, discarder_seat: int, players: Array, hu_checker, rules_config, allow_cheat: bool = false) -> Dictionary:
	var overall_risk := 0
	var reasons: Array[String] = []
	var opponent_items: Array = []
	var dominant_threat_seat := -1
	var dominant_threat_score := -1

	for player in players:
		var seat: int = int(player.get("seat", -1))
		if seat == discarder_seat or bool(player.get("has_won", false)):
			continue
		var profile: Dictionary = opponent_model.analyze_opponent(player)
		var item := _analyze_against_opponent(tile, player, profile, hu_checker, rules_config, allow_cheat)
		opponent_items.append(item)
		overall_risk = maxi(overall_risk, int(item.get("risk", 0)))
		if int(profile.get("threat_score", 0)) > dominant_threat_score:
			dominant_threat_score = int(profile.get("threat_score", 0))
			dominant_threat_seat = seat
		for reason in item.get("reasons", []):
			reasons.append("%s: %s" % [_seat_name(player), str(reason)])
		if bool(item.get("absolute_danger", false)):
			overall_risk = 100
		if bool(item.get("absolute_safe", false)) and reasons.is_empty():
			reasons.append("%s: 该张对其现物安全" % _seat_name(player))

	return {
		"risk": overall_risk,
		"label": _risk_label(overall_risk),
		"reasons": reasons,
		"items": opponent_items,
		"dominant_threat_seat": dominant_threat_seat,
		"dominant_threat_score": dominant_threat_score,
	}


func _seat_name(player: Dictionary) -> String:
	var nickname := str(player.get("nickname", ""))
	if not nickname.is_empty():
		return nickname
	return "座位%d" % int(player.get("seat", -1))


func _analyze_against_opponent(tile: Dictionary, opponent: Dictionary, profile: Dictionary, hu_checker, rules_config, allow_cheat: bool) -> Dictionary:
	var seat: int = int(opponent.get("seat", -1))
	var risk := 8
	var reasons: Array[String] = []
	var exact_safe := _has_exact_discard(opponent, tile)
	var ding_que: String = str(opponent.get("ding_que", ""))
	var tile_suit: String = str(tile.get("suit", ""))

	if ding_que != "" and ding_que == tile_suit:
		reasons.append("其当前弱势花色为%s，理论上较安全" % _suit_name(ding_que))
		return {
			"seat": seat,
			"risk": 5 if not exact_safe else 0,
			"absolute_safe": exact_safe,
			"absolute_danger": false,
			"reasons": reasons,
		}

	if exact_safe:
		reasons.append("该张已被其弃过，属现物")
		return {
			"seat": seat,
			"risk": 0,
			"absolute_safe": true,
			"absolute_danger": false,
			"reasons": reasons,
		}

	var melds: Array = opponent.get("melds", [])
	var discards: Array = opponent.get("discards", [])
	if melds.size() >= 2:
		risk += 18
		reasons.append("副露较多，成型速度快")
	elif melds.size() == 1:
		risk += 8
		reasons.append("已有副露，需防加速听牌")

	if discards.size() >= 11:
		risk += 14
		reasons.append("已进入后巡，放铳风险上升")
	elif discards.size() >= 7:
		risk += 8
		reasons.append("中后盘阶段，应提高防守权重")

	var dangerous_suit: String = str(profile.get("dangerous_suit", ""))
	if bool(profile.get("bao_jiao", false)):
		risk += 24
		reasons.append("对手已报叫，此时放铳风险显著上升")
		for ting_tile in opponent.get("bao_jiao_ting_tiles", []):
			if str(ting_tile.get("suit", "")) == tile_suit and int(ting_tile.get("rank", 0)) == int(tile.get("rank", 0)):
				risk += 38
				reasons.append("该张命中其报叫听口，极高危")
				break
	if dangerous_suit != "" and dangerous_suit == tile_suit:
		risk += 18
		reasons.append("其副露集中在%s，推测此门更危险" % _suit_name(tile_suit))

	var same_suit_discards: int = _count_discards_by_suit(opponent, tile_suit)
	if same_suit_discards <= 1 and discards.size() >= 8:
		risk += 10
		reasons.append("其很少打%s，保留概率更高" % _suit_name(tile_suit))

	var flush_probability := int(profile.get("flush_probability", 0))
	if dangerous_suit == tile_suit and flush_probability >= 65:
		risk += 18
		reasons.append("对手疑似做清一色，该门需高度警惕")

	var pung_probability := int(profile.get("pung_probability", 0))
	if pung_probability >= 55 and int(tile.get("rank", 0)) in [2, 5, 8]:
		risk += 8
		reasons.append("对手疑似对对胡/将对路线，相关牌更危险")

	var ready_pressure := int(profile.get("ready_pressure", 0))
	if ready_pressure >= 60:
		risk += 12
		reasons.append("其听牌压力高，应优先防守")
	elif ready_pressure >= 40:
		risk += 6
		reasons.append("其已具较强听牌压力")

	var edge_rank: int = int(tile.get("rank", 0))
	if edge_rank in [3, 4, 5, 6, 7]:
		risk += 6
		reasons.append("中张普遍更容易放进张")

	if allow_cheat and hu_checker.can_hu_on_discard(opponent, tile, rules_config):
		risk = 100
		reasons.append("作弊级透视判断：此张会直接点炮")

	return {
		"seat": seat,
		"risk": clampi(risk, 0, 100),
		"absolute_safe": false,
		"absolute_danger": allow_cheat and risk >= 100,
		"reasons": reasons,
		"profile": profile.duplicate(true),
	}


func _has_exact_discard(opponent: Dictionary, tile: Dictionary) -> bool:
	for discard in opponent.get("discards", []):
		if str(discard.get("suit", "")) == str(tile.get("suit", "")) and int(discard.get("rank", 0)) == int(tile.get("rank", 0)):
			return true
	return false
func _count_discards_by_suit(opponent: Dictionary, suit: String) -> int:
	var count := 0
	for discard in opponent.get("discards", []):
		if str(discard.get("suit", "")) == suit:
			count += 1
	return count


func _risk_label(risk: int) -> String:
	if risk >= 85:
		return "极危险"
	if risk >= 60:
		return "高危"
	if risk >= 35:
		return "中危"
	return "低危"


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
