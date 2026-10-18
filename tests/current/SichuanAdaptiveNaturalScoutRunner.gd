extends "res://tests/current/SichuanBookFlushTempoScoutRunner.gd"

# New development exposure: sample first applicable root in each public
# 9/10/11-target, early/middle/later and favourable/unfavourable condition.
# Outcome and foreign hidden hands never enter the selection predicate.
func _natural_kinds(game: Node, seat: int) -> Array:
	if int(game.get("current_phase")) != 5 or int(game.get("current_turn_seat")) != seat:
		return []
	if bool(game.call("_can_seat_self_hu_now", seat)):
		return [] # No deferred self-Hu-refusal samples.
	var player: Dictionary = game.get("players")[seat]
	var counts := {}
	for tile in player["hand_tiles"]:
		if tile["suit"] == player["ding_que"]:
			return []
		counts[tile["suit"]] = int(counts.get(tile["suit"], 0)) + 1
	var own_draws := 1 if int(game.get("current_dealer_seat")) == seat else 0
	for event in game.get("ai_public_events"):
		if event["type"] == "draw" and int(event["seat"]) == seat:
			own_draws += 1
	var stage := "early" if own_draws <= 6 else ("middle" if own_draws <= 10 else "later")
	var result: Array = []
	for suit in counts:
		if int(counts[suit]) < 9 or int(counts[suit]) > 11:
			continue
		var compatible := true
		for meld in player["melds"]:
			compatible = compatible and meld["tiles"][0]["suit"] == suit
		if not compatible:
			continue
		var suppliers := 0
		for other in game.get("players"):
			if int(other["seat"]) != seat and not bool(other["has_won"]) and other["ding_que"] == suit:
				suppliers += 1
		result.append("adaptive_flush_%d_%s_%s" % [int(counts[suit]), stage, "favourable" if suppliers >= 2 else "unfavourable"])
	return result
