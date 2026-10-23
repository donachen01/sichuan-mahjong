extends "res://research/hand_review_20261019/shared_execution_audit/paths_check.gd"
const DEST="res://research/book_algorithm_20261011/lower-completion-20261023/"

func _run()->void:
 await process_frame
 var native=root.get_node("SichuanCSharpRuntime")
 var fixtures:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"final-all-fixtures.json"))
 var matrix:bool=OS.get_cmdline_user_args().has("--matrix")
 var prefix:String="matrix" if matrix else "execution"
 var comparisons:Dictionary={}
 var selected:Array=[]
 for id in fixtures:
  if not matrix or id in ["lower-36-5-13-base-B","lower-38-6-intro-nine_gates-declared-draw","lower-41-6-5-A","lower-44-6-6-B","lower-47-6-9-base","lower-50-6-13-D","lower-55-6-17-B","lower-67-6-19-B","lower-69-6-21-B-offer-m3","lower-72-6-24-A-offer-p3","lower-78-7-1-base","lower-85-7-6-base-offer-p9"]:selected.append(id)
 for compact in ([false,true] if matrix else [false]):
  for own in ([1,2,3] if matrix else [1]):
   for id in selected:
    serial+=1
    var s=_fixture(fixtures[id],own,native,compact)
    var reaction:bool=int(fixtures[id].get("offered",-1))>=0
    var label:String=str(id)+"/seat"+str(own)+"/compact"+str(compact)
    _physical_with_winning_tile(s,label+" before")
    _check(s._begin_round_agents(),label+" initialize independent brains")
    var start:int=Time.get_ticks_usec()
    var prepared:Dictionary=s._build_ai_reaction_decision() if reaction else s._build_ai_turn_decision()
    var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
    var analysis:Dictionary=prepared.get("decision",{}) if reaction else prepared.get("analysis",{})
    var command:Dictionary=analysis.get("decision_command",{})
    var action:String=str(analysis.get("action","")) if reaction else str(prepared.get("action",""))
    _check(not command.is_empty(),label+" final command exists "+s.debug_last_message)
    _check(s._valid_ai_command(analysis,own,"reaction" if reaction else "turn",s._build_player_state(own),s._build_table_state()),label+" signed latest-view command")
    if reaction:s.pending_ai_reaction_decision=prepared
    else:s.pending_ai_turn_decision=prepared
    var executed:bool=s.run_ai_reaction() if reaction else s.run_ai_turn()
    _check(executed,label+" real action executes: "+s.debug_last_message)
    if action=="discard" and executed:
     _check(s._sichuan_tile_type(s.players[own]["discards"][-1])==int(command.get("tile",-2)),label+" exact signed discard")
    if action=="peng" and executed:
     var child:Dictionary=s.pending_ai_turn_decision.get("analysis",{}).get("decision_command",{})
     _check(child.get("parentId")==command.get("id"),label+" priced Peng child preserved")
     _check(s.run_ai_turn(),label+" child executes")
     _check(s._sichuan_tile_type(s.players[own]["discards"][-1])==int(command.get("continuationTile",-1)),label+" priced Peng first discard matches")
    if action in ["an_gang","add_gang","gang"] and executed:
     _check(s.last_turn_context.get("draw_reason")=="gang_draw",label+" real replacement draw")
     _check(s.run_ai_turn(),label+" replacement action executes")
    if action in ["hu","self_hu"] and executed:
     _check(s.players[own].get("has_won",false),label+" real Hu settlement")
    _physical_with_winning_tile(s,label+" after")
    var key:String=str(id)+"/"+str(own)
    var picked:String=action+"/"+str(command.get("tile",-1))+"/"+str(command.get("continuationTile",-1))
    if compact:_check(comparisons.get(key)==picked,label+" ordinary/compact agree")
    else:comparisons[key]=picked
    rows.append({"id":label,"source":id,"seat":own,"compact":compact,"action":action,"executed":executed,"ms":elapsed,"command":command,"reasons":analysis.get("reasons",[])})
    print("LOWER_EXEC ",label," action=",action," ms=",snapped(elapsed,.1)," failures=",failures.size())
    s._end_round_agents();s.free()
 var f=FileAccess.open(DEST+prefix+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"rows":rows,"failures":failures,"scope":"physical controlled backgrounds; real C# seat authority and GameState; compact desktop transport is not device NativeAOT"},"  "))
 print("LOWER_EXECUTION rows=",rows.size()," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)

func _fixture(f:Dictionary,own:int,native,compact:bool):
 var s=_state(native,compact,false)
 s.players.clear();s.discard_pile.clear();s.ai_public_events.clear();s.ai_public_event_version=0
 s.ai_agent_generation=serial;s.current_dealer_seat=own
 s.ai_manager=ManagerScript.new();s.ai_manager.native_csharp_runtime=native
 s.ai_manager.force_mobile_aot_runtime_for_tests=compact;s.ai_manager.set_native_async_enabled(false)
 s.ai_manager.ai_reaction_analysis_ready.connect(s._on_ai_reaction_analysis_ready)
 s.ai_manager.ai_turn_analysis_ready.connect(s._on_ai_turn_analysis_ready)
 var pool:Array[Dictionary]=[]
 for t in range(27):
  for copy in range(4):pool.append({"id":t*4+copy,"suit":["tiao","tong","wan"][t/9],"rank":t%9+1,"sort_key":t,"display_name":str(t)})
 var view:Dictionary=f["state"]
 for original in range(4):
  var seat:int=(original+own-1+4)%4
  var p:Dictionary=s._create_player_state(seat,"P%d"%seat,seat!=0,0)
  var h:Array=[]
  for t in range(27):
   for i in range(int(f["hands"][original][t])):h.append(_take(pool,t))
  p["hand_tiles"]=h;p["hand_count"]=h.size();p["ding_que"]=["tiao","tong","wan"][int(view["DingQueSuits"][original])]
  p["has_won"]=bool(view["HasHu"][original]);p["melds"]=[];p["discards"]=[]
  if f["winning"].has(str(original)):
   p["winning_tile"]=_take(pool,int(f["winning"][str(original)]));p["win_type"]="dian_pao"
  for m in view["MeldViews"][original]:
   var t:int=int(m["TileType"])
   var mt:int=int(m["Type"])
   var tiles:Array=[_take(pool,t),_take(pool,t),_take(pool,t)]
   if mt!=0:tiles.append(_take(pool,t))
   p["melds"].append({"type":"peng" if mt==0 else "gang","from_seat":(int(m["SourceSeat"])+own-1+4)%4 if int(m["SourceSeat"])>=0 else -1,"tiles":tiles,"gang_subtype":["","ming_gang","an_gang","add_gang"][mt]})
  for t in view["Discards18"][original]:p["discards"].append(_take(pool,int(t)))
  s.players.append(p)
 s.players.sort_custom(func(a,b):return int(a["seat"])<int(b["seat"]))
 for original in range(4):
  var seat:int=(original+own-1+4)%4
  for tile in s.players[seat]["discards"]:s.discard_pile.append({"seat":seat,"tile":tile})
 var types=["draw","discard","peng","melded_gang","concealed_gang","added_gang","hu","pass"]
 for e in view["PublicEvents"]:
  var original:int=int(e["Seat"]);var source:int=int(e["SourceSeat"])
  var tile:Dictionary={"id":int(e["TileType"])*4,"suit":["tiao","tong","wan"][int(e["TileType"])/9],"rank":int(e["TileType"])%9+1}
  s.ai_public_events.append({"eventIndex":int(e["EventIndex"]),"turnIndex":int(e["TurnIndex"]),"seat":(original+own-1+4)%4,"type":types[int(e["Type"])],"tile":tile,"origin":["unknown","hand","draw"][int(e["Origin"])],"sourceSeat":(source+own-1+4)%4 if source>=0 else -1,"wallCountAfter":-1})
  s.ai_public_event_version=int(e["EventIndex"])
 s.wall=pool;s.wall_count=pool.size();s.current_turn_seat=(int(view["CurrentSeat"])+own-1+4)%4;s.current_phase=int(view["Phase"])
 if int(view["LastDrawTileType"])>=0:
  s.last_draw_tile={"seat":own,"tile":s._find_hand_tile_by_tile_type(own,int(view["LastDrawTileType"]))}
 else:s.last_draw_tile.clear()
 s.last_turn_context={"seat":own,"draw_reason":"normal_draw"}
 _check(s.wall_count==int(view["WallCount"]),"fixture wall count")
 if int(f.get("offered",-1))>=0:
  var source:int=(own+3)%4
  var offer:Dictionary=s.players[source]["discards"][-1]
  s.last_turn_context={"seat":source,"draw_reason":"normal_draw"}
  s._prepare_reaction_context(source,offer)
  s.pending_reactions=s.pending_reactions.filter(func(x):return x.get("seat")==own)
 return s
