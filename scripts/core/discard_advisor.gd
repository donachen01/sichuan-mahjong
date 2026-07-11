extends RefCounted

class_name DiscardAdvisor

const StrategyEngineScript := preload("res://scripts/core/strategy_engine.gd")
const LookaheadEvaluatorScript := preload("res://scripts/core/lookahead_evaluator.gd")
const NeijiangDecisionEngineScript := preload("res://scripts/ai/sichuan_decision_engine.gd")

var strategy_engine = StrategyEngineScript.new()
var lookahead_evaluator = LookaheadEvaluatorScript.new()
var neijiang_decision_engine = NeijiangDecisionEngineScript.new()


func analyze_discard_options(player: Dictionary, players: Array, rules_config, hu_checker, shanten_analyzer, risk_analyzer, allow_cheat: bool = false, enable_lookahead: bool = true, ai_config = null) -> Dictionary:
	if rules_config != null and bool(rules_config.is_neijiang_mode()):
		return {}
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	var active_suits: Array = _resolve_active_suits(rules_config)
	var forced_suit: String = _get_forced_discard_suit(player)
	var current_routes: Array = _estimate_fan_routes(hand_tiles, player)
	var current_shanten_info: Dictionary = shanten_analyzer.analyze_hand(
		hand_tiles,
		int(player.get("melds", []).size()),
		bool(rules_config.enable_qi_dui)
	)
	var current_ting_tiles: Array = hu_checker.get_ting_tiles(
		hand_tiles,
		str(player.get("ding_que", "")),
		rules_config,
		int(player.get("melds", []).size()),
		player.get("melds", [])
	)
	var strategy_profile: Dictionary = strategy_engine.build_profile(
		player,
		players,
		int(current_shanten_info.get("best", 8)),
		current_ting_tiles
	)
	var weights: Dictionary = strategy_profile.get("weights", {})
	_apply_ai_tuning_to_weights(weights, ai_config)
	var endgame_absolute_defense: bool = false if ai_config == null else bool(ai_config.endgame_absolute_defense)
	var option_items: Array = []
	var seen_keys := {}

	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		if forced_suit != "" and suit != forced_suit:
			continue

		var key := "%s_%d" % [suit, int(tile.get("rank", 0))]
		if seen_keys.has(key):
			continue
		seen_keys[key] = true

		var remaining_hand := _remove_one_tile(hand_tiles, tile)
		var shanten_info: Dictionary = shanten_analyzer.analyze_hand(
			remaining_hand,
			int(player.get("melds", []).size()),
			bool(rules_config.enable_qi_dui)
		)
		var ting_tiles: Array = hu_checker.get_ting_tiles(
			remaining_hand,
			str(player.get("ding_que", "")),
			rules_config,
			int(player.get("melds", []).size()),
			player.get("melds", [])
		)
		var ukeire: int = _estimate_ukeire(ting_tiles, remaining_hand, players)
		var route_after: Array = _estimate_fan_routes(remaining_hand, player)
		var route_loss: Array = _array_difference(current_routes, route_after)
		var fan_bonus := _fan_route_bonus(route_after)
		var risk_info: Dictionary = risk_analyzer.analyze_discard_risk(tile, int(player.get("seat", -1)), players, hu_checker, rules_config, allow_cheat)
		var shanten_value: int = int(shanten_info.get("best", 8))
		var fast_ting_discard_rank: int = _resolve_fast_ting_discard_rank(tile, hand_tiles, player, players, forced_suit)
		var tempo_score := _build_tempo_score(shanten_value, ukeire, weights)
		var self_seat: int = int(player.get("seat", -1))
		var wait_quality_score := _build_wait_quality_score(ting_tiles, remaining_hand, players, self_seat, weights)
		var fan_value_score := _build_fan_value_score(fan_bonus, route_loss, weights)
		var shape_score := _build_shape_score(remaining_hand, weights)
		var safety_score := _build_safety_score(int(risk_info.get("risk", 0)), weights)
		var pressure_score := _build_pressure_score(tile, risk_info, strategy_profile, weights)
		var self_draw_score := _build_self_draw_score(ting_tiles, remaining_hand, players, self_seat, strategy_profile, ai_config)
		var neijiang_speed_score := _build_neijiang_speed_score(tile, hand_tiles, remaining_hand, shanten_info, ting_tiles, route_after, player, players, strategy_profile, rules_config, ai_config)
		var gui_preserve_score := _build_neijiang_gui_preserve_score(tile, hand_tiles, remaining_hand, route_after, rules_config)
		var flush_commit_score := _build_flush_commit_score(tile, hand_tiles, remaining_hand, player, players, current_routes, route_after, weights)
		var forced_cleanup_score := _build_forced_cleanup_score(tile, hand_tiles, players, strategy_profile, forced_suit, ai_config)
		var global_plan_score := _build_global_plan_score(tile, hand_tiles, remaining_hand, strategy_profile, shanten_info, ting_tiles, route_after, route_loss, risk_info, endgame_absolute_defense, ai_config)
		var probability_profile := estimate_hand_probability_profile(
			remaining_hand,
			ting_tiles,
			players,
			self_seat,
			shanten_value,
			ukeire,
			route_after,
			risk_info,
			strategy_profile,
			ai_config,
			active_suits
		)
		var probability_score: int = int(probability_profile.get("score", 0))
		var heuristic_score: int = tempo_score + wait_quality_score + fan_value_score + shape_score + safety_score + pressure_score + self_draw_score + neijiang_speed_score + gui_preserve_score + flush_commit_score + forced_cleanup_score + global_plan_score
		var score := probability_score + int(round(float(heuristic_score) * 0.42))

		var reason_parts: Array[String] = []
		reason_parts.append("策略 %s" % str(strategy_profile.get("mode_label", "定缺速听")))
		if forced_suit != "" and not (rules_config != null and bool(rules_config.is_neijiang_mode())):
			reason_parts.append("缺门未出尽，必须优先打%s" % _suit_name(forced_suit))
		elif rules_config != null and bool(rules_config.is_neijiang_mode()):
			reason_parts.append("四川定缺后，优先快速成叫")
		reason_parts.append("向听 %d" % maxi(0, int(shanten_info.get("best", 8))))
		reason_parts.append(_fast_ting_rank_reason(fast_ting_discard_rank))
		reason_parts.append("估算胡率 %.1f%%" % (float(probability_profile.get("win_probability", 0.0)) * 100.0))
		if not ting_tiles.is_empty():
			reason_parts.append("听牌面 %s" % _join_tile_names(ting_tiles))
		if ukeire > 0:
			reason_parts.append("综合进张 %d" % ukeire)
		if not route_after.is_empty():
			reason_parts.append("保留番型 %s" % "/".join(route_after))
		if not route_loss.is_empty():
			reason_parts.append("会丢失 %s" % "/".join(route_loss))
		if int(risk_info.get("risk", 0)) >= 35:
			reason_parts.append("危险度 %s" % str(risk_info.get("label", "中危")))

		option_items.append(
			{
				"tile": tile.duplicate(true),
				"tile_name": tile.get("display_name", "?"),
				"tile_key": key,
				"shanten": int(shanten_info.get("best", 8)),
				"fast_ting_discard_rank": fast_ting_discard_rank,
				"ukeire": ukeire,
				"risk": int(risk_info.get("risk", 0)),
				"risk_label": str(risk_info.get("label", "低危")),
				"risk_reasons": risk_info.get("reasons", []),
				"routes_after": route_after,
				"route_loss": route_loss,
				"tempo_score": tempo_score,
				"probability_score": probability_score,
				"win_probability": float(probability_profile.get("win_probability", 0.0)),
				"tenpai_probability": float(probability_profile.get("tenpai_probability", 0.0)),
				"self_draw_probability": float(probability_profile.get("self_draw_probability", 0.0)),
				"discard_hu_probability": float(probability_profile.get("discard_hu_probability", 0.0)),
				"deal_in_probability": float(probability_profile.get("deal_in_probability", 0.0)),
				"expected_value": float(probability_profile.get("expected_value", 0.0)),
				"wait_quality_score": wait_quality_score,
				"fan_value_score": fan_value_score,
				"shape_score": shape_score,
				"safety_score": safety_score,
				"pressure_score": pressure_score,
				"self_draw_score": self_draw_score,
				"neijiang_speed_score": neijiang_speed_score,
				"gui_preserve_score": gui_preserve_score,
				"flush_commit_score": flush_commit_score,
				"forced_cleanup_score": forced_cleanup_score,
				"global_plan_score": global_plan_score,
				"strategy_mode": str(strategy_profile.get("mode_label", "定缺速听")),
				"score": score,
				"reasons": reason_parts,
				"ting_tiles": ting_tiles,
			}
		)

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

	if enable_lookahead and option_items.size() >= 2:
		var candidate_count := 3 if ai_config == null else int(ai_config.lookahead_candidate_count)
		var draw_samples := 10 if ai_config == null else int(ai_config.lookahead_draw_samples)
		option_items = lookahead_evaluator.evaluate_candidates(
			option_items,
			player,
			players,
			rules_config,
			hu_checker,
			shanten_analyzer,
			risk_analyzer,
			self,
			candidate_count,
			draw_samples,
			allow_cheat,
			active_suits
		)

	var danger_tiles: Array = option_items.duplicate(true)
	danger_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("risk", 0)) > int(b.get("risk", 0))
	)

	return {
		"forced_discard_suit": forced_suit,
		"recommended": option_items[0] if not option_items.is_empty() else {},
		"options": option_items,
		"danger_tiles": danger_tiles.slice(0, mini(3, danger_tiles.size())),
		"current_routes": current_routes,
		"strategy_profile": strategy_profile.duplicate(true),
	}


