extends SceneTree

const STATE := preload("res://autoload/GameState.gd")
const SCORE := preload("res://scripts/core/score_resolver.gd")
const LEDGER := preload("res://scripts/game/presentation/settlement_ledger.gd")
var failures: Array[String] = []
var rows: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for kind in ["add_gang", "an_gang", "melded_gang"]:
		for payer_count in [1, 2, 3]:
			for winner in range(1, 4):
				var state = STATE.new()
				state.rules = preload("res://scripts/core/rule_config.gd").new()
				state.score_resolver = SCORE.new()
				for seat in range(4):
					state.players.append({"seat": seat, "nickname": "P%d" % seat, "score": 0, "has_won": false})
				state.settlement_data = state._create_empty_settlement_data()
				var payers: Array = []
				var total := 0
				for seat in range(1, payer_count + 1):
					payers.append(seat)
					total += _payment(kind, seat)
				var tile := {"id": 0, "suit": "tong", "rank": 1}
				state._append_settlement_gang_event(0, 1, tile, kind, payers)
				for payer in payers:
					_check(int(state.players[payer]["score"]) == -_payment(kind, payer), "immediate original expense")
				state._mark_latest_gang_outcome("gang_discard_win")
				state._append_hu_jiao_zhuan_yi_event(0, winner, tile)
				var changes: Dictionary = state.score_resolver.build_score_changes(state.players, state.settlement_data, state.rules)
				var sum := 0
				var winner_lines: Array = []
				for seat in range(4):
					var expected := total if seat == winner else 0
					if payers.has(seat):
						expected -= _payment(kind, seat)
					_check(int(changes[seat]) == expected, "independent authoritative total")
					_check(int(state.players[seat]["score"]) == expected, "immediate/final agreement")
					var lines: Array[Dictionary] = LEDGER._build_settlement_breakdown_lines(state.players, state.settlement_data, seat, expected, func(s: int): return "P%d" % s)
					_check(LEDGER._sum_settlement_breakdown_scores(lines) == expected, "detail total seat%d %s" % [seat, kind])
					for line in lines:
						_check(not str(line.get("reason")).contains("校验失败"), "no balancing/error row")
					if seat == winner:
						winner_lines = lines
						_check(_has_row(lines, "呼叫转移", total), "full transfer including own returned payment")
						if payers.has(seat):
							_check(_has_row(lines, "支付", -_payment(kind, seat)), "winner original expense remains")
					if seat == 0:
						_check(_has_row(lines, "杠", total) and _has_row(lines, "支付呼叫转移", -total), "actor receipt and transfer separate")
					elif seat != winner and payers.has(seat):
						_check(not _has_row(lines, "支付呼叫转移", -_payment(kind, seat)), "other payer not charged again")
					sum += int(changes[seat])
				_check(sum == 0, "zero sum")
				rows.append({"kind": kind, "payer_count": payer_count, "winner": winner, "transfer": total, "winner_delta": int(changes[winner]), "winner_lines": winner_lines})
				state.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "rows": rows}, "  "))
	print("GANG_TRANSFER_LEDGER cases=", rows.size(), " failures=", failures.size())
	if not failures.is_empty():
		print("FIRST_FAILURES ", failures.slice(0, 8))
	quit(0 if failures.is_empty() else 1)

func _payment(kind: String, payer: int) -> int:
	return 1 if kind == "add_gang" or (kind == "melded_gang" and payer != 1) else 2

func _has_row(lines: Array, reason_part: String, score: int) -> bool:
	for line in lines:
		if str(line.get("reason")).contains(reason_part) and str(line.get("score")).is_valid_int() and int(line["score"]) == score:
			return true
	return false

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
