extends Node
class_name SichuanLanRoomSession

signal status_changed(message: String)
signal room_state_changed(state: Dictionary)
signal match_start_received(controllers: Array)
signal game_command_result(result: Dictionary)
signal private_snapshot_received(snapshot: Dictionary)
signal history_received(history: Array)
signal player_disconnected(player: Dictionary)

const Transport := preload("res://scripts/network/lan_transport.gd")
const Codec := preload("res://scripts/network/protocol_codec.gd")
const Registry := preload("res://scripts/network/room_registry.gd")
const MatchAuthority := preload("res://scripts/network/match_authority.gd")
const SnapshotProjector := preload("res://scripts/network/snapshot_projector.gd")

var transport: Node
var codec = Codec.new()
var registry = Registry.new()
var is_host := false
var local_seat := -1
var local_player_id := ""
var resume_token := ""
var current_room_state: Dictionary = {}
var _nickname := "玩家"
var _match_authority
var _snapshot_projector = SnapshotProjector.new()
var _game_state: Node
var _client_sequence := 0
var _match_start_dispatched := false

func _ready() -> void:
	transport = Transport.new()
	add_child(transport)
	transport.connected.connect(_on_connected)
	transport.peer_left.connect(_on_peer_left)
	transport.disconnected.connect(func():
		var host_name := "房主"
		var host_seat := -1
		for member in current_room_state.get("members", []):
			if str(member.get("player_id", "")) == str(current_room_state.get("host_player_id", "")):
				host_name = str(member.get("nickname", host_name))
				host_seat = int(member.get("seat", -1))
				break
		player_disconnected.emit({"nickname": host_name, "seat": host_seat, "is_host": true})
		current_room_state.clear()
		status_changed.emit("房主连接中断"))
	transport.failed.connect(func(reason): status_changed.emit(str(reason)))
	transport.packet_received.connect(_on_packet)

func host(nickname: String = "房主", port: int = 27865) -> Error:
	reset()
	var joined: Dictionary = registry.create(1, nickname)
	if not joined.ok: return FAILED
	local_seat = int(joined.seat)
	local_player_id = str(joined.player_id)
	resume_token = str(joined.resume_token)
	var result: Error = transport.host(port)
	if result != OK:
		reset()
		return result
	is_host = true
	_publish_room_state()
	status_changed.emit("房间已创建，等待玩家加入")
	return OK

func join(address: String, port: int = 27865, nickname: String = "玩家") -> Error:
	reset()
	_nickname = nickname.strip_edges().left(24)
	var result: Error = transport.join(address, port)
	status_changed.emit("正在加入房间…" if result == OK else "加入失败：%s" % error_string(result))
	return result

func set_ready(ready: bool) -> bool:
	if is_host:
		if not registry.set_ready(1, ready):
			return false
		_publish_room_state()
		_maybe_auto_start()
		return true
	return _send(1, {"protocol_version": 1, "kind": "ready", "ready": ready}) == OK

func can_start_match() -> bool:
	return is_host and registry.can_start(2)

func start_match() -> bool:
	if _match_start_dispatched:
		return false
	if not can_start_match():
		status_changed.emit("至少需要 2 名真人，且所有真人都已准备")
		return false
	_match_start_dispatched = true
	var controllers := registry.build_seat_controllers()
	var message := {"protocol_version": 1, "kind": "match_start", "controllers": controllers}
	for peer_id in registry.peer_to_player.keys():
		if int(peer_id) != 1 and _send(int(peer_id), message) != OK:
			_match_start_dispatched = false
			status_changed.emit("开局消息发送失败")
			return false
	match_start_received.emit(controllers.duplicate(true))
	return true

func reset_guest_ready_for_next_round() -> void:
	if not is_host:
		return
	registry.reset_guest_ready()
	_match_start_dispatched = false
	_publish_room_state()

func activate_match_authority(game_state: Node) -> bool:
	if not is_host or game_state == null:
		return false
	var authority = MatchAuthority.new()
	if not authority.configure(game_state, registry.public_members()):
		return false
	_match_authority = authority
	_game_state = game_state
	if not game_state.state_changed.is_connected(_on_authority_state_changed):
		game_state.state_changed.connect(_on_authority_state_changed)
	_broadcast_private_snapshots()
	return true

func send_game_command(command: String, arguments: Dictionary = {}) -> bool:
	if is_host or local_player_id.is_empty():
		return false
	_client_sequence += 1
	var message := {"protocol_version": 1, "kind": "game_command", "sequence": _client_sequence, "command": command}
	for key in arguments:
		message[str(key)] = arguments[key]
	return _send(1, message) == OK

func publish_history(history: Array) -> void:
	if not is_host: return
	var message := {"protocol_version": 1, "kind": "room_history", "history": history}
	for peer_id in registry.peer_to_player.keys():
		if int(peer_id) != 1: _send(int(peer_id), message)

func reset() -> void:
	if transport != null: transport.close()
	registry.clear()
	is_host = false
	local_seat = -1
	local_player_id = ""
	resume_token = ""
	current_room_state.clear()
	_match_authority = null
	_game_state = null
	_client_sequence = 0
	_match_start_dispatched = false

func _on_connected() -> void:
	_send(1, {"protocol_version": 1, "kind": "join_room", "nickname": _nickname})

