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
	_force_3d_full_table_preview(root_node)
	_force_self_hand_preview(root_node)
	_force_table_overlays_hidden(root_node)
	if _capture_mode() == "settlement":
		_force_settlement_preview(root_node)
	elif _capture_mode() == "ding-que":
		_force_ding_que_preview(root_node)
	elif _capture_mode() in ["won", "self-draw", "ai-discard-win", "max-meld", "right-meld", "discard-pressure"]:
		_force_clean_table_preview(root_node)
	elif _capture_mode() in ["response-hu", "self-hu"]:
		_force_clean_table_preview(root_node)
		_force_action_bar_preview(root_node)
	elif _capture_mode() == "utility-expanded":
		_force_clean_table_preview(root_node)
		_force_utility_expanded_preview(root_node)
	elif _capture_mode() in ["clean", "camera"]:
		_force_clean_table_preview(root_node)
		if _capture_mode() == "clean":
			_force_action_bar_preview(root_node)
	else:
		_force_ai_helper_preview(root_node)
		_force_action_bar_preview(root_node)

	# Metal can expose a partially initialized frame on the first viewport read.
	# Warm the complete UI tree before collecting the evidence image.
	for _frame in range(12):
		await process_frame
	if _capture_mode() == "settlement":
		_force_settlement_preview(root_node)
		for _frame in range(4):
			await process_frame
	elif _capture_mode() == "ding-que":
		_force_ding_que_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["clean", "camera"]:
		_force_clean_table_preview(root_node)
		if _capture_mode() == "clean":
			_force_action_bar_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["won", "self-draw", "ai-discard-win", "max-meld", "right-meld", "discard-pressure"]:
		_force_clean_table_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() in ["response-hu", "self-hu"]:
		_force_clean_table_preview(root_node)
		_force_action_bar_preview(root_node)
		for _frame in range(2):
			await process_frame
	elif _capture_mode() == "utility-expanded":
		_force_clean_table_preview(root_node)
		_force_utility_expanded_preview(root_node)
		for _frame in range(2):
			await process_frame
	else:
		_force_ai_helper_preview(root_node)
		_force_action_bar_preview(root_node)
		for _frame in range(2):
			await process_frame
	_force_3d_full_table_preview(root_node)
	if _capture_mode() == "camera":
		_force_clean_table_preview(root_node)
	RenderingServer.force_draw()
	await process_frame
	if _capture_mode() == "perf":
		await _profile_real_metal_frame_pacing(root_node)
		quit()
		return

	var image: Image = await _capture_stable_image()
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


func _profile_real_metal_frame_pacing(root_node: Node) -> void:
	# Measure the same dense 3D scene used by the screenshot runner in a real
	# window/Metal process.  Frame deltas include presentation pacing, so a 60 Hz
	# VSync build should settle close to 60 rather than reporting an artificial
	# uncapped headless number.
	for _warm_frame in range(60):
		await process_frame
	var frame_times_ms: Array[float] = []
	var previous_usec := Time.get_ticks_usec()
	for _sample in range(600):
		await process_frame
		var current_usec := Time.get_ticks_usec()
		frame_times_ms.append(float(current_usec - previous_usec) / 1000.0)
		previous_usec = current_usec
	frame_times_ms.sort()
	var total_ms := 0.0
	for frame_ms in frame_times_ms:
		total_ms += frame_ms
	var slow_count := maxi(1, int(ceil(float(frame_times_ms.size()) * 0.01)))
	var slow_total_ms := 0.0
	for index in range(frame_times_ms.size() - slow_count, frame_times_ms.size()):
		slow_total_ms += frame_times_ms[index]
	var average_frame_ms := total_ms / float(maxi(1, frame_times_ms.size()))
	var one_percent_frame_ms := slow_total_ms / float(slow_count)
	var profile := {
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"viewport": [get_root().size.x, get_root().size.y],
		"frames": frame_times_ms.size(),
		"average_fps": 1000.0 / maxf(0.001, average_frame_ms),
		"one_percent_low_fps": 1000.0 / maxf(0.001, one_percent_frame_ms),
		"median_frame_ms": frame_times_ms[frame_times_ms.size() / 2],
		"p99_frame_ms": frame_times_ms[frame_times_ms.size() - slow_count],
		"maximum_frame_ms": frame_times_ms.back(),
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"static_memory_peak_mb": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0,
		"table_stage_present": root_node.get("table_stage_3d") != null,
		"passed": 1000.0 / maxf(0.001, average_frame_ms) >= 55.0 \
			and 1000.0 / maxf(0.001, one_percent_frame_ms) >= 45.0 \
			and Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0 <= 1200.0,
	}
	var output_path := _profile_output_path()
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write performance profile: %s" % absolute_path)
		return
	file.store_string(JSON.stringify(profile, "  ") + "\n")
	file.close()
	print(JSON.stringify(profile))
	print(absolute_path)