func _build_tempo_score(shanten: int, ukeire: int, weights: Dictionary) -> int:
	var shanten_weight := float(weights.get("shanten_weight", 1.0))
	var ukeire_weight := float(weights.get("ukeire_weight", 1.0))
	return int(round(-float(shanten) * 100.0 * shanten_weight + float(ukeire) * 8.0 * ukeire_weight))


func _apply_ai_tuning_to_weights(weights: Dictionary, ai_config) -> void:
	if ai_config == null:
		return
	var attack := clampi(int(ai_config.attack_tendency), -3, 3)
	var defense := clampi(int(ai_config.defense_tendency), -3, 3)
	var fast_ting := clampi(int(ai_config.fast_ting_priority), 0, 4)
	var self_draw := clampi(int(ai_config.self_draw_priority), 0, 4)
	var attack_factor := 1.0 + float(attack) * 0.08
	var defense_factor := 1.0 + float(defense) * 0.10
	var fast_ting_factor := 1.0 + float(fast_ting) * 0.24
	var self_draw_factor := 1.0 + float(self_draw) * 0.18
	weights["shanten_weight"] = maxf(0.55, float(weights.get("shanten_weight", 1.0)) * attack_factor * fast_ting_factor)
	weights["ukeire_weight"] = maxf(0.55, float(weights.get("ukeire_weight", 1.0)) * attack_factor * fast_ting_factor * (1.0 + float(self_draw) * 0.06))
	weights["wait_weight"] = maxf(0.55, float(weights.get("wait_weight", 1.0)) * attack_factor * self_draw_factor)
	weights["fan_weight"] = maxf(0.55, float(weights.get("fan_weight", 1.0)) * (1.0 + float(attack) * 0.05))
	weights["risk_weight"] = maxf(0.55, float(weights.get("risk_weight", 1.0)) * defense_factor)
	weights["pressure_weight"] = maxf(0.55, float(weights.get("pressure_weight", 1.0)) * defense_factor)


func _build_wait_quality_score(ting_tiles: Array, remaining_hand: Array, players: Array, self_seat: int, weights: Dictionary) -> int:
	if ting_tiles.is_empty():
		return 0
	var wait_weight := float(weights.get("wait_weight", 1.0))
	var visible_counts := _build_visible_tile_counts(remaining_hand, players)
	var remaining_total := 0
	var pattern_bonus := 0
	var must_appear_bonus := 0
	for tile in ting_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		var visible_count := int(visible_counts.get(key, 0))
		remaining_total += maxi(0, 4 - visible_count)
		pattern_bonus += _score_wait_pattern(tile, remaining_hand)
		var must_appear_info := _analyze_must_appear_tile(tile, remaining_hand, players, self_seat, visible_counts)
		must_appear_bonus += int(must_appear_info.get("bonus", 0))
	var wait_count: int = ting_tiles.size()
	var width_bonus: int = 0
	if wait_count >= 4:
		width_bonus = 34
	elif wait_count == 3:
		width_bonus = 20
	elif wait_count == 2:
		width_bonus = 8
	else:
		width_bonus = -22
	var quality := wait_count * 8 + remaining_total * 3 + width_bonus + pattern_bonus + must_appear_bonus
	return int(round(float(quality) * wait_weight))


func _build_neijiang_speed_score(
	tile: Dictionary,
	hand_tiles: Array,
	remaining_hand: Array,
	shanten_info: Dictionary,
	ting_tiles: Array,
	route_after: Array,
	player: Dictionary,
	players: Array,
	strategy_profile: Dictionary,
	rules_config,
	ai_config
) -> int:
	if rules_config == null or not bool(rules_config.is_neijiang_mode()):
		return 0
	var score := 0
	var shanten: int = int(shanten_info.get("best", 8))
	var self_draw_priority: int = 3 if ai_config == null else clampi(int(ai_config.self_draw_priority), 0, 4)
	var big_hand_bias: int = 1 if ai_config == null else clampi(int(ai_config.big_hand_tendency), 0, 4)
	var tile_suit: String = str(tile.get("suit", ""))
	var suit_span_before: Dictionary = _resolve_suit_span_info(hand_tiles)
	var suit_span_after: Dictionary = _resolve_suit_span_info(remaining_hand)
	var active_suits_after: int = int(suit_span_after.get("active_suits", 0))
	var dominant_suit: String = str(suit_span_after.get("dominant_suit", ""))
	var dominant_count: int = int(suit_span_after.get("dominant_count", 0))
	var weak_suit: String = str(suit_span_before.get("weak_suit", ""))
	var weak_count: int = int(suit_span_before.get("weak_count", 0))
	var keeps_ting_routes: bool = route_after.has("七对") or route_after.has("对对胡") or route_after.has("将对")
	if not ting_tiles.is_empty():
		score += 132 + ting_tiles.size() * (16 + self_draw_priority)
		for item in ting_tiles:
			if str(item.get("suit", "")) == "tiao" and int(item.get("rank", 0)) == 2:
				score += 34 + self_draw_priority * 3
		if ting_tiles.size() >= 3:
			score += 24 + self_draw_priority * 2
		elif ting_tiles.size() == 2:
			score += 10 + self_draw_priority
	if shanten <= 1:
		score += 30 + self_draw_priority * 4
	elif shanten == 2:
		score += 10 + self_draw_priority * 2
	var rank := int(tile.get("rank", 0))
	if rank == 1 or rank == 9:
		score += 8
	if tile_suit == "tong" and (rank == 1 or rank == 8 or rank == 9):
		score += 4
	if active_suits_after <= 1 and dominant_count >= 8 and big_hand_bias >= 2:
		score += 14 + big_hand_bias * 3
	elif active_suits_after <= 1 and dominant_count < 8:
		score -= 22
	if weak_suit != "" and weak_count <= 4 and tile_suit == weak_suit:
		score += 24 + self_draw_priority * 2
	if tile_suit != dominant_suit and dominant_count >= 7:
		score += 18 + big_hand_bias * 2
	if tile_suit == dominant_suit and dominant_count >= 7 and not keeps_ting_routes and shanten >= 2:
		score -= 18 + big_hand_bias * 3
	if _is_two_suit_balanced_shape(suit_span_after) and shanten <= 2:
		score += 16 + self_draw_priority * 2
	if _breaks_two_suit_balance(suit_span_before, suit_span_after, tile_suit) and shanten >= 2 and not keeps_ting_routes:
		score -= 20 + self_draw_priority * 2
	score += _build_neijiang_wait_focus_bonus(ting_tiles, remaining_hand, players, int(player.get("seat", -1)), self_draw_priority)
	score += _build_neijiang_table_read_score(tile, hand_tiles, remaining_hand, ting_tiles, route_after, player, players, strategy_profile)
	return score


