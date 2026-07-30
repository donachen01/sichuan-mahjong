extends Node2D

const PLAYER_UI_SCENE := preload("res://scenes/ui/PlayerUI.tscn")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")
const TILE_SCENE := preload("res://scenes/ui/MahjongTile.tscn")
const DICE_FACE_SCRIPT := preload("res://scripts/ui/DiceFace.gd")
const WALL_COUNT_DISC_SCRIPT := preload("res://scripts/ui/WallCountDisc.gd")
const TABLE_MATERIAL_OVERLAY_SCRIPT := preload("res://scripts/ui/TableMaterialOverlay.gd")
const CIRCULAR_ACTION_BUTTON_OVERLAY_SCRIPT := preload("res://scripts/ui/CircularActionButtonOverlay.gd")
const SEAT_HUD_SCENE := preload("res://scenes/ui/table/SeatHUD.tscn")
const TABLE_UTILITY_BAR_SCENE := preload("res://scenes/ui/table/TableUtilityBar.tscn")
const CENTER_TURN_INDICATOR_SCENE := preload("res://scenes/ui/table/CenterTurnIndicator.tscn")
const TABLE_DISCARD_LAYER_SCRIPT := preload("res://scripts/ui/table/TableDiscardLayer.gd")
const TABLE_ACTION_BAR_SCENE := preload("res://scenes/ui/table/TableActionBar.tscn")
const TABLE_PRESENTATION_DIRECTOR_SCRIPT := preload("res://scripts/ui/presentation/TablePresentationDirector.gd")
const AI_ASSISTANT_SCENE := preload("res://scenes/ui/AIAssistant.tscn")
const TABLE_STAGE_3D_SCRIPT := preload("res://scripts/ui/3d/SichuanTableStage3D.gd")
const SICHUAN_TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const SICHUAN_TABLE_METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const SETTLEMENT_OVERLAY_SCENE := preload("res://scenes/ui/table/SettlementOverlay.tscn")
const DING_QUE_TIAO_SHELL := preload("res://res/art/ui/table_v2/ding_que_tiao.png")
const DING_QUE_TONG_SHELL := preload("res://res/art/ui/table_v2/ding_que_tong.png")
const DING_QUE_WAN_SHELL := preload("res://res/art/ui/table_v2/ding_que_wan.png")
const SETTLEMENT_PANEL_SHELL := preload("res://res/art/ui/table_v2/settlement_panel_9slice.png")
const AUDIO_SFX_DIR := "res://res/audio/sfx"
const AUDIO_TTS_DIR := "res://res/audio/tts"
const SETTLEMENT_HOLD_SECONDS := 1.0
const SETTLEMENT_REDUCED_HOLD_SECONDS := 0.18
const DICE_ROLL_AUDIO_PATH := "res://res/audio/sfx/mahjong_dice_roll.wav"
const SYSTEM_DRAW_AUDIO_PATH := "res://res/audio/sfx/system_draw.mp3"
const SYSTEM_DRAW_AUDIO_SECONDS := 1.0
const HUMAN_DRAW_ACTION_DELAY := 1.0
const SYSTEM_DRAW_ACTION_DELAY := 0.96
const AI_ACTION_DELAY_MIN_SEC := 0.5
const AI_ACTION_DELAY_MAX_SEC := 3.0
const AI_READY_POLL_SEC := 0.03
const AI_WATCHDOG_POLL_SEC := 0.12
const DIAGNOSTIC_EXPORT_UI_ENABLED := false
const DEBUG_DIAGNOSTIC_EXPORT_UI_ENABLED := false
const RELEASE_USER_BUILD_UI := true
const OPENING_ROLL_TICK := 0.04
const OPENING_ROLL_TICKS := 10
const BOARD_TARGET_RATIO := 1065.0 / 772.0
const TABLE_SCREEN_MARGIN := 6
const SELF_HAND_BOTTOM_HEIGHT := 232
const DESIGN_BASE_SIZE := Vector2(2048.0, 1152.0)
const TOTAL_MAHJONG_TILE_COUNT := 108
const MAX_PLAYER_HAND_BEFORE_DRAW := 13
const PLAYER_COUNT := 4
const MAX_TABLE_DISCARD_COUNT := TOTAL_MAHJONG_TILE_COUNT - MAX_PLAYER_HAND_BEFORE_DRAW * PLAYER_COUNT
const MAX_DISCARD_PER_SEAT := MAX_TABLE_DISCARD_COUNT / PLAYER_COUNT
const CENTER_DISCARD_TOP_COLUMNS := 7
const CENTER_DISCARD_BOTTOM_COLUMNS := 7
const CENTER_DISCARD_SIDE_COLUMNS := 5
const CENTER_DISCARD_LEFT_COLUMNS := CENTER_DISCARD_SIDE_COLUMNS
const CENTER_DISCARD_TOP_LIMIT := MAX_DISCARD_PER_SEAT
const CENTER_DISCARD_BOTTOM_LIMIT := MAX_DISCARD_PER_SEAT
const CENTER_DISCARD_SIDE_LIMIT := MAX_DISCARD_PER_SEAT
const CENTER_DISCARD_SEPARATION := 9.0
const CENTER_DISCARD_TOP_SCALE := 0.78
const CENTER_DISCARD_BOTTOM_SCALE := 0.78
const CENTER_DISCARD_SIDE_SCALE := 0.78
const CENTER_DISCARD_FIT_PADDING := 4.0
const CENTER_DISCARD_TILE_VISUAL_EXTRA := Vector2(6.0, 13.0)
const CENTER_DISCARD_RIGHT_INSET := 18.0
const CENTER_DISCARD_LEFT_VERTICAL_OFFSET := -16.0
const CENTER_DISCARD_LEFT_EXTRA_HEIGHT := 28.0
const CENTER_DISCARD_LEFT_EXTRA_WIDTH := 28.0
const CENTER_DISCARD_SIDE_EDGE_MARGIN := 0.0
const CENTER_DISCARD_SIDE_EXTRA_WIDTH := 32.0
const CENTER_DISCARD_SIDE_INSET_RATIO := 0.28
const CENTER_WALL_DISC_SIZE := Vector2(236.0, 236.0)
const CENTER_WALL_COUNT_FONT_SIZE := 64
const CENTER_WALL_COUNT_LABEL_SIZE := Vector2(132.0, 88.0)
const CENTER_WALL_WIND_FONT_SIZE := 34
const TOP_EXIT_BUTTON_SIZE := Vector2(68.0, 68.0)
const TOP_EXIT_BUTTON_MARGIN := Vector2(20.0, 18.0)
const AI_DRAWER_ENTRY_SIZE := Vector2(78.0, 78.0)
const AI_DRAWER_ITEM_SIZE := Vector2(178.0, 58.0)
const AI_DRAWER_MARGIN := Vector2(18.0, 20.0)
const UI_PREFS_PATH := "user://ui_prefs.cfg"
const UI_PREFS_SECTION := "main_scene_v2"
const UI_PREFS_KEY_AI_HELPER := "ai_helper_enabled"
const UI_PREFS_KEY_OPPONENT_HANDS := "opponent_hands_enabled"
const UI_PREFS_KEY_AI_GLASS_OPACITY := "ai_glass_opacity"
const UI_PREFS_KEY_AI_GLASS_OPACITY_LEGACY := "ai_glass_opacity_index"
const UI_PREFS_KEY_AI_DRAWER_POSITION := "ai_drawer_position_normalized"
const UI_PREFS_KEY_AI_DRAWER_POSITIONED := "ai_drawer_positioned"
const UI_PREFS_KEY_AI_DRAWER_LAYOUT_VERSION := "ai_drawer_layout_version"
const AI_DRAWER_LAYOUT_VERSION := 2
const TILE_VISUAL_BASE_SIZE := Vector2(92.0, 140.0)
const SETTLEMENT_PANEL_SCREEN_RATIO := Vector2(0.985, 0.965)
const SETTLEMENT_PANEL_MAX_SIZE := Vector2(4096.0, 4096.0)
const SETTLEMENT_PANEL_MIN_SIZE := Vector2(1320.0, 760.0)
const SETTLEMENT_TILE_SCALE := 0.47
const SETTLEMENT_MELD_TILE_SCALE := 0.39
const SETTLEMENT_WIN_TILE_SCALE := 0.50
const MATTE_FELT_BG := Color("052820")
const MATTE_FELT_BASE := Color("062C28")
const MATTE_FELT_PANEL := Color("0B3F34")
const MATTE_FELT_DEEP := Color(0.012, 0.094, 0.082, 0.98)
const WOOD_DARK := Color("15110E")
const WOOD_MID := Color("2A2018")
const WOOD_EDGE := Color("7A522C")
const GOLD_SOFT := Color("B99655")
const IVORY_SOFT := Color("F4E9C9")
const TABLE_BLUE_DEEP := Color("101A2E")
const TABLE_BLUE_PANEL := Color("172744")
const TABLE_BLUE_CARD := Color("21385F")
const TABLE_BLUE_ACTIVE := Color("2E4D7A")
const TABLE_STEEL_EDGE := Color("5F789D")
const SETTLEMENT_INK_DEEP := Color("061E19")
const SETTLEMENT_JADE_PANEL := Color("102F29")
const SETTLEMENT_JADE_CARD := Color("17483C")
const SETTLEMENT_JADE_ACTIVE := Color("1B6D58")
const ACTION_PRIMARY_CENTER := Color("FFF176")
const ACTION_PRIMARY_EDGE := Color("FF8F00")
const ACTION_PRIMARY_OUTLINE := Color("FFD54F")
const ACTION_SECONDARY_CENTER := Color("A5D6A7")
const ACTION_SECONDARY_EDGE := Color("2E7D32")
const ACTION_SECONDARY_OUTLINE := Color("66BB6A")
const ACTION_BUTTON_TEXT := Color(1.0, 1.0, 1.0, 1.0)
const ACTION_BUTTON_TEXT_DISABLED := Color(1.0, 1.0, 1.0, 0.44)
const ACTION_BUTTON_GRID_GAP := 24
const ACTION_PANEL_PADDING := 6
const ACTION_PRIMARY_SIZE := Vector2(236.0, 236.0)
const ACTION_SECONDARY_SIZE := Vector2(204.0, 204.0)
const ACTION_PRIMARY_FONT_SIZE := 172
const ACTION_SECONDARY_FONT_SIZE := 148
const UTILITY_CROSS_INPUT_DEDUP_WINDOW_MSEC := 5000
const ACTION_CROSS_INPUT_DEDUP_WINDOW_MSEC := 5000
const TABLE_3D_PROJECT_SETTING := "ui/mahjong_3d_enabled"
const TABLE_3D_CROSS_INPUT_DEDUP_WINDOW_MSEC := 5000
const EMULATED_MOUSE_EVENT_WINDOW_MSEC := 1200
const EMULATED_MOUSE_POSITION_TOLERANCE := 28.0
const AI_PRESET_ORDER := ["intermediate", "bone_ash", "hell"]
const AI_PRESET_LABELS := {
	"intermediate": "中级",
	"bone_ash": "骨灰",
	"hell": "地狱",
}

enum SeatDock {
	SELF,
	TOP,
	LEFT,
	RIGHT,
}

@onready var game_manager: GameManager = %GameManager
@onready var root_ui: Control = $UILayer/RootUI
@onready var background_rect: ColorRect = $UILayer/RootUI/Background
@onready var safe_area: MarginContainer = $UILayer/RootUI/SafeArea
@onready var room_card: Panel = %RoomCard
@onready var room_label: Label = %RoomLabel
@onready var info_card: Panel = %InfoCard
@onready var center_info: Label = %CenterInfo
@onready var top_bar_button: Button = %TopBarButton
@onready var top_ai_tuning_button: Button = %TopAITuningButton
@onready var top_ai_helper_button: Button = %TopAIHelperButton
@onready var top_opponent_hand_button: Button = %TopOpponentHandButton
@onready var top_settlement_info_button: Button = %TopSettlementInfoButton
@onready var top_next_round_button: Button = %TopNextRoundButton
@onready var top_exit_button: Button = %TopExitButton
@onready var player_self_host: Control = %SelfInfoHost
@onready var player_top_host: Control = %PlayerTopHost
@onready var player_left_host: Control = %PlayerLeftHost
@onready var player_right_host: Control = %PlayerRightHost
@onready var center_card: Panel = %CenterCard
@onready var center_status: Label = %CenterStatus
@onready var center_stats_card: Panel = %CenterStatsCard
@onready var center_dealer_label: Label = %CenterDealerLabel
@onready var center_wall_label: Label = %CenterWallLabel
@onready var center_turn_label: Label = %CenterTurnLabel
@onready var center_reaction_label: Label = %CenterReactionLabel
@onready var center_hint_card: Panel = %CenterHintCard
@onready var center_hint_box: Label = %CenterHintBox
@onready var board_area: Panel = %BoardArea
@onready var board_aspect: AspectRatioContainer = %BoardAspect
@onready var board_square: Panel = %BoardSquare
@onready var self_section: Panel = %SelfSection
@onready var board_core: Panel = %BoardCore
@onready var board_core_label: Label = %BoardCoreLabel
@onready var board_top_lane: HBoxContainer = %BoardTopLane
@onready var board_left_lane: VBoxContainer = %BoardLeftLane
@onready var board_right_lane: VBoxContainer = %BoardRightLane
@onready var board_bottom_lane: HBoxContainer = %BoardBottomLane
@onready var center_meld_card: Panel = %CenterMeldCard
@onready var center_discard_card: Panel = %CenterDiscardCard
@onready var self_meld_summary: Label = %SelfMeldSummary
@onready var left_meld_summary: Label = %LeftMeldSummary
@onready var top_meld_summary: Label = %TopMeldSummary
@onready var right_meld_summary: Label = %RightMeldSummary
@onready var self_discard_summary: Label = %SelfDiscardSummary
@onready var left_discard_summary: Label = %LeftDiscardSummary
@onready var top_discard_summary: Label = %TopDiscardSummary
@onready var right_discard_summary: Label = %RightDiscardSummary
@onready var self_status: Label = %SelfStatus
@onready var self_info_bar: HBoxContainer = %SelfInfoBar
@onready var self_ding_que_label: Label = %SelfDingQueLabel
@onready var self_score_label: Label = %SelfScoreLabel
@onready var self_won_stamp: Label = %SelfWonStamp
@onready var self_hand_host: PlayerHandViewport = %SelfHandHost
@onready var self_section_vbox: VBoxContainer = $UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/SelfSection/SelfSectionMargin/SelfSectionVBox
@onready var self_top_row: HBoxContainer = $UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/SelfSection/SelfSectionMargin/SelfSectionVBox/SelfTopRow
@onready var self_spacer: Control = $UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/SelfSection/SelfSectionMargin/SelfSectionVBox/SelfSpacer
@onready var action_panel: Panel = %ActionPanel
@onready var action_status_label: Label = %ActionStatusLabel
@onready var action_buttons: GridContainer = %ActionButtons
@onready var hu_button: Button = %HuButton
@onready var gang_button: Button = %GangButton
@onready var peng_button: Button = %PengButton
@onready var pass_button: Button = %PassButton
@onready var ding_que_overlay: Control = %DingQueOverlay
@onready var ding_que_panel: Panel = %DingQuePanel
@onready var ding_que_shade: ColorRect = %DingQueShade
@onready var ding_que_status_label: Label = %DingQueStatusLabel
@onready var ding_que_hint_label: Label = %DingQueHintLabel
@onready var ding_que_button_card: Panel = %DingQueButtonCard
@onready var ding_que_tiao_button: Button = %DingQueTiaoButton
@onready var ding_que_tong_button: Button = %DingQueTongButton
@onready var ding_que_wan_button: Button = %DingQueWanButton
@onready var settlement_overlay: Control = %SettlementOverlay
@onready var settlement_panel: Panel = %SettlementPanel
@onready var settlement_shade: ColorRect = %SettlementShade
@onready var settlement_round_label: Label = %SettlementRoundLabel
@onready var settlement_content: HBoxContainer = %SettlementContent
@onready var settlement_player_list_card: Panel = %SettlementPlayerListCard
@onready var settlement_player_list_title: Label = %SettlementPlayerListTitle
@onready var settlement_player_list: VBoxContainer = %SettlementPlayerList
@onready var settlement_detail_card: Panel = %SettlementDetailCard
@onready var settlement_hero_card: Panel = %SettlementHeroCard
@onready var settlement_hero_badge: Label = %SettlementHeroBadge
@onready var settlement_hero_name: Label = %SettlementHeroName
@onready var settlement_hero_result: Label = %SettlementHeroResult
@onready var settlement_hero_summary: Label = %SettlementHeroSummary
@onready var settlement_hero_hu: Label = %SettlementHeroHu
@onready var settlement_hero_fan: Label = %SettlementHeroFan
@onready var settlement_hero_score: Label = %SettlementHeroScore
@onready var settlement_hand_card: Panel = %SettlementHandCard
@onready var settlement_hand_row: VBoxContainer = %SettlementHandRow
@onready var settlement_breakdown_card: Panel = %SettlementBreakdownCard
@onready var settlement_breakdown_title: Label = %SettlementBreakdownTitle
@onready var settlement_breakdown_list: VBoxContainer = %SettlementBreakdownList
@onready var settlement_close_button: Button = %SettlementCloseButton
@onready var next_round_button: Button = %NextRoundButton
@onready var settlement_margin: MarginContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin
@onready var settlement_vbox: VBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox
@onready var settlement_player_list_margin: MarginContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementPlayerListCard/SettlementPlayerListMargin
@onready var settlement_player_list_vbox: VBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementPlayerListCard/SettlementPlayerListMargin/SettlementPlayerListVBox
@onready var settlement_detail_margin: MarginContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin
@onready var settlement_detail_vbox: VBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox
@onready var settlement_hero_margin: MarginContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementHeroCard/SettlementHeroMargin
@onready var settlement_hero_row: HBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementHeroCard/SettlementHeroMargin/SettlementHeroRow
@onready var settlement_hero_info: VBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementHeroCard/SettlementHeroMargin/SettlementHeroRow/SettlementHeroInfo
@onready var settlement_hero_stats: HBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementHeroCard/SettlementHeroMargin/SettlementHeroRow/SettlementHeroStats
@onready var settlement_hand_margin: MarginContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementHandCard/SettlementHandMargin
@onready var settlement_breakdown_margin: MarginContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementBreakdownCard/SettlementBreakdownMargin
@onready var settlement_breakdown_vbox: VBoxContainer = $UILayer/RootUI/SettlementOverlay/SettlementCenter/SettlementPanel/SettlementMargin/SettlementVBox/SettlementContent/SettlementDetailCard/SettlementDetailMargin/SettlementDetailVBox/SettlementBreakdownCard/SettlementBreakdownMargin/SettlementBreakdownVBox

var self_ui
var top_ui
var left_ui
var right_ui
var an_gang_button: Button
var selected_tile_id: int = -1
var settlement_selected_seat: int = -1
var settlement_layout_scale: float = 1.0
var last_snapshot: Dictionary = {}
var ai_turn_timer: Timer
var ai_reaction_timer: Timer
var ai_watchdog_timer: Timer
var opening_roll_timer: Timer
var opening_roll_commit_timer: Timer
var draw_transition_timer: Timer
var tile_voice_player: AudioStreamPlayer
var action_voice_player: AudioStreamPlayer
var system_sfx_player: AudioStreamPlayer
var system_sfx_play_token: int = 0
var sfx_process_id: int = -1
var pending_tile_voice_token: int = 0
var seat_voice_profiles: Dictionary = {}
var voice_cache: Dictionary = {}
var opening_roll_payload: Dictionary = {}
var opening_roll_animation_ticks: int = 0
var opening_roll_started_round: int = -1
var opening_roll_visual_rng := RandomNumberGenerator.new()
var ai_action_delay_rng := RandomNumberGenerator.new()
var settlement_dismissed: bool = false
var settlement_transition_signature := ""
var settlement_transition_pending_snapshot: Dictionary = {}
var settlement_transition_ready := false
var settlement_transition_generation := 0
var settlement_transition_started_msec := -1
var settlement_transition_completed_msec := -1
var settlement_transition_hold_seconds := SETTLEMENT_HOLD_SECONDS
var draw_transition_active: bool = false
var draw_transition_started_at_ms: int = 0
var draw_transition_expected_ms: int = 0
var ai_turn_timer_started_at_ms: int = 0
var ai_reaction_timer_started_at_ms: int = 0
var round_result_overlay: Control
var round_result_banner: Label
var seat_result_labels: Dictionary = {}
var dice_overlay_layer: Control
var dice_panel: Control
var die_a_face: Control
var die_b_face: Control
var dice_count_label: Label
var dice_wind_top_label: Label
var dice_wind_right_label: Label
var dice_wind_bottom_label: Label
var dice_wind_left_label: Label
var self_dealer_badge: Label
var ai_tuning_overlay: Control
var ai_tuning_panel: Panel
var ai_tuning_title_label: Label
var ai_tuning_status_label: Label
var ai_tuning_value_labels: Dictionary = {}
var ai_tuning_preset_buttons: Dictionary = {}
var ai_tuning_learning_label: RichTextLabel
var ai_tuning_auto_learning_button: Button
var ai_tuning_endgame_defense_button: Button
var ai_tuning_close_button: Button
var ai_tuning_dragging: bool = false
var ai_tuning_drag_offset: Vector2 = Vector2.ZERO
var ai_tuning_panel_moved: bool = false
var ai_tuning_click_actions: Array = []
var ai_helper_enabled: bool = false
var opponent_hands_enabled: bool = false
var ai_glass_opacity: float = 0.70
var ai_drawer_position_normalized := Vector2(0.5, 0.72)
var ai_drawer_positioned := false
var discard_helper_panel: Panel
var discard_helper_title: Label
var discard_helper_summary: Label
var discard_helper_compare: Label
var discard_helper_options: Label
var discard_helper_action_button: Button
var board_core_stack: Control
var board_core_count_label: Label
var board_core_wind_top: Label
var board_core_wind_right: Label
var board_core_wind_bottom: Label
var board_core_wind_left: Label
var board_core_status_chip: Label
var board_core_recent_chip: Label
var floating_right_button_bar: VBoxContainer
var floating_right_toggle_button: Button
var floating_ai_tuning_button: Button
var floating_ai_helper_button: Button
var floating_opponent_hand_button: Button
var floating_hell_mark_button: Button
var floating_diagnostic_export_button: Button
var diagnostic_export_in_progress: bool = false
var floating_left_button_bar: VBoxContainer
var floating_left_toggle_button: Button
var floating_preset_button: Button
var floating_exit_button: Button
var floating_right_buttons_collapsed: bool = false
var floating_left_buttons_collapsed: bool = false
var seat_huds: Dictionary = {}
var table_utility_bar: Control
var table_discard_layer: Control
var center_turn_indicator: Control
var table_action_bar: Control
var table_presentation_director: Node
var ai_assistant_drawer: Control
var settlement_overlay_v2: Control
var self_hu_tile_host: Control
var exit_confirmation_dialog: ConfirmationDialog
var last_utility_input_action := ""
var last_utility_input_source := ""
var last_utility_input_msec := -1
var last_action_input_action := ""
var last_action_input_source := ""
var last_action_input_msec := -1
var pending_emulated_mouse_press := false
var pending_emulated_mouse_position := Vector2.ZERO
var pending_emulated_mouse_msec := -1
var table_stage_3d: SichuanTableStage3D
var table_3d_enabled := true
var last_table_3d_tile_id := -1
var last_table_3d_input_source := ""
var last_table_3d_input_msec := -1
var pending_ding_que_suit := ""

const SELF_ROW_MAX_SLOTS := 18
const SELF_SLOT_STEP := 136.0
const SELF_TILE_FACE_WIDTH := 136.0
const SELF_ROW_GAP := 22.0
const SELF_ROW_TILE_VISUAL_HEIGHT := 204.0
const TILE_VISUAL_BASE_RENDER_HEIGHT := 153.0
const SELF_ROW_TILE_VISUAL_SCALE := SELF_ROW_TILE_VISUAL_HEIGHT / TILE_VISUAL_BASE_RENDER_HEIGHT


func _ready() -> void:
	opening_roll_visual_rng.randomize()
	ai_action_delay_rng.randomize()
	_load_ui_preferences()
	_setup_audio_players()
	_setup_ai_timers()
	_setup_opening_roll_timers()
	_setup_table_discard_layer()
	_setup_center_turn_indicator()
	_setup_opening_roll_ui()
	_setup_round_result_overlay()
	_setup_rich_settlement_overlay()
	_setup_settlement_overlay_v2()
	_setup_ai_assistant_drawer()
	_setup_ai_tuning_overlay()
	_setup_board_core_hud()
	_setup_table_utility_bar()
	_setup_table_action_bar()
	_setup_table_presentation_director()
	_setup_seat_huds()
	_setup_self_hu_tile_host()
	game_manager.set_human_trainer_hint_enabled(ai_helper_enabled)
	_apply_style()
	_setup_3d_table_stage()
	_mount_self_won_stamp_overlay()
	_configure_board_lanes()
	_bind_board_square_layout()
	ding_que_overlay.top_level = true
	ding_que_overlay.z_index = 420
	ding_que_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ding_que_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ding_que_center := ding_que_overlay.get_node_or_null("DingQueCenter") as Control
	if ding_que_center != null:
		ding_que_center.mouse_filter = Control.MOUSE_FILTER_PASS
	self_ui = _mount_player_ui(player_self_host, SeatDock.SELF)
	top_ui = _mount_player_ui(player_top_host, SeatDock.TOP)
	left_ui = _mount_player_ui(player_left_host, SeatDock.LEFT)
	right_ui = _mount_player_ui(player_right_host, SeatDock.RIGHT)

	self_hand_host.tile_pressed.connect(_on_hand_tile_pressed)
	top_bar_button.pressed.connect(_on_top_bar_button_pressed)
	top_ai_tuning_button.pressed.connect(_on_top_ai_tuning_button_pressed)
	top_ai_helper_button.pressed.connect(_on_top_ai_helper_button_pressed)
	top_opponent_hand_button.pressed.connect(_on_top_opponent_hand_button_pressed)
	top_settlement_info_button.pressed.connect(_on_top_settlement_info_pressed)
	top_next_round_button.pressed.connect(_on_top_next_round_pressed)
	top_exit_button.pressed.connect(_on_top_exit_pressed)
	ding_que_tiao_button.pressed.connect(_on_ding_que_pressed.bind("tiao"))
	ding_que_tong_button.pressed.connect(_on_ding_que_pressed.bind("tong"))
	ding_que_wan_button.pressed.connect(_on_ding_que_pressed.bind("wan"))

	game_manager.snapshot_changed.connect(_on_snapshot_changed)
	game_manager.opening_roll_started.connect(_on_opening_roll_started)
	_on_snapshot_changed(game_manager.get_snapshot())
	call_deferred("_center_ai_tuning_panel")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			if ding_que_overlay != null and ding_que_overlay.visible:
				_handle_ding_que_overlay_click(touch_event.position)
				_arm_emulated_mouse_suppression(touch_event.position)
				get_viewport().set_input_as_handled()
				return
			if _handle_table_utility_click(touch_event.position, "touch"):
				_arm_emulated_mouse_suppression(touch_event.position)
				get_viewport().set_input_as_handled()
				return
			if _handle_table_action_click(touch_event.position, "touch"):
				_arm_emulated_mouse_suppression(touch_event.position)
				get_viewport().set_input_as_handled()
				return
			if _handle_left_floating_toggle_click(touch_event.position):
				_arm_emulated_mouse_suppression(touch_event.position)
				get_viewport().set_input_as_handled()
				return
			if _handle_left_floating_action_click(touch_event.position):
				_arm_emulated_mouse_suppression(touch_event.position)
				get_viewport().set_input_as_handled()
				return
			if _handle_3d_table_tile_click(touch_event.position, "touch"):
				_arm_emulated_mouse_suppression(touch_event.position)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _consume_emulated_mouse_press(mouse_event.position):
				get_viewport().set_input_as_handled()
				return
			if ding_que_overlay != null and ding_que_overlay.visible:
				_handle_ding_que_overlay_click(mouse_event.position)
				get_viewport().set_input_as_handled()
				return
			if _handle_table_utility_click(mouse_event.position, "mouse"):
				get_viewport().set_input_as_handled()
				return
			# Keep the decision buttons operable even when one of the full-table
			# presentation layers happens to win Godot's GUI hit test.  The table
			# already uses this explicit dispatch pattern for other floating UI.
			# Marking the event handled also prevents the Button signal from firing
			# the same claim twice.
			if _handle_table_action_click(mouse_event.position, "mouse"):
				get_viewport().set_input_as_handled()
				return
			if _handle_left_floating_toggle_click(mouse_event.position):
				get_viewport().set_input_as_handled()
				return
			if _handle_left_floating_action_click(mouse_event.position):
				get_viewport().set_input_as_handled()
				return
			if _handle_ai_tuning_overlay_click(mouse_event.position):
				get_viewport().set_input_as_handled()
				return
			if _handle_ai_tuning_drag_press(mouse_event.position):
				get_viewport().set_input_as_handled()
				return
			if _handle_3d_table_tile_click(mouse_event.position, "mouse"):
				get_viewport().set_input_as_handled()
				return
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			ai_tuning_dragging = false
	if not ai_tuning_dragging or ai_tuning_panel == null:
		return
	if event is InputEventMouseMotion:
		ai_tuning_panel.global_position = get_global_mouse_position() - ai_tuning_drag_offset
		_clamp_ai_tuning_panel_position()


func _arm_emulated_mouse_suppression(global_pos: Vector2) -> void:
	pending_emulated_mouse_press = true
	pending_emulated_mouse_position = global_pos
	pending_emulated_mouse_msec = Time.get_ticks_msec()


func _consume_emulated_mouse_press(global_pos: Vector2) -> bool:
	if not pending_emulated_mouse_press:
		return false
	var elapsed_msec := Time.get_ticks_msec() - pending_emulated_mouse_msec
	var is_same_physical_press := (
		elapsed_msec >= 0
		and elapsed_msec <= EMULATED_MOUSE_EVENT_WINDOW_MSEC
		and pending_emulated_mouse_position.distance_to(global_pos) <= EMULATED_MOUSE_POSITION_TOLERANCE
	)
	pending_emulated_mouse_press = false
	return is_same_physical_press


func _handle_3d_table_tile_click(global_pos: Vector2, input_source: String) -> bool:
	if not table_3d_enabled or table_stage_3d == null or not is_instance_valid(table_stage_3d):
		return false
	var tile_id := int(table_stage_3d.call("find_tile_at_screen", global_pos))
	if tile_id < 0:
		return false
	var now_msec := Time.get_ticks_msec()
	if input_source == "mouse":
		var is_emulated_mouse := (
			last_table_3d_tile_id == tile_id
			and last_table_3d_input_source == "touch"
			and now_msec - last_table_3d_input_msec >= 0
			and now_msec - last_table_3d_input_msec <= TABLE_3D_CROSS_INPUT_DEDUP_WINDOW_MSEC
		)
		if is_emulated_mouse:
			last_table_3d_input_source = "mouse_consumed"
			last_table_3d_input_msec = now_msec
			return true
	last_table_3d_tile_id = tile_id
	last_table_3d_input_source = input_source
	last_table_3d_input_msec = now_msec
	_on_hand_tile_pressed(tile_id)
	return true


func _handle_table_utility_click(global_pos: Vector2, input_source: String = "direct") -> bool:
	if table_utility_bar == null or not is_instance_valid(table_utility_bar) or not table_utility_bar.visible:
		return false
	# Snapshot a normalized layout before hit-testing. Several utility actions
	# synchronously refresh the game snapshot and relayout this drawer; without
	# normalization, the emulated half of an iOS tap can see transient overlapping
	# rectangles and dispatch to the adjacent row.
	table_utility_bar.call("_layout_buttons")
	var matched_action := ""
	var matched_button: Button
	var matched_distance := INF
	for action in ["toggle", "ai", "settings", "opponent_hands", "settlement", "next_round", "exit"]:
		var button: Button = table_utility_bar.call("get_button", action)
		if button == null or not is_instance_valid(button):
			continue
		if not button.is_visible_in_tree() or button.disabled:
			continue
		var rect := button.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0 and rect.has_point(global_pos):
			var distance := rect.get_center().distance_squared_to(global_pos)
			if distance < matched_distance:
				matched_distance = distance
				matched_action = action
				matched_button = button
	if matched_button == null:
		return false
	if _is_duplicate_utility_cross_input(matched_action, input_source):
		# iOS emits a touch event and then an emulated mouse event for the same
		# physical tap. Consume the second event without executing the action.
		return true
	matched_button.emit_signal("pressed")
	return true


func _is_duplicate_utility_cross_input(action: String, input_source: String) -> bool:
	if input_source not in ["touch", "mouse"]:
		return false
	var now_msec := Time.get_ticks_msec()
	if input_source == "mouse":
		var elapsed_msec := now_msec - last_utility_input_msec
		var is_emulated_mouse := (
			last_utility_input_action == action
			and last_utility_input_source == "touch"
			and elapsed_msec >= 0
			and elapsed_msec <= UTILITY_CROSS_INPUT_DEDUP_WINDOW_MSEC
		)
		if is_emulated_mouse:
			# Consume exactly one emulated mouse event. Marking the pair as
			# consumed prevents the next genuine touch from being suppressed.
			last_utility_input_source = "mouse_consumed"
			last_utility_input_msec = now_msec
			return true
	last_utility_input_action = action
	last_utility_input_source = input_source
	last_utility_input_msec = now_msec
	return false


func _handle_table_action_click(global_pos: Vector2, input_source: String = "direct") -> bool:
	if table_action_bar == null or not is_instance_valid(table_action_bar) or not table_action_bar.visible:
		return false
	for action in ["hu", "gang", "peng", "pass"]:
		var button: Button = table_action_bar.call("get_button", action)
		if button == null or not is_instance_valid(button):
			continue
		if not button.is_visible_in_tree() or button.disabled:
			continue
		var rect := button.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0 and rect.has_point(global_pos):
			if _is_duplicate_action_cross_input(action, input_source):
				return true
			# Emit the real Button signal so pressed feedback and the action-bar
			# dispatch path are identical to a normal GUI hit.
			button.emit_signal("pressed")
			return true
	return false


func _is_duplicate_action_cross_input(action: String, input_source: String) -> bool:
	if input_source not in ["touch", "mouse"]:
		return false
	var now_msec := Time.get_ticks_msec()
	if input_source == "mouse":
		var elapsed_msec := now_msec - last_action_input_msec
		var is_emulated_mouse := (
			last_action_input_action == action
			and last_action_input_source == "touch"
			and elapsed_msec >= 0
			and elapsed_msec <= ACTION_CROSS_INPUT_DEDUP_WINDOW_MSEC
		)
		if is_emulated_mouse:
			last_action_input_source = "mouse_consumed"
			last_action_input_msec = now_msec
			return true
	last_action_input_action = action
	last_action_input_source = input_source
	last_action_input_msec = now_msec
	return false


func _handle_ding_que_overlay_click(global_pos: Vector2) -> bool:
	if ding_que_overlay == null or not ding_que_overlay.visible:
		return false
	var targets := [
		{"button": ding_que_tiao_button, "suit": "tiao"},
		{"button": ding_que_tong_button, "suit": "tong"},
		{"button": ding_que_wan_button, "suit": "wan"},
	]
	for entry in targets:
		var button: Button = entry.get("button", null)
		if button == null or not is_instance_valid(button):
			continue
		if not button.visible or button.disabled:
			continue
		var rect := button.get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		if rect.has_point(global_pos):
			_on_ding_que_pressed(str(entry.get("suit", "")))
			return true
	var overlay_rect := ding_que_overlay.get_global_rect()
	return overlay_rect.has_point(global_pos)


func _bind_board_square_layout() -> void:
	if board_area != null and not board_area.resized.is_connected(_queue_board_square_layout):
		board_area.resized.connect(_queue_board_square_layout)
	if root_ui != null and not root_ui.resized.is_connected(_queue_board_square_layout):
		root_ui.resized.connect(_queue_board_square_layout)
	_queue_board_square_layout()


func _queue_board_square_layout() -> void:
	call_deferred("_apply_board_square_layout")


func _apply_board_square_layout() -> void:
	if board_area == null or board_aspect == null or board_square == null:
		return
	var available_size := board_area.size - Vector2(6.0, 6.0)
	var width := floorf(maxf(320.0, minf(available_size.x, available_size.y * BOARD_TARGET_RATIO)))
	var height := floorf(width / BOARD_TARGET_RATIO)
	if height > available_size.y:
		height = floorf(available_size.y)
		width = floorf(height * BOARD_TARGET_RATIO)
	board_aspect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_aspect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_aspect.ratio = BOARD_TARGET_RATIO
	board_aspect.custom_minimum_size = Vector2(width, height)
	board_square.custom_minimum_size = Vector2(width, height)
	_layout_table_center_components(width, height)


func _setup_audio_players() -> void:
	tile_voice_player = AudioStreamPlayer.new()
	tile_voice_player.name = "TileVoicePlayer"
	tile_voice_player.volume_db = 4.5
	add_child(tile_voice_player)

	action_voice_player = AudioStreamPlayer.new()
	action_voice_player.name = "ActionVoicePlayer"
	action_voice_player.volume_db = 5.5
	add_child(action_voice_player)

	system_sfx_player = AudioStreamPlayer.new()
	system_sfx_player.name = "SystemSfxPlayer"
	system_sfx_player.volume_db = 3.5
	add_child(system_sfx_player)


func _setup_ai_timers() -> void:
	ai_turn_timer = Timer.new()
	ai_turn_timer.one_shot = false
	ai_turn_timer.wait_time = AI_ACTION_DELAY_MIN_SEC
	add_child(ai_turn_timer)
	ai_turn_timer.timeout.connect(_on_ai_turn_timer_timeout)

	ai_reaction_timer = Timer.new()
	ai_reaction_timer.one_shot = false
	ai_reaction_timer.wait_time = AI_ACTION_DELAY_MIN_SEC
	add_child(ai_reaction_timer)
	ai_reaction_timer.timeout.connect(_on_ai_reaction_timer_timeout)

	ai_watchdog_timer = Timer.new()
	ai_watchdog_timer.one_shot = false
	ai_watchdog_timer.wait_time = AI_WATCHDOG_POLL_SEC
	add_child(ai_watchdog_timer)
	ai_watchdog_timer.timeout.connect(_on_ai_watchdog_timer_timeout)
	ai_watchdog_timer.start()


func _setup_opening_roll_timers() -> void:
	opening_roll_timer = Timer.new()
	opening_roll_timer.one_shot = false
	opening_roll_timer.wait_time = OPENING_ROLL_TICK
	add_child(opening_roll_timer)
	opening_roll_timer.timeout.connect(_on_opening_roll_timer_timeout)

	opening_roll_commit_timer = Timer.new()
	opening_roll_commit_timer.one_shot = true
	opening_roll_commit_timer.wait_time = 0.18
	add_child(opening_roll_commit_timer)
	opening_roll_commit_timer.timeout.connect(_on_opening_roll_commit_timer_timeout)

	draw_transition_timer = Timer.new()
	draw_transition_timer.one_shot = true
	draw_transition_timer.wait_time = SYSTEM_DRAW_ACTION_DELAY
	add_child(draw_transition_timer)
	draw_transition_timer.timeout.connect(_on_draw_transition_timer_timeout)


func _process(_delta: float) -> void:
	if game_manager == null:
		return
	var delivered_count := int(game_manager.pump_ai_background_requests())
	if delivered_count <= 0:
		return
	_kick_ai_timers_after_background_delivery()


