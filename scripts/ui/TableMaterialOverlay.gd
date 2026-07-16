extends Control

class_name TableMaterialOverlay

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const CLUB_FELT_SHADER := preload("res://shaders/table_club_felt.gdshader")

enum MaterialMode {
	FELT,
	WOOD,
	SOFT_PANEL,
	BUTTON_GLOSS,
}

const FRAME_THICKNESS := 28.0
const BRASS_LINE_WIDTH := 2.0
const WOOD_DARK := TABLE_THEME.EBONY
const WOOD_MID := TABLE_THEME.LACQUER_BROWN
const BRASS := TABLE_THEME.AGED_COPPER

@export var material_mode: MaterialMode = MaterialMode.FELT:
	set(value):
		material_mode = value
		_sync_felt_shader_layer()
		queue_redraw()

@export var opacity: float = 1.0:
	set(value):
		opacity = clampf(value, 0.0, 1.0)
		_sync_felt_shader_layer()
		queue_redraw()

var _texture_cache: Dictionary = {}
var _felt_shader_layer: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_felt_shader_layer()


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
	# The opaque procedural shader below this draw pass owns the base color,
	# directional light and vignette.  This translucent wash binds the vector
	# brocade and frame to the same ink-jade material without recreating the old
	# circular hotspot.
	draw_rect(Rect2(Vector2.ZERO, size), Color(TABLE_THEME.INK_JADE_DEEP, 0.10 * opacity), true)

	var line_gap := maxf(12.0, minf(size.x, size.y) / 76.0)
	var horizontal_count := int(size.y / line_gap)
	for index in range(horizontal_count + 1):
		var y := float(index) * line_gap
		var alpha := (0.0008 + 0.0005 * sin(float(index) * 1.37)) * opacity
		draw_line(Vector2(0.0, y), Vector2(size.x, y + sin(float(index) * 0.61) * 1.2), Color(0.60, 0.92, 0.66, alpha), 1.0, true)
	var vertical_count := int(size.x / (line_gap * 1.35))
	for index in range(vertical_count + 1):
		var x := float(index) * line_gap * 1.35
		var alpha := (0.0006 + 0.0004 * cos(float(index) * 1.19)) * opacity
		draw_line(Vector2(x, 0.0), Vector2(x + cos(float(index) * 0.57) * 1.0, size.y), Color(0.0, 0.10, 0.05, alpha), 1.0, true)

	# A restrained woven diamond field breaks up the large empty green areas
	# without competing with tiles or HUD text.
	var weave_gap := maxf(54.0, minf(size.x, size.y) * 0.065)
	var diagonal_extent := size.x + size.y
	var diagonal_count := int(diagonal_extent / weave_gap)
	for index in range(-diagonal_count, diagonal_count + 1):
		var offset := float(index) * weave_gap
		draw_line(Vector2(offset, 0.0), Vector2(offset + size.y, size.y), Color(0.64, 0.76, 0.58, 0.014 * opacity), 1.0, true)
		draw_line(Vector2(offset, size.y), Vector2(offset + size.y, 0.0), Color(0.0, 0.10, 0.06, 0.020 * opacity), 1.0, true)
	_draw_brocade_field()
	_draw_table_frame()


func _draw_directional_spotlight() -> void:
	# Warm, asymmetric upper-left light.  Concentric polygons stay reliable on
	# the macOS Metal renderer while producing a clearly legible soft source.
	var center := Vector2(size.x * 0.25, size.y * 0.19)
	var radii := Vector2(size.x * 0.48, size.y * 0.56)
	for band in range(9):
		var t := float(band) / 8.0
		var scale := lerpf(1.0, 0.18, t)
		var alpha := lerpf(0.010, 0.040, t) * opacity
		draw_colored_polygon(_ellipse_points(center, radii * scale, 72), Color(0.82, 0.92, 0.62, alpha))
	# A cool lower-right falloff gives the felt depth rather than a flat green
	# fill, without covering tile faces.
	var shade_center := Vector2(size.x * 0.82, size.y * 0.78)
	for band in range(5):
		var t := float(band) / 4.0
		draw_colored_polygon(
			_ellipse_points(shade_center, Vector2(size.x * 0.40, size.y * 0.42) * lerpf(1.0, 0.28, t), 64),
			Color(0.0, 0.055, 0.035, lerpf(0.010, 0.030, t) * opacity)
		)


