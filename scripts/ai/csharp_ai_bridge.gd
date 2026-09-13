extends RefCounted

class_name CSharpAIBridge

const DOTNET_BIN := "/opt/homebrew/Cellar/dotnet/10.0.107/libexec/dotnet"
const CLI_DLL_PATH := "res://dotnet/AI.Core.Cli/bin/Release/net10.0/AI.Core.Cli.dll"
const TMP_DIR := "user://tmp_ai_core"
const HOST_DEFAULT_PORT := 38581
const HOST_CONNECT_TIMEOUT_MS := 1200
const HOST_READ_TIMEOUT_MS := 1200

const TileCodecScript := preload("res://scripts/ai/sichuan_tile_codec.gd")

var tile_codec = TileCodecScript.new()
var host_mode_enabled: bool = false
var host_port: int = HOST_DEFAULT_PORT
var host_pid: int = -1
var host_client: StreamPeerTCP = StreamPeerTCP.new()
var host_read_buffer: String = ""
var last_transport_mode: String = "cli"
var last_host_error: String = ""


func is_available() -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(CLI_DLL_PATH))


func analyze_discard(player_state: Dictionary, table_state: Dictionary, rules_config, request_tag: String = "", force_lightweight: bool = false, compact_result: bool = false) -> Dictionary:
	if not is_available():
		last_transport_mode = "unavailable"
		last_host_error = "cli_missing"
		return {}
	var payload := build_discard_transport_payload(player_state, table_state, rules_config, force_lightweight, compact_result)
	if _ensure_host_connection():
		var host_result := _analyze_discard_via_host(payload)
		if not host_result.is_empty():
			last_transport_mode = "host"
			return host_result
	var file_path := _write_payload(payload, request_tag)
	if file_path.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "payload_write_failed"
		return {}
	var output: Array = []
	var exit_code := OS.execute(DOTNET_BIN, [ProjectSettings.globalize_path(CLI_DLL_PATH), "discard-json", file_path], output, true, true)
	if exit_code != 0 or output.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "cli_exit_%d" % exit_code
		return {}
	var parsed := _parse_cli_output(output)
	last_transport_mode = "cli_after_host_miss" if host_mode_enabled else "cli"
	last_host_error = ""
	return parsed


func build_discard_transport_payload(player_state: Dictionary, table_state: Dictionary, rules_config, force_lightweight: bool = false, compact_result: bool = false) -> Dictionary:
	var payload := _build_payload(player_state, table_state, rules_config)
	if force_lightweight:
		payload["forceLightweight"] = true
		payload["mobileSpeedMode"] = true
	if compact_result:
		payload["compactResult"] = true
	return payload


func analyze_reaction(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, request_tag: String = "") -> Dictionary:
	if not is_available():
		last_transport_mode = "unavailable"
		last_host_error = "cli_missing"
		return {}
	var payload := _build_reaction_payload(candidate, player_state, table_state, discard_context, rules_config)
	if _ensure_host_connection():
		var host_result := _analyze_reaction_via_host(payload)
		if not host_result.is_empty():
			last_transport_mode = "host"
			return host_result
	var file_path := _write_payload(payload, "reaction_%s" % request_tag)
	if file_path.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "payload_write_failed"
		return {}
	var output: Array = []
	var exit_code := OS.execute(DOTNET_BIN, [ProjectSettings.globalize_path(CLI_DLL_PATH), "reaction-json", file_path], output, true, true)
	if exit_code != 0 or output.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "cli_exit_%d" % exit_code
		return {}
	var parsed := _parse_cli_output(output)
	last_transport_mode = "cli_after_host_miss" if host_mode_enabled else "cli"
	last_host_error = ""
	return parsed


func build_reaction_transport_payload(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config) -> Dictionary:
	return _build_reaction_payload(candidate, player_state, table_state, discard_context, rules_config)


