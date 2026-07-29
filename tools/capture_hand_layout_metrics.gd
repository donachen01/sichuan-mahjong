extends SceneTree

const HAND_CANVAS := preload("res://scripts/ui/HandCanvas2D.gd")
const TABLE_STAGE := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const TILE_3D := preload("res://scripts/ui/3d/SichuanTile3D.gd")
const CANVAS_SIZE := Vector2(2008.0, 262.0)
const EPSILON := 0.01


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hand := HAND_CANVAS.new() as Node2D
	get_root().add_child(hand)
	var tiles: Array = []
	for index in range(14):
		tiles.append({"id": 8100 + index, "suit": ["wan", "tong", "tiao"][index % 3], "rank": index % 9 + 1})

	hand.call("configure", tiles, -1, -1, CANVAS_SIZE, {}, {})
	var baseline_layouts: Array = hand.call("get_layout_contract")
	var baseline_bounds: Rect2 = hand.call("get_layout_bounds")

	hand.call("configure", tiles, 8106, 8113, CANVAS_SIZE, {}, {})
	var feedback_layouts: Array = hand.call("get_layout_contract")
	var selected_lift := _top(feedback_layouts, 5) - _top(feedback_layouts, 6)
	var draw_lift := _top(feedback_layouts, 12) - _top(feedback_layouts, 13)
	var regular_step := _left(baseline_layouts, 1) - _left(baseline_layouts, 0)
	var draw_step_with_gap := _left(feedback_layouts, 13) - _left(feedback_layouts, 12)
	var draw_gap := draw_step_with_gap - regular_step

	hand.call("configure", tiles, -1, -1, CANVAS_SIZE, {"winning_tile_id": 8113}, {})
	var winning_layouts: Array = hand.call("get_layout_contract")
	var winning_gap := (_left(winning_layouts, 13) - _left(winning_layouts, 12)) - regular_step

	var expected_width := HAND_CANVAS.TILE_FACE_SIZE.x + HAND_CANVAS.TILE_STEP_MAX * 13.0 + 9.0
	var expected_bounds := Rect2(
		Vector2(floor((CANVAS_SIZE.x - (HAND_CANVAS.TILE_FACE_SIZE.x + HAND_CANVAS.TILE_STEP_MAX * 13.0)) * 0.5), CANVAS_SIZE.y - 34.0 - HAND_CANVAS.TILE_FACE_SIZE.y),
		Vector2(expected_width, HAND_CANVAS.TILE_FACE_SIZE.y + 12.0)
	)
	var max_bounds_error := _max_rect_error(baseline_bounds, expected_bounds)
	var result := {
		"criterion": "AC-HAND-01/02",
		"canvas_size": [CANVAS_SIZE.x, CANVAS_SIZE.y],
		"tile_count": baseline_layouts.size(),
		"frozen_metrics": {
			"face_width_px": HAND_CANVAS.TILE_FACE_SIZE.x,
			"face_height_px": HAND_CANVAS.TILE_FACE_SIZE.y,
			"max_step_px": HAND_CANVAS.TILE_STEP_MAX,
			"new_draw_gap_px": HAND_CANVAS.NEW_DRAW_GAP,
			"winning_tile_gap_px": HAND_CANVAS.WINNING_TILE_GAP,
			"selected_lift_px": HAND_CANVAS.SELECTED_LIFT,
			"new_draw_lift_px": HAND_CANVAS.NEW_DRAW_LIFT,
		},
		"measured_metrics": {
			"regular_step_px": regular_step,
			"new_draw_gap_px": draw_gap,
			"winning_tile_gap_px": winning_gap,
			"selected_lift_px": selected_lift,
			"new_draw_lift_px": draw_lift,
			"baseline_bounds": _rect_json(baseline_bounds),
			"expected_bounds": _rect_json(expected_bounds),
			"max_bounds_error_px": max_bounds_error,
		},
		"animation_contract_ms": {
			"new_draw_travel": TABLE_STAGE.DRAW_TRAVEL_SECONDS * 1000.0,
			"new_draw_settle": TABLE_STAGE.DRAW_SETTLE_SECONDS * 1000.0,
			"selected_hand_fade": TILE_3D.SELECTED_HAND_FADE_SECONDS * 1000.0,
			"reduced_motion_stops_loops": true,
		},
		"objective_result": "PASS" if baseline_layouts.size() == 14 \
			and absf(regular_step - 136.0) <= EPSILON \
			and absf(draw_gap - 22.0) <= EPSILON \
			and absf(winning_gap - 24.0) <= EPSILON \
			and absf(selected_lift - 18.0) <= EPSILON \
			and absf(draw_lift - 8.0) <= EPSILON \
			and TABLE_STAGE.DRAW_TRAVEL_SECONDS >= 0.18 and TABLE_STAGE.DRAW_TRAVEL_SECONDS <= 0.22 \
			and TABLE_STAGE.DRAW_SETTLE_SECONDS >= 0.04 and TABLE_STAGE.DRAW_SETTLE_SECONDS <= 0.06 \
			and TILE_3D.SELECTED_HAND_FADE_SECONDS >= 0.12 and TILE_3D.SELECTED_HAND_FADE_SECONDS <= 0.16 \
			and max_bounds_error <= 1.0 else "FAIL",
	}
	var output_path := _output_path()
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write hand metrics: %s" % absolute_path)
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print(JSON.stringify(result))
	print(absolute_path)
	hand.free()
	quit(0 if result["objective_result"] == "PASS" else 1)


func _top(layouts: Array, index: int) -> float:
	return float((layouts[index].get("front_rect", Rect2()) as Rect2).position.y)


func _left(layouts: Array, index: int) -> float:
	return float((layouts[index].get("front_rect", Rect2()) as Rect2).position.x)


func _max_rect_error(actual: Rect2, expected: Rect2) -> float:
	return maxf(
		maxf(absf(actual.position.x - expected.position.x), absf(actual.position.y - expected.position.y)),
		maxf(absf(actual.size.x - expected.size.x), absf(actual.size.y - expected.size.y))
	)


func _rect_json(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return "user://hand_layout_metrics.json"
