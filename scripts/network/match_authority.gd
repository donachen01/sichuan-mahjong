extends RefCounted
class_name SichuanMatchAuthority

const ALLOWED_ACTIONS := ["hu", "self_hu", "pass_self_hu", "peng", "gang", "add_gang", "an_gang", "pass"]
const ALLOWED_DING_QUE := ["tiao", "tong", "wan"]

var game_state: Node
var player_seats: Dictionary = {}
var last_sequence: Dictionary = {}

func configure(authority_state: Node, members: Array) -> bool:
	if authority_state == null:
		return false
	var next_seats := {}
	for raw_member in members:
		if not raw_member is Dictionary:
			return false
		var member: Dictionary = raw_member
		var player_id := str(member.get("player_id", ""))
		var seat := int(member.get("seat", -1))
		if player_id.is_empty() or seat < 0 or seat >= 4 or next_seats.has(player_id):
			return false
		next_seats[player_id] = seat
	game_state = authority_state
	player_seats = next_seats
	last_sequence.clear()
	return true

func handle_command(player_id: String, command: Dictionary) -> Dictionary:
	if game_state == null or not player_seats.has(player_id):
		return _reject(command, "UNKNOWN_PLAYER")
	var sequence := int(command.get("sequence", 0))
	if sequence <= int(last_sequence.get(player_id, 0)):
		return _reject(command, "STALE_SEQUENCE")
	var kind := str(command.get("command", ""))
	var seat := int(player_seats[player_id])
	var accepted := false
	match kind:
		"discard":
			var tile_id := int(command.get("tile_id", -1))
			if tile_id <= 0: return _reject(command, "INVALID_ARGUMENT")
			accepted = bool(game_state.call("discard_tile_by_id", seat, tile_id))
		"ding_que":
			var suit := str(command.get("suit", ""))
			if suit not in ALLOWED_DING_QUE: return _reject(command, "INVALID_ARGUMENT")
			accepted = bool(game_state.call("choose_ding_que", seat, suit))
		"action":
			var action := str(command.get("action", ""))
			if action not in ALLOWED_ACTIONS: return _reject(command, "INVALID_ARGUMENT")
			accepted = _execute_action(seat, action)
		_:
			return _reject(command, "UNKNOWN_COMMAND")
	last_sequence[player_id] = sequence
	return {"ok": accepted, "sequence": sequence, "error": "" if accepted else "ILLEGAL_ACTION"}

func _execute_action(seat: int, action: String) -> bool:
	var method: String = {
		"hu": "execute_human_hu",
		"self_hu": "execute_human_self_hu",
		"pass_self_hu": "pass_human_self_hu",
		"peng": "execute_human_peng",
		"gang": "execute_human_gang",
		"add_gang": "execute_human_add_gang",
		"an_gang": "execute_human_an_gang",
		"pass": "pass_human_reaction",
	}.get(action, "")
	return not method.is_empty() and bool(game_state.call(method, seat))

func _reject(command: Dictionary, error: String) -> Dictionary:
	return {"ok": false, "sequence": int(command.get("sequence", 0)), "error": error}
