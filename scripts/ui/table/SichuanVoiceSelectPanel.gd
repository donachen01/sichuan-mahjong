class_name SichuanVoiceSelectPanel
extends Control

signal voice_selected(voice_id: String)
signal closed

const CATALOG := preload("res://scripts/ui/table/SichuanVoiceCatalog.gd")
const BODY_FONT := preload("res://res/fonts/NotoSansCJKsc-Regular.otf")
const PANEL_SIZE := Vector2(980.0, 730.0)

var selected_voice_id := ""
var current_language := "mandarin"
var safe_margins := Vector4(24.0, 18.0, 24.0, 22.0)
var panel: Panel
var close_button: Button
var follow_button: Button
var filter_buttons: Dictionary = {}
var active_filter := "all"
var status_label: Label
var options_scroll: ScrollContainer
var options_content: Control
var option_rows: Dictionary = {}
var choice_buttons: Dictionary = {}
var preview_buttons: Dictionary = {}
var preview_player: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false
	resized.connect(_layout_panel)


func open(voice_id: String, language: String) -> void:
	selected_voice_id = voice_id if _has_voice(voice_id) else ""
	current_language = language
	active_filter = _language_for_voice(selected_voice_id) if selected_voice_id != "" else language
	visible = true
	_apply_filter()
	_refresh_selection()
	_layout_panel()
	call_deferred("_focus_selection")


func close() -> void:
	if not visible:
		return
	preview_player.stop()
	visible = false
	closed.emit()


func set_safe_margins(value: Vector4) -> void:
	if safe_margins == value:
		return
	safe_margins = value
	_layout_panel()


func handle_pointer_press(global_position: Vector2) -> bool:
	if not visible:
		return false
	if close_button.get_global_rect().has_point(global_position):
		close()
		return true
	if follow_button.get_global_rect().has_point(global_position):
		_select_voice("")
		return true
	for filter_key in filter_buttons:
		var filter_button := filter_buttons[filter_key] as Button
		if filter_button.get_global_rect().has_point(global_position):
			_set_filter(str(filter_key))
			return true
	if options_scroll.get_global_rect().has_point(global_position):
		for option in CATALOG.all_options():
			var voice_id := str(option.get("id", ""))
			var preview := preview_buttons.get(voice_id) as Button
			var choice := choice_buttons.get(voice_id) as Button
			if preview != null and preview.is_visible_in_tree() and preview.get_global_rect().has_point(global_position):
				_preview_voice(voice_id)
				return true
			if choice != null and choice.is_visible_in_tree() and choice.get_global_rect().has_point(global_position):
				_select_voice(voice_id)
				return true
	if not panel.get_global_rect().has_point(global_position):
		close()
		return true
	# Let the ScrollContainer own drags and taps on empty space.
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.08, 0.13, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	panel = Panel.new()
	panel.name = "VoiceGlassPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _glass_style(false))
	add_child(panel)

	var title := _label("选择我的声音", 42, Color("F8FCFF"))
	title.position = Vector2(44, 30)
	title.size = Vector2(700, 60)
	panel.add_child(title)
	close_button = _button("关闭", 26)
	close_button.position = Vector2(792, 26)
	close_button.size = Vector2(144, 66)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	var hint := _label("原语言按钮继续切换普通话／四川话；这里可单独指定你的声音。", 25, Color("D7E9F7"))
	hint.position = Vector2(46, 101)
	hint.size = Vector2(885, 45)
	panel.add_child(hint)

	follow_button = _button("跟随语言设置 · 默认男声", 29)
	follow_button.position = Vector2(44, 154)
	follow_button.size = Vector2(890, 78)
	follow_button.pressed.connect(_select_voice.bind(""))
	panel.add_child(follow_button)
	var filter_labels := {"all": "全部", "mandarin": "普通话", "sichuan": "四川话"}
	for index in range(3):
		var filter_key := str(["all", "mandarin", "sichuan"][index])
		var filter_button := _button(str(filter_labels[filter_key]), 27)
		filter_button.position = Vector2(44 + index * 300, 247)
		filter_button.size = Vector2(286, 62)
		filter_button.pressed.connect(_set_filter.bind(filter_key))
		panel.add_child(filter_button)
		filter_buttons[filter_key] = filter_button

	options_scroll = ScrollContainer.new()
	options_scroll.name = "VoiceOptionsScroll"
	options_scroll.position = Vector2(44, 324)
	options_scroll.size = Vector2(890, 276)
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(options_scroll)
	options_content = Control.new()
	options_content.custom_minimum_size = Vector2(800, CATALOG.all_options().size() * 88.0)
	options_scroll.add_child(options_content)
	var scroll_bar := options_scroll.get_v_scroll_bar()
	scroll_bar.custom_minimum_size.x = 74.0
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.55, 0.79, 1.0, 0.18)
	track.border_color = Color(1.0, 1.0, 1.0, 0.72)
	track.set_border_width_all(2)
	track.set_corner_radius_all(24)
	var thumb := track.duplicate() as StyleBoxFlat
	thumb.bg_color = Color(0.27, 0.64, 0.96, 0.85)
	scroll_bar.add_theme_stylebox_override("scroll", track)
	scroll_bar.add_theme_stylebox_override("grabber", thumb)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", thumb)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", thumb)

	var row_y := 0.0
	for option in CATALOG.all_options():
		var voice_id := str(option.get("id", ""))
		var language_text := "四川话" if str(option.get("language", "")) == "sichuan" else "普通话"
		var gender_text := "男声" if str(option.get("gender", "")) == "male" else "女声"
		var choice := _button("%s · %s · %s" % [language_text, gender_text, str(option.get("name", ""))], 29)
		choice.position = Vector2(0, row_y)
		choice.size = Vector2(620, 76)
		choice.pressed.connect(_select_voice.bind(voice_id))
		options_content.add_child(choice)
		choice_buttons[voice_id] = choice
		var preview := _button("▶ 试听", 26)
		preview.tooltip_text = "试听：五筒"
		preview.position = Vector2(636, row_y)
		preview.size = Vector2(160, 76)
		preview.pressed.connect(_preview_voice.bind(voice_id))
		options_content.add_child(preview)
		preview_buttons[voice_id] = preview
		option_rows[voice_id] = {"choice": choice, "preview": preview, "language": str(option.get("language", ""))}
		row_y += 88.0

	status_label = _label("", 24, Color("D7E9F7"))
	status_label.position = Vector2(48, 620)
	status_label.size = Vector2(875, 70)
	panel.add_child(status_label)

	preview_player = AudioStreamPlayer.new()
	preview_player.name = "VoicePreviewPlayer"
	preview_player.volume_db = 5.0
	add_child(preview_player)
	_layout_panel()


