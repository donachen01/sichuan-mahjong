extends Node
## Permission-light LAN discovery. Uses bounded unicast probes instead of broadcast.

signal rooms_changed(rooms: Array[Dictionary])
signal discovery_failed(reason: String)

const PROTOCOL := "scmj-room-discovery-1"
const DISCOVERY_PORT := 27864
const ROOM_TTL_MS := 6500
const RESCAN_MS := 3000
const SENDS_PER_FRAME := 24

var _socket: PacketPeerUDP
var _host_mode := false
var _room_id := ""
var _room_name := ""
var _game_port := 27865
var _metadata: Dictionary = {}
var _targets: Array[String] = []
var _target_index := 0
var _next_scan_ms := 0
var _nonce := ""
var _rooms: Dictionary = {}


func start_host(room_id: String, room_name: String, game_port: int, metadata: Dictionary = {}) -> Error:
	stop()
	if room_id.is_empty() or room_name.strip_edges().is_empty() or game_port < 1024 or game_port > 65535:
		return ERR_INVALID_PARAMETER
	_socket = PacketPeerUDP.new()
	var result := _socket.bind(DISCOVERY_PORT, "0.0.0.0")
	if result != OK:
		_socket = null
		discovery_failed.emit("无法发布房间：%s" % error_string(result))
		return result
	_host_mode = true
	_room_id = room_id
	_room_name = room_name.strip_edges().left(32)
	_game_port = game_port
	_metadata = metadata.duplicate(true)
	set_process(true)
	return OK


func start_browsing(test_targets: Array[String] = []) -> Error:
	stop()
	_socket = PacketPeerUDP.new()
	var result := _socket.bind(0, "0.0.0.0")
	if result != OK:
		_socket = null
		discovery_failed.emit("无法搜索房间：%s" % error_string(result))
		return result
	_targets = test_targets.duplicate()
	if _targets.is_empty():
		_targets = _build_private_ipv4_targets()
	if _targets.is_empty():
		stop()
		discovery_failed.emit("没有找到可用的 Wi-Fi IPv4 地址")
		return ERR_CANT_RESOLVE
	_begin_scan()
	set_process(true)
	return OK


func stop() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_host_mode = false
	_targets.clear()
	_rooms.clear()
	_metadata.clear()
	_target_index = 0
	set_process(false)


func get_rooms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for room in _rooms.values():
		result.append(Dictionary(room).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
	return result

func update_host_metadata(metadata: Dictionary) -> void:
	if _host_mode:
		_metadata = metadata.duplicate(true)


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_receive_packets()
	if _host_mode:
		return
	var sent := 0
	while _target_index < _targets.size() and sent < SENDS_PER_FRAME:
		_send_probe(_targets[_target_index])
		_target_index += 1
		sent += 1
	var now := Time.get_ticks_msec()
	if _target_index >= _targets.size() and now >= _next_scan_ms:
		_begin_scan()
	_expire_rooms(now)


func _receive_packets() -> void:
	while _socket != null and _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var source_ip := _socket.get_packet_ip()
		var source_port := _socket.get_packet_port()
		if packet.is_empty() or packet.size() > 1024:
			continue
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if not data is Dictionary or data.get("protocol") != PROTOCOL:
			continue
		if _host_mode:
			_handle_probe(data, source_ip, source_port)
		else:
			_handle_offer(data, source_ip)


func _handle_probe(data: Dictionary, source_ip: String, source_port: int) -> void:
	if data.size() != 3 or data.get("kind") != "discover" or not data.get("nonce") is String:
		return
	var offer := {
		"protocol": PROTOCOL,
		"kind": "offer",
		"nonce": str(data.nonce),
		"room_id": _room_id,
		"name": _room_name,
		"game_port": _game_port,
		"protocol_version": 1,
		"room_number": str(_metadata.get("room_number", "")),
		"host_name": str(_metadata.get("host_name", _room_name)).left(24),
		"human_count": clampi(int(_metadata.get("human_count", 1)), 1, 4),
		"capacity": 4,
		"state": str(_metadata.get("state", "waiting")),
		"rule_label": str(_metadata.get("rule_label", "四川血战到底")).left(32),
	}
	_socket.set_dest_address(source_ip, source_port)
	_socket.put_packet(JSON.stringify(offer).to_utf8_buffer())


func _handle_offer(data: Dictionary, source_ip: String) -> void:
	if data.size() < 7 or data.get("kind") != "offer" or data.get("nonce") != _nonce:
		return
	var room_id := str(data.get("room_id", ""))
	var name := str(data.get("name", "")).strip_edges()
	var port := int(data.get("game_port", 0))
	if room_id.is_empty() or name.is_empty() or name.length() > 32 or port < 1024 or port > 65535 or int(data.get("protocol_version", 0)) != 1:
		return
	var room_number := str(data.get("room_number", ""))
	if not room_number.is_empty() and (room_number.length() != 6 or not room_number.is_valid_int()):
		return
	_rooms[room_id] = {
		"room_id": room_id, "room_number": room_number, "name": name,
		"host_name": str(data.get("host_name", name)), "human_count": int(data.get("human_count", 1)),
		"capacity": int(data.get("capacity", 4)), "state": str(data.get("state", "waiting")),
		"rule_label": str(data.get("rule_label", "四川血战到底")),
		"address": source_ip, "port": port, "seen_ms": Time.get_ticks_msec()
	}
	rooms_changed.emit(get_rooms())


func _send_probe(address: String) -> void:
	if _socket.set_dest_address(address, DISCOVERY_PORT) == OK:
		_socket.put_packet(JSON.stringify({"protocol": PROTOCOL, "kind": "discover", "nonce": _nonce}).to_utf8_buffer())


func _begin_scan() -> void:
	_nonce = "%d-%d" % [Time.get_ticks_msec(), randi()]
	_target_index = 0
	_next_scan_ms = Time.get_ticks_msec() + RESCAN_MS


func _expire_rooms(now: int) -> void:
	var changed := false
	for room_id in _rooms.keys():
		if now - int(_rooms[room_id].seen_ms) > ROOM_TTL_MS:
			_rooms.erase(room_id)
			changed = true
	if changed:
		rooms_changed.emit(get_rooms())


func _build_private_ipv4_targets() -> Array[String]:
	var targets: Array[String] = []
	var seen_prefixes := {}
	for address in IP.get_local_addresses():
		if not _is_private_ipv4(address):
			continue
		var parts := address.split(".")
		var prefix := "%s.%s.%s." % [parts[0], parts[1], parts[2]]
		if seen_prefixes.has(prefix):
			continue
		seen_prefixes[prefix] = true
		for host in range(1, 255):
			var target := prefix + str(host)
			if target != address:
				targets.append(target)
	return targets


func _is_private_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not str(part).is_valid_int() or int(part) < 0 or int(part) > 255:
			return false
	var first := int(parts[0])
	var second := int(parts[1])
	return first == 10 or (first == 172 and second >= 16 and second <= 31) or (first == 192 and second == 168)


func _exit_tree() -> void:
	stop()
