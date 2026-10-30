extends "res://research/book_algorithm_20261011/lower-completion-20261023/verify_game.gd"
const RUN_OUT="res://research/book_algorithm_20261011/capability-acceptance-20261024/"
func _run()->void:
 await process_frame
 var native=root.get_node("SichuanCSharpRuntime")
 var fixtures:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RUN_OUT+"unseen-fixtures.json"))
 var comparable:Dictionary={}
 var public_views:Dictionary={}
 for compact in [false,true]:
  for own in [1,3]:
   for id in fixtures:
    var variants:Array=[false,true] if own==1 and str(id).begins_with("ready_choice/clearedFalse/wall12") else [false]
    for hidden_changed in variants:
     serial+=1
     var s=_fixture(fixtures[id],own,native,compact)
     if hidden_changed:_swap_hidden(s,own)
     _physical_with_winning_tile(s,"before")
     var payload:Dictionary=s.ai_manager.csharp_bridge.build_discard_transport_payload(s._build_player_state(own),s._build_table_state(),s.rules)
     var observation:Dictionary=payload.duplicate(true)
     for metadata in ["roundId","hostGeneration","viewVersion"]:observation.erase(metadata)
     var key:String=str(id)+"/seat%d"%own
     if hidden_changed:_check(observation==public_views[key],"hidden swap keeps public observation identical")
     else:public_views[key]=observation
     _check(s._begin_round_agents(),"begin real independent agents")
     var prepared:Dictionary=s._get_or_prepare_ai_turn_decision()
     var analysis:Dictionary=prepared.get("analysis",{})
     var command:Dictionary=analysis.get("decision_command",{})
     _check(s._valid_ai_command(analysis,own,"turn",s._build_player_state(own),s._build_table_state()),"signed latest-state authority")
     var action:String=str(prepared.get("action",""))
     _check(action=="discard","fresh non-winning no-Gang hand discards")
     var selected:int=int(command.get("tile",-1))
     if compact or hidden_changed:_check(comparable[key]==selected,"compact/hidden-invariant public decision")
     else:comparable[key]=selected
     var executed:bool=s.run_ai_turn()
     _check(executed,"real GameState execution")
     var actual:int=s._sichuan_tile_type(s.players[own]["discards"][-1]) if executed else -1
     _check(actual==selected,"actual discard equals formal contract")
     _physical_with_winning_tile(s,"after")
     var label:String=key+"/compact%s/latent%s"%[compact,hidden_changed]
     rows.append({"id":label,"executed":executed,"action":action,"selected":selected,"actual":actual,"command":command,"reasons":analysis.get("reasons",[]),"scope":"fresh physical background; actual hidden allocation used only to initialize game, never passed to public AI"})
     print("ACCEPT ",label," tile=",selected," failures=",failures.size())
     s._end_round_agents();s.free()
 var f=FileAccess.open(RUN_OUT+"game-results.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"failures":failures,"rows":rows,"scope":"12 fresh physical backgrounds x 2 seats x 2 transports, plus 2 hidden-allocation swaps. Not independent full games or iOS NativeAOT."},"  "))
 print("DONE executed=",rows.size()," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)

func _swap_hidden(s,own:int)->void:
 var actor:int=(own+3)%4
 for i in range(s.players[actor]["hand_tiles"].size()):
  var hand_tile:Dictionary=s.players[actor]["hand_tiles"][i]
  for j in range(s.wall.size()):
   var wall_tile:Dictionary=s.wall[j]
   if hand_tile.get("suit")==wall_tile.get("suit") and hand_tile.get("rank")!=wall_tile.get("rank"):
    s.players[actor]["hand_tiles"][i]=wall_tile;s.wall[j]=hand_tile
    return
 _check(false,"construct physically distinct hidden allocation")
