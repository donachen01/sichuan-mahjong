extends SceneTree

const TileCodecScript := preload("res://scripts/ai/sichuan_tile_codec.gd")


func _initialize() -> void:
	var codec = TileCodecScript.new()
	var suits := ["tiao", "tong", "wan"]
	var shared_discard := {"id": 60, "suit": "tiao", "rank": 1}
	var self_draw := {"id": 61, "suit": "tong", "rank": 2}
	var own_pair := {"id": 62, "suit": "wan", "rank": 9}
	var players := [
		{"seat": 0, "discards": [], "melds": []},
		{"seat": 1, "discards": [], "melds": [], "winning_tile": shared_discard, "winning_source_seat": 0},
		{"seat": 2, "discards": [], "melds": [], "winning_tile": shared_discard, "winning_source_seat": 0},
		{"seat": 3, "discards": [], "melds": [], "winning_tile": self_draw, "winning_source_seat": 0, "win_type": "dian_gang_hua"},
	]
	var hand := [own_pair, own_pair]
	var public_counts: PackedInt32Array = codec.build_visible_count_array(players, [], suits, 0)
	var remaining: PackedInt32Array = codec.build_remaining_count_array(hand, players, suits, 0)
	var hand_counts: PackedInt32Array = codec.build_count_array(hand, suits)
	var errors := []
	if int(public_counts[0]) != 1:
		errors.append("multi-Hu counted one physical discard more than once")
	if int(public_counts[10]) != 0:
		errors.append("self-draw winning tile counted twice with concealed hand")
	if int(public_counts[26]) != 0 or int(remaining[26]) != 2:
		errors.append("own hand leaked into public counts or was not removed from hidden pool")
	for tile in range(27):
		if int(hand_counts[tile]) + int(public_counts[tile]) + int(remaining[tile]) != 4:
			errors.append("four-copy conservation failed at tile %d" % tile)
	for failure in errors:
		printerr(failure)
	print("AI_TILE_ACCOUNTING_CHECKS failures=%d" % errors.size())
	quit(0 if errors.is_empty() else 1)
