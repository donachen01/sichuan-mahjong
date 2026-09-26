extends SceneTree

const OUTPUT_PATH := "user://capture_game_mode_select.png"
const SCENE_PATH := "res://scenes/network/GameModeSelect.tscn"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load mode selection scene")
		quit(1)
		return
	var root_node := scene.instantiate()
	get_root().add_child(root_node)
	for _frame in range(8):
		await process_frame
	if OS.has_environment("CAPTURE_ONLINE_PANEL"):
		root_node.call("_show_online")
		for _frame in range(8):
			await process_frame
	var image := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var result := image.save_png(path)
	if result != OK:
		push_error("Failed to save capture: %s" % path)
		quit(result)
		return
	print(path)
	quit(0)
