extends SceneTree

const RULE_SCRIPT := preload("res://scripts/core/rule_config.gd")
const FAN_SCRIPT := preload("res://scripts/core/fan_resolver.gd")
const SCORE_SCRIPT := preload("res://scripts/core/score_resolver.gd")

var failures: Array[String] = []
var next_tile_id := 70000
var rules
var fan_resolver
var score_resolver


func _init() -> void:
	rules = RULE_SCRIPT.new()
	fan_resolver = FAN_SCRIPT.new()
	score_resolver = SCORE_SCRIPT.new()
	_verify_base_hand_table()
	_verify_root_and_bonus_table()
	_verify_payment_table()
	_verify_draw_table()
	if failures.is_empty():
		print("SICHUAN_SCORING_RULES_20260723_PASS")
		quit(0)
		return
	push_error("SICHUAN_SCORING_RULES_20260723_FAILED:\n- " + "\n- ".join(failures))
	quit(1)


func _verify_base_hand_table() -> void:
	var ping := _tiles([
		["wan", 1, 1], ["wan", 2, 1], ["wan", 3, 1],
		["wan", 4, 1], ["wan", 5, 1], ["wan", 6, 1],
		["tong", 1, 1], ["tong", 2, 1], ["tong", 3, 1],
		["tong", 4, 1], ["tong", 5, 1], ["tong", 6, 1],
		["wan", 9, 2],
	])
	var da_dui := _tiles([
		["wan", 1, 3], ["wan", 3, 3], ["tong", 5, 3], ["tong", 7, 3], ["wan", 9, 2],
	])
	var qing := _tiles([
		["wan", 1, 1], ["wan", 2, 1], ["wan", 3, 1],
		["wan", 3, 1], ["wan", 4, 1], ["wan", 5, 1],
		["wan", 5, 1], ["wan", 6, 1], ["wan", 7, 1],
		["wan", 6, 1], ["wan", 7, 1], ["wan", 8, 1],
		["wan", 9, 2],
	])
	var qi_dui := _tiles([
		["wan", 1, 2], ["wan", 2, 2], ["wan", 3, 2], ["tong", 4, 2],
		["tong", 5, 2], ["tong", 6, 2], ["tong", 7, 2],
	])
	var long_qi_dui := _tiles([
		["wan", 1, 4], ["wan", 2, 2], ["wan", 3, 2],
		["tong", 4, 2], ["tong", 5, 2], ["tong", 6, 2],
	])
	var qing_qi_dui := _tiles([
		["wan", 1, 2], ["wan", 2, 2], ["wan", 3, 2], ["wan", 4, 2],
		["wan", 5, 2], ["wan", 6, 2], ["wan", 7, 2],
	])
	var qing_dui := _tiles([
		["wan", 1, 3], ["wan", 3, 3], ["wan", 5, 3], ["wan", 7, 3], ["wan", 9, 2],
	])
	var jiang_dui := _tiles([
		["wan", 2, 3], ["wan", 5, 3], ["tong", 8, 3], ["tong", 2, 3], ["wan", 8, 2],
	])
	var jin_gou_melds := [
		_meld("peng", "wan", 1), _meld("peng", "wan", 3),
		_meld("gang", "tong", 5), _meld("peng", "tong", 7),
	]
	var qing_jin_gou_melds := [
		_meld("peng", "wan", 1), _meld("peng", "wan", 3),
		_meld("gang", "wan", 5), _meld("peng", "wan", 7),
	]
	var luohan_melds := [
		_meld("gang", "wan", 1), _meld("gang", "wan", 3),
		_meld("gang", "tong", 5), _meld("gang", "tong", 7),
	]
	var cases := [
		["ping_hu", 0, ping, []],
		["da_dui_zi", 1, da_dui, []],
		["qing_yi_se", 2, qing, []],
		["qi_dui", 2, qi_dui, []],
		["jin_gou_diao", 2, _tiles([["wan", 9, 2]]), jin_gou_melds],
		["qing_dui", 3, qing_dui, []],
		["jiang_dui", 3, jiang_dui, []],
		["long_qi_dui", 3, long_qi_dui, []],
		["qing_qi_dui", 4, qing_qi_dui, []],
		["qing_jin_gou_diao", 4, _tiles([["wan", 9, 2]]), qing_jin_gou_melds],
		["shi_ba_luo_han", 4, _tiles([["wan", 9, 2]]), luohan_melds],
	]
	for item in cases:
		var detail := _detail(item[2], item[3], "self_draw")
		_check(str(detail.get("hand_type", "")) == str(item[0]), "%s hand type, got %s" % [item[0], detail])
		_check(int(detail.get("base_fan", -1)) == int(item[1]), "%s base fan must be %d" % [item[0], item[1]])
		_check(int(detail.get("hand_score", 0)) == (1 << int(item[1])), "%s score must equal 2^fan" % item[0])


