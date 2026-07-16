class_name SafeAreaLayout
extends MarginContainer

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")


func _ready() -> void:
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_apply_device_safe_area):
		viewport.size_changed.connect(_apply_device_safe_area)
	call_deferred("_apply_device_safe_area")


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_apply_device_safe_area):
		viewport.size_changed.disconnect(_apply_device_safe_area)


func apply_safe_area_for_test(viewport_size: Vector2, display_size: Vector2, safe_rect: Rect2) -> Vector4:
	var margins := METRICS.design_safe_margins(viewport_size, display_size, safe_rect)
	_apply_margins(margins)
	return margins


func get_safe_margins() -> Vector4:
	return Vector4(
		get_theme_constant("margin_left"),
		get_theme_constant("margin_top"),
		get_theme_constant("margin_right"),
		get_theme_constant("margin_bottom")
	)


func _apply_device_safe_area() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var screen_index := DisplayServer.window_get_current_screen()
	var display_size := Vector2(DisplayServer.screen_get_size(screen_index))
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	var margins := METRICS.design_safe_margins(viewport_size, display_size, safe_rect)
	_apply_margins(margins)


func _apply_margins(margins: Vector4) -> void:
	add_theme_constant_override("margin_left", ceili(margins.x))
	add_theme_constant_override("margin_top", ceili(margins.y))
	add_theme_constant_override("margin_right", ceili(margins.z))
	add_theme_constant_override("margin_bottom", ceili(margins.w))
