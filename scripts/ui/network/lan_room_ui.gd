extends Control
class_name SichuanLanRoomUI

const MODE_SELECT_SCENE := "res://scenes/network/GameModeSelect.tscn"
const BODY_FONT := preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const LOBBY_PANEL_GLASS := preload("res://res/art/ui/network/lan_lobby_panel_glass.png")
const LOBBY_READY_GLASS := preload("res://res/art/ui/network/lan_lobby_ready_glass.png")
const LOBBY_LEAVE_GLASS := preload("res://res/art/ui/network/lan_lobby_leave_glass.png")

var runtime: Node
var mode_overlay: Control
var room_overlay: Control
var lobby_overlay: Control
var lobby_panel: PanelContainer
var details_overlay: Control
var disconnected_overlay: Control
var disconnected_label: Label
var end_disconnected_game_button: Button
var room_list: VBoxContainer
var room_status: Label
var nickname_edit: LineEdit
var lobby_title: Label
var lobby_seats: GridContainer
var ready_button: Button
var start_button: Button
var leave_button: Button
var detail_tabs: TabContainer
var _ready := false

func setup(launch_layer: CanvasLayer) -> void:
	name = "LanRoomUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	launch_layer.add_child(self)
	# Dynamic controls must not fall back to the iOS system font. The fallback
	# was the source of the mojibake seen specifically in the details tabs.
	var embedded_theme := Theme.new()
	embedded_theme.default_font = BODY_FONT
	embedded_theme.default_font_size = 28
	theme = embedded_theme
	runtime = get_node_or_null("/root/LanRuntime")
	if runtime == null: return
	_build_room_overlay()
	_build_lobby_overlay()
	_build_details_overlay()
	_build_disconnected_overlay()
	runtime.rooms_changed.connect(_render_rooms)
	runtime.room_state_changed.connect(_render_lobby)
	runtime.status_changed.connect(func(message: String): room_status.text = message)
	runtime.match_started.connect(func(): lobby_overlay.hide())
	runtime.history_changed.connect(_render_details)
	runtime.player_disconnected.connect(show_player_disconnected)
	if not runtime.match_active and not runtime.session.current_room_state.is_empty(): _render_lobby(runtime.session.current_room_state)
	if not runtime.last_disconnected_player.is_empty(): show_player_disconnected(runtime.last_disconnected_player)

func _build_mode_overlay() -> void:
	mode_overlay = _overlay(Color(0.008, 0.035, 0.03, 0.90))
	var box := _panel_box(mode_overlay, Vector2(760, 500))
	var eyebrow := Label.new(); eyebrow.text = "四 川 麻 将"; eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; eyebrow.add_theme_font_size_override("font_size", 18); eyebrow.add_theme_color_override("font_color", Color("D5B56A")); box.add_child(eyebrow)
	var title := Label.new(); title.text = "选择游戏模式"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 38); title.add_theme_color_override("font_color", Color("FFF1C7")); box.add_child(title)
	var divider := HSeparator.new(); divider.add_theme_color_override("separator", Color("A9813E")); box.add_child(divider)
	var hint := Label.new(); hint.text = "选择本机对战，或与同一 Wi-Fi 内的玩家联机"; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.add_theme_font_size_override("font_size", 21); hint.add_theme_color_override("font_color", Color("D8D1B9")); box.add_child(hint)
	var choices := HBoxContainer.new(); choices.size_flags_vertical = Control.SIZE_EXPAND_FILL; choices.alignment = BoxContainer.ALIGNMENT_CENTER; choices.add_theme_constant_override("separation", 28); box.add_child(choices)
	var single := _mode_button("单机游戏\n\n经典人机对战", Vector2(310, 190), false); choices.add_child(single)
	var online := _mode_button("联网游戏\n\n同 Wi-Fi 建房对战", Vector2(310, 190), true); choices.add_child(online)
	single.pressed.connect(_choose_single_player)
	online.pressed.connect(_choose_online)

