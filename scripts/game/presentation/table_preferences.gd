extends RefCounted

const VoiceCatalog := preload("res://scripts/ui/table/SichuanVoiceCatalog.gd")
const SkinCatalog := preload("res://scripts/ui/table/SichuanTableSkinCatalog.gd")
const PATH := "user://ui_prefs.cfg"
const SECTION := "main_scene_v2"
const DRAWER_LAYOUT_VERSION := 3
const STORED_KEYS := {
	"ai_helper_enabled": "ai_helper_enabled",
	"opponent_hands_enabled": "opponent_hands_enabled",
	"voice_language": "voice_language",
	"my_voice_id": "my_voice_id",
	"table_skin_id": "sichuan_table_skin_id",
	"ai_glass_opacity": "ai_glass_opacity",
	"ai_drawer_position_normalized": "ai_drawer_position_normalized",
	"ai_drawer_positioned": "ai_drawer_positioned",
}


static func read_preferences(path: String = PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	var values := {
		"ai_helper_enabled": bool(config.get_value(SECTION, "ai_helper_enabled", false)),
		"opponent_hands_enabled": bool(config.get_value(SECTION, "opponent_hands_enabled", false)),
	}
	var language := str(config.get_value(SECTION, "voice_language", "mandarin"))
	values.voice_language = language if language in ["mandarin", "sichuan"] else "mandarin"
	var voice_id := str(config.get_value(SECTION, "my_voice_id", ""))
	values.my_voice_id = ""
	for option in VoiceCatalog.all_options():
		if str(option.get("id", "")) == voice_id:
			values.my_voice_id = voice_id
			break
	var skin_id := str(config.get_value(SECTION, "sichuan_table_skin_id", SkinCatalog.DEFAULT_SKIN_ID))
	values.table_skin_id = skin_id if SkinCatalog.has_skin(skin_id) else SkinCatalog.DEFAULT_SKIN_ID
	if config.has_section_key(SECTION, "ai_glass_opacity"):
		values.ai_glass_opacity = clampf(float(config.get_value(SECTION, "ai_glass_opacity", 0.70)), 0.0, 1.0)
	else:
		var legacy_index := clampi(int(config.get_value(SECTION, "ai_glass_opacity_index", 1)), 0, 2)
		values.ai_glass_opacity = [0.48, 0.70, 0.90][legacy_index]
	var position: Variant = config.get_value(SECTION, "ai_drawer_position_normalized", Vector2(0.5, 0.72))
	if position is Vector2:
		values.ai_drawer_position_normalized = Vector2(clampf(position.x, 0.0, 1.0), clampf(position.y, 0.0, 1.0))
	values.ai_drawer_positioned = bool(config.get_value(SECTION, "ai_drawer_positioned", false)) \
		and int(config.get_value(SECTION, "ai_drawer_layout_version", 0)) >= DRAWER_LAYOUT_VERSION
	return values


static func save_preferences(values: Dictionary, path: String = PATH) -> Error:
	var config := ConfigFile.new()
	for property in STORED_KEYS:
		if values.has(property):
			config.set_value(SECTION, STORED_KEYS[property], values[property])
	config.set_value(SECTION, "ai_drawer_layout_version", DRAWER_LAYOUT_VERSION)
	return config.save(path)
