extends "res://research/hand_review_20261018/decision_unification/game_contract_check.gd"

const OUT := "res://research/book_algorithm_20261011/lower-completion-20261023/affected-44/"
var serial := 0

func _run() -> void:
 await process_frame
 var native = root.get_node("SichuanCSharpRuntime")
 var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://research/technical_theory_lower_20261002/sections/4.4-fixtures.json"))
 var full := OS.get_cmdline_user_args().has("--full")
 for compact in [false, true]:
  for shift in ([0,1,2] if full else [0]):
   for own in ([1,2,3] if full else [1]):
    for raw in fixtures:
     if not raw.has("reaction_tile"):
      serial += 1
      _verify_self_draw(raw,shift,own,native,compact)
      continue
     serial += 1
     var label := "%s/shift%d/seat%d/compact%s" % [raw["case"],shift,own,compact]
     var state = _flying_state(raw,shift,own,native,compact)
     _check(state._begin_round_agents(),label+" initialize agents")
     _check_physical(state)
     var before: Dictionary = state.ai_manager.csharp_bridge.build_discard_transport_payload(state._build_player_state(own),state._build_table_state(),state.rules)
     var prepared: Dictionary = state._build_ai_reaction_decision()
     _check(bool(prepared.get("candidate",{}).get("can_hu",false)) and bool(prepared.get("candidate",{}).get("can_peng",false)),label+" real judge offers both Hu and Peng")
     var analysis: Dictionary = prepared.get("decision",{})
     var command: Dictionary = analysis.get("decision_command",{})
     var action := str(analysis.get("action",""))
     var planned := int(analysis.get("planned_discard_tile",-1))
     var entry := {"id":label,"action":action,"planned":planned,"reaction_command":command,"before_payload":before,"reaction_reasons":analysis.get("reasons",[])}
     _check(action=="peng",label+" source-shaped midgame selects Peng: "+action)
     if action=="peng":
      _check(command.get("continuationAction")=="discard" and int(command.get("continuationTile",-1))==planned,label+" command carries priced first discard")
      state.pending_ai_reaction_decision=prepared
      var reacted: bool=state.run_ai_reaction()
      entry["reaction_executed"]=reacted
      _check(reacted,label+" real reaction executes: "+state.debug_last_message)
      _check_physical(state)
      var pending: Dictionary=state.pending_ai_turn_decision.duplicate(true)
      var turn_analysis: Dictionary=pending.get("analysis",{})
      var turn_command: Dictionary=turn_analysis.get("decision_command",{})
      entry["turn_command"]=turn_command
      entry["turn_reasons"]=turn_analysis.get("reasons",[])
      entry["after_peng_payload"]=state.ai_manager.csharp_bridge.build_discard_transport_payload(state._build_player_state(own),state._build_table_state(),state.rules)
      _check(str(turn_command.get("parentId",""))==str(command.get("id","missing")),label+" exact priced plan is committed, not recomputed")
      _check(int(turn_command.get("tile",-1))==planned,label+" post-Peng tile matches reaction plan")
      _check(state._find_all_add_gang_options(own).is_empty(),label+" no immediate added gang")
      var executed: bool=state.run_ai_turn()
      entry["discard_executed"]=executed
      entry["message"]=state.debug_last_message
      _check(executed,label+" real planned discard executes: "+state.debug_last_message)
      var discards: Array=state.players[own]["discards"]
      var actual: int=state._sichuan_tile_type(discards[-1]) if not discards.is_empty() else -1
      entry["actual_discard"]=actual
      _check(actual==planned,label+" actual physical discard equals priced tile")
      var after_counts: Array=[]
      after_counts.resize(27);after_counts.fill(0)
      for tile in state.players[own]["hand_tiles"]:
       after_counts[state._sichuan_tile_type(tile)]+=1
      entry["after_hand"]=after_counts
      entry["after_melds"]=state.players[own]["melds"].duplicate(true)
      var waits: Array=[]
      for t in range(27):
       if t/9==int(before["dingQueSuits"][own]) or after_counts[t]>=4:
        continue
       var tile := {"id":108+t,"suit":["tiao","tong","wan"][t/9],"rank":t%9+1,"sort_key":t,"display_name":str(t)}
       if state.mahjong_judge.can_hu_on_discard(state._build_player_state(own),tile,state.rules):
        waits.append(t)
      entry["game_waits"]=waits
      _check(not waits.is_empty(),label+" game confirms re-entered tenpai")
      _check_physical(state)
     rows.append(entry)
     print("FLYING_EXEC ",label," action=",action," planned=",planned," parent=",str(entry.get("turn_command",{}).get("parentId","")).left(10)," failures=",failures.size())
     state._end_round_agents()
     state.free()
 var output=FileAccess.open(OUT+("execution-full.json" if full else "execution-first.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"platform":"macOS Godot 4.6.2 real C# runtime; JSON and mobile compact protocol, not device AOT","passed":failures.is_empty(),"failures":failures,"rows":rows},"  "))
 print("FLYING_EXECUTION rows=",rows.size()," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)

func _map(t: int,shift: int)->int:
 return ((t/9+shift)%3)*9+t%9

func _flying_state(raw:Dictionary,shift:int,own:int,native,compact:bool):
 var s=_state(native,compact,false)
 s.players.clear()
 s.ai_manager=ManagerScript.new()
 s.ai_manager.native_csharp_runtime=native
 s.ai_manager.force_mobile_aot_runtime_for_tests=compact
 s.ai_manager.set_native_async_enabled(false)
 s.ai_manager.ai_reaction_analysis_ready.connect(s._on_ai_reaction_analysis_ready)
 s.ai_manager.ai_turn_analysis_ready.connect(s._on_ai_turn_analysis_ready)
 s.ai_agent_generation=serial*10
 s.current_dealer_seat=0
 var source: int=(own+1)%4
 var pool: Array[Dictionary]=[]
 for t in range(27):
  for copy in range(4):
   pool.append({"id":t*4+copy,"suit":["tiao","tong","wan"][t/9],"rank":t%9+1,"sort_key":t,"display_name":str(t)})
 var hand: Array=[]
 for t in range(27):
  for copy in range(int(raw["hand18"][t])):
   hand.append(_take(pool,_map(t,shift)))
 var melds: Array=[]
 for m in raw["typed_melds"]:
  var mt: int=_map(int(m["tiles"][0]),shift)
  var tiles: Array=[]
  for i in range(3):tiles.append(_take(pool,mt))
  melds.append({"type":"peng","from_seat":source,"tiles":tiles})
 var has_reaction: bool=raw.has("reaction_tile")
 var offered: Dictionary=_take(pool,_map(int(raw["reaction_tile"]),shift)) if has_reaction else {}
 var missing_suit := -1
 for suit in range(3):
  var total := 0
  for rank in range(9):total+=int(raw["hand18"][suit*9+rank])
  if total==0:missing_suit=(suit+shift)%3;break
 var oi := 0
 for seat in range(4):
  var p: Dictionary=s._create_player_state(seat,"P%d"%seat,seat!=0,0)
  var h: Array=hand if seat==own else []
  if seat!=own:
   for i in range(13):
    var idx: int=(seat*13+i*7)%pool.size()
    h.append(pool[idx]);pool.remove_at(idx)
  p["hand_tiles"]=h;p["hand_count"]=h.size()
  p["has_won"]=false
  var dq: int=missing_suit if seat==own else (oi+shift)%3
  if seat!=own:oi+=1
  p["ding_que"]=["tiao","tong","wan"][dq]
  p["melds"]=melds if seat==own else []
  if seat==source and has_reaction:p["discards"]=[offered]
  s.players.append(p)
 s.wall=pool;s.wall_count=pool.size()
 if has_reaction:
  s.current_turn_seat=source;s.current_phase=6
  s.last_draw_tile={};s.last_turn_context={}
  s.discard_pile.append({"seat":source,"tile":offered})
  s._append_ai_public_event("discard",source,offered,source,"draw")
  s._prepare_reaction_context(source,offered)
  # Other players' concealed allocation is a physical completion, never AI input.
  # Preserve the actual target's legal candidate and isolate this response window.
  s.pending_reactions=s.pending_reactions.filter(func(c):return int(c.get("seat",-1))==own)
 else:
  s.current_turn_seat=own;s.current_phase=5
  var draw_type: int=_map(16 if raw["case"]=="4-24" else 11,shift)
  s.last_draw_tile={"seat":own,"tile":s._find_hand_tile_by_tile_type(own,draw_type)}
  s.last_turn_context={"seat":own,"draw_reason":"normal_draw"}
 return s

func _verify_self_draw(raw:Dictionary,shift:int,own:int,native,compact:bool)->void:
 var label := "%s/shift%d/seat%d/compact%s" % [raw["case"],shift,own,compact]
 var state=_flying_state(raw,shift,own,native,compact)
 _check(state._begin_round_agents(),label+" initialize agents")
 _check_physical(state)
 _check(state._can_seat_self_hu_now(own),label+" actual legal self Hu")
 _check(state._start_ai_turn_background_request(),label+" prepare formal turn")
 var self_payload: Dictionary=state.ai_manager.csharp_bridge.build_discard_transport_payload(state._build_player_state(own),state._build_table_state(),state.rules)
 var pending: Dictionary=state.pending_ai_turn_decision.duplicate(true)
 var action: String=str(pending.get("action",""))
 _check(action=="self_hu",label+" selects immediate self Hu")
 var executed: bool=state.run_ai_turn()
 _check(executed and state.players[own].get("has_won",false),label+" actual self Hu executes")
 _check(not state.settlement_data.get("win_events",[]).is_empty(),label+" settlement Hu event exists")
 _check_physical(state)
 rows.append({"id":label,"kind":"self_hu","self_payload":self_payload,"action":action,"executed":executed,"has_won":state.players[own].get("has_won",false),"command":pending.get("analysis",{}).get("decision_command",{}),"win_events":state.settlement_data.get("win_events",[]).duplicate(true)})
 print("FLYING_EXEC ",label," action=",action," executed=",executed," failures=",failures.size())
 state._end_round_agents()
 state.free()
