extends RefCounted

class_name AIManager

signal ai_turn_analysis_ready(request_id: int, seat_index: int, analysis: Dictionary)
signal ai_reaction_analysis_ready(request_id: int, seat_index: int, analysis: Dictionary)

const AICoreBridgeScript := preload("res://scripts/ai/AICoreBridge.gd")
const CSharpAIBridgeScript := preload("res://scripts/ai/csharp_ai_bridge.gd")
const CSHARP_DLL_PATH := "res://dotnet/AI.Core/bin/Release/net10.0/SichuanMahjong.AI.Core.dll"
const CSHARP_SMOKE_PROJ := "res://dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj"
const DOTNET_BIN := "/opt/homebrew/Cellar/dotnet/10.0.107/libexec/dotnet"
const TURN_BUDGET_MS := 400
const REACTION_BUDGET_MS := 180
const TURN_CACHE_LIMIT := 128
const CSHARP_HOST_DEFAULT_PORT := 38581

var bridge = AICoreBridgeScript.new()
var csharp_bridge = CSharpAIBridgeScript.new()
var prefer_csharp_backend: bool = true
var csharp_host_mode_enabled: bool = false
var csharp_host_port: int = CSHARP_HOST_DEFAULT_PORT
var latest_turn_snapshot: Dictionary = {}
var latest_reaction_snapshot: Dictionary = {}
var performance_metrics: Dictionary = _create_empty_performance_metrics()
var request_state: Dictionary = _create_empty_request_state()
var active_async_requests: Dictionary = {}
var active_async_request_keys: Dictionary = {}
var turn_analysis_cache: Dictionary = {}
var turn_cache_order: Array[String] = []
var native_csharp_runtime: Object = null
var strict_native_runtime_required: bool = true
var compact_runtime_snapshots: bool = true
var last_native_turn_error: String = ""
var last_native_reaction_error: String = ""
var last_native_turn_raw_summary: String = ""
var last_native_reaction_raw_summary: String = ""
var is_pumping_async_requests: bool = false
var native_async_enabled: bool = false


func _should_use_csharp_backend(rules_config) -> bool:
	if has_native_csharp_runtime():
		return true
	if not prefer_csharp_backend:
		return false
	if rules_config == null or not bool(rules_config.is_sichuan_mode()):
		return false
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"):
		return false
	return true


func set_native_csharp_runtime(runtime: Object) -> void:
	native_csharp_runtime = runtime


func has_native_csharp_runtime() -> bool:
	return native_csharp_runtime != null and native_csharp_runtime.has_method("IsRuntimeReady") and bool(native_csharp_runtime.call("IsRuntimeReady"))


func has_native_csharp_async_runtime() -> bool:
	return has_native_csharp_runtime() \
		and native_csharp_runtime.has_method("StartAnalyzeDiscardJson") \
		and native_csharp_runtime.has_method("StartAnalyzeReactionJson") \
		and native_csharp_runtime.has_method("PollAiResultJson")


func has_native_hell_challenge_runtime() -> bool:
	return has_native_csharp_runtime() \
		and native_csharp_runtime.has_method("AnalyzeHellChallengeDiscardJson") \
		and native_csharp_runtime.has_method("StartAnalyzeHellChallengeDiscardJson")


func has_native_hell_challenge_reaction_runtime() -> bool:
	return has_native_csharp_runtime() \
		and native_csharp_runtime.has_method("AnalyzeHellChallengeReactionJson") \
		and native_csharp_runtime.has_method("StartAnalyzeHellChallengeReactionJson")


func analyze_turn(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool = false) -> Dictionary:
	var result := _compute_turn_analysis(player_state, table_state, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat, "sync")
	_finalize_turn_analysis(int(player_state.get("seat", -1)), result)
	return result.get("analysis", {}).duplicate(true)


func analyze_reaction(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool = false) -> Dictionary:
	var result := _compute_reaction_analysis(candidate, player_state, table_state, discard_context, rules_config, ai_config, hu_checker, allow_cheat)
	_finalize_reaction_analysis(int(player_state.get("seat", -1)), result)
	return result.get("analysis", {}).duplicate(true)


func analyze_turn_lightweight(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool = false) -> Dictionary:
	var result := _compute_turn_analysis(player_state, table_state, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat, "lightweight", false, true, true)
	_finalize_turn_analysis(int(player_state.get("seat", -1)), result)
	return result.get("analysis", {}).duplicate(true)


func analyze_turn_fail_safe(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool = false) -> Dictionary:
	var payload := bridge.build_discard_payload(player_state, table_state, rules_config, ai_config, allow_cheat)
	var analysis: Dictionary = bridge.request_discard(payload, hu_checker, risk_analyzer)
	if analysis.is_empty():
		return {}
	analysis["backend_mode"] = "gdscript_sichuan_fail_safe"
	analysis["native_error"] = last_native_turn_error
	return analysis


func analyze_reaction_lightweight(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool = false) -> Dictionary:
	var result := _compute_reaction_analysis(candidate, player_state, table_state, discard_context, rules_config, ai_config, hu_checker, allow_cheat)
	_finalize_reaction_analysis(int(player_state.get("seat", -1)), result)
	return result.get("analysis", {}).duplicate(true)


func analyze_self_action(player_state: Dictionary, table_state: Dictionary, rules_config, can_self_hu: bool, an_gang_tile_types: Array, add_gang_tile_types: Array, add_gang_qiang_gang_counts: Dictionary = {}, mandatory_gang_tile_types: Array = []) -> Dictionary:
	var started_at_ms := Time.get_ticks_msec()
	var analysis: Dictionary = {}
	var active_backend := "csharp_self_action_required"
	last_native_turn_error = ""
	if has_native_csharp_runtime() and rules_config != null and bool(rules_config.is_sichuan_mode()):
		var payload: Dictionary = csharp_bridge.build_self_action_transport_payload(player_state, table_state, rules_config, can_self_hu, an_gang_tile_types, add_gang_tile_types, add_gang_qiang_gang_counts, mandatory_gang_tile_types)
		var raw := str(native_csharp_runtime.call("AnalyzeSelfActionJson", JSON.stringify(payload)))
		var parsed = JSON.parse_string(raw)
		var native_result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		if not native_result.is_empty() and bool(native_result.get("ok", true)) and not str(native_result.get("action", "")).is_empty():
			analysis = _build_csharp_self_action_analysis(native_result, "csharp_native_self_action")
			active_backend = "csharp_native_self_action"
		else:
			last_native_turn_error = str(native_result.get("error", "empty_native_self_action_result"))
	elif _should_use_csharp_backend(rules_config) and csharp_bridge.is_available():
		var csharp_result := csharp_bridge.analyze_self_action(player_state, table_state, rules_config, can_self_hu, an_gang_tile_types, add_gang_tile_types, add_gang_qiang_gang_counts, mandatory_gang_tile_types, "self_action")
		if not csharp_result.is_empty() and bool(csharp_result.get("ok", true)) and not str(csharp_result.get("action", "")).is_empty():
			analysis = _build_csharp_self_action_analysis(csharp_result, "csharp_self_action")
			active_backend = "csharp_self_action"
		else:
			last_native_turn_error = "empty_csharp_self_action_result"
	if analysis.is_empty() and rules_config != null and bool(rules_config.is_sichuan_mode()):
		last_native_turn_error = "strict_csharp_required_no_self_action_analysis" if last_native_turn_error.is_empty() else last_native_turn_error
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
	latest_turn_snapshot = {
		"seat": int(player_state.get("seat", -1)),
		"analysis": analysis.duplicate(true),
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": TURN_BUDGET_MS,
		"over_budget": elapsed_ms > TURN_BUDGET_MS,
	}
	return analysis


func analyze_ding_que(hand_tiles: Array, active_suits: Array) -> Dictionary:
	var started_at_ms := Time.get_ticks_msec()
	var analysis: Dictionary = {}
	var active_backend := "csharp_ding_que_required"
	last_native_turn_error = ""
	if has_native_csharp_runtime() and native_csharp_runtime.has_method("AnalyzeDingQueJson"):
		var payload: Dictionary = csharp_bridge.build_ding_que_transport_payload(hand_tiles, active_suits)
		var raw := str(native_csharp_runtime.call("AnalyzeDingQueJson", JSON.stringify(payload)))
		var parsed = JSON.parse_string(raw)
		var native_result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		if not native_result.is_empty() and bool(native_result.get("ok", true)) and not str(native_result.get("suit", "")).is_empty():
			analysis = native_result
			active_backend = "csharp_native_ding_que"
		else:
			last_native_turn_error = str(native_result.get("error", "empty_native_ding_que_result"))
	elif csharp_bridge.is_available():
		var csharp_result := csharp_bridge.analyze_ding_que(hand_tiles, active_suits, "ding_que")
		if not csharp_result.is_empty() and not str(csharp_result.get("suit", "")).is_empty():
			analysis = csharp_result
			active_backend = "csharp_ding_que"
		else:
			last_native_turn_error = "empty_csharp_ding_que_result"
	if analysis.is_empty():
		last_native_turn_error = "strict_csharp_required_no_ding_que_analysis" if last_native_turn_error.is_empty() else last_native_turn_error
	latest_turn_snapshot = {
		"seat": -1,
		"analysis": analysis.duplicate(true),
		"active_backend": active_backend,
		"elapsed_ms": maxi(0, Time.get_ticks_msec() - started_at_ms),
		"budget_ms": TURN_BUDGET_MS,
		"over_budget": false,
	}
	return analysis


func analyze_hell_oracle_discard(payload: Dictionary) -> Dictionary:
	if not has_native_csharp_runtime():
		last_native_turn_error = "native_runtime_unavailable_for_hell_oracle"
		return {}
	if not native_csharp_runtime.has_method("AnalyzeHellOracleDiscardJson"):
		last_native_turn_error = "hell_oracle_runtime_method_missing"
		return {}
	var raw := str(native_csharp_runtime.call("AnalyzeHellOracleDiscardJson", JSON.stringify(payload)))
	last_native_turn_raw_summary = "hell_oracle raw=%s" % raw.left(700)
	var parsed = JSON.parse_string(raw)
	var result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if result.is_empty() or not bool(result.get("ok", false)):
		last_native_turn_error = str(result.get("error", "empty_hell_oracle_result"))
		return {}
	last_native_turn_error = ""
	return result.duplicate(true)


func analyze_hell_challenge_discard(player_state: Dictionary, table_state: Dictionary, rules_config, hell_payload: Dictionary) -> Dictionary:
	if not has_native_hell_challenge_runtime():
		last_native_turn_error = "native_runtime_unavailable_for_hell_challenge"
		return {}
	var payload: Dictionary = csharp_bridge.build_discard_transport_payload(player_state, table_state, rules_config)
	for key in hell_payload.keys():
		payload[key] = hell_payload[key]
	var raw := str(native_csharp_runtime.call("AnalyzeHellChallengeDiscardJson", JSON.stringify(payload)))
	last_native_turn_raw_summary = "hell_challenge raw=%s" % raw.left(700)
	var parsed = JSON.parse_string(raw)
	var native_result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if native_result.is_empty() or not bool(native_result.get("ok", false)):
		last_native_turn_error = str(native_result.get("error", "empty_hell_challenge_result"))
		return {}
	last_native_turn_error = ""
	return _build_csharp_discard_analysis(player_state, native_result, rules_config, csharp_bridge, "hell_challenge_direct", table_state)


