extends "res://tests/current/sichuan_ai_pressure_benchmark.gd"

# Opt-in experiment for the public continuation selector. Both arms use the
# current engine; the baseline disables only this selector. This is not a
# comparison with the previously released engine or a standing test manifest.
func _run() -> void:
	var deals := _read_int_arg("--rounds=", 8)
	var seed_base := _read_int_arg("--seed-base=", 20260929)
	var pairs: Array = []
	var deltas: Array[float] = []
	var failures := 0
	for deal in range(deals):
		for seat in range(4):
			var seed := seed_base + deal * 1009
			var candidate: Dictionary = await _run_policy_arm(seed, seat, "current", 5000,
				deal * 8 + seat * 2, "continuation", true, false, false, "continuation_disabled")
			var baseline: Dictionary = await _run_policy_arm(seed, seat, "continuation_disabled", 5000,
				deal * 8 + seat * 2 + 1, "no_continuation", true, false, false, "continuation_disabled")
			var valid: bool = bool(candidate.completed) and bool(baseline.completed) \
				and bool(candidate.ledger_balanced) and bool(baseline.ledger_balanced) \
				and candidate.initial_world_hash == baseline.initial_world_hash \
				and bool(candidate.checkpoint_legality.passed) and bool(baseline.checkpoint_legality.passed)
			if not valid:
				failures += 1
			var delta := float(candidate.seat_delta) - float(baseline.seat_delta)
			deltas.append(delta)
			pairs.append({"seed": seed, "seat": seat, "valid": valid,
				"delta": delta, "candidate": candidate, "baseline": baseline})
			print("continuation_pair seed=", seed, " seat=", seat, " delta=", delta, " valid=", valid)
	var total := 0.0
	for delta in deltas:
		total += delta
	var report := {"scope": "current continuation selector versus same engine with selector disabled",
		"deals": deals, "seed_base": seed_base, "invalid_pairs": failures,
		"pairs": pairs, "mean_delta": total / max(1, deltas.size())}
	_write_report(report, _read_string_arg("--output=", "res://evidence/ai_continuation_20260928/paired_games.json"))
	quit(0 if failures == 0 else 1)
