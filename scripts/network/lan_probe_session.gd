extends Node
## M1 diagnostic protocol, intentionally separate from future game protocol.
signal status_changed(message: String)
signal pong_received(peer_id: int, sequence: int)

const Transport := preload("res://scripts/network/lan_transport.gd")
const PROTOCOL := "scmj-lan-probe-1"
const HANDSHAKE_MS := 10000
var transport: Node
var accepted: Dictionary = {}
var _pending: Dictionary = {}
var _sequence := 0
var _outstanding: Dictionary = {}
var _host := false

func _ready() -> void:
	transport = Transport.new()
	add_child(transport)
	transport.connected.connect(_connected)
	transport.peer_joined.connect(_joined)
	transport.peer_left.connect(_left)
	transport.disconnected.connect(func():
		accepted.clear()
		status_changed.emit("房主连接中断；请重新加入"))
	transport.failed.connect(func(reason: String): status_changed.emit(reason))
	transport.packet_received.connect(_receive)
	process_mode = Node.PROCESS_MODE_ALWAYS

func host(port: int = 27865) -> Error:
	reset()
	_host = true
	var result: Error = transport.host(port)
	status_changed.emit("正在监听 UDP %d（连接测试，不是麻将房间）" % port if result == OK else "监听失败：%s" % error_string(result))
	return result

func join(address: String, port: int = 27865) -> Error:
	reset()
	var result: Error = transport.join(address, port)
	status_changed.emit("正在连接…" if result == OK else "连接参数错误：%s" % error_string(result))
	return result

func reset() -> void:
	transport.close()
	accepted.clear()
	_pending.clear()
	_outstanding.clear()
	_sequence = 0
	_host = false

func _connected() -> void:
	_pending[1] = Time.get_ticks_msec()
	_send(1, "hello", 0)

func _joined(peer_id: int) -> void:
	if _host:
		_pending[peer_id] = Time.get_ticks_msec()

func _left(peer_id: int) -> void:
	accepted.erase(peer_id)
	_pending.erase(peer_id)
	_outstanding.erase(peer_id)
	status_changed.emit("连接 %d 已断开" % peer_id)

func _process(_delta: float) -> void:
	for peer_id in _pending.keys():
		if Time.get_ticks_msec() - int(_pending[peer_id]) > HANDSHAKE_MS:
			_pending.erase(peer_id)
			transport.drop(peer_id)
			status_changed.emit("握手超时，请检查版本、局域网权限及 Wi-Fi 隔离")

func ping() -> void:
	_sequence += 1
	for peer_id in accepted:
		# Only the most recent probe is outstanding; memory remains bounded.
		_outstanding[peer_id] = _sequence
		_send(peer_id, "ping", _sequence)

func _send(peer_id: int, kind: String, sequence: int) -> void:
	var result: Error = transport.send_to(peer_id, JSON.stringify({"protocol": PROTOCOL, "kind": kind, "sequence": sequence}).to_utf8_buffer())
	if result != OK:
		status_changed.emit("发送失败：%s" % error_string(result))

func _receive(peer_id: int, bytes: PackedByteArray) -> void:
	if bytes.size() > 512:
		transport.drop.call_deferred(peer_id)
		return
	var data = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary or data.size() != 3 or data.get("protocol") != PROTOCOL:
		status_changed.emit("协议不匹配或消息无效")
		transport.drop.call_deferred(peer_id)
		return
	var kind = data.get("kind")
	var sequence = data.get("sequence")
	if not kind is String or not (sequence is float or sequence is int) or sequence < 0 or sequence > 1000000000 or sequence != floor(sequence):
		transport.drop.call_deferred(peer_id)
		return
	if kind == "hello" and _host and _pending.has(peer_id):
		_pending.erase(peer_id)
		accepted[peer_id] = true
		_send(peer_id, "welcome", 0)
		status_changed.emit("连接 %d 协议握手成功" % peer_id)
	elif kind == "welcome" and not _host and peer_id == 1 and _pending.has(1):
		_pending.erase(1)
		accepted[1] = true
		status_changed.emit("已连接房主，协议握手成功")
	elif kind == "ping" and accepted.has(peer_id):
		_send(peer_id, "pong", int(sequence))
		status_changed.emit("收到连接 %d 的测试消息 #%d" % [peer_id, sequence])
	elif kind == "pong" and accepted.has(peer_id) and _outstanding.get(peer_id, -1) == int(sequence):
		_outstanding.erase(peer_id)
		pong_received.emit(peer_id, int(sequence))
		status_changed.emit("连接 %d 双向消息成功 #%d" % [peer_id, sequence])
	else:
		transport.drop.call_deferred(peer_id)
