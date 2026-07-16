extends SceneTree

const JUDGE_SCRIPT := preload("res://scripts/ai/sichuan_old_hand_discard_scorer.gd")


func _init() -> void:
	var judge = JUDGE_SCRIPT.new()
	var objectively_strong := {
		"csharp_tile_type": 3,
		"tile_name": "4条",
		"score": -999999,
		"shanten": 0,
		"live_ukeire": 8,
		"wait_count": 2,
		"risk": 24,
		"expected_net_score": 4.2,
	}
	var online_score_favorite := {
		"csharp_tile_type": 12,
		"tile_name": "4筒",
		"score": 999999,
		"shanten": 2,
		"live_ukeire": 4,
		"wait_count": 0,
		"risk": 65,
		"expected_net_score": -0.6,
	}
	var result: Dictionary = judge.score_analysis(
		{"options": [objectively_strong, online_score_favorite]},
		3,
		0,
		1,
		1
	)
	if str(result.get("score_source", "")) != "independent_rule_judge_v2":
		push_error("Independent judge did not report its own score source")
		quit(1)
		return
	if int(result.get("best_tile_type", -1)) != 3 or int(result.get("rank", 0)) != 1:
		push_error("Independent judge followed the online score instead of objective outcomes")
		quit(2)
		return
	var route_consistent := objectively_strong.duplicate(true)
	route_consistent["csharp_tile_type"] = 6
	route_consistent["route_plan_score"] = 900
	route_consistent["wait_shape_score"] = 12.0
	var route_breaking := objectively_strong.duplicate(true)
	route_breaking["csharp_tile_type"] = 7
	route_breaking["route_plan_score"] = -900
	route_breaking["wait_shape_score"] = -6.0
	route_breaking["route_loss"] = ["清一色"]
	var theory_result: Dictionary = judge.score_analysis(
		{"options": [route_breaking, route_consistent]},
		6,
		0,
		2,
		8
	)
	if int(theory_result.get("best_tile_type", -1)) != 6:
		push_error("Independent judge ignored route continuity and wait quality")
		quit(3)
		return
	print("INDEPENDENT JUDGE REGRESSION OK")
	quit()
