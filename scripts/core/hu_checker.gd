extends RefCounted

class_name HuChecker

const SUITS := ["tiao", "tong", "wan"]
const RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9]


func can_hu_on_discard(player: Dictionary, discarded_tile: Dictionary, rules_config) -> bool:
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	hand_tiles.append(discarded_tile.duplicate(true))
	return can_hu_with_full_hand(
		hand_tiles,
		player.get("ding_que", ""),
		rules_config,
		int(player.get("melds", []).size()),
		player.get("melds", [])
	)


func can_hu_with_player_state(player: Dictionary, rules_config) -> bool:
	return can_hu_with_full_hand(
		player.get("hand_tiles", []),
		player.get("ding_que", ""),
		rules_config,
		int(player.get("melds", []).size()),
		player.get("melds", [])
	)


func can_hu_with_full_hand(
	full_hand_tiles: Array,
	ding_que_suit: String,
	rules_config,
	exposed_meld_count: int = 0,
	exposed_melds: Array = []
) -> bool:
	var required_concealed_size := ((4 - exposed_meld_count) * 3) + 2
	if exposed_meld_count < 0 or exposed_meld_count > 4:
		return false
	if full_hand_tiles.size() != required_concealed_size:
		return false
	if rules_config.require_missing_one_suit_to_win \
		and ding_que_suit != "" \
		and (_contains_suit(full_hand_tiles, ding_que_suit) or _melds_contain_suit(exposed_melds, ding_que_suit)):
		return false
	if rules_config.enable_qi_dui and exposed_meld_count == 0 and _is_qi_dui(full_hand_tiles):
		return true
	return _is_standard_win(full_hand_tiles)


func get_ting_tiles(
	hand_tiles: Array,
	ding_que_suit: String,
	rules_config,
	exposed_meld_count: int = 0,
	exposed_melds: Array = []
) -> Array:
	var results: Array = []
	if hand_tiles.size() % 3 != 1:
		return results

	for suit in _rule_suits(rules_config):
		for rank in RANKS:
			var test_hand: Array = hand_tiles.duplicate(true)
			test_hand.append(
				{
					"id": -1,
					"suit": suit,
					"rank": rank,
					"display_name": "%d%s" % [rank, _suit_display_name(suit)],
				}
			)
			if can_hu_with_full_hand(test_hand, ding_que_suit, rules_config, exposed_meld_count, exposed_melds):
				results.append(
					{
						"suit": suit,
						"rank": rank,
						"display_name": "%d%s" % [rank, _suit_display_name(suit)],
					}
				)
	return results




func _rule_suits(rules_config) -> Array:
	if rules_config != null:
		return Array(rules_config.available_suits)
	return SUITS

func is_ting(
	hand_tiles: Array,
	ding_que_suit: String,
	rules_config,
	exposed_meld_count: int = 0,
	exposed_melds: Array = []
) -> bool:
	return not get_ting_tiles(hand_tiles, ding_que_suit, rules_config, exposed_meld_count, exposed_melds).is_empty()


func _contains_suit(tiles: Array, suit: String) -> bool:
	for tile in tiles:
		if tile.get("suit", "") == suit:
			return true
	return false


func _melds_contain_suit(melds: Array, suit: String) -> bool:
	for meld in melds:
		for tile in meld.get("tiles", []):
			if str(tile.get("suit", "")) == suit:
				return true
	return false


func _suit_display_name(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return "?"


func _is_qi_dui(tiles: Array) -> bool:
	if tiles.size() != 14:
		return false
	var counts := _build_tile_counts(tiles)
	var pair_count := 0
	for key in counts.keys():
		var count: int = counts[key]
		if count != 2 and count != 4:
			return false
		pair_count += count / 2
	return pair_count == 7


func _is_standard_win(tiles: Array) -> bool:
	var grouped_counts := _build_suit_rank_counts(tiles)
	for suit in grouped_counts.keys():
		for rank in RANKS:
			if grouped_counts[suit][rank] < 2:
				continue
			var trial_counts := _duplicate_grouped_counts(grouped_counts)
			trial_counts[suit][rank] -= 2
			if _can_clear_all_suits(trial_counts):
				return true
	return false


func _can_clear_all_suits(grouped_counts: Dictionary) -> bool:
	for suit in SUITS:
		if not _can_clear_single_suit(grouped_counts[suit], 1):
			return false
	return true


func _can_clear_single_suit(rank_counts: Dictionary, start_rank: int) -> bool:
	var next_rank := start_rank
	while next_rank <= 9 and rank_counts[next_rank] == 0:
		next_rank += 1
	if next_rank > 9:
		return true

	if rank_counts[next_rank] >= 3:
		var triplet_counts := rank_counts.duplicate(true)
		triplet_counts[next_rank] -= 3
		if _can_clear_single_suit(triplet_counts, next_rank):
			return true

	if next_rank <= 7 and rank_counts[next_rank + 1] > 0 and rank_counts[next_rank + 2] > 0:
		var sequence_counts := rank_counts.duplicate(true)
		sequence_counts[next_rank] -= 1
		sequence_counts[next_rank + 1] -= 1
		sequence_counts[next_rank + 2] -= 1
		if _can_clear_single_suit(sequence_counts, next_rank):
			return true

	return false


func _build_tile_counts(tiles: Array) -> Dictionary:
	var counts := {}
	for tile in tiles:
		var key := "%s_%d" % [tile.get("suit", ""), int(tile.get("rank", 0))]
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _build_suit_rank_counts(tiles: Array) -> Dictionary:
	var grouped := {}
	for suit in SUITS:
		grouped[suit] = {}
		for rank in RANKS:
			grouped[suit][rank] = 0

	for tile in tiles:
		var suit: String = str(tile.get("suit", ""))
		var rank := int(tile.get("rank", 0))
		if not grouped.has(suit) or not grouped[suit].has(rank):
			continue
		grouped[suit][rank] += 1
	return grouped


func _duplicate_grouped_counts(grouped_counts: Dictionary) -> Dictionary:
	var result := {}
	for suit in grouped_counts.keys():
		result[suit] = grouped_counts[suit].duplicate(true)
	return result
