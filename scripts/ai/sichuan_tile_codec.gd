extends RefCounted

class_name SichuanTileCodec

const SUIT_ORDER := ["tiao", "tong", "wan"]


func resolve_active_suits(rules_config) -> Array:
	if rules_config != null and rules_config.get("available_suits") != null:
		var suits := Array(rules_config.get("available_suits")).duplicate()
		if not suits.is_empty():
			return suits
	return SUIT_ORDER.duplicate()


func tile_type(tile: Dictionary, active_suits: Array) -> int:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	var suit_index := active_suits.find(suit)
	if suit_index == -1 or rank < 1 or rank > 9:
		return -1
	return suit_index * 9 + rank - 1


func encode_tile(suit: String, rank: int, active_suits: Array) -> int:
	var suit_index := active_suits.find(suit)
	if suit_index == -1 or rank < 1 or rank > 9:
		return -1
	return suit_index * 9 + rank - 1


func decode_type(tile_type_value: int, active_suits: Array) -> Dictionary:
	if tile_type_value < 0 or tile_type_value >= active_suits.size() * 9:
		return {}
	var suit_index := int(tile_type_value / 9)
	var rank := int(tile_type_value % 9) + 1
	return {
		"suit": str(active_suits[suit_index]),
		"rank": rank,
		"display_name": "%d%s" % [rank, _suit_label(str(active_suits[suit_index]))],
	}


func build_count_array(hand_tiles: Array, active_suits: Array) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(active_suits.size() * 9)
	counts.fill(0)
	for tile in hand_tiles:
		var code := tile_type(tile, active_suits)
		if code >= 0 and code < counts.size():
			counts[code] += 1
	return counts


func build_visible_count_array(players: Array, extra_tiles: Array, active_suits: Array, self_seat: int) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(active_suits.size() * 9)
	counts.fill(0)
	var public_tile_ids := {}
	for player in players:
		var seat := int(player.get("seat", -1))
		for tile in player.get("discards", []):
			_increment(counts, tile_type(tile, active_suits))
			if int(tile.get("id", -1)) >= 0:
				public_tile_ids[int(tile.get("id", -1))] = true
		for meld in player.get("melds", []):
			for tile in meld.get("tiles", []):
				_increment(counts, tile_type(tile, active_suits))
				if int(tile.get("id", -1)) >= 0:
					public_tile_ids[int(tile.get("id", -1))] = true
		if seat != self_seat:
			var winning_tile: Dictionary = player.get("winning_tile", {})
			var winning_id := int(winning_tile.get("id", -1))
			var win_type := str(player.get("win_type", ""))
			var is_self_draw := win_type in ["self_draw", "gang_self_draw", "dian_gang_hua"] \
				or (win_type.is_empty() and int(player.get("winning_source_seat", seat)) == seat)
			# Self-draw keeps the tile inside the winner's concealed hand. A
			# multi-Hu uses the same physical discard for all winners.
			if not winning_tile.is_empty() and not is_self_draw \
				and (winning_id < 0 or not public_tile_ids.has(winning_id)):
				_increment(counts, tile_type(winning_tile, active_suits))
				if winning_id >= 0:
					public_tile_ids[winning_id] = true
	for tile in extra_tiles:
		_increment(counts, tile_type(tile, active_suits))
	return counts


func build_remaining_count_array(hand_tiles: Array, players: Array, active_suits: Array, self_seat: int) -> PackedInt32Array:
	var remaining := PackedInt32Array()
	remaining.resize(active_suits.size() * 9)
	remaining.fill(4)
	var visible := build_visible_count_array(players, hand_tiles, active_suits, self_seat)
	for index in range(remaining.size()):
		remaining[index] = maxi(0, int(remaining[index]) - int(visible[index]))
	return remaining


func _increment(counts: PackedInt32Array, code: int) -> void:
	if code >= 0 and code < counts.size():
		counts[code] += 1


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
