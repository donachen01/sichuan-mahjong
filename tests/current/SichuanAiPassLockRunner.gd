extends SceneTree

const GAME = preload("res://autoload/GameState.gd")
var failures: Array = []
var checks := 0

func _init() -> void:
	await process_frame
	for rotation in range(3):
		for seat in range(4):
			for reaction_type in ["discard", "qiang_gang_hu"]:
				for can_hu in [false, true]:
					var human := _fixture(rotation, seat, reaction_type, can_hu)
					var ai := _fixture(rotation, seat, reaction_type, can_hu)
					human.call("pass_human_reaction", seat)
					ai.call("_pass_ai_reaction", seat)
					_check(human.get("shun_he_locks") == ai.get("shun_he_locks"), "human/AI pass lock parity %s/%s/%s/%s" % [rotation, seat, reaction_type, can_hu])
					_check(ai.get("shun_he_locks").has(seat) == can_hu, "lock only when Hu offered")
					if can_hu:
						var offered: Array[Dictionary] = [{"seat": seat, "can_hu": true, "can_peng": false, "can_gang": false}]
						ai.set("pending_reactions", offered)
						ai.call("_apply_shun_he_lock_filter")
						_check(ai.get("pending_reactions").is_empty(), "same fan unavailable after AI pass")
						ai.get("players")[seat]["is_ai"] = false
						ai.set("current_turn_seat", seat)
						var wall: Array[Dictionary] = [_tile(100, (rotation + 1) % 3, 9)]
						ai.set("wall", wall)
						ai.set("wall_count", 1)
						ai.call("_begin_turn")
						_check(not ai.get("shun_he_locks").has(seat), "own draw releases AI lock")
					human.free()
					ai.free()
	print("AI_PASS_LOCK ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _tile(id: int, suit: int, rank: int) -> Dictionary:
	return {"id": id, "suit": ["tiao", "tong", "wan"][suit], "rank": rank, "sort_key": suit * 100 + rank, "display_name": str(rank)}

func _fixture(rotation: int, seat: int, reaction_type: String, can_hu: bool) -> Node:
	var game: Node = GAME.new()
	game.set("rules", load("res://scripts/core/rule_config.gd").new())
	game.set("mahjong_state", load("res://scripts/core/mahjong_state.gd").new())
	game.set("score_resolver", load("res://scripts/core/score_resolver.gd").new())
	game.set("mahjong_judge", load("res://scripts/core/mahjong_judge.gd").new())
	game.set("hu_checker", load("res://scripts/core/hu_checker.gd").new())
	game.set("_rng", RandomNumberGenerator.new())
	var players: Array[Dictionary] = []
	for s in range(4):
		var hand: Array[Dictionary] = []
		if s == seat:
			for rank in [2,3,4,2,3,4,5,5]:
				hand.append(_tile(hand.size(), (rotation + 1) % 3, rank))
			for rank in [5,6,7,1,2]:
				hand.append(_tile(hand.size(), (rotation + 2) % 3, rank))
		players.append({"seat": s, "nickname": str(s), "score": 1000, "is_ai": true, "hand_tiles": hand, "hand_count": hand.size(), "melds": [], "discards": [], "ding_que": ["tiao","tong","wan"][rotation], "has_won": false})
	game.set("players", players)
	game.set("current_phase", 6)
	game.set("current_discard_context", {"source_seat": (seat + 3) % 4, "tile": _tile(30, (rotation + 2) % 3, 3), "reaction_type": reaction_type})
	# Retain another candidate so neither pass advances/settles this synthetic component fixture.
	var candidates: Array[Dictionary] = [{"seat": seat, "can_hu": can_hu, "can_peng": false, "can_gang": false}, {"seat": (seat + 1) % 4, "can_hu": false, "can_peng": true, "can_gang": false}]
	game.set("pending_reactions", candidates)
	return game