func build_self_action_transport_payload(player_state: Dictionary, table_state: Dictionary, rules_config, can_self_hu: bool, an_gang_tile_types: Array, add_gang_tile_types: Array, _add_gang_qiang_gang_counts: Dictionary = {}, mandatory_gang_tile_types: Array = []) -> Dictionary:
	var payload := _build_payload(player_state, table_state, rules_config)
	payload["canSelfHu"] = can_self_hu
	payload["anGangTileTypes"] = an_gang_tile_types.duplicate(true)
	payload["addGangTileTypes"] = add_gang_tile_types.duplicate(true)
	# Actual rob-gang candidates are computed from concealed opponent hands.
	# Unknown is not zero risk: the decision engine must use public belief.
	payload["addGangQiangGangCounts"] = {}
	payload["mandatoryGangTileTypes"] = mandatory_gang_tile_types.duplicate(true)
	return payload


func build_ding_que_transport_payload(hand_tiles: Array, active_suits: Array) -> Dictionary:
	var counts := {}
	for suit_value in active_suits:
		counts[str(suit_value)] = 0
	for tile in hand_tiles:
		var suit := str(tile.get("suit", ""))
		if counts.has(suit):
			counts[suit] = int(counts.get(suit, 0)) + 1
	return {
		"suitCounts": counts,
		"activeSuits": active_suits.duplicate(true),
	}


func analyze_ding_que(hand_tiles: Array, active_suits: Array, request_tag: String = "") -> Dictionary:
	if not is_available():
		last_transport_mode = "unavailable"
		last_host_error = "cli_missing"
		return {}
	var payload := build_ding_que_transport_payload(hand_tiles, active_suits)
	if _ensure_host_connection():
		var host_result := _analyze_ding_que_via_host(payload)
		if not host_result.is_empty():
			last_transport_mode = "host"
			return host_result
	var file_path := _write_payload(payload, "ding_que_%s" % request_tag)
	if file_path.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "payload_write_failed"
		return {}
	var output: Array = []
	var exit_code := OS.execute(DOTNET_BIN, [ProjectSettings.globalize_path(CLI_DLL_PATH), "ding-que-json", file_path], output, true, true)
	if exit_code != 0 or output.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "cli_exit_%d" % exit_code
		return {}
	var parsed := _parse_cli_output(output)
	last_transport_mode = "cli_after_host_miss" if host_mode_enabled else "cli"
	last_host_error = ""
	return parsed


func analyze_self_action(player_state: Dictionary, table_state: Dictionary, rules_config, can_self_hu: bool, an_gang_tile_types: Array, add_gang_tile_types: Array, add_gang_qiang_gang_counts: Dictionary = {}, mandatory_gang_tile_types: Array = [], request_tag: String = "") -> Dictionary:
	if not is_available():
		last_transport_mode = "unavailable"
		last_host_error = "cli_missing"
		return {}
	var payload := build_self_action_transport_payload(player_state, table_state, rules_config, can_self_hu, an_gang_tile_types, add_gang_tile_types, add_gang_qiang_gang_counts, mandatory_gang_tile_types)
	if _ensure_host_connection():
		var host_result := _analyze_self_action_via_host(payload)
		if not host_result.is_empty():
			last_transport_mode = "host"
			return host_result
	var file_path := _write_payload(payload, "self_action_%s" % request_tag)
	if file_path.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "payload_write_failed"
		return {}
	var output: Array = []
	var exit_code := OS.execute(DOTNET_BIN, [ProjectSettings.globalize_path(CLI_DLL_PATH), "self-action-json", file_path], output, true, true)
	if exit_code != 0 or output.is_empty():
		last_transport_mode = "cli_failed"
		last_host_error = "cli_exit_%d" % exit_code
		return {}
	var parsed := _parse_cli_output(output)
	last_transport_mode = "cli_after_host_miss" if host_mode_enabled else "cli"
	last_host_error = ""
	return parsed


