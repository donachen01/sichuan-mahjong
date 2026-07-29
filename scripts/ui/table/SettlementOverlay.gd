class_name SettlementOverlay
extends Control

signal close_requested
signal next_round_requested

const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

@onready var shade: ColorRect = %Shade
@onready var panel: Panel = %Panel
@onready var round_label: Label = %RoundLabel
@onready var player_list: VBoxContainer = %PlayerList
@onready var result_badge: Label = %ResultBadge
@onready var focus_name_label: Label = %FocusNameLabel
@onready var score_label: Label = %ScoreLabel
@onready var fan_label: Label = %FanLabel
@onready var hand_label: Label = %HandLabel
@onready var breakdown_label: Label = %BreakdownLabel
@onready var close_button: Button = %CloseButton
@onready var next_round_button: Button = %NextRoundButton

var snapshot_view: Dictionary = {}
var selected_seat := -1
var display_contract: Dictionary = {}
var settlement_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_gui_input)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	next_round_button.pressed.connect(func() -> void: next_round_requested.emit())
	_apply_styles()
	resized.connect(_layout_panel)
	call_deferred("_layout_panel")


func render(snapshot: Dictionary) -> void:
	snapshot_view = snapshot.duplicate(true)
	var players: Array = snapshot_view.get("players", [])
	var settlement: Dictionary = snapshot_view.get("settlement_data", {})
	var score_changes: Dictionary = settlement.get("score_changes", {})
	var next_signature := "%s|%s|%s" % [settlement.get("round_index", snapshot_view.get("round_index", 1)), score_changes, settlement.get("win_events", [])]
	if next_signature != settlement_signature:
		settlement_signature = next_signature
		selected_seat = -1
	if selected_seat < 0 or _player_by_seat(players, selected_seat).is_empty():
		selected_seat = _resolve_focus_seat(players, settlement, score_changes)
	round_label.text = "第 %d 局 · %s" % [
		int(settlement.get("round_index", snapshot_view.get("round_index", 1))),
		_end_reason_text(str(settlement.get("end_reason", ""))),
	]
	_render_player_rows(players, score_changes)
	_render_focus(players, settlement, score_changes)
	_layout_panel()


func set_selected_seat(seat: int) -> void:
	selected_seat = clampi(seat, 0, 3)
	if not snapshot_view.is_empty():
		render(snapshot_view)


func get_display_contract() -> Dictionary:
	return display_contract.duplicate(true)


func get_next_round_button() -> Button:
	return next_round_button


func _render_player_rows(players: Array, score_changes: Dictionary) -> void:
	_clear_children(player_list)
	for player in players:
		var seat := int(player.get("seat", 0))
		var delta := _score_change(score_changes, seat)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 88.0)
		button.text = "%s\n总分 %d        %s%d" % [
			_player_name(player, seat),
			int(player.get("score", 0)),
			"+" if delta > 0 else "",
			delta,
		]
		STYLE_CONFIG.apply_button(button, false)
		button.add_theme_font_size_override("font_size", 26 if seat == selected_seat else 23)
		button.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		button.add_theme_stylebox_override("normal", _make_player_row_style(seat == selected_seat, delta))
		button.add_theme_stylebox_override("hover", _make_player_row_style(true, delta))
		button.add_theme_stylebox_override("pressed", _make_player_row_style(true, delta))
		button.pressed.connect(set_selected_seat.bind(seat))
		player_list.add_child(button)


