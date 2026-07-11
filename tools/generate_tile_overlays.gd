extends SceneTree

const SOURCE_IMAGE := "res://res/source/tiles/矢量全套麻将_爱给网_aigei_com.png"
const OUTPUT_DIR := "res://res/art/tiles"

const TILE_ROWS := [
	[
		Rect2i(8, 0, 359, 472),
		Rect2i(396, 0, 359, 472),
		Rect2i(787, 0, 359, 472),
		Rect2i(1176, 0, 360, 472),
		Rect2i(1564, 0, 359, 472),
	],
	[
		Rect2i(8, 511, 359, 471),
		Rect2i(396, 511, 359, 471),
		Rect2i(787, 511, 359, 471),
		Rect2i(1176, 511, 360, 471),
	],
	[
		Rect2i(8, 1087, 359, 472),
		Rect2i(396, 1087, 359, 472),
		Rect2i(787, 1087, 359, 472),
		Rect2i(1182, 1090, 359, 472),
		Rect2i(1588, 1090, 359, 472),
	],
	[
		Rect2i(1, 1634, 360, 472),
		Rect2i(396, 1634, 359, 472),
		Rect2i(795, 1642, 359, 471),
		Rect2i(1182, 1642, 359, 471),
	],
	[
		Rect2i(3, 2243, 360, 471),
		Rect2i(421, 2237, 359, 472),
		Rect2i(827, 2238, 359, 471),
		Rect2i(1244, 2238, 359, 471),
		Rect2i(1673, 2238, 359, 471),
		Rect2i(2108, 2238, 360, 471),
		Rect2i(2583, 2238, 359, 471),
	],
	[
		Rect2i(3, 2769, 359, 471),
		Rect2i(389, 2769, 360, 471),
		Rect2i(776, 2769, 360, 471),
		Rect2i(1163, 2769, 359, 471),
		Rect2i(1550, 2769, 359, 471),
	],
	[
		Rect2i(3, 3281, 359, 472),
		Rect2i(389, 3281, 360, 472),
		Rect2i(776, 3281, 360, 472),
		Rect2i(1159, 3286, 359, 472),
	],
]

const FACE_OUTPUT_SIZE := Vector2i(196, 288)
const BACK_OUTPUT_SIZE := Vector2i(170, 250)
const FACE_FILL_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const BACK_FILL_COLOR := Color(0.18, 0.36, 0.25, 1.0)
const TILE_INSET := Vector2i(22, 22)
const BACK_INSET := Vector2i(18, 18)
const CONTENT_PADDING := {
	"tong": 10,
	"tiao": 12,
	"wan": 10,
}
const CONTENT_SCALE := {
	"tong": Vector2(0.84, 0.82),
	"tiao": Vector2(0.80, 0.88),
	"wan": Vector2(0.84, 0.90),
}
const CONTENT_SHIFT := {
	"tong": Vector2i(8, 6),
	"tiao": Vector2i(6, 6),
	"wan": Vector2i(6, 8),
}


func _init() -> void:
	var source := Image.new()
	var error := source.load(SOURCE_IMAGE)
	if error != OK:
		push_error("Failed to load source image: %s" % SOURCE_IMAGE)
		quit(1)
		return

	source.convert(Image.FORMAT_RGBA8)
	_generate_suit(source, "tong", 0, 1)
	_generate_suit(source, "tiao", 2, 3, [0, 6, 4, 5, 3, 2, 1, 7, 8], true)
	_generate_suit(source, "wan", 5, 6)
	_generate_back_face(source)

	print("Generated tile overlays from %s" % SOURCE_IMAGE)
	quit()


func _generate_suit(source: Image, suit: String, row_a: int, row_b: int, rank_order: Array = [], reverse_rank_order: bool = false) -> void:
	var rects: Array[Rect2i] = []
	rects.append_array(TILE_ROWS[row_a])
	rects.append_array(TILE_ROWS[row_b])
	if reverse_rank_order:
		rects.reverse()
	if not rank_order.is_empty():
		var ordered_rects: Array[Rect2i] = []
		for index in rank_order:
			ordered_rects.append(rects[int(index)])
		rects = ordered_rects
	var rank := 1
	for rect: Rect2i in rects:
		_save_face_tile(source, suit, rank, rect)
		rank += 1


