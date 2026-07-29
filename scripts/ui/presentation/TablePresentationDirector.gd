class_name TablePresentationDirector
extends Node

signal event_enqueued(event: Dictionary)
signal event_started(event: Dictionary)
signal event_completed(event: Dictionary)
signal decorative_event_interrupted(event: Dictionary, by_event: Dictionary)

const EVENT_LAYER_SCRIPT := preload("res://scripts/ui/presentation/PresentationEventLayer.gd")
const CALLOUT_LAYER_SCRIPT := preload("res://scripts/ui/presentation/CalloutFxLayer.gd")

const PRIORITY := {
	"win": 90,
	"gang": 80,
	"peng": 70,
	"discard": 60,
	"draw": 50,
	"score": 40,
	"tip": 10,
}
const DURATION_SECONDS := {
	"win": 1.00,
	"gang": 0.26,
	"peng": 0.22,
	"discard": 0.22,
	"draw": 0.20,
	"score": 0.42,
	"tip": 0.36,
}
const MOTION_CONTRACT := {
	"action_button_entry_seconds": 0.16,
	"draw_seconds": 0.20,
	"discard_seconds": 0.20,
	"peng_seconds": 0.22,
	"gang_seconds": 0.26,
	"callout_entry_seconds": 0.18,
	"callout_hold_seconds": 0.36,
	"score_float_seconds": 0.42,
	"active_hud_edge_seconds": 0.18,
	"screen_shake": false,
	"changes_layout_rect": false,
	"changes_touch_rect": false,
	"changes_tile_id_mapping": false,
}
const EVENT_SEQUENCE_CONTRACTS := {
	"peng": ["source_discard_flies_to_meld", "three_tiles_land", "callout_peng"],
	"melded_gang": ["source_discard_flies_to_meld", "four_tiles_land", "callout_gang", "payer_and_actor_score"],
	"add_gang": ["fourth_tile_hand_to_existing_peng", "four_tiles_land", "callout_add_gang", "three_payers_and_actor_score"],
	"an_gang": ["four_tiles_land_outer_faces_middle_backs", "callout_an_gang", "three_payers_and_actor_score"],
	"self_draw": ["winning_tile_glow_and_hud", "callout_self_draw_and_fan", "three_payers_then_winner_score"],
	"gang_self_draw": ["supplement_draw_lands", "callout_gang_self_draw", "gang_score_event", "hu_score_event"],
	"discard_win": ["discard_transfers_to_winner", "callout_hu", "source_and_winner_score"],
	"qiang_gang_hu": ["add_gang_tile_transfers_to_winner", "sharp_callout_without_shake", "source_and_winner_score"],
}
const CRITICAL_TILE_MOTION_KINDS: Array[String] = ["gang", "peng", "discard", "draw"]
const DECORATIVE_KINDS: Array[String] = ["score", "tip"]

var auto_advance := true
var active_round := -1
var played_signatures: Dictionary = {}
var pending_events: Array[Dictionary] = []
var active_event: Dictionary = {}
var active_remaining_seconds := 0.0
var sequence_counter := 0
var event_log: Array[Dictionary] = []
var layers: Dictionary = {}


func _ready() -> void:
	_ensure_layers()
	set_process(true)


func _process(delta: float) -> void:
	if not auto_advance or active_event.is_empty():
		return
	active_remaining_seconds -= maxf(0.0, delta)
	if active_remaining_seconds <= 0.0:
		complete_active_event()


func consume_snapshot(previous_snapshot: Dictionary, current_snapshot: Dictionary) -> void:
	if current_snapshot.is_empty():
		return
	_ensure_layers()
	var round_index := int(current_snapshot.get("round_index", 0))
	if round_index != active_round:
		reset_for_round(round_index)
	for event in _extract_events(previous_snapshot, current_snapshot):
		enqueue_event(event)


