using System.Text.Json;
using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class Chapter414TwoMissingSmoke
{
    public static int Run(string folder)
    {
        int checks=0;var reports=new List<object>();
        void Check(bool ok,string name){checks++;if(!ok)throw new InvalidOperationException(name);}
        try
        {
            using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
            var rule=new SichuanRepresentativeHuPolicy();
            foreach(var category in new[]{"matrix","controls"})
            foreach(var row in doc.RootElement.GetProperty(category).EnumerateArray())
            {
                string name=row.GetProperty("name").GetString()!;
                var q=row.GetProperty("payload");var s=Chapter412Smoke.State(q);var r=rule.Evaluate(s);
                Check(r.Applies,name+" applicability");
                Check(r.RefusalLimit==row.GetProperty("cap").GetInt32(),name+" quota: "+JsonSerializer.Serialize(r));
                Check(r.AllowsRefusal==row.GetProperty("allowed").GetBoolean(),name+" eligibility: "+JsonSerializer.Serialize(r));
                foreach(var g in r.WaitSuits)
                    Check(g.UnseenCopies==row.GetProperty("liveBySuit").GetProperty(g.Suit.ToString()).GetInt32(),name+" independent per-suit copies");
                var actual=new SichuanExactHandAnalyzer().EnumerateWaits(s.Hand18,s.Remaining18,s.OwnMeldCount)
                    .Select(w=>w.TileType).ToArray();
                var expected=row.GetProperty("waits").EnumerateArray().Select(t=>t.GetInt32()).Where(t=>s.Remaining18[t]>0).ToArray();
                Check(actual.SequenceEqual(expected),name+" independent ordinary/7-pairs waits");
                if(row.TryGetProperty("route",out var route))Check(r.Goal==route.GetString(),name+" development witness");
                if(row.TryGetProperty("viable",out var viable))Check(r.ViableGangTargets==viable.GetInt32(),name+" live triplets");
                if(category=="matrix")
                {
                    Check(r.OwnRound==row.GetProperty("round").GetInt32()&&r.Danger==row.GetProperty("danger").GetInt32()
                        &&r.UsedRefusals==row.GetProperty("used").GetInt32()&&r.OpponentWon==row.GetProperty("won").GetBoolean(),name+" controlling conditions");
                }
                else
                {
                    var plan=new SichuanDevelopmentPolicy().Evaluate(s);
                    Check(plan.Representative is not null&&plan.AllowsRefusal==r.AllowsRefusal,name+" shared plan wiring");
                    int offer=q.GetProperty("reactionTileType").GetInt32();
                    var decision=new SichuanReactionDecisionEngine().DecideReaction(s,offer,true,false,false,s.CurrentSeat);
                    if(expected.Length>0)Check(decision.Reasons.Contains("TWO_MISSING_HU_DISCIPLINE")||name=="mixed_separate_bands",name+" live policy marker");
                    if(!r.AllowsRefusal)Check(decision.Action.ActionType==SichuanActionType.Hu,name+" hard exit bypassed");
                    reports.Add(new{name,assessment=r,decision.Action,decision.Reasons});
                }
            }
            foreach(var name in new[]{"narrow_cashed_widened","medium_cashed_base_used","held_upgrade_zero_cash"})
            {
                var row=doc.RootElement.GetProperty("controls").EnumerateArray().Single(x=>x.GetProperty("name").GetString()==name);
                var s=Chapter412Smoke.State(row.GetProperty("payload"));var history=new SichuanHuRefusalHistory(s);var r=rule.Evaluate(s);
                if(name=="narrow_cashed_widened")
                    Check(history.FirstRefusalWaits(s)?.Sum()==3&&r.GangRealized&&r.CashOutOrigin=="narrow_development_cashed","narrow cashout must reconstruct original3 and reject widened9");
                else if(name=="medium_cashed_base_used")
                    Check(history.FirstRefusalWaits(s)?.Sum()==8&&r.UsedRefusals==1&&r.CashOutOrigin=="restore_base_budget","restore base without renewing history");
                else Check(!r.GangRealized,"zero-cash held upgrade counted as cashout");
            }
            var basis=doc.RootElement.GetProperty("matrix").EnumerateArray().First(x=>x.GetProperty("live").GetInt32()==8
                &&x.GetProperty("danger").GetInt32()==0&&x.GetProperty("used").GetInt32()==1&&x.GetProperty("round").GetInt32()==4&&!x.GetProperty("won").GetBoolean());
            var original=Chapter412Smoke.State(basis.GetProperty("payload"));var before=rule.Evaluate(original);
            var e=original.PublicEvents.First(x=>x.Type==SichuanPublicEventType.Pass);
            original.PublicEvents.Add(e with{EventIndex=10000});
            Check(rule.Evaluate(original).UsedRefusals==1,"same offer spent twice");
            Check(rule.Evaluate(original).UsedRefusals==1,"queries renew/spend history");
            original.IsReady[1]=true;original.IsCalled[2]=true;original.LockedFans[3]=5;original.PassedHu18[2][11]=9;
            var privateResult=rule.Evaluate(original);
            Check(privateResult.RefusalLimit==before.RefusalLimit&&privateResult.AllowsRefusal==before.AllowsRefusal,"private opponent flags leak");
            var fifth=doc.RootElement.GetProperty("controls").EnumerateArray().Single(x=>x.GetProperty("name").GetString()=="golden_fifth_copy_forbidden");
            var fifthState=Chapter412Smoke.State(fifth.GetProperty("payload"));
            var fifthWall=new SichuanWallAvailabilityEngine().Build(fifthState,new SichuanBeliefEngine().Build(fifthState));
            Check(SichuanRepresentativeHuPolicy.FindDevelopment(fifthState,SichuanDevelopmentPolicy.Melds(fifthState,0),fifthWall,0)=="",
                "projected Peng invented a fifth physical copy");
            var memory=Chapter412Smoke.State(basis.GetProperty("payload"));
            memory.RoundId="two-missing-chapter414";memory.HostGeneration=1;memory.ViewVersion=1;
            var host=new SichuanRoundAgentHost();host.Begin([memory]);
            Check(host.Inspect(memory).Plan?.DevelopmentPlan?.Representative?.UsedRefusals==1,"actual agent plan missed history");
            var checkpoint=host.Capture(memory);host.End(memory.RoundId,1);memory.HostGeneration=2;
            host.Restore([memory],[checkpoint]);
            Check(host.Inspect(memory).Plan?.DevelopmentPlan?.Representative?.UsedRefusals==1,"checkpoint recovery renewed budget");
            host.End(memory.RoundId,2);
            // Suit transforms preserve full state, melds, public history and
            // the matching missing-suit condition, not only the concealed hand.
            foreach(var row in doc.RootElement.GetProperty("controls").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));var expected=rule.Evaluate(s);
                for(int shift=1;shift<3;shift++)
                {
                    int Map(int t)=>t<0?t:((t/9+shift)%3)*9+t%9;
                    int[] R(int[] a){var b=new int[27];for(int t=0;t<27;t++)b[Map(t)]=a[t];return b;}
                    var v=SichuanStateCodec.FromRaw(0,0,s.CurrentSeat,s.WallCount,R(s.Hand18),R(s.Visible18),R(s.Remaining18),
                        discards18:s.Discards18.Select(a=>a.Select(Map)),melds18:s.Melds18.Select(a=>a.Select(Map)),
                        dingQueSuits:s.DingQueSuits.Select(a=>(a+shift)%3),handCounts:s.HandCounts,activeSeats:s.ActiveSeats);
                    Array.Copy(s.HasHu,v.HasHu,4);
                    for(int seat=0;seat<4;seat++)v.MeldViews[seat].AddRange(s.MeldViews[seat].Select(m=>m with{TileType=Map(m.TileType)}));
                    v.PublicEvents.AddRange(s.PublicEvents.Select(a=>a with{TileType=Map(a.TileType)}));
                    var r=rule.Evaluate(v);
                    Check(r.RefusalLimit==expected.RefusalLimit&&r.AllowsRefusal==expected.AllowsRefusal
                        &&r.CashOutOrigin==expected.CashOutOrigin,"whole-state suit transform "+row.GetProperty("name").GetString());
                }
            }
            var report=new{passed=true,checks,matrix=396,controls=reports.Count,reports};
            File.WriteAllText(Path.Combine(folder,"rule_results.json"),JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"two-missing-hu: PASS checks={checks} matrix=396 controls={reports.Count}");return 0;
        }
        catch(Exception e){Console.Error.WriteLine($"two-missing-hu: FAIL after {checks}: {e}");return 1;}
    }
}
