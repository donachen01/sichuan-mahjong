extends RefCounted

class_name OpeningRollResolver

func build_opening_roll(dealer_seat: int, rng: RandomNumberGenerator) -> Dictionary:
	var die_a := rng.randi_range(1, 6)
	var die_b := rng.randi_range(1, 6)
	var total := die_a + die_b
	var opening_side := opening_side_from_total(total)
	var opening_seat := resolve_opening_seat(dealer_seat, opening_side)
	return {
		"dealer_seat": dealer_seat,
		"die_a": die_a,
		"die_b": die_b,
		"total": total,
		"opening_side": opening_side,
		"opening_side_label": opening_side_label(opening_side),
		"opening_seat": opening_seat,
	}


func opening_side_from_total(total: int) -> String:
	match total:
		5, 9:
			return "self"
		2, 6, 10:
			return "xiajia"
		3, 7, 11:
			return "duijia"
		4, 8, 12:
			return "shangjia"
		_:
			return "self"


func opening_side_label(side: String) -> String:
	match side:
		"self":
			return "自家"
		"xiajia":
			return "下家"
		"duijia":
			return "对家"
		"shangjia":
			return "上家"
		_:
			return "自家"


func resolve_opening_seat(dealer_seat: int, opening_side: String) -> int:
	match opening_side:
		"self":
			return dealer_seat
		"xiajia":
			return posmod(dealer_seat - 1, 4)
		"duijia":
			return posmod(dealer_seat - 2, 4)
		"shangjia":
			return posmod(dealer_seat - 3, 4)
		_:
			return dealer_seat
