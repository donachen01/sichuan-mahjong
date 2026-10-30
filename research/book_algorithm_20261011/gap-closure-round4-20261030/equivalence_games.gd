extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

func _run()->void:
 var folder:="res://research/book_algorithm_20261011/gap-closure-round4-20261030/"
 var label:=_read_string_arg("--label=","before");var games:Array=[];var failed:Dictionary={}
 var identity:String=str(root.get_node("SichuanCSharpRuntime").call("PolicyCoreIdentityDiagnostic"))
 for d in range(8):
  var seed:int=112611031+1009*d
  var game:Node=GAME_STATE_SCRIPT.new();root.add_child(game);await process_frame
  game.set("ai_agent_generation",200000+d);game.call("set_test_seed",seed);game.call("set_ai_preset","bone_ash")
  game.call("start_new_round");_prepare_all_ai_table(game);game.get("ai_manager").set_native_async_enabled(false)
  var trace:Array=[];var digest:=""
  for step in range(1500):
   var phase:int=int(game.get("current_phase"))
   if phase==7:break
   if digest.is_empty() and phase==5:
    var hands:Array=[];var wall:Array=[]
    for player in game.get("players"):
     var h:Array=[]
     for tile in player["hand_tiles"]:h.append(int(game.call("_sichuan_tile_type",tile)))
     h.sort();hands.append(h)
    for tile in game.get("wall"):wall.append(int(game.call("_sichuan_tile_type",tile)))
    digest=JSON.stringify({"hands":hands,"wall":wall}).sha256_text()
   var actor:int=int(game.get("current_turn_seat"))
   if phase==6:actor=int(game.call("_get_next_ai_reaction_candidate").get("seat",actor))
   var started:=Time.get_ticks_usec();var ok:=_step(game);var ms:float=(Time.get_ticks_usec()-started)/1000.0
   if not ok or not _physical_integrity(game)["passed"]:
    failed={"seed":seed,"step":step,"phase":phase,"message":game.get("debug_last_message")};break
   trace.append({"phase":phase,"actor":actor,"wall_after":game.get("wall_count"),"event_sha256":JSON.stringify(game.get("ai_public_events")).sha256_text(),"ms":ms})
   await process_frame
  var result:=_extract_round_result(game,d,0,false)
  if int(game.get("current_phase"))!=7 or _net_sum(result["score_changes"])!=0:failed["incomplete_or_unbalanced"]=seed
  games.append({"seed":seed,"deal_sha256":digest,"trace":trace,"scores":result["score_changes"],"fully_settled":int(game.get("current_phase"))==7})
  game.call("abort_agent_round");game.queue_free();await process_frame
  _write_report({"core_identity":identity,"games":games,"failure":failed,"scope":"Eight fresh same-policy natural deals for exact behavior equivalence/performance; not a strength comparison or new default checklist."},folder+"equivalence-"+label+".json")
  print("EQUIVALENCE ",label," games=",games.size()," failure=",not failed.is_empty())
  if not failed.is_empty():quit(1);return
 quit(0)
