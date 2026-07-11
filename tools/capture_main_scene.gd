extends SceneTree

const DEFAULT_OUTPUT_PATH := "user://capture_main_scene.png"
const SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"
const AUTO_DING_QUE_SUIT := "tong"
const MAX_AI_STEPS := 24
const DEMO_DISCARDS := {
	0: [["tiao", 1], ["tiao", 3], ["tiao", 5], ["tong", 2], ["tong", 4], ["tong", 6], ["wan", 2], ["wan", 4], ["wan", 6], ["wan", 8]],
	1: [["wan", 1], ["wan", 2], ["wan", 3], ["tong", 5], ["tong", 6], ["tong", 7], ["tiao", 6], ["tiao", 7]],
	2: [["tong", 1], ["tong", 2], ["tong", 3], ["wan", 4], ["wan", 5], ["wan", 6], ["tiao", 7], ["tiao", 8], ["tiao", 9]],
	3: [["tiao", 2], ["tiao", 4], ["tiao", 6], ["tong", 7], ["tong", 8], ["tong", 9], ["wan", 7], ["wan", 9]],
}


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output_path := _capture_output_path()
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Failed to load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)

	await process_frame
	_force_playable_snapshot()
	_force_discard_demo()
	_log_self_hand_debug(root_node)

	await process_frame
	await process_frame
	_force_tabletop_polish_preview(root_node)
	_force_self_hand_preview(root_node)
	_force_self_hu_preview(root_node)
	_force_ai_helper_preview(root_node)

	var image: Image = get_root().get_texture().get_image()
	if image == null:
		push_error("Failed to capture viewport image")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(output_path)
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save capture: %s" % path)
		quit(1)
		return

	print(path)
	quit()


func _capture_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			var value := argument.trim_prefix("--capture-output=")
			if value != "":
				return value
	return DEFAULT_OUTPUT_PATH


func _force_playable_snapshot() -> void:
	var game_state: Node = get_root().get_node_or_null("GameState")
	if game_state == null:
		return

	var players: Array = game_state.get("players")
	if players.is_empty():
		return

	for index in range(players.size()):
		var player: Dictionary = players[index]
		if str(player.get("ding_que", "")) == "":
			if index == 0:
				player["ding_que"] = AUTO_DING_QUE_SUIT
			else:
				player["ding_que"] = str(game_state.call("_choose_ai_ding_que", player.get("hand_tiles", [])))
			players[index] = player
	game_state.set("players", players)
	if bool(game_state.get("opening_roll_pending_completion")):
		game_state.call("complete_opening_roll")
	else:
		game_state.call("_complete_ding_que_if_ready")

	var step_count := 0
	while step_count < MAX_AI_STEPS and not bool(game_state.call("can_human_discard", 0)):
		if bool(game_state.call("is_ai_reaction_pending")):
			game_state.call("run_ai_reaction")
		elif bool(game_state.call("is_ai_turn_ready")):
			game_state.call("run_ai_turn")
		else:
			break
		step_count += 1
		await process_frame


func _log_self_hand_debug(root_node: Node) -> void:
	var hand_host := root_node.get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/SelfSection/SelfSectionMargin/SelfSectionVBox/SelfHandHost")
	if hand_host is Control:
		var control := hand_host as Control
		print("SelfHandHost size=", control.size, " position=", control.global_position)


func _force_discard_demo() -> void:
	var game_state: Node = get_root().get_node_or_null("GameState")
	if game_state == null:
		return

	var players: Array = game_state.get("players")
	var wall: Array = game_state.get("wall")
	var discard_pile: Array = []

	for seat in range(players.size()):
		var player: Dictionary = players[seat]
		player["discards"] = []
		var requests: Array = DEMO_DISCARDS.get(seat, [])
		for request in requests:
			var tile := _take_tile_from_wall(wall, str(request[0]), int(request[1]))
			if tile.is_empty():
				continue
			player["discards"].append(tile)
			discard_pile.append(
				{
					"seat": seat,
					"tile": tile,
				}
			)
		players[seat] = player

	game_state.set("players", players)
	game_state.set("wall", wall)
	game_state.set("discard_pile", discard_pile)
	game_state.set("wall_count", wall.size())
	game_state.call("_emit_state_changed")