func _profile_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-output="):
			var value := argument.trim_prefix("--profile-output=")
			if not value.is_empty():
				return value
	return "user://sichuan_stage7_performance.json"


func _capture_stable_image() -> Image:
	var fallback: Image
	for attempt in range(8):
		for _frame in range(8):
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		fallback = get_root().get_texture().get_image()
		var black_ratio := _sample_near_black_ratio(fallback)
		if black_ratio <= 0.025:
			return fallback
		print("capture_retry=", attempt + 1, " sampled_black_ratio=", black_ratio)
	return fallback


func _sample_near_black_ratio(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var sample_step := 24
	var black_count := 0
	var sample_count := 0
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			var pixel := image.get_pixel(x, y)
			sample_count += 1
			if pixel.a >= 0.9 and pixel.r <= 0.03 and pixel.g <= 0.03 and pixel.b <= 0.03:
				black_count += 1
	return float(black_count) / float(maxi(1, sample_count))


func _capture_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			var value := argument.trim_prefix("--capture-output=")
			if value != "":
				return value
	return DEFAULT_OUTPUT_PATH


func _capture_mode() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-mode="):
			return argument.trim_prefix("--capture-mode=")
	return "table"


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
			players[index] = player
	game_state.set("players", players)
	game_state.call("_auto_select_ai_ding_que")
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
		while player["discards"].size() < 14 and not wall.is_empty():
			var pressure_tile: Dictionary = wall.pop_back()
			player["discards"].append(pressure_tile)
			discard_pile.append({"seat": seat, "tile": pressure_tile})
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
	var drawer: Control = root_node.get("ai_assistant_drawer") as Control
	if drawer != null:
		# Evidence capture must not inherit a developer-machine drag preference;
		# use the product's deterministic default position for every resolution.
		root_node.set("ai_drawer_positioned", false)
		drawer.call("restore_user_position", Vector2(0.5, 0.5), false)
		# Capture the shipped default (70%).  The 50% setting remains covered by
		# the interaction contract, but it is not the product's first impression.
		drawer.call("set_glass_opacity", 0.70)
		drawer.call("set_expanded", _capture_mode() == "ai-expanded")
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
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar != null:
		utility_bar.call("render", true, false, false, "骨灰", false)
	root_node.call_deferred("_layout_ai_assistant_drawer")


func _force_clean_table_preview(root_node: Node) -> void:
	# Presentation capture only: keep the real AI drawer implementation intact,
	# but remove it from the beauty shot so the table/tiles hierarchy is visible.
	if root_node == null:
		return
	var drawer: Control = root_node.get("ai_assistant_drawer") as Control
	if drawer != null:
		drawer.visible = false
	var helper_panel: Control = root_node.get("discard_helper_panel") as Control
	if helper_panel != null:
		helper_panel.visible = false
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar != null:
		utility_bar.call("render", false, false, false)


func _force_settlement_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var manager: Node = root_node.get("game_manager") as Node
	if manager == null:
		return
	var snapshot: Dictionary = manager.call("get_snapshot").duplicate(true)
	var players: Array = snapshot.get("players", [])
	if players.size() < 4:
		return
	for index in range(players.size()):
		var player: Dictionary = players[index]
		player["nickname"] = ["陈旭", "舒小燕", "陈东", "舒玲"][index]
		player["score"] = [18, -4, -8, -6][index]
		player["has_won"] = index == 0
		players[index] = player
	var winning_tile: Dictionary = players[0].get("hand_tiles", [{}]).back() if not players[0].get("hand_tiles", []).is_empty() else {"id": 9999, "suit": "wan", "rank": 9}
	snapshot["current_phase"] = 7
	snapshot["current_dealer_seat"] = 1
	snapshot["players"] = players
	snapshot["settlement_data"] = {
		"round_index": 3,
		"dealer_seat": 1,
		"end_reason": "battle_end",
		"winner_seats": [0],
		"score_changes": {0: 18, 1: -4, 2: -8, 3: -6},
		"win_events": [{
			"winner_seat": 0,
			"source_seat": 2,
			"payer_seats": [2],
			"win_type": "discard_win",
			"winning_tile": winning_tile,
			"fan_detail": {"capped_fan": 3, "hand_score": 8, "labels": ["清一色", "平胡"]},
		}],
		"gang_events": [{"actor_seat": 0, "gang_type": "melded_gang", "payer_seats": [1, 2, 3]}],
		"tui_gang_refunds": [{"actor_seat": 0, "gang_type": "melded_gang", "payer_seats": [1, 2, 3]}],
		"transfer_events": [{"transfer_type": "hu_jiao_zhuan_yi", "to_seat": 0, "gang_type": "melded_gang", "payer_seats": [2]}],
	}
	root_node.set("last_snapshot", {"current_phase": 6})
	root_node.call("_refresh_settlement", snapshot)


func _force_self_hand_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var self_hand_host: Node = root_node.get("self_hand_host") as Node
	if self_hand_host == null:
		return
	var preview_tiles: Array = []
	for index in range(11):
		preview_tiles.append({
			"id": 9001 + index,
			"suit": ["tiao", "tong", "wan"][index % 3],
			"rank": index % 9 + 1,
		})
	self_hand_host.call(
		"configure_hand",
		preview_tiles,
		-1,
		9011,
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


func _force_table_overlays_hidden(root_node: Node) -> void:
	for property_name in ["settlement_overlay_v2", "settlement_overlay", "ding_que_overlay"]:
		var overlay: Control = root_node.get(property_name) as Control
		if overlay != null:
			overlay.visible = false
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar != null:
		utility_bar.call("render", false, false, false)


func _force_ding_que_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var drawer: Control = root_node.get("ai_assistant_drawer") as Control
	if drawer != null:
		drawer.visible = false
	var overlay: Control = root_node.get("ding_que_overlay") as Control
	if overlay != null:
		overlay.visible = true
		overlay.move_to_front()
	var action_bar: Control = root_node.get("table_action_bar") as Control
	if action_bar != null:
		action_bar.call("hide_actions")


func _force_action_bar_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var action_bar: Control = root_node.get("table_action_bar") as Control
	if action_bar == null:
		return
	var preview_actions: Array[String]
	var status_text := "响应 3筒 · 可选：碰 / 取消"
	match _capture_mode():
		"response-hu":
			action_bar.call("set_action_label", "hu", "胡")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["hu", "pass"]
			status_text = "响应 9筒 · 可选：胡 / 取消"
		"self-hu":
			action_bar.call("set_action_label", "hu", "自摸")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["hu", "pass"]
			status_text = "轮到你 · 可选：自摸 / 取消"
		_:
			action_bar.call("set_action_label", "peng", "碰")
			action_bar.call("set_action_label", "pass", "取消")
			preview_actions = ["peng", "pass"]
	action_bar.call("render", preview_actions, status_text)
	var center_indicator: Control = root_node.get("center_turn_indicator") as Control
	if center_indicator != null:
		center_indicator.call("render", 40, 0, "等待本家响应")
	root_node.call_deferred("_layout_table_action_bar")


func _force_utility_expanded_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var utility_bar: Control = root_node.get("table_utility_bar") as Control
	if utility_bar == null:
		return
	utility_bar.call("render", true, false, false, "骨灰", true)
	utility_bar.call("set_collapsed", false)
	root_node.call_deferred("_layout_table_utility_bar")


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
			"has_won": false,
		},
		{
			"seat": 1,
			"nickname": "舒小燕",
			"score": -5,
			"hand_count": 11,
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
			"hand_count": 11,
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
			"hand_count": 11,
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
		"human_reaction_options": {"can_peng": true, "can_pass": true},
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
	root_node.call("_update_seat_huds", snapshot)
	root_node.call("_update_self_area", snapshot, players[0]["hand_tiles"])


func _force_3d_full_table_preview(root_node: Node) -> void:
	if root_node == null:
		return
	var stage := root_node.get("table_stage_3d") as Node3D
	if stage == null or not stage.has_method("render_snapshot"):
		return
	if _capture_mode() == "camera":
		root_node.set("opponent_hands_enabled", false)
		root_node.set("ai_helper_enabled", false)
	var hand_counts := [14, 13, 13, 13] if _capture_mode() == "camera" else [11, 10, 10, 10]
	# The camera-reference frame mirrors the supplied ding-que screenshot: four
	# concealed hands, no discards and no melds. Dense gameplay remains covered
	# by the contract runner and the normal beauty-shot modes.
	var discard_counts := [0, 0, 0, 0] if _capture_mode() == "camera" else ([18, 18, 18, 18] if _capture_mode() == "discard-pressure" else [10, 9, 10, 9])
	var all_hands: Array = []
	var players: Array = []
	for seat in range(4):
		var hand := _make_3d_demo_tiles(10000 + seat * 100, hand_counts[seat], seat)
		var discards := _make_3d_demo_tiles(20000 + seat * 100, discard_counts[seat], seat + 1)
		var meld_tile_count := 12 if seat == 0 and _capture_mode() == "max-meld" else (7 if seat == 3 and _capture_mode() == "right-meld" else (4 if seat == 2 else 3))
		var meld_tiles := _make_3d_demo_tiles(30000 + seat * 100, meld_tile_count, seat + 2)
		all_hands.append(hand)
		var preview_melds: Array = []
		if _capture_mode() != "camera":
			if seat == 0 and _capture_mode() == "max-meld":
				# Four exposed groups exercise the widest legal lower-left rail and
				# prove that the shifted concealed hand still remains unobstructed.
				for group_index in range(4):
					var group_tiles: Array = []
					for tile_index in range(group_index * 3, group_index * 3 + 3):
						group_tiles.append(meld_tiles[tile_index])
					preview_melds.append({
						"type": "peng",
						"tiles": group_tiles,
						"from_seat": (seat + group_index + 1) % 4,
					})
			elif seat == 3 and _capture_mode() == "right-meld":
				preview_melds = [
					{
						"type": "peng",
						"tiles": meld_tiles.slice(0, 3),
						"from_seat": 0,
					},
					{
						"type": "gang",
						"gang_subtype": "ming_gang",
						"tiles": meld_tiles.slice(3, 7),
						"from_seat": 2,
					},
				]
			else:
				preview_melds = [{
					"type": "gang" if seat == 2 else "peng",
					"gang_subtype": "an_gang" if seat == 2 else "",
					"tiles": meld_tiles,
					"from_seat": (seat + 1) % 4,
				}]
		players.append({
			"seat": seat,
			"nickname": ["本家", "舒小燕", "陈东", "舒玲"][seat],
			"score": [3, -5, 6, 2][seat],
			"hand_count": hand_counts[seat],
			"hand_tiles": hand if seat == 0 else [],
			"melds": preview_melds,
			"discards": discards,
			"ding_que": ["tong", "wan", "tong", "wan"][seat],
			"has_won": false,
		})
	if _capture_mode() == "won":
		players[0]["has_won"] = true
		players[0]["winning_tile"] = all_hands[0].back()
		players[0]["winning_source_seat"] = 1
	elif _capture_mode() == "self-draw":
		players[0]["has_won"] = true
		players[0]["winning_tile"] = all_hands[0].back()
		players[0]["winning_source_seat"] = 0
	elif _capture_mode() == "ai-discard-win":
		players[1]["has_won"] = true
		players[1]["winning_tile"] = all_hands[1].back()
		players[1]["winning_source_seat"] = 0
	var recent_tile: Dictionary = {}
	if not (players[3]["discards"] as Array).is_empty():
		recent_tile = players[3]["discards"].back()
	var snapshot := {
		"players": players,
		"wall_count": 40,
		"current_turn_seat": 2 if _capture_mode() == "ai-discard-win" else (1 if _capture_mode() == "won" else 0),
		"current_dealer_seat": 0,
		"human_can_discard": _capture_mode() not in ["won", "self-draw", "ai-discard-win"],
		"human_last_draw_tile_id": int(all_hands[0].back().get("id", -1)),
		"recent_discard_tile_id": int(recent_tile.get("id", -1)),
	}
	# Evidence states must obey the same interaction contract as runtime state.
	# Previously the action bar was forced after the HUD snapshot, producing
	# impossible frames such as 已胡 + 本家出牌中 or 响应按钮 + 出牌徽章.
	match _capture_mode():
		"response-hu":
			snapshot["human_can_discard"] = false
			snapshot["human_reaction_options"] = {"can_hu": true, "can_pass": true}
		"self-hu":
			snapshot["human_can_discard"] = false
			snapshot["human_can_self_hu"] = true
		"ai-expanded", "table":
			snapshot["human_can_discard"] = false
			snapshot["human_reaction_options"] = {"can_peng": true, "can_pass": true}
	var reveal_opponents := _capture_mode() == "3d-reveal"
	var selected_tile_id := int(all_hands[0][4].get("id", -1)) if _capture_mode() == "selection" else -1
	stage.call("set_reduced_motion", true)
	stage.call("render_snapshot", snapshot, all_hands, reveal_opponents, selected_tile_id, {
		"recommended_tile_id": int(all_hands[0][2].get("id", -1)),
		"danger_tile_ids": [int(all_hands[0][8].get("id", -1))],
	})
	if root_node.has_method("_update_seat_huds"):
		root_node.call("_update_seat_huds", snapshot)
	var center_indicator := root_node.get("center_turn_indicator") as Control
	if center_indicator != null and center_indicator.has_method("render"):
		if _capture_mode() == "won":
			center_indicator.call("render", 40, 1, "上家出牌中")
		elif _capture_mode() == "self-draw":
			center_indicator.call("render", 40, 0, "本家已自摸")
		elif _capture_mode() == "ai-discard-win":
			center_indicator.call("render", 40, 2, "对家出牌中")
		elif _capture_mode() in ["response-hu", "self-hu", "ai-expanded", "table"]:
			center_indicator.call("render", 40, 0, "等待本家响应" if _capture_mode() != "self-hu" else "本家操作中")
		else:
			center_indicator.call("render", 40, int(snapshot.get("current_turn_seat", 0)))
	root_node.call("_layout_3d_center_indicator")


func _make_3d_demo_tiles(start_id: int, count: int, offset: int) -> Array:
	var result: Array = []
	var suits := ["tiao", "tong", "wan"]
	for index in range(count):
		result.append({
			"id": start_id + index,
			"suit": suits[(index + offset) % suits.size()],
			"rank": (index * 2 + offset) % 9 + 1,
		})
	return result


func _take_tile_from_wall(wall: Array, suit: String, rank: int) -> Dictionary:
	for index in range(wall.size()):
		var tile: Dictionary = wall[index]
		if str(tile.get("suit", "")) == suit and int(tile.get("rank", 0)) == rank:
			wall.remove_at(index)
			return tile
	return {}
