extends "res://tests/current/SichuanBookFlushTempoScoutRunner.gd"

# First legal opportunity of each self-Gang type in a natural original game.
# Selection includes opportunities the live AI rejects; it reads no future wall
# or opponent concealed hand. Ordinary self-draw Hu always takes priority.
func _natural_kinds(game: Node, seat: int) -> Array:
	if int(game.get("current_phase")) != 5 or int(game.get("current_turn_seat")) != seat:
		return []
	if bool(game.call("_can_seat_self_hu_now", seat)):
		return []
	var kinds: Array = []
	for action in _root_actions(game, seat):
		if action["action"] in ["an_gang", "add_gang"]:
			var kind: String = "conditional_" + str(action["action"])
			if not kinds.has(kind):
				kinds.append(kind)
	return kinds