func enqueue_event(event: Dictionary) -> bool:
	var normalized := _normalize_event(event)
	var signature := str(normalized.get("signature", ""))
	if signature.is_empty() or played_signatures.has(signature):
		return false
	played_signatures[signature] = true
	sequence_counter += 1
	normalized["sequence"] = sequence_counter
	normalized["round_index"] = active_round
	event_log.append({"phase": "enqueued", "signature": signature, "kind": normalized.get("kind"), "sequence": sequence_counter})
	event_enqueued.emit(normalized.duplicate(true))

	if active_event.is_empty():
		_start_event(normalized)
		return true
	if _can_interrupt_active(normalized):
		var interrupted := active_event.duplicate(true)
		event_log.append({"phase": "interrupted_decorative", "signature": interrupted.get("signature"), "by": signature})
		decorative_event_interrupted.emit(interrupted, normalized.duplicate(true))
		active_event.clear()
		active_remaining_seconds = 0.0
		_start_event(normalized)
		return true
	pending_events.append(normalized)
	_sort_pending_events()
	return true


func complete_active_event() -> void:
	if active_event.is_empty():
		return
	var completed := active_event.duplicate(true)
	event_log.append({"phase": "completed", "signature": completed.get("signature"), "kind": completed.get("kind")})
	event_completed.emit(completed)
	active_event.clear()
	active_remaining_seconds = 0.0
	_start_next_event()


func reset_for_round(round_index: int) -> void:
	active_round = round_index
	played_signatures.clear()
	pending_events.clear()
	active_event.clear()
	active_remaining_seconds = 0.0
	sequence_counter = 0
	event_log.clear()
	_ensure_layers()
	for layer in layers.values():
		(layer as Node).call("clear_presentation_log")


func clear_queue_stably() -> void:
	pending_events.clear()
	active_event.clear()
	active_remaining_seconds = 0.0


func get_dependency_contract() -> Dictionary:
	_ensure_layers()
	var layer_contracts: Dictionary = {}
	for key in layers:
		layer_contracts[key] = (layers[key] as Node).call("get_contract")
	return {
		"input": "GameState/UI snapshot duplicate",
		"direction": "snapshot_to_presentation_only",
		"stores_snapshot_reference": false,
		"writes_game_state": false,
		"writes_score_state": false,
		"writes_ai_state": false,
		"layers": layer_contracts,
	}


func get_state_contract() -> Dictionary:
	return {
		"active_round": active_round,
		"active_signature": str(active_event.get("signature", "")),
		"active_kind": str(active_event.get("kind", "")),
		"active_is_critical_motion": bool(active_event.get("critical_motion", false)),
		"pending_signatures": pending_events.map(func(item: Dictionary) -> String: return str(item.get("signature", ""))),
		"played_signatures": played_signatures.keys(),
		"priority_order": ["win", "gang", "peng", "discard", "draw", "score", "tip"],
	}


func get_event_log() -> Array[Dictionary]:
	return event_log.duplicate(true)


func get_motion_contract() -> Dictionary:
	return {
		"timings": MOTION_CONTRACT.duplicate(true),
		"event_sequences": EVENT_SEQUENCE_CONTRACTS.duplicate(true),
		"critical_motion_non_interruptible": true,
		"reduced_motion": "fade_placement_and_numeric_update_only",
	}


func set_reduced_motion(enabled: bool) -> void:
	_ensure_layers()
	for layer_value in layers.values():
		var layer_node := layer_value as Node
		if layer_node != null and layer_node.has_method("set_reduced_motion"):
			layer_node.call("set_reduced_motion", enabled)


func get_layer(layer_name: String) -> Node:
	_ensure_layers()
	return layers.get(layer_name)


func _ensure_layers() -> void:
	if not layers.is_empty():
		return
	_create_layer("TileMotionLayer", "critical tile displacement", ["draw", "discard", "peng", "gang"])
	_create_callout_layer("CalloutFxLayer", "short action and win callouts", ["peng", "gang", "win", "tip"])
	_create_layer("ScoreDeltaLayer", "signed score delta feedback", ["score"])
	_create_layer("TurnIndicatorLayer", "turn and draw orientation feedback", ["draw", "discard"])
	_create_layer("ResultTransitionLayer", "win hold and settlement transition", ["win"])


