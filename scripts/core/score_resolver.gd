extends RefCounted

class_name ScoreResolver

const FanResolverScript := preload("res://scripts/core/fan_resolver.gd")

var fan_resolver = FanResolverScript.new()


func build_score_changes(players: Array, settlement_data: Dictionary, rules_config) -> Dictionary:
	var changes := _blank_score_changes(players)

	var gang_events: Array = settlement_data.get("gang_events", [])
	for event in gang_events:
		_merge_score_changes(changes, build_gang_event_score_changes(players, event))

	var tui_gang_refunds: Array = settlement_data.get("tui_gang_refunds", [])
	if rules_config != null and bool(rules_config.enable_tui_shui):
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
	for event in transfer_events:
		_merge_score_changes(changes, build_transfer_event_score_changes(players, event))

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

	_apply_draw_adjustments(changes, settlement_data, rules_config)

	return changes


func _resolve_hand_basic_score(capped_fan: int, rules_config = null) -> int:
	var bottom_score := 1 if rules_config == null else maxi(1, int(rules_config.base_score))
	return bottom_score * int(pow(2.0, maxi(0, capped_fan)))


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


func resolve_gang_total_score(event: Dictionary) -> int:
	var total := 0
	for payer in event.get("payer_seats", []):
		total += _resolve_gang_payer_score(event, int(payer))
	return total


func build_gang_event_score_changes(players: Array, event: Dictionary) -> Dictionary:
	var changes := _blank_score_changes(players)
	var actor_seat := int(event.get("actor_seat", -1))
	for payer in event.get("payer_seats", []):
		_apply_payment(changes, actor_seat, int(payer), _resolve_gang_payer_score(event, int(payer)))
	return changes


func _resolve_gang_payer_score(event: Dictionary, payer_seat: int) -> int:
	var gang_type := str(event.get("gang_type", ""))
	# 点杠采用逐付款人口径：点杠者付 2，其他仍在牌局中的玩家各付 1。
	# 暗杠和补杠仍分别为每家 2、每家 1。
	if gang_type == "melded_gang":
		var source_seat := int(event.get("source_seat", -1))
		if source_seat < 0 and Array(event.get("payer_seats", [])).size() == 1:
			source_seat = payer_seat
		return 2 if payer_seat == source_seat else 1
	return _resolve_gang_unit_score(gang_type)


func build_transfer_event_score_changes(players: Array, event: Dictionary) -> Dictionary:
	var changes := _blank_score_changes(players)
	if str(event.get("transfer_type", "")) != "hu_jiao_zhuan_yi":
		return changes
	var from_seat := int(event.get("from_seat", event.get("related_actor_seat", -1)))
	var winner_seat := int(event.get("to_seat", -1))
	var transfer_score := int(event.get("transfer_score", 0))
	if transfer_score <= 0:
		transfer_score = resolve_gang_total_score(event)
	_apply_payment(changes, winner_seat, from_seat, transfer_score)
	return changes


func build_event_fan_detail(player: Dictionary, winning_tile: Dictionary, win_type: String, rules_config) -> Dictionary:
	return fan_resolver.resolve_win_fans(player, winning_tile, win_type, rules_config)


func _apply_draw_adjustments(changes: Dictionary, settlement_data: Dictionary, rules_config) -> void:
	var draw_assessment: Array = settlement_data.get("draw_assessment", [])
	if draw_assessment.is_empty():
		return

	var ting_items: Array[Dictionary] = []
	var no_ting_seats: Array[int] = []
	var hua_zhu_seats: Array[int] = []
	for item in draw_assessment:
		var seat: int = int(item.get("seat", -1))
		var is_ting := bool(item.get("is_ting", false))
		if item.get("hua_zhu", false):
			hua_zhu_seats.append(seat)
		elif is_ting:
			ting_items.append(item)
		else:
			no_ting_seats.append(seat)

	# 花猪统一按封顶 4 番（底分 1 时即 16 分）赔付所有仍处于下叫状态的玩家。
	var hua_zhu_payment := _resolve_hand_basic_score(4, rules_config)
	for hua_zhu_seat in hua_zhu_seats:
		for item in ting_items:
			var target: int = int(item.get("seat", -1))
			_apply_payment(changes, target, hua_zhu_seat, hua_zhu_payment)

	# 查大叫只在牌墙耗尽时仍未胡的玩家之间结算。已经胡牌的玩家已按
	# 胡牌事件收过一次分，不能再被重新加入查叫收款目标。
	for no_ting_seat in no_ting_seats:
		for item in ting_items:
			var target: int = int(item.get("seat", -1))
			var payment := _resolve_draw_assessment_payment(item)
			_apply_payment(changes, target, no_ting_seat, payment)

func _resolve_draw_assessment_payment(item: Dictionary) -> int:
	return maxi(1, int(item.get("cha_jiao_score", 1)))


func _blank_score_changes(players: Array) -> Dictionary:
	var changes := {}
	for player in players:
		changes[int(player.get("seat", -1))] = 0
	return changes


func _merge_score_changes(target: Dictionary, source: Dictionary) -> void:
	for seat in source.keys():
		if target.has(seat):
			target[seat] = int(target.get(seat, 0)) + int(source.get(seat, 0))


func _apply_payment(changes: Dictionary, receiver_seat: int, payer_seat: int, score: int) -> void:
	if score <= 0 or receiver_seat == payer_seat:
		return
	if not changes.has(receiver_seat) or not changes.has(payer_seat):
		return
	changes[receiver_seat] = int(changes.get(receiver_seat, 0)) + score
	changes[payer_seat] = int(changes.get(payer_seat, 0)) - score