func set_host_mode_enabled(enabled: bool, port: int = HOST_DEFAULT_PORT) -> void:
	host_mode_enabled = enabled
	host_port = port
	if not enabled:
		_disconnect_host()


func get_host_mode_enabled() -> bool:
	return host_mode_enabled


func get_host_port() -> int:
	return host_port


func is_host_connected() -> bool:
	return host_client.get_status() == StreamPeerTCP.STATUS_CONNECTED


func get_last_transport_mode() -> String:
	return last_transport_mode


func get_last_host_error() -> String:
	return last_host_error


func _build_payload(player_state: Dictionary, table_state: Dictionary, rules_config) -> Dictionary:
	var active_suits: Array = tile_codec.resolve_active_suits(rules_config)
	var players: Array = table_state.get("players", [])
	var self_seat := int(player_state.get("seat", -1))
	var hand_tiles: Array = player_state.get("hand_tiles", [])
	var last_draw_tile_type := -1
	var last_draw: Dictionary = table_state.get("last_draw_tile", {})
	if int(last_draw.get("seat", -1)) == self_seat:
		last_draw_tile_type = tile_codec.tile_type(last_draw.get("tile", {}), active_suits)
	var hand18: PackedInt32Array = tile_codec.build_count_array(hand_tiles, active_suits)
	var visible18: PackedInt32Array = tile_codec.build_visible_count_array(players, hand_tiles, active_suits, self_seat)
	var remaining18: PackedInt32Array = tile_codec.build_remaining_count_array(hand_tiles, players, active_suits, self_seat)
	var discards18: Array = []
	var melds18: Array = []
	var meld_views: Array = []
	var passed_hu18: Array = _build_reaction_pass_count_matrix(table_state.get("reaction_pass_evidence", []), active_suits, "can_hu", self_seat)
	var passed_peng18: Array = _build_reaction_pass_count_matrix(table_state.get("reaction_pass_evidence", []), active_suits, "can_peng", self_seat)
	var passed_gang18: Array = _build_reaction_pass_count_matrix(table_state.get("reaction_pass_evidence", []), active_suits, "can_gang", self_seat)
	var is_called := PackedByteArray()
	is_called.resize(4)
	var is_ready := PackedByteArray()
	is_ready.resize(4)
	var has_hu := PackedByteArray()
	has_hu.resize(4)
	var scores: Array[int] = []
	var ding_que_suits: Array[int] = []
	var hand_counts: Array[int] = []
	var active_seats: Array[bool] = []
	var discard_total := 0
	var meld_total := 0
	for index in range(mini(4, players.size())):
		var player: Dictionary = players[index]
		var encoded_discards := _encode_tile_list(player.get("discards", []), active_suits)
		var encoded_melds := _encode_meld_tile_list(player.get("melds", []), active_suits)
		discards18.append(encoded_discards)
		melds18.append(encoded_melds)
		meld_views.append(_encode_meld_views(player.get("melds", []), active_suits))
		discard_total += encoded_discards.size()
		meld_total += encoded_melds.size()
		scores.append(int(player.get("score", 0)))
		ding_que_suits.append(active_suits.find(str(player.get("ding_que", ""))))
		hand_counts.append(int(player.get("hand_count", 0)))
		active_seats.append(not bool(player.get("has_won", false)))
		is_called[index] = 1 if not Array(player.get("melds", [])).is_empty() else 0
		# Sichuan has no public ready declaration: opponent is_ting is private.
		is_ready[index] = 1 if index == self_seat and bool(player.get("is_ting", false)) else 0
		has_hu[index] = 1 if bool(player.get("has_won", false)) else 0
	while discards18.size() < 4:
		discards18.append([])
	while melds18.size() < 4:
		melds18.append([])
	while scores.size() < 4:
		scores.append(0)
	while ding_que_suits.size() < 4:
		ding_que_suits.append(-1)
	while hand_counts.size() < 4:
		hand_counts.append(0)
	while active_seats.size() < 4:
		active_seats.append(false)
	while meld_views.size() < 4:
		meld_views.append([])
	var public_events: Array = table_state.get("public_ai_events", [])
	var encoded_public_events := _encode_public_events(public_events, active_suits, self_seat)
	# Private reaction counts must not leak through event IDs/cache seeds either.
	var event_version := int(JSON.stringify(encoded_public_events).hash() & 0x7fffffff)
	var visible_version := event_version
	var hand_version := int(player_state.get("hand_count", hand_tiles.size())) * 19 + hand_tiles.size()
	var shun_locks: Dictionary = table_state.get("shun_he_locks", {})
	var locked_fans: Array[int] = []
	var lock_turns: Array[int] = []
	var unlock_on_own_draw: Array[bool] = []
	for seat in range(4):
		var lock_info: Dictionary = shun_locks.get(seat, shun_locks.get(str(seat), {}))
		if seat != self_seat:
			lock_info = {}
		locked_fans.append(int(lock_info.get("locked_fan", lock_info.get("min_fan", -1))))
		lock_turns.append(int(lock_info.get("lock_turn", -1)))
		unlock_on_own_draw.append(bool(lock_info.get("unlock_on_own_draw", true)))
	var last_gang: Dictionary = table_state.get("last_gang_context", {})
	var test_policy_variants: Dictionary = table_state.get("test_ai_policy_variants_by_seat", {})
	var policy_variant := str(test_policy_variants.get(self_seat, test_policy_variants.get(str(self_seat), "current")))
	return {
		"seatIndex": self_seat,
		"dealerSeat": _resolve_dealer_seat(players, table_state, self_seat),
		"currentSeat": int(table_state.get("current_turn_seat", self_seat)),
		"wallCount": int(table_state.get("wall_count", 0)),
		"roundIndex": int(table_state.get("round_index", 0)),
		"totalRounds": int(table_state.get("total_rounds", 0)),
		"remainingRounds": int(table_state.get("remaining_rounds", 0)),
		"visibleVersion": visible_version,
		"handVersion": hand_version,
		"strategyContextVersion": visible_version + hand_version,
		"eventVersion": event_version,
		"informationMode": "public",
		"policyVariant": policy_variant,
		"scores": scores,
		"dingQueSuits": ding_que_suits,
		"handCounts": hand_counts,
		"lockedFans": locked_fans,
		"lockTurns": lock_turns,
		"unlockOnOwnDraw": unlock_on_own_draw,
		"activeSeats": active_seats,
		# bone_ash is the public-information veteran baseline on every device.
		# Lightweight mode remains opt-in through an explicit forceLightweight payload
		# flag; the platform itself must not change the AI's action selection.
		"mobileSpeedMode": false,
		"compactResult": OS.has_feature("android") or OS.has_feature("ios"),
		"hand18": hand18,
		"visible18": visible18,
		"remaining18": remaining18,
		"discards18": discards18,
		"melds18": melds18,
		"meldViews": meld_views,
		"publicEvents": encoded_public_events,
		"passedHu18": passed_hu18,
		"passedPeng18": passed_peng18,
		"passedGang18": passed_gang18,
		"isCalled": _byte_array_to_bool_array(is_called),
		"isReady": _byte_array_to_bool_array(is_ready),
		"hasHu": _byte_array_to_bool_array(has_hu),
		"lastDrawTileType": last_draw_tile_type,
		"lastDrawOrigin": "draw" if last_draw_tile_type >= 0 else "unknown",
		"lastGangSeat": int(last_gang.get("seat", -1)),
		"lastGangTileType": tile_codec.tile_type(last_gang.get("tile", {}), active_suits),
		"lastGangType": str(last_gang.get("gang_type", "")),
	}


