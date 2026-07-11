extends SceneTree

const OUTPUT_PATH := "user://capture_player_ui_claims.png"
const PLAYER_UI_SCENE := preload("res://scenes/ui/PlayerUI.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	get_root().size = Vector2i(1800, 1200)
	var root := Control.new()
	root.anchor_right = 0.0
	root.anchor_bottom = 0.0
	root.offset_right = 1800
	root.offset_bottom = 1200
	root.custom_minimum_size = Vector2(1800, 1200)
	get_root().add_child(root)

	var bg := ColorRect.new()
	bg.anchor_right = 0.0
	bg.anchor_bottom = 0.0
	bg.offset_right = 1800
	bg.offset_bottom = 1200
	bg.color = Color(0.05, 0.28, 0.18, 1.0)
	root.add_child(bg)

	var players := _build_mock_players()
	var staged: Array = []
	staged.append(_add_player_ui(root, Rect2(500, 860, 800, 250), PlayerUI.SeatDock.SELF, players[0], false))
	staged.append(_add_player_ui(root, Rect2(500, 70, 800, 230), PlayerUI.SeatDock.TOP, players[2], true))
	staged.append(_add_player_ui(root, Rect2(60, 260, 260, 620), PlayerUI.SeatDock.LEFT, players[1], true))
	staged.append(_add_player_ui(root, Rect2(1480, 260, 260, 620), PlayerUI.SeatDock.RIGHT, players[3], true))

	await process_frame
	for item in staged:
		var ui: PlayerUI = item["ui"]
		ui.apply_snapshot(item["player"], item["show_back"], int(item["player"].get("seat", -1)), 0)
	await process_frame
	await RenderingServer.frame_post_draw

	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("Failed to capture UI claims preview")
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


func _add_player_ui(root: Control, rect: Rect2, dock: int, player: Dictionary, show_back: bool) -> Dictionary:
	var ui := PLAYER_UI_SCENE.instantiate() as PlayerUI
	ui.seat_dock = dock
	root.add_child(ui)
	ui.anchor_right = 0.0
	ui.anchor_bottom = 0.0
	ui.anchor_right = 0.0
	ui.anchor_bottom = 0.0
	ui.offset_left = rect.position.x
	ui.offset_top = rect.position.y
	ui.offset_right = rect.position.x + rect.size.x
	ui.offset_bottom = rect.position.y + rect.size.y
	ui.custom_minimum_size = rect.size
	return {
		"ui": ui,
		"player": player,
		"show_back": show_back,
	}


func _tile(suit: String, rank: int, id_value: int) -> Dictionary:
	return {
		"id": id_value,
		"suit": suit,
		"rank": rank,
		"display_name": "%d%s" % [rank, _suit_label(suit)],
	}


func _suit_label(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return "?"


func _build_mock_players() -> Array:
	return [
		{
			"seat": 0,
			"nickname": "玩家",
			"score": 1240,
			"hand_count": 11,
			"ding_que": "wan",
			"melds": [
				{"type": "peng", "from_seat": 3, "tiles": [_tile("tong", 4, 101), _tile("tong", 4, 102), _tile("tong", 4, 103)]},
				{"type": "gang", "from_seat": 1, "tiles": [_tile("tiao", 7, 104), _tile("tiao", 7, 105), _tile("tiao", 7, 106), _tile("tiao", 7, 107)]},
			],
			"discards": [_tile("tiao", 2, 108), _tile("tong", 9, 109)],
			"has_won": true,
			"winning_tile": _tile("tong", 8, 110),
			"winning_source_seat": 0,
			"win_type": "self_draw",
		},
		{
			"seat": 1,
			"nickname": "上家",
			"score": 980,
			"hand_count": 9,
			"ding_que": "tiao",
			"melds": [
				{"type": "peng", "from_seat": 2, "tiles": [_tile("wan", 3, 201), _tile("wan", 3, 202), _tile("wan", 3, 203)]},
			],
			"discards": [_tile("tong", 5, 204), _tile("tong", 6, 205), _tile("wan", 8, 206)],
			"has_won": false,
			"winning_tile": {},
			"winning_source_seat": 1,
			"win_type": "",
		},
		{
			"seat": 2,
			"nickname": "对家",
			"score": 1120,
			"hand_count": 10,
			"ding_que": "tong",
			"melds": [
				{"type": "gang", "from_seat": 0, "tiles": [_tile("wan", 9, 301), _tile("wan", 9, 302), _tile("wan", 9, 303), _tile("wan", 9, 304)]},
			],
			"discards": [_tile("tiao", 1, 305), _tile("tiao", 5, 306)],
			"has_won": true,
			"winning_tile": _tile("tong", 6, 307),
			"winning_source_seat": 1,
			"win_type": "discard_win",
		},
		{
			"seat": 3,
			"nickname": "下家",
			"score": 660,
			"hand_count": 8,
			"ding_que": "wan",
			"melds": [
				{"type": "peng", "from_seat": 0, "tiles": [_tile("tiao", 6, 401), _tile("tiao", 6, 402), _tile("tiao", 6, 403)]},
				{"type": "gang", "from_seat": 3, "tiles": [_tile("tong", 2, 404), _tile("tong", 2, 405), _tile("tong", 2, 406), _tile("tong", 2, 407)]},
			],
			"discards": [_tile("wan", 1, 408), _tile("wan", 2, 409)],
			"has_won": false,
			"winning_tile": {},
			"winning_source_seat": 3,
			"win_type": "",
		},
	]