func _show_mode_choice() -> void:
	mode_overlay.show()
	var choices := mode_overlay.find_children("*", "Button", true, false)
	if not choices.is_empty(): (choices[0] as Button).grab_focus()

func _choose_single_player() -> void:
	mode_overlay.hide()

func _choose_online() -> void:
	mode_overlay.hide()
	_open_room_overlay()

func _build_room_overlay() -> void:
	room_overlay = _overlay()
	var box := _panel_box(room_overlay, Vector2(820, 610))
	box.add_child(_header("联机对战", func(): _close_room_overlay()))
	var nick_row := HBoxContainer.new()
	box.add_child(nick_row)
	var label := Label.new(); label.text = "我的昵称"; nick_row.add_child(label)
	nickname_edit = LineEdit.new(); nickname_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nickname_edit.text = _load_nickname(); nickname_edit.max_length = 24; nick_row.add_child(nickname_edit)
	var create_button := _button("创建房间", Vector2(170, 58)); box.add_child(create_button)
	create_button.pressed.connect(_create_room)
	var list_title := Label.new(); list_title.text = "同一 Wi-Fi 房间"; list_title.add_theme_font_size_override("font_size", 25); box.add_child(list_title)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(0, 300); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	room_list = VBoxContainer.new(); room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(room_list)
	room_status = Label.new(); room_status.text = "正在自动搜索…"; box.add_child(room_status)

func _build_lobby_overlay() -> void:
	lobby_overlay = _overlay(Color(0, 0, 0, 0.0))
	lobby_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _panel_box(lobby_overlay, Vector2(860, 430))
	lobby_panel = box.get_parent().get_parent() as PanelContainer
	lobby_panel.add_theme_stylebox_override("panel", _lobby_glass_style(LOBBY_PANEL_GLASS, 22))
	var lobby_center := lobby_panel.get_parent() as CenterContainer
	lobby_center.offset_top = 150
	lobby_center.offset_bottom = 150
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_title = Label.new(); lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lobby_title.add_theme_font_size_override("font_size", 30); lobby_title.add_theme_color_override("font_color", Color("F2FAFF")); lobby_title.add_theme_color_override("font_outline_color", Color(0.02, 0.16, 0.27, 0.90)); lobby_title.add_theme_constant_override("outline_size", 3); box.add_child(lobby_title)
	lobby_seats = GridContainer.new(); lobby_seats.hide(); box.add_child(lobby_seats)
	ready_button = _button("准 备", Vector2(720, 136)); _style_lobby_action(ready_button, true); box.add_child(ready_button)
	start_button = _button("开 始 游 戏", Vector2(720, 136)); _style_lobby_action(start_button, true); box.add_child(start_button)
	leave_button = _button("离 开 游 戏", Vector2(720, 136)); _style_lobby_action(leave_button, false); box.add_child(leave_button)
	ready_button.pressed.connect(func(): _ready = not _ready; runtime.set_ready(_ready))
	start_button.hide()
	leave_button.pressed.connect(_leave_game)

func _leave_game() -> void:
	runtime.leave_room()
	lobby_overlay.hide()
	if disconnected_overlay != null:
		disconnected_overlay.hide()
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)


func _build_disconnected_overlay() -> void:
	disconnected_overlay = _overlay(Color(0.02, 0.08, 0.16, 0.52))
	disconnected_overlay.name = "PlayerDisconnectedOverlay"
	var box := _panel_box(disconnected_overlay, Vector2(760, 350))
	var panel := box.get_parent().get_parent() as PanelContainer
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.36, 0.67, 0.94, 0.24)
	glass.border_color = Color(1.0, 1.0, 1.0, 0.93)
	glass.set_border_width_all(2)
	glass.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", glass)
	disconnected_label = Label.new()
	disconnected_label.name = "DisconnectedMessage"
	disconnected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disconnected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disconnected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disconnected_label.custom_minimum_size = Vector2(680, 136)
	disconnected_label.add_theme_font_override("font", BODY_FONT)
	disconnected_label.add_theme_font_size_override("font_size", 38)
	disconnected_label.add_theme_color_override("font_color", Color.WHITE)
	disconnected_label.add_theme_color_override("font_outline_color", Color(0.02, 0.16, 0.34, 0.95))
	disconnected_label.add_theme_constant_override("outline_size", 3)
	box.add_child(disconnected_label)
	end_disconnected_game_button = _button("结束游戏 · 返回模式选择", Vector2(680, 110))
	end_disconnected_game_button.name = "EndDisconnectedGameButton"
	_style_lobby_action(end_disconnected_game_button, true)
	end_disconnected_game_button.pressed.connect(_leave_game)
	box.add_child(end_disconnected_game_button)