func _build_neijiang_wait_focus_bonus(ting_tiles: Array, remaining_hand: Array, players: Array, self_seat: int, self_draw_priority: int) -> int:
	if ting_tiles.is_empty():
		return 0
	var visible_counts := _build_visible_tile_counts(remaining_hand, players)
	var score := 0
	for tile in ting_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		var visible_count := int(visible_counts.get(key, 0))
		var live_count := maxi(0, 4 - visible_count)
		score += live_count * (4 + self_draw_priority)
		var must_appear_info := _analyze_must_appear_tile(tile, remaining_hand, players, self_seat, visible_counts)
		if bool(must_appear_info.get("must_appear", false)):
			score += 10 + int(must_appear_info.get("bonus", 0)) / 2
		if str(tile.get("suit", "")) == "tiao" and int(tile.get("rank", 0)) == 2:
			score += 20 + self_draw_priority * 2
	return score


func _build_neijiang_table_read_score(
	tile: Dictionary,
	hand_tiles: Array,
	remaining_hand: Array,
	ting_tiles: Array,
	route_after: Array,
	player: Dictionary,
	players: Array,
	strategy_profile: Dictionary
) -> int:
	var score := 0
	var self_seat: int = int(player.get("seat", -1))
	var hand_state: Dictionary = strategy_profile.get("hand_state", {})
	var keeps_qidui: bool = route_after.has("七对") or bool(hand_state.get("qidui_ready", false))
	var keeps_pung_route: bool = route_after.has("对对胡") or route_after.has("将对")
	var tile_rank: int = int(tile.get("rank", 0))
	var tile_suit: String = str(tile.get("suit", ""))
	if _count_matching_tiles(hand_tiles, tile) >= 2 and not keeps_qidui and not keeps_pung_route:
		var adjacency_count: int = _count_neighbor_links(hand_tiles, tile)
		if adjacency_count <= 0:
			score += 20
		else:
			score += 10
	if not ting_tiles.is_empty():
		for wait_tile in ting_tiles:
			var table_info: Dictionary = _analyze_table_wait_friendliness(wait_tile, players, self_seat)
			score += int(table_info.get("bonus", 0))
			if str(wait_tile.get("suit", "")) == tile_suit and tile_rank == int(wait_tile.get("rank", 0)):
				score -= 6
	if _forms_long_chain(remaining_hand, tile_suit):
		score += 12
	return score


func _build_neijiang_gui_preserve_score(
	tile: Dictionary,
	hand_tiles: Array,
	remaining_hand: Array,
	route_after: Array,
	rules_config
) -> int:
	if rules_config == null or not bool(rules_config.is_neijiang_mode()) or not bool(rules_config.enable_gui):
		return 0
	var before_count: int = _count_matching_tiles(hand_tiles, tile)
	var after_count: int = _count_matching_tiles(remaining_hand, tile)
	var score := 0
	if before_count >= 4:
		score -= 42
	elif before_count == 3 and after_count <= 2:
		score -= 26
	elif before_count == 2 and after_count <= 1 and not route_after.has("七对"):
		score -= 8
	if before_count >= 3 and route_after.has("七对"):
		score -= 10
	return score


func _build_self_draw_score(ting_tiles: Array, remaining_hand: Array, players: Array, self_seat: int, strategy_profile: Dictionary, ai_config) -> int:
	if ai_config == null:
		return 0
	var self_draw_priority: int = clampi(int(ai_config.self_draw_priority), 0, 4)
	if self_draw_priority <= 0:
		return 0
	var visible_counts := _build_visible_tile_counts(remaining_hand, players)
	var broad_wait_bonus: int = ting_tiles.size() * (8 + self_draw_priority * 2)
	var live_tile_bonus: int = 0
	var dingque_bonus: int = 0
	var must_appear_bonus: int = 0
	var unseen_tile_bias: int = 0
	for tile in ting_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		var visible_count := int(visible_counts.get(key, 0))
		var remaining_count := maxi(0, 4 - visible_count)
		live_tile_bonus += remaining_count * (3 + self_draw_priority)
		dingque_bonus += _count_opponents_missing_suit(players, self_seat, str(tile.get("suit", ""))) * 4
		var must_appear_info := _analyze_must_appear_tile(tile, remaining_hand, players, self_seat, visible_counts)
		if bool(must_appear_info.get("must_appear", false)):
			must_appear_bonus += int(must_appear_info.get("bonus", 0)) + 6 + self_draw_priority * 3
		elif visible_count <= 0:
			unseen_tile_bias += 2 + self_draw_priority
		elif visible_count == 1:
			unseen_tile_bias += 2
	var stage_bias: int = 8 if int(strategy_profile.get("round_stage", 0)) <= 1 else 0
	return broad_wait_bonus + live_tile_bonus + dingque_bonus + must_appear_bonus + unseen_tile_bias + stage_bias


func _score_wait_pattern(tile: Dictionary, remaining_hand: Array) -> int:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	var counts := _build_rank_counts_for_suit(remaining_hand, suit)
	var has_left_pair := int(counts.get(rank - 2, 0)) > 0 and int(counts.get(rank - 1, 0)) > 0
	var has_right_pair := int(counts.get(rank + 1, 0)) > 0 and int(counts.get(rank + 2, 0)) > 0
	var has_middle_pair := int(counts.get(rank - 1, 0)) > 0 and int(counts.get(rank + 1, 0)) > 0
	var same_count := int(counts.get(rank, 0))
	if (has_left_pair and rank != 3) or (has_right_pair and rank != 7):
		return 18
	if has_middle_pair or (has_left_pair and rank == 3) or (has_right_pair and rank == 7):
		return 6
	if same_count >= 1:
		return -12
	return -4


func _build_rank_counts_for_suit(hand_tiles: Array, suit: String) -> Dictionary:
	var counts := {}
	for tile in hand_tiles:
		if str(tile.get("suit", "")) != suit:
			continue
		var rank: int = int(tile.get("rank", 0))
		counts[rank] = int(counts.get(rank, 0)) + 1
	return counts


func _resolve_fast_ting_discard_rank(tile: Dictionary, hand_tiles: Array, player: Dictionary, players: Array, forced_suit: String) -> int:
	var suit: String = str(tile.get("suit", ""))
	if forced_suit != "" and suit == forced_suit:
		return 0
	if forced_suit == "" and suit == str(player.get("ding_que", "")):
		return 0
	var protect_advantage_suit := _is_advantage_suit_to_keep(suit, hand_tiles, player, players)
	if _is_isolated_tile(tile, hand_tiles):
		return 11 if protect_advantage_suit else 1
	if _is_edge_taatsu_tile(tile, hand_tiles):
		return 12 if protect_advantage_suit else 2
	if _is_weak_kan_taatsu_tile(tile, hand_tiles):
		return 13 if protect_advantage_suit else 3
	if int(tile.get("rank", 0)) in [1, 9]:
		return 14 if protect_advantage_suit else 4
	if int(tile.get("rank", 0)) in [2, 8]:
		return 15 if protect_advantage_suit else 5
	return 16 if protect_advantage_suit else 6


func _fast_ting_rank_reason(rank: int) -> String:
	match rank:
		0:
			return "同向听优先保留宽叫"
		1:
			return "同向听先拆孤张"
		2:
			return "同向听先拆边搭"
		3:
			return "同向听先拆弱卡搭"
		4:
			return "同向听先出幺九"
		5:
			return "同向听先出二八"
		11, 12, 13, 14, 15, 16:
			return "同向听保留优势门"
		_:
			return "同向听保留高效率结构"


func _is_advantage_suit_to_keep(suit: String, hand_tiles: Array, player: Dictionary, players: Array) -> bool:
	if suit == "" or suit == str(player.get("ding_que", "")):
		return false
	var self_seat: int = int(player.get("seat", -1))
	var opponent_missing_count: int = _count_opponents_missing_suit(players, self_seat, suit)
	if opponent_missing_count < 2:
		return false
	var suit_counts := {"tiao": 0, "tong": 0, "wan": 0}
	for tile in hand_tiles:
		var tile_suit: String = str(tile.get("suit", ""))
		if suit_counts.has(tile_suit):
			suit_counts[tile_suit] = int(suit_counts.get(tile_suit, 0)) + 1
	var suit_count: int = int(suit_counts.get(suit, 0))
	if suit_count < 4:
		return false
	var best_count: int = 0
	for item_suit in suit_counts.keys():
		if item_suit == str(player.get("ding_que", "")):
			continue
		best_count = maxi(best_count, int(suit_counts.get(item_suit, 0)))
	return suit_count >= best_count - 1


