extends "res://tests/current/SichuanAdaptiveSupplyScoutRunner.gd"

class PublicSelectionState extends Node:
	var current_phase: int = 5
	var current_turn_seat: int = 0
	var current_dealer_seat: int = 3
	var players: Array = []
	var ai_public_events: Array = []
	var self_hu := false
	func _can_seat_self_hu_now(_seat: int) -> bool:
		return self_hu

func _run() -> void:
	var game := PublicSelectionState.new()
	for seat in range(4):
		game.players.append({"seat": seat, "has_won": false, "ding_que": "tiao" if seat == 0 else ("tong" if seat < 3 else "wan"), "hand_tiles": [], "melds": []})
	for rank in range(1, 9):
		game.players[0]["hand_tiles"].append({"suit": "tong", "rank": rank})
	for rank in range(2, 5):
		game.players[0]["hand_tiles"].append({"suit": "wan", "rank": rank})
	game.players[0]["melds"] = [{"tiles": [{"suit": "tong", "rank": 9}, {"suit": "tong", "rank": 9}, {"suit": "tong", "rank": 9}]}]
	var checks := 0
	for _i in range(6):
		game.ai_public_events.append({"type": "draw", "seat": 0})
	assert(_natural_kinds(game, 0) == ["adaptive_owned_11_early_favourable"])
	checks += 1
	# A fourth Gang tile is physical inventory, not a fourth structural slot.
	game.players[0]["melds"][0]["tiles"].append({"suit": "tong", "rank": 9})
	assert(_natural_kinds(game, 0) == ["adaptive_owned_11_early_favourable"])
	checks += 1
	for kind in ["concealed_gang", "melded_gang", "added_gang"]:
		game.ai_public_events.append({"type": kind, "seat": 0})
		game.ai_public_events.append({"type": "pass", "seat": 1})
		game.ai_public_events.append({"type": "draw", "seat": 0})
		assert(_natural_kinds(game, 0) == ["adaptive_owned_11_early_favourable"])
		checks += 1
	game.ai_public_events.append({"type": "discard", "seat": 1})
	game.ai_public_events.append({"type": "draw", "seat": 0})
	assert(_natural_kinds(game, 0) == ["adaptive_owned_11_middle_favourable"])
	checks += 1
	game.players[1]["has_won"] = true
	assert(_natural_kinds(game, 0) == ["adaptive_owned_11_middle_unfavourable"])
	checks += 1
	game.self_hu = true
	assert(_natural_kinds(game, 0).is_empty())
	checks += 1
	game.self_hu = false
	game.players[0]["hand_tiles"].append({"suit": "tiao", "rank": 1})
	assert(_natural_kinds(game, 0).is_empty())
	checks += 1
	game.players[0]["hand_tiles"].pop_back()
	game.players[0]["melds"].append({"tiles": [{"suit": "wan", "rank": 1}]})
	assert(_natural_kinds(game, 0).is_empty())
	checks += 1
	game.players[0]["melds"].pop_back()
	game.current_phase = 6
	assert(_natural_kinds(game, 0).is_empty())
	checks += 1
	game.current_phase = 5
	game.current_turn_seat = 1
	assert(_natural_kinds(game, 0).is_empty())
	checks += 1
	game.free()
	_write_report({"passed": true, "checks": checks, "scope": "public selection only; not physical full-game validation"}, _read_string_arg("--output=", ""))
	print("ADAPTIVE_SUPPLY_SELECTION PASS checks=", checks)
	quit()
