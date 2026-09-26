extends Node

signal private_snapshot_changed(snapshot: Dictionary)
signal command_result_received(result: Dictionary)
signal status_changed(message: String)
signal room_state_changed(state: Dictionary)
signal room_table_entered()
signal rooms_changed(rooms: Array)
signal match_started()
signal history_changed()
signal player_disconnected(player: Dictionary)

const Session := preload("res://scripts/network/lan_room_session.gd")
const Discovery := preload("res://scripts/network/lan_room_discovery.gd")

var session: Node
var discovery: Node
var match_active := false
var latest_private_snapshot: Dictionary = {}
var room_history: Array[Dictionary] = []
var last_disconnected_player: Dictionary = {}
var _settlement_ready_reset_round := -1

func _ready() -> void:
	session = Session.new()
	add_child(session)
	discovery = Discovery.new()
	add_child(discovery)
	session.match_start_received.connect(_on_match_start_received)
	session.private_snapshot_received.connect(_on_private_snapshot_received)
	session.game_command_result.connect(func(result: Dictionary): command_result_received.emit(result))
	session.status_changed.connect(func(message: String): status_changed.emit(message))
	session.player_disconnected.connect(func(player: Dictionary):
		last_disconnected_player = player.duplicate(true)
		player_disconnected.emit(last_disconnected_player.duplicate(true)))
	session.room_state_changed.connect(_on_room_state_changed)
	session.history_received.connect(func(history: Array): room_history.assign(history); history_changed.emit())
	discovery.rooms_changed.connect(func(rooms: Array): rooms_changed.emit(rooms))
	discovery.discovery_failed.connect(func(reason: String): status_changed.emit(reason))

func host_room(nickname: String) -> Error:
	last_disconnected_player.clear()
	var result: Error = session.host(nickname)
	if result != OK: return result
	room_history.clear()
	var state: Dictionary = session.current_room_state
	result = discovery.start_host(str(state.room_id), "%s的房间" % nickname, 27865, _discovery_metadata(state))
	if result != OK:
		session.reset()
	return result

func browse_rooms() -> Error:
	if session.is_host: return OK
	return discovery.start_browsing()

func stop_browsing() -> void:
	if not session.is_host: discovery.stop()

func join_room(address: String, port: int, nickname: String) -> Error:
	last_disconnected_player.clear()
	discovery.stop()
	room_history.clear()
	return session.join(address, port, nickname)

func set_ready(ready: bool) -> bool:
	return session.set_ready(ready)

func begin_match() -> bool:
	return session != null and session.start_match()

func send_game_command(command: String, arguments: Dictionary = {}) -> bool:
	return session != null and session.send_game_command(command, arguments)

func leave_room() -> void:
	last_disconnected_player.clear()
	if session != null:
		session.reset()
	match_active = false
	latest_private_snapshot.clear()
	room_history.clear()
	if discovery != null: discovery.stop()
	history_changed.emit()

func configure_game_manager(manager: Node) -> bool:
	if not match_active or session == null or manager == null:
		return false
	if session.is_host:
		return bool(manager.call("configure_session", 1, session.local_seat))
	if not bool(manager.call("configure_network_client", session.local_seat, send_game_command)):
		return false
	if not latest_private_snapshot.is_empty():
		manager.call("apply_private_snapshot", latest_private_snapshot)
	private_snapshot_changed.connect(manager.apply_private_snapshot)
	command_result_received.connect(manager.apply_network_command_result)
	return true

func _on_match_start_received(_controllers: Array) -> void:
	if session.is_host:
		var game_state := get_node_or_null("/root/GameState")
		if game_state == null:
			status_changed.emit("房主初始化牌局失败")
			return
		if match_active:
			if not bool(game_state.call("advance_to_next_round")):
				status_changed.emit("下一局启动失败")
				return
		else:
			if not bool(game_state.call("configure_seat_controllers", session.current_room_state.get("controllers", []), true)):
				status_changed.emit("房主初始化牌局失败")
				return
			if not session.activate_match_authority(game_state):
				status_changed.emit("房主权威会话启动失败")
				return
	match_active = true
	_settlement_ready_reset_round = -1
	match_started.emit()
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != "res://scenes/table/MainSceneV2.tscn":
		get_tree().call_deferred("change_scene_to_file", "res://scenes/table/MainSceneV2.tscn")

func _on_room_state_changed(state: Dictionary) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if not match_active and game_state != null:
		game_state.call("prepare_lan_table", state.get("controllers", []))
	# Publish seat readiness after the waiting-table snapshot has rendered. That
	# snapshot uses normal in-round nameplates and would otherwise immediately
	# hide the local readiness control again.
	room_state_changed.emit(state.duplicate(true))
	if not match_active:
		var current := get_tree().current_scene
		if current == null or current.scene_file_path != "res://scenes/table/MainSceneV2.tscn":
			room_table_entered.emit()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/table/MainSceneV2.tscn")
	if session.is_host and discovery != null:
		discovery.update_host_metadata(_discovery_metadata(state))

func _discovery_metadata(state: Dictionary) -> Dictionary:
	var host_name := "房主"
	for member in state.get("members", []):
		if str(member.get("player_id", "")) == str(state.get("host_player_id", "")):
			host_name = str(member.get("nickname", host_name))
	return {"room_number": str(state.get("room_number", "")), "host_name": host_name, "human_count": int(state.get("human_count", 1)), "state": "playing" if match_active else "waiting", "rule_label": "四川血战到底"}

func record_completed_round(snapshot: Dictionary) -> bool:
	if not session.is_host or int(snapshot.get("current_phase", 0)) != 7: return false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		snapshot = game_state.call("get_debug_snapshot", 0)
	var settlement: Dictionary = snapshot.get("settlement_data", {})
	if settlement.is_empty() or not bool(settlement.get("ledger_valid", true)): return false
	var round_index := int(snapshot.get("round_index", room_history.size() + 1))
	for item in room_history:
		if int(item.get("round_index", -1)) == round_index: return false
	var names := {}
	var scores := {}
	for player in snapshot.get("players", []):
		var seat := int(player.get("seat", -1))
		if seat >= 0:
			names[seat] = str(player.get("nickname", "玩家%d" % (seat + 1)))
			scores[seat] = int(player.get("score", 0))
	var record := settlement.duplicate(true)
	record["round_index"] = round_index
	record["player_names"] = names
	record["scores_after_round"] = scores
	room_history.append(record)
	if _settlement_ready_reset_round != round_index:
		_settlement_ready_reset_round = round_index
		session.reset_guest_ready_for_next_round()
	session.publish_history(room_history)
	history_changed.emit()
	return true

func _on_private_snapshot_received(snapshot: Dictionary) -> void:
	latest_private_snapshot = snapshot.duplicate(true)
	private_snapshot_changed.emit(latest_private_snapshot.duplicate(true))
