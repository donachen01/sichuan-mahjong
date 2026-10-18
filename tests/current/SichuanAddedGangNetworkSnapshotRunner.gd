extends "res://tests/current/SichuanAddedGangWinFlowRunner.gd"

const MANAGER := preload("res://scripts/game/GameManager.gd")
const PROJECTOR := preload("res://scripts/network/snapshot_projector.gd")

func _run() -> void:
	for order in ["snapshot_first", "ack_first", "delayed", "send_failed"]:
		var state = _state(1, false, false)
		var manager = MANAGER.new()
		root.add_child(manager)
		await process_frame
		var initial: Dictionary = PROJECTOR.new().project(state.get_gameplay_snapshot(0), 0)
		var next_snapshot: Dictionary = {}
		var sender := func(_command: String, _arguments: Dictionary) -> bool:
			if order == "send_failed":
				return false
			_check(state.execute_human_add_gang(0), "network submitted real add gang")
			next_snapshot.merge(PROJECTOR.new().project(state.get_gameplay_snapshot(0), 0), true)
			if order == "ack_first":
				manager.apply_network_command_result({"ok": true})
			if order != "delayed":
				_check(manager.apply_private_snapshot(next_snapshot), "authoritative private snapshot accepted")
			return true
		_check(manager.configure_network_client(0, sender), "client configured")
		_check(manager.apply_private_snapshot(initial), "initial add gang snapshot")
		var submitted: bool = manager.execute_action("add_gang")
		if order == "delayed":
			_check(not bool(manager.get_snapshot().get("human_can_self_hu")), "pending old actions disabled")
			_check(not manager.execute_action("add_gang"), "pending duplicate submission blocked")
			manager.apply_private_snapshot(next_snapshot)
		elif order == "send_failed":
			_check(not submitted and bool(manager.get_snapshot().get("human_can_add_gang")), "send failure restores actions")
			manager.queue_free()
			state.free()
			continue
		var result: Dictionary = manager.get_snapshot()
		_check(bool(result.get("human_can_self_hu")) and bool(Dictionary(result.get("own_actions")).get("can_self_hu")), "new replacement Hu survives submit bookkeeping: " + order)
		_check(Dictionary(manager.get("snapshot_before_pending_command")).is_empty(), "no stale pending command: " + order)
		rows.append({"order": order, "can_self_hu": result.get("human_can_self_hu"), "own_actions": result.get("own_actions")})
		manager.queue_free()
		state.free()
		await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var f := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "rows": rows}, "  "))
	print("ADDED_GANG_NETWORK_SNAPSHOT failures=", failures)
	quit(0 if failures.is_empty() else 1)
