class_name PresentationEventLayer
extends Node

signal event_presented(event: Dictionary)

var responsibility := ""
var accepted_kinds: Array[String] = []
var presentation_log: Array[Dictionary] = []


func configure(layer_responsibility: String, kinds: Array[String]) -> void:
	responsibility = layer_responsibility
	accepted_kinds = kinds.duplicate()


func present(event: Dictionary) -> void:
	if not accepted_kinds.has(str(event.get("kind", ""))):
		return
	var read_only_event := event.duplicate(true)
	presentation_log.append(read_only_event)
	event_presented.emit(read_only_event)


func clear_presentation_log() -> void:
	presentation_log.clear()


func get_contract() -> Dictionary:
	return {
		"responsibility": responsibility,
		"accepted_kinds": accepted_kinds.duplicate(),
		"input": "immutable presentation event duplicate",
		"writes_game_state": false,
		"writes_score_state": false,
		"writes_ai_state": false,
	}
