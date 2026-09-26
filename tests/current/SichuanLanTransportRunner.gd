extends SceneTree
const Session := preload("res://scripts/network/lan_probe_session.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func until(condition: Callable, seconds: float = 4.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < end:
		await process_frame
	return condition.call()

func run() -> void:
	var host = Session.new()
	var client = Session.new()
	root.add_child(host)
	root.add_child(client)
	check(host.host(27866) == OK, "host binds")
	check(client.join("127.0.0.1", 27866) == OK, "client starts")
	check(await until(func(): return client.accepted.size() == 1 and host.accepted.size() == 1), "protocol handshake")
	var pongs: Array = []
	host.pong_received.connect(func(id, seq): pongs.append([id, seq]))
	client.pong_received.connect(func(id, seq): pongs.append([id, seq]))
	host.ping()
	client.ping()
	check(await until(func(): return pongs.size() == 2), "bidirectional reliable messages")
	check(client.transport.send_to(0, "x".to_utf8_buffer()) == ERR_INVALID_PARAMETER, "broadcast forbidden")
	check(client.transport.send_to(2, "x".to_utf8_buffer()) == ERR_INVALID_PARAMETER, "other-client target forbidden")
	var oversized := PackedByteArray()
	oversized.resize(65537)
	check(client.transport.send_to(1, oversized) == ERR_INVALID_DATA, "oversized packet rejected")
	client.reset()
	check(await until(func(): return host.accepted.is_empty()), "disconnect observed")
	check(client.join("127.0.0.1", 27866) == OK, "rejoin starts")
	check(await until(func(): return client.accepted.size() == 1 and host.accepted.size() == 1), "rejoin handshake")
	client.transport.send_to(1, '{"protocol":"wrong","kind":"hello","sequence":0}'.to_utf8_buffer())
	check(await until(func(): return host.accepted.is_empty()), "incompatible protocol disconnects")
	host.reset()
	client.reset()
	check(client.host(27866) == OK, "role swap host binds")
	check(host.join("127.0.0.1", 27866) == OK, "role swap joins")
	check(await until(func(): return client.accepted.size() == 1 and host.accepted.size() == 1), "role swap handshake")
	host.free()
	client.free()
	print("LAN_TRANSPORT_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
