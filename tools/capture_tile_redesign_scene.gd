extends SceneTree

const DEFAULT_OUTPUT_PATH := "user://capture_tile_redesign_scene.png"
const TILE_SCENE := preload("res://scenes/ui/MahjongTile.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(1600, 900)
	get_root().add_child(root)

	var bg := ColorRect.new()
	bg.color = Color8(18, 60, 41, 255)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var row := HBoxContainer.new()
	row.position = Vector2(120, 180)
	row.custom_minimum_size = Vector2(1360, 260)
	row.add_theme_constant_override("separation", 28)
	root.add_child(row)

	var samples := [
		{"id": 1, "suit": "tiao", "rank": 1},
		{"id": 2, "suit": "tiao", "rank": 5},
		{"id": 3, "suit": "tong", "rank": 1},
		{"id": 4, "suit": "tong", "rank": 9},
		{"id": 5, "suit": "wan", "rank": 1},
		{"id": 6, "suit": "wan", "rank": 9},
	]

	for index in range(samples.size()):
		var tile := TILE_SCENE.instantiate()
		var selected := index == 2
		tile.call("configure", samples[index], 1.35, false, false, selected)
		row.add_child(tile)

	var back_row := HBoxContainer.new()
	back_row.position = Vector2(120, 500)
	back_row.custom_minimum_size = Vector2(900, 220)
	back_row.add_theme_constant_override("separation", 28)
	root.add_child(back_row)

	for index in range(3):
		var back_tile := TILE_SCENE.instantiate()
		back_tile.call("configure", {}, 1.35, true, false, index == 1)
		back_row.add_child(back_tile)

	await process_frame
	await process_frame

	var image: Image = get_root().get_texture().get_image()
	var output := ProjectSettings.globalize_path(_capture_output_path())
	var err := image.save_png(output)
	if err != OK:
		push_error("Failed to save capture: %s" % output)
		quit(1)
		return

	print(output)
	quit()


func _capture_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			var value := argument.trim_prefix("--capture-output=")
			if value != "":
				return value
	return DEFAULT_OUTPUT_PATH
