extends "res://research/book_algorithm_20261011/gap-closure-20261030/verify_game.gd"

func _arg(prefix:String,fallback:String)->String:
 for a in OS.get_cmdline_user_args():
  if a.begins_with(prefix):return a.trim_prefix(prefix)
 return fallback

func _live_step(s)->bool:
 if int(s.current_phase)==5:return s.run_ai_turn()
 if int(s.current_phase)==6:
  if s.is_ai_reaction_pending():return s.run_ai_reaction()
  s._finalize_reaction_after_hu_or_pass();return true
 return false

func _run()->void:
 await process_frame
 var folder:="res://research/book_algorithm_20261011/gap-closure-round3-20261030/"
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"claim-worlds.json"))
 var output:=_arg("--output=",folder+"full-claims.json");var completed:Array=[];var done:Dictionary={}
 if FileAccess.file_exists(output):
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output))
  if not saved.get("failures",[]).is_empty():push_error("Preserve failed claim study");quit(1);return
  completed=saved.get("rows",[])
  for r in completed:done[str(r["id"])+"/"+str(r["root"])]=true
 var native=root.get_node("SichuanCSharpRuntime")
 for world in data["rows"]:
  if not _arg("--only-id=","").is_empty() and str(world["id"])!=_arg("--only-id=",""):continue
  for intended in ["pass","peng"]:
   if not _arg("--only-action=","").is_empty() and intended!=_arg("--only-action=",""):continue
   var key:String=str(world["id"])+"/"+intended
   if done.has(key):continue
   serial+=1
   var s=_fixture(world["fixture"],1,native,false)
   for p in s.players:p["is_ai"]=true;p["ai_level"]=s.ai_level
   var pool:Array=s.wall.duplicate();var ordered:Array[Dictionary]=[]
   for tile in world["fixture"]["wall_order"]:ordered.append(_take(pool,int(tile)))
   _check(pool.is_empty(),key+" allocation complete");s.wall=ordered;s.wall_count=ordered.size()
   _physical_with_winning_tile(s,key+" initial state")
   # Restore ALL actual root candidates; no rival is silently forced to Pass.
   var offer:Dictionary=s.players[0]["discards"][-1]
   var root_tile_id:int=int(offer["id"])
   s._prepare_reaction_context(0,offer)
   _check(s._begin_round_agents(),key+" current native brains")
   var applied:=false;var root_trace:Array=[]
   for j in range(16):
    if int(s.current_phase)!=6 or int(s.current_discard_context.get("tile",{}).get("id",-1))!=root_tile_id:break
    var candidate:Dictionary=s._get_next_ai_reaction_candidate()
    var actor:int=int(candidate.get("seat",-1))
    root_trace.append({"actor":actor,"can_hu":candidate.get("can_hu",false),"can_peng":candidate.get("can_peng",false),"can_gang":candidate.get("can_gang",false)})
    if actor==1:
     _check(bool(candidate.get("can_peng",false)),key+" own legal root candidate")
     applied=true
     if intended=="pass":_check(s._pass_ai_reaction(1),key+" declared legal Pass")
     else:
      _check(s._execute_peng(1),key+" declared legal Peng")
      s.pending_ai_turn_decision.clear();s._clear_pending_ai_turn_request()
      var tile:Dictionary=s._find_hand_tile_by_tile_type(1,int(world["pengDiscard"]))
      _check(not tile.is_empty(),key+" public-priced first discard owned")
      _check(s._discard_tile_internal(1,int(tile.get("id",-1))),key+" declared first discard")
     break
    _check(_live_step(s),key+" actual rival root response "+s.debug_last_message)
    _physical_with_winning_tile(s,key+" root"+str(j))
    if not failures.is_empty():break
   _check(applied or int(s.current_phase)!=6 or int(s.current_discard_context.get("tile",{}).get("id",-1))!=root_tile_id,key+" root intervention resolved or legally preempted")
   var trace:Array=[];var steps:=0
   for step in range(500):
    if int(s.current_phase)==7:break
    var phase:int=int(s.current_phase)
    _check(_live_step(s),key+" actual continuation "+s.debug_last_message)
    _physical_with_winning_tile(s,key+" step"+str(step))
    if not failures.is_empty():break
    trace.append({"phase":phase,"wall":s.wall_count,"turn":s.current_turn_seat});steps+=1;await process_frame
   _check(int(s.current_phase)==7,key+" fully settled")
   var scores:Dictionary=s.settlement_data.get("score_changes",{});var net:=0
   for v in scores.values():net+=int(v)
   _check(net==0,key+" balanced ledger")
   completed.append({"id":world["id"],"source":world["source"],"pool":world["pool"],"pool_ess":world["pool_ess"],"selected_index":world["selected_index"],"weight":world["weight"],"root":intended,"root_applied":applied,"first_discard":world["pengDiscard"] if applied and intended=="peng" else -1,"root_trace":root_trace,"scores":scores,"fully_settled":int(s.current_phase)==7,"steps":steps,"trace":trace,"deferred_count":int(s.ai_decision_metrics.get("reaction_deferred",0))})
   s._end_round_agents();s.free()
   if completed.size()%4==0 or not failures.is_empty():
    var out=FileAccess.open(output,FileAccess.WRITE);out.store_string(JSON.stringify({"rows":completed,"failures":failures,"pools":data["pools"]}));out.close()
   print("JOINT_CLAIM games=",completed.size()," applied=",applied," failures=",failures.size())
   if not failures.is_empty():quit(1);return
 var final_out=FileAccess.open(output,FileAccess.WRITE);final_out.store_string(JSON.stringify({"rows":completed,"failures":failures,"pools":data["pools"]}));final_out.close()
 quit(0)