func analyze_hell_challenge_reaction(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, hell_payload: Dictionary) -> Dictionary:
	if not has_native_hell_challenge_reaction_runtime():
		last_native_reaction_error = "native_runtime_unavailable_for_hell_challenge_reaction"
		return {}
	var payload: Dictionary = csharp_bridge.build_reaction_transport_payload(candidate, player_state, table_state, discard_context, rules_config)
	for key in hell_payload.keys():
		payload[key] = hell_payload[key]
	var raw := str(native_csharp_runtime.call("AnalyzeHellChallengeReactionJson", JSON.stringify(payload)))
	last_native_reaction_raw_summary = "hell_challenge_reaction raw=%s" % raw.left(700)
	var native_result = JSON.parse_string(raw)
	var result: Dictionary = native_result if typeof(native_result) == TYPE_DICTIONARY else {}
	if result.is_empty() or not bool(result.get("ok", false)):
		last_native_reaction_error = str(result.get("error", "empty_hell_challenge_reaction_result"))
		return {}
	last_native_reaction_error = ""
	return _build_csharp_reaction_analysis(result, "hell_challenge_reaction_direct")


func _build_csharp_self_action_analysis(csharp_result: Dictionary, default_backend: String) -> Dictionary:
	var gang_subtype := str(csharp_result.get("gangSubtype", csharp_result.get("gang_subtype", "")))
	return {
		"action": str(csharp_result.get("action", "pass")),
		"tile_type": int(csharp_result.get("tileType", -1)),
		"gang_subtype": gang_subtype,
		"gangSubtype": gang_subtype,
		"score": int(csharp_result.get("score", 0)),
		"reason": str(csharp_result.get("reason", "")),
		"reasons": csharp_result.get("reasons", []).duplicate(true),
		"action_scores": csharp_result.get("actionScores", {}).duplicate(true),
		"backend_mode": default_backend,
		"csharp_result": csharp_result.duplicate(true),
	}


func get_debug_snapshot() -> Dictionary:
	pump_async_requests()
	return {
		"latest_turn_snapshot": latest_turn_snapshot.duplicate(true),
		"latest_reaction_snapshot": latest_reaction_snapshot.duplicate(true),
		"backend_status": get_backend_status(),
		"performance_metrics": performance_metrics.duplicate(true),
		"request_state": request_state.duplicate(true),
		"active_async_requests": _build_active_async_requests_snapshot(),
		"cache_stats": _build_cache_stats_snapshot(),
	}


func get_backend_status() -> Dictionary:
	var dll_exists := FileAccess.file_exists(ProjectSettings.globalize_path(CSHARP_DLL_PATH))
	var smoke_exists := FileAccess.file_exists(ProjectSettings.globalize_path(CSHARP_SMOKE_PROJ))
	return {
		"active_backend": str(latest_turn_snapshot.get("active_backend", "csharp_required")),
		"prefer_csharp_backend": prefer_csharp_backend,
		"native_csharp_runtime": has_native_csharp_runtime(),
		"csharp_host_mode_enabled": csharp_host_mode_enabled,
		"csharp_host_port": csharp_host_port,
		"csharp_host_connected": csharp_bridge.is_host_connected(),
		"csharp_last_transport_mode": csharp_bridge.get_last_transport_mode(),
		"csharp_last_host_error": csharp_bridge.get_last_host_error(),
		"csharp_core_built": dll_exists,
		"csharp_smoke_project": smoke_exists,
		"csharp_cli_built": csharp_bridge.is_available(),
		"strict_native_runtime_required": strict_native_runtime_required,
		"last_native_turn_error": last_native_turn_error,
		"last_native_reaction_error": last_native_reaction_error,
		"last_native_turn_raw_summary": last_native_turn_raw_summary,
		"last_native_reaction_raw_summary": last_native_reaction_raw_summary,
		"dotnet_bin": DOTNET_BIN,
		"csharp_dll_path": CSHARP_DLL_PATH,
	}


func set_prefer_csharp_backend(enabled: bool) -> void:
	prefer_csharp_backend = enabled


func set_csharp_host_mode_enabled(enabled: bool, port: int = CSHARP_HOST_DEFAULT_PORT) -> void:
	csharp_host_mode_enabled = enabled
	csharp_host_port = port
	csharp_bridge.set_host_mode_enabled(enabled, port)


func set_strict_native_runtime_required(enabled: bool) -> void:
	strict_native_runtime_required = enabled


func is_strict_native_runtime_required() -> bool:
	return strict_native_runtime_required


func set_compact_runtime_snapshots(enabled: bool) -> void:
	compact_runtime_snapshots = enabled


func set_native_async_enabled(enabled: bool) -> void:
	native_async_enabled = enabled


func should_use_native_async_requests() -> bool:
	if not native_async_enabled:
		return false
	if OS.has_feature("android") or OS.has_feature("ios"):
		return false
	return true


func request_turn_analysis_async(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool = false) -> int:
	var seat := int(player_state.get("seat", -1))
	var request_id := _begin_request("turn", seat)
	var analysis := analyze_turn(player_state, table_state, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat)
	_finish_request("turn", request_id, seat, analysis)
	ai_turn_analysis_ready.emit(request_id, seat, analysis.duplicate(true))
	return request_id


func request_reaction_analysis_async(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool = false) -> int:
	var seat := int(player_state.get("seat", -1))
	var request_id := _begin_request("reaction", seat)
	var analysis := analyze_reaction(candidate, player_state, table_state, discard_context, rules_config, ai_config, hu_checker, allow_cheat)
	_finish_request("reaction", request_id, seat, analysis)
	ai_reaction_analysis_ready.emit(request_id, seat, analysis.duplicate(true))
	return request_id


func _analyze_discard_via_native_runtime(player_state: Dictionary, table_state: Dictionary, rules_config, force_lightweight: bool = false, compact_result: bool = false) -> Dictionary:
	if not has_native_csharp_runtime():
		last_native_turn_raw_summary = "native_runtime_unavailable"
		return {}
	var payload: Dictionary = csharp_bridge.build_discard_transport_payload(player_state, table_state, rules_config, force_lightweight, compact_result)
	last_native_turn_raw_summary = "payload seat=%d hand_sum=%d wall=%d light=%s compact=%s" % [
		int(payload.get("seatIndex", -1)),
		_sum_int_array(payload.get("hand18", [])),
		int(payload.get("wallCount", -1)),
		str(force_lightweight),
		str(compact_result),
	]
	var raw := str(native_csharp_runtime.call("AnalyzeDiscardJson", JSON.stringify(payload)))
	last_native_turn_raw_summary = "%s raw=%s" % [last_native_turn_raw_summary, raw.left(700)]
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _analyze_reaction_via_native_runtime(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config) -> Dictionary:
	if not has_native_csharp_runtime():
		last_native_reaction_raw_summary = "native_runtime_unavailable"
		return {}
	var payload: Dictionary = csharp_bridge.build_reaction_transport_payload(candidate, player_state, table_state, discard_context, rules_config)
	last_native_reaction_raw_summary = "payload seat=%d tile=%d can=%s/%s/%s" % [
		int(payload.get("seatIndex", -1)),
		int(payload.get("reactionTileType", -1)),
		str(payload.get("canHu", false)),
		str(payload.get("canPeng", false)),
		str(payload.get("canGang", false)),
	]
	var raw := str(native_csharp_runtime.call("AnalyzeReactionJson", JSON.stringify(payload)))
	last_native_reaction_raw_summary = "%s raw=%s" % [last_native_reaction_raw_summary, raw.left(700)]
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _start_native_turn_analysis_background(request_id: int, player_state: Dictionary, table_state: Dictionary, rules_config, request_key: String = "", hell_payload: Dictionary = {}, force_lightweight: bool = false, compact_result: bool = false) -> bool:
	var payload_started_at := Time.get_ticks_msec()
	var payload: Dictionary = csharp_bridge.build_discard_transport_payload(player_state, table_state, rules_config, force_lightweight, compact_result)
	var use_hell_challenge := not hell_payload.is_empty() and has_native_hell_challenge_runtime()
	if use_hell_challenge:
		for key in hell_payload.keys():
			payload[key] = hell_payload[key]
	var payload_ms := maxi(0, Time.get_ticks_msec() - payload_started_at)
	var native_method := "StartAnalyzeHellChallengeDiscardJson" if use_hell_challenge and has_native_hell_challenge_runtime() else "StartAnalyzeDiscardJson"
	var native_request_id := int(native_csharp_runtime.call(native_method, JSON.stringify(payload)))
	if native_request_id <= 0:
		last_native_turn_error = "native_async_turn_start_failed"
		return false
	last_native_turn_raw_summary = "async_payload seat=%d hand_sum=%d wall=%d payload_ms=%d native_id=%d method=%s" % [
		int(payload.get("seatIndex", -1)),
		_sum_int_array(payload.get("hand18", [])),
		int(payload.get("wallCount", -1)),
		payload_ms,
		native_request_id,
		native_method,
	]
	active_async_requests[request_id] = {
		"kind": "turn",
		"seat": int(player_state.get("seat", -1)),
		"native_request_id": native_request_id,
		"player_state": player_state.duplicate(true),
		"table_state": table_state.duplicate(true),
		"rules_config": rules_config,
		"hell_challenge": use_hell_challenge,
		"force_lightweight": force_lightweight,
		"compact_result": compact_result,
		"payload_ms": payload_ms,
		"started_at_ms": Time.get_ticks_msec(),
		"request_key": request_key,
	}
	_remember_active_async_request(request_id, request_key)
	return true


func _start_native_turn_analysis_sync_delivery(request_id: int, player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool, request_key: String = "", hell_payload: Dictionary = {}, force_lightweight: bool = false, compact_result: bool = false) -> bool:
	var started_at_ms := Time.get_ticks_msec()
	var analysis: Dictionary = {}
	var active_backend := "csharp_native_sync_delivery"
	if not hell_payload.is_empty() and has_native_hell_challenge_runtime():
		var payload: Dictionary = csharp_bridge.build_discard_transport_payload(player_state, table_state, rules_config, force_lightweight, compact_result)
		for key in hell_payload.keys():
			payload[key] = hell_payload[key]
		var raw := str(native_csharp_runtime.call("AnalyzeHellChallengeDiscardJson", JSON.stringify(payload)))
		last_native_turn_raw_summary = "sync_delivery_hell raw=%s" % raw.left(700)
		var parsed = JSON.parse_string(raw)
		var native_result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		var native_error := _validate_native_discard_result(native_result)
		if not native_error.is_empty():
			last_native_turn_error = native_error
			active_backend = "hell_challenge_direct_sync_delivery_error"
		else:
			analysis = _build_csharp_discard_analysis(player_state, native_result, rules_config, csharp_bridge, "hell_challenge_direct_sync_delivery", table_state)
			active_backend = "hell_challenge_direct_sync_delivery"
	else:
		var result := _compute_turn_analysis(player_state, table_state, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat, "sync_delivery_%d" % request_id, false, force_lightweight, compact_result)
		analysis = result.get("analysis", {}).duplicate(true)
		active_backend = "csharp_native_sync_delivery" if str(result.get("active_backend", "")) == "csharp_native" else str(result.get("active_backend", "csharp_native_sync_delivery"))
	if analysis.is_empty():
		return false
	analysis["backend_mode"] = active_backend
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
	var result_payload := {
		"analysis": analysis,
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": _resolve_budget_ms("turn", active_backend),
		"over_budget": elapsed_ms > _resolve_budget_ms("turn", active_backend),
	}
	active_async_requests[request_id] = {
		"kind": "turn",
		"seat": int(player_state.get("seat", -1)),
		"completed_payload": {
			"request_id": request_id,
			"kind": "turn",
			"seat": int(player_state.get("seat", -1)),
			"result": result_payload,
		},
		"request_key": request_key,
		"started_at_ms": started_at_ms,
	}
	last_native_turn_raw_summary = "%s sync_delivery_ready request=%d elapsed_ms=%d backend=%s" % [
		last_native_turn_raw_summary,
		request_id,
		elapsed_ms,
		active_backend,
	]
	_remember_active_async_request(request_id, request_key)
	return true


