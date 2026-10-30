extends "res://tests/current/SichuanActualActionBranchesRunner.gd"

func _numbers(raw:String)->Array:
 var a:Array=[]
 for x in raw.split(",",false):a.append(float(x))
 return a

func _run()->void:
 var folder:="res://research/book_algorithm_20261011/gap-closure-round3-20261030/"
 var output:=folder+"forecast-holdout.json"
 var completed:Array=[];var observations:Array=[];var seen:Dictionary={}
 if FileAccess.file_exists(output):
  var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output))
  if prior.has("failure"):push_error("Preserve failed cohort before restart");quit(1);return
  completed=prior.get("complete_games",[]);observations=prior.get("observations",[])
  for r in completed:seen[int(r["seed"])]=true
 for deal in range(48):
  var seed:int=82611031+deal*1009
  if seen.has(seed):continue
  var game:Node=GAME_STATE_SCRIPT.new();root.add_child(game);await process_frame
  game.set("ai_agent_generation",180000+deal);game.call("set_test_seed",seed);game.call("set_ai_preset","bone_ash")
  game.call("start_new_round");_prepare_all_ai_table(game);game.get("ai_manager").set_native_async_enabled(false)
  var predicted:=false;var threshold:=36 if deal<24 else 20
  for step in range(1500):
   var phase:int=int(game.get("current_phase"))
   if phase==7:break
   if not predicted and phase==5 and int(game.get("wall_count"))<=threshold:
    var actor:int=int(game.get("current_turn_seat"));var manager=game.get("ai_manager")
    var payload:Dictionary=manager.csharp_bridge.build_discard_transport_payload(game.call("_build_player_state",actor),game.call("_build_table_state"),game.get("rules"))
    var start:=Time.get_ticks_usec()
    var result:String=str(manager.native_csharp_runtime.call("DiagnoseJointReadinessCompact",JSON.stringify(payload),4096,20261221+deal*7919))
    var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
    var fields:=result.split("|",true)
    if fields.size()!=12:push_error("joint diagnostic contract mismatch: "+result.left(160));quit(1);return
    var row:Dictionary={"seed":seed,"actor":actor,"wall":int(game.get("wall_count")),"status":fields[0],"samples":int(fields[1]),"prior_ess":float(fields[2]),"ess":float(fields[3]),"residual":float(fields[4]),"target":_numbers(fields[5]),"prior_ready":_numbers(fields[6]),"ready":_numbers(fields[7]),"prior_wall":_numbers(fields[8]),"wall_copies":_numbers(fields[9]),"prior_presence":_numbers(fields[10]),"presence":_numbers(fields[11]),"ms":elapsed,"predictions_before_labels":true}
    # Read hidden evaluation labels only AFTER the public forecast returns.
    var truth_wall:Array=[];truth_wall.resize(27);truth_wall.fill(0)
    for tile in game.get("wall"):truth_wall[int(game.call("_sichuan_tile_type",tile))]+=1
    var truth_ready:Array=[];var active:Array=[]
    for seat in range(4):
     var p:Dictionary=game.call("_build_player_state",seat)
     var eligible:bool=seat!=actor and not bool(game.get("players")[seat].get("has_won",false))
     active.append(eligible)
     var waits:Array=game.get("mahjong_judge").get_ting_tiles(p,game.get("rules")) if eligible else []
     truth_ready.append(0 if waits.is_empty() else 1)
    row["truth_wall"]=truth_wall;row["truth_ready"]=truth_ready;row["eligible"]=active
    observations.append(row);predicted=true
   if not _step(game) or not _physical_integrity(game)["passed"]:
    _write_report({"complete_games":completed,"observations":observations,"failure":{"seed":seed,"step":step,"phase":phase,"message":game.get("debug_last_message"),"turn_error":game.get("ai_manager").last_native_turn_error,"reaction_error":game.get("ai_manager").last_native_reaction_error}},output)
    quit(1);return
   await process_frame
  if int(game.get("current_phase"))!=7:push_error("incomplete forecast game");quit(1);return
  var settled:=_extract_round_result(game,deal,0,false)
  if _net_sum(settled["score_changes"])!=0:push_error("unbalanced forecast game");quit(1);return
  completed.append({"seed":seed,"predicted":predicted,"fully_settled":true,"physical_conservation":true,"scores":settled["score_changes"]})
  game.call("abort_agent_round");game.queue_free();await process_frame
  _write_report({"complete_games":completed,"observations":observations},output)
  print("FORECAST games=",completed.size()," observations=",observations.size())
 quit(0)