func _kick_ai_timers_after_background_delivery() -> void:
	if game_manager == null:
		return
	if game_manager.is_ai_reaction_pending():
		_clear_draw_transition_block("ai_reaction_background_delivery")
	if game_manager.is_ai_turn_ready() and ai_turn_timer != null and ai_turn_timer.is_stopped() and not draw_transition_active:
		_start_ai_turn_action_timer()
	if game_manager.is_ai_reaction_pending() and ai_reaction_timer != null and ai_reaction_timer.is_stopped():
		_start_ai_reaction_action_timer()


func _next_ai_action_delay_seconds() -> float:
	return ai_action_delay_rng.randf_range(AI_ACTION_DELAY_MIN_SEC, AI_ACTION_DELAY_MAX_SEC)


func _start_ai_turn_action_timer() -> void:
	if ai_turn_timer == null:
		return
	ai_turn_timer.wait_time = _next_ai_action_delay_seconds()
	ai_turn_timer_started_at_ms = Time.get_ticks_msec()
	ai_turn_timer.start()


func _start_ai_reaction_action_timer() -> void:
	if ai_reaction_timer == null:
		return
	ai_reaction_timer.wait_time = _next_ai_action_delay_seconds()
	ai_reaction_timer_started_at_ms = Time.get_ticks_msec()
	ai_reaction_timer.start()


func _set_ai_action_delay_seed(seed_value: int) -> void:
	ai_action_delay_rng.seed = seed_value


func _apply_style() -> void:
	var style := STYLE_CONFIG

	for panel in [
		%TopBar,
		%RoomCard,
		%InfoCard,
		center_card,
		center_stats_card,
		center_hint_card,
		board_area,
		board_square,
		board_core,
		center_meld_card,
		center_discard_card,
		%LeftRail,
		%TopRail,
		%RightRail,
		%SelfSection,
		action_panel,
		ding_que_panel,
		settlement_panel,
		settlement_player_list_card,
		settlement_detail_card,
		settlement_hero_card,
		settlement_hand_card,
		settlement_breakdown_card,
	]:
		style.apply_panel(panel, true if panel in [%TopBar, center_card, %SelfSection, settlement_panel] else false)

	for shell_panel in [%LeftRail, %TopRail, %RightRail, board_area, board_square]:
		style.apply_clear_panel(shell_panel)

	if discard_helper_panel != null:
		style.apply_panel(discard_helper_panel, false)

	for label in [
		room_label,
		center_info,
		center_status,
		center_dealer_label,
		center_wall_label,
		center_turn_label,
		center_reaction_label,
		center_hint_box,
		board_core_label,
		self_meld_summary,
		left_meld_summary,
		top_meld_summary,
		right_meld_summary,
		self_discard_summary,
		left_discard_summary,
		top_discard_summary,
		right_discard_summary,
		self_status,
		self_ding_que_label,
		self_score_label,
		self_won_stamp,
		action_status_label,
		ding_que_status_label,
		ding_que_hint_label,
		settlement_round_label,
		settlement_player_list_title,
		settlement_hero_badge,
		settlement_hero_name,
		settlement_hero_result,
		settlement_hero_summary,
		settlement_hero_hu,
		settlement_hero_fan,
		settlement_hero_score,
		settlement_breakdown_title,
		%MeldSectionTitle,
		%DiscardSectionTitle,
	]:
		style.apply_label(label, false, false)

	for label in [discard_helper_title, discard_helper_summary, discard_helper_compare, discard_helper_options]:
		if label != null:
			style.apply_label(label, label == discard_helper_title, false)

	for label in [
		self_meld_summary,
		left_meld_summary,
		top_meld_summary,
		right_meld_summary,
		self_discard_summary,
		left_discard_summary,
		top_discard_summary,
		right_discard_summary,
		%MeldSectionTitle,
		%DiscardSectionTitle,
	]:
		style.apply_label(label, true, false)

	style.apply_label(room_label, false, true)
	style.apply_label(center_info, false, false)
	style.apply_label(center_status, true, false)
	style.apply_label(self_status, false, false)
	style.apply_label(self_ding_que_label, false, true)
	style.apply_label(self_score_label, false, true)
	style.apply_label(self_won_stamp, false, true)
	style.apply_label(%SettlementTitle, false, true)
	style.apply_label(settlement_round_label, true, false)
	style.apply_label(settlement_hero_badge, false, true)
	style.apply_label(settlement_hero_name, false, false)
	style.apply_label(settlement_hero_result, false, true)
	style.apply_label(settlement_hero_summary, false, false)
	style.apply_label(settlement_hero_hu, false, false)
	style.apply_label(settlement_hero_fan, false, false)
	style.apply_label(settlement_hero_score, false, false)
	# The rich settlement overlay remains the authoritative fallback path for
	# the iOS typography contract. Reapply its explicit hierarchy after the
	# generic theme pass so 26/18/14 defaults cannot shrink it.
	%SettlementTitle.add_theme_font_size_override("font_size", 36)
	%SettlementTitle.add_theme_font_override("font", style._display_font())
	settlement_round_label.add_theme_font_size_override("font_size", 24)
	settlement_round_label.add_theme_font_override("font", style._body_font())
	settlement_hero_badge.add_theme_font_size_override("font_size", 26)
	settlement_hero_badge.add_theme_font_override("font", style._display_font())
	settlement_hero_name.add_theme_font_size_override("font_size", 28)
	settlement_hero_name.add_theme_font_override("font", style._body_font())
	settlement_hero_hu.add_theme_font_size_override("font_size", 24)
	settlement_hero_hu.add_theme_font_override("font", style._body_font())
	settlement_hero_fan.add_theme_font_size_override("font_size", 24)
	settlement_hero_fan.add_theme_font_override("font", style._body_font())
	settlement_hero_score.add_theme_font_size_override("font_size", 64)
	settlement_hero_score.add_theme_font_override("font", style._body_font())
	settlement_breakdown_title.add_theme_font_size_override("font_size", 32)
	settlement_breakdown_title.add_theme_font_override("font", style._display_font())
	style.apply_label(board_core_label, true, false)
	_apply_self_ding_que_style()
	_apply_self_score_style()
	_setup_self_dealer_badge()
	_apply_self_won_stamp_style()
	_apply_round_result_overlay_style()

	for button in [top_bar_button, top_settlement_info_button, top_exit_button, peng_button, pass_button, settlement_close_button]:
		style.apply_button(button, false)
	for button in [hu_button, gang_button, ding_que_tiao_button, ding_que_tong_button, ding_que_wan_button, next_round_button, top_next_round_button, top_ai_helper_button]:
		style.apply_button(button, true)
	if discard_helper_action_button != null:
		style.apply_button(discard_helper_action_button, true)
	_apply_ding_que_overlay_style()
	_apply_top_bar_button_group_styles()
	center_status.visible = false
	self_status.visible = false
	_apply_reference_table_layout()

	var section_titles: Array[Label] = [%MeldSectionTitle, %DiscardSectionTitle]
	for label in section_titles:
		style.apply_label(label, true, false)
	_apply_tabletop_matte_theme()
	_apply_opening_roll_ui_style(style)
	_apply_discard_helper_style()
	_apply_floating_action_button_styles()
	_apply_embedded_ui_font()


func _setup_v17_plus_menu() -> void:
	floating_left_buttons_collapsed = true
	floating_right_buttons_collapsed = true
	_setup_left_floating_buttons()
	if floating_left_button_bar != null:
		# The shared TableUtilityBar now owns the public AI / difficulty / reveal
		# drawer.  Keep this legacy group instantiated for compatibility with old
		# diagnostics, but never stack duplicate hit targets over the release UI.
		floating_left_button_bar.visible = false
	if floating_right_button_bar != null:
		floating_right_button_bar.visible = false


func _configure_v17_top_bar() -> void:
	if info_card == null:
		return
	%RoomCard.visible = false
	info_card.visible = false
	top_bar_button.visible = false
	top_ai_tuning_button.visible = false
	top_ai_helper_button.visible = false
	top_opponent_hand_button.visible = false
	top_settlement_info_button.visible = false
	top_next_round_button.visible = false
	top_exit_button.visible = false


func _configure_board_lanes() -> void:
	board_top_lane.visible = false
	board_left_lane.visible = false
	board_right_lane.visible = false
	board_bottom_lane.visible = false
	board_core.custom_minimum_size = Vector2(148, 148)
	board_core.visible = false


func _apply_reference_table_layout() -> void:
	var main_vbox := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox") as VBoxContainer
	if main_vbox != null:
		main_vbox.add_theme_constant_override("separation", 4)
	var table_row := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow") as HBoxContainer
	if table_row != null:
		table_row.add_theme_constant_override("separation", 0)
	var center_column := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn") as VBoxContainer
	if center_column != null:
		center_column.add_theme_constant_override("separation", 0)
	%LeftRail.custom_minimum_size = Vector2(182, 0)
	%RightRail.custom_minimum_size = Vector2(182, 0)
	%TopRail.custom_minimum_size = Vector2(0, 70)
	%SelfSection.custom_minimum_size = Vector2(0, SELF_HAND_BOTTOM_HEIGHT)
	%CenterStatsCard.visible = false
	%CenterHintCard.visible = false
	var center_summary_row := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/CenterCard/CenterMargin/CenterVBox/CenterSummaryRow") as Control
	if center_summary_row != null:
		center_summary_row.visible = false
	board_area.custom_minimum_size = Vector2(0, 610)
	self_top_row.custom_minimum_size = Vector2(0, 0)
	self_top_row.visible = false
	self_info_bar.visible = false
	self_spacer.custom_minimum_size = Vector2(0, 0)
	self_hand_host.custom_minimum_size = Vector2(0, SELF_HAND_BOTTOM_HEIGHT)
	action_panel.top_level = true
	action_panel.z_index = 220
	board_core.visible = false
	var left_margin := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/LeftRail/LeftRailMargin") as MarginContainer
	if left_margin != null:
		left_margin.add_theme_constant_override("margin_left", 4)
		left_margin.add_theme_constant_override("margin_right", 4)
	var right_margin := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/RightRail/RightRailMargin") as MarginContainer
	if right_margin != null:
		right_margin.add_theme_constant_override("margin_left", 4)
		right_margin.add_theme_constant_override("margin_right", 4)
	var top_margin := get_node_or_null("UILayer/RootUI/SafeArea/MainVBox/TableRow/CenterColumn/TopRail/TopRailMargin") as MarginContainer
	if top_margin != null:
		top_margin.add_theme_constant_override("margin_left", 20)
		top_margin.add_theme_constant_override("margin_top", 0)
		top_margin.add_theme_constant_override("margin_right", 20)
		top_margin.add_theme_constant_override("margin_bottom", 0)
	if player_left_host != null:
		player_left_host.custom_minimum_size = Vector2(182, 0)
	if player_right_host != null:
		player_right_host.custom_minimum_size = Vector2(182, 0)
	if player_top_host != null:
		player_top_host.custom_minimum_size = Vector2(0, 136)
	_apply_v17_reference_frames()


func _scale_design_rect(x: float, y: float, width: float, height: float) -> Rect2:
	if root_ui == null or root_ui.size.x <= 0.0 or root_ui.size.y <= 0.0:
		return Rect2(Vector2(x, y), Vector2(width, height))
	var scale_x := root_ui.size.x / DESIGN_BASE_SIZE.x
	var scale_y := root_ui.size.y / DESIGN_BASE_SIZE.y
	return Rect2(
		Vector2(x * scale_x, y * scale_y),
		Vector2(width * scale_x, height * scale_y)
	)


func _scale_v17_rect(x: float, y: float, width: float, height: float) -> Rect2:
	return _scale_design_rect(x, y, width, height)


func _apply_v17_reference_frames() -> void:
	if root_ui == null:
		return
	var top_rect := _v17_top_dynamic_rect()
	var left_rect := _v17_left_dynamic_rect()
	var right_rect := _v17_right_dynamic_rect()
	var self_rect := _v17_self_dynamic_rect()
	var board_rect := _v17_board_rect()

	%TopRail.custom_minimum_size = Vector2(0, top_rect.size.y)
	%LeftRail.custom_minimum_size = Vector2(left_rect.size.x, 0)
	%RightRail.custom_minimum_size = Vector2(right_rect.size.x, 0)
	%SelfSection.custom_minimum_size = Vector2(0, self_rect.size.y)
	board_area.custom_minimum_size = Vector2(0, board_rect.size.y)

	if player_left_host != null:
		player_left_host.custom_minimum_size = Vector2(left_rect.size.x, left_rect.size.y)
	if player_right_host != null:
		player_right_host.custom_minimum_size = Vector2(right_rect.size.x, right_rect.size.y)
	if player_top_host != null:
		player_top_host.custom_minimum_size = Vector2(top_rect.size.x, top_rect.size.y)
	_apply_v17_absolute_layout()


func _v17_board_rect() -> Rect2:
	return _compact_board_rect()


func _compact_board_rect() -> Rect2:
	return SICHUAN_TABLE_METRICS.board_rect(root_ui.size if root_ui != null else DESIGN_BASE_SIZE)


func _v17_top_dynamic_rect() -> Rect2:
	return _opponent_host_rect(2)


func _v17_left_dynamic_rect() -> Rect2:
	return _opponent_host_rect(1)


func _v17_right_dynamic_rect() -> Rect2:
	return _opponent_host_rect(3)


func _v17_self_dynamic_rect() -> Rect2:
	return _self_hand_rect()


func _v17_self_meld_rect() -> Rect2:
	return _scale_design_rect(20.0, 884.0, 560.0, 262.0)


func _v17_self_hand_rect() -> Rect2:
	return _self_hand_rect()


func _self_hand_rect() -> Rect2:
	return SICHUAN_TABLE_METRICS.self_hand_rect(root_ui.size if root_ui != null else DESIGN_BASE_SIZE)


func _opponent_host_rect(seat: int) -> Rect2:
	return SICHUAN_TABLE_METRICS.opponent_track_rect(seat, root_ui.size if root_ui != null else DESIGN_BASE_SIZE)


func _v17_self_hu_rect() -> Rect2:
	return _scale_design_rect(1876.0, 894.0, 144.0, 236.0)


func _seat_hud_rect(seat: int) -> Rect2:
	return SICHUAN_TABLE_METRICS.seat_hud_rect(seat, root_ui.size if root_ui != null else DESIGN_BASE_SIZE)


func _apply_v17_absolute_layout() -> void:
	if root_ui == null:
		return
	_place_v17_absolute_host(player_top_host, _v17_top_dynamic_rect(), 18)
	_place_v17_absolute_host(player_left_host, _v17_left_dynamic_rect(), 18)
	_place_v17_absolute_host(player_right_host, _v17_right_dynamic_rect(), 18)
	_place_v17_absolute_host(self_hand_host, _v17_self_hand_rect(), 22)
	if player_self_host != null:
		player_self_host.visible = false
	if self_hu_tile_host != null:
		self_hu_tile_host.visible = false

	if board_area != null:
		board_area.top_level = true
		board_area.z_index = 12
		_place_overlay_box(board_area, Vector2.ZERO, _v17_board_rect().position, _v17_board_rect().size)


func _place_v17_absolute_host(host: Control, rect: Rect2, z_index_value: int = 10) -> void:
	if host == null:
		return
	if root_ui != null and host.get_parent() != root_ui:
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		root_ui.add_child(host)
	host.top_level = true
	host.z_index = z_index_value
	_place_overlay_box(host, Vector2.ZERO, rect.position, rect.size)


func _setup_table_discard_layer() -> void:
	if board_square == null:
		return
	table_discard_layer = TABLE_DISCARD_LAYER_SCRIPT.new()
	table_discard_layer.name = "TableDiscardLayer"
	table_discard_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_discard_layer.z_index = 4
	board_square.add_child(table_discard_layer)


func _setup_3d_table_stage() -> void:
	table_3d_enabled = bool(ProjectSettings.get_setting(TABLE_3D_PROJECT_SETTING, true))
	if not table_3d_enabled:
		return
	var game_scene := get_node_or_null("GameScene") as Node2D
	if game_scene == null:
		push_warning("[MainSceneV2] GameScene missing; keeping the 2D table fallback.")
		table_3d_enabled = false
		return
	table_stage_3d = TABLE_STAGE_3D_SCRIPT.new() as SichuanTableStage3D
	table_stage_3d.name = "SichuanTableStage3D"
	game_scene.add_child(table_stage_3d)
	table_stage_3d.set_reduced_motion(bool(ProjectSettings.get_setting("accessibility/reduced_motion", false)))
	if center_turn_indicator != null and root_ui != null and center_turn_indicator.get_parent() != root_ui:
		center_turn_indicator.reparent(root_ui)
		center_turn_indicator.top_level = true
		center_turn_indicator.z_index = 82
	_apply_3d_presentation_visibility()
	_layout_3d_center_indicator()


func _apply_3d_presentation_visibility() -> void:
	if not table_3d_enabled:
		return
	if background_rect != null:
		background_rect.visible = false
	if table_discard_layer != null:
		table_discard_layer.visible = false
	# 3D table mode owns the remaining-wall numeral as physical world text.
	# Keep the Control scene only for the non-3D fallback, otherwise both layers
	# would produce duplicate counts above the compass.
	if center_turn_indicator != null:
		center_turn_indicator.visible = false
	for legacy_host in [player_self_host, player_top_host, player_left_host, player_right_host, self_hand_host]:
		if legacy_host != null:
			legacy_host.visible = false


func _update_3d_table(snapshot: Dictionary) -> void:
	if not table_3d_enabled or table_stage_3d == null or game_manager == null or game_manager.game_state == null:
		return
	var all_hands: Array = []
	for seat in range(4):
		all_hands.append(game_manager.game_state.call("get_player_hand_tiles", seat))
	var trainer_hint: Dictionary = snapshot.get("trainer_hint", {}) if ai_helper_enabled else {}
	var markers := {
		"recommended_tile_id": int(trainer_hint.get("recommended_tile_id", -1)),
		"danger_tile_ids": Array(trainer_hint.get("danger_tile_ids", [])).duplicate(),
	}
	table_stage_3d.render_snapshot(snapshot, all_hands, opponent_hands_enabled, selected_tile_id, markers)
	_apply_3d_presentation_visibility()
	_layout_3d_center_indicator()


func _layout_3d_center_indicator() -> void:
	if table_stage_3d == null or center_turn_indicator == null or root_ui == null:
		return
	var stage_camera := table_stage_3d.get_camera()
	if stage_camera == null:
		return
	var center_world_z := float(TABLE_STAGE_3D_SCRIPT.CENTER_INDICATOR_WORLD_Z)
	var center_screen := stage_camera.unproject_position(Vector3(0.0, 0.10, center_world_z))
	var compact := get_viewport_rect().size.y < 820.0
	center_turn_indicator.call("set_compact", compact)
	var indicator_size := center_turn_indicator.size
	if indicator_size.x <= 1.0 or indicator_size.y <= 1.0:
		indicator_size = center_turn_indicator.custom_minimum_size
	_place_overlay_box(center_turn_indicator, Vector2.ZERO, center_screen - indicator_size * 0.5, indicator_size)


func _setup_center_turn_indicator() -> void:
	if board_square == null:
		return
	center_turn_indicator = CENTER_TURN_INDICATOR_SCENE.instantiate()
	center_turn_indicator.name = "CenterTurnIndicator"
	center_turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_turn_indicator.z_index = 8
	board_square.add_child(center_turn_indicator)


func _layout_table_center_components(board_width: float, board_height: float) -> void:
	if board_width <= 0.0 or board_height <= 0.0:
		return
	var board_rect := Rect2(Vector2.ZERO, Vector2(board_width, board_height))
	if table_discard_layer != null:
		table_discard_layer.call("set_board_rect", board_rect)
	if center_turn_indicator != null:
		if table_stage_3d != null:
			_layout_3d_center_indicator()
			return
		var compact := get_viewport_rect().size.y < 820.0
		center_turn_indicator.call("set_compact", compact)
		center_turn_indicator.position = (board_rect.size - center_turn_indicator.size) * 0.5


func _place_overlay_box(node: Control, anchor: Vector2, offset: Vector2, box_size: Vector2) -> void:
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = offset.x
	node.offset_top = offset.y
	node.offset_right = offset.x + box_size.x
	node.offset_bottom = offset.y + box_size.y
	node.custom_minimum_size = box_size


func _setup_opening_roll_ui() -> void:
	board_core.visible = false
	board_core_label.visible = false

	dice_overlay_layer = Control.new()
	dice_overlay_layer.name = "OpeningRollOverlay"
	dice_overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dice_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_square.add_child(dice_overlay_layer)

	var center_root := CenterContainer.new()
	center_root.name = "OpeningCenterRoot"
	center_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_overlay_layer.add_child(center_root)

	dice_panel = WALL_COUNT_DISC_SCRIPT.new()
	dice_panel.name = "DicePanel"
	dice_panel.custom_minimum_size = Vector2(136, 136)
	dice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_root.add_child(dice_panel)

	var panel_center := CenterContainer.new()
	panel_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_panel.add_child(panel_center)

	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 2)
	panel_center.add_child(dice_row)

	die_a_face = DICE_FACE_SCRIPT.new()
	die_b_face = DICE_FACE_SCRIPT.new()
	die_a_face.custom_minimum_size = Vector2(16, 16)
	die_b_face.custom_minimum_size = Vector2(16, 16)
	die_b_face.set("pip_color", Color(0.62, 0.18, 0.12, 1.0))
	dice_row.add_child(die_a_face)
	dice_row.add_child(die_b_face)

	dice_count_label = Label.new()
	dice_count_label.visible = false
	dice_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_center.add_child(dice_count_label)

	dice_wind_top_label = _create_dice_wind_label("北")
	dice_wind_right_label = _create_dice_wind_label("东")
	dice_wind_bottom_label = _create_dice_wind_label("南")
	dice_wind_left_label = _create_dice_wind_label("西")
	for label in [dice_wind_top_label, dice_wind_right_label, dice_wind_bottom_label, dice_wind_left_label]:
		dice_panel.add_child(label)


func _create_dice_wind_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(64, 48)
	STYLE_CONFIG.apply_label(label, false, true)
	label.add_theme_font_size_override("font_size", CENTER_WALL_WIND_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.86, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _setup_round_result_overlay() -> void:
	round_result_overlay = Control.new()
	round_result_overlay.name = "RoundResultOverlay"
	round_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(round_result_overlay)

	round_result_banner = Label.new()
	round_result_banner.visible = false
	round_result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_result_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_result_overlay.add_child(round_result_banner)

	for seat in range(4):
		var score_label := Label.new()
		score_label.visible = false
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		round_result_overlay.add_child(score_label)
		seat_result_labels[seat] = score_label


func _setup_settlement_overlay_v2() -> void:
	if root_ui == null or settlement_overlay_v2 != null:
		return
	settlement_overlay_v2 = SETTLEMENT_OVERLAY_SCENE.instantiate() as Control
	settlement_overlay_v2.name = "SettlementOverlayV2"
	settlement_overlay_v2.top_level = true
	settlement_overlay_v2.z_index = 245
	settlement_overlay_v2.visible = false
	root_ui.add_child(settlement_overlay_v2)
	settlement_overlay_v2.connect("close_requested", _on_settlement_close_pressed)
	settlement_overlay_v2.connect("next_round_requested", _on_top_next_round_pressed)


func _setup_rich_settlement_overlay() -> void:
	settlement_overlay.top_level = true
	settlement_overlay.z_index = 245
	settlement_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settlement_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not settlement_close_button.pressed.is_connected(_on_settlement_close_pressed):
		settlement_close_button.pressed.connect(_on_settlement_close_pressed)
	if not next_round_button.pressed.is_connected(_on_next_round_pressed):
		next_round_button.pressed.connect(_on_next_round_pressed)
	if not root_ui.resized.is_connected(_queue_settlement_overlay_layout):
		root_ui.resized.connect(_queue_settlement_overlay_layout)
	call_deferred("_layout_settlement_overlay")


func _queue_settlement_overlay_layout() -> void:
	call_deferred("_layout_settlement_overlay")


func _layout_settlement_overlay() -> void:
	if settlement_panel == null or root_ui == null:
		return
	var viewport_size := root_ui.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var outer_margin := 10.0
	var compact_margin := 6.0
	var max_size := Vector2(
		minf(SETTLEMENT_PANEL_MAX_SIZE.x, maxf(0.0, viewport_size.x - outer_margin * 2.0)),
		minf(SETTLEMENT_PANEL_MAX_SIZE.y, maxf(0.0, viewport_size.y - outer_margin * 2.0))
	)
	var target_size := Vector2(
		clampf(viewport_size.x * SETTLEMENT_PANEL_SCREEN_RATIO.x, minf(SETTLEMENT_PANEL_MIN_SIZE.x, max_size.x), max_size.x),
		clampf(viewport_size.y * SETTLEMENT_PANEL_SCREEN_RATIO.y, minf(SETTLEMENT_PANEL_MIN_SIZE.y, max_size.y), max_size.y)
	)
	if viewport_size.x < 1700.0 or viewport_size.y < 940.0:
		target_size = Vector2(maxf(0.0, viewport_size.x - compact_margin * 2.0), maxf(0.0, viewport_size.y - compact_margin * 2.0))
	settlement_panel.custom_minimum_size = target_size
	settlement_panel.size = target_size

	var scale := clampf(target_size.y / 1000.0, 0.72, 1.30)
	settlement_layout_scale = scale
	_set_margin_constants(settlement_margin, 28.0 * scale, 12.0 * scale, 28.0 * scale, 16.0 * scale)
	_set_margin_constants(settlement_player_list_margin, 18.0 * scale, 18.0 * scale, 18.0 * scale, 18.0 * scale)
	_set_margin_constants(settlement_detail_margin, 20.0 * scale, 14.0 * scale, 20.0 * scale, 14.0 * scale)
	_set_margin_constants(settlement_hero_margin, 22.0 * scale, 14.0 * scale, 22.0 * scale, 14.0 * scale)
	_set_margin_constants(settlement_hand_margin, 14.0 * scale, 10.0 * scale, 14.0 * scale, 10.0 * scale)
	_set_margin_constants(settlement_breakdown_margin, 14.0 * scale, 10.0 * scale, 14.0 * scale, 10.0 * scale)
	settlement_vbox.add_theme_constant_override("separation", int(round(10.0 * scale)))
	settlement_content.add_theme_constant_override("separation", int(round(18.0 * scale)))
	settlement_player_list_vbox.add_theme_constant_override("separation", int(round(14.0 * scale)))
	settlement_player_list.add_theme_constant_override("separation", int(round(12.0 * scale)))
	settlement_detail_vbox.add_theme_constant_override("separation", int(round(10.0 * scale)))
	settlement_hero_row.add_theme_constant_override("separation", int(round(22.0 * scale)))
	settlement_hero_info.add_theme_constant_override("separation", int(round(9.0 * scale)))
	settlement_hero_stats.add_theme_constant_override("separation", int(round(22.0 * scale)))
	settlement_hand_row.add_theme_constant_override("separation", int(round(10.0 * scale)))
	settlement_breakdown_vbox.add_theme_constant_override("separation", int(round(8.0 * scale)))
	settlement_breakdown_list.add_theme_constant_override("separation", int(round(8.0 * scale)))
	settlement_player_list_card.custom_minimum_size = Vector2(maxf(292.0, target_size.x * 0.24), 0.0)
	settlement_hero_card.custom_minimum_size = Vector2(0.0, 148.0 * scale)
	settlement_hand_card.custom_minimum_size = Vector2(0.0, 190.0 * scale)
	settlement_breakdown_card.custom_minimum_size = Vector2(0.0, 330.0 * scale)
	settlement_close_button.custom_minimum_size = Vector2(124.0 * scale, 52.0 * scale)
	next_round_button.custom_minimum_size = Vector2(300.0 * scale, 82.0 * scale)


func _setup_discard_helper_panel() -> void:
	if root_ui == null:
		return
	discard_helper_panel = Panel.new()
	discard_helper_panel.name = "DiscardHelperPanel"
	discard_helper_panel.custom_minimum_size = Vector2(1320, 238)
	discard_helper_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_helper_panel.z_index = 160
	discard_helper_panel.top_level = true

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 20)
	discard_helper_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.visible = false
	box.add_child(header)

	discard_helper_title = Label.new()
	discard_helper_title.text = ""
	discard_helper_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_helper_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_helper_title.visible = false
	header.add_child(discard_helper_title)

	discard_helper_action_button = Button.new()
	discard_helper_action_button.name = "DiscardHelperActionButton"
	discard_helper_action_button.text = "选中推荐"
	discard_helper_action_button.custom_minimum_size = Vector2(112, 34)
	discard_helper_action_button.pressed.connect(_on_discard_helper_action_pressed)
	discard_helper_action_button.visible = false
	discard_helper_action_button.disabled = true
	header.add_child(discard_helper_action_button)

	discard_helper_summary = Label.new()
	discard_helper_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discard_helper_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_helper_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	discard_helper_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_helper_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(discard_helper_summary)

	discard_helper_compare = Label.new()
	discard_helper_compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discard_helper_compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_helper_compare.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	discard_helper_compare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_helper_compare.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_helper_compare.visible = false
	box.add_child(discard_helper_compare)

	discard_helper_options = Label.new()
	discard_helper_options.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discard_helper_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_helper_options.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	discard_helper_options.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_helper_options.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discard_helper_options.visible = false
	box.add_child(discard_helper_options)

	root_ui.add_child(discard_helper_panel)


func _setup_ai_assistant_drawer() -> void:
	if root_ui == null or ai_assistant_drawer != null:
		return
	ai_assistant_drawer = AI_ASSISTANT_SCENE.instantiate() as Control
	ai_assistant_drawer.name = "AIAssistantDrawer"
	ai_assistant_drawer.top_level = true
	ai_assistant_drawer.z_index = 228
	ai_assistant_drawer.visible = false
	root_ui.add_child(ai_assistant_drawer)
	ai_assistant_drawer.connect("toggle_requested", _on_ai_drawer_toggle_requested)
	ai_assistant_drawer.connect("recommendation_requested", _on_ai_recommendation_requested)
	ai_assistant_drawer.connect("opacity_changed", _on_ai_glass_opacity_changed)
	ai_assistant_drawer.connect("opacity_change_finished", _on_ai_glass_opacity_change_finished)
	ai_assistant_drawer.connect("position_changed", _on_ai_drawer_position_changed)
	ai_assistant_drawer.connect("position_change_finished", _on_ai_drawer_position_change_finished)
	ai_assistant_drawer.call("set_glass_opacity", ai_glass_opacity)
	ai_assistant_drawer.call("restore_user_position", ai_drawer_position_normalized, ai_drawer_positioned)
	if not root_ui.resized.is_connected(_layout_ai_assistant_drawer):
		root_ui.resized.connect(_layout_ai_assistant_drawer)
	if safe_area != null and not safe_area.resized.is_connected(_layout_ai_assistant_drawer):
		safe_area.resized.connect(_layout_ai_assistant_drawer)


func _layout_ai_assistant_drawer() -> void:
	if ai_assistant_drawer == null or root_ui == null or not ai_assistant_drawer.visible:
		return
	var margins := Vector4(24.0, 18.0, 24.0, 22.0)
	if safe_area != null and safe_area.has_method("get_safe_margins"):
		margins = safe_area.call("get_safe_margins")
	var desired_size := ai_assistant_drawer.custom_minimum_size
	var max_width := maxf(320.0, root_ui.size.x - margins.x - margins.z - 24.0)
	desired_size.x = minf(desired_size.x, max_width)
	ai_assistant_drawer.size = desired_size
	var drag_bounds := Rect2(
		Vector2(margins.x + 8.0, margins.y + 104.0),
		Vector2(
			maxf(desired_size.x, root_ui.size.x - margins.x - margins.z - 16.0),
			maxf(desired_size.y, root_ui.size.y - margins.y - margins.w - 116.0)
		)
	)
	ai_assistant_drawer.call("set_drag_bounds", drag_bounds)
	var hand_rect := self_hand_host.get_global_rect() if self_hand_host != null else Rect2()
	var root_origin := root_ui.global_position
	var target_x := (root_ui.size.x - desired_size.x) * 0.5
	var target_y := root_ui.size.y - margins.w - desired_size.y - 224.0
	if hand_rect.size.y > 1.0:
		var drawer_expanded := bool(ai_assistant_drawer.call("is_expanded"))
		# The expanded inspector is wider than the vertical gap between the centre
		# counter and the player's rack. Dock it to the rack's left edge so the
		# persistent 余牌/turn state stays unobstructed at every phone aspect.
		target_x = root_ui.size.x * 0.14 if drawer_expanded else hand_rect.get_center().x - root_origin.x - desired_size.x * 0.5
		if not drawer_expanded and root_ui.size.y >= 820.0:
			# Use the rendered tile bounds, not the much taller hand host. The host
			# starts inside the table and previously placed the rail over the second
			# discard row even though a clear gap existed above the tile faces.
			var hand_content_bounds: Rect2 = self_hand_host.call("get_hand_layout_bounds")
			var tile_top := hand_rect.position.y - root_origin.y + hand_content_bounds.position.y
			target_y = tile_top - desired_size.y - 10.0
		else:
			target_y = hand_rect.position.y - root_origin.y - desired_size.y - 16.0
		if not drawer_expanded:
			# Preserve a clean air gap above the actual 3D rack. The fallback hand
			# host is taller than the rendered tiles on some aspects, so the former
			# anchor could visually press the compact AI rail into the tile faces.
			target_y -= 96.0
	ai_assistant_drawer.call("place_default_position", Vector2(
		clampf(target_x, margins.x + 8.0, root_ui.size.x - margins.z - desired_size.x - 8.0),
		clampf(target_y, margins.y + 104.0, root_ui.size.y - margins.w - desired_size.y - 12.0)
	))


func _on_ai_drawer_toggle_requested(_expanded: bool) -> void:
	_layout_ai_assistant_drawer()


func _on_ai_glass_opacity_changed(opacity: float) -> void:
	ai_glass_opacity = clampf(opacity, 0.0, 1.0)


func _on_ai_glass_opacity_change_finished(opacity: float) -> void:
	ai_glass_opacity = clampf(opacity, 0.0, 1.0)
	_save_ui_preferences()


func _on_ai_drawer_position_changed(normalized_position: Vector2) -> void:
	ai_drawer_position_normalized = normalized_position
	ai_drawer_positioned = true


func _on_ai_drawer_position_change_finished(normalized_position: Vector2) -> void:
	ai_drawer_position_normalized = normalized_position
	ai_drawer_positioned = true
	_save_ui_preferences()


func _on_ai_recommendation_requested(tile_id: int) -> void:
	selected_tile_id = tile_id
	_on_snapshot_changed(game_manager.get_snapshot())


func _apply_discard_helper_style() -> void:
	if discard_helper_panel == null:
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.25, 0.20, 0.62)
	panel_style.border_color = Color(0.82, 0.95, 0.74, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 5)
	discard_helper_panel.add_theme_stylebox_override("panel", panel_style)
	discard_helper_title.visible = false
	discard_helper_title.add_theme_font_size_override("font_size", 1)
	discard_helper_title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 0.98))
	discard_helper_title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.90))
	discard_helper_title.add_theme_constant_override("outline_size", 0)
	discard_helper_summary.add_theme_font_size_override("font_size", 48)
	discard_helper_summary.add_theme_color_override("font_color", IVORY_SOFT)
	discard_helper_summary.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	discard_helper_summary.add_theme_constant_override("outline_size", 5)
	discard_helper_compare.add_theme_font_size_override("font_size", 34)
	discard_helper_compare.add_theme_color_override("font_color", Color(0.94, 0.99, 0.86, 0.99))
	discard_helper_compare.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.88))
	discard_helper_compare.add_theme_constant_override("outline_size", 3)
	discard_helper_options.add_theme_font_size_override("font_size", 26)
	discard_helper_options.add_theme_color_override("font_color", Color(0.79, 0.84, 0.81, 0.92))
	discard_helper_options.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	discard_helper_options.add_theme_constant_override("outline_size", 2)
	discard_helper_action_button.modulate = Color(1.0, 1.0, 1.0, 0.92)
	discard_helper_action_button.visible = false
	discard_helper_action_button.disabled = true


func _soften_table_panel(panel: Panel, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.10)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	panel.add_theme_stylebox_override("panel", style)


func _flatten_table_panel(panel: Panel, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)


func _apply_tabletop_matte_theme() -> void:
	if background_rect != null:
		background_rect.color = MATTE_FELT_BG
		_ensure_material_overlay(background_rect, "TableFeltSoftGlow", TABLE_MATERIAL_OVERLAY_SCRIPT.MaterialMode.FELT, 1.0)

	_apply_clear_panel(%TopBar)
	_apply_felt_panel(room_card, Color(0.012, 0.094, 0.082, 0.72), Color(0.659, 0.475, 0.227, 0.34), 18, 1, 8)
	_apply_felt_panel(info_card, Color(0.012, 0.094, 0.082, 0.78), Color(0.659, 0.475, 0.227, 0.38), 14, 1, 10)
	_ensure_material_overlay(info_card, "InfoCardSoftLight", TABLE_MATERIAL_OVERLAY_SCRIPT.MaterialMode.SOFT_PANEL, 0.80)

	_apply_clear_panel(center_card)
	_apply_felt_panel(center_stats_card, Color(0.012, 0.094, 0.082, 0.90), Color(0.725, 0.588, 0.333, 0.62), 16, 1, 5)
	_apply_felt_panel(center_hint_card, Color(0.012, 0.094, 0.082, 0.90), Color(0.725, 0.588, 0.333, 0.62), 16, 1, 5)
	_apply_clear_panel(board_area)
	_apply_clear_panel(board_square)
	_remove_material_overlay(board_square, "BoardFeltTexture")
	_apply_felt_panel(board_core, Color(0.012, 0.094, 0.082, 0.98), Color(0.725, 0.588, 0.333, 0.78), 14, 2, 10)
	_apply_clear_panel(center_meld_card)
	_apply_clear_panel(center_discard_card)
	_apply_clear_panel(%SelfSection)
	_apply_clear_panel(%TopRail)
	_apply_clear_panel(%LeftRail)
	_apply_clear_panel(%RightRail)
	_apply_v17_plate_styles()

	room_label.add_theme_color_override("font_color", IVORY_SOFT)
	center_info.add_theme_color_override("font_color", IVORY_SOFT)
	room_label.add_theme_font_size_override("font_size", 18)
	center_info.add_theme_font_size_override("font_size", 17)
	room_label.add_theme_constant_override("outline_size", 1)
	center_info.add_theme_constant_override("outline_size", 1)
	center_status.add_theme_color_override("font_color", IVORY_SOFT)
	center_dealer_label.add_theme_color_override("font_color", IVORY_SOFT)
	center_wall_label.add_theme_color_override("font_color", IVORY_SOFT)
	center_turn_label.add_theme_color_override("font_color", IVORY_SOFT)
	center_reaction_label.add_theme_color_override("font_color", IVORY_SOFT)
	center_hint_box.add_theme_color_override("font_color", Color(0.92, 0.96, 0.93, 1.0))
	board_core_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.89, 1.0))


func _apply_v17_plate_styles() -> void:
	for host in [player_self_host, self_hu_tile_host]:
		_hide_v17_host_backplate(host)


func _apply_v17_host_backplate(host: Control) -> void:
	if host == null:
		return
	var panel := host.get_node_or_null("V17Backplate") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "V17Backplate"
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(panel)
		host.move_child(panel, 0)
	STYLE_CONFIG.apply_plate_panel(panel, false, false)
	panel.clip_contents = true
	_ensure_material_overlay(panel, "V17HostSoftPlateLight", TABLE_MATERIAL_OVERLAY_SCRIPT.MaterialMode.SOFT_PANEL, 0.90)


