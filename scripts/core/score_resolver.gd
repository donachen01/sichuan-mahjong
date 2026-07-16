extends RefCounted

class_name ScoreResolver

const FanResolverScript := preload("res://scripts/core/fan_resolver.gd")

var fan_resolver = FanResolverScript.new()


func build_score_changes(players: Array, settlement_data: Dictionary, rules_config) -> Dictionary:
	var changes := {}
	for player in players:
		changes[player["seat"]] = 0

	var unresolved_players := 0
	for player in players:
		if not bool(player.get("has_won", false)):
			unresolved_players += 1
	var is_draw_settlement := str(settlement_data.get("end_reason", "")) == "draw_wall_empty"
	var is_battle_end_settlement := str(settlement_data.get("end_reason", "")) == "battle_end"
	var should_count_gang_scores: bool = unresolved_players == 0 or is_draw_settlement or is_battle_end_settlement

	var gang_events: Array = settlement_data.get("gang_events", [])
	if should_count_gang_scores:
		for event in gang_events:
			var actor_seat: int = int(event.get("actor_seat", -1))
			var gang_type: String = str(event.get("gang_type", ""))
			var related_outcome: String = str(event.get("related_outcome", ""))
			if related_outcome == "gang_discard_win":
				continue
			var payer_seats: Array = event.get("payer_seats", [])
			var unit_score: int = _resolve_gang_unit_score(gang_type)
			for payer in payer_seats:
				var payer_seat: int = int(payer)
				if changes.has(actor_seat) and changes.has(payer_seat):
					changes[actor_seat] += unit_score
					changes[payer_seat] -= unit_score

	var tui_gang_refunds: Array = settlement_data.get("tui_gang_refunds", [])
	if should_count_gang_scores:
		for refund in tui_gang_refunds:
			var actor_seat: int = int(refund.get("actor_seat", -1))
			var gang_type: String = str(refund.get("gang_type", ""))
			var payer_seats: Array = refund.get("payer_seats", [])
			var refund_unit: int = _resolve_gang_unit_score(gang_type)
			for payer in payer_seats:
				var payer_seat: int = int(payer)
				if changes.has(actor_seat) and changes.has(payer_seat):
					changes[actor_seat] -= refund_unit
					changes[payer_seat] += refund_unit

	var transfer_events: Array = settlement_data.get("transfer_events", [])
	if should_count_gang_scores:
		for event in transfer_events:
			var transfer_type: String = str(event.get("transfer_type", ""))
			if transfer_type != "hu_jiao_zhuan_yi":
				continue
			var winner_seat: int = int(event.get("to_seat", -1))
			var gang_type: String = str(event.get("gang_type", ""))
			var payer_seats: Array = event.get("payer_seats", [])
			var transfer_unit: int = _resolve_gang_unit_score(gang_type)
			for payer in payer_seats:
				var payer_seat: int = int(payer)
				if changes.has(winner_seat) and changes.has(payer_seat):
					changes[winner_seat] += transfer_unit
					changes[payer_seat] -= transfer_unit

	var win_events: Array = settlement_data.get("win_events", [])
	for event in win_events:
		var winner_seat: int = int(event.get("winner_seat", -1))
		var payer_seats: Array = event.get("payer_seats", [])
		var win_type: String = str(event.get("win_type", "discard_win"))
		var fan_detail: Dictionary = event.get("fan_detail", {})
		var capped_fan: int = int(fan_detail.get("capped_fan", 1))
		var hand_score: int = int(fan_detail.get("hand_score", _resolve_hand_basic_score(capped_fan, rules_config)))
		var self_draw_bonus := _resolve_self_draw_bottom_score(win_type, rules_config)
		for payer in payer_seats:
			var payer_seat: int = int(payer)
			if not changes.has(winner_seat) or not changes.has(payer_seat):
				continue
			var payment := hand_score + self_draw_bonus
			changes[winner_seat] += payment
			changes[payer_seat] -= payment

	_apply_draw_adjustments(changes, settlement_data)

	return changes


func _resolve_hand_basic_score(capped_fan: int, rules_config = null) -> int:
	if capped_fan <= 0:
		return 1
	return int(pow(2.0, capped_fan - 1))


func _resolve_self_draw_bottom_score(win_type: String, rules_config) -> int:
	if win_type == "self_draw" or win_type == "gang_self_draw":
		return 1 if rules_config == null else int(rules_config.self_draw_extra_base_score)
	return 0


func _resolve_gang_unit_score(gang_type: String) -> int:
	match gang_type:
		"melded_gang", "an_gang":
			return 2
		"add_gang":
			return 1
		_:
			return 1


func build_event_fan_detail(player: Dictionary, winning_tile: Dictionary, win_type: String, rules_config) -> Dictionary:
	return fan_resolver.resolve_win_fans(player, winning_tile, win_type, rules_config)


func _apply_draw_adjustments(changes: Dictionary, settlement_data: Dictionary) -> void:
	var draw_assessment: Array = settlement_data.get("draw_assessment", [])
	if draw_assessment.is_empty():
		return

	var ting_items: Array[Dictionary] = []
	var ting_items_by_seat: Dictionary = {}
	var no_ting_seats: Array[int] = []
	var hua_zhu_seats: Array[int] = []
	for item in draw_assessment:
		var seat: int = int(item.get("seat", -1))
		var is_ting := bool(item.get("is_ting", false))
		if item.get("hua_zhu", false):
			hua_zhu_seats.append(seat)
		elif is_ting:
			ting_items.append(item)
			ting_items_by_seat[seat] = item
		else:
			no_ting_seats.append(seat)

	for hua_zhu_seat in hua_zhu_seats:
		for item in ting_items:
			var target: int = int(item.get("seat", -1))
			var payment := _resolve_draw_assessment_payment(item)
			if changes.has(hua_zhu_seat) and changes.has(target):
				changes[hua_zhu_seat] -= payment
				changes[target] += payment

	for no_ting_seat in no_ting_seats:
		for item in ting_items:
			var target: int = int(item.get("seat", -1))
			var payment := _resolve_draw_assessment_payment(item)
			if changes.has(no_ting_seat) and changes.has(target):
				changes[no_ting_seat] -= payment
				changes[target] += payment

func _resolve_draw_assessment_payment(item: Dictionary) -> int:
	return maxi(1, int(item.get("cha_jiao_score", 1)))
