extends RefCounted

class_name ReactionResolver

const HuCheckerScript := preload("res://scripts/core/hu_checker.gd")

var hu_checker = HuCheckerScript.new()


func build_reaction_candidates(players: Array, discard_context: Dictionary, rules_config) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if discard_context.is_empty():
		return result

	var source_seat: int = discard_context["source_seat"]
	var discarded_tile: Dictionary = discard_context["tile"]

	for player in players:
		var seat: int = player["seat"]
		if seat == source_seat:
			continue
		if player.get("has_won", false):
			continue

		var candidate := {
			"seat": seat,
			"nickname": str(player.get("nickname", "")),
			"can_hu": _can_hu_on_discard_placeholder(player, discarded_tile, rules_config),
			"can_gang": _can_gang_on_discard(player, discarded_tile, rules_config),
			"can_peng": _can_peng_on_discard(player, discarded_tile, rules_config),
		}

		if candidate["can_hu"] or candidate["can_gang"] or candidate["can_peng"]:
			result.append(candidate)

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_candidate_priority(a) > get_candidate_priority(b)
	)
	return result


func summarize_candidates(candidates: Array) -> String:
	if candidates.is_empty():
		return "-"

	var parts: Array[String] = []
	for candidate in candidates:
		var tags: Array[String] = []
		if candidate["can_hu"]:
			tags.append("HU")
		if candidate["can_gang"]:
			tags.append("GANG")
		if candidate["can_peng"]:
			tags.append("PENG")
		parts.append("%s[%s]" % [_candidate_name(candidate), "/".join(tags)])
	return " ".join(parts)


func get_candidate_priority(candidate: Dictionary) -> int:
	if candidate.get("can_hu", false):
		return 3
	if candidate.get("can_gang", false):
		return 2
	if candidate.get("can_peng", false):
		return 1
	return 0


func _can_peng_on_discard(player: Dictionary, discarded_tile: Dictionary, rules_config) -> bool:
	if not rules_config.allow_peng:
		return false
	if bool(player.get("bao_jiao", false)):
		# 旧锁听流程已禁用；四川按定缺、碰杠胡优先级处理。
		return false
	# Sichuan ding-que: only the missing suit itself is blocked from peng.
	if _is_missing_suit_tile(player, discarded_tile, rules_config):
		return false
	return _count_same_tiles(player["hand_tiles"], discarded_tile) >= 2


func _can_gang_on_discard(player: Dictionary, discarded_tile: Dictionary, rules_config) -> bool:
	if not rules_config.allow_gang:
		return false
	if bool(player.get("bao_jiao", false)):
		# 旧锁听强制杠流程已禁用；四川明杠由常规杠牌规则处理。
		if not _is_bao_gang_whitelisted(player, discarded_tile):
			return false
	# Sichuan ding-que: only the missing suit itself is blocked from gang.
	if _is_missing_suit_tile(player, discarded_tile, rules_config):
		return false
	return _count_same_tiles(player["hand_tiles"], discarded_tile) >= 3


func _can_hu_on_discard_placeholder(player: Dictionary, discarded_tile: Dictionary, rules_config) -> bool:
	return hu_checker.can_hu_on_discard(player, discarded_tile, rules_config)


func _is_missing_suit_tile(player: Dictionary, tile: Dictionary, rules_config = null) -> bool:
	if rules_config != null and rules_config.has_method("is_neijiang_mode") and bool(rules_config.is_neijiang_mode()):
		return false
	var ding_que: String = str(player.get("ding_que", ""))
	if ding_que == "":
		return false
	return str(tile.get("suit", "")) == ding_que


func _count_same_tiles(hand_tiles: Array, target_tile: Dictionary) -> int:
	var count: int = 0
	for tile in hand_tiles:
		if tile["suit"] == target_tile["suit"] and tile["rank"] == target_tile["rank"]:
			count += 1
	return count


func _is_bao_gang_whitelisted(player: Dictionary, tile: Dictionary) -> bool:
	var key := "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]
	return Array(player.get("bao_gang_tiles", [])).has(key)


func _candidate_name(candidate: Dictionary) -> String:
	var nickname := str(candidate.get("nickname", ""))
	if not nickname.is_empty():
		return nickname
	return "座位%d" % int(candidate.get("seat", -1))
