extends Control

class_name PlayerHandViewport

const VIEWPORT_RENDER_SCALE := 1.0
const TABLE_MATERIAL_OVERLAY_SCRIPT := preload("res://scripts/ui/TableMaterialOverlay.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const EMBEDDED_HOST_INSET := 8.0
const EMBEDDED_HOST_MAX_HEIGHT := 204.0

signal tile_pressed(tile_id: int)

@onready var tray_panel: Panel = %TrayPanel
@onready var viewport: SubViewport = %HandViewport
@onready var hand_canvas: Node = %HandCanvas
@onready var embedded_layer: Control = %EmbeddedLayer

var hand_tiles: Array = []
var selected_tile_id: int = -1
var new_draw_tile_id: int = -1
var can_interact: bool = false
var trainer_markers: Dictionary = {}
var embedded_left_host: Control
var embedded_left_width: float = 0.0
var embedded_left_gap: float = 0.0
var embedded_right_host: Control
var embedded_right_width: float = 0.0
var embedded_right_gap: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_style_tray()
	if hand_canvas != null and hand_canvas.has_method("set_reduced_motion"):
		hand_canvas.call("set_reduced_motion", bool(ProjectSettings.get_setting("accessibility/reduced_motion", false)))
	_sync_viewport()
	_refresh_canvas()


func configure_hand(tiles: Array, selected_id: int, new_id: int, interactive: bool, markers: Dictionary = {}, layout_options: Dictionary = {}) -> void:
	hand_tiles = tiles.duplicate(true)
	selected_tile_id = selected_id
	new_draw_tile_id = new_id
	can_interact = interactive
	trainer_markers = markers.duplicate(true)
	embedded_left_width = float(layout_options.get("embedded_left_width", embedded_left_width))
	embedded_left_gap = float(layout_options.get("embedded_left_gap", embedded_left_gap))
	embedded_right_width = float(layout_options.get("embedded_right_width", embedded_right_width))
	embedded_right_gap = float(layout_options.get("embedded_right_gap", embedded_right_gap))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	_refresh_canvas()
	_layout_embedded_left_host()
	_layout_embedded_right_host()


func get_hand_layout_bounds() -> Rect2:
	if hand_canvas == null or not hand_canvas.has_method("get_layout_bounds"):
		return Rect2()
	return hand_canvas.call("get_layout_bounds")


func get_hand_layout_contract() -> Array:
	if hand_canvas == null or not hand_canvas.has_method("get_layout_contract"):
		return []
	return hand_canvas.call("get_layout_contract")


func set_reduced_motion(enabled: bool) -> void:
	if hand_canvas != null and hand_canvas.has_method("set_reduced_motion"):
		hand_canvas.call("set_reduced_motion", enabled)


func embed_left_host(host: Control, width: float, gap: float = 0.0) -> void:
	if host == null or embedded_layer == null:
		return
	if embedded_left_host != host:
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		embedded_layer.add_child(host)
		embedded_left_host = host
	host.top_level = false
	embedded_left_width = width
	embedded_left_gap = gap
	_refresh_canvas()
	_layout_embedded_left_host()
	_layout_embedded_right_host()


func clear_left_host() -> void:
	var previous_host := embedded_left_host
	embedded_left_host = null
	embedded_left_width = 0.0
	embedded_left_gap = 0.0
	if previous_host != null and previous_host.get_parent() == embedded_layer:
		previous_host.visible = false
	_refresh_canvas()


func embed_right_host(host: Control, width: float, gap: float = 0.0) -> void:
	if host == null or embedded_layer == null:
		return
	if embedded_right_host != host:
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		embedded_layer.add_child(host)
		embedded_right_host = host
	host.top_level = false
	embedded_right_width = width
	embedded_right_gap = gap
	_refresh_canvas()
	_layout_embedded_left_host()
	_layout_embedded_right_host()


func clear_right_host() -> void:
	var previous_host := embedded_right_host
	embedded_right_host = null
	embedded_right_width = 0.0
	embedded_right_gap = 0.0
	if previous_host != null and previous_host.get_parent() == embedded_layer:
		previous_host.visible = false
	_refresh_canvas()


func _layout_embedded_left_host() -> void:
	if embedded_left_host == null or embedded_layer == null:
		return
	embedded_left_host.visible = embedded_left_width > 0.0
	if embedded_left_width <= 0.0:
		return
	embedded_left_host.anchor_left = 0.0
	embedded_left_host.anchor_right = 0.0
	embedded_left_host.anchor_top = 0.0
	embedded_left_host.anchor_bottom = 1.0
	var host_height := _embedded_host_height()
	var host_top := _embedded_host_top(host_height)
	var host_left := _embedded_left_host_x()
	embedded_left_host.offset_left = host_left
	embedded_left_host.offset_top = host_top
	embedded_left_host.offset_right = host_left + embedded_left_width
	embedded_left_host.offset_bottom = host_top + host_height - embedded_layer.size.y
	embedded_left_host.custom_minimum_size = Vector2(embedded_left_width, host_height)
	embedded_left_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embedded_left_host.z_index = 2


func _layout_embedded_right_host() -> void:
	if embedded_right_host == null or embedded_layer == null:
		return
	embedded_right_host.visible = embedded_right_width > 0.0
	if embedded_right_width <= 0.0:
		return
	embedded_right_host.anchor_left = 0.0
	embedded_right_host.anchor_right = 0.0
	embedded_right_host.anchor_top = 0.0
	embedded_right_host.anchor_bottom = 1.0
	var host_height := _embedded_host_height()
	var host_top := _embedded_host_top(host_height)
	var host_left := _embedded_right_host_x()
	embedded_right_host.offset_left = host_left
	embedded_right_host.offset_top = host_top
	embedded_right_host.offset_right = host_left + embedded_right_width
	embedded_right_host.offset_bottom = host_top + host_height - embedded_layer.size.y
	embedded_right_host.custom_minimum_size = Vector2(embedded_right_width, host_height)
	embedded_right_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embedded_right_host.z_index = 3


func _embedded_host_height() -> float:
	var hand_bounds := _embedded_hand_bounds()
	if hand_bounds.size.y > 1.0:
		return clampf(hand_bounds.size.y, 1.0, maxf(1.0, embedded_layer.size.y))
	return minf(EMBEDDED_HOST_MAX_HEIGHT, maxf(1.0, embedded_layer.size.y - EMBEDDED_HOST_INSET * 2.0))


func _embedded_host_top(host_height: float) -> float:
	var hand_bounds := _embedded_hand_bounds()
	if hand_bounds.size.y > 1.0:
		return clampf(hand_bounds.position.y - embedded_layer.position.y, 0.0, maxf(0.0, embedded_layer.size.y - host_height))
	return maxf(EMBEDDED_HOST_INSET, embedded_layer.size.y - host_height - EMBEDDED_HOST_INSET)


func _embedded_hand_bounds() -> Rect2:
	if hand_canvas == null or not hand_canvas.has_method("get_layout_bounds"):
		return Rect2()
	return hand_canvas.call("get_layout_bounds")


func _embedded_left_host_x() -> float:
	var hand_bounds := _embedded_hand_bounds()
	if hand_bounds.size.x <= 1.0:
		return EMBEDDED_HOST_INSET
	var desired := hand_bounds.position.x - embedded_left_gap - embedded_left_width
	var max_left := embedded_layer.size.x - EMBEDDED_HOST_INSET - embedded_left_width
	return clampf(desired, EMBEDDED_HOST_INSET, max_left)


func _embedded_right_host_x() -> float:
	var fallback := maxf(
		EMBEDDED_HOST_INSET,
		embedded_layer.size.x - EMBEDDED_HOST_INSET - embedded_right_width
	)
	var hand_bounds := _embedded_hand_bounds()
	if hand_bounds.size.x <= 1.0:
		return fallback
	var desired := hand_bounds.end.x + embedded_right_gap
	var max_left := embedded_layer.size.x - EMBEDDED_HOST_INSET - embedded_right_width
	return clampf(desired, EMBEDDED_HOST_INSET, max_left)


func _gui_input(event: InputEvent) -> void:
	if not can_interact:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_id: int = hand_canvas.call("get_tile_id_at_point", event.position * VIEWPORT_RENDER_SCALE)
		if tile_id != -1:
			tile_pressed.emit(tile_id)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport()
		_refresh_canvas()


func _sync_viewport() -> void:
	if viewport == null:
		return
	viewport.size = Vector2i(
		maxi(1, int(round(size.x * VIEWPORT_RENDER_SCALE))),
		maxi(1, int(round(size.y * VIEWPORT_RENDER_SCALE)))
	)


func _refresh_canvas() -> void:
	if hand_canvas == null:
		return
	hand_canvas.call("configure", hand_tiles, selected_tile_id, new_draw_tile_id, size, trainer_markers, {
		"embedded_left_width": embedded_left_width,
		"embedded_left_gap": embedded_left_gap,
		"embedded_right_width": embedded_right_width,
		"embedded_right_gap": embedded_right_gap,
	})


func _style_tray() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	tray_panel.add_theme_stylebox_override("panel", style)
	var overlay := tray_panel.get_node_or_null("SelfHandTraySoftLight") as Control
	if overlay != null:
		overlay.queue_free()
	var rack := tray_panel.get_node_or_null("ShuBrocadeHandRack") as Panel
	if rack == null:
		rack = Panel.new()
		rack.name = "ShuBrocadeHandRack"
		rack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rack.anchor_left = 0.0
		rack.anchor_right = 1.0
		rack.anchor_top = 1.0
		rack.anchor_bottom = 1.0
		rack.offset_left = 18.0
		rack.offset_right = -18.0
		rack.offset_top = -98.0
		rack.offset_bottom = -8.0
		tray_panel.add_child(rack)
		tray_panel.move_child(rack, 0)
	rack.add_theme_stylebox_override("panel", TABLE_THEME.make_hand_rack_style())
