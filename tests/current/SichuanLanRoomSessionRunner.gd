extends SceneTree
const RoomSession := preload("res://scripts/network/lan_room_session.gd")
const Codec := preload("res://scripts/network/protocol_codec.gd")
const Projector := preload("res://scripts/network/snapshot_projector.gd")

class FakeGameState extends Node:
	signal state_changed(snapshot: Dictionary)
	var calls: Array = []
	var resolved := false
	func choose_ding_que(seat: int, suit: String) -> bool:
		calls.append([seat, suit])
		resolved = true
		state_changed.emit({})
		return true
	func get_debug_snapshot(viewer_seat: int = 0) -> Dictionary:
		var players: Array = []
		for seat in range(4):
			players.append({"seat": seat, "nickname": "p%d" % seat, "hand_tiles": [{"id": seat + 1}], "hand_count": 1, "melds": [], "has_won": resolved and not calls.is_empty() and seat == int(calls[-1][0])})
		return {"current_phase": 6, "current_dealer_seat": 0, "current_turn_seat": viewer_seat, "players": players, "human_can_discard": not resolved, "human_reaction_options": {} if resolved else {"can_hu": true, "can_pass": true}, "settlement_data": {"description": "胡牌结算说明".repeat(40)} if resolved else {}}

func _initialize() -> void:
	call_deferred("run")

func wait_until(check: Callable, timeout_ms := 4000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not check.call() and Time.get_ticks_msec() < deadline: await process_frame
	return check.call()

func _member_for_player(members: Array, player_id: String) -> Dictionary:
	for member in members:
		if str(member.get("player_id", "")) == player_id: return member
	return {}

func _human_controller_count(controllers: Array) -> int:
	var count := 0
	for controller in controllers:
		if not bool(controller.get("is_ai", true)): count += 1
	return count

func run() -> void:
	var host = RoomSession.new()
	var client = RoomSession.new()
	root.add_child(host)
	root.add_child(client)
	assert(host.host("房主", 27867) == OK)
	assert(str(host.current_room_state.room_number).length() == 6 and str(host.current_room_state.room_number).is_valid_int())
	assert(client.join("127.0.0.1", 27867, "玩家二") == OK)
	assert(await wait_until(func(): return client.local_seat >= 0 and client.current_room_state.get("members", []).size() == 2))
	assert(client.current_room_state.get("controllers", []).size() == 4)
	assert(not client.current_room_state.members[0].has("peer_id"))
	var received := {"host": [], "client": []}
	host.match_start_received.connect(func(controllers: Array): received.host = controllers)
	client.match_start_received.connect(func(controllers: Array): received.client = controllers)
	assert(client.set_ready(true))
	assert(await wait_until(func(): return bool(_member_for_player(host.current_room_state.members, client.local_player_id).get("ready", false))))
	assert(not host.can_start_match())
	assert(not bool(_member_for_player(host.current_room_state.members, host.local_player_id).get("ready", false)))
	for controller in host.current_room_state.controllers:
		if bool(controller.is_ai): assert(str(controller.nickname).begins_with("电脑") and not str(controller.nickname).contains("1"))
	assert(host.set_ready(true))
	assert(await wait_until(func(): return received.host.size() == 4 and received.client.size() == 4))
	assert(_human_controller_count(received.host) == 2)
	assert(_human_controller_count(received.client) == 2)
	host.reset_guest_ready_for_next_round()
	assert(not bool(_member_for_player(host.current_room_state.members, host.local_player_id).get("ready", true)))
	assert(not bool(_member_for_player(host.current_room_state.members, client.local_player_id).get("ready", true)))
	var state := FakeGameState.new()
	root.add_child(state)
	var private_received := {"host": {}, "client": {}, "result": {}}
	host.private_snapshot_received.connect(func(snapshot: Dictionary): private_received.host = snapshot)
	client.private_snapshot_received.connect(func(snapshot: Dictionary): private_received.client = snapshot)
	client.game_command_result.connect(func(result: Dictionary): private_received.result = result)
	var probe_snapshot: Dictionary = Projector.new().project(state.get_debug_snapshot(1), 1)
	var probe_message := {"protocol_version": 1, "kind": "private_snapshot", "snapshot": probe_snapshot}
	assert(Codec.new().validate_message(probe_message))
	assert(host.activate_match_authority(state))
	assert(await wait_until(func(): return not private_received.host.is_empty()))
	assert(await wait_until(func(): return not private_received.client.is_empty()))
	assert(private_received.host.players[0].has("hand_tiles") and not private_received.host.players[1].has("hand_tiles"))
	assert(private_received.client.players[0].has("hand_tiles") and not private_received.client.players[1].has("hand_tiles"))
	assert(client.send_game_command("ding_que", {"suit": "wan"}))
	assert(await wait_until(func(): return bool(private_received.result.get("ok", false))))
	assert(state.calls[-1] == [client.local_seat, "wan"])
	assert(await wait_until(func(): return bool(private_received.client.players[0].get("has_won", false))))
	assert(Dictionary(private_received.client.get("human_reaction_options", {})).is_empty())
	var history_holder := {"items": []}
	client.history_received.connect(func(history: Array): history_holder.items = history)
	host.publish_history([{"round_index": 1, "score_changes": {"0": 3, "1": -3}}])
	assert(await wait_until(func(): return history_holder.items.size() == 1))
	client.reset()
	assert(await wait_until(func(): return host.current_room_state.members.size() == 1))
	host.free()
	client.free()
	print("LAN_ROOM_SESSION_PASS")
	quit(0)
