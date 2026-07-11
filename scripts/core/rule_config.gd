extends RefCounted

class_name RuleConfig

const MODE_SICHUAN_COMPETITIVE_BATTLE_TO_END := "sichuan_competitive_battle_to_end"
const MODE_NEIJIANG_CLASSIC := "removed_neijiang_classic"

const ALL_SUITS := ["tiao", "tong", "wan"]

var mode: String = MODE_SICHUAN_COMPETITIVE_BATTLE_TO_END
var available_suits: Array = ALL_SUITS.duplicate()
var total_tile_count: int = 108

var allow_chi: bool = false
var allow_peng: bool = true
var allow_gang: bool = true
var allow_qiang_gang_hu: bool = true
var allow_multi_win_on_discard: bool = true
var enable_qi_dui: bool = true
var require_missing_one_suit_to_win: bool = true
var use_battle_to_end_flow: bool = true
var max_winners_per_round: int = 3
var fan_cap: int = 3

var use_ding_que_phase: bool = true
var enable_bao_jiao: bool = false
var enable_bao_gang: bool = false
var enable_ka_er_tiao: bool = false
var enable_gui: bool = false
var enable_cha_jiao: bool = true
var enable_tui_shui: bool = true
var enable_hua_zhu: bool = true
var self_draw_extra_base_score: int = 1


func _init(mode_name: String = MODE_SICHUAN_COMPETITIVE_BATTLE_TO_END) -> void:
	apply_mode(mode_name)


func apply_mode(mode_name: String) -> void:
	mode = MODE_SICHUAN_COMPETITIVE_BATTLE_TO_END
	_apply_sichuan_defaults()


func is_neijiang_mode() -> bool:
	return false


func is_sichuan_mode() -> bool:
	return mode == MODE_SICHUAN_COMPETITIVE_BATTLE_TO_END


func requires_ding_que_phase() -> bool:
	return use_ding_que_phase


func _apply_sichuan_defaults() -> void:
	available_suits = ALL_SUITS.duplicate()
	total_tile_count = 108
	allow_chi = false
	allow_peng = true
	allow_gang = true
	allow_qiang_gang_hu = true
	allow_multi_win_on_discard = true
	enable_qi_dui = true
	require_missing_one_suit_to_win = true
	use_battle_to_end_flow = true
	max_winners_per_round = 3
	fan_cap = 3
	use_ding_que_phase = true
	enable_bao_jiao = false
	enable_bao_gang = false
	enable_ka_er_tiao = false
	enable_gui = false
	enable_cha_jiao = true
	enable_tui_shui = true
	enable_hua_zhu = true
	self_draw_extra_base_score = 1


func to_debug_dict() -> Dictionary:
	return {
		"mode": mode,
		"available_suits": available_suits.duplicate(),
		"total_tile_count": total_tile_count,
		"allow_chi": allow_chi,
		"allow_peng": allow_peng,
		"allow_gang": allow_gang,
		"allow_qiang_gang_hu": allow_qiang_gang_hu,
		"allow_multi_win_on_discard": allow_multi_win_on_discard,
		"enable_qi_dui": enable_qi_dui,
		"require_missing_one_suit_to_win": require_missing_one_suit_to_win,
		"use_battle_to_end_flow": use_battle_to_end_flow,
		"max_winners_per_round": max_winners_per_round,
		"fan_cap": fan_cap,
		"use_ding_que_phase": use_ding_que_phase,
		"enable_bao_jiao": enable_bao_jiao,
		"enable_bao_gang": enable_bao_gang,
		"enable_ka_er_tiao": enable_ka_er_tiao,
		"enable_gui": enable_gui,
		"enable_cha_jiao": enable_cha_jiao,
		"enable_tui_shui": enable_tui_shui,
		"enable_hua_zhu": enable_hua_zhu,
		"self_draw_extra_base_score": self_draw_extra_base_score,
	}
