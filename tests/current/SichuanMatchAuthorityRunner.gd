extends SceneTree

const Authority := preload("res://scripts/network/match_authority.gd")

class FakeState extends Node:
	var calls: Array = []
	func discard_tile_by_id(seat: int, tile_id: int) -> bool:
		calls.append(["discard", seat, tile_id])
		return tile_id == 99
	func choose_ding_que(seat: int, suit: String) -> bool:
		calls.append(["ding_que", seat, suit])
		return true
	func execute_human_peng(seat: int) -> bool:
		calls.append(["peng", seat])
		return true

func _initialize() -> void:
	var state := FakeState.new()
	var authority = Authority.new()
	assert(authority.configure(state, [{"player_id": "a", "seat": 2}, {"player_id": "b", "seat": 0}]))
	var result := authority.handle_command("a", {"sequence": 1, "command": "discard", "tile_id": 99})
	assert(result.ok and state.calls[-1] == ["discard", 2, 99])
	assert(authority.handle_command("a", {"sequence": 1, "command": "discard", "tile_id": 99}).error == "STALE_SEQUENCE")
	assert(authority.handle_command("b", {"sequence": 1, "command": "ding_que", "suit": "wan"}).ok)
	assert(state.calls[-1] == ["ding_que", 0, "wan"])
	assert(authority.handle_command("a", {"sequence": 2, "command": "action", "action": "peng"}).ok)
	assert(state.calls[-1] == ["peng", 2])
	assert(authority.handle_command("a", {"sequence": 3, "command": "action", "action": "admin_win"}).error == "INVALID_ARGUMENT")
	assert(authority.handle_command("unknown", {"sequence": 1, "command": "action", "action": "peng"}).error == "UNKNOWN_PLAYER")
	print("MATCH_AUTHORITY_PASS")
	quit(0)
