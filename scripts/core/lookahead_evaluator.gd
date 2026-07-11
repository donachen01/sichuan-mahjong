extends RefCounted

class_name LookaheadEvaluator


func evaluate_candidates(
	option_items: Array,
	player: Dictionary,
	players: Array,
	rules_config,
	hu_checker,
	shanten_analyzer,
	risk_analyzer,
	discard_advisor,
	max_candidates: int = 3,
	max_draw_samples: int = 10,
	allow_cheat: bool = false,
	active_suits: Array = ["tiao", "tong", "wan"]
) -> Array:
	if option_items.is_empty():
		return option_items

	var visible_counts := _build_visible_tile_counts(player, players)
	var candidate_count := mini(max_candidates, option_items.size())
	for index in range(candidate_count):
		var option: Dictionary = option_items[index]
		var remaining_hand: Array = _remove_one_tile(player.get("hand_tiles", []), option.get("tile", {}))
		var draw_pool: Array = _build_draw_pool(visible_counts, remaining_hand, active_suits)
		var future_value := _estimate_future_value(
			draw_pool,
			remaining_hand,
			player,
			players,
			rules_config,
			hu_checker,
			shanten_analyzer,
			risk_analyzer,
			discard_advisor,
			max_draw_samples,
			allow_cheat,
			active_suits
		)
		option["lookahead_score"] = future_value
		option["score"] = int(option.get("score", 0)) + future_value
		var reasons: Array = option.get("reasons", []).duplicate(true)
		reasons.append("前瞻收益 %+d" % future_value)
		option["reasons"] = reasons
		option_items[index] = option

	option_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("shanten", 8)) != int(b.get("shanten", 8)):
			return int(a.get("shanten", 8)) < int(b.get("shanten", 8))
		if int(a.get("fast_ting_discard_rank", 99)) != int(b.get("fast_ting_discard_rank", 99)):
			return int(a.get("fast_ting_discard_rank", 99)) < int(b.get("fast_ting_discard_rank", 99))
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		if int(a.get("ukeire", 0)) != int(b.get("ukeire", 0)):
			return int(a.get("ukeire", 0)) > int(b.get("ukeire", 0))
		return str(a.get("tile_name", "")) < str(b.get("tile_name", ""))
	)
	return option_items


func _estimate_future_value(
	draw_pool: Array,
	remaining_hand: Array,
	player: Dictionary,
	players: Array,
	rules_config,
	hu_checker,
	shanten_analyzer,
	risk_analyzer,
	discard_advisor,
	max_draw_samples: int,
	allow_cheat: bool,
	active_suits: Array
) -> int:
	if draw_pool.is_empty():
		return 0
	var weighted_total := 0.0
	var total_weight := 0.0
	var meld_count := int(player.get("melds", []).size())
	var ding_que := str(player.get("ding_que", ""))
	var enable_qi_dui := bool(rules_config.enable_qi_dui)
	var visible_counts := _build_visible_tile_counts(player, players)
	var sample_count := draw_pool.size() if max_draw_samples <= 0 else mini(max_draw_samples, draw_pool.size())
	for index in range(sample_count):
		var draw_tile: Dictionary = draw_pool[index]
		var weight := float(int(draw_tile.get("remaining", 0)))
		if weight <= 0.0:
			continue
		var simulated_hand := remaining_hand.duplicate(true)
		simulated_hand.append(draw_tile)
		var future_value := float(_estimate_fast_best_discard_value(
			simulated_hand,
			player,
			players,
			meld_count,
			ding_que,
			enable_qi_dui,
			visible_counts,
			active_suits,
			rules_config,
			hu_checker,
			shanten_analyzer,
			player.get("melds", []),
			discard_advisor
		))
		weighted_total += future_value * weight
		total_weight += weight
	if total_weight <= 0.0:
		return 0
	return int(round(weighted_total / total_weight))


