extends SceneTree

const SPLASH_SCENE := preload("res://scenes/boot/SplashScreen.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var root_node := SPLASH_SCENE.instantiate()
	get_root().add_child(root_node)
	await process_frame

	_run_test("splash_displays_project_version", _test_splash_displays_project_version.bind(root_node), failures)
	_run_test("splash_uses_sichuan_identity", _test_splash_uses_sichuan_identity.bind(root_node), failures)

	root_node.queue_free()
	if failures.is_empty():
		print("SPLASH SCREEN REGRESSION OK")
		quit(0)
		return

	push_error("SPLASH SCREEN REGRESSION FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _run_test(name: String, callable: Callable, failures: Array[String]) -> void:
	var result = callable.call()
	if typeof(result) == TYPE_BOOL and bool(result):
		print("PASS %s" % name)
		return
	failures.append("%s -> %s" % [name, str(result)])


func _test_splash_displays_project_version(root_node: Node):
	var version_label := root_node.get_node_or_null("%VersionLabel") as Label
	if version_label == null:
		return "expected splash to expose VersionLabel"
	var app_version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	var expected := "版本 v%s" % app_version
	if str(version_label.text) != expected:
		return "expected splash version text %s, got %s" % [expected, version_label.text]
	if not version_label.visible:
		return "expected splash version label to be visible"
	return true


func _test_splash_uses_sichuan_identity(root_node: Node):
	var splash_image := root_node.get_node_or_null("%SplashImage") as TextureRect
	var title_label := root_node.get_node_or_null("%TitleLabel") as Label
	var loading_label := root_node.get_node_or_null("%LoadingLabel") as Label
	if splash_image == null:
		return "expected splash to expose SplashImage"
	if splash_image.texture == null:
		return "expected SplashImage texture"
	var texture_path := str(splash_image.texture.resource_path)
	if not texture_path.ends_with("sichuan_mahjong_splash.png"):
		return "expected Sichuan splash texture, got %s" % texture_path
	if title_label == null or str(title_label.text).find("四川") == -1 or str(title_label.text).find("内江") != -1:
		return "expected Sichuan title text, got %s" % (title_label.text if title_label != null else "<missing>")
	if loading_label == null or str(loading_label.text).find("四川") == -1 or str(loading_label.text).find("内江") != -1:
		return "expected Sichuan loading text, got %s" % (loading_label.text if loading_label != null else "<missing>")
	return true