func _on_peer_left(peer_id: int) -> void:
	if is_host:
		var player_id := str(registry.peer_to_player.get(peer_id, ""))
		if player_id.is_empty():
			return
		var member: Dictionary = registry.members.get(player_id, {})
		var departed := {"nickname": str(member.get("nickname", "玩家")), "seat": int(member.get("seat", -1)), "is_host": false}
		registry.leave(peer_id)
		player_disconnected.emit(departed.duplicate(true))
		for remaining_peer in registry.peer_to_player.keys():
			if int(remaining_peer) != 1:
				_send(int(remaining_peer), {"protocol_version": 1, "kind": "player_disconnected", "player": departed})
		_publish_room_state()
		status_changed.emit("%s 已掉线" % departed.nickname)

func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var decoded: Dictionary = codec.decode(bytes)
	if not decoded.ok:
		transport.drop.call_deferred(peer_id)
		return
	var message: Dictionary = decoded.message
	if is_host:
		_handle_host_message(peer_id, message)
	elif peer_id == 1:
		_handle_client_message(message)

func _handle_host_message(peer_id: int, message: Dictionary) -> void:
	match str(message.kind):
		"join_room":
			var joined := registry.join(peer_id, str(message.get("nickname", "玩家")))
			if not joined.ok:
				_send(peer_id, {"protocol_version": 1, "kind": "join_rejected", "error": str(joined.error)})
				transport.drop.call_deferred(peer_id)
				return
			_send(peer_id, {"protocol_version": 1, "kind": "welcome", "player_id": joined.player_id, "seat": joined.seat, "resume_token": joined.resume_token})
			_publish_room_state()
			status_changed.emit("玩家已加入座位 %d" % (int(joined.seat) + 1))
		"ready":
			if registry.set_ready(peer_id, bool(message.get("ready", false))):
				_publish_room_state()
				_maybe_auto_start()
		"game_command":
			_handle_game_command(peer_id, message)
		_:
			transport.drop.call_deferred(peer_id)

func _handle_client_message(message: Dictionary) -> void:
	match str(message.kind):
		"welcome":
			local_player_id = str(message.get("player_id", ""))
			local_seat = int(message.get("seat", -1))
			resume_token = str(message.get("resume_token", ""))
			status_changed.emit("已加入座位 %d" % (local_seat + 1))
		"room_state":
			current_room_state = message.duplicate(true)
			room_state_changed.emit(current_room_state.duplicate(true))
		"join_rejected":
			status_changed.emit("加入被拒绝：%s" % str(message.get("error", "UNKNOWN")))
		"match_start":
			var controllers: Array = message.get("controllers", [])
			if controllers.size() == 4:
				match_start_received.emit(controllers.duplicate(true))
		"game_command_result":
			game_command_result.emit(Dictionary(message.get("result", {})).duplicate(true))
		"private_snapshot":
			var snapshot: Dictionary = message.get("snapshot", {})
			if int(snapshot.get("local_seat_id", -1)) == 0:
				private_snapshot_received.emit(snapshot.duplicate(true))
		"room_history":
			history_received.emit(Array(message.get("history", [])).duplicate(true))
		"player_disconnected":
			player_disconnected.emit(Dictionary(message.get("player", {})).duplicate(true))

func _publish_room_state() -> void:
	var state := {
		"protocol_version": 1,
		"kind": "room_state",
		"room_id": registry.room_id,
		"room_number": registry.room_number,
		"host_player_id": registry.host_player_id,
		"members": registry.public_members(),
		"controllers": registry.build_seat_controllers(),
		"human_count": registry.members.size(),
		"capacity": Registry.SEAT_COUNT,
		"state": "waiting",
	}
	current_room_state = state.duplicate(true)
	room_state_changed.emit(current_room_state.duplicate(true))
	for peer_id in registry.peer_to_player.keys():
		if int(peer_id) != 1: _send(int(peer_id), state)

func _maybe_auto_start() -> void:
	if is_host and not _match_start_dispatched and registry.can_start(2):
		call_deferred("start_match")

func _send(peer_id: int, message: Dictionary) -> Error:
	var bytes := codec.encode(message)
	return ERR_INVALID_DATA if bytes.is_empty() else transport.send_to(peer_id, bytes)

func _handle_game_command(peer_id: int, message: Dictionary) -> void:
	if _match_authority == null:
		_send(peer_id, {"protocol_version": 1, "kind": "game_command_result", "result": {"ok": false, "sequence": int(message.get("sequence", 0)), "error": "MATCH_NOT_ACTIVE"}})
		return
	var player_id := str(registry.peer_to_player.get(peer_id, ""))
	var result: Dictionary = _match_authority.handle_command(player_id, message)
	_send(peer_id, {"protocol_version": 1, "kind": "game_command_result", "result": result})
	if bool(result.get("ok", false)):
		_broadcast_private_snapshots()

func _on_authority_state_changed(_snapshot: Dictionary) -> void:
	_broadcast_private_snapshots()

func _broadcast_private_snapshots() -> void:
	if not is_host or _game_state == null:
		return
	for member in registry.public_members():
		var seat := int(member.seat)
		var authority_snapshot: Dictionary = _game_state.call("get_debug_snapshot", seat)
		var private_snapshot: Dictionary = _snapshot_projector.project(authority_snapshot, seat)
		if str(member.player_id) == local_player_id:
			private_snapshot_received.emit(private_snapshot)
			continue
		var peer_id := _peer_for_player(str(member.player_id))
		if peer_id > 0:
			var send_result := _send(peer_id, {"protocol_version": 1, "kind": "private_snapshot", "snapshot": private_snapshot})
			if send_result != OK:
				status_changed.emit("私有牌局快照发送失败：%s" % error_string(send_result))

func _peer_for_player(player_id: String) -> int:
	for peer_id in registry.peer_to_player:
		if str(registry.peer_to_player[peer_id]) == player_id:
			return int(peer_id)
	return -1