func _is_edge_taatsu_tile(tile: Dictionary, hand_tiles: Array) -> bool:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	var counts := _build_rank_counts_for_suit(hand_tiles, suit)
	if rank == 1:
		return int(counts.get(2, 0)) > 0
	if rank == 2:
		return int(counts.get(1, 0)) > 0
	if rank == 8:
		return int(counts.get(9, 0)) > 0
	if rank == 9:
		return int(counts.get(8, 0)) > 0
	return false


func _is_weak_kan_taatsu_tile(tile: Dictionary, hand_tiles: Array) -> bool:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	var counts := _build_rank_counts_for_suit(hand_tiles, suit)
	var has_left_gap := int(counts.get(rank - 2, 0)) > 0
	var has_right_gap := int(counts.get(rank + 2, 0)) > 0
	var has_direct_neighbor := int(counts.get(rank - 1, 0)) > 0 or int(counts.get(rank + 1, 0)) > 0
	if has_direct_neighbor:
		return false
	if rank in [1, 3, 7, 9] and (has_left_gap or has_right_gap):
		return true
	return (has_left_gap or has_right_gap) and int(counts.get(rank, 0)) <= 1


func _build_fan_value_score(fan_bonus: int, route_loss: Array, weights: Dictionary) -> int:
	var fan_weight := float(weights.get("fan_weight", 1.0))
	var route_loss_weight := float(weights.get("route_loss_weight", 1.0))
	var score := float(fan_bonus) * fan_weight - float(route_loss.size() * 18) * route_loss_weight
	return int(round(score))


func _build_shape_score(remaining_hand: Array, weights: Dictionary) -> int:
	var shape_weight := float(weights.get("shape_weight", 1.0))
	var adjacency_pairs := 0
	var close_pairs := 0
	var isolated_tiles := 0
	var suit_groups := {"tiao": [], "tong": [], "wan": []}
	for tile in remaining_hand:
		var suit := str(tile.get("suit", ""))
		if suit_groups.has(suit):
			suit_groups[suit].append(int(tile.get("rank", 0)))
	for suit in suit_groups.keys():
		var ranks: Array = suit_groups[suit]
		ranks.sort()
		for index in range(ranks.size()):
			var rank := int(ranks[index])
			var has_neighbor := false
			for other_index in range(ranks.size()):
				if index == other_index:
					continue
				var other_rank := int(ranks[other_index])
				var delta: int = rank - other_rank
				if delta < 0:
					delta = -delta
				if delta == 1:
					adjacency_pairs += 1
					has_neighbor = true
				elif delta == 2:
					close_pairs += 1
					has_neighbor = true
			if not has_neighbor:
				isolated_tiles += 1
	var raw := adjacency_pairs * 4 + close_pairs * 2 - isolated_tiles * 6
	return int(round(float(raw) * shape_weight))


func _build_safety_score(risk: int, weights: Dictionary) -> int:
	var risk_weight := float(weights.get("risk_weight", 1.0))
	return -int(round(float(risk) * 2.4 * risk_weight))


func _build_pressure_score(tile: Dictionary, risk_info: Dictionary, strategy_profile: Dictionary, weights: Dictionary) -> int:
	var pressure_weight := float(weights.get("pressure_weight", 1.0))
	var threat_level := int(strategy_profile.get("threat_level", 0))
	var round_stage := int(strategy_profile.get("round_stage", 1))
	var score := 0
	if round_stage >= 2 and int(risk_info.get("risk", 0)) >= 45:
		score -= 12 + threat_level * 4
	if round_stage >= 1 and int(tile.get("rank", 0)) in [3, 4, 5, 6, 7]:
		score -= 4 + threat_level * 2
	if int(risk_info.get("risk", 0)) <= 12:
		score += 8
	return int(round(float(score) * pressure_weight))


func _build_flush_commit_score(
	tile: Dictionary,
	hand_tiles: Array,
	remaining_hand: Array,
	player: Dictionary,
	players: Array,
	current_routes: Array,
	route_after: Array,
	weights: Dictionary
) -> int:
	var melds: Array = player.get("melds", [])
	var total_suit_info: Dictionary = _resolve_total_suit_info(hand_tiles, melds)
	if int(total_suit_info.get("active_suits", 0)) >= 2 and int(total_suit_info.get("meld_active_suits", 0)) >= 2:
		return 0
	var dominant_info: Dictionary = _resolve_total_suit_info(hand_tiles, melds)
	var dominant_suit: String = str(dominant_info.get("suit", ""))
	var dominant_count: int = int(dominant_info.get("count", 0))
	var active_suits: int = int(dominant_info.get("active_suits", 0))
	if dominant_suit.is_empty():
		return 0

	var score: int = 0
	var tile_suit: String = str(tile.get("suit", ""))
	var route_weight: float = maxf(0.8, float(weights.get("fan_weight", 1.0)))
	var has_clear_route: bool = current_routes.has("清一色") or current_routes.has("做%s清" % _suit_name(dominant_suit))
	var remaining_info: Dictionary = _resolve_total_suit_info(remaining_hand, melds)
	var remaining_dominant_count: int = int(remaining_info.get("count", 0))
	var opponent_missing_count: int = _count_opponents_missing_suit(players, int(player.get("seat", -1)), dominant_suit)

	if has_clear_route or dominant_count >= 6:
		if tile_suit == dominant_suit:
			score -= int(round((42.0 + float(opponent_missing_count) * 6.0) * route_weight))
			if active_suits <= 2 and dominant_count >= 7:
				score -= int(round(22.0 * route_weight))
		else:
			score += int(round((18.0 + float(opponent_missing_count) * 4.0) * route_weight))
	if remaining_dominant_count >= dominant_count and tile_suit != dominant_suit:
		score += int(round(12.0 * route_weight))
	if route_after.has("清一色"):
		score += int(round(16.0 * route_weight))
	return score


func _build_forced_cleanup_score(
	tile: Dictionary,
	hand_tiles: Array,
	players: Array,
	strategy_profile: Dictionary,
	forced_suit: String,
	ai_config
) -> int:
	if forced_suit.is_empty() or str(tile.get("suit", "")) != forced_suit:
		return 0
	var round_stage: int = int(strategy_profile.get("round_stage", 0))
	var same_count: int = _count_matching_tiles(hand_tiles, tile)
	var visible_count: int = _count_visible_tile(tile, players)
	var cleanup_bias: int = 2 if ai_config == null else int(ai_config.forced_cleanup_tendency)
	var score: int = 0
	if round_stage == 0:
		score += 82 + cleanup_bias * 8
		if same_count <= 1:
			score += 22 + cleanup_bias * 4
		else:
			score -= 10 + cleanup_bias * 4
		if int(tile.get("rank", 0)) in [1, 9]:
			score += 12
		elif int(tile.get("rank", 0)) in [2, 8]:
			score += 6
		if visible_count <= 0:
			score += 12 + cleanup_bias * 2
		elif visible_count >= 2:
			score -= 8
	else:
		score += 30 + cleanup_bias * 5
		if same_count <= 1:
			score += 8 + cleanup_bias * 2
		if visible_count <= 1 and round_stage == 1:
			score += 6
	return score


