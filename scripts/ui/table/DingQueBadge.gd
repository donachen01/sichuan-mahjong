class_name DingQueBadge
extends PanelContainer

const METRICS := preload("res://scripts/ui/table/SichuanTableMetrics.gd")
const TABLE_THEME := preload("res://scripts/ui/table/SichuanTableTheme.gd")
const STYLE_CONFIG := preload("res://res/ui/default_ui_style.tres")

@onready var text_label: Label = %TextLabel

var suit := ""
var compact := false
var revealed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	STYLE_CONFIG.apply_label(text_label, false, true)
	_refresh()


func configure(suit_value: String, compact_value: bool = false) -> void:
	suit = suit_value if suit_value in ["wan", "tong", "tiao"] else ""
	compact = compact_value
	_refresh()


func set_revealed(value: bool) -> void:
	revealed = value
	_refresh()


func get_suit() -> String:
	return suit


func _refresh() -> void:
	if text_label == null:
		return
	custom_minimum_size = METRICS.ding_que_size(compact)
	text_label.custom_minimum_size = Vector2(88.0 if compact else 96.0, 34.0 if compact else 38.0)
	text_label.text = TABLE_THEME.ding_que_text(suit)
	text_label.add_theme_font_size_override("font_size", TABLE_THEME.font_size("ding_que", compact))
	text_label.add_theme_color_override("font_color", TABLE_THEME.TEXT_PRIMARY)
	text_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	text_label.add_theme_constant_override("outline_size", 3)
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	add_theme_stylebox_override("panel", clear_style)
	var badge_style := TABLE_THEME.make_badge_style(suit)
	# The shared table HUD carries name, score and ding-que state in one compact
	# card. Keep the chip's visual padding tactile without letting the font's
	# ascent plus theme padding inflate the chip beyond its published token.
	badge_style.content_margin_top = 4.0
	badge_style.content_margin_bottom = 4.0
	text_label.add_theme_stylebox_override("normal", badge_style)
	visible = revealed and not suit.is_empty()