func show_player_disconnected(player: Dictionary) -> void:
	if disconnected_overlay == null:
		return
	var nickname := str(player.get("nickname", "玩家")).strip_edges()
	if nickname.is_empty():
		nickname = "玩家"
	disconnected_label.text = "%s已掉线\n本局联机已中断，其他玩家可以结束游戏。" % ("房主 %s " % nickname if bool(player.get("is_host", false)) else "%s " % nickname)
	lobby_overlay.hide()
	disconnected_overlay.show()
	disconnected_overlay.move_to_front()
	end_disconnected_game_button.grab_focus()

func _build_details_overlay() -> void:
	details_overlay = _overlay(Color(0.015, 0.04, 0.032, 0.80))
	var box := _panel_box(details_overlay, Vector2(1500, 850))
	box.add_child(_header("对局详情", func(): details_overlay.hide()))
	detail_tabs = TabContainer.new(); detail_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; detail_tabs.add_theme_font_override("font", BODY_FONT); detail_tabs.add_theme_font_size_override("font_size", 34); _style_details_tabs(detail_tabs); box.add_child(detail_tabs)
	for title in ["对局排行", "对局流水", "房间玩法"]:
		var scroll := ScrollContainer.new(); scroll.name = title; detail_tabs.add_child(scroll)
		var text := RichTextLabel.new(); text.name = "Content"; text.bbcode_enabled = true; text.fit_content = true; text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; text.size_flags_vertical = Control.SIZE_EXPAND_FILL; text.add_theme_font_override("normal_font", BODY_FONT); text.add_theme_font_override("bold_font", BODY_FONT); text.add_theme_font_size_override("normal_font_size", 31); text.add_theme_font_size_override("bold_font_size", 34); text.add_theme_color_override("default_color", Color("F2E7C9")); text.add_theme_stylebox_override("normal", _details_content_style()); scroll.add_child(text)

func _open_room_overlay() -> void:
	if not runtime.session.current_room_state.is_empty():
		_render_lobby(runtime.session.current_room_state)
		return
	room_overlay.show(); room_status.text = "正在自动搜索同一 Wi-Fi 内的房间…"
	var result: Error = runtime.browse_rooms()
	if result != OK: room_status.text = "搜索失败：%s" % error_string(result)

func _close_room_overlay() -> void:
	room_overlay.hide(); runtime.stop_browsing()

func _create_room() -> void:
	_save_nickname(nickname_edit.text)
	var result: Error = runtime.host_room(nickname_edit.text)
	if result != OK: room_status.text = "创建失败：%s" % error_string(result)

func _join_room(room: Dictionary) -> void:
	_save_nickname(nickname_edit.text)
	room_status.text = "正在加入房间…"
	var result: Error = runtime.join_room(str(room.address), int(room.port), nickname_edit.text)
	if result != OK: room_status.text = "加入失败：%s" % error_string(result)

