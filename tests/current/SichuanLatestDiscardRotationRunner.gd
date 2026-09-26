extends SceneTree

const TILE_SCRIPT := preload("res://scripts/ui/3d/SichuanTile3D.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tile := TILE_SCRIPT.new() as SichuanTile3D
	get_root().add_child(tile)
	await process_frame
	tile.set_latest_marker_visible(true)
	var before := tile.latest_marker.rotation.y
	for _frame in range(4):
		await process_frame
	if not tile.is_processing() or is_equal_approx(tile.latest_marker.rotation.y, before):
		push_error("Latest discard marker did not rotate while visible")
		quit(1)
		return
	tile.set_reduced_motion(true)
	before = tile.latest_marker.rotation.y
	for _frame in range(4):
		await process_frame
	if tile.is_processing() or not is_equal_approx(tile.latest_marker.rotation.y, before):
		push_error("Reduced motion did not pause the latest discard marker")
		quit(1)
		return
	tile.set_reduced_motion(false)
	tile.set_latest_marker_visible(false)
	if tile.is_processing():
		push_error("Hidden latest discard marker retained frame processing")
		quit(1)
		return
	print("SICHUAN LATEST DISCARD ROTATION OK")
	tile.queue_free()
	await process_frame
	quit(0)
