extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://scenes/network/LanProbe.tscn")
	await process_frame
	await process_frame
	var probe := current_scene
	var buttons := probe.find_children("*", "Button", true, false)
	var back: Button = null
	for button in buttons:
		if button.text == "返回单机麻将": back = button
	if back == null:
		push_error("Missing return-to-game entry")
		quit(1)
		return
	back.pressed.emit()
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/table/MainSceneV2.tscn":
		push_error("Return-to-game failed")
		quit(1)
		return
	print("LAN_ENTRY_RETURN_PASS")
	quit(0)
