extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/network/GameModeSelect.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.get_node_or_null("GameManager") == null)
	assert(scene.scene_file_path == "res://scenes/network/GameModeSelect.tscn")
	var quit_button := scene.get_node_or_null("%QuitGameButton") as Button
	if quit_button == null:
		quit_button = scene.find_child("QuitGameButton", true, false) as Button
	assert(quit_button != null and quit_button.text == "退出游戏")
	assert(quit_button.custom_minimum_size.x >= 300.0 and quit_button.custom_minimum_size.y >= 76.0)
	assert(scene.has_method("get_quit_behavior_contract"))
	var quit_contract: Dictionary = scene.call("get_quit_behavior_contract")
	assert(str(quit_contract.get("desktop", "")) == "quit_process")
	assert(str(quit_contract.get("android", "")) == "quit_process")
	assert(str(quit_contract.get("ios", "")) == "show_system_exit_instructions")
	assert(scene.mode_panel.visible and not scene.online_panel.visible)
	assert(scene.theme != null and scene.theme.default_font != null)
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = scene.online_button.get_global_rect().get_center(); scene._input(touch)
	assert(scene.online_panel.visible and not scene.mode_panel.visible)
	assert(scene.online_panel.custom_minimum_size.x >= 1600)
	var runtime: Node = root.get_node("LanRuntime")
	runtime.stop_browsing()
	assert(runtime.host_room("大字测试") == OK)
	await process_frame
	assert(scene.current_room_panel.visible)
	assert(not runtime.match_active)
	assert(scene._navigating)
	assert(not scene.start_button.visible)
	runtime.leave_room()
	scene.queue_free()
	print("GAME_MODE_SELECT_PASS")
	quit(0)
