extends SceneTree

const Rotation := preload("res://scripts/core/dealer_rotation.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _event(winner: int, source: int, tile_id: int, kind: String = "discard_win") -> Dictionary:
	return {"winner_seat": winner, "source_seat": source, "winning_tile": {"id": tile_id}, "win_type": kind}

func _check(events: Array, expected: int, reason: String) -> void:
	if Rotation.next_dealer(events, 4, 3) != expected:
		failures.append(reason)

func _run() -> void:
	_check([], 3, "无人胡牌应留庄")
	_check([_event(2, 2, 10, "self_draw"), _event(1, 0, 11), _event(3, 0, 11)], 2, "先自摸后多响不能改首胡庄")
	_check([_event(1, 0, 20), _event(2, 0, 21), _event(3, 0, 21)], 1, "先单胡后同一人再次点炮多响不能改庄")
	_check([_event(1, 0, 20), _event(2, 0, 21)], 1, "同一人先后两次点炮不是一炮双响")
	_check([_event(1, 0, 20), _event(2, 0, 20)], 0, "首批双响由点炮者坐庄")
	_check([_event(1, 0, 20), _event(2, 0, 20), _event(3, 0, 20)], 0, "首批三响由点炮者坐庄")
	_check([_event(1, 0, 30, "gang_discard_win"), _event(2, 0, 30, "gang_discard_win")], 0, "首批杠后点炮双响")
	_check([_event(1, 0, 31, "qiang_gang_hu"), _event(2, 0, 31, "qiang_gang_hu")], 0, "保留首批抢杠双响归属")
	_check([_event(1, 0, 20), _event(1, 0, 20)], 1, "重复同一赢家不是多响")
	_check([{"winner_seat": 1, "source_seat": 0, "win_type": "discard_win"}, {"winner_seat": 2, "source_seat": 0, "win_type": "discard_win"}], 1, "缺失出牌身份不能猜为同时胡牌")
	var state = root.get_node("GameState")
	state.start_new_round()
	state.settlement_data["win_events"] = [_event(1, 0, 20), _event(2, 0, 21), _event(3, 0, 21)]
	if state._resolve_next_dealer_seat() != 1:
		failures.append("GameState 未使用新规则")
	state.current_phase = 7
	state.advance_to_next_round()
	if state.current_dealer_seat != 1:
		failures.append("真实下一局没有使用首胡庄")
	if failures.is_empty():
		print("DEALER_ROTATION_PASS cases=11")
		quit(0)
	else:
		push_error("\n".join(failures))
		quit(1)
