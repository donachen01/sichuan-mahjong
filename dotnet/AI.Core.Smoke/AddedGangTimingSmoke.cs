using System.Text.Json;
using SichuanMahjong.AI.Core.Analysis;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

internal static class AddedGangTimingSmoke
{
    public static int Run()
    {
        var checks = 0;
        void Check(bool ok, string why) { checks++; if (!ok) throw new InvalidOperationException(why); }
        void Illegal(Action action, string why) {
            var rejected = false;
            try { action(); } catch (InvalidOperationException) { rejected = true; }
            Check(rejected, why);
        }
        try {
            // Expected permission is fixed by the scenario's timeline, not by
            // the engine's option list. Test every tile identity and draw kind.
            foreach (var tile in Enumerable.Range(0, 27)) {
                foreach (var scenario in new[] { "just_peng", "peng_then_replacement", "later_held", "later_fourth", "later_gang_draw", "not_own_draw", "wall_empty", "has_hu", "missing_suit", "no_peng" }) {
                    var own = new int[27]; own[tile] = 1;
                    var state = SichuanStateCodec.FromRaw(0,0,0,scenario == "wall_empty" ? 0 : 20,own,new int[27],
                        dingQueSuits:[scenario == "missing_suit" ? tile/9 : (tile/9+1)%3,0,1,2]);
                    state.LastDrawTileType = scenario == "later_fourth" ? tile : (tile+1)%27;
                    state.LastDrawOrigin = SichuanTileOrigin.Draw;
                    state.OwnDrawReason = scenario.Contains("replacement") || scenario == "later_gang_draw" ? "gang_draw" : "normal_draw";
                    if (scenario is "just_peng" or "not_own_draw") {
                        state.LastDrawOrigin = SichuanTileOrigin.Unknown; state.LastDrawTileType = -1;
                    }
                    state.HasHu[0] = scenario == "has_hu";
                    if (scenario != "no_peng") state.MeldViews[0].Add(new(SichuanMeldType.Peng,tile,1,1) {
                        AddedGangBlockedUntilOwnDraw = scenario is "just_peng" or "peng_then_replacement"
                    });
                    var expected = scenario is "later_held" or "later_fourth" or "later_gang_draw";
                    Check(SichuanAddedGangRules.CanUpgrade(state,tile)==expected,$"permission {tile}/{scenario}");
                    if (expected) Check(SichuanMeldCounterfactualEvaluator.ProjectImmediateGangGain(state,"add_gang",tileType:tile)==(scenario=="later_fourth"?3:0),"scored/zero cash");
                    var transition = new SichuanActionTransitionEngine();
                    var source = transition.FromState(state);
                    if (scenario is "just_peng" or "peng_then_replacement" or "not_own_draw" or "wall_empty" or "no_peng")
                        Illegal(()=>transition.ApplyAddedGang(source,tile),"transition accepted illegal upgrade");
                }
                var hand = new int[27]; hand[tile] = 3; hand[(tile+1)%27] = 1;
                var before = SichuanStateCodec.FromRaw(0,0,1,30,hand,new int[27],dingQueSuits:[(tile/9+1)%3,0,1,2]);
                var t = new SichuanActionTransitionEngine();
                var peng = t.ApplyPeng(t.FromState(before),tile);
                Illegal(()=>t.ApplyAddedGang(peng,tile),"Peng immediately upgraded");
                var replacement = t.ApplyReplacementDraw(peng,(tile+1)%27);
                Illegal(()=>t.ApplyAddedGang(replacement,tile),"replacement bypassed Peng delay");
                var later = t.ApplyOwnDraw(t.ApplyDiscard(peng,(tile+1)%27),(tile+2)%27);
                Check(t.ApplyAddedGang(later,tile).Hand27[tile]==0,"normal later draw did not reopen upgrade");
            }

            // A client-supplied or mandatory list cannot legalize a forbidden action.
            var h = new int[27]; h[9]=1; h[15]=1;
            var s = SichuanStateCodec.FromRaw(0,0,0,12,h,new int[27],dingQueSuits:[0,1,1,2]);
            s.MeldViews[0].Add(new(SichuanMeldType.Peng,9,1,1){AddedGangBlockedUntilOwnDraw=true});
            foreach (var tile in new[]{12,13,14}) s.MeldViews[0].Add(new(SichuanMeldType.ConcealedGang,tile,0,0));
            s.LastDrawOrigin=SichuanTileOrigin.Draw; s.LastDrawTileType=15;
            var key=SichuanStateFingerprint.BuildTurnKey(s,true,false);
            var raw=JsonSerializer.Serialize(s.MeldViews[0][0]);
            Check(JsonSerializer.Deserialize<SichuanMeldView>(raw)!.AddedGangBlockedUntilOwnDraw,"timing flag lost in JSON");
            foreach(var mandatory in new[]{false,true}) {
                var result=new SichuanSelfActionDecisionEngine().DecideSelfAction(s,false,[],[9],mandatoryGangTileTypes:mandatory?[9]:[]);
                Check(result.Action.ActionType!=SichuanActionType.Gang,"AI accepted forbidden supplied Gang");
                Check(!result.ActionScores.ContainsKey("add_gang:9"),"illegal candidate was still priced");
            }
            Illegal(()=>new SichuanMeldCounterfactualEvaluator().Evaluate(s,"add_gang",9,1,4,0,0,0),"counterfactual priced forbidden Gang");
            s.MeldViews[0][0]=s.MeldViews[0][0] with{AddedGangBlockedUntilOwnDraw=false};
            Check(key!=SichuanStateFingerprint.BuildTurnKey(s,true,false),"decision cache ignores timing flag");
            Check(SichuanAddedGangRules.CanUpgrade(s,9),"later held copy rejected");
            Console.WriteLine($"ADDED_GANG_TIMING PASS checks={checks}");
            return 0;
        } catch(Exception e) { Console.Error.WriteLine($"ADDED_GANG_TIMING FAIL checks={checks}: {e}"); return 1; }
    }
}
