using System.Text.Json;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Models;

internal static class Chapter413Smoke
{
    public static int Run(string folder)
    {
        int checks=0;
        void Check(bool ok,string name){checks++;if(!ok)throw new InvalidOperationException(name);}
        var rows=new List<object>();
        try
        {
            using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
            var root=doc.RootElement;var rule=new SichuanWideBedHuPolicy();
            foreach(var row in root.GetProperty("books").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));string name=row.GetProperty("name").GetString()!;
                var p=rule.Evaluate(s);
                var w=new SichuanExactHandAnalyzer().EnumerateWaits(s.Hand18,s.Remaining18).Select(w=>w.TileType);
                Check(w.SequenceEqual(row.GetProperty("waits").EnumerateArray().Select(t=>t.GetInt32())),name+" independent waits");
                Check(p.Applies && p.KnownWallSuit && p.UnseenWaitCopies==row.GetProperty("live").GetInt32(),name+" applicability "+JsonSerializer.Serialize(p));
                Check(name=="4-6" ? !p.AllowsRefusal : p.AllowsRefusal,name+" source scope "+JsonSerializer.Serialize(p));
                var plan=new SichuanDevelopmentPolicy().Evaluate(s);
                Check(plan.WideBed is not null && plan.AllowsRefusal==p.AllowsRefusal,name+" plan wiring");
                var a=new SichuanReactionDecisionEngine().DecideReaction(s,row.GetProperty("payload").GetProperty("reactionTileType").GetInt32(),true,false,false,1);
                Check(a.Reasons.Contains("WIDE_BED_HU_DISCIPLINE"),name+" real decision wiring");
                if(name=="4-6")Check(a.Action.ActionType==SichuanActionType.Hu,"4-6 speculative dismantling bypass");
                rows.Add(new{name,policy=p,action=a.Action,reasons=a.Reasons});
            }
            foreach(var row in root.GetProperty("matrix").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));var p=rule.Evaluate(s);string name=row.GetProperty("name").GetString()!;
                Check(p.Applies && p.UnseenWaitCopies==row.GetProperty("live").GetInt32(),name+" count");
                Check(p.RefusalLimit==row.GetProperty("cap").GetInt32(),name+" cap "+JsonSerializer.Serialize(p));
                Check(p.AllowsRefusal==row.GetProperty("allowed").GetBoolean(),name+" eligible");
                Check(rule.Evaluate(s).UsedRefusals==p.UsedRefusals,name+" query spends budget");
            }
            foreach(var row in root.GetProperty("controls").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));var p=rule.Evaluate(s);string name=row.GetProperty("name").GetString()!;
                Check(p.Applies && p.AllowsRefusal==row.GetProperty("allowed").GetBoolean(),name+" control "+JsonSerializer.Serialize(p));
                if(row.TryGetProperty("goal",out var goal))Check(p.Goal==goal.GetString(),name+" goal");
                if(name=="narrow_gang_cashed")
                {
                    Check(new SichuanHuRefusalHistory(s).FirstRefusalWaits(s)?.Sum()==2,"cashout reconstruct original two-copy wait");
                    Check(p.GangRealized && p.UsedRefusals==1,"cashout historical commitment");
                }
                if(name=="held_upgrade_zero_cash")
                    Check(!p.GangRealized && !p.Reasons.Contains("WIDE_BED_SCORED_GANG_REPRICE_IMMEDIATE_HU_NO_NEW_GANG_EXCEPTION"),"zero cash upgrade must not trigger cash-out");
                if(name=="existing_scored_gang_reprice")
                {
                    Check(p.RefusalLimit==int.MaxValue,"arbitrary one-refusal restriction returned");
                    var estimate=new SichuanDevelopmentPolicy().AssessRefusal(s,14,SichuanWinType.Discard);
                    Check(estimate.ImmediateHuGain>1,"existing root must raise immediate Hu price");
                }
                rows.Add(new{name,policy=p});
            }
            foreach(var row in root.GetProperty("excluded").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));
                Check(!rule.Evaluate(s).Applies,"plain-hand table invaded valuable/near-flush route "+row.GetProperty("name").GetString());
            }
            foreach(var row in root.GetProperty("peng").EnumerateArray())
            {
                string name=row.GetProperty("name").GetString()!;
                var source=root.GetProperty("controls").EnumerateArray().Any(x=>x.GetProperty("name").GetString()==name)
                    ?root.GetProperty("controls").EnumerateArray().Single(x=>x.GetProperty("name").GetString()==name)
                    :root.GetProperty("books").EnumerateArray().Single(x=>x.GetProperty("name").GetString()==name);
                var s=Chapter412Smoke.State(source.GetProperty("payload"));int tile=row.GetProperty("tile").GetInt32();
                foreach(var r in row.GetProperty("successors").EnumerateArray())
                {
                    var h=(int[])s.Hand18.Clone();h[tile]-=2;h[r.GetProperty("discard").GetInt32()]--;
                    var capacity=Enumerable.Range(0,27).Select(t=>4-h[t]).ToArray();capacity[tile]-=3;
                    var actual=new SichuanExactHandAnalyzer().EnumerateWaits(h,capacity,1,false).Select(w=>w.TileType);
                    Check(actual.SequenceEqual(r.GetProperty("waits").EnumerateArray().Select(t=>t.GetInt32())),name+" independent Peng successor");
                }
                if(name is "two_waits_real_peng_improvement" or "dead_triplet_still_has_real_peng")
                {
                    var p=rule.Evaluate(s);
                    Check(p.PengTile==tile&&row.GetProperty("successors").EnumerateArray().Any(r=>r.GetProperty("discard").GetInt32()==p.PengDiscard
                        &&r.GetProperty("allLane").GetBoolean()&&r.GetProperty("live").GetInt32()>p.UnseenWaitCopies),"production Peng witness is independently valid");
                }
            }
            foreach(var row in root.GetProperty("probabilities").EnumerateArray())
            {
                double actual=SichuanSingleLaneSupply.HitProbability(row.GetProperty("wall").GetInt32(),row.GetProperty("copies").GetInt32(),row.GetProperty("draws").GetInt32());
                Check(Math.Abs(actual-row.GetProperty("probability").GetDouble())<1e-12,"independent finite-wall probability");
            }
            var normal=Chapter412Smoke.State(root.GetProperty("matrix")[0].GetProperty("payload"));
            var one=Chapter412Smoke.State(root.GetProperty("matrix")[2].GetProperty("payload"));
            var pass=one.PublicEvents.First(e=>e.Type==SichuanPublicEventType.Pass);
            var before=rule.Evaluate(one).UsedRefusals;
            one.PublicEvents.Add(pass with{EventIndex=99999});
            Check(rule.Evaluate(one).UsedRefusals==before,"duplicate offer counted twice");
            // Reusing a complete state after checkpoint recovery preserves the
            // same budget; changing private opponent flags cannot alter it.
            one.IsReady[1]=true;one.IsCalled[2]=true;
            Check(rule.Evaluate(one).UsedRefusals==before,"history recovery/private flags");
            foreach(var row in root.GetProperty("books").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));var expected=rule.Evaluate(s);
                s.IsReady[1]=true;s.IsCalled[2]=true;s.PassedHu18[3][11]=9;
                Check(JsonSerializer.Serialize(expected)==JsonSerializer.Serialize(rule.Evaluate(s)),"private opponent flags changed book policy");
                for(int shift=1;shift<3;shift++)
                {
                    int Map(int t)=>t<0?t:((t/9+shift)%3)*9+t%9;
                    int[] Rotate(int[] a){var b=new int[27];for(int t=0;t<27;t++)b[Map(t)]=a[t];return b;}
                    var r=SichuanStateCodec.FromRaw(0,0,s.CurrentSeat,s.WallCount,Rotate(s.Hand18),Rotate(s.Visible18),Rotate(s.Remaining18),
                        discards18:s.Discards18.Select(a=>a.Select(Map)),melds18:s.Melds18.Select(a=>a.Select(Map)),
                        dingQueSuits:s.DingQueSuits.Select(a=>(a+shift)%3),handCounts:s.HandCounts,activeSeats:s.ActiveSeats);
                    for(int seat=0;seat<4;seat++)r.MeldViews[seat].AddRange(s.MeldViews[seat].Select(m=>m with{TileType=Map(m.TileType)}));
                    r.PublicEvents.AddRange(s.PublicEvents.Select(e=>e with{TileType=Map(e.TileType)}));
                    var result=rule.Evaluate(r);
                    Check(result.Applies==expected.Applies && result.AllowsRefusal==expected.AllowsRefusal
                        &&result.RefusalLimit==expected.RefusalLimit &&result.UnseenWaitCopies==expected.UnseenWaitCopies,"suit-equivariant wide bed");
                }
            }
            var report=new{passed=true,checks,rows};
            File.WriteAllText(Path.Combine(folder,"rule_results.json"),JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"chapter413: PASS checks={checks} books=4 matrix=144 probabilityRows={root.GetProperty("probabilities").GetArrayLength()}");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine($"chapter413: FAIL after {checks}: {e}");return 1;}
    }
}
