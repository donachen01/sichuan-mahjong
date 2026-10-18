using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class DevelopmentPolicySmoke
{
    public static int Run(bool includeRollout = true)
    {
        try
        {
            var policy=new SichuanDevelopmentPolicy();
            var wide=Book([18,18,19,20,21,24,25,26,11,12,13,15,16],14);
            var plan=policy.Evaluate(wide);
            Check(plan.TargetSuit==1 && plan.LiveWaits==7 && plan.AllowsRefusal,"4-4 wide lane");
            Check(policy.ShouldRefuse(wide,14,SichuanWinType.Discard),"wide public selfdraw continuation");
            for(var i=0;i<8;i++)wide.PublicEvents.Add(new(5+i,5+i,0,SichuanPublicEventType.Pass,14,CanHu:true));
            Check(policy.Evaluate(wide).AllowsRefusal,"single lane incorrectly uses eighth-turn/two-pass cutoff");
            var a=Book([18,18,19,20,21,24,25,26,11,12,13,16,17],15);
            Check(policy.Evaluate(a).LiveWaits==3 && policy.Evaluate(a).AllowsRefusal,"4-5 A safe");
            a.Remaining18[15]=2;a.Visible18[15]++;
            Check(!policy.Evaluate(a).AllowsRefusal,"two copies plain take hu");
            var b=Book([19,20,21,24,25,26,10,10,13,13,13,16,17],15);
            b.Remaining18[15]=2;b.Visible18[15]++;
            Check(policy.Evaluate(b).Goal=="wait_live_gang" && policy.Evaluate(b).AllowsRefusal,"4-5 B gang route");
            var cashedHand=(int[])b.Hand18.Clone();cashedHand[13]-=3;
            var cashedVisible=(int[])b.Visible18.Clone();cashedVisible[13]=4;
            var cashed=SichuanStateCodec.FromRaw(0,0,1,b.WallCount-1,cashedHand,cashedVisible,
                dingQueSuits:[0,1,1,1],handCounts:[10,13,13,13]);
            cashed.MeldViews[0].Add(new(SichuanMeldType.ConcealedGang,13,0,5));
            cashed.Melds18[0].AddRange([13,13,13,13]);cashed.PublicEvents.AddRange(b.PublicEvents);
            cashed.PublicEvents.Add(new(5,5,0,SichuanPublicEventType.Pass,15,CanHu:true));
            cashed.PublicEvents.Add(new(6,6,0,SichuanPublicEventType.ConcealedGang,13));
            Check(policy.Evaluate(cashed).GangRealized&&!policy.Evaluate(cashed).AllowsRefusal,"gang cashed exit");
            b.Remaining18[13]=0;b.Visible18[13]++;
            Check(policy.Evaluate(b).Goal!="wait_live_gang","dead fourth tile kept gang plan");
            var danger=Book([18,18,19,20,21,24,25,26,11,12,13,15,16],14);
            for(var i=0;i<3;i++)danger.MeldViews[2].Add(new(SichuanMeldType.Peng,i,-1,0));
            Check(policy.Evaluate(danger).Danger==1 && policy.Evaluate(danger).RefusalLimit==2,"general danger budget");
            danger.PublicEvents.Add(new(20,20,0,SichuanPublicEventType.Pass,14,CanHu:true));
            danger.PublicEvents.Add(new(21,21,0,SichuanPublicEventType.Pass,14,CanHu:true));
            Check(!policy.Evaluate(danger).AllowsRefusal,"general danger exhausted budget");
            danger.MeldViews[2].Add(new(SichuanMeldType.Peng,3,-1,0));
            Check(policy.Evaluate(danger).Danger==2&&!policy.Evaluate(danger).AllowsRefusal,"major danger exit");
            var decision=new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(danger,14,1,"discard");
            Check(decision.SelectedAction==SichuanActionType.Hu&&decision.Reasons.Contains("DEVELOPMENT_TAKE_HU"),"live Hu gate");
            // Querying, snapshotting and replay must not renew/spend refusal budget.
            wide.EventVersion=12;wide.RoundId="development-memory";wide.HostGeneration=1;wide.ViewVersion=1;
            var host=new SichuanRoundAgentHost();host.Begin([wide]);
            Check(host.Inspect(wide).Plan?.DevelopmentPlan?.UsedRefusals==8,"agent memory");
            var saved=host.Capture(wide);host.End(wide.RoundId,1);wide.HostGeneration=2;
            host.Restore([wide],[saved]);Check(host.Inspect(wide).Plan?.DevelopmentPlan?.UsedRefusals==8,"checkpoint memory");
            host.End(wide.RoundId,2);
            // A same-distance Peng changes a live wait from a contested suit
            // to the exclusive suit. Exhausted copies cannot manufacture gain.
            var change=Book([18,18,18,19,20,21,24,25,26,10,10,11,12],10);
            var equal=new List<(int Tile,SichuanPengImprovement Gain)>();
            for(var d=0;d<27;d++)if(change.Hand18[d]-(d==10?2:0)>0)
            {
                var g=policy.EvaluatePeng(change,10,d);
                if(g.Improves&&g.BeforeDistance==g.AfterDistance)equal.Add((d,g));
            }
            Console.WriteLine("equal-distance improvements="+string.Join(',',equal.Select(x=>x.Tile)));
            Check(equal.Count>0,"same-distance improvement rejected");
            var supplyExample=Book([18,18,18,19,20,21,24,25,26,10,10,12,12],10);
            var supplyGain=policy.EvaluatePeng(supplyExample,10,19);
            Check(supplyGain.Improves&&supplyGain.BeforeDistance==0&&supplyGain.AfterDistance==0
                &&supplyGain.AfterSupply>supplyGain.BeforeSupply,"same-ready wait supply improvement");
            // 独占筒子：2334 筒原听 3 筒，碰 3 筒打 2 筒后改听 4 筒；
            // 上听数仍为 0，但已经公开的 3 筒使原听口更窄。
            var laneExample=Book([18,18,18,19,20,21,24,25,26,10,11,11,12],11);
            var laneGain=policy.EvaluatePeng(laneExample,11,10);
            Check(laneGain.Improves&&laneGain.BeforeDistance==0&&laneGain.AfterDistance==0
                &&laneGain.AfterSupply>laneGain.BeforeSupply,"exclusive-suit changed wait rejected");
            var clearedDensity=SichuanDevelopmentPolicy.Density(laneExample,12,laneExample.Remaining18);
            laneExample.PublicEvents.Clear();foreach(var river in laneExample.Discards18)river.Clear();
            Check(SichuanDevelopmentPolicy.Density(laneExample,12,laneExample.Remaining18)<clearedDensity,
                "declared missing suit falsely proves all copies in wall");
            var chosen=policy.SelectPengDiscard(change,10,equal[0].Tile);
            var pre=(int[])change.Hand18.Clone();pre[10]-=2;
            var projected=SichuanUnifiedDecisionEngine.ProjectPengContinuation(change,pre,10,1);
            Check(policy.SelectLiveDiscard(projected,equal[0].Tile)==chosen,"projected/live Peng disagreement");
            var liveDiscard=new SichuanDecisionEngine().DecideDiscard(projected,true).Action.TileType;
            var liveReaction=new SichuanReactionDecisionEngine().DecideReaction(change,10,false,true,false,1,forceLightweight:true);
            Check(liveReaction.FutureSummary.Contains($"PENG_PLANNED_DISCARD_{liveDiscard}"),"live reaction plans a different actual discard");
            var improvement=policy.EvaluatePeng(change,10,chosen);
            Check(improvement.AddedGangChance>0,"live fourth tile option");
            change.Remaining18[10]=0;change.Visible18[10]++;
            Check(policy.EvaluatePeng(change,10,chosen).AddedGangChance==0,"dead fourth tile valued");
            var heldFourth=Book([18,18,18,20,21,24,25,26,10,10,10,11,12],10);
            Check(policy.EvaluatePeng(heldFourth,10,18).AddedGangChance==0,"held fourth tile has no Gang score");
            // Chapter 4-6 is evaluated, not an unconditional claim/break-ready rule.
            var pivot=Book([18,19,20,20,22,10,10,11,12,13,15,16,17],21);
            Console.WriteLine("4-6 plan="+policy.Evaluate(pivot).Goal);
            if(!includeRollout)
            {
                Console.WriteLine("development-policy local: PASS; full-wall research rollout excluded by explicit option");
                return 0;
            }
            var timer=System.Diagnostics.Stopwatch.StartNew();
            var report=new SichuanPublicEndgameEvaluator().AnalyzeHuContinuation(Book([18,18,19,20,21,24,25,26,11,12,13,15,16],14),14,1,samples:32,seed:1241);
            Check(report.Candidates.Count>=2,"complete single lane rollout: "+report.Status);
            Console.WriteLine($"single-lane samples={report.Samples} ms={timer.ElapsedMilliseconds}");
            Check(report.Candidates.All(c=>double.IsFinite(c.NetScore)),"nonfinite result");
            Console.WriteLine("future-refusals="+report.Candidates.First(c=>c.Action==SichuanActionType.Pass).ExpectedStrategicRefusals);
            Check(report.Candidates.First(c=>c.Action==SichuanActionType.Pass).ExpectedStrategicRefusals>0,"rollout still takes first future Hu");
            Console.WriteLine("development-policy: PASS");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
    private static SichuanStateView Book(int[] tiles,int offered)
    {
        var hand=new int[27];foreach(var t in tiles)hand[t]++;
        var visible=new int[27];visible[0]=3;visible[offered]++;
        var state=SichuanStateCodec.FromRaw(0,0,1,108-13-39-visible.Sum(),hand,visible,dingQueSuits:[0,1,1,1]);
        for(var i=1;i<4;i++){state.Discards18[i].Add(0);state.PublicEvents.Add(new(i,i,i,SichuanPublicEventType.Discard,0));}
        state.Discards18[1].Add(offered);state.PublicEvents.Add(new(4,4,1,SichuanPublicEventType.Discard,offered));
        state.EventVersion=4;return state;
    }
    private static void Check(bool value,string message){if(!value)throw new InvalidOperationException(message);}
}