func _create_layer(layer_name: String, responsibility: String, accepted: Array[String]) -> void:
	var layer := EVENT_LAYER_SCRIPT.new() as Node
	layer.name = layer_name
	layer.call("configure", responsibility, accepted)
	add_child(layer)
	layers[layer_name] = layer


func _create_callout_layer(layer_name: String, responsibility: String, accepted: Array[String]) -> void:
	var layer := CALLOUT_LAYER_SCRIPT.new() as Node
	layer.name = layer_name
	layer.call("configure", responsibility, accepted)
	add_child(layer)
	layers[layer_name] = layer


func _normalize_event(event: Dictionary) -> Dictionary:
	var normalized := event.duplicate(true)
	var kind := str(normalized.get("kind", "tip"))
	normalized["kind"] = kind
	normalized["priority"] = int(PRIORITY.get(kind, 0))
	normalized["duration_seconds"] = float(normalized.get("duration_seconds", DURATION_SECONDS.get(kind, 0.20)))
	normalized["critical_motion"] = kind in CRITICAL_TILE_MOTION_KINDS
	normalized["decorative"] = kind in DECORATIVE_KINDS
	if kind == "peng":
		normalized["callout_delay_seconds"] = 0.22
	elif kind == "gang":
		normalized["callout_delay_seconds"] = 0.26
	elif kind == "win":
		normalized["callout_delay_seconds"] = 0.24
	return normalized


func _can_interrupt_active(incoming: Dictionary) -> bool:
	if active_event.is_empty() or bool(active_event.get("critical_motion", false)):
		return false
	return bool(active_event.get("decorative", false)) \
		and int(incoming.get("priority", 0)) > int(active_event.get("priority", 0))


func _start_event(event: Dictionary) -> void:
	active_event = event.duplicate(true)
	active_remaining_seconds = float(active_event.get("duration_seconds", 0.20))
	event_log.append({"phase": "started", "signature": active_event.get("signature"), "kind": active_event.get("kind")})
	_route_to_layers(active_event)
	event_started.emit(active_event.duplicate(true))


func _start_next_event() -> void:
	if pending_events.is_empty():
		return
	var next_event := pending_events.pop_front() as Dictionary
	_start_event(next_event)


func _sort_pending_events() -> void:
	pending_events.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_priority := int(first.get("priority", 0))
		var second_priority := int(second.get("priority", 0))
		if first_priority == second_priority:
			return int(first.get("sequence", 0)) < int(second.get("sequence", 0))
		return first_priority > second_priority
	)


func _route_to_layers(event: Dictionary) -> void:
	for layer in layers.values():
		(layer as Node).call("present", event.duplicate(true))


