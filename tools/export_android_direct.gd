@tool
extends SceneTree

const MONO_TEMPLATE_DIR := "/Users/chendong/Library/Application Support/Godot/export_templates/4.6.2.stable.mono/templates"
const STABLE_TEMPLATE_DIR := "/Users/chendong/Library/Application Support/Godot/export_templates/4.6.2.stable"


func _resolve_template_file(file_name: String) -> String:
	var mono_path := MONO_TEMPLATE_DIR.path_join(file_name)
	if FileAccess.file_exists(mono_path):
		return mono_path
	var stable_path := STABLE_TEMPLATE_DIR.path_join(file_name)
	if FileAccess.file_exists(stable_path):
		return stable_path
	return ""


func _initialize() -> void:
	await _wait_for_editor_filesystem()
	_prune_non_runtime_import_cache()
	_export_android()


func _wait_for_editor_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return
	var safety := 0
	while filesystem.is_scanning() and safety < 600:
		safety += 1
		await process_frame
	for index in range(10):
		await process_frame


func _prune_non_runtime_import_cache() -> void:
	var removed := 0
	for import_path in _collect_import_sidecars("res://docs"):
		removed += _remove_import_artifacts(import_path)
	print("pruned_non_runtime_import_cache=", removed)


func _collect_import_sidecars(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directories: Array[String] = [root_path]
	while not directories.is_empty():
		var current: String = str(directories.pop_back())
		var dir: DirAccess = DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var entry := dir.get_next()
			if entry == "":
				break
			if entry.begins_with("."):
				continue
			var path: String = current.path_join(entry)
			if dir.current_is_dir():
				directories.append(path)
			elif entry.ends_with(".import"):
				result.append(path)
		dir.list_dir_end()
	return result


func _remove_import_artifacts(import_path: String) -> int:
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return 0
	var removed := 0
	var dest_files: Array = config.get_value("deps", "dest_files", [])
	for dest in dest_files:
		var path := str(dest)
		if path.begins_with("res://.godot/imported/"):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				removed += 1
			var md5_path := path.get_basename() + ".md5"
			if FileAccess.file_exists(md5_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(md5_path))
				removed += 1
	if FileAccess.file_exists(import_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(import_path))
		removed += 1
	return removed


func _export_android() -> void:
	var export_mode := OS.get_environment("GODOT_ANDROID_EXPORT_MODE").to_lower()
	if export_mode == "":
		export_mode = "debug"
	var is_debug := export_mode != "release"
	var app_version := _app_version_name()
	var platform: Object = ClassDB.instantiate("EditorExportPlatformAndroid")
	if not platform:
		push_error("无法实例化 EditorExportPlatformAndroid")
		quit(1)
		return

	var preset: Object = platform.call("create_preset")
	preset.set("custom_features", "C#")
	preset.set("export_filter", "all_resources")
	preset.set("include_filter", "")
	preset.set("exclude_filter", "docs/**,tests/**,tools/**,build/**,evidence/**,backups/**,测试数据统计/**,.tmp_tts/**,.venv_tts/**,.git/**,.godot/**")
	preset.set("script_export_mode", 2)
	preset.set("gradle_build/use_gradle_build", true)
	var gradle_build_dir := OS.get_environment("GODOT_ANDROID_GRADLE_BUILD_DIR")
	if gradle_build_dir == "":
		gradle_build_dir = "/tmp/sichuan_mahjong_android_gradle_build"
	preset.set("gradle_build/gradle_build_directory", gradle_build_dir)
	preset.set("gradle_build/android_source_template", _resolve_template_file("android_source.zip"))
	preset.set("gradle_build/compress_native_libraries", false)
	preset.set("gradle_build/export_format", 0)
	preset.set("architectures/armeabi-v7a", false)
	preset.set("architectures/arm64-v8a", true)
	preset.set("architectures/x86", false)
	preset.set("architectures/x86_64", false)
	preset.set("custom_template/debug", _resolve_template_file("android_debug.apk"))
	preset.set("custom_template/release", _resolve_template_file("android_release.apk"))
	preset.set("version/code", _app_version_code(app_version))
	preset.set("version/name", app_version)
	preset.set("package/unique_name", "com.chendong.sichuanmahjong")
	preset.set("package/name", "四川麻将新版")
	preset.set("package/signed", true)
	preset.set("package/app_category", 2)
	preset.set("package/show_in_android_tv", false)
	preset.set("launcher_icons/main_192x192", "res://res/art/app_icon/app_icon_192.png")
	preset.set("launcher_icons/adaptive_foreground_432x432", "res://res/art/app_icon/app_icon_foreground_432.png")
	preset.set("launcher_icons/adaptive_background_432x432", "res://res/art/app_icon/app_icon_background_432.png")
	preset.set("launcher_icons/adaptive_monochrome_432x432", "res://res/art/app_icon/app_icon_monochrome_432.png")
	preset.set("screen/immersive_mode", true)
	preset.set("screen/edge_to_edge", false)
	preset.set("screen/support_small", true)
	preset.set("screen/support_normal", true)
	preset.set("screen/support_large", true)
	preset.set("screen/support_xlarge", true)
	preset.set("screen/background_color", Color.BLACK)
	preset.set("user_data_backup/allow", false)
	preset.set("shader_baker/enabled", false)
	preset.set("xr_features/xr_mode", 0)
	preset.set("permissions/internet", false)
	preset.set("permissions/read_external_storage", is_debug)
	preset.set("permissions/write_external_storage", is_debug)
	preset.set("permissions/manage_external_storage", is_debug)
	preset.set("dotnet/include_scripts_content", true)
	preset.set("dotnet/include_debug_symbols", true)
	preset.set("dotnet/embed_build_outputs", true)
	preset.set("dotnet/android_use_linux_bionic", false)

	if is_debug:
		preset.set("keystore/release", "/Users/chendong/Library/Application Support/Godot/keystores/debug.keystore")
		preset.set("keystore/release_user", "androiddebugkey")
		preset.set("keystore/release_password", "android")
	else:
		preset.set("keystore/release", OS.get_environment("GODOT_ANDROID_RELEASE_KEYSTORE"))
		preset.set("keystore/release_user", OS.get_environment("GODOT_ANDROID_RELEASE_ALIAS"))
		preset.set("keystore/release_password", OS.get_environment("GODOT_ANDROID_RELEASE_PASSWORD"))

	var output_path := OS.get_environment("GODOT_ANDROID_OUTPUT")
	if output_path == "":
		output_path = "/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-direct-debug.apk" if is_debug else "/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-release.apk"

	var output_dir := output_path.get_base_dir()
	if output_dir != "":
		var make_dir_result := DirAccess.make_dir_recursive_absolute(output_dir)
		if make_dir_result != OK:
			push_error("无法创建 Android 导出目录：%s" % output_dir)
			quit(make_dir_result)
			return

	var result: int = platform.call("export_project", preset, is_debug, output_path, 0)
	print("export_result=", result)
	print("message_count=", platform.call("get_message_count"))
	for index in range(platform.call("get_message_count")):
		print("message[%d].type=%s" % [index, str(platform.call("get_message_type", index))])
		print("message[%d].text=%s" % [index, str(platform.call("get_message_text", index))])
	if result != OK:
		if FileAccess.file_exists(output_path):
			DirAccess.remove_absolute(output_path)
		quit(result)
		return
	if FileAccess.file_exists(output_path):
		print("output_exists=true")
		print("output_size=", FileAccess.get_file_as_bytes(output_path).size())
		quit(0)
		return
	quit(result)


func _app_version_name() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	return "1.0.0" if version.strip_edges() == "" else version.strip_edges()


func _app_version_code(version_name: String) -> int:
	var parts := version_name.split(".")
	if parts.size() >= 3:
		return maxi(1, int(parts[2]))
	return 1
