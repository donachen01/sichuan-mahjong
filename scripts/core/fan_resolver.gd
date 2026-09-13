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
	var concealed_quad_count := _count_concealed_quads(concealed_tiles)
	var exposed_quad_count := _count_gang_melds(melds)
	var is_qi_dui := _is_qi_dui_hand(concealed_tiles, melds)
	var is_long_qi_dui := is_qi_dui and concealed_quad_count > 0
	# 龙七对本身内置的一组四张不重复计根；如果七对里还有第二组四张，
	# 额外的那一组仍按“多根可累加”计入。已经副露的明杠、暗杠、补杠
	# 同样是四张相同牌，必须计根，不能因移出手牌而漏算。
	var gen_count := exposed_quad_count + maxi(0, concealed_quad_count - (1 if is_long_qi_dui else 0))
	var is_qing_yi_se := _is_qing_yi_se(concealed_tiles, melds)
	var is_da_dui_zi := _is_da_dui_zi(concealed_tiles, melds)
	var is_jin_gou_diao := _is_jin_gou_diao(concealed_tiles, melds)
	var is_jiang_dui := is_da_dui_zi and _all_tiles_are_jiang(concealed_tiles, melds)
	var is_shi_ba_luo_han := _count_gang_melds(melds) == 4
	var flags := {
		"qing_yi_se": is_qing_yi_se,
		"qi_dui": is_qi_dui,
		"long_qi_dui": is_long_qi_dui,
		"da_dui_zi": is_da_dui_zi,
		"ping_hu": not is_qi_dui and not is_da_dui_zi and not is_jin_gou_diao,
		"jin_gou_diao": is_jin_gou_diao,
		"jiang_dui": is_jiang_dui,
		"shi_ba_luo_han": is_shi_ba_luo_han,
		"dai_gen": gen_count > 0,
		"gang_shang_hua": win_type == "gang_self_draw",
		"gang_shang_pao": win_type == "gang_discard_win",
		"qiang_gang_hu": win_type == "qiang_gang_hu",
		"zi_mo": win_type == "self_draw" or win_type == "gang_self_draw",
	}

	var base_result := _resolve_base_hand_type(flags)
	var hand_type := str(base_result.get("hand_type", "ping_hu"))
	var base_fan := int(base_result.get("base_fan", 0))
	var bonus_fan := gen_count
	if flags["gang_shang_hua"]:
		bonus_fan += 1
	if flags["gang_shang_pao"]:
		bonus_fan += 1
	if flags["qiang_gang_hu"]:
		bonus_fan += 1

	var uncapped_fan := base_fan + bonus_fan
	var cap_value := 4 if rules_config == null else int(rules_config.fan_cap)
	var capped_fan := uncapped_fan if cap_value <= 0 else mini(uncapped_fan, cap_value)
	var hand_score := _resolve_score_from_fan(capped_fan, rules_config)
	var per_payer_score := _resolve_per_payer_score(capped_fan, win_type, rules_config)
	var labels: Array[String] = [_hand_type_label(hand_type)]
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
		"bonus_fan": bonus_fan,
		# 保留旧字段供历史诊断读取，但含义明确为“加番对应的倍率”，
		# 不再拿它与基础番相乘。
		"bonus_multiplier": int(pow(2.0, bonus_fan)),
		"score_multiplier": int(pow(2.0, capped_fan)),
		"uncapped_fan": uncapped_fan,
		"capped_fan": capped_fan,
		"hand_score": hand_score,
		"per_payer_score": per_payer_score,
		"labels": labels,
	}


func _resolve_score_from_fan(capped_fan: int, rules_config) -> int:
	var bottom_score := 1 if rules_config == null else maxi(1, int(rules_config.base_score))
	return bottom_score * int(pow(2.0, maxi(0, capped_fan)))


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


func _count_concealed_quads(concealed_tiles: Array) -> int:
	var counts := _build_tile_counts(concealed_tiles)
	var gen_count := 0
	for key in counts.keys():
		gen_count += int(counts[key]) / 4
	return gen_count


func _count_gang_melds(melds: Array) -> int:
	var count := 0
	for meld in melds:
		if str(meld.get("type", "")) == "gang":
			count += 1
	return count


func _all_tiles_are_jiang(concealed_tiles: Array, melds: Array) -> bool:
	var found_tile := false
	for tile in concealed_tiles:
		found_tile = true
		if not [2, 5, 8].has(int(tile.get("rank", 0))):
			return false
	for meld in melds:
		for tile in meld.get("tiles", []):
			found_tile = true
			if not [2, 5, 8].has(int(tile.get("rank", 0))):
				return false
	return found_tile


func _resolve_base_hand_type(flags: Dictionary) -> Dictionary:
	if bool(flags.get("shi_ba_luo_han", false)):
		return {"hand_type": "shi_ba_luo_han", "base_fan": 4}
	if bool(flags.get("qing_yi_se", false)) and bool(flags.get("qi_dui", false)):
		return {"hand_type": "qing_qi_dui", "base_fan": 4}
	if bool(flags.get("qing_yi_se", false)) and bool(flags.get("jin_gou_diao", false)):
		return {"hand_type": "qing_jin_gou_diao", "base_fan": 4}
	if bool(flags.get("jiang_dui", false)):
		return {"hand_type": "jiang_dui", "base_fan": 3}
	if bool(flags.get("qing_yi_se", false)) and bool(flags.get("da_dui_zi", false)):
		return {"hand_type": "qing_dui", "base_fan": 3}
	if bool(flags.get("long_qi_dui", false)):
		return {"hand_type": "long_qi_dui", "base_fan": 3}
	if bool(flags.get("qing_yi_se", false)):
		return {"hand_type": "qing_yi_se", "base_fan": 2}
	if bool(flags.get("qi_dui", false)):
		return {"hand_type": "qi_dui", "base_fan": 2}
	if bool(flags.get("jin_gou_diao", false)):
		return {"hand_type": "jin_gou_diao", "base_fan": 2}
	if bool(flags.get("da_dui_zi", false)):
		return {"hand_type": "da_dui_zi", "base_fan": 1}
	return {"hand_type": "ping_hu", "base_fan": 0}


func _hand_type_label(hand_type: String) -> String:
	match hand_type:
		"shi_ba_luo_han":
			return "十八罗汉"
		"qing_qi_dui":
			return "清七对"
		"qing_jin_gou_diao":
			return "清金钩钓"
		"jiang_dui":
			return "将对"
		"qing_dui":
			return "清对"
		"long_qi_dui":
			return "龙七对"
		"qing_yi_se":
			return "清一色"
		"qi_dui":
			return "小七对"
		"jin_gou_diao":
			return "金钩钓"
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