func _hide_v17_host_backplate(host: Control) -> void:
	if host == null:
		return
	var panel := host.get_node_or_null("V17Backplate") as Panel
	if panel != null:
		panel.visible = false


func _apply_felt_panel(panel: Panel, bg: Color, border: Color, radius: int, border_width: int, shadow_size: int) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	var restrained_radius := mini(radius, 8)
	style.corner_radius_top_left = restrained_radius
	style.corner_radius_top_right = restrained_radius
	style.corner_radius_bottom_left = restrained_radius
	style.corner_radius_bottom_right = restrained_radius
	style.shadow_color = Color(0.0, 0.015, 0.010, 0.34)
	style.shadow_size = mini(shadow_size, 8)
	style.shadow_offset = Vector2(3.0, maxf(3.0, float(style.shadow_size) * 0.48))
	panel.add_theme_stylebox_override("panel", style)


func _apply_wood_frame_panel(panel: Panel, bg: Color, border: Color, radius: int, border_width: int, shadow_size: int) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	var restrained_radius := mini(radius, 8)
	style.corner_radius_top_left = restrained_radius
	style.corner_radius_top_right = restrained_radius
	style.corner_radius_bottom_left = restrained_radius
	style.corner_radius_bottom_right = restrained_radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)


func _apply_clear_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)


func _ensure_material_overlay(parent: Control, overlay_name: String, mode: int, overlay_opacity: float) -> void:
	if parent == null:
		return
	var overlay := parent.get_node_or_null(overlay_name) as Control
	if overlay == null:
		overlay = TABLE_MATERIAL_OVERLAY_SCRIPT.new()
		overlay.name = overlay_name
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(overlay)
		parent.move_child(overlay, 0)
	overlay.set("material_mode", mode)
	overlay.set("opacity", overlay_opacity)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0


func _ensure_button_gloss_overlay(button: Button, overlay_opacity: float = 0.80) -> void:
	if button == null:
		return
	_ensure_material_overlay(button, "ButtonGlossLight", TABLE_MATERIAL_OVERLAY_SCRIPT.MaterialMode.BUTTON_GLOSS, overlay_opacity)


func _ensure_circular_action_button_overlay(button: Button, overlay_name: String, primary: bool) -> void:
	if button == null:
		return
	var overlay := button.get_node_or_null(overlay_name) as Control
	if overlay == null:
		overlay = CIRCULAR_ACTION_BUTTON_OVERLAY_SCRIPT.new()
		overlay.name = overlay_name
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(overlay)
	overlay.set("primary", primary)
	overlay.set("label_text", button.text)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.move_to_front()


func _remove_material_overlay(parent: Control, overlay_name: String) -> void:
	if parent == null:
		return
	var existing := parent.get_node_or_null(overlay_name)
	if existing != null:
		existing.queue_free()


func _apply_opening_roll_ui_style(style: Resource) -> void:
	if die_a_face == null or die_b_face == null or dice_panel == null or dice_count_label == null:
		return
	if dice_panel.has_method("set"):
		dice_panel.set("outer_ring_color", Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.94))
		dice_panel.set("inner_ring_color", Color(0.34, 0.55, 0.38, 0.98))
		dice_panel.set("core_color", Color(0.13, 0.27, 0.21, 0.96))
		dice_panel.set("shadow_color", Color(0.00, 0.00, 0.00, 0.30))
		dice_panel.set("glow_color", Color(0.34, 0.55, 0.38, 0.18))
		dice_panel.set("hotspot_glow_color", Color(0.48, 0.66, 0.48, 0.16))
	STYLE_CONFIG.apply_label(dice_count_label, false, true)
	dice_count_label.custom_minimum_size = CENTER_WALL_COUNT_LABEL_SIZE
	dice_count_label.add_theme_font_size_override("font_size", CENTER_WALL_COUNT_FONT_SIZE)
	dice_count_label.add_theme_color_override("font_color", IVORY_SOFT)
	dice_count_label.add_theme_color_override("font_outline_color", Color(0.04, 0.10, 0.08, 0.96))
	dice_count_label.add_theme_constant_override("outline_size", 5)
	dice_count_label.add_theme_color_override("font_shadow_color", Color(0.00, 0.04, 0.03, 0.48))
	dice_count_label.add_theme_constant_override("shadow_offset_x", 0)
	dice_count_label.add_theme_constant_override("shadow_offset_y", 3)


func _apply_floating_action_button_styles() -> void:
	if floating_ai_tuning_button == null:
		return
	if floating_right_toggle_button != null:
		_apply_floating_action_button_style(floating_right_toggle_button, Color(0.06, 0.18, 0.14, 0.42), "收起/展开")
	if floating_left_toggle_button != null:
		_apply_ai_drawer_entry_button_style(floating_left_toggle_button)
	_apply_floating_action_button_style(floating_ai_tuning_button, Color(0.08, 0.34, 0.25, 0.90), "AI调参")
	_apply_floating_action_button_style(floating_ai_helper_button, Color(0.10, 0.40, 0.29, 0.90) if ai_helper_enabled else Color(0.09, 0.28, 0.22, 0.82), "AI辅助")
	_apply_floating_action_button_style(floating_opponent_hand_button, Color(0.10, 0.36, 0.27, 0.90) if opponent_hands_enabled else Color(0.09, 0.28, 0.22, 0.82), "明牌模式")
	if floating_hell_mark_button != null:
		_apply_floating_action_button_style(floating_hell_mark_button, Color(0.56, 0.25, 0.10, 0.92), "标记这手")
	if floating_diagnostic_export_button != null:
		_apply_floating_action_button_style(floating_diagnostic_export_button, Color(0.16, 0.33, 0.48, 0.90), "导出诊断")
	if floating_preset_button != null:
		_apply_floating_action_button_style(floating_preset_button, Color(0.10, 0.34, 0.25, 0.88), "AI预设")
	if floating_exit_button != null:
		_apply_floating_action_button_style(floating_exit_button, Color(0.55, 0.21, 0.18, 0.88), "退出牌局")


func _apply_floating_action_button_style(button: Button, bg: Color, tooltip: String) -> void:
	if button == null:
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = AI_DRAWER_ITEM_SIZE
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg.lightened(0.10)
	normal.border_color = Color(1.0, 0.96, 0.68, 0.30)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.shadow_color = Color(0.0, 0.08, 0.05, 0.28)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.18)
	hover.border_color = Color(1.0, 0.98, 0.76, 0.64)
	hover.shadow_size = 15

	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.08)
	pressed.border_color = Color(0.94, 0.84, 0.54, 0.42)
	pressed.shadow_size = 5
	pressed.shadow_offset = Vector2(0, 1)
	pressed.content_margin_top = 4
	pressed.content_margin_bottom = 0

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.99, 0.98, 0.88, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.09, 0.94))
	button.add_theme_constant_override("outline_size", 2)
	button.tooltip_text = tooltip
	_ensure_button_gloss_overlay(button, 0.42)


func _apply_ai_drawer_entry_button_style(button: Button) -> void:
	if button == null:
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = AI_DRAWER_ENTRY_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.15, 0.12, 0.72)
	style.border_color = Color(1.0, 0.96, 0.68, 0.38)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 39
	style.corner_radius_top_right = 39
	style.corner_radius_bottom_left = 39
	style.corner_radius_bottom_right = 39
	style.shadow_color = Color(0.0, 0.08, 0.05, 0.30)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	var hover := style.duplicate()
	hover.bg_color = Color(0.06, 0.20, 0.16, 0.82)
	hover.border_color = Color(1.0, 0.96, 0.68, 0.56)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", IVORY_SOFT)
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.10, 0.08, 0.92))
	button.add_theme_constant_override("outline_size", 2)
	button.tooltip_text = "AI 工具"
	_ensure_button_gloss_overlay(button, 0.36)


func _update_floating_button_texts() -> void:
	if floating_right_toggle_button != null:
		floating_right_toggle_button.visible = false
	if floating_left_toggle_button != null:
		floating_left_toggle_button.text = "AI"
	if floating_preset_button != null:
		floating_preset_button.text = "难度 %s" % _current_ai_preset_short_label()
		floating_preset_button.visible = not floating_left_buttons_collapsed
	if floating_ai_tuning_button != null:
		floating_ai_tuning_button.text = "调参"
		floating_ai_tuning_button.visible = not RELEASE_USER_BUILD_UI and not floating_left_buttons_collapsed
	if floating_ai_helper_button != null:
		floating_ai_helper_button.text = "辅助 %s" % ("开" if ai_helper_enabled else "关")
		floating_ai_helper_button.visible = not floating_left_buttons_collapsed
	if floating_opponent_hand_button != null:
		floating_opponent_hand_button.text = "明牌 %s" % ("开" if opponent_hands_enabled else "关")
		floating_opponent_hand_button.visible = not floating_left_buttons_collapsed
	if floating_hell_mark_button != null:
		var snapshot := game_manager.get_snapshot()
		floating_hell_mark_button.text = "标记"
		floating_hell_mark_button.visible = not RELEASE_USER_BUILD_UI and not floating_left_buttons_collapsed and bool(snapshot.get("hell_training", {}).get("enabled", false))
	if floating_diagnostic_export_button != null:
		floating_diagnostic_export_button.text = "导出"
		floating_diagnostic_export_button.visible = _is_diagnostic_export_ui_enabled() and not floating_left_buttons_collapsed
	if floating_exit_button != null:
		floating_exit_button.visible = false
	_apply_floating_action_button_styles()


func _current_ai_preset_short_label() -> String:
	if game_manager == null:
		return "骨灰"
	var snapshot := game_manager.get_snapshot()
	var preset_name := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
	return str(AI_PRESET_LABELS.get(preset_name, "骨灰"))


func _update_board_core_hud(snapshot: Dictionary) -> void:
	if board_core_count_label == null:
		return
	var wall_count := int(snapshot.get("wall_count", 0))
	board_core_count_label.text = str(maxi(0, wall_count))
	for wind_label in [board_core_wind_top, board_core_wind_right, board_core_wind_bottom, board_core_wind_left]:
		wind_label.text = ""
		wind_label.visible = false
	var dealer_seat := int(snapshot.get("current_dealer_seat", 0))
	var turn_seat := int(snapshot.get("current_turn_seat", 0))
	var reaction_text := str(snapshot.get("reaction_summary", "-"))
	var recent_discard := str(snapshot.get("recent_discard_display", "-"))
	board_core_status_chip.text = "庄%s · %s" % [_seat_name(dealer_seat), _seat_name(turn_seat)]
	board_core_recent_chip.text = "出%s" % recent_discard if recent_discard != "-" else "待出牌"
	board_core_status_chip.visible = false
	board_core_recent_chip.visible = false
	if board_core_status_chip.get_theme_stylebox("normal") is StyleBoxFlat:
		var style := board_core_status_chip.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.bg_color = Color(0.10, 0.38, 0.29, 0.88) if reaction_text == "-" else Color(0.14, 0.42, 0.31, 0.90)
		board_core_status_chip.add_theme_stylebox_override("normal", style)


func _apply_round_result_overlay_style() -> void:
	if round_result_banner == null:
		return
	STYLE_CONFIG.apply_label(round_result_banner, false, true)
	round_result_banner.add_theme_font_size_override("font_size", 34)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.88, 0.18, 0.16, 0.94)
	banner_style.border_color = Color(1.0, 0.92, 0.76, 0.95)
	banner_style.set_border_width_all(3)
	banner_style.corner_radius_top_left = 20
	banner_style.corner_radius_top_right = 20
	banner_style.corner_radius_bottom_left = 20
	banner_style.corner_radius_bottom_right = 20
	banner_style.content_margin_left = 18
	banner_style.content_margin_right = 18
	banner_style.content_margin_top = 10
	banner_style.content_margin_bottom = 10
	banner_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	banner_style.shadow_size = 8
	banner_style.shadow_offset = Vector2(0, 3)
	round_result_banner.add_theme_stylebox_override("normal", banner_style)

	for label in seat_result_labels.values():
		var typed := label as Label
		STYLE_CONFIG.apply_label(typed, false, true)
		typed.add_theme_font_size_override("font_size", 24)


func _mount_player_ui(host: Control, dock: int):
	var node = PLAYER_UI_SCENE.instantiate()
	node.seat_dock = dock
	host.add_child(node)
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _setup_board_core_hud() -> void:
	if board_core == null or board_core_stack != null:
		return
	board_core.visible = true
	if board_core_label != null and is_instance_valid(board_core_label):
		board_core_label.visible = false

	var core_root := Control.new()
	core_root.name = "BoardCoreHud"
	core_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	core_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_core.add_child(core_root)
	board_core_stack = core_root

	board_core_count_label = Label.new()
	board_core_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_core_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board_core_count_label.custom_minimum_size = Vector2(84, 52)
	board_core_count_label.anchor_left = 0.5
	board_core_count_label.anchor_top = 0.5
	board_core_count_label.anchor_right = 0.5
	board_core_count_label.anchor_bottom = 0.5
	board_core_count_label.offset_left = -42
	board_core_count_label.offset_top = -28
	board_core_count_label.offset_right = 42
	board_core_count_label.offset_bottom = 24
	STYLE_CONFIG.apply_label(board_core_count_label, false, true)
	board_core_count_label.add_theme_font_size_override("font_size", 34)
	board_core_count_label.add_theme_color_override("font_color", Color(0.48, 0.90, 1.0, 1.0))
	board_core_count_label.add_theme_color_override("font_outline_color", Color(0.10, 0.18, 0.24, 0.96))
	board_core_count_label.add_theme_constant_override("outline_size", 2)
	core_root.add_child(board_core_count_label)

	board_core_wind_top = _create_board_core_wind_label("北", Vector2(0.5, 0.0), Vector2(-24, -30), Vector2(48, 34))
	board_core_wind_right = _create_board_core_wind_label("东", Vector2(1.0, 0.5), Vector2(16, -17), Vector2(38, 34))
	board_core_wind_bottom = _create_board_core_wind_label("南", Vector2(0.5, 1.0), Vector2(-24, 12), Vector2(48, 34))
	board_core_wind_left = _create_board_core_wind_label("西", Vector2(0.0, 0.5), Vector2(-30, -17), Vector2(38, 34))
	for node in [board_core_wind_top, board_core_wind_right, board_core_wind_bottom, board_core_wind_left]:
		node.text = ""
		node.visible = false
		core_root.add_child(node)

	board_core_status_chip = _create_board_core_chip(Vector2(0.5, 1.0), Vector2(42, 10), Vector2(96, 34))
	board_core_recent_chip = _create_board_core_chip(Vector2(0.5, 1.0), Vector2(-140, 10), Vector2(126, 34))
	core_root.add_child(board_core_status_chip)
	core_root.add_child(board_core_recent_chip)
	board_core_status_chip.visible = false
	board_core_recent_chip.visible = false


func _setup_seat_huds() -> void:
	if root_ui == null or not seat_huds.is_empty():
		return
	for seat in [0, 1, 2, 3]:
		var seat_hud := SEAT_HUD_SCENE.instantiate() as Control
		seat_hud.name = "SeatHUD%d" % seat
		seat_hud.top_level = true
		seat_hud.z_index = 120
		seat_hud.configure_seat(seat)
		root_ui.add_child(seat_hud)
		seat_huds[seat] = seat_hud


func _setup_table_utility_bar() -> void:
	if root_ui == null or table_utility_bar != null:
		return
	table_utility_bar = TABLE_UTILITY_BAR_SCENE.instantiate() as Control
	table_utility_bar.name = "TableUtilityBar"
	table_utility_bar.top_level = true
	table_utility_bar.z_index = 230
	root_ui.add_child(table_utility_bar)
	table_utility_bar.connect("ai_pressed", _on_top_ai_helper_button_pressed)
	table_utility_bar.connect("settings_pressed", _on_top_bar_button_pressed)
	table_utility_bar.connect("opponent_hands_pressed", _on_top_opponent_hand_button_pressed)
	table_utility_bar.connect("settlement_pressed", _on_top_settlement_info_pressed)
	table_utility_bar.connect("next_round_pressed", _on_top_next_round_pressed)
	table_utility_bar.connect("exit_pressed", _on_top_exit_pressed)
	if not root_ui.resized.is_connected(_layout_table_utility_bar):
		root_ui.resized.connect(_layout_table_utility_bar)
	if safe_area != null and not safe_area.resized.is_connected(_layout_table_utility_bar):
		safe_area.resized.connect(_layout_table_utility_bar)
	call_deferred("_layout_table_utility_bar")


func _setup_table_action_bar() -> void:
	if root_ui == null or table_action_bar != null:
		return
	table_action_bar = TABLE_ACTION_BAR_SCENE.instantiate() as Control
	table_action_bar.name = "TableActionBar"
	table_action_bar.top_level = true
	table_action_bar.z_index = 225
	root_ui.add_child(table_action_bar)
	table_action_bar.connect("action_selected", _on_table_action_selected)
	if not root_ui.resized.is_connected(_queue_table_action_bar_layout):
		root_ui.resized.connect(_queue_table_action_bar_layout)
	if safe_area != null and not safe_area.resized.is_connected(_queue_table_action_bar_layout):
		safe_area.resized.connect(_queue_table_action_bar_layout)
	call_deferred("_layout_table_action_bar")


func _setup_table_presentation_director() -> void:
	if table_presentation_director != null:
		return
	table_presentation_director = TABLE_PRESENTATION_DIRECTOR_SCRIPT.new() as Node
	table_presentation_director.name = "TablePresentationDirector"
	add_child(table_presentation_director)
	table_presentation_director.call(
		"set_reduced_motion",
		bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	)


func _queue_table_action_bar_layout() -> void:
	call_deferred("_layout_table_action_bar")


func _layout_table_action_bar() -> void:
	if table_action_bar == null or root_ui == null or not table_action_bar.visible:
		return
	var margins := Vector4(24.0, 18.0, 24.0, 22.0)
	if safe_area != null and safe_area.has_method("get_safe_margins"):
		margins = safe_area.call("get_safe_margins")
	var desired_size := table_action_bar.custom_minimum_size
	table_action_bar.size = desired_size
	var target_y := root_ui.size.y - desired_size.y - margins.w - 220.0
	if table_3d_enabled:
		# The legacy 2D hand host is deliberately hidden in 3D mode; using its stale
		# rectangle could place Hu/Cancel behind the real 3D hand on some phones.
		# The real 3D rack begins around 76% of the design height, so reserve 22.5%
		# below the decision bar. This keeps even the four-action compact profile
		# above the projected tile bounds instead of overlapping their right edge.
		target_y = root_ui.size.y - desired_size.y - margins.w - maxf(180.0, root_ui.size.y * 0.225)
	else:
		var hand_rect := self_hand_host.get_global_rect() if self_hand_host != null else Rect2()
		if hand_rect.size.y > 1.0:
			target_y = hand_rect.position.y - desired_size.y - 18.0
	table_action_bar.position = Vector2(
		maxf(margins.x, root_ui.size.x - margins.z - desired_size.x - 46.0),
		clampf(target_y, margins.y + 82.0, root_ui.size.y - margins.w - desired_size.y)
	)


func _layout_table_utility_bar() -> void:
	if table_utility_bar == null or root_ui == null:
		return
	table_utility_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margins := Vector4(24.0, 18.0, 24.0, 22.0)
	if safe_area != null and safe_area.has_method("get_safe_margins"):
		margins = safe_area.call("get_safe_margins")
	table_utility_bar.call("set_safe_margins", margins)
func _setup_self_hu_tile_host() -> void:
	if root_ui == null or self_hu_tile_host != null:
		return
	self_hu_tile_host = Control.new()
	self_hu_tile_host.name = "SelfHuTileHost"
	self_hu_tile_host.top_level = true
	self_hu_tile_host.z_index = 26
	self_hu_tile_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(self_hu_tile_host)


func _create_board_core_wind_label(text: String, anchor: Vector2, offset: Vector2, box_size: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.offset_left = offset.x
	label.offset_top = offset.y
	label.offset_right = offset.x + box_size.x
	label.offset_bottom = offset.y + box_size.y
	STYLE_CONFIG.apply_label(label, false, false)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.92, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.16, 0.15, 0.92))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _create_board_core_chip(anchor: Vector2, offset: Vector2, box_size: Vector2) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.offset_left = offset.x
	label.offset_top = offset.y
	label.offset_right = offset.x + box_size.x
	label.offset_bottom = offset.y + box_size.y
	STYLE_CONFIG.apply_label(label, true, false)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.38, 0.29, 0.88)
	style.border_color = Color(0.86, 0.94, 0.90, 0.16)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.97, 0.98, 0.94, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.14, 0.11, 0.84))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _setup_floating_action_buttons() -> void:
	if root_ui == null or floating_right_button_bar != null:
		return
	floating_right_button_bar = VBoxContainer.new()
	floating_right_button_bar.name = "FloatingRightButtonBar"
	floating_right_button_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	floating_right_button_bar.top_level = true
	floating_right_button_bar.z_index = 120
	floating_right_button_bar.add_theme_constant_override("separation", 18)
	root_ui.add_child(floating_right_button_bar)

	floating_right_toggle_button = _create_floating_circle_button("-")
	floating_right_toggle_button.pressed.connect(_toggle_right_floating_buttons)
	floating_right_button_bar.add_child(floating_right_toggle_button)
	floating_ai_helper_button = _create_floating_circle_button("辅")
	floating_ai_helper_button.pressed.connect(_on_top_ai_helper_button_pressed)
	floating_right_button_bar.add_child(floating_ai_helper_button)
	if not RELEASE_USER_BUILD_UI:
		floating_ai_tuning_button = _create_floating_circle_button("调")
		floating_opponent_hand_button = _create_floating_circle_button("明")
		floating_ai_tuning_button.pressed.connect(_on_top_ai_tuning_button_pressed)
		floating_opponent_hand_button.pressed.connect(_on_top_opponent_hand_button_pressed)
		floating_right_button_bar.add_child(floating_ai_tuning_button)
		floating_right_button_bar.add_child(floating_opponent_hand_button)

	if not root_ui.resized.is_connected(_position_floating_action_buttons):
		root_ui.resized.connect(_position_floating_action_buttons)
	call_deferred("_position_floating_action_buttons")


func _setup_left_floating_buttons() -> void:
	if root_ui == null or floating_left_button_bar != null:
		return
	floating_left_button_bar = VBoxContainer.new()
	floating_left_button_bar.name = "FloatingLeftButtonBar"
	floating_left_button_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	floating_left_button_bar.top_level = true
	floating_left_button_bar.z_index = 180
	floating_left_button_bar.add_theme_constant_override("separation", 14)
	root_ui.add_child(floating_left_button_bar)

	floating_left_toggle_button = _create_floating_circle_button("➕")
	floating_left_toggle_button.pressed.connect(_toggle_left_floating_buttons)
	floating_left_button_bar.add_child(floating_left_toggle_button)
	floating_preset_button = _create_floating_circle_button("难度")
	floating_ai_tuning_button = _create_floating_circle_button("调")
	floating_ai_helper_button = _create_floating_circle_button("辅")
	floating_opponent_hand_button = _create_floating_circle_button("明")
	floating_hell_mark_button = _create_floating_circle_button("标")
	floating_diagnostic_export_button = null
	floating_exit_button = null
	floating_preset_button.pressed.connect(_on_top_bar_button_pressed)
	if not RELEASE_USER_BUILD_UI:
		floating_ai_tuning_button.pressed.connect(_on_top_ai_tuning_button_pressed)
	floating_ai_helper_button.pressed.connect(_on_top_ai_helper_button_pressed)
	floating_opponent_hand_button.pressed.connect(_on_top_opponent_hand_button_pressed)
	if not RELEASE_USER_BUILD_UI:
		floating_hell_mark_button.pressed.connect(_on_hell_mark_button_pressed)
	if _is_diagnostic_export_ui_enabled():
		floating_diagnostic_export_button = _create_floating_circle_button("导")
		floating_diagnostic_export_button.pressed.connect(_on_diagnostic_export_button_pressed)
	floating_left_button_bar.add_child(floating_ai_helper_button)
	floating_left_button_bar.add_child(floating_opponent_hand_button)
	floating_left_button_bar.add_child(floating_hell_mark_button)
	if floating_diagnostic_export_button != null:
		floating_left_button_bar.add_child(floating_diagnostic_export_button)
	floating_left_button_bar.add_child(floating_preset_button)
	floating_left_button_bar.add_child(floating_ai_tuning_button)

	if not root_ui.resized.is_connected(_position_left_floating_buttons):
		root_ui.resized.connect(_position_left_floating_buttons)
	call_deferred("_position_left_floating_buttons")


func _create_floating_circle_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(74, 74)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	return button


func _is_diagnostic_export_ui_enabled() -> bool:
	if RELEASE_USER_BUILD_UI:
		return false
	return DIAGNOSTIC_EXPORT_UI_ENABLED or (DEBUG_DIAGNOSTIC_EXPORT_UI_ENABLED and OS.is_debug_build())


func _position_floating_action_buttons() -> void:
	if root_ui == null or floating_right_button_bar == null:
		return
	var total_height := floating_right_button_bar.get_combined_minimum_size().y
	floating_right_button_bar.position = Vector2(
		root_ui.size.x - 96.0,
		118.0
	)


func _position_left_floating_buttons() -> void:
	if root_ui == null or floating_left_button_bar == null:
		return
	floating_left_button_bar.position = Vector2(
		AI_DRAWER_MARGIN.x,
		AI_DRAWER_MARGIN.y
	)


func _toggle_right_floating_buttons() -> void:
	floating_right_buttons_collapsed = not floating_right_buttons_collapsed
	_update_floating_button_texts()
	_position_floating_action_buttons()


func _toggle_left_floating_buttons() -> void:
	floating_left_buttons_collapsed = not floating_left_buttons_collapsed
	_update_floating_button_texts()
	_position_left_floating_buttons()


func _handle_left_floating_toggle_click(global_pos: Vector2) -> bool:
	if floating_left_toggle_button == null or not is_instance_valid(floating_left_toggle_button):
		return false
	if not floating_left_toggle_button.visible:
		return false
	var toggle_rect := floating_left_toggle_button.get_global_rect()
	if toggle_rect.size.x <= 1.0 or toggle_rect.size.y <= 1.0:
		toggle_rect = Rect2(
			floating_left_button_bar.global_position,
			floating_left_toggle_button.custom_minimum_size
		)
	if not toggle_rect.has_point(global_pos):
		return false
	_toggle_left_floating_buttons()
	return true


func _handle_left_floating_action_click(global_pos: Vector2) -> bool:
	if floating_left_buttons_collapsed:
		return false
	var targets := [
		{"button": floating_ai_helper_button, "action": Callable(self, "_on_top_ai_helper_button_pressed")},
		{"button": floating_opponent_hand_button, "action": Callable(self, "_on_top_opponent_hand_button_pressed")},
		{"button": floating_hell_mark_button, "action": Callable(self, "_on_hell_mark_button_pressed")},
		{"button": floating_preset_button, "action": Callable(self, "_on_top_bar_button_pressed")},
		{"button": floating_ai_tuning_button, "action": Callable(self, "_on_top_ai_tuning_button_pressed")},
	]
	if _is_diagnostic_export_ui_enabled() and floating_diagnostic_export_button != null:
		targets.insert(3, {"button": floating_diagnostic_export_button, "action": Callable(self, "_on_diagnostic_export_button_pressed")})
	for entry in targets:
		var button: Button = entry.get("button", null)
		var action: Callable = entry.get("action", Callable())
		if button == null or not is_instance_valid(button) or not action.is_valid():
			continue
		if not button.visible:
			continue
		var rect := button.get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		if rect.has_point(global_pos):
			action.call()
			return true
	return false


func _handle_ai_tuning_overlay_click(global_pos: Vector2) -> bool:
	if ai_tuning_overlay == null or not ai_tuning_overlay.visible:
		return false
	if ai_tuning_close_button != null and is_instance_valid(ai_tuning_close_button):
		var close_rect := ai_tuning_close_button.get_global_rect()
		if close_rect.size.x > 1.0 and close_rect.size.y > 1.0 and close_rect.has_point(global_pos):
			_close_ai_tuning_overlay()
			return true
	if floating_ai_tuning_button != null and is_instance_valid(floating_ai_tuning_button):
		var tuning_rect := floating_ai_tuning_button.get_global_rect()
		if tuning_rect.size.x > 1.0 and tuning_rect.size.y > 1.0 and tuning_rect.has_point(global_pos):
			_on_top_ai_tuning_button_pressed()
			return true
	for entry in ai_tuning_click_actions:
		var target: Control = entry.get("control", null)
		var action: Callable = entry.get("action", Callable())
		if target == null or not is_instance_valid(target) or not action.is_valid():
			continue
		if not target.visible or target.disabled:
			continue
		var target_rect := target.get_global_rect()
		if target_rect.size.x <= 1.0 or target_rect.size.y <= 1.0:
			continue
		if target_rect.has_point(global_pos):
			action.call()
			return true
	return false


func _handle_ai_tuning_drag_press(global_pos: Vector2) -> bool:
	if ai_tuning_overlay == null or not ai_tuning_overlay.visible or ai_tuning_panel == null or ai_tuning_title_label == null:
		return false
	var title_rect := ai_tuning_title_label.get_global_rect()
	if title_rect.size.x <= 1.0 or title_rect.size.y <= 1.0 or not title_rect.has_point(global_pos):
		return false
	ai_tuning_dragging = true
	ai_tuning_panel_moved = true
	ai_tuning_drag_offset = global_pos - ai_tuning_panel.global_position
	return true


func _register_ai_tuning_click_action(control: Control, action: Callable) -> void:
	if control == null or not action.is_valid():
		return
	ai_tuning_click_actions.append({
		"control": control,
		"action": action,
	})


