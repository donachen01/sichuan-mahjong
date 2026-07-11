extends SceneTree

const DEFAULT_OUTPUT_PATH := "user://capture_bao_gang_dialog.png"
const SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame

	root_node.call("_show_bao_gang_selection_dialog", [
		{"key": "tiao_1", "display_name": "1条", "tile": _tile(9401, "tiao", 1), "subtype": "ming"},
		{"key": "tiao_8", "display_name": "8条", "tile": _tile(9408, "tiao", 8), "subtype": "an"},
		{"key": "tong_9", "display_name": "9筒", "tile": _tile(9509, "tong", 9), "subtype": "ming"},
		{"key": "tong_5", "display_name": "5筒", "tile": _tile(9505, "tong", 5), "subtype": "ming"},
	])
	for _index in range(6):
		await process_frame

	var image: Image = get_root().get_texture().get_image()
	if image == null:
		push_error("Failed to capture viewport image")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(_capture_output_path())
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save capture: %s" % path)
		quit(1)
		return

	print(path)
	quit()


func _capture_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			var value := argument.trim_prefix("--capture-output=")
			if value != "":
				return value
	return DEFAULT_OUTPUT_PATH


func _tile(id: int, suit: String, rank: int) -> Dictionary:
	return {
		"id": id,
		"suit": suit,
		"rank": rank,
		"display_name": "%d%s" % [rank, "条" if suit == "tiao" else "筒"],
	}
