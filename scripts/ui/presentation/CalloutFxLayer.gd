class_name CalloutFxLayer
extends CanvasLayer

signal event_presented(event: Dictionary)

const BODY_FONT := preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
const TEXTURES := {
	"peng": preload("res://res/art/ui/event_callouts/peng.png"),
	"gang": preload("res://res/art/ui/event_callouts/gang.png"),
	"hu": preload("res://res/art/ui/event_callouts/hu.png"),
	"self_draw": preload("res://res/art/ui/event_callouts/self_draw.png"),
	"gang_self_draw": preload("res://res/art/ui/event_callouts/gang_self_draw.png"),
	"qiang_gang_hu": preload("res://res/art/ui/event_callouts/qiang_gang_hu.png"),
}
const ENTER_SECONDS := 0.18
const HOLD_SECONDS := 0.36
const EXIT_SECONDS := 0.14
const REDUCED_FADE_SECONDS := 0.12

var responsibility := ""
var accepted_kinds: Array[String] = []
var presentation_log: Array[Dictionary] = []
var reduced_motion := false
var active_tween: Tween
var root: Control
var event_box: Control
var texture_rect: TextureRect
var detail_label: Label


func _ready() -> void:
	layer = 48
	_build_visuals()
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)


func configure(layer_responsibility: String, kinds: Array[String]) -> void:
	responsibility = layer_responsibility
	accepted_kinds = kinds.duplicate()
	if is_inside_tree() and root == null:
		_build_visuals()


func present(event: Dictionary) -> void:
	if not accepted_kinds.has(str(event.get("kind", ""))):
		return
	if root == null:
		_build_visuals()
	var read_only_event := event.duplicate(true)
	presentation_log.append(read_only_event)
	event_presented.emit(read_only_event)
	_show_event(read_only_event)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_stop_and_reset()


func clear_presentation_log() -> void:
	presentation_log.clear()
	_stop_and_reset()


func get_contract() -> Dictionary:
	return {
		"responsibility": responsibility,
		"accepted_kinds": accepted_kinds.duplicate(),
		"input": "immutable presentation event duplicate",
		"writes_game_state": false,
		"writes_score_state": false,
		"writes_ai_state": false,
		"transparent_original_png": true,
		"source_blender": "res://res/source/ui/event_callouts/sichuan_event_callouts.blend",
		"entry_seconds": ENTER_SECONDS,
		"hold_seconds": HOLD_SECONDS,
		"exit_seconds": EXIT_SECONDS,
		"screen_shake": false,
		"mouse_filter": "ignore",
	}


func get_visual_state_contract() -> Dictionary:
	return {
		"visible": event_box != null and event_box.visible,
		"texture_path": str(texture_rect.texture.resource_path) if texture_rect != null and texture_rect.texture != null else "",
		"detail_text": detail_label.text if detail_label != null else "",
		"scale": event_box.scale if event_box != null else Vector2.ONE,
		"position": event_box.position if event_box != null else Vector2.ZERO,
		"active_tween_count": 1 if active_tween != null and active_tween.is_valid() else 0,
		"reduced_motion": reduced_motion,
	}


func _build_visuals() -> void:
	if root != null:
		return
	root = Control.new()
	root.name = "CalloutFxCanvas"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	event_box = Control.new()
	event_box.name = "EventCallout"
	event_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_box.pivot_offset = Vector2(220.0, 96.0)
	root.add_child(event_box)
	texture_rect = TextureRect.new()
	texture_rect.name = "EventArtwork"
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_box.add_child(texture_rect)
	detail_label = Label.new()
	detail_label.name = "EventDetail"
	detail_label.position = Vector2(20.0, 166.0)
	detail_label.size = Vector2(400.0, 48.0)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.add_theme_font_override("font", BODY_FONT)
	detail_label.add_theme_font_size_override("font_size", 24)
	detail_label.add_theme_color_override("font_color", Color("FFF2C9"))
	detail_label.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.03, 0.98))
	detail_label.add_theme_constant_override("outline_size", 4)
	event_box.add_child(detail_label)
	event_box.visible = false


