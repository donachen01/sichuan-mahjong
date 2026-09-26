extends SceneTree

const RoomSession := preload("res://scripts/network/lan_room_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _wait_until(check: Callable, timeout_ms := 5000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not check.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check.call()


func _run() -> void:
	var host = RoomSession.new()
	var leaving = RoomSession.new()
	var remaining = RoomSession.new()
	root.add_child(host)
	root.add_child(leaving)
	root.add_child(remaining)
	assert(host.host("房主", 27869) == OK)
	assert(leaving.join("127.0.0.1", 27869, "离开的玩家") == OK)
	assert(remaining.join("127.0.0.1", 27869, "留下的玩家") == OK)
	assert(await _wait_until(func(): return remaining.current_room_state.get("members", []).size() == 3))
	var received := {"host": {}, "remaining": {}, "host_lost": {}}
	host.player_disconnected.connect(func(player: Dictionary): received.host = player)
	remaining.player_disconnected.connect(func(player: Dictionary):
		if bool(player.get("is_host", false)):
			received.host_lost = player
		else:
			received.remaining = player)
	leaving.reset()
	assert(await _wait_until(func(): return not received.host.is_empty() and not received.remaining.is_empty()))
	assert(str(received.host.get("nickname", "")) == "离开的玩家")
	assert(str(received.remaining.get("nickname", "")) == "离开的玩家")
	assert(int(received.remaining.get("seat", -1)) >= 0)
	assert(await _wait_until(func(): return remaining.current_room_state.get("members", []).size() == 2))
	host.reset()
	assert(await _wait_until(func(): return not received.host_lost.is_empty()))
	assert(str(received.host_lost.get("nickname", "")) == "房主")
	assert(remaining.current_room_state.is_empty())
	remaining.reset()
	host.free()
	leaving.free()
	remaining.free()
	print("SICHUAN_LAN_DISCONNECT_PASS")
	quit(0)
