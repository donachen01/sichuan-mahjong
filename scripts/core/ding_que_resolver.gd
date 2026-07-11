extends RefCounted

class_name DingQueResolver


func choose_ai_missing_suit(hand_tiles: Array, suits: Array, rng: RandomNumberGenerator) -> String:
	var suit_counts: Dictionary = {}
	for suit in suits:
		suit_counts[suit] = 0

	for tile in hand_tiles:
		var suit: String = tile["suit"]
		suit_counts[suit] += 1

	var best_suits: Array[String] = []
	var min_count: int = 999999
	for suit in suits:
		var count: int = suit_counts[suit]
		if count < min_count:
			min_count = count
			best_suits = [suit]
		elif count == min_count:
			best_suits.append(suit)

	return best_suits[rng.randi_range(0, best_suits.size() - 1)]


func has_concealed_gang_candidate(hand_tiles: Array) -> bool:
	var counts: Dictionary = {}
	for tile in hand_tiles:
		var tile_key := "%s_%s" % [tile["suit"], tile["rank"]]
		counts[tile_key] = counts.get(tile_key, 0) + 1
		if counts[tile_key] >= 4:
			return true
	return false


func must_choose_before_first_discard(player: Dictionary, dealer_seat: int) -> bool:
	return true


func can_finish_opening_ding_que(players: Array, dealer_seat: int) -> bool:
	for player in players:
		if player["seat"] == dealer_seat:
			if must_choose_before_first_discard(player, dealer_seat) and player["ding_que"] == "":
				return false
			continue
		if player["ding_que"] == "":
			return false
	return true
