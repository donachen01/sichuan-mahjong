using System.Text.Json;
using System.Text.Json.Serialization;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class Chapter412Smoke
{
    private static readonly JsonSerializerOptions Json=new(){PropertyNameCaseInsensitive=true,Converters={new JsonStringEnumConverter()}};
    internal static SichuanStateView State(JsonElement q)
    {
        int[] A(string key)=>q.GetProperty(key).EnumerateArray().Select(x=>x.GetInt32()).ToArray();
        bool[] B(string key)=>q.GetProperty(key).EnumerateArray().Select(x=>x.GetBoolean()).ToArray();
        var s=SichuanStateCodec.FromRaw(0,0,q.GetProperty("currentSeat").GetInt32(),q.GetProperty("wallCount").GetInt32(),
            A("hand18"),A("visible18"),A("remaining18"),
            discards18:q.GetProperty("discards18").Deserialize<int[][]>(Json),melds18:q.GetProperty("melds18").Deserialize<int[][]>(Json),
            dingQueSuits:A("dingQueSuits"),handCounts:A("handCounts"),activeSeats:B("activeSeats"));
        Array.Copy(B("hasHu"),s.HasHu,4);
        for(int i=0;i<4;i++)s.MeldViews[i].AddRange(q.GetProperty("meldViews")[i].Deserialize<SichuanMeldView[]>(Json)!);
        s.PublicEvents.AddRange(q.GetProperty("publicEvents").Deserialize<SichuanPublicEvent[]>(Json)!);
        return s;
    }
    public static int Run(string folder)
    {
        var rows=new List<object>();int checks=0;
        void Check(bool value,string name){checks++;if(!value)throw new InvalidOperationException(name);}
        try
        {
            using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
            var rule=new SichuanDistinctDingQueHuPolicy();var danger=new SichuanPublicDangerEvaluator();
            int[] caps=[2,1,0,0,0,2];int index=0;
            foreach(var row in doc.RootElement.GetProperty("books").EnumerateArray())
            {
                var q=row.GetProperty("payload");var state=State(q);string name=row.GetProperty("name").GetString()!;
                Check(Enumerable.Range(0,27).All(t=>state.Hand18[t]+state.Visible18[t]+state.Remaining18[t]==4),name+" copies");
                Check(state.Remaining18.Sum()==state.WallCount+state.HandCounts.Skip(1).Sum(),name+"108 pool");
                var actual=new SichuanExactHandAnalyzer().EnumerateWaits(state.Hand18,state.Remaining18).Select(w=>w.TileType);
                Check(actual.SequenceEqual(row.GetProperty("waits").EnumerateArray().Select(t=>t.GetInt32())),name+" independent waits");
                var result=rule.Evaluate(state);Check(result.OwnRound==4,name+" fourth own round");
                if(index<6)Check(result.MaximumRefusals==caps[index],name+" book quota: "+JsonSerializer.Serialize(result));
                int offer=row.GetProperty("offer").GetInt32();
                var runtime=new SichuanReactionDecisionEngine().DecideReaction(state,offer,true,false,false,1);
                Check(runtime.Reasons.Contains("DISTINCT_DINGQUE_HU_DISCIPLINE"),name+" production discipline missing");
                if(index is >=2 and <=4)Check(runtime.Action.ActionType==SichuanActionType.Hu,name+" narrow default not cashed");
                rows.Add(new{name,result,action=runtime.Action,reasons=runtime.Reasons});index++;
            }
            foreach(var row in doc.RootElement.GetProperty("matrix").EnumerateArray())
            {
                var state=State(row.GetProperty("payload"));var r=rule.Evaluate(state);
                Check(r.UnseenWaitCopies==row.GetProperty("live").GetInt32(),"quota live count");
                Check(r.DangerLevel==row.GetProperty("danger").GetInt32(),"quota danger");
                Check(r.OwnRound==row.GetProperty("round").GetInt32(),"quota own round");
                Check(r.UsedRefusals==row.GetProperty("used").GetInt32(),"quota used");
                Check(r.MaximumRefusals==row.GetProperty("cap").GetInt32(),"quota band");
                Check(r.AllowsRefusal==row.GetProperty("allowed").GetBoolean(),"quota allowed: "+JsonSerializer.Serialize(row));
                Check(rule.Evaluate(state).UsedRefusals==r.UsedRefusals,"queries spend quota");
            }
            foreach(var row in doc.RootElement.GetProperty("danger").EnumerateArray())
            {
                var state=State(row.GetProperty("payload"));var r=danger.Evaluate(state);
                string name=row.GetProperty("name").GetString()!;
                Check(r.Level==row.GetProperty("level").GetInt32(),name+": "+JsonSerializer.Serialize(r));
                // Suit rotations preserve the PUBLIC inference and cannot be
                // implemented as a rule for the source's particular tiles.
                for(int shift=1;shift<3;shift++)
                {
                    int Map(int t)=>t<0?t:((t/9+shift)%3)*9+t%9;
                    int[] Rotate(int[] values){var result=new int[27];for(int t=0;t<27;t++)result[Map(t)]=values[t];return result;}
                    var rotated=SichuanStateCodec.FromRaw(0,0,state.CurrentSeat,state.WallCount,Rotate(state.Hand18),Rotate(state.Visible18),Rotate(state.Remaining18),
                        discards18:state.Discards18.Select(d=>d.Select(Map)),melds18:state.Melds18.Select(m=>m.Select(Map)),
                        dingQueSuits:state.DingQueSuits.Select(s=>(s+shift)%3),handCounts:state.HandCounts,activeSeats:state.ActiveSeats);
                    Array.Copy(state.HasHu,rotated.HasHu,4);
                    for(int i=0;i<4;i++)rotated.MeldViews[i].AddRange(state.MeldViews[i].Select(m=>m with{TileType=Map(m.TileType)}));
                    rotated.PublicEvents.AddRange(state.PublicEvents.Select(e=>e with{TileType=Map(e.TileType)}));
                    Check(danger.Evaluate(rotated).Level==r.Level,name+" suit rotation");
                }
                state.IsReady[1]=true;state.IsCalled[2]=true;state.PassedHu18[3][11]=9;
                Check(JsonSerializer.Serialize(r)==JsonSerializer.Serialize(danger.Evaluate(state)),name+" private flags leak");
                rows.Add(new{name,report=r});
            }
            foreach(var row in doc.RootElement.GetProperty("development").EnumerateArray())
            {
                var state=State(row.GetProperty("payload"));var r=rule.Evaluate(state);
                Check(r.AllowsRefusal==row.GetProperty("allowed").GetBoolean(),"concrete Peng+discard golden hook: "+JsonSerializer.Serialize(r));
                rows.Add(new{name=row.GetProperty("name").GetString(),result=r});
            }
            foreach(var row in doc.RootElement.GetProperty("routes").EnumerateArray())
            {
                var state=State(row.GetProperty("payload"));var r=rule.Evaluate(state);
                string route=row.GetProperty("name").GetString()!;
                Check(r.UnseenWaitCopies<=6&&r.DevelopmentRoute==route&&r.MaximumRefusals==2&&r.AllowsRefusal,
                    "explicit narrow big-hand route "+route+": "+JsonSerializer.Serialize(r));
                rows.Add(new{name=route,result=r});
            }
            var one=State(doc.RootElement.GetProperty("matrix")[1].GetProperty("payload"));
            var old=one.PublicEvents.Single(e=>e.Type==SichuanPublicEventType.Pass);
            one.PublicEvents.Add(old with{EventIndex=1000});
            Check(rule.Evaluate(one).UsedRefusals==1,"same offered Hu charged twice");
            var cash=State(JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"cashout_widened.json"))).RootElement);
            var history=new SichuanHuRefusalHistory(cash);
            Check(history.FirstRefusalWaits(cash)?.Sum()==3,"original narrow wait reconstruction");
            var cashed=rule.Evaluate(cash);
            Check(cashed.UnseenWaitCopies==9 && cashed.GangRealized && !cashed.AllowsRefusal
                &&cashed.CashOutOrigin=="narrow_development_cashed","widened cash-out renewed quota: "+JsonSerializer.Serialize(cashed));
            var chosen=new SichuanReactionDecisionEngine().DecideReaction(cash,10,true,false,false,1);
            Check(chosen.Action.ActionType==SichuanActionType.Hu,"production bypassed original narrow cash-out");
            rows.Add(new{name="cashout_widened",cashed,action=chosen.Action,reasons=chosen.Reasons});
            using var wideDoc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"cashout_restore_base.json")));
            var wideCash=State(wideDoc.RootElement);var restored=rule.Evaluate(wideCash);
            Check(new SichuanHuRefusalHistory(wideCash).FirstRefusalWaits(wideCash)?.Sum()==10,"original wide wait reconstruction");
            Check(restored.CashOutOrigin=="restore_base_budget"&&restored.MaximumRefusals==1&&restored.UsedRefusals==1,
                "cash-out must restore CURRENT band without renewing used quota");
            rows.Add(new{name="cashout_restore_base",result=restored});
            // A zero-cash held upgrade cannot spend the scored-Gang commitment.
            var gangIndex=cash.PublicEvents.FindIndex(e=>e.Type==SichuanPublicEventType.MeldedGang);
            cash.PublicEvents[gangIndex]=cash.PublicEvents[gangIndex] with{GangScoreEligible=false};
            Check(!rule.Evaluate(cash).GangRealized,"zero-cash event marked scored cash-out");
            File.WriteAllText(Path.Combine(folder,"rule_results.json"),JsonSerializer.Serialize(new{checks,rows},new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"chapter412: PASS checks={checks} books=6 newHands=2 quotaControls=198 dangerCases={doc.RootElement.GetProperty("danger").GetArrayLength()} with suit/privacy controls");return 0;
        }
        catch(Exception e)
        {
            File.WriteAllText(Path.Combine(folder,"rule_failure.json"),JsonSerializer.Serialize(new{checks,error=e.ToString(),rows},new JsonSerializerOptions{WriteIndented=true}));
            Console.Error.WriteLine("chapter412: FAIL "+e);return 1;
        }
    }
}
