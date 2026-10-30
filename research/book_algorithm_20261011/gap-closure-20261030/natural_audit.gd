extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Task-local experiment. Seeds and metrics declared before results. Labels
# are observed after prediction and never enter a policy's public payload.
func _run()->void:
 var output:=_read_string_arg("--output=","")
 var deals:=_read_int_arg("--rounds=",8)
 var variants:Array=["pre_learning_closure_v1","current"]
 var complete:Array=[]
 var calibration:Array=[]
 var path:=output+".checkpoint.json"
 var done:Dictionary={}
 if FileAccess.file_exists(path):
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  complete=saved.get("complete_games",[]);calibration=saved.get("readiness",[])
  for r in complete:done[str(r["seed"])+":"+str(r["seat"])+":"+str(r["variant"])]=true
 for deal in range(deals):
  for seat in range(4):
   for variant in variants:
    var seed:int=31561031+deal*1009
    var key:=str(seed)+":"+str(seat)+":"+str(variant)
    if done.has(key):continue
    var game:Node=GAME_STATE_SCRIPT.new();root.add_child(game);await process_frame
    game.set("ai_agent_generation",90000+deal*16+seat*2+variants.find(variant))
    game.call("set_test_seed",seed);game.call("set_ai_preset","bone_ash")
    var policies:Dictionary={}
    for other in range(4):policies[other]=variant if other==seat else "pre_learning_closure_v1"
    game.set("test_ai_policy_variants_by_seat",policies)
    game.call("start_new_round");_prepare_all_ai_table(game)
    game.get("ai_manager").set_native_async_enabled(false)
    var timings:Array=[]
    for step in range(1500):
     var phase:int=int(game.get("current_phase"))
     if phase==7:break
     var controlled:bool=phase==5 and int(game.get("current_turn_seat"))==seat
     if phase==6:controlled=int(game.call("_get_next_ai_reaction_candidate").get("seat",-1))==seat
     if phase==5 and controlled and int(game.get("wall_count"))%4==0:
      var manager=game.get("ai_manager")
      var payload:Dictionary=manager.csharp_bridge.build_discard_transport_payload(game.call("_build_player_state",seat),game.call("_build_table_state"),game.get("rules"))
      var prediction:String=str(manager.native_csharp_runtime.call("DiagnosePublicReadinessCompact",JSON.stringify(payload)))
      for line in prediction.split(";",false):
       var values:=line.split(",")
       if values.size()!=11:push_error("invalid calibration output");quit(1);return
       var other:=int(values[0]);var player:Dictionary=game.call("_build_player_state",other)
       var waits:Array=game.get("mahjong_judge").get_ting_tiles(player,game.get("rules"))
       calibration.append({"seed":seed,"observer":seat,"variant":variant,"wall":game.get("wall_count"),"seat":other,"prediction":float(values[1]),"truth":0 if waits.is_empty() else 1,"prediction_before_label":true})
     var start:=Time.get_ticks_usec()
     var ok:=_step(game)
     if controlled:timings.append((Time.get_ticks_usec()-start)/1000.0)
     if not ok or not _physical_integrity(game)["passed"]:
      _write_report({"complete_games":complete,"readiness":calibration,"failure":{"key":key,"step":step,"phase":phase,"message":game.get("debug_last_message"),"physical":_physical_integrity(game),"agents":game.get("ai_agents_started")}},output)
      quit(1);return
     await process_frame
    if int(game.get("current_phase"))!=7:push_error("incomplete natural game");quit(1);return
    var result:=_extract_round_result(game,deal,0,false)
    var scores:Dictionary=result["score_changes"]
    if _net_sum(scores)!=0:push_error("unbalanced natural settlement");quit(1);return
    complete.append({"seed":seed,"seat":seat,"variant":variant,"scores":scores,"fully_settled":true,"physical_conservation":true,"decision_ms":timings})
    game.call("abort_agent_round");game.queue_free();await process_frame
    _write_report({"complete_games":complete,"readiness":calibration},path)
    print("NATURAL ",key," completed=",complete.size())
 _write_report({"complete_games":complete,"readiness":calibration,"scope":"paired held-out seed pilot, clustered by deal; current policy sees own hand and public state only"},output)
 quit(0)
