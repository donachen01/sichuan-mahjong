extends Control

const TILE_VISUAL_SCENE := preload("res://scenes/ui/TileVisual2D.tscn")
const AI_TURN_MIN_DELAY_SEC := 0.8
const AI_REACTION_MIN_DELAY_SEC := 0.7
const AI_READY_POLL_SEC := 0.06

@onready var phase_value: Label = %PhaseValue
@onready var round_value: Label = %RoundValue
@onready var dealer_value: Label = %DealerValue
@onready var turn_value: Label = %TurnValue
@onready var wall_value: Label = %WallValue
@onready var room_info_value: Label = %RoomInfoValue
@onready var clock_value: Label = %ClockValue
@onready var top_wall_value: Label = %TopWallValue
@onready var center_wall_count: Label = %CenterWallCount
@onready var center_hint: Label = %CenterHint
@onready var ai_level_panel: Panel = %AILevelPanel
@onready var ai_level_option: OptionButton = %AILevelOption
@onready var top_ai_level_button: Button = %TopAILevelButton
@onready var ai_level_overlay: Control = %AILevelOverlay
@onready var ai_level_modal: Panel = %AILevelModal
@onready var ai_level_modal_hint: Label = %AILevelModalHint
@onready var ai_level_beginner_button: Button = %AILevelBeginnerButton
@onready var ai_level_intermediate_button: Button = %AILevelIntermediateButton
@onready var ai_level_advanced_button: Button = %AILevelAdvancedButton
@onready var ai_level_cheat_button: Button = %AILevelCheatButton
@onready var trainer_panel: Panel = %TrainerPanel
@onready var trainer_summary_value: Label = %TrainerSummaryValue
@onready var trainer_danger_value: Label = %TrainerDangerValue
@onready var trainer_fan_value: Label = %TrainerFanValue
@onready var debug_panel: Panel = get_node_or_null("DebugPanel")
@onready var center_wall_top: HBoxContainer = %CenterWallTop
@onready var center_wall_left: VBoxContainer = %CenterWallLeft
@onready var center_wall_right: VBoxContainer = %CenterWallRight
@onready var center_wall_bottom: HBoxContainer = %CenterWallBottom
@onready var top_right_info: Label = %TopRightInfo
@onready var top_right_dealer_tag: Label = %TopRightDealerTag
@onready var top_right_ding_que_tag: Label = %TopRightDingQueTag
@onready var discard_value: Label = %DiscardValue
@onready var recent_draw_value: Label = %RecentDrawValue
@onready var recent_discard_value: Label = %RecentDiscardValue
@onready var reaction_value: Label = %ReactionValue
@onready var debug_value: Label = %DebugValue
@onready var player_info_value: Label = %PlayerInfoValue
@onready var action_panel: Panel = %ActionPanel
@onready var action_status_value: Label = %ActionStatusValue
@onready var hu_button: Button = %HuButton
@onready var gang_button: Button = %GangButton
@onready var peng_button: Button = %PengButton
@onready var pass_button: Button = %PassButton
@onready var ding_que_panel: Panel = %DingQuePanel
@onready var ding_que_status_value: Label = %DingQueStatusValue
@onready var ding_que_button_hint: Label = %DingQueButtonHint
@onready var ding_que_tiao_button: Button = %DingQueTiaoButton
@onready var ding_que_tong_button: Button = %DingQueTongButton
@onready var ding_que_wan_button: Button = %DingQueWanButton
@onready var hand_tiles_container: Control = %HandTilesContainer
@onready var hand_status_value: Label = %HandStatusValue
@onready var left_hand_container: VBoxContainer = %LeftHandContainer
@onready var top_hand_container: HBoxContainer = %TopHandContainer
@onready var right_hand_container: VBoxContainer = %RightHandContainer
@onready var player_melds_value: Label = %PlayerMeldsValue
@onready var player_discard_value_legacy: Label = %PlayerDiscardValue
@onready var player_melds_container: HBoxContainer = %PlayerMeldsContainer
@onready var player_discard_grid: GridContainer = %PlayerDiscardGrid
@onready var player_won_badge: Label = %PlayerWonBadge
@onready var player_info_title: Label = %PlayerInfoTitle
@onready var player_score_value: Label = %PlayerScoreValue
@onready var player_dealer_tag: Label = %PlayerDealerTag
@onready var player_ding_que_tag: Label = %PlayerDingQueTag
@onready var left_melds_value: Label = %LeftMeldsValue
@onready var left_discard_value_legacy: Label = %LeftDiscardValue
@onready var left_melds_container: VBoxContainer = %LeftMeldsContainer
@onready var left_discard_grid: GridContainer = %LeftDiscardGrid
@onready var left_won_badge: Label = %LeftWonBadge
@onready var left_info_value: Label = %LeftInfoValue
@onready var left_dealer_tag: Label = %LeftDealerTag
@onready var left_ding_que_tag: Label = %LeftDingQueTag
@onready var top_melds_value: Label = %TopMeldsValue
@onready var top_discard_value_legacy: Label = %TopDiscardValue
@onready var top_melds_container: HBoxContainer = %TopMeldsContainer
@onready var top_discard_grid: GridContainer = %TopDiscardGrid
@onready var top_won_badge: Label = %TopWonBadge
@onready var top_seat_ding_que_tag: Label = %TopSeatDingQueTag
@onready var right_melds_value: Label = %RightMeldsValue
@onready var right_discard_value_legacy: Label = %RightDiscardValue
@onready var right_melds_container: VBoxContainer = %RightMeldsContainer
@onready var right_discard_grid: GridContainer = %RightDiscardGrid
@onready var right_won_badge: Label = %RightWonBadge
@onready var right_info_value: Label = %RightInfoValue
@onready var right_dealer_tag: Label = %RightDealerTag
@onready var right_ding_que_tag: Label = %RightDingQueTag
@onready var settlement_overlay: Control = %SettlementOverlay
@onready var settlement_panel: Panel = %SettlementPanel
@onready var settlement_value: Label = %SettlementValue
@onready var next_round_button: Button = %NextRoundButton
@onready var ai_turn_timer: Timer = %AITurnTimer
@onready var ai_reaction_timer: Timer = %AIReactionTimer
@onready var game_state: Node = get_node("/root/GameState")

var selected_tile_id: int = -1
var ding_que_badge_states: Dictionary = {}
var ai_level_selected_once: bool = false
var ai_turn_started_ms: int = 0
var ai_reaction_started_ms: int = 0

func _ready() -> void:
	_apply_static_table_styles()
	_apply_button_styles()
	if debug_panel != null:
		debug_panel.visible = false
	var menu_badge := get_node_or_null("TopBar/MenuBadge") as Control
	if menu_badge != null:
		menu_badge.visible = false
	var clock_panel := get_node_or_null("TopBar/ClockPanel") as Control
	if clock_panel != null:
		clock_panel.visible = false
	var rule_badge := get_node_or_null("TopBar/RuleBadge") as Control
	if rule_badge != null:
		rule_badge.visible = false
	var top_right_actions := get_node_or_null("TopBar/TopRightActions") as Control
	if top_right_actions != null:
		top_right_actions.visible = false
	if ai_level_panel != null:
		ai_level_panel.visible = false
	if hand_tiles_container.has_signal("tile_pressed"):
		hand_tiles_container.connect("tile_pressed", Callable(self, "_on_hand_tile_pressed"))
	game_state.state_changed.connect(_on_game_state_changed)
	ding_que_tiao_button.pressed.connect(_on_ding_que_button_pressed.bind("tiao"))
	ding_que_tong_button.pressed.connect(_on_ding_que_button_pressed.bind("tong"))
	ding_que_wan_button.pressed.connect(_on_ding_que_button_pressed.bind("wan"))
	hu_button.pressed.connect(_on_hu_button_pressed)
	gang_button.pressed.connect(_on_gang_button_pressed)
	peng_button.pressed.connect(_on_peng_button_pressed)
	pass_button.pressed.connect(_on_pass_button_pressed)
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	ai_turn_timer.timeout.connect(_on_ai_turn_timer_timeout)
	ai_reaction_timer.timeout.connect(_on_ai_reaction_timer_timeout)
	if ai_level_option.item_count == 0:
		ai_level_option.add_item("初级")
		ai_level_option.add_item("中级")
		ai_level_option.add_item("高级")
		ai_level_option.add_item("作弊级")
	ai_level_option.item_selected.connect(_on_ai_level_option_item_selected)
	top_ai_level_button.pressed.connect(_on_top_ai_level_button_pressed)
	ai_level_beginner_button.pressed.connect(_on_ai_level_choice_pressed.bind(0))
	ai_level_intermediate_button.pressed.connect(_on_ai_level_choice_pressed.bind(1))
	ai_level_advanced_button.pressed.connect(_on_ai_level_choice_pressed.bind(2))
	ai_level_cheat_button.pressed.connect(_on_ai_level_choice_pressed.bind(3))
	_open_ai_level_overlay(true)
	refresh_debug_view()


