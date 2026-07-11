extends RefCounted

class_name SichuanCallQualityEngine


func evaluate(ting_tiles: Array, remaining_hand: Array, players: Array, self_seat: int) -> Dictionary:
	if ting_tiles.is_empty():
		return {
			"wait_count": 0,
			"live_count": 0,
			"self_draw_bonus": 0,
			"must_appear_bonus": 0,
			"score": 0,
		}
	var visible := _build_visible_counts(players, remaining_hand)
	var live_count := 0
	var self_draw_bonus := 0
	var must_appear_bonus := 0
	for tile in ting_tiles:
		var key := _tile_key(tile)
		var seen := int(visible.get(key, 0))
		var live := maxi(0, 4 - seen)
		live_count += live
		self_draw_bonus += live * (1 + _missing_suit_bonus(players, self_seat, str(tile.get("suit", ""))))
		must_appear_bonus += _must_appear_bonus(tile, visible)
	var wait_count := ting_tiles.size()
	var score := wait_count * 16 + live_count * 7 + self_draw_bonus * 4 + must_appear_bonus
	return {
		"wait_count": wait_count,
		"live_count": live_count,
		"self_draw_bonus": self_draw_bonus,
		"must_appear_bonus": must_appear_bonus,
		"score": score,
	}


func _build_visible_counts(players: Array, remaining_hand: Array) -> Dictionary:
	var counts: Dictionary = {}
	for tile in remaining_hand:
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


func _missing_suit_bonus(players: Array, self_seat: int, suit: String) -> int:
	var count := 0
	for player in players:
		var seat := int(player.get("seat", -1))
		if seat == self_seat or bool(player.get("has_won", false)):
			continue
		if str(player.get("ding_que", "")) == suit:
			count += 1
	return count


func _must_appear_bonus(tile: Dictionary, visible: Dictionary) -> int:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var left_key := "%s_%d" % [suit, rank - 1]
	var right_key := "%s_%d" % [suit, rank + 1]
	var left_seen := 4 if rank <= 1 else int(visible.get(left_key, 0))
	var right_seen := 4 if rank >= 9 else int(visible.get(right_key, 0))
	if left_seen >= 4 and right_seen >= 4:
		return 12
	if left_seen >= 4 or right_seen >= 4:
		return 5
	return 0


func _tile_key(tile: Dictionary) -> String:
	return "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
