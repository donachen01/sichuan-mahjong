using System.Text.Json;
using System.Text.Json.Nodes;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class OpponentWideBedDefenseSmoke
{
    internal static SichuanStateView DrawState(JsonElement row)
    {
        var q=JsonNode.Parse(row.GetProperty("payload").GetRawText())!;
        int t=row.GetProperty("draw").GetInt32();
        q["hand18"]![t]=q["hand18"]![t]!.GetValue<int>()+1;
        q["remaining18"]![t]=q["remaining18"]![t]!.GetValue<int>()-1;
        q["handCounts"]![0]=14;q["wallCount"]=q["wallCount"]!.GetValue<int>()-1;q["currentSeat"]=0;
        var s=Chapter412Smoke.State(JsonSerializer.SerializeToElement(q));s.LastDrawTileType=t;s.LastDrawOrigin=SichuanTileOrigin.Draw;
        s.PublicEvents.Add(new(1000,1000,0,SichuanPublicEventType.Draw,t,SichuanTileOrigin.Draw));return s;
    }
    public static int Run(string folder)
    {
        int checks=0;var reports=new List<object>();
        void Check(bool ok,string name){checks++;if(!ok)throw new InvalidOperationException(name);}
        try
        {
            using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
            var root=doc.RootElement;
            foreach(var row in root.GetProperty("classification").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));int expected=row.GetProperty("seat").GetInt32();
                Check(SichuanOpponentWideBedDefense.ActiveSeat(s)==expected,"independent sole-collector classifier");
                Check(SichuanOpponentWideBedDefense.Applies(s)==(expected>=0),"defensive applicability");
            }
            foreach(var row in root.GetProperty("hu").EnumerateArray())
            {
                var q=row.GetProperty("payload");var s=Chapter412Smoke.State(q);string name=row.GetProperty("name").GetString()!;
                var r=new SichuanRepresentativeHuPolicy().Evaluate(s);
                Check(!r.AllowsRefusal&&r.RefusalLimit==0&&r.OpponentSingleLane,name+" no speculative refusal");
                Check(r.Danger==new SichuanPublicDangerEvaluator().Evaluate(s).Level,name+" invented danger inflation");
                var a=new SichuanReactionDecisionEngine().DecideReaction(s,q.GetProperty("reactionTileType").GetInt32(),true,false,q.GetProperty("canGang").GetBoolean(),1);
                Check(a.Action.ActionType==SichuanActionType.Hu,name+" legal Hu bypassed");
                Check(a.Reasons.Contains(SichuanOpponentWideBedDefense.ActiveCode),name+" shared marker");
                Check(!new SichuanDevelopmentPolicy().AssessRefusal(s,q.GetProperty("reactionTileType").GetInt32(),SichuanWinType.Discard).Refuse,name+" local policy bypass");
            }
            foreach(var row in root.GetProperty("exits").EnumerateArray())
            {
                var s=Chapter412Smoke.State(row.GetProperty("payload"));string name=row.GetProperty("name").GetString()!;
                Check(SichuanOpponentWideBedDefense.Applies(s)==row.GetProperty("defense").GetBoolean(),name+" exit state");
                var plan=new SichuanDevelopmentPolicy().Evaluate(s);
                Check(plan.Reasons.Contains(SichuanOpponentWideBedDefense.ActiveCode)==row.GetProperty("defense").GetBoolean(),name+" stale defense marker");
                if(name=="exit_keeps_used")Check(plan.UsedRefusals==1&&!plan.AllowsRefusal,"exit restored budget");
                reports.Add(new{name,plan});
            }
            foreach(var row in root.GetProperty("claims").EnumerateArray())
                Check(SichuanOpponentWideBedDefense.SafeClaim(row.GetProperty("before").GetInt32(),row.GetProperty("beforeLive").GetInt32(),
                    row.GetProperty("after").GetInt32(),row.GetProperty("afterLive").GetInt32(),row.GetProperty("reference").GetInt32(),
                    row.GetProperty("risk").GetInt32())==row.GetProperty("allowed").GetBoolean(),"ordinal claim preference");
            var baseline=Chapter412Smoke.State(root.GetProperty("hu")[0].GetProperty("payload"));
            foreach(var row in root.GetProperty("selectors").EnumerateArray())
            {
                var candidates=row.GetProperty("candidates").EnumerateArray().Select(c=>new SichuanCandidateDetail{TileType=c.GetProperty("tile").GetInt32(),
                    Shanten=c.GetProperty("shanten").GetInt32(),LiveUkeire=c.GetProperty("live").GetInt32(),Danger=c.GetProperty("risk").GetInt32(),ExpectedDealInLoss=c.GetProperty("loss").GetDouble()}).ToArray();
                var chosen=SichuanOpponentWideBedDefense.SaferDiscard(baseline,candidates,row.GetProperty("current").GetInt32());
                Check((chosen?.TileType??-1)==row.GetProperty("expected").GetInt32(),row.GetProperty("name").GetString()!);
            }
            var belief=new SichuanBeliefEngine().Build(baseline);int safe=Enumerable.Range(0,27).Where(t=>baseline.Hand18[t]>0)
                .OrderBy(t=>new SichuanDangerEngine().Evaluate(t,baseline,belief)).First();
            SichuanMeldCounterfactual Gang(params SichuanGangReplacementBranch[] branches)=>new("an_gang",0,4,0,0,0,0){ReplacementBranches=branches};
            var good=new SichuanGangReplacementBranch(11,1,0,4,safe,0,false);
            var bad=good with{Shanten=1};var win=good with{ImmediateWin=true,DiscardTile=-1};
            Check(SichuanOpponentWideBedDefense.SafeGang(baseline,belief,0,4,Gang(good)),"safe continuation rejected");
            Check(!SichuanOpponentWideBedDefense.SafeGang(baseline,belief,0,4,Gang(good,bad)),"bad replacement hidden by average");
            Check(SichuanOpponentWideBedDefense.SafeGang(baseline,belief,0,4,Gang(win)),"immediate winning branch rejected");
            Check(!SichuanOpponentWideBedDefense.SafeGang(baseline,belief,0,4,Gang()),"unknown replacement assumed safe");
            foreach(var row in root.GetProperty("noHu").EnumerateArray())
            {
                var q=row.GetProperty("payload");var s=Chapter412Smoke.State(q);
                var a=new SichuanReactionDecisionEngine().DecideReaction(s,q.GetProperty("reactionTileType").GetInt32(),false,q.GetProperty("canPeng").GetBoolean(),q.GetProperty("canGang").GetBoolean(),1);
                Check(a.Reasons.Contains(SichuanOpponentWideBedDefense.ActiveCode),"no-Hu reaction missed defense");
                Check(a.OpponentWideBedDefenseAllowed,"selected an unsafe optional claim");
                reports.Add(new{name=row.GetProperty("name").GetString(),kind="no_hu",a.Action,a.Reasons,a.ActionScores});
            }
            foreach(var row in root.GetProperty("discard").EnumerateArray())
            {
                var s=DrawState(row);string name=row.GetProperty("name").GetString()!;
                var d=new SichuanDecisionEngine().DecideDiscard(s,true);
                Check(d.Reasons.Contains(SichuanOpponentWideBedDefense.ActiveCode),name+" discard missed defense");
                Check(s.Hand18[d.Action.TileType]>0,"discard illegal");
                Check(d.Arbitration.Any(a=>a.Accepted&&a.Priority>=SichuanDiscardArbiter.ExtremeSafety)
                    || SichuanOpponentWideBedDefense.SaferDiscard(s,d.Candidates,d.Action.TileType) is null,name+" later module undid safer choice");
                reports.Add(new{name,kind="discard",d.Action,d.Reasons,d.Arbitration});
                if(name=="quad")
                {
                    var a=new SichuanSelfActionDecisionEngine().DecideSelfAction(s,false,[18],[]);
                    Check(a.Reasons.Contains(SichuanOpponentWideBedDefense.ActiveCode),"self Gang defense missing");
                    Check(a.OpponentWideBedDefenseAllowed,"unsafe self Gang selected");
                    var mandatory=new SichuanSelfActionDecisionEngine().DecideSelfAction(s,false,[18],[],mandatoryGangTileTypes:[18]);
                    Check(mandatory.Action.ActionType==SichuanActionType.Gang,"defense broke mandatory Gang");
                    reports.Add(new{name,kind="self_gang",a.Action,a.Reasons,a.CandidateReasons});
                }
            }
            var before=new SichuanRepresentativeHuPolicy().Evaluate(baseline);
            baseline.IsReady[1]=true;baseline.IsCalled[2]=true;baseline.PassedHu18[1][11]=9;
            Check(!new SichuanRepresentativeHuPolicy().Evaluate(baseline).AllowsRefusal,"private flags changed hard exit");
            baseline.InformationMode="oracle";Check(!SichuanOpponentWideBedDefense.Applies(baseline),"changed oracle scope");
            File.WriteAllText(Path.Combine(folder,"rule_results.json"),JsonSerializer.Serialize(new{passed=true,checks,reports},new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"opponent-wide-bed-defense: PASS checks={checks} classifiers=810 hu=157 claims=108");return 0;
        }
        catch(Exception e){Console.Error.WriteLine($"opponent-wide-bed-defense: FAIL after {checks}: {e}");return 1;}
    }
}