func _ellipse_points(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _draw_brocade_field() -> void:
	var motif_color := Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.020 * opacity)
	var shadow_color := Color(0.0, 0.10, 0.065, 0.032 * opacity)
	var cell := maxf(76.0, minf(size.x, size.y) * 0.082)
	var columns := int(size.x / cell) + 1
	var rows := int(size.y / cell) + 1
	for row in range(rows):
		for column in range(columns):
			var center := Vector2((float(column) + 0.5) * cell, (float(row) + 0.5) * cell)
			if row % 2 == 1:
				center.x += cell * 0.5
			var radius := cell * 0.16
			draw_arc(center, radius, 0.16, PI - 0.16, 18, motif_color, 1.2, true)
			draw_arc(center, radius, PI + 0.16, TAU - 0.16, 18, shadow_color, 1.0, true)
			draw_arc(center, radius * 0.55, -PI * 0.34, PI * 0.34, 12, motif_color, 1.0, true)

	var playfield := Rect2(Vector2(size.x * 0.205, size.y * 0.155), Vector2(size.x * 0.59, size.y * 0.61))
	if playfield.size.x > 60.0 and playfield.size.y > 60.0:
		draw_rect(playfield, Color(TABLE_THEME.AGED_COPPER, 0.080 * opacity), false, 1.2, true)
		draw_rect(playfield.grow(-8.0), Color(0.42, 0.56, 0.39, 0.034 * opacity), false, 1.0, true)


func _draw_table_frame() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	var frame_fill := Color(WOOD_DARK, 0.995 * opacity)
	draw_rect(Rect2(0.0, 0.0, size.x, FRAME_THICKNESS), frame_fill, true)
	draw_rect(Rect2(0.0, size.y - FRAME_THICKNESS, size.x, FRAME_THICKNESS), frame_fill, true)
	draw_rect(Rect2(0.0, FRAME_THICKNESS, FRAME_THICKNESS, size.y - FRAME_THICKNESS * 2.0), frame_fill, true)
	draw_rect(Rect2(size.x - FRAME_THICKNESS, FRAME_THICKNESS, FRAME_THICKNESS, size.y - FRAME_THICKNESS * 2.0), frame_fill, true)
	var inner_wood := Color(WOOD_MID, 0.94 * opacity)
	draw_rect(Rect2(FRAME_THICKNESS - 9.0, FRAME_THICKNESS - 9.0, size.x - (FRAME_THICKNESS - 9.0) * 2.0, size.y - (FRAME_THICKNESS - 9.0) * 2.0), inner_wood, false, 7.0, true)
	draw_rect(outer, Color(WOOD_DARK, 0.98 * opacity), false, FRAME_THICKNESS, true)
	var wood_highlight := Rect2(Vector2(FRAME_THICKNESS * 0.38, FRAME_THICKNESS * 0.38), size - Vector2.ONE * FRAME_THICKNESS * 0.76)
	draw_rect(wood_highlight, Color(WOOD_MID, 0.88 * opacity), false, maxf(3.0, FRAME_THICKNESS * 0.34), true)
	var outer_brass := Rect2(Vector2(FRAME_THICKNESS * 0.22, FRAME_THICKNESS * 0.22), size - Vector2.ONE * FRAME_THICKNESS * 0.44)
	draw_rect(outer_brass, Color(TABLE_THEME.COPPER_SHADOW, 0.78 * opacity), false, 1.0, true)
	var brass_rect := Rect2(Vector2(FRAME_THICKNESS, FRAME_THICKNESS), size - Vector2.ONE * FRAME_THICKNESS * 2.0)
	if brass_rect.size.x > 0.0 and brass_rect.size.y > 0.0:
		draw_rect(brass_rect, Color(BRASS, 0.82 * opacity), false, BRASS_LINE_WIDTH, true)
		var inner_rail := brass_rect.grow(-5.0)
		draw_rect(inner_rail, Color(0.82, 0.69, 0.35, 0.24 * opacity), false, 1.0, true)
		for corner in [inner_rail.position + Vector2(8.0, 8.0), Vector2(inner_rail.end.x - 8.0, inner_rail.position.y + 8.0), Vector2(inner_rail.position.x + 8.0, inner_rail.end.y - 8.0), inner_rail.end - Vector2(8.0, 8.0)]:
			draw_circle(corner, 2.2, Color(BRASS.lightened(0.18), 0.64 * opacity))
		_draw_shu_corner_motifs(inner_rail)
		_draw_carved_corner_caps()


