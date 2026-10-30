extends "res://research/book_algorithm_20261011/gap-closure-round3-20261030/benchmark.gd"

func _run()->void:
 var folder:="res://research/book_algorithm_20261011/gap-closure-round4-20261030/"
 var label:=_read_string_arg("--label=","before")
 var game:Node=GAME_STATE_SCRIPT.new();root.add_child(game);await process_frame
 game.set("ai_agent_generation",150113);game.call("set_test_seed",92625157);game.call("set_ai_preset","bone_ash")
 game.set("test_ai_policy_variants_by_seat",{0:"current",1:"cash_cost_before_v1",2:"cash_cost_before_v1",3:"cash_cost_before_v1"})
 game.call("start_new_round");_prepare_all_ai_table(game);game.get("ai_manager").set_native_async_enabled(false)
 var native=game.get("ai_manager").native_csharp_runtime
 var steps:Array=[];var snapshots:Dictionary={};var failure:Dictionary={};var digest:=""
 var core_identity:String=str(native.call("PolicyCoreIdentityDiagnostic"))
 for step in range(1500):
  var phase:int=int(game.get("current_phase"))
  if phase==7:break
  if digest.is_empty() and phase==5:
   var hands:Array=[];var wall:Array=[]
   for player in game.get("players"):
    var h:Array=[]
    for tile in player["hand_tiles"]:h.append(int(game.call("_sichuan_tile_type",tile)))
    h.sort();hands.append(h)
   for tile in game.get("wall"):wall.append(int(game.call("_sichuan_tile_type",tile)))
   digest=JSON.stringify({"hands":hands,"wall":wall}).sha256_text()
  var actor:int=int(game.get("current_turn_seat"))
  if phase==6:actor=int(game.call("_get_next_ai_reaction_candidate").get("seat",actor))
  var manager=game.get("ai_manager")
  var payload:Dictionary={}
  if actor>=0 and phase in [5,6]:payload=manager.csharp_bridge.build_discard_transport_payload(game.call("_build_player_state",actor),game.call("_build_table_state"),game.get("rules"))
  native.call("PolicyTimingDiagnostic",true)
  var start:=Time.get_ticks_usec();var ok:=_step(game);var ms:float=(Time.get_ticks_usec()-start)/1000.0
  var profile:String=str(native.call("PolicyTimingDiagnostic",false))
  if not ok or not _physical_integrity(game)["passed"]:
   failure={"step":step,"phase":phase,"message":game.get("debug_last_message"),"turn":manager.last_native_turn_error,"reaction":manager.last_native_reaction_error};break
  steps.append({"step":step,"phase":phase,"actor":actor,"ms":ms,"timing":profile,"wall_after":game.get("wall_count"),"event_sha256":JSON.stringify(game.get("ai_public_events")).sha256_text()})
  if ms>250:snapshots[str(step)]={"public_payload_before":payload,"turn_snapshot_after":manager.latest_turn_snapshot,"reaction_snapshot_after":manager.latest_reaction_snapshot}
  print("PROFILE ",label," step=",step," phase=",phase," actor=",actor," ms=",snapped(ms,.1))
  await process_frame
 var scores:Dictionary=game.get("settlement_data").get("score_changes",{})
 if int(game.get("current_phase"))!=7:failure["terminal"]=false
 var compared:Dictionary={}
 for seat in range(4):compared[seat]=int(scores.get(seat,scores.get(str(seat),999999)))
 if scores.size()!=4 or compared!={0:13,1:-1,2:-4,3:-8}:failure["different_scores"]=scores
 _write_report({"core_identity":core_identity,"seed":92625157,"controlled":0,"steps":steps,"snapshots":snapshots,"scores":scores,"deal_sha256":digest,"failure":failure,"scope":"Single-process actual native replay; no action override, reduced search, hidden-input override or timeout fallback."},folder+"profile-"+label+".json")
 game.call("abort_agent_round");game.queue_free();await process_frame
 quit(0 if failure.is_empty() else 1)