func _verify_root_and_bonus_table() -> void:
	var qing_one_root := _tiles([
		["wan", 1, 4], ["wan", 2, 3], ["wan", 3, 1],
		["wan", 4, 1], ["wan", 5, 1], ["wan", 6, 1], ["wan", 7, 1], ["wan", 8, 1], ["wan", 9, 1],
	])
	var one_root := _detail(qing_one_root, [], "self_draw")
	_check(int(one_root.get("base_fan", -1)) == 2 and int(one_root.get("gen_count", -1)) == 1, "concealed un-ganged quad must add one root")
	_check(int(one_root.get("uncapped_fan", -1)) == 3, "qing-yise plus one root must total 3 fan")

	var double_quad_qi_dui := _tiles([
		["wan", 1, 4], ["tong", 2, 4], ["wan", 3, 2], ["tong", 4, 2], ["wan", 5, 2],
	])
	var dragon := _detail(double_quad_qi_dui, [], "self_draw")
	_check(str(dragon.get("hand_type", "")) == "long_qi_dui", "double-quad seven pairs must resolve as dragon seven pairs")
	_check(int(dragon.get("gen_count", -1)) == 1, "dragon seven pairs must consume only its built-in first root")
	_check(int(dragon.get("uncapped_fan", -1)) == 4, "dragon seven pairs plus the extra root must total 4 fan")

	var ping := _tiles([
		["wan", 1, 1], ["wan", 2, 1], ["wan", 3, 1],
		["wan", 4, 1], ["wan", 5, 1], ["wan", 6, 1],
		["tong", 1, 1], ["tong", 2, 1], ["tong", 3, 1],
		["tong", 4, 1], ["tong", 5, 1], ["tong", 6, 1],
		["wan", 9, 2],
	])
	for win_type in ["gang_self_draw", "gang_discard_win", "qiang_gang_hu"]:
		var player_hand: Array = ping if win_type == "gang_self_draw" else ping.slice(0, 13)
		var winning_tile: Dictionary = ping[0] if win_type == "gang_self_draw" else ping[13]
		var detail: Dictionary = fan_resolver.resolve_win_fans(
			{"hand_tiles": player_hand, "melds": []},
			winning_tile,
			win_type,
			rules
		)
		_check(int(detail.get("bonus_fan", -1)) == 1, "%s must add exactly one fan" % win_type)

	var capped := _detail(double_quad_qi_dui, [], "gang_self_draw")
	_check(int(capped.get("uncapped_fan", 0)) == 5 and int(capped.get("capped_fan", 0)) == 4, "all additions above four fan must cap at four")
	_check(int(capped.get("hand_score", 0)) == 16, "capped hand score must be 16")


