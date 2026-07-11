extends RefCounted

class_name SichuanShantenEngine

const ShantenAnalyzerScript := preload("res://scripts/core/shanten_analyzer.gd")

var analyzer = ShantenAnalyzerScript.new()


func analyze_hand(hand_tiles: Array, meld_count: int = 0, allow_qi_dui: bool = true) -> Dictionary:
	var info: Dictionary = analyzer.analyze_hand(hand_tiles, meld_count, allow_qi_dui)
	return {
		"standard": int(info.get("standard", 8)),
		"qi_dui": int(info.get("qi_dui", 99)),
		"best": int(info.get("best", 8)),
	}


func calc_best_shanten(hand_tiles: Array, meld_count: int = 0, allow_qi_dui: bool = true) -> int:
	return int(analyze_hand(hand_tiles, meld_count, allow_qi_dui).get("best", 8))


func calc_shanten_after_discard(hand_tiles: Array, discard_tile: Dictionary, meld_count: int = 0, allow_qi_dui: bool = true) -> int:
	var simulated := _remove_one(hand_tiles, discard_tile)
	return calc_best_shanten(simulated, meld_count, allow_qi_dui)


func calc_ukeire_after_discard(hand_tiles: Array, discard_tile: Dictionary, players: Array, active_suits: Array, meld_count: int = 0, allow_qi_dui: bool = true) -> Dictionary:
	var remaining_hand := _remove_one(hand_tiles, discard_tile)
	var current_shanten := calc_best_shanten(remaining_hand, meld_count, allow_qi_dui)
	var visible_counts := _build_visible_counts(players, remaining_hand)
	var improving_tiles: Array = []
	var live_total := 0
	for suit in active_suits:
		for rank in range(1, 10):
			var probe := {
				"id": -1,
				"suit": suit,
				"rank": rank,
				"display_name": "%d%s" % [rank, _suit_label(suit)],
			}
			var key := _tile_key(probe)
			var live_count := maxi(0, 4 - int(visible_counts.get(key, 0)))
			if live_count <= 0:
				continue
			var simulated := remaining_hand.duplicate(true)
			simulated.append(probe)
			var new_shanten := calc_best_shanten(simulated, meld_count, allow_qi_dui)
			if new_shanten < current_shanten:
				improving_tiles.append(probe)
				live_total += live_count
	return {
		"shanten": current_shanten,
		"ukeire": improving_tiles.size(),
		"live_ukeire": live_total,
		"improving_tiles": improving_tiles,
	}


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


func _build_visible_counts(players: Array, hand_tiles: Array) -> Dictionary:
	var counts: Dictionary = {}
	for tile in hand_tiles:
		var key := _tile_key(tile)
		counts[key] = int(counts.get(key, 0)) + 1
	for player in players:
		for tile in player.get("discards", []):
			var discard_key := _tile_key(tile)
			counts[discard_key] = int(counts.get(discard_key, 0)) + 1
		for meld in player.get("melds", []):
			for meld_tile in meld.get("tiles", []):
				var meld_key := _tile_key(meld_tile)
				counts[meld_key] = int(counts.get(meld_key, 0)) + 1
	return counts


func _tile_key(tile: Dictionary) -> String:
	return "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


func _suit_label(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return suit
