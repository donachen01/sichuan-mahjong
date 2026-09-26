extends Node
## ENet transport only. No game state, RPC execution or client-to-client relay.

signal connected
signal disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal packet_received(peer_id: int, packet: PackedByteArray)
signal failed(reason: String)

const MAX_PACKET_BYTES := 65536
const CONNECT_TIMEOUT_MS := 10000
const MAX_PACKETS_PER_SECOND := 60
var _api: SceneMultiplayer
var _peer: ENetMultiplayerPeer
var _connecting_at := 0
var _rates: Dictionary = {}
var is_host := false

func host(port: int) -> Error:
	if port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER
	close()
	_setup()
	is_host = true
	var result := _peer.create_server(port, 3)
	if result != OK:
		close()
		return result
	_api.multiplayer_peer = _peer
	return OK

func join(address: String, port: int) -> Error:
	if address.strip_edges().is_empty() or port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER
	close()
	_setup()
	var result := _peer.create_client(address.strip_edges(), port)
	if result != OK:
		close()
		return result
	_api.multiplayer_peer = _peer
	_connecting_at = Time.get_ticks_msec()
	return OK

func _setup() -> void:
	_peer = ENetMultiplayerPeer.new()
	_api = SceneMultiplayer.new()
	_api.root_path = get_path()
	_api.allow_object_decoding = false
	_api.server_relay = false
	_api.peer_connected.connect(func(id: int): peer_joined.emit(id))
	_api.peer_disconnected.connect(func(id: int):
		_rates.erase(id)
		peer_left.emit(id))
	_api.connected_to_server.connect(func():
		_connecting_at = 0
		connected.emit())
	_api.connection_failed.connect(func(): _fail("CONNECT_FAILED"))
	_api.server_disconnected.connect(func():
		close.call_deferred()
		disconnected.emit())
	_api.peer_packet.connect(_receive)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_delta: float) -> void:
	if _api == null:
		return
	_api.poll()
	if _connecting_at > 0 and Time.get_ticks_msec() - _connecting_at > CONNECT_TIMEOUT_MS:
		_fail("CONNECT_TIMEOUT")

func send_to(peer_id: int, packet: PackedByteArray) -> Error:
	if _api == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	# Deliberately forbid broadcast and client-to-client targets.
	if peer_id <= 0 or (not is_host and peer_id != 1) or not _api.get_peers().has(peer_id):
		return ERR_INVALID_PARAMETER
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES:
		return ERR_INVALID_DATA
	return _api.send_bytes(packet, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE)

func _receive(peer_id: int, packet: PackedByteArray) -> void:
	var second := Time.get_ticks_msec() / 1000
	var rate: Dictionary = _rates.get(peer_id, {"second": second, "count": 0})
	if rate.second != second:
		rate = {"second": second, "count": 0}
	rate.count += 1
	_rates[peer_id] = rate
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES or rate.count > MAX_PACKETS_PER_SECOND:
		drop.call_deferred(peer_id)
		return
	if not is_host and peer_id != 1:
		return
	packet_received.emit(peer_id, packet)

func drop(peer_id: int) -> void:
	if _api != null and _api.get_peers().has(peer_id):
		_api.disconnect_peer(peer_id)
		# SceneMultiplayer local disconnect does not emit peer_disconnected.
		_rates.erase(peer_id)
		peer_left.emit(peer_id)

func _fail(reason: String) -> void:
	_connecting_at = 0
	close.call_deferred()
	failed.emit(reason)

func close() -> void:
	if _peer != null:
		_peer.close()
	_api = null
	_peer = null
	_rates.clear()
	_connecting_at = 0
	is_host = false
	set_process(false)

func _exit_tree() -> void:
	close()