func _verify_payment_table() -> void:
	var players := [_player(0), _player(1), _player(2), _player(3)]
	for fan in range(5):
		var discard: Dictionary = score_resolver.build_score_changes(players, {
			"win_events": [{
				"winner_seat": 0, "payer_seats": [1], "win_type": "discard_win",
				"fan_detail": {"capped_fan": fan},
			}],
		}, rules)
		_check(int(discard.get(0, 0)) == (1 << fan) and int(discard.get(1, 0)) == -(1 << fan), "discard payment table failed at %d fan" % fan)
	var self_draw: Dictionary = score_resolver.build_score_changes(players, {
		"win_events": [{
			"winner_seat": 0, "payer_seats": [1, 2, 3], "win_type": "self_draw",
			"fan_detail": {"capped_fan": 4},
		}],
	}, rules)
	_check(int(self_draw.get(0, 0)) == 51, "self-draw winner must receive (16+1) from all three players")
	for seat in [1, 2, 3]:
		_check(int(self_draw.get(seat, 0)) == -17, "self-draw payer %d must pay fixed 17" % seat)

	var gang: Dictionary = score_resolver.build_score_changes(players, {
		"gang_events": [
			{"actor_seat": 0, "gang_type": "melded_gang", "payer_seats": [1]},
			{"actor_seat": 0, "gang_type": "add_gang", "payer_seats": [1, 2, 3]},
			{"actor_seat": 0, "gang_type": "an_gang", "payer_seats": [1, 2, 3]},
		],
	}, rules)
	_check(gang == {0: 11, 1: -5, 2: -3, 3: -3}, "gang unit table must be direct=2, added=1x3, concealed=2x3")

	var transfer: Dictionary = score_resolver.build_score_changes(players, {
		"transfer_events": [{
			"from_seat": 0, "to_seat": 2, "transfer_type": "hu_jiao_zhuan_yi",
			"gang_type": "an_gang", "payer_seats": [1, 2, 3],
		}],
	}, rules)
	_check(transfer == {0: -6, 1: 0, 2: 6, 3: 0}, "gang-discard transfer must move the whole gang gain from actor to winner")


func _verify_draw_table() -> void:
	var players := [_player(0), _player(1), _player(2), _player(3)]
	var draw: Dictionary = score_resolver.build_score_changes(players, {
		"win_events": [{
			"winner_seat": 3,
			"payer_seats": [0],
			"win_type": "discard_win",
			"fan_detail": {"capped_fan": 2, "hand_score": 4},
		}],
		"draw_assessment": [
			{"seat": 0, "is_ting": true, "hua_zhu": false, "cha_jiao_score": 2},
			{"seat": 1, "is_ting": false, "hua_zhu": false, "cha_jiao_score": 0},
			{"seat": 2, "is_ting": false, "hua_zhu": true, "cha_jiao_score": 0},
		],
	}, rules)
	# 胡牌事件先让 0 向 3 支付 4；流局时 1 再向下叫 0 付 2、向已胡 3 付 4；
	# 花猪 2 只向仍下叫的 0 固定支付 16。
	_check(draw == {0: 14, 1: -6, 2: -16, 3: 8}, "draw settlement must combine fixed flower-pig and max-ready/winner big-call payments")


func _detail(hand: Array, melds: Array, win_type: String) -> Dictionary:
	var winning_tile: Dictionary = hand[0] if not hand.is_empty() else {}
	return fan_resolver.resolve_win_fans(
		{"hand_tiles": hand, "melds": melds},
		winning_tile,
		win_type,
		rules
	)


func _tiles(spec: Array) -> Array:
	var result: Array = []
	for item in spec:
		for _copy in range(int(item[2])):
			result.append({
				"id": next_tile_id,
				"suit": str(item[0]),
				"rank": int(item[1]),
				"display_name": "%s%d" % [str(item[0]), int(item[1])],
			})
			next_tile_id += 1
	return result


func _meld(meld_type: String, suit: String, rank: int) -> Dictionary:
	return {
		"type": meld_type,
		"gang_subtype": "an_gang" if meld_type == "gang" else "",
		"tiles": _tiles([[suit, rank, 4 if meld_type == "gang" else 3]]),
	}


func _player(seat: int) -> Dictionary:
	return {"seat": seat, "hand_tiles": [], "melds": [], "has_won": false}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
