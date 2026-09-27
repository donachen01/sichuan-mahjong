extends RefCounted


static func next_dealer(win_events: Array, player_count: int, current_dealer: int) -> int:
	if win_events.is_empty():
		return current_dealer
	var first: Dictionary = win_events[0]
	var source := int(first.get("source_seat", -1))
	var win_type := str(first.get("win_type", ""))
	var tile_id := int(first.get("winning_tile", {}).get("id", -1))
	var first_winners := {}
	# A shared source is insufficient: that player may discard into two separate
	# wins later in the round. Only the first physical discard can change this rule.
	if tile_id >= 0 and win_type in ["discard_win", "gang_discard_win", "qiang_gang_hu"]:
		for event_value in win_events:
			var event: Dictionary = event_value
			if int(event.get("source_seat", -1)) != source \
				or str(event.get("win_type", "")) != win_type \
				or int(event.get("winning_tile", {}).get("id", -1)) != tile_id:
				break
			var winner := int(event.get("winner_seat", -1))
			if winner >= 0 and winner < player_count:
				first_winners[winner] = true
		if first_winners.size() >= 2 and source >= 0 and source < player_count:
			return source
	var first_winner := int(first.get("winner_seat", -1))
	return first_winner if first_winner >= 0 and first_winner < player_count else current_dealer
