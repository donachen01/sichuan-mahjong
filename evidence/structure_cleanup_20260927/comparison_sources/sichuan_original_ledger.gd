extends RefCounted
const PLAYER_COUNT := 4
var names: Array = ["本家", "上家", "对家", "下家"]
func _seat_name(seat: int) -> String:
	return str(names[seat]) if seat >= 0 and seat < 4 else "未知"

func _build_settlement_breakdown_lines(players: Array, settlement_data: Dictionary, focus_seat: int, round_delta: int) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for event in settlement_data.get("win_events", []):
		var winner_seat: int = int(event.get("winner_seat", -1))
		var fan_detail: Dictionary = event.get("fan_detail", {})
		var labels: Array = fan_detail.get("labels", [])
		var reason := "%s（%s）" % [
			_win_type_display_name(str(event.get("win_type", "discard_win"))),
			"/".join(labels) if not labels.is_empty() else _hand_type_display_name(str(fan_detail.get("hand_type", "ping_hu"))),
		]
		var payer_names: Array[String] = []
		for seat in event.get("payer_seats", []):
			payer_names.append(_seat_name(int(seat)))
		var factor_text := _build_event_factor_text(event, players)
		var event_total_score := _resolve_event_total_score(event, players)
		var payer_seats: Array = event.get("payer_seats", [])
		if winner_seat == focus_seat:
			lines.append(
				{
					"reason": reason,
					"source": " / ".join(payer_names) if not payer_names.is_empty() else _seat_name(focus_seat),
					"factor": factor_text,
					"score": "+%d" % event_total_score,
				}
			)
		elif payer_seats.has(focus_seat):
			lines.append(
				{
					"reason": "支付%s" % reason,
					"source": _seat_name(winner_seat),
					"factor": factor_text,
					"score": "-%d" % _resolve_event_payment_for_payer(event, focus_seat, players),
				}
			)

	for event in settlement_data.get("gang_events", []):
		if str(event.get("related_outcome", "")) == "gang_discard_win":
			continue
		var actor_seat: int = int(event.get("actor_seat", -1))
		var gang_total_score: int = _resolve_gang_event_total_score(event)
		var gang_unit_score: int = _resolve_gang_unit_score(str(event.get("gang_type", "")))
		var gang_payers: Array = event.get("payer_seats", [])
		if actor_seat == focus_seat:
			lines.append(
				{
					"reason": _gang_type_display_name(str(event.get("gang_type", "melded_gang"))),
					"source": _refund_payers_display(gang_payers),
					"factor": "杠分",
					"score": "+%d" % gang_total_score,
				}
			)
		elif gang_payers.has(focus_seat):
			lines.append(
				{
					"reason": "支付%s" % _gang_type_display_name(str(event.get("gang_type", "melded_gang"))),
					"source": _seat_name(actor_seat),
					"factor": "杠分",
					"score": "-%d" % gang_unit_score,
				}
			)

	for refund in settlement_data.get("tui_gang_refunds", []):
		var refund_actor_seat: int = int(refund.get("actor_seat", -1))
		var refund_unit_score: int = _resolve_gang_unit_score(str(refund.get("gang_type", "")))
		var refund_payers: Array = refund.get("payer_seats", [])
		if refund_actor_seat == focus_seat:
			lines.append(
				{
					"reason": "退回%s税" % _gang_type_display_name(str(refund.get("gang_type", ""))),
					"source": _refund_payers_display(refund_payers),
					"factor": "退税",
					"score": "-%d" % (refund_unit_score * refund_payers.size()),
				}
			)
		elif refund_payers.has(focus_seat):
			lines.append(
				{
					"reason": "收回退税",
					"source": _seat_name(refund_actor_seat),
					"factor": "退税",
					"score": "+%d" % refund_unit_score,
				}
			)

	for event in settlement_data.get("transfer_events", []):
		if str(event.get("transfer_type", "")) != "hu_jiao_zhuan_yi":
			continue
		var transfer_winner_seat: int = int(event.get("to_seat", -1))
		var transfer_unit_score: int = _resolve_gang_unit_score(str(event.get("gang_type", "")))
		var transfer_payers: Array = event.get("payer_seats", [])
		if transfer_winner_seat == focus_seat:
			lines.append(
				{
					"reason": "呼叫转移",
					"source": _refund_payers_display(transfer_payers),
					"factor": "转移杠分",
					"score": "+%d" % (transfer_unit_score * transfer_payers.size()),
				}
			)
		elif transfer_payers.has(focus_seat):
			lines.append(
				{
					"reason": "支付呼叫转移",
					"source": _seat_name(transfer_winner_seat),
					"factor": "转移杠分",
					"score": "-%d" % transfer_unit_score,
				}
			)

	var focus_assessment := _find_draw_assessment_by_seat(settlement_data, focus_seat)
	if not focus_assessment.is_empty():
		var focus_is_hua_zhu := bool(focus_assessment.get("hua_zhu", false))
		var focus_is_ting := bool(focus_assessment.get("is_ting", false))
		for item in settlement_data.get("draw_assessment", []):
			var seat := int(item.get("seat", -1))
			if seat == focus_seat:
				continue
			var target_is_ting := bool(item.get("is_ting", false))
			var target_is_hua_zhu := bool(item.get("hua_zhu", false))
			var score_text := ""
			var reason_text := ""
			var source_text := _seat_name(seat)
			var factor_text := ""

			if focus_is_hua_zhu and target_is_ting:
				reason_text = "花猪赔付"
				factor_text = _build_cha_jiao_factor_text(item)
				score_text = "-%d" % maxi(1, int(item.get("cha_jiao_score", 1)))
			elif not focus_is_ting and not focus_is_hua_zhu and target_is_ting:
				reason_text = "查叫赔付"
				factor_text = _build_cha_jiao_factor_text(item)
				score_text = "-%d" % maxi(1, int(item.get("cha_jiao_score", 1)))
			elif focus_is_ting and target_is_hua_zhu:
				reason_text = "花猪赔付"
				factor_text = _build_cha_jiao_factor_text(focus_assessment)
				score_text = "+%d" % maxi(1, int(focus_assessment.get("cha_jiao_score", 1)))
			elif focus_is_ting and not target_is_ting:
				reason_text = "查叫赔付"
				factor_text = _build_cha_jiao_factor_text(focus_assessment)
				score_text = "+%d" % maxi(1, int(focus_assessment.get("cha_jiao_score", 1)))

			if reason_text == "":
				continue
			lines.append({
				"reason": reason_text,
				"source": source_text,
				"factor": factor_text if factor_text != "" else "查叫",
				"score": score_text,
			})

	if lines.is_empty():
		lines.append({"reason": "本局暂无细分事件", "source": _seat_name(focus_seat), "factor": "-", "score": "%s%d" % ["+" if round_delta > 0 else "", round_delta]})
	else:
		var visible_total := _sum_settlement_breakdown_scores(lines)
		var undisplayed_delta := round_delta - visible_total
		if undisplayed_delta != 0:
			push_error("结算明细与权威总账不一致：seat=%d ledger=%d detail=%d" % [focus_seat, round_delta, visible_total])
			lines.append({
				"reason": "结算明细校验失败",
				"source": "权威总账与事件账本不一致",
				"factor": "差额 %+d" % undisplayed_delta,
				"score": "—",
			})
	return lines

