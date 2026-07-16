class_name SichuanTableTheme
extends RefCounted

const INK_JADE_DEEP := Color("052820")
const MALACHITE := Color("0B3F34")
const MOSS_GLOW := Color("123F35")
const EBONY := Color("031815")
const LACQUER_BROWN := Color("0A2B24")
const WARM_CERAMIC := Color("F4E9C9")
const JADE_SIDE := Color("0D5A3E")
const AGED_COPPER := Color("A8793A")
const COPPER_HIGHLIGHT := Color("C59A58")
const COPPER_MID := Color("B99655")
const COPPER_SHADOW := Color("7A522C")
const CINNABAR := Color("7A2B25")
const INDIGO := Color("122B36")
const MIST_GREEN := Color("82948A")

const FELT_DEEP := INK_JADE_DEEP
const FELT_BASE := MALACHITE
const FELT_LIGHT := MOSS_GLOW
const WOOD_DARK := EBONY
const WOOD_MID := LACQUER_BROWN
const BRASS := AGED_COPPER
const IVORY := WARM_CERAMIC
const TEXT_PRIMARY := Color("F4E9C9")
const TEXT_SECONDARY := Color("D8C49A")
const WAN_QUE := Color("8E2F33")
const TONG_QUE := Color("315A8C")
const TIAO_QUE := Color("247A68")

const RADIUS_STATUS := 4
const RADIUS_CHIP := 8
const RADIUS_NAMEPLATE := 12
const RADIUS_SURFACE := 20


static func brand_contract() -> Dictionary:
	return {
		"name": "蜀锦玉案",
		"direction": "modern_oriental_craftsmanship",
		"shape_motif": "shu_courtyard_cut_corner",
		"materials": ["ink_jade_felt", "ebony_lacquer", "warm_ceramic_and_jade"],
		"accent_material": "aged_copper",
		"light_direction": "top_left_315_degrees",
		"radius_tokens": [RADIUS_STATUS, RADIUS_CHIP, RADIUS_NAMEPLATE, RADIUS_SURFACE],
	}


static func ding_que_color(suit: String) -> Color:
	match suit:
		"wan":
			return WAN_QUE
		"tong":
			return TONG_QUE
		"tiao":
			return TIAO_QUE
		_:
			return Color("3D5149")


static func ding_que_text(suit: String) -> String:
	match suit:
		"wan":
			return "缺万"
		"tong":
			return "缺筒"
		"tiao":
			return "缺条"
		_:
			return ""


static func font_size(role: String, compact: bool = false) -> int:
	match role:
		"player_name":
			return 26 if compact else 30
		"score":
			return 28 if compact else 32
		"ding_que":
			return 26 if compact else 28
		"utility":
			return 28 if compact else 32
		"center_count":
			return 52 if compact else 64
		"center_caption":
			return 22 if compact else 26
		"action_primary":
			return 50 if compact else 58
		"action_secondary":
			return 44 if compact else 50
		_:
			return 24 if compact else 28


static func make_panel_style(active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(EBONY, 0.10 if active else 0.06)
	style.border_color = Color(COPPER_SHADOW, 0.18 if active else 0.10)
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_NAMEPLATE)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.015, 0.010, 0.20)
	style.shadow_size = 4
	style.shadow_offset = Vector2(3.0, 4.0)
	style.anti_aliasing = true
	return style


static func make_badge_style(suit: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ding_que_color(suit).darkened(0.26)
	style.border_color = Color(COPPER_MID, 0.88)
	style.set_border_width_all(2)
	style.corner_radius_top_left = RADIUS_CHIP
	style.corner_radius_top_right = RADIUS_STATUS
	style.corner_radius_bottom_left = RADIUS_STATUS
	style.corner_radius_bottom_right = RADIUS_CHIP
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.0, 0.015, 0.01, 0.48)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3.0, 4.0)
	return style


static func make_utility_style(danger: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211713") if danger else Color(EBONY, 0.94)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.18)
	style.border_color = Color(AGED_COPPER, 0.72 if not danger else 0.58)
	style.set_border_width_all(1)
	style.corner_radius_top_left = RADIUS_NAMEPLATE
	style.corner_radius_top_right = RADIUS_STATUS
	style.corner_radius_bottom_left = RADIUS_STATUS
	style.corner_radius_bottom_right = RADIUS_NAMEPLATE
	style.shadow_color = Color(0.0, 0.015, 0.01, 0.32)
	style.shadow_size = 4 if not pressed else 1
	style.shadow_offset = Vector2(3.0, 4.0 if not pressed else 2.0)
	return style


static func make_action_style(action: String, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match action:
		"hu":
			style.bg_color = Color("0D5A3E")
			style.border_color = COPPER_HIGHLIGHT
		"gang":
			style.bg_color = Color("102832")
			style.border_color = Color(COPPER_MID, 0.88)
		"peng":
			style.bg_color = Color("0D5A3E")
			style.border_color = COPPER_HIGHLIGHT
		_:
			style.bg_color = Color("211A16")
			style.border_color = Color(AGED_COPPER, 0.82)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.18)
	style.border_width_top = 3 if action != "pass" else 2
	style.border_width_left = 3 if action != "pass" else 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.corner_radius_top_left = RADIUS_NAMEPLATE
	style.corner_radius_top_right = RADIUS_STATUS
	style.corner_radius_bottom_left = RADIUS_STATUS
	style.corner_radius_bottom_right = RADIUS_NAMEPLATE
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	style.shadow_color = Color(0.0, 0.012, 0.008, 0.58)
	style.shadow_size = 10 if not pressed else 3
	style.shadow_offset = Vector2(5.0, 7.0 if not pressed else 2.0)
	style.content_margin_top = 2.0 if not pressed else 6.0
	return style


static func make_seat_rail_style(primary: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(EBONY, 0.58 if primary else 0.42)
	style.border_color = Color(AGED_COPPER, 0.34 if primary else 0.22)
	style.set_border_width_all(1)
	style.corner_radius_top_left = RADIUS_NAMEPLATE
	style.corner_radius_top_right = RADIUS_STATUS
	style.corner_radius_bottom_left = RADIUS_STATUS
	style.corner_radius_bottom_right = RADIUS_NAMEPLATE
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0.0, 0.015, 0.01, 0.28)
	style.shadow_size = 5
	style.shadow_offset = Vector2(3.0, 4.0)
	return style


static func make_hand_rack_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15120F")
	style.border_color = Color(AGED_COPPER, 0.62)
	style.border_width_top = 2
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = RADIUS_NAMEPLATE
	style.corner_radius_top_right = RADIUS_STATUS
	style.corner_radius_bottom_left = RADIUS_STATUS
	style.corner_radius_bottom_right = RADIUS_NAMEPLATE
	style.shadow_color = Color(0.0, 0.015, 0.01, 0.46)
	style.shadow_size = 9
	style.shadow_offset = Vector2(5.0, 7.0)
	return style