func _apply_static_table_styles() -> void:
	_style_panel(get_node_or_null("TopBar"), Color(0.07, 0.24, 0.17, 0.8), Color(0.96, 0.83, 0.45, 0.38), 18, 1, 3)
	_style_panel(get_node_or_null("CenterTable"), Color(0.07, 0.32, 0.22, 0.88), Color(0.97, 0.85, 0.44, 0.2), 34, 1, 3)
	_style_panel(get_node_or_null("PlayerArea"), Color(0.09, 0.23, 0.17, 0.12), Color(0.96, 0.82, 0.42, 0.06), 24, 1, 0)
	_style_panel(get_node_or_null("LeftOpponent"), Color(0.08, 0.2, 0.14, 0.08), Color(0.88, 0.76, 0.38, 0.04), 20, 1, 0)
	_style_panel(get_node_or_null("TopOpponent"), Color(0.08, 0.2, 0.14, 0.12), Color(0.88, 0.76, 0.38, 0.05), 20, 1, 0)
	_style_panel(get_node_or_null("RightOpponent"), Color(0.08, 0.2, 0.14, 0.08), Color(0.88, 0.76, 0.38, 0.04), 20, 1, 0)
	_style_panel(action_panel, Color(0.17, 0.14, 0.08, 0.94), Color(1.0, 0.84, 0.42, 0.75), 22)
	_style_panel(ding_que_panel, Color(0.09, 0.24, 0.17, 0.78), Color(0.95, 0.83, 0.47, 0.52), 28)
	_style_panel(settlement_panel, Color(0.12, 0.16, 0.11, 0.98), Color(1.0, 0.86, 0.48, 0.5), 28, 1, 8)
	_style_panel(get_node_or_null("TopBar/RoomInfoPanel"), Color(0.15, 0.2, 0.12, 0.76), Color(0.97, 0.84, 0.42, 0.28), 14, 1, 2)
	_style_panel(get_node_or_null("TopBar/ClockPanel"), Color(0.15, 0.2, 0.12, 0.76), Color(0.97, 0.84, 0.42, 0.28), 14, 1, 2)
	_style_panel(get_node_or_null("TopBar/RuleBadge"), Color(0.19, 0.16, 0.08, 0.76), Color(0.97, 0.84, 0.42, 0.3), 14, 1, 2)
	_style_panel(get_node_or_null("TopBar/TopWallBar"), Color(0.13, 0.2, 0.13, 0.72), Color(0.88, 0.98, 0.74, 0.18), 18, 1, 2)
	_style_panel(get_node_or_null("TopBar/TopRightSeat"), Color(0.12, 0.18, 0.13, 0.76), Color(0.97, 0.84, 0.42, 0.24), 16, 1, 2)
	_style_panel(get_node_or_null("TopBar/TopRightActions"), Color(0.11, 0.17, 0.12, 0.76), Color(0.97, 0.84, 0.42, 0.2), 16, 1, 2)
	_style_panel(ai_level_panel, Color(0.11, 0.18, 0.12, 0.84), Color(0.97, 0.84, 0.42, 0.24), 18, 1, 2)
	_style_panel(ai_level_modal, Color(0.1, 0.16, 0.12, 0.98), Color(1.0, 0.86, 0.48, 0.54), 34, 2, 12)
	_style_panel(trainer_panel, Color(0.08, 0.16, 0.11, 0.84), Color(0.97, 0.84, 0.42, 0.22), 24, 1, 2)
	_style_panel(get_node_or_null("CenterTable/CenterHud"), Color(0.05, 0.09, 0.06, 0.18), Color(0.99, 0.87, 0.48, 0.12), 18, 1, 0)
	_style_lane_panel(get_node_or_null("CenterTable/CenterWallTopRail"), Color(0.11, 0.26, 0.18, 0.22), Color(0.97, 0.85, 0.46, 0.08), 28)
	_style_lane_panel(get_node_or_null("CenterTable/CenterWallLeftRail"), Color(0.11, 0.26, 0.18, 0.18), Color(0.97, 0.85, 0.46, 0.06), 28)
	_style_lane_panel(get_node_or_null("CenterTable/CenterWallRightRail"), Color(0.11, 0.26, 0.18, 0.18), Color(0.97, 0.85, 0.46, 0.06), 28)
	_style_lane_panel(get_node_or_null("PlayerDiscardTray"), Color(0.08, 0.18, 0.13, 0.12), Color(1.0, 0.86, 0.48, 0.04), 24)
	_style_lane_panel(get_node_or_null("TopDiscardTray"), Color(0.08, 0.18, 0.13, 0.08), Color(1.0, 0.86, 0.48, 0.03), 24)
	_style_lane_panel(get_node_or_null("LeftDiscardTray"), Color(0.08, 0.18, 0.13, 0.06), Color(1.0, 0.86, 0.48, 0.02), 24)
	_style_lane_panel(get_node_or_null("RightDiscardTray"), Color(0.08, 0.18, 0.13, 0.06), Color(1.0, 0.86, 0.48, 0.02), 24)
	_style_lane_panel(get_node_or_null("TopHandRail"), Color(0.08, 0.2, 0.14, 0.08), Color(1.0, 0.86, 0.48, 0.02), 26)
	_style_lane_panel(get_node_or_null("LeftOpponent/LeftHandRail"), Color(0.08, 0.2, 0.14, 0.08), Color(1.0, 0.86, 0.48, 0.02), 26)
	_style_lane_panel(get_node_or_null("RightOpponent/RightHandRail"), Color(0.08, 0.2, 0.14, 0.08), Color(1.0, 0.86, 0.48, 0.02), 26)
	_style_avatar_frame(get_node_or_null("TopBar/TopRightSeat/TopRightAvatar/TopRightAvatarFrame"))
	_style_avatar_frame(get_node_or_null("LeftOpponent/LeftAvatar/LeftAvatarFrame"))
	_style_avatar_frame(get_node_or_null("RightOpponent/RightAvatar/RightAvatarFrame"))
	_apply_ding_que_badge_style(top_right_ding_que_tag, "", false)
	_apply_ding_que_badge_style(player_ding_que_tag, "", false)
	_apply_ding_que_badge_style(left_ding_que_tag, "", false)
	_apply_ding_que_badge_style(top_seat_ding_que_tag, "", true)
	_apply_ding_que_badge_style(right_ding_que_tag, "", false)
	_place_visual_layers()
	_tune_table_containers()


func _style_panel(panel: Panel, bg: Color, border: Color, radius: int, border_width: int = 2, shadow_size: int = 6) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)


func _style_avatar_frame(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	style.border_color = Color(1.0, 0.9, 0.72, 0.55)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)


func _style_lane_panel(panel: Panel, bg: Color, border: Color, radius: int) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.14)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)


func _apply_ding_que_badge_style(label: Label, suit: String, emphasized: bool) -> void:
	if label == null:
		return
	var fill_color := _ding_que_badge_fill(suit)
	var outline_color := fill_color.darkened(0.52)
	var current_alpha := label.self_modulate.a if label != null else 1.0
	label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.94, 1.0))
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.32))
	label.add_theme_constant_override("outline_size", 8 if emphasized else 6)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 32 if emphasized else 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.self_modulate = Color(1, 1, 1, current_alpha)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill_color, 0.92)
	style.border_color = Color(1.0, 0.96, 0.82, 0.88)
	style.set_border_width_all(3 if emphasized else 2)
	style.corner_radius_top_left = 18 if emphasized else 14
	style.corner_radius_top_right = 18 if emphasized else 14
	style.corner_radius_bottom_left = 18 if emphasized else 14
	style.corner_radius_bottom_right = 18 if emphasized else 14
	style.shadow_color = Color(fill_color.darkened(0.4), 0.34)
	style.shadow_size = 8 if emphasized else 5
	style.shadow_offset = Vector2(0, 2)
	label.add_theme_stylebox_override("normal", style)


