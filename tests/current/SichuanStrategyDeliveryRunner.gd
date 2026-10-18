extends "res://tests/current/sichuan_ai_pressure_benchmark.gd"

# Runs actual gameplay to full Sichuan settlement. Each arm is executed in its
# independently frozen project, rather than labelling two current policies as versions.
func _run() -> void:
	var started := Time.get_datetime_string_from_system(true) + "Z"
	var rows: Array[Dictionary] = []
	var rounds := _read_int_arg("--rounds=", 2)
	var seed_base := _read_int_arg("--seed-base=", 20261002)
	var opponent := _read_string_arg("--opponent-variant=", "frozen_hard_tier_v1")
	var variant := _read_string_arg("--variant=", "bucket_local_candidate_v1")
	var arm_name := _read_string_arg("--arm=", "candidate")
	for deal in range(rounds):
		var seed := seed_base + deal * 1009
		for seat in range(4):
			print("delivery_start arm=", arm_name, " seed=", seed, " seat=", seat)
			var arm: Dictionary = await _run_policy_arm(seed, seat, variant, 1500,
				deal * 4 + seat + 1, "delivery_" + arm_name, true, false, false, opponent)
			rows.append({"seed": seed, "seat": seat, "arm": arm})
	_write_report({"arm": arm_name, "opponent": opponent, "started_at": started,
		"completed_at": Time.get_datetime_string_from_system(true) + "Z", "rows": rows},
		_read_string_arg("--output=", "res://evidence/strategy_delivery_20261002/candidate-rounds.json"))
	quit()