func _on_snapshot_changed(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_recover_stale_draw_transition(snapshot)
	var previous_snapshot := last_snapshot.duplicate(true)
	last_snapshot = snapshot.duplicate(true)
	if table_presentation_director != null:
		table_presentation_director.consume_snapshot(previous_snapshot, snapshot)

	var players: Array = snapshot.get("players", [])
	var current_turn_seat := int(snapshot.get("current_turn_seat", -1))
	var current_dealer_seat := int(snapshot.get("current_dealer_seat", -1))
	var show_opponent_ding_que := _should_show_ding_que_badges(snapshot)
	var self_player := _player_by_seat(players, 0)
	var self_hand_tiles: Array = game_manager.game_state.call("get_player_hand_tiles", 0)

	if selected_tile_id != -1 and not _hand_contains_tile(self_hand_tiles, selected_tile_id):
		selected_tile_id = -1

	self_ui.apply_snapshot(self_player, false, current_turn_seat, current_dealer_seat, true)
	left_ui.apply_snapshot(_player_by_seat(players, 1), not opponent_hands_enabled, current_turn_seat, current_dealer_seat, show_opponent_ding_que)
	top_ui.apply_snapshot(_player_by_seat(players, 2), not opponent_hands_enabled, current_turn_seat, current_dealer_seat, show_opponent_ding_que)
	right_ui.apply_snapshot(_player_by_seat(players, 3), not opponent_hands_enabled, current_turn_seat, current_dealer_seat, show_opponent_ding_que)
	_update_seat_huds(snapshot)

	_update_top_bar(snapshot)
	_update_center_area(snapshot, players, self_player)
	_update_self_area(snapshot, self_hand_tiles)
	_refresh_action_panel(snapshot)
	_refresh_ding_que_panel(snapshot)
	_refresh_settlement(snapshot)
	_refresh_ai_tuning_panel(snapshot)
	_refresh_round_result_overlay(snapshot)
	_schedule_ai_progress_if_needed(snapshot)
	_layout_table_action_bar()
	_refresh_opening_roll_ui(snapshot)
	_handle_audio_transitions(previous_snapshot, snapshot)

	if bool(snapshot.get("opening_roll_pending", false)):
		var opening_roll: Dictionary = snapshot.get("opening_roll", {})
		if not opening_roll.is_empty():
			_start_opening_roll_animation_if_needed(opening_roll)
	_apply_embedded_ui_font()


func _apply_embedded_ui_font() -> void:
	STYLE_CONFIG.apply_font_tree(self)


func _handle_audio_transitions(previous_snapshot: Dictionary, snapshot: Dictionary) -> void:
	var previous_round := int(previous_snapshot.get("round_index", -1))
	var current_round := int(snapshot.get("round_index", -1))
	if previous_snapshot.is_empty() or previous_round != current_round:
		_assign_voice_profiles_for_round(snapshot)

	var previous_phase := int(previous_snapshot.get("current_phase", -1))
	var current_phase := int(snapshot.get("current_phase", -1))
	if previous_phase != 7 and current_phase == 7:
		_play_settlement_result(snapshot)

	var previous_discard_count := int(previous_snapshot.get("discard_count", 0))
	var current_discard_count := int(snapshot.get("discard_count", 0))
	var previous_recent_discard_id := int(previous_snapshot.get("recent_discard_tile_id", -1))
	var current_recent_discard_id := int(snapshot.get("recent_discard_tile_id", -1))
	if current_discard_count > previous_discard_count and current_recent_discard_id != -1 and current_recent_discard_id != previous_recent_discard_id:
		var discard_event := _find_discard_event(snapshot.get("players", []), current_recent_discard_id)
		if not discard_event.is_empty():
			_schedule_tile_voice_after_render(discard_event.get("tile", {}), int(discard_event.get("seat", 0)))

	var previous_recent_draw := str(previous_snapshot.get("recent_draw_display", ""))
	var current_recent_draw := str(snapshot.get("recent_draw_display", ""))
	if current_recent_draw != "" and current_recent_draw != "-" and current_recent_draw != previous_recent_draw:
		var draw_seat := int(snapshot.get("recent_draw_seat", -1))
		if draw_seat == -1:
			draw_seat = _parse_recent_draw_seat(current_recent_draw)
		if draw_seat >= 0:
			_begin_draw_transition(draw_seat, snapshot)

	var previous_players: Array = previous_snapshot.get("players", [])
	var current_players: Array = snapshot.get("players", [])
	_play_new_meld_voice(previous_players, current_players)
	_play_new_win_voice(previous_snapshot, snapshot)


func _play_settlement_result(snapshot: Dictionary) -> void:
	var settlement_data: Dictionary = snapshot.get("settlement_data", {})
	var score_changes: Dictionary = settlement_data.get("score_changes", {})
	var round_delta := int(score_changes.get(0, 0))
	if round_delta > 0:
		_play_result("win")
	elif round_delta < 0:
		_play_result("lose")


func _find_discard_event(players: Array, tile_id: int) -> Dictionary:
	for player in players:
		for tile in player.get("discards", []):
			if int(tile.get("id", -1)) == tile_id:
				return {
					"seat": int(player.get("seat", 0)),
					"tile": tile,
				}
	return {}


func _parse_recent_draw_seat(display_text: String) -> int:
	if not display_text.begins_with("Seat "):
		return -1
	var seat_part := display_text.get_slice(":", 0).trim_suffix(":")
	return int(seat_part.trim_prefix("Seat ").strip_edges())


func _begin_draw_transition(draw_seat: int, snapshot: Dictionary) -> void:
	draw_transition_active = true
	var is_ai_draw := _is_ai_seat(snapshot, draw_seat)
	if is_ai_draw:
		ai_turn_timer.stop()
		ai_reaction_timer.stop()
	else:
		ai_turn_timer.stop()
		ai_reaction_timer.stop()
	_play_system_audio(SYSTEM_DRAW_AUDIO_PATH, "1.0", SYSTEM_DRAW_AUDIO_SECONDS)
	var wait_seconds := SYSTEM_DRAW_ACTION_DELAY if is_ai_draw else HUMAN_DRAW_ACTION_DELAY
	draw_transition_started_at_ms = Time.get_ticks_msec()
	draw_transition_expected_ms = int(round(wait_seconds * 1000.0))
	if draw_transition_timer != null:
		draw_transition_timer.stop()
		draw_transition_timer.wait_time = wait_seconds
		draw_transition_timer.start()


func _recover_stale_draw_transition(snapshot: Dictionary) -> void:
	if not draw_transition_active:
		return
	var current_phase := int(snapshot.get("current_phase", -1))
	if current_phase == GameState.RoundPhase.REACTION:
		_clear_draw_transition_block("entered_reaction_phase")
		return
	var human_can_discard := bool(snapshot.get("human_can_discard", false))
	var current_turn_seat := int(snapshot.get("current_turn_seat", -1))
	var timer_running := draw_transition_timer != null and not draw_transition_timer.is_stopped()
	var elapsed_ms := maxi(0, Time.get_ticks_msec() - draw_transition_started_at_ms)
	if current_phase == GameState.RoundPhase.DISCARD and human_can_discard and current_turn_seat == 0:
		var expected_ms := maxi(draw_transition_expected_ms, int(round(HUMAN_DRAW_ACTION_DELAY * 1000.0)))
		if not timer_running or elapsed_ms >= expected_ms + 120:
			draw_transition_active = false
			draw_transition_started_at_ms = 0
			draw_transition_expected_ms = 0
			if timer_running and draw_transition_timer != null:
				draw_transition_timer.stop()
		return
	if current_phase == GameState.RoundPhase.DISCARD and game_manager.is_ai_turn_ready():
		var expected_ms := maxi(draw_transition_expected_ms, int(round(SYSTEM_DRAW_ACTION_DELAY * 1000.0)))
		if not timer_running or elapsed_ms >= expected_ms + 180:
			draw_transition_active = false
			draw_transition_started_at_ms = 0
			draw_transition_expected_ms = 0
			if timer_running and draw_transition_timer != null:
				draw_transition_timer.stop()
		return
	if not timer_running:
		draw_transition_active = false
		draw_transition_started_at_ms = 0
		draw_transition_expected_ms = 0


func _clear_draw_transition_block(reason: String = "") -> void:
	if not draw_transition_active:
		return
	draw_transition_active = false
	draw_transition_started_at_ms = 0
	draw_transition_expected_ms = 0
	if draw_transition_timer != null and not draw_transition_timer.is_stopped():
		draw_transition_timer.stop()
	if not reason.is_empty():
		print("[MainSceneV2] cleared stale draw transition: ", reason)


func _is_ai_seat(snapshot: Dictionary, seat: int) -> bool:
	for player in snapshot.get("players", []):
		if int(player.get("seat", -1)) == seat:
			return bool(player.get("is_ai", false))
	return false


func _play_new_meld_voice(previous_players: Array, current_players: Array) -> void:
	for seat in range(4):
		var previous_player := _player_by_seat(previous_players, seat)
		var current_player := _player_by_seat(current_players, seat)
		var previous_melds: Array = previous_player.get("melds", [])
		var current_melds: Array = current_player.get("melds", [])
		if current_melds.size() > previous_melds.size():
			var latest_meld: Dictionary = current_melds[current_melds.size() - 1]
			var meld_type := str(latest_meld.get("type", ""))
			match meld_type:
				"peng":
					_speak_action("碰", seat)
				"gang":
					_speak_action("杠", seat)
			return
		if current_melds.size() != previous_melds.size():
			continue
		for index in range(current_melds.size()):
			var previous_meld: Dictionary = previous_melds[index]
			var current_meld: Dictionary = current_melds[index]
			var previous_type := str(previous_meld.get("type", ""))
			var current_type := str(current_meld.get("type", ""))
			if previous_type == current_type:
				continue
			if current_type == "gang":
				_speak_action("杠", seat)
				return


func _play_new_win_voice(previous_snapshot: Dictionary, snapshot: Dictionary) -> void:
	var previous_settlement: Dictionary = previous_snapshot.get("settlement_data", {})
	var current_settlement: Dictionary = snapshot.get("settlement_data", {})
	var previous_win_events: Array = previous_settlement.get("win_events", [])
	var current_win_events: Array = current_settlement.get("win_events", [])
	if current_win_events.size() <= previous_win_events.size():
		return
	var latest_event: Dictionary = current_win_events[current_win_events.size() - 1]
	var winner_seat := int(latest_event.get("winner_seat", 0))
	var win_type := str(latest_event.get("win_type", "discard_win"))
	if win_type == "self_draw" or win_type == "gang_self_draw":
		_speak_action("自摸", winner_seat)
	else:
		_speak_action("胡", winner_seat)


func _play_tile_voice(tile: Dictionary, seat: int) -> void:
	var suit := str(tile.get("suit", ""))
	var rank := int(tile.get("rank", 0))
	if suit.is_empty() or rank <= 0:
		return
	var profile := _voice_profile_for_seat(seat)
	var stream := _load_voice_stream(str(profile.get("pack", "female")), "%s_%d" % [suit, rank])
	if stream == null:
		return
	tile_voice_player.stream = stream
	tile_voice_player.play()


func _schedule_tile_voice_after_render(tile: Dictionary, seat: int) -> void:
	pending_tile_voice_token += 1
	var token := pending_tile_voice_token
	_play_tile_voice_after_render(tile.duplicate(true), seat, token)


func _play_tile_voice_after_render(tile: Dictionary, seat: int, token: int) -> void:
	await get_tree().process_frame
	if token != pending_tile_voice_token:
		return
	_play_tile_voice(tile, seat)


func _play_sfx(name: String) -> void:
	_play_system_audio("%s/%s.wav" % [AUDIO_SFX_DIR, name], "1.35")


func _play_result(name: String) -> void:
	_play_system_audio("%s/%s.wav" % [AUDIO_SFX_DIR, name], "1.45")


func _speak_action(text: String, seat: int = 0) -> void:
	if text.is_empty():
		return
	var profile := _voice_profile_for_seat(seat)
	var action_key := _action_audio_key(text)
	if action_key.is_empty():
		return
	var stream := _load_voice_stream(str(profile.get("pack", "female")), action_key)
	if stream == null:
		return
	action_voice_player.stream = stream
	action_voice_player.play()


func _speak_ding_que(suit: String, seat: int = 0) -> void:
	var action_key := ""
	match suit:
		"wan":
			action_key = "ding_que_wan"
		"tiao":
			action_key = "ding_que_tiao"
		"tong":
			action_key = "ding_que_tong"
		_:
			return
	var profile := _voice_profile_for_seat(seat)
	var stream := _load_voice_stream(str(profile.get("pack", "female")), action_key)
	if stream == null:
		return
	action_voice_player.stream = stream
	action_voice_player.play()


func _play_system_audio(resource_path: String, volume: String = "1.0", max_seconds: float = 0.0) -> void:
	if not ResourceLoader.exists(resource_path):
		return
	var stream := load(resource_path) as AudioStream
	if stream == null or system_sfx_player == null:
		return
	system_sfx_play_token += 1
	var token := system_sfx_play_token
	system_sfx_player.stream = stream
	system_sfx_player.volume_db = linear_to_db(maxf(0.01, float(volume)))
	system_sfx_player.play()
	if max_seconds > 0.0:
		_stop_system_sfx_after(token, max_seconds)


func _play_system_audio_delayed(resource_path: String, volume: String = "1.0", max_seconds: float = 0.0, delay_seconds: float = 0.0) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	_play_system_audio(resource_path, volume, max_seconds)


func _stop_system_sfx_after(token: int, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if token == system_sfx_play_token and system_sfx_player != null and system_sfx_player.playing:
		system_sfx_player.stop()


func _shell_quote(text: String) -> String:
	return "'" + text.replace("'", "'\"'\"'") + "'"


func _assign_voice_profiles_for_round(snapshot: Dictionary) -> void:
	seat_voice_profiles.clear()
	seat_voice_profiles[0] = {
		"gender": "male",
		"pack": "male",
	}
	var players: Array = snapshot.get("players", [])
	for seat in [1, 2, 3]:
		var player := _player_by_seat(players, seat)
		if player.is_empty():
			continue
		var use_male := randi() % 2 == 0
		seat_voice_profiles[seat] = {
			"gender": "male" if use_male else "female",
			"pack": "male" if use_male else "female",
		}


func _voice_profile_for_seat(seat: int) -> Dictionary:
	if seat_voice_profiles.has(seat):
		return seat_voice_profiles[seat]
	return {
		"gender": "female",
		"pack": "female",
	}


func _action_audio_key(text: String) -> String:
	match text:
		"碰":
			return "peng"
		"杠":
			return "gang"
		"胡":
			return "hu"
		"自摸":
			return "zimo"
		"过":
			return "pass"
		"赢了":
			return "win"
		"输了":
			return "lose"
		_:
			return ""


func _load_voice_stream(pack: String, key: String) -> AudioStream:
	var cache_key := "%s/%s" % [pack, key]
	if voice_cache.has(cache_key):
		return voice_cache[cache_key]
	var path := "%s/%s/%s.wav" % [AUDIO_TTS_DIR, pack, key]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		voice_cache[cache_key] = stream
	return stream


func _update_top_bar(snapshot: Dictionary) -> void:
	_configure_v17_top_bar()
	room_card.visible = false
	room_label.text = ""
	info_card.visible = false
	var preset_name := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
	top_bar_button.visible = true
	top_bar_button.text = str(AI_PRESET_LABELS.get(preset_name, "骨灰"))
	top_bar_button.visible = false
	top_ai_tuning_button.visible = false
	top_ai_helper_button.visible = false
	top_opponent_hand_button.visible = false
	top_settlement_info_button.visible = false
	top_next_round_button.visible = false
	_configure_top_right_exit_button()
	center_info.text = ""
	_apply_ai_preset_button_style(preset_name)
	_apply_ai_helper_button_style()
	_update_floating_button_texts()
	if table_utility_bar != null:
		var round_complete := int(snapshot.get("current_phase", 0)) == 7
		table_utility_bar.call("render", ai_helper_enabled, round_complete, settlement_dismissed, str(AI_PRESET_LABELS.get(preset_name, "骨灰")), opponent_hands_enabled)
		_layout_table_utility_bar()


func _update_center_area(snapshot: Dictionary, players: Array, self_player: Dictionary) -> void:
	var trainer_hint: Dictionary = snapshot.get("trainer_hint", {}) if ai_helper_enabled else {}
	var routes: Array = trainer_hint.get("current_routes", [])
	var route_text := "/".join(routes)
	if route_text.is_empty():
		route_text = "当前以效率与防守为主"

	center_status.visible = false
	center_stats_card.visible = false
	center_hint_card.visible = false
	center_dealer_label.text = "庄家：%s" % _seat_name(int(snapshot.get("current_dealer_seat", 0)))
	center_wall_label.text = "牌墙：%d 张" % int(snapshot.get("wall_count", 0))
	center_turn_label.text = "当前回合：%s" % _seat_name(int(snapshot.get("current_turn_seat", 0)))
	center_reaction_label.text = "可响应：%s" % str(snapshot.get("reaction_summary", "-"))
	var use_ding_que := bool(snapshot.get("rules", {}).get("use_ding_que_phase", true))
	if use_ding_que:
		center_hint_box.text = "本家缺门：%s  ·  最近摸牌：%s  ·  最近弃牌：%s  ·  做牌方向：%s" % [
			_ding_que_display(str(self_player.get("ding_que", ""))),
			str(snapshot.get("recent_draw_display", "-")),
			str(snapshot.get("recent_discard_display", "-")),
			route_text,
		]
	else:
		center_hint_box.text = "最近摸牌：%s  ·  最近弃牌：%s  ·  做牌方向：%s" % [
			str(snapshot.get("recent_draw_display", "-")),
			str(snapshot.get("recent_discard_display", "-")),
			route_text,
		]
	if board_core_label != null and is_instance_valid(board_core_label):
		board_core_label.text = ""
	board_core.visible = false
	_update_board_core_hud(snapshot)
	if table_discard_layer != null:
		table_discard_layer.call(
			"render",
			players,
			{"id": int(snapshot.get("recent_discard_tile_id", -1))},
			Rect2(Vector2.ZERO, board_square.size)
		)
	if center_turn_indicator != null:
		var interaction_seat := _active_interaction_seat(snapshot)
		center_turn_indicator.call(
			"render",
			int(snapshot.get("wall_count", 0)),
			interaction_seat,
			_center_interaction_status(snapshot)
		)

	self_meld_summary.text = _meld_summary_text("本家", _player_by_seat(players, 0))
	left_meld_summary.text = _meld_summary_text("上家", _player_by_seat(players, 1))
	top_meld_summary.text = _meld_summary_text("对家", _player_by_seat(players, 2))
	right_meld_summary.text = _meld_summary_text("下家", _player_by_seat(players, 3))
	self_discard_summary.text = _discard_summary_text("本家", _player_by_seat(players, 0))
	left_discard_summary.text = _discard_summary_text("上家", _player_by_seat(players, 1))
	top_discard_summary.text = _discard_summary_text("对家", _player_by_seat(players, 2))
	right_discard_summary.text = _discard_summary_text("下家", _player_by_seat(players, 3))


func _refresh_opening_roll_ui(snapshot: Dictionary) -> void:
	var self_player := _player_by_seat(snapshot.get("players", []), 0)
	var use_ding_que := bool(snapshot.get("rules", {}).get("use_ding_que_phase", true))
	var ding_que_done := not use_ding_que or str(self_player.get("ding_que", "")) != ""
	if dice_overlay_layer != null:
		dice_overlay_layer.visible = not ding_que_done
	if center_turn_indicator != null:
		center_turn_indicator.visible = ding_que_done and not table_3d_enabled
	if table_stage_3d != null:
		table_stage_3d.call("set_center_wall_count_visible", ding_que_done)
	if ding_que_done:
		if center_turn_indicator != null:
			var interaction_seat := _active_interaction_seat(snapshot)
			center_turn_indicator.call(
				"render",
				int(snapshot.get("wall_count", 0)),
				interaction_seat,
				_center_interaction_status(snapshot)
			)
		return

	var opening_roll: Dictionary = snapshot.get("opening_roll", {})
	if opening_roll.is_empty():
		_show_dice_faces()
		_set_opening_roll_faces(1, 1)
		return

	if opening_roll_timer.is_stopped():
		_show_dice_faces()
		_set_opening_roll_faces(int(opening_roll.get("die_a", 1)), int(opening_roll.get("die_b", 1)))


func _start_opening_roll_animation_if_needed(opening_roll: Dictionary) -> void:
	var round_index := int(opening_roll.get("round_index", -1))
	if round_index == opening_roll_started_round and (not opening_roll_timer.is_stopped() or opening_roll_commit_timer.time_left > 0.0):
		return
	if round_index == opening_roll_started_round and opening_roll_payload == opening_roll:
		return
	opening_roll_started_round = round_index
	_begin_opening_roll_animation(opening_roll)


func _begin_opening_roll_animation(opening_roll: Dictionary) -> void:
	opening_roll_payload = opening_roll.duplicate(true)
	opening_roll_animation_ticks = OPENING_ROLL_TICKS
	opening_roll_commit_timer.stop()
	_play_system_audio_delayed(DICE_ROLL_AUDIO_PATH, "1.35", 3.0, 0.05)
	_show_dice_faces()
	_set_opening_roll_faces(opening_roll_visual_rng.randi_range(1, 6), opening_roll_visual_rng.randi_range(1, 6))
	opening_roll_timer.start()


func _on_opening_roll_started(data: Dictionary) -> void:
	if data.is_empty():
		return
	_begin_opening_roll_animation(data)


func _on_opening_roll_timer_timeout() -> void:
	if opening_roll_animation_ticks > 0:
		opening_roll_animation_ticks -= 1
		_set_opening_roll_faces(opening_roll_visual_rng.randi_range(1, 6), opening_roll_visual_rng.randi_range(1, 6))
		return
	opening_roll_timer.stop()
	if opening_roll_payload.is_empty():
		return
	_set_opening_roll_faces(int(opening_roll_payload.get("die_a", 1)), int(opening_roll_payload.get("die_b", 1)))
	opening_roll_commit_timer.start()


func _on_opening_roll_commit_timer_timeout() -> void:
	if not game_manager.complete_opening_roll():
		return


func _set_opening_roll_faces(die_a: int, die_b: int) -> void:
	die_a_face.set("value", clampi(die_a, 1, 6))
	die_b_face.set("value", clampi(die_b, 1, 6))


func _show_wall_count_in_dice_panel(wall_count: int) -> void:
	if dice_count_label == null or die_a_face == null or die_b_face == null:
		return
	if dice_panel != null:
		dice_panel.custom_minimum_size = CENTER_WALL_DISC_SIZE
	die_a_face.visible = false
	die_b_face.visible = false
	dice_count_label.visible = true
	dice_count_label.text = str(maxi(0, wall_count))
	_position_dice_wind_labels()
	for label in [dice_wind_top_label, dice_wind_right_label, dice_wind_bottom_label, dice_wind_left_label]:
		if label != null:
			label.visible = true


func _show_dice_faces() -> void:
	if dice_count_label == null or die_a_face == null or die_b_face == null:
		return
	if dice_panel != null:
		dice_panel.custom_minimum_size = Vector2(136, 136)
	dice_count_label.visible = false
	die_a_face.visible = true
	die_b_face.visible = true
	for label in [dice_wind_top_label, dice_wind_right_label, dice_wind_bottom_label, dice_wind_left_label]:
		if label != null:
			label.visible = false


func _position_dice_wind_labels() -> void:
	if dice_panel == null:
		return
	var disc_size := dice_panel.custom_minimum_size
	if dice_wind_top_label != null:
		dice_wind_top_label.position = Vector2((disc_size.x - dice_wind_top_label.size.x) * 0.5, -40.0)
	if dice_wind_bottom_label != null:
		dice_wind_bottom_label.position = Vector2((disc_size.x - dice_wind_bottom_label.size.x) * 0.5, disc_size.y - 8.0)
	if dice_wind_left_label != null:
		dice_wind_left_label.position = Vector2(-42.0, (disc_size.y - dice_wind_left_label.size.y) * 0.5)
	if dice_wind_right_label != null:
		dice_wind_right_label.position = Vector2(disc_size.x - 22.0, (disc_size.y - dice_wind_right_label.size.y) * 0.5)


func _update_self_area(snapshot: Dictionary, self_hand_tiles: Array) -> void:
	var self_player := _player_by_seat(snapshot.get("players", []), 0)
	var self_has_won := bool(self_player.get("has_won", false))
	var can_discard := bool(snapshot.get("human_can_discard", false)) and not self_has_won
	var trainer_hint: Dictionary = snapshot.get("trainer_hint", {}) if ai_helper_enabled else {}
	self_status.visible = false
	var use_ding_que := bool(snapshot.get("rules", {}).get("use_ding_que_phase", true))
	var self_ding_que := str(self_player.get("ding_que", "")) if use_ding_que else ""
	var self_score := int(self_player.get("score", 0))
	self_ding_que_label.text = _ding_que_display(self_ding_que) if self_ding_que != "" else ""
	self_ding_que_label.visible = self_ding_que != ""
	_apply_self_ding_que_style(self_ding_que)
	self_score_label.text = "%s\n%d分" % [_seat_name(0), self_score]
	self_score_label.visible = true
	if self_dealer_badge != null:
		self_dealer_badge.visible = int(snapshot.get("current_dealer_seat", -1)) == 0
		_position_self_dealer_badge()
	self_won_stamp.visible = self_has_won
	_position_self_won_stamp_overlay()
	self_info_bar.visible = false
	# 已胡只降低少量活跃度，仍保持暖象牙牌面作为第一视觉层级。
	self_hand_host.modulate = Color(0.94, 0.92, 0.86, 0.98) if self_has_won else Color.WHITE
	self_ding_que_label.modulate = self_hand_host.modulate
	self_score_label.modulate = self_hand_host.modulate
	if self_dealer_badge != null:
		self_dealer_badge.modulate = self_hand_host.modulate
	self_won_stamp.modulate = self_hand_host.modulate
	_layout_reference_self_info_bar()
	_update_self_row_slot_layout(self_player, self_hand_tiles.size())
	var display_hand_tiles := _build_display_hand_tiles(
		self_hand_tiles,
		int(snapshot.get("human_last_draw_tile_id", -1)),
		self_ding_que,
	)
	var self_winning_tile: Dictionary = self_player.get("winning_tile", {})
	var self_winning_tile_id := -1
	var self_winning_source_seat := -1
	if self_has_won and not self_winning_tile.is_empty():
		self_winning_tile_id = int(self_winning_tile.get("id", -1))
		self_winning_source_seat = int(self_player.get("winning_source_seat", -1))
		# 自摸牌是完整手牌的一部分，只有点炮胡才从手牌去重后单独附加来源牌。
		if self_winning_source_seat != 0:
			display_hand_tiles = display_hand_tiles.filter(func(tile: Dictionary) -> bool:
				return int(tile.get("id", -1)) != self_winning_tile_id
			)

	var self_trainer_markers := {
		"winning_tile_id": -1,
		"winning_source_seat": self_winning_source_seat,
	}
	if ai_helper_enabled:
		self_trainer_markers["recommended_tile_id"] = int(trainer_hint.get("recommended_tile_id", -1))
		self_trainer_markers["danger_tile_ids"] = trainer_hint.get("danger_tile_ids", []).duplicate()

	self_hand_host.configure_hand(
		display_hand_tiles,
		selected_tile_id,
		int(snapshot.get("human_last_draw_tile_id", -1)),
		can_discard,
		self_trainer_markers
	)
	_update_self_hu_tile_display(
		self_winning_tile if self_winning_source_seat != 0 else {},
		self_winning_source_seat
	)
	_update_discard_helper_panel(snapshot, trainer_hint, can_discard)
	_update_3d_table(snapshot)


func _update_seat_huds(snapshot: Dictionary) -> void:
	if seat_huds.is_empty():
		return
	var players: Array = snapshot.get("players", [])
	var current_dealer_seat := int(snapshot.get("current_dealer_seat", -1))
	var use_ding_que := bool(snapshot.get("rules", {}).get("use_ding_que_phase", true))
	var self_player := _player_by_seat(players, 0)
	var reveal_ding_que := not use_ding_que or not str(self_player.get("ding_que", "")).is_empty()
	var interaction_seat := _active_interaction_seat(snapshot)
	var self_interaction_label := "响应" if _has_human_reaction(snapshot) else "操作"
	for seat in [0, 1, 2, 3]:
		var seat_hud: Control = seat_huds.get(seat)
		if seat_hud == null:
			continue
		var rect := _seat_hud_rect(seat)
		_place_overlay_box(seat_hud, Vector2.ZERO, rect.position, rect.size)
		seat_hud.visible = true
		var player := _player_by_seat(players, seat)
		var player_view := player.duplicate(true)
		player_view["_is_dealer"] = seat == current_dealer_seat
		player_view["_interaction_label"] = self_interaction_label if seat == 0 and interaction_seat == 0 and _has_human_action(snapshot) else "出牌"
		seat_hud.render(player_view, interaction_seat, reveal_ding_que)


func _has_human_reaction(snapshot: Dictionary) -> bool:
	var reaction_options: Dictionary = snapshot.get("human_reaction_options", {})
	for key in ["can_hu", "can_gang", "can_peng", "can_pass"]:
		if bool(reaction_options.get(key, false)):
			return true
	return false


func _has_human_action(snapshot: Dictionary) -> bool:
	return _has_human_reaction(snapshot) \
		or bool(snapshot.get("human_can_self_hu", false)) \
		or bool(snapshot.get("human_can_add_gang", false)) \
		or bool(snapshot.get("human_can_an_gang", false))


func _active_interaction_seat(snapshot: Dictionary) -> int:
	return 0 if _has_human_action(snapshot) else int(snapshot.get("current_turn_seat", 0))


func _center_interaction_status(snapshot: Dictionary) -> String:
	if _has_human_reaction(snapshot):
		return "等待本家响应"
	if _has_human_action(snapshot):
		return "本家操作中"
	return "%s出牌中" % _seat_name(int(snapshot.get("current_turn_seat", 0)))


func _update_self_hu_tile_display(winning_tile: Dictionary, winning_source_seat: int) -> void:
	if self_hu_tile_host == null:
		return
	for child in self_hu_tile_host.get_children():
		self_hu_tile_host.remove_child(child)
		child.queue_free()
	var hu_rect := _v17_self_hu_rect()
	self_hu_tile_host.custom_minimum_size = Vector2(hu_rect.size.x, hu_rect.size.y)
	self_hu_tile_host.size = self_hu_tile_host.custom_minimum_size
	self_hu_tile_host.visible = not winning_tile.is_empty()
	if winning_tile.is_empty():
		if self_hand_host != null and self_hand_host.has_method("clear_right_host"):
			self_hand_host.call("clear_right_host")
		return
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := TILE_SCENE.instantiate()
	tile.call("configure", winning_tile, SELF_ROW_TILE_VISUAL_SCALE * 1.10, false, false, false, false, true)
	var tile_size: Vector2 = tile.custom_minimum_size
	wrapper.custom_minimum_size = tile_size
	wrapper.size = wrapper.custom_minimum_size
	tile.position = Vector2.ZERO
	wrapper.add_child(tile)
	if winning_source_seat > 0:
		wrapper.add_child(_create_winning_source_badge(tile_size, winning_source_seat))
	self_hu_tile_host.add_child(wrapper)
	if self_hand_host != null and self_hand_host.has_method("embed_right_host"):
		self_hand_host.call("embed_right_host", self_hu_tile_host, hu_rect.size.x, 10.0)


func _create_winning_source_badge(tile_size: Vector2, winning_source_seat: int) -> Node:
	var badge := Node2D.new()
	badge.name = "WinningSourceBadge"
	badge.position = tile_size * 0.5
	badge.rotation = _winning_source_badge_rotation(winning_source_seat)
	var badge_size := Vector2(18, 16)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(0, -badge_size.y * 0.5),
		Vector2(badge_size.x * 0.5, 0),
		Vector2(badge_size.x * 0.18, 0),
		Vector2(badge_size.x * 0.18, badge_size.y * 0.5),
		Vector2(-badge_size.x * 0.18, badge_size.y * 0.5),
		Vector2(-badge_size.x * 0.18, 0),
		Vector2(-badge_size.x * 0.5, 0),
	])
	arrow.color = SichuanTile3D.SOURCE_ARROW_COLOR
	badge.add_child(arrow)
	return badge


func _winning_source_badge_rotation(winning_source_seat: int) -> float:
	match winning_source_seat:
		1:
			return -PI * 0.5
		2:
			return PI
		3:
			return PI * 0.5
		_:
			return 0.0


func _update_self_row_slot_layout(self_player: Dictionary, hand_count: int) -> void:
	if player_self_host == null or self_hand_host == null:
		return
	var meld_slots := 0
	for meld in self_player.get("melds", []):
		meld_slots += (meld.get("tiles", []) as Array).size()
	meld_slots = clampi(meld_slots, 0, SELF_ROW_MAX_SLOTS)

	var meld_width := _slot_band_width(meld_slots)
	var self_rect := _v17_self_dynamic_rect()
	var hand_band_rect := _v17_self_hand_rect()
	var target_tile_width := self_rect.size.x / 16.0
	var target_height := target_tile_width * 4.0 / 3.0 + 24.0
	self_hand_host.custom_minimum_size = Vector2(
		hand_band_rect.size.x,
		clampf(target_height, 176.0, float(SELF_HAND_BOTTOM_HEIGHT))
	)
	player_self_host.visible = meld_slots > 0
	if meld_slots > 0:
		var max_embed_width := maxf(176.0, hand_band_rect.size.x * 0.72)
		var embed_width := minf(max_embed_width, maxf(meld_width, 176.0))
		player_self_host.custom_minimum_size = Vector2(embed_width, hand_band_rect.size.y)
		if self_hand_host.has_method("embed_left_host"):
			self_hand_host.call("embed_left_host", player_self_host, embed_width, 12.0)
	elif self_hand_host.has_method("clear_left_host"):
		self_hand_host.call("clear_left_host")


func _update_discard_helper_panel(snapshot: Dictionary, trainer_hint: Dictionary, can_discard: bool) -> void:
	_update_ai_assistant_drawer(trainer_hint, can_discard)
	if discard_helper_panel != null:
		discard_helper_panel.visible = false
	return


func _update_ai_assistant_drawer(trainer_hint: Dictionary, can_discard: bool) -> void:
	if ai_assistant_drawer == null:
		return
	ai_assistant_drawer.visible = ai_helper_enabled
	if not ai_helper_enabled:
		return
	ai_assistant_drawer.call("apply_hint", trainer_hint, can_discard, selected_tile_id)
	_layout_ai_assistant_drawer()


func _update_legacy_discard_helper_panel(snapshot: Dictionary, trainer_hint: Dictionary, can_discard: bool) -> void:
	if discard_helper_panel == null:
		return
	if not ai_helper_enabled:
		discard_helper_panel.visible = false
		return
	discard_helper_panel.visible = false
	discard_helper_action_button.visible = false
	discard_helper_action_button.disabled = true
	_position_discard_helper_panel()
	if trainer_hint.is_empty():
		_show_discard_helper_status(_build_discard_helper_idle_text(snapshot, can_discard))
		return

	var recommended: Dictionary = trainer_hint.get("recommended", {})
	var self_player: Dictionary = _player_by_seat(snapshot.get("players", []), 0)
	discard_helper_title.text = ""
	discard_helper_title.visible = false

	if bool(trainer_hint.get("can_self_hu", false)):
		discard_helper_summary.text = "已成和，直接自摸"
		discard_helper_compare.text = ""
		discard_helper_compare.visible = false
		discard_helper_options.text = ""
		discard_helper_options.visible = false
		discard_helper_panel.visible = true
		return

	if not can_discard or recommended.is_empty():
		if bool(trainer_hint.get("can_self_hu", false)):
			discard_helper_summary.text = "已成和，直接自摸"
		elif bool(trainer_hint.get("can_add_gang", false)):
			discard_helper_summary.text = "可补杠"
		elif bool(trainer_hint.get("can_an_gang", false)):
			discard_helper_summary.text = "可暗杠"
		else:
			discard_helper_summary.text = _build_discard_helper_idle_text(snapshot, can_discard)
		discard_helper_compare.text = ""
		discard_helper_compare.visible = false
		discard_helper_options.text = ""
		discard_helper_options.visible = false
		discard_helper_panel.visible = discard_helper_summary.text != ""
		if discard_helper_panel.visible:
			_position_discard_helper_panel()
		return

	var recommended_tile_name: String = str(recommended.get("tile_name", "?"))
	var recommended_tile_id: int = int(recommended.get("tile", {}).get("id", -1))
	var selected_option: Dictionary = {}
	if selected_tile_id != -1:
		selected_option = _find_helper_option_by_tile_id(
			trainer_hint.get("options", []),
			selected_tile_id,
			self_player.get("hand_tiles", [])
		)
	var display_option: Dictionary = selected_option if not selected_option.is_empty() else recommended
	var display_tile_name: String = str(display_option.get("tile_name", recommended_tile_name))
	discard_helper_summary.text = "打 %s" % recommended_tile_name
	if not selected_option.is_empty():
		discard_helper_summary.text = "%s → 打 %s" % [display_tile_name, recommended_tile_name]
	discard_helper_action_button.visible = false
	discard_helper_action_button.disabled = true
	var reason_text := _build_helper_selected_option_reason(selected_option, recommended) if not selected_option.is_empty() and int(selected_option.get("tile", {}).get("id", -1)) != recommended_tile_id else _build_helper_explanation_text(trainer_hint, recommended)
	discard_helper_compare.text = reason_text
	discard_helper_compare.visible = not reason_text.is_empty()
	discard_helper_options.text = _build_helper_top_candidates_text(trainer_hint.get("options", []))
	discard_helper_options.visible = not discard_helper_options.text.is_empty()
	discard_helper_panel.visible = true
	_position_discard_helper_panel()


func _build_helper_top_candidates_text(options: Array) -> String:
	if options.is_empty():
		return ""
	var parts: Array[String] = []
	var rank := 1
	for option_item in options.slice(0, mini(3, options.size())):
		var option: Dictionary = option_item
		var net := float(option.get("expected_net_score", option.get("csharp_expected_net_score", 0.0)))
		var risk := _plain_helper_risk_text(str(option.get("risk_label", "低危")))
		var route := str(option.get("route_plan_primary", option.get("strategy_mode", "")))
		var expected_fan := float(option.get("expected_fan", option.get("csharp_expected_fan", 0.0)))
		var win_probability := float(option.get("win_probability", option.get("csharp_win_probability", 0.0)))
		var tenpai_probability := float(option.get("tenpai_probability", option.get("csharp_tenpai_probability", 0.0)))
		var reason := _helper_candidate_core_reason(option, route)
		parts.append("%d.%s  净%.1f  胡%.0f%%/叫%.0f%%  %.1f番  %s  %s" % [
			rank,
			str(option.get("tile_name", "?")),
			net,
			win_probability * 100.0,
			tenpai_probability * 100.0,
			expected_fan,
			risk,
			reason,
		])
		rank += 1
	return "候选\n" + "\n".join(parts)


func _helper_candidate_core_reason(option: Dictionary, route: String) -> String:
	var explanation := str(option.get("explanation_hint", option.get("csharp_explanation_hint", ""))).strip_edges()
	if not explanation.is_empty():
		return _humanize_helper_text(explanation)
	var reasons: Array = option.get("reasons", option.get("csharp_reasons", []))
	for reason_value in reasons:
		var reason := _humanize_helper_text(str(reason_value)).strip_edges()
		if not reason.is_empty() and not reason.begins_with("最小向听") and not reason.begins_with("活进张"):
			return reason
	if not route.is_empty():
		return route
	return "兼顾速度和安全"


func _show_discard_helper_status(message: String) -> void:
	discard_helper_title.text = ""
	discard_helper_title.visible = false
	discard_helper_summary.text = message
	discard_helper_compare.text = ""
	discard_helper_compare.visible = false
	discard_helper_options.text = ""
	discard_helper_options.visible = false
	discard_helper_action_button.visible = false
	discard_helper_action_button.disabled = true
	discard_helper_panel.visible = not message.is_empty()
	if discard_helper_panel.visible:
		_position_discard_helper_panel()


func _build_discard_helper_idle_text(snapshot: Dictionary, can_discard: bool) -> String:
	if not ai_helper_enabled:
		return ""
	if bool(snapshot.get("human_ding_que_pending", false)):
		return "AI辅助已开启：请先选择定缺，选完后会按缺门优先提示出牌"
	if can_discard:
		var trainer_hint: Dictionary = snapshot.get("trainer_hint", {})
		if bool(trainer_hint.get("pending", false)):
			return "AI辅助正在计算：稍等一下，后台会给出推荐牌"
		return "AI辅助已开启：正在等待后台推荐牌"
	var turn_seat := int(snapshot.get("current_turn_seat", -1))
	if turn_seat >= 0 and turn_seat != 0:
		return "AI辅助已开启：等待你的出牌回合，轮到你时会显示推荐牌和原因"
	return "AI辅助已开启：当前不是主动出牌时机"


func _position_discard_helper_panel() -> void:
	if discard_helper_panel == null or root_ui == null or self_hand_host == null:
		return
	var panel_width: float = discard_helper_panel.custom_minimum_size.x
	var panel_height: float = discard_helper_panel.custom_minimum_size.y
	var action_rect := action_panel.get_global_rect() if action_panel != null and action_panel.visible else Rect2(Vector2.ZERO, Vector2.ZERO)
	var hand_rect := self_hand_host.get_global_rect()
	var root_rect := root_ui.get_global_rect()
	var board_rect := board_area.get_global_rect() if board_area != null else root_rect
	var min_x := root_rect.position.x + 18.0
	var max_x := maxf(min_x, root_rect.end.x - panel_width - 18.0)
	var x := clampf(board_rect.get_center().x - panel_width * 0.5, min_x, max_x)
	var y := maxf(18.0, hand_rect.position.y - panel_height - 20.0)
	if action_rect.size.x > 1.0:
		if Rect2(Vector2(x, y), Vector2(panel_width, panel_height)).intersects(action_rect, true):
			y = maxf(18.0, minf(y, action_rect.position.y - panel_height - 18.0))
	if self_hand_host != null:
		var hand_top := self_hand_host.get_global_rect().position.y
		y = minf(y, maxf(18.0, hand_top - panel_height - 16.0))
	discard_helper_panel.position = Vector2(x, y)
	discard_helper_panel.size = Vector2(panel_width, panel_height)


func _find_helper_option_by_tile_id(options: Array, tile_id: int, hand_tiles: Array = []) -> Dictionary:
	for option in options:
		var tile: Dictionary = option.get("tile", {})
		if int(tile.get("id", -1)) == tile_id:
			return option
	if hand_tiles.is_empty():
		return {}
	var selected_tile := _find_tile_in_hand_by_id(hand_tiles, tile_id)
	if selected_tile.is_empty():
		return {}
	for option in options:
		var tile: Dictionary = option.get("tile", {})
		if str(tile.get("suit", "")) == str(selected_tile.get("suit", "")) and int(tile.get("rank", 0)) == int(selected_tile.get("rank", 0)):
			return option
	return {}


func _find_tile_in_hand_by_id(hand_tiles: Array, tile_id: int) -> Dictionary:
	for tile in hand_tiles:
		if int(tile.get("id", -1)) == tile_id:
			return tile
	return {}


func _build_helper_secondary_choice_text(options: Array, recommended_id: int) -> String:
	if options.size() < 2:
		return ""
	for item in options:
		if int(item.get("tile", {}).get("id", -1)) == recommended_id:
			continue
		var posterior_reasons: Array = item.get("posterior_reasons", item.get("csharp_posterior_reasons", []))
		var suffix := ""
		if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
			suffix = "｜%s" % str(posterior_reasons[0])
		return "也可以考虑：%s｜胡牌机会%.1f%%%s" % [
			str(item.get("tile_name", "?")),
			float(item.get("win_probability", 0.0)) * 100.0,
			suffix,
		]
	return ""


func _build_helper_explanation_text(trainer_hint: Dictionary, recommended: Dictionary) -> String:
	var forced_suit: String = str(trainer_hint.get("forced_discard_suit", ""))
	if not forced_suit.is_empty():
		return "先打定缺：手里还有%s牌，必须优先清完缺门" % _ding_que_short_text(forced_suit)
	var csharp_probability_text := _build_helper_csharp_probability_text(recommended)
	if not csharp_probability_text.is_empty():
		return csharp_probability_text
	var explanation_hint: String = str(recommended.get("explanation_hint", ""))
	if not explanation_hint.is_empty():
		return explanation_hint

	var strategy_profile: Dictionary = trainer_hint.get("strategy_profile", {})
	var dingque_state: Dictionary = strategy_profile.get("dingque_state", {})
	var opponent_state: Dictionary = strategy_profile.get("opponent_state", {})
	var current_routes: Array = trainer_hint.get("current_routes", [])
	var routes_after: Array = recommended.get("routes_after", [])
	var route_loss: Array = recommended.get("route_loss", [])
	var risk_label: String = str(recommended.get("risk_label", "低危"))
	var shanten: int = int(recommended.get("shanten", 8))
	var ukeire: int = int(recommended.get("ukeire", 0))
	var shape_score: int = int(recommended.get("shape_score", 0))
	var wait_score: int = int(recommended.get("wait_quality_score", 0))
	var safety_score: int = int(recommended.get("safety_score", 0))
	var pressure_score: int = int(recommended.get("pressure_score", 0))
	var tile: Dictionary = recommended.get("tile", {})
	var rank: int = int(tile.get("rank", 0))
	var tile_name: String = str(recommended.get("tile_name", "?"))
	var top_threat_profile: Dictionary = opponent_state.get("top_threat_profile", {})
	var posterior_reasons: Array = recommended.get("posterior_reasons", recommended.get("csharp_posterior_reasons", []))

	if bool(dingque_state.get("is_two_suit_table", false)):
		if int(opponent_state.get("fast_call_count", 0)) >= 2:
			return "牌不多了，而且好几家都在提速，先让自己更快听牌"
		if int(dingque_state.get("spread", 0)) >= 3 and _has_big_route(routes_after):
			return "这一门很多，可以继续留着冲大牌"
		if int(opponent_state.get("flush_watch_count", 0)) >= 1 and str(top_threat_profile.get("dangerous_suit", "")) == str(tile.get("suit", "")):
			return "有人像在做%s清一色，这张先别急着打" % str(top_threat_profile.get("dangerous_suit_label", ""))
		if int(opponent_state.get("pung_watch_count", 0)) >= 1 and rank in [2, 5, 8]:
			return "有人像在做对对胡，2、5、8这类牌先少打"
		if shanten <= 1 and ukeire >= 4:
			return "这样打更容易尽快听牌"
		if int(dingque_state.get("spread", 0)) <= 1:
			return "牌路比较平均，先留更容易接牌的打法"

	if bool(dingque_state.get("is_three_same", false)):
		return "大家缺的门差不多，先拼速度"
	if bool(dingque_state.get("is_all_same", false)):
		return "四家缺门都一样，先按最稳的方式打"
	if bool(dingque_state.get("is_two_same_self_diff", false)) and _has_big_route(routes_after):
		return "别人缺门和你不一样，这手可以顺着大牌方向走"
	if int(opponent_state.get("flush_watch_count", 0)) >= 1 and str(top_threat_profile.get("dangerous_suit", "")) == str(tile.get("suit", "")):
		return "有人像在做%s清一色，这张先别急着打" % str(top_threat_profile.get("dangerous_suit_label", ""))
	if int(opponent_state.get("pung_watch_count", 0)) >= 1 and rank in [2, 5, 8]:
		return "有人像在做对对胡，2、5、8这类牌先少打"

	if current_routes.has("对对胡") and routes_after.has("对对胡"):
		return "这手还可以继续做对对胡"
	if current_routes.has("七对") and routes_after.has("七对"):
		return "这手还可以继续做七对"
	if current_routes.has("将对") and routes_after.has("将对"):
		return "先把将对的底子留住"
	if current_routes.has("清一色") or _has_qing_route(current_routes):
		if _has_qing_route(routes_after):
			return "建议继续保清一色的路"
		return "这时候拆清一色不划算"
	if _has_qing_route(routes_after):
		return "这手可以继续往清一色走"
	if not route_loss.is_empty():
		return "这张打出去，会少一条做大牌的路"
	if shanten <= 1 and ukeire >= 8:
		return "这手先抢速度更合适"
	if shanten < 8 and ukeire >= 10:
		return "打这张后，后面最容易摸到能接上的牌"
	if wait_score >= 36 and ukeire >= 6:
		return "先留两头都能接的顺子搭子"
	if shape_score <= -10:
		return "先拆掉不连不靠的单张"
	if shape_score >= 18:
		return "先留连着的牌更顺"
	if _is_pair_tile_name(tile_name):
		return "对子先留着，后面变化更多"
	if rank in [1, 9] and risk_label in ["中危", "高危"]:
		return "中间张更危险，边张可以先出"
	if safety_score >= 0 and (risk_label == "中危" or risk_label == "高危" or pressure_score <= -8):
		return "这一手先安全一点更合适"
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		return _humanize_helper_text(str(posterior_reasons[0]))
	if risk_label == "低危":
		return "这张相对更安全"
	return "这手先留更容易听牌的路，也顾一下安全"