func _render_rooms(rooms: Array) -> void:
	for child in room_list.get_children(): child.queue_free()
	rooms.sort_custom(func(a, b): return str(a.get("room_number", "")) < str(b.get("room_number", "")))
	for room in rooms:
		var row := HBoxContainer.new(); room_list.add_child(row)
		var info := Label.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s  房主：%s  真人 %d/%d%s" % [str(room.get("room_number", "------")), str(room.get("host_name", room.get("name", ""))), int(room.get("human_count", 1)), int(room.get("capacity", 4)), "  游戏中" if str(room.get("state", "waiting")) != "waiting" else ""]
		row.add_child(info)
		var join := _button("加入", Vector2(110, 48)); join.disabled = str(room.get("state", "waiting")) != "waiting"; row.add_child(join); join.pressed.connect(_join_room.bind(room))
	room_status.text = "未发现房间，正在继续搜索…" if rooms.is_empty() else "已发现 %d 个房间" % rooms.size()

func _render_lobby(state: Dictionary) -> void:
	room_overlay.hide()
	# During an active match room-state updates drive the four nameplates only.
	# Never cover settlement with the pre-game lobby panel.
	if not runtime.match_active:
		lobby_overlay.show()
	lobby_title.text = "房间 %s  ·  真人 %d/4  ·  AI %d" % [str(state.get("room_number", "------")), int(state.get("human_count", 1)), 4 - int(state.get("human_count", 1))]
	for child in lobby_seats.get_children(): child.queue_free()
	var members_by_seat := {}
	for member in state.get("members", []): members_by_seat[int(member.seat)] = member
	for controller in state.get("controllers", []):
		var seat := int(controller.get("seat", 0)); var card := Label.new(); card.custom_minimum_size = Vector2(280, 92); card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bool(controller.get("is_ai", false)): card.text = "%s\n已准备 · AI" % str(controller.nickname)
		else:
			var member: Dictionary = members_by_seat.get(seat, {}); card.text = "%s%s\n%s" % [str(controller.nickname), "（我）" if str(controller.player_id) == runtime.session.local_player_id else "", "已准备" if bool(member.get("ready", false)) else "未准备"]
		lobby_seats.add_child(card)
	var local := {}
	for member in state.get("members", []):
		if str(member.player_id) == runtime.session.local_player_id: local = member
	_ready = bool(local.get("ready", false)); ready_button.text = "取 消 准 备" if _ready else "准 备"
	ready_button.visible = true
	start_button.visible = false
	leave_button.visible = not runtime.match_active

func show_round_ready_controls() -> void:
	# Round readiness is rendered on the four seat nameplates. Reopening a
	# centered lobby here covered the table and hid exactly who was not ready.
	lobby_overlay.hide()

func hide_round_ready_controls() -> void:
	lobby_overlay.hide()

func _open_details() -> void:
	_render_details(); details_overlay.show()

func open_details() -> void:
	_open_details()

func _render_details() -> void:
	if detail_tabs == null: return
	var totals := {}; var wins := {}; var discards := {}; var gangs := {}; var names := {}
	for controller in runtime.session.current_room_state.get("controllers", []): names[int(controller.seat)] = str(controller.nickname)
	for record in runtime.room_history:
		for key in record.get("score_changes", {}): totals[int(str(key))] = int(totals.get(int(str(key)), 0)) + int(record.score_changes[key])
		for event in record.get("win_events", []): wins[int(event.get("winner_seat", -1))] = int(wins.get(int(event.get("winner_seat", -1)), 0)) + 1; discards[int(event.get("discarder_seat", -1))] = int(discards.get(int(event.get("discarder_seat", -1)), 0)) + (0 if bool(event.get("is_self_draw", false)) else 1)
		for event in record.get("gang_events", []): gangs[int(event.get("seat", -1))] = int(gangs.get(int(event.get("seat", -1)), 0)) + 1
	var seats := names.keys(); seats.sort_custom(func(a, b):
		if int(totals.get(a, 0)) != int(totals.get(b, 0)): return int(totals.get(a, 0)) > int(totals.get(b, 0))
		if int(wins.get(a, 0)) != int(wins.get(b, 0)): return int(wins.get(a, 0)) > int(wins.get(b, 0))
		return int(a) < int(b)
	)
	var ranking := "[font_size=34][color=#E8C66D][b]排名　玩家　　　　　　　　积分　胡牌　点炮　杠[/b][/color][/font_size]\n[color=#7F9F91]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n"
	for index in range(seats.size()): var seat = seats[index]; ranking += "[font_size=32][color=#FFF1C7][b]%d[/b][/color]　%s　　　　　　　　[color=#FFE27A]%+d[/color]　　%d　　%d　　%d[/font_size]\n[color=#355F53]────────────────────────────────[/color]\n" % [index + 1, names[seat], totals.get(seat, 0), wins.get(seat, 0), discards.get(seat, 0), gangs.get(seat, 0)]
	if seats.is_empty(): ranking += "暂无已完成对局"
	_set_tab_text(0, ranking)
	var ledger := ""
	for record in runtime.room_history: ledger += "[font_size=34][color=#E8C66D][b]第 %d 局[/b][/color][/font_size]\n[font_size=30]%s[/font_size]\n[color=#355F53]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" % [int(record.get("round_index", 0)), _score_line(record)]
	_set_tab_text(1, ledger if not ledger.is_empty() else "本局未结束，暂不计入流水。")
	_set_tab_text(2, "[font_size=36][color=#E8C66D][b]四川血战到底[/b][/color][/font_size]\n[color=#355F53]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n\n[font_size=31][color=#FFF1C7][b]核心玩法[/b][/color]\n定缺 · 查叫 · 花猪 · 杠分 · 呼叫转移\n\n[color=#FFF1C7][b]牌局规则[/b][/color]\n最后一张牌没有后续补牌时不可杠。\n本局未结束的数据不计入排行和流水。[/font_size]")

