using SichuanMahjong.AI.Core.Analysis;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class AddedGangRuleSmoke
{
    public static int Run()
    {
        var checks = 0;
        void Check(bool ok, string message) { checks++; if (!ok) throw new InvalidOperationException(message); }
        try
        {
            var own = Hand(18,18,19,20,21,24,25,26,12,13,14,15,16);
            var evaluator = new SichuanPublicEndgameEvaluator();
            foreach (var eligible in new[] { false, true })
            {
                var melds = Enumerable.Range(0,4).Select(_ => new List<SichuanMeldView>()).ToArray();
                melds[1].Add(new(SichuanMeldType.AddedGang,0,2,0));
                var world = HuIncomeCostSmoke.Fixture(own,[],1,11,melds:melds);
                world.State.DingQueSuits[1]=2;
                world.State.PublicEvents.Insert(world.State.PublicEvents.Count-1,
                    new(1000,1000,1,SichuanPublicEventType.AddedGang,0,SourceSeat:1,GangScoreEligible:eligible));
                for(var i=0;i<world.State.PublicEvents.Count;i++)
                    world.State.PublicEvents[i]=world.State.PublicEvents[i] with { EventIndex=i+1 };
                var root = SichuanPublicEndgameEvaluator.PrepareReactionRoot(world.State,11,1,"gang_discard");
                Check(root is not null && root.GangScoreEligible==eligible, "gang-discard root lost public eligibility");
                Check(SichuanPublicInferenceBoundary.TryProject(world.State,out var projected,out var reason,reaction:true,sourceSeat:1), "public projection: "+reason);
                SichuanPublicInferenceBoundary.RestorePolicyHistory(world.State,projected);
                Check(projected.PublicEvents.Single(e=>e.Type==SichuanPublicEventType.AddedGang).GangScoreEligible==eligible,
                    "public projection restored a zero-score gang");
                var hu = evaluator.Simulate(world.State,world.Particle,[],-1,reaction:root);
                Check(hu.WinGain==2 && hu.GangNet==(eligible?3:0), "gang-discard Hu/transfer amount");

                var state = SichuanStateCodec.FromRaw(0,0,0,8,new int[27],new int[27]);
                state.OwnDrawReason="gang_draw"; state.LastGangSeat=0;
                state.LastGangType="add_gang"; state.LastGangTileType=0;
                state.LastGangScoreEligible=eligible;
                state.LastDrawOrigin=SichuanTileOrigin.Draw; state.LastDrawTileType=8;
                Check(SichuanGangDiscardLiability.CurrentGangCash(state)==(eligible?3:0),
                    "replacement tile identity changed completed gang cash");
                var before=SichuanStateFingerprint.BuildTurnKey(state,true,false);
                state.LastGangScoreEligible=!eligible;
                Check(before!=SichuanStateFingerprint.BuildTurnKey(state,true,false),"gang score not in decision fingerprint");

                var pending = Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
                pending[1].Add(new(SichuanMeldType.Peng,11,2,0));
                var rob = HuIncomeCostSmoke.Fixture(own,[9],1,11,
                    new(){[1]=Hand(0,1,2,3,4,5,6,7,8,9)},pending);
                rob.State.DingQueSuits[1]=2;
                var robRoot = new SichuanPublicEndgameEvaluator.HuReactionRoot(11,1,SichuanWinType.RobAddedGang,
                    SichuanActionType.Pass,-1,SichuanMeldType.AddedGang,1,[0,2,3],[],eligible);
                var pass=evaluator.Simulate(rob.State,rob.Particle,[9],-1,reaction:robRoot);
                var take=evaluator.Simulate(rob.State,rob.Particle,[9],-1,reaction:robRoot with{Action=SichuanActionType.Hu});
                Check(pass.GangNet==(eligible?-1:0),"passing rob-Gang used observer draw instead of actor eligibility");
                Check(take.GangNet==0 && take.WinGain==2,"robbed Gang still received cash");
                rob.State.HandCounts[1]++;
                rob.State.PendingAddedGangScoreEligible=eligible;
                var publicRoot=SichuanPublicEndgameEvaluator.PrepareReactionRoot(rob.State,11,1,"qiang_gang_hu");
                Check(publicRoot is not null && publicRoot.GangScoreEligible==eligible,"public pending root lost actor score metadata");
                rob.State.PendingAddedGangScoreEligible=null;
                Check(SichuanPublicEndgameEvaluator.PrepareReactionRoot(rob.State,11,1,"qiang_gang_hu") is null,
                    "missing public pending eligibility invented gang cash");

                var planHand=Hand(10,11,12,12,13,14,18,19,20,21);
                var visible=Hand(9,9,9,9,22,21);
                var planState=SichuanStateCodec.FromRaw(0,0,1,40,planHand,visible,
                    dingQueSuits:[0,1,1,1],handCounts:[10,13,13,13]);
                planState.MeldViews[0].Add(new(SichuanMeldType.AddedGang,9,1,4));
                planState.Melds18[0].AddRange([9,9,9,9]);
                planState.PublicEvents.AddRange([
                    new(1,1,0,SichuanPublicEventType.Peng,9,SourceSeat:1),
                    new(2,2,0,SichuanPublicEventType.Pass,21,SourceSeat:1,CanHu:true),
                    new(3,3,0,SichuanPublicEventType.Draw,22),
                    new(4,3,0,SichuanPublicEventType.AddedGang,9,GangScoreEligible:eligible),
                    new(5,3,0,SichuanPublicEventType.Draw,12),
                    new(6,3,0,SichuanPublicEventType.Discard,22),
                    new(7,4,1,SichuanPublicEventType.Discard,21)]);
                Check(new SichuanHuRefusalHistory(planState).GangRealized==eligible,"unscored gang counted as realized cash after refusal");
                Check(new SichuanDevelopmentPolicy().Evaluate(planState).GangRealized==eligible,"development plan treats structural gang as paid cash");
                var winning=(int[])planHand.Clone(); winning[21]++;
                Check(new SichuanFanProjectionEngine().Project(winning,planState.MeldViews[0],SichuanWinType.Discard).GenCount==1,
                    "zero gang cash must not erase structural Gen");
                planState.DingQueSuits=[0,0,1,2];
                Check(new SichuanDistinctDingQueHuPolicy().Evaluate(planState).GangRealized==eligible,
                    "distinct ding-que policy treats zero-score gang as cash-out");
            }
            Console.WriteLine($"ADDED_GANG_RULE roots PASS checks={checks}");

            foreach (var held in new[] { false, true })
            {
                var melds=Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
                melds[1].Add(new(SichuanMeldType.Peng,11,2,0));
                var wall=held?new[]{9,9}:new[]{11,9};
                var drawOwn=Hand(18,18,19,20,21,24,25,26,12,13,14,15,15);
                var world=HuIncomeCostSmoke.Fixture(drawOwn,wall,2,15,
                    new(){[1]=Hand(0,1,2,3,4,5,6,7,8,held?11:9)},melds);
                world.State.DingQueSuits[1]=2;
                var root=new SichuanPublicEndgameEvaluator.HuReactionRoot(15,2,SichuanWinType.Discard,
                    SichuanActionType.Pass,-1,SichuanMeldType.AddedGang,-1,[],[]);
                var result=evaluator.Simulate(world.State,world.Particle,wall,-1,reaction:root);
                Check(result.GangNet==(held?0:-1),$"actual draw -> self-action -> replacement cash held={held}: {result}");
                var added=result.Events.Where(e=>e.Seat==1 && e.Type==SichuanPublicEventType.AddedGang).ToArray();
                Check(held ? added.All(e=>!e.GangScoreEligible) : added.Length==1 && added[0].GangScoreEligible && result.OpponentLoss>0,
                    "actual chosen self-action lost drawn/held eligibility");
                Console.WriteLine($"ADDED_GANG_RULE continuation held={held} gang={result.GangNet} added={added.Length}");
            }

            // Historical cash must be refunded exactly once if the actor ends
            // unready. A zero-score gang creates no new refund obligation.
            foreach(var eligible in new[]{false,true})
            {
                var melds=Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
                melds[1].Add(new(SichuanMeldType.AddedGang,0,2,0));
                var world=HuIncomeCostSmoke.Fixture(own,[],2,11,
                    new(){[1]=Hand(1,1,3,3,5,5,7,7,9,10)},melds);
                world.State.DingQueSuits[1]=2;
                world.State.PublicEvents.Insert(0,new(0,0,1,SichuanPublicEventType.AddedGang,0,
                    SourceSeat:1,GangScoreEligible:eligible));
                var root=new SichuanPublicEndgameEvaluator.HuReactionRoot(11,2,SichuanWinType.Discard,
                    SichuanActionType.Pass,-1,SichuanMeldType.AddedGang,-1,[],[]);
                var result=evaluator.Simulate(world.State,world.Particle,[],-1,reaction:root);
                Check(result.GangNet==(eligible?1:0),"unready draw refund eligibility or original payer");
            }
            Console.WriteLine($"ADDED_GANG_RULE PASS checks={checks}; roots, transfer, rob cancellation, actual draw/self-action, refund");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine($"ADDED_GANG_RULE FAIL checks={checks}: {e}");return 1;}
    }
    private static int[] Hand(params int[] tiles){var h=new int[27];foreach(var t in tiles)h[t]++;return h;}
}
