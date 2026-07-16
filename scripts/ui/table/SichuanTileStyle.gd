class_name SichuanTileStyle
extends RefCounted

const FACE_TOP := Color("FFF4D8")
const FACE_BOTTOM := Color("F2E4BD")
const FACE_WARMTH := Color("F4E9C9")
const FACE_HIGHLIGHT := Color(1.0, 0.985, 0.90, 0.74)
const FACE_INNER_SHADE := Color(0.24, 0.18, 0.10, 0.15)
const SIDE_LIGHT := Color("E5D6AA")
const SIDE_MID := Color("C4B386")
const SIDE_DARK := Color("8F7D58")
const BOTTOM_DEEP := Color("5E5039")
const BACK_TOP := Color("16704F")
const BACK_MID := Color("0D5A3E")
const BACK_BOTTOM := Color("0A4A3D")
const FACE_BORDER := Color("B7A477")
const BACK_BORDER := Color("3D8668")
const CONTACT_SHADOW := Color(0.0, 0.015, 0.010, 0.54)
const AMBIENT_SHADOW := Color(0.0, 0.020, 0.014, 0.26)
const INNER_HIGHLIGHT := Color(1.0, 0.985, 0.90, 0.62)
const LIGHT_SOURCE := Vector2(-1.0, -1.0)


static func side_color(show_back: bool) -> Color:
	return BACK_MID if show_back else SIDE_MID


static func bottom_color(show_back: bool) -> Color:
	return BACK_BOTTOM.darkened(0.28) if show_back else BOTTOM_DEEP


static func material_contract() -> Dictionary:
	return {
		"light_source": LIGHT_SOURCE,
		"face_highlight": FACE_HIGHLIGHT,
		"face_warmth": FACE_WARMTH,
		"side_mid": SIDE_MID,
		"bottom_deep": BOTTOM_DEEP,
		"contact_shadow": CONTACT_SHADOW,
		"back_finish": "matte_malachite_brocade",
		"depth_ratio": {"self": 0.064, "public": 0.052, "opponent": 0.044},
		"layers": ["ambient_shadow", "contact_shadow", "bottom_body", "side_body", "ivory_face", "bevel_highlight"],
	}