func _extract_events(previous_snapshot: Dictionary, snapshot: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var round_index := int(snapshot.get("round_index", active_round))
	var previous_players: Array = previous_snapshot.get("players", [])
	var players: Array = snapshot.get("players", [])
	var turn_index := int(snapshot.get("turn_index", snapshot.get("discard_count", 0)))
	for seat in range(4):
		var previous_player := _player_by_seat(previous_players, seat)
		var player := _player_by_seat(players, seat)
		var previous_discards: Array = previous_player.get("discards", [])
		var discards: Array = player.get("discards", [])
		for index in range(previous_discards.size(), discards.size()):
			var tile: Dictionary = discards[index]
			var tile_id := int(tile.get("id", -1))
			events.append({
				"kind": "discard",
				"signature": "discard:%d:%d:%d:%d" % [round_index, turn_index, seat, tile_id],
				"seat": seat,
				"tile_id": tile_id,
				"payload": tile.duplicate(true),
			})
		var previous_melds: Array = previous_player.get("melds", [])
		var melds: Array = player.get("melds", [])
		for index in range(previous_melds.size(), melds.size()):
			var meld: Dictionary = melds[index]
			var kind := "peng" if str(meld.get("type", "")) == "peng" else "gang"
			var source_seat := int(meld.get("source_seat", seat))
			var tile_id := int(meld.get("source_tile_id", _first_tile_id(meld.get("tiles", []))))
			var signature := "peng:%d:%d:%d:%d" % [round_index, seat, source_seat, tile_id]
			if kind == "gang":
				var gang_type := str(meld.get("gang_subtype", meld.get("gang_type", "melded_gang")))
				signature = "gang:%d:%d:%s:%d" % [round_index, seat, gang_type, tile_id]
			events.append({
				"kind": kind,
				"signature": signature,
				"seat": seat,
				"source_seat": source_seat,
				"tile_id": tile_id,
				"payload": meld.duplicate(true),
			})

	var previous_draw := str(previous_snapshot.get("recent_draw_display", ""))
	var draw_display := str(snapshot.get("recent_draw_display", ""))
	if not draw_display.is_empty() and draw_display != "-" and draw_display != previous_draw:
		var draw_seat := int(snapshot.get("recent_draw_seat", -1))
		var draw_tile_id := int(snapshot.get("recent_draw_tile_id", -1))
		events.append({
			"kind": "draw",
			"signature": "draw:%d:%d:%d:%d" % [round_index, turn_index, draw_seat, draw_tile_id],
			"seat": draw_seat,
			"tile_id": draw_tile_id,
		})

	var settlement: Dictionary = snapshot.get("settlement_data", {})
	for win_event in settlement.get("win_events", []):
		var winner := int(win_event.get("winner_seat", -1))
		var source := int(win_event.get("source_seat", winner))
		var winning_tile: Dictionary = win_event.get("winning_tile", {})
		var tile_id := int(winning_tile.get("id", win_event.get("winning_tile_id", -1)))
		events.append({
			"kind": "win",
			"signature": "win:%d:%d:%d:%d" % [round_index, winner, source, tile_id],
			"seat": winner,
			"source_seat": source,
			"tile_id": tile_id,
			"payload": (win_event as Dictionary).duplicate(true),
		})

	var score_changes: Dictionary = {}
	# Gang points settle immediately before the final round ledger exists.  Player
	# score deltas are presentation inputs only; they are copied and signed here,
	# never written back to the authoritative snapshot.
	var player_scores_are_authoritative := not previous_players.is_empty() and not players.is_empty()
	for seat in range(4):
		var previous_player := _player_by_seat(previous_players, seat)
		var player := _player_by_seat(players, seat)
		if previous_player.is_empty() or player.is_empty() or not previous_player.has("score") or not player.has("score"):
			player_scores_are_authoritative = false
			break
	if player_scores_are_authoritative:
		for seat in range(4):
			var previous_player := _player_by_seat(previous_players, seat)
			var player := _player_by_seat(players, seat)
			var delta := int(player.get("score", 0)) - int(previous_player.get("score", 0))
			if delta != 0:
				score_changes[seat] = delta
	else:
		score_changes = (settlement.get("score_changes", {}) as Dictionary).duplicate(true)
	var score_seats: Array = score_changes.keys()
	score_seats.sort_custom(func(first: Variant, second: Variant) -> bool: return int(first) < int(second))
	var event_index := int(settlement.get(
		"event_index",
		Array(settlement.get("gang_events", [])).size() * 100 + Array(settlement.get("win_events", [])).size()
	))
	var previous_settlement: Dictionary = previous_snapshot.get("settlement_data", {})
	var new_gang_event := Array(settlement.get("gang_events", [])).size() > Array(previous_settlement.get("gang_events", [])).size()
	var new_win_event := Array(settlement.get("win_events", [])).size() > Array(previous_settlement.get("win_events", [])).size()
	var score_component := "gang" if new_gang_event and not new_win_event else ("hu" if new_win_event else "ledger")
	for seat_key in score_seats:
		var seat := int(seat_key)
		var delta := int(score_changes.get(seat_key, 0))
		if delta == 0:
			continue
		events.append({
			"kind": "score",
			"signature": "score:%d:%d:%d:%d" % [round_index, event_index, seat, delta],
			"seat": seat,
			"delta": delta,
			"event_index": event_index,
			"score_component": score_component,
		})
	return events


func _player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if int(player.get("seat", -1)) == seat:
			return player
	return {}


func _first_tile_id(tiles: Array) -> int:
	if tiles.is_empty():
		return -1
	return int((tiles[0] as Dictionary).get("id", -1))
