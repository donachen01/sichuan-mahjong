extends SceneTree

const MAIN_SCRIPT := preload("res://scripts/game/MainSceneV2.gd")
const VOICE_CATALOG := preload("res://scripts/ui/table/SichuanVoiceCatalog.gd")
const VOICE_PANEL_SCRIPT := preload("res://scripts/ui/table/SichuanVoiceSelectPanel.gd")
const UTILITY_BAR_SCENE := preload("res://scenes/ui/table/TableUtilityBar.tscn")
const MANIFEST_PATH := "res://res/audio/voice_manifest.json"
const TILE_SUFFIXES := {"tong": "筒", "tiao": "条", "wan": "万"}
const NUMBER_TEXT := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
const ACTION_KEYS := [
	"peng", "gang", "hu", "zimo", "qiang_gang_hu", "gang_shang_hua", "gang_shang_pao",
	"pass", "win", "lose", "bao_jiao", "bao_gang", "ding_que_wan", "ding_que_tiao", "ding_que_tong",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check_tile_contract(manifest)
	_check_profile_resources(manifest)
	_check_runtime_mapping()
	_check_self_voice_choice()
	await process_frame
	_finish()


func _load_manifest() -> Dictionary:
	_check(FileAccess.file_exists(MANIFEST_PATH), "voice manifest exists")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(parsed is Dictionary, "voice manifest parses")
	return parsed if parsed is Dictionary else {}


func _check_tile_contract(manifest: Dictionary) -> void:
	var tile_texts: Dictionary = manifest.get("tile_texts", {})
	_check(tile_texts.size() == 27, "manifest has exactly 27 numbered tile utterances")
	for suit in TILE_SUFFIXES:
		for rank in range(1, 10):
			var key := "%s_%d" % [suit, rank]
			var expected := "%s%s" % [NUMBER_TEXT[rank], TILE_SUFFIXES[suit]]
			_check(str(tile_texts.get(key, "")) == expected, "%s is the pure tile name %s" % [key, expected])


func _check_profile_resources(manifest: Dictionary) -> void:
	var profiles: Dictionary = manifest.get("profiles", {})
	_check(profiles.size() == 4, "manifest defines four language/gender profiles")
	for profile_name in profiles:
		var profile: Dictionary = profiles[profile_name]
		var directory := str(profile.get("directory", ""))
		var actions: Dictionary = profile.get("actions", {})
		_check(actions.size() == ACTION_KEYS.size(), "%s has every action utterance" % profile_name)
		for action_key in ACTION_KEYS:
			_check(not str(actions.get(action_key, "")).is_empty(), "%s action %s has text" % [profile_name, action_key])
		for tile_key in manifest.get("tile_texts", {}).keys():
			_check_audio("res://res/audio/%s/%s.wav" % [directory, tile_key], true)
		for action_key in ACTION_KEYS:
			_check_audio("res://res/audio/%s/%s.wav" % [directory, action_key], false)


func _check_audio(path: String, is_tile: bool) -> void:
	_check(ResourceLoader.exists(path), "%s exists" % path)
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	_check(stream != null, "%s loads as AudioStream" % path)
	if stream == null:
		return
	var maximum := 1.55 if is_tile else 3.20
	_check(stream.get_length() > 0.0 and stream.get_length() <= maximum, "%s duration %.3fs <= %.2fs" % [path, stream.get_length(), maximum])


func _check_runtime_mapping() -> void:
	var main = MAIN_SCRIPT.new()
	_check(main.call("_voice_profile_for_seat", 0).get("pack") == "male", "self seat uses male voice")
	_check(main.call("_voice_profile_for_seat", 1).get("pack") == "female", "upper seat uses female voice")
	_check(main.call("_voice_profile_for_seat", 2).get("pack") == "male", "opposite seat uses male voice")
	_check(main.call("_voice_profile_for_seat", 3).get("pack") == "female", "lower seat uses female voice")
	main.set("voice_language", "sichuan")
	var self_stream := main.call("_load_voice_stream", str(main.call("_voice_profile_for_seat", 0).get("pack")), "tong_5") as AudioStream
	var upper_stream := main.call("_load_voice_stream", str(main.call("_voice_profile_for_seat", 1).get("pack")), "tong_5") as AudioStream
	_check(self_stream != null and self_stream.resource_path == "res://res/audio/tts_sichuan/male/tong_5.wav", "self seat actually loads the Sichuan male pack")
	_check(upper_stream != null and upper_stream.resource_path == "res://res/audio/tts_sichuan/female/tong_5.wav", "upper seat actually loads the Sichuan female pack")
	var expected := {
		"胡": "hu", "自摸": "zimo", "抢杠胡": "qiang_gang_hu",
		"杠上花": "gang_shang_hua", "杠上炮": "gang_shang_pao",
	}
	for label in expected:
		_check(main.call("_action_audio_key", label) == expected[label], "%s maps to %s" % [label, expected[label]])
	main.free()


func _check_self_voice_choice() -> void:
	var options := VOICE_CATALOG.all_options()
	_check(options.size() == 14, "four original and ten new named voices are selectable")
	for option in options:
		_check(not str(option.get("name", "")).is_empty(), "voice has a visible name")
		var directory := str(option.get("directory", ""))
		for suit in TILE_SUFFIXES:
			for rank in range(1, 10):
				_check_audio("res://res/audio/%s/%s_%d.wav" % [directory, suit, rank], true)
		for action_key in ACTION_KEYS:
			var path := "res://res/audio/%s/%s.wav" % [directory, action_key]
			_check(ResourceLoader.exists(path), "%s exists" % path)
			if ResourceLoader.exists(path):
				var stream := load(path) as AudioStream
				_check(stream != null and stream.get_length() > 0.0 and stream.get_length() <= 4.2, "%s is a playable action clip" % path)
	var main = MAIN_SCRIPT.new()
	main.set("voice_language", "mandarin")
	main.set("my_voice_id", "sichuan_vivi_2")
	for language in ["mandarin", "sichuan"]:
		main.set("voice_language", language)
		main.call("_randomize_automatic_voices")
		var random_ids: Dictionary = main.get("automatic_voice_ids")
		for seat in range(4):
			var expected_gender := "male" if seat in [0, 2] else "female"
			var matching: Array[Dictionary] = VOICE_CATALOG.options_for(language, expected_gender)
			var random_id := str(random_ids.get(seat, ""))
			_check(matching.any(func(option): return str(option.get("id", "")) == random_id), "seat %d random voice matches %s %s" % [seat, language, expected_gender])
	main.set("voice_language", "mandarin")
	var self_stream := main.call("_load_voice_stream_for_seat", 0, "tong_5") as AudioStream
	var other_stream := main.call("_load_voice_stream_for_seat", 1, "tong_5") as AudioStream
	_check(self_stream != null and self_stream.resource_path == "res://res/audio/tts_sichuan/female/tong_5.wav", "chosen self voice overrides language and gender")
	_check(other_stream != null and other_stream.resource_path == "res://res/audio/tts/female/tong_5.wav", "other seat still follows language")
	main.set("my_voice_id", "")
	var default_stream := main.call("_load_voice_stream_for_seat", 0, "tong_5") as AudioStream
	_check(default_stream != null and default_stream.resource_path == "res://res/audio/tts/male/tong_5.wav", "follow language restores the original self voice")
	main.free()
	var bar := UTILITY_BAR_SCENE.instantiate()
	root.add_child(bar)
	bar.call("set_collapsed", false)
	var language_button := bar.call("get_button", "voice") as Button
	var choose_button := bar.call("get_button", "choose_voice") as Button
	_check(language_button != null and language_button.visible, "language switch remains available")
	_check(choose_button != null and choose_button.visible, "separate choose voice button exists")
	bar.free()
	var panel := VOICE_PANEL_SCRIPT.new()
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(2556, 1179)
	panel.call("open", "", "mandarin")
	_check((panel.get("panel") as Control).scale.x >= 1.49, "voice panel enlarges by at least half on large screens")
	_check((panel.get("options_scroll") as ScrollContainer).get_v_scroll_bar().custom_minimum_size.x >= 74.0, "voice scrollbar has a broad touch target")
	_check(panel.get("choice_buttons").size() == 14, "glass panel lists all loaded voices")
	_check(panel.get("preview_buttons").size() == 14, "each listed voice has a preview button")
	_check((panel.get("options_scroll") as ScrollContainer).get_child(0).custom_minimum_size.y > (panel.get("options_scroll") as ScrollContainer).size.y, "all voice rows fit in a scrollable list")
	var filter_buttons: Dictionary = panel.get("filter_buttons")
	_check(filter_buttons.size() == 3, "voice list offers all, Mandarin, and Sichuan filters")
	for language in ["mandarin", "sichuan"]:
		panel.call("_set_filter", language)
		var visible_count := 0
		for option in options:
			var voice_id := str(option.get("id", ""))
			var choice := (panel.get("choice_buttons") as Dictionary).get(voice_id) as Button
			var expected: bool = str(option.get("language", "")) == str(language)
			_check(choice.visible == expected, "%s filter handles %s" % [language, voice_id])
			if choice.visible:
				visible_count += 1
		_check(visible_count > 0, "%s filter has voices" % language)
		_check((panel.get("options_content") as Control).custom_minimum_size.y == visible_count * 88.0, "%s filter compacts the list" % language)
	panel.call("_set_filter", "all")
	for option in options:
		panel.call("_preview_voice", str(option.get("id", "")))
		var selected_stream := (panel.get("preview_player") as AudioStreamPlayer).stream
		_check(selected_stream != null and selected_stream.resource_path == "res://res/audio/%s/tong_5.wav" % str(option.get("directory", "")), "preview loads %s" % str(option.get("id", "")))
	panel.call("_preview_voice", "sichuan_vivi_2")
	var preview_stream := (panel.get("preview_player") as AudioStreamPlayer).stream
	_check(preview_stream != null and preview_stream.resource_path == "res://res/audio/tts_sichuan/female/tong_5.wav", "preview plays the selected voice resource")
	panel.call("_select_voice", "sichuan_vivi_2")
	_check(str(panel.get("selected_voice_id")) == "sichuan_vivi_2", "selecting a voice updates the panel")
	panel.call("close")
	panel.free()


func _finish() -> void:
	if failures.is_empty():
		print("SICHUAN_VOICE_PACK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
