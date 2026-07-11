extends RefCounted

class_name AILearningEngine

const LEARNING_DIR := "user://测试数据统计"
const LEARNING_FILE := "user://测试数据统计/ai学习数据.json"
const LEARNING_HISTORY_FILE := "user://测试数据统计/ai参数学习历史.json"
const DOTNET_BIN := "/opt/homebrew/Cellar/dotnet/10.0.107/libexec/dotnet"
const CLI_DLL_PATH := "res://dotnet/AI.Core.Cli/bin/Release/net10.0/AI.Core.Cli.dll"
const TMP_DIR := "user://tmp_ai_core"
const MAX_RECENT_ROUNDS := 60
const MAX_ADJUSTMENT_HISTORY := 120
const PARAMETER_LABELS := {
	"lookahead_candidate_count": "前瞻候选数",
	"lookahead_draw_samples": "前瞻样本数",
	"add_gang_min_score": "补杠阈值",
	"an_gang_min_score": "暗杠阈值",
	"intermediate_top_pick_count": "中级随机池",
	"attack_tendency": "进攻倾向",
	"defense_tendency": "防守倾向",
	"fast_ting_priority": "快速听牌",
	"self_draw_priority": "自摸优先",
	"forced_cleanup_tendency": "成叫/查叫优先",
	"big_hand_tendency": "做大倾向",
	"opponent_read_tendency": "读牌能力",
}

var profile: Dictionary = {}
var last_backend_mode: String = "gdscript"
var native_csharp_runtime: Object = null
var persistence_enabled: bool = true


func set_native_csharp_runtime(runtime: Object) -> void:
	native_csharp_runtime = runtime


func set_persistence_enabled(enabled: bool) -> void:
	persistence_enabled = enabled


func load_profile() -> Dictionary:
	profile = _default_profile()
	if not persistence_enabled:
		last_backend_mode = "disabled"
		return profile.duplicate(true)
	if not FileAccess.file_exists(LEARNING_FILE):
		save_profile()
		return profile.duplicate(true)

	var file := FileAccess.open(LEARNING_FILE, FileAccess.READ)
	if file == null:
		return profile.duplicate(true)

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var should_save: bool = not parsed.has("summary_stats")
		profile = _merge_profile_with_defaults(parsed)
		_recalculate_parameter_bias()
		if should_save:
			save_profile()
	return profile.duplicate(true)


func save_profile() -> bool:
	if not persistence_enabled:
		return false
	_ensure_learning_dir()
	var file := FileAccess.open(LEARNING_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile, "\t", false))
	_export_adjustment_history_file()
	return true


func get_profile() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return profile.duplicate(true)


func get_runtime_summary() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return {
		"backend_mode": last_backend_mode,
		"total_human_rounds": int(profile.get("total_human_rounds", 0)),
		"last_updated_unix": int(profile.get("last_updated_unix", 0)),
		"parameter_bias": profile.get("parameter_bias", {}).duplicate(true),
		"parameter_adjustments": profile.get("parameter_adjustments", {}).duplicate(true),
		"summary_stats": profile.get("summary_stats", {}).duplicate(true),
		"last_adjustment_reasons": profile.get("last_adjustment_reasons", []).duplicate(),
		"adjustment_history": profile.get("adjustment_history", []).duplicate(true),
	}


func record_human_round(round_result: Dictionary) -> Dictionary:
	if not persistence_enabled:
		last_backend_mode = "disabled"
		if profile.is_empty():
			profile = _default_profile()
		return profile.duplicate(true)
	if _record_human_round_via_csharp(round_result):
		load_profile()
		return profile.duplicate(true)
	return _record_human_round_gd(round_result)


