extends SceneTree

const EXPECTED_VERSION := "2.6.34"
const EXPECTED_ANDROID_CODE := 294

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var version_text := FileAccess.get_file_as_string("res://VERSION").strip_edges()
	_check(version_text == EXPECTED_VERSION, "VERSION matches the release")

	var project := ConfigFile.new()
	_check(project.load("res://project.godot") == OK, "project.godot loads")
	_check(str(project.get_value("application", "config/version", "")) == EXPECTED_VERSION, "Godot app version matches")

	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	for section in ["preset.0.options", "preset.2.options"]:
		_check(str(presets.get_value(section, "application/short_version", "")) == EXPECTED_VERSION, "%s short version matches" % section)
		_check(str(presets.get_value(section, "application/version", "")) == EXPECTED_VERSION, "%s build version matches" % section)
	_check(str(presets.get_value("preset.1.options", "version/name", "")) == EXPECTED_VERSION, "Android version name matches")
	_check(int(presets.get_value("preset.1.options", "version/code", 0)) == EXPECTED_ANDROID_CODE, "Android version code matches")

	var version_doc := FileAccess.get_file_as_string("res://VERSION.md")
	var readme := FileAccess.get_file_as_string("res://README.md")
	var changelog := FileAccess.get_file_as_string("res://CHANGELOG.md")
	_check("当前应用版本：`%s`" % EXPECTED_VERSION in version_doc, "VERSION.md current version matches")
	_check("version/name=%s" % EXPECTED_VERSION in version_doc, "VERSION.md Android version matches")
	_check("构建版本 `%s`" % EXPECTED_VERSION in version_doc, "VERSION.md iOS version matches")
	_check("- 版本：`%s`" % EXPECTED_VERSION in readme, "README current version matches")
	_check(changelog.begins_with("# Changelog\n\n## %s" % EXPECTED_VERSION), "CHANGELOG latest entry matches")

	if failures.is_empty():
		print("SICHUAN_VERSION_CONSISTENCY_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
