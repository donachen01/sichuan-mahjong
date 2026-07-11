extends RefCounted

class_name SichuanDangerEngine

const BeliefEngineScript := preload("res://scripts/ai/sichuan_belief_engine.gd")

var belief_engine = BeliefEngineScript.new()


func evaluate_tile(tile: Dictionary, discarder_seat: int, players: Array, active_suits: Array) -> Dictionary:
	var belief: Dictionary = belief_engine.build_snapshot(players, discarder_seat, active_suits)
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var max_risk := 0.06
	var reasons: Array[String] = []
	for player in players:
		var seat := int(player.get("seat", -1))
		if seat == discarder_seat or bool(player.get("has_won", false)):
			continue
		var pressure := float(belief.get("seat_pressure", {}).get(seat, 0.0))
		var seat_demand: Dictionary = belief.get("seat_tile_demand", {}).get(seat, {})
		var suit_info: Dictionary = seat_demand.get(suit, {})
		var suit_heat := float(suit_info.get("heat", 0.0))
		var rank_heat := float(suit_info.get("ranks", {}).get(rank, 0.25))
		var tile_risk := pressure * (0.42 + suit_heat * 0.32 + rank_heat * 0.26)
		if _is_exact_safe(player, tile):
			tile_risk *= 0.22
			reasons.append("%s现物偏安全" % _seat_name(player))
		elif _is_suit_abandoned(player, suit):
			tile_risk *= 0.54
			reasons.append("%s该门已弃多张" % _seat_name(player))
		if bool(player.get("bao_jiao", false)):
			tile_risk *= 1.22
			reasons.append("%s已报叫" % _seat_name(player))
		max_risk = maxf(max_risk, tile_risk)
	var risk_int := clampi(int(round(max_risk * 100.0)), 0, 100)
	return {
		"risk": risk_int,
		"label": _label(risk_int),
		"reasons": reasons,
	}


func _is_exact_safe(player: Dictionary, tile: Dictionary) -> bool:
	for discard in player.get("discards", []):
		if str(discard.get("suit", "")) == str(tile.get("suit", "")) and int(discard.get("rank", 0)) == int(tile.get("rank", 0)):
			return true
	return false


func _is_suit_abandoned(player: Dictionary, suit: String) -> bool:
	var count := 0
	for discard in player.get("discards", []):
		if str(discard.get("suit", "")) == suit:
			count += 1
	return count >= 3


func _seat_name(player: Dictionary) -> String:
	var nickname := str(player.get("nickname", ""))
	return nickname if not nickname.is_empty() else "座位%d" % int(player.get("seat", -1))


func _label(risk: int) -> String:
	if risk >= 78:
		return "极危险"
	if risk >= 56:
		return "高危"
	if risk >= 34:
		return "中危"
	return "低危"