func _ding_que_badge_fill(suit: String) -> Color:
	match suit:
		"tiao":
			return Color(0.13, 0.62, 0.25, 1.0)
		"tong":
			return Color(0.12, 0.44, 0.92, 1.0)
		"wan":
			return Color(0.86, 0.22, 0.18, 1.0)
		_:
			return Color(0.28, 0.38, 0.46, 0.9)


func _tune_table_containers() -> void:
	player_discard_grid.add_theme_constant_override("h_separation", 8)
	player_discard_grid.add_theme_constant_override("v_separation", 8)
	top_discard_grid.add_theme_constant_override("h_separation", 8)
	top_discard_grid.add_theme_constant_override("v_separation", 8)
	left_discard_grid.add_theme_constant_override("h_separation", 4)
	left_discard_grid.add_theme_constant_override("v_separation", 6)
	right_discard_grid.add_theme_constant_override("h_separation", 4)
	right_discard_grid.add_theme_constant_override("v_separation", 6)
	player_melds_container.add_theme_constant_override("separation", 12)
	top_melds_container.add_theme_constant_override("separation", 12)
	left_melds_container.add_theme_constant_override("separation", 10)
	right_melds_container.add_theme_constant_override("separation", 10)
	top_hand_container.add_theme_constant_override("separation", 2)
	left_hand_container.add_theme_constant_override("separation", 2)
	right_hand_container.add_theme_constant_override("separation", 2)
	center_wall_top.add_theme_constant_override("separation", 4)
	center_wall_left.add_theme_constant_override("separation", 3)
	center_wall_right.add_theme_constant_override("separation", 3)


func _place_visual_layers() -> void:
	_move_behind("PlayerDiscardTray", "PlayerDiscardGrid")
	_move_behind("TopDiscardTray", "TopDiscardGrid")
	_move_behind("LeftDiscardTray", "LeftOpponent")
	_move_behind("RightDiscardTray", "RightOpponent")
	_move_behind("TopHandRail", "TopOpponent")
	_move_behind("CenterTable/CenterWallTopRail", "CenterTable/CenterWallTop")
	_move_behind("CenterTable/CenterWallLeftRail", "CenterTable/CenterWallLeft")
	_move_behind("CenterTable/CenterWallRightRail", "CenterTable/CenterWallRight")
	_move_behind("LeftOpponent/LeftHandRail", "LeftOpponent/LeftHandContainer")
	_move_behind("RightOpponent/RightHandRail", "RightOpponent/RightHandContainer")


func _move_behind(node_path: String, reference_path: String) -> void:
	var node := get_node_or_null(node_path)
	var reference := get_node_or_null(reference_path)
	if node == null or reference == null:
		return
	var parent := node.get_parent()
	if parent == null or parent != reference.get_parent():
		return
	parent.move_child(node, reference.get_index())


func _apply_button_styles() -> void:
	_style_action_button(hu_button, Color(0.62, 0.18, 0.14, 0.96), Color(1.0, 0.82, 0.52, 0.86))
	_style_action_button(gang_button, Color(0.5, 0.28, 0.1, 0.96), Color(1.0, 0.83, 0.44, 0.84))
	_style_action_button(peng_button, Color(0.24, 0.47, 0.22, 0.96), Color(0.86, 0.98, 0.74, 0.82))
	_style_action_button(pass_button, Color(0.23, 0.25, 0.28, 0.94), Color(0.86, 0.9, 0.98, 0.72))
	_style_round_button(ding_que_tiao_button, Color(0.19, 0.78, 0.26, 0.98), Color(0.9, 1.0, 0.86, 0.92))
	_style_round_button(ding_que_tong_button, Color(0.15, 0.55, 0.96, 0.98), Color(0.85, 0.95, 1.0, 0.92))
	_style_round_button(ding_que_wan_button, Color(0.96, 0.22, 0.15, 0.98), Color(1.0, 0.92, 0.88, 0.92))
	ding_que_tiao_button.text = "条"
	ding_que_tong_button.text = "筒"
	ding_que_wan_button.text = "万"
	_style_action_button(top_ai_level_button, Color(0.14, 0.24, 0.18, 0.94), Color(1.0, 0.84, 0.42, 0.5))
	top_ai_level_button.add_theme_font_size_override("font_size", 22)
	top_ai_level_button.custom_minimum_size = Vector2(160, 48)
	_style_round_button(ai_level_beginner_button, Color(0.16, 0.55, 0.28, 0.98), Color(0.9, 1.0, 0.86, 0.92))
	_style_round_button(ai_level_intermediate_button, Color(0.19, 0.48, 0.88, 0.98), Color(0.86, 0.94, 1.0, 0.92))
	_style_round_button(ai_level_advanced_button, Color(0.84, 0.48, 0.12, 0.98), Color(1.0, 0.92, 0.82, 0.92))
	_style_round_button(ai_level_cheat_button, Color(0.82, 0.18, 0.16, 0.98), Color(1.0, 0.88, 0.84, 0.92))
	for button in [ai_level_beginner_button, ai_level_intermediate_button, ai_level_advanced_button, ai_level_cheat_button]:
		button.add_theme_font_size_override("font_size", 28)
		button.custom_minimum_size = Vector2(420, 140)
	var popup := ai_level_option.get_popup()
	if popup != null:
		popup.add_theme_font_size_override("font_size", 24)


func _style_action_button(button: Button, bg: Color, border: Color) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)

	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.08)
	pressed.shadow_size = 2

	var disabled_style := normal.duplicate()
	disabled_style.bg_color = Color(bg, 0.36)
	disabled_style.border_color = Color(border, 0.28)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(1, 0.98, 0.92, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.96, 0.88, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.58))
	button.add_theme_font_size_override("font_size", 28)
	button.custom_minimum_size = Vector2(92, 56)


func _style_round_button(button: Button, bg: Color, border: Color) -> void:
	if button == null:
		return
	_style_action_button(button, bg, border)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state_name) as StyleBoxFlat
		if style:
			style.corner_radius_top_left = 54
			style.corner_radius_top_right = 54
			style.corner_radius_bottom_left = 54
			style.corner_radius_bottom_right = 54
			style.shadow_size = 10
			style.shadow_color = Color(bg.r, bg.g, bg.b, 0.34)
	button.add_theme_font_size_override("font_size", 54)
	button.custom_minimum_size = Vector2(172, 172)


func refresh_debug_view() -> void:
	var snapshot: Dictionary = game_state.call("get_debug_snapshot")
	phase_value.text = _phase_to_text(snapshot["current_phase"])
	round_value.text = "Round %d" % snapshot["round_index"]
	dealer_value.text = _seat_name(int(snapshot["current_dealer_seat"]))
	turn_value.text = _seat_name(int(snapshot["current_turn_seat"]))
	wall_value.text = str(snapshot["wall_count"])
	room_info_value.text = "房号 488603\n第%d局" % snapshot["round_index"]
	clock_value.text = "19:%02d" % int(18 + snapshot["round_index"])
	top_wall_value.text = "牌墙剩余 %d" % snapshot["wall_count"]
	center_wall_count.text = "%d 张" % snapshot["wall_count"]
	center_hint.text = _center_hint_text(snapshot)
	_apply_center_hint_style(snapshot)
	discard_value.text = str(snapshot["discard_count"])
	recent_draw_value.text = snapshot["recent_draw_display"]
	recent_discard_value.text = snapshot["recent_discard_display"]
	reaction_value.text = snapshot["reaction_summary"]
	debug_value.text = snapshot["debug_last_message"]
	player_info_value.text = _build_player_summary(snapshot["players"])
	_refresh_seat_info(snapshot)
	_refresh_ding_que_panel(snapshot)
	_refresh_player_hand(snapshot)
	_refresh_opponent_hands(snapshot)
	_refresh_center_wall(snapshot)
	_refresh_meld_panels(snapshot)
	_refresh_discard_panels(snapshot)
	_refresh_winner_badges(snapshot)
	_refresh_action_panel(snapshot)
	_refresh_settlement_panel(snapshot)
	_refresh_training_panel(snapshot)
	_schedule_ai_turn_if_needed()


func _center_hint_text(snapshot: Dictionary) -> String:
	match int(snapshot["current_phase"]):
		GameState.RoundPhase.DING_QUE:
			return "规则切换中..."
		GameState.RoundPhase.DISCARD:
			return "请选择一张手牌打出"
		GameState.RoundPhase.REACTION:
			return "可响应当前弃牌"
		GameState.RoundPhase.SETTLEMENT:
			return "本局结算"
		_:
			return "等待开始"