func _build_helper_csharp_probability_text(option: Dictionary) -> String:
	var has_csharp_detail := option.has("csharp_expected_net_score") \
		or option.has("csharp_self_draw_probability") \
		or option.has("csharp_deal_in_probability") \
		or option.has("csharp_defense_adjustment") \
		or option.has("csharp_shape_score") \
		or option.has("csharp_wait_shape_label") \
		or option.has("csharp_limited_lookahead_score") \
		or not Array(option.get("csharp_reasons", [])).is_empty()
	if not has_csharp_detail:
		return ""
	var parts: Array[String] = []
	var expected_net := float(option.get("expected_net_score", option.get("csharp_expected_net_score", 0.0)))
	var self_draw := float(option.get("self_draw_probability", option.get("csharp_self_draw_probability", 0.0)))
	var deal_in := float(option.get("deal_in_probability", option.get("csharp_deal_in_probability", 0.0)))
	var defense_adjustment := float(option.get("defense_adjustment", option.get("csharp_defense_adjustment", 0.0)))
	var shape_score := float(option.get("shape_score", option.get("csharp_shape_score", 0.0)))
	parts.append("综合看大概能赚%.2f" % expected_net)
	if self_draw > 0.0:
		parts.append("自摸机会%.0f%%" % (self_draw * 100.0))
	if deal_in > 0.0:
		parts.append("放炮机会%.0f%%" % (deal_in * 100.0))
	if defense_adjustment > 0.01:
		parts.append("因为要防守，收益会少%.2f" % defense_adjustment)
	if absf(shape_score) >= 0.5:
		parts.append("牌会更顺%+.0f" % shape_score)
	var wait_shape_label := str(option.get("wait_shape_label", option.get("csharp_wait_shape_label", "")))
	if not wait_shape_label.is_empty() and wait_shape_label != "未成听":
		parts.append("听牌后牌路%s" % wait_shape_label)
	var limited_lookahead := float(option.get("limited_lookahead_score", option.get("csharp_limited_lookahead_score", 0.0)))
	if absf(limited_lookahead) >= 3.0:
		parts.append("往后多看几步会%+.1f" % limited_lookahead)
	var posterior_reasons: Array = option.get("posterior_reasons", option.get("csharp_posterior_reasons", []))
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		parts.append(_humanize_helper_text(str(posterior_reasons[0])))
	var risk_reasons: Array = option.get("risk_reasons", option.get("csharp_risk_reasons", []))
	if not risk_reasons.is_empty():
		parts.append(_humanize_helper_text(str(risk_reasons[0])))
	var csharp_reasons: Array = option.get("reasons", option.get("csharp_reasons", []))
	for reason in csharp_reasons:
		var reason_text := str(reason)
		if reason_text.is_empty():
			continue
		if reason_text.begins_with("最小向听") \
			or reason_text.begins_with("活进张") \
			or reason_text.begins_with("净分期望") \
			or reason_text.begins_with("危险度") \
			or reason_text.begins_with("阶段") \
			or reason_text.begins_with("策略"):
			continue
		parts.append(_humanize_helper_text(reason_text))
		if parts.size() >= 8:
			break
	return "｜".join(parts.slice(0, 8))


func _build_helper_selected_option_reason(selected_option: Dictionary, recommended: Dictionary) -> String:
	var parts: Array[String] = []
	var selected_name := str(selected_option.get("tile_name", "?"))
	var recommended_name := str(recommended.get("tile_name", "?"))
	parts.append("不建议先打%s，更建议打%s" % [selected_name, recommended_name])
	var delta_shanten := int(selected_option.get("shanten", 8)) - int(recommended.get("shanten", 8))
	var delta_live := int(selected_option.get("live_ukeire", 0)) - int(recommended.get("live_ukeire", 0))
	var delta_risk := int(selected_option.get("risk", 0)) - int(recommended.get("risk", 0))
	var delta_net := float(recommended.get("expected_net_score", recommended.get("csharp_expected_net_score", 0.0))) - float(selected_option.get("expected_net_score", selected_option.get("csharp_expected_net_score", 0.0)))
	var selected_win_gain := float(selected_option.get("expected_win_gain", selected_option.get("csharp_expected_win_gain", 0.0)))
	var selected_deal_loss := float(selected_option.get("expected_deal_in_loss", selected_option.get("csharp_expected_deal_in_loss", 0.0)))
	var selected_risk_label := str(selected_option.get("risk_label", selected_option.get("csharp_risk_label", "")))
	if delta_shanten > 0:
		parts.append("会晚%d步才更接近听牌" % delta_shanten)
	if delta_live < 0:
		parts.append("后面能接上的牌会少%d张" % abs(delta_live))
	if delta_risk > 0:
		parts.append("而且会更危险一些")
	if delta_net > 0.01:
		parts.append("综合收益会少%.2f" % delta_net)
	if selected_win_gain > 0.0 or selected_deal_loss > 0.0:
		parts.append("按你现在点的打法，大概能赚%.2f，也可能亏%.2f" % [selected_win_gain, selected_deal_loss])
	if not selected_risk_label.is_empty():
		parts.append(_plain_helper_risk_text(selected_risk_label))
	var csharp_reasons: Array = selected_option.get("reasons", selected_option.get("csharp_reasons", []))
	if not csharp_reasons.is_empty():
		parts.append(_humanize_helper_text(str(csharp_reasons[0])))
	var posterior_reasons: Array = selected_option.get("posterior_reasons", selected_option.get("csharp_posterior_reasons", []))
	if not posterior_reasons.is_empty() and str(posterior_reasons[0]) != "后验未明显压分":
		parts.append(_humanize_helper_text(str(posterior_reasons[0])))
	var risk_reasons: Array = selected_option.get("risk_reasons", selected_option.get("csharp_risk_reasons", []))
	if not risk_reasons.is_empty():
		parts.append(_humanize_helper_text(str(risk_reasons[0])))
	return "｜".join(parts.slice(0, 8))


func _plain_helper_risk_text(risk_label: String) -> String:
	match risk_label:
		"高危":
			return "危险比较大"
		"中危":
			return "有点危险"
		_:
			return "相对安全"


func _humanize_helper_text(text: String) -> String:
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
		"搭子": "搭子",
	}
	for key in replacements.keys():
		result = result.replace(key, str(replacements[key]))
	return result


func _has_qing_route(routes: Array) -> bool:
	for route in routes:
		var route_text: String = str(route)
		if route_text == "清一色" or route_text.contains("清"):
			return true
	return false


func _has_big_route(routes: Array) -> bool:
	for route in routes:
		var route_text: String = str(route)
		if route_text in ["清一色", "七对", "对对胡", "将对", "带幺九"] or route_text.contains("清"):
			return true
	return false


func _is_pair_tile_name(tile_name: String) -> bool:
	if tile_name.is_empty():
		return false
	var counts: Dictionary = {}
	for character in tile_name:
		var key: String = str(character)
		counts[key] = int(counts.get(key, 0)) + 1
	for key in counts.keys():
		if int(counts[key]) >= 2:
			return true
	return false


func _join_limited_strings(items: Array, limit: int, separator: String) -> String:
	if items.is_empty():
		return "当前以效率和安全平衡为主"
	var result: Array[String] = []
	for index in range(mini(limit, items.size())):
		result.append(str(items[index]))
	return separator.join(result)


func _slot_band_width(slot_count: int) -> float:
	if slot_count <= 0:
		return 0.0
	return SELF_TILE_FACE_WIDTH + SELF_SLOT_STEP * float(slot_count - 1)


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
	var a_is_ding_que: bool = ding_que_suit != "" and str(a.get("suit", "")) == ding_que_suit
	var b_is_ding_que: bool = ding_que_suit != "" and str(b.get("suit", "")) == ding_que_suit
	if a_is_ding_que != b_is_ding_que:
		return not a_is_ding_que
	return _sort_hand_tile(a, b)


func _build_display_hand_tiles(hand_tiles: Array, _last_draw_tile_id: int, ding_que_suit: String = "") -> Array:
	var sorted_hand_tiles := hand_tiles.duplicate(true)
	if ding_que_suit == "":
		sorted_hand_tiles.sort_custom(_sort_hand_tile)
	else:
		sorted_hand_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _sort_hand_tile_with_ding_que(a, b, ding_que_suit)
		)
	return sorted_hand_tiles


func _refresh_action_panel(snapshot: Dictionary) -> void:
	_refresh_table_action_bar(snapshot)
	if action_panel != null:
		action_panel.visible = false
	return


func _refresh_table_action_bar(snapshot: Dictionary) -> void:
	if table_action_bar == null:
		return
	var reaction_options: Dictionary = snapshot.get("human_reaction_options", {})
	var can_self_hu := bool(snapshot.get("human_can_self_hu", false))
	var can_add_gang := bool(snapshot.get("human_can_add_gang", false))
	var can_an_gang := bool(snapshot.get("human_can_an_gang", false))
	var show_cancel_self_hu := can_self_hu and not bool(reaction_options.get("can_pass", false))
	var actions: Array[String] = []
	if can_self_hu or bool(reaction_options.get("can_hu", false)):
		actions.append("hu")
	if can_add_gang or can_an_gang or bool(reaction_options.get("can_gang", false)):
		actions.append("gang")
	if bool(reaction_options.get("can_peng", false)):
		actions.append("peng")
	if bool(reaction_options.get("can_pass", false)) or show_cancel_self_hu:
		actions.append("pass")
	var blocked := int(snapshot.get("current_phase", 0)) == 7 \
		or bool(_player_by_seat(snapshot.get("players", []), 0).get("has_won", false))
	# A supplement draw may expose gang-self-hu immediately in GameState, but
	# the visual action must not appear before the 3D draw tile has travelled and
	# settled. Keep the authoritative action list intact while the draw transition
	# owns presentation; the timer refresh below reveals it after the draw beat.
	if draw_transition_active and not actions.is_empty():
		table_action_bar.call("hide_actions")
		return
	if actions.is_empty() or blocked:
		table_action_bar.call("hide_actions")
		return
	table_action_bar.call("set_action_label", "hu", "自摸" if can_self_hu and not bool(reaction_options.get("can_hu", false)) else "胡")
	var gang_label := "杠"
	if can_add_gang:
		gang_label = "补杠"
	elif can_an_gang and not bool(reaction_options.get("can_gang", false)):
		gang_label = "暗杠"
	table_action_bar.call("set_action_label", "gang", gang_label)
	table_action_bar.call("set_action_label", "peng", "碰")
	# 自摸和响应胡的次要选项都是“取消本次胡”，避免 3D
	# 重构后仍显示语义含糊的“过”。
	table_action_bar.call("set_action_label", "pass", "取消")
	var status_text := _build_action_panel_status_text(
		reaction_options,
		can_self_hu,
		can_add_gang,
		can_an_gang,
		show_cancel_self_hu,
		str(snapshot.get("recent_discard_display", "-"))
	)
	table_action_bar.call("render", actions, status_text)
	call_deferred("_layout_table_action_bar")


func _on_table_action_selected(action: String) -> void:
	match action:
		"hu":
			_on_hu_pressed()
		"gang":
			_on_gang_pressed()
		"peng":
			_on_peng_pressed()
		"pass":
			_on_pass_pressed()


func _build_action_panel_status_text(
	reaction_options: Dictionary,
	can_self_hu: bool,
	can_add_gang: bool,
	can_an_gang: bool,
	show_cancel_self_hu: bool,
	recent_discard_display: String = "-"
) -> String:
	var reaction_labels: Array[String] = []
	if bool(reaction_options.get("can_hu", false)):
		reaction_labels.append("胡")
	if bool(reaction_options.get("can_gang", false)):
		reaction_labels.append("杠")
	if bool(reaction_options.get("can_peng", false)):
		reaction_labels.append("碰")
	if bool(reaction_options.get("can_pass", false)):
		reaction_labels.append("过")
	if not reaction_labels.is_empty():
		var discard_context := "" if recent_discard_display in ["", "-"] else " %s" % recent_discard_display
		return "响应%s · 可选：%s" % [discard_context, " / ".join(reaction_labels)]
	var self_labels: Array[String] = []
	if can_self_hu:
		self_labels.append("自摸")
		if show_cancel_self_hu:
			self_labels.append("过")
	if can_add_gang:
		self_labels.append("补杠")
	if can_an_gang:
		self_labels.append("暗杠")
	if not self_labels.is_empty():
		return "轮到你 · 可选：" + " / ".join(self_labels)
	return "当前没有可执行操作"


func _set_margin_constants(margin: MarginContainer, left: float, top: float, right: float, bottom: float) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", int(round(left)))
	margin.add_theme_constant_override("margin_top", int(round(top)))
	margin.add_theme_constant_override("margin_right", int(round(right)))
	margin.add_theme_constant_override("margin_bottom", int(round(bottom)))


func _settlement_content_scale() -> float:
	return settlement_layout_scale


func _refresh_ding_que_panel(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("rules", {}).get("use_ding_que_phase", true)):
		ding_que_overlay.visible = false
		return
	var current_phase := int(snapshot.get("current_phase", 0))
	var show_panel := current_phase == 3 and bool(snapshot.get("human_ding_que_pending", false))
	ding_que_overlay.visible = show_panel
	if not show_panel:
		_reset_ding_que_visual_state()
		return
	if action_panel != null:
		action_panel.visible = false
	# 定缺是唯一的开局模态决策。AI 提示窗即使在上一局被用户开启，
	# 也不能在圆印后方形成第二个可读/可拖焦点；定缺结束后的下一份
	# 快照会由 _update_ai_assistant_drawer 按原偏好恢复。
	if ai_assistant_drawer != null:
		ai_assistant_drawer.visible = false
	ding_que_overlay.top_level = true
	ding_que_overlay.z_index = 420
	ding_que_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ding_que_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ding_que_center := ding_que_overlay.get_node_or_null("DingQueCenter") as Control
	if ding_que_center != null:
		ding_que_center.mouse_filter = Control.MOUSE_FILTER_PASS
	ding_que_overlay.move_to_front()
	# 开局只呈现三枚可选花色印章。规则说明已在玩法中建立，不再用标题、
	# 副标题或外层提示卡重复遮住牌桌。
	ding_que_status_label.visible = false
	ding_que_hint_label.visible = false
	var title_block := ding_que_status_label.get_parent() as Control
	if title_block != null:
		title_block.visible = false
	var options: Array = game_manager.game_state.call("get_human_ding_que_options", 0)
	ding_que_tiao_button.disabled = not options.has("tiao")
	ding_que_tong_button.disabled = not options.has("tong")
	ding_que_wan_button.disabled = not options.has("wan")
	for button in [ding_que_tiao_button, ding_que_tong_button, ding_que_wan_button]:
		if not button.disabled:
			button.call_deferred("grab_focus")
			break


func _apply_self_ding_que_style(suit: String = "") -> void:
	var style := StyleBoxFlat.new()
	var palette := _self_ding_que_palette(suit)
	style.bg_color = palette.get("bg", _self_ding_que_color(suit))
	style.border_color = palette.get("border", Color(0.95, 0.86, 0.62, 0.92))
	style.set_border_width_all(4)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	self_ding_que_label.add_theme_stylebox_override("normal", style)
	self_ding_que_label.add_theme_font_size_override("font_size", 32)
	self_ding_que_label.add_theme_color_override("font_color", palette.get("font", Color(0.96, 0.94, 0.86, 1.0)))
	self_ding_que_label.add_theme_color_override("font_outline_color", palette.get("outline", Color(0.12, 0.08, 0.05, 0.94)))
	self_ding_que_label.add_theme_constant_override("outline_size", 4)
	self_ding_que_label.custom_minimum_size = Vector2(176, 64)
	self_ding_que_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	self_ding_que_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _self_ding_que_palette(suit: String) -> Dictionary:
	match suit:
		"wan":
			return {
				"bg": Color(0.58, 0.10, 0.08, 0.96),
				"border": Color(1.0, 0.58, 0.36, 0.96),
				"font": Color(1.0, 0.92, 0.80, 1.0),
				"outline": Color(0.20, 0.02, 0.01, 0.96),
			}
		"tiao":
			return {
				"bg": Color(0.09, 0.40, 0.20, 0.96),
				"border": Color(0.54, 0.96, 0.58, 0.94),
				"font": Color(0.90, 1.0, 0.86, 1.0),
				"outline": Color(0.01, 0.14, 0.06, 0.96),
			}
		"tong":
			return {
				"bg": Color(0.08, 0.28, 0.58, 0.96),
				"border": Color(0.48, 0.82, 1.0, 0.94),
				"font": Color(0.88, 0.96, 1.0, 1.0),
				"outline": Color(0.01, 0.08, 0.18, 0.96),
			}
		_:
			return {
				"bg": Color(0.30, 0.18, 0.14, 0.96),
				"border": Color(0.95, 0.86, 0.62, 0.92),
				"font": Color(0.96, 0.94, 0.86, 1.0),
				"outline": Color(0.12, 0.08, 0.05, 0.94),
			}


func _self_ding_que_color(suit: String) -> Color:
	match suit:
		"tiao":
			return Color(0.16, 0.42, 0.24, 0.96)
		"tong":
			return Color(0.12, 0.30, 0.52, 0.96)
		"wan":
			return Color(0.52, 0.16, 0.14, 0.96)
		_:
			return Color(0.30, 0.18, 0.14, 0.96)


func _apply_self_score_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.20, 0.16, 0.46)
	style.border_color = Color(0.86, 1.0, 0.82, 0.05)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 11
	style.shadow_offset = Vector2(0, 4)
	self_score_label.add_theme_stylebox_override("normal", style)
	var calligraphy_font := SystemFont.new()
	calligraphy_font.font_names = PackedStringArray([
		"FZXingKJW-B",
		"FZXingKJW-M",
		"STKaiti",
		"Kaiti SC",
		"Songti SC",
	])
	calligraphy_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	calligraphy_font.hinting = TextServer.HINTING_LIGHT
	self_score_label.add_theme_font_override("font", calligraphy_font)
	self_score_label.add_theme_font_size_override("font_size", 34)
	self_score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	self_score_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.05, 0.98))
	self_score_label.add_theme_constant_override("outline_size", 4)
	self_score_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.82, 0.32, 0.36))
	self_score_label.add_theme_constant_override("shadow_offset_x", 0)
	self_score_label.add_theme_constant_override("shadow_offset_y", 2)
	self_score_label.custom_minimum_size = Vector2(302, 136)
	self_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self_score_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	self_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	self_score_label.add_theme_constant_override("line_spacing", 8)
	self_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _apply_self_won_stamp_style() -> void:
	var stamp_style := StyleBoxFlat.new()
	stamp_style.bg_color = Color(0.44, 0.05, 0.03, 0.18)
	stamp_style.border_color = Color(0.86, 0.14, 0.08, 0.98)
	stamp_style.set_border_width_all(4)
	stamp_style.corner_radius_top_left = 14
	stamp_style.corner_radius_top_right = 14
	stamp_style.corner_radius_bottom_left = 14
	stamp_style.corner_radius_bottom_right = 14
	stamp_style.content_margin_left = 16
	stamp_style.content_margin_right = 16
	stamp_style.content_margin_top = 8
	stamp_style.content_margin_bottom = 8
	stamp_style.shadow_color = Color(0.18, 0.02, 0.00, 0.34)
	stamp_style.shadow_size = 7
	stamp_style.shadow_offset = Vector2(0, 3)
	self_won_stamp.add_theme_stylebox_override("normal", stamp_style)
	self_won_stamp.add_theme_font_size_override("font_size", 30)
	self_won_stamp.add_theme_color_override("font_color", Color(0.97, 0.16, 0.10, 0.98))
	self_won_stamp.add_theme_color_override("font_outline_color", Color(1.0, 0.84, 0.80, 0.56))
	self_won_stamp.add_theme_color_override("font_shadow_color", Color(0.44, 0.03, 0.02, 0.30))
	self_won_stamp.add_theme_constant_override("outline_size", 2)
	self_won_stamp.add_theme_constant_override("shadow_offset_x", 0)
	self_won_stamp.add_theme_constant_override("shadow_offset_y", 2)
	self_won_stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	self_won_stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	self_won_stamp.custom_minimum_size = Vector2(108, 52)
	self_won_stamp.rotation_degrees = 0.0
	self_won_stamp.pivot_offset = Vector2.ZERO
	self_won_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_self_dealer_badge() -> void:
	if self_dealer_badge != null or self_score_label == null:
		return
	self_dealer_badge = Label.new()
	self_dealer_badge.name = "SelfDealerBadge"
	self_dealer_badge.text = "庄"
	self_dealer_badge.visible = false
	self_dealer_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_score_label.add_child(self_dealer_badge)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.56, 0.20, 0.08, 0.96)
	style.bg_color = Color(0.20, 0.07, 0.03, 0.97)
	style.border_color = Color(1.0, 0.78, 0.22, 0.98)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	self_dealer_badge.add_theme_stylebox_override("normal", style)
	self_dealer_badge.add_theme_font_size_override("font_size", 36)
	self_dealer_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
	self_dealer_badge.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.95))
	self_dealer_badge.add_theme_constant_override("outline_size", 4)
	self_dealer_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self_dealer_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	self_dealer_badge.custom_minimum_size = Vector2(76, 56)
	_position_self_dealer_badge()


func _position_self_dealer_badge() -> void:
	if self_dealer_badge == null or self_score_label == null:
		return
	if self_dealer_badge.size.x <= 1.0 or self_dealer_badge.size.y <= 1.0:
		self_dealer_badge.size = self_dealer_badge.custom_minimum_size
	var score_size := self_score_label.size
	if score_size.x <= 1.0 or score_size.y <= 1.0:
		score_size = self_score_label.custom_minimum_size
	self_dealer_badge.position = Vector2(
		maxf(8.0, score_size.x - self_dealer_badge.size.x - 10.0),
		8.0
	)


func _mount_self_won_stamp_overlay() -> void:
	if self_won_stamp == null or self_score_label == null:
		return
	if self_won_stamp.get_parent() == self_score_label:
		return
	if self_won_stamp.get_parent() != null:
		self_won_stamp.get_parent().remove_child(self_won_stamp)
	self_score_label.add_child(self_won_stamp)
	self_won_stamp.anchor_left = 0.0
	self_won_stamp.anchor_top = 0.0
	self_won_stamp.anchor_right = 0.0
	self_won_stamp.anchor_bottom = 0.0
	_position_self_won_stamp_overlay()


func _position_self_won_stamp_overlay() -> void:
	if self_won_stamp == null or self_score_label == null:
		return
	if self_won_stamp.size.x <= 1.0 or self_won_stamp.size.y <= 1.0:
		self_won_stamp.size = self_won_stamp.custom_minimum_size
	var score_size := self_score_label.size
	if score_size.x <= 1.0 or score_size.y <= 1.0:
		score_size = self_score_label.custom_minimum_size
	self_won_stamp.position = Vector2(
		maxf(10.0, score_size.x - self_won_stamp.size.x - 12.0),
		maxf(10.0, score_size.y - self_won_stamp.size.y - 10.0)
	)


func _layout_reference_self_info_bar() -> void:
	if self_info_bar == null or root_ui == null:
		return
	var info_rect := _seat_hud_rect(0)
	self_info_bar.top_level = true
	self_info_bar.z_index = 110
	self_info_bar.custom_minimum_size = info_rect.size
	self_info_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self_info_bar.size = info_rect.size
	self_info_bar.position = info_rect.position
	if self_score_label != null:
		self_score_label.custom_minimum_size = info_rect.size
		self_score_label.size = info_rect.size


func _apply_ding_que_overlay_style() -> void:
	ding_que_overlay.top_level = true
	ding_que_overlay.z_index = 420
	ding_que_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# A restrained neutral-green veil keeps the hand visible and darkens the
	# table by roughly 12%, matching the modal contract without a blue cast.
	ding_que_shade.color = Color(0.01, 0.04, 0.03, 0.13)
	ding_que_panel.custom_minimum_size = Vector2(812, 292)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.11, 0.20, 0.0)
	panel_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.corner_radius_top_left = 34
	panel_style.corner_radius_top_right = 34
	panel_style.corner_radius_bottom_left = 34
	panel_style.corner_radius_bottom_right = 34
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.shadow_size = 0
	panel_style.shadow_offset = Vector2.ZERO
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	ding_que_panel.add_theme_stylebox_override("panel", panel_style)

	var button_card_style := StyleBoxFlat.new()
	button_card_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	button_card_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	button_card_style.set_border_width_all(0)
	button_card_style.corner_radius_top_left = 24
	button_card_style.corner_radius_top_right = 24
	button_card_style.corner_radius_bottom_left = 24
	button_card_style.corner_radius_bottom_right = 24
	button_card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	button_card_style.shadow_size = 0
	button_card_style.shadow_offset = Vector2.ZERO
	ding_que_button_card.add_theme_stylebox_override("panel", button_card_style)

	ding_que_status_label.add_theme_font_size_override("font_size", 44)
	ding_que_status_label.add_theme_color_override("font_color", IVORY_SOFT)
	ding_que_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.28))
	ding_que_status_label.add_theme_constant_override("shadow_outline_size", 1)

	ding_que_hint_label.add_theme_font_size_override("font_size", 22)
	ding_que_hint_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.76, 0.90))
	ding_que_hint_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.18))
	ding_que_hint_label.add_theme_constant_override("shadow_outline_size", 1)
	ding_que_status_label.visible = false
	ding_que_hint_label.visible = false
	var title_block := ding_que_status_label.get_parent() as Control
	if title_block != null:
		title_block.visible = false

	_apply_ding_que_button_style(
		ding_que_tiao_button,
		SICHUAN_TABLE_THEME.TIAO_QUE,
		SICHUAN_TABLE_THEME.TIAO_QUE.lightened(0.12),
		SICHUAN_TABLE_THEME.TIAO_QUE.darkened(0.28)
	)
	_apply_ding_que_button_style(
		ding_que_tong_button,
		SICHUAN_TABLE_THEME.TONG_QUE,
		SICHUAN_TABLE_THEME.TONG_QUE.lightened(0.12),
		SICHUAN_TABLE_THEME.TONG_QUE.darkened(0.28)
	)
	_apply_ding_que_button_style(
		ding_que_wan_button,
		SICHUAN_TABLE_THEME.WAN_QUE,
		SICHUAN_TABLE_THEME.WAN_QUE.lightened(0.12),
		SICHUAN_TABLE_THEME.WAN_QUE.darkened(0.28)
	)


func _apply_ding_que_button_style(button: Button, neon_color: Color, hover_color: Color, base_fill: Color) -> void:
	button.custom_minimum_size = Vector2(230, 230)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 78)
	button.add_theme_color_override("font_color", Color(0.96, 1.0, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.94, 1.0, 0.98, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.72, 0.66, 0.52))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08, 0.98))
	button.add_theme_constant_override("outline_size", 4)

	# Blender owns the bevel, jade body, ivory rim and copper keyline. Godot owns
	# the live glyph, focus, touch target and transient selection state.
	var normal := _ding_que_shell_style(button, false, false)
	var hover := _ding_que_shell_style(button, false, false)
	hover.modulate_color = Color(1.08, 1.08, 1.04, 1.0)
	hover.expand_margin_left = 4.0
	hover.expand_margin_right = 4.0
	hover.expand_margin_top = 6.0
	hover.expand_margin_bottom = 2.0
	var pressed := _ding_que_shell_style(button, true, false)
	var disabled := _ding_que_shell_style(button, false, false)
	disabled.modulate_color = Color(0.46, 0.50, 0.46, 0.66)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(hover_color, 0.92)
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(115)
	focus.expand_margin_left = 4.0
	focus.expand_margin_right = 4.0
	focus.expand_margin_top = 4.0
	focus.expand_margin_bottom = 4.0
	focus.shadow_color = Color(hover_color, 0.30)
	focus.shadow_size = 12

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.set_meta("ding_que_neon", neon_color)
	button.set_meta("ding_que_base_fill", base_fill)


func _ding_que_shell_style(button: Button, pressed: bool, selected: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _ding_que_shell_texture(button)
	style.draw_center = true
	style.modulate_color = Color(0.80, 0.80, 0.80, 1.0) if pressed else Color.WHITE
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 13.0 if pressed else 7.0
	style.content_margin_bottom = 7.0 if pressed else 13.0
	style.expand_margin_left = 4.0 if selected else 2.0
	style.expand_margin_right = 4.0 if selected else 2.0
	style.expand_margin_top = 12.0 if selected else 2.0
	style.expand_margin_bottom = 0.0 if selected else 2.0
	return style


func _ding_que_shell_texture(button: Button) -> Texture2D:
	if button == ding_que_tiao_button:
		return DING_QUE_TIAO_SHELL
	if button == ding_que_tong_button:
		return DING_QUE_TONG_SHELL
	return DING_QUE_WAN_SHELL


func _apply_ding_que_selection_state(suit: String) -> void:
	for entry in [
		{"button": ding_que_tiao_button, "suit": "tiao"},
		{"button": ding_que_tong_button, "suit": "tong"},
		{"button": ding_que_wan_button, "suit": "wan"},
	]:
		var button := entry.get("button") as Button
		var selected := str(entry.get("suit", "")) == suit
		var selected_style := _ding_que_shell_style(button, false, selected)
		button.add_theme_stylebox_override("normal", selected_style)
		button.add_theme_stylebox_override("hover", selected_style)
		button.add_theme_stylebox_override("pressed", selected_style)
		button.modulate = Color(1.08, 1.08, 1.04, 1.0) if selected else Color(0.58, 0.62, 0.58, 0.78)
		# Keep the native focus ring visible on the selected seal. Input is already
		# de-duplicated by pending_ding_que_suit, so disabling all three buttons
		# would only replace the selected shell with the dim disabled style.
		button.disabled = false
	if suit == "tiao":
		ding_que_tiao_button.grab_focus()
	elif suit == "tong":
		ding_que_tong_button.grab_focus()
	else:
		ding_que_wan_button.grab_focus()


func _reset_ding_que_visual_state() -> void:
	if ding_que_tiao_button == null:
		return
	pending_ding_que_suit = ""
	for button in [ding_que_tiao_button, ding_que_tong_button, ding_que_wan_button]:
		button.modulate = Color.WHITE
		button.add_theme_stylebox_override("normal", _ding_que_shell_style(button, false, false))
		button.add_theme_stylebox_override("hover", _ding_que_shell_style(button, false, false))
		button.add_theme_stylebox_override("pressed", _ding_que_shell_style(button, true, false))
		button.disabled = false


func get_ding_que_visual_contract() -> Dictionary:
	return {
		"choices": ["tiao", "tong", "wan"],
		"visible_labels": ["条", "筒", "万"],
		"button_minimum_size": Vector2(230.0, 230.0),
		"shell_pipeline": "blender_orthographic_baked_jade_seals",
		"shade_alpha": 0.13,
		"selected_visual_lift_px": 12.0,
		"selected_glow": "native_focus_ring",
		"selection_feedback_seconds": 0.14,
		"extra_confirmation_step": false,
		"reduced_motion": "static_selected_state_without_delay",
	}


func _refresh_settlement(snapshot: Dictionary) -> void:
	var show_panel := int(snapshot.get("current_phase", 0)) == 7
	if not show_panel:
		_reset_settlement_transition()
		_set_settlement_overlay_active(snapshot, false)
	else:
		var signature := _settlement_transition_signature_for(snapshot)
		if signature != settlement_transition_signature:
			_begin_settlement_transition(snapshot, signature)
		else:
			settlement_transition_pending_snapshot = snapshot.duplicate(true)
		_set_settlement_overlay_active(
			settlement_transition_pending_snapshot,
			settlement_transition_ready and not settlement_dismissed
		)
	top_settlement_info_button.visible = false
	top_next_round_button.visible = false
	if table_utility_bar != null:
		var preset_name := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
		table_utility_bar.call(
			"render",
			ai_helper_enabled,
			show_panel and settlement_transition_ready,
			settlement_dismissed,
			str(AI_PRESET_LABELS.get(preset_name, "骨灰")),
			opponent_hands_enabled
		)
		_layout_table_utility_bar()
	if not show_panel:
		settlement_dismissed = false
		settlement_selected_seat = -1


func _settlement_transition_signature_for(snapshot: Dictionary) -> String:
	var settlement_data: Dictionary = snapshot.get("settlement_data", {})
	return JSON.stringify({
		"round_index": settlement_data.get("round_index", snapshot.get("round_index", 0)),
		"end_reason": settlement_data.get("end_reason", ""),
		"score_changes": settlement_data.get("score_changes", {}),
		"winner_seats": settlement_data.get("winner_seats", []),
		"win_events": settlement_data.get("win_events", []),
	})


func _begin_settlement_transition(snapshot: Dictionary, signature: String) -> void:
	settlement_transition_generation += 1
	var generation := settlement_transition_generation
	settlement_transition_signature = signature
	settlement_transition_pending_snapshot = snapshot.duplicate(true)
	settlement_transition_ready = false
	settlement_dismissed = false
	settlement_selected_seat = -1
	settlement_transition_started_msec = Time.get_ticks_msec()
	settlement_transition_completed_msec = -1
	settlement_transition_hold_seconds = (
		SETTLEMENT_REDUCED_HOLD_SECONDS
		if bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
		else SETTLEMENT_HOLD_SECONDS
	)
	_wait_for_settlement_transition(generation, signature)


func _wait_for_settlement_transition(generation: int, signature: String) -> void:
	await get_tree().create_timer(settlement_transition_hold_seconds).timeout
	if generation != settlement_transition_generation:
		return
	if signature != settlement_transition_signature:
		return
	if int(settlement_transition_pending_snapshot.get("current_phase", 0)) != 7:
		return
	settlement_transition_ready = true
	settlement_transition_completed_msec = Time.get_ticks_msec()
	_set_settlement_overlay_active(settlement_transition_pending_snapshot, not settlement_dismissed)
	if table_utility_bar != null:
		var snapshot := settlement_transition_pending_snapshot
		var preset_name := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
		table_utility_bar.call("render", ai_helper_enabled, true, settlement_dismissed, str(AI_PRESET_LABELS.get(preset_name, "骨灰")), opponent_hands_enabled)
		_layout_table_utility_bar()


func _set_settlement_overlay_active(snapshot: Dictionary, active: bool) -> void:
	settlement_overlay.visible = active
	if settlement_overlay_v2 != null:
		settlement_overlay_v2.visible = false
	_apply_settlement_backdrop_state(active)
	if not active:
		return
	_layout_settlement_overlay()
	_render_settlement(snapshot)
	root_ui.move_child(settlement_overlay, root_ui.get_child_count() - 1)
	settlement_overlay.move_to_front()


func _reset_settlement_transition() -> void:
	settlement_transition_generation += 1
	settlement_transition_signature = ""
	settlement_transition_pending_snapshot = {}
	settlement_transition_ready = false
	settlement_transition_started_msec = -1
	settlement_transition_completed_msec = -1
	settlement_transition_hold_seconds = SETTLEMENT_HOLD_SECONDS


func force_complete_settlement_transition_for_test() -> void:
	if settlement_transition_signature.is_empty() or settlement_transition_pending_snapshot.is_empty():
		return
	settlement_transition_generation += 1
	settlement_transition_ready = true
	settlement_transition_completed_msec = Time.get_ticks_msec()
	_set_settlement_overlay_active(settlement_transition_pending_snapshot, not settlement_dismissed)


func get_settlement_transition_contract() -> Dictionary:
	var elapsed_seconds := -1.0
	if settlement_transition_started_msec >= 0:
		var end_msec := settlement_transition_completed_msec
		if end_msec < 0:
			end_msec = Time.get_ticks_msec()
		elapsed_seconds = float(end_msec - settlement_transition_started_msec) / 1000.0
	return {
		"normal_hold_seconds": SETTLEMENT_HOLD_SECONDS,
		"reduced_hold_seconds": SETTLEMENT_REDUCED_HOLD_SECONDS,
		"active_hold_seconds": settlement_transition_hold_seconds,
		"elapsed_seconds": elapsed_seconds,
		"signature": settlement_transition_signature,
		"ready": settlement_transition_ready,
		"overlay_visible": settlement_overlay.visible,
		"authoritative_score_path": "settlement_data/score_changes",
		"terminal_ledger_preserved": true,
	}


func _apply_settlement_backdrop_state(active: bool) -> void:
	safe_area.modulate = Color(0.62, 0.66, 0.62, 0.24) if active else Color(1.0, 1.0, 1.0, 1.0)
	settlement_shade.visible = active
	settlement_shade.color = Color(0.03, 0.07, 0.05, 0.76) if active else Color(0.02, 0.05, 0.04, 0.0)


func _refresh_round_result_overlay(snapshot: Dictionary) -> void:
	if round_result_overlay == null:
		return
	round_result_banner.visible = false
	for label in seat_result_labels.values():
		(label as Label).visible = false


func _seat_result_anchor_rect(seat: int) -> Rect2:
	match seat:
		0:
			return self_hand_host.get_global_rect()
		1:
			return player_left_host.get_global_rect()
		2:
			return player_top_host.get_global_rect()
		3:
			return player_right_host.get_global_rect()
	return Rect2(Vector2.ZERO, Vector2(120.0, 120.0))


func _schedule_ai_progress_if_needed(snapshot: Dictionary) -> void:
	if int(snapshot.get("current_phase", 0)) in [2, 7] or bool(snapshot.get("human_ding_que_pending", false)):
		ai_turn_timer.stop()
		ai_reaction_timer.stop()
		return
	if game_manager.is_ai_reaction_pending():
		_clear_draw_transition_block("schedule_ai_reaction")
	elif draw_transition_active and not game_manager.is_ai_turn_ready():
		ai_turn_timer.stop()
		ai_reaction_timer.stop()
		return

	if game_manager.is_ai_turn_ready():
		if draw_transition_active:
			ai_turn_timer.stop()
		elif ai_turn_timer.is_stopped():
			_start_ai_turn_action_timer()
	else:
		ai_turn_timer.stop()
		ai_turn_timer_started_at_ms = 0

	if game_manager.is_ai_reaction_pending():
		if ai_reaction_timer.is_stopped():
			_start_ai_reaction_action_timer()
	else:
		ai_reaction_timer.stop()
		ai_reaction_timer_started_at_ms = 0


func _phase_text(phase: int, snapshot: Dictionary) -> String:
	var use_ding_que := bool(snapshot.get("rules", {}).get("use_ding_que_phase", true))
	match phase:
		2:
			return "庄家掷骰开牌中"
		3:
			return "定缺阶段" if use_ding_que else "庄家首打准备中"
		5:
			return "请先处理手牌" if bool(snapshot.get("human_can_discard", false)) else "等待其他玩家行动"
		6:
			return "当前存在可响应操作"
		7:
			return "本局结算"
		_:
			return "等待牌局开始"


func _self_waiting_text(snapshot: Dictionary) -> String:
	if bool(snapshot.get("human_ding_que_pending", false)):
		return "请先完成当前选择。"
	if int(snapshot.get("current_phase", 0)) == 6:
		return "等待你决定是否碰、杠、胡或过。"
	return "当前不是你的回合。"


func _should_show_ding_que_badges(snapshot: Dictionary) -> bool:
	if not bool(snapshot.get("rules", {}).get("use_ding_que_phase", true)):
		return false
	var self_player := _player_by_seat(snapshot.get("players", []), 0)
	if str(self_player.get("ding_que", "")) == "":
		return false
	return int(snapshot.get("current_phase", 0)) != 2


func _player_by_seat(players: Array, seat: int) -> Dictionary:
	for player in players:
		if int(player.get("seat", -1)) == seat:
			return player
	return {}


func _meld_summary_text(prefix: String, player: Dictionary) -> String:
	var melds: Array = player.get("melds", [])
	if melds.is_empty():
		return "%s：暂无副露" % prefix
	var parts: Array[String] = []
	for meld in melds:
		var meld_type := str(meld.get("type", "")).to_upper()
		var tile_name := "?"
		var tiles: Array = meld.get("tiles", [])
		if not tiles.is_empty():
			tile_name = str(tiles[0].get("display_name", "?"))
		parts.append("%s %s" % [meld_type, tile_name])
	return "%s：%s" % [prefix, " / ".join(parts)]


func _discard_summary_text(prefix: String, player: Dictionary) -> String:
	var discards: Array = player.get("discards", [])
	if discards.is_empty():
		return "%s：暂无" % prefix
	var counts := {"wan": 0, "tiao": 0, "tong": 0}
	var tail_names: Array[String] = []
	for tile in discards:
		var suit := str(tile.get("suit", ""))
		if counts.has(suit):
			counts[suit] = int(counts.get(suit, 0)) + 1
		tail_names.append(str(tile.get("display_name", "?")))
	var recent := tail_names.slice(maxi(0, tail_names.size() - 2), tail_names.size())
	return "%s：万%d 条%d 筒%d 近%s" % [
		prefix,
		int(counts["wan"]),
		int(counts["tiao"]),
		int(counts["tong"]),
		"/".join(recent),
	]


func _render_settlement(snapshot: Dictionary) -> void:
	var settlement_data: Dictionary = snapshot.get("settlement_data", {})
	var settlement_view_data := settlement_data.duplicate(true)
	settlement_view_data["use_ding_que_phase"] = bool(snapshot.get("rules", {}).get("use_ding_que_phase", true))
	var players: Array = snapshot.get("players", [])
	if players.is_empty():
		settlement_round_label.text = "本局结算"
		settlement_hero_badge.text = "本局最佳"
		settlement_hero_name.text = "暂无玩家数据"
		settlement_hero_result.text = ""
		settlement_hero_result.visible = false
		settlement_hero_summary.text = ""
		settlement_hero_summary.visible = false
		settlement_hero_hu.text = "0胡"
		settlement_hero_fan.text = "0番 / 0分"
		settlement_hero_score.text = "0"
		_clear_children(settlement_player_list)
		_clear_children(settlement_hand_row)
		_clear_children(settlement_breakdown_list)
		return
	var score_changes: Dictionary = settlement_view_data.get("score_changes", {})
	var default_focus_seat := _resolve_settlement_focus_seat(players, settlement_view_data, score_changes)
	var best_seats := _resolve_settlement_best_seats(players, score_changes)
	var focus_seat := settlement_selected_seat
	if focus_seat == -1 or _player_by_seat(players, focus_seat).is_empty():
		focus_seat = default_focus_seat
		settlement_selected_seat = focus_seat
	var round_delta := int(score_changes.get(focus_seat, 0))
	var round_prefix := "+" if round_delta > 0 else ""
	var dealer_seat := int(settlement_view_data.get("dealer_seat", snapshot.get("current_dealer_seat", 0)))

	settlement_round_label.text = "第 %d 局 · 庄家%s · %s" % [
		int(settlement_view_data.get("round_index", snapshot.get("round_index", 1))),
		_seat_name(dealer_seat),
		_settlement_end_reason_text(str(settlement_view_data.get("end_reason", ""))),
	]
	settlement_player_list_title.text = "本局结算"
	settlement_breakdown_title.text = "分数明细"
	settlement_hero_badge.text = "本局最佳"
	settlement_hero_badge.visible = best_seats.has(focus_seat)
	var hero_result_text := _build_hero_result_text(focus_seat, settlement_view_data, round_delta)
	settlement_hero_name.text = "%s %s" % [_settlement_display_name(focus_seat), hero_result_text]
	settlement_hero_result.text = hero_result_text
	settlement_hero_result.visible = false
	settlement_hero_summary.text = ""
	settlement_hero_summary.visible = false
	settlement_hero_hu.text = _build_hero_hu_text(focus_seat, settlement_view_data)
	settlement_hero_fan.text = _build_hero_fan_text(focus_seat, settlement_view_data)
	settlement_hero_score.text = "%s%d" % [round_prefix, round_delta]

	_render_settlement_player_list(players, score_changes, focus_seat, dealer_seat, best_seats)
	_render_settlement_hand(players, settlement_view_data, focus_seat)
	_render_settlement_breakdown(players, settlement_view_data, focus_seat, round_delta)
	_apply_settlement_visuals(round_delta)


func _resolve_settlement_focus_seat(players: Array, settlement_data: Dictionary, score_changes: Dictionary) -> int:
	var winner_seats: Array = settlement_data.get("winner_seats", [])
	if not winner_seats.is_empty():
		return int(winner_seats[0])
	var best_seat := 0
	var best_delta := -999999
	for player in players:
		var seat := int(player.get("seat", 0))
		var delta := int(score_changes.get(seat, -999999))
		if delta > best_delta:
			best_delta = delta
			best_seat = seat
	return best_seat


func _resolve_settlement_best_seats(players: Array, score_changes: Dictionary) -> Array[int]:
	var best_seats: Array[int] = []
	var best_delta := -999999
	for player in players:
		var seat := int(player.get("seat", 0))
		var delta := int(score_changes.get(seat, -999999))
		if delta > best_delta:
			best_delta = delta
			best_seats.clear()
			best_seats.append(seat)
		elif delta == best_delta:
			best_seats.append(seat)
	return best_seats


func _render_settlement_player_list(players: Array, score_changes: Dictionary, focus_seat: int, dealer_seat: int, best_seats: Array[int]) -> void:
	_clear_children(settlement_player_list)
	var scale := _settlement_content_scale()
	var sorted_players := players.duplicate()
	sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(score_changes.get(int(a.get("seat", 0)), 0)) > int(score_changes.get(int(b.get("seat", 0)), 0))
	)

	for player in sorted_players:
		var seat := int(player.get("seat", 0))
		var delta := int(score_changes.get(seat, 0))
		var row_button := Button.new()
		row_button.flat = true
		row_button.focus_mode = Control.FOCUS_NONE
		row_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_button.custom_minimum_size = Vector2(0, 118 * scale)
		row_button.add_theme_stylebox_override("normal", _build_settlement_list_row_style(seat == focus_seat, delta))
		row_button.add_theme_stylebox_override("hover", _build_settlement_list_row_hover_style(seat == focus_seat, delta))
		row_button.add_theme_stylebox_override("pressed", _build_settlement_list_row_style(seat == focus_seat, delta))
		row_button.add_theme_stylebox_override("focus", _build_settlement_list_row_hover_style(seat == focus_seat, delta))
		row_button.pressed.connect(_on_settlement_player_selected.bind(seat))
		row_button.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		row_button.add_theme_font_size_override("font_size", 1)
		settlement_player_list.add_child(row_button)

		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		row_button.add_child(card)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", int(round(16 * scale)))
		margin.add_theme_constant_override("margin_top", int(round(10 * scale)))
		margin.add_theme_constant_override("margin_right", int(round(16 * scale)))
		margin.add_theme_constant_override("margin_bottom", int(round(10 * scale)))
		card.add_child(margin)

		var inner := HBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", int(round(12 * scale)))
		margin.add_child(inner)

		var avatar := Label.new()
		avatar.custom_minimum_size = Vector2(76, 76) * scale
		avatar.text = _settlement_avatar_text(seat)
		avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_settlement_label_style(avatar, seat == focus_seat, true, false, true)
		if seat == focus_seat:
			_apply_settlement_focus_row_text_style(avatar)
		avatar.add_theme_font_size_override("font_size", int(round(30 * scale)))
		avatar.add_theme_stylebox_override("normal", _build_settlement_avatar_style(seat == focus_seat))
		inner.add_child(avatar)

		var name_box := VBoxContainer.new()
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_theme_constant_override("separation", int(round(4 * scale)))
		inner.add_child(name_box)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", int(round(8 * scale)))
		name_box.add_child(name_row)

		var name_label := Label.new()
		name_label.text = _settlement_display_name(seat)
		_apply_settlement_label_style(name_label, seat == focus_seat, true)
		name_label.add_theme_font_size_override("font_size", clampi(int(round((29 if seat == focus_seat else 26) * scale)), 22, 30))
		if seat == focus_seat:
			_apply_settlement_focus_row_text_style(name_label)
		name_row.add_child(name_label)

		if seat == dealer_seat:
			var dealer_badge := Label.new()
			dealer_badge.text = "庄"
			_apply_settlement_label_style(dealer_badge, true, true)
			dealer_badge.add_theme_font_size_override("font_size", int(round(19 * scale)))
			dealer_badge.add_theme_stylebox_override("normal", _build_settlement_dealer_badge_style())
			name_row.add_child(dealer_badge)

		if best_seats.has(seat):
			var best_badge := Label.new()
			best_badge.text = "本局最佳"
			_apply_settlement_label_style(best_badge, true, true, false, true)
			best_badge.add_theme_font_size_override("font_size", int(round(16 * scale)))
			best_badge.add_theme_stylebox_override("normal", _build_settlement_hero_badge_style())
			name_row.add_child(best_badge)

		var total_label := Label.new()
		total_label.text = "总分 %d" % int(player.get("score", 0))
		_apply_settlement_label_style(total_label, seat == focus_seat, false, true)
		total_label.add_theme_font_size_override("font_size", clampi(int(round(24 * scale)), 22, 26))
		if seat == focus_seat:
			_apply_settlement_focus_row_text_style(total_label, true)
		name_box.add_child(total_label)

		var delta_label := Label.new()
		var prefix := "+" if delta > 0 else ""
		delta_label.text = "%s%d" % [prefix, delta]
		_apply_settlement_label_style(delta_label, seat == focus_seat, true)
		delta_label.add_theme_font_size_override("font_size", int(round((42 if seat == focus_seat else 36) * scale)))
		if seat == focus_seat:
			_apply_settlement_focus_row_text_style(delta_label)
		elif delta < 0:
			delta_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.84, 1.0))
		inner.add_child(delta_label)


