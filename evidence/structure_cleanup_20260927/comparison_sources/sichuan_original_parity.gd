extends SceneTree
const OriginalSnapshot = preload("res://evidence/structure_cleanup_20260927/comparison_sources/sichuan_original_snapshot.gd")
const OriginalLedger = preload("res://evidence/structure_cleanup_20260927/comparison_sources/sichuan_original_ledger.gd")
const Ledger = preload("res://scripts/game/presentation/settlement_ledger.gd")
func _initialize():
	call_deferred("_run")
func _run():
	var state = root.get_node("GameState")
	state.set_test_seed(812)
	state.start_new_round()
	var mismatch = []
	for seat in range(4):
		if OriginalSnapshot.build(state,seat) != state.get_debug_snapshot(seat):
			mismatch.append("original diagnostic snapshot differs at seat %d" % seat)
	var old_ledger = OriginalLedger.new()
	for item in _ledger_cases():
		var expected = old_ledger.get_settlement_ledger_contract(item.snapshot)
		var actual = Ledger.get_settlement_ledger_contract(item.snapshot,old_ledger._seat_name)
		if actual != expected or not actual.net_zero or not actual.all_detail_sums_match:
			mismatch.append("ledger differs: "+item.name)
	print("ORIGINAL_PARITY_RESULT ",JSON.stringify({"diagnostic_seats":4,"ledger_cases":5,"failures":mismatch}))
	quit(0 if mismatch.is_empty() else 1)

func _ledger_cases() -> Array[Dictionary]:
	return [
		{"name": "self_draw", "snapshot": _win_snapshot(
			"self_draw", 0, 0, {0: 15, 1: -5, 2: -5, 3: -5}, [1, 2, 3],
			{"capped_fan": 2, "hand_score": 4, "per_payer_score": 5, "labels": ["清一色", "自摸"]}
		)},
		{"name": "discard_win", "snapshot": _win_snapshot(
			"discard_win", 1, 2, {0: 0, 1: 8, 2: -8, 3: 0}, [2],
			{"capped_fan": 3, "hand_score": 8, "per_payer_score": 8, "labels": ["清一色", "点炮"]}
		)},
		{"name": "gang_self_draw", "snapshot": _gang_self_draw_snapshot()},
		{"name": "qiang_gang_hu", "snapshot": _win_snapshot(
			"qiang_gang_hu", 2, 3, {0: 0, 1: 0, 2: 4, 3: -4}, [3],
			{"capped_fan": 2, "hand_score": 4, "per_payer_score": 4, "labels": ["抢杠胡"]}
		)},
		{"name": "draw_wall_empty", "snapshot": _draw_snapshot()},
	]


func _win_snapshot(win_type: String, winner: int, source: int, changes: Dictionary, payers: Array, fan_detail: Dictionary) -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot["settlement_data"] = {
		"round_index": 11,
		"dealer_seat": 0,
		"end_reason": "battle_end",
		"winner_seats": [winner],
		"score_changes": changes,
		"win_events": [{
			"winner_seat": winner,
			"source_seat": source,
			"payer_seats": payers,
			"win_type": win_type,
			"winning_tile": {"id": 9900 + winner, "suit": "wan", "rank": 9},
			"fan_detail": fan_detail,
		}],
		"gang_events": [],
	}
	return snapshot


func _gang_self_draw_snapshot() -> Dictionary:
	var snapshot := _win_snapshot(
		"gang_self_draw", 0, 0, {0: 21, 1: -7, 2: -7, 3: -7}, [1, 2, 3],
		{"capped_fan": 2, "hand_score": 4, "per_payer_score": 5, "labels": ["清一色", "杠上花"]}
	)
	snapshot["settlement_data"]["gang_events"] = [{
		"actor_seat": 0,
		"gang_type": "an_gang",
		"payer_seats": [1, 2, 3],
	}]
	return snapshot


func _draw_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot["settlement_data"] = {
		"round_index": 12,
		"dealer_seat": 0,
		"end_reason": "draw_wall_empty",
		"winner_seats": [],
		"score_changes": {0: -4, 1: 4, 2: 4, 3: -4},
		"win_events": [],
		"gang_events": [],
		"draw_assessment": [
			{"seat": 0, "is_ting": false, "hua_zhu": false, "cha_jiao_score": 0},
			{"seat": 1, "is_ting": true, "hua_zhu": false, "cha_jiao_fan": 1, "cha_jiao_score": 2},
			{"seat": 2, "is_ting": true, "hua_zhu": false, "cha_jiao_fan": 1, "cha_jiao_score": 2},
			{"seat": 3, "is_ting": false, "hua_zhu": false, "cha_jiao_score": 0},
		],
	}
	return snapshot


func _base_snapshot() -> Dictionary:
	var players: Array = []
	for seat in range(4):
		var hand_tiles: Array = []
		for index in range(7):
			hand_tiles.append({"id": seat * 100 + index, "suit": ["tiao", "tong", "wan"][index % 3], "rank": index % 9 + 1})
		players.append({
			"seat": seat,
			"nickname": ["本家", "上家", "对家", "下家"][seat],
			"score": 100,
			"hand_tiles": hand_tiles,
			"melds": [],
			"ding_que": ["tong", "wan", "tiao", "wan"][seat],
			"has_won": false,
		})
	return {
		"current_phase": 7,
		"round_index": 11,
		"current_dealer_seat": 0,
		"ai_tuning_config": {"preset_name": "bone_ash"},
		"rules": {"use_ding_que_phase": true},
		"players": players,
		"settlement_data": {},
	}
