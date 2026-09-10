@tool
extends SceneTree

const DEFAULT_IOS_TEMPLATE := "/Users/chendong/Library/Application Support/Godot/export_templates/4.6.2.stable.mono/templates/ios.zip"


func _initialize() -> void:
	await _wait_for_editor_filesystem()
	_prune_non_runtime_import_cache()
	_export_ios_xcode_project()


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
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var entry := dir.get_next()
			if entry == "":
				break
			if entry.begins_with("."):
				continue
			var path := current.path_join(entry)
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
	for dest in config.get_value("deps", "dest_files", []):
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


func _export_ios_xcode_project() -> void:
	if not ClassDB.class_exists("EditorExportPlatformIOS"):
		push_error("当前 Godot 版本不包含 EditorExportPlatformIOS，无法导出 iOS。")
		quit(1)
		return

	var platform: Object = ClassDB.instantiate("EditorExportPlatformIOS")
	if not platform:
		push_error("无法实例化 EditorExportPlatformIOS。")
		quit(1)
		return

	var preset: Object = platform.call("create_preset")
	var app_version := _app_version_name()
	var team_id := _env_or_default("GODOT_IOS_TEAM_ID", "FCB4ZVWWD8")
	var bundle_id := _env_or_default("GODOT_IOS_BUNDLE_ID", "com.chendong.sichuanmahjong.iosdev")
	var template_path := _env_or_default("GODOT_IOS_TEMPLATE", DEFAULT_IOS_TEMPLATE)
	var output_path := _env_or_default(
		"GODOT_IOS_OUTPUT",
		"/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/SichuanMahjongIOS/SichuanMahjongIOS"
	)

	if not FileAccess.file_exists(template_path):
		push_error("iOS 导出模板不存在：%s" % template_path)
		quit(1)
		return

	var output_dir := output_path.get_base_dir()
	if output_dir != "":
		var make_dir_result := DirAccess.make_dir_recursive_absolute(output_dir)
		if make_dir_result != OK:
			push_error("无法创建 iOS 导出目录：%s" % output_dir)
			quit(make_dir_result)
			return

	preset.set("custom_features", "")
	preset.set("export_filter", "all_resources")
	preset.set("include_filter", "")
	preset.set("exclude_filter", "docs/*,tests/*,tools/*,build/*,evidence/*,research/*,dotnet/*,backups/*,source_assets/*,planning/*,测试数据统计/*,设计文档/*,.tmp_tts/*,.venv_tts/*,.git/*,.godot/*")
	preset.set("script_export_mode", 2)
	preset.set("custom_template/debug", template_path)
	preset.set("custom_template/release", template_path)
	preset.set("application/app_store_team_id", team_id)
	preset.set("application/bundle_identifier", bundle_id)
	preset.set("application/export_project_only", true)
	preset.set("application/delete_old_export_files_unconditionally", true)
	preset.set("application/min_ios_version", "14.0")
	preset.set("application/short_version", app_version)
	preset.set("application/version", app_version)
	preset.set("application/targeted_device_family", 2)
	preset.set("architectures/arm64", true)
	preset.set("icons/icon_1024x1024", "res://res/art/app_icon/app_icon_1024.png")
	preset.set("icons/app_store_1024x1024", "res://res/art/app_icon/app_icon_1024.png")
	preset.set("shader_baker/enabled", false)
	preset.set("dotnet/include_scripts_content", false)
	preset.set("dotnet/include_debug_symbols", true)
	preset.set("dotnet/embed_build_outputs", false)

	var debug_export := _env_or_default("GODOT_IOS_DEBUG_EXPORT", "false").to_lower() in ["1", "true", "yes", "on"]
	var result: int = platform.call("export_project", preset, debug_export, output_path, 0)
	print("ios_export_result=", result)
	print("ios_output_path=", output_path)
	print("ios_team_id=", team_id)
	print("ios_bundle_id=", bundle_id)
	print("ios_debug_export=", debug_export)
	print("message_count=", platform.call("get_message_count"))
	var has_blocking_error_message := false
	for index in range(platform.call("get_message_count")):
		var message_type: int = int(platform.call("get_message_type", index))
		var message_text := str(platform.call("get_message_text", index))
		if message_type >= 3:
			if result == OK and message_text.find("Failed to build project. Check MSBuild panel for details.") != -1:
				push_warning("iOS 工程已生成，忽略 Godot 项目导出后的非阻塞构建提示：%s" % message_text)
			else:
				has_blocking_error_message = true
		print("message[%d].type=%s" % [index, str(message_type)])
		print("message[%d].text=%s" % [index, message_text])

	if result != OK or has_blocking_error_message:
		quit(FAILED if result == OK else result)
		return
	quit(0)


func _env_or_default(name: String, default_value: String) -> String:
	var value := OS.get_environment(name).strip_edges()
	return default_value if value == "" else value


func _app_version_name() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	return "1.0.0" if version == "" else version
