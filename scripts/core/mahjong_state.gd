extends RefCounted

class_name MahjongState


func build_player_state(player: Dictionary) -> Dictionary:
	var bao_jiao_enabled := false
	return {
		"seat": int(player.get("seat", -1)),
		"nickname": str(player.get("nickname", "")),
		"is_ai": bool(player.get("is_ai", false)),
		"ai_level": int(player.get("ai_level", -1)),
		"score": int(player.get("score", 0)),
		"ding_que": str(player.get("ding_que", "")),
		"bao_jiao": bao_jiao_enabled,
		"bao_gang_tiles": [],
		"bao_jiao_ting_tiles": [],
		"has_won": bool(player.get("has_won", false)),
		"win_type": str(player.get("win_type", "")),
		"winning_source_seat": int(player.get("winning_source_seat", -1)),
		"hand_tiles": player.get("hand_tiles", []).duplicate(true),
		"hand_count": int(player.get("hand_count", player.get("hand_tiles", []).size())),
		"melds": player.get("melds", []).duplicate(true),
		"discards": player.get("discards", []).duplicate(true),
		"winning_tile": player.get("winning_tile", {}).duplicate(true),
	}


func build_table_state(
	players: Array,
	current_turn_seat: int,
	current_phase: int,
	current_discard_context: Dictionary,
	last_draw_tile: Dictionary,
	pending_reactions: Array,
	wall_count: int
) -> Dictionary:
	var player_states: Array[Dictionary] = []
	for player in players:
		player_states.append(build_player_state(player))
	return {
		"players": player_states,
		"current_turn_seat": current_turn_seat,
		"current_phase": current_phase,
		"current_discard_context": current_discard_context.duplicate(true),
		"last_draw_tile": last_draw_tile.duplicate(true),
		"pending_reactions": pending_reactions.duplicate(true),
		"wall_count": wall_count,
	}
