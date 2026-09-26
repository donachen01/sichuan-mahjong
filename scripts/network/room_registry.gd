extends RefCounted
class_name SichuanRoomRegistry

const SEAT_COUNT := 4
var room_id := ""
var room_number := ""
var host_player_id := ""
var members: Dictionary = {}
var peer_to_player: Dictionary = {}

func create(host_peer_id: int, nickname: String) -> Dictionary:
	clear()
	room_id = _token(12)
	room_number = "%06d" % (randi_range(0, 999999))
	var joined := join(host_peer_id, nickname)
	if joined.ok:
		host_player_id = joined.player_id
	return joined

func join(peer_id: int, nickname: String, requested_seat: int = -1) -> Dictionary:
	if peer_id <= 0 or peer_to_player.has(peer_id):
		return {"ok": false, "error": "ALREADY_JOINED"}
	var seat := requested_seat if requested_seat >= 0 else _random_free_seat()
	if seat < 0 or seat >= SEAT_COUNT or _seat_taken(seat):
		return {"ok": false, "error": "ROOM_FULL" if _first_free_seat() < 0 else "SEAT_TAKEN"}
	var clean_name := nickname.strip_edges().left(24)
	if clean_name.is_empty(): clean_name = "玩家%d" % (seat + 1)
	var player_id := _token(16)
	var member := {"player_id": player_id, "peer_id": peer_id, "seat": seat, "nickname": clean_name, "ready": false, "online": true, "controller_generation": 1}
	members[player_id] = member
	peer_to_player[peer_id] = player_id
	# Joining changes the participants of the next deal. Every human confirms
	# readiness for that exact line-up; AI seats remain implicitly ready.
	_reset_human_ready()
	return {"ok": true, "player_id": player_id, "seat": seat, "resume_token": _token(24)}

func set_ready(peer_id: int, ready: bool) -> bool:
	var player_id: String = peer_to_player.get(peer_id, "")
	if player_id.is_empty(): return false
	members[player_id].ready = ready
	return true

func leave(peer_id: int) -> void:
	var player_id: String = peer_to_player.get(peer_id, "")
	if player_id.is_empty(): return
	peer_to_player.erase(peer_id)
	members.erase(player_id)
	# A departed seat is filled by an AI. Existing humans keep their readiness.

func public_members() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in members.values():
		var public_member := Dictionary(member).duplicate(true)
		public_member.erase("peer_id")
		result.append(public_member)
	result.sort_custom(func(a, b): return int(a.seat) < int(b.seat))
	return result

func can_start(minimum_humans: int = 2) -> bool:
	if members.size() < minimum_humans or members.size() > SEAT_COUNT:
		return false
	for member in members.values():
		if not bool(member.get("online", false)):
			return false
		if not bool(member.get("ready", false)):
			return false
	return true

func reset_guest_ready() -> void:
	_reset_human_ready()

func build_seat_controllers() -> Array[Dictionary]:
	var by_seat := {}
	for member in public_members():
		by_seat[int(member.seat)] = member
	var result: Array[Dictionary] = []
	var ai_index := 0
	var chinese_numbers := ["一", "二", "三", "四"]
	for seat in range(SEAT_COUNT):
		if by_seat.has(seat):
			var member: Dictionary = by_seat[seat]
			result.append({"seat": seat, "nickname": member.nickname, "is_ai": false, "player_id": member.player_id})
		else:
			result.append({"seat": seat, "nickname": "电脑%s" % chinese_numbers[ai_index], "is_ai": true, "player_id": "", "ready": true})
			ai_index += 1
	return result

func clear() -> void:
	room_id = ""
	room_number = ""
	host_player_id = ""
	members.clear()
	peer_to_player.clear()

func _first_free_seat() -> int:
	for seat in range(SEAT_COUNT):
		if not _seat_taken(seat): return seat
	return -1

func _random_free_seat() -> int:
	var seats: Array[int] = []
	for seat in range(SEAT_COUNT):
		if not _seat_taken(seat): seats.append(seat)
	return -1 if seats.is_empty() else seats[randi_range(0, seats.size() - 1)]

func _reset_human_ready() -> void:
	for member in members.values():
		member.ready = false

func _seat_taken(seat: int) -> bool:
	for member in members.values():
		if int(member.seat) == seat: return true
	return false

func _token(byte_count: int) -> String:
	return Crypto.new().generate_random_bytes(byte_count).hex_encode()
