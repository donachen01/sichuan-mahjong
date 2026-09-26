class_name SichuanVoiceCatalog
extends RefCounted

const MANIFEST_PATH := "res://res/audio/voice_manifest.json"
const LANGUAGES := ["mandarin", "sichuan"]
const GENDERS := ["male", "female"]

static var _options: Array[Dictionary] = []


static func all_options() -> Array[Dictionary]:
	if _options.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			for entry in (parsed as Dictionary).get("voice_options", []):
				if entry is Dictionary:
					_options.append(entry)
	return _options


static func options_for(language: String, gender: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in all_options():
		if str(option.get("language", "")) == language and str(option.get("gender", "")) == gender:
			result.append(option)
	return result


static func default_id(language: String, gender: String) -> String:
	var matches := options_for(language, gender)
	return str(matches[0].get("id", "")) if not matches.is_empty() else ""


static func resolve(language: String, gender: String, requested_id: String) -> Dictionary:
	var matches := options_for(language, gender)
	for option in matches:
		if str(option.get("id", "")) == requested_id:
			return option
	return matches[0] if not matches.is_empty() else {}


static func normalize_selection(stored: Dictionary) -> Dictionary:
	var result := {}
	for language in LANGUAGES:
		for gender in GENDERS:
			var key := "%s_%s" % [language, gender]
			var option := resolve(language, gender, str(stored.get(key, "")))
			result[key] = str(option.get("id", ""))
	return result
