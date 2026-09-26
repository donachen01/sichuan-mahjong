extends SceneTree

const Projector := preload("res://scripts/network/snapshot_projector.gd")
const Codec := preload("res://scripts/network/protocol_codec.gd")
const Manager := preload("res://scripts/game/GameManager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var authority_scores := {0: -12, 1: 20, 2: -4, 3: -4}
	var players: Array = []
	for seat in range(4):
		players.append({
			"seat": seat,
			"nickname": "P%d" % seat,
			"score": 100 + authority_scores[seat],
			"hand_tiles": [{"id": seat + 1}],
			"hand_count": 1,
			"melds": [],
			"has_won": seat == 1,
			"winning_source_seat": 0 if seat == 1 else -1,
		})
	var authority_snapshot := {
		"current_phase": 7,
		"players": players,
		"settlement_data": {
			"winner_seats": [1],
			"score_changes": authority_scores,
			"preapplied_score_changes": {0: -1, 1: 3, 2: -1, 3: -1},
			"win_events": [{"winner_seat": 1, "source_seat": 0, "payer_seats": [0], "win_type": "discard_win"}],
		},
	}
	var projected: Dictionary = Projector.new().project(authority_snapshot, 1)
	var codec = Codec.new()
	var wire := codec.encode({"protocol_version": 1, "kind": "private_snapshot", "snapshot": projected})
	assert(not wire.is_empty())
	var decoded: Dictionary = codec.decode(wire).message.snapshot
	var manager = Manager.new()
	root.add_child(manager)
	await process_frame
	assert(manager.configure_network_client(1, func(_command: String, _arguments: Dictionary): return true))
	assert(manager.apply_private_snapshot(decoded))
	var client_snapshot: Dictionary = manager.get_snapshot()
	var client_scores: Dictionary = client_snapshot.settlement_data.score_changes
	assert(client_scores == {0: 20, 1: -4, 2: -4, 3: -12})
	for player in client_snapshot.players:
		var authority_seat := int(player.authority_seat)
		var view_seat := int(player.seat)
		assert(int(client_scores[view_seat]) == int(authority_scores[authority_seat]))
		assert(int(player.score) == 100 + int(authority_scores[authority_seat]))
	assert(int(client_snapshot.settlement_data.winner_seats[0]) == 0)
	assert(int(client_snapshot.settlement_data.win_events[0].winner_seat) == 0)
	assert(int(client_snapshot.settlement_data.win_events[0].source_seat) == 3)
	assert(int(client_snapshot.players[0].seat) == 0)
	assert(int(client_snapshot.players[0].winning_source_seat) == 3)
	print("LAN_SETTLEMENT_PARITY_PASS")
	manager.queue_free()
	quit(0)
