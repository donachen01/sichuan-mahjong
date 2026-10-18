using System.Text.Json;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Models;

internal static class Chapter423Audit
{
    public static int Run(string folder)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
        var rows=new List<object>();var errors=new List<string>();var differences=new List<string>();int checks=0;
        void Check(bool ok,string name){checks++;if(!ok)errors.Add(name);}
        foreach(var r in doc.RootElement.GetProperty("cases").EnumerateArray())
        {
            var name=r.GetProperty("name").GetString()!;var offer=r.GetProperty("offer").GetInt32();
            var s=Chapter412Smoke.State(r.GetProperty("payload"));
            var exact=new SichuanExactHandAnalyzer();
            var initial=exact.EnumerateWaits(s.Hand18,s.Remaining18).Select(w=>w.TileType).Order();
            Check(initial.SequenceEqual(r.GetProperty("waits").EnumerateArray().Select(w=>w.GetInt32()).Order()),name+" initial waits");
            var action=new SichuanReactionDecisionEngine().DecideReaction(s,offer,false,true,true,1);
            var peng=new SichuanMeldCounterfactualEvaluator().Evaluate(s,"peng",offer,2,1,0,0,0,
                plannedDiscardTile:action.Action.ActionType==SichuanMahjong.AI.Core.Models.SichuanActionType.Peng?action.PlannedDiscardTile:-1);
            var gang=new SichuanMeldCounterfactualEvaluator().Evaluate(s,"gang",offer,3,1,0,0,0);
            var pass=new SichuanMeldCounterfactualEvaluator().Evaluate(s,"pass",offer,0,0,0,0,0);
            Check(gang.ImmediateGangGain==4,name+" real current four-player Gang money is 4, not source 2");
            Check(Math.Abs(gang.ReplacementBranches.Sum(b=>b.Weight)-1)<1e-9,name+" normalized replacement allocation");
            foreach(var b in gang.ReplacementBranches)
            {
                Check(!b.ImmediateWin,name+" non-independent source Gang cannot immediately win");
                var source=r.GetProperty("gang").EnumerateArray().Single(x=>x.GetProperty("draw").GetInt32()==b.DrawTile);
                var independent=source.GetProperty("options").EnumerateArray().Single(x=>x.GetProperty("discard").GetInt32()==b.DiscardTile);
                Check(independent.GetProperty("shanten").GetInt32()==b.Shanten,name+" chosen branch exact shanten");
                // LiveUkeire for an unready hand measures improvements. For
                // ready branches it must equal the independently legal waits.
                if(b.Shanten==0)Check(b.LiveUkeire>=0&&b.LiveUkeire<=independent.GetProperty("live").GetInt32(),name+" ready branch wall mass cannot exceed unseen waits");
            }
            var expected=r.GetProperty("source_preference").GetString();var actual=action.Action.ActionType.ToString().ToLowerInvariant();
            if(expected!=actual)differences.Add(name);
            rows.Add(new{name,expectedSourceTendency=expected,actual,matchesSourceTendency=expected==actual,
                actionScores=action.ActionScores,plannedPengDiscard=action.PlannedDiscardTile,
                reasons=action.Reasons,valueCandidates=action.ValueCandidates,
                pass,peng,gang,
                readyReplacementMass=gang.ReplacementBranches.Where(b=>b.Shanten==0&&b.LiveUkeire>0).Sum(b=>b.Weight),
                deadReadyReplacementMass=gang.ReplacementBranches.Where(b=>b.Shanten==0&&b.LiveUkeire==0).Sum(b=>b.Weight),
                unreadyReplacementMass=gang.ReplacementBranches.Where(b=>b.Shanten>0).Sum(b=>b.Weight),
                geometry= r.GetProperty("gang").EnumerateArray().Select(x=>new{draw=x.GetProperty("draw").GetInt32(),
                    canLiveReady=x.GetProperty("canLiveReady").GetBoolean(),canStructuralReady=x.GetProperty("canStructuralReady").GetBoolean()})});
        }
        // 4-12A's source explanation explicitly says the recovery keys are
        // exhausted. Add that public evidence without changing the shape.
        var exhausted=doc.RootElement.GetProperty("cases").EnumerateArray()
            .Single(x=>x.GetProperty("name").GetString()=="4-12-A-s0");
        var exhaustedState=Chapter412Smoke.State(exhausted.GetProperty("payload"));
        var exhaustedRemaining=(int[])exhaustedState.Remaining18.Clone();
        var exhaustedVisible=(int[])exhaustedState.Visible18.Clone();
        var exhaustedWall=exhaustedState.WallCount;
        foreach(var t in new[]{10,11})
        {
            var known=exhaustedRemaining[t];exhaustedRemaining[t]=0;
            exhaustedVisible[t]+=known;exhaustedWall-=known;
        }
        var rebuilt=SichuanStateCodec.FromRaw(exhaustedState.SeatIndex,exhaustedState.DealerSeat,
            exhaustedState.CurrentSeat,exhaustedWall,exhaustedState.Hand18,exhaustedVisible,exhaustedRemaining,
            exhaustedState.Discards18.Select(x=>x.AsEnumerable()),exhaustedState.Melds18.Select(x=>x.AsEnumerable()),
            dingQueSuits:exhaustedState.DingQueSuits,handCounts:exhaustedState.HandCounts,activeSeats:exhaustedState.ActiveSeats);
        for(var seat=0;seat<4;seat++)rebuilt.MeldViews[seat].AddRange(exhaustedState.MeldViews[seat]);
        rebuilt.PublicEvents.AddRange(exhaustedState.PublicEvents);
        exhaustedState=rebuilt;
        var exhaustedAction=new SichuanReactionDecisionEngine().DecideReaction(exhaustedState,exhausted.GetProperty("offer").GetInt32(),false,true,true,1);
        Check(exhaustedAction.Action.ActionType==SichuanActionType.Peng,
            "4-12A publicly exhausted recovery keys prefer ready Peng");
        Check(exhaustedAction.ActionScores["gang"]<exhaustedAction.ActionScores["peng"],
            "4-12A publicly exhausted recovery keys lower Gang below ready Peng");
        rows.Add(new{name="4-12-A-public-exhaustion",action=exhaustedAction.Action.ActionType.ToString(),
            scores=exhaustedAction.ActionScores,reasons=exhaustedAction.Reasons});
        var output=new{auditOnly=true,checks,errors,sourceTendencyDifferences=differences,rows,
            strategyVersion=SichuanStrategyContract.Version,
            scope="Current production audit; heuristic candidate values are not calibrated terminal EV. Source money differs; no new strategy approval or production modification."};
        File.WriteAllText(Path.Combine(folder,"current_policy_audit.json"),JsonSerializer.Serialize(output,new JsonSerializerOptions{WriteIndented=true}));
        Console.WriteLine($"CHAPTER423_AUDIT cases={rows.Count} checks={checks} geometryErrors={errors.Count} sourceTendencyDifferences={differences.Count}");
        foreach(var e in errors.Take(12))Console.WriteLine(e);
        return errors.Count==0?0:1;
    }
}