func _score_line(record: Dictionary) -> String:
	var parts: Array[String] = []
	for seat in range(4): parts.append("%s %+d" % [str(record.get("player_names", {}).get(seat, "座位%d" % (seat + 1))), int(record.get("score_changes", {}).get(seat, record.get("score_changes", {}).get(str(seat), 0)))])
	return "  ".join(parts)

func _set_tab_text(index: int, value: String) -> void:
	var content := detail_tabs.get_child(index).get_node("Content") as RichTextLabel; content.text = value

func _overlay(shade := Color(0, 0, 0, 0.62)) -> Control:
	var overlay := Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_STOP; overlay.hide(); add_child(overlay)
	var color := ColorRect.new(); color.color = shade; color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(color)
	return overlay

func _panel_box(overlay: Control, minimum: Vector2) -> VBoxContainer:
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(center)
	var panel := PanelContainer.new(); panel.custom_minimum_size = minimum; center.add_child(panel)
	var panel_style := StyleBoxFlat.new(); panel_style.bg_color = Color("082C25"); panel_style.border_color = Color("B58B43"); panel_style.set_border_width_all(3); panel_style.set_corner_radius_all(22); panel_style.shadow_color = Color(0, 0, 0, 0.55); panel_style.shadow_size = 18; panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 28); margin.add_theme_constant_override("margin_right", 28); margin.add_theme_constant_override("margin_top", 22); margin.add_theme_constant_override("margin_bottom", 22); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); margin.add_child(box); return box

func _header(title: String, close_action: Callable) -> HBoxContainer:
	var row := HBoxContainer.new(); var label := Label.new(); label.text = title; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_override("font", BODY_FONT); label.add_theme_font_size_override("font_size", 44); label.add_theme_color_override("font_color", Color("E8C66D")); row.add_child(label)
	var close := _button("×", Vector2(84, 68)); close.add_theme_font_size_override("font_size", 38); row.add_child(close); close.pressed.connect(close_action); return row

func _button(text_value: String, minimum: Vector2) -> Button:
	var result := Button.new(); result.text = text_value; result.custom_minimum_size = minimum; result.add_theme_font_size_override("font_size", 22); _style_button(result, false); return result

func _mode_button(text_value: String, minimum: Vector2, primary: bool) -> Button:
	var result := Button.new(); result.text = text_value; result.custom_minimum_size = minimum; result.add_theme_font_size_override("font_size", 27); result.add_theme_color_override("font_color", Color("FFF1C7")); result.add_theme_color_override("font_hover_color", Color.WHITE); _style_button(result, primary); return result

