extends "res://scripts/ui/TileVisual2D.gd"

class_name MahjongTile

signal tile_activated(tile_id: int)

@export var interactive: bool = false


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_activated.emit(int(tile_data.get("id", -1)))
		accept_event()