func _start_native_reaction_analysis_background(request_id: int, candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, request_key: String = "", hell_payload: Dictionary = {}) -> bool:
	var payload_started_at := Time.get_ticks_msec()
	var payload: Dictionary = csharp_bridge.build_reaction_transport_payload(candidate, player_state, table_state, discard_context, rules_config)
	var use_hell_challenge := not hell_payload.is_empty() and has_native_hell_challenge_reaction_runtime()
	if use_hell_challenge:
		for key in hell_payload.keys():
			payload[key] = hell_payload[key]
	var payload_ms := maxi(0, Time.get_ticks_msec() - payload_started_at)
	var native_method := "StartAnalyzeHellChallengeReactionJson" if use_hell_challenge else "StartAnalyzeReactionJson"
	var native_request_id := int(native_csharp_runtime.call(native_method, JSON.stringify(payload)))
	if native_request_id <= 0:
		last_native_reaction_error = "native_async_reaction_start_failed"
		return false
	last_native_reaction_raw_summary = "async_payload seat=%d tile=%d can=%s/%s/%s payload_ms=%d native_id=%d method=%s" % [
		int(payload.get("seatIndex", -1)),
		int(payload.get("reactionTileType", -1)),
		str(payload.get("canHu", false)),
		str(payload.get("canPeng", false)),
		str(payload.get("canGang", false)),
		payload_ms,
		native_request_id,
		native_method,
	]
	active_async_requests[request_id] = {
		"kind": "reaction",
		"seat": int(player_state.get("seat", -1)),
		"native_request_id": native_request_id,
		"candidate": candidate.duplicate(true),
		"player_state": player_state.duplicate(true),
		"rules_config": rules_config,
		"hell_challenge": use_hell_challenge,
		"payload_ms": payload_ms,
		"started_at_ms": Time.get_ticks_msec(),
		"request_key": request_key,
	}
	_remember_active_async_request(request_id, request_key)
	return true


func _start_native_reaction_analysis_sync_delivery(request_id: int, candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool, request_key: String = "", hell_payload: Dictionary = {}) -> bool:
	var started_at_ms := Time.get_ticks_msec()
	var analysis: Dictionary = {}
	var active_backend := "hybrid_csharp_native_sync_delivery"
	if not hell_payload.is_empty() and has_native_hell_challenge_reaction_runtime():
		var payload: Dictionary = csharp_bridge.build_reaction_transport_payload(candidate, player_state, table_state, discard_context, rules_config)
		for key in hell_payload.keys():
			payload[key] = hell_payload[key]
		var raw := str(native_csharp_runtime.call("AnalyzeHellChallengeReactionJson", JSON.stringify(payload)))
		last_native_reaction_raw_summary = "sync_delivery_hell raw=%s" % raw.left(700)
		var parsed = JSON.parse_string(raw)
		var native_result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		var native_error := _validate_native_reaction_result(native_result)
		if not native_error.is_empty():
			last_native_reaction_error = native_error
			active_backend = "hell_challenge_reaction_direct_sync_delivery_error"
		else:
			analysis = _build_csharp_reaction_analysis(native_result, "hell_challenge_reaction_direct_sync_delivery")
			active_backend = "hell_challenge_reaction_direct_sync_delivery"
	else:
		var result := _compute_reaction_analysis(candidate, player_state, table_state, discard_context, rules_config, ai_config, hu_checker, allow_cheat)
		analysis = result.get("analysis", {}).duplicate(true)
		active_backend = "hybrid_csharp_native_sync_delivery" if str(result.get("active_backend", "")) == "hybrid_csharp_native" else str(result.get("active_backend", "hybrid_csharp_native_sync_delivery"))
	if analysis.is_empty():
		return false
	analysis["backend_mode"] = active_backend
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
	var result_payload := {
		"analysis": analysis,
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": _resolve_budget_ms("reaction", active_backend),
		"over_budget": elapsed_ms > _resolve_budget_ms("reaction", active_backend),
	}
	active_async_requests[request_id] = {
		"kind": "reaction",
		"seat": int(player_state.get("seat", -1)),
		"completed_payload": {
			"request_id": request_id,
			"kind": "reaction",
			"seat": int(player_state.get("seat", -1)),
			"result": result_payload,
		},
		"request_key": request_key,
		"started_at_ms": started_at_ms,
	}
	last_native_reaction_raw_summary = "%s sync_delivery_ready request=%d elapsed_ms=%d backend=%s" % [
		last_native_reaction_raw_summary,
		request_id,
		elapsed_ms,
		active_backend,
	]
	_remember_active_async_request(request_id, request_key)
	return true


func _poll_native_async_request(request_id: int, request: Dictionary) -> int:
	if not has_native_csharp_async_runtime():
		var kind_for_unavailable := str(request.get("kind", ""))
		var age_ms := maxi(0, Time.get_ticks_msec() - int(request.get("started_at_ms", Time.get_ticks_msec())))
		var unavailable_summary := "async_pending_native_runtime_unavailable request=%d native_id=%d age_ms=%d" % [
			request_id,
			int(request.get("native_request_id", 0)),
			age_ms,
		]
		if kind_for_unavailable == "reaction":
			last_native_reaction_error = "native_async_runtime_unavailable_while_pending"
			last_native_reaction_raw_summary = unavailable_summary
		else:
			last_native_turn_error = "native_async_runtime_unavailable_while_pending"
			last_native_turn_raw_summary = unavailable_summary
		return -1
	var native_request_id := int(request.get("native_request_id", 0))
	var raw := str(native_csharp_runtime.call("PollAiResultJson", native_request_id))
	var parsed = JSON.parse_string(raw)
	var native_result: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var kind := str(request.get("kind", ""))
	if bool(native_result.get("pending", false)):
		var age_ms := maxi(0, Time.get_ticks_msec() - int(request.get("started_at_ms", Time.get_ticks_msec())))
		var pending_summary := "async_pending request=%d native_id=%d age_ms=%d status=%s native_elapsed=%d thread=%d raw=%s" % [
			request_id,
			native_request_id,
			age_ms,
			str(native_result.get("status", "")),
			int(native_result.get("elapsedMs", -1)),
			int(native_result.get("managedThreadId", -1)),
			raw.left(260),
		]
		if kind == "reaction":
			last_native_reaction_raw_summary = pending_summary
		else:
			last_native_turn_raw_summary = pending_summary
		return -1
	if kind == "turn":
		return _deliver_native_turn_payload(request_id, request, native_result)
	if kind == "reaction":
		return _deliver_native_reaction_payload(request_id, request, native_result)
	return 0


func _deliver_native_turn_payload(request_id: int, request: Dictionary, native_result: Dictionary) -> int:
	var seat := int(request.get("seat", -1))
	var payload_ms := int(request.get("payload_ms", 0))
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - int(request.get("started_at_ms", Time.get_ticks_msec())))
	var native_error := _validate_native_discard_result(native_result)
	var analysis: Dictionary = {}
	var active_backend := "hell_challenge_direct_async" if bool(request.get("hell_challenge", false)) else "csharp_native_async"
	if native_error.is_empty():
		analysis = _build_csharp_discard_analysis(request.get("player_state", {}), native_result, request.get("rules_config"), csharp_bridge, active_backend, request.get("table_state", {}))
		last_native_turn_error = ""
	else:
		last_native_turn_error = native_error
		active_backend = "csharp_native_async_error"
	last_native_turn_raw_summary = "async_done request=%d native_id=%d elapsed_ms=%d payload_ms=%d native_ms=%d belief=%s err=%s raw=%s" % [
		request_id,
		int(request.get("native_request_id", 0)),
		elapsed_ms,
		payload_ms,
		int(native_result.get("elapsedMs", -1)),
		JSON.stringify(native_result.get("beliefMetrics", {})).left(220),
		native_error,
		JSON.stringify(native_result).left(700),
	]
	var budget_ms := _resolve_budget_ms("turn", active_backend)
	var result := {
		"analysis": analysis,
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": budget_ms,
		"over_budget": elapsed_ms > budget_ms,
		"payload_ms": payload_ms,
	}
	return _deliver_async_payload({
		"request_id": request_id,
		"kind": "turn",
		"seat": seat,
		"result": result,
	})


func _deliver_native_reaction_payload(request_id: int, request: Dictionary, native_result: Dictionary) -> int:
	var seat := int(request.get("seat", -1))
	var payload_ms := int(request.get("payload_ms", 0))
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - int(request.get("started_at_ms", Time.get_ticks_msec())))
	var native_error := _validate_native_reaction_result(native_result)
	var analysis: Dictionary = {}
	var active_backend := "hell_challenge_reaction_direct_async" if bool(request.get("hell_challenge", false)) else "hybrid_csharp_native_async"
	if native_error.is_empty():
		analysis = _build_csharp_reaction_analysis(native_result, active_backend)
		last_native_reaction_error = ""
	else:
		last_native_reaction_error = native_error
		active_backend = "hybrid_csharp_native_async_error"
	last_native_reaction_raw_summary = "async_done request=%d native_id=%d elapsed_ms=%d payload_ms=%d native_ms=%d belief=%s err=%s raw=%s" % [
		request_id,
		int(request.get("native_request_id", 0)),
		elapsed_ms,
		payload_ms,
		int(native_result.get("elapsedMs", -1)),
		JSON.stringify(native_result.get("beliefMetrics", {})).left(220),
		native_error,
		JSON.stringify(native_result).left(700),
	]
	var budget_ms := _resolve_budget_ms("reaction", active_backend)
	var result := {
		"analysis": analysis,
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": budget_ms,
		"over_budget": elapsed_ms > budget_ms,
		"payload_ms": payload_ms,
	}
	return _deliver_async_payload({
		"request_id": request_id,
		"kind": "reaction",
		"seat": seat,
		"result": result,
	})


func _build_csharp_reaction_analysis(csharp_result: Dictionary, default_backend: String) -> Dictionary:
	return {
		"action": str(csharp_result.get("action", "pass")),
		"score": int(csharp_result.get("score", 0)),
		"reasons": csharp_result.get("reasons", []).duplicate(true),
		"reason": str(csharp_result.get("reason", "")),
		"shanten_after": int(csharp_result.get("shantenAfter", 8)),
		"live_ukeire_after": int(csharp_result.get("liveUkeireAfter", 0)),
		"ukeire_after": int(csharp_result.get("ukeireAfter", 0)),
		"current_shanten": int(csharp_result.get("currentShanten", 8)),
		"current_live_ukeire": int(csharp_result.get("currentLiveUkeire", 0)),
		"threat_level": int(csharp_result.get("threatLevel", 0)),
		"round_stage": int(csharp_result.get("roundStage", 0)),
		"round_stage_label": str(csharp_result.get("roundStageLabel", "")),
		"max_ready_posterior": float(csharp_result.get("maxReadyPosterior", 0.0)),
		"posterior_summary": csharp_result.get("posteriorSummary", []).duplicate(true),
		"future_summary": csharp_result.get("futureSummary", []).duplicate(true),
		"search_bonus": float(csharp_result.get("searchBonus", 0.0)),
		"search_simulations": int(csharp_result.get("searchSimulations", 0)),
		"search_used": bool(csharp_result.get("searchUsed", false)),
		"action_scores": csharp_result.get("actionScores", {}).duplicate(true),
		"backend_mode": default_backend,
		"csharp_result": csharp_result.duplicate(true),
	}


