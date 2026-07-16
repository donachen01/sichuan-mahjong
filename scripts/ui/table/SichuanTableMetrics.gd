class_name SichuanTableMetrics
extends RefCounted

const DESIGN_SIZE := Vector2(2048.0, 1152.0)
const COMPACT_HEIGHT := 820.0
const TOUCH_TARGET := Vector2(76.0, 76.0)
const BASE_SAFE_MARGIN := Vector4(24.0, 18.0, 24.0, 22.0)
const SEAT_HUD_STANDARD := Vector2(238.0, 142.0)
const SEAT_HUD_COMPACT := Vector2(198.0, 118.0)
const DING_QUE_STANDARD := Vector2(112.0, 48.0)
const DING_QUE_COMPACT := Vector2(104.0, 44.0)
const CENTER_INDICATOR_STANDARD := Vector2(210.0, 210.0)
const CENTER_INDICATOR_COMPACT := Vector2(174.0, 174.0)


static func layout_mode(viewport_size: Vector2) -> StringName:
	return &"compact" if viewport_size.y < COMPACT_HEIGHT else &"standard"


static func is_compact(viewport_size: Vector2) -> bool:
	return layout_mode(viewport_size) == &"compact"


static func content_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / DESIGN_SIZE.y, 0.82, 1.18)


static func touch_target() -> Vector2:
	return TOUCH_TARGET


static func seat_hud_size(compact: bool) -> Vector2:
	return SEAT_HUD_COMPACT if compact else SEAT_HUD_STANDARD


static func ding_que_size(compact: bool) -> Vector2:
	return DING_QUE_COMPACT if compact else DING_QUE_STANDARD


static func center_indicator_size(compact: bool) -> Vector2:
	return CENTER_INDICATOR_COMPACT if compact else CENTER_INDICATOR_STANDARD


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