func _sum_settlement_breakdown_scores(lines: Array[Dictionary]) -> int:
	var total := 0
	for item in lines:
		var score_text := str(item.get("score", "0")).strip_edges()
		if score_text.is_valid_int():
			total += int(score_text)
	return total

func get_settlement_ledger_contract(snapshot: Dictionary) -> Dictionary:
	var settlement_data: Dictionary = snapshot.get("settlement_data", {})
	var score_changes: Dictionary = settlement_data.get("score_changes", {})
	var players: Array = snapshot.get("players", [])
	var seat_rows := {}
	var net_change := 0
	var all_detail_sums_match := true
	for seat in range(PLAYER_COUNT):
		var authoritative_delta := int(score_changes.get(seat, 0))
		var lines := _build_settlement_breakdown_lines(players, settlement_data, seat, authoritative_delta)
		var detail_sum := _sum_settlement_breakdown_scores(lines)
		seat_rows[seat] = {
			"authoritative_delta": authoritative_delta,
			"detail_sum": detail_sum,
			"matches": detail_sum == authoritative_delta,
			"lines": lines,
		}
		net_change += authoritative_delta
		all_detail_sums_match = all_detail_sums_match and detail_sum == authoritative_delta
	return {
		"authoritative_path": "settlement_data/score_changes",
		"score_changes": score_changes.duplicate(true),
		"net_change": net_change,
		"net_zero": net_change == 0,
		"all_detail_sums_match": all_detail_sums_match,
		"ui_applies_self_draw_bonus": false,
		"seat_rows": seat_rows,
	}

