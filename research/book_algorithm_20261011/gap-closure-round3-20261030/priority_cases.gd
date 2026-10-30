extends "res://research/book_algorithm_20261011/gap-closure-round3-20261030/full_claims.gd"

var proof:Array=[]
var watched:Dictionary={}

func _save_proof()->void:
 var out=FileAccess.open(_arg("--proof=","res://research/book_algorithm_20261011/gap-closure-round3-20261030/priority-proof.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify({"checks":proof,"failures":failures,"scope":"real native failing world; optional competing Pass is an explicitly declared legal test intervention"}));out.close()

func _live_step(s)->bool:
 if int(s.current_phase)!=6 or not s.is_ai_reaction_pending():return super._live_step(s)
 var prepared:Dictionary=s._get_or_prepare_ai_reaction_decision()
 var candidate:Dictionary=prepared.get("candidate",{})
 var decision:Dictionary=prepared.get("decision",{})
 var seat:int=int(prepared.get("seat",-1));var action:String=str(decision.get("action",""))
 if action in ["peng","gang"] and s._has_higher_priority_candidate_than(seat,action):
  var before:Array=s.pending_reactions.duplicate(true);var locks:Dictionary=s.shun_he_locks.duplicate(true)
  var pass_count:int=s.reaction_pass_evidence.size()
  watched={"seat":seat,"tile":int(s.current_discard_context.get("tile",{}).get("id",-1)),"request":int(s.ai_manager.request_state.get("last_reaction_request_id",0)),"locks":locks}
  var ok:bool=s.run_ai_reaction()
  _check(ok,"defer is progress")
  _check(before==s.pending_reactions,"defer preserves complete legal alternatives")
  _check(locks==s.shun_he_locks and pass_count==s.reaction_pass_evidence.size(),"unexecuted proposal is not Pass or a Hu lock")
  var next:Dictionary=s._get_next_ai_reaction_candidate()
  _check(int(next.get("seat",-1))!=seat and bool(next.get("can_hu",false)),"higher Hu reconsidered first")
  s.pending_ai_reaction_decision=prepared
  _check(not s._is_pending_ai_reaction_decision_valid(),"old scheduled-owner command is stale")
  s.pending_ai_reaction_decision.clear()
  proof.append({"phase":"defer","seat":seat,"next":next.get("seat",-1),"all_options_and_locks_preserved":true})
  if OS.get_cmdline_user_args().has("--force-competing-pass"):
   _check(s._pass_ai_reaction(int(next["seat"])),"declared competing Pass intervention")
  _save_proof();return ok
 if not watched.is_empty() and seat==int(watched["seat"]) and int(s.current_discard_context.get("tile",{}).get("id",-2))==int(watched["tile"]):
  _check(bool(candidate.get("can_hu",false)),"Hu option retained until an actual decision")
  var winner_count:int=s.current_discard_context.get("winner_seats",[]).size()
  if winner_count>0:_check(not candidate.get("can_peng",false) and not candidate.get("can_gang",false),"multi-Hu keeps only legal Hu/Pass")
  var latest:Dictionary=s.ai_manager.request_state.get("last_completed_request",{})
  _check(int(latest.get("seat",-1))==seat and int(latest.get("request_id",0))>int(watched["request"]),"new native request after priority resolution; deterministic command IDs may repeat for identical visible input")
  var ok:bool=s.run_ai_reaction()
  _check(ok,"fresh selected action executes")
  if action=="peng":_check(s.shun_he_locks.get(seat,{})==watched["locks"].get(seat,{}),"completed Peng preserves old lock and creates no Pass lock")
  if action=="hu":_check(bool(s.players[seat].get("has_won",false)),"actual Hu settlement")
  if action=="pass":_check(s.shun_he_locks.has(seat) or int(s.last_draw_tile.get("seat",-1))==seat,"actual Pass locks until own draw")
  proof.append({"phase":"fresh","seat":seat,"action":action,"prior_winners":winner_count});watched.clear();_save_proof();return ok
 return s.run_ai_reaction()
