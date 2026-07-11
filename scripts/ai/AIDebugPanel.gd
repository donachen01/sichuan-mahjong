extends Control

class_name AIDebugPanel

@onready var label: Label = get_node_or_null("Label")


func apply_snapshot(snapshot: Dictionary) -> void:
	if label == null:
		return
	var turn_snapshot: Dictionary = snapshot.get("latest_turn_snapshot", {})
	var reaction_snapshot: Dictionary = snapshot.get("latest_reaction_snapshot", {})
	var backend_status: Dictionary = snapshot.get("backend_status", {})
	var performance_metrics: Dictionary = snapshot.get("performance_metrics", {})
	var request_state: Dictionary = snapshot.get("request_state", {})
	var lines: Array[String] = []
	lines.append("后端：%s | C#偏好：%s" % [
		str(backend_status.get("active_backend", "gdscript")),
		"开" if bool(backend_status.get("prefer_csharp_backend", false)) else "关"
	])
	if not turn_snapshot.is_empty():
		var analysis: Dictionary = turn_snapshot.get("analysis", {})
		var recommended: Dictionary = analysis.get("recommended", {})
		lines.append("出牌建议：%s | 向听 %s | 活进张 %s" % [
			str(recommended.get("tile_name", "-")),
			str(recommended.get("shanten", "-")),
			str(recommended.get("live_ukeire", "-"))
		])
		lines.append("策略：%s | 风险：%s | 胡率 %.1f%%" % [
			str(recommended.get("strategy_tag", "-")),
			str(recommended.get("risk_label", "-")),
			float(recommended.get("win_probability", 0.0)) * 100.0
		])
		lines.append("出牌耗时：%sms / 预算 %sms | 均值 %.1fms" % [
			str(turn_snapshot.get("elapsed_ms", "-")),
			str(turn_snapshot.get("budget_ms", performance_metrics.get("turn_budget_ms", "-"))),
			float(performance_metrics.get("turn_avg_ms", 0.0))
		])
	if not reaction_snapshot.is_empty():
		var reaction: Dictionary = reaction_snapshot.get("analysis", {})
		lines.append("反应建议：%s | 分值 %s" % [
			str(reaction.get("action", "pass")),
			str(reaction.get("score", 0))
		])
		lines.append("反应耗时：%sms / 预算 %sms | 均值 %.1fms" % [
			str(reaction_snapshot.get("elapsed_ms", "-")),
			str(reaction_snapshot.get("budget_ms", performance_metrics.get("reaction_budget_ms", "-"))),
			float(performance_metrics.get("reaction_avg_ms", 0.0))
		])
	lines.append("预算超限：出牌 %d 次 | 反应 %d 次" % [
		int(performance_metrics.get("turn_over_budget_count", 0)),
		int(performance_metrics.get("reaction_over_budget_count", 0))
	])
	var backend_turns: Dictionary = performance_metrics.get("backend_turns", {})
	var hybrid_stats: Dictionary = backend_turns.get("hybrid_csharp", {})
	if not hybrid_stats.is_empty():
		lines.append("C#混合：%d次 | 均值 %.1fms | 峰值 %dms | 超限 %d" % [
			int(hybrid_stats.get("count", 0)),
			float(hybrid_stats.get("avg_ms", 0.0)),
			int(hybrid_stats.get("max_ms", 0)),
			int(hybrid_stats.get("over_budget_count", 0))
		])
	lines.append("请求状态：进行中 %d | 最近 %s#%s" % [
		int(request_state.get("inflight_count", 0)),
		str(request_state.get("last_completed_kind", "-")),
		str(Dictionary(request_state.get("last_completed_request", {})).get("request_id", "-"))
	])
	label.text = "\n".join(lines)