func _build_cha_jiao_factor_text(item: Dictionary) -> String:
	var fan := int(item.get("cha_jiao_fan", 0))
	var score := int(item.get("cha_jiao_score", 0))
	if fan <= 0 and score <= 0:
		return "查叫"
	return "%d番/%d分" % [maxi(1, fan), maxi(1, score)]

func _find_draw_assessment_by_seat(settlement_data: Dictionary, seat: int) -> Dictionary:
	for item in settlement_data.get("draw_assessment", []):
		if int(item.get("seat", -1)) == seat:
			return item
	return {}

func _format_fan_and_basic_score(fan_detail: Dictionary, win_type: String = "") -> String:
	var capped_fan := int(fan_detail.get("capped_fan", 0))
	var hand_score := int(fan_detail.get("hand_score", _resolve_basic_score_from_fan(capped_fan)))
	var basic_score := int(fan_detail.get("per_payer_score", hand_score))
	var fan_text := "%d番（封顶）" % capped_fan if capped_fan >= 4 else "%d番" % capped_fan
	if basic_score != hand_score and (win_type == "self_draw" or win_type == "gang_self_draw"):
		return "%s / %d+自摸1=%d分" % [fan_text, hand_score, basic_score]
	return "%s / %d分" % [fan_text, basic_score]

func _build_event_factor_text(event: Dictionary, _players: Array) -> String:
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var win_type := str(event.get("win_type", "discard_win"))
	return _format_fan_and_basic_score(fan_detail, win_type)

func _resolve_basic_score_from_fan(capped_fan: int) -> int:
	return int(pow(2.0, maxi(0, capped_fan)))

func _resolve_event_total_score(event: Dictionary, players: Array) -> int:
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var payer_seats: Array = event.get("payer_seats", [])
	var total := 0
	for payer in payer_seats:
		total += _resolve_event_payment_for_payer(event, int(payer), players)
	return total

func _resolve_event_payment_for_payer(event: Dictionary, _payer_seat: int, _players: Array) -> int:
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var win_type: String = str(event.get("win_type", "discard_win"))
	var capped_fan := int(fan_detail.get("capped_fan", 0))
	var hand_score := int(fan_detail.get("hand_score", _resolve_basic_score_from_fan(capped_fan)))
	if win_type == "self_draw" or win_type == "gang_self_draw":
		# The rules layer owns the self-draw +1 and exports the authoritative
		# per-payer amount. The settlement UI must never manufacture another +1.
		return int(fan_detail.get("per_payer_score", hand_score))
	return hand_score

func _resolve_gang_event_total_score(event: Dictionary) -> int:
	var payer_seats: Array = event.get("payer_seats", [])
	var gang_type := str(event.get("gang_type", ""))
	var source_seat := int(event.get("source_seat", -1))
	var total := 0
	for payer in payer_seats:
		total += 2 if gang_type == "melded_gang" and int(payer) == source_seat else _resolve_gang_unit_score(gang_type if gang_type != "melded_gang" else "add_gang")
	return total

func _resolve_gang_unit_score(gang_type: String) -> int:
	match gang_type:
		"melded_gang", "an_gang":
			return 2
		"add_gang":
			return 1
		_:
			return 1

func _win_type_display_name(win_type: String) -> String:
	match win_type:
		"self_draw":
			return "自摸"
		"gang_self_draw":
			return "杠上花"
		"dian_gang_hua":
			return "点杠花"
		"discard_win":
			return "点炮胡"
		"gang_discard_win":
			return "杠上炮"
		"qiang_gang_hu":
			return "抢杠胡"
		_:
			return "胡牌"

func _hand_type_display_name(hand_type: String) -> String:
	match hand_type:
		"ping_hu":
			return "平胡"
		"qi_dui":
			return "暗七对"
		"long_qi_dui":
			return "龙七对"
		"qing_yi_se":
			return "清一色"
		"qing_dui":
			return "清对"
		"qing_qi_dui":
			return "清七对"
		"qing_long_qi_dui":
			return "青龙七对"
		"da_dui_zi":
			return "大对子"
		"dui_dui_hu":
			return "对对胡"
		"jiang_dui":
			return "将对"
		"dai_yao_jiu":
			return "带幺九"
		_:
			return "成牌"

func _gang_type_display_name(gang_type: String) -> String:
	match gang_type:
		"melded_gang":
			return "明杠"
		"an_gang":
			return "暗杠"
		"add_gang":
			return "补杠"
		_:
			return "杠"

func _refund_payers_display(payer_seats: Array) -> String:
	if payer_seats.is_empty():
		return "-"
	var names: Array[String] = []
	for seat in payer_seats:
		names.append(_seat_name(int(seat)))
	return " / ".join(names)
