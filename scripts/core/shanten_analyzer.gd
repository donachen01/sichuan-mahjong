extends RefCounted

class_name ShantenAnalyzer

const SUITS := ["tiao", "tong", "wan"]
const RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9]


func analyze_hand(hand_tiles: Array, meld_count: int = 0, allow_qi_dui: bool = true) -> Dictionary:
	var standard: int = _standard_shanten(hand_tiles, meld_count)
	var qi_dui: int = 99
	if allow_qi_dui and meld_count == 0:
		qi_dui = _qi_dui_shanten(hand_tiles)
	return {
		"standard": standard,
		"qi_dui": qi_dui,
		"best": mini(standard, qi_dui),
	}


func _standard_shanten(hand_tiles: Array, meld_count: int) -> int:
	var counts: Array = _build_counts_array(hand_tiles)
	var result := {"best": 8}
	_search_standard(counts, 0, meld_count, 0, 0, result)
	return maxi(-1, int(result["best"]))


func _search_standard(counts: Array, index: int, melds: int, taatsu: int, pairs: int, result: Dictionary) -> void:
	var next_index := index
	while next_index < counts.size() and int(counts[next_index]) == 0:
		next_index += 1

	if next_index >= counts.size():
		var effective_taatsu := mini(taatsu, maxi(0, 4 - melds))
		var has_pair := 1 if pairs > 0 else 0
		var shanten := 8 - melds * 2 - effective_taatsu - has_pair
		result["best"] = mini(int(result["best"]), shanten)
		return

	if melds > 4:
		return

	if int(counts[next_index]) >= 3:
		counts[next_index] = int(counts[next_index]) - 3
		_search_standard(counts, next_index, melds + 1, taatsu, pairs, result)
		counts[next_index] = int(counts[next_index]) + 3

	if _can_take_sequence(counts, next_index):
		counts[next_index] = int(counts[next_index]) - 1
		counts[next_index + 1] = int(counts[next_index + 1]) - 1
		counts[next_index + 2] = int(counts[next_index + 2]) - 1
		_search_standard(counts, next_index, melds + 1, taatsu, pairs, result)
		counts[next_index] = int(counts[next_index]) + 1
		counts[next_index + 1] = int(counts[next_index + 1]) + 1
		counts[next_index + 2] = int(counts[next_index + 2]) + 1

	if int(counts[next_index]) >= 2:
		counts[next_index] = int(counts[next_index]) - 2
		_search_standard(counts, next_index, melds, taatsu, pairs + 1, result)
		_search_standard(counts, next_index, melds, taatsu + 1, pairs, result)
		counts[next_index] = int(counts[next_index]) + 2
	elif int(counts[next_index]) >= 1:
		if _can_take_adjacent(counts, next_index, 1):
			counts[next_index] = int(counts[next_index]) - 1
			counts[next_index + 1] = int(counts[next_index + 1]) - 1
			_search_standard(counts, next_index, melds, taatsu + 1, pairs, result)
			counts[next_index] = int(counts[next_index]) + 1
			counts[next_index + 1] = int(counts[next_index + 1]) + 1

		if _can_take_adjacent(counts, next_index, 2):
			counts[next_index] = int(counts[next_index]) - 1
			counts[next_index + 2] = int(counts[next_index + 2]) - 1
			_search_standard(counts, next_index, melds, taatsu + 1, pairs, result)
			counts[next_index] = int(counts[next_index]) + 1
			counts[next_index + 2] = int(counts[next_index + 2]) + 1

	counts[next_index] = int(counts[next_index]) - 1
	_search_standard(counts, next_index, melds, taatsu, pairs, result)
	counts[next_index] = int(counts[next_index]) + 1


func _qi_dui_shanten(hand_tiles: Array) -> int:
	var counts := {}
	for tile in hand_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		counts[key] = int(counts.get(key, 0)) + 1

	var pair_count := 0
	var distinct_count := counts.size()
	for key in counts.keys():
		if int(counts[key]) >= 2:
			pair_count += 1

	return maxi(-1, 6 - pair_count + maxi(0, 7 - distinct_count))


func _build_counts_array(hand_tiles: Array) -> Array:
	var counts: Array = []
	counts.resize(27)
	counts.fill(0)
	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		var rank: int = int(tile.get("rank", 0))
		var tile_index := _tile_index(suit, rank)
		if tile_index >= 0:
			counts[tile_index] = int(counts[tile_index]) + 1
	return counts


func _tile_index(suit: String, rank: int) -> int:
	var suit_index := SUITS.find(suit)
	if suit_index == -1 or rank < 1 or rank > 9:
		return -1
	return suit_index * 9 + rank - 1


func _can_take_sequence(counts: Array, index: int) -> bool:
	var rank := index % 9
	if rank > 6:
		return false
	return int(counts[index]) > 0 and int(counts[index + 1]) > 0 and int(counts[index + 2]) > 0


func _can_take_adjacent(counts: Array, index: int, gap: int) -> bool:
	var rank := index % 9
	if rank + gap > 8:
		return false
	return int(counts[index]) > 0 and int(counts[index + gap]) > 0
