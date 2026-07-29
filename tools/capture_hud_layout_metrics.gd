extends SceneTree

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const DEFAULT_OUTPUT := "res://evidence/ui_emerald_final_20260726/stage2_dq_center/hud_rects_four_resolutions.json"
const VIEWPORTS := [
	Vector2(1365.0, 768.0),
	Vector2(2048.0, 1152.0),
	Vector2(2400.0, 1080.0),
	Vector2(2556.0, 1179.0),
]


func _init() -> void:
	var cases: Array = []
	var passed := true
	for viewport in VIEWPORTS:
		var compact := METRICS.is_compact(viewport)
		var minimum := Vector2(196.0, 146.0) if compact else Vector2(230.0, 156.0)
		var seats: Array = []
		for seat in range(4):
			var rect := METRICS.seat_hud_rect(seat, viewport)
			var inside := Rect2(Vector2.ZERO, viewport).encloses(rect)
			var meets_minimum := rect.size.x >= minimum.x and rect.size.y >= minimum.y
			passed = passed and inside and meets_minimum
			seats.append({
				"seat": seat,
				"x": rect.position.x,
				"y": rect.position.y,
				"width": rect.size.x,
				"height": rect.size.y,
				"inside_viewport": inside,
				"meets_minimum": meets_minimum,
			})
		cases.append({
			"resolution": "%dx%d" % [int(viewport.x), int(viewport.y)],
			"layout_mode": "compact" if compact else "standard",
			"required_minimum": {"width": minimum.x, "height": minimum.y},
			"seats": seats,
		})
	var payload := {
		"criterion": "AC-HUD-01",
		"cases": cases,
		"animation_rect_tolerance_px": 1.0,
		"implementation_changes_panel_rect": false,
		"objective_result": "PASS" if passed else "FAIL",
	}
	var output := DEFAULT_OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write HUD metrics: %s" % output)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	print(ProjectSettings.globalize_path(output))
	quit(0 if passed else 1)
