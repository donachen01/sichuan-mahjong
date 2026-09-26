extends RefCounted
class_name SeatViewMapper

const SEAT_COUNT := 4

static func authority_to_view(authority_seat: int, local_seat: int) -> int:
	if not _valid(authority_seat) or not _valid(local_seat):
		return -1
	return posmod(authority_seat - local_seat, SEAT_COUNT)

static func view_to_authority(view_seat: int, local_seat: int) -> int:
	if not _valid(view_seat) or not _valid(local_seat):
		return -1
	return posmod(view_seat + local_seat, SEAT_COUNT)

static func map_seat_list(authority_seats: Array, local_seat: int) -> Array[int]:
	var result: Array[int] = []
	for seat in authority_seats:
		var mapped := authority_to_view(int(seat), local_seat)
		if mapped >= 0:
			result.append(mapped)
	return result

static func map_player_for_view(player: Dictionary, local_seat: int) -> Dictionary:
	var mapped := player.duplicate(true)
	var authority_seat := int(player.get("seat", -1))
	mapped["authority_seat"] = authority_seat
	mapped["seat"] = authority_to_view(authority_seat, local_seat)
	# `winning_source_seat` is consumed directly by both the 3D result layout and
	# the player nameplate.  Keeping it in authority coordinates makes a remote
	# client misclassify some discard wins as self draws (hiding the claimed
	# tile), and some self draws as discard wins (duplicating the drawn tile).
	if mapped.has("winning_source_seat"):
		var source_seat := int(mapped["winning_source_seat"])
		mapped["winning_source_seat"] = authority_to_view(source_seat, local_seat) if source_seat >= 0 else source_seat
	var mapped_melds: Array = []
	for meld_value in mapped.get("melds", []):
		var meld: Dictionary = Dictionary(meld_value).duplicate(true)
		if meld.has("from_seat"):
			meld["from_seat"] = authority_to_view(int(meld.from_seat), local_seat)
		mapped_melds.append(meld)
	mapped["melds"] = mapped_melds
	return mapped

static func map_settlement_for_view(settlement: Dictionary, local_seat: int) -> Dictionary:
	var mapped := settlement.duplicate(true)
	if mapped.has("dealer_seat"):
		mapped.dealer_seat = authority_to_view(int(mapped.dealer_seat), local_seat)
	if mapped.has("winner_seats"):
		mapped.winner_seats = map_seat_list(mapped.winner_seats, local_seat)
	for list_key in ["win_events", "gang_events", "kong_resolution_events", "transfer_events", "qiang_gang_hu_placeholders", "draw_assessment", "tui_gang_refunds"]:
		var items: Array = []
		for value in mapped.get(list_key, []):
			items.append(_map_event(Dictionary(value), local_seat))
		mapped[list_key] = items
	for score_key in ["score_changes", "preapplied_score_changes"]:
		var scores: Dictionary = {}
		for authority_key in Dictionary(mapped.get(score_key, {})).keys():
			var view_seat := authority_to_view(int(authority_key), local_seat)
			if view_seat >= 0:
				scores[view_seat] = mapped[score_key][authority_key]
		mapped[score_key] = scores
	return mapped

static func _map_event(event: Dictionary, local_seat: int) -> Dictionary:
	var mapped := event.duplicate(true)
	for key in ["seat", "winner_seat", "source_seat", "actor_seat", "from_seat", "to_seat", "related_actor_seat"]:
		if mapped.has(key):
			var seat := int(mapped[key])
			mapped[key] = authority_to_view(seat, local_seat) if seat >= 0 else seat
	for key in ["payer_seats", "winner_seats"]:
		if mapped.has(key):
			mapped[key] = map_seat_list(mapped[key], local_seat)
	return mapped

static func _valid(seat: int) -> bool:
	return seat >= 0 and seat < SEAT_COUNT
