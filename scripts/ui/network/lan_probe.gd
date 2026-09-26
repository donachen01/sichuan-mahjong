extends Control
const Session := preload("res://scripts/network/lan_room_session.gd")
const Discovery := preload("res://scripts/network/lan_room_discovery.gd")
var session: Node
var discovery: Node
var address: LineEdit
var port: SpinBox
var output: Label
var room_list: VBoxContainer
var member_list: VBoxContainer
var ready_button: Button
var start_button: Button
var advanced_box: VBoxContainer
var _lines: Array[String] = []
var _ready_state := false

func _ready() -> void:
	var runtime := get_node_or_null("/root/LanRuntime")
	if runtime != null:
		session = runtime.session
	else:
		session = Session.new()
		add_child(session)
	session.status_changed.connect(_status)
	session.room_state_changed.connect(_render_room_state)
	discovery = Discovery.new()
	add_child(discovery)
	discovery.rooms_changed.connect(_render_rooms)
	discovery.discovery_failed.connect(_status)
	DisplayServer.screen_set_keep_on(true)
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
	ui_theme.default_font_size = 24
	theme = ui_theme
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 48)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	_label(column, "四川麻将 · 局域网房间")
	_label(column, "房主创建后，同一 Wi-Fi 内的玩家会自动发现房间，点击即可加入。")
	_button(column, "创建房间（本机作为房主）", _create_room)
	_label(column, "同一 Wi-Fi 内可加入的房间")
	room_list = VBoxContainer.new()
	room_list.add_theme_constant_override("separation", 10)
	column.add_child(room_list)
	_render_rooms([])
	_button(column, "重新搜索房间", func():
		discovery.start_browsing()
		_status("正在自动搜索同一 Wi-Fi 内的房间…"))
	_label(column, "当前房间")
	member_list = VBoxContainer.new()
	member_list.add_theme_constant_override("separation", 8)
	column.add_child(member_list)
	_render_room_state({})
	ready_button = Button.new()
	ready_button.text = "我已准备"
	ready_button.custom_minimum_size.y = 56
	ready_button.disabled = true
	ready_button.pressed.connect(_toggle_ready)
	column.add_child(ready_button)
	start_button = Button.new()
	start_button.text = "开始游戏"
	start_button.custom_minimum_size.y = 56
	start_button.disabled = true
	start_button.visible = false
	start_button.pressed.connect(_start_match)
	column.add_child(start_button)
	var advanced_toggle := CheckButton.new()
	advanced_toggle.text = "高级排障：地址直连"
	column.add_child(advanced_toggle)
	advanced_box = VBoxContainer.new()
	advanced_box.visible = false
	column.add_child(advanced_box)
	advanced_toggle.toggled.connect(func(enabled: bool): advanced_box.visible = enabled)
	address = LineEdit.new()
	address.placeholder_text = "仅排障使用的房主 IP"
	address.custom_minimum_size.y = 56
	advanced_box.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 27865
	advanced_box.add_child(port)
	_button(advanced_box, "按地址加入（排障）", func(): session.join(address.text, int(port.value), "玩家"))
	_button(column, "断开 / 重新开始", func():
		session.reset()
		_ready_state = false
		_render_room_state({})
		_status("已断开，可重新建房或加入"))
	output = _label(column, "等待操作")
	if get_node_or_null("/root/GameState") != null:
		_button(column, "返回单机麻将", func():
			session.reset()
			get_tree().change_scene_to_file("res://scenes/table/MainSceneV2.tscn"))
	# Explicit development arguments allow repeatable device-to-device probes.
	for arg in OS.get_cmdline_user_args():
		if arg == "--probe-host":
			_create_room()
		elif arg.begins_with("--probe-join="):
			session.join(arg.trim_prefix("--probe-join="))
	if not OS.get_cmdline_user_args().has("--probe-host"):
		discovery.start_browsing()
		_status("正在自动搜索同一 Wi-Fi 内的房间…")

func _create_room() -> void:
	discovery.stop()
	var result: Error = session.host("房主", 27865)
	if result != OK:
		return
	var room_id := "%d-%d" % [Time.get_unix_time_from_system(), randi()]
	if discovery.start_host(room_id, "四川麻将房间", 27865) == OK:
		_status("房间已创建，其他玩家可在房间列表中直接加入")

func _render_rooms(rooms: Array[Dictionary]) -> void:
	if room_list == null:
		return
	for child in room_list.get_children():
		child.queue_free()
	if rooms.is_empty():
		_label(room_list, "正在搜索…暂未发现房间")
		return
	for room in rooms:
		var title := "%s  ·  点击加入" % str(room.get("name", "四川麻将房间"))
		_button(room_list, title, func():
			discovery.stop()
			session.join(str(room.address), int(room.port), "玩家"))

func _render_room_state(state: Dictionary) -> void:
	if member_list == null:
		return
	for child in member_list.get_children():
		child.queue_free()
	var members: Array = state.get("members", [])
	if members.is_empty():
		_label(member_list, "尚未加入房间")
		if ready_button != null: ready_button.disabled = true
		if start_button != null: start_button.visible = false
		return
	for member in members:
		var seat := int(member.get("seat", -1)) + 1
		var nickname := str(member.get("nickname", "玩家"))
		var ready_text := "已准备" if bool(member.get("ready", false)) else "未准备"
		var own := "（我）" if int(member.get("seat", -1)) == session.local_seat else ""
		_label(member_list, "座位 %d  %s%s  %s" % [seat, nickname, own, ready_text])
	if ready_button != null: ready_button.disabled = session.local_seat < 0
	if start_button != null:
		start_button.visible = session.is_host
		start_button.disabled = not session.can_start_match()

func _toggle_ready() -> void:
	_ready_state = not _ready_state
	if not session.set_ready(_ready_state):
		_ready_state = not _ready_state
		_status("准备状态更新失败")
		return
	ready_button.text = "取消准备" if _ready_state else "我已准备"

func _start_match() -> void:
	var runtime := get_node_or_null("/root/LanRuntime")
	if runtime == null or not bool(runtime.call("begin_match")):
		_status("开始游戏失败，请检查人数和准备状态")

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 56
	button.pressed.connect(action)
	parent.add_child(button)

func _status(message: String) -> void:
	print("LAN_PROBE ", message)
	_lines.append(message)
	if _lines.size() > 8: _lines.pop_front()
	if output != null: output.text = "\n".join(_lines)