func _build_csharp_discard_analysis(player_state: Dictionary, csharp_result: Dictionary, rules_config, bridge_instance, backend_mode: String, table_state: Dictionary = {}) -> Dictionary:
	if csharp_result.is_empty():
		return {}
	var action_tile_type := int(csharp_result.get("tileType", -1))
	var active_suits: Array = bridge_instance.tile_codec.resolve_active_suits(rules_config)
	var hand_tiles: Array = player_state.get("hand_tiles", [])
	var preferred_tile_by_type := _build_preferred_discard_tile_by_type(player_state, table_state, active_suits, bridge_instance)
	var hand_tile_by_type: Dictionary = {}
	for tile in hand_tiles:
		var tile_type: int = int(bridge_instance.tile_codec.tile_type(tile, active_suits))
		if tile_type >= 0 and preferred_tile_by_type.has(tile_type):
			hand_tile_by_type[tile_type] = preferred_tile_by_type[tile_type].duplicate(true)
		elif tile_type >= 0 and not hand_tile_by_type.has(tile_type):
			hand_tile_by_type[tile_type] = tile.duplicate(true)
	var action := str(csharp_result.get("action", "")).strip_edges().to_lower()
	if action == "gang":
		return _build_csharp_turn_gang_analysis(
			player_state,
			csharp_result,
			active_suits,
			bridge_instance,
			backend_mode,
			hand_tile_by_type
		)
	var candidate_source: Array = csharp_result.get("candidates", [])
	if candidate_source.is_empty() and action == "discard" and action_tile_type >= 0:
		candidate_source = [_build_top_level_csharp_discard_candidate(csharp_result)]
	var enriched: Array = []
	for candidate in candidate_source:
		var csharp_item: Dictionary = candidate
		var tile_type := int(csharp_item.get("tileType", -1))
		if not hand_tile_by_type.has(tile_type):
			continue
		var support_option := {
			"tile": hand_tile_by_type[tile_type].duplicate(true),
			"tile_name": str(hand_tile_by_type[tile_type].get("display_name", "")),
			"tile_key": "%s_%d" % [str(hand_tile_by_type[tile_type].get("suit", "")), int(hand_tile_by_type[tile_type].get("rank", 0))],
		}
		enriched.append(_build_hybrid_option(csharp_item, support_option, active_suits, bridge_instance))
	if enriched.is_empty():
		return {}
	var recommended := _select_csharp_recommended_option(enriched, action_tile_type)
	var danger_tiles: Array = enriched.duplicate(true)
	danger_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("risk", 0)) > int(b.get("risk", 0))
	)
	return {
		"forced_discard_suit": "",
		"recommended": recommended,
		"options": enriched,
		"danger_tiles": danger_tiles.slice(0, mini(3, danger_tiles.size())),
		"current_routes": csharp_result.get("currentRoutes", []).duplicate(true),
		"route_plan": csharp_result.get("routePlan", {}).duplicate(true),
		"strategy_profile": _merge_strategy_profile({}, csharp_result.get("strategyProfile", {})),
		"belief_summary": csharp_result.get("beliefSummary", {}).duplicate(true),
		"csharp_result": _compact_csharp_result(csharp_result) if compact_runtime_snapshots else csharp_result.duplicate(true),
		"backend_mode": backend_mode,
	}


func _build_top_level_csharp_discard_candidate(csharp_result: Dictionary) -> Dictionary:
	return {
		"tileType": int(csharp_result.get("tileType", -1)),
		"score": int(csharp_result.get("score", 0)),
		"shanten": int(csharp_result.get("shanten", 0)),
		"ukeire": int(csharp_result.get("ukeire", 0)),
		"liveUkeire": int(csharp_result.get("liveUkeire", 0)),
		"danger": 100 if bool(csharp_result.get("oracleExactDealIn", false)) else 0,
		"waitCount": int(csharp_result.get("waitCount", 0)),
		"riskLabel": str(csharp_result.get("riskLabel", "")),
		"strategyTag": str(csharp_result.get("category", "")),
		"strategyMode": str(csharp_result.get("backendMode", "")),
		"explanationHint": str(Array(csharp_result.get("reasons", [])).front() if not Array(csharp_result.get("reasons", [])).is_empty() else ""),
		"reasons": Array(csharp_result.get("reasons", [])).duplicate(true),
	}


func _build_csharp_turn_gang_analysis(player_state: Dictionary, csharp_result: Dictionary, active_suits: Array, bridge_instance, backend_mode: String, hand_tile_by_type: Dictionary) -> Dictionary:
	var tile_type := int(csharp_result.get("tileType", -1))
	if not hand_tile_by_type.has(tile_type):
		return {}
	var tile: Dictionary = hand_tile_by_type[tile_type].duplicate(true)
	var gang_subtype := str(csharp_result.get("gangSubtype", csharp_result.get("gang_subtype", ""))).strip_edges()
	if gang_subtype == "":
		gang_subtype = _infer_csharp_turn_gang_subtype(player_state, tile_type, active_suits, bridge_instance)
	if gang_subtype == "":
		return {}
	var support_option := {
		"tile": tile.duplicate(true),
		"tile_name": str(tile.get("display_name", "")),
		"tile_key": "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))],
	}
	var csharp_item := {
		"tileType": tile_type,
		"score": int(csharp_result.get("score", 0)),
		"reasons": Array(csharp_result.get("reasons", [])),
	}
	var recommended := _build_hybrid_option(csharp_item, support_option, active_suits, bridge_instance)
	return {
		"action": "gang",
		"gang_subtype": gang_subtype,
		"gangSubtype": gang_subtype,
		"tile_type": tile_type,
		"tile": tile.duplicate(true),
		"recommended": recommended,
		"options": [recommended],
		"danger_tiles": [],
		"current_routes": csharp_result.get("currentRoutes", []).duplicate(true),
		"route_plan": csharp_result.get("routePlan", {}).duplicate(true),
		"strategy_profile": _merge_strategy_profile({}, csharp_result.get("strategyProfile", {})),
		"belief_summary": csharp_result.get("beliefSummary", {}).duplicate(true),
		"csharp_result": _compact_csharp_result(csharp_result) if compact_runtime_snapshots else csharp_result.duplicate(true),
		"backend_mode": backend_mode,
	}


func _infer_csharp_turn_gang_subtype(player_state: Dictionary, tile_type: int, active_suits: Array, bridge_instance) -> String:
	var hand_count := 0
	for tile in player_state.get("hand_tiles", []):
		if int(bridge_instance.tile_codec.tile_type(tile, active_suits)) == tile_type:
			hand_count += 1
	if hand_count >= 4:
		return "an_gang"
	for meld in player_state.get("melds", []):
		var meld_dict: Dictionary = meld
		if str(meld_dict.get("type", "")) != "peng":
			continue
		var matches := 0
		for meld_tile in meld_dict.get("tiles", []):
			if int(bridge_instance.tile_codec.tile_type(meld_tile, active_suits)) == tile_type:
				matches += 1
		if matches >= 3 and hand_count >= 1:
			return "add_gang"
	return ""


func start_turn_analysis_background(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool = false, hell_payload: Dictionary = {}, force_lightweight: bool = false, compact_result: bool = false, force_native_async: bool = false, allow_sync_delivery: bool = true) -> int:
	var seat := int(player_state.get("seat", -1))
	var request_key := _build_active_turn_request_key(player_state, table_state, rules_config, allow_cheat, force_lightweight)
	if not hell_payload.is_empty():
		request_key = "%s|hell_challenge" % request_key
	var existing_request_id := _find_active_async_request(request_key)
	if existing_request_id > 0:
		_record_duplicate_async_request("turn", seat, existing_request_id, request_key)
		return existing_request_id
	var request_id := _begin_request("turn", seat)
	if allow_sync_delivery and not force_native_async and _start_native_turn_analysis_sync_delivery(request_id, player_state, table_state, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat, request_key, hell_payload, force_lightweight, compact_result):
		return request_id
	if has_native_csharp_async_runtime() and rules_config != null and bool(rules_config.is_sichuan_mode()):
		if (force_native_async or should_use_native_async_requests()) and _start_native_turn_analysis_background(request_id, player_state, table_state, rules_config, request_key, hell_payload, force_lightweight, compact_result):
			return request_id
		request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
		return 0
	if allow_sync_delivery:
		request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
		return 0
	var thread := Thread.new()
	active_async_requests[request_id] = {
		"kind": "turn",
		"seat": seat,
		"thread": thread,
		"request_key": request_key,
	}
	_remember_active_async_request(request_id, request_key)
	var started := thread.start(Callable(self, "_thread_compute_turn").bind(
		request_id,
		player_state.duplicate(true),
		table_state.duplicate(true),
		rules_config,
		ai_config,
		hu_checker,
		risk_analyzer,
		allow_cheat,
		force_lightweight,
		compact_result
	))
	if started != OK:
		_forget_active_async_request(request_id, active_async_requests.get(request_id, {}))
		request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
		return 0
	return request_id


func start_reaction_analysis_background(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool = false, hell_payload: Dictionary = {}, force_native_async: bool = false, allow_sync_delivery: bool = true) -> int:
	var seat := int(player_state.get("seat", -1))
	var request_key := _build_active_reaction_request_key(candidate, player_state, table_state, discard_context, rules_config, allow_cheat)
	if not hell_payload.is_empty():
		request_key = "%s|hell_challenge" % request_key
	var existing_request_id := _find_active_async_request(request_key)
	if existing_request_id > 0:
		_record_duplicate_async_request("reaction", seat, existing_request_id, request_key)
		return existing_request_id
	var request_id := _begin_request("reaction", seat)
	if allow_sync_delivery and not force_native_async and _start_native_reaction_analysis_sync_delivery(request_id, candidate, player_state, table_state, discard_context, rules_config, ai_config, hu_checker, allow_cheat, request_key, hell_payload):
		return request_id
	if has_native_csharp_async_runtime() and rules_config != null and bool(rules_config.is_sichuan_mode()):
		if (force_native_async or should_use_native_async_requests()) and _start_native_reaction_analysis_background(request_id, candidate, player_state, table_state, discard_context, rules_config, request_key, hell_payload):
			return request_id
		request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
		return 0
	if allow_sync_delivery:
		request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
		return 0
	var thread := Thread.new()
	active_async_requests[request_id] = {
		"kind": "reaction",
		"seat": seat,
		"thread": thread,
		"request_key": request_key,
	}
	_remember_active_async_request(request_id, request_key)
	var started := thread.start(Callable(self, "_thread_compute_reaction").bind(
		request_id,
		candidate.duplicate(true),
		player_state.duplicate(true),
		table_state.duplicate(true),
		discard_context.duplicate(true),
		rules_config,
		ai_config,
		hu_checker,
		allow_cheat
	))
	if started != OK:
		_forget_active_async_request(request_id, active_async_requests.get(request_id, {}))
		request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
		return 0
	return request_id


func pump_async_requests() -> int:
	if active_async_requests.is_empty():
		return 0
	if is_pumping_async_requests:
		return 0
	is_pumping_async_requests = true
	var completed_ids: Array = []
	var delivered_count := 0
	for request_id in active_async_requests.keys():
		var request: Dictionary = active_async_requests.get(request_id, {})
		if request.has("completed_payload"):
			var completed_payload: Dictionary = request.get("completed_payload", {})
			completed_ids.append(request_id)
			delivered_count += _deliver_async_payload(completed_payload)
			continue
		if request.has("native_request_id"):
			var native_delivery := _poll_native_async_request(int(request_id), request)
			if native_delivery < 0:
				continue
			completed_ids.append(request_id)
			delivered_count += native_delivery
			continue
		var thread: Thread = request.get("thread")
		if thread == null or thread.is_alive():
			continue
		var payload = thread.wait_to_finish()
		completed_ids.append(request_id)
		delivered_count += _deliver_async_payload(payload if typeof(payload) == TYPE_DICTIONARY else {})
	for request_id in completed_ids:
		_forget_active_async_request(int(request_id), active_async_requests.get(request_id, {}))
	is_pumping_async_requests = false
	return delivered_count


func has_pending_async_requests() -> bool:
	return not active_async_requests.is_empty()