func _record_human_round_gd(round_result: Dictionary) -> Dictionary:
	if profile.is_empty():
		load_profile()

	var score_changes: Dictionary = round_result.get("score_changes", {})
	var win_events: Array = round_result.get("win_events", [])
	var gang_events: Array = round_result.get("gang_events", [])
	var end_reason := str(round_result.get("end_reason", ""))
	var human_delta := int(score_changes.get(0, 0))
	var human_deal_in := _did_human_deal_in(win_events)
	var ai_win_count := _count_ai_wins(win_events)
	var ai_self_draw_count := _count_ai_self_draws(win_events)
	var ai_gang_count := _count_ai_gangs(gang_events)

	profile["total_human_rounds"] = int(profile.get("total_human_rounds", 0)) + 1
	profile["last_updated_unix"] = int(Time.get_unix_time_from_system())

	var rolling: Dictionary = profile.get("rolling", {})
	rolling["human_total_delta"] = int(rolling.get("human_total_delta", 0)) + human_delta
	if human_delta > 0:
		rolling["human_positive_rounds"] = int(rolling.get("human_positive_rounds", 0)) + 1
	elif human_delta < 0:
		rolling["human_negative_rounds"] = int(rolling.get("human_negative_rounds", 0)) + 1
	if human_deal_in:
		rolling["human_deal_in_count"] = int(rolling.get("human_deal_in_count", 0)) + 1
	rolling["ai_win_count"] = int(rolling.get("ai_win_count", 0)) + ai_win_count
	rolling["ai_self_draw_count"] = int(rolling.get("ai_self_draw_count", 0)) + ai_self_draw_count
	rolling["ai_gang_count"] = int(rolling.get("ai_gang_count", 0)) + ai_gang_count
	if end_reason == "draw_wall_empty":
		rolling["draw_rounds"] = int(rolling.get("draw_rounds", 0)) + 1
	profile["rolling"] = rolling

	var recent_rounds: Array = profile.get("recent_rounds", [])
	recent_rounds.append(
		{
			"round_index": int(round_result.get("round_index", 0)),
			"timestamp_unix": int(profile.get("last_updated_unix", 0)),
			"human_delta": human_delta,
			"human_deal_in": human_deal_in,
			"ai_win_count": ai_win_count,
			"ai_self_draw_count": ai_self_draw_count,
			"ai_gang_count": ai_gang_count,
			"end_reason": end_reason,
			"score_changes": score_changes.duplicate(true),
		}
	)
	while recent_rounds.size() > MAX_RECENT_ROUNDS:
		recent_rounds.pop_front()
	profile["recent_rounds"] = recent_rounds

	_recalculate_parameter_bias()
	save_profile()
	last_backend_mode = "gdscript"
	return profile.duplicate(true)


