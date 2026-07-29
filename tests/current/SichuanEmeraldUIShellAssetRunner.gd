extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const ACTION_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")
const UI_ROOT := "res://res/art/ui/table_v2/"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_sources_and_images()
	var hud := HUD_SCENE.instantiate() as Control
	hud.size = Vector2(230.0, 156.0)
	get_root().add_child(hud)
	var action_bar := ACTION_SCENE.instantiate() as Control
	get_root().add_child(action_bar)
	await process_frame
	await process_frame

	var shell := hud.get_node_or_null("MaterialShell") as TextureRect
	_check(shell != null, "SeatHUD uses the Blender orthographic material shell")
	if shell != null:
		_check(shell.texture != null, "SeatHUD shell texture is loaded")
		_check(shell.stretch_mode == TextureRect.STRETCH_SCALE, "HUD shell scales as one preserved silhouette")
		_check(shell.get_rect().size == hud.get_rect().size, "HUD shell covers the unchanged HUD rect")
	var craft := hud.get_node_or_null("CraftPanel") as Control
	_check(craft != null and not craft.visible, "legacy opaque craft panel does not cover Blender shell")

	for action in ["hu", "gang", "peng", "pass"]:
		var button := action_bar.call("get_button", action) as Button
		_check(button != null, "%s action button exists" % action)
		if button == null:
			continue
		var style := button.get_theme_stylebox("normal") as StyleBoxTexture
		_check(style != null, "%s action uses Blender seal StyleBoxTexture" % action)
		if style != null and style.texture != null:
			_check(style.texture.resource_path == UI_ROOT + "action_%s.png" % action, "%s action uses its named seal texture" % action)

	hud.queue_free()
	action_bar.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN_EMERALD_UI_SHELL_ASSET_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_sources_and_images() -> void:
	_check(FileAccess.file_exists("res://tools/3d/generate_sichuan_ui_shells_v2.py"), "Blender UI shell generator is versioned")
	_check(FileAccess.file_exists("res://tools/3d/generate_sichuan_center_compass_v2.py"), "Blender center compass generator is versioned")
	_check(ResourceLoader.exists("res://res/art/3d/sichuan_center_compass_v2.glb"), "Blender center compass GLB is loadable")
	_check(FileAccess.file_exists(UI_ROOT + "README.md"), "UI shell provenance/readme is versioned")
	var specs := {
		"hud_shell.png": Vector2i(768, 480),
		"action_hu.png": Vector2i(384, 384),
		"action_gang.png": Vector2i(384, 384),
		"action_peng.png": Vector2i(384, 384),
		"action_pass.png": Vector2i(384, 384),
		"ding_que_tiao.png": Vector2i(384, 384),
		"ding_que_tong.png": Vector2i(384, 384),
		"ding_que_wan.png": Vector2i(384, 384),
	}
	for file_name in specs:
		var texture := load(UI_ROOT + str(file_name)) as Texture2D
		_check(texture != null, "%s loads as Texture2D" % file_name)
		if texture != null:
			var expected: Vector2i = specs[file_name]
			_check(texture.get_width() == expected.x and texture.get_height() == expected.y, "%s keeps authored resolution" % file_name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
