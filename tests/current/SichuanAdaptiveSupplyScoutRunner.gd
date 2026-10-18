extends "res://tests/current/SichuanBookFlushTempoScoutRunner.gd"

# Textbook 6.4.3/6.4.4 counts an exposed set as three structural tiles.
# Keep the previous frozen concealed-only scout unchanged. This selection reads
# only our hand, public melds/events and declared missing suits, never outcomes.
func _natural_kinds(game: Node, seat: int) -> Array:
	if int(game.get("current_phase")) != 5 or int(game.get("current_turn_seat")) != seat:
		return []
	if bool(game.call("_can_seat_self_hu_now", seat)):
		return []
	var player: Dictionary = game.get("players")[seat]
	var counts := {}
	for tile in player["hand_tiles"]:
		if tile["suit"] == player["ding_que"]:
			return []
		counts[tile["suit"]] = int(counts.get(tile["suit"], 0)) + 1
	var regular_draws := 1 if int(game.get("current_dealer_seat")) == seat else 0
	var previous := {}
	for event in game.get("ai_public_events"):
		if event["type"] == "pass":
			continue
		if event["type"] == "draw" and int(event["seat"]) == seat:
			var replacement: bool = int(previous.get("seat", -1)) == seat and previous.get("type", "") in ["an_gang", "ming_gang", "add_gang", "concealed_gang", "melded_gang", "added_gang"]
			if not replacement:
				regular_draws += 1
		previous = event
	var stage := "early" if regular_draws <= 6 else ("middle" if regular_draws <= 10 else "later")
	var result: Array = []
	for suit in ["tiao", "tong", "wan"]:
		var compatible: bool = suit != player["ding_que"]
		var structural := int(counts.get(suit, 0))
		for meld in player["melds"]:
			compatible = compatible and meld["tiles"][0]["suit"] == suit
			structural += 3
		if not compatible or structural < 9 or structural > 12:
			continue
		var suppliers := 0
		for other in game.get("players"):
			if int(other["seat"]) != seat and not bool(other["has_won"]) and other["ding_que"] == suit:
				suppliers += 1
		result.append("adaptive_owned_%d_%s_%s" % [structural, stage, "favourable" if suppliers >= 2 else "unfavourable"])
	return result
