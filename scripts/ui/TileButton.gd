extends Button

class_name TileButton

const TILE_SIZE := Vector2(88, 124)
const DEFAULT_BG := Color(1.0, 1.0, 1.0, 0.0)
const SELECTED_BG := Color(1.0, 0.97, 0.78, 0.14)
const DISABLED_BG := Color(0.18, 0.18, 0.18, 0.14)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.0)
const HOVER_BORDER := Color(1.0, 1.0, 1.0, 0.28)
const PRESSED_BORDER := Color(0.98, 0.92, 0.68, 0.72)
const HIGHLIGHT_BORDER := Color(1.0, 0.78, 0.18, 1.0)
const HIGHLIGHT_BG := Color(1.0, 0.98, 0.88, 1.0)
const TILE_FACE_BG := Color(1.0, 1.0, 1.0, 1.0)
const TILE_FACE_BORDER := Color(0.878, 0.878, 0.878, 1.0)
const TILE_FACE_BORDER_HAND := Color(0.878, 0.878, 0.878, 1.0)
const TILE_FACE_TOP_HIGHLIGHT := Color(0.961, 0.961, 0.961, 0.80)
const TILE_FACE_TOP_CLEAR := Color(1.0, 1.0, 1.0, 0.0)
const TILE_SELECTED_BLUE := Color(0.337, 0.620, 1.0, 1.0)
const TILE_ART_DIR := "res://res/art/tiles"

var tile_id: int = -1
var tile_data: Dictionary = {}
var is_selected: bool = false
var is_new_draw: bool = false
var tile_scale_factor: float = 1.0
var is_display_only: bool = false
var show_back: bool = false
var display_rotation_degrees: float = 0.0
var display_profile: String = "table"

var tile_texture: TextureRect
var number_label: Label
var suit_label: Label

static var texture_cache: Dictionary = {}
static var profile_texture_cache: Dictionary = {}


func _ready() -> void:
	_ensure_label_refs()
	_configure_texture_rect()
	custom_minimum_size = _tile_minimum_size()
	flat = true
	clip_text = false
	text = ""
	_update_visual()


func configure(tile: Dictionary, selectable: bool, selected: bool, new_draw: bool = false, scale_factor: float = 1.0, display_only: bool = false, should_show_back: bool = false, rotation_degrees_value: float = 0.0, profile_value: String = "table") -> void:
	_ensure_label_refs()
	tile_data = tile
	tile_id = tile.get("id", -1)
	is_selected = selected
	is_new_draw = new_draw
	tile_scale_factor = scale_factor
	is_display_only = display_only
	show_back = should_show_back
	display_rotation_degrees = rotation_degrees_value
	display_profile = profile_value
	_configure_texture_rect()
	custom_minimum_size = _tile_minimum_size()
	disabled = not selectable and not is_display_only
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_display_only else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE if is_display_only else Control.FOCUS_ALL
	number_label.text = str(tile.get("rank", "?"))
	suit_label.text = _suit_symbol(tile.get("suit", ""))
	_update_visual()


func _ensure_label_refs() -> void:
	if tile_texture == null:
		tile_texture = get_node_or_null("%TileTexture")
	if number_label == null:
		number_label = get_node_or_null("%NumberLabel")
	if suit_label == null:
		suit_label = get_node_or_null("%SuitLabel")


func _configure_texture_rect() -> void:
	if tile_texture == null:
		return
	tile_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile_texture.offset_left = 0.0
	tile_texture.offset_top = 0.0
	tile_texture.offset_right = 0.0
	tile_texture.offset_bottom = 0.0
	tile_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if display_profile == "hand":
		var vertical_adjust := _hand_vertical_adjust()
		tile_texture.offset_top = vertical_adjust
		tile_texture.offset_bottom = vertical_adjust


func _suit_symbol(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return "?"


func _suit_color(suit: String) -> Color:
	match suit:
		"tiao":
			return Color(0.06, 0.45, 0.18, 1.0)
		"tong":
			return Color(0.08, 0.25, 0.72, 1.0)
		"wan":
			return Color(0.72, 0.12, 0.12, 1.0)
		_:
			return Color(0.15, 0.15, 0.15, 1.0)


func _update_visual() -> void:
	var has_texture := _apply_tile_texture()
	var border_width := _border_width_for_state()
	var normal_style := _create_stylebox(_background_color_for_state(has_texture), _border_color_for_state(has_texture), border_width, has_texture)
	var hover_style := _create_stylebox(_hover_background_color(has_texture), _hover_border_color(has_texture), border_width, has_texture)
	var pressed_style := _create_stylebox(_pressed_background_color(has_texture), _pressed_border_color(has_texture), border_width, has_texture)
	var disabled_style := _create_stylebox(DISABLED_BG if has_texture else Color(0.78, 0.78, 0.78, 1.0), _disabled_border_color(has_texture), 1.0, has_texture)

	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_stylebox_override("focus", hover_style)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))

	var suit_color := _suit_color(tile_data.get("suit", ""))
	number_label.visible = not has_texture
	suit_label.visible = not has_texture
	number_label.add_theme_color_override("font_color", suit_color)
	number_label.add_theme_color_override("font_disabled_color", Color(0.32, 0.32, 0.32, 0.9))
	number_label.add_theme_font_size_override("font_size", int(round(28 * tile_scale_factor)))
	suit_label.add_theme_color_override("font_color", suit_color.darkened(0.08))
	suit_label.add_theme_color_override("font_disabled_color", Color(0.32, 0.32, 0.32, 0.9))
	suit_label.add_theme_font_size_override("font_size", int(round(20 * tile_scale_factor)))
	rotation_degrees = display_rotation_degrees
	pivot_offset = custom_minimum_size * 0.5

	if is_selected and not is_display_only:
		position.y = -12.0 * tile_scale_factor
	else:
		position.y = 0.0
	queue_redraw()