func _style_button(button: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new(); normal.bg_color = Color("12604D") if primary else Color("0D4036"); normal.border_color = Color("D0A858") if primary else Color("806A43"); normal.set_border_width_all(2); normal.set_corner_radius_all(14); normal.content_margin_left = 20; normal.content_margin_right = 20; normal.content_margin_top = 14; normal.content_margin_bottom = 14
	var hover := normal.duplicate() as StyleBoxFlat; hover.bg_color = Color("19745C") if primary else Color("145245"); hover.border_color = Color("F3D17E"); hover.set_border_width_all(3)
	var pressed := hover.duplicate() as StyleBoxFlat; pressed.bg_color = Color("092F28")
	var focus := hover.duplicate() as StyleBoxFlat; focus.border_color = Color("FFE29A"); focus.set_border_width_all(4)
	button.add_theme_stylebox_override("normal", normal); button.add_theme_stylebox_override("hover", hover); button.add_theme_stylebox_override("pressed", pressed); button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("F4E8C5")); button.add_theme_color_override("font_hover_color", Color.WHITE)

func _style_lobby_action(button: Button, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 46)
	button.add_theme_font_override("font", BODY_FONT)
	var ink := Color.WHITE if primary else Color("0752A0")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.19, 0.44, 0.35) if primary else Color(0, 0, 0, 0))
	button.add_theme_constant_override("outline_size", 2 if primary else 0)
	var texture: Texture2D = LOBBY_READY_GLASS if primary else LOBBY_LEAVE_GLASS
	var normal := _lobby_glass_style(texture, 14)
	var hover := _lobby_glass_style(texture, 14)
	hover.modulate_color = Color(1.12, 1.12, 1.12, 1.0)
	var pressed := _lobby_glass_style(texture, 14)
	pressed.modulate_color = Color(0.82, 0.87, 0.94, 1.0)
	var disabled := _lobby_glass_style(texture, 14)
	disabled.modulate_color = Color(0.66, 0.70, 0.75, 0.60)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)

func _lobby_glass_style(texture: Texture2D, corner_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.texture_margin_left = corner_margin
	style.texture_margin_right = corner_margin
	style.texture_margin_top = corner_margin
	style.texture_margin_bottom = corner_margin
	return style

func _style_details_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_stylebox_override("panel", _details_content_style())
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("0D5A46")
	selected.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.96)
	selected.set_border_width_all(3)
	selected.set_corner_radius_all(12)
	selected.content_margin_left = 34
	selected.content_margin_right = 34
	selected.content_margin_top = 16
	selected.content_margin_bottom = 16
	var unselected := selected.duplicate() as StyleBoxFlat
	unselected.bg_color = Color("092F28")
	unselected.border_color = Color(TABLE_THEME.BRASS, 0.34)
	unselected.set_border_width_all(1)
	tabs.add_theme_stylebox_override("tab_selected", selected)
	tabs.add_theme_stylebox_override("tab_unselected", unselected)
	tabs.add_theme_stylebox_override("tab_hovered", selected)
	tabs.add_theme_color_override("font_selected_color", Color("FFF1C7"))
	tabs.add_theme_color_override("font_unselected_color", Color("BFB79F"))

func _details_content_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("031815")
	style.border_color = Color(TABLE_THEME.COPPER_HIGHLIGHT, 0.74)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	return style

func _load_nickname() -> String:
	var config := ConfigFile.new(); if config.load("user://lan_profile.cfg") == OK: return str(config.get_value("profile", "nickname", OS.get_name()))
	return "iPhone" if OS.has_feature("ios") else ("Android" if OS.has_feature("android") else "玩家")

func _save_nickname(value: String) -> void:
	var clean := value.strip_edges().left(24); if clean.is_empty(): clean = "玩家"; nickname_edit.text = clean
	var config := ConfigFile.new(); config.set_value("profile", "nickname", clean); config.save("user://lan_profile.cfg")