func _record_human_round_via_csharp(round_result: Dictionary) -> bool:
	if not _is_csharp_learning_available():
		return false
	var payload := {
		"learning_file_path": ProjectSettings.globalize_path(LEARNING_FILE),
		"learning_history_file_path": ProjectSettings.globalize_path(LEARNING_HISTORY_FILE),
		"round_result": {
			"round_index": int(round_result.get("round_index", 0)),
			"end_reason": str(round_result.get("end_reason", "")),
			"score_changes": _normalize_score_changes(round_result.get("score_changes", {})),
			"win_events": round_result.get("win_events", []).duplicate(true),
			"gang_events": round_result.get("gang_events", []).duplicate(true),
		},
	}
	if _has_native_csharp_runtime():
		var raw := str(native_csharp_runtime.call("RecordLearningJson", JSON.stringify(payload)))
		var parsed_native = JSON.parse_string(raw)
		if typeof(parsed_native) == TYPE_DICTIONARY and bool(parsed_native.get("ok", false)):
			last_backend_mode = "csharp_native"
			return true
	_ensure_learning_dir()
	var dir_path := ProjectSettings.globalize_path(TMP_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var payload_path := dir_path.path_join("learning_payload.json")
	var file := FileAccess.open(payload_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	var output: Array = []
	var exit_code := OS.execute(
		DOTNET_BIN,
		[ProjectSettings.globalize_path(CLI_DLL_PATH), "learning-record", payload_path],
		output,
		true,
		true
	)
	if exit_code != 0 or output.is_empty():
		return false
	var parsed = JSON.parse_string("\n".join(output))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	last_backend_mode = "csharp"
	return bool(parsed.get("ok", false))


func _normalize_score_changes(raw: Dictionary) -> Dictionary:
	var normalized := {}
	for key in raw.keys():
		normalized[str(key)] = int(raw.get(key, 0))
	return normalized


func _is_csharp_learning_available() -> bool:
	return _has_native_csharp_runtime() or FileAccess.file_exists(ProjectSettings.globalize_path(CLI_DLL_PATH))


func _has_native_csharp_runtime() -> bool:
	return native_csharp_runtime != null and native_csharp_runtime.has_method("IsRuntimeReady") and bool(native_csharp_runtime.call("IsRuntimeReady"))


func _default_profile() -> Dictionary:
	return {
		"version": 1,
		"total_human_rounds": 0,
		"last_updated_unix": 0,
		"rolling": {
			"human_total_delta": 0,
			"human_positive_rounds": 0,
			"human_negative_rounds": 0,
			"human_deal_in_count": 0,
			"ai_win_count": 0,
			"ai_self_draw_count": 0,
			"ai_gang_count": 0,
			"draw_rounds": 0,
		},
		"parameter_bias": {
			"risk_bias": 0,
			"attack_bias": 0,
			"gang_bias": 0,
			"lookahead_bias": 0,
		},
		"parameter_adjustments": _empty_parameter_adjustments(),
		"summary_stats": {
			"human_average_delta": 0.0,
			"human_positive_rate": 0.0,
			"human_negative_rate": 0.0,
			"human_deal_in_rate": 0.0,
			"ai_win_average": 0.0,
			"ai_self_draw_rate": 0.0,
			"ai_gang_average": 0.0,
			"draw_rate": 0.0,
		},
		"last_adjustment_reasons": [],
		"recent_rounds": [],
		"adjustment_history": [],
	}


func _merge_profile_with_defaults(loaded_profile: Dictionary) -> Dictionary:
	var merged := _default_profile()
	for key in loaded_profile.keys():
		if typeof(loaded_profile[key]) == TYPE_DICTIONARY and typeof(merged.get(key)) == TYPE_DICTIONARY:
			var nested: Dictionary = merged[key]
			var loaded_nested: Dictionary = loaded_profile[key]
			for nested_key in loaded_nested.keys():
				nested[nested_key] = loaded_nested[nested_key]
			merged[key] = nested
		else:
			merged[key] = loaded_profile[key]
	return merged


func _recalculate_parameter_bias() -> void:
	var previous_adjustments: Dictionary = profile.get("parameter_adjustments", {}).duplicate(true)
	var previous_bias: Dictionary = profile.get("parameter_bias", {}).duplicate(true)
	var total_rounds := maxi(1, int(profile.get("total_human_rounds", 0)))
	var rolling: Dictionary = profile.get("rolling", {})
	var human_avg_delta := float(int(rolling.get("human_total_delta", 0))) / float(total_rounds)
	var human_positive_rate := float(int(rolling.get("human_positive_rounds", 0))) / float(total_rounds)
	var human_deal_in_rate := float(int(rolling.get("human_deal_in_count", 0))) / float(total_rounds)
	var draw_rate := float(int(rolling.get("draw_rounds", 0))) / float(total_rounds)
	var ai_self_draw_rate := float(int(rolling.get("ai_self_draw_count", 0))) / float(total_rounds)
	var human_negative_rate := float(int(rolling.get("human_negative_rounds", 0))) / float(total_rounds)
	var ai_win_average := float(int(rolling.get("ai_win_count", 0))) / float(total_rounds)
	var ai_gang_average := float(int(rolling.get("ai_gang_count", 0))) / float(total_rounds)

	var risk_bias := 0
	var attack_bias := 0
	var gang_bias := 0
	var lookahead_bias := 0
	var adjustments := _empty_parameter_adjustments()
	var reasons: Array[String] = []

	if human_avg_delta > 0.8 or human_positive_rate > 0.42:
		lookahead_bias += 2
		risk_bias += 1
		_bump_adjustment(adjustments, "lookahead_candidate_count", 1)
		_bump_adjustment(adjustments, "lookahead_draw_samples", 2)
		_bump_adjustment(adjustments, "defense_tendency", 1)
		_bump_adjustment(adjustments, "opponent_read_tendency", 1)
		reasons.append("真人长期占优，四川 AI 提高读牌、防炮与尾盘收缩强度。")
	if human_avg_delta > 2.0:
		lookahead_bias += 1
		attack_bias += 1
		_bump_adjustment(adjustments, "attack_tendency", 1)
		_bump_adjustment(adjustments, "lookahead_draw_samples", 1)
		_bump_adjustment(adjustments, "fast_ting_priority", 1)
		reasons.append("真人优势明显，四川 AI 提高成叫搜索和听牌转化强度。")
	if human_deal_in_rate > 0.24:
		risk_bias += 1
		_bump_adjustment(adjustments, "defense_tendency", 1)
		_bump_adjustment(adjustments, "opponent_read_tendency", 1)
		_bump_adjustment(adjustments, "forced_cleanup_tendency", 1)
		_bump_adjustment(adjustments, "add_gang_min_score", 4)
		_bump_adjustment(adjustments, "an_gang_min_score", 3)
		reasons.append("真人点炮偏高，四川 AI 强化尾盘防炮并收紧杠牌。")
	if draw_rate > 0.28:
		attack_bias += 1
		gang_bias += 1
		_bump_adjustment(adjustments, "attack_tendency", 1)
		_bump_adjustment(adjustments, "fast_ting_priority", 1)
		_bump_adjustment(adjustments, "add_gang_min_score", -3)
		_bump_adjustment(adjustments, "an_gang_min_score", -2)
		_bump_adjustment(adjustments, "big_hand_tendency", -1)
		reasons.append("流局偏高，四川 AI 提高成叫、自摸与中盘提速倾向。")
	if ai_self_draw_rate < 0.16 and total_rounds >= 6:
		attack_bias += 1
		lookahead_bias += 1
		_bump_adjustment(adjustments, "self_draw_priority", 1)
		_bump_adjustment(adjustments, "lookahead_draw_samples", 1)
		_bump_adjustment(adjustments, "fast_ting_priority", 1)
		reasons.append("AI 自摸收益偏低，增加定缺后前瞻样本并抬高自摸权重。")
	if ai_win_average < 0.90 and total_rounds >= 6:
		_bump_adjustment(adjustments, "attack_tendency", 1)
		_bump_adjustment(adjustments, "lookahead_candidate_count", 1)
		_bump_adjustment(adjustments, "fast_ting_priority", 1)
		reasons.append("AI 胡牌频率偏低，提升快速成叫与候选搜索权重。")
	if ai_gang_average < 0.18 and draw_rate > 0.16 and total_rounds >= 6:
		_bump_adjustment(adjustments, "add_gang_min_score", -2)
		_bump_adjustment(adjustments, "an_gang_min_score", -2)
		reasons.append("AI 杠收益偏少且流局偏多，适度放宽中前盘杠牌收益窗口。")
	if human_negative_rate > 0.58 and ai_win_average >= 1.0:
		_bump_adjustment(adjustments, "big_hand_tendency", 1)
		_bump_adjustment(adjustments, "defense_tendency", 1)
		reasons.append("AI 已能稳定压制真人，适度提高归收益追求与稳守质量。")
	if reasons.is_empty():
		reasons.append("数据量仍在积累，当前以四川骨灰级基准做小步微调。")

	profile["parameter_bias"] = {
		"risk_bias": clampi(risk_bias, 0, 5),
		"attack_bias": clampi(attack_bias, 0, 5),
		"gang_bias": clampi(gang_bias, 0, 5),
		"lookahead_bias": clampi(lookahead_bias, 0, 6),
	}
	profile["parameter_adjustments"] = _clamp_parameter_adjustments(adjustments)
	profile["summary_stats"] = {
		"human_average_delta": human_avg_delta,
		"human_positive_rate": human_positive_rate,
		"human_negative_rate": human_negative_rate,
		"human_deal_in_rate": human_deal_in_rate,
		"ai_win_average": ai_win_average,
		"ai_self_draw_rate": ai_self_draw_rate,
		"ai_gang_average": ai_gang_average,
		"draw_rate": draw_rate,
	}
	profile["last_adjustment_reasons"] = reasons
	_append_adjustment_history(previous_bias, previous_adjustments)


func _empty_parameter_adjustments() -> Dictionary:
	return {
		"lookahead_candidate_count": 0,
		"lookahead_draw_samples": 0,
		"add_gang_min_score": 0,
		"an_gang_min_score": 0,
		"intermediate_top_pick_count": 0,
		"attack_tendency": 0,
		"defense_tendency": 0,
		"fast_ting_priority": 0,
		"self_draw_priority": 0,
		"forced_cleanup_tendency": 0,
		"big_hand_tendency": 0,
		"opponent_read_tendency": 0,
	}


func _bump_adjustment(adjustments: Dictionary, key: String, amount: int) -> void:
	adjustments[key] = int(adjustments.get(key, 0)) + amount


func _clamp_parameter_adjustments(adjustments: Dictionary) -> Dictionary:
	var result := _empty_parameter_adjustments()
	for key in result.keys():
		result[key] = clampi(int(adjustments.get(key, 0)), -6, 6)
	result["lookahead_draw_samples"] = clampi(int(result.get("lookahead_draw_samples", 0)), -4, 6)
	result["add_gang_min_score"] = clampi(int(result.get("add_gang_min_score", 0)), -12, 12)
	result["an_gang_min_score"] = clampi(int(result.get("an_gang_min_score", 0)), -12, 12)
	return result


func _append_adjustment_history(previous_bias: Dictionary, previous_adjustments: Dictionary) -> void:
	var current_bias: Dictionary = profile.get("parameter_bias", {}).duplicate(true)
	var current_adjustments: Dictionary = profile.get("parameter_adjustments", {}).duplicate(true)
	var changed_params: Array[Dictionary] = []
	for key in current_adjustments.keys():
		var before := int(previous_adjustments.get(key, 0))
		var after := int(current_adjustments.get(key, 0))
		if before == after:
			continue
		changed_params.append(
			{
				"key": key,
				"before": before,
				"after": after,
				"delta": after - before,
			}
		)
	var changed_bias: Array[Dictionary] = []
	for key in current_bias.keys():
		var before := int(previous_bias.get(key, 0))
		var after := int(current_bias.get(key, 0))
		if before == after:
			continue
		changed_bias.append(
			{
				"key": key,
				"before": before,
				"after": after,
				"delta": after - before,
			}
		)
	if changed_params.is_empty() and changed_bias.is_empty():
		return
	var history: Array = profile.get("adjustment_history", [])
	history.append(
		{
			"round_index": int(profile.get("total_human_rounds", 0)),
			"timestamp_unix": int(profile.get("last_updated_unix", 0)),
			"parameter_bias": current_bias,
			"parameter_adjustments": current_adjustments,
			"changed_bias": changed_bias,
			"changed_parameters": changed_params,
			"reasons": profile.get("last_adjustment_reasons", []).duplicate(true),
		}
	)
	while history.size() > MAX_ADJUSTMENT_HISTORY:
		history.pop_front()
	profile["adjustment_history"] = history


func _did_human_deal_in(win_events: Array) -> bool:
	for item in win_events:
		var event: Dictionary = item
		var winner_seat := int(event.get("winner_seat", -1))
		var source_seat := int(event.get("source_seat", -1))
		var win_type := str(event.get("win_type", ""))
		if source_seat == 0 and winner_seat != 0 and not win_type.contains("self_draw"):
			return true
	return false


func _count_ai_wins(win_events: Array) -> int:
	var count := 0
	for item in win_events:
		var event: Dictionary = item
		if int(event.get("winner_seat", -1)) != 0:
			count += 1
	return count


func _count_ai_self_draws(win_events: Array) -> int:
	var count := 0
	for item in win_events:
		var event: Dictionary = item
		var winner_seat := int(event.get("winner_seat", -1))
		var win_type := str(event.get("win_type", ""))
		if winner_seat != 0 and win_type.contains("self_draw"):
			count += 1
	return count


func _count_ai_gangs(gang_events: Array) -> int:
	var count := 0
	for item in gang_events:
		var event: Dictionary = item
		if int(event.get("actor_seat", -1)) != 0:
			count += 1
	return count


func _ensure_learning_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(LEARNING_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _export_adjustment_history_file() -> void:
	var history_file := FileAccess.open(LEARNING_HISTORY_FILE, FileAccess.WRITE)
	if history_file == null:
		return
	var readable_history: Array = []
	for item in profile.get("adjustment_history", []):
		var entry: Dictionary = item
		var changed_lines: Array[String] = []
		for changed_item in entry.get("changed_parameters", []):
			var changed: Dictionary = changed_item
			var key: String = str(changed.get("key", ""))
			var before := int(changed.get("before", 0))
			var after := int(changed.get("after", 0))
			changed_lines.append("%s：%d → %d" % [str(PARAMETER_LABELS.get(key, key)), before, after])
		readable_history.append(
			{
				"round_index": int(entry.get("round_index", 0)),
				"timestamp_unix": int(entry.get("timestamp_unix", 0)),
				"summary_text": "第 %d 局后：%s" % [
					int(entry.get("round_index", 0)),
					"；".join(changed_lines) if not changed_lines.is_empty() else "参数未变化"
				],
				"reasons_text": " / ".join(entry.get("reasons", [])),
				"changed_parameters_text": changed_lines,
				"changed_parameters": entry.get("changed_parameters", []).duplicate(true),
				"changed_bias": entry.get("changed_bias", []).duplicate(true),
			}
		)
	var payload := {
		"updated_unix": int(profile.get("last_updated_unix", 0)),
		"total_human_rounds": int(profile.get("total_human_rounds", 0)),
		"latest_reasons": profile.get("last_adjustment_reasons", []).duplicate(true),
		"current_parameter_adjustments": profile.get("parameter_adjustments", {}).duplicate(true),
		"current_parameter_adjustments_text": _build_current_adjustment_text_lines(),
		"latest_reasons_text": " / ".join(profile.get("last_adjustment_reasons", [])),
		"latest_summary_text": _build_latest_adjustment_summary_text(),
		"readable_adjustment_history": readable_history,
		"adjustment_history": profile.get("adjustment_history", []).duplicate(true),
	}
	history_file.store_string(JSON.stringify(payload, "\t", false))


func _build_current_adjustment_text_lines() -> Array[String]:
	var lines: Array[String] = []
	var adjustments: Dictionary = profile.get("parameter_adjustments", {})
	for key in PARAMETER_LABELS.keys():
		var value := int(adjustments.get(key, 0))
		if value == 0:
			continue
		lines.append("%s%+d" % [str(PARAMETER_LABELS.get(key, key)), value])
	return lines


func _build_latest_adjustment_summary_text() -> String:
	var history: Array = profile.get("adjustment_history", [])
	if history.is_empty():
		return "暂无参数学习历史"
	var latest: Dictionary = history.back()
	var changed_lines: Array[String] = []
	for changed_item in latest.get("changed_parameters", []):
		var changed: Dictionary = changed_item
		var key: String = str(changed.get("key", ""))
		var before := int(changed.get("before", 0))
		var after := int(changed.get("after", 0))
		changed_lines.append("%s：%d → %d" % [str(PARAMETER_LABELS.get(key, key)), before, after])
	if changed_lines.is_empty():
		return "最近一轮学习未引起参数变化"
	return "第 %d 局后：%s" % [int(latest.get("round_index", 0)), "；".join(changed_lines)]