func _build_global_plan_score(
	tile: Dictionary,
	hand_tiles: Array,
	remaining_hand: Array,
	strategy_profile: Dictionary,
	shanten_info: Dictionary,
	ting_tiles: Array,
	route_after: Array,
	route_loss: Array,
	risk_info: Dictionary,
	endgame_absolute_defense: bool,
	ai_config
) -> int:
	var score: int = 0
	var hand_state: Dictionary = strategy_profile.get("hand_state", {})
	var dingque_state: Dictionary = strategy_profile.get("dingque_state", {})
	var opponent_state: Dictionary = strategy_profile.get("opponent_state", {})
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	var mode_label: String = str(strategy_profile.get("mode_label", "定缺速听"))
	var top_threat_profile: Dictionary = opponent_state.get("top_threat_profile", {})
	var big_hand_bias: int = 1 if ai_config == null else int(ai_config.big_hand_tendency)
	var read_bias: int = 2 if ai_config == null else int(ai_config.opponent_read_tendency)
	var shanten: int = int(shanten_info.get("best", 8))
	var wait_count: int = ting_tiles.size()
	var tile_rank: int = int(tile.get("rank", 0))
	var tile_suit: String = str(tile.get("suit", ""))
	var pair_like_count: int = _count_matching_tiles(hand_tiles, tile)
	var remaining_pair_like_count: int = _count_matching_tiles(remaining_hand, tile)
	var isolated_before: bool = _is_isolated_tile(tile, hand_tiles)
	var isolated_after: bool = _has_isolated_suit_cluster(remaining_hand, tile_suit)

	if round_stage == 0:
		if tile_rank in [1, 9] and isolated_before:
			score += 26
		elif isolated_before:
			score += 14
		if pair_like_count >= 2 and str(hand_state.get("hand_label", "")) == "进攻型":
			score -= 12
		elif pair_like_count >= 2 and str(hand_state.get("hand_label", "")) == "摆烂型":
			score += 8
	if bool(dingque_state.get("is_two_same_self_diff", false)):
		if _has_big_route(route_after):
			score += 14 + big_hand_bias * 6
		if not route_loss.is_empty():
			score -= 10 + big_hand_bias * 3
	if bool(dingque_state.get("is_three_same", false)):
		score += int(recommended_speed_bias(round_stage, risk_info, route_after))
		if _has_big_route(route_after) and round_stage <= 1:
			score -= 12 + big_hand_bias * 5
	if round_stage == 1:
		if int(opponent_state.get("fast_call_count", 0)) >= 1 and int(risk_info.get("risk", 0)) >= 35:
			score += 12 + read_bias * 3
		if int(opponent_state.get("silent_big_hand_count", 0)) >= 1 and tile_rank in [4, 5, 6]:
			score += 4 + read_bias * 3
		if int(opponent_state.get("flush_watch_count", 0)) >= 1 and tile_suit == str(top_threat_profile.get("dangerous_suit", "")):
			score += 8 + read_bias * 4
		if int(opponent_state.get("pung_watch_count", 0)) >= 1 and tile_rank in [2, 5, 8]:
			score += 4 + read_bias * 3
		if str(hand_state.get("hand_label", "")) == "进攻型" and _has_big_route(route_after) and int(opponent_state.get("fast_call_count", 0)) <= 0:
			score += 6 + big_hand_bias * 3
		if route_after.is_empty() and not route_loss.is_empty() and bool(hand_state.get("big_hand_focus", false)) and int(opponent_state.get("fast_call_count", 0)) >= 1:
			score += 10 + read_bias * 2
	if round_stage >= 2:
		score += 24 if int(risk_info.get("risk", 0)) <= 12 else -int(risk_info.get("risk", 0)) / 2
		if mode_label in ["全守", "防守平衡"]:
			score += 18
		if not route_loss.is_empty():
			score += 6
		if int(opponent_state.get("flush_watch_count", 0)) >= 1 and tile_suit == str(top_threat_profile.get("dangerous_suit", "")):
			score += 12 + read_bias * 3
		if endgame_absolute_defense:
			var risk_value: int = int(risk_info.get("risk", 0))
			if risk_value >= 60:
				score -= 160
			elif risk_value >= 35:
				score -= 72
			elif risk_value <= 12:
				score += 36
	if shanten <= 0 and wait_count > 0:
		if wait_count >= 3:
			score += 28
		elif wait_count == 2:
			score += 12
		else:
			score -= 30 if round_stage >= 2 else 18
		if not route_after.is_empty() and wait_count <= 1:
			score -= 20 if round_stage >= 2 else 10
		if round_stage >= 2 and not route_loss.is_empty() and wait_count <= 2:
			score -= 18
	if pair_like_count >= 2 and remaining_pair_like_count <= 0 and str(hand_state.get("hand_label", "")) != "摆烂型":
		score -= 10
	if isolated_after and round_stage <= 1:
		score -= 6
	if round_stage == 0 and not bool(dingque_state.get("is_three_same", false)) and _has_big_route(route_after) and pair_like_count >= 2:
		score -= 6 + big_hand_bias * 2
	return score


func recommended_speed_bias(round_stage: int, risk_info: Dictionary, route_after: Array) -> float:
	var score: float = 0.0
	if round_stage <= 1:
		score += 18.0
	if not route_after.is_empty():
		score -= 8.0
	if int(risk_info.get("risk", 0)) >= 35:
		score += 6.0
	return score