func _encode_meld_views(melds: Array, active_suits: Array) -> Array:
	var result: Array = []
	var index := 0
	for meld_item in melds:
		var meld: Dictionary = meld_item
		var tiles: Array = meld.get("tiles", [])
		if tiles.is_empty():
			continue
		var raw_type := str(meld.get("gang_subtype", meld.get("type", "peng")))
		var meld_type := "peng"
		match raw_type:
			"an_gang": meld_type = "concealedGang"
			"add_gang": meld_type = "addedGang"
			"gang", "melded_gang": meld_type = "meldedGang"
		result.append({
			"type": meld_type,
			"tileType": tile_codec.tile_type(tiles[0], active_suits),
			"sourceSeat": int(meld.get("from_seat", -1)),
			"eventIndex": index,
		})
		index += 1
	return result


func _encode_public_events(events: Array, active_suits: Array, self_seat: int) -> Array:
	var result: Array = []
	for event_item in events:
		var event: Dictionary = event_item
		var event_type := str(event.get("type", "pass"))
		match event_type:
			"concealed_gang": event_type = "concealedGang"
			"melded_gang": event_type = "meldedGang"
			"added_gang": event_type = "addedGang"
		var event_seat := int(event.get("seat", -1))
		# These events exist only when the engine found a legal private reaction.
		# Even retaining a pass with all permission bits false reveals its presence.
		if event_type == "pass" and event_seat != self_seat:
			continue
		var tile_type := tile_codec.tile_type(event.get("tile", {}), active_suits)
		if event_type == "draw" and event_seat != self_seat:
			tile_type = -1
		result.append({
			"eventIndex": result.size() + 1,
			"turnIndex": int(event.get("turnIndex", 0)),
			"seat": event_seat,
			"type": event_type,
			"tileType": tile_type,
			"origin": str(event.get("origin", "unknown")),
			"sourceSeat": int(event.get("sourceSeat", -1)),
			"wallCountAfter": int(event.get("wallCountAfter", -1)),
			"canHu": bool(event.get("canHu", false)),
			"canPeng": bool(event.get("canPeng", false)),
			"canGang": bool(event.get("canGang", false)),
		})
	return result