func _render_focus(players: Array, settlement: Dictionary, score_changes: Dictionary) -> void:
	var player := _player_by_seat(players, selected_seat)
	var delta := _score_change(score_changes, selected_seat)
	var event := _win_event_for_seat(settlement.get("win_events", []), selected_seat)
	var result_text := _result_text(event, settlement, selected_seat)
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var fan := int(fan_detail.get("capped_fan", event.get("fan", 0)))
	var labels: Array = fan_detail.get("labels", event.get("labels", []))
	result_badge.text = result_text
	focus_name_label.text = _player_name(player, selected_seat)
	score_label.text = "%s%d" % ["+" if delta > 0 else "", delta]
	var label_text := " · ".join(labels)
	fan_label.text = "%d番%s" % [fan, " · %s" % label_text if not label_text.is_empty() else ""]
	if event.is_empty():
		fan_label.text = _draw_status_text(settlement, selected_seat)
	hand_label.text = _hand_summary(player, event)
	breakdown_label.text = _breakdown_text(settlement, event, selected_seat, delta)
	display_contract = {
		"selected_seat": selected_seat,
		"delta": delta,
		"score_changes": score_changes.duplicate(true),
		"result_text": result_text,
		"fan": fan,
		"labels": labels.duplicate(),
		"win_type": str(event.get("win_type", "")),
		"winner_seat": int(event.get("winner_seat", -1)),
		"source_seat": int(event.get("source_seat", -1)),
	}
	_apply_result_colors(delta)


func _resolve_focus_seat(players: Array, settlement: Dictionary, score_changes: Dictionary) -> int:
	var winners: Array = settlement.get("winner_seats", [])
	if not winners.is_empty():
		return int(winners[0])
	var best_seat := 0
	var best_delta := -999999
	for player in players:
		var seat := int(player.get("seat", 0))
		var delta := _score_change(score_changes, seat)
		if delta > best_delta:
			best_delta = delta
			best_seat = seat
	return best_seat


func _score_change(score_changes: Dictionary, seat: int) -> int:
	if score_changes.has(seat):
		return int(score_changes.get(seat, 0))
	return int(score_changes.get(str(seat), 0))


func _win_event_for_seat(events: Array, seat: int) -> Dictionary:
	for event in events:
		if int(event.get("winner_seat", -1)) == seat:
			return event
	return {}


func _result_text(event: Dictionary, settlement: Dictionary, seat: int) -> String:
	if event.is_empty():
		return "流局" if str(settlement.get("end_reason", "")).begins_with("draw") else "本局结算"
	match str(event.get("win_type", "")):
		"self_draw", "gang_self_draw":
			return "自摸"
		"qiang_gang_hu":
			return "抢杠胡"
		_:
			return "胡牌" if int(event.get("source_seat", seat)) != seat else "自摸"


func _draw_status_text(settlement: Dictionary, seat: int) -> String:
	var tags: Array[String] = []
	if settlement.get("hua_zhu_seats", []).has(seat):
		tags.append("花猪")
	if settlement.get("cha_jiao_seats", []).has(seat):
		tags.append("查叫")
	if settlement.get("ting_seats", []).has(seat):
		tags.append("有叫")
	return " · ".join(tags) if not tags.is_empty() else "本局无胡牌"


func _hand_summary(player: Dictionary, event: Dictionary) -> String:
	var names: Array[String] = []
	for tile in player.get("hand_tiles", []):
		var tile_name := str(tile.get("display_name", ""))
		if tile_name.is_empty():
			tile_name = "%d%s" % [int(tile.get("rank", 0)), _suit_text(str(tile.get("suit", "")))]
		names.append(tile_name)
	var winning_tile: Dictionary = event.get("winning_tile", {})
	if not winning_tile.is_empty():
		var winning_name := str(winning_tile.get("display_name", ""))
		if not winning_name.is_empty():
			names.append("胡%s" % winning_name)
	var meld_count := (player.get("melds", []) as Array).size()
	return "手牌：%s%s" % [
		" ".join(names) if not names.is_empty() else "未提供",
		" · %d组副露" % meld_count if meld_count > 0 else "",
	]


