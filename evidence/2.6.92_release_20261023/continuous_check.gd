extends "res://evidence/2.6.92_release_20261023/paths_check.gd"

func _run()->void:
 await process_frame
 var state=StateScript.new()
 root.add_child(state)
 state.human_trainer_hint_enabled=false
 state.ai_manager.set_native_async_enabled(false)
 var old_analysis: Dictionary={}
 var old_seat:=0
 for run in range(4):
  var compact: bool=run>=2
  state.ai_manager.force_mobile_aot_runtime_for_tests=compact
  state.set_test_seed(42917+run)
  state.round_index=run+1
  state.start_new_round()
  for p in state.players:p["is_ai"]=true;p["ai_level"]=state.ai_level
  _check(state.complete_opening_roll(),"run%d opening and real dingque"%run)
  if not old_analysis.is_empty():
   _check(not state._valid_ai_command(old_analysis,old_seat,"turn",state._build_player_state(old_seat),state._build_table_state()),"run%d rejects prior round command"%run)
  var actions: Dictionary={}
  var max_us:=0
  var total_validation_us:=0
  var count:=0
  var has_blood_continuation:=false
  var blocked: Dictionary={}
  for step in range(800):
   if state.current_phase==7:break
   if state.current_phase==3:
    state._auto_select_ai_ding_que();state._complete_ding_que_if_ready()
    continue
   var turn: bool=state.current_phase==5
   if state.current_phase==6 and not state.is_ai_reaction_pending():
    state._finalize_reaction_without_claim()
    continue
   var ready: Dictionary=state._get_or_prepare_ai_turn_decision() if turn else state._get_or_prepare_ai_reaction_decision()
   var a: Dictionary=ready.get("analysis",{}) if turn else ready.get("decision",{})
   var seat: int=int(ready.get("seat",-1))
   var c: Dictionary=a.get("decision_command",{})
   if c.is_empty() or seat<0:
    blocked={"step":step,"phase":state.current_phase,"seat":seat,"message":state.debug_last_message,"turn_error":state.ai_manager.last_native_self_action_error,"reaction_error":state.ai_manager.last_native_reaction_error}
    break
   var start:=Time.get_ticks_usec()
   var valid: bool=state._valid_ai_command(a,seat,"turn" if turn else "reaction",state._build_player_state(seat),state._build_table_state())
   var elapsed:=Time.get_ticks_usec()-start
   total_validation_us+=elapsed;max_us=max(max_us,elapsed)
   _check(valid,"run%d step%d issued contract validates"%[run,step])
   var action: String=str(c.get("action",""))
   var before_discards: int=state.players[seat]["discards"].size()
   var ok: bool=state.run_ai_turn() if turn else state.run_ai_reaction()
   if not ok:
    blocked={"step":step,"phase":state.current_phase,"seat":seat,"action":action,"message":state.debug_last_message}
    break
   if action=="discard":
    _check(state.players[seat]["discards"].size()==before_discards+1,"run%d step%d exactly one discard"%[run,step])
    _check(state._sichuan_tile_type(state.players[seat]["discards"][-1])==int(c.get("tile",-1)),"run%d step%d actual tile equals command"%[run,step])
   _check(not state._valid_ai_command(a,seat,"turn" if turn else "reaction",state._build_player_state(seat),state._build_table_state()),"run%d step%d replay rejected"%[run,step])
   if turn:old_analysis=a.duplicate(true);old_seat=seat
   if state.round_winners.size()>0 and state.current_phase!=7:has_blood_continuation=true
   actions[action]=int(actions.get(action,0))+1;count+=1
   _physical_with_winning_tile(state,"run%d step%d"%[run,step])
   await process_frame
  _check(blocked.is_empty(),"run%d no blocked execution %s"%[run,blocked])
  _check(state.current_phase==7,"run%d reaches settlement"%run)
  var score_sum:=0
  for delta in state.settlement_data.get("score_changes",{}).values():score_sum+=int(delta)
  _check(score_sum==0,"run%d settlement conserved"%run)
  var row={"run":run,"compact":compact,"settlement":state.current_phase==7,"executed_actions":count,"actions":actions,"blood_continues":has_blood_continuation,"winners":state.round_winners.duplicate(),"score_sum":score_sum,"blocked":blocked,"contract_validation_avg_us":float(total_validation_us)/max(1,count),"contract_validation_max_us":max_us}
  rows.append(row)
  print("CONTINUOUS ",JSON.stringify(row))
 var f=FileAccess.open(OUT+"continuous.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"failures":failures,"rows":rows,"scope":"four bounded natural rounds with real native runtime and physical GameState actions; desktop, including compact transport"},"  "))
 state._end_round_agents();state.free()
 quit(0 if failures.is_empty() else 1)
