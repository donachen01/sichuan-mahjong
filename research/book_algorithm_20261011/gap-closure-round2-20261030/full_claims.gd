extends "res://research/book_algorithm_20261011/gap-closure-20261030/verify_game.gd"

# The two root prefixes are declared counterfactual actions, not falsely
# claimed native recommendations. Every subsequent action is real signed AI.
func _run()->void:
 await process_frame
 var folder:="res://research/book_algorithm_20261011/gap-closure-round2-20261030/"
 var n:=8
 var tag:=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--worlds="):n=int(a.trim_prefix("--worlds="))
  if a.begins_with("--output-tag="):tag=a.trim_prefix("--output-tag=")+"-"
 var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"precision/worlds-%d.json"%n))
 var path:=folder+"full-claims-"+tag+"%d.json"%n
 var complete:Array=[];var done:Dictionary={}
 if FileAccess.file_exists(path):
  var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  if not prior.get("failures",[]).is_empty():push_error("prior failed study must be preserved separately");quit(1);return
  complete=prior.get("rows",[])
  for row in complete:done[str(row["id"])+"/"+str(row["root"])]=true
 var native=root.get_node("SichuanCSharpRuntime")
 for world in input["rows"]:
  for action in ["pass","peng"]:
   var key:String=str(world["id"])+"/"+action
   if done.has(key):continue
   serial+=1
   var s=_fixture(world["fixture"],1,native,false)
   for player in s.players:player["is_ai"]=true;player["ai_level"]=s.ai_level
   var pool:Array=s.wall.duplicate();var ordered:Array[Dictionary]=[]
   for tile in world["fixture"]["wall_order"]:ordered.append(_take(pool,int(tile)))
   _check(pool.is_empty(),key+" physical public world allocation")
   s.wall=ordered;s.wall_count=ordered.size()
   _check(s._begin_round_agents(),key+" real native brains")
   var played:bool=s._pass_ai_reaction(1) if action=="pass" else s._execute_peng(1)
   _check(played,key+" legal declared counterfactual root")
   if action=="peng" and played:
    s.pending_ai_turn_decision.clear();s._clear_pending_ai_turn_request()
    var tile:Dictionary=s._find_hand_tile_by_tile_type(1,int(world["pengDiscard"]))
    _check(not tile.is_empty(),key+" priced first discard owned")
    _check(s._discard_tile_internal(1,int(tile.get("id",-1))),key+" declared priced first discard")
   var steps:=0
   var trace:Array=[]
   for i in range(400):
    if int(s.current_phase)==7:break
    var phase:int=int(s.current_phase);var ok:=false
    if phase==5:ok=s.run_ai_turn()
    elif phase==6:
     if s.is_ai_reaction_pending():ok=s.run_ai_reaction()
     else:s._finalize_reaction_without_claim();ok=true
    _check(ok,key+" actual continuation "+s.debug_last_message)
    _physical_with_winning_tile(s,key+" step"+str(i))
    if not failures.is_empty():break
    trace.append({"phase":phase,"wall":s.wall_count,"turn":s.current_turn_seat})
    steps+=1;await process_frame
   _check(int(s.current_phase)==7,key+" complete terminal settlement")
   var changes:Dictionary=s.settlement_data.get("score_changes",{})
   var net:=0
   for v in changes.values():net+=int(v)
   _check(net==0,key+" zero-sum ledger")
   complete.append({"id":world["id"],"source":world["source"],"root":action,"weight":world["weight"],"first_discard":world["pengDiscard"] if action=="peng" else -1,"steps":steps,"scores":changes,"fully_settled":int(s.current_phase)==7,"trace":trace})
   s._end_round_agents();s.free()
   var out=FileAccess.open(path,FileAccess.WRITE);out.store_string(JSON.stringify({"rows":complete,"failures":failures,"scope":"paired public hypotheses, declared root claim/first discard; all later actions actual native policy"}));out.close()
   print("FULL_CLAIM ",key," complete=",complete.size()," failures=",failures.size())
   if not failures.is_empty():quit(1);return
 quit(0)
