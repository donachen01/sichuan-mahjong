extends "res://tests/current/sichuan_ai_pressure_benchmark.gd"

# Explicit research experiment; no default seeds or standing regression list.
# Both arms contain the legality/transport fixes. Only shape calculation differs.
func _run() -> void:
	var deals := _read_nonnegative_int_arg("--rounds=", -1)
	var seed_base := _read_nonnegative_int_arg("--seed-base=", -1)
	if deals < 1 or seed_base < 0:
		push_error("Theory comparison requires explicit rounds and seed-base")
		quit(2)
		return
	var pairs: Array = []
	var failures := 0
	for deal in range(deals):
		for seat in range(4):
			var seed := seed_base + deal * 1009
			var candidate: Dictionary = await _run_policy_arm(seed, seat, "current", 5000,
				deal * 8 + seat * 2, "theory_shape", true, false, false, "theory_shape_legacy")
			var baseline: Dictionary = await _run_policy_arm(seed, seat, "theory_shape_legacy", 5000,
				deal * 8 + seat * 2 + 1, "legacy_shape", true, false, false, "theory_shape_legacy")
			var valid: bool = bool(candidate.completed) and bool(baseline.completed) \
				and bool(candidate.ledger_balanced) and bool(baseline.ledger_balanced) \
				and candidate.initial_world_hash == baseline.initial_world_hash \
				and bool(candidate.checkpoint_legality.passed) and bool(baseline.checkpoint_legality.passed)
			if not valid:
				failures += 1
			pairs.append({"seed": seed, "seat": seat, "valid": valid,
				"delta": float(candidate.seat_delta) - float(baseline.seat_delta),
				"candidate": candidate, "baseline": baseline})
			print("theory_pair seed=", seed, " seat=", seat, " valid=", valid)
			_write_report({"scope": "natural paired rounds; exact versus local-neighbor shape only",
				"deals_requested": deals, "seed_base": seed_base, "invalid_pairs": failures,
				"complete": deal == deals - 1 and seat == 3, "pairs": pairs},
				_read_string_arg("--output=", "res://tmp/theory-paired.json"))
	quit(0 if failures == 0 else 1)
