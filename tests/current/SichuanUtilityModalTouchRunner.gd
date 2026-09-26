extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var utility := scene.get("table_utility_bar") as TableUtilityBar
	var voice := scene.get("voice_select_panel") as SichuanVoiceSelectPanel
	var skin := scene.get("table_skin_panel") as SichuanTableSkinPanel
	var failures: Array[String] = []
	if utility == null or voice == null or skin == null:
		failures.append("missing utility, voice, or skin controls")
	else:
		utility.set_collapsed(false)
		await process_frame
		scene.set("voice_language", "sichuan")
		var snapshot: Dictionary = (scene.get("game_manager") as Node).call("get_snapshot")
		scene.call("_update_top_bar", snapshot)
		var skin_normal_style := utility.get_button("skin").get_theme_stylebox("normal")
		scene.call("_refresh_settlement", snapshot)
		if utility.voice_language != "sichuan":
			failures.append("settlement refresh reset the utility language")
		if utility.get_button("skin").get_theme_stylebox("normal") != skin_normal_style:
			failures.append("unchanged snapshot rebuilt utility styles")
		_push_touch(utility.get_button("choose_voice").get_global_rect().get_center())
		if not voice.visible:
			failures.append("voice chooser did not open on the first native touch")
		if voice.visible and voice.z_index <= utility.z_index:
			failures.append("voice chooser is below the utility drawer")
		await process_frame
		if voice.visible:
			var filter := voice.filter_buttons.get("sichuan") as Button
			if filter != null:
				_push_touch(filter.get_global_rect().get_center())
				if voice.active_filter != "sichuan":
					failures.append("voice language filter did not react on the first native touch")
			voice.close()
		_push_touch(utility.get_button("skin").get_global_rect().get_center())
		if not skin.visible:
			failures.append("skin chooser did not open on the first native touch")
		if skin.visible and skin.z_index <= utility.z_index:
			failures.append("skin chooser is below the utility drawer")
		if skin.get_visual_contract().get("authored_size", Vector2.ZERO).x < 1200.0:
			failures.append("skin chooser did not receive the larger glass layout")
		skin.close()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN UTILITY MODAL TOUCH PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _push_touch(position: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = position
	touch.pressed = true
	root.push_input(touch, true)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = position
	release.pressed = false
	root.push_input(release, true)
