extends SceneTree

const METRICS_PATH := "res://scripts/ui/table/SichuanTableMetrics.gd"
const THEME_PATH := "res://scripts/ui/table/SichuanTableTheme.gd"
const SAFE_AREA_PATH := "res://scripts/ui/table/SafeAreaLayout.gd"
const SEAT_HUD_PATH := "res://scripts/ui/table/SeatHUD.gd"
const CENTER_INDICATOR_PATH := "res://scripts/ui/table/CenterTurnIndicator.gd"
const DISCARD_LAYER_PATH := "res://scripts/ui/table/TableDiscardLayer.gd"
const MAIN_SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"
const VIEWPORT_CASES := [
	Vector2(1365.0, 768.0),
	Vector2(2048.0, 1152.0),
	Vector2(2400.0, 1080.0),
	Vector2(2556.0, 1179.0),
	Vector2(2796.0, 1290.0),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var metrics_script := load(METRICS_PATH)
	var theme_script := load(THEME_PATH)
	var safe_area_script := load(SAFE_AREA_PATH)
	if metrics_script == null:
		failures.append("missing SichuanTableMetrics.gd")
	if theme_script == null:
		failures.append("missing SichuanTableTheme.gd")
	if safe_area_script == null:
		failures.append("missing SafeAreaLayout.gd")
	if failures.is_empty():
		_verify_metrics(metrics_script, failures)
		_verify_theme(theme_script, failures)
		await _verify_live_scene(failures)

	if failures.is_empty():
		print("SICHUAN TABLE LAYOUT CONTRACT OK")
		quit(0)
		return
	push_error("SICHUAN TABLE LAYOUT CONTRACT FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_metrics(metrics_script: Script, failures: Array[String]) -> void:
	for viewport_size in VIEWPORT_CASES:
		var scale_value := float(metrics_script.call("content_scale", viewport_size))
		if scale_value < 0.82 or scale_value > 1.18:
			failures.append("content scale out of contract for %s: %.3f" % [viewport_size, scale_value])
	var compact_mode := str(metrics_script.call("layout_mode", Vector2(1365.0, 768.0)))
	var standard_mode := str(metrics_script.call("layout_mode", Vector2(2048.0, 1152.0)))
	if compact_mode != "compact":
		failures.append("1365x768 must use compact layout")
	if standard_mode != "standard":
		failures.append("2048x1152 must use standard layout")
	var touch_target: Vector2 = metrics_script.call("touch_target")
	if touch_target.x < 76.0 or touch_target.y < 76.0:
		failures.append("touch target must be at least 76x76")
	var standard_board: Rect2 = metrics_script.call("board_rect", Vector2(2048.0, 1152.0))
	if not standard_board.is_equal_approx(Rect2(304.0, 160.0, 1440.0, 710.0)):
		failures.append("standard board rect drifted from the shared reference contract")
	var compact_self_hud: Rect2 = metrics_script.call("seat_hud_rect", 0, Vector2(1365.0, 768.0))
	if compact_self_hud.size.x < 176.0 or compact_self_hud.size.y < 112.0:
		failures.append("compact SeatHUD must retain the 176x112 readability token")
	var compact_hand: Rect2 = metrics_script.call("self_hand_rect", Vector2(1365.0, 768.0))
	if compact_self_hud.end.y > compact_hand.position.y + 0.1:
		failures.append("compact self SeatHUD must stay above the self hand")


func _verify_theme(theme_script: Script, failures: Array[String]) -> void:
	var colors := [
		theme_script.call("ding_que_color", "wan"),
		theme_script.call("ding_que_color", "tong"),
		theme_script.call("ding_que_color", "tiao"),
	]
	if colors[0] == colors[1] or colors[0] == colors[2] or colors[1] == colors[2]:
		failures.append("ding-que palettes must be distinct")
	if int(theme_script.call("font_size", "player_name", true)) < 26:
		failures.append("compact player-name font must be at least 26")
	if int(theme_script.call("font_size", "ding_que", true)) < 26:
		failures.append("compact ding-que font must be at least 26")


func _verify_live_scene(failures: Array[String]) -> void:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		failures.append("main table scene failed to load")
		return
	var scene := packed_scene.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	if scene.get("root_ui") == null:
		failures.append("main table root UI missing")
	if scene.get("safe_area") == null:
		failures.append("main table safe area missing")
	else:
		var safe_area: Control = scene.get("safe_area")
		if safe_area.get_script() == null or safe_area.get_script().resource_path != SAFE_AREA_PATH:
			failures.append("main table safe area must use SafeAreaLayout.gd")
		var margins: Vector4 = safe_area.call(
			"apply_safe_area_for_test",
			Vector2(2556.0, 1179.0),
			Vector2(2556.0, 1179.0),
			Rect2(96.0, 0.0, 2364.0, 1179.0)
		)
		if margins.x < 96.0 or margins.z < 96.0:
			failures.append("iPhone safe-area insets were not preserved")
	var seat_huds: Dictionary = scene.get("seat_huds")
	if seat_huds.size() != 4:
		failures.append("expected four shared SeatHUD instances")
	else:
		var players := [
			{"seat": 0, "nickname": "本家", "score": 120, "ding_que": ""},
			{"seat": 1, "nickname": "上家", "score": 80, "ding_que": "wan"},
			{"seat": 2, "nickname": "对家", "score": 40, "ding_que": "tong"},
			{"seat": 3, "nickname": "下家", "score": -20, "ding_que": "tiao"},
		]
		scene.call("_update_seat_huds", {
			"players": players,
			"current_dealer_seat": 2,
			"current_turn_seat": 1,
			"rules": {"use_ding_que_phase": true},
		})
		for seat in [0, 1, 2, 3]:
			var seat_hud: Control = seat_huds.get(seat)
			if seat_hud == null or seat_hud.get_script() == null:
				failures.append("SeatHUD%d missing script" % seat)
				continue
			if seat_hud.get_script().resource_path != SEAT_HUD_PATH:
				failures.append("SeatHUD%d does not use the shared component" % seat)
			var badge: Control = seat_hud.call("get_ding_que_badge")
			if badge == null:
				failures.append("SeatHUD%d missing DingQueBadge" % seat)
			elif badge.visible:
				failures.append("opponent ding-que badges must stay hidden before self selection")

		players[0]["ding_que"] = "wan"
		scene.call("_update_seat_huds", {
			"players": players,
			"current_dealer_seat": 2,
			"current_turn_seat": 1,
			"rules": {"use_ding_que_phase": true},
		})
		for seat in [0, 1, 2, 3]:
			var revealed_hud: Control = seat_huds.get(seat)
			var revealed_badge: Control = revealed_hud.call("get_ding_que_badge")
			if not revealed_badge.visible:
				failures.append("SeatHUD%d ding-que badge was not revealed" % seat)
		var left_hud: Control = seat_huds.get(1)
		var top_hud: Control = seat_huds.get(2)
		var right_hud: Control = seat_huds.get(3)
		var self_hud: Control = seat_huds.get(0)
		for compared_hud in [left_hud, top_hud, right_hud]:
			if not self_hud.size.is_equal_approx(compared_hud.size):
				failures.append("all four SeatHUD cards must use one size token")
		var viewport_height := scene.get_viewport().get_visible_rect().size.y
		for side_hud in [left_hud, right_hud]:
			var normalized_y: float = side_hud.get_global_rect().get_center().y / maxf(1.0, viewport_height)
			if normalized_y < 0.16 or normalized_y > 0.32:
				failures.append("side SeatHUD nameplates must use the target-reference upper rail")
		var root_ui: Control = scene.get("root_ui")
		var top_opponent_host: Control = scene.get("player_top_host")
		if top_opponent_host != null and top_hud.get_global_rect().intersects(top_opponent_host.get_global_rect()):
			failures.append("top SeatHUD must stay outside the top opponent tile track")
		var normalized_top_x: float = top_hud.get_global_rect().get_center().x / maxf(1.0, root_ui.get_global_rect().size.x)
		if normalized_top_x < 0.68 or normalized_top_x > 0.83:
			failures.append("top SeatHUD must use the target-reference upper-right anchor")
	await _verify_center_and_discard_layer(scene, failures)
	scene.queue_free()
	await process_frame
	await process_frame


func _verify_center_and_discard_layer(scene: Node, failures: Array[String]) -> void:
	var indicator: Control = scene.get("center_turn_indicator")
	if indicator == null or indicator.get_script() == null or indicator.get_script().resource_path != CENTER_INDICATOR_PATH:
		failures.append("shared CenterTurnIndicator component missing")
	else:
		indicator.call("set_compact", false)
		indicator.call("render", 55, 3, "下家出牌中")
		if indicator.size.x < 190.0 or indicator.size.x > 220.0 or indicator.size.y < 190.0 or indicator.size.y > 220.0:
			failures.append("center indicator must stay within 190x190 and 220x220")
		if str(indicator.call("get_active_direction_text")) != "下":
			failures.append("中心四向风盘必须用本上对下标明当前下家")

	var discard_layer: Control = scene.get("table_discard_layer")
	if discard_layer == null or discard_layer.get_script() == null or discard_layer.get_script().resource_path != DISCARD_LAYER_PATH:
		failures.append("shared TableDiscardLayer component missing")
		return
	var pressure_players: Array = []
	var latest_id := -1
	for seat in range(4):
		var discards: Array = []
		for index in range(14):
			var tile_id := seat * 100 + index
			discards.append({
				"id": tile_id,
				"suit": ["wan", "tiao", "tong"][index % 3],
				"rank": index % 9 + 1,
				"display_name": "%d万" % (index % 9 + 1),
			})
			if seat == 3 and index == 13:
				latest_id = tile_id
		pressure_players.append({"seat": seat, "discards": discards})
	discard_layer.call("render", pressure_players, {"id": latest_id}, Rect2(Vector2.ZERO, Vector2(1440.0, 710.0)))
	await process_frame
	var center_reserved: Rect2 = discard_layer.call("get_center_reserved_rect")
	for seat in range(4):
		var lane_contract: Dictionary = discard_layer.call("get_lane_contract", seat)
		var expected_items_per_row := 7 if seat in [0, 2] else 3
		if int(lane_contract.get("items_per_row", -1)) != expected_items_per_row:
			failures.append("discard lane %d lost its four-sided ring wrapping contract" % seat)
		if not bool(lane_contract.get("stable_origin", false)):
			failures.append("discard lane %d must retain a fixed origin as tiles are added" % seat)
		var lane_rect: Rect2 = discard_layer.call("get_lane_rect", seat)
		if lane_rect.intersects(center_reserved):
			failures.append("discard lane %d intersects center reserved rect" % seat)
		var lane: Control = discard_layer.call("get_lane", seat)
		for tile_host in lane.get_children():
			var tile_rect := Rect2(lane_rect.position + tile_host.position, tile_host.size)
			if tile_rect.intersects(center_reserved):
				failures.append("seat %d pressure discard entered center reserved rect" % seat)
				break
	if int(discard_layer.call("get_latest_marker_count")) != 1:
		failures.append("latest discard marker must appear exactly once")
