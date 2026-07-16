extends RefCounted

class_name SichuanBeliefEngine


func build_snapshot(players: Array, self_seat: int, active_suits: Array) -> Dictionary:
	var seat_pressure: Dictionary = {}
	var seat_tile_demand: Dictionary = {}
	var suit_heat: Dictionary = {}
	for suit in active_suits:
		suit_heat[suit] = 0.0
	for player in players:
		var seat := int(player.get("seat", -1))
		if seat == self_seat or bool(player.get("has_won", false)):
			continue
		var pressure := _estimate_ready_pressure(player)
		seat_pressure[seat] = pressure
		seat_tile_demand[seat] = _build_tile_demand(player, active_suits)
		for suit in active_suits:
			suit_heat[suit] = float(suit_heat.get(suit, 0.0)) + float(seat_tile_demand[seat].get(suit, {}).get("heat", 0.0))
	return {
		"seat_pressure": seat_pressure,
		"seat_tile_demand": seat_tile_demand,
		"suit_heat": suit_heat,
	}


func _estimate_ready_pressure(player: Dictionary) -> float:
	var meld_count := int(player.get("melds", []).size())
	var discard_count := int(player.get("discards", []).size())
	var pressure := 0.16 + float(meld_count) * 0.12
	if discard_count >= 10:
		pressure += 0.22
	elif discard_count >= 6:
		pressure += 0.12
	return clampf(pressure, 0.05, 0.95)


func _build_tile_demand(player: Dictionary, active_suits: Array) -> Dictionary:
	var demand := {}
	var discard_counts := {}
	for suit in active_suits:
		discard_counts[suit] = 0
	for tile in player.get("discards", []):
		var suit := str(tile.get("suit", ""))
		if discard_counts.has(suit):
			discard_counts[suit] = int(discard_counts.get(suit, 0)) + 1
	for suit in active_suits:
		var heat := maxf(0.0, 1.0 - float(discard_counts.get(suit, 0)) / 6.0)
		demand[suit] = {
			"heat": clampf(heat, 0.0, 1.0),
			"ranks": _rank_demand(player, suit),
		}
	return demand


func _rank_demand(player: Dictionary, suit: String) -> Dictionary:
	var ranks := {}
	for rank in range(1, 10):
		ranks[rank] = 0.55 if rank >= 3 and rank <= 7 else 0.38
	for tile in player.get("discards", []):
		if str(tile.get("suit", "")) != suit:
			continue
		var rank := int(tile.get("rank", 0))
		ranks[rank] = maxf(0.08, float(ranks.get(rank, 0.2)) - 0.22)
	for meld in player.get("melds", []):
		for meld_tile in meld.get("tiles", []):
			if str(meld_tile.get("suit", "")) != suit:
				continue
			var rank := int(meld_tile.get("rank", 0))
			ranks[rank] = minf(1.0, float(ranks.get(rank, 0.4)) + 0.18)
	return ranks
