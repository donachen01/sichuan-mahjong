extends SceneTree

const SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load scene")
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

	for path in [
		"UILayer/RootUI/DingQueOverlay/DingQueCenter/DingQuePanel/DingQueMargin/DingQueVBox/DingQueButtonCard/DingQueButtonCardMargin/DingQueButtons/DingQueTiaoButton",
		"UILayer/RootUI/DingQueOverlay/DingQueCenter/DingQuePanel/DingQueMargin/DingQueVBox/DingQueButtonCard/DingQueButtonCardMargin/DingQueButtons/DingQueTongButton",
		"UILayer/RootUI/DingQueOverlay/DingQueCenter/DingQuePanel/DingQueMargin/DingQueVBox/DingQueButtonCard/DingQueButtonCardMargin/DingQueButtons/DingQueWanButton",
	]:
		var button := root_node.get_node_or_null(path)
		if button == null:
			print(path, " => missing")
			continue
		var normal = button.get_theme_stylebox("normal")
		var hover = button.get_theme_stylebox("hover")
		if normal is StyleBoxFlat and hover is StyleBoxFlat:
			var normal_flat := normal as StyleBoxFlat
			var hover_flat := hover as StyleBoxFlat
			print(path)
			print("  normal bg=", normal_flat.bg_color, " border=", normal_flat.border_color, " border_width=", normal_flat.border_width_left, " shadow=", normal_flat.shadow_color, " shadow_size=", normal_flat.shadow_size)
			print("  hover  bg=", hover_flat.bg_color, " border=", hover_flat.border_color, " border_width=", hover_flat.border_width_left, " shadow=", hover_flat.shadow_color, " shadow_size=", hover_flat.shadow_size)

	quit()