func _merge_csharp_discard_recommendation(base_analysis: Dictionary, csharp_result: Dictionary, rules_config) -> Dictionary:
	return _merge_csharp_discard_recommendation_with_bridge(base_analysis, csharp_result, rules_config, csharp_bridge)


func _merge_csharp_discard_recommendation_with_bridge(base_analysis: Dictionary, csharp_result: Dictionary, rules_config, bridge_instance) -> Dictionary:
	if csharp_result.is_empty():
		return base_analysis
	var action_tile_type := int(csharp_result.get("tileType", -1))
	var active_suits: Array = bridge_instance.tile_codec.resolve_active_suits(rules_config)
	var support_map: Dictionary = base_analysis.get("option_support", {})
	var enriched: Array = []
	for candidate in csharp_result.get("candidates", []):
		var csharp_item: Dictionary = candidate
		var tile_type: int = int(csharp_item.get("tileType", -1))
		var support_option: Dictionary = support_map.get(tile_type, {}).duplicate(true)
		enriched.append(_build_hybrid_option(csharp_item, support_option, active_suits, bridge_instance))
	if enriched.is_empty():
		return base_analysis
	var recommended := _select_csharp_recommended_option(enriched, action_tile_type)
	var danger_tiles: Array = enriched.duplicate(true)
	danger_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("risk", 0)) > int(b.get("risk", 0))
	)
	return {
		"forced_discard_suit": str(base_analysis.get("forced_discard_suit", "")),
		"recommended": recommended,
		"options": enriched,
		"danger_tiles": danger_tiles.slice(0, mini(3, danger_tiles.size())),
		"current_routes": csharp_result.get("currentRoutes", base_analysis.get("current_routes", [])).duplicate(true),
		"route_plan": csharp_result.get("routePlan", base_analysis.get("route_plan", {})).duplicate(true),
		"strategy_profile": _merge_strategy_profile(base_analysis.get("strategy_profile", {}), csharp_result.get("strategyProfile", {})),
		"belief_summary": csharp_result.get("beliefSummary", {}).duplicate(true),
		"csharp_result": _compact_csharp_result(csharp_result) if compact_runtime_snapshots else csharp_result.duplicate(true),
		"backend_mode": "hybrid_csharp",
	}


func _select_csharp_recommended_option(enriched_options: Array, action_tile_type: int) -> Dictionary:
	if action_tile_type >= 0:
		for option in enriched_options:
			var item: Dictionary = option
			if int(item.get("csharp_tile_type", -1)) == action_tile_type:
				return item
	return enriched_options[0] if not enriched_options.is_empty() else {}


func _build_preferred_discard_tile_by_type(player_state: Dictionary, table_state: Dictionary, active_suits: Array, bridge_instance) -> Dictionary:
	var result: Dictionary = {}
	if not bool(player_state.get("bao_jiao", false)):
		return result
	var self_seat := int(player_state.get("seat", -1))
	var last_draw: Dictionary = table_state.get("last_draw_tile", {})
	if int(last_draw.get("seat", -1)) != self_seat:
		return result
	var last_draw_tile: Dictionary = last_draw.get("tile", {})
	var last_draw_type := int(bridge_instance.tile_codec.tile_type(last_draw_tile, active_suits))
	if last_draw_type < 0:
		return result
	for tile in player_state.get("hand_tiles", []):
		var hand_tile: Dictionary = tile
		if int(hand_tile.get("id", -1)) == int(last_draw_tile.get("id", -2)):
			result[last_draw_type] = hand_tile.duplicate(true)
			return result
	return result


func _build_hybrid_option(csharp_item: Dictionary, support_option: Dictionary, active_suits: Array, bridge_instance = null) -> Dictionary:
	var tile_type: int = int(csharp_item.get("tileType", -1))
	var option: Dictionary = support_option.duplicate(true)
	var tile: Dictionary = option.get("tile", {}).duplicate(true)
	if tile.is_empty():
		var effective_bridge = bridge_instance if bridge_instance != null else csharp_bridge
		tile = effective_bridge.tile_codec.decode_type(tile_type, active_suits)
	option["tile"] = tile
	option["tile_name"] = str(option.get("tile_name", tile.get("display_name", "?")))
	option["tile_key"] = str(option.get("tile_key", "%s_%d" % [str(tile.get("suit", "")), int(tile.get("rank", 0))]))
	option["csharp_tile_type"] = tile_type
	option["csharp_fast_ting_discard_rank"] = int(csharp_item.get("fastTingDiscardRank", option.get("fast_ting_discard_rank", 99)))
	option["csharp_score"] = int(csharp_item.get("score", option.get("score", 0)))
	option["csharp_shanten"] = int(csharp_item.get("shanten", option.get("shanten", 8)))
	option["csharp_ukeire"] = int(csharp_item.get("ukeire", option.get("ukeire", 0)))
	option["csharp_live_ukeire"] = int(csharp_item.get("liveUkeire", option.get("live_ukeire", 0)))
	option["csharp_danger"] = int(csharp_item.get("danger", option.get("risk", 0)))
	option["csharp_wait_count"] = int(csharp_item.get("waitCount", option.get("wait_count", 0)))
	option["csharp_wait_quality_score"] = int(csharp_item.get("waitQualityScore", option.get("wait_quality_score", 0)))
	option["csharp_risk_label"] = str(csharp_item.get("riskLabel", option.get("risk_label", "")))
	option["csharp_strategy_tag"] = str(csharp_item.get("strategyTag", option.get("strategy_tag", "")))
	option["csharp_strategy_mode"] = str(csharp_item.get("strategyMode", option.get("strategy_mode", "")))
	option["csharp_explanation_hint"] = str(csharp_item.get("explanationHint", option.get("explanation_hint", "")))
	option["csharp_route_plan_primary"] = str(csharp_item.get("routePlanPrimary", option.get("route_plan_primary", "")))
	option["csharp_route_plan_score"] = int(csharp_item.get("routePlanScore", option.get("route_plan_score", 0)))
	option["csharp_tenpai_probability"] = float(csharp_item.get("tenpaiProbability", option.get("tenpai_probability", 0.0)))
	option["csharp_self_draw_probability"] = float(csharp_item.get("selfDrawProbability", option.get("self_draw_probability", 0.0)))
	option["csharp_win_probability"] = float(csharp_item.get("winProbability", option.get("win_probability", 0.0)))
	option["csharp_deal_in_probability"] = float(csharp_item.get("dealInProbability", option.get("deal_in_probability", 0.0)))
	option["csharp_expected_value"] = float(csharp_item.get("expectedValue", option.get("expected_value", 0.0)))
	option["csharp_expected_net_score"] = float(csharp_item.get("expectedNetScore", option.get("expected_net_score", 0.0)))
	option["csharp_expected_win_gain"] = float(csharp_item.get("expectedWinGain", option.get("expected_win_gain", 0.0)))
	option["csharp_expected_deal_in_loss"] = float(csharp_item.get("expectedDealInLoss", option.get("expected_deal_in_loss", 0.0)))
	option["csharp_expected_draw_risk_loss"] = float(csharp_item.get("expectedDrawRiskLoss", option.get("expected_draw_risk_loss", 0.0)))
	option["csharp_expected_ready_value"] = float(csharp_item.get("expectedReadyValue", option.get("expected_ready_value", 0.0)))
	option["csharp_posterior_adjustment"] = float(csharp_item.get("posteriorAdjustment", 0.0))
	option["csharp_defense_adjustment"] = float(csharp_item.get("defenseAdjustment", 0.0))
	option["csharp_good_shape_count"] = int(csharp_item.get("goodShapeCount", 0))
	option["csharp_bad_shape_count"] = int(csharp_item.get("badShapeCount", 0))
	option["csharp_pair_pressure"] = int(csharp_item.get("pairPressure", 0))
	option["csharp_taatsu_overflow"] = int(csharp_item.get("taatsuOverflow", 0))
	option["csharp_same_shanten_improvement_count"] = int(csharp_item.get("sameShantenImprovementCount", 0))
	option["csharp_middle_tile_flexibility"] = int(csharp_item.get("middleTileFlexibility", 0))
	option["csharp_shape_score"] = float(csharp_item.get("shapeScore", 0.0))
	option["csharp_breaks_pair"] = bool(csharp_item.get("breaksPair", false))
	option["csharp_breaks_triplet"] = bool(csharp_item.get("breaksTriplet", false))
	option["csharp_set_preservation_score"] = float(csharp_item.get("setPreservationScore", 0.0))
	option["csharp_wait_shape_label"] = str(csharp_item.get("waitShapeLabel", ""))
	option["csharp_wait_shape_score"] = float(csharp_item.get("waitShapeScore", 0.0))
	option["csharp_ryanmen_wait_count"] = int(csharp_item.get("ryanmenWaitCount", 0))
	option["csharp_kanchan_wait_count"] = int(csharp_item.get("kanchanWaitCount", 0))
	option["csharp_penchan_wait_count"] = int(csharp_item.get("penchanWaitCount", 0))
	option["csharp_tanki_wait_count"] = int(csharp_item.get("tankiWaitCount", 0))
	option["csharp_shanpon_wait_count"] = int(csharp_item.get("shanponWaitCount", 0))
	option["csharp_limited_lookahead_score"] = float(csharp_item.get("limitedLookaheadScore", 0.0))
	option["csharp_limited_lookahead_samples"] = int(csharp_item.get("limitedLookaheadSamples", 0))
	option["csharp_limited_lookahead_best_shanten"] = int(csharp_item.get("limitedLookaheadBestShanten", 8))
	option["csharp_limited_lookahead_best_live_ukeire"] = int(csharp_item.get("limitedLookaheadBestLiveUkeire", 0))
	option["csharp_search_bonus"] = float(csharp_item.get("searchBonus", 0.0))
	option["csharp_search_simulations"] = int(csharp_item.get("searchSimulations", 0))
	option["csharp_search_used"] = bool(csharp_item.get("searchUsed", false))
	option["csharp_posterior_reasons"] = csharp_item.get("posteriorReasons", []).duplicate(true)
	option["csharp_risk_reasons"] = csharp_item.get("riskReasons", option.get("risk_reasons", [])).duplicate(true)
	option["csharp_reasons"] = csharp_item.get("reasons", []).duplicate(true)
	option["csharp_exact_deal_in"] = bool(csharp_item.get("exactDealIn", option.get("exact_deal_in", false)))
	option["csharp_feeds_human_hu"] = bool(csharp_item.get("feedsHumanHu", option.get("feeds_human_hu", false)))
	option["csharp_feeds_human_peng"] = bool(csharp_item.get("feedsHumanPeng", option.get("feeds_human_peng", false)))
	option["csharp_feeds_human_gang"] = bool(csharp_item.get("feedsHumanGang", option.get("feeds_human_gang", false)))
	option["csharp_human_peng_threat"] = int(csharp_item.get("humanPengThreat", option.get("human_peng_threat", 0)))
	option["csharp_human_peng_penalty"] = int(csharp_item.get("humanPengPenalty", option.get("human_peng_penalty", 0)))
	option["csharp_tempo_peng_allowance_bonus"] = int(csharp_item.get("tempoPengAllowanceBonus", option.get("tempo_peng_allowance_bonus", 0)))
	option["csharp_peng_only_interaction_bonus"] = int(csharp_item.get("pengOnlyInteractionBonus", option.get("peng_only_interaction_bonus", 0)))
	option["csharp_keeps_ready"] = bool(csharp_item.get("keepsReady", option.get("keeps_ready", false)))
	option["csharp_exact_wall_remaining"] = int(csharp_item.get("exactWallRemaining", option.get("exact_wall_remaining", 0)))
	option["csharp_deal_in_target_seats"] = csharp_item.get("dealInTargetSeats", option.get("deal_in_target_seats", [])).duplicate(true)
	option["fast_ting_discard_rank"] = int(csharp_item.get("fastTingDiscardRank", option.get("fast_ting_discard_rank", 99)))
	option["score"] = int(csharp_item.get("score", option.get("score", 0)))
	option["shanten"] = int(csharp_item.get("shanten", option.get("shanten", 8)))
	option["ukeire"] = int(csharp_item.get("ukeire", option.get("ukeire", 0)))
	option["live_ukeire"] = int(csharp_item.get("liveUkeire", option.get("live_ukeire", 0)))
	option["risk"] = int(csharp_item.get("danger", option.get("risk", 0)))
	option["wait_count"] = int(csharp_item.get("waitCount", option.get("wait_count", 0)))
	option["wait_quality_score"] = int(csharp_item.get("waitQualityScore", option.get("wait_quality_score", 0)))
	option["risk_label"] = str(csharp_item.get("riskLabel", option.get("risk_label", "")))
	option["strategy_tag"] = str(csharp_item.get("strategyTag", option.get("strategy_tag", "")))
	option["strategy_mode"] = str(csharp_item.get("strategyMode", option.get("strategy_mode", "定缺速听")))
	option["explanation_hint"] = str(csharp_item.get("explanationHint", option.get("explanation_hint", "")))
	option["route_plan_primary"] = str(csharp_item.get("routePlanPrimary", option.get("route_plan_primary", "")))
	option["route_plan_score"] = int(csharp_item.get("routePlanScore", option.get("route_plan_score", 0)))
	option["routes_after"] = csharp_item.get("routesAfter", option.get("routes_after", [])).duplicate(true)
	option["route_loss"] = csharp_item.get("routeLoss", option.get("route_loss", [])).duplicate(true)
	option["tenpai_probability"] = float(csharp_item.get("tenpaiProbability", option.get("tenpai_probability", 0.0)))
	option["self_draw_probability"] = float(csharp_item.get("selfDrawProbability", option.get("self_draw_probability", 0.0)))
	option["win_probability"] = float(csharp_item.get("winProbability", option.get("win_probability", 0.0)))
	option["discard_hu_probability"] = maxf(0.0, float(option.get("win_probability", 0.0)) - float(option.get("self_draw_probability", 0.0)))
	option["deal_in_probability"] = float(csharp_item.get("dealInProbability", option.get("deal_in_probability", 0.0)))
	option["expected_value"] = float(csharp_item.get("expectedValue", option.get("expected_value", 0.0)))
	option["expected_net_score"] = float(csharp_item.get("expectedNetScore", option.get("expected_net_score", 0.0)))
	option["expected_win_gain"] = float(csharp_item.get("expectedWinGain", option.get("expected_win_gain", 0.0)))
	option["expected_deal_in_loss"] = float(csharp_item.get("expectedDealInLoss", option.get("expected_deal_in_loss", 0.0)))
	option["expected_draw_risk_loss"] = float(csharp_item.get("expectedDrawRiskLoss", option.get("expected_draw_risk_loss", 0.0)))
	option["expected_ready_value"] = float(csharp_item.get("expectedReadyValue", option.get("expected_ready_value", 0.0)))
	option["posterior_adjustment"] = float(csharp_item.get("posteriorAdjustment", option.get("posterior_adjustment", 0.0)))
	option["defense_adjustment"] = float(csharp_item.get("defenseAdjustment", option.get("defense_adjustment", 0.0)))
	option["good_shape_count"] = int(csharp_item.get("goodShapeCount", option.get("good_shape_count", 0)))
	option["bad_shape_count"] = int(csharp_item.get("badShapeCount", option.get("bad_shape_count", 0)))
	option["pair_pressure"] = int(csharp_item.get("pairPressure", option.get("pair_pressure", 0)))
	option["taatsu_overflow"] = int(csharp_item.get("taatsuOverflow", option.get("taatsu_overflow", 0)))
	option["same_shanten_improvement_count"] = int(csharp_item.get("sameShantenImprovementCount", option.get("same_shanten_improvement_count", 0)))
	option["middle_tile_flexibility"] = int(csharp_item.get("middleTileFlexibility", option.get("middle_tile_flexibility", 0)))
	option["shape_score"] = float(csharp_item.get("shapeScore", option.get("shape_score", 0.0)))
	option["breaks_pair"] = bool(csharp_item.get("breaksPair", option.get("breaks_pair", false)))
	option["breaks_triplet"] = bool(csharp_item.get("breaksTriplet", option.get("breaks_triplet", false)))
	option["set_preservation_score"] = float(csharp_item.get("setPreservationScore", option.get("set_preservation_score", 0.0)))
	option["wait_shape_label"] = str(csharp_item.get("waitShapeLabel", option.get("wait_shape_label", "")))
	option["wait_shape_score"] = float(csharp_item.get("waitShapeScore", option.get("wait_shape_score", 0.0)))
	option["ryanmen_wait_count"] = int(csharp_item.get("ryanmenWaitCount", option.get("ryanmen_wait_count", 0)))
	option["kanchan_wait_count"] = int(csharp_item.get("kanchanWaitCount", option.get("kanchan_wait_count", 0)))
	option["penchan_wait_count"] = int(csharp_item.get("penchanWaitCount", option.get("penchan_wait_count", 0)))
	option["tanki_wait_count"] = int(csharp_item.get("tankiWaitCount", option.get("tanki_wait_count", 0)))
	option["shanpon_wait_count"] = int(csharp_item.get("shanponWaitCount", option.get("shanpon_wait_count", 0)))
	option["limited_lookahead_score"] = float(csharp_item.get("limitedLookaheadScore", option.get("limited_lookahead_score", 0.0)))
	option["limited_lookahead_samples"] = int(csharp_item.get("limitedLookaheadSamples", option.get("limited_lookahead_samples", 0)))
	option["limited_lookahead_best_shanten"] = int(csharp_item.get("limitedLookaheadBestShanten", option.get("limited_lookahead_best_shanten", 8)))
	option["limited_lookahead_best_live_ukeire"] = int(csharp_item.get("limitedLookaheadBestLiveUkeire", option.get("limited_lookahead_best_live_ukeire", 0)))
	option["search_bonus"] = float(csharp_item.get("searchBonus", option.get("search_bonus", 0.0)))
	option["search_simulations"] = int(csharp_item.get("searchSimulations", option.get("search_simulations", 0)))
	option["search_used"] = bool(csharp_item.get("searchUsed", option.get("search_used", false)))
	option["posterior_reasons"] = csharp_item.get("posteriorReasons", option.get("posterior_reasons", [])).duplicate(true)
	option["reasons"] = csharp_item.get("reasons", option.get("reasons", [])).duplicate(true)
	option["risk_reasons"] = csharp_item.get("riskReasons", option.get("risk_reasons", [])).duplicate(true)
	option["exact_deal_in"] = bool(csharp_item.get("exactDealIn", option.get("exact_deal_in", false)))
	option["feeds_human_hu"] = bool(csharp_item.get("feedsHumanHu", option.get("feeds_human_hu", false)))
	option["feeds_human_peng"] = bool(csharp_item.get("feedsHumanPeng", option.get("feeds_human_peng", false)))
	option["feeds_human_gang"] = bool(csharp_item.get("feedsHumanGang", option.get("feeds_human_gang", false)))
	option["human_peng_threat"] = int(csharp_item.get("humanPengThreat", option.get("human_peng_threat", 0)))
	option["human_peng_penalty"] = int(csharp_item.get("humanPengPenalty", option.get("human_peng_penalty", 0)))
	option["tempo_peng_allowance_bonus"] = int(csharp_item.get("tempoPengAllowanceBonus", option.get("tempo_peng_allowance_bonus", 0)))
	option["peng_only_interaction_bonus"] = int(csharp_item.get("pengOnlyInteractionBonus", option.get("peng_only_interaction_bonus", 0)))
	option["keeps_ready"] = bool(csharp_item.get("keepsReady", option.get("keeps_ready", false)))
	option["exact_wall_remaining"] = int(csharp_item.get("exactWallRemaining", option.get("exact_wall_remaining", 0)))
	option["deal_in_target_seats"] = csharp_item.get("dealInTargetSeats", option.get("deal_in_target_seats", [])).duplicate(true)
	return option