func _apply_center_hint_style(snapshot: Dictionary) -> void:
	if int(snapshot["current_phase"]) == GameState.RoundPhase.DING_QUE:
		center_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52, 1.0))
		center_hint.add_theme_font_size_override("font_size", 62)
	else:
		center_hint.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88, 0.94))
		center_hint.add_theme_font_size_override("font_size", 34)


func _phase_to_text(phase: int) -> String:
	match phase:
		GameState.RoundPhase.BOOT:
			return "BOOT"
		GameState.RoundPhase.MAIN_MENU:
			return "MAIN_MENU"
		GameState.RoundPhase.TABLE_SETUP:
			return "TABLE_SETUP"
		GameState.RoundPhase.DING_QUE:
			return "DING_QUE"
		GameState.RoundPhase.DRAW:
			return "DRAW"
		GameState.RoundPhase.DISCARD:
			return "DISCARD"
		GameState.RoundPhase.REACTION:
			return "REACTION"
		GameState.RoundPhase.SETTLEMENT:
			return "SETTLEMENT"
		_:
			return "UNKNOWN"


func _build_player_summary(players: Array) -> String:
	var lines: Array[String] = []
	for player in players:
		var state_text := "已胡" if player.get("has_won", false) else "进行中"
		lines.append(
			"%s | %s | score=%d | hand=%d | ding_que=%s | sample=%s" % [
				_seat_name(int(player["seat"])),
				player["nickname"],
				state_text,
				player["score"],
				player["hand_count"],
				player["ding_que"] if player["ding_que"] != "" else "-",
				_build_hand_sample(player),
			]
		)
	return "\n".join(lines)


func _build_hand_sample(player: Dictionary) -> String:
	var hand_tiles: Array = player["hand_tiles"]
	var sample_count := mini(5, hand_tiles.size())
	if sample_count == 0:
		return "-"

	var parts: Array[String] = []
	for index in range(sample_count):
		parts.append(hand_tiles[index]["display_name"])
	return " ".join(parts)


func _refresh_ding_que_panel(snapshot: Dictionary) -> void:
	if ai_level_overlay.visible:
		ding_que_panel.visible = false
		return
	var current_phase: int = snapshot["current_phase"]
	var is_pending: bool = game_state.call("is_human_ding_que_pending", 0)
	var show_panel: bool = current_phase == GameState.RoundPhase.DING_QUE and is_pending
	ding_que_panel.visible = show_panel

	if not show_panel:
		return

	if snapshot["dealer_ding_que_deferred"]:
		ding_que_status_value.text = "当前玩法不使用定缺"
		ding_que_button_hint.text = "当前阶段无需定缺。"
	else:
		ding_que_status_value.text = "当前玩法不使用定缺"
		ding_que_button_hint.text = "当前阶段无需定缺"
	ding_que_status_value.add_theme_color_override("font_color", Color(0.98, 0.9, 0.64, 1.0))
	ding_que_status_value.add_theme_font_size_override("font_size", 62)
	var options: Array = game_state.call("get_human_ding_que_options", 0)
	ding_que_tiao_button.disabled = not options.has("tiao")
	ding_que_tong_button.disabled = not options.has("tong")
	ding_que_wan_button.disabled = not options.has("wan")


func _refresh_player_hand(snapshot: Dictionary) -> void:
	var hand_tiles: Array = game_state.call("get_player_hand_tiles", 0)
	var can_discard: bool = snapshot["human_can_discard"]
	var last_draw_tile_id: int = snapshot["human_last_draw_tile_id"]
	var player_state: Dictionary = _get_player_by_seat(snapshot["players"], 0)
	var ding_que_suit: String = str(player_state.get("ding_que", ""))
	var forced_discard_suit: String = _get_forced_discard_suit_from_player(player_state)
	var trainer_hint: Dictionary = snapshot.get("trainer_hint", {})

	if hand_tiles.is_empty():
		hand_status_value.text = "当前没有可显示手牌。"
		selected_tile_id = -1
		return

	if not _hand_contains_tile(hand_tiles, selected_tile_id):
		selected_tile_id = -1

	hand_status_value.text = "请选择一张手牌打出。" if can_discard else ""
	if can_discard and forced_discard_suit != "":
		hand_status_value.text = "你还有缺门牌，必须优先打%s。" % _ding_que_label_short(forced_discard_suit)
	if _get_player_by_seat(snapshot["players"], 0).get("has_won", false):
		hand_status_value.text = "你本局已胡，等待其余玩家继续完成血战流程。"
	if snapshot["current_phase"] == GameState.RoundPhase.SETTLEMENT:
		hand_status_value.text = "本局已进入结算占位阶段。"
	if snapshot["current_phase"] == GameState.RoundPhase.DING_QUE:
		hand_status_value.text = ""

	var display_hand_tiles := _build_display_hand_tiles(hand_tiles, last_draw_tile_id, ding_que_suit)
	hand_tiles_container.call(
		"configure_hand",
		display_hand_tiles,
		selected_tile_id,
		last_draw_tile_id,
		can_discard,
		{
			"recommended_tile_id": int(trainer_hint.get("recommended_tile_id", -1)),
			"danger_tile_ids": trainer_hint.get("danger_tile_ids", []).duplicate(),
		}
	)


func _sort_hand_tile(a: Dictionary, b: Dictionary) -> bool:
	var suit_order := {"tiao": 0, "tong": 1, "wan": 2}
	var a_suit := int(suit_order.get(str(a.get("suit", "")), 99))
	var b_suit := int(suit_order.get(str(b.get("suit", "")), 99))
	if a_suit != b_suit:
		return a_suit < b_suit
	var a_rank := int(a.get("rank", 0))
	var b_rank := int(b.get("rank", 0))
	if a_rank != b_rank:
		return a_rank < b_rank
	return int(a.get("id", 0)) < int(b.get("id", 0))


func _sort_hand_tile_with_ding_que(a: Dictionary, b: Dictionary, ding_que_suit: String) -> bool:
	var a_is_ding_que: bool = str(a.get("suit", "")) == ding_que_suit and ding_que_suit != ""
	var b_is_ding_que: bool = str(b.get("suit", "")) == ding_que_suit and ding_que_suit != ""
	if a_is_ding_que != b_is_ding_que:
		return not a_is_ding_que
	return _sort_hand_tile(a, b)


func _build_display_hand_tiles(hand_tiles: Array, last_draw_tile_id: int, ding_que_suit: String = "") -> Array:
	var sorted_hand_tiles := hand_tiles.duplicate(true)
	var draw_tile: Dictionary = {}
	if last_draw_tile_id != -1:
		for index in range(sorted_hand_tiles.size()):
			if int(sorted_hand_tiles[index].get("id", -1)) == last_draw_tile_id:
				draw_tile = sorted_hand_tiles[index]
				sorted_hand_tiles.remove_at(index)
				break
	var should_apply_ding_que_sort := ding_que_suit != "" and game_state != null and bool(game_state.rules.requires_ding_que_phase())
	if not should_apply_ding_que_sort:
		sorted_hand_tiles.sort_custom(_sort_hand_tile)
	else:
		sorted_hand_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _sort_hand_tile_with_ding_que(a, b, ding_que_suit)
		)
	if not draw_tile.is_empty():
		sorted_hand_tiles.append(draw_tile)
	return sorted_hand_tiles


func _refresh_seat_info(snapshot: Dictionary) -> void:
	var players: Array = snapshot["players"]
	var show_ding_que_badges: bool = _should_show_ding_que_badges(snapshot)
	_apply_seat_info(
		_get_player_by_seat(players, 0),
		player_info_title,
		player_score_value,
		player_dealer_tag,
		player_ding_que_tag,
		snapshot["current_dealer_seat"],
		show_ding_que_badges
	)
	_apply_seat_info(
		_get_player_by_seat(players, 1),
		left_info_value,
		left_info_value,
		left_dealer_tag,
		left_ding_que_tag,
		snapshot["current_dealer_seat"],
		show_ding_que_badges
	)
	_apply_seat_info(
		_get_player_by_seat(players, 2),
		top_right_info,
		top_right_info,
		top_right_dealer_tag,
		top_right_ding_que_tag,
		snapshot["current_dealer_seat"],
		show_ding_que_badges
	)
	_apply_seat_info(
		_get_player_by_seat(players, 3),
		right_info_value,
		right_info_value,
		right_dealer_tag,
		right_ding_que_tag,
		snapshot["current_dealer_seat"],
		show_ding_que_badges
	)
	var top_player: Dictionary = _get_player_by_seat(players, 2)
	top_seat_ding_que_tag.text = _ding_que_label(top_player.get("ding_que", ""))
	_apply_ding_que_badge_style(top_seat_ding_que_tag, str(top_player.get("ding_que", "")), true)
	_set_ding_que_badge_visible(top_seat_ding_que_tag, show_ding_que_badges and top_player.get("ding_que", "") != "")