func _force_ai_helper_preview(root_node: Node) -> void:
	if root_node == null:
		return
	root_node.set("ai_helper_enabled", true)
	root_node.call("_update_discard_helper_panel", {
		"players": [
			{
				"seat": 0,
				"nickname": "本家",
				"score": 0,
				"hand_tiles": [
					{"id": 9001, "suit": "tiao", "rank": 1},
					{"id": 9002, "suit": "tiao", "rank": 2},
					{"id": 9003, "suit": "tiao", "rank": 3},
					{"id": 9004, "suit": "tong", "rank": 5},
					{"id": 9005, "suit": "wan", "rank": 7},
					{"id": 9006, "suit": "wan", "rank": 8},
				],
			},
		],
	}, {
		"recommended": {
			"tile": {"id": 9009, "suit": "tiao", "rank": 9},
			"tile_name": "9条",
			"shanten": 1,
			"ukeire": 8,
			"win_probability": 0.24,
			"risk_label": "低危",
			"score": 120,
			"explanation_hint": "边九孤张，先拆掉",
		},
		"recommended_tile_id": 9009,
		"options": [],
		"strategy_profile": {"mode_label": "快攻"},
		"situation_label": "缺门",
	}, true)


func _force_self_hand_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var self_hand_host: Node = root_node.get("self_hand_host") as Node
	if self_hand_host == null:
		return
	self_hand_host.call(
		"configure_hand",
		[
			{"id": 9001, "suit": "tiao", "rank": 1},
			{"id": 9002, "suit": "tiao", "rank": 2},
			{"id": 9003, "suit": "tiao", "rank": 3},
			{"id": 9004, "suit": "tong", "rank": 5},
			{"id": 9005, "suit": "wan", "rank": 7},
			{"id": 9006, "suit": "wan", "rank": 8},
		],
		-1,
		-1,
		false,
		{"recommended_tile_id": 9002},
		{}
	)


func _force_self_hu_preview(root_node: Node) -> void:
	if root_node == null:
		return
	root_node.call(
		"_update_self_area",
		{
			"players": [
				{
					"seat": 0,
					"nickname": "本家",
					"score": 0,
					"hand_tiles": [
						{"id": 9101, "suit": "tiao", "rank": 1},
						{"id": 9102, "suit": "tiao", "rank": 2},
						{"id": 9103, "suit": "tiao", "rank": 3},
						{"id": 9104, "suit": "tong", "rank": 5},
						{"id": 9105, "suit": "wan", "rank": 7},
						{"id": 9106, "suit": "wan", "rank": 8},
					],
					"hand_count": 6,
					"melds": [],
					"discards": [],
					"ding_que": "tong",
					"has_won": true,
					"win_type": "discard_win",
					"winning_tile": {"id": 9199, "suit": "tong", "rank": 8},
					"winning_source_seat": 1,
				},
			],
			"rules": {"use_ding_que_phase": true},
			"human_can_discard": false,
			"human_last_draw_tile_id": -1,
		},
		[
			{"id": 9101, "suit": "tiao", "rank": 1},
			{"id": 9102, "suit": "tiao", "rank": 2},
			{"id": 9103, "suit": "tiao", "rank": 3},
			{"id": 9104, "suit": "tong", "rank": 5},
			{"id": 9105, "suit": "wan", "rank": 7},
			{"id": 9106, "suit": "wan", "rank": 8},
		]
	)


