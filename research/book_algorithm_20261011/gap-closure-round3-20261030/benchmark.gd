extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

var last_debug_turn:Dictionary={}

func _step(game:Node)->bool:
 if OS.get_cmdline_user_args().has("--debug-turns") and int(game.get("current_phase"))==5:
  if not game.is_ai_turn_ready():return false
  game._pump_ai_background_requests()
  var d:Dictionary=game._get_or_prepare_ai_turn_decision()
  last_debug_turn=d.duplicate(true)
  if d.is_empty():return false
  game.pending_ai_turn_decision.clear();game._clear_pending_ai_turn_request()
  return game._execute_ai_turn_decision(d)
 return super._step(game)

# One identical baseline game supplies four seat references for each deal.
# Four current-policy games then change exactly one controlled seat each.
func _run()->void:
 var folder:="res://research/book_algorithm_20261011/gap-closure-round3-20261030/"
 var output:=_read_string_arg("--output=",folder+"benchmark-final.json")
 var only_seed:=_read_int_arg("--only-seed=",-1)
 var only_control:=int(_read_string_arg("--only-control=","-2"))
 var complete:Array=[];var observations:Array=[];var done:Dictionary={};var deals:Dictionary={}
 if FileAccess.file_exists(output):
  var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output))
  if prior.has("failure"):push_error("preserve failed benchmark before resuming");quit(1);return
  complete=prior.get("complete_games",[]);observations=prior.get("observations",[])
  for r in complete:done[str(r["seed"])+":"+str(r["controlled"])]=true;deals[str(r["seed"])]=r["deal_sha256"]
 for deal in range(32):
  var seed:int=92611031+deal*1009
  if only_seed>=0 and seed!=only_seed:continue
  for controlled in [-1,0,1,2,3]:
   if only_control>=-1 and controlled!=only_control:continue
   var key:=str(seed)+":"+str(controlled)
   if done.has(key):continue
   var game:Node=GAME_STATE_SCRIPT.new();root.add_child(game);await process_frame
   game.set("ai_agent_generation",150000+deal*8+controlled+1);game.call("set_test_seed",seed);game.call("set_ai_preset","bone_ash")
   var policies:Dictionary={}
   for seat in range(4):policies[seat]="current" if seat==controlled else "cash_cost_before_v1"
   game.set("test_ai_policy_variants_by_seat",policies);game.call("start_new_round");_prepare_all_ai_table(game);game.get("ai_manager").set_native_async_enabled(false)
   var digest:="";var latencies:Array=[]
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
     if controlled==-1:deals[str(seed)]=digest
     elif str(deals.get(str(seed),""))!=digest:push_error("unpaired initial deal");quit(1);return
    var actor:int=int(game.get("current_turn_seat"))
    var is_controlled:bool=phase==5 and actor==controlled
    if phase==6:is_controlled=int(game.call("_get_next_ai_reaction_candidate").get("seat",-1))==controlled
    if phase==5 and int(game.get("wall_count"))%4==0 and (is_controlled or controlled==-1):
     var manager=game.get("ai_manager")
     var payload:Dictionary=manager.csharp_bridge.build_discard_transport_payload(game.call("_build_player_state",actor),game.call("_build_table_state"),game.get("rules"))
     var prediction:String=str(manager.native_csharp_runtime.call("DiagnosePublicReadinessV2Compact",JSON.stringify(payload)))
     for line in prediction.split(";",false):
      var v:=line.split(",")
      if v.size()!=12:push_error("V2 diagnostic field mismatch");quit(1);return
      var features:Array=[float(v[1])]
      for i in range(3,12):features.append(float(v[i]))
      var other:Dictionary=game.call("_build_player_state",int(v[0]))
      var waits:Array=game.get("mahjong_judge").get_ting_tiles(other,game.get("rules"))
      observations.append({"seed":seed,"observer_policy":policies[actor],"features":features,"actual":float(v[2]),"truth":0 if waits.is_empty() else 1,"prediction_before_label":true})
    var start:=Time.get_ticks_usec();var ok:=_step(game)
    if is_controlled:latencies.append((Time.get_ticks_usec()-start)/1000.0)
    if not ok or not _physical_integrity(game)["passed"]:
     _write_report({"complete_games":complete,"observations":observations,"failure":{"key":key,"step":step,"phase":phase,"message":game.get("debug_last_message"),"native_turn":game.get("ai_manager").last_native_turn_error,"native_reaction":game.get("ai_manager").last_native_reaction_error,"turn_snapshot":game.get("ai_manager").latest_turn_snapshot,"debug_decision":last_debug_turn,"public_views":game.call("_agent_views")}},output)
     quit(1);return
    await process_frame
   if int(game.get("current_phase"))!=7:push_error("incomplete strength evaluation");quit(1);return
   var result:=_extract_round_result(game,deal,0,false)
   if _net_sum(result["score_changes"])!=0:push_error("unbalanced benchmark ledger");quit(1);return
   complete.append({"seed":seed,"controlled":controlled,"scores":result["score_changes"],"fully_settled":true,"physical_conservation":true,"deal_sha256":digest,"decision_ms":latencies})
   game.call("abort_agent_round");game.queue_free();await process_frame
   _write_report({"complete_games":complete,"observations":observations},output)
   print("BENCHMARK ",key," games=",complete.size())
 quit(0)
