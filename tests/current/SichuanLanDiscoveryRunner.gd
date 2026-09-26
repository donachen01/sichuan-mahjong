extends SceneTree
const Discovery := preload("res://scripts/network/lan_room_discovery.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host = Discovery.new()
	var browser = Discovery.new()
	root.add_child(host)
	root.add_child(browser)
	assert(host.start_host("room-test", "测试房间", 27865) == OK)
	var updates: Array = []
	browser.rooms_changed.connect(func(rooms):
		updates.clear()
		updates.append_array(rooms))
	assert(browser.start_browsing(["127.0.0.1"]) == OK)
	var deadline := Time.get_ticks_msec() + 3000
	while updates.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(updates.size() == 1)
	assert(updates[0].room_id == "room-test")
	assert(updates[0].name == "测试房间")
	assert(updates[0].address == "127.0.0.1")
	assert(updates[0].port == 27865)
	host.free()
	browser.free()
	print("LAN_DISCOVERY_PASS")
	quit(0)