func _build_reaction_pass_count_matrix(pass_evidence: Array, active_suits: Array, flag_key: String, self_seat: int) -> Array:
	var matrix: Array = []
	var tile_type_count := active_suits.size() * 9
	for _seat in range(4):
		var row: Array[int] = []
		for _tile_type in range(tile_type_count):
			row.append(0)
		matrix.append(row)
	for item in pass_evidence:
		var event: Dictionary = item
		if not bool(event.get(flag_key, false)):
			continue
		var seat := int(event.get("seat", -1))
		if seat < 0 or seat >= 4 or seat != self_seat:
			continue
		var tile: Dictionary = event.get("tile", {})
		var tile_type := tile_codec.tile_type(tile, active_suits)
		if tile_type < 0 or tile_type >= tile_type_count:
			continue
		matrix[seat][tile_type] = int(matrix[seat][tile_type]) + 1
	return matrix


func _build_reaction_payload(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config) -> Dictionary:
	var payload := _build_payload(player_state, table_state, rules_config)
	var active_suits: Array = tile_codec.resolve_active_suits(rules_config)
	var reaction_tile: Dictionary = discard_context.get("tile", {})
	payload["reactionTileType"] = tile_codec.tile_type(reaction_tile, active_suits)
	payload["sourceSeat"] = int(discard_context.get("source_seat", int(candidate.get("source_seat", -1))))
	payload["reactionType"] = str(discard_context.get("reaction_type", "discard"))
	payload["canHu"] = bool(candidate.get("can_hu", false))
	payload["canPeng"] = bool(candidate.get("can_peng", false))
	payload["canGang"] = bool(candidate.get("can_gang", false))
	payload["mandatoryGang"] = bool(candidate.get("mandatory_gang", false))
	return payload


func _resolve_dealer_seat(players: Array, table_state: Dictionary, fallback: int) -> int:
	if table_state.has("dealer_seat"):
		return int(table_state.get("dealer_seat", fallback))
	for player in players:
		if bool(player.get("is_dealer", false)):
			return int(player.get("seat", fallback))
	return fallback