func _refresh_opponent_hands(snapshot: Dictionary) -> void:
	var players: Array = snapshot["players"]
	_render_opponent_back_hand(left_hand_container, _get_player_by_seat(players, 1), 0.14, -90.0)
	_render_opponent_back_hand(top_hand_container, _get_player_by_seat(players, 2), 0.2, 0.0)
	_render_opponent_back_hand(right_hand_container, _get_player_by_seat(players, 3), 0.14, 90.0)


func _refresh_center_wall(snapshot: Dictionary) -> void:
	var wall_count: int = int(snapshot.get("wall_count", 0))
	var total_slots := 28
	var visible_tiles := clampi(int(ceil(float(wall_count) / 4.0)), 0, total_slots)
	var side_counts := _distribute_wall_tiles(visible_tiles)
	_render_wall_strip(center_wall_top, side_counts[0] * 2, 0.16, 0.0)
	_render_wall_strip(center_wall_right, side_counts[1] * 2, 0.11, 90.0)
	_render_wall_strip(center_wall_bottom, 0, 0.16, 0.0)
	_render_wall_strip(center_wall_left, side_counts[3] * 2, 0.11, -90.0)


func _apply_seat_info(player: Dictionary, title_label: Label, score_label: Label, dealer_tag: Label, ding_que_tag: Label, dealer_seat: int, show_ding_que_badges: bool) -> void:
	if player.is_empty():
		return
	if title_label == score_label:
		title_label.text = "%s\n%d分" % [player.get("nickname", "-"), int(player.get("score", 0))]
	else:
		title_label.text = str(player.get("nickname", "-"))
		score_label.text = "%d分" % int(player.get("score", 0))
	dealer_tag.visible = int(player.get("seat", -1)) == dealer_seat
	ding_que_tag.text = _ding_que_label(player.get("ding_que", ""))
	_apply_ding_que_badge_style(ding_que_tag, str(player.get("ding_que", "")), false)
	_set_ding_que_badge_visible(ding_que_tag, show_ding_que_badges and player.get("ding_que", "") != "")


func _should_show_ding_que_badges(snapshot: Dictionary) -> bool:
	var phase: int = int(snapshot.get("current_phase", GameState.RoundPhase.BOOT))
	return phase != GameState.RoundPhase.DING_QUE and phase != GameState.RoundPhase.TABLE_SETUP


func _set_ding_que_badge_visible(label: Label, should_show: bool) -> void:
	if label == null:
		return
	var key := str(label.get_path())
	var was_visible: bool = bool(ding_que_badge_states.get(key, false))
	if should_show:
		label.visible = true
		if not was_visible:
			label.self_modulate = Color(1, 1, 1, 0)
			var tween := create_tween()
			tween.tween_property(label, "self_modulate", Color(1, 1, 1, 1), 0.22)
		else:
			label.self_modulate = Color(1, 1, 1, 1)
	else:
		label.visible = false
		label.self_modulate = Color(1, 1, 1, 0)
	ding_que_badge_states[key] = should_show


func _ding_que_label(suit: String) -> String:
	match suit:
		"tiao":
			return "缺条"
		"tong":
			return "缺筒"
		"wan":
			return "缺万"
		_:
			return ""


func _ding_que_label_short(suit: String) -> String:
	match suit:
		"tiao":
			return "条"
		"tong":
			return "筒"
		"wan":
			return "万"
		_:
			return suit


func _get_forced_discard_suit_from_player(player: Dictionary) -> String:
	if game_state == null or game_state.rules == null or not bool(game_state.rules.requires_ding_que_phase()):
		return ""
	var ding_que_suit: String = str(player.get("ding_que", ""))
	if ding_que_suit == "":
		return ""
	for tile in player.get("hand_tiles", []):
		if str(tile.get("suit", "")) == ding_que_suit:
			return ding_que_suit
	return ""


func _refresh_meld_panels(snapshot: Dictionary) -> void:
	var players: Array = snapshot["players"]
	player_melds_value.visible = false
	left_melds_value.visible = false
	top_melds_value.visible = false
	right_melds_value.visible = false
	_render_melds_for_seat(player_melds_container, _get_player_by_seat(players, 0), 0, false)
	_render_melds_for_seat(left_melds_container, _get_player_by_seat(players, 1), 1, true)
	_render_melds_for_seat(top_melds_container, _get_player_by_seat(players, 2), 2, false)
	_render_melds_for_seat(right_melds_container, _get_player_by_seat(players, 3), 3, true)


func _get_player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if player["seat"] == seat:
			return player
	return {}


func _build_meld_summary(player: Dictionary, compact: bool) -> String:
	if player.is_empty():
		return "-"

	var melds: Array = player.get("melds", [])
	if melds.is_empty():
		return "暂无副露"

	var parts: Array[String] = []
	for meld in melds:
		parts.append(_format_single_meld(meld, compact))
	return "\n".join(parts) if compact else "  ".join(parts)


func _format_single_meld(meld: Dictionary, compact: bool) -> String:
	var meld_type: String = str(meld.get("type", "")).to_upper()
	var tiles: Array = meld.get("tiles", [])
	var tile_name := "?"
	if not tiles.is_empty():
		tile_name = tiles[0].get("display_name", "?")
	var from_seat_text := "Seat %s" % str(meld.get("from_seat", "?"))
	if compact:
		return "%s %s <- %s" % [meld_type, tile_name, from_seat_text]
	return "%s %s 来自 %s" % [meld_type, tile_name, from_seat_text]


func _refresh_discard_panels(snapshot: Dictionary) -> void:
	var players: Array = snapshot["players"]
	var recent_discard_tile_id: int = int(snapshot.get("recent_discard_tile_id", -1))
	player_discard_value_legacy.visible = false
	left_discard_value_legacy.visible = false
	top_discard_value_legacy.visible = false
	right_discard_value_legacy.visible = false
	_render_discards_for_grid(player_discard_grid, _get_player_by_seat(players, 0), 0.84, 0.0, recent_discard_tile_id)
	_render_discards_for_grid(left_discard_grid, _get_player_by_seat(players, 1), 0.7, -90.0, recent_discard_tile_id)
	_render_discards_for_grid(top_discard_grid, _get_player_by_seat(players, 2), 0.8, 0.0, recent_discard_tile_id)
	_render_discards_for_grid(right_discard_grid, _get_player_by_seat(players, 3), 0.7, 90.0, recent_discard_tile_id)


func _build_discard_grid_text(player: Dictionary) -> String:
	if player.is_empty():
		return "-"
	var discards: Array = player.get("discards", [])
	if discards.is_empty():
		return "暂无弃牌"
	var rows: Array[String] = []
	var current_row: Array[String] = []
	for tile in discards:
		current_row.append(tile.get("display_name", "?"))
		if current_row.size() == 6:
			rows.append(" ".join(current_row))
			current_row.clear()
	if not current_row.is_empty():
		rows.append(" ".join(current_row))
	return "\n".join(rows)


func _render_discards_for_grid(container: GridContainer, player: Dictionary, scale_factor: float, rotation_value: float, recent_discard_tile_id: int) -> void:
	_clear_container_children(container)
	if player.is_empty():
		return
	for tile in player.get("discards", []):
		var is_recent := int(tile.get("id", -1)) == recent_discard_tile_id
		var offset := Vector2(0.0, -10.0) if is_recent else Vector2.ZERO
		container.add_child(_create_tile_wrapper(tile, scale_factor, rotation_value, offset, false, is_recent))


func _render_melds_for_seat(container: Container, player: Dictionary, viewer_seat: int, compact_vertical: bool) -> void:
	_clear_container_children(container)
	if player.is_empty():
		return
	var melds: Array = player.get("melds", [])
	if melds.is_empty():
		return

	for meld in melds:
		var row: BoxContainer = VBoxContainer.new() if compact_vertical else HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if row is HBoxContainer:
			row.add_theme_constant_override("separation", 8)
		else:
			row.add_theme_constant_override("separation", 6)

		var badge := Label.new()
		badge.text = _meld_badge_text(meld, viewer_seat)
		badge.add_theme_font_size_override("font_size", 18 if compact_vertical else 22)
		badge.add_theme_color_override("font_color", Color(0.96, 0.92, 0.72, 1.0))
		row.add_child(badge)

		var tiles_box := HBoxContainer.new()
		tiles_box.add_theme_constant_override("separation", 4 if compact_vertical else 6)
		_render_meld_tiles(tiles_box, meld, viewer_seat, 0.52 if compact_vertical else 0.64, compact_vertical)
		row.add_child(tiles_box)
		container.add_child(row)