func _layout_for_viewport() -> void:
	if root == null or event_box == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := 420.0 if viewport_size.x < 1500.0 else 460.0
	var height := width * 0.50
	event_box.size = Vector2(width, height)
	# The centre-compass breathing zone contains no playable tile or touch target.
	# It keeps callouts clear of every rack/river, all four score HUDs and the
	# bottom action rail at both 16:9 and wide-phone sizes.
	event_box.position = Vector2((viewport_size.x - width) * 0.5, viewport_size.y * 0.34)
	event_box.pivot_offset = event_box.size * 0.5
	detail_label.position = Vector2(10.0, height - 48.0)
	detail_label.size = Vector2(width - 20.0, 44.0)


func _show_event(event: Dictionary) -> void:
	_stop_active_tween()
	var key := _asset_key(event)
	texture_rect.texture = TEXTURES.get(key, TEXTURES["hu"])
	detail_label.text = _detail_text(event, key)
	_layout_for_viewport()
	event_box.visible = true
	event_box.rotation = 0.0
	event_box.position.x = (get_viewport().get_visible_rect().size.x - event_box.size.x) * 0.5
	var delay := float(event.get("callout_delay_seconds", 0.0))
	if reduced_motion:
		event_box.scale = Vector2.ONE
		event_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
		active_tween = event_box.create_tween()
		if delay > 0.0:
			active_tween.tween_interval(delay)
		active_tween.tween_property(event_box, "modulate:a", 1.0, REDUCED_FADE_SECONDS)
		active_tween.tween_interval(HOLD_SECONDS)
		active_tween.tween_property(event_box, "modulate:a", 0.0, REDUCED_FADE_SECONDS)
		active_tween.tween_callback(_hide_event)
		return
	event_box.scale = Vector2.ONE * 0.88
	event_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
	active_tween = event_box.create_tween()
	if delay > 0.0:
		active_tween.tween_interval(delay)
	active_tween.set_parallel(true)
	active_tween.tween_property(event_box, "modulate:a", 1.0, ENTER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(event_box, "scale", Vector2.ONE, ENTER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.set_parallel(false)
	active_tween.tween_interval(HOLD_SECONDS)
	active_tween.tween_property(event_box, "modulate:a", 0.0, EXIT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_callback(_hide_event)


func _asset_key(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	if kind == "peng":
		return "peng"
	if kind == "gang":
		return "gang"
	if kind != "win":
		return "hu"
	var payload: Dictionary = event.get("payload", {})
	var win_type := str(payload.get("win_type", event.get("win_type", "discard_win")))
	match win_type:
		"self_draw":
			return "self_draw"
		"gang_self_draw":
			return "gang_self_draw"
		"qiang_gang_hu":
			return "qiang_gang_hu"
	return "hu"


func _detail_text(event: Dictionary, key: String) -> String:
	var payload: Dictionary = event.get("payload", {})
	if key == "gang":
		match str(payload.get("gang_subtype", payload.get("gang_type", "melded_gang"))):
			"add_gang":
				return "补杠"
			"an_gang":
				return "暗杠"
		return "直杠"
	if key in ["hu", "self_draw", "gang_self_draw", "qiang_gang_hu"]:
		var fan_detail: Dictionary = payload.get("fan_detail", {})
		var fan := int(fan_detail.get("capped_fan", fan_detail.get("fan", 0)))
		return "%d番" % fan
	return ""


func _stop_active_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null


func _stop_and_reset() -> void:
	_stop_active_tween()
	if event_box == null:
		return
	event_box.scale = Vector2.ONE
	event_box.rotation = 0.0
	event_box.modulate = Color.WHITE
	event_box.visible = false


func _hide_event() -> void:
	if event_box != null:
		event_box.visible = false
		event_box.scale = Vector2.ONE
		event_box.modulate = Color.WHITE
	active_tween = null
