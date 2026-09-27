extends RefCounted

# Bounded diagnostic serialization and filesystem access, separate from rules.
const DIAGNOSTIC_DOWNLOAD_SUBDIR := "SichuanMahjongLogs"
const DIAGNOSTIC_MAX_DEPTH := 5
const DIAGNOSTIC_MAX_ARRAY_ITEMS := 80
const DIAGNOSTIC_MAX_DICT_KEYS := 120
const DIAGNOSTIC_MAX_STRING_LENGTH := 4000
const DIAGNOSTIC_MAX_TEXT_FILE_CHARS := 120000


static func _copy_diagnostic_package_to_downloads(internal_path: String, file_name: String) -> Dictionary:
	var downloads_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS, true)
	if downloads_dir.is_empty():
		return {"ok": false, "error": "downloads_dir_unavailable"}
	var export_dir := downloads_dir.path_join(DIAGNOSTIC_DOWNLOAD_SUBDIR)
	var dir_err := DirAccess.make_dir_recursive_absolute(export_dir)
	if dir_err != OK:
		return {
			"ok": false,
			"error": "downloads_dir_create_failed",
			"error_code": dir_err,
			"path": export_dir,
		}
	var text := FileAccess.get_file_as_string(internal_path)
	if text.is_empty():
		return {"ok": false, "error": "internal_package_empty", "path": internal_path}
	var external_path := export_dir.path_join(file_name)
	var file := FileAccess.open(external_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "downloads_write_failed",
			"error_code": FileAccess.get_open_error(),
			"path": external_path,
		}
	file.store_string(text)
	file.close()
	return {
		"ok": true,
		"path": external_path,
		"downloads_dir": export_dir,
	}


static func _collect_diagnostic_text_files(paths: Array) -> Dictionary:
	var result := {}
	for item in paths:
		var path := str(item)
		result[path] = _read_diagnostic_text_file(path)
	return result


static func _collect_diagnostic_dir_text_files(root_path: String, max_files: int) -> Dictionary:
	var result := {
		"root": root_path,
		"root_absolute": ProjectSettings.globalize_path(root_path),
		"files": {},
		"truncated": false,
	}
	var paths: Array[String] = []
	_collect_diagnostic_dir_paths(root_path, paths, max_files)
	if paths.size() > max_files:
		result["truncated"] = true
		paths = paths.slice(0, max_files)
	for path in paths:
		result["files"][path] = _read_diagnostic_text_file(path)
	return result


static func _collect_diagnostic_dir_paths(path: String, paths: Array[String], max_files: int) -> void:
	if paths.size() > max_files:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path := path.path_join(entry)
		if dir.current_is_dir():
			_collect_diagnostic_dir_paths(child_path, paths, max_files)
		elif entry.ends_with(".json") or entry.ends_with(".jsonl") or entry.ends_with(".csv") or entry.ends_with(".md") or entry.ends_with(".log"):
			paths.append(child_path)
			if paths.size() > max_files:
				break
	dir.list_dir_end()


static func _read_diagnostic_text_file(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {
			"exists": false,
			"path": path,
			"path_absolute": ProjectSettings.globalize_path(path),
		}
	var text := FileAccess.get_file_as_string(path)
	var truncated := text.length() > DIAGNOSTIC_MAX_TEXT_FILE_CHARS
	if truncated:
		text = text.right(DIAGNOSTIC_MAX_TEXT_FILE_CHARS)
	return {
		"exists": true,
		"path": path,
		"path_absolute": ProjectSettings.globalize_path(path),
		"char_count": text.length(),
		"truncated_from_start": truncated,
		"content": text,
	}


static func _compact_diagnostic_value(value, depth: int = 0):
	if depth >= DIAGNOSTIC_MAX_DEPTH:
		return _compact_diagnostic_leaf(value)
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var output := {}
			var count := 0
			for key in source.keys():
				if count >= DIAGNOSTIC_MAX_DICT_KEYS:
					output["_truncated_keys"] = maxi(0, source.size() - count)
					break
				output[str(key)] = _compact_diagnostic_value(source[key], depth + 1)
				count += 1
			return output
		TYPE_ARRAY:
			var source_array: Array = value
			var output_array := []
			var limit := mini(source_array.size(), DIAGNOSTIC_MAX_ARRAY_ITEMS)
			for index in range(limit):
				output_array.append(_compact_diagnostic_value(source_array[index], depth + 1))
			if source_array.size() > limit:
				output_array.append({"_truncated_items": source_array.size() - limit})
			return output_array
		TYPE_STRING:
			var text := str(value)
			if text.length() > DIAGNOSTIC_MAX_STRING_LENGTH:
				return text.left(DIAGNOSTIC_MAX_STRING_LENGTH) + "...<truncated>"
			return text
		_:
			return value


static func _compact_diagnostic_leaf(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			return {"_truncated_dictionary_keys": dictionary.size()}
		TYPE_ARRAY:
			var array: Array = value
			return {"_truncated_array_items": array.size()}
		TYPE_STRING:
			var text := str(value)
			if text.length() > DIAGNOSTIC_MAX_STRING_LENGTH:
				return text.left(DIAGNOSTIC_MAX_STRING_LENGTH) + "...<truncated>"
			return text
		_:
			return value
