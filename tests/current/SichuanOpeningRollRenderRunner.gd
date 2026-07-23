extends SceneTree

const MAIN_SCENE := preload("res://scenes/table/MainSceneV2.tscn")
const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const MAX_WAIT_SECONDS := 2.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1365, 768)
	var failures: Array[String] = []
	var scene := MAIN_SCENE.instantiate()
	get_root().add_child(scene)

	var deadline := Time.get_ticks_msec() + int(MAX_WAIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var manager = scene.get("game_manager")
		if manager == null or manager.game_state == null:
			continue
		if not bool(manager.game_state.get("opening_roll_pending_completion")):
			break

	var game_manager = scene.get("game_manager")
	var game_state = null if game_manager == null else game_manager.game_state
	if game_state == null:
		failures.append("GameState 未连接")
	else:
		_verify_deal_state(game_state, failures)
		_verify_scene_render(scene, game_state, failures)

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("SICHUAN OPENING ROLL RENDER OK: AUTO COMMIT + 53 DEALT TILES + 3D STAGE")
		quit(0)
		return
	push_error("SICHUAN OPENING ROLL RENDER FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_deal_state(game_state: Node, failures: Array[String]) -> void:
	if bool(game_state.get("opening_roll_pending_completion")):
		failures.append("骰子动画结束后 opening_roll_pending_completion 仍为 true")
	if int(game_state.get("current_phase")) == int(GAME_STATE_SCRIPT.RoundPhase.TABLE_SETUP):
		failures.append("骰子动画结束后仍停在 TABLE_SETUP")
	var total_hand_tiles := 0
	var hand_counts: Array[int] = []
	for seat in range(4):
		var hand: Array = game_state.call("get_player_hand_tiles", seat)
		hand_counts.append(hand.size())
		total_hand_tiles += hand.size()
	if total_hand_tiles != 53:
		failures.append("发牌结果不是 53 张，实际 hand_counts=%s" % str(hand_counts))


func _verify_scene_render(scene: Node, game_state: Node, failures: Array[String]) -> void:
	var stage = scene.get("table_stage_3d")
	if stage == null:
		failures.append("3D 牌桌舞台不存在")
		return
	# Do not manually refresh here. This assertion covers the real signal path:
	# opening-roll timer -> GameState state_changed -> GameManager -> MainScene -> 3D stage.
	var contract: Dictionary = stage.call("get_visual_contract")
	var hand_counts: Array = contract.get("hand_counts", [])
	var rendered_tile_nodes := int(contract.get("rendered_tile_nodes", 0))
	if hand_counts.size() != 4 or hand_counts.reduce(func(total, count): return total + int(count), 0) != 53:
		failures.append("3D 舞台没有收到完整手牌，contract hand_counts=%s" % str(hand_counts))
	if rendered_tile_nodes < 53:
		failures.append("3D 舞台仅生成 %d 个牌节点，预期至少 53" % rendered_tile_nodes)
	var tile_root := stage.get("tile_root") as Node3D
	if tile_root == null or tile_root.get_child_count() < 53:
		failures.append("GameplayTiles 实际子节点不足 53，实际=%d" % (0 if tile_root == null else tile_root.get_child_count()))
