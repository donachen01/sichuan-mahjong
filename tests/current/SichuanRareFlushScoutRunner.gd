extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Dedicated development sample: first publicly eligible flush structure node
# per naturally dealt seed/controlled seat/style, without future label filtering.
func _natural_kinds(game: Node, seat: int) -> Array:
	var kinds := super._natural_kinds(game, seat)
	return ["flush_route"] if kinds.has("flush_route") else []
