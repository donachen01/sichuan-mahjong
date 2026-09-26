extends Control

const MAIN_SCENE := "res://scenes/table/MainSceneV2.tscn"
const BODY_FONT := preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
const UIStyleConfigScript := preload("res://scripts/ui/UIStyleConfig.gd")

const BACKGROUND_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.94, 0.965, 0.995);
	vec3 bottom = vec3(0.018, 0.30, 0.76);
	// A single uninterrupted top-to-bottom ramp keeps the lower edge from
	// becoming a separate flat color band.
	float vertical = pow(clamp(uv.y, 0.0, 1.0), 1.90);
	vec3 color = mix(top, bottom, vertical);
	float horizon = 1.0 - smoothstep(0.0, 0.42, abs(uv.y - 0.52));
	color += vec3(0.18, 0.34, 0.58) * horizon * 0.075;
	float upper_light = 1.0 - smoothstep(0.0, 0.72, distance(uv, vec2(0.50, 0.08)));
	float left_light = 1.0 - smoothstep(0.0, 0.48, distance(uv, vec2(0.18, 0.50)));
	float right_light = 1.0 - smoothstep(0.0, 0.44, distance(uv, vec2(0.82, 0.47)));
	color += vec3(1.0, 1.0, 1.0) * upper_light * 0.16;
	color += vec3(0.48, 0.72, 1.0) * (left_light + right_light) * 0.07;
	COLOR = vec4(color, 1.0);
}
"""

const BUTTON_LIGHT_SHADER := """
shader_type canvas_item;
uniform vec4 color_top : source_color;
uniform vec4 color_bottom : source_color;
uniform vec4 light_color : source_color;
uniform float glass_mode;
void fragment() {
	vec2 uv = UV;
	vec4 base = mix(color_top, color_bottom, smoothstep(0.0, 1.0, uv.y));
	// Target lighting travels from upper-left to lower-right. The earlier
	// x+y beam produced the opposite diagonal and visually flattened the cards.
	float diagonal = 1.0 - smoothstep(0.03, 0.34, abs(uv.x - uv.y - 0.05));
	float upper_left = 1.0 - smoothstep(0.0, 0.76, distance(uv, vec2(-0.10, -0.08)));
	float lower_right = 1.0 - smoothstep(0.0, 0.70, distance(uv, vec2(1.08, 1.10)));
	float lower_left = 1.0 - smoothstep(0.0, 0.78, distance(uv, vec2(-0.12, 1.12)));
	float white_card_light = diagonal * 0.15 + upper_left * 0.15 + lower_right * 0.18;
	float blue_card_light = upper_left * 0.25 + lower_left * 0.07 + lower_right * 0.27 + diagonal * 0.065;
	base.rgb += light_color.rgb * mix(white_card_light, blue_card_light, glass_mode) * light_color.a;
	float edge = smoothstep(0.0, 0.035, uv.x) * smoothstep(0.0, 0.035, uv.y) * smoothstep(0.0, 0.035, 1.0 - uv.x) * smoothstep(0.0, 0.035, 1.0 - uv.y);
	base.rgb += vec3(1.0) * (1.0 - edge) * 0.055;
	// Keep the shader inside the same rounded silhouette as the glass card.
	vec2 p = (uv - vec2(0.5)) * vec2(2.114, 1.0);
	float radius = 0.045;
	vec2 bounds = vec2(1.057, 0.5) - vec2(radius);
	vec2 q = abs(p) - bounds;
	float rounded_distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float shape = 1.0 - smoothstep(-0.004, 0.004, rounded_distance);
	base.a *= shape;
	COLOR = base;
}
"""

var runtime: Node
var mode_panel: Control
var online_panel: Control
var room_list: VBoxContainer
var status_label: Label
var nickname_edit: LineEdit
var current_room_panel: PanelContainer
var current_room_title: Label
var current_room_members: GridContainer
var ready_button: Button
var start_button: Button
var _local_ready := false
var single_button: Button
var online_button: Button
var quit_button: Button
var ios_exit_dialog: AcceptDialog
var _navigating := false
var _mode_choice_locked := false
var _style = UIStyleConfigScript.new()

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = BODY_FONT
	ui_theme.default_font_size = 30
	theme = ui_theme
	runtime = get_node("/root/LanRuntime")
	_build_background()
	_build_mode_panel()
	_build_online_panel()
	runtime.rooms_changed.connect(_render_rooms)
	runtime.room_state_changed.connect(_render_current_room)
	runtime.room_table_entered.connect(_enter_network_table)
	runtime.status_changed.connect(func(message: String): status_label.text = message)
	mode_panel.show()
	online_panel.hide()

func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "GlassGradientBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BACKGROUND_SHADER
	material.shader = shader
	background.material = material
	add_child(background)
	var ambient := ColorRect.new()
	ambient.name = "AmbientGlassVeil"
	ambient.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Full-rect veil only: inset offsets created visible horizontal seams near
	# the screen edges and interrupted the background gradient.
	ambient.color = Color(0.82, 0.91, 1.0, 0.018)
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ambient)

func _build_mode_panel() -> void:
	mode_panel = _centered_panel(Vector2(1320, 720))
	var box := _panel_content(mode_panel)
	_add_title(box, "", "请选择游戏模式")
	var choices := HBoxContainer.new(); choices.alignment = BoxContainer.ALIGNMENT_CENTER; choices.size_flags_vertical = Control.SIZE_EXPAND_FILL; choices.add_theme_constant_override("separation", 56); box.add_child(choices)
	single_button = _large_button("单机游戏", false); choices.add_child(single_button)
	online_button = _large_button("联网游戏", true); choices.add_child(online_button)
	single_button.pressed.connect(_choose_single)
	online_button.pressed.connect(_show_online)
	quit_button = _action_button("退出游戏", false)
	quit_button.name = "QuitGameButton"
	quit_button.custom_minimum_size = Vector2(360, 88)
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_button.add_theme_font_size_override("font_size", 31)
	box.add_child(quit_button)
	quit_button.pressed.connect(_request_app_exit)
	single_button.grab_focus.call_deferred()

func _request_app_exit() -> void:
	if OS.has_feature("ios"):
		_show_ios_exit_instructions()
		return
	get_tree().quit(0)

func _show_ios_exit_instructions() -> void:
	if ios_exit_dialog == null:
		ios_exit_dialog = AcceptDialog.new()
		ios_exit_dialog.name = "IOSExitInstructions"
		ios_exit_dialog.title = "关闭游戏"
		ios_exit_dialog.dialog_text = "iPhone 和 iPad 不允许应用主动结束自身进程。\n请返回主屏幕；如需完全关闭，请在多任务界面中将本游戏向上划出。"
		ios_exit_dialog.ok_button_text = "知道了"
		ios_exit_dialog.exclusive = false
		ios_exit_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ios_exit_dialog)
	ios_exit_dialog.popup_centered(Vector2i(920, 390))

func get_quit_behavior_contract() -> Dictionary:
	return {
		"desktop": "quit_process",
		"android": "quit_process",
		"ios": "show_system_exit_instructions",
	}

func _input(event: InputEvent) -> void:
	if not mode_panel.visible or _mode_choice_locked: return
	var pressed := false
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed; point = event.position
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT; point = event.position
	if not pressed: return
	if single_button.get_global_rect().has_point(point):
		get_viewport().set_input_as_handled(); _choose_single()
	elif online_button.get_global_rect().has_point(point):
		get_viewport().set_input_as_handled(); _show_online()

func _choose_single() -> void:
	if _mode_choice_locked: return
	_mode_choice_locked = true
	if not runtime.session.current_room_state.is_empty():
		runtime.leave_room()
	get_node("/root/GameState").call("start_local_game")
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)

func _build_online_panel() -> void:
	online_panel = _centered_panel(Vector2(1660, 900))
	var box := _panel_content(online_panel)
	var top_space := Control.new(); top_space.custom_minimum_size = Vector2(0, 28); box.add_child(top_space)
	var nick_row := HBoxContainer.new(); nick_row.alignment = BoxContainer.ALIGNMENT_CENTER; nick_row.add_theme_constant_override("separation", 20); box.add_child(nick_row)
	var nick_label := Label.new(); nick_label.text = "我的昵称"; nick_label.custom_minimum_size = Vector2(180, 74); nick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; nick_label.add_theme_font_size_override("font_size", 31); nick_label.add_theme_color_override("font_color", Color("0A4E8C")); nick_row.add_child(nick_label)
	nickname_edit = LineEdit.new(); nickname_edit.text = _load_nickname().left(4); nickname_edit.max_length = 4; nickname_edit.custom_minimum_size = Vector2(520, 74); nickname_edit.add_theme_font_size_override("font_size", 32); nickname_edit.add_theme_color_override("font_color", Color("0A4E8C")); nickname_edit.add_theme_color_override("caret_color", Color("1478D4")); nickname_edit.add_theme_color_override("selection_color", Color(0.18, 0.55, 1.0, 0.28)); nickname_edit.add_theme_stylebox_override("normal", _glass_input_style()); nickname_edit.add_theme_stylebox_override("focus", _glass_input_style(true)); nick_row.add_child(nickname_edit)
	var action_row := HBoxContainer.new(); action_row.alignment = BoxContainer.ALIGNMENT_CENTER; action_row.add_theme_constant_override("separation", 26); box.add_child(action_row)
	var back := _action_button("返回", false); back.custom_minimum_size = Vector2(220, 92); action_row.add_child(back); back.pressed.connect(_back_to_modes)
	var refresh := _action_button("重新搜索", false); refresh.custom_minimum_size = Vector2(300, 92); action_row.add_child(refresh); refresh.pressed.connect(_refresh_rooms)
	var create := _action_button("创建房间", true); create.custom_minimum_size = Vector2(430, 92); create.add_theme_font_size_override("font_size", 35); action_row.add_child(create); create.pressed.connect(_create_room)
	_build_current_room_panel(box)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(0, 310); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	room_list = VBoxContainer.new(); room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; room_list.add_theme_constant_override("separation", 16); scroll.add_child(room_list)
	status_label = Label.new(); status_label.text = "正在搜索同一 Wi-Fi 内的房间…"; status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status_label.add_theme_font_size_override("font_size", 28); status_label.add_theme_color_override("font_color", Color("175F9E")); box.add_child(status_label)

func _build_current_room_panel(box: VBoxContainer) -> void:
	current_room_panel = PanelContainer.new(); current_room_panel.hide(); current_room_panel.add_theme_stylebox_override("panel", _online_card_style()); box.add_child(current_room_panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 28); margin.add_theme_constant_override("margin_right", 28); margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_bottom", 20); current_room_panel.add_child(margin)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 16); margin.add_child(content)
	current_room_title = Label.new(); current_room_title.add_theme_font_size_override("font_size", 38); current_room_title.add_theme_color_override("font_color", Color("084B88")); content.add_child(current_room_title)
	current_room_members = GridContainer.new(); current_room_members.columns = 2; current_room_members.add_theme_constant_override("h_separation", 28); current_room_members.add_theme_constant_override("v_separation", 10); content.add_child(current_room_members)
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 22); content.add_child(controls)
	ready_button = _action_button("我已准备", true); ready_button.custom_minimum_size = Vector2(330, 82); controls.add_child(ready_button); ready_button.pressed.connect(_toggle_ready)
	start_button = _action_button("开始游戏", true); start_button.custom_minimum_size = Vector2(330, 82); controls.add_child(start_button); start_button.pressed.connect(func(): runtime.begin_match())
	var leave := _action_button("离开房间", false); leave.custom_minimum_size = Vector2(280, 82); controls.add_child(leave); leave.pressed.connect(_leave_room)

func _show_online() -> void:
	if _mode_choice_locked: return
	_mode_choice_locked = true
	mode_panel.hide(); online_panel.show(); _refresh_rooms()

func _back_to_modes() -> void:
	if not runtime.session.current_room_state.is_empty(): runtime.leave_room()
	runtime.stop_browsing(); online_panel.hide(); mode_panel.show(); _mode_choice_locked = false

func _refresh_rooms() -> void:
	status_label.text = "正在自动搜索同一 Wi-Fi 内的房间…"
	var result: Error = runtime.browse_rooms()
	if result != OK: status_label.text = "搜索失败：%s" % error_string(result)

func _create_room() -> void:
	_save_nickname()
	var result: Error = runtime.host_room(nickname_edit.text)
	if result != OK: status_label.text = "创建失败：%s" % error_string(result)

func _join(room: Dictionary) -> void:
	_save_nickname(); status_label.text = "正在加入 %s…" % str(room.get("room_number", ""))
	var result: Error = runtime.join_room(str(room.address), int(room.port), nickname_edit.text)
	if result != OK: status_label.text = "加入失败：%s" % error_string(result)

func _render_rooms(rooms: Array) -> void:
	for child in room_list.get_children(): child.queue_free()
	rooms.sort_custom(func(a, b): return str(a.get("room_number", "")) < str(b.get("room_number", "")))
	for room in rooms:
		var card := PanelContainer.new(); card.custom_minimum_size = Vector2(0, 112); card.add_theme_stylebox_override("panel", _online_card_style()); room_list.add_child(card)
		var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 26); margin.add_theme_constant_override("margin_right", 20); margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 14); card.add_child(margin)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 20); margin.add_child(row)
		var info := Label.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; info.add_theme_font_size_override("font_size", 31); info.add_theme_color_override("font_color", Color("0A4E8C")); info.text = "房间 %s    房主：%s    真人 %d/%d" % [str(room.get("room_number", "------")), str(room.get("host_name", room.get("name", ""))), int(room.get("human_count", 1)), int(room.get("capacity", 4))]; row.add_child(info)
		var join := _action_button("加入房间", true); join.custom_minimum_size = Vector2(300, 82); join.add_theme_font_size_override("font_size", 33); join.disabled = str(room.get("state", "waiting")) != "waiting"; row.add_child(join); join.pressed.connect(_join.bind(room))
	status_label.text = "未发现房间，将持续自动搜索…" if rooms.is_empty() else "已发现 %d 个可用房间" % rooms.size()

func _render_current_room(state: Dictionary) -> void:
	if state.is_empty(): current_room_panel.hide(); return
	current_room_panel.show()
	var humans := int(state.get("human_count", 1))
	current_room_title.text = "当前房间 %s    真人 %d/4    AI %d    状态：等待准备" % [str(state.get("room_number", "------")), humans, 4 - humans]
	for child in current_room_members.get_children(): child.queue_free()
	var member_by_seat := {}
	for member in state.get("members", []): member_by_seat[int(member.get("seat", -1))] = member
	for controller in state.get("controllers", []):
		var seat := int(controller.get("seat", -1)); var label := Label.new(); label.custom_minimum_size = Vector2(620, 54); label.add_theme_font_size_override("font_size", 30); label.add_theme_color_override("font_color", Color("0A4E8C"))
		if bool(controller.get("is_ai", false)): label.text = "%s    已准备 · AI" % str(controller.get("nickname", "电脑"))
		else:
			var member: Dictionary = member_by_seat.get(seat, {}); label.text = "%s%s    %s" % [str(controller.get("nickname", "玩家")), "（我）" if str(controller.get("player_id", "")) == runtime.session.local_player_id else "", "已准备" if bool(member.get("ready", false)) else "未准备"]
		current_room_members.add_child(label)
	var local_member := {}
	for member in state.get("members", []):
		if str(member.get("player_id", "")) == runtime.session.local_player_id: local_member = member
	_local_ready = bool(local_member.get("ready", false)); ready_button.text = "取消准备" if _local_ready else "我已准备"
	start_button.visible = false
	status_label.text = "房间已创建，等待其他玩家加入。" if runtime.session.is_host and humans == 1 else "玩家状态已更新。"

func _toggle_ready() -> void:
	runtime.set_ready(not _local_ready)

func _leave_room() -> void:
	runtime.leave_room(); current_room_panel.hide(); _refresh_rooms()

func _enter_network_table() -> void:
	if _navigating: return
	_navigating = true
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)

func _centered_panel(minimum: Vector2) -> Control:
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _glass_panel_style())
	center.add_child(panel)
	return panel

func _panel_content(panel: Control) -> VBoxContainer:
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 54); margin.add_theme_constant_override("margin_right", 54); margin.add_theme_constant_override("margin_top", 36); margin.add_theme_constant_override("margin_bottom", 42); panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 22); margin.add_child(box); return box

func _add_title(box: VBoxContainer, eyebrow_text: String, title_text: String) -> void:
	if not eyebrow_text.is_empty():
		var eyebrow := Label.new(); eyebrow.text = eyebrow_text; eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; eyebrow.add_theme_font_size_override("font_size", 24); eyebrow.add_theme_color_override("font_color", Color("376A94")); box.add_child(eyebrow)
	var title := Label.new(); title.text = title_text; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 46); title.add_theme_color_override("font_color", Color("083F72")); title.add_theme_color_override("font_shadow_color", Color(0.36, 0.67, 1.0, 0.30)); title.add_theme_constant_override("shadow_offset_x", 0); title.add_theme_constant_override("shadow_offset_y", 3); box.add_child(title)

func _large_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = text_value
	button.custom_minimum_size = Vector2(520, 246)
	button.clip_contents = true
	_apply_glass_choice_style(button, primary)
	_attach_button_light(button, primary)
	var label := Label.new()
	label.name = "ChoiceLabel"
	label.text = text_value
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color.WHITE if primary else Color("0054A6"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.12, 0.36, 0.20))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	button.add_child(label)
	return button

func _action_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 31)
	button.add_theme_color_override("font_color", Color.WHITE if primary else Color("0752A0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else Color("06488B"))
	button.add_theme_color_override("font_focus_color", Color.WHITE if primary else Color("06488B"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE if primary else Color("06488B"))
	var normal := _online_action_style(primary, false)
	var hover := _online_action_style(primary, true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", _online_action_style(false, false, true))
	return button

func _online_action_style(primary: bool, highlighted: bool, disabled: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if disabled:
		style.bg_color = Color(0.86, 0.91, 0.97, 0.58)
		style.border_color = Color(0.62, 0.76, 0.90, 0.44)
	elif primary:
		style.bg_color = Color("147EEB") if not highlighted else Color("2998FF")
		style.border_color = Color(0.70, 0.90, 1.0, 0.92)
	else:
		style.bg_color = Color(0.96, 0.98, 1.0, 0.82) if not highlighted else Color(1.0, 1.0, 1.0, 0.94)
		style.border_color = Color(0.66, 0.82, 0.96, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _glass_input_style(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.985, 1.0, 0.78)
	style.border_color = Color(0.22, 0.60, 0.94, 0.96) if focused else Color(0.64, 0.80, 0.94, 0.80)
	style.set_border_width_all(3 if focused else 2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	return style

func _online_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.975, 1.0, 0.62)
	style.border_color = Color(0.72, 0.86, 0.98, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style

func _box_style(fill: Color, border: Color, radius: int, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = fill; style.border_color = border; style.set_border_width_all(width); style.set_corner_radius_all(radius); style.content_margin_left = 20; style.content_margin_right = 20; style.content_margin_top = 14; style.content_margin_bottom = 14; return style

func _glass_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Pure transparency inside the panel: only its illuminated border and
	# exterior shadow distinguish the glass boundary from the background.
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 1.0, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	# A StyleBox shadow is a filled blurred rectangle. With a transparent panel
	# it remains visible through the interior and falsely darkens the glass.
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func _apply_glass_choice_style(button: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	# Fill, outline and rounded corners are drawn together by GlassLight.
	# Keeping this StyleBox fully transparent avoids doubled edges and clipped
	# shadow triangles at the four corners.
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(14)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.shadow_size = 0
	normal.shadow_offset = Vector2.ZERO
	var hover := normal.duplicate()
	var pressed := normal.duplicate()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("FFFFFF") if primary else Color("0752A0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else Color("06488B"))
	button.add_theme_color_override("font_focus_color", Color.WHITE if primary else Color("06488B"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE if primary else Color("06488B"))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.20, 0.52, 0.28))
	button.add_theme_font_override("font", BODY_FONT)

func _attach_button_light(button: Button, primary: bool) -> void:
	var light := ColorRect.new()
	light.name = "GlassLight"
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BUTTON_LIGHT_SHADER
	material.shader = shader
	material.set_shader_parameter("color_top", Color("2FADFF") if primary else Color("F7FAFF"))
	material.set_shader_parameter("color_bottom", Color("0057DE") if primary else Color("D5DCE8"))
	material.set_shader_parameter("light_color", Color(0.94, 0.98, 1.0, 0.96))
	material.set_shader_parameter("glass_mode", 1.0 if primary else 0.0)
	light.material = material
	button.add_child(light)

func _load_nickname() -> String:
	var config := ConfigFile.new(); if config.load("user://lan_profile.cfg") == OK: return str(config.get_value("profile", "nickname", "玩家"))
	return "iPhone" if OS.has_feature("ios") else ("Android" if OS.has_feature("android") else "玩家")

func _save_nickname() -> void:
	var clean := nickname_edit.text.strip_edges().left(4); if clean.is_empty(): clean = "玩家"; nickname_edit.text = clean
	var config := ConfigFile.new(); config.set_value("profile", "nickname", clean); config.save("user://lan_profile.cfg")