func _compact_csharp_result(csharp_result: Dictionary) -> Dictionary:
	return {
		"ok": bool(csharp_result.get("ok", true)),
		"action": str(csharp_result.get("action", "")),
		"tileType": int(csharp_result.get("tileType", -1)),
		"score": int(csharp_result.get("score", 0)),
		"shanten": int(csharp_result.get("shanten", 8)),
		"ukeire": int(csharp_result.get("ukeire", 0)),
		"liveUkeire": int(csharp_result.get("liveUkeire", 0)),
		"winProbability": float(csharp_result.get("winProbability", 0.0)),
		"dealInProbability": float(csharp_result.get("dealInProbability", 0.0)),
		"searchUsed": bool(csharp_result.get("searchUsed", false)),
		"searchSimulations": int(csharp_result.get("searchSimulations", 0)),
		"routePlan": csharp_result.get("routePlan", {}).duplicate(true),
		"elapsedMs": int(csharp_result.get("elapsedMs", -1)),
		"beliefMetrics": csharp_result.get("beliefMetrics", {}).duplicate(true),
		"cache": csharp_result.get("cache", {}).duplicate(true),
		"mobileSpeedMode": bool(csharp_result.get("mobileSpeedMode", false)),
		"backendMode": str(csharp_result.get("backendMode", "")),
		"category": str(csharp_result.get("category", "")),
		"severity": str(csharp_result.get("severity", "")),
		"exactDealIn": bool(csharp_result.get("exactDealIn", false)),
		"oracleExactDealIn": bool(csharp_result.get("oracleExactDealIn", false)),
		"oracleFeedsHumanHu": bool(csharp_result.get("oracleFeedsHumanHu", false)),
		"oracleFeedsHumanPeng": bool(csharp_result.get("oracleFeedsHumanPeng", false)),
		"oracleFeedsHumanGang": bool(csharp_result.get("oracleFeedsHumanGang", false)),
		"humanPressureLevel": int(csharp_result.get("humanPressureLevel", 0)),
		"oracleDealInTargetSeats": csharp_result.get("oracleDealInTargetSeats", []).duplicate(true),
		"exactKeepsReady": bool(csharp_result.get("exactKeepsReady", false)),
		"exactWallRemaining": int(csharp_result.get("exactWallRemaining", 0)),
		"fairTileType": int(csharp_result.get("fairTileType", -1)),
		"actualTileType": int(csharp_result.get("actualTileType", -1)),
		"teamRole": str(csharp_result.get("teamRole", "")),
			"teamPressureBonus": int(csharp_result.get("teamPressureBonus", 0)),
			"teamPlanSummary": csharp_result.get("teamPlanSummary", []).duplicate(true),
			"candidates": csharp_result.get("candidates", []).duplicate(true),
			"reasons": csharp_result.get("reasons", []).duplicate(true),
		}


func _merge_strategy_profile(base_profile: Dictionary, csharp_profile: Dictionary) -> Dictionary:
	if csharp_profile.is_empty():
		return base_profile.duplicate(true)
	var merged: Dictionary = base_profile.duplicate(true)
	merged["mode_label"] = str(csharp_profile.get("mode_label", merged.get("mode_label", "定缺速听")))
	merged["round_stage"] = int(csharp_profile.get("round_stage", merged.get("round_stage", 1)))
	merged["round_stage_label"] = str(csharp_profile.get("round_stage_label", merged.get("round_stage_label", "中巡")))
	merged["threat_level"] = int(csharp_profile.get("threat_level", merged.get("threat_level", 0)))
	merged["reasons"] = csharp_profile.get("reasons", merged.get("reasons", [])).duplicate(true)
	var dingque_state: Dictionary = merged.get("dingque_state", {}).duplicate(true)
	var csharp_dingque: Dictionary = csharp_profile.get("dingque_state", {})
	for key in csharp_dingque.keys():
		dingque_state[key] = csharp_dingque[key]
	merged["dingque_state"] = dingque_state
	var opponent_state: Dictionary = merged.get("opponent_state", {}).duplicate(true)
	var csharp_opponent: Dictionary = csharp_profile.get("opponent_state", {})
	for key in csharp_opponent.keys():
		opponent_state[key] = csharp_opponent[key]
	merged["opponent_state"] = opponent_state
	return merged


