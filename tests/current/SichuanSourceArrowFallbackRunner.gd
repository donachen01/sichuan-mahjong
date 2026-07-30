extends SceneTree

const PLAYER_UI_SCENE := preload("res://scenes/ui/PlayerUI.tscn")
const EXPECTED_COLOR := Color("48C8FF")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var player_ui := PLAYER_UI_SCENE.instantiate() as PlayerUI
	player_ui.seat_dock = PlayerUI.SeatDock.LEFT
	get_root().add_child(player_ui)
	await process_frame

	var directions := {
		0: "↓",
		1: "←",
		2: "↑",
		3: "→",
	}
	for source_seat in directions:
		var direction: String = player_ui._claim_arrow_text(1, int(source_seat))
		if int(source_seat) == 1:
			if not direction.is_empty():
				failures.append("self-sourced meld fallback must not expose a source arrow or text")
		elif direction != str(directions[source_seat]):
			failures.append("fallback source direction for seat %d must contain no seat-name text" % int(source_seat))

	var overlay: Control = player_ui._create_claim_arrow_overlay(Vector2(80, 120), "↑", true)
	var badge := overlay.get_node_or_null("CompactSkyBlueClaimArrow") as Node2D
	var arrow := badge.get_node_or_null("FlatSkyBlueArrow") as Polygon2D if badge != null else null
	if badge == null:
		failures.append("fallback source marker is missing the compact-arrow node")
	elif badge.get_child_count() != 1:
		failures.append("fallback source marker must not retain shadow, highlight, outline, or text children")
	if arrow == null:
		failures.append("fallback source marker is missing the flat arrow polygon")
	else:
		if not arrow.color.is_equal_approx(EXPECTED_COLOR):
			failures.append("fallback source marker is not sky blue")
		if arrow.polygon.size() != 7:
			failures.append("fallback source marker is not the compact seven-point shaft arrow")
	if _contains_label(overlay):
		failures.append("fallback source marker still contains source-seat text")

	overlay.free()
	player_ui.queue_free()
	if failures.is_empty():
		print("SICHUAN SOURCE ARROW FALLBACK OK")
		quit(0)
		return
	push_error("SICHUAN SOURCE ARROW FALLBACK FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _contains_label(node: Node) -> bool:
	if node is Label:
		return true
	for child in node.get_children():
		if _contains_label(child):
			return true
	return false