func _force_tabletop_polish_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var players := [
		{
			"seat": 0,
			"nickname": "本家",
			"score": 3,
			"hand_count": 10,
			"hand_tiles": [
				{"id": 9301, "suit": "tiao", "rank": 1},
				{"id": 9302, "suit": "tiao", "rank": 2},
				{"id": 9303, "suit": "tiao", "rank": 3},
				{"id": 9304, "suit": "tong", "rank": 5},
				{"id": 9305, "suit": "tong", "rank": 6},
				{"id": 9306, "suit": "wan", "rank": 7},
			],
			"melds": [
				{"type": "peng", "tile": {"id": 9311, "suit": "tong", "rank": 2}, "tiles": [
					{"id": 9311, "suit": "tong", "rank": 2},
					{"id": 9312, "suit": "tong", "rank": 2},
					{"id": 9313, "suit": "tong", "rank": 2},
				], "from_seat": 1},
			],
			"discards": [],
			"ding_que": "tong",
			"has_won": true,
			"win_type": "discard_win",
			"winning_tile": {"id": 9399, "suit": "tong", "rank": 8},
			"winning_source_seat": 1,
		},
		{
			"seat": 1,
			"nickname": "舒小燕",
			"score": -5,
			"hand_count": 8,
			"hand_tiles": [],
			"melds": [
				{"type": "gang", "tile": {"id": 9411, "suit": "tong", "rank": 3}, "tiles": [
					{"id": 9411, "suit": "tong", "rank": 3},
					{"id": 9412, "suit": "tong", "rank": 3},
					{"id": 9413, "suit": "tong", "rank": 3},
					{"id": 9414, "suit": "tong", "rank": 3},
				], "from_seat": 0},
			],
			"discards": [],
			"ding_que": "wan",
			"has_won": false,
		},
		{
			"seat": 2,
			"nickname": "陈东",
			"score": 6,
			"hand_count": 9,
			"hand_tiles": [],
			"melds": [
				{"type": "peng", "tile": {"id": 9511, "suit": "tiao", "rank": 6}, "tiles": [
					{"id": 9511, "suit": "tiao", "rank": 6},
					{"id": 9512, "suit": "tiao", "rank": 6},
					{"id": 9513, "suit": "tiao", "rank": 6},
				], "from_seat": 3},
			],
			"discards": [],
			"ding_que": "tong",
			"has_won": false,
		},
		{
			"seat": 3,
			"nickname": "舒玲",
			"score": 2,
			"hand_count": 8,
			"hand_tiles": [],
			"melds": [
				{"type": "peng", "tile": {"id": 9611, "suit": "wan", "rank": 5}, "tiles": [
					{"id": 9611, "suit": "wan", "rank": 5},
					{"id": 9612, "suit": "wan", "rank": 5},
					{"id": 9613, "suit": "wan", "rank": 5},
				], "from_seat": 2},
			],
			"discards": [],
			"ding_que": "wan",
			"has_won": false,
		},
	]
	var snapshot := {
		"players": players,
		"current_turn_seat": 0,
		"current_dealer_seat": 0,
		"rules": {"use_ding_que_phase": true},
		"human_can_discard": true,
		"human_last_draw_tile_id": -1,
	}
	if root_node.get("self_ui") != null:
		root_node.get("self_ui").apply_snapshot(players[0], false, 0, 0, true)
	if root_node.get("left_ui") != null:
		root_node.get("left_ui").apply_snapshot(players[1], true, 0, 0, true)
	if root_node.get("top_ui") != null:
		root_node.get("top_ui").apply_snapshot(players[2], true, 0, 0, true)
	if root_node.get("right_ui") != null:
		root_node.get("right_ui").apply_snapshot(players[3], true, 0, 0, true)
	root_node.call("_update_v17_player_info_panels", snapshot)
	root_node.call("_update_self_area", snapshot, players[0]["hand_tiles"])


func _take_tile_from_wall(wall: Array, suit: String, rank: int) -> Dictionary:
	for index in range(wall.size()):
		var tile: Dictionary = wall[index]
		if str(tile.get("suit", "")) == suit and int(tile.get("rank", 0)) == rank:
			wall.remove_at(index)
			return tile
	return {}
