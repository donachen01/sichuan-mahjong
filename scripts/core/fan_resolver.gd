extends RefCounted

class_name FanResolver

const SUITS := ["tiao", "tong", "wan"]
const RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9]


func resolve_win_fans(player: Dictionary, winning_tile: Dictionary, win_type: String, rules_config) -> Dictionary:
	return _resolve_sichuan_win_fans(player, winning_tile, win_type, rules_config)


func _resolve_sichuan_win_fans(player: Dictionary, winning_tile: Dictionary, win_type: String, rules_config) -> Dictionary:
	var concealed_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	if win_type != "self_draw" and win_type != "gang_self_draw":
		concealed_tiles.append(winning_tile.duplicate(true))

	var melds: Array = player.get("melds", [])
	var gen_count: int = _count_gen(concealed_tiles, melds)
	var flags := {
		"qing_yi_se": _is_qing_yi_se(concealed_tiles, melds),
		"qi_dui": _is_qi_dui_hand(concealed_tiles, melds),
		"da_dui_zi": _is_da_dui_zi(concealed_tiles, melds),
		"ping_hu": false,
		"jin_gou_diao": _is_jin_gou_diao(concealed_tiles, melds),
		"dai_gen": gen_count > 0,
		"gang_shang_hua": win_type == "gang_self_draw",
		"gang_shang_pao": win_type == "gang_discard_win",
		"qiang_gang_hu": win_type == "qiang_gang_hu",
		"zi_mo": win_type == "self_draw" or win_type == "gang_self_draw",
	}
	flags["ping_hu"] = not flags["qing_yi_se"] and not flags["qi_dui"] and not flags["da_dui_zi"]

	var base_fan := 1
	var hand_type := "ping_hu"
	if flags["qing_yi_se"]:
		base_fan = 4
		hand_type = "qing_yi_se"
	elif flags["qi_dui"]:
		base_fan = 4
		hand_type = "qi_dui"
	elif flags["da_dui_zi"]:
		base_fan = 2
		hand_type = "da_dui_zi"

	var bonus_multiplier := 1
	if flags["gang_shang_hua"] or flags["gang_shang_pao"] or flags["qiang_gang_hu"]:
		bonus_multiplier *= 2
	if flags["jin_gou_diao"]:
		bonus_multiplier *= 2
	for _i in range(gen_count):
		bonus_multiplier *= 2

	var uncapped_fan := base_fan * bonus_multiplier
	var cap_value := int(rules_config.fan_cap)
	var capped_fan := uncapped_fan if cap_value <= 0 else mini(uncapped_fan, cap_value)
	var hand_score := _resolve_score_from_fan(capped_fan, rules_config)
	var per_payer_score := _resolve_per_payer_score(capped_fan, win_type, rules_config)
	var labels: Array[String] = [_hand_type_label(hand_type)]
	if flags["jin_gou_diao"]:
		labels.append("金钩钓")
	for _i in range(gen_count):
		labels.append("带根")
	if flags["gang_shang_hua"]:
		labels.append("杠上花")
	if flags["gang_shang_pao"]:
		labels.append("杠上炮")
	if flags["qiang_gang_hu"]:
		labels.append("抢杠胡")
	if flags["zi_mo"]:
		labels.append("自摸")
	return {
		"hand_type": hand_type,
		"flags": flags,
		"gen_count": gen_count,
		"base_fan": base_fan,
		"bonus_multiplier": bonus_multiplier,
		"score_multiplier": 1,
		"uncapped_fan": uncapped_fan,
		"capped_fan": capped_fan,
		"hand_score": hand_score,
		"per_payer_score": per_payer_score,
		"labels": labels,
	}


func _resolve_score_from_fan(capped_fan: int, rules_config) -> int:
	if capped_fan <= 0:
		return 1
	return int(pow(2.0, capped_fan - 1))


func _resolve_per_payer_score(capped_fan: int, win_type: String, rules_config) -> int:
	var score := _resolve_score_from_fan(capped_fan, rules_config)
	if win_type == "self_draw" or win_type == "gang_self_draw":
		score += 1 if rules_config == null else int(rules_config.self_draw_extra_base_score)
	return score


func _is_qing_yi_se(concealed_tiles: Array, melds: Array) -> bool:
	var suit := ""
	for tile in concealed_tiles:
		var tile_suit: String = tile.get("suit", "")
		if tile_suit == "":
			continue
		if suit == "":
			suit = tile_suit
		elif suit != tile_suit:
			return false
	for meld in melds:
		for tile in meld.get("tiles", []):
			var meld_suit: String = tile.get("suit", "")
			if meld_suit == "":
				continue
			if suit == "":
				suit = meld_suit
			elif suit != meld_suit:
				return false
	return suit != ""


func _is_qi_dui_hand(concealed_tiles: Array, melds: Array) -> bool:
	if not melds.is_empty():
		return false
	if concealed_tiles.size() != 14:
		return false
	var counts := _build_tile_counts(concealed_tiles)
	var pair_count := 0
	for key in counts.keys():
		var count: int = counts[key]
		if count != 2 and count != 4:
			return false
		pair_count += count / 2
	return pair_count == 7


func _is_da_dui_zi(concealed_tiles: Array, melds: Array) -> bool:
	for meld in melds:
		var meld_type: String = meld.get("type", "")
		if meld_type != "peng" and meld_type != "gang":
			return false
	if concealed_tiles.size() % 3 != 2:
		return false
	var counts := _build_suit_rank_counts(concealed_tiles)
	for suit in SUITS:
		for rank in RANKS:
			if counts[suit][rank] < 2:
				continue
			var trial := _duplicate_grouped_counts(counts)
			trial[suit][rank] -= 2
			if _can_clear_triplets_only(trial):
				return true
	return false


func _can_clear_triplets_only(grouped_counts: Dictionary) -> bool:
	for suit in SUITS:
		for rank in RANKS:
			if grouped_counts[suit][rank] % 3 != 0:
				return false
	return true


func _is_jin_gou_diao(concealed_tiles: Array, melds: Array) -> bool:
	return melds.size() == 4 and concealed_tiles.size() == 2


func _count_gen(concealed_tiles: Array, melds: Array) -> int:
	var all_tiles: Array = concealed_tiles.duplicate(true)
	for meld in melds:
		for tile in meld.get("tiles", []):
			all_tiles.append(tile.duplicate(true))
	var counts := _build_tile_counts(all_tiles)
	var gen_count := 0
	for key in counts.keys():
		gen_count += int(counts[key]) / 4
	return gen_count


func _hand_type_label(hand_type: String) -> String:
	match hand_type:
		"qing_yi_se":
			return "清一色"
		"qi_dui":
			return "暗七对"
		"da_dui_zi":
			return "大对子"
		_:
			return "平胡"


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
		var rank: int = int(tile.get("rank", 0))
		if grouped.has(suit) and grouped[suit].has(rank):
			grouped[suit][rank] += 1
	return grouped


func _duplicate_grouped_counts(grouped_counts: Dictionary) -> Dictionary:
	var result := {}
	for suit in grouped_counts.keys():
		result[suit] = grouped_counts[suit].duplicate(true)
	return result
