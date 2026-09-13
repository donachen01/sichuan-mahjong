extends SceneTree

const MAIN_SCRIPT := preload("res://scripts/game/MainSceneV2.gd")
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