func _save_face_tile(source: Image, suit: String, rank: int, tile_rect: Rect2i) -> void:
	var inner_rect := _inset_rect(tile_rect, TILE_INSET)
	var sample := source.get_region(inner_rect)
	sample.convert(Image.FORMAT_RGBA8)
	sample = _trim_to_content(sample, int(CONTENT_PADDING.get(suit, 10)))
	var fitted := _fit_to_box(sample, _target_size_for_suit(suit))
	var canvas := _empty_canvas(FACE_OUTPUT_SIZE, FACE_FILL_COLOR)
	var shift: Vector2i = CONTENT_SHIFT.get(suit, Vector2i.ZERO)
	var dst := Vector2i(
		maxi(0, int(round((FACE_OUTPUT_SIZE.x - fitted.get_width()) * 0.5)) + shift.x),
		maxi(0, int(round((FACE_OUTPUT_SIZE.y - fitted.get_height()) * 0.5)) + shift.y)
	)
	dst.x = clampi(dst.x, 0, maxi(0, FACE_OUTPUT_SIZE.x - fitted.get_width()))
	dst.y = clampi(dst.y, 0, maxi(0, FACE_OUTPUT_SIZE.y - fitted.get_height()))
	canvas.blit_rect(fitted, Rect2i(Vector2i.ZERO, Vector2i(fitted.get_width(), fitted.get_height())), dst)
	canvas.save_png(ProjectSettings.globalize_path("%s/%s_%d.png" % [OUTPUT_DIR, suit, rank]))


func _generate_back_face(source: Image) -> void:
	var tile_rect: Rect2i = TILE_ROWS[4][6]
	var inner_rect := _inset_rect(tile_rect, BACK_INSET)
	var sample := source.get_region(inner_rect)
	sample.convert(Image.FORMAT_RGBA8)
	sample = _trim_to_content(sample, 12)
	var fitted := _fit_to_box(sample, BACK_OUTPUT_SIZE - Vector2i(14, 14))
	var canvas := _empty_canvas(BACK_OUTPUT_SIZE, BACK_FILL_COLOR)
	var dst := Vector2i(
		maxi(0, int(round((BACK_OUTPUT_SIZE.x - fitted.get_width()) * 0.5))),
		maxi(0, int(round((BACK_OUTPUT_SIZE.y - fitted.get_height()) * 0.5)))
	)
	canvas.blit_rect(fitted, Rect2i(Vector2i.ZERO, Vector2i(fitted.get_width(), fitted.get_height())), dst)
	canvas.save_png(ProjectSettings.globalize_path("%s/back_face.png" % OUTPUT_DIR))


func _inset_rect(rect: Rect2i, inset: Vector2i) -> Rect2i:
	return Rect2i(
		rect.position.x + inset.x,
		rect.position.y + inset.y,
		rect.size.x - inset.x * 2,
		rect.size.y - inset.y * 2
	)


func _trim_to_content(image: Image, padding: int) -> Image:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _is_content_pixel(image.get_pixel(x, y)):
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return image

	min_x = maxi(0, min_x - padding)
	min_y = maxi(0, min_y - padding)
	max_x = mini(image.get_width() - 1, max_x + padding)
	max_y = mini(image.get_height() - 1, max_y + padding)

	return image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


func _is_content_pixel(color: Color) -> bool:
	return color.a > 0.01 and (color.r > 0.08 or color.g > 0.08 or color.b > 0.08)


func _fit_to_box(image: Image, box_size: Vector2i) -> Image:
	var result := image.duplicate()
	var scale_factor := minf(
		float(box_size.x) / float(maxi(1, image.get_width())),
		float(box_size.y) / float(maxi(1, image.get_height()))
	)
	result.resize(
		maxi(1, int(round(image.get_width() * scale_factor))),
		maxi(1, int(round(image.get_height() * scale_factor))),
		Image.INTERPOLATE_LANCZOS
	)
	return result


func _target_size_for_suit(suit: String) -> Vector2i:
	var scale: Vector2 = CONTENT_SCALE.get(suit, Vector2.ONE)
	return Vector2i(
		maxi(1, int(round(FACE_OUTPUT_SIZE.x * scale.x))),
		maxi(1, int(round(FACE_OUTPUT_SIZE.y * scale.y)))
	)


func _empty_canvas(size: Vector2i, fill_color: Color) -> Image:
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(fill_color)
	return canvas
