extends Control

class_name TableMaterialOverlay

enum MaterialMode {
	FELT,
	WOOD,
	SOFT_PANEL,
	BUTTON_GLOSS,
}

const FELT_TEXTURE_PATH := "res://res/art/ui_3d_cartoon/felt_table_luxury.png"

@export var material_mode: MaterialMode = MaterialMode.FELT:
	set(value):
		material_mode = value
		queue_redraw()

@export var opacity: float = 1.0:
	set(value):
		opacity = clampf(value, 0.0, 1.0)
		queue_redraw()

var _texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	match material_mode:
		MaterialMode.FELT:
			_draw_felt_texture()
		MaterialMode.WOOD:
			_draw_wood_texture()
		MaterialMode.SOFT_PANEL:
			_draw_soft_panel_texture()
		MaterialMode.BUTTON_GLOSS:
			_draw_button_gloss_texture()


func _draw_felt_texture() -> void:
	var felt_texture := _load_texture(FELT_TEXTURE_PATH)
	if felt_texture != null:
		draw_texture_rect(felt_texture, Rect2(Vector2.ZERO, size), false, Color(1.0, 1.0, 1.0, opacity))

	var center := Vector2(size.x * 0.50, size.y * 0.42)
	var highlight := Vector2(size.x * 0.18, size.y * 0.16)
	var shadow := Vector2(size.x * 0.83, size.y * 0.82)
	var radius := maxf(size.x, size.y) * 0.66
	for band in range(8):
		var t := float(band) / 7.0
		draw_circle(center, lerpf(radius * 0.16, radius * 0.62, t), Color(0.22, 0.55, 0.34, 0.020 * opacity * (1.0 - t)))
	for band in range(6):
		var t := float(band) / 5.0
		draw_circle(highlight, lerpf(radius * 0.05, radius * 0.32, t), Color(0.78, 0.98, 0.70, 0.010 * opacity * (1.0 - t)))
		draw_circle(shadow, lerpf(radius * 0.08, radius * 0.34, t), Color(0.0, 0.06, 0.035, 0.020 * opacity * (1.0 - t)))

	var line_gap := maxf(12.0, minf(size.x, size.y) / 76.0)
	var horizontal_count := int(size.y / line_gap)
	for index in range(horizontal_count + 1):
		var y := float(index) * line_gap
		var alpha := (0.0012 + 0.0008 * sin(float(index) * 1.37)) * opacity
		draw_line(Vector2(0.0, y), Vector2(size.x, y + sin(float(index) * 0.61) * 1.2), Color(0.60, 0.92, 0.66, alpha), 1.0, true)
	var vertical_count := int(size.x / (line_gap * 1.35))
	for index in range(vertical_count + 1):
		var x := float(index) * line_gap * 1.35
		var alpha := (0.0008 + 0.0005 * cos(float(index) * 1.19)) * opacity
		draw_line(Vector2(x, 0.0), Vector2(x + cos(float(index) * 0.57) * 1.0, size.y), Color(0.0, 0.10, 0.05, alpha), 1.0, true)


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_texture_cache[path] = texture
	return texture


func _draw_soft_panel_texture() -> void:
	var center := Vector2(size.x * 0.45, size.y * 0.38)
	var top_left := Vector2(size.x * 0.18, size.y * 0.18)
	var bottom_right := Vector2(size.x * 0.82, size.y * 0.80)
	var radius := maxf(size.x, size.y) * 0.58
	for band in range(5):
		var t := float(band) / 4.0
		draw_circle(center + Vector2(-size.x * 0.05, -size.y * 0.05), lerpf(radius * 0.18, radius * 0.58, t), Color(0.86, 0.98, 0.68, 0.028 * opacity * (1.0 - t)))
	for band in range(4):
		var t := float(band) / 3.0
		draw_circle(top_left, lerpf(radius * 0.05, radius * 0.24, t), Color(0.98, 1.0, 0.88, 0.034 * opacity * (1.0 - t)))
		draw_circle(bottom_right, lerpf(radius * 0.05, radius * 0.22, t), Color(0.0, 0.12, 0.06, 0.026 * opacity * (1.0 - t)))
	draw_rect(Rect2(Vector2(6.0, 5.0), Vector2(maxf(0.0, size.x - 12.0), 2.0)), Color(1.0, 1.0, 0.84, 0.045 * opacity), true)
	draw_rect(Rect2(Vector2(7.0, maxf(0.0, size.y - 8.0)), Vector2(maxf(0.0, size.x - 14.0), 4.0)), Color(0.0, 0.11, 0.05, 0.055 * opacity), true)
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(2.0, size.y)), Color(1.0, 1.0, 0.78, 0.015 * opacity), true)
	draw_rect(Rect2(Vector2(maxf(0.0, size.x - 2.0), 0.0), Vector2(2.0, size.y)), Color(0.0, 0.14, 0.07, 0.020 * opacity), true)
	var gloss_rect := Rect2(Vector2(9.0, 7.0), Vector2(maxf(0.0, size.x - 18.0), maxf(3.0, size.y * 0.22)))
	for band in range(5):
		var t := float(band) / 4.0
		var y := gloss_rect.position.y + gloss_rect.size.y * t
		draw_rect(
			Rect2(gloss_rect.position.x + t * 3.0, y, maxf(0.0, gloss_rect.size.x - t * 6.0), 2.0),
			Color(1.0, 1.0, 0.86, 0.030 * opacity * (1.0 - t)),
			true
		)
	var inset := minf(size.x, size.y) * 0.045
	var inner_rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	draw_rect(inner_rect, Color(1.0, 0.98, 0.78, 0.028 * opacity), false, 1.0, true)