func _estimate_fast_best_discard_value(
	hand_tiles: Array,
	player: Dictionary,
	players: Array,
	meld_count: int,
	ding_que: String,
	enable_qi_dui: bool,
	visible_counts: Dictionary,
	active_suits: Array,
	rules_config,
	hu_checker,
	shanten_analyzer,
	melds: Array,
	discard_advisor
) -> int:
	var best_value := -9999
	var seen_keys := {}
	var self_seat: int = int(player.get("seat", -1))
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		var key := "%s_%d" % [suit, int(tile.get("rank", 0))]
		if seen_keys.has(key):
			continue
		seen_keys[key] = true
		if _must_discard_ding_que(hand_tiles, ding_que) and suit != ding_que:
			continue
		var test_hand := _remove_one_tile(hand_tiles, tile)
		var shanten_info: Dictionary = shanten_analyzer.analyze_hand(test_hand, meld_count, enable_qi_dui)
		var ting_tiles: Array = hu_checker.get_ting_tiles(
			test_hand,
			ding_que,
			rules_config,
			meld_count,
			melds
		)
		var shanten := int(shanten_info.get("best", 8))
		var ukeire := _estimate_ukeire_from_counts(ting_tiles, visible_counts)
		var simulated_player := player.duplicate(true)
		simulated_player["hand_tiles"] = test_hand.duplicate(true)
		var strategy_profile: Dictionary = discard_advisor.strategy_engine.build_profile(simulated_player, players, shanten, ting_tiles)
		var risk_info := {"risk": 18}
		var probability_profile: Dictionary = discard_advisor.estimate_hand_probability_profile(
			test_hand,
			ting_tiles,
			players,
			self_seat,
			shanten,
			ukeire,
			[],
			risk_info,
			strategy_profile,
			null,
			active_suits
		)
		var value := int(probability_profile.get("score", 0)) + ukeire * 2
		if value > best_value:
			best_value = value
	return best_value


func _must_discard_ding_que(hand_tiles: Array, ding_que: String) -> bool:
	if ding_que == "":
		return false
	for tile in hand_tiles:
		if str(tile.get("suit", "")) == ding_que:
			return true
	return false


func _estimate_ukeire_from_counts(ting_tiles: Array, visible_counts: Dictionary) -> int:
	var total := 0
	for tile in ting_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		total += maxi(0, 4 - int(visible_counts.get(key, 0)))
	return total


func _build_draw_pool(visible_counts: Dictionary, remaining_hand: Array, active_suits: Array = ["tiao", "tong", "wan"]) -> Array:
	var counts := visible_counts.duplicate(true)
	for tile in remaining_hand:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		counts[key] = int(counts.get(key, 0)) + 1
	var pool: Array = []
	for suit in active_suits:
		for rank in range(1, 10):
			var key := "%s_%d" % [suit, rank]
			var unseen := maxi(0, 4 - int(counts.get(key, 0)))
			if unseen <= 0:
				continue
			pool.append(
				{
					"suit": suit,
					"rank": rank,
					"display_name": _tile_name(suit, rank),
					"remaining": unseen,
				}
			)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("remaining", 0)) != int(b.get("remaining", 0)):
			return int(a.get("remaining", 0)) > int(b.get("remaining", 0))
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	return pool


func _build_visible_tile_counts(player: Dictionary, players: Array) -> Dictionary:
	var counts := {}
	for tile in player.get("hand_tiles", []):
		_add_visible_tile_count(counts, tile)
	for item in players:
		for discard in item.get("discards", []):
			_add_visible_tile_count(counts, discard)
		for meld in item.get("melds", []):
			for tile in meld.get("tiles", []):
				_add_visible_tile_count(counts, tile)
	return counts


func _add_visible_tile_count(counts: Dictionary, tile: Dictionary) -> void:
	var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
	counts[key] = int(counts.get(key, 0)) + 1


func _remove_one_tile(hand_tiles: Array, target_tile: Dictionary) -> Array:
	var removed := false
	var result: Array = []
	for tile in hand_tiles:
		if not removed and str(tile.get("suit", "")) == str(target_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(target_tile.get("rank", 0)):
			removed = true
			continue
		result.append(tile.duplicate(true))
	return result


func _tile_name(suit: String, rank: int) -> String:
	match suit:
		"tiao":
			return "%d条" % rank
		"tong":
			return "%d筒" % rank
		"wan":
			return "%d万" % rank
		_:
			return "%d" % rank
