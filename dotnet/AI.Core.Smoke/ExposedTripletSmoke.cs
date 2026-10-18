using System.Text.Json;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class ExposedTripletSmoke
{
    public static int Run(string folder, string phase)
    {
        int checks=0;
        var failures=new List<string>();var rows=new List<object>();var pengRows=new List<object>();
        void Check(bool ok,string why){checks++;if(!ok)failures.Add(why);}
        try {
            using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
            var paired=new Dictionary<string,(int Limit,bool Eligible,string Action)>();
            foreach(var row in doc.RootElement.GetProperty("books").EnumerateArray()) {
                string name=row.GetProperty("name").GetString()!;var state=Chapter412Smoke.State(row.GetProperty("payload"));
                string family=row.GetProperty("family").GetString()!;
                int offer=row.GetProperty("offer").GetInt32();
                Check(Enumerable.Range(0,27).All(t=>state.Hand18[t]+state.Visible18[t]+state.Remaining18[t]==4),name+" copies");
                Check(state.Remaining18.Sum()==state.WallCount+state.HandCounts.Skip(1).Sum(),name+" unknown pool");
                var expected=row.GetProperty("waits").EnumerateArray().Select(t=>t.GetInt32()).Order().ToArray();
                var waits=new SichuanExactHandAnalyzer().EnumerateWaits(state.Hand18,state.Remaining18,state.OwnMeldCount).Select(w=>w.TileType).Order().ToArray();
                Check(waits.SequenceEqual(expected),name+" independent waits");
                var winning=(int[])state.Hand18.Clone();winning[offer]++;
                var fan=new SichuanFanProjectionEngine().Project(winning,state.MeldViews[0],SichuanWinType.Discard);
                Check(fan.HandScore==row.GetProperty("ron").GetInt32(),name+" independent ron price");
                Check(fan.IsJinGouDiao==(family=="4-8"),name+" golden hook distinction");
                var strategy=SichuanStrategyContract.Assess(state);
                Check(strategy.Development.GangOpportunity==0,name+" exposed Peng treated as concealed triplet");
                var result=new SichuanReactionDecisionEngine().DecideReaction(state,offer,true,false,false,1);
                if(family.StartsWith("4-7")) {
                    Check(!strategy.AllowsRonRefusal,name+" single wait gained refusal eligibility");
                    Check(result.Action.ActionType==SichuanActionType.Hu,name+" single wait not cashed");
                }
                if(family=="wide-independent")Check(strategy.AllowsRonRefusal,name+" independent wide wait suppressed by Peng rule");
                string key=family+"-"+row.GetProperty("permutation").GetRawText();
                var signature=(strategy.Development.RefusalLimit,strategy.AllowsRonRefusal,result.Action.ActionType.ToString());
                if(paired.TryGetValue(key,out var before)) {
                    Check(signature.Item1==before.Limit&&signature.Item2==before.Eligible,name+" fourth visibility added quota");
                } else paired[key]=signature;
                rows.Add(new{name,family,signature,action=result.Action,fan,refusal=strategy,reason=result.Reasons});
            }
            int speculative=0,verifiedSupply=0;
            foreach(var row in doc.RootElement.GetProperty("peng").EnumerateArray()) {
                string name=row.GetProperty("name").GetString()!;
                var state=Chapter412Smoke.State(row.GetProperty("payload"));
                int tile=row.GetProperty("claim").GetInt32(),discard=row.GetProperty("discard").GetInt32();
                var gain=new SichuanDevelopmentPolicy().EvaluatePeng(state,tile,discard);
                var bp=row.GetProperty("before_profile");var ap=row.GetProperty("after_profile");
                int beforeDistance=bp.GetProperty("distance").GetInt32(),afterDistance=ap.GetProperty("distance").GetInt32();
                double beforeSupply=bp.GetProperty("supply").GetDouble();
                double afterSupply=ap.GetProperty("supply").GetDouble();
                Check(gain.BeforeDistance==beforeDistance&&gain.AfterDistance==afterDistance,name+" independent distance");
                Check(Math.Abs(gain.BeforeSupply-beforeSupply)<1e-10&&Math.Abs(gain.AfterSupply-afterSupply)<1e-10,name+" independent public supply");
                bool speed=afterDistance<beforeDistance;
                bool supply=afterDistance==beforeDistance && afterSupply>beforeSupply+0.005;
                if(gain.Improves&&!speed&&!supply)speculative++;
                Check(!gain.Improves||speed||supply,name+" future added Gang purchased structural loss");
                Check(!gain.Reasons.Contains("PENG_LIVE_ADDED_GANG_COVERS_WAITING_COST"),name+" obsolete future bonus");
                if(supply){Check(gain.Improves,name+" actual supply improvement lost");verifiedSupply++;}
                if(row.GetProperty("after_waits").GetArrayLength()>0)Check(gain.AfterDistance==0,name+" independent ready successor");
                if(phase!="baseline")Check(gain.Reasons.Contains("PENG_FUTURE_ADDED_GANG_NO_GREED"),name+" candidate mechanism not executed");
                var value=new SichuanMeldCounterfactualEvaluator().Evaluate(state,"peng",tile,2,state.OwnMeldCount+1,0,0,0,plannedDiscardTile:discard,gangSourceSeat:1);
                Check(value.ImmediateSelfAction!="add_gang",name+" illegal Peng/add chain returned");
                pengRows.Add(new{name,gain,value});
            }
            Check(verifiedSupply>0,"no real structural improvement exercised");
            foreach(var cell in doc.RootElement.GetProperty("hypothetical_fixed_position_probabilities").EnumerateArray()) {
                int n=cell.GetProperty("unknown_pool").GetInt32(),k=cell.GetProperty("fourths").GetInt32(),draws=cell.GetProperty("own_positions").GetInt32();
                double miss=1;for(int i=0;i<draws;i++)miss*=(n-k-i)/(double)(n-i);
                Check(Math.Abs(1-miss-cell.GetProperty("probability").GetDouble())<1e-12,"independent finite-pool product/combinations");
            }
            var report=new{phase,passed=failures.Count==0,checks,failures,speculative,verifiedSupply,books=rows,peng=pengRows,
                scope="source shape plus declared physical synthetic completions; finite policy/structure controls, no strength or probability calibration claim"};
            File.WriteAllText(Path.Combine(folder,phase+"_results.json"),JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"EXPOSED_TRIPLET {phase} checks={checks} failures={failures.Count} speculative={speculative} supply={verifiedSupply}");
            foreach(var f in failures.Take(8))Console.WriteLine(f);
            return failures.Count==0?0:1;
        }catch(Exception e){Console.Error.WriteLine($"EXPOSED_TRIPLET {phase} FAIL checks={checks}: {e}");return 2;}
    }
}
