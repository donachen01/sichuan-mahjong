extends RefCounted

class_name FanResolver

const SUITS := ["tiao", "tong", "wan"]
const RANKS := [1, 2, 3, 4, 5, 6, 7, 8, 9]


func resolve_win_fans(player: Dictionary, winning_tile: Dictionary, win_type: String, rules_config) -> Dictionary:
	if rules_config != null and bool(rules_config.is_neijiang_mode()):
		return _resolve_neijiang_win_fans(player, winning_tile, win_type, rules_config)
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


func _resolve_neijiang_win_fans(player: Dictionary, winning_tile: Dictionary, win_type: String, rules_config) -> Dictionary:
	var concealed_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	if win_type != "self_draw" and win_type != "gang_self_draw":
		concealed_tiles.append(winning_tile.duplicate(true))
	var melds: Array = player.get("melds", [])
	var gui_count: int = _count_gen(concealed_tiles, melds)
	var is_qing := _is_qing_yi_se(concealed_tiles, melds)
	var is_qi_dui := _is_qi_dui_hand(concealed_tiles, melds)
	var is_da_dui := _is_da_dui_zi(concealed_tiles, melds)
	var is_bao_jiao := bool(player.get("bao_jiao", false)) and bool(rules_config.enable_bao_jiao)
	var is_ka_er_tiao := bool(rules_config.enable_ka_er_tiao) and _is_ka_er_tiao(concealed_tiles, melds, winning_tile)
	var is_gui_enabled := bool(rules_config.enable_gui)
	var rule_marks: Array = player.get("rule_marks", [])
	var is_tian_he := rule_marks.has("天和")
	var is_di_hu := rule_marks.has("地胡")
	var is_hai_di := rule_marks.has("海底")
	var hand_type := "ping_hu"
	var base_fan := 1
	var use_gui_as_type_bonus := false
	if is_qi_dui and is_qing and gui_count > 0:
		hand_type = "qing_long_qi_dui"
		base_fan = 5
		use_gui_as_type_bonus = true
	elif is_qi_dui and is_qing:
		hand_type = "qing_qi_dui"
		base_fan = 4
	elif is_da_dui and is_qing:
		hand_type = "qing_dui"
		base_fan = 4
	elif is_qi_dui and gui_count > 0:
		hand_type = "long_qi_dui"
		base_fan = 5 if gui_count >= 2 else 4
		use_gui_as_type_bonus = true
	elif is_qi_dui:
		hand_type = "qi_dui"
		base_fan = 3
	elif is_qing:
		hand_type = "qing_yi_se"
		base_fan = 3
	elif is_da_dui:
		hand_type = "da_dui_zi"
		base_fan = 3

	var extra_fan := 0
	var labels: Array[String] = []
	if hand_type != "ping_hu":
		labels.append(_hand_type_label(hand_type))
	else:
		labels.append("平胡")
	if is_bao_jiao:
		extra_fan += 1
		labels.append("报叫")
	if is_ka_er_tiao:
		extra_fan += 1
		labels.append("卡二条")
	if is_gui_enabled and gui_count > 0 and not use_gui_as_type_bonus:
		for _i in range(gui_count):
			extra_fan += 1
			labels.append("归")
	if is_tian_he:
		extra_fan += 4
		labels.append("天和")
	elif is_di_hu:
		extra_fan += 4
		labels.append("地胡")
	if is_hai_di:
		extra_fan += 1
		labels.append("海底")
	if win_type == "gang_self_draw":
		extra_fan += 1
		labels.append("杠上花")
	elif win_type == "gang_discard_win":
		extra_fan += 1
		labels.append("杠上炮")
	elif win_type == "qiang_gang_hu":
		extra_fan += 1
		labels.append("抢杠胡")
	if win_type == "self_draw" or win_type == "gang_self_draw":
		labels.append("自摸")

	var uncapped_fan := base_fan + extra_fan
	var cap_value := int(rules_config.fan_cap)
	var capped_fan := uncapped_fan if cap_value <= 0 else mini(uncapped_fan, cap_value)
	var hand_score := _resolve_score_from_fan(capped_fan, rules_config)
	var per_payer_score := _resolve_per_payer_score(capped_fan, win_type, rules_config)
	return {
		"hand_type": hand_type,
		"flags": {
			"qing_yi_se": is_qing,
			"qi_dui": is_qi_dui,
			"da_dui_zi": is_da_dui,
			"bao_jiao": is_bao_jiao,
			"ka_er_tiao": is_ka_er_tiao,
			"gui": gui_count > 0,
			"tian_he": is_tian_he,
			"di_hu": is_di_hu,
			"hai_di": is_hai_di,
			"gang_shang_hua": win_type == "gang_self_draw",
			"gang_shang_pao": win_type == "gang_discard_win",
			"qiang_gang_hu": win_type == "qiang_gang_hu",
			"zi_mo": win_type == "self_draw" or win_type == "gang_self_draw",
		},
		"gen_count": gui_count,
		"gui_count": gui_count,
		"base_fan": base_fan,
		"bonus_multiplier": 1,
		"score_multiplier": 1,
		"uncapped_fan": uncapped_fan,
		"capped_fan": capped_fan,
		"hand_score": hand_score,
		"per_payer_score": per_payer_score,
		"labels": labels,
	}


