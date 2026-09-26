extends RefCounted
class_name SichuanSnapshotProjector

const Mapper := preload("res://scripts/game/seat_view_mapper.gd")
const PUBLIC_KEYS := ["round_index", "current_phase", "current_dealer_seat", "current_turn_seat", "wall_count", "discard_count", "winner_count", "round_winners", "recent_discard_display", "recent_discard_tile_id", "recent_draw_display", "recent_draw_seat", "discard_context", "opening_roll", "opening_roll_pending", "reaction_summary", "rules", "settlement_data"]
const PRIVATE_ACTION_KEYS := ["human_can_discard", "human_can_self_hu", "human_can_add_gang", "human_can_an_gang", "human_ding_que_pending", "human_ding_que_options", "human_last_draw_tile_id", "human_reaction_options", "trainer_hint"]

func project(snapshot: Dictionary, receiver_seat: int) -> Dictionary:
	if receiver_seat < 0 or receiver_seat >= 4:
		return {}
	var result := {"schema_version": 1, "local_seat_id": 0}
	for key in PUBLIC_KEYS:
		if snapshot.has(key): result[key] = snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
	for key in PRIVATE_ACTION_KEYS:
		if snapshot.has(key): result[key] = snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
	for key in ["current_dealer_seat", "current_turn_seat", "recent_draw_seat"]:
		if result.has(key): result[key] = Mapper.authority_to_view(int(result[key]), receiver_seat)
	result["round_winners"] = Mapper.map_seat_list(result.get("round_winners", []), receiver_seat)
	var context: Dictionary = result.get("discard_context", {})
	if context.has("source_seat"): context.source_seat = Mapper.authority_to_view(int(context.source_seat), receiver_seat)
	result["discard_context"] = context
	if result.has("settlement_data"):
		result["settlement_data"] = Mapper.map_settlement_for_view(result.settlement_data, receiver_seat)
	var projected_players: Array = []
	var reveal_all_hands := int(snapshot.get("current_phase", -1)) == 7
	for value in snapshot.get("players", []):
		var player: Dictionary = Mapper.map_player_for_view(value, receiver_seat)
		if int(value.get("seat", -1)) != receiver_seat and not reveal_all_hands:
			player.erase("hand_tiles")
			player["hand_count"] = int(value.get("hand_count", Array(value.get("hand_tiles", [])).size()))
		projected_players.append(player)
	projected_players.sort_custom(func(a, b): return int(a.seat) < int(b.seat))
	result["players"] = projected_players
	result["own_actions"] = {
		"can_discard": bool(snapshot.get("human_can_discard", false)),
		"can_self_hu": bool(snapshot.get("human_can_self_hu", false)),
		"can_add_gang": bool(snapshot.get("human_can_add_gang", false)),
		"can_an_gang": bool(snapshot.get("human_can_an_gang", false)),
		"reaction": Dictionary(snapshot.get("human_reaction_options", {})).duplicate(true),
	}
	return _network_safe(result)

func _network_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[str(key)] = _network_safe(value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(_network_safe(item))
		return array
	return value