func _create_empty_performance_metrics() -> Dictionary:
	return {
		"turn_count": 0,
		"turn_total_ms": 0,
		"turn_avg_ms": 0.0,
		"turn_max_ms": 0,
		"turn_budget_ms": TURN_BUDGET_MS,
		"turn_over_budget_count": 0,
		"reaction_count": 0,
		"reaction_total_ms": 0,
		"reaction_avg_ms": 0.0,
		"reaction_max_ms": 0,
		"reaction_budget_ms": REACTION_BUDGET_MS,
		"reaction_over_budget_count": 0,
		"backend_turns": {
			"csharp_required": {"count": 0, "total_ms": 0, "avg_ms": 0.0, "max_ms": 0, "over_budget_count": 0},
			"csharp_cli": {"count": 0, "total_ms": 0, "avg_ms": 0.0, "max_ms": 0, "over_budget_count": 0},
			"csharp_native": {"count": 0, "total_ms": 0, "avg_ms": 0.0, "max_ms": 0, "over_budget_count": 0},
			"csharp_native_async": {"count": 0, "total_ms": 0, "avg_ms": 0.0, "max_ms": 0, "over_budget_count": 0},
			"hybrid_csharp": {"count": 0, "total_ms": 0, "avg_ms": 0.0, "max_ms": 0, "over_budget_count": 0},
			"hybrid_csharp_native": {"count": 0, "total_ms": 0, "avg_ms": 0.0, "max_ms": 0, "over_budget_count": 0},
		},
	}


func _create_empty_request_state() -> Dictionary:
	return {
		"next_request_id": 1,
		"inflight_count": 0,
		"active_key_count": 0,
		"duplicate_reuse_count": 0,
		"last_turn_request_id": 0,
		"last_reaction_request_id": 0,
		"last_completed_kind": "",
		"last_completed_request": {},
		"last_background_request_id": 0,
		"last_duplicate_request": {},
	}


func _find_active_async_request(request_key: String) -> int:
	if request_key.is_empty():
		return 0
	var request_id := int(active_async_request_keys.get(request_key, 0))
	if request_id > 0 and active_async_requests.has(request_id):
		return request_id
	active_async_request_keys.erase(request_key)
	request_state["active_key_count"] = active_async_request_keys.size()
	return 0


func _remember_active_async_request(request_id: int, request_key: String) -> void:
	if request_id <= 0 or request_key.is_empty():
		return
	active_async_request_keys[request_key] = request_id
	request_state["active_key_count"] = active_async_request_keys.size()


func _forget_active_async_request(request_id: int, request: Dictionary) -> void:
	var request_key := str(request.get("request_key", ""))
	if not request_key.is_empty() and int(active_async_request_keys.get(request_key, 0)) == request_id:
		active_async_request_keys.erase(request_key)
	active_async_requests.erase(request_id)
	request_state["active_key_count"] = active_async_request_keys.size()


func _record_duplicate_async_request(kind: String, seat: int, request_id: int, request_key: String) -> void:
	request_state["duplicate_reuse_count"] = int(request_state.get("duplicate_reuse_count", 0)) + 1
	request_state["last_duplicate_request"] = {
		"kind": kind,
		"seat": seat,
		"request_id": request_id,
		"key_prefix": request_key.left(160),
		"ticks_msec": Time.get_ticks_msec(),
	}


func _build_active_turn_request_key(player_state: Dictionary, table_state: Dictionary, rules_config, allow_cheat: bool, force_lightweight: bool = false) -> String:
	return "turn|%s" % _build_turn_cache_key(player_state, table_state, rules_config, allow_cheat, false, force_lightweight)


func _build_active_reaction_request_key(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, allow_cheat: bool) -> String:
	var payload: Dictionary = csharp_bridge.build_reaction_transport_payload(candidate, player_state, table_state, discard_context, rules_config)
	payload["allowCheat"] = allow_cheat
	return "reaction|%s" % JSON.stringify(payload)


func _build_cache_stats_snapshot() -> Dictionary:
	return {
		"turn_cache_size": turn_cache_order.size(),
		"turn_cache_limit": TURN_CACHE_LIMIT,
		"turn_cache_hits": int(performance_metrics.get("turn_cache_hits", 0)),
		"turn_cache_misses": int(performance_metrics.get("turn_cache_misses", 0)),
	}


func _build_active_async_requests_snapshot() -> Dictionary:
	var items: Array = []
	for request_id in active_async_requests.keys():
		var request: Dictionary = active_async_requests.get(request_id, {})
		items.append({
			"request_id": int(request_id),
			"kind": str(request.get("kind", "")),
			"seat": int(request.get("seat", -1)),
			"native_request_id": int(request.get("native_request_id", 0)),
			"age_ms": maxi(0, Time.get_ticks_msec() - int(request.get("started_at_ms", Time.get_ticks_msec()))),
			"has_thread": request.has("thread"),
			"key_prefix": str(request.get("request_key", "")).left(160),
		})
	return {
		"count": active_async_requests.size(),
		"key_count": active_async_request_keys.size(),
		"items": items.slice(0, mini(16, items.size())),
	}


func _record_performance_sample(kind: String, backend: String, elapsed_ms: int, budget_ms: int, over_budget: bool) -> void:
	var prefix := "turn" if kind == "turn" else "reaction"
	var count_key := "%s_count" % prefix
	var total_key := "%s_total_ms" % prefix
	var avg_key := "%s_avg_ms" % prefix
	var max_key := "%s_max_ms" % prefix
	var over_budget_key := "%s_over_budget_count" % prefix
	performance_metrics[count_key] = int(performance_metrics.get(count_key, 0)) + 1
	performance_metrics[total_key] = int(performance_metrics.get(total_key, 0)) + elapsed_ms
	performance_metrics[max_key] = maxi(int(performance_metrics.get(max_key, 0)), elapsed_ms)
	performance_metrics[avg_key] = float(performance_metrics[total_key]) / maxf(1.0, float(performance_metrics[count_key]))
	performance_metrics["%s_budget_ms" % prefix] = budget_ms
	if over_budget:
		performance_metrics[over_budget_key] = int(performance_metrics.get(over_budget_key, 0)) + 1
	if kind != "turn":
		return
	var backend_turns: Dictionary = performance_metrics.get("backend_turns", {})
	var backend_metrics: Dictionary = backend_turns.get(backend, {
		"count": 0,
		"total_ms": 0,
		"avg_ms": 0.0,
		"max_ms": 0,
		"over_budget_count": 0,
	})
	backend_metrics["count"] = int(backend_metrics.get("count", 0)) + 1
	backend_metrics["total_ms"] = int(backend_metrics.get("total_ms", 0)) + elapsed_ms
	backend_metrics["max_ms"] = maxi(int(backend_metrics.get("max_ms", 0)), elapsed_ms)
	backend_metrics["avg_ms"] = float(backend_metrics["total_ms"]) / maxf(1.0, float(backend_metrics["count"]))
	if over_budget:
		backend_metrics["over_budget_count"] = int(backend_metrics.get("over_budget_count", 0)) + 1
	backend_turns[backend] = backend_metrics
	performance_metrics["backend_turns"] = backend_turns


func _resolve_budget_ms(kind: String, backend: String) -> int:
	if kind == "reaction":
		return REACTION_BUDGET_MS
	if backend == "hybrid_csharp" or backend == "hybrid_csharp_native" or backend == "csharp_native_async" or backend == "hybrid_csharp_native_async":
		return TURN_BUDGET_MS
	return int(TURN_BUDGET_MS * 0.75)


func _sum_int_array(values) -> int:
	var total := 0
	if typeof(values) == TYPE_PACKED_INT32_ARRAY:
		for value in values:
			total += int(value)
	elif typeof(values) == TYPE_ARRAY:
		for value in values:
			total += int(value)
	return total


func _begin_request(kind: String, seat: int) -> int:
	var request_id := int(request_state.get("next_request_id", 1))
	request_state["next_request_id"] = request_id + 1
	request_state["inflight_count"] = int(request_state.get("inflight_count", 0)) + 1
	if kind == "turn":
		request_state["last_turn_request_id"] = request_id
	else:
		request_state["last_reaction_request_id"] = request_id
	return request_id


func _finish_request(kind: String, request_id: int, seat: int, analysis: Dictionary) -> void:
	request_state["inflight_count"] = maxi(0, int(request_state.get("inflight_count", 0)) - 1)
	request_state["last_completed_kind"] = kind
	request_state["last_completed_request"] = {
		"request_id": request_id,
		"seat": seat,
			"analysis_summary": {
				"action": str(analysis.get("action", analysis.get("recommended", {}).get("tile_name", ""))),
				"backend_mode": str(analysis.get("backend_mode", "csharp_required")),
			},
		}


func _compute_turn_analysis(player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool, request_tag: String, force_gdscript: bool = false, force_lightweight: bool = false, compact_result: bool = false) -> Dictionary:
	var cache_key := _build_turn_cache_key(player_state, table_state, rules_config, allow_cheat, force_gdscript, force_lightweight)
	var cached := _get_cached_turn_analysis(cache_key)
	if not cached.is_empty():
		performance_metrics["turn_cache_hits"] = int(performance_metrics.get("turn_cache_hits", 0)) + 1
		return cached
	performance_metrics["turn_cache_misses"] = int(performance_metrics.get("turn_cache_misses", 0)) + 1
	var local_bridge = AICoreBridgeScript.new()
	var local_csharp_bridge = CSharpAIBridgeScript.new()
	local_csharp_bridge.set_host_mode_enabled(csharp_host_mode_enabled, csharp_host_port)
	var started_at_ms := Time.get_ticks_msec()
	var payload := local_bridge.build_discard_payload(player_state, table_state, rules_config, ai_config, allow_cheat)
	var analysis: Dictionary = {}
	var active_backend := "csharp_required"
	last_native_turn_error = ""
	if not force_gdscript and has_native_csharp_runtime() and rules_config != null and bool(rules_config.is_sichuan_mode()):
		var native_result := _analyze_discard_via_native_runtime(player_state, table_state, rules_config, force_lightweight, compact_result)
		var native_error := _validate_native_discard_result(native_result)
		if native_error.is_empty():
			analysis = _build_csharp_discard_analysis(player_state, native_result, rules_config, local_csharp_bridge, "csharp_native", table_state)
			active_backend = "csharp_native"
		else:
			last_native_turn_error = native_error
			active_backend = "hybrid_csharp_native_error"
			if strict_native_runtime_required:
				var native_elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
				return {
					"analysis": {},
					"active_backend": active_backend,
					"elapsed_ms": native_elapsed_ms,
					"budget_ms": _resolve_budget_ms("turn", "hybrid_csharp_native"),
					"over_budget": native_elapsed_ms > _resolve_budget_ms("turn", "hybrid_csharp_native"),
					"native_error": native_error,
				}
	elif not force_gdscript and _should_use_csharp_backend(rules_config) and local_csharp_bridge.is_available():
		var csharp_result := local_csharp_bridge.analyze_discard(player_state, table_state, rules_config, request_tag, force_lightweight, compact_result)
		if not csharp_result.is_empty():
			analysis = _build_csharp_discard_analysis(player_state, csharp_result, rules_config, local_csharp_bridge, "csharp_cli", table_state)
			active_backend = "csharp_cli"
	if analysis.is_empty() and rules_config != null and bool(rules_config.is_sichuan_mode()) and strict_native_runtime_required:
		last_native_turn_error = "strict_csharp_required_no_discard_analysis" if last_native_turn_error.is_empty() else last_native_turn_error
	elif analysis.is_empty():
		last_native_turn_error = "csharp_required_no_discard_analysis" if last_native_turn_error.is_empty() else last_native_turn_error
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
	var budget_ms := _resolve_budget_ms("turn", active_backend)
	var result := {
		"analysis": analysis.duplicate(true),
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": budget_ms,
		"over_budget": elapsed_ms > budget_ms,
	}
	_store_turn_analysis_cache(cache_key, result)
	return result