func _meld_badge_text(meld: Dictionary, viewer_seat: int) -> String:
	var meld_type: String = str(meld.get("type", "")).to_upper()
	var from_seat: int = int(meld.get("from_seat", viewer_seat))
	var direction := _direction_symbol_for_claim(viewer_seat, from_seat)
	if from_seat == viewer_seat:
		direction = "暗"
	return "%s %s" % [direction, meld_type]


func _direction_symbol_for_claim(viewer_seat: int, from_seat: int) -> String:
	var distance := (from_seat - viewer_seat + 4) % 4
	match distance:
		1:
			return "左"
		2:
			return "对"
		3:
			return "右"
		_:
			return "自"


func _create_tile_wrapper(tile: Dictionary, scale_factor: float, rotation_value: float = 0.0, offset: Vector2 = Vector2.ZERO, show_back_tile: bool = false, is_new_draw_tile: bool = false) -> Control:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile_visual: Control = TILE_VISUAL_SCENE.instantiate()
	tile_visual.call("configure", tile, scale_factor, show_back_tile, is_new_draw_tile, false)
	tile_visual.rotation_degrees = rotation_value
	var tile_size: Vector2 = tile_visual.custom_minimum_size
	var inset := Vector2(absf(offset.x), absf(offset.y))
	wrapper.custom_minimum_size = tile_size + inset
	var tile_position := Vector2(maxf(0.0, offset.x), maxf(0.0, -offset.y))
	tile_visual.position = tile_position
	wrapper.add_child(tile_visual)
	return wrapper


func _render_meld_tiles(container: HBoxContainer, meld: Dictionary, viewer_seat: int, scale_factor: float, compact_vertical: bool) -> void:
	var tiles: Array = meld.get("tiles", [])
	if tiles.size() == 4:
		_render_gang_tiles(container, meld, viewer_seat, scale_factor, compact_vertical)
		return
	var from_seat: int = int(meld.get("from_seat", viewer_seat))
	var claim_index := _claim_tile_index_for_meld(tiles.size(), viewer_seat, from_seat)
	var claim_rotation := 90.0 if from_seat != viewer_seat else 0.0
	var claim_offset := Vector2(0.0, 18.0 if compact_vertical else 22.0)
	for index in range(tiles.size()):
		var tile: Dictionary = tiles[index]
		if index == claim_index and from_seat != viewer_seat:
			container.add_child(_create_tile_wrapper(tile, scale_factor, claim_rotation, claim_offset))
		else:
			container.add_child(_create_tile_wrapper(tile, scale_factor, 0.0))


func _render_gang_tiles(container: HBoxContainer, meld: Dictionary, viewer_seat: int, scale_factor: float, compact_vertical: bool) -> void:
	var tiles: Array = meld.get("tiles", [])
	var from_seat: int = int(meld.get("from_seat", viewer_seat))
	var claim_index := _claim_tile_index_for_meld(3, viewer_seat, from_seat)
	var claim_rotation := 90.0 if from_seat != viewer_seat else 0.0
	var claim_offset := Vector2(0.0, 18.0 if compact_vertical else 22.0)
	for index in range(3):
		var base_tile: Dictionary = tiles[index]
		if index == claim_index and from_seat != viewer_seat:
			container.add_child(_create_tile_wrapper(base_tile, scale_factor, claim_rotation, claim_offset))
		else:
			container.add_child(_create_tile_wrapper(base_tile, scale_factor, 0.0))

	var stack_target_index := clampi(1 if claim_index == 0 else claim_index, 0, 2)
	var stacked_wrapper := _create_stacked_tile_wrapper(
		tiles[stack_target_index],
		tiles[3],
		scale_factor,
		compact_vertical
	)
	container.remove_child(container.get_child(stack_target_index))
	container.add_child(stacked_wrapper)
	container.move_child(stacked_wrapper, stack_target_index)


func _create_stacked_tile_wrapper(base_tile: Dictionary, top_tile: Dictionary, scale_factor: float, compact_vertical: bool) -> Control:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_button: Control = TILE_VISUAL_SCENE.instantiate()
	base_button.call("configure", base_tile, scale_factor, false, false, false)
	var top_button: Control = TILE_VISUAL_SCENE.instantiate()
	top_button.call("configure", top_tile, scale_factor * 0.84, false, false, false)
	var lift_y := -38.0 if compact_vertical else -44.0
	var top_x := (base_button.custom_minimum_size.x - top_button.custom_minimum_size.x) * 0.5
	base_button.position = Vector2(0.0, 18.0)
	top_button.position = Vector2(top_x, maxf(0.0, lift_y + 18.0))
	wrapper.custom_minimum_size = Vector2(
		base_button.custom_minimum_size.x,
		base_button.custom_minimum_size.y + 18.0
	)
	wrapper.add_child(base_button)
	wrapper.add_child(top_button)
	return wrapper


func _claim_tile_index_for_meld(tile_count: int, viewer_seat: int, from_seat: int) -> int:
	if tile_count <= 0:
		return 0
	if from_seat == viewer_seat:
		return clampi(tile_count - 1, 0, tile_count - 1)
	var distance := (from_seat - viewer_seat + 4) % 4
	match distance:
		1:
			return 0
		2:
			return mini(1, tile_count - 1)
		3:
			return tile_count - 1
		_:
			return tile_count - 1


func _create_back_tile(scale_factor: float, rotation_value: float = 0.0) -> Control:
	var tile_button: Control = TILE_VISUAL_SCENE.instantiate()
	tile_button.call("configure", {}, scale_factor, true, false, false)
	tile_button.rotation_degrees = rotation_value
	return tile_button


func _render_opponent_back_hand(container: Container, player: Dictionary, scale_factor: float, rotation_value: float) -> void:
	_clear_container_children(container)
	if player.is_empty():
		return

	var remaining_count: int = maxi(0, int(player.get("hand_count", 0)))
	for _index in range(remaining_count):
		container.add_child(_create_back_tile(scale_factor, rotation_value))


func _render_wall_strip(container: Container, tile_count: int, scale_factor: float, rotation_value: float) -> void:
	_clear_container_children(container)
	for _index in range(tile_count):
		container.add_child(_create_back_tile(scale_factor, rotation_value))


func _distribute_wall_tiles(total_tiles: int) -> Array:
	var capacities := [8, 6, 8, 6]
	var counts := [0, 0, 0, 0]
	var remaining := total_tiles
	var index := 0
	while remaining > 0:
		if counts[index] < capacities[index]:
			counts[index] += 1
			remaining -= 1
		index = (index + 1) % capacities.size()
		if counts == capacities:
			break
	return counts


func _clear_container_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _refresh_winner_badges(snapshot: Dictionary) -> void:
	var players: Array = snapshot["players"]
	_apply_winner_badge(player_won_badge, _get_player_by_seat(players, 0))
	_apply_winner_badge(left_won_badge, _get_player_by_seat(players, 1))
	_apply_winner_badge(top_won_badge, _get_player_by_seat(players, 2))
	_apply_winner_badge(right_won_badge, _get_player_by_seat(players, 3))


func _apply_winner_badge(label: Label, player: Dictionary) -> void:
	var has_won: bool = player.get("has_won", false)
	label.visible = has_won
	if not has_won:
		return
	label.text = "已和"


