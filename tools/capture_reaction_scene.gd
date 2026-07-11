extends SceneTree

const OUTPUT_PATH := "user://capture_reaction_scene.png"
const SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root_node = scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame

	_force_reaction_snapshot(root_node)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_root().get_texture().get_image()
	if image == null:
		push_error("Failed to capture viewport image")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save capture: %s" % path)
		quit(1)
		return

	print(path)
	quit()


func _force_reaction_snapshot(root_node: Node) -> void:
	var game_state: Node = get_root().get_node_or_null("GameState")
	if game_state == null:
		return

	var players: Array = [
		_make_player(
			0,
			"tong",
			[
				_tile(1, "wan", 2), _tile(2, "wan", 2),
				_tile(3, "wan", 3), _tile(4, "wan", 4), _tile(5, "wan", 5),
				_tile(6, "tiao", 3), _tile(7, "tiao", 4), _tile(8, "tiao", 5),
				_tile(9, "tiao", 6), _tile(10, "tong", 1), _tile(11, "tong", 3),
				_tile(12, "tong", 5), _tile(13, "tong", 7),
			]
		),
		_make_player(
			1,
			"wan",
			[_tile(100, "tiao", 1), _tile(101, "tiao", 2), _tile(102, "tiao", 3)],
			[_tile(199, "wan", 2)]
		),
		_make_player(
			2,
			"tiao",
			[_tile(200, "tong", 1), _tile(201, "tong", 2), _tile(202, "tong", 3)]
		),
		_make_player(
			3,
			"tong",
			[_tile(300, "wan", 7), _tile(301, "wan", 8), _tile(302, "wan", 9)]
		),
	]

	game_state.set("players", players)
	game_state.set("current_dealer_seat", 1)
	game_state.set("current_turn_seat", 0)
	game_state.set("wall_count", 31)
	game_state.set("last_draw_tile", {})
	game_state.set("current_phase", 6)
	game_state.set("discard_pile", [
		{
			"seat": 1,
			"tile": _tile(199, "wan", 2),
		},
	])
	game_state.set("current_discard_context", {
		"source_seat": 1,
		"tile": _tile(199, "wan", 2),
		"allow_chi": false,
	})
	game_state.set("pending_reactions", [
		{
			"seat": 0,
			"can_peng": true,
			"can_gang": false,
			"can_hu": false,
		},
	])
	root_node._on_snapshot_changed(game_state.get_debug_snapshot())


func _make_player(seat: int, ding_que: String, hand_tiles: Array, discards: Array = []) -> Dictionary:
	return {
		"seat": seat,
		"nickname": "Player" if seat == 0 else ("上家" if seat == 1 else ("对家" if seat == 2 else "下家")),
		"score": 1000,
		"hand_tiles": hand_tiles.duplicate(true),
		"hand_count": hand_tiles.size(),
		"ding_que": ding_que,
		"melds": [],
		"discards": discards.duplicate(true),
		"is_ai": seat != 0,
		"ai_level": 1,
		"has_won": false,
		"winning_tile": {},
		"winning_source_seat": seat,
		"win_type": "",
	}


func _tile(id_value: int, suit: String, rank: int) -> Dictionary:
	var sort_key := ["tiao", "tong", "wan"].find(suit) * 100 + rank
	return {
		"id": id_value,
		"suit": suit,
		"rank": rank,
		"sort_key": sort_key,
		"display_name": "%d%s" % [rank, _suit_name(suit)],
	}


func _suit_name(suit: String) -> String:
	match suit:
		"wan":
			return "万"
		"tong":
			return "筒"
		"tiao":
			return "条"
		_:
			return "?"