func _render_settlement_hand(players: Array, settlement_data: Dictionary, focus_seat: int) -> void:
	_clear_children(settlement_hand_row)
	var scale := _settlement_content_scale()
	var player := _player_by_seat(players, focus_seat)
	if player.is_empty():
		return

	var row_card := Panel.new()
	row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_card.add_theme_stylebox_override("panel", _build_settlement_hand_row_style(true))
	settlement_hand_row.add_child(row_card)

	var row_margin := MarginContainer.new()
	row_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_margin.add_theme_constant_override("margin_left", int(round(18 * scale)))
	row_margin.add_theme_constant_override("margin_top", int(round(14 * scale)))
	row_margin.add_theme_constant_override("margin_right", int(round(18 * scale)))
	row_margin.add_theme_constant_override("margin_bottom", int(round(14 * scale)))
	row_card.add_child(row_margin)

	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", int(round(10 * scale)))
	row_margin.add_child(group)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(round(12 * scale)))
	group.add_child(header)

	var name_label := Label.new()
	name_label.text = _settlement_display_name(focus_seat)
	_apply_settlement_label_style(name_label, true, true)
	name_label.add_theme_font_size_override("font_size", clampi(int(round(30 * scale)), 22, 30))
	header.add_child(name_label)

	if bool(player.get("has_won", false)):
		var win_badge := Label.new()
		win_badge.text = _settlement_win_badge_text(settlement_data, focus_seat)
		_apply_settlement_label_style(win_badge, true, false)
		win_badge.add_theme_stylebox_override("normal", _build_settlement_hero_badge_style())
		win_badge.add_theme_font_size_override("font_size", int(round(18 * scale)))
		header.add_child(win_badge)

	var use_ding_que := _settlement_uses_ding_que(settlement_data)
	var ding_que := str(player.get("ding_que", "")) if use_ding_que else ""
	if ding_que != "":
		var ding_que_label := Label.new()
		ding_que_label.text = _ding_que_display(ding_que)
		_apply_settlement_label_style(ding_que_label, true, false, true)
		ding_que_label.add_theme_stylebox_override("normal", _build_settlement_hand_tag_style(ding_que, true))
		ding_que_label.add_theme_font_size_override("font_size", int(round(18 * scale)))
		header.add_child(ding_que_label)

	var tiles := _build_settlement_hand_tiles(player, settlement_data, focus_seat)
	_render_settlement_all_tiles_row(group, tiles, player.get("melds", []), settlement_data, focus_seat)


func _render_settlement_all_tiles_row(parent: VBoxContainer, hand_tiles: Array, melds: Array, settlement_data: Dictionary, seat: int) -> void:
	var scale := _settlement_content_scale()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(round(14 * scale)))
	parent.add_child(row)

	var lane := HBoxContainer.new()
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.add_theme_constant_override("separation", int(round(8 * scale)))
	row.add_child(lane)

	if hand_tiles.is_empty() and melds.is_empty() and _find_focus_win_event(settlement_data, seat).is_empty():
		var empty_label := Label.new()
		empty_label.text = "无手牌"
		_apply_settlement_label_style(empty_label, true, false, true)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lane.add_child(empty_label)
		return

	for tile_data in hand_tiles:
		lane.add_child(_create_settlement_tile(tile_data, SETTLEMENT_TILE_SCALE * scale))

	for meld in melds:
		lane.add_child(_create_settlement_group_tag(_settlement_meld_tag_text(meld)))
		for tile_data in meld.get("tiles", []):
			lane.add_child(_create_settlement_tile(tile_data, SETTLEMENT_MELD_TILE_SCALE * scale))

	var win_event := _find_focus_win_event(settlement_data, seat)
	if not win_event.is_empty():
		var winning_tile: Dictionary = win_event.get("winning_tile", {})
		if not winning_tile.is_empty():
			lane.add_child(_create_settlement_group_tag(_settlement_win_badge_text(settlement_data, seat)))
			lane.add_child(_create_settlement_claim_tile(
				winning_tile,
				SETTLEMENT_WIN_TILE_SCALE * scale,
				seat,
				int(win_event.get("source_seat", seat)),
				str(win_event.get("win_type", ""))
			))


func _create_settlement_tile(tile_data: Dictionary, scale: float, highlight_winning: bool = false) -> Control:
	var tile: Control = TILE_SCENE.instantiate()
	tile.call("configure", tile_data, scale, false, false, false, false, highlight_winning)
	return tile


func _create_settlement_claim_tile(tile_data: Dictionary, scale: float, focus_seat: int, source_seat: int, win_type: String) -> Control:
	var tile: Control = _create_settlement_tile(tile_data, scale, true)
	if win_type in ["self_draw", "gang_self_draw"] or source_seat == focus_seat or source_seat < 0:
		return tile
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile_size: Vector2 = tile.custom_minimum_size
	wrapper.custom_minimum_size = tile_size
	wrapper.size = tile_size
	wrapper.add_child(tile)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = _settlement_claim_text(focus_seat, source_seat)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(tile_size.x * 0.82, maxf(30.0, tile_size.y * 0.26))
	badge.position = Vector2((tile_size.x - badge.custom_minimum_size.x) * 0.5, tile_size.y * 0.36)
	badge.add_theme_font_size_override("font_size", int(round(clampf(tile_size.y * 0.18, 15.0, 30.0))))
	_apply_settlement_label_style(badge, true, false)
	badge.add_theme_color_override("font_color", Color(0.34, 0.20, 0.02, 0.96))
	badge.add_theme_stylebox_override("normal", _build_settlement_claim_badge_style())
	wrapper.add_child(badge)
	return wrapper


func _create_settlement_group_tag(text: String) -> Label:
	var scale := _settlement_content_scale()
	var tag := Label.new()
	tag.custom_minimum_size = Vector2(78, 44) * scale
	tag.text = text
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_settlement_label_style(tag, true, false, true)
	tag.add_theme_font_size_override("font_size", int(round(22 * scale)))
	tag.add_theme_stylebox_override("normal", _build_settlement_group_tag_style())
	return tag


func _settlement_claim_text(focus_seat: int, source_seat: int) -> String:
	if source_seat == focus_seat:
		return "自摸"
	var direction := _settlement_claim_direction(focus_seat, source_seat)
	if direction == "":
		return "胡牌"
	if focus_seat == 0:
		return "%s%s" % [direction, _seat_relation_name(source_seat)]
	return "%s%s" % [direction, _settlement_display_name(source_seat)]


func _settlement_claim_direction(focus_seat: int, source_seat: int) -> String:
	match focus_seat:
		0:
			match source_seat:
				1:
					return "←"
				2:
					return "↑"
				3:
					return "→"
		1:
			match source_seat:
				0:
					return "→"
				2:
					return "↑"
				3:
					return "←"
		2:
			match source_seat:
				0:
					return "↓"
				1:
					return "→"
				3:
					return "←"
		3:
			match source_seat:
				0:
					return "←"
				1:
					return "↓"
				2:
					return "↑"
	return ""


func _seat_relation_name(source_seat: int) -> String:
	match source_seat:
		1:
			return "上家"
		2:
			return "对家"
		3:
			return "下家"
	return ""


func _build_settlement_claim_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.89, 0.36, 0.86)
	style.border_color = Color(0.72, 0.50, 0.08, 0.96)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_border_width_all(1)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


func _render_settlement_breakdown(players: Array, settlement_data: Dictionary, focus_seat: int, round_delta: int) -> void:
	_clear_children(settlement_breakdown_list)
	var scale := _settlement_content_scale()
	var header_card := Panel.new()
	header_card.custom_minimum_size = Vector2(0, 58 * scale)
	header_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_card.add_theme_stylebox_override("panel", _build_settlement_breakdown_row_style(true, false))
	settlement_breakdown_list.add_child(header_card)

	var header_margin := MarginContainer.new()
	header_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_margin.add_theme_constant_override("margin_left", int(round(20 * scale)))
	header_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	header_margin.add_theme_constant_override("margin_right", int(round(20 * scale)))
	header_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	header_card.add_child(header_margin)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", int(round(20 * scale)))
	header_margin.add_child(header)

	var header_reason := Label.new()
	header_reason.custom_minimum_size = Vector2(360, 0) * scale
	header_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_reason.text = "分数来源"
	_apply_settlement_label_style(header_reason, true, false, true)
	_apply_settlement_breakdown_label_style(header_reason, true)
	header.add_child(header_reason)

	var header_source := Label.new()
	header_source.custom_minimum_size = Vector2(280, 0) * scale
	header_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_source.text = "对象"
	_apply_settlement_label_style(header_source, true, false, true)
	_apply_settlement_breakdown_label_style(header_source, true)
	header.add_child(header_source)

	var header_factor := Label.new()
	header_factor.custom_minimum_size = Vector2(300, 0) * scale
	header_factor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_factor.text = "番/分"
	_apply_settlement_label_style(header_factor, true, false, true)
	_apply_settlement_breakdown_label_style(header_factor, true)
	header.add_child(header_factor)

	var header_score := Label.new()
	header_score.custom_minimum_size = Vector2(150, 0) * scale
	header_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_score.text = "本局得分"
	_apply_settlement_label_style(header_score, true, false, true)
	_apply_settlement_breakdown_label_style(header_score, true)
	header.add_child(header_score)

	var lines := _build_settlement_breakdown_lines(players, settlement_data, focus_seat, round_delta)
	for index in range(lines.size()):
		var item := lines[index]
		var row_card := Panel.new()
		row_card.custom_minimum_size = Vector2(0, 84 * scale)
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_card.add_theme_stylebox_override("panel", _build_settlement_breakdown_row_style(false, index % 2 == 0))
		settlement_breakdown_list.add_child(row_card)

		var row_margin := MarginContainer.new()
		row_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		row_margin.add_theme_constant_override("margin_left", int(round(20 * scale)))
		row_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
		row_margin.add_theme_constant_override("margin_right", int(round(20 * scale)))
		row_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
		row_card.add_child(row_margin)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", int(round(20 * scale)))
		row_margin.add_child(row)

		var reason_label := Label.new()
		reason_label.custom_minimum_size = Vector2(360, 0) * scale
		reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.text = str(item.get("reason", "-"))
		_apply_settlement_label_style(reason_label, true)
		_apply_settlement_breakdown_label_style(reason_label)
		row.add_child(reason_label)

		var source_label := Label.new()
		source_label.custom_minimum_size = Vector2(280, 0) * scale
		source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		source_label.text = str(item.get("source", "-"))
		_apply_settlement_label_style(source_label, true, false, true)
		_apply_settlement_breakdown_label_style(source_label)
		row.add_child(source_label)

		var factor_label := Label.new()
		factor_label.custom_minimum_size = Vector2(300, 0) * scale
		factor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		factor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		factor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		factor_label.text = str(item.get("factor", "-"))
		_apply_settlement_label_style(factor_label, true, false, true)
		_apply_settlement_breakdown_label_style(factor_label)
		row.add_child(factor_label)

		var score_label := Label.new()
		score_label.custom_minimum_size = Vector2(150, 0) * scale
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.text = str(item.get("score", "-"))
		_apply_settlement_label_style(score_label, true, false, true)
		_apply_settlement_breakdown_label_style(score_label, false, true)
		if str(item.get("score", "")).begins_with("-"):
			score_label.add_theme_color_override("font_color", Color(0.82, 0.46, 0.40, 1.0))
		else:
			score_label.add_theme_color_override("font_color", Color(0.73, 0.82, 0.62, 1.0) if str(item.get("score", "")) != "+0" else Color(0.86, 0.79, 0.62, 1.0))
		row.add_child(score_label)


func _build_settlement_breakdown_lines(players: Array, settlement_data: Dictionary, focus_seat: int, round_delta: int) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for event in settlement_data.get("win_events", []):
		var winner_seat: int = int(event.get("winner_seat", -1))
		var fan_detail: Dictionary = event.get("fan_detail", {})
		var labels: Array = fan_detail.get("labels", [])
		var reason := "%s（%s）" % [
			_win_type_display_name(str(event.get("win_type", "discard_win"))),
			"/".join(labels) if not labels.is_empty() else _hand_type_display_name(str(fan_detail.get("hand_type", "ping_hu"))),
		]
		var payer_names: Array[String] = []
		for seat in event.get("payer_seats", []):
			payer_names.append(_seat_name(int(seat)))
		var factor_text := _build_event_factor_text(event, players)
		var event_total_score := _resolve_event_total_score(event, players)
		var payer_seats: Array = event.get("payer_seats", [])
		if winner_seat == focus_seat:
			lines.append(
				{
					"reason": reason,
					"source": " / ".join(payer_names) if not payer_names.is_empty() else _seat_name(focus_seat),
					"factor": factor_text,
					"score": "+%d" % event_total_score,
				}
			)
		elif payer_seats.has(focus_seat):
			lines.append(
				{
					"reason": "支付%s" % reason,
					"source": _seat_name(winner_seat),
					"factor": factor_text,
					"score": "-%d" % _resolve_event_payment_for_payer(event, focus_seat, players),
				}
			)

	for event in settlement_data.get("gang_events", []):
		if str(event.get("related_outcome", "")) == "gang_discard_win":
			continue
		var actor_seat: int = int(event.get("actor_seat", -1))
		var gang_total_score: int = _resolve_gang_event_total_score(event)
		var gang_unit_score: int = _resolve_gang_unit_score(str(event.get("gang_type", "")))
		var gang_payers: Array = event.get("payer_seats", [])
		if actor_seat == focus_seat:
			lines.append(
				{
					"reason": _gang_type_display_name(str(event.get("gang_type", "melded_gang"))),
					"source": _refund_payers_display(gang_payers),
					"factor": "杠分",
					"score": "+%d" % gang_total_score,
				}
			)
		elif gang_payers.has(focus_seat):
			lines.append(
				{
					"reason": "支付%s" % _gang_type_display_name(str(event.get("gang_type", "melded_gang"))),
					"source": _seat_name(actor_seat),
					"factor": "杠分",
					"score": "-%d" % gang_unit_score,
				}
			)

	for refund in settlement_data.get("tui_gang_refunds", []):
		var refund_actor_seat: int = int(refund.get("actor_seat", -1))
		var refund_unit_score: int = _resolve_gang_unit_score(str(refund.get("gang_type", "")))
		var refund_payers: Array = refund.get("payer_seats", [])
		if refund_actor_seat == focus_seat:
			lines.append(
				{
					"reason": "退回%s税" % _gang_type_display_name(str(refund.get("gang_type", ""))),
					"source": _refund_payers_display(refund_payers),
					"factor": "退税",
					"score": "-%d" % (refund_unit_score * refund_payers.size()),
				}
			)
		elif refund_payers.has(focus_seat):
			lines.append(
				{
					"reason": "收回退税",
					"source": _seat_name(refund_actor_seat),
					"factor": "退税",
					"score": "+%d" % refund_unit_score,
				}
			)

	for event in settlement_data.get("transfer_events", []):
		if str(event.get("transfer_type", "")) != "hu_jiao_zhuan_yi":
			continue
		var transfer_winner_seat: int = int(event.get("to_seat", -1))
		var transfer_unit_score: int = _resolve_gang_unit_score(str(event.get("gang_type", "")))
		var transfer_payers: Array = event.get("payer_seats", [])
		if transfer_winner_seat == focus_seat:
			lines.append(
				{
					"reason": "呼叫转移",
					"source": _refund_payers_display(transfer_payers),
					"factor": "转移杠分",
					"score": "+%d" % (transfer_unit_score * transfer_payers.size()),
				}
			)
		elif transfer_payers.has(focus_seat):
			lines.append(
				{
					"reason": "支付呼叫转移",
					"source": _seat_name(transfer_winner_seat),
					"factor": "转移杠分",
					"score": "-%d" % transfer_unit_score,
				}
			)

	var focus_assessment := _find_draw_assessment_by_seat(settlement_data, focus_seat)
	if not focus_assessment.is_empty():
		var focus_is_hua_zhu := bool(focus_assessment.get("hua_zhu", false))
		var focus_is_ting := bool(focus_assessment.get("is_ting", false))
		for item in settlement_data.get("draw_assessment", []):
			var seat := int(item.get("seat", -1))
			if seat == focus_seat:
				continue
			var target_is_ting := bool(item.get("is_ting", false))
			var target_is_hua_zhu := bool(item.get("hua_zhu", false))
			var score_text := ""
			var reason_text := ""
			var source_text := _seat_name(seat)
			var factor_text := ""

			if focus_is_hua_zhu and target_is_ting:
				reason_text = "花猪赔付"
				factor_text = _build_cha_jiao_factor_text(item)
				score_text = "-%d" % maxi(1, int(item.get("cha_jiao_score", 1)))
			elif not focus_is_ting and not focus_is_hua_zhu and target_is_ting:
				reason_text = "查叫赔付"
				factor_text = _build_cha_jiao_factor_text(item)
				score_text = "-%d" % maxi(1, int(item.get("cha_jiao_score", 1)))
			elif focus_is_ting and target_is_hua_zhu:
				reason_text = "花猪赔付"
				factor_text = _build_cha_jiao_factor_text(focus_assessment)
				score_text = "+%d" % maxi(1, int(focus_assessment.get("cha_jiao_score", 1)))
			elif focus_is_ting and not target_is_ting:
				reason_text = "查叫赔付"
				factor_text = _build_cha_jiao_factor_text(focus_assessment)
				score_text = "+%d" % maxi(1, int(focus_assessment.get("cha_jiao_score", 1)))

			if reason_text == "":
				continue
			lines.append({
				"reason": reason_text,
				"source": source_text,
				"factor": factor_text if factor_text != "" else "查叫",
				"score": score_text,
			})

	# 已胡玩家通常不会再进入 draw_assessment，但牌墙流局时仍按规则参与
	# 查大叫收付。过去总账已经计入这笔钱，明细却漏掉，造成画面上
	# “自摸 +4、暗杠 +6，最终却 +11”的假象。这里逐项镜像计分器的
	# winner draw targets，让最终收分严格等于用户能看到的明细合计。
	var winner_draw_targets := _build_settlement_winner_draw_targets(settlement_data)
	var focus_winner_draw_score := int(winner_draw_targets.get(focus_seat, 0))
	if focus_winner_draw_score > 0:
		for item in settlement_data.get("draw_assessment", []):
			if bool(item.get("hua_zhu", false)) or bool(item.get("is_ting", false)):
				continue
			lines.append({
				"reason": "查大叫收益（已胡）",
				"source": _seat_name(int(item.get("seat", -1))),
				"factor": "已胡最大牌分",
				"score": "+%d" % focus_winner_draw_score,
			})
	elif not focus_assessment.is_empty() and not bool(focus_assessment.get("hua_zhu", false)) and not bool(focus_assessment.get("is_ting", false)):
		for winner_seat in winner_draw_targets.keys():
			var winner_score := int(winner_draw_targets.get(winner_seat, 0))
			if winner_score <= 0 or int(winner_seat) == focus_seat:
				continue
			lines.append({
				"reason": "查大叫赔付（对方已胡）",
				"source": _seat_name(int(winner_seat)),
				"factor": "已胡最大牌分",
				"score": "-%d" % winner_score,
			})

	if lines.is_empty():
		lines.append({"reason": "本局暂无细分事件", "source": _seat_name(focus_seat), "factor": "-", "score": "%s%d" % ["+" if round_delta > 0 else "", round_delta]})
	else:
		# 账本始终是最终权威值；若未来新增计分事件而明细构建尚未同步，
		# 也必须把差额作为可见行列出，禁止再次出现“明细相加不等于顶部”。
		var visible_total := _sum_settlement_breakdown_scores(lines)
		var undisplayed_delta := round_delta - visible_total
		if undisplayed_delta != 0:
			lines.append({
				"reason": "其他结算调整",
				"source": _seat_name(focus_seat),
				"factor": "账本对齐",
				"score": "%+d" % undisplayed_delta,
			})
	return lines


func _build_settlement_winner_draw_targets(settlement_data: Dictionary) -> Dictionary:
	var targets := {}
	for event in settlement_data.get("win_events", []):
		var winner_seat := int(event.get("winner_seat", -1))
		var fan_detail: Dictionary = event.get("fan_detail", {})
		var capped_fan := int(fan_detail.get("capped_fan", 0))
		# 查大叫对已胡玩家只取胡牌基础分；自摸固定加底已经包含在自摸
		# 明细中，不在这里重复放大或重复支付。
		var hand_score := int(fan_detail.get("hand_score", _resolve_basic_score_from_fan(capped_fan)))
		targets[winner_seat] = maxi(int(targets.get(winner_seat, 0)), hand_score)
	return targets


func _sum_settlement_breakdown_scores(lines: Array[Dictionary]) -> int:
	var total := 0
	for item in lines:
		var score_text := str(item.get("score", "0")).strip_edges()
		if score_text.is_valid_int():
			total += int(score_text)
	return total


func get_settlement_ledger_contract(snapshot: Dictionary) -> Dictionary:
	var settlement_data: Dictionary = snapshot.get("settlement_data", {})
	var score_changes: Dictionary = settlement_data.get("score_changes", {})
	var players: Array = snapshot.get("players", [])
	var seat_rows := {}
	var net_change := 0
	var all_detail_sums_match := true
	for seat in range(PLAYER_COUNT):
		var authoritative_delta := int(score_changes.get(seat, 0))
		var lines := _build_settlement_breakdown_lines(players, settlement_data, seat, authoritative_delta)
		var detail_sum := _sum_settlement_breakdown_scores(lines)
		seat_rows[seat] = {
			"authoritative_delta": authoritative_delta,
			"detail_sum": detail_sum,
			"matches": detail_sum == authoritative_delta,
			"lines": lines,
		}
		net_change += authoritative_delta
		all_detail_sums_match = all_detail_sums_match and detail_sum == authoritative_delta
	return {
		"authoritative_path": "settlement_data/score_changes",
		"score_changes": score_changes.duplicate(true),
		"net_change": net_change,
		"net_zero": net_change == 0,
		"all_detail_sums_match": all_detail_sums_match,
		"ui_applies_self_draw_bonus": false,
		"seat_rows": seat_rows,
	}


func _build_cha_jiao_reason_text(item: Dictionary) -> String:
	var tile: Dictionary = item.get("cha_jiao_tile", {})
	var tile_name := str(tile.get("display_name", ""))
	if tile_name == "":
		return "流局判定（有叫）"
	return "流局查叫（听%s）" % tile_name


func _build_cha_jiao_factor_text(item: Dictionary) -> String:
	var fan := int(item.get("cha_jiao_fan", 0))
	var score := int(item.get("cha_jiao_score", 0))
	if fan <= 0 and score <= 0:
		return "查叫"
	return "%d番/%d分" % [maxi(1, fan), maxi(1, score)]


func _build_cha_jiao_payer_text(settlement_data: Dictionary, focus_seat: int) -> String:
	var payers: Array[String] = []
	for item in settlement_data.get("draw_assessment", []):
		var seat := int(item.get("seat", -1))
		if seat == focus_seat:
			continue
		if bool(item.get("hua_zhu", false)) or not bool(item.get("is_ting", false)):
			payers.append(_seat_name(seat))
	return " / ".join(payers) if not payers.is_empty() else "-"


func _build_cha_jiao_target_text(settlement_data: Dictionary) -> String:
	var targets: Array[String] = []
	for item in settlement_data.get("draw_assessment", []):
		if bool(item.get("is_ting", false)):
			targets.append(_seat_name(int(item.get("seat", -1))))
	return " / ".join(targets) if not targets.is_empty() else "-"


func _format_draw_reward_total(settlement_data: Dictionary, focus_seat: int) -> String:
	var total := 0
	for item in settlement_data.get("draw_assessment", []):
		var seat := int(item.get("seat", -1))
		if seat == focus_seat:
			continue
		if bool(item.get("hua_zhu", false)) or not bool(item.get("is_ting", false)):
			total += maxi(1, int(_find_draw_assessment_by_seat(settlement_data, focus_seat).get("cha_jiao_score", 1)))
	return "+%d" % total


func _format_draw_penalty_total(settlement_data: Dictionary, focus_seat: int) -> String:
	var total := 0
	for item in settlement_data.get("draw_assessment", []):
		if bool(item.get("is_ting", false)):
			total += maxi(1, int(item.get("cha_jiao_score", 1)))
	return "-%d" % total if total > 0 else "+0"


func _find_draw_assessment_by_seat(settlement_data: Dictionary, seat: int) -> Dictionary:
	for item in settlement_data.get("draw_assessment", []):
		if int(item.get("seat", -1)) == seat:
			return item
	return {}


func _find_focus_win_event(settlement_data: Dictionary, focus_seat: int) -> Dictionary:
	for event in settlement_data.get("win_events", []):
		if int(event.get("winner_seat", -1)) == focus_seat:
			return event
	return {}


func _build_settlement_hand_tiles(player: Dictionary, settlement_data: Dictionary, seat: int) -> Array:
	var hand_tiles: Array = player.get("hand_tiles", []).duplicate(true)
	var ding_que_suit := str(player.get("ding_que", "")) if _settlement_uses_ding_que(settlement_data) else ""
	var display_tiles := _build_display_hand_tiles(hand_tiles, -1, ding_que_suit)
	var win_event := _find_focus_win_event(settlement_data, seat)
	if win_event.is_empty():
		return display_tiles

	var winning_tile: Dictionary = win_event.get("winning_tile", {})
	if winning_tile.is_empty():
		return display_tiles

	for index in range(display_tiles.size()):
		var tile: Dictionary = display_tiles[index]
		if int(tile.get("id", -1)) == int(winning_tile.get("id", -1)):
			display_tiles.remove_at(index)
			break
	return display_tiles


func _settlement_uses_ding_que(settlement_data: Dictionary) -> bool:
	return bool(settlement_data.get("use_ding_que_phase", false))


func _settlement_win_badge_text(settlement_data: Dictionary, seat: int) -> String:
	var event := _find_focus_win_event(settlement_data, seat)
	if event.is_empty():
		return "已胡"
	return _win_type_brief_text(str(event.get("win_type", "")))


func _settlement_meld_tag_text(meld: Dictionary) -> String:
	var meld_type := str(meld.get("type", ""))
	if meld_type == "peng":
		return "碰"
	if meld_type == "gang":
		match str(meld.get("gang_subtype", "")):
			"an_gang":
				return "暗杠"
			"add_gang":
				return "补杠"
			_:
				return "杠"
	return "副露"


func _win_type_brief_text(win_type: String) -> String:
	match win_type:
		"self_draw":
			return "自摸"
		"gang_self_draw":
			return "杠上花"
		"discard_win":
			return "点炮胡"
		"gang_discard_win":
			return "杠上炮"
		"qiang_gang_hu":
			return "抢杠胡"
		_:
			return "已胡"


func _build_hero_summary_text(focus_seat: int, settlement_data: Dictionary) -> String:
	var event := _find_focus_win_event(settlement_data, focus_seat)
	if event.is_empty():
		return ""
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var labels: Array = fan_detail.get("labels", [])
	var label_text := "/".join(labels)
	if label_text.is_empty():
		label_text = _hand_type_display_name(str(fan_detail.get("hand_type", "ping_hu")))
	var payer_names: Array[String] = []
	for seat in event.get("payer_seats", []):
		payer_names.append(_seat_name(int(seat)))
	var source_text := "对象：%s" % (" / ".join(payer_names) if not payer_names.is_empty() else _seat_name(focus_seat))
	var fan_text := "牌型：%s" % label_text
	var score_text := _build_event_factor_text(event, _current_players())
	return "%s · %s\n%s · %s" % [_win_type_display_name(str(event.get("win_type", "discard_win"))), fan_text, score_text, source_text]


func _build_hero_result_text(focus_seat: int, settlement_data: Dictionary, round_delta: int) -> String:
	var event := _find_focus_win_event(settlement_data, focus_seat)
	if not event.is_empty():
		var win_type := str(event.get("win_type", "discard_win"))
		match win_type:
			"self_draw", "gang_self_draw":
				return "自摸收分"
			"discard_win":
				return "点炮胡牌"
			"qiang_gang_hu":
				return "抢杠胡"
			_:
				return "胡牌收分"
	if str(settlement_data.get("end_reason", "")) == "draw_wall_empty":
		var item := _find_draw_assessment_by_seat(settlement_data, focus_seat)
		if bool(item.get("is_ting", false)):
			return "流局查叫"
		return "流局退税"
	return "本局 %+d 分" % round_delta


func _build_hero_hu_text(focus_seat: int, settlement_data: Dictionary) -> String:
	var count := 0
	for event in settlement_data.get("win_events", []):
		if int(event.get("winner_seat", -1)) == focus_seat:
			count += 1
	return "%d胡" % max(1, count)


func _build_hero_fan_text(focus_seat: int, settlement_data: Dictionary) -> String:
	var event := _find_focus_win_event(settlement_data, focus_seat)
	if event.is_empty():
		return "0番 / 0分"
	return _build_event_factor_text(event, _current_players())


func _format_fan_and_basic_score(fan_detail: Dictionary, win_type: String = "") -> String:
	var capped_fan := int(fan_detail.get("capped_fan", 0))
	var hand_score := int(fan_detail.get("hand_score", _resolve_basic_score_from_fan(capped_fan)))
	var basic_score := int(fan_detail.get("per_payer_score", hand_score))
	var fan_text := "%d番（封顶）" % capped_fan if capped_fan >= 4 else "%d番" % capped_fan
	if basic_score != hand_score and (win_type == "self_draw" or win_type == "gang_self_draw"):
		return "%s / %d+自摸1=%d分" % [fan_text, hand_score, basic_score]
	return "%s / %d分" % [fan_text, basic_score]


func _build_event_factor_text(event: Dictionary, _players: Array) -> String:
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var win_type := str(event.get("win_type", "discard_win"))
	return _format_fan_and_basic_score(fan_detail, win_type)


func _resolve_basic_score_from_fan(capped_fan: int) -> int:
	return int(pow(2.0, maxi(0, capped_fan)))


func _current_players() -> Array:
	return Array(last_snapshot.get("players", []))