func _refresh_action_panel(snapshot: Dictionary) -> void:
	if ai_level_overlay.visible:
		action_panel.visible = false
		return
	var reaction_options: Dictionary = snapshot["human_reaction_options"]
	var can_self_hu: bool = snapshot.get("human_can_self_hu", false)
	var can_add_gang: bool = game_state.call("can_human_add_gang", 0)
	var can_an_gang: bool = game_state.call("can_human_an_gang", 0)
	var show_panel: bool = can_self_hu or can_add_gang or can_an_gang or reaction_options["can_hu"] or reaction_options["can_gang"] or reaction_options["can_peng"] or reaction_options["can_pass"]
	if snapshot["current_phase"] == GameState.RoundPhase.SETTLEMENT:
		show_panel = false
	action_panel.visible = show_panel

	if not show_panel:
		return

	if can_self_hu:
		action_status_value.text = "当前手牌已成和，可直接自摸胡。"
		hu_button.visible = true
		hu_button.disabled = false
		gang_button.visible = can_add_gang or can_an_gang
		gang_button.disabled = not (can_add_gang or can_an_gang)
		gang_button.text = "补杠" if can_add_gang else "暗杠"
		peng_button.visible = false
		pass_button.visible = false
		return

	if (can_add_gang or can_an_gang) and snapshot["current_phase"] == GameState.RoundPhase.DISCARD:
		if can_add_gang:
			action_status_value.text = "当前可执行补杠。若他家成和，将触发抢杠胡响应。"
			gang_button.text = "补杠"
		else:
			action_status_value.text = "当前可执行暗杠，并立即补牌继续。"
			gang_button.text = "暗杠"
		hu_button.visible = false
		gang_button.visible = true
		gang_button.disabled = false
		peng_button.visible = false
		pass_button.visible = false
		return

	var action_parts: Array[String] = []
	if reaction_options["can_hu"]:
		action_parts.append("胡")
	if reaction_options["can_gang"]:
		action_parts.append("杠")
	if reaction_options["can_peng"]:
		action_parts.append("碰")
	action_status_value.text = "当前弃牌可响应：%s。按优先级处理。" % ["/".join(action_parts)]
	hu_button.visible = reaction_options["can_hu"]
	hu_button.disabled = not reaction_options["can_hu"]
	gang_button.visible = reaction_options["can_gang"]
	gang_button.disabled = not reaction_options["can_gang"]
	peng_button.visible = reaction_options["can_peng"]
	peng_button.disabled = not reaction_options["can_peng"]
	pass_button.visible = reaction_options["can_pass"]
	pass_button.disabled = not reaction_options["can_pass"]


func _refresh_settlement_panel(snapshot: Dictionary) -> void:
	var show_panel: bool = snapshot["current_phase"] == GameState.RoundPhase.SETTLEMENT
	settlement_overlay.visible = show_panel
	settlement_panel.visible = show_panel
	if not show_panel:
		return

	move_child(settlement_overlay, get_child_count() - 1)
	var settlement_data: Dictionary = snapshot.get("settlement_data", {})
	settlement_value.text = _build_compact_settlement_text(settlement_data)
	next_round_button.visible = show_panel
	next_round_button.disabled = not show_panel
	top_ai_level_button.disabled = not show_panel and ai_level_selected_once


func _build_compact_settlement_text(settlement_data: Dictionary) -> String:
	var lines: Array[String] = []
	var end_reason: String = str(settlement_data.get("end_reason", ""))
	match end_reason:
		"draw_wall_empty":
			lines.append("本局流局")
		"battle_end":
			lines.append("本局结束")
		_:
			lines.append("本局结算")

	var win_events: Array = settlement_data.get("win_events", [])
	if win_events.is_empty():
		lines.append("胡牌：暂无")
	else:
		var event: Dictionary = win_events[0]
		var winner_seat: int = int(event.get("winner_seat", -1))
		var fan_detail: Dictionary = event.get("fan_detail", {})
		var fan_value := int(fan_detail.get("capped_fan", 0))
		var basic_score := 1 if fan_value <= 0 else int(pow(2.0, fan_value - 1))
		var fan_text := "%d番/%d分" % [fan_value, basic_score]
		var labels: Array = fan_detail.get("labels", [])
		lines.append("胡牌：%s | %s | %s" % [_seat_name(winner_seat), fan_text, "/".join(labels)])

	var score_changes: Dictionary = settlement_data.get("score_changes", {})
	if not score_changes.is_empty():
		lines.append("积分：%s" % str(game_state.call("_format_score_change_summary", score_changes)))

	var review_lines: Variant = game_state.call("_build_trainer_review_lines")
	if review_lines is Array and not review_lines.is_empty():
		lines.append("")
		lines.append("训练复盘")
		for line in review_lines.slice(1, mini(3, review_lines.size())):
			lines.append(str(line))

	return "\n".join(lines)


func _refresh_training_panel(snapshot: Dictionary) -> void:
	if ai_level_overlay.visible:
		trainer_panel.visible = false
		return
	var show_training: bool = (
		(snapshot["current_phase"] == GameState.RoundPhase.DISCARD and snapshot.get("human_can_discard", false))
		or snapshot["current_phase"] == GameState.RoundPhase.REACTION
	)
	if snapshot["current_phase"] == GameState.RoundPhase.SETTLEMENT:
		show_training = false
	trainer_panel.visible = show_training
	if not show_training:
		return

	var ai_level_index: int = int(snapshot.get("ai_level_index", 1))
	if ai_level_option.selected != ai_level_index:
		ai_level_option.select(ai_level_index)
	top_ai_level_button.text = "AI %s" % str(snapshot.get("ai_level_name", "中级"))

	var trainer_hint: Dictionary = snapshot.get("trainer_hint", {})
	if trainer_hint.is_empty():
		trainer_summary_value.text = "等待进入你的回合后显示建议。"
		trainer_danger_value.text = ""
		trainer_fan_value.text = ""
		return

	var recommended: Dictionary = trainer_hint.get("recommended", {})
	var summary_lines: Array[String] = []
	if snapshot["current_phase"] == GameState.RoundPhase.DISCARD and snapshot.get("human_can_discard", false):
		if not recommended.is_empty():
			summary_lines.append("建议先打：%s" % str(recommended.get("tile_name", "?")))
			if recommended.has("expected_net_score") or recommended.has("csharp_expected_net_score"):
				summary_lines.append("综合看这张更划算：大概能赚 %.2f，可能要冒 %.2f 的风险，算下来 %.2f" % [
					float(recommended.get("expected_win_gain", recommended.get("csharp_expected_win_gain", 0.0))),
					float(recommended.get("expected_deal_in_loss", recommended.get("csharp_expected_deal_in_loss", 0.0))),
					float(recommended.get("expected_net_score", recommended.get("csharp_expected_net_score", 0.0))),
				])
			var reasons: Array = recommended.get("reasons", [])
			if not reasons.is_empty():
				var readable_reasons: Array[String] = []
				for reason in reasons.slice(0, mini(3, reasons.size())):
					readable_reasons.append(_humanize_trainer_text(str(reason)))
				summary_lines.append("原因：%s" % "；".join(readable_reasons))
		var selected_option := _find_trainer_option_by_tile_id(trainer_hint.get("options", []), selected_tile_id)
		if not selected_option.is_empty() and selected_tile_id != int(recommended.get("tile", {}).get("id", -1)):
			var compare_parts: Array[String] = []
			compare_parts.append("如果改打 %s" % str(selected_option.get("tile_name", "?")))
			compare_parts.append(_plain_trainer_shanten_text(int(selected_option.get("shanten", 8))))
			compare_parts.append(_plain_trainer_ukeire_text(int(selected_option.get("ukeire", 0))))
			compare_parts.append(_plain_trainer_risk_text(str(selected_option.get("risk_label", "低危"))))
			if not selected_option.get("route_loss", []).is_empty():
				compare_parts.append("会把%s这条路打窄" % "、".join(selected_option.get("route_loss", [])))
			summary_lines.append("当前选中：%s" % "；".join(compare_parts))
		if trainer_hint.get("can_add_gang", false):
			summary_lines.append("现在可以补杠，先看看值不值，也要防别人抢杠。")
		elif trainer_hint.get("can_an_gang", false):
			summary_lines.append("现在可以暗杠，先看看补一张牌值不值。")
	else:
		summary_lines.append("当前不是你的主动出牌回合。")
	trainer_summary_value.text = "\n".join(summary_lines)

	var danger_lines: Array[String] = []
	for item in trainer_hint.get("danger_tiles", []):
		var line := "%s：%s" % [
			str(item.get("tile_name", "?")),
			_plain_trainer_risk_text(str(item.get("risk_label", "低危")))
		]
		var risk_reasons: Array = item.get("risk_reasons", [])
		if not risk_reasons.is_empty():
			line += "，%s" % _humanize_trainer_text(str(risk_reasons[0]))
		danger_lines.append(line)
	if danger_lines.is_empty():
		danger_lines.append("暂时没有特别危险的牌")
	trainer_danger_value.text = "尽量少打：%s" % " / ".join(danger_lines.slice(0, 2))

	var route_lines: Array[String] = []
	var current_routes: Array = trainer_hint.get("current_routes", [])
	if not current_routes.is_empty():
		route_lines.append("这手牌可以往这些方向做：%s" % "、".join(current_routes))
	if not recommended.is_empty() and not recommended.get("route_loss", []).is_empty():
		route_lines.append("如果打%s，会把这条路打掉：%s" % [
			str(recommended.get("tile_name", "?")),
			"、".join(recommended.get("route_loss", [])),
		])
	if route_lines.is_empty():
		route_lines.append("先顾摸牌顺不顺，也顾一下安全")
	trainer_fan_value.text = "；".join(route_lines.slice(0, 2))


