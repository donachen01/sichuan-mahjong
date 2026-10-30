extends "res://research/hand_review_20261023/late_wall_break_ready/verify_game.gd"
const WIDE_OUT="res://research/book_algorithm_20261011/capability-acceptance-20261024/"
func _run()->void:
 await process_frame
 var native=root.get_node("SichuanCSharpRuntime")
 for compact in [false,true]:
  for wall in [40]:
   serial+=1
   var s=_wide_fixture(native,compact,wall)
   _physical_with_winning_tile(s,"wide before")
   _check(s._begin_round_agents(),"wide begin agents")
   var prepared:Dictionary=s._get_or_prepare_ai_turn_decision()
   var analysis:Dictionary=prepared.get("analysis",{})
   var command:Dictionary=analysis.get("decision_command",{})
   _check(s._valid_ai_command(analysis,1,"turn",s._build_player_state(1),s._build_table_state()),"wide latest-state command")
   var executed:bool=s.run_ai_turn()
   var actual:int=s._sichuan_tile_type(s.players[1]["discards"][-1]) if executed else -1
   _check(executed and actual==int(command.get("tile",-1)),"wide actual discard matches signed command")
   _physical_with_winning_tile(s,"wide after")
   rows.append({"id":"wall%d/compact%s"%[wall,compact],"executed":executed,"actual":actual,"command":command,"reasons":analysis.get("reasons",[])})
   print("WIDE_GAME wall=",wall," compact=",compact," discard=",actual," failures=",failures.size())
   s._end_round_agents();s.free()
 var f=FileAccess.open(WIDE_OUT+"wide-game-results.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"failures":failures,"rows":rows,"scope":"three wider-wall reconstructed backgrounds x ordinary/compact real C# to GameState execution; not original replay or iOS AOT"},"  "))
 print("DONE wide game rows=",rows.size()," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)

func _wide_fixture(native,compact:bool,wall_count:int):
 var s=_fixture(native,compact,8)
 for i in range(max(0,wall_count-8)):
  var moved:Dictionary=s.players[2]["discards"].pop_back()
  s.wall.append(moved)
 s.wall_count=s.wall.size()
 return s
