@tool
extends SceneTree

func _initialize() -> void:
	await process_frame
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning():
		await process_frame
	var output := OS.get_environment("LAN_PROBE_IOS_OUTPUT")
	if output.is_empty():
		push_error("LAN_PROBE_IOS_OUTPUT is required")
		quit(1)
		return
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var platform := EditorExportPlatformIOS.new()
	var preset := platform.create_preset()
	preset.set("export_filter", "all_resources")
	preset.set("exclude_filter", "tests/*,tools/*")
	for key in config.get_section_keys("preset.0.options"):
		preset.set(key, config.get_value("preset.0.options", key))
	var result := platform.export_project(preset, true, output)
	for index in range(platform.get_message_count()):
		print(platform.get_message_text(index))
	print("LAN_IOS_EXPORT_RESULT=", result)
	quit(0 if result == OK else 1)
