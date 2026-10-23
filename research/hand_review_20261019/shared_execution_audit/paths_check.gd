extends "res://research/hand_review_20261018/decision_unification/game_contract_check.gd"
const OUT="res://research/hand_review_20261019/shared_execution_audit/"
var serial := 100

func _run()->void:
 await process_frame
 var native=root.get_node("SichuanCSharpRuntime")
 var scenarios=[
  {"name":"ordinary","hand":[0,1,2,3,4,5,9,10,11,12,13,14,16,17],"dq":2,"draw":17,"expected":"discard"},
  {"name":"clear_missing","hand":[0,1,2,3,4,5,9,10,11,12,13,14,16,26],"dq":2,"draw":26,"expected":"discard","discard":26},
  {"name":"keep_pairs","hand":[26,26,26,26,0,0,3,3,6,6,18,18,20,23],"dq":1,"draw":26,"expected":"discard","two_active":true},
  {"name":"concealed_gang","hand":[2,2,4,4,5,6,7,7,7,21,26,26,26,26],"dq":1,"draw":26,"expected":"an_gang","two_active":true},
  {"name":"added_gang_scored","hand":[9,18,19,20,21,22,23,24,25,26,15],"melds":[9],"dq":0,"draw":9,"replacement":15,"expected":"add_gang"},
  {"name":"added_gang_unscored","hand":[9,18,19,20,21,22,23,24,25,26,15],"melds":[9],"dq":0,"draw":26,"replacement":15,"expected":"add_gang"},
  {"name":"rob_added_gang","hand":[9,18,19,20,21,22,23,24,25,26,15],"melds":[9],"dq":0,"draw":9,"reactor_hand":[10,11,18,19,20,21,22,23,24,25,26,25,25],"expected":"add_gang"},
  {"name":"plain_peng","hand":[0,0,3,4,5,9,10,11,12,13,14,16,17],"dq":2,"offered":0,"expected":"peng"},
  {"name":"melded_gang","hand":[0,0,0,3,4,5,9,10,11,12,13,14,16],"dq":2,"offered":0,"replacement":16,"expected":"gang"},
  {"name":"ron","hand":[0,0,0,3,4,5,9,10,11,12,13,14,16],"dq":2,"offered":16,"expected":"hu"},
  {"name":"pass","hand":[0,0,3,3,6,6,9,9,12,12,15,15,17],"dq":2,"offered":0,"expected":"pass"},
  {"name":"stale_missing_option","hand":[0,0,1,2,3,4,5,6,7,8,9,10,11],"dq":0,"offered":0,"expected":"blocked","manual":true},
 ]
 var full: bool=OS.get_cmdline_user_args().has("--full")
 for compact in [false,true]:
  for own in ([1,2,3] if full else [1]):
   for scenario in scenarios:
    # This rob-Gang fixture is established at seat 3. Other seats have different
    # relative missing-suit context and need not select the same risky Gang.
    if scenario.has("reactor_hand") and own!=3:continue
    serial+=1
    var s=_scenario(scenario,own,native,compact)
    var label: String=str(scenario["name"])+"/seat"+str(own)+"/compact"+str(compact)
    _check(s._begin_round_agents(),label+" begin agents")
    _check_physical(s)
    var before_wall: int=s.wall_count
    var e={"id":label,"expected":scenario["expected"],"before_wall":before_wall}
    var reaction: bool=scenario.has("offered")
    var prepared: Dictionary=s._build_ai_reaction_decision() if reaction else s._build_ai_turn_decision()
    var a: Dictionary=prepared.get("decision",{}) if reaction else prepared.get("analysis",{})
    var c: Dictionary=a.get("decision_command",{})
    if scenario["expected"]=="blocked":
     _check(a.is_empty(),label+" stale illegal option does not get a signed action")
     _check(not s.run_ai_reaction(),label+" stale illegal option cannot execute")
     _physical_with_winning_tile(s,label)
     rows.append({"id":label,"action":"blocked","native_error":s.ai_manager.last_native_reaction_error,"contract_absent":a.get("decision_command",{}).is_empty()})
     s._end_round_agents();s.free()
     continue
    var action: String=str(a.get("action","")) if reaction else str(prepared.get("action",""))
    e["action"]=action;e["command"]=c;e["reasons"]=a.get("reasons",[])
    _check(action==scenario["expected"],label+" expected "+str(scenario["expected"])+" got "+action)
    _check(s._valid_ai_command(a,own,"reaction" if reaction else "turn",s._build_player_state(own),s._build_table_state()),label+" original issued command validates")
    var executed := false
    if reaction:
     s.pending_ai_reaction_decision=prepared
     executed=s.run_ai_reaction()
    else:
     s.pending_ai_turn_decision=prepared
     executed=s.run_ai_turn()
    e["executed"]=executed;e["message"]=s.debug_last_message
    _check(executed,label+" executes exactly chosen action: "+s.debug_last_message)
    e["after_wall"]=s.wall_count
    if action=="discard" and executed:
     var actual: int=s._sichuan_tile_type(s.players[own]["discards"][-1])
     _check(actual==int(c.get("tile",-1)),label+" physical discard matches issued tile")
     if scenario.has("discard"):_check(actual==scenario["discard"],label+" missing suit enforced")
     if scenario["name"]=="keep_pairs":
      _check(actual in [20,23],label+" exact no-Gang continuation preserved")
    if action=="peng" and executed:
     var child: Dictionary=s.pending_ai_turn_decision.duplicate(true)
     var child_c: Dictionary=child.get("analysis",{}).get("decision_command",{})
     e["child_command"]=child_c
     _check(child_c.get("parentId")==c.get("id"),label+" ordinary Peng commits same parent plan")
     _check(s.run_ai_turn(),label+" Peng first discard executes")
     _check(s._sichuan_tile_type(s.players[own]["discards"][-1])==int(c.get("continuationTile",-1)),label+" ordinary Peng actual tile equals priced continuation")
    if scenario.has("reactor_hand") and executed:
     _check(not s.pending_qiang_gang_context.is_empty(),label+" real rob-Gang window opens")
     _check(s.wall_count==before_wall,label+" rob window precedes replacement draw")
     var reaction_prepared: Dictionary=s._build_ai_reaction_decision()
     var reaction_analysis: Dictionary=reaction_prepared.get("decision",{})
     e["rob_command"]=reaction_analysis.get("decision_command",{})
     _check(reaction_analysis.get("action")=="hu",label+" real reactor selects Hu")
     s.pending_ai_reaction_decision=reaction_prepared
     _check(s.run_ai_reaction(),label+" issued rob Hu executes")
     var reactor: int=(own+1)%4
     _check(s.players[reactor].get("has_won",false),label+" reactor wins")
     _check(s.players[reactor].get("win_type")=="qiang_gang_hu",label+" rob Hu settlement type")
     _check(s.players[own]["melds"][0].get("type")=="peng",label+" robbed Peng never upgrades")
     _check(s.settlement_data.get("gang_events",[]).is_empty(),label+" robbed Gang never charges Gang score")
    if action in ["an_gang","add_gang","gang"] and executed and not scenario.has("reactor_hand"):
     e["gang_events"]=s.settlement_data.get("gang_events",[]).duplicate(true)
     e["replacement_reason"]=s.last_turn_context.get("draw_reason","")
     _check(s.wall_count==before_wall-1,label+" exactly one replacement draw")
     _check(s.last_turn_context.get("draw_reason")=="gang_draw",label+" replacement origin preserved")
     _check(not s.settlement_data.get("gang_events",[]).is_empty(),label+" gang ledger exists")
     if action=="add_gang":
      _check(bool(s.settlement_data["gang_events"][-1].get("score_eligible",true))==(scenario["name"]=="added_gang_scored"),label+" scored/unscored eligibility")
     var child: Dictionary=s.pending_ai_turn_decision.duplicate(true)
     var child_c: Dictionary=child.get("analysis",{}).get("decision_command",{})
     e["replacement_command"]=child_c
     _check(child_c.get("id")!=c.get("id") and str(child_c.get("parentId",""))=="",label+" new draw gets fresh command")
     var next_ok: bool=s.run_ai_turn()
     e["replacement_executed"]=next_ok
     _check(next_ok,label+" replacement action actually executes")
     if scenario.has("replacement"):_check(bool(s.players[own].get("has_won",false)),label+" replacement Hu settles")
    if action=="hu" and executed:
     _check(s.players[own].get("has_won",false),label+" winner marked")
     _check(not s.settlement_data.get("win_events",[]).is_empty(),label+" Hu event settles")
    if action=="pass" and executed:
     _check(not s.pending_reactions.any(func(x):return x.get("seat")==own),label+" pass removes response once")
    # Claimed winning tiles live in winning_tile, rather than the concealed hand.
    _physical_with_winning_tile(s,label)
    rows.append(e)
    print("SHARED_PATH ",label," action=",action," executed=",executed," failures=",failures.size())
    s._end_round_agents();s.free()
 var f=FileAccess.open(OUT+("paths-full.json" if full else "paths-first.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"failures":failures,"rows":rows,"scope":"controlled physical snapshots, real C# seat authority and GameState; no forced AI action"},"  "))
 print("SHARED_PATHS rows=",rows.size()," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)

func _scenario(c:Dictionary,own:int,native,compact:bool):
 var s=_state(native,compact,false)
 s.players.clear();s.ai_agent_generation=serial
 s.ai_manager=ManagerScript.new();s.ai_manager.native_csharp_runtime=native
 s.ai_manager.force_mobile_aot_runtime_for_tests=compact;s.ai_manager.set_native_async_enabled(false)
 s.ai_manager.ai_reaction_analysis_ready.connect(s._on_ai_reaction_analysis_ready)
 s.ai_manager.ai_turn_analysis_ready.connect(s._on_ai_turn_analysis_ready)
 var pool: Array[Dictionary]=[]
 for t in range(27):
  for copy in range(4):pool.append({"id":t*4+copy,"suit":["tiao","tong","wan"][t/9],"rank":t%9+1,"sort_key":t,"display_name":str(t)})
 var hand: Array=[]
 for t in c["hand"]:hand.append(_take(pool,int(t)))
 var source: int=(own+1)%4
 var melds: Array=[]
 for t in c.get("melds",[]):melds.append({"type":"peng","from_seat":source,"tiles":[_take(pool,int(t)),_take(pool,int(t)),_take(pool,int(t))]})
 var offered: Dictionary=_take(pool,int(c["offered"])) if c.has("offered") else {}
 var replacement: Dictionary=_take(pool,int(c["replacement"])) if c.has("replacement") else {}
 var reactor_hand: Array=[]
 for t in c.get("reactor_hand",[]):reactor_hand.append(_take(pool,int(t)))
 var other:=0
 for seat in range(4):
  var p: Dictionary=s._create_player_state(seat,"P%d"%seat,seat!=0 or c.has("reactor_hand"),0)
  var h: Array=hand if seat==own else []
  if seat==source and not reactor_hand.is_empty():h=reactor_hand
  elif seat!=own:
   for i in range(13):
    var index: int=(seat*7+i*11)%pool.size();h.append(pool[index]);pool.remove_at(index)
  p["hand_tiles"]=h;p["hand_count"]=h.size();p["has_won"]=bool(c.get("two_active",false)) and seat not in [own,source]
  p["melds"]=melds if seat==own else []
  p["ding_que"]=["tiao","tong","wan"][int(c["dq"]) if seat==own else other%3]
  if seat==source and not reactor_hand.is_empty():p["ding_que"]="tiao"
  if seat!=own:other+=1
  if seat==source and not offered.is_empty():p["discards"]=[offered]
  s.players.append(p)
 if not replacement.is_empty():pool.append(replacement)
 s.wall=pool;s.wall_count=pool.size();s.last_draw_tile={};s.last_turn_context={}
 if offered.is_empty():
  s.current_turn_seat=own;s.current_phase=5
  s.last_draw_tile={"seat":own,"tile":s._find_hand_tile_by_tile_type(own,int(c["draw"]))}
  s.last_turn_context={"seat":own,"draw_reason":"normal_draw"}
 else:
  s.current_turn_seat=source;s.current_phase=6
  s.discard_pile.append({"seat":source,"tile":offered});s._append_ai_public_event("discard",source,offered,source,"hand")
  s._prepare_reaction_context(source,offered)
  if c.get("manual",false):
   # Represents a delayed option snapshot: missing-suit legality must still win.
   s.pending_reactions.clear();s.pending_reactions.append({"seat":own,"can_hu":false,"can_peng":true,"can_gang":false})
  else:s.pending_reactions=s.pending_reactions.filter(func(x):return x.get("seat")==own)
 return s

func _physical_with_winning_tile(s,label:String)->void:
 var ids: Array=[]
 for tile in s.wall:ids.append(int(tile["id"]))
 for p in s.players:
  for tile in p["hand_tiles"]+p["discards"]:ids.append(int(tile["id"]))
  for m in p["melds"]:
   for tile in m["tiles"]:ids.append(int(tile["id"]))
 # Winning tiles can reference a later seat's river, or one physical discard
 # for several winners. Collect all physical containers before extra refs.
 for p in s.players:
  var winning: Dictionary=p.get("winning_tile",{})
  if not winning.is_empty() and not ids.has(int(winning["id"])):ids.append(int(winning["id"]))
 var unique: Dictionary={}
 for id in ids:unique[id]=true
 _check(ids.size()==108 and unique.size()==108,label+" 108 physical tiles conserved")
