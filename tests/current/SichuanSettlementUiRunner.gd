extends SceneTree

const SETTLEMENT_SCENE := preload("res://scenes/ui/table/SettlementOverlay.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(2048, 1152)
	var overlay := SETTLEMENT_SCENE.instantiate() as Control
	get_root().add_child(overlay)
	await process_frame
	await process_frame
	var failures: Array[String] = []

	_verify_case(overlay, _snapshot("self_draw", 0, 0, {0: 15, 1: -5, 2: -5, 3: -5}, 3, ["清一色"]), 0, "自摸", 15, 3, failures)
	_verify_case(overlay, _snapshot("discard", 1, 2, {0: 0, 1: 4, 2: -4, 3: 0}, 3, ["碰碰和"]), 1, "胡牌", 4, 3, failures)
	_verify_case(overlay, _snapshot("qiang_gang_hu", 2, 3, {0: 0, 1: 0, 2: 4, 3: -4}, 3, ["抢杠胡"]), 2, "抢杠胡", 4, 3, failures)

	var blood_snapshot := _base_snapshot()
	blood_snapshot["settlement_data"] = {
		"round_index": 4,
		"end_reason": "battle_end",
		"winner_seats": [1, 3],
		"score_changes": {0: -6, 1: 4, 2: -2, 3: 4},
		"win_events": [
			{"winner_seat": 1, "source_seat": 0, "win_type": "discard", "fan_detail": {"capped_fan": 3, "labels": ["清一色"]}},
			{"winner_seat": 3, "source_seat": 2, "win_type": "discard", "fan_detail": {"capped_fan": 2, "labels": ["平和"]}},
		],
	}
	_verify_case(overlay, blood_snapshot, 1, "胡牌", 4, 3, failures)
	var contract: Dictionary = overlay.call("get_display_contract")
	if contract.get("score_changes", {}) != blood_snapshot["settlement_data"]["score_changes"]:
		failures.append("blood-battle score changes must be displayed without UI recomputation")

	var draw_snapshot := _base_snapshot()
	draw_snapshot["settlement_data"] = {
		"round_index": 5,
		"end_reason": "draw_wall_empty",
		"winner_seats": [],
		"score_changes": {0: -8, 1: 4, 2: 4, 3: 0},
		"hua_zhu_seats": [0],
		"cha_jiao_seats": [1],
		"ting_seats": [1, 2],
		"display_lines": ["花猪赔付：本家 -8", "查叫收益：上家 +4"],
	}
	overlay.call("render", draw_snapshot)
	overlay.call("set_selected_seat", 0)
	contract = overlay.call("get_display_contract")
	if str(contract.get("result_text", "")) != "流局" or int(contract.get("delta", 0)) != -8:
		failures.append("draw settlement must preserve the snapshot result and score")
	var fan_label: Label = overlay.get("fan_label")
	var breakdown_label: Label = overlay.get("breakdown_label")
	if not fan_label.text.contains("花猪") or not breakdown_label.text.contains("花猪赔付：本家 -8"):
		failures.append("draw settlement must display snapshot hua-zhu/cha-jiao details")

	var next_button: Button = overlay.call("get_next_round_button")
	if next_button == null or not next_button.visible or next_button.custom_minimum_size.x < 152.0 or next_button.custom_minimum_size.y < 64.0:
		failures.append("next-round entry must be visible and touchable only inside settlement")

	overlay.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SICHUAN SETTLEMENT UI OK: 5 CASES")
		quit(0)
		return
	push_error("SICHUAN SETTLEMENT UI FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_case(overlay: Control, snapshot: Dictionary, expected_seat: int, expected_result: String, expected_delta: int, expected_fan: int, failures: Array[String]) -> void:
	overlay.call("render", snapshot)
	var contract: Dictionary = overlay.call("get_display_contract")
	if int(contract.get("selected_seat", -1)) != expected_seat:
		failures.append("settlement focus seat mismatch for %s" % expected_result)
	if str(contract.get("result_text", "")) != expected_result:
		failures.append("settlement result mismatch: expected %s, got %s" % [expected_result, contract.get("result_text", "")])
	if int(contract.get("delta", 0)) != expected_delta:
		failures.append("settlement delta must equal snapshot for %s" % expected_result)
	if int(contract.get("fan", 0)) != expected_fan:
		failures.append("settlement fan must equal snapshot for %s" % expected_result)


func _snapshot(win_type: String, winner: int, source: int, changes: Dictionary, fan: int, labels: Array) -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot["settlement_data"] = {
		"round_index": 2,
		"end_reason": "battle_end",
		"winner_seats": [winner],
		"score_changes": changes,
		"win_events": [{
			"winner_seat": winner,
			"source_seat": source,
			"win_type": win_type,
			"winning_tile": {"id": 99, "suit": "wan", "rank": 9, "display_name": "9万"},
			"fan_detail": {"capped_fan": fan, "labels": labels},
		}],
	}
	return snapshot


func _base_snapshot() -> Dictionary:
	var players: Array = []
	for seat in range(4):
		players.append({
			"seat": seat,
			"nickname": ["本家", "上家", "对家", "下家"][seat],
			"score": 100,
			"hand_tiles": [{"id": seat * 10 + 1, "suit": "wan", "rank": seat + 1, "display_name": "%d万" % (seat + 1)}],
			"melds": [],
		})
	return {"round_index": 1, "players": players, "settlement_data": {}}
