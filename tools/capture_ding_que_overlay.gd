extends SceneTree

const OUTPUT_PATH := "user://capture_ding_que_overlay.png"
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

	var game_manager := root_node.get_node_or_null("GameManager")
	if game_manager == null:
		push_error("GameManager not found")
		quit(1)
		return

	var game_state = game_manager.get("game_state")
	if game_state == null:
		push_error("game_state not found")
		quit(1)
		return

	if bool(game_state.get("opening_roll_pending_completion")):
		game_state.call("complete_opening_roll")

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_root().get_texture().get_image()
	if image == null:
		push_error("Failed to capture viewport image")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save capture: %s" % path)
		quit(1)
		return

	print(path)
	quit()