func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", BODY_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _button(value: String, font_size: int) -> Button:
	var result := Button.new()
	result.text = value
	result.focus_mode = Control.FOCUS_ALL
	result.alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_override("font", BODY_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("F8FCFF"))
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.add_theme_stylebox_override("normal", _glass_style(false))
	result.add_theme_stylebox_override("hover", _glass_style(true))
	result.add_theme_stylebox_override("pressed", _glass_style(true))
	result.add_theme_stylebox_override("focus", _glass_style(true))
	return result


func _glass_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.48, 0.82, 0.48) if active else Color(0.89, 0.95, 1.0, 0.10)
	style.border_color = Color(0.93, 0.98, 1.0, 0.92) if active else Color(0.93, 0.98, 1.0, 0.68)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.01, 0.10, 0.24, 0.33)
	style.shadow_size = 12
	style.shadow_offset = Vector2(3, 6)
	style.anti_aliasing = true
	return style


func _layout_panel() -> void:
	if panel == null:
		return
	var available := size - Vector2(safe_margins.x + safe_margins.z, safe_margins.y + safe_margins.w)
	var scale_value := minf(1.5, minf(available.x / PANEL_SIZE.x, available.y / PANEL_SIZE.y))
	panel.size = PANEL_SIZE
	panel.scale = Vector2.ONE * maxf(0.5, scale_value)
	panel.position = Vector2(safe_margins.x, safe_margins.y) + (available - PANEL_SIZE * panel.scale) * 0.5


func _select_voice(voice_id: String) -> void:
	if voice_id != "" and not _has_voice(voice_id):
		return
	selected_voice_id = voice_id
	_refresh_selection()
	voice_selected.emit(voice_id)


func _preview_voice(voice_id: String) -> void:
	for option in CATALOG.all_options():
		if str(option.get("id", "")) != voice_id:
			continue
		var path := "res://res/audio/%s/tong_5.wav" % str(option.get("directory", ""))
		if ResourceLoader.exists(path):
			preview_player.stop()
			preview_player.stream = load(path) as AudioStream
			preview_player.play()
		return


func _refresh_selection() -> void:
	follow_button.add_theme_stylebox_override("normal", _glass_style(selected_voice_id == ""))
	for filter_key in filter_buttons:
		(filter_buttons[filter_key] as Button).add_theme_stylebox_override("normal", _glass_style(str(filter_key) == active_filter))
	for voice_id_value in choice_buttons:
		var voice_id := str(voice_id_value)
		var choice := choice_buttons[voice_id] as Button
		choice.add_theme_stylebox_override("normal", _glass_style(selected_voice_id == voice_id))
	if selected_voice_id == "":
		status_label.text = "当前：跟随%s，使用默认男声" % ("四川话" if current_language == "sichuan" else "普通话")
	else:
		for option in CATALOG.all_options():
			if str(option.get("id", "")) == selected_voice_id:
				status_label.text = "当前：%s · %s" % ["四川话" if str(option.get("language", "")) == "sichuan" else "普通话", str(option.get("name", ""))]
				break


func _focus_selection() -> void:
	if not visible:
		return
	var target := follow_button if selected_voice_id == "" else choice_buttons.get(selected_voice_id) as Button
	if target != null and not target.visible:
		target = filter_buttons.get(active_filter) as Button
	if target != null:
		target.grab_focus()


func _set_filter(filter_key: String) -> void:
	if filter_key not in ["all", "mandarin", "sichuan"]:
		return
	active_filter = filter_key
	_apply_filter()
	_refresh_selection()


func _apply_filter() -> void:
	if options_content == null:
		return
	var row_y := 0.0
	for option in CATALOG.all_options():
		var voice_id := str(option.get("id", ""))
		var row: Dictionary = option_rows.get(voice_id, {})
		if row.is_empty():
			continue
		var shown := active_filter == "all" or str(row.get("language", "")) == active_filter
		for control in [row.get("choice"), row.get("preview")]:
			(control as Control).visible = shown
			if shown:
				(control as Control).position.y = row_y
		if shown:
			row_y += 88.0
	options_content.custom_minimum_size.y = row_y
	options_scroll.scroll_vertical = 0


func _language_for_voice(voice_id: String) -> String:
	for option in CATALOG.all_options():
		if str(option.get("id", "")) == voice_id:
			return str(option.get("language", "mandarin"))
	return current_language


func _has_voice(voice_id: String) -> bool:
	for option in CATALOG.all_options():
		if str(option.get("id", "")) == voice_id:
			return true
	return false
