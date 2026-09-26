extends SceneTree

const Mapper := preload("res://scripts/game/seat_view_mapper.gd")
const Adapter := preload("res://scripts/game/session_adapter.gd")

func _initialize() -> void:
	for local in range(4):
		assert(Mapper.authority_to_view(local, local) == 0)
		for authority in range(4):
			var view := Mapper.authority_to_view(authority, local)
			assert(Mapper.view_to_authority(view, local) == authority)
	assert(Mapper.authority_to_view(1, 0) == 1)
	assert(Mapper.authority_to_view(0, 1) == 3)
	var mapped := Mapper.map_player_for_view({"seat": 3, "winning_source_seat": 0, "melds": [{"type": "peng", "from_seat": 0}]}, 2)
	assert(mapped.seat == 1 and mapped.authority_seat == 3)
	assert(mapped.winning_source_seat == 2)
	assert(mapped.melds[0].from_seat == 2)
	var mapped_self_draw := Mapper.map_player_for_view({"seat": 2, "winning_source_seat": 2, "melds": []}, 2)
	assert(mapped_self_draw.seat == 0 and mapped_self_draw.winning_source_seat == 0)
	var mapped_discard_win := Mapper.map_player_for_view({"seat": 2, "winning_source_seat": 1, "melds": []}, 2)
	assert(mapped_discard_win.seat == 0 and mapped_discard_win.winning_source_seat == 3)
	var settlement := Mapper.map_settlement_for_view({
		"dealer_seat": 2,
		"winner_seats": [1, 3],
		"win_events": [{"winner_seat": 1, "source_seat": 0, "payer_seats": [0]}],
		"gang_events": [{"actor_seat": 3, "source_seat": 2, "payer_seats": [0, 1, 2]}],
		"score_changes": {0: -2, 1: 2, 2: 0, 3: 0},
	}, 2)
	assert(settlement.dealer_seat == 0)
	assert(settlement.winner_seats == [3, 1])
	assert(settlement.win_events[0].winner_seat == 3 and settlement.win_events[0].source_seat == 2)
	assert(settlement.score_changes[2] == -2 and settlement.score_changes[3] == 2)
	var session = Adapter.new()
	assert(session.configure(Adapter.Role.HOST, 2))
	assert(session.is_authority() and session.may_call_game_state_directly())
	assert(session.authority_to_view(2) == 0)
	assert(session.configure(Adapter.Role.CLIENT, 3))
	assert(not session.is_authority() and not session.may_call_game_state_directly())
	assert(not session.configure(Adapter.Role.CLIENT, 4))
	print("SEAT_SESSION_PASS")
	quit(0)
