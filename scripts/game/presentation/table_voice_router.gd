extends RefCounted

const VOICE_CATALOG := preload("res://scripts/ui/table/SichuanVoiceCatalog.gd")

var seat_voice_profiles: Dictionary = {}
var automatic_voice_ids: Dictionary = {}
var voice_cache: Dictionary = {}

func _assign_voice_profiles_for_round(snapshot: Dictionary, voice_language: String) -> void:
	seat_voice_profiles.clear()
	var players: Array = snapshot.get("players", [])
	for seat in [0, 1, 2, 3]:
		var player: Dictionary = {}
		for candidate in players:
			if int(candidate.get("seat", -1)) == seat:
				player = candidate
				break
		if player.is_empty():
			continue
		# Seat order is fixed in this table: self (0) and opposite (2) use male
		# voices; upper (1) and lower (3) use female voices.
		var use_male: bool = seat in [0, 2]
		seat_voice_profiles[seat] = {
			"gender": "male" if use_male else "female",
			"pack": "male" if use_male else "female",
		}
	_randomize_automatic_voices(voice_language)


func _randomize_automatic_voices(voice_language: String) -> void:
	automatic_voice_ids.clear()
	for seat in [0, 1, 2, 3]:
		var profile := _voice_profile_for_seat(seat)
		var options := VOICE_CATALOG.options_for(voice_language, str(profile.get("gender", "male")))
		if not options.is_empty():
			automatic_voice_ids[seat] = str(options[randi_range(0, options.size() - 1)].get("id", ""))


func _voice_profile_for_seat(seat: int) -> Dictionary:
	if seat_voice_profiles.has(seat):
		return seat_voice_profiles[seat]
	var use_male: bool = seat in [0, 2]
	return {"gender": "male" if use_male else "female", "pack": "male" if use_male else "female"}


func _action_audio_key(text: String) -> String:
	match text:
		"碰":
			return "peng"
		"杠":
			return "gang"
		"胡":
			return "hu"
		"自摸":
			return "zimo"
		"抢杠胡":
			return "qiang_gang_hu"
		"杠上花":
			return "gang_shang_hua"
		"杠上炮":
			return "gang_shang_pao"
		"过":
			return "pass"
		"赢了":
			return "win"
		"输了":
			return "lose"
		_:
			return ""


func _load_voice_stream(pack: String, key: String, voice_language: String) -> AudioStream:
	var dialect_dir := "tts_sichuan" if voice_language == "sichuan" else "tts"
	return _load_voice_stream_at("%s/%s" % [dialect_dir, pack], key)


func _load_voice_stream_for_seat(seat: int, key: String, voice_language: String, my_voice_id: String) -> AudioStream:
	if seat == 0 and my_voice_id != "":
		for option in VOICE_CATALOG.all_options():
			if str(option.get("id", "")) == my_voice_id:
				return _load_voice_stream_at(str(option.get("directory", "")), key)
	var automatic_id := str(automatic_voice_ids.get(seat, ""))
	for option in VOICE_CATALOG.all_options():
		if str(option.get("id", "")) == automatic_id and str(option.get("language", "")) == voice_language:
			return _load_voice_stream_at(str(option.get("directory", "")), key)
	var profile := _voice_profile_for_seat(seat)
	return _load_voice_stream(str(profile.get("pack", "female")), key, voice_language)


func _load_voice_stream_at(directory: String, key: String) -> AudioStream:
	var cache_key := "%s/%s" % [directory, key]
	if voice_cache.has(cache_key):
		return voice_cache[cache_key]
	var path := "res://res/audio/%s/%s.wav" % [directory, key]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		voice_cache[cache_key] = stream
	return stream