func _plain_trainer_shanten_text(shanten: int) -> String:
	if shanten <= 0:
		return "已经听牌"
	return "离听牌还差%d步" % shanten


func _plain_trainer_ukeire_text(ukeire: int) -> String:
	return "后面能接上的牌大约%d张" % maxi(0, ukeire)


func _plain_trainer_risk_text(risk_label: String) -> String:
	match risk_label:
		"高危":
			return "危险比较大"
		"中危":
			return "有点危险"
		_:
			return "相对安全"


func _humanize_trainer_text(text: String) -> String:
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
		"宽叫": "更容易听牌",
	}
	for key in replacements.keys():
		result = result.replace(key, str(replacements[key]))
	return result


func _hand_contains_tile(hand_tiles: Array, tile_id: int) -> bool:
	for tile in hand_tiles:
		if tile["id"] == tile_id:
			return true
	return false


func _on_hand_tile_pressed(tile_id: int) -> void:
	if selected_tile_id == tile_id:
		var success: bool = game_state.call("discard_tile_by_id", 0, tile_id)
		if success:
			selected_tile_id = -1
		else:
			refresh_debug_view()
		return

	selected_tile_id = tile_id
	refresh_debug_view()


func _on_ding_que_button_pressed(suit: String) -> void:
	var success: bool = game_state.call("choose_ding_que", 0, suit)
	if not success:
		refresh_debug_view()


func _find_trainer_option_by_tile_id(options: Array, tile_id: int) -> Dictionary:
	for option in options:
		var tile: Dictionary = option.get("tile", {})
		if int(tile.get("id", -1)) == tile_id:
			return option
	return {}


func _on_peng_button_pressed() -> void:
	var success: bool = game_state.call("execute_human_peng", 0)
	if not success:
		refresh_debug_view()


func _on_gang_button_pressed() -> void:
	var success: bool = false
	if game_state.call("can_human_add_gang", 0):
		success = game_state.call("execute_human_add_gang", 0)
	elif game_state.call("can_human_an_gang", 0):
		success = game_state.call("execute_human_an_gang", 0)
	else:
		success = game_state.call("execute_human_gang", 0)
	if not success:
		refresh_debug_view()


func _on_hu_button_pressed() -> void:
	var success: bool = false
	if game_state.call("can_human_self_hu", 0):
		success = game_state.call("execute_human_self_hu", 0)
	else:
		success = game_state.call("execute_human_hu", 0)
	if not success:
		refresh_debug_view()


func _on_pass_button_pressed() -> void:
	var success: bool = game_state.call("pass_human_reaction", 0)
	if not success:
		refresh_debug_view()


func _on_game_state_changed(_snapshot: Dictionary) -> void:
	refresh_debug_view()


func _on_next_round_button_pressed() -> void:
	var success: bool = game_state.call("advance_to_next_round")
	if not success:
		refresh_debug_view()


func _schedule_ai_turn_if_needed() -> void:
	if ai_level_overlay.visible:
		ai_turn_timer.stop()
		ai_reaction_timer.stop()
		_clear_ai_timer_state("turn")
		_clear_ai_timer_state("reaction")
		return
	if game_state.call("is_ai_turn_ready"):
		game_state.call("prepare_ai_turn_decision")
		if ai_turn_timer.is_stopped():
			if ai_turn_started_ms <= 0:
				ai_turn_started_ms = Time.get_ticks_msec()
			_restart_timer(ai_turn_timer, _next_ai_wait_seconds(ai_turn_started_ms, AI_TURN_MIN_DELAY_SEC))
	else:
		ai_turn_timer.stop()
		_clear_ai_timer_state("turn")

	if game_state.call("is_ai_reaction_pending"):
		game_state.call("prepare_ai_reaction_decision")
		if ai_reaction_timer.is_stopped():
			if ai_reaction_started_ms <= 0:
				ai_reaction_started_ms = Time.get_ticks_msec()
			_restart_timer(ai_reaction_timer, _next_ai_wait_seconds(ai_reaction_started_ms, AI_REACTION_MIN_DELAY_SEC))
	else:
		ai_reaction_timer.stop()
		_clear_ai_timer_state("reaction")


func _on_ai_turn_timer_timeout() -> void:
	var ready: bool = bool(game_state.call("is_ai_turn_ready"))
	if not ready:
		_clear_ai_timer_state("turn")
		refresh_debug_view()
		return
	game_state.call("prepare_ai_turn_decision")
	if not _has_ai_wait_elapsed(ai_turn_started_ms, AI_TURN_MIN_DELAY_SEC):
		_restart_timer(ai_turn_timer, _next_ai_wait_seconds(ai_turn_started_ms, AI_TURN_MIN_DELAY_SEC))
		return
	var success: bool = bool(game_state.call("run_ai_turn"))
	if success:
		_clear_ai_timer_state("turn")
		return
	_restart_timer(ai_turn_timer, AI_READY_POLL_SEC)
	refresh_debug_view()


func _on_ai_reaction_timer_timeout() -> void:
	var pending: bool = bool(game_state.call("is_ai_reaction_pending"))
	if not pending:
		_clear_ai_timer_state("reaction")
		refresh_debug_view()
		return
	game_state.call("prepare_ai_reaction_decision")
	if not _has_ai_wait_elapsed(ai_reaction_started_ms, AI_REACTION_MIN_DELAY_SEC):
		_restart_timer(ai_reaction_timer, _next_ai_wait_seconds(ai_reaction_started_ms, AI_REACTION_MIN_DELAY_SEC))
		return
	var success: bool = bool(game_state.call("run_ai_reaction"))
	if success:
		_clear_ai_timer_state("reaction")
		return
	_restart_timer(ai_reaction_timer, AI_READY_POLL_SEC)
	refresh_debug_view()


func _restart_timer(timer: Timer, seconds: float) -> void:
	if timer == null:
		return
	timer.stop()
	timer.start(maxf(0.01, seconds))


func _next_ai_wait_seconds(started_ms: int, min_delay_sec: float) -> float:
	if started_ms <= 0:
		return min_delay_sec
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - started_ms)
	var remaining_ms := int(round(min_delay_sec * 1000.0)) - elapsed_ms
	if remaining_ms <= 0:
		return AI_READY_POLL_SEC
	return maxf(AI_READY_POLL_SEC, float(remaining_ms) / 1000.0)


func _has_ai_wait_elapsed(started_ms: int, min_delay_sec: float) -> bool:
	if started_ms <= 0:
		return true
	return Time.get_ticks_msec() - started_ms >= int(round(min_delay_sec * 1000.0))


func _clear_ai_timer_state(kind: String) -> void:
	if kind == "turn":
		ai_turn_started_ms = 0
	else:
		ai_reaction_started_ms = 0


func _on_ai_level_option_item_selected(index: int) -> void:
	var success: bool = game_state.call("set_ai_level", index)
	if not success:
		refresh_debug_view()


func _open_ai_level_overlay(is_required: bool) -> void:
	ai_level_overlay.visible = true
	ai_level_selected_once = not is_required and ai_level_selected_once
	top_ai_level_button.disabled = true
	ai_level_modal_hint.text = "首次进入牌局请先确定 AI 强度。结算后可在顶栏重新设定下一局难度。" if is_required else "请选择下一局的 AI 难度。当前牌桌会在你确认后按新难度继续。"


func _close_ai_level_overlay() -> void:
	ai_level_overlay.visible = false
	ai_level_selected_once = true
	refresh_debug_view()


func _on_ai_level_choice_pressed(index: int) -> void:
	var success: bool = game_state.call("set_ai_level", index)
	if not success:
		return
	if ai_level_option.selected != index:
		ai_level_option.select(index)
	_close_ai_level_overlay()


func _on_top_ai_level_button_pressed() -> void:
	if not ai_level_selected_once:
		_open_ai_level_overlay(true)
		return
	if settlement_panel.visible:
		_open_ai_level_overlay(false)


func _seat_name(seat: int) -> String:
	match seat:
		0:
			return "本家"
		1:
			return "上家"
		2:
			return "对家"
		3:
			return "下家"
		_:
			return "未知"