func _sync_felt_shader_layer() -> void:
	if not is_inside_tree():
		return
	if material_mode != MaterialMode.FELT:
		if _felt_shader_layer != null:
			_felt_shader_layer.visible = false
		return
	if _felt_shader_layer == null:
		_felt_shader_layer = ColorRect.new()
		_felt_shader_layer.name = "ClubFeltShader"
		_felt_shader_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_felt_shader_layer.offset_left = 0.0
		_felt_shader_layer.offset_top = 0.0
		_felt_shader_layer.offset_right = 0.0
		_felt_shader_layer.offset_bottom = 0.0
		_felt_shader_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_felt_shader_layer.show_behind_parent = true
		_felt_shader_layer.color = Color.WHITE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = CLUB_FELT_SHADER
		_felt_shader_layer.material = shader_material
		add_child(_felt_shader_layer)
	_felt_shader_layer.visible = true
	var shader_material := _felt_shader_layer.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("brocade_opacity", 0.055 * opacity)
		shader_material.set_shader_parameter("weave_opacity", 0.040 * opacity)
		shader_material.set_shader_parameter("vignette_strength", 0.42 * opacity)
		shader_material.set_shader_parameter("light_strength", 0.105 * opacity)


func _draw_carved_corner_caps() -> void:
	var base_points := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(122.0, 0.0), Vector2(110.0, 13.0),
		Vector2(88.0, 13.0), Vector2(80.0, 25.0), Vector2(61.0, 25.0),
		Vector2(51.0, 38.0), Vector2(51.0, 59.0), Vector2(38.0, 72.0),
		Vector2(24.0, 72.0), Vector2(14.0, 86.0), Vector2(0.0, 98.0),
	])
	for flip in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]:
		var origin := Vector2(0.0 if flip.x > 0.0 else size.x, 0.0 if flip.y > 0.0 else size.y)
		var points := PackedVector2Array()
		for point in base_points:
			points.append(origin + point * flip)
		draw_colored_polygon(points, Color(WOOD_DARK.darkened(0.12), 0.985 * opacity))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(TABLE_THEME.AGED_COPPER, 0.82 * opacity), 2.0, true)
		var curl_center := origin + Vector2(30.0 * flip.x, 30.0 * flip.y)
		var start_angle := 0.0 if flip.x * flip.y > 0.0 else PI
		draw_arc(curl_center, 14.0, start_angle, start_angle + PI * 1.55, 20, Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.62 * opacity), 1.6, true)
		draw_arc(curl_center, 7.0, start_angle + 0.35, start_angle + PI * 1.45, 16, Color(TABLE_THEME.AGED_COPPER, 0.46 * opacity), 1.2, true)


func _draw_shu_corner_motifs(rect: Rect2) -> void:
	var color := Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.76 * opacity)
	var inner_color := Color(TABLE_THEME.AGED_COPPER, 0.48 * opacity)
	var length := minf(82.0, minf(rect.size.x, rect.size.y) * 0.13)
	var cut := minf(22.0, length * 0.34)
	var corners := [
		{"p": rect.position + Vector2(5.0, 5.0), "sx": 1.0, "sy": 1.0},
		{"p": Vector2(rect.end.x - 5.0, rect.position.y + 5.0), "sx": -1.0, "sy": 1.0},
		{"p": Vector2(rect.position.x + 5.0, rect.end.y - 5.0), "sx": 1.0, "sy": -1.0},
		{"p": rect.end - Vector2(5.0, 5.0), "sx": -1.0, "sy": -1.0},
	]
	for corner_data in corners:
		var p: Vector2 = corner_data["p"]
		var sx := float(corner_data["sx"])
		var sy := float(corner_data["sy"])
		var points := PackedVector2Array([
			p + Vector2(0.0, sy * length),
			p + Vector2(0.0, sy * cut),
			p + Vector2(sx * cut, 0.0),
			p + Vector2(sx * length, 0.0),
		])
		draw_polyline(points, color, 2.2, true)
		var inner_p := p + Vector2(sx * 8.0, sy * 8.0)
		var inner_points := PackedVector2Array([
			inner_p + Vector2(0.0, sy * (length * 0.58)),
			inner_p + Vector2(0.0, sy * (cut * 0.72)),
			inner_p + Vector2(sx * (cut * 0.72), 0.0),
			inner_p + Vector2(sx * (length * 0.58), 0.0),
		])
		draw_polyline(inner_points, inner_color, 1.4, true)
		draw_line(
			p + Vector2(sx * cut, sy * 2.0),
			p + Vector2(sx * 2.0, sy * cut),
			Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.56 * opacity),
			1.4,
			true
		)


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
