extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

# Prediction must return before reading the other seat's hidden label.
func _run()->void:
 var part:=_read_string_arg("--split=","train")
 var specs:Dictionary={"train":[32,42611031],"validation":[8,52611031],"holdout":[24,62611031]}
 if not specs.has(part):quit(2);return
 var output:=_read_string_arg("--output=","")
 if output.is_empty():quit(2);return
 var complete:Array=[];var observations:Array=[];var seen:Dictionary={}
 var checkpoint:=output+".checkpoint.json"
 if FileAccess.file_exists(checkpoint):
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
  complete=saved.get("complete_games",[]);observations=saved.get("observations",[])
  for r in complete:seen[int(r["seed"])]=true
 for deal in range(int(specs[part][0])):
  var seed:int=int(specs[part][1])+deal*1009
  if seen.has(seed):continue
  var policy:String="current" if deal%2==0 else "pre_learning_closure_v1"
  var game:Node=GAME_STATE_SCRIPT.new();root.add_child(game);await process_frame
  game.set("ai_agent_generation",120000+deal);game.call("set_test_seed",seed);game.call("set_ai_preset","bone_ash")
  game.set("test_ai_policy_variants_by_seat",{0:policy,1:policy,2:policy,3:policy})
  game.call("start_new_round");_prepare_all_ai_table(game);game.get("ai_manager").set_native_async_enabled(false)
  for step in range(1500):
   var phase:int=int(game.get("current_phase"))
   if phase==7:break
   if phase==5 and int(game.get("wall_count"))%2==0:
    var actor:int=int(game.get("current_turn_seat"));var manager=game.get("ai_manager")
    var payload:Dictionary=manager.csharp_bridge.build_discard_transport_payload(game.call("_build_player_state",actor),game.call("_build_table_state"),game.get("rules"))
    var raw:String=str(manager.native_csharp_runtime.call("DiagnosePublicReadinessV2Compact",JSON.stringify(payload)))
    for line in raw.split(";",false):
     var v:=line.split(",")
     if v.size()!=12:push_error("readiness V2 requires 12 fields");quit(1);return
     var seat:=int(v[0]);var features:Array=[float(v[1])]
     for i in range(3,12):features.append(float(v[i]))
     var other:Dictionary=game.call("_build_player_state",seat)
     var waits:Array=game.get("mahjong_judge").get_ting_tiles(other,game.get("rules"))
     observations.append({"seed":seed,"policy":policy,"observer":actor,"seat":seat,"step":step,"features":features,"actual_deployed_probability":float(v[2]),"truth":0 if waits.is_empty() else 1,"prediction_before_label":true})
   if not _step(game) or not _physical_integrity(game)["passed"]:
    _write_report({"failure":{"seed":seed,"step":step,"phase":phase,"message":game.get("debug_last_message"),"native_error":game.get("ai_manager").last_native_reaction_error,"candidate":game.call("_get_next_ai_reaction_candidate"),"public_views":game.call("_agent_views")},"complete_games":complete,"observations":observations},output)
    quit(1);return
   await process_frame
  if int(game.get("current_phase"))!=7:push_error("incomplete calibration game");quit(1);return
  var result:=_extract_round_result(game,deal,0,false)
  if _net_sum(result["score_changes"])!=0:push_error("unbalanced calibration game");quit(1);return
  complete.append({"seed":seed,"policy":policy,"fully_settled":true,"scores":result["score_changes"],"physical_conservation":true})
  game.call("abort_agent_round");game.queue_free();await process_frame
  _write_report({"split":part,"complete_games":complete,"observations":observations},checkpoint)
  print("CALIBRATION ",part," seed=",seed," games=",complete.size()," observations=",observations.size())
 _write_report({"split":part,"complete_games":complete,"observations":observations,"diagnostic_version":2,"hidden_labels_not_policy_inputs":true},output)
 quit(0)
