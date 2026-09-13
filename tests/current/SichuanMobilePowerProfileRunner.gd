extends SceneTree

const ACTION_OVERLAY := preload("res://scripts/ui/CircularActionButtonOverlay.gd")
const PRESENTATION_DIRECTOR := preload("res://scripts/ui/presentation/TablePresentationDirector.gd")
const MAIN_SCENE := preload("res://scripts/game/MainSceneV2.gd")
const TABLE_STAGE := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const TILE_3D := preload("res://scripts/ui/3d/SichuanTile3D.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert(int(ProjectSettings.get_setting("performance/mobile_active_frame_cap", 0)) == 60, "active mobile frame cap must be 60")
	_assert(int(ProjectSettings.get_setting("performance/mobile_idle_frame_cap", 0)) == 30, "idle mobile frame cap must be 30")
	_assert(int(ProjectSettings.get_setting("performance/mobile_idle_delay_msec", 0)) == 1400, "mobile idle transition must be 1400 ms")
	_assert(not bool(ProjectSettings.get_setting("performance/mobile_ssao_enabled", true)), "mobile SSAO must default off")
	_assert(not bool(ProjectSettings.get_setting("performance/mobile_directional_shadows_enabled", true)), "mobile directional shadows must default off")
	_assert(not bool(ProjectSettings.get_setting("performance/mobile_expensive_materials_enabled", true)), "expensive mobile tile materials must default off")
	_assert(str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")) == "mobile", "iOS mobile renderer must use Godot Mobile")

	var main_scene := MAIN_SCENE.new()
	var power_contract: Dictionary = main_scene.get_mobile_power_profile_contract()
	_assert(int(power_contract.get("active_frame_cap", 0)) == 60, "power contract must expose the active cap")
	_assert(int(power_contract.get("idle_frame_cap", 0)) == 30, "power contract must expose the idle cap")
	_assert(str(power_contract.get("ai_result_polling", "")) == "pending_requests_only", "AI polling must sleep without a pending request")
	_assert(str(power_contract.get("idle_main_loop", "")) == "suspended_without_pending_ai", "the mobile scene frame callback must suspend while idle")
	_assert(str(power_contract.get("watchdog_snapshot_copy", "")) == "draw_transition_only", "watchdog must not copy snapshots while idle")
	_assert(str(power_contract.get("font_tree_refresh", "")) == "startup_only", "the full font tree must not refresh on each snapshot")
	main_scene.mobile_power_profile_enabled = true
	main_scene.mobile_activity_deadline_msec = 0
	main_scene.set_process(true)
	main_scene._update_mobile_frame_budget()
	_assert(not main_scene.is_processing(), "an idle mobile scene without AI work must suspend its frame callback")
	main_scene._mark_mobile_activity(10)
	_assert(main_scene.is_processing(), "input or a snapshot must wake the mobile scene immediately")
	Engine.max_fps = 0
	main_scene.free()

	var stage := TABLE_STAGE.new()
	var render_contract: Dictionary = stage.get_mobile_render_budget_contract()
	_assert(str(render_contract.get("mobile_renderer", "")) == "mobile", "render contract must expose the Mobile renderer")
	_assert(not bool(render_contract.get("directional_shadows_enabled", true)), "render contract must disable mobile shadows")
	_assert(str(render_contract.get("felt_anisotropy", "")) == "disabled_on_mobile", "mobile felt must avoid anisotropic sampling")
	stage.free()

	var tile := TILE_3D.new() as SichuanTile3D
	root.add_child(tile)
	await process_frame
	var tile_state := {"id": 7001, "suit": "tong", "rank": 3}
	tile.configure(tile_state, true, false, false, false, false, true, true)
	var initial_configure_count := tile.get_full_configure_count()
	for _repeat_index in range(100):
		tile.configure(tile_state, true, false, false, false, false, true, true)
	_assert(tile.get_full_configure_count() == initial_configure_count, "unchanged snapshots must not rebuild a tile material state")
	_assert(not tile.is_processing(), "the latest-discard marker must not spin forever")
	tile.configure(tile_state, true, true, false, false, false, true, true)
	_assert(tile.get_full_configure_count() == initial_configure_count + 1, "a real visual-state change must still reconfigure the tile")
	tile.queue_free()

	var button := Button.new()
	var overlay := ACTION_OVERLAY.new() as CircularActionButtonOverlay
	button.add_child(overlay)
	root.add_child(button)
	await process_frame
	_assert(not overlay.is_processing(), "static action overlay must not process every frame")
	button.queue_free()

	var director := PRESENTATION_DIRECTOR.new() as TablePresentationDirector
	root.add_child(director)
	await process_frame
	_assert(not director.is_processing(), "presentation director must sleep while idle")
	director.enqueue_event({"kind": "tip", "signature": "power-test-tip", "duration_seconds": 0.1})
	_assert(director.is_processing(), "presentation director must wake for an event")
	director.complete_active_event()
	_assert(not director.is_processing(), "presentation director must sleep after the queue drains")
	for round_index in range(1, 101):
		director.reset_for_round(round_index)
	_assert(director.event_log.is_empty(), "round reset must not retain presentation event history")
	_assert(director.pending_events.is_empty(), "round reset must not retain presentation queue")
	_assert(not director.is_processing(), "round reset must leave presentation director idle")
	director.queue_free()

	if failures.is_empty():
		print("SICHUAN MOBILE POWER PROFILE OK: 60/30 ADAPTIVE FPS + MOBILE RENDER BUDGET + IDLE CPU GATES + IDEMPOTENT TILES")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
