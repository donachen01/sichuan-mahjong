class_name SeatAvatarMedallion
extends Control

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")

var seat := 0
var active := false
var won := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(seat_value: int, active_value: bool, won_value: bool) -> void:
	seat = clampi(seat_value, 0, 3)
	active = active_value
	won = won_value
	queue_redraw()


func get_visual_contract() -> Dictionary:
	return {
		"identity_surface": "original_jade_seal_medallion",
		"seat_shape_encoding": true,
		"active_ring": "aged_copper_double_ring",
		"portrait_replaceable": true,
	}


func _draw() -> void:
	if size.x <= 4.0 or size.y <= 4.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var palette := _seat_palette()

	# Contact shadow and a shallow jade cabochon. Multiple opaque rings avoid
	# transparency sorting and still read as a softly rounded mobile-game avatar.
	draw_circle(center + Vector2(3.0, 5.0), radius + 2.0, Color(0.0, 0.015, 0.01, 0.46))
	draw_circle(center, radius + 2.0, Color(TABLE_THEME.COPPER_SHADOW, 0.92))
	draw_circle(center, radius, Color(palette[0], 0.98))
	for band in range(7):
		var t := float(band) / 6.0
		var band_radius := lerpf(radius * 0.84, radius * 0.24, t)
		var band_center := center + Vector2(-radius * 0.13, -radius * 0.16) * (1.0 - t)
		draw_circle(band_center, band_radius, Color(palette[1].lightened(0.08 * t), 0.055 + 0.025 * t))

	_draw_seat_motif(center, radius, palette[2])
	draw_arc(center, radius - 3.0, 0.0, TAU, 48, Color(1.0, 0.96, 0.76, 0.23), 1.2, true)
	draw_arc(center + Vector2(-radius * 0.07, -radius * 0.08), radius * 0.72, PI * 1.08, PI * 1.72, 24, Color(1.0, 1.0, 0.90, 0.28), 2.0, true)

	if active:
		draw_arc(center, radius + 3.0, 0.0, TAU, 56, Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.98), 3.0, true)
		draw_arc(center, radius + 6.0, -PI * 0.18, PI * 0.64, 28, Color(1.0, 0.90, 0.48, 0.74), 2.0, true)
	else:
		draw_arc(center, radius + 3.0, 0.0, TAU, 56, Color(TABLE_THEME.AGED_COPPER, 0.42), 1.5, true)

	if won:
		draw_circle(center, radius - 1.0, Color(0.02, 0.035, 0.03, 0.44))
		var stamp_radius := radius * 0.24
		draw_circle(center + Vector2(radius * 0.52, radius * 0.48), stamp_radius, Color(TABLE_THEME.CINNABAR, 0.96))
		draw_arc(center + Vector2(radius * 0.52, radius * 0.48), stamp_radius, 0.0, TAU, 24, Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.88), 1.5, true)


func _seat_palette() -> Array[Color]:
	match seat:
		0:
			return [Color("0D5A3E"), Color("37A777"), Color("E5C46F")]
		1:
			return [Color("183C49"), Color("397B86"), Color("D9BE76")]
		2:
			return [Color("4A3427"), Color("8F6747"), Color("E9C77C")]
		3:
			return [Color("492C43"), Color("8B5B79"), Color("E6BE78")]
		_:
			return [Color("0D5A3E"), Color("37A777"), Color("E5C46F")]


func _draw_seat_motif(center: Vector2, radius: float, color: Color) -> void:
	var ink := Color(color, 0.20)
	match seat:
		0:
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius * 0.66),
				center + Vector2(radius * 0.66, 0.0),
				center + Vector2(0.0, radius * 0.66),
				center + Vector2(-radius * 0.66, 0.0),
				center + Vector2(0.0, -radius * 0.66),
			])
			draw_polyline(diamond, ink, 1.6, true)
		1:
			for offset in [-0.26, 0.0, 0.26]:
				draw_arc(center + Vector2(radius * offset, 0.0), radius * 0.34, PI, TAU, 18, ink, 1.5, true)
		2:
			for ring in range(3):
				draw_arc(center, radius * (0.30 + float(ring) * 0.16), 0.0, TAU, 32, Color(ink, ink.a * (1.0 - float(ring) * 0.18)), 1.4, true)
		3:
			var step := radius * 0.22
			for index in range(-2, 3):
				draw_line(center + Vector2(-radius * 0.56, float(index) * step), center + Vector2(radius * 0.56, float(index) * step + step), ink, 1.2, true)