func _write_payload(payload: Dictionary, request_tag: String = "") -> String:
	var dir_path := ProjectSettings.globalize_path(TMP_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var safe_tag := request_tag.strip_edges()
	if safe_tag.is_empty():
		safe_tag = "default"
	var file_path := dir_path.path_join("discard_payload_%s.json" % safe_tag)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(payload))
	file.close()
	return file_path


func _parse_cli_output(output: Array) -> Dictionary:
	# OS.execute can merge diagnostic text with stdout on macOS. Prefer the
	# complete JSON document, then recover the outermost object so a harmless
	# native/runtime warning cannot erase an otherwise valid AI decision.
	var raw := "\n".join(output.map(func(item): return str(item))).strip_edges()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	var first_object := raw.find("{")
	var last_object := raw.rfind("}")
	if first_object >= 0 and last_object > first_object:
		parsed = JSON.parse_string(raw.substr(first_object, last_object - first_object + 1))
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {}


func _byte_array_to_bool_array(bytes: PackedByteArray) -> Array:
	var result: Array = []
	for value in bytes:
		result.append(int(value) != 0)
	return result


func _tile_type_from_key(key: String, active_suits: Array) -> int:
	var parts := key.split("_", false)
	if parts.size() != 2:
		return -1
	return tile_codec.encode_tile(str(parts[0]), int(parts[1]), active_suits)


func _ensure_host_connection() -> bool:
	if not host_mode_enabled or not is_available():
		return false
	if host_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		return true
	if host_pid <= 0:
		_start_host_process()
	if host_client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		host_client = StreamPeerTCP.new()
		host_read_buffer = ""
		var connect_err: int = host_client.connect_to_host("127.0.0.1", host_port)
		if connect_err != OK and connect_err != ERR_ALREADY_IN_USE and connect_err != ERR_BUSY:
			last_host_error = "connect_err_%d" % connect_err
			return false
	var deadline: int = Time.get_ticks_msec() + HOST_CONNECT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		host_client.poll()
		if host_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			last_host_error = ""
			return true
		OS.delay_msec(20)
	last_host_error = "connect_timeout"
	return host_client.get_status() == StreamPeerTCP.STATUS_CONNECTED


func _start_host_process() -> void:
	var cli_path: String = ProjectSettings.globalize_path(CLI_DLL_PATH)
	host_pid = OS.create_process(DOTNET_BIN, [cli_path, "host-tcp", "--port=%d" % host_port], false)
	if host_pid <= 0:
		last_host_error = "create_process_failed"


func _disconnect_host() -> void:
	if host_client.get_status() != StreamPeerTCP.STATUS_NONE:
		host_client.disconnect_from_host()
	host_client = StreamPeerTCP.new()
	host_read_buffer = ""
	host_pid = -1