func _remove_one_tile(hand_tiles: Array, target_tile: Dictionary) -> Array:
	var removed := false
	var result: Array = []
	for tile in hand_tiles:
		if not removed and str(tile.get("suit", "")) == str(target_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(target_tile.get("rank", 0)):
			removed = true
			continue
		result.append(tile.duplicate(true))
	return result


func _estimate_ukeire(ting_tiles: Array, remaining_hand: Array, players: Array) -> int:
	if ting_tiles.is_empty():
		return 0
	var visible_counts := _build_visible_tile_counts(remaining_hand, players)
	var total := 0
	for tile in ting_tiles:
		var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
		total += maxi(0, 4 - int(visible_counts.get(key, 0)))
	return total


func estimate_hand_probability_profile(
	remaining_hand: Array,
	ting_tiles: Array,
	players: Array,
	self_seat: int,
	shanten: int,
	ukeire: int,
	route_after: Array,
	risk_info: Dictionary,
	strategy_profile: Dictionary,
	ai_config,
	active_suits: Array = ["tiao", "tong", "wan"]
) -> Dictionary:
	var visible_counts := _build_visible_tile_counts(remaining_hand, players)
	var unseen_total: int = _estimate_unseen_total_count(visible_counts, active_suits)
	var self_draw_horizon: int = _estimate_self_draw_horizon(strategy_profile, players)
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	var tenpai_probability: float = _estimate_tenpai_probability(shanten, ukeire, unseen_total, self_draw_horizon)
	var self_draw_probability: float = 0.0
	var discard_hu_probability: float = 0.0
	var combined_wait_probability: float = 0.0
	if not ting_tiles.is_empty():
		var wait_result := _estimate_wait_win_probability(
			ting_tiles,
			remaining_hand,
			players,
			self_seat,
			strategy_profile,
			visible_counts,
			unseen_total,
			self_draw_horizon
		)
		self_draw_probability = float(wait_result.get("self_draw_probability", 0.0))
		discard_hu_probability = float(wait_result.get("discard_hu_probability", 0.0))
		combined_wait_probability = float(wait_result.get("combined_probability", 0.0))
	else:
		combined_wait_probability = 0.0
	var route_multiplier: float = _estimate_route_value_multiplier(route_after, ai_config)
	var risk_value: float = float(int(risk_info.get("risk", 0))) / 100.0
	var deal_in_probability: float = clampf(risk_value * [0.22, 0.34, 0.48][clampi(round_stage, 0, 2)], 0.0, 0.88)
	var win_probability: float = clampf(tenpai_probability * combined_wait_probability, 0.0, 0.985)
	var expected_value: float = win_probability * route_multiplier - deal_in_probability * (1.10 + float(round_stage) * 0.16)
	var score: int = int(round(expected_value * 280.0 + win_probability * 120.0 - deal_in_probability * 90.0))
	return {
		"tenpai_probability": tenpai_probability,
		"self_draw_probability": self_draw_probability,
		"discard_hu_probability": discard_hu_probability,
		"wait_probability": combined_wait_probability,
		"win_probability": win_probability,
		"deal_in_probability": deal_in_probability,
		"expected_value": expected_value,
		"score": score,
	}


func _estimate_tenpai_probability(shanten: int, ukeire: int, unseen_total: int, self_draw_horizon: int) -> float:
	if shanten <= 0:
		return 1.0
	if unseen_total <= 0 or self_draw_horizon <= 0 or ukeire <= 0:
		return 0.0
	var single_draw_hit: float = clampf(float(ukeire) / float(unseen_total), 0.0, 0.92)
	var horizon_hit: float = 1.0 - pow(1.0 - single_draw_hit, float(self_draw_horizon))
	if shanten == 1:
		return clampf(horizon_hit, 0.0, 0.92)
	if shanten == 2:
		return clampf(pow(horizon_hit, 1.35) * 0.72, 0.0, 0.80)
	if shanten == 3:
		return clampf(pow(horizon_hit, 1.7) * 0.42, 0.0, 0.55)
	return clampf(pow(horizon_hit, 2.0) * 0.24, 0.0, 0.35)


func _estimate_wait_win_probability(
	ting_tiles: Array,
	remaining_hand: Array,
	players: Array,
	self_seat: int,
	strategy_profile: Dictionary,
	visible_counts: Dictionary,
	unseen_total: int,
	self_draw_horizon: int
) -> Dictionary:
	var self_miss_product: float = 1.0
	var discard_miss_product: float = 1.0
	for tile in ting_tiles:
		var wait_profile := _estimate_tile_wait_probability(
			tile,
			remaining_hand,
			players,
			self_seat,
			strategy_profile,
			visible_counts,
			unseen_total,
			self_draw_horizon
		)
		self_miss_product *= 1.0 - float(wait_profile.get("self_draw_probability", 0.0))
		discard_miss_product *= 1.0 - float(wait_profile.get("discard_probability", 0.0))
	var self_draw_probability: float = clampf(1.0 - self_miss_product, 0.0, 0.98)
	var discard_hu_probability: float = clampf(1.0 - discard_miss_product, 0.0, 0.98)
	var combined_probability: float = clampf(
		self_draw_probability + discard_hu_probability - self_draw_probability * discard_hu_probability,
		0.0,
		0.985
	)
	return {
		"self_draw_probability": self_draw_probability,
		"discard_hu_probability": discard_hu_probability,
		"combined_probability": combined_probability,
	}


func _estimate_tile_wait_probability(
	tile: Dictionary,
	remaining_hand: Array,
	players: Array,
	self_seat: int,
	strategy_profile: Dictionary,
	visible_counts: Dictionary,
	unseen_total: int,
	self_draw_horizon: int
) -> Dictionary:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	var unseen_count: int = maxi(0, 4 - _get_visible_count_for_rank(visible_counts, suit, rank))
	if unseen_count <= 0 or unseen_total <= 0:
		return {"self_draw_probability": 0.0, "discard_probability": 0.0}
	var base_draw_hit: float = clampf(float(unseen_count) / float(unseen_total), 0.0, 0.85)
	var self_draw_probability: float = 1.0 - pow(1.0 - base_draw_hit, float(self_draw_horizon))
	var pattern_factor: float = _resolve_wait_pattern_probability_factor(tile, remaining_hand)
	var must_appear_info := _analyze_must_appear_tile(tile, remaining_hand, players, self_seat, visible_counts)
	var certainty_floor: float = _resolve_must_appear_probability_floor(must_appear_info)
	self_draw_probability = clampf(self_draw_probability * pattern_factor, 0.0, 0.95)
	var discard_probability: float = _estimate_forced_discard_probability(tile, players, self_seat, strategy_profile)
	var table_info: Dictionary = _analyze_table_wait_friendliness(tile, players, self_seat)
	discard_probability = clampf(discard_probability + float(table_info.get("probability_bonus", 0.0)), 0.0, 0.95)
	if certainty_floor > 0.0:
		if "花色牌量锁死" in must_appear_info.get("reasons", []):
			self_draw_probability = maxf(self_draw_probability, certainty_floor * 0.58)
		else:
			discard_probability = maxf(discard_probability, certainty_floor * 0.62)
	return {
		"self_draw_probability": self_draw_probability,
		"discard_probability": clampf(discard_probability, 0.0, 0.95),
	}


func _resolve_wait_pattern_probability_factor(tile: Dictionary, remaining_hand: Array) -> float:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	var counts := _build_rank_counts_for_suit(remaining_hand, suit)
	var has_left_pair := int(counts.get(rank - 2, 0)) > 0 and int(counts.get(rank - 1, 0)) > 0
	var has_right_pair := int(counts.get(rank + 1, 0)) > 0 and int(counts.get(rank + 2, 0)) > 0
	var has_middle_pair := int(counts.get(rank - 1, 0)) > 0 and int(counts.get(rank + 1, 0)) > 0
	var same_count := int(counts.get(rank, 0))
	if (has_left_pair and rank != 3) or (has_right_pair and rank != 7):
		return 1.18
	if has_middle_pair or (has_left_pair and rank == 3) or (has_right_pair and rank == 7):
		return 0.96
	if same_count >= 1:
		return 0.72
	return 0.86


func _resolve_must_appear_probability_floor(must_appear_info: Dictionary) -> float:
	var reasons: Array = must_appear_info.get("reasons", [])
	if reasons.is_empty():
		return 0.0
	var floor_value: float = 0.0
	if reasons.has("断张锁死"):
		floor_value = maxf(floor_value, 0.70)
	if reasons.has("花色牌量锁死"):
		floor_value = maxf(floor_value, 0.78)
	if reasons.has("对手必打"):
		floor_value = maxf(floor_value, 0.66)
	if reasons.size() >= 2:
		floor_value += 0.10
	return clampf(floor_value, 0.0, 0.94)


func _estimate_forced_discard_probability(tile: Dictionary, players: Array, self_seat: int, strategy_profile: Dictionary) -> float:
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	var suit: String = str(tile.get("suit", ""))
	var miss_probability: float = 1.0
	for player in players:
		var seat: int = int(player.get("seat", -1))
		if seat == self_seat or bool(player.get("has_won", false)):
			continue
		var opponent_probability: float = 0.0
		if str(player.get("ding_que", "")) == suit:
			opponent_probability = [0.28, 0.46, 0.68][clampi(round_stage, 0, 2)]
		elif _is_opponent_single_track_forced_offsuit(player, suit):
			opponent_probability = [0.10, 0.18, 0.28][clampi(round_stage, 0, 2)]
		if opponent_probability <= 0.0:
			continue
		miss_probability *= 1.0 - opponent_probability
	return clampf(1.0 - miss_probability, 0.0, 0.92)


func _analyze_table_wait_friendliness(tile: Dictionary, players: Array, self_seat: int) -> Dictionary:
	var same_tile_discards: int = 0
	var predecessor_discards: int = 0
	var successor_missing_suit: int = 0
	var predecessor_seat: int = _previous_seat(self_seat)
	var successor_seat: int = _next_seat(self_seat)
	var tile_suit: String = str(tile.get("suit", ""))
	var tile_rank: int = int(tile.get("rank", 0))
	for player in players:
		var seat: int = int(player.get("seat", -1))
		if seat == self_seat or bool(player.get("has_won", false)):
			continue
		for discard in player.get("discards", []):
			if str(discard.get("suit", "")) == tile_suit and int(discard.get("rank", 0)) == tile_rank:
				same_tile_discards += 1
				if seat == predecessor_seat:
					predecessor_discards += 1
		if seat == successor_seat and str(player.get("ding_que", "")) == tile_suit:
			successor_missing_suit += 1
	var probability_bonus: float = 0.0
	var bonus: int = 0
	if same_tile_discards >= 1:
		probability_bonus += 0.03 * float(same_tile_discards)
		bonus += 6 * same_tile_discards
	if predecessor_discards >= 1:
		probability_bonus += 0.06
		bonus += 14
	if successor_missing_suit >= 1:
		probability_bonus += 0.03
		bonus += 8
	return {
		"probability_bonus": clampf(probability_bonus, 0.0, 0.18),
		"bonus": clampi(bonus, 0, 30),
	}


func _estimate_route_value_multiplier(route_after: Array, ai_config) -> float:
	var value: float = 1.0
	var big_hand_bias: float = 0.0 if ai_config == null else float(int(ai_config.big_hand_tendency)) * 0.04
	for route in route_after:
		match str(route):
			"清一色":
				value += 0.34 + big_hand_bias
			"七对":
				value += 0.26 + big_hand_bias * 0.8
			"对对胡":
				value += 0.18 + big_hand_bias * 0.6
			"将对":
				value += 0.16
			"带幺九":
				value += 0.12
			_:
				value += 0.05
	return clampf(value, 1.0, 2.1)


func _estimate_self_draw_horizon(strategy_profile: Dictionary, players: Array) -> int:
	var round_stage: int = int(strategy_profile.get("round_stage", 1))
	var active_players: int = 0
	for player in players:
		if not bool(player.get("has_won", false)):
			active_players += 1
	var max_discards: int = 0
	for player in players:
		max_discards = maxi(max_discards, int(player.get("discards", []).size()))
	var stage_horizon: int = int([5, 3, 2][clampi(round_stage, 0, 2)])
	if active_players <= 2:
		stage_horizon += 1
	if max_discards <= 5:
		stage_horizon += 1
	return clampi(stage_horizon, 1, 7)


func _estimate_unseen_total_count(visible_counts: Dictionary, active_suits: Array = ["tiao", "tong", "wan"]) -> int:
	var unseen_total: int = 0
	for suit in active_suits:
		for rank in range(1, 10):
			unseen_total += maxi(0, 4 - _get_visible_count_for_rank(visible_counts, suit, rank))
	return unseen_total


func _analyze_must_appear_tile(tile: Dictionary, remaining_hand: Array, players: Array, self_seat: int, visible_counts: Dictionary = {}) -> Dictionary:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	if suit not in ["tiao", "tong", "wan"] or rank < 1 or rank > 9:
		return {"must_appear": false, "bonus": 0, "reasons": []}
	var counts := visible_counts if not visible_counts.is_empty() else _build_visible_tile_counts(remaining_hand, players)
	var visible_count: int = _get_visible_count_for_rank(counts, suit, rank)
	var unseen_count: int = maxi(0, 4 - visible_count)
	if unseen_count <= 0:
		return {"must_appear": false, "bonus": 0, "reasons": []}

	var reasons: Array[String] = []
	var bonus: int = 0
	if _is_must_appear_by_broken_neighbors(tile, counts):
		reasons.append("断张锁死")
		bonus += 20
	if _is_must_appear_by_dingque_lock(tile, players, self_seat, counts):
		reasons.append("花色牌量锁死")
		bonus += 24
	if _is_must_appear_by_forced_opponent_discard(tile, players, self_seat, counts):
		reasons.append("对手必打")
		bonus += 12
	if reasons.size() >= 2:
		bonus += 8
	return {
		"must_appear": not reasons.is_empty(),
		"bonus": bonus,
		"reasons": reasons,
	}


func _is_must_appear_by_broken_neighbors(tile: Dictionary, visible_counts: Dictionary) -> bool:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	if suit not in ["tiao", "tong", "wan"] or rank < 1 or rank > 9:
		return false
	var left_broken: bool = rank > 1 and _is_rank_fully_exposed(visible_counts, suit, rank - 1)
	var right_broken: bool = rank < 9 and _is_rank_fully_exposed(visible_counts, suit, rank + 1)
	if rank == 2 and left_broken:
		return true
	if rank == 8 and right_broken:
		return true
	return left_broken and right_broken


func _is_must_appear_by_dingque_lock(tile: Dictionary, players: Array, self_seat: int, visible_counts: Dictionary) -> bool:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	var unseen_count: int = maxi(0, 4 - _get_visible_count_for_rank(visible_counts, suit, rank))
	if unseen_count <= 0:
		return false
	var holder_count: int = 0
	for player in players:
		if bool(player.get("has_won", false)):
			continue
		var player_suit: String = str(player.get("ding_que", ""))
		if player_suit != suit:
			holder_count += 1
	if holder_count <= 1:
		return true
	var self_player := _find_player_by_seat(players, self_seat)
	if not self_player.is_empty() and str(self_player.get("ding_que", "")) == suit:
		return holder_count <= 2
	return false


func _is_must_appear_by_forced_opponent_discard(tile: Dictionary, players: Array, self_seat: int, visible_counts: Dictionary) -> bool:
	var suit: String = str(tile.get("suit", ""))
	var rank: int = int(tile.get("rank", 0))
	if maxi(0, 4 - _get_visible_count_for_rank(visible_counts, suit, rank)) <= 0:
		return false
	for player in players:
		var seat: int = int(player.get("seat", -1))
		if seat == self_seat or bool(player.get("has_won", false)):
			continue
		if str(player.get("ding_que", "")) == suit:
			return true
		if _is_opponent_single_track_forced_offsuit(player, suit):
			return true
	return false


func _is_opponent_single_track_forced_offsuit(opponent: Dictionary, suit: String) -> bool:
	var melds: Array = opponent.get("melds", [])
	if melds.size() < 2:
		return false
	var dominant_suit: String = _resolve_meld_dominant_suit(melds)
	if dominant_suit == "" or dominant_suit == suit:
		return false
	var off_suit_discards: int = 0
	for discard in opponent.get("discards", []):
		if str(discard.get("suit", "")) == suit:
			off_suit_discards += 1
	return off_suit_discards >= 2


func _resolve_meld_dominant_suit(melds: Array) -> String:
	var suit_counts := {}
	for meld in melds:
		for tile in meld.get("tiles", []):
			var suit: String = str(tile.get("suit", ""))
			if suit == "":
				continue
			suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	var best_suit := ""
	var best_count := 0
	for suit in suit_counts.keys():
		if int(suit_counts[suit]) > best_count:
			best_count = int(suit_counts[suit])
			best_suit = str(suit)
	return best_suit


func _is_rank_fully_exposed(visible_counts: Dictionary, suit: String, rank: int) -> bool:
	return _get_visible_count_for_rank(visible_counts, suit, rank) >= 4


func _get_visible_count_for_rank(visible_counts: Dictionary, suit: String, rank: int) -> int:
	return int(visible_counts.get("%s_%d" % [suit, rank], 0))


func _find_player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if int(player.get("seat", -1)) == seat:
			return player
	return {}


func _build_visible_tile_counts(remaining_hand: Array, players: Array) -> Dictionary:
	var counts := {}
	for tile in remaining_hand:
		_add_visible_tile_count(counts, tile)
	for player in players:
		for discard in player.get("discards", []):
			_add_visible_tile_count(counts, discard)
		for meld in player.get("melds", []):
			for tile in meld.get("tiles", []):
				_add_visible_tile_count(counts, tile)
	return counts


func _add_visible_tile_count(counts: Dictionary, tile: Dictionary) -> void:
	var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
	counts[key] = int(counts.get(key, 0)) + 1


func _estimate_fan_routes(hand_tiles: Array, player: Dictionary) -> Array:
	var routes: Array[String] = []
	var melds: Array = player.get("melds", [])
	var suit_counts := {"tiao": 0, "tong": 0, "wan": 0}
	var pair_count := 0
	var triplet_count := 0
	var all_258 := true
	var terminal_count := 0
	var tile_counts := {}

	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		if suit_counts.has(suit):
			suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
		if int(tile.get("rank", 0)) not in [2, 5, 8]:
			all_258 = false
		if int(tile.get("rank", 0)) in [1, 9]:
			terminal_count += 1
		var key := "%s_%d" % [suit, int(tile.get("rank", 0))]
		tile_counts[key] = int(tile_counts.get(key, 0)) + 1

	for meld in melds:
		for tile in meld.get("tiles", []):
			var meld_suit: String = str(tile.get("suit", ""))
			if suit_counts.has(meld_suit):
				suit_counts[meld_suit] = int(suit_counts.get(meld_suit, 0)) + 1
			if int(tile.get("rank", 0)) not in [2, 5, 8]:
				all_258 = false
			if int(tile.get("rank", 0)) in [1, 9]:
				terminal_count += 1

	for key in tile_counts.keys():
		var count: int = int(tile_counts[key])
		if count >= 2:
			pair_count += 1
		if count >= 3:
			triplet_count += 1

	var active_suits := 0
	var dominant_suit := ""
	var dominant_count := 0
	for suit in suit_counts.keys():
		var count: int = int(suit_counts[suit])
		if count > 0:
			active_suits += 1
		if count > dominant_count:
			dominant_count = count
			dominant_suit = str(suit)

	var combined_tile_count: int = hand_tiles.size()
	for meld in melds:
		combined_tile_count += (meld.get("tiles", []) as Array).size()
	if active_suits <= 1 or dominant_count >= maxi(0, combined_tile_count - 2):
		routes.append("清一色")
	if melds.is_empty() and pair_count >= 4:
		routes.append("七对")
	if triplet_count >= 2 or pair_count >= 5:
		routes.append("对对胡")
	if terminal_count >= 5:
		routes.append("带幺九")
	if all_258 and (triplet_count >= 1 or pair_count >= 4):
		routes.append("将对")
	if routes.is_empty() and dominant_suit != "" and active_suits == 2 and dominant_count >= maxi(7, combined_tile_count - 3):
		routes.append("做%s清" % _suit_name(dominant_suit))
	return routes


func _resolve_dominant_suit_info(hand_tiles: Array) -> Dictionary:
	var suit_counts := {"tiao": 0, "tong": 0, "wan": 0}
	var active_suits: int = 0
	var dominant_suit: String = ""
	var dominant_count: int = 0
	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		if suit_counts.has(suit):
			suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	for suit in suit_counts.keys():
		var count: int = int(suit_counts.get(suit, 0))
		if count > 0:
			active_suits += 1
		if count > dominant_count:
			dominant_count = count
			dominant_suit = str(suit)
	return {
		"suit": dominant_suit,
		"count": dominant_count,
		"active_suits": active_suits,
	}


func _resolve_total_suit_info(hand_tiles: Array, melds: Array) -> Dictionary:
	var suit_counts := {"tiao": 0, "tong": 0, "wan": 0}
	var meld_suits := {}
	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		if suit_counts.has(suit):
			suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	for meld in melds:
		for tile in meld.get("tiles", []):
			var suit: String = str(tile.get("suit", ""))
			if suit_counts.has(suit):
				suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
				meld_suits[suit] = true
	var active_suits: int = 0
	var dominant_suit: String = ""
	var dominant_count: int = 0
	for suit in suit_counts.keys():
		var count: int = int(suit_counts.get(suit, 0))
		if count > 0:
			active_suits += 1
		if count > dominant_count:
			dominant_count = count
			dominant_suit = str(suit)
	return {
		"suit": dominant_suit,
		"count": dominant_count,
		"active_suits": active_suits,
		"meld_active_suits": meld_suits.size(),
	}


func _resolve_suit_span_info(hand_tiles: Array) -> Dictionary:
	var suit_counts := {"tiao": 0, "tong": 0, "wan": 0}
	var active_suits := []
	var dominant_suit := ""
	var dominant_count := -1
	var weak_suit := ""
	var weak_count := 99
	for tile in hand_tiles:
		var suit: String = str(tile.get("suit", ""))
		if suit_counts.has(suit):
			suit_counts[suit] = int(suit_counts.get(suit, 0)) + 1
	for suit in suit_counts.keys():
		var count: int = int(suit_counts.get(suit, 0))
		if count <= 0:
			continue
		active_suits.append(suit)
		if count > dominant_count:
			dominant_count = count
			dominant_suit = suit
		if count < weak_count:
			weak_count = count
			weak_suit = suit
	if weak_count == 99:
		weak_count = 0
	return {
		"counts": suit_counts,
		"active_suits": active_suits.size(),
		"dominant_suit": dominant_suit,
		"dominant_count": maxi(0, dominant_count),
		"weak_suit": weak_suit,
		"weak_count": weak_count,
		"spread": maxi(0, int(dominant_count) - int(weak_count)),
	}


func _is_two_suit_balanced_shape(suit_span_info: Dictionary) -> bool:
	if int(suit_span_info.get("active_suits", 0)) != 2:
		return false
	var dominant_count: int = int(suit_span_info.get("dominant_count", 0))
	var weak_count: int = int(suit_span_info.get("weak_count", 0))
	return dominant_count >= 5 and weak_count >= 4 and dominant_count - weak_count <= 3


func _breaks_two_suit_balance(before_info: Dictionary, after_info: Dictionary, discarded_suit: String) -> bool:
	if int(before_info.get("active_suits", 0)) != 2:
		return false
	if int(after_info.get("active_suits", 0)) < 2:
		return false
	var before_counts: Dictionary = before_info.get("counts", {})
	var after_counts: Dictionary = after_info.get("counts", {})
	var before_value: int = int(before_counts.get(discarded_suit, 0))
	var after_value: int = int(after_counts.get(discarded_suit, 0))
	if before_value <= 0 or after_value >= before_value:
		return false
	var before_spread: int = int(before_info.get("spread", 0))
	var after_spread: int = int(after_info.get("spread", 0))
	return before_value >= 4 and after_value <= 3 and after_spread > before_spread


func _count_matching_tiles(hand_tiles: Array, target_tile: Dictionary) -> int:
	var count: int = 0
	for tile in hand_tiles:
		if str(tile.get("suit", "")) == str(target_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(target_tile.get("rank", 0)):
			count += 1
	return count


func _count_neighbor_links(hand_tiles: Array, target_tile: Dictionary) -> int:
	var target_suit: String = str(target_tile.get("suit", ""))
	var target_rank: int = int(target_tile.get("rank", 0))
	var count: int = 0
	for tile in hand_tiles:
		if str(tile.get("suit", "")) != target_suit:
			continue
		var rank: int = int(tile.get("rank", 0))
		if rank == target_rank:
			continue
		if abs(rank - target_rank) <= 2:
			count += 1
	return count


func _forms_long_chain(hand_tiles: Array, suit: String) -> bool:
	if suit == "":
		return false
	var unique_ranks := {}
	for tile in hand_tiles:
		if str(tile.get("suit", "")) != suit:
			continue
		unique_ranks[int(tile.get("rank", 0))] = true
	for start_rank in range(1, 6):
		var ok := true
		for rank in range(start_rank, start_rank + 4):
			if not unique_ranks.has(rank):
				ok = false
				break
		if ok:
			return true
	return false


func _count_visible_tile(target_tile: Dictionary, players: Array) -> int:
	var count: int = 0
	for player in players:
		for discard in player.get("discards", []):
			if str(discard.get("suit", "")) == str(target_tile.get("suit", "")) and int(discard.get("rank", 0)) == int(target_tile.get("rank", 0)):
				count += 1
		for meld in player.get("melds", []):
			for tile in meld.get("tiles", []):
				if str(tile.get("suit", "")) == str(target_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(target_tile.get("rank", 0)):
					count += 1
	return count


func _is_isolated_tile(target_tile: Dictionary, hand_tiles: Array) -> bool:
	var suit: String = str(target_tile.get("suit", ""))
	var rank: int = int(target_tile.get("rank", 0))
	var same_count: int = 0
	for tile in hand_tiles:
		if str(tile.get("suit", "")) != suit:
			continue
		var other_rank: int = int(tile.get("rank", 0))
		if other_rank == rank:
			same_count += 1
			continue
		if abs(other_rank - rank) <= 2:
			return false
	return same_count <= 1


func _has_isolated_suit_cluster(hand_tiles: Array, suit: String) -> bool:
	var suit_tiles: Array[int] = []
	for tile in hand_tiles:
		if str(tile.get("suit", "")) == suit:
			suit_tiles.append(int(tile.get("rank", 0)))
	suit_tiles.sort()
	for rank in suit_tiles:
		var near_count: int = 0
		for other_rank in suit_tiles:
			if rank == other_rank:
				continue
			if abs(other_rank - rank) <= 2:
				near_count += 1
		if near_count <= 0:
			return true
	return false


func _has_big_route(routes: Array) -> bool:
	for route in routes:
		var route_name: String = str(route)
		if route_name in ["清一色", "七对", "对对胡", "将对", "带幺九"] or route_name.contains("清"):
			return true
	return false


func _count_opponents_missing_suit(players: Array, self_seat: int, suit: String) -> int:
	var count: int = 0
	for player in players:
		if int(player.get("seat", -1)) == self_seat:
			continue
		if bool(player.get("has_won", false)):
			continue
		if str(player.get("ding_que", "")) == suit:
			count += 1
	return count




func _fan_route_bonus(routes: Array) -> int:
	var score := 0
	for route in routes:
		match str(route):
			"清一色":
				score += 32
			"七对":
				score += 26
			"对对胡":
				score += 18
			"将对":
				score += 16
			"带幺九":
				score += 12
			_:
				score += 6
	return score


func _array_difference(from_items: Array, to_items: Array) -> Array:
	var result: Array = []
	for item in from_items:
		if not to_items.has(item):
			result.append(item)
	return result


func _join_tile_names(tiles: Array) -> String:
	var names: Array[String] = []
	for tile in tiles:
		names.append(str(tile.get("display_name", "?")))
	return "/".join(names)


func _get_forced_discard_suit(player: Dictionary) -> String:
	var ding_que_suit: String = str(player.get("ding_que", ""))
	if ding_que_suit == "":
		return ""
	for tile in player.get("hand_tiles", []):
		if str(tile.get("suit", "")) == ding_que_suit:
			return ding_que_suit
	return ""


func _suit_name(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return suit


func _previous_seat(seat: int) -> int:
	return (seat + 3) % 4


func _next_seat(seat: int) -> int:
	return (seat + 1) % 4


func _resolve_active_suits(rules_config) -> Array:
	if rules_config != null and rules_config.available_suits != null:
		return Array(rules_config.available_suits).duplicate()
	return ["tiao", "tong", "wan"]
