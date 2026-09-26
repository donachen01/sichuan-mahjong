extends RefCounted
class_name SessionAdapter

const Mapper := preload("res://scripts/game/seat_view_mapper.gd")

enum Role { LOCAL, HOST, CLIENT }

var role := Role.LOCAL
var local_seat := 0

func configure(next_role: Role, next_local_seat: int) -> bool:
	if next_local_seat < 0 or next_local_seat >= Mapper.SEAT_COUNT:
		return false
	role = next_role
	local_seat = next_local_seat
	return true

func is_authority() -> bool:
	return role != Role.CLIENT

func may_call_game_state_directly() -> bool:
	return role == Role.LOCAL or role == Role.HOST

func authority_to_view(seat: int) -> int:
	return Mapper.authority_to_view(seat, local_seat)

func view_to_authority(seat: int) -> int:
	return Mapper.view_to_authority(seat, local_seat)
