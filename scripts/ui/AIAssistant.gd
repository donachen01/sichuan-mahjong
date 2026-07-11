extends Control

class_name AIAssistant

signal toggle_requested(expanded: bool)
signal recommendation_requested(tile_id: int)

@export var style_config: Resource

@onready var root_panel: Panel = %RootPanel
@onready var toggle_button: Button = %ToggleButton
@onready var recommendation_button: Button = %RecommendationButton
@onready var summary_label: Label = %SummaryLabel
@onready var reason_label: Label = %ReasonLabel
@onready var danger_label: Label = %DangerLabel
@onready var routes_label: Label = %RoutesLabel

var expanded: bool = false
var last_hint: Dictionary = {}


func _ready() -> void:
	if style_config == null:
		style_config = load("res://res/ui/default_ui_style.tres")
	style_config.apply_panel(root_panel)
	style_config.apply_button(toggle_button, false)
	style_config.apply_button(recommendation_button, true)
	style_config.apply_label(summary_label, false, false)
	style_config.apply_label(reason_label, true, false)
	style_config.apply_label(danger_label, true, false)
	style_config.apply_label(routes_label, true, false)
	toggle_button.pressed.connect(_on_toggle_pressed)
	recommendation_button.pressed.connect(_on_recommendation_pressed)
	reason_label.visible = expanded
	danger_label.visible = expanded
	routes_label.visible = expanded
	toggle_button.text = "展开"


func apply_hint(trainer_hint: Dictionary, can_discard: bool, selected_tile_id: int = -1) -> void:
	last_hint = trainer_hint.duplicate(true)
	var recommended: Dictionary = trainer_hint.get("recommended", {})
	if not can_discard or recommended.is_empty():
		summary_label.text = "当前不是你的主动出牌回合。"
		recommendation_button.visible = false
		reason_label.text = ""
		danger_label.text = ""
		routes_label.text = ""
		return

	var recommended_tile_id := int(recommended.get("tile", {}).get("id", -1))
	var recommended_tile_name := str(recommended.get("tile_name", "?"))
	summary_label.text = "建议先打：%s" % recommended_tile_name
	var selected_option: Dictionary = {}
	if selected_tile_id != -1 and selected_tile_id != recommended_tile_id:
		selected_option = _find_option_by_tile_id(trainer_hint.get("options", []), selected_tile_id)
		if not selected_option.is_empty():
			summary_label.text += " | 你现在点的是 %s：%s，%s，胡牌机会%.1f%%，%s" % [
				str(selected_option.get("tile_name", "?")),
				_plain_shanten_text(int(selected_option.get("shanten", 8))),
				_plain_ukeire_text(int(selected_option.get("ukeire", 0))),
				float(selected_option.get("win_probability", 0.0)) * 100.0,
				_plain_risk_label(str(selected_option.get("risk_label", "低危"))),
			]

	recommendation_button.visible = expanded and recommended_tile_id != -1
	recommendation_button.text = "点此选中 %s" % recommended_tile_name
	var display_option: Dictionary = selected_option if not selected_option.is_empty() else recommended
	var reasons: Array = display_option.get("reasons", [])
	var posterior_reasons: Array = display_option.get("posterior_reasons", display_option.get("csharp_posterior_reasons", []))
	var reason_parts: Array[String] = []
	if not reasons.is_empty():
		var base_lines: Array[String] = []
		for item in reasons.slice(0, 2):
			base_lines.append(_humanize_reason_text(str(item)))
		reason_parts.append("主要原因：%s" % "；".join(base_lines))
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		var table_lines: Array[String] = []
		for item in posterior_reasons.slice(0, 2):
			table_lines.append(_humanize_reason_text(str(item)))
		reason_parts.append("结合场上情况：%s" % "；".join(table_lines))
	if reason_parts.is_empty():
		reason_parts.append("先顾摸牌顺不顺，也顾一下安全。")
	reason_label.text = "为什么这样打：%s" % "\n".join(reason_parts)
	var danger_lines: Array = []
	for item in trainer_hint.get("danger_tiles", []).slice(0, 2):
		var line := "%s：%s" % [
			str(item.get("tile_name", "?")),
			_plain_risk_label(str(item.get("risk_label", "低危")))
		]
		var risk_reasons: Array = item.get("risk_reasons", [])
		if not risk_reasons.is_empty():
			line += "，%s" % _humanize_reason_text(str(risk_reasons[0]))
		danger_lines.append(line)
	danger_label.text = "尽量少打：%s" % (" / ".join(danger_lines) if not danger_lines.is_empty() else "暂时没有特别危险的牌")

	var route_text := "、".join(trainer_hint.get("current_routes", []))
	if route_text.is_empty():
		route_text = "先顾速度，也顾安全"
	routes_label.text = "这手牌现在可以往这些方向做：%s" % route_text
	if not selected_option.is_empty() and selected_tile_id != recommended_tile_id:
		routes_label.text += "\n为什么不先打%s：%s" % [
			str(selected_option.get("tile_name", "?")),
			_build_selected_option_delta_text(recommended, selected_option),
		]


