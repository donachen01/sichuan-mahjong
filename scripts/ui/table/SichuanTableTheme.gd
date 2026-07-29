class_name SichuanTableTheme
extends RefCounted

const TABLE_CENTER := Color("167A64")
const TABLE_BASE := Color("0F6957")
const TABLE_EDGE := Color("0A4B41")
const LEATHER_RAIL := Color("172621")
const WALNUT_DARK := Color("281F1B")
const AGED_COPPER := Color("9D743A")
const COPPER_HIGHLIGHT := Color("C49A55")
const IVORY_TEXT := Color("F2EBDD")
const SECONDARY_TEXT := Color("C9C6BC")
const POSITIVE_SCORE := Color("E8C96A")
const NEGATIVE_SCORE := Color("E38B7F")
const SOURCE_ARROW_BLUE := Color("43A7E8")
const PENG_CYAN_JADE := Color("2C9B8A")
const GANG_GOLD_BROWN := AGED_COPPER
const HU_CINNABAR := Color("B84236")
const PASS_MUTED := Color("53645E")

# Compatibility names remain while shared components migrate to the named V2
# tokens.  They intentionally resolve to the Deep Emerald palette, not blue.
const INK_JADE_DEEP := TABLE_EDGE
const MALACHITE := TABLE_BASE
const MOSS_GLOW := TABLE_CENTER
const EBONY := LEATHER_RAIL
const LACQUER_BROWN := WALNUT_DARK
const PANEL_JADE_BLACK := Color("102F29")
const WARM_CERAMIC := IVORY_TEXT
const JADE_SIDE := Color("2B9131")
const COPPER_MID := AGED_COPPER
const COPPER_SHADOW := Color("6F4E29")
const CINNABAR := HU_CINNABAR
const INDIGO := SOURCE_ARROW_BLUE
const MIST_GREEN := SECONDARY_TEXT

const FELT_DEEP := INK_JADE_DEEP
const FELT_BASE := MALACHITE
const FELT_LIGHT := MOSS_GLOW
const WOOD_DARK := EBONY
const WOOD_MID := LACQUER_BROWN
const BRASS := AGED_COPPER
const IVORY := WARM_CERAMIC
const TEXT_PRIMARY := IVORY_TEXT
const TEXT_SECONDARY := SECONDARY_TEXT
const WAN_QUE := Color("EA5146")
const TONG_QUE := Color("F6B73B")
const TIAO_QUE := Color("24B87A")

const RADIUS_STATUS := 4
const RADIUS_CHIP := 8
const RADIUS_NAMEPLATE := 12
const RADIUS_SURFACE := 20


static func brand_contract() -> Dictionary:
	return {
		"name": "深翡翠雅局",
		"direction": "deep_emerald_refined_noncommercial_mahjong",
		"shape_motif": "shu_courtyard_cut_corner",
		"materials": ["deep_emerald_short_nap_felt", "ink_green_leather", "black_walnut", "warm_ivory_tiles"],
		"accent_material": "aged_copper",
		"light_direction": "top_left_315_degrees",
		"visual_hierarchy": ["tiles", "actions_and_key_text", "player_panels", "brocade_frame_ornament"],
		"background_role": "atmosphere_only",
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
	style.bg_color = Color(PANEL_JADE_BLACK, 0.94 if active else 0.84)
	style.border_color = Color(COPPER_HIGHLIGHT if active else COPPER_SHADOW, 0.88 if active else 0.52)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(RADIUS_NAMEPLATE)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.015, 0.010, 0.48 if active else 0.36)
	style.shadow_size = 9 if active else 6
	style.shadow_offset = Vector2(4.0, 6.0)
	style.anti_aliasing = true
	return style


static func make_badge_style(suit: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Keep even the naturally bright 筒 amber behind 28px ivory copy above the
	# WCAG large-text threshold. The hue still identifies the suit; the written
	# 缺万/缺筒/缺条 label remains the primary, non-colour-only state cue.
	style.bg_color = ding_que_color(suit).darkened(0.36)
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
			style.bg_color = HU_CINNABAR.darkened(0.18)
			style.border_color = COPPER_HIGHLIGHT
		"gang":
			style.bg_color = Color("293125")
			style.border_color = Color(COPPER_MID, 0.88)
		"peng":
			style.bg_color = PENG_CYAN_JADE.darkened(0.24)
			style.border_color = COPPER_HIGHLIGHT
		_:
			style.bg_color = PASS_MUTED.darkened(0.30)
			style.border_color = Color(AGED_COPPER, 0.82)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.18)
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
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