func _resolve_event_total_score(event: Dictionary, players: Array) -> int:
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var payer_seats: Array = event.get("payer_seats", [])
	var total := 0
	for payer in payer_seats:
		total += _resolve_event_payment_for_payer(event, int(payer), players)
	return total


func _resolve_event_payment_for_payer(event: Dictionary, _payer_seat: int, _players: Array) -> int:
	var fan_detail: Dictionary = event.get("fan_detail", {})
	var win_type: String = str(event.get("win_type", "discard_win"))
	var capped_fan := int(fan_detail.get("capped_fan", 0))
	var hand_score := int(fan_detail.get("hand_score", _resolve_basic_score_from_fan(capped_fan)))
	if win_type == "self_draw" or win_type == "gang_self_draw":
		# The rules layer owns the self-draw +1 and exports the authoritative
		# per-payer amount. The settlement UI must never manufacture another +1.
		return int(fan_detail.get("per_payer_score", hand_score))
	return hand_score


func _resolve_gang_event_total_score(event: Dictionary) -> int:
	var payer_seats: Array = event.get("payer_seats", [])
	var payer_count: int = max(1, payer_seats.size())
	return _resolve_gang_unit_score(str(event.get("gang_type", ""))) * payer_count


func _resolve_gang_unit_score(gang_type: String) -> int:
	match gang_type:
		"melded_gang", "an_gang":
			return 2
		"add_gang":
			return 1
		_:
			return 1


func _apply_settlement_visuals(round_delta: int) -> void:
	var scale := _settlement_content_scale()
	settlement_shade.color = Color(0.012, 0.055, 0.044, 0.78)
	settlement_panel.add_theme_stylebox_override("panel", _build_settlement_panel_style())
	settlement_hero_card.add_theme_stylebox_override("panel", _build_settlement_hero_style(round_delta))
	settlement_breakdown_card.add_theme_stylebox_override("panel", _build_settlement_detail_style())
	settlement_hand_card.add_theme_stylebox_override("panel", _build_settlement_hand_style())
	settlement_player_list_card.add_theme_stylebox_override("panel", _build_settlement_side_style())
	settlement_detail_card.add_theme_stylebox_override("panel", _build_settlement_detail_style())
	settlement_close_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
	settlement_close_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
	settlement_close_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
	settlement_close_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
	settlement_close_button.add_theme_color_override("font_color", IVORY_SOFT)
	next_round_button.add_theme_stylebox_override("normal", _build_settlement_primary_button_style())
	next_round_button.add_theme_stylebox_override("hover", _build_settlement_primary_button_hover_style())
	next_round_button.add_theme_stylebox_override("pressed", _build_settlement_primary_button_pressed_style())
	next_round_button.add_theme_stylebox_override("focus", _build_settlement_primary_button_hover_style())
	next_round_button.add_theme_color_override("font_color", IVORY_SOFT)
	settlement_hero_badge.add_theme_stylebox_override("normal", _build_settlement_hero_badge_style())
	settlement_hero_badge.add_theme_font_size_override("font_size", int(round(22 * scale)))
	_apply_settlement_label_style(settlement_hero_badge, true, true, false, true)
	_apply_settlement_label_style(%SettlementTitle, false, true, false, true)
	%SettlementTitle.add_theme_font_size_override("font_size", clampi(int(round(36 * scale)), 30, 40))
	%SettlementTitle.add_theme_color_override("font_color", IVORY_SOFT)
	settlement_round_label.add_theme_font_size_override("font_size", clampi(int(round(25 * scale)), 22, 28))
	settlement_round_label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.80, 1.0))
	settlement_player_list_title.add_theme_color_override("font_color", IVORY_SOFT)
	settlement_player_list_title.add_theme_font_size_override("font_size", int(round(34 * scale)))
	settlement_hero_result.add_theme_font_size_override("font_size", int(round(44 * scale)))
	settlement_hero_result.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	settlement_hero_name.add_theme_font_size_override("font_size", clampi(int(round(32 * scale)), 24, 34))
	settlement_hero_name.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84, 1.0))
	settlement_hero_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	settlement_hero_name.clip_text = true
	settlement_hero_summary.add_theme_font_size_override("font_size", clampi(int(round(22 * scale)), 22, 26))
	settlement_hero_summary.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82, 0.94))
	settlement_hero_hu.add_theme_font_size_override("font_size", clampi(int(round(26 * scale)), 22, 28))
	settlement_hero_fan.add_theme_font_size_override("font_size", clampi(int(round(26 * scale)), 22, 28))
	settlement_hero_score.add_theme_font_size_override("font_size", clampi(int(round(66 * scale)), 60, 72))
	settlement_hero_score.add_theme_color_override("font_color", Color(0.98, 0.95, 0.84, 1.0))
	_apply_settlement_label_style(settlement_breakdown_title, false, true, false, true)
	settlement_breakdown_title.add_theme_font_size_override("font_size", clampi(int(round(32 * scale)), 30, 36))
	settlement_breakdown_title.add_theme_color_override("font_color", IVORY_SOFT)
	settlement_close_button.add_theme_font_size_override("font_size", int(round(26 * scale)))
	next_round_button.add_theme_font_size_override("font_size", int(round(42 * scale)))


func _apply_settlement_label_style(
	label: Control,
	dark_text: bool = false,
	_large: bool = false,
	use_aux: bool = false,
	use_display_font: bool = false
) -> void:
	# Size and font role are independent. Large settlement numbers, names and
	# ledger copy remain Noto Sans CJK; calligraphy is opt-in for short decorative
	# headings only.
	STYLE_CONFIG.apply_label(label, use_aux, use_display_font)
	if not dark_text:
		return
	var font_color := Color(0.96, 0.94, 0.86, 1.0) if not use_aux else Color(0.79, 0.82, 0.76, 1.0)
	if label is Label:
		var typed := label as Label
		typed.add_theme_color_override("font_color", font_color)
		typed.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.055, 0.94))
	elif label is Button:
		var button := label as Button
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.055, 0.94))


func _apply_settlement_focus_row_text_style(label: Control, aux: bool = false) -> void:
	var font_color := Color(1.0, 0.98, 0.93, 1.0) if not aux else Color(0.99, 0.96, 0.90, 1.0)
	var outline_color := Color(0.01, 0.07, 0.055, 0.96)
	if label is Label:
		var typed := label as Label
		typed.add_theme_color_override("font_color", font_color)
		typed.add_theme_color_override("font_outline_color", outline_color)
		typed.add_theme_constant_override("outline_size", 2)
	elif label is Button:
		var button := label as Button
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_outline_color", outline_color)
		button.add_theme_constant_override("outline_size", 2)


func _apply_settlement_breakdown_label_style(label: Label, is_header: bool = false, is_score: bool = false) -> void:
	var scale := _settlement_content_scale()
	label.add_theme_font_size_override("font_size", clampi(int(round((26 if is_header else 24) * scale)), 22, 28))
	label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.87, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.055, 0.90))
	label.add_theme_constant_override("outline_size", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_score:
		label.add_theme_font_size_override("font_size", clampi(int(round(26 * scale)), 22, 28))


func _build_settlement_side_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SETTLEMENT_JADE_PANEL
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.58)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 10
	style.shadow_offset = Vector2(5, 7)
	return style


func _build_settlement_detail_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SETTLEMENT_INK_DEEP
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.62)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	style.shadow_offset = Vector2(5, 7)
	return style


func _build_settlement_hand_style() -> StyleBoxFlat:
	var style := _build_settlement_detail_style()
	style.bg_color = SETTLEMENT_JADE_PANEL
	return style


func _build_settlement_hand_row_style(is_focus: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SETTLEMENT_JADE_ACTIVE if is_focus else Color(SETTLEMENT_JADE_CARD, 0.94)
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.82) if is_focus else Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.34)
	style.set_border_width_all(2 if is_focus else 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16) if is_focus else Color(0.0, 0.0, 0.0, 0.08)
	style.shadow_size = 4 if is_focus else 1
	style.shadow_offset = Vector2(3, 4)
	return style


func _build_settlement_hand_tag_style(suit: String, is_focus: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _ding_que_badge_fill(suit).darkened(0.18 if is_focus else 0.28)
	style.border_color = Color(0.95, 0.90, 0.78, 0.80)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _build_settlement_group_tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7A522C")
	style.border_color = Color("C59A58")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _build_settlement_breakdown_row_style(is_header: bool, alternate: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_header:
		style.bg_color = SETTLEMENT_JADE_ACTIVE
		style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.70)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(SETTLEMENT_JADE_CARD.lightened(0.045), 0.96) if alternate else Color(SETTLEMENT_JADE_PANEL, 0.96)
		style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.16)
		style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _build_settlement_hero_style(round_delta: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SETTLEMENT_JADE_ACTIVE if round_delta >= 0 else SETTLEMENT_JADE_PANEL
	style.border_color = Color(SICHUAN_TABLE_THEME.COPPER_HIGHLIGHT, 0.90)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 12
	style.shadow_offset = Vector2(6, 8)
	return style


func _build_settlement_list_row_style(is_focus: bool, delta: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SETTLEMENT_JADE_ACTIVE if is_focus else Color(SETTLEMENT_JADE_PANEL, 0.94)
	if delta < 0 and not is_focus:
		style.bg_color = Color("172621")
	style.border_color = Color(SICHUAN_TABLE_THEME.COPPER_HIGHLIGHT, 0.92) if is_focus else Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.30)
	style.set_border_width_all(2 if is_focus else 1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


func _build_settlement_list_row_hover_style(is_focus: bool, delta: int) -> StyleBoxFlat:
	var style := _build_settlement_list_row_style(is_focus, delta)
	style.bg_color = style.bg_color.lightened(0.04)
	style.border_color = Color(1.0, 0.94, 0.80, 0.98) if is_focus else Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.30)
	return style


func _build_settlement_avatar_style(is_focus: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("25705C") if is_focus else Color("0B352C")
	style.border_color = Color(SICHUAN_TABLE_THEME.COPPER_HIGHLIGHT, 0.86)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(3, 4)
	return style


func _build_settlement_dealer_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7A522C")
	style.border_color = Color("C59A58")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _build_settlement_hero_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7A522C")
	style.border_color = Color("C59A58")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 3
	style.shadow_offset = Vector2(3, 4)
	return style


func _build_settlement_panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = SETTLEMENT_PANEL_SHELL
	style.draw_center = true
	style.texture_margin_left = 112.0
	style.texture_margin_right = 112.0
	style.texture_margin_top = 92.0
	style.texture_margin_bottom = 92.0
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	return style


func _build_settlement_utility_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SETTLEMENT_JADE_PANEL
	style.border_color = Color(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b, 0.74)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 4)
	return style


func _build_settlement_utility_button_hover_style() -> StyleBoxFlat:
	var style := _build_settlement_utility_button_style()
	style.bg_color = style.bg_color.lightened(0.05)
	return style


func _build_settlement_utility_button_pressed_style() -> StyleBoxFlat:
	var style := _build_settlement_utility_button_style()
	style.bg_color = style.bg_color.darkened(0.08)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _build_settlement_primary_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("176F58")
	style.border_color = Color(SICHUAN_TABLE_THEME.COPPER_HIGHLIGHT, 0.96)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(5, 6)
	return style


func _build_settlement_primary_button_hover_style() -> StyleBoxFlat:
	var style := _build_settlement_primary_button_style()
	style.bg_color = style.bg_color.lightened(0.05)
	return style


func _build_settlement_primary_button_pressed_style() -> StyleBoxFlat:
	var style := _build_settlement_primary_button_style()
	style.bg_color = style.bg_color.darkened(0.07)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _settlement_avatar_text(seat: int) -> String:
	match seat:
		0:
			return "本"
		1:
			return "上"
		2:
			return "对"
		3:
			return "下"
		_:
			return "牌"


func _settlement_display_name(seat: int) -> String:
	var player_name := _player_name_by_seat(seat)
	if not player_name.is_empty():
		return player_name
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
			return "玩家"


func _player_name_by_seat(seat: int) -> String:
	var snapshot := game_manager.get_snapshot()
	var players: Array = snapshot.get("players", [])
	var player := _player_by_seat(players, seat)
	return str(player.get("name", ""))


func _on_settlement_player_selected(seat: int) -> void:
	settlement_selected_seat = seat
	if last_snapshot.is_empty():
		return
	call_deferred("_refresh_selected_settlement")


func _refresh_selected_settlement() -> void:
	if last_snapshot.is_empty():
		return
	_render_settlement(last_snapshot)


func _settlement_end_reason_text(end_reason: String) -> String:
	match end_reason:
		"battle_end":
			return "本局结束"
		"draw_wall_empty":
			return "牌墙流局"
		_:
			return "本局结算"


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _win_type_display_name(win_type: String) -> String:
	match win_type:
		"self_draw":
			return "自摸"
		"gang_self_draw":
			return "杠上花"
		"discard_win":
			return "点炮胡"
		"gang_discard_win":
			return "杠上炮"
		"qiang_gang_hu":
			return "抢杠胡"
		_:
			return "胡牌"


func _hand_type_display_name(hand_type: String) -> String:
	match hand_type:
		"ping_hu":
			return "平胡"
		"qi_dui":
			return "暗七对"
		"long_qi_dui":
			return "龙七对"
		"qing_yi_se":
			return "清一色"
		"qing_dui":
			return "清对"
		"qing_qi_dui":
			return "清七对"
		"qing_long_qi_dui":
			return "青龙七对"
		"da_dui_zi":
			return "大对子"
		"dui_dui_hu":
			return "对对胡"
		"jiang_dui":
			return "将对"
		"dai_yao_jiu":
			return "带幺九"
		_:
			return "成牌"


func _gang_type_display_name(gang_type: String) -> String:
	match gang_type:
		"melded_gang":
			return "明杠"
		"an_gang":
			return "暗杠"
		"add_gang":
			return "补杠"
		_:
			return "杠"


func _refund_payers_display(payer_seats: Array) -> String:
	if payer_seats.is_empty():
		return "-"
	var names: Array[String] = []
	for seat in payer_seats:
		names.append(_seat_name(int(seat)))
	return " / ".join(names)


func _apply_action_button_styles() -> void:
	_apply_action_panel_visual_style()
	action_buttons.add_theme_constant_override("h_separation", ACTION_BUTTON_GRID_GAP)
	action_buttons.add_theme_constant_override("v_separation", ACTION_BUTTON_GRID_GAP)
	action_status_label.add_theme_color_override("font_color", IVORY_SOFT)
	action_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	action_status_label.add_theme_constant_override("outline_size", 1)
	action_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_status_label.visible = false
	action_status_label.custom_minimum_size = Vector2.ZERO
	_apply_action_button_style(hu_button, true)
	_apply_action_button_style(gang_button, true)
	if an_gang_button != null:
		_apply_action_button_style(an_gang_button, true)
	_apply_action_button_style(peng_button, false)
	_apply_action_button_style(pass_button, false)
	hu_button.custom_minimum_size = ACTION_PRIMARY_SIZE
	gang_button.custom_minimum_size = ACTION_PRIMARY_SIZE
	if an_gang_button != null:
		an_gang_button.custom_minimum_size = ACTION_PRIMARY_SIZE
	peng_button.custom_minimum_size = ACTION_SECONDARY_SIZE
	pass_button.custom_minimum_size = ACTION_SECONDARY_SIZE


func _apply_top_bar_button_group_styles() -> void:
	_apply_ai_preset_button_style("bone_ash")
	_apply_top_bar_button_style(
		top_ai_tuning_button,
		Color(0.09, 0.32, 0.24, 0.86),
		Color(0.82, 0.94, 0.88, 0.18),
		IVORY_SOFT,
		18,
		false
	)
	_apply_ai_helper_button_style()
	_apply_top_bar_button_style(
		top_settlement_info_button,
		Color(0.09, 0.32, 0.24, 0.86),
		Color(0.82, 0.94, 0.88, 0.18),
		IVORY_SOFT,
		18,
		false
	)
	_apply_top_bar_button_style(
		top_opponent_hand_button,
		Color(0.09, 0.32, 0.24, 0.86),
		Color(0.82, 0.94, 0.88, 0.18),
		IVORY_SOFT,
		18,
		false
	)
	_apply_top_bar_button_style(
		top_next_round_button,
		Color(0.95, 0.72, 0.20, 0.98),
		Color(0.62, 0.45, 0.18, 0.86),
		Color(0.20, 0.13, 0.08, 1.0),
		18,
		true
	)
	_apply_top_bar_button_style(
		top_exit_button,
		Color(0.55, 0.21, 0.18, 0.90),
		Color(0.94, 0.78, 0.72, 0.24),
		IVORY_SOFT,
		18,
		false
	)
	top_bar_button.custom_minimum_size = Vector2(214, 82)
	top_ai_tuning_button.custom_minimum_size = Vector2(214, 82)
	top_ai_helper_button.custom_minimum_size = Vector2(214, 82)
	top_opponent_hand_button.custom_minimum_size = Vector2(214, 82)
	top_settlement_info_button.custom_minimum_size = Vector2(214, 82)
	top_next_round_button.custom_minimum_size = Vector2(214, 88)
	_configure_top_right_exit_button()


func _configure_top_right_exit_button() -> void:
	if top_exit_button == null or root_ui == null:
		return
	top_exit_button.visible = false
	top_exit_button.disabled = true


func _apply_ai_preset_button_style(preset_name: String) -> void:
	match preset_name:
		"intermediate":
			_apply_top_bar_button_style(
				top_bar_button,
				Color(0.14, 0.28, 0.34, 0.90),
				Color(0.76, 0.88, 0.96, 0.28),
				Color(0.92, 0.96, 1.0, 1.0),
				34,
				false
			)
		"hell":
			_apply_top_bar_button_style(
				top_bar_button,
				Color(0.78, 0.25, 0.20, 0.96),
				Color(0.96, 0.82, 0.44, 0.92),
				Color(1.0, 0.92, 0.82, 1.0),
				34,
				true
			)
		_:
			_apply_top_bar_button_style(
				top_bar_button,
				Color(0.09, 0.32, 0.24, 0.86),
				Color(0.82, 0.94, 0.88, 0.18),
				IVORY_SOFT,
				34,
				false
			)


func _ai_preset_hint_text(preset_name: String) -> String:
	match preset_name:
		"intermediate":
			return "当前 AI 预设：中级 · 稳健成叫"
		"hell":
			return "当前 AI 预设：地狱挑战 · 透视压分"
		_:
			return "当前 AI 预设：骨灰 · 四川血战"


func _ai_preset_short_text(preset_name: String) -> String:
	match preset_name:
		"intermediate":
			return "中级"
		"hell":
			return "地狱"
		_:
			return "老手"


func _apply_ai_helper_button_style() -> void:
	if ai_helper_enabled:
		_apply_top_bar_button_style(
			top_ai_helper_button,
			Color(0.18, 0.43, 0.30, 0.92),
			Color(0.90, 0.95, 0.70, 0.32),
			IVORY_SOFT,
			18,
			false
		)
	else:
		_apply_top_bar_button_style(
			top_ai_helper_button,
			Color(0.09, 0.32, 0.24, 0.72),
			Color(0.82, 0.94, 0.88, 0.14),
			Color(0.92, 0.96, 0.93, 0.92),
			18,
			false
		)


func _apply_top_bar_button_style(button: Button, bg: Color, border: Color, font_color: Color, font_size: int, emphasized: bool) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg.lightened(0.07 if not emphasized else 0.12)
	normal.border_color = border.lightened(0.26)
	normal.set_border_width_all(2 if emphasized else 1)
	normal.corner_radius_top_left = 25
	normal.corner_radius_top_right = 25
	normal.corner_radius_bottom_left = 25
	normal.corner_radius_bottom_right = 25
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	normal.shadow_color = Color(0.0, 0.08, 0.05, 0.34 if emphasized else 0.24)
	normal.shadow_size = 15 if emphasized else 10
	normal.shadow_offset = Vector2(0, 5)
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.4

	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.18)
	hover.border_color = Color(1.0, 0.96, 0.70, 0.62) if emphasized else border.lightened(0.42)
	hover.shadow_size = normal.shadow_size + 2

	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.06)
	pressed.border_color = border.darkened(0.03)
	pressed.shadow_size = maxi(2, normal.shadow_size - 5)
	pressed.shadow_offset = Vector2(0, 1)
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 6

	var disabled := normal.duplicate()
	disabled.bg_color = Color(bg.r, bg.g, bg.b, 0.30).lightened(0.06)
	disabled.border_color = Color(border.r, border.g, border.b, 0.22)
	disabled.shadow_color = Color(0.0, 0.06, 0.04, 0.12)
	disabled.shadow_size = 4
	disabled.shadow_offset = Vector2(0, 1)
	disabled.content_margin_top = 9
	disabled.content_margin_bottom = 9

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color(font_color.r, font_color.g, font_color.b, 0.46))
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 0.92))
	button.add_theme_color_override("font_disabled_outline_color", Color(0.08, 0.06, 0.03, 0.48))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_font_size_override("font_size", 17 if button in [top_bar_button, top_ai_tuning_button, top_ai_helper_button, top_settlement_info_button, top_next_round_button, top_exit_button] else font_size)
	_ensure_button_gloss_overlay(button, 0.56 if not emphasized else 0.74)


func _setup_ai_tuning_overlay() -> void:
	ai_tuning_click_actions.clear()
	ai_tuning_overlay = Control.new()
	ai_tuning_overlay.name = "AITuningOverlay"
	ai_tuning_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ai_tuning_overlay.visible = false
	ai_tuning_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ai_tuning_overlay.z_index = 210
	root_ui.add_child(ai_tuning_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.07, 0.05, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_ai_tuning_shade_gui_input)
	ai_tuning_overlay.add_child(shade)

	ai_tuning_panel = Panel.new()
	ai_tuning_panel.custom_minimum_size = Vector2(1940, 1210)
	ai_tuning_panel.size = ai_tuning_panel.custom_minimum_size
	ai_tuning_panel.clip_contents = true
	ai_tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ai_tuning_panel.gui_input.connect(_on_ai_tuning_panel_gui_input)
	ai_tuning_overlay.add_child(ai_tuning_panel)
	ai_tuning_panel.add_theme_stylebox_override("panel", _build_settlement_panel_style())
	_ensure_material_overlay(ai_tuning_panel, "AITuningWoodGrain", TABLE_MATERIAL_OVERLAY_SCRIPT.MaterialMode.SOFT_PANEL, 0.48)

	ai_tuning_close_button = Button.new()
	ai_tuning_close_button.text = "×"
	ai_tuning_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ai_tuning_close_button.offset_left = -142
	ai_tuning_close_button.offset_top = 28
	ai_tuning_close_button.offset_right = -28
	ai_tuning_close_button.offset_bottom = 106
	ai_tuning_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	ai_tuning_close_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
	ai_tuning_close_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
	ai_tuning_close_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
	ai_tuning_close_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
	ai_tuning_close_button.add_theme_font_size_override("font_size", 40)
	ai_tuning_close_button.add_theme_color_override("font_color", IVORY_SOFT)
	ai_tuning_close_button.add_theme_color_override("font_outline_color", Color(0.07, 0.11, 0.09, 0.88))
	ai_tuning_close_button.add_theme_constant_override("outline_size", 2)
	ai_tuning_close_button.pressed.connect(_close_ai_tuning_overlay)
	ai_tuning_panel.add_child(ai_tuning_close_button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	ai_tuning_panel.add_child(margin)
	ai_tuning_close_button.move_to_front()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	ai_tuning_title_label = Label.new()
	ai_tuning_title_label.text = "AI 调参（四川麻将新版｜按住标题可拖动）"
	_apply_settlement_label_style(ai_tuning_title_label, false, true)
	ai_tuning_title_label.add_theme_font_size_override("font_size", 48)
	ai_tuning_title_label.add_theme_color_override("font_color", IVORY_SOFT)
	ai_tuning_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_tuning_title_label.custom_minimum_size = Vector2(0, 72)
	ai_tuning_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(ai_tuning_title_label)

	ai_tuning_status_label = Label.new()
	_apply_settlement_label_style(ai_tuning_status_label, false, false)
	ai_tuning_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_tuning_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_tuning_status_label.add_theme_font_size_override("font_size", 28)
	ai_tuning_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 0.98))
	ai_tuning_status_label.text = "围绕定缺清缺、下叫效率、番型收益与尾盘防守来微调 AI。"
	vbox.add_child(ai_tuning_status_label)

	var preset_label := Label.new()
	preset_label.text = "难度预设"
	_apply_settlement_label_style(preset_label, false, true)
	preset_label.add_theme_font_size_override("font_size", 28)
	preset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preset_label)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 18)
	preset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(preset_row)
	for item in [
		{"key": "intermediate", "label": "中级"},
		{"key": "bone_ash", "label": "骨灰"},
		{"key": "hell", "label": "地狱"}
	]:
		var preset_button := Button.new()
		preset_button.text = str(item["label"])
		preset_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
		preset_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
		preset_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
		preset_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
		preset_button.add_theme_font_size_override("font_size", 26)
		preset_button.add_theme_color_override("font_color", IVORY_SOFT)
		preset_button.custom_minimum_size = Vector2(170, 64)
		var preset_action := _on_ai_tuning_preset_pressed.bind(str(item["key"]))
		preset_button.pressed.connect(preset_action)
		_register_ai_tuning_click_action(preset_button, preset_action)
		preset_row.add_child(preset_button)
		ai_tuning_preset_buttons[str(item["key"])] = preset_button

	var tuning_groups: Array = [
		{
			"title": "成叫与胡牌效率",
			"items": [
				{"key": "attack_tendency", "label": "进攻节奏", "step": 1},
				{"key": "defense_tendency", "label": "尾盘防守", "step": 1},
				{"key": "fast_ting_priority", "label": "快速成叫", "step": 1},
				{"key": "self_draw_priority", "label": "自摸优先", "step": 1},
				{"key": "forced_cleanup_tendency", "label": "成叫/查叫优先", "step": 1},
				{"key": "big_hand_tendency", "label": "做大倾向", "step": 1},
				{"key": "opponent_read_tendency", "label": "读牌能力", "step": 1},
			],
		},
		{
			"title": "前瞻、杠牌与读牌",
			"items": [
				{"key": "lookahead_candidate_count", "label": "前瞻候选数", "step": 1},
				{"key": "lookahead_draw_samples", "label": "前瞻样本数", "step": 1},
				{"key": "add_gang_min_score", "label": "补杠阈值", "step": 2},
				{"key": "an_gang_min_score", "label": "暗杠阈值", "step": 2},
				{"key": "intermediate_top_pick_count", "label": "中级容错池", "step": 1},
			],
		},
	]
	for group in tuning_groups:
		var group_label := Label.new()
		group_label.text = str(group.get("title", ""))
		_apply_settlement_label_style(group_label, false, true)
		group_label.add_theme_font_size_override("font_size", 28)
		group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(group_label)

		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 12)
		vbox.add_child(grid)

		for item in group.get("items", []):
			var name_label := Label.new()
			name_label.text = str(item["label"])
			_apply_settlement_label_style(name_label, false, false)
			name_label.custom_minimum_size = Vector2(178, 56)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 24)
			grid.add_child(name_label)

			var minus_button := Button.new()
			minus_button.text = "－"
			minus_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
			minus_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
			minus_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
			minus_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
			minus_button.add_theme_font_size_override("font_size", 28)
			minus_button.add_theme_color_override("font_color", IVORY_SOFT)
			minus_button.custom_minimum_size = Vector2(72, 56)
			var minus_action := _on_ai_tuning_adjust_pressed.bind(str(item["key"]), -int(item["step"]))
			minus_button.pressed.connect(minus_action)
			_register_ai_tuning_click_action(minus_button, minus_action)
			grid.add_child(minus_button)

			var value_label := Label.new()
			value_label.text = "-"
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_apply_settlement_label_style(value_label, false, true)
			value_label.add_theme_stylebox_override("normal", _build_settlement_group_tag_style())
			value_label.add_theme_font_size_override("font_size", 24)
			value_label.custom_minimum_size = Vector2(108, 56)
			grid.add_child(value_label)
			ai_tuning_value_labels[str(item["key"])] = value_label

			var plus_button := Button.new()
			plus_button.text = "＋"
			plus_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
			plus_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
			plus_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
			plus_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
			plus_button.add_theme_font_size_override("font_size", 28)
			plus_button.add_theme_color_override("font_color", IVORY_SOFT)
			plus_button.custom_minimum_size = Vector2(72, 56)
			var plus_action := _on_ai_tuning_adjust_pressed.bind(str(item["key"]), int(item["step"]))
			plus_button.pressed.connect(plus_action)
			_register_ai_tuning_click_action(plus_button, plus_action)
			grid.add_child(plus_button)

	ai_tuning_learning_label = RichTextLabel.new()
	ai_tuning_learning_label.bbcode_enabled = false
	ai_tuning_learning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_tuning_learning_label.fit_content = false
	ai_tuning_learning_label.scroll_active = true
	ai_tuning_learning_label.scroll_following = false
	ai_tuning_learning_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ai_tuning_learning_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_tuning_learning_label.custom_minimum_size = Vector2(0, 0)
	ai_tuning_learning_label.clip_contents = true
	ai_tuning_learning_label.add_theme_font_size_override("normal_font_size", 22)
	ai_tuning_learning_label.add_theme_color_override("default_color", Color(1.0, 0.95, 0.82, 0.96))
	ai_tuning_learning_label.add_theme_constant_override("line_separation", 6)
	ai_tuning_learning_label.scroll_to_line(0)
	vbox.add_child(ai_tuning_learning_label)
	call_deferred("_configure_ai_tuning_learning_scrollbar")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	ai_tuning_auto_learning_button = Button.new()
	ai_tuning_auto_learning_button.text = "自动学习：开"
	ai_tuning_auto_learning_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
	ai_tuning_auto_learning_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
	ai_tuning_auto_learning_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
	ai_tuning_auto_learning_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
	ai_tuning_auto_learning_button.add_theme_font_size_override("font_size", 24)
	ai_tuning_auto_learning_button.add_theme_color_override("font_color", IVORY_SOFT)
	ai_tuning_auto_learning_button.custom_minimum_size = Vector2(240, 64)
	ai_tuning_auto_learning_button.pressed.connect(_on_ai_tuning_auto_learning_pressed)
	_register_ai_tuning_click_action(ai_tuning_auto_learning_button, Callable(self, "_on_ai_tuning_auto_learning_pressed"))
	footer.add_child(ai_tuning_auto_learning_button)

	ai_tuning_endgame_defense_button = Button.new()
	ai_tuning_endgame_defense_button.text = "尾盘绝对防炮：开"
	ai_tuning_endgame_defense_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
	ai_tuning_endgame_defense_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
	ai_tuning_endgame_defense_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
	ai_tuning_endgame_defense_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
	ai_tuning_endgame_defense_button.add_theme_font_size_override("font_size", 24)
	ai_tuning_endgame_defense_button.add_theme_color_override("font_color", IVORY_SOFT)
	ai_tuning_endgame_defense_button.custom_minimum_size = Vector2(300, 64)
	ai_tuning_endgame_defense_button.pressed.connect(_on_ai_tuning_endgame_defense_pressed)
	_register_ai_tuning_click_action(ai_tuning_endgame_defense_button, Callable(self, "_on_ai_tuning_endgame_defense_pressed"))
	footer.add_child(ai_tuning_endgame_defense_button)

	var reset_button := Button.new()
	reset_button.text = "恢复默认微调"
	reset_button.add_theme_stylebox_override("normal", _build_settlement_utility_button_style())
	reset_button.add_theme_stylebox_override("hover", _build_settlement_utility_button_hover_style())
	reset_button.add_theme_stylebox_override("pressed", _build_settlement_utility_button_pressed_style())
	reset_button.add_theme_stylebox_override("focus", _build_settlement_utility_button_hover_style())
	reset_button.add_theme_font_size_override("font_size", 24)
	reset_button.add_theme_color_override("font_color", IVORY_SOFT)
	reset_button.custom_minimum_size = Vector2(264, 64)
	reset_button.pressed.connect(_on_ai_tuning_reset_pressed)
	_register_ai_tuning_click_action(reset_button, Callable(self, "_on_ai_tuning_reset_pressed"))
	footer.add_child(reset_button)

	var bone_button := Button.new()
	bone_button.text = "一键套用四川骨灰"
	bone_button.add_theme_stylebox_override("normal", _build_settlement_primary_button_style())
	bone_button.add_theme_stylebox_override("hover", _build_settlement_primary_button_hover_style())
	bone_button.add_theme_stylebox_override("pressed", _build_settlement_primary_button_pressed_style())
	bone_button.add_theme_stylebox_override("focus", _build_settlement_primary_button_hover_style())
	bone_button.add_theme_font_size_override("font_size", 24)
	bone_button.add_theme_color_override("font_color", Color(0.19, 0.16, 0.10, 1.0))
	bone_button.custom_minimum_size = Vector2(286, 64)
	bone_button.pressed.connect(_on_ai_tuning_bone_recommended_pressed)
	_register_ai_tuning_click_action(bone_button, Callable(self, "_on_ai_tuning_bone_recommended_pressed"))
	footer.add_child(bone_button)


func _refresh_ai_tuning_panel(snapshot: Dictionary) -> void:
	if ai_tuning_overlay == null:
		return
	var tuning: Dictionary = snapshot.get("ai_tuning_config", {})
	var learning: Dictionary = snapshot.get("ai_learning_profile", {})
	var preset_name := str(tuning.get("preset_name", "bone_ash"))
	var auto_learning := bool(tuning.get("auto_learning_enabled", true))
	var endgame_absolute_defense := bool(tuning.get("endgame_absolute_defense", true))
	for key in ai_tuning_preset_buttons.keys():
		var button := ai_tuning_preset_buttons[key] as Button
		if button == null:
			continue
		button.disabled = key == preset_name
	for key in ai_tuning_value_labels.keys():
		var label := ai_tuning_value_labels[key] as Label
		if label != null:
			label.text = str(tuning.get(key, "-"))
	var total_rounds := int(learning.get("total_human_rounds", 0))
	var reasons: Array = learning.get("last_adjustment_reasons", [])
	var parameter_adjustments: Dictionary = learning.get("parameter_adjustments", {})
	var parameter_bias: Dictionary = learning.get("parameter_bias", {})
	var summary_stats: Dictionary = learning.get("summary_stats", {})
	var adjustment_history: Array = learning.get("adjustment_history", [])
	var ai_core_debug: Dictionary = snapshot.get("ai_core_debug", {})
	var latest_turn_snapshot: Dictionary = ai_core_debug.get("latest_turn_snapshot", {})
	var adjustment_parts: Array[String] = []
	var learning_labels := {
		"lookahead_candidate_count": "前瞻候选",
		"lookahead_draw_samples": "前瞻样本",
		"add_gang_min_score": "补杠阈值",
		"an_gang_min_score": "暗杠阈值",
		"attack_tendency": "进攻节奏",
		"defense_tendency": "尾盘防守",
		"fast_ting_priority": "快速成叫",
		"self_draw_priority": "自摸优先",
		"forced_cleanup_tendency": "成叫/查叫优先",
		"big_hand_tendency": "做大倾向",
		"opponent_read_tendency": "读牌能力",
	}
	for key in learning_labels.keys():
		var delta := int(parameter_adjustments.get(key, 0))
		if delta == 0:
			continue
		adjustment_parts.append("%s%+d" % [str(learning_labels.get(key, key)), delta])
	var latest_change_text := "最近一轮：暂无历史变更"
	var latest_reason_text := "学习依据：%s" % (" / ".join(reasons) if auto_learning and not reasons.is_empty() else ("已关闭" if not auto_learning else "暂未生成"))
	if not adjustment_history.is_empty():
		var latest_history: Dictionary = adjustment_history.back()
		var latest_parts: Array[String] = []
		for item in latest_history.get("changed_parameters", []):
			var changed: Dictionary = item
			var key := str(changed.get("key", ""))
			var delta := int(changed.get("delta", 0))
			if delta == 0 or not learning_labels.has(key):
				continue
			latest_parts.append("%s%+d" % [str(learning_labels.get(key, key)), delta])
		if not latest_parts.is_empty():
			latest_change_text = "最近一轮：%s" % "，".join(latest_parts)
		var latest_reasons: Array = latest_history.get("reasons", [])
		if not latest_reasons.is_empty():
			latest_reason_text = "学习依据：%s" % " / ".join(latest_reasons)
	if ai_tuning_auto_learning_button != null:
		ai_tuning_auto_learning_button.text = "自动学习：%s" % ("开" if auto_learning else "关")
	if ai_tuning_endgame_defense_button != null:
		ai_tuning_endgame_defense_button.text = "尾盘绝对防炮：%s" % ("开" if endgame_absolute_defense else "关")
	var backend_mode := str(learning.get("backend_mode", "gdscript"))
	var backend_text := "C#" if backend_mode == "csharp" else "GDScript"
	var bias_parts: Array[String] = []
	var bias_labels := {
		"risk_bias": "风险",
		"attack_bias": "进攻",
		"gang_bias": "杠牌",
		"lookahead_bias": "前瞻",
	}
	for key in ["risk_bias", "attack_bias", "gang_bias", "lookahead_bias"]:
		bias_parts.append("%s%+d" % [str(bias_labels.get(key, key)), int(parameter_bias.get(key, 0))])
	var summary_line := "核心指标：真人均分 %.2f｜真人正收益 %.0f%%｜点炮 %.0f%%｜AI 胡牌 %.2f/局｜AI 自摸 %.0f%%｜流局 %.0f%%" % [
		float(summary_stats.get("human_average_delta", 0.0)),
		float(summary_stats.get("human_positive_rate", 0.0)) * 100.0,
		float(summary_stats.get("human_deal_in_rate", 0.0)) * 100.0,
		float(summary_stats.get("ai_win_average", 0.0)),
		float(summary_stats.get("ai_self_draw_rate", 0.0)) * 100.0,
		float(summary_stats.get("draw_rate", 0.0)) * 100.0,
	]
	var live_readout_lines := _build_ai_live_readout_lines(snapshot, latest_turn_snapshot)
	ai_tuning_learning_label.text = "\n".join([
		"学习后端：%s" % backend_text,
		"累计学习：%d 局" % total_rounds,
		"当前偏置：%s" % "｜".join(bias_parts),
		"当前参数：%s" % ("｜".join(adjustment_parts) if auto_learning and not adjustment_parts.is_empty() else ("已关闭" if not auto_learning else "暂未生成")),
		summary_line,
		latest_change_text if auto_learning else "最近一轮：已关闭",
		latest_reason_text,
		"",
		"最近一次电脑读牌：",
		"\n".join(live_readout_lines),
	])
	ai_tuning_status_label.text = "当前预设：%s。面板中的默认值已切换为四川麻将权重，改动会即时同步到电脑 AI 与辅助建议。" % str(AI_PRESET_LABELS.get(preset_name, "骨灰"))
	ai_tuning_learning_label.scroll_to_line(0)


