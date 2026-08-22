extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var utility := scene.get("table_utility_bar") as Control
	var panel := scene.get("table_skin_panel") as Control
	var failures: Array[String] = []
	if utility == null or panel == null:
		failures.append("missing utility or panel")
	else:
		utility.call("set_collapsed", false)
		utility.call("_layout_buttons")
		var button := utility.call("get_button", "skin") as Button
		if button == null or not button.visible:
			failures.append("skin button not visible")
		else:
			var center := button.get_global_rect().get_center()
			var mouse_motion := InputEventMouseMotion.new()
			mouse_motion.position = center
			mouse_motion.global_position = center
			get_root().push_input(mouse_motion, true)
			await process_frame
			var mouse_press := InputEventMouseButton.new()
			mouse_press.button_index = MOUSE_BUTTON_LEFT
			mouse_press.position = center
			mouse_press.global_position = center
			mouse_press.pressed = true
			get_root().push_input(mouse_press, true)
			await process_frame
			var mouse_release := InputEventMouseButton.new()
			mouse_release.button_index = MOUSE_BUTTON_LEFT
			mouse_release.position = center
			mouse_release.global_position = center
			mouse_release.pressed = false
			get_root().push_input(mouse_release, true)
			await process_frame
			if not panel.visible:
				failures.append("mouse click on skin entry collapsed the toolbar without leaving chooser visible")
			if bool(utility.call("is_collapsed")):
				failures.append("mouse click on skin entry unexpectedly collapsed the utility tray")
			panel.close()
			utility.call("set_collapsed", false)
			utility.call("_layout_buttons")
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = center
			touch.pressed = true
			get_root().push_input(touch, true)
			await process_frame
			if not panel.visible:
				failures.append("screen touch did not open panel")
			else:
				var alternate := panel.get("skin_buttons").get("emerald_linen") as Button
				if alternate == null:
					failures.append("alternate skin button missing")
				else:
					var alternate_touch := InputEventScreenTouch.new()
					alternate_touch.index = 0
					alternate_touch.position = alternate.get_global_rect().get_center()
					alternate_touch.pressed = true
					get_root().push_input(alternate_touch, true)
					var alternate_release := InputEventScreenTouch.new()
					alternate_release.index = 0
					alternate_release.position = alternate_touch.position
					alternate_release.pressed = false
					get_root().push_input(alternate_release, true)
					await process_frame
					if str(scene.get("table_skin_id")) != "emerald_linen":
						failures.append("screen touch did not select alternate skin")
			panel.close()
			await process_frame
	if failures.is_empty():
		print("SICHUAN TABLE SKIN TOUCH PASS")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	scene.queue_free()
	await process_frame
	quit(0)
