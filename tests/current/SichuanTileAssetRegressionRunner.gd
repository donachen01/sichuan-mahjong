extends SceneTree

const WAN_SYMBOL_DIRS := [
	"res://res/art/ui_3d_cartoon/tile_symbols",
	"res://res/art/tiles",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for dir in WAN_SYMBOL_DIRS:
		for rank in range(1, 10):
			var path := "%s/wan_%d.png" % [dir, rank]
			var result: Variant = _check_wan_symbol_color(path)
			if typeof(result) != TYPE_BOOL or not bool(result):
				failures.append(str(result))
	if failures.is_empty():
		print("SICHUAN TILE ASSET REGRESSION OK: wan digits are black and wan glyphs are bright red")
		quit(0)
		return
	push_error("SICHUAN TILE ASSET REGRESSION FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _check_wan_symbol_color(path: String):
	var image := Image.new()
	var load_result := image.load(ProjectSettings.globalize_path(path))
	if load_result != OK:
		return "expected readable tile symbol: %s" % path
	var split_y := _resolve_wan_symbol_split_y(image)
	if split_y <= 0:
		return "expected two visible wan symbol zones: %s" % path
	var top_stats := _average_visible_color(image, 0, split_y)
	var bottom_stats := _average_visible_color(image, split_y + 1, image.get_height() - 1)
	if float(top_stats.get("alpha", 0.0)) <= 0.0:
		return "expected visible black digit pixels: %s" % path
	if float(bottom_stats.get("alpha", 0.0)) <= 0.0:
		return "expected visible red wan glyph pixels: %s" % path
	var top_red := float(top_stats.get("red", 0.0))
	var top_green := float(top_stats.get("green", 0.0))
	var top_blue := float(top_stats.get("blue", 0.0))
	if top_red > 0.18 or top_green > 0.18 or top_blue > 0.18:
		return "expected black wan digit at %s, top avg=(%.3f, %.3f, %.3f)" % [path, top_red, top_green, top_blue]
	var bottom_red := float(bottom_stats.get("red", 0.0))
	var bottom_green := float(bottom_stats.get("green", 0.0))
	var bottom_blue := float(bottom_stats.get("blue", 0.0))
	if bottom_red < 0.55 or bottom_red < bottom_green * 4.0 or bottom_red < bottom_blue * 4.0:
		return "expected bright red wan glyph at %s, bottom avg=(%.3f, %.3f, %.3f)" % [path, bottom_red, bottom_green, bottom_blue]
	var red_center_x := _average_visible_red_x(image, split_y + 1, image.get_height() - 1)
	var canvas_center_x := float(image.get_width() - 1) * 0.5
	if absf(red_center_x - canvas_center_x) > 2.0:
		return "expected centered red wan glyph at %s, red_center=%.2f canvas_center=%.2f" % [path, red_center_x, canvas_center_x]
	return true


func _resolve_wan_symbol_split_y(image: Image) -> int:
	var rows: Array[int] = []
	for y in range(image.get_height()):
		var visible_count := 0
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.06:
				visible_count += 1
		if visible_count > 0:
			rows.append(y)
	if rows.size() < 2:
		return -1
	var groups: Array[Vector2i] = []
	var start := int(rows[0])
	var previous := int(rows[0])
	for index in range(1, rows.size()):
		var row := int(rows[index])
		if row == previous + 1:
			previous = row
			continue
		groups.append(Vector2i(start, previous))
		start = row
		previous = row
	groups.append(Vector2i(start, previous))
	if groups.size() < 2:
		return rows[0] + int((rows[rows.size() - 1] - rows[0]) * 0.43)
	return groups[groups.size() - 1].x - 1


func _average_visible_color(image: Image, y_start: int, y_end: int) -> Dictionary:
	var red_sum := 0.0
	var green_sum := 0.0
	var blue_sum := 0.0
	var alpha_sum := 0.0
	for y in range(maxi(0, y_start), mini(image.get_height() - 1, y_end) + 1):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.06:
				continue
			red_sum += color.r * color.a
			green_sum += color.g * color.a
			blue_sum += color.b * color.a
			alpha_sum += color.a
	if alpha_sum <= 0.0:
		return {"alpha": 0.0, "red": 0.0, "green": 0.0, "blue": 0.0}
	return {
		"alpha": alpha_sum,
		"red": red_sum / alpha_sum,
		"green": green_sum / alpha_sum,
		"blue": blue_sum / alpha_sum,
	}


func _average_visible_red_x(image: Image, y_start: int, y_end: int) -> float:
	var x_sum := 0.0
	var alpha_sum := 0.0
	for y in range(maxi(0, y_start), mini(image.get_height() - 1, y_end) + 1):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.06:
				continue
			if color.r <= 0.30 or color.r <= color.g * 1.55 or color.r <= color.b * 1.55:
				continue
			x_sum += float(x) * color.a
			alpha_sum += color.a
	if alpha_sum <= 0.0:
		return -999.0
	return x_sum / alpha_sum