func _compute_reaction_analysis(candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool) -> Dictionary:
	var local_bridge = AICoreBridgeScript.new()
	var started_at_ms := Time.get_ticks_msec()
	var payload := local_bridge.build_reaction_payload(candidate, player_state, table_state, discard_context, rules_config, ai_config, allow_cheat)
	var analysis: Dictionary = {}
	var active_backend := "csharp_required"
	last_native_reaction_error = ""
	if has_native_csharp_runtime() and rules_config != null and bool(rules_config.is_sichuan_mode()):
		var native_result := _analyze_reaction_via_native_runtime(candidate, player_state, table_state, discard_context, rules_config)
		var native_error := _validate_native_reaction_result(native_result)
		if native_error.is_empty():
			analysis = _build_csharp_reaction_analysis(native_result, "hybrid_csharp_native")
			active_backend = "hybrid_csharp_native"
		else:
			last_native_reaction_error = native_error
			active_backend = "hybrid_csharp_native_error"
			if strict_native_runtime_required:
				var native_elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
				return {
					"analysis": {},
					"active_backend": active_backend,
					"elapsed_ms": native_elapsed_ms,
					"budget_ms": _resolve_budget_ms("reaction", "hybrid_csharp_native"),
					"over_budget": native_elapsed_ms > _resolve_budget_ms("reaction", "hybrid_csharp_native"),
					"native_error": native_error,
				}
	elif _should_use_csharp_backend(rules_config) and csharp_bridge.is_available():
		var csharp_result := csharp_bridge.analyze_reaction(candidate, player_state, table_state, discard_context, rules_config, "reaction_sync")
		if not csharp_result.is_empty():
			analysis = _build_csharp_reaction_analysis(csharp_result, "hybrid_csharp")
			active_backend = "hybrid_csharp"
	if analysis.is_empty() and rules_config != null and bool(rules_config.is_sichuan_mode()) and strict_native_runtime_required:
		last_native_reaction_error = "strict_csharp_required_no_reaction_analysis" if last_native_reaction_error.is_empty() else last_native_reaction_error
	elif analysis.is_empty():
		last_native_reaction_error = "csharp_required_no_reaction_analysis" if last_native_reaction_error.is_empty() else last_native_reaction_error
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - started_at_ms)
	var budget_ms := _resolve_budget_ms("reaction", active_backend)
	return {
		"analysis": analysis.duplicate(true),
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": budget_ms,
		"over_budget": elapsed_ms > budget_ms,
	}


func _validate_native_discard_result(native_result: Dictionary) -> String:
	if native_result.is_empty():
		return "empty_native_discard_result"
	if not bool(native_result.get("ok", true)):
		return str(native_result.get("error", "native_discard_not_ok"))
	if str(native_result.get("action", "")).strip_edges().to_lower() == "gang":
		if int(native_result.get("tileType", -1)) < 0:
			return "native_discard_gang_missing_tile"
		return ""
	var candidates = native_result.get("candidates", [])
	if typeof(candidates) != TYPE_ARRAY or Array(candidates).is_empty():
		return "native_discard_missing_candidates"
	return ""


func _validate_native_reaction_result(native_result: Dictionary) -> String:
	if native_result.is_empty():
		return "empty_native_reaction_result"
	if not bool(native_result.get("ok", true)):
		return str(native_result.get("error", "native_reaction_not_ok"))
	var action := str(native_result.get("action", ""))
	if action.is_empty():
		return "native_reaction_missing_action"
	return ""


func _finalize_turn_analysis(seat: int, result: Dictionary) -> void:
	var active_backend := str(result.get("active_backend", "gdscript"))
	var elapsed_ms := int(result.get("elapsed_ms", 0))
	var budget_ms := int(result.get("budget_ms", TURN_BUDGET_MS))
	var over_budget := bool(result.get("over_budget", false))
	var analysis: Dictionary = result.get("analysis", {}).duplicate(true)
	_record_performance_sample("turn", active_backend, elapsed_ms, budget_ms, over_budget)
	latest_turn_snapshot = {
		"seat": seat,
		"analysis": analysis,
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": budget_ms,
		"over_budget": over_budget,
	}


func _finalize_reaction_analysis(seat: int, result: Dictionary) -> void:
	var active_backend := str(result.get("active_backend", "gdscript"))
	var elapsed_ms := int(result.get("elapsed_ms", 0))
	var budget_ms := int(result.get("budget_ms", REACTION_BUDGET_MS))
	var over_budget := bool(result.get("over_budget", false))
	var analysis: Dictionary = result.get("analysis", {}).duplicate(true)
	_record_performance_sample("reaction", active_backend, elapsed_ms, budget_ms, over_budget)
	latest_reaction_snapshot = {
		"seat": seat,
		"analysis": analysis,
		"active_backend": active_backend,
		"elapsed_ms": elapsed_ms,
		"budget_ms": budget_ms,
		"over_budget": over_budget,
	}


func _thread_compute_turn(request_id: int, player_state: Dictionary, table_state: Dictionary, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat: bool, force_lightweight: bool = false, compact_result: bool = false) -> Dictionary:
	return {
		"request_id": request_id,
		"kind": "turn",
		"seat": int(player_state.get("seat", -1)),
		"result": _compute_turn_analysis(player_state, table_state, rules_config, ai_config, hu_checker, risk_analyzer, allow_cheat, "bg_%d" % request_id, false, force_lightweight, compact_result),
	}


func _thread_compute_reaction(request_id: int, candidate: Dictionary, player_state: Dictionary, table_state: Dictionary, discard_context: Dictionary, rules_config, ai_config, hu_checker, allow_cheat: bool) -> Dictionary:
	return {
		"request_id": request_id,
		"kind": "reaction",
		"seat": int(player_state.get("seat", -1)),
		"result": _compute_reaction_analysis(candidate, player_state, table_state, discard_context, rules_config, ai_config, hu_checker, allow_cheat),
	}


func _deliver_async_payload(payload: Dictionary) -> int:
	if payload.is_empty():
		return 0
	var kind := str(payload.get("kind", ""))
	var request_id := int(payload.get("request_id", 0))
	var seat := int(payload.get("seat", -1))
	var result: Dictionary = payload.get("result", {})
	var analysis: Dictionary = result.get("analysis", {}).duplicate(true)
	request_state["last_background_request_id"] = request_id
	if kind == "turn":
		_finalize_turn_analysis(seat, result)
		_finish_request(kind, request_id, seat, analysis)
		ai_turn_analysis_ready.emit(request_id, seat, analysis)
		return 1
	if kind == "reaction":
		_finalize_reaction_analysis(seat, result)
		_finish_request(kind, request_id, seat, analysis)
		ai_reaction_analysis_ready.emit(request_id, seat, analysis)
		return 1
	return 0


func _build_turn_cache_key(player_state: Dictionary, table_state: Dictionary, rules_config, allow_cheat: bool, force_gdscript: bool, force_lightweight: bool = false) -> String:
	var active_suits: Array = csharp_bridge.tile_codec.resolve_active_suits(rules_config)
	var parts: Array[String] = []
	parts.append("seat=%d" % int(player_state.get("seat", -1)))
	parts.append("turn=%d" % int(table_state.get("current_turn_seat", -1)))
	parts.append("wall=%d" % int(table_state.get("wall_count", 0)))
	parts.append("dealer=%d" % int(table_state.get("dealer_seat", -1)))
	parts.append("cheat=%d" % int(allow_cheat))
	parts.append("force_gd=%d" % int(force_gdscript))
	parts.append("light=%d" % int(force_lightweight))
	parts.append("prefer_csharp=%d" % int(prefer_csharp_backend))
	parts.append("self_bao=%d" % int(bool(player_state.get("bao_jiao", false))))
	var last_draw: Dictionary = table_state.get("last_draw_tile", {})
	parts.append("last_draw=%d:%s" % [
		int(last_draw.get("seat", -1)),
		_encode_single_tile(last_draw.get("tile", {}), active_suits),
	])
	parts.append("hand=%s" % _encode_tile_counts(player_state.get("hand_tiles", []), active_suits))
	var players: Array = table_state.get("players", [])
	for index in range(players.size()):
		var player: Dictionary = players[index]
		parts.append("p%d_d=%s" % [index, _encode_tile_sequence(player.get("discards", []), active_suits)])
		parts.append("p%d_m=%s" % [index, _encode_meld_sequence(player.get("melds", []), active_suits)])
		parts.append("p%d_bj=%d" % [index, int(bool(player.get("bao_jiao", false)))])
		parts.append("p%d_hu=%d" % [index, int(bool(player.get("has_won", false)))])
	return "|".join(parts)


func _encode_tile_counts(tiles: Array, active_suits: Array) -> String:
	var counts: PackedInt32Array = csharp_bridge.tile_codec.build_count_array(tiles, active_suits)
	var parts: Array[String] = []
	for value in counts:
		parts.append(str(int(value)))
	return ",".join(parts)


func _encode_tile_sequence(tiles: Array, active_suits: Array) -> String:
	var encoded: Array[String] = []
	for tile in tiles:
		var tile_type: int = int(csharp_bridge.tile_codec.tile_type(tile, active_suits))
		if tile_type >= 0:
			encoded.append(str(tile_type))
	return ",".join(encoded)


func _encode_single_tile(tile: Dictionary, active_suits: Array) -> String:
	var tile_type: int = int(csharp_bridge.tile_codec.tile_type(tile, active_suits))
	return str(tile_type) if tile_type >= 0 else "-1"


func _encode_meld_sequence(melds: Array, active_suits: Array) -> String:
	var encoded: Array[String] = []
	for meld in melds:
		var meld_tiles: Array[String] = []
		for tile in meld.get("tiles", []):
			var tile_type: int = int(csharp_bridge.tile_codec.tile_type(tile, active_suits))
			if tile_type >= 0:
				meld_tiles.append(str(tile_type))
		encoded.append("%s:%s" % [str(meld.get("type", "")), ",".join(meld_tiles)])
	return ";".join(encoded)


func _get_cached_turn_analysis(cache_key: String) -> Dictionary:
	if cache_key == "" or not turn_analysis_cache.has(cache_key):
		return {}
	var cached: Dictionary = turn_analysis_cache.get(cache_key, {}).duplicate(true)
	cached["elapsed_ms"] = 0
	cached["cache_hit"] = true
	_touch_turn_cache_key(cache_key)
	return cached


func _store_turn_analysis_cache(cache_key: String, result: Dictionary) -> void:
	if cache_key == "":
		return
	var stored: Dictionary = result.duplicate(true)
	stored["cache_hit"] = false
	turn_analysis_cache[cache_key] = stored
	_touch_turn_cache_key(cache_key)
	while turn_cache_order.size() > TURN_CACHE_LIMIT:
		var oldest_key: String = str(turn_cache_order.pop_front())
		turn_analysis_cache.erase(oldest_key)


func _touch_turn_cache_key(cache_key: String) -> void:
	turn_cache_order.erase(cache_key)
	turn_cache_order.append(cache_key)
