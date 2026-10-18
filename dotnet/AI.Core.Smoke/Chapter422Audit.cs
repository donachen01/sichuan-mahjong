using System.Text.Json;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Rules;

internal static class Chapter422Audit
{
    public static int Run(string folder)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"audit_inputs.json")));
        var rows=new List<object>();var errors=new List<string>();int matches=0,mismatches=0,unresolved=0;
        foreach(var row in doc.RootElement.GetProperty("cases").EnumerateArray()) {
            var state=Chapter412Smoke.State(row.GetProperty("payload"));string name=row.GetProperty("name").GetString()!;
            var ws=new SichuanExactHandAnalyzer().EnumerateWaits(state.Hand18,state.Remaining18,state.OwnMeldCount).Select(w=>w.TileType).Order().ToArray();
            if(!ws.SequenceEqual(row.GetProperty("waits").EnumerateArray().Select(x=>x.GetInt32()).Order()))errors.Add(name+" independent waits");
            if(ws.Sum(t=>state.Remaining18[t])!=row.GetProperty("live").GetInt32())errors.Add(name+" live copies");
            if(state.Remaining18.Sum()!=state.WallCount+state.HandCounts.Skip(1).Sum())errors.Add(name+" physical pool");
            var s=SichuanStrategyContract.Assess(state);var plan=s.Development;
            int rawCap=plan.RefusalLimit;
            if(s.Discipline.Applies)rawCap=Math.Min(rawCap,s.Discipline.MaximumRefusals);
            int effectiveCap=s.AllowsRonRefusal?rawCap:0;
            string reference=row.GetProperty("reference").ToString();
            bool? agrees=reference switch {
                "self_only"=>effectiveCap==int.MaxValue,
                "until_gang"=>effectiveCap==int.MaxValue&&plan.Goal=="wait_live_gang",
                "last_one"=>null,
                "1-2"=>effectiveCap is 1 or 2,
                _=>effectiveCap==int.Parse(reference)
            };
            if(agrees==true)matches++;else if(agrees==false)mismatches++;else unresolved++;
            var action=new SichuanReactionDecisionEngine().DecideReaction(state,row.GetProperty("offer").GetInt32(),true,false,false,1);
            rows.Add(new{name,reference,agrees,effectiveCap,rawCap,allows=s.AllowsRonRefusal,
                danger=plan.Danger,round=s.Discipline.Applies?s.Discipline.OwnRound:0,
                independentlyVerifiedTriplets=row.GetProperty("independent_triplets").Clone(),
                liveTargets=s.Discipline.Applies?s.Discipline.ViableGangTargets:plan.Representative?.ViableGangTargets,
                strategy=s,action=action.Action,reasons=action.Reasons});
        }
        File.WriteAllText(Path.Combine(folder,"current_policy_audit.json"),JsonSerializer.Serialize(new{
            audited=true,geometry_verified=errors.Count==0,errors,matches,mismatches,unresolved,rows,
            scope="Read-only current v24 policy audit against source ceilings; mismatches are findings, not automatically approved bugs. Source ranges and current EV exits are separate."
        },new JsonSerializerOptions{WriteIndented=true}));
        Console.WriteLine($"CHAPTER422_AUDIT cases={rows.Count} geometryErrors={errors.Count} sourceMatches={matches} differences={mismatches} semanticUnresolved={unresolved}");
        return errors.Count==0?0:1;
    }
}
