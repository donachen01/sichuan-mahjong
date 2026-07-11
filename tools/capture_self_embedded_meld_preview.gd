extends SceneTree

const OUTPUT_PATH := "user://capture_self_embedded_meld_preview.png"
const HAND_VIEWPORT_SCENE := preload("res://scenes/ui/PlayerHandViewport.tscn")
const PLAYER_UI_SCENE := preload("res://scenes/ui/PlayerUI.tscn")

const SELF_ROW_GAP := 18.0
const SELF_TILE_FACE_WIDTH := 92.0
const SELF_SLOT_STEP := 80.0


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	get_root().size = Vector2i(2200, 780)

	var root := Control.new()
	root.anchor_right = 0.0
	root.anchor_bottom = 0.0
	root.offset_right = 2200
	root.offset_bottom = 780
	root.custom_minimum_size = Vector2(2200, 780)
	get_root().add_child(root)

	var bg := ColorRect.new()
	bg.anchor_right = 0.0
	bg.anchor_bottom = 0.0
	bg.offset_right = 2200
	bg.offset_bottom = 780
	bg.color = Color(0.06, 0.34, 0.20, 1.0)
	root.add_child(bg)

	var hand_host := HAND_VIEWPORT_SCENE.instantiate() as Control
	hand_host.anchor_left = 0.5
	hand_host.anchor_right = 0.5
	hand_host.anchor_top = 1.0
	hand_host.anchor_bottom = 1.0
	hand_host.offset_left = -940
	hand_host.offset_right = 940
	hand_host.offset_top = -254
	hand_host.offset_bottom = -18
	root.add_child(hand_host)

	var meld_host := PLAYER_UI_SCENE.instantiate() as PlayerUI
	meld_host.seat_dock = PlayerUI.SeatDock.SELF
	root.add_child(meld_host)

	await process_frame

	var meld_player := {
		"seat": 0,
		"nickname": "玩家",
		"score": 1420,
		"hand_count": 10,
		"ding_que": "wan",
		"melds": [
			{"type": "peng", "from_seat": 3, "tiles": [_tile("tong", 4, 101), _tile("tong", 4, 102), _tile("tong", 4, 103)]},
			{"type": "gang", "from_seat": 1, "tiles": [_tile("tiao", 7, 104), _tile("tiao", 7, 105), _tile("tiao", 7, 106), _tile("tiao", 7, 107)]},
		],
		"discards": [],
		"has_won": false,
		"winning_tile": {},
		"winning_source_seat": 0,
		"win_type": "",
	}
	meld_host.apply_snapshot(meld_player, false, -1, 0)

	var hand_tiles := [
		_tile("tiao", 1, 1),
		_tile("tiao", 2, 2),
		_tile("tiao", 3, 3),
		_tile("tiao", 4, 4),
		_tile("tiao", 6, 5),
		_tile("tiao", 8, 6),
		_tile("wan", 2, 7),
		_tile("wan", 5, 8),
		_tile("wan", 7, 9),
		_tile("tong", 8, 10),
	]
	var meld_slots := 7
	var meld_width := _slot_band_width(meld_slots)
	var hand_width := _slot_band_width(hand_tiles.size())
	hand_host.custom_minimum_size = Vector2(meld_width + hand_width + SELF_ROW_GAP, 292.0)
	hand_host.call("embed_left_host", meld_host, meld_width, SELF_ROW_GAP)
	hand_host.call("configure_hand", hand_tiles, -1, -1, true, {}, {
		"embedded_left_width": meld_width,
		"embedded_left_gap": SELF_ROW_GAP,
	})

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("Failed to capture embedded meld preview")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save preview: %s" % path)
		quit(1)
		return

	print(path)
	quit()


func _slot_band_width(slot_count: int) -> float:
	if slot_count <= 0:
		return 0.0
	return SELF_TILE_FACE_WIDTH + SELF_SLOT_STEP * float(slot_count - 1)


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
