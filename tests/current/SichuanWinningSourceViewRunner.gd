extends SceneTree

const Mapper := preload("res://scripts/game/seat_view_mapper.gd")
const StageScript := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := StageScript.new() as SichuanTableStage3D
	root.add_child(stage)
	await process_frame
	await process_frame
	stage.set_reduced_motion(true)

	# Authority seat 2 is this client's local seat.  A discard from authority
	# seat 1 must therefore appear as 下家(view seat 3), with one external tile.
	var discard_case := _mapped_case(2, 1, false)
	stage.render_snapshot(discard_case.snapshot, discard_case.hands, true, -1, {}, true)
	await process_frame
	assert(int(discard_case.snapshot.players[0].winning_source_seat) == 3)
	assert(_winning_tile_count(stage, 0) == 1)

	# The same winner's self draw maps both winner and source to view seat 0.
	# Its drawn tile stays in the hand and must not be appended a second time.
	var self_draw_case := _mapped_case(2, 2, true)
	stage.render_snapshot(self_draw_case.snapshot, self_draw_case.hands, true, -1, {}, true)
	await process_frame
	assert(int(self_draw_case.snapshot.players[0].winning_source_seat) == 0)
	assert(_winning_tile_count(stage, 0) == 0)

	stage.queue_free()
	await process_frame
	print("WINNING_SOURCE_VIEW_PASS")
	quit(0)


func _mapped_case(winner_authority: int, source_authority: int, self_draw: bool) -> Dictionary:
	var local_seat := winner_authority
	var players: Array = []
	var hands: Array = [[], [], [], []]
	for authority_seat in range(4):
		var hand := [_tile(authority_seat * 10 + 1), _tile(authority_seat * 10 + 2), _tile(authority_seat * 10 + 3)]
		var player := {
			"seat": authority_seat,
			"hand_tiles": hand,
			"hand_count": hand.size(),
			"melds": [],
			"discards": [],
			"has_won": authority_seat == winner_authority,
			"winning_tile": hand.back() if authority_seat == winner_authority else {},
			"winning_source_seat": source_authority if authority_seat == winner_authority else -1,
			"win_type": ("self_draw" if self_draw else "discard_win") if authority_seat == winner_authority else "",
		}
		var mapped := Mapper.map_player_for_view(player, local_seat)
		players.append(mapped)
		hands[int(mapped.seat)] = hand
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seat) < int(b.seat))
	return {
		"snapshot": {"players": players, "wall_count": 20, "current_turn_seat": 0, "human_can_discard": false},
		"hands": hands,
	}


func _winning_tile_count(stage: SichuanTableStage3D, seat: int) -> int:
	var count := 0
	for key in (stage.get("tile_nodes") as Dictionary).keys():
		if str(key).begins_with("winning_%d_" % seat):
			count += 1
	return count


func _tile(id_value: int) -> Dictionary:
	return {"id": id_value, "suit": "wan", "rank": posmod(id_value, 9) + 1}
