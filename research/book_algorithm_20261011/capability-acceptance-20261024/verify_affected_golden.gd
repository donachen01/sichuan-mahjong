extends "res://research/book_algorithm_20261011/golden-hook-differences-20261021/verify_game.gd"
const CURRENT_OUT="res://research/book_algorithm_20261011/capability-acceptance-20261024/"
func _run()->void:
 await process_frame
 var native=root.get_node("SichuanCSharpRuntime")
 var configs:Array=JSON.parse_string(FileAccess.get_file_as_string(GOLD_OUT+"cases.json"))
 # Two directly affected target-release backgrounds; selected for
 # this shared-premise change only, without rewriting historical evidence.
 var picked:Array=[]
 for c in configs:
  if c.get("first",false):picked.append(c)
  if picked.size()==2:break
 _check(picked.size()==2,"two affected golden-hook contexts")
 for compact in [false,true]:
  for own in [1,3]:
   for c in picked:
    serial+=1
    var s=_gold_state(c,own,native,compact)
    var label:String=str(c["id"])+"/seat%d/compact%s"%[own,compact]
    _physical_with_winning_tile(s,"before "+label)
    _check(s._begin_round_agents(),"begin "+label)
    var prepared:Dictionary=s._get_or_prepare_ai_reaction_decision()
    var a:Dictionary=prepared.get("decision",{})
    var command:Dictionary=a.get("decision_command",{})
    _check(s._valid_ai_command(a,own,"reaction",s._build_player_state(own),s._build_table_state()),"latest-state reaction "+label)
    s.pending_ai_reaction_decision=prepared
    var executed:bool=s.run_ai_reaction()
    _check(executed,"real reaction "+label)
    var action:String=str(a.get("action",""))
    var child:Dictionary={}
    if action=="peng":
     child=s.pending_ai_turn_decision.get("analysis",{}).get("decision_command",{}).duplicate(true)
     _check(child.get("parentId")==command.get("id"),"Peng carries same parent "+label)
     _check(s.run_ai_turn(),"real Peng continuation "+label)
     _check(s._sichuan_tile_type(s.players[own]["discards"][-1])==int(command.get("continuationTile",-1)),"actual priced continuation "+label)
    if action=="hu":_check(s.players[own].get("has_won",false),"actual Hu settlement "+label)
    _physical_with_winning_tile(s,"after "+label)
    rows.append({"id":label,"action":action,"executed":executed,"command":command,"child":child,"reasons":a.get("reasons",[])})
    print("GOLD_AFFECT ",label," action=",action," failures=",failures.size())
    s._end_round_agents();s.free()
 var f=FileAccess.open(CURRENT_OUT+"affected-golden.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"failures":failures,"rows":rows,"scope":"two prior golden-hook backgrounds selected for changed release premise; real C# reaction and physical continuation, not new original cases or strength evidence"},"  "))
 quit(0 if failures.is_empty() else 1)