func _draw() -> void:
	if not _uses_mahjong_shell():
		return
	var width := size.x
	var highlight_height := maxf(12.0, 18.0 * tile_scale_factor)
	var band_count := 7
	for index in range(band_count):
		var t := float(index) / float(maxi(1, band_count - 1))
		var color := TILE_FACE_TOP_HIGHLIGHT.lerp(TILE_FACE_TOP_CLEAR, t)
		var y := t * highlight_height
		draw_rect(Rect2(2.0, y + 2.0, maxf(1.0, width - 4.0), highlight_height / float(band_count) + 1.0), color, true)
	if is_selected:
		var bar_height := maxf(4.0, 5.0 * tile_scale_factor)
		draw_rect(Rect2(2.0, 2.0, maxf(1.0, width - 4.0), bar_height), TILE_SELECTED_BLUE, true)


func _tile_minimum_size() -> Vector2:
	var scaled_size := TILE_SIZE * tile_scale_factor
	if display_profile == "hand":
		scaled_size.x *= 1.12
		scaled_size.y *= 0.98
	if is_equal_approx(absf(fmod(display_rotation_degrees, 180.0)), 90.0):
		return Vector2(scaled_size.y, scaled_size.x)
	return scaled_size


func _hand_vertical_adjust() -> float:
	return 0.0


func _hand_crop_profile() -> Dictionary:
	match str(tile_data.get("suit", "")):
		"tong":
			return {
				"left": 0.31,
				"right": 0.17,
				"top": 0.05,
				"bottom": 0.015,
			}
		"tiao":
			return {
				"left": 0.29,
				"right": 0.16,
				"top": 0.03,
				"bottom": 0.01,
			}
		"wan":
			return {
				"left": 0.27,
				"right": 0.15,
				"top": 0.02,
				"bottom": 0.01,
			}
		_:
			return {
				"left": 0.28,
				"right": 0.18,
				"top": 0.02,
				"bottom": 0.01,
			}


func _apply_tile_texture() -> bool:
	if tile_texture == null:
		return false
	var texture := _resolve_tile_texture()
	tile_texture.texture = texture
	tile_texture.visible = texture != null
	tile_texture.modulate = Color(1.0, 1.0, 1.0, 0.9) if disabled else Color(1.0, 1.0, 1.0, 1.0)
	return texture != null


func _background_color_for_state(has_texture: bool) -> Color:
	if disabled:
		return Color(TILE_FACE_BG, 0.92) if has_texture else Color(0.88, 0.88, 0.88, 1.0)
	if is_new_draw:
		return TILE_FACE_BG if has_texture else HIGHLIGHT_BG
	if is_selected:
		return TILE_FACE_BG if has_texture else Color(1.0, 0.97, 0.78, 1.0)
	return TILE_FACE_BG if has_texture else Color(0.95, 0.92, 0.84, 1.0)


func _hover_background_color(has_texture: bool) -> Color:
	if has_texture:
		return _background_color_for_state(true)
	return _background_color_for_state(false).lightened(0.04)


func _pressed_background_color(has_texture: bool) -> Color:
	if has_texture:
		return _background_color_for_state(true)
	return _background_color_for_state(false).darkened(0.05)


func _border_color_for_state(has_texture: bool) -> Color:
	if is_new_draw:
		return TILE_SELECTED_BLUE if _uses_mahjong_shell() else HIGHLIGHT_BORDER
	if is_selected:
		return TILE_SELECTED_BLUE if _uses_mahjong_shell() else PRESSED_BORDER
	if has_texture:
		return TILE_FACE_BORDER_HAND if display_profile == "hand" else TILE_FACE_BORDER
	return BORDER_COLOR


func _border_width_for_state() -> float:
	if is_new_draw:
		return 2.0 if _uses_mahjong_shell() else 3.0
	if is_selected:
		return 2.0
	if _uses_mahjong_shell():
		return 2.0
	return 1.0