func _breakdown_text(settlement: Dictionary, event: Dictionary, seat: int, delta: int) -> String:
	var lines: Array[String] = []
	for line in settlement.get("display_lines", []):
		lines.append(str(line))
	if not event.is_empty():
		var source_seat := int(event.get("source_seat", seat))
		if source_seat == seat or source_seat < 0:
			lines.append("得分来源：自摸")
		else:
			lines.append("得分来源：%s点炮" % _seat_name(source_seat))
		var fan_detail: Dictionary = event.get("fan_detail", {})
		for label in fan_detail.get("labels", []):
			lines.append("牌型：%s" % str(label))
	if lines.is_empty():
		lines.append("本局分数变化：%s%d" % ["+" if delta > 0 else "", delta])
	return "\n".join(lines)


func _layout_panel() -> void:
	if panel == null:
		return
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var target := Vector2(viewport_size.x * 0.86, viewport_size.y * 0.76)
	target.x = clampf(target.x, 980.0, viewport_size.x - 32.0)
	target.y = clampf(target.y, 620.0, viewport_size.y - 28.0)
	panel.size = target
	panel.custom_minimum_size = target
	panel.position = (viewport_size - target) * 0.5


func _apply_styles() -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	for label in [round_label, result_badge, focus_name_label, score_label, fan_label, hand_label, breakdown_label]:
		# Calligraphy is reserved for the short settlement heading/badge. Names,
		# numbers and detail copy must keep the embedded Noto Sans CJK body font;
		# using the display font for a 72px score or multi-line ledger damages digit
		# clarity and violates the cross-platform no-system-fallback contract.
		var use_display_font: bool = label == round_label or label == result_badge
		STYLE_CONFIG.apply_label(label, label in [hand_label, breakdown_label], use_display_font)
		label.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.96))
		label.add_theme_constant_override("outline_size", 2)
	round_label.add_theme_font_size_override("font_size", 30)
	result_badge.add_theme_font_size_override("font_size", 34)
	focus_name_label.add_theme_font_size_override("font_size", 34)
	score_label.add_theme_font_size_override("font_size", 72)
	fan_label.add_theme_font_size_override("font_size", 28)
	hand_label.add_theme_font_size_override("font_size", 24)
	breakdown_label.add_theme_font_size_override("font_size", 24)
	for button in [close_button, next_round_button]:
		STYLE_CONFIG.apply_button(button, button == next_round_button)
		button.custom_minimum_size = Vector2(152.0, 64.0)
		button.add_theme_font_size_override("font_size", 26)


func _apply_result_colors(delta: int) -> void:
	score_label.add_theme_color_override("font_color", Color("FFE27A") if delta >= 0 else Color("F3B4AD"))
	result_badge.add_theme_stylebox_override("normal", _make_badge_style(delta))


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("031815")
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 22
	style.shadow_offset = Vector2(7.0, 10.0)
	return style


func _make_player_row_style(selected: bool, delta: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.161, 0.137, 0.96 if selected else 0.72)
	style.border_color = Color(TABLE_THEME.BRASS, 0.88 if selected else 0.28)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(10)
	if delta < 0 and not selected:
		style.bg_color = Color(0.23, 0.12, 0.11, 0.62)
	return style


func _make_badge_style(delta: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("8E2F33") if delta >= 0 else Color("4A4541")
	style.border_color = Color(TABLE_THEME.BRASS, 0.84)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()


func _player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if int(player.get("seat", -1)) == seat:
			return player
	return {}


func _player_name(player: Dictionary, seat: int) -> String:
	return str(player.get("nickname", player.get("name", _seat_name(seat))))


func _seat_name(seat: int) -> String:
	return ["本家", "上家", "对家", "下家"][clampi(seat, 0, 3)]


func _suit_text(suit: String) -> String:
	return {"wan": "万", "tong": "筒", "tiao": "条"}.get(suit, "")


func _end_reason_text(reason: String) -> String:
	return "牌墙流局" if reason.begins_with("draw") else "本局结算"


func _on_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_requested.emit()
		shade.accept_event()
