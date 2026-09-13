class_name SichuanTableMetrics
extends RefCounted

const DESIGN_SIZE := Vector2(2048.0, 1152.0)
const COMPACT_HEIGHT := 820.0
const TOUCH_TARGET := Vector2(76.0, 76.0)
const BASE_SAFE_MARGIN := Vector4(24.0, 18.0, 24.0, 22.0)
const SEAT_HUD_STANDARD := Vector2(230.0, 200.0)
const SEAT_HUD_COMPACT := Vector2(214.0, 184.0)
const DING_QUE_STANDARD := Vector2(112.0, 48.0)
const DING_QUE_COMPACT := Vector2(104.0, 44.0)
const CENTER_INDICATOR_STANDARD := Vector2(210.0, 210.0)
const CENTER_INDICATOR_COMPACT := Vector2(174.0, 174.0)

# One reference contract owns the four seat rails and their identity plates.
# Keeping these rectangles together prevents the hand tracks, nameplates and
# table center from drifting apart as individual features are tuned.
const BOARD_REFERENCE_RECT := Rect2(304.0, 160.0, 1440.0, 710.0)
const SELF_HAND_REFERENCE_RECT := Rect2(20.0, 856.0, 2008.0, 290.0)
const OPPONENT_TRACK_REFERENCE_RECTS := {
	1: Rect2(126.0, 110.0, 390.0, 820.0),
	2: Rect2(250.0, 8.0, 1080.0, 160.0),
	3: Rect2(1532.0, 110.0, 390.0, 820.0),
}
const SEAT_HUD_REFERENCE_RECTS := {
	0: Rect2(24.0, 754.0, 218.0, 132.0),
	1: Rect2(24.0, 260.0, 218.0, 132.0),
	2: Rect2(1380.0, 24.0, 218.0, 132.0),
	3: Rect2(1806.0, 170.0, 218.0, 132.0),
}


static func layout_mode(viewport_size: Vector2) -> StringName:
	return &"compact" if viewport_size.y < COMPACT_HEIGHT else &"standard"


static func is_compact(viewport_size: Vector2) -> bool:
	return layout_mode(viewport_size) == &"compact"


static func content_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / DESIGN_SIZE.y, 0.82, 1.18)


static func touch_target() -> Vector2:
	return TOUCH_TARGET


static func seat_hud_size(compact: bool, viewport_size: Vector2 = DESIGN_SIZE) -> Vector2:
	var reference := SEAT_HUD_COMPACT if compact else SEAT_HUD_STANDARD
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return reference
	return reference * Vector2(
		maxf(1.0, viewport_size.x / DESIGN_SIZE.x),
		maxf(1.0, viewport_size.y / DESIGN_SIZE.y)
	)


static func ding_que_size(compact: bool) -> Vector2:
	return DING_QUE_COMPACT if compact else DING_QUE_STANDARD


static func center_indicator_size(compact: bool) -> Vector2:
	return CENTER_INDICATOR_COMPACT if compact else CENTER_INDICATOR_STANDARD


static func scale_reference_rect(viewport_size: Vector2, reference_rect: Rect2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return reference_rect
	var scale := Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	return Rect2(reference_rect.position * scale, reference_rect.size * scale)


static func board_rect(viewport_size: Vector2) -> Rect2:
	return scale_reference_rect(viewport_size, BOARD_REFERENCE_RECT)


static func self_hand_rect(viewport_size: Vector2) -> Rect2:
	return scale_reference_rect(viewport_size, SELF_HAND_REFERENCE_RECT)


static func opponent_track_rect(seat: int, viewport_size: Vector2) -> Rect2:
	var reference_rect: Rect2 = OPPONENT_TRACK_REFERENCE_RECTS.get(seat, Rect2())
	var track_rect := scale_reference_rect(viewport_size, reference_rect)
	if seat not in [1, 3]:
		return track_rect

	# The side hands and their nameplates share the same vertical center. Keep
	# the whole tile track on the table-facing side of the nameplate so centered
	# hands never sit underneath the HUD, including compact phone layouts.
	var scaled_hud_reference := scale_reference_rect(
		viewport_size,
		SEAT_HUD_REFERENCE_RECTS.get(seat, Rect2())
	)
	var hud_size := seat_hud_size(is_compact(viewport_size), viewport_size)
	var horizontal_scale := viewport_size.x / DESIGN_SIZE.x if viewport_size.x > 0.0 else 1.0
	var clearance := maxf(8.0, 12.0 * horizontal_scale)
	if seat == 1:
		track_rect.position.x = maxf(
			track_rect.position.x,
			scaled_hud_reference.position.x + hud_size.x + clearance
		)
	else:
		var right_margin := maxf(BASE_SAFE_MARGIN.z, viewport_size.x - scaled_hud_reference.end.x)
		var hud_left := viewport_size.x - right_margin - hud_size.x
		track_rect.position.x = minf(
			track_rect.position.x,
			hud_left - clearance - track_rect.size.x
		)
	return track_rect


static func seat_hud_rect(seat: int, viewport_size: Vector2) -> Rect2:
	var reference_rect: Rect2 = SEAT_HUD_REFERENCE_RECTS.get(seat, Rect2())
	var hud_size := seat_hud_size(is_compact(viewport_size), viewport_size)
	var scaled_reference := scale_reference_rect(viewport_size, reference_rect)
	if seat in [1, 3]:
		var side_x := scaled_reference.position.x
		if seat == 3:
			side_x = viewport_size.x - maxf(BASE_SAFE_MARGIN.z, viewport_size.x - scaled_reference.end.x) - hud_size.x
		return Rect2(Vector2(side_x, scaled_reference.position.y), hud_size)
	if seat == 0:
		var hand_rect := self_hand_rect(viewport_size)
		var vertical_scale := viewport_size.y / DESIGN_SIZE.y if viewport_size.y > 0.0 else 1.0
		return Rect2(Vector2(scaled_reference.position.x, hand_rect.position.y - hud_size.y + 56.0 * vertical_scale), hud_size)
	if seat == 2:
		return Rect2(scaled_reference.position, hud_size)
	return Rect2(scaled_reference.position, hud_size)


static func safe_margins(viewport_size: Vector2, safe_rect: Rect2) -> Vector4:
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return BASE_SAFE_MARGIN
	return Vector4(
		maxf(BASE_SAFE_MARGIN.x, safe_rect.position.x),
		maxf(BASE_SAFE_MARGIN.y, safe_rect.position.y),
		maxf(BASE_SAFE_MARGIN.z, viewport_size.x - safe_rect.end.x),
		maxf(BASE_SAFE_MARGIN.w, viewport_size.y - safe_rect.end.y)
	)


static func design_safe_margins(viewport_size: Vector2, display_size: Vector2, safe_rect: Rect2) -> Vector4:
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return BASE_SAFE_MARGIN
	var scale := Vector2(viewport_size.x / display_size.x, viewport_size.y / display_size.y)
	var mapped_rect := Rect2(safe_rect.position * scale, safe_rect.size * scale)
	return safe_margins(viewport_size, mapped_rect)
