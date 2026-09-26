extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var stage = load("res://scripts/ui/3d/SichuanTableStage3D.gd").new()
	root.add_child(stage)
	for seat in range(4):
		for count in [3, 4]:
			assert(stage._claim_tile_index_for_meld(count, seat, (seat + 1) % 4) == (count - 1 if seat == 3 else 0))
			assert(stage._claim_tile_index_for_meld(count, seat, (seat + 3) % 4) == (0 if seat == 3 else count - 1))
	var state = root.get_node("GameState")
	var tiles: Array = []
	for i in range(4):
		tiles.append({"id": 90000 + i, "suit": "tiao", "rank": 1})
	state.players.clear()
	state.players.append({"melds": [{"type": "peng", "from_seat": 1, "tiles": tiles.slice(0, 3)}]})
	assert(state._upgrade_peng_to_gang(0, 0, tiles[3]))
	var meld = state.players[0].melds[0]
	assert(meld.gang_subtype == "add_gang")
	var desired := {}
	stage._append_meld_entries(desired, 0, [meld])
	var entries = desired.values()
	assert(entries.size() == 4)
	assert(entries[0].transform.basis.is_equal_approx(entries[3].transform.basis))
	assert(is_equal_approx(entries[1].transform.origin.x, entries[3].transform.origin.x))
	assert(entries[3].transform.origin.y > entries[1].transform.origin.y)
	assert(stage._meld_layout_slot_count([meld]) == 3)
	var hand: Array = []
	for kind in [["tiao",1],["tiao",2],["tiao",3],["tiao",4],["tiao",5],["tiao",6],["tong",1],["tong",2],["tong",3],["tong",9],["tong",9]]:
		hand.append({"suit": kind[0], "rank": kind[1]})
	var fan = load("res://scripts/core/fan_resolver.gd").new().resolve_win_fans({"hand_tiles": hand, "melds": [{"type":"peng", "tiles":tiles.slice(0,3)}]}, {}, "self_draw", null)
	assert(fan.gen_count == 1 and fan.capped_fan == 1 and fan.per_payer_score == 3)
	stage.free()
	print("SICHUAN_MELD_ROOT_FIX_PASS")
	quit()