func _on_toggle_pressed() -> void:
	expanded = not expanded
	var recommended: Dictionary = last_hint.get("recommended", {})
	recommendation_button.visible = expanded and int(recommended.get("tile", {}).get("id", -1)) != -1
	reason_label.visible = expanded
	danger_label.visible = expanded
	routes_label.visible = expanded
	toggle_button.text = "收起" if expanded else "展开"
	toggle_requested.emit(expanded)


func _on_recommendation_pressed() -> void:
	var recommended: Dictionary = last_hint.get("recommended", {})
	var tile_id := int(recommended.get("tile", {}).get("id", -1))
	if tile_id != -1:
		recommendation_requested.emit(tile_id)


func _find_option_by_tile_id(options: Array, tile_id: int) -> Dictionary:
	for option in options:
		var tile: Dictionary = option.get("tile", {})
		if int(tile.get("id", -1)) == tile_id:
			return option
	return {}


func _build_selected_option_delta_text(recommended: Dictionary, selected_option: Dictionary) -> String:
	var delta_shanten := int(selected_option.get("shanten", 8)) - int(recommended.get("shanten", 8))
	var delta_ukeire := int(selected_option.get("live_ukeire", 0)) - int(recommended.get("live_ukeire", 0))
	var delta_risk := int(selected_option.get("risk", 0)) - int(recommended.get("risk", 0))
	var parts: Array[String] = []
	if delta_shanten > 0:
		parts.append("会晚%d步才更接近听牌" % delta_shanten)
	elif delta_shanten < 0:
		parts.append("会快%d步接近听牌" % abs(delta_shanten))
	if delta_ukeire < 0:
		parts.append("后面能接上的牌会少%d张" % abs(delta_ukeire))
	elif delta_ukeire > 0:
		parts.append("后面能接上的牌会多%d张" % delta_ukeire)
	if delta_risk > 0:
		parts.append("而且会更危险一些")
	var posterior_reasons: Array = selected_option.get("posterior_reasons", selected_option.get("csharp_posterior_reasons", []))
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		parts.append(_humanize_reason_text(str(posterior_reasons[0])))
	if parts.is_empty():
		return "综合看没有现在这张合适"
	return "｜".join(parts.slice(0, 3))


func _plain_risk_label(risk_label: String) -> String:
	match risk_label:
		"高危":
			return "危险比较大"
		"中危":
			return "有点危险"
		_:
			return "相对安全"


func _plain_shanten_text(shanten: int) -> String:
	if shanten <= 0:
		return "已经听牌"
	return "离听牌还差%d步" % shanten


func _plain_ukeire_text(ukeire: int) -> String:
	return "后面能接上的牌大约%d张" % maxi(0, ukeire)


func _humanize_reason_text(text: String) -> String:
	var result := text
	var replacements := {
		"向听": "离听牌",
		"活进张": "能接上的牌",
		"进张": "能接上的牌",
		"后验": "结合场上情况再看",
		"压分": "会拉低收益",
		"净分期望": "综合收益",
		"危险度": "危险大小",
		"听形": "听牌后的牌路",
		"两面搭子": "两头都能接的顺子搭子",
		"孤张": "单张",
		"连张": "连着的牌",
		"宽叫": "更容易听牌",
	}
	for key in replacements.keys():
		result = result.replace(key, str(replacements[key]))
	return result