func _build_ai_live_readout_lines(snapshot: Dictionary, latest_turn_snapshot: Dictionary) -> Array[String]:
	var ai_core_debug: Dictionary = snapshot.get("ai_core_debug", {})
	var backend_status: Dictionary = ai_core_debug.get("backend_status", {})
	var chain_debug: Array = snapshot.get("ai_chain_debug", [])
	var status_line := "链路状态：native=%s｜后端=%s｜错误=%s" % [
		str(backend_status.get("native_csharp_runtime", false)),
		str(backend_status.get("active_backend", "")),
		str(backend_status.get("last_native_turn_error", "")),
	]
	if latest_turn_snapshot.is_empty():
		var empty_lines: Array[String] = [status_line, "暂无最近决策数据"]
		if not chain_debug.is_empty():
			empty_lines.append("最近链路：%s" % str(chain_debug.back()))
		return empty_lines
	var analysis: Dictionary = latest_turn_snapshot.get("analysis", {})
	if analysis.is_empty():
		var no_analysis_lines: Array[String] = [status_line, "暂无最近决策数据"]
		no_analysis_lines.append("C#摘要：%s" % str(backend_status.get("last_native_turn_raw_summary", "")).left(180))
		if not chain_debug.is_empty():
			no_analysis_lines.append("最近链路：%s" % str(chain_debug.back()))
		return no_analysis_lines
	var latest_reaction_snapshot: Dictionary = ai_core_debug.get("latest_reaction_snapshot", {})
	var recommended: Dictionary = analysis.get("recommended", {})
	var strategy_profile: Dictionary = analysis.get("strategy_profile", {})
	var opponent_state: Dictionary = strategy_profile.get("opponent_state", {})
	var top_threat_profile: Dictionary = opponent_state.get("top_threat_profile", {})
	var belief_summary: Dictionary = analysis.get("belief_summary", {})
	var danger_tiles: Array = analysis.get("danger_tiles", [])
	var lines: Array[String] = []
	var seat := int(latest_turn_snapshot.get("seat", -1))
	var active_backend := str(latest_turn_snapshot.get("active_backend", "gdscript"))
	var elapsed_ms := int(latest_turn_snapshot.get("elapsed_ms", 0))
	var backend_text := "C#原生" if active_backend == "csharp_native" else ("C#混合" if active_backend == "hybrid_csharp" else active_backend)
	lines.append(status_line)
	lines.append("C#摘要：%s" % str(backend_status.get("last_native_turn_raw_summary", "")).left(180))
	if not chain_debug.is_empty():
		lines.append("最近链路：%s" % str(chain_debug.back()))
	lines.append("电脑座位：%s｜后端：%s｜本次耗时：%dms" % [_seat_name(seat), backend_text, elapsed_ms])
	lines.append("当前策略：%s｜阶段：%s｜桌面威胁：%d" % [
		str(strategy_profile.get("mode_label", "定缺速听")),
		str(strategy_profile.get("round_stage_label", "中巡")),
		int(strategy_profile.get("threat_level", 0)),
	])
	if not top_threat_profile.is_empty() and int(top_threat_profile.get("seat", -1)) >= 0:
		lines.append("现在最需要防的是：%s｜看起来主做%s｜像清一色 %d%%｜像对对胡 %d%%｜危险分 %d" % [
			_seat_name(int(top_threat_profile.get("seat", -1))),
			str(top_threat_profile.get("dangerous_suit_label", "?")),
			int(top_threat_profile.get("flush_probability", 0)),
			int(top_threat_profile.get("pung_probability", 0)),
			int(top_threat_profile.get("threat_score", 0)),
		])
	else:
		lines.append("现在还没有特别危险的对手")
	if not recommended.is_empty():
		lines.append("这次建议打%s｜%s｜%s｜综合收益 %.2f｜听牌机会 %.0f%%｜自摸机会 %.0f%%｜胡牌机会 %.0f%%｜放炮机会 %.0f%%" % [
			str(recommended.get("tile_name", "?")),
			_plain_debug_shanten_text(int(recommended.get("shanten", 8))),
			_plain_debug_ukeire_text(int(recommended.get("live_ukeire", 0))),
			float(recommended.get("expected_net_score", recommended.get("csharp_expected_net_score", 0.0))),
			float(recommended.get("csharp_tenpai_probability", recommended.get("tenpai_probability", 0.0))) * 100.0,
			float(recommended.get("csharp_self_draw_probability", recommended.get("self_draw_probability", 0.0))) * 100.0,
			float(recommended.get("csharp_win_probability", recommended.get("win_probability", 0.0))) * 100.0,
			float(recommended.get("csharp_deal_in_probability", recommended.get("deal_in_probability", 0.0))) * 100.0,
		])
	lines.append_array(_build_candidate_posterior_rank_lines(analysis))
	lines.append_array(_build_ai_belief_summary_lines(belief_summary))
	var danger_summary := _summarize_ai_danger_tiles(danger_tiles)
	lines.append("尽量少打：%s" % danger_summary)
	lines.append_array(_build_ai_reaction_debug_lines(latest_reaction_snapshot))
	return lines


func _build_candidate_posterior_rank_lines(analysis: Dictionary) -> Array[String]:
	var options: Array = analysis.get("options", [])
	if options.is_empty():
		return []
	var lines: Array[String] = ["如果换别的打，也大概是这样："]
	var index := 1
	for option in options.slice(0, 3):
		var candidate: Dictionary = option
		var expected_net := float(candidate.get("expected_net_score", candidate.get("csharp_expected_net_score", 0.0)))
		var expected_win := float(candidate.get("expected_win_gain", candidate.get("csharp_expected_win_gain", 0.0)))
		var expected_loss := float(candidate.get("expected_deal_in_loss", candidate.get("csharp_expected_deal_in_loss", 0.0)))
		var posterior_adjustment := float(candidate.get("posterior_adjustment", candidate.get("csharp_posterior_adjustment", 0.0)))
		var posterior_reasons: Array = candidate.get("posterior_reasons", candidate.get("csharp_posterior_reasons", []))
		var posterior_text := "场上情况没有明显扣分"
		if posterior_adjustment > 0.01:
			posterior_text = "结合场上情况，收益少 %.2f" % posterior_adjustment
			if not posterior_reasons.is_empty():
				posterior_text += "｜%s" % _humanize_helper_text(str(posterior_reasons[0]))
		lines.append("%d. %s｜%s｜%s｜综合收益%.2f｜大概能赚%.2f/可能亏%.2f｜%s｜%s" % [
			index,
			str(candidate.get("tile_name", "?")),
			_plain_debug_shanten_text(int(candidate.get("shanten", 8))),
			_plain_debug_ukeire_text(int(candidate.get("live_ukeire", 0))),
			expected_net,
			expected_win,
			expected_loss,
			_plain_helper_risk_text(str(candidate.get("risk_label", "低危"))),
			posterior_text,
		])
		index += 1
	return lines


func _build_ai_belief_summary_lines(belief_summary: Dictionary) -> Array[String]:
	if belief_summary.is_empty():
		return ["场上判断摘要：当前还没有拿到更多判断数据"]
	var lines: Array[String] = []
	var ready_items: Array = belief_summary.get("ready_posteriors", [])
	if ready_items.is_empty():
		lines.append("谁更像快听牌了：暂时看不出来")
	else:
		var ready_parts: Array[String] = []
		for item in ready_items.slice(0, 2):
			var ready_item: Dictionary = item
			ready_parts.append("%s %.0f%%%s" % [
				_seat_name(int(ready_item.get("seat", -1))),
				float(ready_item.get("ready_posterior", 0.0)) * 100.0,
				"｜已有副露" if bool(ready_item.get("is_called", false)) else "",
			])
		lines.append("谁更像快听牌了：%s" % " / ".join(ready_parts))
	var hold_summary: Dictionary = belief_summary.get("hold_summary", {})
	var hold_items: Array = hold_summary.get("top_holders", [])
	if hold_items.is_empty():
		lines.append("谁手里更像捏着关键牌：暂时看不出来")
	else:
		var hold_tile_label := str(hold_summary.get("tile_label", "?"))
		var hold_parts: Array[String] = []
		for item in hold_items.slice(0, 2):
			var hold_item: Dictionary = item
			hold_parts.append("%s %.0f%%｜这张牌危险 %.0f%%｜他对这门牌需求 %.0f%%" % [
				_seat_name(int(hold_item.get("seat", -1))),
				float(hold_item.get("hold_posterior", 0.0)) * 100.0,
				float(hold_item.get("tile_danger", 0.0)) * 100.0,
				float(hold_item.get("suit_demand", 0.0)) * 100.0,
			])
		lines.append("如果打%s，谁手里更像捏着它：%s" % [hold_tile_label, " / ".join(hold_parts)])
	var wall_summary: Dictionary = belief_summary.get("wall_summary", {})
	var wall_items: Array = wall_summary.get("top_tiles", [])
	if wall_items.is_empty():
		lines.append("牌墙里更可能还剩什么：暂时看不出来")
	else:
		var wall_parts: Array[String] = []
		for item in wall_items.slice(0, 3):
			var wall_item: Dictionary = item
			wall_parts.append("%s %.0f%%" % [
				str(wall_item.get("tile_label", "?")),
				float(wall_item.get("posterior", 0.0)) * 100.0,
			])
		lines.append("牌墙里更可能还剩什么：%s｜平均 %.0f%%" % [
			" / ".join(wall_parts),
			float(wall_summary.get("average_posterior", 0.0)) * 100.0,
		])
	var wait_summary: Dictionary = belief_summary.get("wait_summary", {})
	var wait_items: Array = wait_summary.get("top_waiters", [])
	if not wait_items.is_empty():
		var wait_tile_label := str(wait_summary.get("tile_label", "?"))
		var wait_parts: Array[String] = []
		for item in wait_items.slice(0, 2):
			var wait_item: Dictionary = item
			wait_parts.append("%s 胡这张概率 %.0f%%｜暂时不胡的迹象 %.0f%%" % [
				_seat_name(int(wait_item.get("seat", -1))),
				float(wait_item.get("wait_posterior", 0.0)) * 100.0,
				float(wait_item.get("no_hu_evidence", 0.0)) * 100.0,
			])
		lines.append("如果打%s，谁更像能胡：%s" % [wait_tile_label, " / ".join(wait_parts)])
	var unknown_summary: Dictionary = belief_summary.get("unknown_summary", {})
	var unknown_items: Array = unknown_summary.get("top_tiles", [])
	if not unknown_items.is_empty():
		var unknown_parts: Array[String] = []
		for item in unknown_items.slice(0, 4):
			var unknown_item: Dictionary = item
			unknown_parts.append("%s×%d" % [
				str(unknown_item.get("tile_label", "?")),
				int(unknown_item.get("count", 0)),
			])
		lines.append("还没露面的牌大概有：%s｜总共%d张" % [
			" / ".join(unknown_parts),
			int(unknown_summary.get("total_unknown", 0)),
		])
	return lines


func _build_ai_reaction_debug_lines(latest_reaction_snapshot: Dictionary) -> Array[String]:
	if latest_reaction_snapshot.is_empty():
		return []
	var analysis: Dictionary = latest_reaction_snapshot.get("analysis", {})
	if analysis.is_empty():
		return []
	var lines: Array[String] = []
	var seat := int(latest_reaction_snapshot.get("seat", -1))
	var action := str(analysis.get("action", "pass"))
	var round_stage_label := str(analysis.get("round_stage_label", ""))
	var action_scores: Dictionary = analysis.get("action_scores", {})
	lines.append("最近一次响应判断：%s｜动作 %s｜阶段 %s" % [
		_seat_name(seat),
		{"pass":"过","peng":"碰","gang":"杠","hu":"胡"}.get(action, action),
		round_stage_label,
	])
	if not action_scores.is_empty():
		lines.append("这几种动作大概评分：过 %s｜碰 %s｜杠 %s" % [
			str(action_scores.get("pass", "-")),
			str(action_scores.get("peng", "-")),
			str(action_scores.get("gang", "-")),
		])
	if bool(analysis.get("search_used", false)):
		lines.append("系统额外试算了 %d 次｜最后修正 %.2f" % [
			int(analysis.get("search_simulations", 0)),
			float(analysis.get("search_bonus", 0.0)),
		])
	var posterior_summary: Array = analysis.get("posterior_summary", [])
	if not posterior_summary.is_empty():
		var readable_posteriors: Array[String] = []
		for item in posterior_summary:
			readable_posteriors.append(_humanize_helper_text(str(item)))
		lines.append("结合场上情况再看：" + "｜".join(PackedStringArray(readable_posteriors)))
	var future_summary: Array = analysis.get("future_summary", [])
	if not future_summary.is_empty():
		var readable_future: Array[String] = []
		for item in future_summary.slice(0, 3):
			readable_future.append(_humanize_helper_text(str(item)))
		lines.append("后面大概会怎样：" + "｜".join(PackedStringArray(readable_future)))
	return lines


func _summarize_ai_danger_tiles(danger_tiles: Array) -> String:
	if danger_tiles.is_empty():
		return "暂时没有特别危险的牌"
	var parts: Array[String] = []
	for item in danger_tiles.slice(0, 2):
		var danger_item: Dictionary = item
		var reason_text := ""
		var reasons: Array = danger_item.get("risk_reasons", danger_item.get("csharp_risk_reasons", []))
		if not reasons.is_empty():
			reason_text = "（%s）" % _humanize_helper_text(str(reasons[0]))
		parts.append("%s 危险分 %d%s" % [
			str(danger_item.get("tile_name", "?")),
			int(danger_item.get("risk", danger_item.get("csharp_danger", 0))),
			reason_text,
		])
	return " / ".join(parts)


func _plain_debug_shanten_text(shanten: int) -> String:
	if shanten <= 0:
		return "已经听牌"
	return "离听牌还差%d步" % shanten


func _plain_debug_ukeire_text(ukeire: int) -> String:
	return "后面能接上的牌约%d张" % maxi(0, ukeire)


func _center_ai_tuning_panel() -> void:
	if ai_tuning_overlay == null or ai_tuning_panel == null:
		return
	var panel_size := _resolve_ai_tuning_panel_size()
	ai_tuning_panel.size = panel_size
	ai_tuning_panel.position = (ai_tuning_overlay.size - panel_size) * 0.5
	_clamp_ai_tuning_panel_position()
	call_deferred("_configure_ai_tuning_learning_scrollbar")


func _resolve_ai_tuning_panel_size() -> Vector2:
	if ai_tuning_overlay == null or ai_tuning_overlay.size == Vector2.ZERO:
		return ai_tuning_panel.custom_minimum_size if ai_tuning_panel != null else Vector2(1940, 1210)
	var viewport_size := ai_tuning_overlay.size
	var target_size := Vector2(
		maxf(1440.0, viewport_size.x * 0.994),
		maxf(980.0, viewport_size.y * 0.988)
	)
	return Vector2(
		minf(2040.0, minf(viewport_size.x - 2.0, target_size.x)),
		minf(1240.0, minf(viewport_size.y - 2.0, target_size.y))
	)


func _configure_ai_tuning_learning_scrollbar() -> void:
	if ai_tuning_learning_label == null or not is_instance_valid(ai_tuning_learning_label):
		return
	if not ai_tuning_learning_label.has_method("get_v_scroll_bar"):
		return
	var scroll_bar := ai_tuning_learning_label.get_v_scroll_bar()
	if scroll_bar == null:
		return
	scroll_bar.custom_minimum_size = Vector2(28.0, 0.0)
	scroll_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_STOP




func _clamp_ai_tuning_panel_position() -> void:
	if ai_tuning_overlay == null or ai_tuning_panel == null:
		return
	var margin := 16.0
	var max_position := ai_tuning_overlay.size - ai_tuning_panel.size - Vector2(margin, margin)
	ai_tuning_panel.position = Vector2(
		clampf(ai_tuning_panel.position.x, margin, maxf(margin, max_position.x)),
		clampf(ai_tuning_panel.position.y, margin, maxf(margin, max_position.y))
	)


func _apply_action_panel_visual_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = ACTION_PANEL_PADDING
	style.content_margin_right = ACTION_PANEL_PADDING
	style.content_margin_top = ACTION_PANEL_PADDING
	style.content_margin_bottom = ACTION_PANEL_PADDING
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	action_panel.add_theme_stylebox_override("panel", style)
	_remove_material_overlay(action_panel, "ActionPanelSoftLight")
	_remove_material_overlay(action_panel, "ActionPanelCyberHud")
	_remove_material_overlay(action_panel, "ActionPanelCrystalGlass")


func _apply_action_button_style(button: Button, primary: bool) -> void:
	if button == null:
		return
	var center := ACTION_PRIMARY_CENTER if primary else ACTION_SECONDARY_CENTER
	var edge := ACTION_PRIMARY_EDGE if primary else ACTION_SECONDARY_EDGE
	var outline := ACTION_PRIMARY_OUTLINE if primary else ACTION_SECONDARY_OUTLINE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.01)
	normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(0)
	normal.corner_radius_top_left = 999
	normal.corner_radius_top_right = 999
	normal.corner_radius_bottom_left = 999
	normal.corner_radius_bottom_right = 999
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.shadow_size = 0
	normal.shadow_offset = Vector2.ZERO
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.6

	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 1.0, 1.0, 0.03)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.0, 0.0, 0.0, 0.04)
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 6

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.0, 0.0, 0.0, 0.10)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_size_override("font_size", ACTION_PRIMARY_FONT_SIZE if primary else ACTION_SECONDARY_FONT_SIZE)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.0))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	button.add_theme_color_override("font_disabled_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	button.add_theme_constant_override("outline_size", 0)
	button.custom_minimum_size = ACTION_PRIMARY_SIZE if primary else ACTION_SECONDARY_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remove_material_overlay(button, "ButtonGlossLight")
	_remove_material_overlay(button, "CyberHudOverlay")
	_remove_material_overlay(button, "CrystalGlassOverlay")
	_ensure_circular_action_button_overlay(button, "CircularActionButtonOverlay", primary)
	var overlay := button.get_node_or_null("CircularActionButtonOverlay") as Control
	if overlay != null:
		overlay.set("center_color", center)
		overlay.set("edge_color", edge)
		overlay.set("outline_color", outline)
		overlay.set("label_text", button.text)


func _hand_contains_tile(hand_tiles: Array, tile_id: int) -> bool:
	for tile in hand_tiles:
		if int(tile.get("id", -1)) == tile_id:
			return true
	return false


func _seat_name(seat: int) -> String:
	var player_name := _player_name_by_seat(seat)
	if not player_name.is_empty():
		return player_name
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
			return "座位%d" % seat


func _ding_que_display(suit: String) -> String:
	match suit:
		"wan":
			return "缺万"
		"tiao":
			return "缺条"
		"tong":
			return "缺筒"
		_:
			return "待定"


func _ding_que_short_text(suit: String) -> String:
	match suit:
		"wan":
			return "万"
		"tiao":
			return "条"
		"tong":
			return "筒"
		_:
			return ""


func _ding_que_badge_fill(suit: String) -> Color:
	match suit:
		"tiao":
			return Color(0.20, 0.42, 0.28, 1.0)
		"tong":
			return Color(0.20, 0.32, 0.50, 1.0)
		"wan":
			return Color(0.52, 0.18, 0.17, 1.0)
		_:
			return Color(0.30, 0.29, 0.25, 1.0)
func _on_hand_tile_pressed(tile_id: int) -> void:
	if draw_transition_active:
		_recover_stale_draw_transition(game_manager.get_snapshot())
	if draw_transition_active:
		return
	if selected_tile_id == tile_id:
		_preview_human_discard(tile_id)
		if game_manager.discard_tile(tile_id):
			selected_tile_id = -1
			return
		selected_tile_id = tile_id
		_refresh_after_failed_human_action()
		return
	selected_tile_id = tile_id
	_refresh_self_selection_only()


func _preview_human_discard(tile_id: int) -> void:
	if last_snapshot.is_empty():
		return
	var players: Array = last_snapshot.get("players", [])
	var self_player := _player_by_seat(players, 0)
	if self_player.is_empty():
		return
	var preview_tiles: Array = game_manager.game_state.call("get_player_hand_tiles", 0)
	for index in range(preview_tiles.size()):
		var tile: Dictionary = preview_tiles[index]
		if int(tile.get("id", -1)) == tile_id:
			preview_tiles.remove_at(index)
			selected_tile_id = -1
			_update_self_area(last_snapshot, preview_tiles)
			return


func _refresh_self_selection_only() -> void:
	if last_snapshot.is_empty():
		return
	var players: Array = last_snapshot.get("players", [])
	var self_player := _player_by_seat(players, 0)
	var self_hand_tiles: Array = game_manager.game_state.call("get_player_hand_tiles", 0)
	if selected_tile_id != -1 and not _hand_contains_tile(self_hand_tiles, selected_tile_id):
		selected_tile_id = -1
	_update_self_area(last_snapshot, self_hand_tiles)


func _on_discard_helper_action_pressed() -> void:
	if last_snapshot.is_empty():
		return
	var trainer_hint: Dictionary = last_snapshot.get("trainer_hint", {})
	var tile_id: int = int(trainer_hint.get("recommended_tile_id", -1))
	if tile_id == -1:
		return
	selected_tile_id = tile_id
	_on_snapshot_changed(game_manager.get_snapshot())


func _on_top_bar_button_pressed() -> void:
	var snapshot := game_manager.get_snapshot()
	var current_preset := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
	var current_index := AI_PRESET_ORDER.find(current_preset)
	if current_index == -1:
		current_index = 1
	var next_preset: String = str(AI_PRESET_ORDER[(current_index + 1) % AI_PRESET_ORDER.size()])
	game_manager.set_ai_preset(next_preset)


func _on_top_ai_helper_button_pressed() -> void:
	ai_helper_enabled = not ai_helper_enabled
	if ai_assistant_drawer != null:
		ai_assistant_drawer.visible = ai_helper_enabled
		if ai_helper_enabled:
			# Default to the one-line decision rail that fits between the table and
			# the hand. Detailed reasons remain one explicit tap away.
			ai_assistant_drawer.call("set_expanded", false)
	game_manager.set_human_trainer_hint_enabled(ai_helper_enabled)
	_save_ui_preferences()
	if not ai_helper_enabled and discard_helper_panel != null:
		discard_helper_panel.visible = false
	var snapshot: Dictionary = game_manager.get_fresh_snapshot()
	_update_top_bar(snapshot)
	_on_snapshot_changed(snapshot)


func _on_top_opponent_hand_button_pressed() -> void:
	opponent_hands_enabled = not opponent_hands_enabled
	_save_ui_preferences()
	_update_top_bar(game_manager.get_snapshot())
	_on_snapshot_changed(game_manager.get_snapshot())


func _on_hell_mark_button_pressed() -> void:
	game_manager.mark_current_hell_training_case("manual_mark_from_ui")
	_update_top_bar(game_manager.get_snapshot())
	_on_snapshot_changed(game_manager.get_snapshot())


func _on_diagnostic_export_button_pressed() -> void:
	if diagnostic_export_in_progress:
		return
	_run_diagnostic_export_deferred()


func _run_diagnostic_export_deferred() -> void:
	diagnostic_export_in_progress = true
	if floating_diagnostic_export_button != null and is_instance_valid(floating_diagnostic_export_button):
		floating_diagnostic_export_button.disabled = true
		floating_diagnostic_export_button.text = "..."
	await get_tree().process_frame
	if OS.has_feature("android"):
		OS.request_permissions()
	var result := game_manager.export_diagnostic_package()
	var message := _build_diagnostic_export_message(result)
	var path_to_copy := str(result.get("path_absolute", result.get("path", "")))
	var download_copy: Dictionary = result.get("download_copy", {})
	if bool(download_copy.get("ok", false)):
		path_to_copy = str(download_copy.get("path", path_to_copy))
	if bool(download_copy.get("ok", false)) and not path_to_copy.is_empty():
		DisplayServer.clipboard_set(path_to_copy)
	else:
		var internal_path := str(result.get("path", ""))
		var diagnostic_text := FileAccess.get_file_as_string(internal_path) if not internal_path.is_empty() else ""
		if not diagnostic_text.is_empty():
			DisplayServer.clipboard_set(diagnostic_text.left(180000))
		elif not path_to_copy.is_empty():
			DisplayServer.clipboard_set(path_to_copy)
	print("[DiagnosticExport] ", JSON.stringify(result))
	_show_nonblocking_diagnostic_export_message(message)
	diagnostic_export_in_progress = false
	if floating_diagnostic_export_button != null and is_instance_valid(floating_diagnostic_export_button):
		floating_diagnostic_export_button.disabled = false
		floating_diagnostic_export_button.text = "导"
	_update_top_bar(game_manager.get_snapshot())
	_on_snapshot_changed(game_manager.get_snapshot())


func _show_nonblocking_diagnostic_export_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "诊断导出"
	dialog.dialog_text = message
	dialog.exclusive = false
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	root_ui.add_child(dialog)
	dialog.popup_centered(Vector2(720, 360))


func _build_diagnostic_export_message(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return "诊断包导出失败。\n错误：%s\n内部路径：%s" % [
			str(result.get("error", "unknown")),
			str(result.get("path_absolute", result.get("path", ""))),
		]
	var download_copy: Dictionary = result.get("download_copy", {})
	if bool(download_copy.get("ok", false)):
		return "诊断包已导出到下载目录，并已复制文件路径。\n\n%s" % str(download_copy.get("path", ""))
	var internal_path := str(result.get("path_absolute", result.get("path", "")))
	return "诊断包已生成，但安卓拒绝写入下载目录。\n\n我已把诊断内容复制到剪贴板；也可以用 ADB 读取内部文件。\n\n内部路径：%s\n\n下载目录错误：%s" % [
		internal_path,
		str(download_copy.get("error", "unknown")),
	]


func _on_top_exit_pressed() -> void:
	if exit_confirmation_dialog == null or not is_instance_valid(exit_confirmation_dialog):
		exit_confirmation_dialog = ConfirmationDialog.new()
		exit_confirmation_dialog.name = "ExitGameConfirmation"
		exit_confirmation_dialog.title = "退出游戏"
		exit_confirmation_dialog.dialog_text = "确定退出四川麻将吗？\n当前这一局将不会继续。"
		exit_confirmation_dialog.exclusive = true
		exit_confirmation_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		root_ui.add_child(exit_confirmation_dialog)
		exit_confirmation_dialog.get_ok_button().text = "退出游戏"
		exit_confirmation_dialog.get_cancel_button().text = "继续游戏"
		STYLE_CONFIG.apply_button(exit_confirmation_dialog.get_ok_button(), true)
		STYLE_CONFIG.apply_button(exit_confirmation_dialog.get_cancel_button(), false)
		exit_confirmation_dialog.confirmed.connect(_confirm_exit_game)
	exit_confirmation_dialog.popup_centered(Vector2(620.0, 280.0))


func _confirm_exit_game() -> void:
	_save_ui_preferences()
	await get_tree().process_frame
	if OS.has_feature("ios"):
		# SceneTree.quit() 在 iOS 上会被平台生命周期忽略。Godot 4.6 的
		# OS.kill() 明确实现了 iOS 后端，用自身 PID 结束本应用，保证用户
		# 已确认的“退出游戏”动作真正生效。
		OS.kill(OS.get_process_id())
		return
	get_tree().quit()


func _load_ui_preferences() -> void:
	var config := ConfigFile.new()
	var err: int = config.load(UI_PREFS_PATH)
	if err != OK:
		return
	ai_helper_enabled = bool(config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_HELPER, false))
	opponent_hands_enabled = bool(config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_OPPONENT_HANDS, false))
	if config.has_section_key(UI_PREFS_SECTION, UI_PREFS_KEY_AI_GLASS_OPACITY):
		ai_glass_opacity = clampf(float(config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_GLASS_OPACITY, 0.70)), 0.0, 1.0)
	else:
		var legacy_index := clampi(int(config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_GLASS_OPACITY_LEGACY, 1)), 0, 2)
		ai_glass_opacity = [0.48, 0.70, 0.90][legacy_index]
	var stored_position: Variant = config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_DRAWER_POSITION, Vector2(0.5, 0.72))
	if stored_position is Vector2:
		ai_drawer_position_normalized = Vector2(
			clampf((stored_position as Vector2).x, 0.0, 1.0),
			clampf((stored_position as Vector2).y, 0.0, 1.0)
		)
	var stored_drawer_layout_version := int(config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_DRAWER_LAYOUT_VERSION, 0))
	ai_drawer_positioned = bool(config.get_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_DRAWER_POSITIONED, false)) \
		and stored_drawer_layout_version >= AI_DRAWER_LAYOUT_VERSION


func _save_ui_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_HELPER, ai_helper_enabled)
	config.set_value(UI_PREFS_SECTION, UI_PREFS_KEY_OPPONENT_HANDS, opponent_hands_enabled)
	config.set_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_GLASS_OPACITY, ai_glass_opacity)
	config.set_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_DRAWER_POSITION, ai_drawer_position_normalized)
	config.set_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_DRAWER_POSITIONED, ai_drawer_positioned)
	config.set_value(UI_PREFS_SECTION, UI_PREFS_KEY_AI_DRAWER_LAYOUT_VERSION, AI_DRAWER_LAYOUT_VERSION)
	config.save(UI_PREFS_PATH)


func _on_top_ai_tuning_button_pressed() -> void:
	if ai_tuning_overlay == null:
		return
	_refresh_ai_tuning_panel(game_manager.get_snapshot())
	if not ai_tuning_panel_moved:
		_center_ai_tuning_panel()
	ai_tuning_overlay.visible = true


func _close_ai_tuning_overlay() -> void:
	if ai_tuning_overlay == null:
		return
	ai_tuning_overlay.visible = false


func _on_ai_tuning_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_ai_tuning_overlay()


func _on_ai_tuning_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		ai_tuning_dragging = false


func _on_ai_tuning_drag_handle_gui_input(event: InputEvent) -> void:
	if ai_tuning_panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		ai_tuning_dragging = event.pressed
		if event.pressed:
			ai_tuning_panel_moved = true
			ai_tuning_drag_offset = ai_tuning_panel.get_local_mouse_position()
	elif event is InputEventMouseMotion and ai_tuning_dragging:
		ai_tuning_panel.global_position = get_global_mouse_position() - ai_tuning_drag_offset
		_clamp_ai_tuning_panel_position()


func _on_ai_tuning_preset_pressed(preset_name: String) -> void:
	game_manager.set_ai_preset(preset_name)


func _on_ai_tuning_adjust_pressed(key: String, delta: int) -> void:
	var snapshot := game_manager.get_snapshot()
	var tuning: Dictionary = snapshot.get("ai_tuning_config", {})
	var current_value := int(tuning.get(key, 0))
	game_manager.set_ai_tuning_value(key, current_value + delta)


func _on_ai_tuning_reset_pressed() -> void:
	game_manager.reset_ai_tuning_overrides()


func _on_ai_tuning_auto_learning_pressed() -> void:
	var snapshot := game_manager.get_snapshot()
	var tuning: Dictionary = snapshot.get("ai_tuning_config", {})
	var current_enabled := bool(tuning.get("auto_learning_enabled", true))
	game_manager.set_ai_auto_learning_enabled(not current_enabled)


func _on_ai_tuning_endgame_defense_pressed() -> void:
	var snapshot := game_manager.get_snapshot()
	var tuning: Dictionary = snapshot.get("ai_tuning_config", {})
	var current_enabled := bool(tuning.get("endgame_absolute_defense", true))
	game_manager.set_ai_endgame_absolute_defense_enabled(not current_enabled)


func _on_ai_tuning_bone_recommended_pressed() -> void:
	game_manager.apply_bone_ash_recommended_tuning()


func _on_draw_transition_timer_timeout() -> void:
	draw_transition_active = false
	draw_transition_started_at_ms = 0
	draw_transition_expected_ms = 0
	if game_manager.is_ai_turn_ready():
		game_manager.prepare_ai_turn_decision()
		_start_ai_turn_action_timer()
		return
	_on_snapshot_changed(game_manager.get_snapshot())


func _on_top_next_round_pressed() -> void:
	if int(game_manager.get_snapshot().get("current_phase", 0)) != 7:
		return
	game_manager.advance_to_next_round()


func _on_hu_pressed() -> void:
	var snapshot := game_manager.get_snapshot()
	var reaction_options: Dictionary = snapshot.get("human_reaction_options", {})
	var actions: Array = []
	if bool(reaction_options.get("can_hu", false)):
		actions.append("hu")
	if bool(snapshot.get("human_can_self_hu", false)):
		actions.append("self_hu")
	var executed_action := _execute_human_action_sequence(actions)
	if executed_action == "self_hu":
		_speak_action("自摸", 0)
	elif executed_action == "hu":
		_speak_action("胡", 0)


func _on_gang_pressed() -> void:
	var snapshot := game_manager.get_snapshot()
	var reaction_options: Dictionary = snapshot.get("human_reaction_options", {})
	var actions: Array = []
	if bool(reaction_options.get("can_gang", false)):
		actions.append("gang")
	if bool(snapshot.get("human_can_add_gang", false)):
		actions.append("add_gang")
	if bool(snapshot.get("human_can_an_gang", false)):
		actions.append("an_gang")
	if not _execute_human_action_sequence(actions).is_empty():
		_speak_action("杠", 0)


func _on_peng_pressed() -> void:
	if not _execute_human_action_sequence(["peng"]).is_empty():
		_speak_action("碰", 0)


func _on_an_gang_pressed() -> void:
	if not _execute_human_action_sequence(["an_gang"]).is_empty():
		_speak_action("杠", 0)


func _on_pass_pressed() -> void:
	var snapshot := game_manager.get_snapshot()
	if bool(snapshot.get("human_can_self_hu", false)) and not bool(snapshot.get("human_reaction_options", {}).get("can_pass", false)):
		if not _execute_human_action_sequence(["pass_self_hu"]).is_empty():
			return
	if not _execute_human_action_sequence(["pass"]).is_empty():
		_speak_action("过", 0)


func _execute_human_action_sequence(actions: Array) -> String:
	if game_manager == null:
		return ""
	for action in actions:
		var action_name := str(action)
		if action_name.is_empty():
			continue
		if game_manager.execute_action(action_name):
			return action_name
	_refresh_after_failed_human_action()
	return ""


func _refresh_after_failed_human_action() -> void:
	if game_manager == null:
		return
	# A rejected click must refresh from GameState, not from the manager's
	# cached frame.  Otherwise a stale reaction panel can remain visible and
	# make only the visually-unobstructed "过" button appear usable.
	var snapshot := game_manager.get_fresh_snapshot()
	if snapshot.is_empty():
		return
	_recover_stale_draw_transition(snapshot)
	_on_snapshot_changed(snapshot)


func _ensure_an_gang_button() -> void:
	if an_gang_button != null:
		return
	an_gang_button = Button.new()
	an_gang_button.visible = false
	an_gang_button.focus_mode = Control.FOCUS_NONE
	action_buttons.add_child(an_gang_button)
	action_buttons.move_child(an_gang_button, 2)


func _on_ding_que_pressed(suit: String) -> void:
	if not pending_ding_que_suit.is_empty():
		return
	pending_ding_que_suit = suit
	_apply_ding_que_selection_state(suit)
	var reduced_motion := bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	if not reduced_motion:
		await get_tree().create_timer(0.14).timeout
	if game_manager.choose_ding_que(suit):
		_speak_ding_que(suit, 0)
		return
	_reset_ding_que_visual_state()
	_refresh_ding_que_panel(game_manager.get_fresh_snapshot())


func _on_next_round_pressed() -> void:
	game_manager.advance_to_next_round()


func _on_top_settlement_info_pressed() -> void:
	if int(game_manager.get_snapshot().get("current_phase", 0)) != 7:
		return
	settlement_dismissed = false
	settlement_overlay.visible = true
	if settlement_overlay_v2 != null:
		settlement_overlay_v2.visible = false
	_apply_settlement_backdrop_state(true)
	_layout_settlement_overlay()
	_render_settlement(game_manager.get_snapshot())
	settlement_overlay.move_to_front()


func _on_settlement_close_pressed() -> void:
	if int(game_manager.get_snapshot().get("current_phase", 0)) != 7:
		return
	settlement_dismissed = true
	settlement_overlay.visible = false
	if settlement_overlay_v2 != null:
		settlement_overlay_v2.visible = false
	_apply_settlement_backdrop_state(false)
	if table_utility_bar != null:
		var snapshot := game_manager.get_snapshot()
		var preset_name := str(snapshot.get("ai_tuning_config", {}).get("preset_name", "bone_ash"))
		table_utility_bar.call("render", ai_helper_enabled, true, true, str(AI_PRESET_LABELS.get(preset_name, "骨灰")), opponent_hands_enabled)
		_layout_table_utility_bar()


func _on_settlement_shade_gui_input(event: InputEvent) -> void:
	if not settlement_overlay.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_settlement_close_pressed()
		settlement_shade.accept_event()


func _on_ai_turn_timer_timeout() -> void:
	ai_turn_timer.stop()
	ai_turn_timer_started_at_ms = 0
	var success: bool = game_manager.run_ai_turn()
	if success:
		return
	if game_manager.is_ai_turn_ready():
		game_manager.prepare_ai_turn_decision()
		ai_turn_timer.wait_time = AI_READY_POLL_SEC
		ai_turn_timer_started_at_ms = Time.get_ticks_msec()
		ai_turn_timer.start()
		return
	_on_snapshot_changed(game_manager.get_snapshot())


func _on_ai_reaction_timer_timeout() -> void:
	ai_reaction_timer.stop()
	ai_reaction_timer_started_at_ms = 0
	var success: bool = game_manager.run_ai_reaction()
	if success:
		return
	if game_manager.is_ai_reaction_pending():
		game_manager.prepare_ai_reaction_decision()
		ai_reaction_timer.wait_time = AI_READY_POLL_SEC
		ai_reaction_timer_started_at_ms = Time.get_ticks_msec()
		ai_reaction_timer.start()
		return
	_on_snapshot_changed(game_manager.get_snapshot())


func _on_ai_watchdog_timer_timeout() -> void:
	if game_manager == null:
		return
	var snapshot := game_manager.get_snapshot()
	if snapshot.is_empty():
		return
	if draw_transition_active and game_manager.is_ai_reaction_pending():
		_clear_draw_transition_block("watchdog_ai_reaction")
	if draw_transition_active:
		var was_active := draw_transition_active
		_recover_stale_draw_transition(snapshot)
		if was_active and not draw_transition_active:
			_on_snapshot_changed(snapshot)
			return
	if draw_transition_active:
		return
	if game_manager.is_ai_turn_ready() and ai_turn_timer != null and ai_turn_timer.is_stopped():
		_start_ai_turn_action_timer()
		return
	if game_manager.is_ai_turn_ready() and ai_turn_timer != null and not ai_turn_timer.is_stopped():
		var elapsed_turn_ms := maxi(0, Time.get_ticks_msec() - ai_turn_timer_started_at_ms)
		var expected_turn_ms := int(round(maxf(ai_turn_timer.wait_time, AI_READY_POLL_SEC) * 1000.0))
		if ai_turn_timer_started_at_ms > 0 and elapsed_turn_ms >= expected_turn_ms + 260:
			ai_turn_timer.stop()
			ai_turn_timer_started_at_ms = 0
			if not game_manager.run_ai_turn():
				game_manager.prepare_ai_turn_decision()
				ai_turn_timer.wait_time = AI_READY_POLL_SEC
				ai_turn_timer_started_at_ms = Time.get_ticks_msec()
				ai_turn_timer.start()
			return
	if game_manager.is_ai_reaction_pending() and ai_reaction_timer != null and ai_reaction_timer.is_stopped():
		_start_ai_reaction_action_timer()
		return
	if game_manager.is_ai_reaction_pending() and ai_reaction_timer != null and not ai_reaction_timer.is_stopped():
		var elapsed_reaction_ms := maxi(0, Time.get_ticks_msec() - ai_reaction_timer_started_at_ms)
		var expected_reaction_ms := int(round(maxf(ai_reaction_timer.wait_time, AI_READY_POLL_SEC) * 1000.0))
		if ai_reaction_timer_started_at_ms > 0 and elapsed_reaction_ms >= expected_reaction_ms + 260:
			ai_reaction_timer.stop()
			ai_reaction_timer_started_at_ms = 0
			if not game_manager.run_ai_reaction():
				game_manager.prepare_ai_reaction_decision()
				ai_reaction_timer.wait_time = AI_READY_POLL_SEC
				ai_reaction_timer_started_at_ms = Time.get_ticks_msec()
				ai_reaction_timer.start()