func _analyze_discard_via_host(payload: Dictionary) -> Dictionary:
	var request: Dictionary = {
		"action": "discard",
		"payload": payload,
	}
	var request_line: String = JSON.stringify(request) + "\n"
	var send_err: int = host_client.put_data(request_line.to_utf8_buffer())
	if send_err != OK:
		last_host_error = "send_err_%d" % send_err
		_disconnect_host()
		return {}
	var response_line: String = _read_host_line(HOST_READ_TIMEOUT_MS)
	if response_line == "":
		if last_host_error == "":
			last_host_error = "host_empty_response"
		_disconnect_host()
		return {}
	var parsed = JSON.parse_string(response_line)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_host_error = "host_invalid_json"
		return {}
	var response: Dictionary = parsed
	if not bool(response.get("ok", false)):
		last_host_error = str(response.get("error", "host_error"))
		return {}
	var result = response.get("result", {})
	last_host_error = ""
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _analyze_reaction_via_host(payload: Dictionary) -> Dictionary:
	var request: Dictionary = {
		"action": "reaction",
		"reactionPayload": payload,
	}
	var request_line: String = JSON.stringify(request) + "\n"
	var send_err: int = host_client.put_data(request_line.to_utf8_buffer())
	if send_err != OK:
		last_host_error = "send_err_%d" % send_err
		_disconnect_host()
		return {}
	var response_line: String = _read_host_line(HOST_READ_TIMEOUT_MS)
	if response_line == "":
		if last_host_error == "":
			last_host_error = "host_empty_response"
		_disconnect_host()
		return {}
	var parsed = JSON.parse_string(response_line)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_host_error = "host_invalid_json"
		return {}
	var response: Dictionary = parsed
	if not bool(response.get("ok", false)):
		last_host_error = str(response.get("error", "host_error"))
		return {}
	var result = response.get("result", {})
	last_host_error = ""
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _analyze_self_action_via_host(payload: Dictionary) -> Dictionary:
	var request: Dictionary = {
		"action": "self_action",
		"selfActionPayload": payload,
	}
	var request_line: String = JSON.stringify(request) + "\n"
	var send_err: int = host_client.put_data(request_line.to_utf8_buffer())
	if send_err != OK:
		last_host_error = "send_err_%d" % send_err
		_disconnect_host()
		return {}
	var response_line: String = _read_host_line(HOST_READ_TIMEOUT_MS)
	if response_line == "":
		if last_host_error == "":
			last_host_error = "host_empty_response"
		_disconnect_host()
		return {}
	var parsed = JSON.parse_string(response_line)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_host_error = "host_invalid_json"
		return {}
	var response: Dictionary = parsed
	if not bool(response.get("ok", false)):
		last_host_error = str(response.get("error", "host_error"))
		return {}
	var result = response.get("result", {})
	last_host_error = ""
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _analyze_ding_que_via_host(payload: Dictionary) -> Dictionary:
	var request: Dictionary = {
		"action": "ding_que",
		"dingQuePayload": payload,
	}
	var request_line: String = JSON.stringify(request) + "\n"
	var send_err: int = host_client.put_data(request_line.to_utf8_buffer())
	if send_err != OK:
		last_host_error = "send_err_%d" % send_err
		_disconnect_host()
		return {}
	var response_line: String = _read_host_line(HOST_READ_TIMEOUT_MS)
	if response_line == "":
		if last_host_error == "":
			last_host_error = "host_empty_response"
		_disconnect_host()
		return {}
	var parsed = JSON.parse_string(response_line)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_host_error = "host_invalid_json"
		return {}
	var response: Dictionary = parsed
	if not bool(response.get("ok", false)):
		last_host_error = str(response.get("error", "host_error"))
		return {}
	var result = response.get("result", {})
	last_host_error = ""
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _read_host_line(timeout_ms: int) -> String:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		host_client.poll()
		if host_client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			last_host_error = "host_disconnected"
			break
		var available: int = host_client.get_available_bytes()
		if available > 0:
			var packet: Array = host_client.get_data(available)
			if packet.size() >= 2 and int(packet[0]) == OK:
				host_read_buffer += PackedByteArray(packet[1]).get_string_from_utf8()
				var newline_index: int = host_read_buffer.find("\n")
				if newline_index >= 0:
					var line: String = host_read_buffer.substr(0, newline_index)
					host_read_buffer = host_read_buffer.substr(newline_index + 1)
					return line
		OS.delay_msec(10)
	if last_host_error == "":
		last_host_error = "read_timeout"
	return ""


func _encode_tile_list(tiles: Array, active_suits: Array) -> Array:
	var result: Array = []
	for tile in tiles:
		var code := tile_codec.tile_type(tile, active_suits)
		if code >= 0:
			result.append(code)
	return result


func _encode_meld_tile_list(melds: Array, active_suits: Array) -> Array:
	var result: Array = []
	for meld in melds:
		for tile in meld.get("tiles", []):
			var code := tile_codec.tile_type(tile, active_suits)
			if code >= 0:
				result.append(code)
	return result