func _hover_border_color(has_texture: bool) -> Color:
	if is_new_draw or is_selected:
		return _border_color_for_state(has_texture)
	return TILE_FACE_BORDER if _uses_mahjong_shell() else (Color(0.56, 0.44, 0.24, 0.38) if has_texture else Color(0.18, 0.18, 0.18, 0.85))


func _pressed_border_color(has_texture: bool) -> Color:
	if is_new_draw:
		return TILE_SELECTED_BLUE if _uses_mahjong_shell() else HIGHLIGHT_BORDER
	return TILE_SELECTED_BLUE if _uses_mahjong_shell() else (PRESSED_BORDER if has_texture else Color(0.18, 0.18, 0.18, 0.85))


func _disabled_border_color(has_texture: bool) -> Color:
	if has_texture:
		return Color(TILE_FACE_BORDER, 0.7)
	return Color(0.12, 0.12, 0.12, 0.65)


func _resolve_tile_texture() -> Texture2D:
	var asset_path := ""
	if show_back:
		asset_path = _preferred_asset_path([
			"%s/back_face.png" % TILE_ART_DIR,
			"%s/back_face.jpg" % TILE_ART_DIR,
		])
	else:
		var suit := str(tile_data.get("suit", ""))
		var rank := int(tile_data.get("rank", 0))
		if suit != "" and rank > 0:
			asset_path = _preferred_asset_path([
				"%s/%s_%d.png" % [TILE_ART_DIR, suit, rank],
				"%s/%s_%d.jpg" % [TILE_ART_DIR, suit, rank],
			])

	if asset_path == "":
		return null
	var cache_key := "%s|%s" % [asset_path, display_profile]
	if profile_texture_cache.has(cache_key):
		return profile_texture_cache[cache_key]
	if not ResourceLoader.exists(asset_path):
		return null

	var texture := load(asset_path) as Texture2D
	if texture == null:
		texture = _load_texture_from_image(asset_path)
	texture_cache[asset_path] = texture
	if display_profile == "hand" and asset_path.get_extension().to_lower() != "png":
		var hand_texture := _build_hand_profile_texture(texture)
		profile_texture_cache[cache_key] = hand_texture
		return hand_texture
	profile_texture_cache[cache_key] = texture
	return texture


func _build_hand_profile_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var source_size := texture.get_size()
	var crop_profile := _hand_crop_profile()
	var crop_left := int(round(source_size.x * float(crop_profile.get("left", 0.28))))
	var crop_right := int(round(source_size.x * float(crop_profile.get("right", 0.18))))
	var crop_top := int(round(source_size.y * float(crop_profile.get("top", 0.02))))
	var crop_bottom := int(round(source_size.y * float(crop_profile.get("bottom", 0.01))))
	atlas.region = Rect2(
		crop_left,
		crop_top,
		maxf(1.0, source_size.x - crop_left - crop_right),
		maxf(1.0, source_size.y - crop_top - crop_bottom)
	)
	return atlas


func _preferred_asset_path(candidates: Array) -> String:
	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


func _load_texture_from_image(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _create_stylebox(background: Color, border_color: Color, border_width: float, has_texture: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(int(border_width))
	style.border_color = border_color
	style.corner_radius_top_left = int(round((12 if has_texture else 10) * tile_scale_factor))
	style.corner_radius_top_right = int(round((12 if has_texture else 10) * tile_scale_factor))
	style.corner_radius_bottom_left = int(round((12 if has_texture else 8) * tile_scale_factor))
	style.corner_radius_bottom_right = int(round((12 if has_texture else 8) * tile_scale_factor))
	var shadow_alpha := 0.22 if not has_texture else 0.08
	var shadow_size := 3 if not has_texture else 2
	if _uses_mahjong_shell():
		shadow_alpha = 0.15
		shadow_size = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	style.shadow_size = int(round(shadow_size * tile_scale_factor))
	style.shadow_offset = Vector2(0, maxf(2.0, 2.0 * tile_scale_factor)) if _uses_mahjong_shell() else Vector2(0, maxf(0.0, 1.0 * tile_scale_factor))
	if has_texture and _uses_mahjong_shell():
		style.draw_center = true
		style.border_blend = true
		style.expand_margin_top = 0.0
		style.expand_margin_bottom = 0.0
	style.content_margin_left = 2 * tile_scale_factor if has_texture else 6 * tile_scale_factor
	style.content_margin_right = 2 * tile_scale_factor if has_texture else 6 * tile_scale_factor
	style.content_margin_top = 2 * tile_scale_factor if has_texture else 8 * tile_scale_factor
	style.content_margin_bottom = 2 * tile_scale_factor if has_texture else 8 * tile_scale_factor
	return style


func _uses_mahjong_shell() -> bool:
	return display_profile == "hand"