func _draw_button_gloss_texture() -> void:
	var w := size.x
	var h := size.y
	var radius := minf(w, h) * 0.46
	var upper_center := Vector2(w * 0.34, h * 0.16)
	var lower_center := Vector2(w * 0.70, h * 0.88)
	for band in range(5):
		var t := float(band) / 4.0
		draw_circle(
			upper_center,
			lerpf(radius * 0.35, radius * 1.05, t),
			Color(1.0, 1.0, 0.82, 0.030 * opacity * (1.0 - t))
		)
	for band in range(4):
		var t := float(band) / 3.0
		draw_circle(
			lower_center,
			lerpf(radius * 0.34, radius * 0.96, t),
			Color(0.0, 0.08, 0.035, 0.030 * opacity * (1.0 - t))
		)
	var top_gloss := Rect2(Vector2(w * 0.15, h * 0.10), Vector2(w * 0.70, maxf(2.0, h * 0.10)))
	for band in range(4):
		var t := float(band) / 3.0
		draw_rect(
			Rect2(top_gloss.position.x + w * 0.025 * t, top_gloss.position.y + h * 0.035 * t, maxf(0.0, top_gloss.size.x - w * 0.050 * t), 2.0),
			Color(1.0, 1.0, 0.88, 0.044 * opacity * (1.0 - t)),
			true
		)
	draw_rect(Rect2(Vector2(w * 0.12, h * 0.08), Vector2(w * 0.76, h * 0.84)), Color(1.0, 0.97, 0.70, 0.034 * opacity), false, 1.0, true)
	draw_rect(Rect2(Vector2(w * 0.18, h - 5.0), Vector2(w * 0.64, 2.0)), Color(0.0, 0.10, 0.04, 0.052 * opacity), true)


func _draw_wood_texture() -> void:
	var rect := Rect2(Vector2(10.0, 8.0), size - Vector2(20.0, 16.0))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = Rect2(Vector2.ZERO, size)

	var grain_count := maxi(8, int(rect.size.y / 7.0))
	for index in range(grain_count):
		var t := float(index) / float(maxi(1, grain_count - 1))
		var y := lerpf(rect.position.y, rect.end.y, t)
		var alpha := (0.035 + 0.020 * sin(float(index) * 1.7)) * opacity
		var points := PackedVector2Array()
		var segments := 18
		for segment in range(segments + 1):
			var s := float(segment) / float(segments)
			var x := lerpf(rect.position.x, rect.end.x, s)
			var wave := sin(s * TAU * 2.2 + float(index) * 0.6) * 2.2
			wave += sin(s * TAU * 5.1 + float(index) * 0.27) * 0.8
			points.append(Vector2(x, y + wave))
		draw_polyline(points, Color(0.98, 0.76, 0.38, alpha), 2.0, true)

	for knot_index in range(3):
		var knot_center := Vector2(
			lerpf(rect.position.x + rect.size.x * 0.18, rect.end.x - rect.size.x * 0.12, float(knot_index) / 2.0),
			rect.position.y + rect.size.y * (0.28 + 0.18 * float(knot_index % 2))
		)
		var radius := minf(rect.size.x, rect.size.y) * (0.035 + 0.012 * float(knot_index))
		for ring in range(3):
			draw_arc(
				knot_center,
				radius + float(ring) * 4.0,
				0.0,
				TAU,
				36,
				Color(0.26, 0.15, 0.04, (0.028 - float(ring) * 0.005) * opacity),
				1.0,
				true
			)
