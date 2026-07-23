extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const SETTING := "ui/mahjong_3d_enabled"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous: Variant = ProjectSettings.get_setting(SETTING, true)
	ProjectSettings.set_setting(SETTING, false)
	var root_node := MAIN_SCENE.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame
	await process_frame
	var failures: Array[String] = []
	if bool(root_node.get("table_3d_enabled")):
		failures.append("project setting did not disable the 3D presentation")
	if root_node.get("table_stage_3d") != null:
		failures.append("fallback mode must not allocate the 3D table stage")
	var background := root_node.get("background_rect") as Control
	if background == null or not background.visible:
		failures.append("2D fallback background must remain visible")
	var hand := root_node.get("self_hand_host") as Control
	if hand == null or not hand.visible:
		failures.append("2D fallback self hand must remain visible")
	root_node.queue_free()
	await process_frame
	ProjectSettings.set_setting(SETTING, previous)
	if failures.is_empty():
		print("SICHUAN 3D FALLBACK CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN 3D FALLBACK CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)