func _resolve_score_from_fan(capped_fan: int, rules_config) -> int:
	if rules_config != null and bool(rules_config.is_neijiang_mode()):
		if capped_fan <= 1:
			return 1
		if capped_fan == 2:
			return 2
		if capped_fan == 3:
			return 4
		if capped_fan == 4:
			return 8
		return 16
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


func _is_ka_er_tiao(concealed_tiles: Array, melds: Array, winning_tile: Dictionary) -> bool:
	if str(winning_tile.get("suit", "")) != "tiao" or int(winning_tile.get("rank", 0)) != 2:
		return false
	if _is_qi_dui_hand(concealed_tiles, melds):
		return false
	var counts := _build_suit_rank_counts(concealed_tiles)
	if int(counts["tiao"][1]) <= 0 or int(counts["tiao"][2]) <= 0 or int(counts["tiao"][3]) <= 0:
		return false
	var winning_key := _tile_key(winning_tile)
	for suit in SUITS:
		for rank in RANKS:
			if counts[suit][rank] < 2:
				continue
			var trial := _duplicate_grouped_counts(counts)
			trial[suit][rank] -= 2
			if _can_resolve_with_ka_er_tiao(trial, winning_key, false):
				return true
	return false


func _can_resolve_with_ka_er_tiao(grouped_counts: Dictionary, winning_key: String, used_target: bool) -> bool:
	var next := _find_first_nonzero(grouped_counts)
	if next.is_empty():
		return used_target
	var suit: String = str(next.get("suit", ""))
	var rank: int = int(next.get("rank", 0))
	if grouped_counts[suit][rank] >= 3:
		var triplet_trial := _duplicate_grouped_counts(grouped_counts)
		triplet_trial[suit][rank] -= 3
		if _can_resolve_with_ka_er_tiao(triplet_trial, winning_key, used_target):
			return true
	if rank <= 7 and grouped_counts[suit][rank + 1] > 0 and grouped_counts[suit][rank + 2] > 0:
		var sequence_trial := _duplicate_grouped_counts(grouped_counts)
		sequence_trial[suit][rank] -= 1
		sequence_trial[suit][rank + 1] -= 1
		sequence_trial[suit][rank + 2] -= 1
		var target_now := used_target or (suit == "tiao" and rank == 1 and winning_key == "tiao_2")
		if _can_resolve_with_ka_er_tiao(sequence_trial, winning_key, target_now):
			return true
	return false


func _find_first_nonzero(grouped_counts: Dictionary) -> Dictionary:
	for suit in SUITS:
		for rank in RANKS:
			if int(grouped_counts[suit][rank]) > 0:
				return {"suit": suit, "rank": rank}
	return {}


func _hand_type_label(hand_type: String) -> String:
	match hand_type:
		"qing_yi_se":
			return "清一色"
		"qi_dui":
			return "暗七对"
		"long_qi_dui":
			return "龙七对"
		"qing_dui":
			return "清对"
		"qing_qi_dui":
			return "清七对"
		"qing_long_qi_dui":
			return "青龙七对"
		"da_dui_zi":
			return "大对子"
		_:
			return "平胡"


func _tile_key(tile: Dictionary) -> String:
	return "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]


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
