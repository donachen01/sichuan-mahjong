using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Executable counterpart of the public fixed-hand stopping price.
/// Does not borrow a refusal permission for Peng/Gang or special win types.</summary>
internal static class SichuanReadyStoppingPolicy
{
    internal static int RefusalBudget(SichuanStateView s)
    {
        var a=SichuanStrategyContract.Assess(s);
        return SichuanStrategyContract.CanRefuse(a,SichuanWinType.Discard)
            ?Math.Max(0,a.Development.RefusalLimit-a.Development.UsedRefusals):0;
    }
    internal static SichuanHuRefusalAssessment Refine(SichuanStateView s,SichuanHuRefusalAssessment old)
    {
        if(!SichuanLearningClosurePolicy.MayStop(s)||old.EffectiveWinType!=SichuanWinType.Discard
            ||old.LocalGangValue>0||SichuanOpponentWideBedDefense.Applies(s))return old;
        // Preserve the shared strategy's cash-out exits and refusal budget.
        int budget=RefusalBudget(s);if(budget==0)return old;
        var waiting=old.Waiting is {Supported:true} known?known:new SichuanHuWaitingModel().Estimate(s);
        if(!waiting.Supported||waiting.EffectiveSampleSize<8)return old;
        var belief=new SichuanBeliefEngine().Build(s);var wall=new SichuanWallAvailabilityEngine().Build(s,belief);
        var price=new SichuanReadyWaitPricing().Build(s,s.Hand18,wall.ExpectedCounts18);
        if(price is not {HasDrawableWait:true})return old;
        var groups=SichuanReadyRaceSupply.ForStopping(s,price);
        if(!SichuanReadyRaceSupply.SupportsStopping(groups))return old;
        int players=Math.Max(2,Enumerable.Range(0,4).Count(x=>s.ActiveSeats[x]&&!s.HasHu[x]));
        var chance=new SichuanActionTreeEvaluator().SearchChanceNodes(new(price.PublicDrawableMass,s.WallCount,players,
            SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(s,s.CurrentSeat,s.SeatIndex),
            price.WeightedSelfDrawPerPayer*(players-1),SichuanUnifiedDecisionEngine.EstimateOpponentWinPerDraw(s,belief,wall),2.5,
            MaxDraws:s.WallCount,ReadyGroups:groups,AllowRonRefusal:true,InitialRonLockScore:old.ImmediateHuGain,
            MaxRonRefusals:budget==int.MaxValue?budget:budget-1));
        // Keep the measured waiting-cost floor. A profitable conditional
        // model is not permission to pretend future misses carry no Ron cost.
        double cost=Math.Max(chance.ExpectedOpponentLoss,waiting.WaitingLoss);
        double net=chance.ExpectedOwnWinGain-cost,required=old.ImmediateHuGain+Math.Max(.25,old.ImmediateHuGain*.25);
        // The caller deducts WaitingLoss once. Supply raw continuation income
        // here, not an already-net value that would deduct it a second time.
        waiting=waiting with{OpponentSelfDrawLoss=waiting.OpponentSelfDrawLoss+Math.Max(0,cost-waiting.WaitingLoss)};
        return old with{Refuse=net>=required,LocalSelfDrawValue=chance.ExpectedOwnWinGain,LocalGangValue=0,RequiredValue=required,Waiting=waiting,
            Reasons=old.Reasons.Concat(new[]{"PUBLIC_READY_STOPPING_WITH_PASS_HU_LOCK",
                net>=required?"PUBLIC_STOPPING_PASS_CONFIRMED":"PUBLIC_STOPPING_CASH_OUT_CONFIRMED",
                $"当前确定胡 {old.ImmediateHuGain:F4}；公开等待总收入（含未来合法接胡） {chance.ExpectedOwnWinGain:F4}，等待成本底限 {cost:F4}，净值 {net:F4}，拒胡门槛 {required:F4}",
                "每次新观测重算；过胡先锁同价/低价接胡，本家后续正常摸牌才解除；不读取后墙"}).ToArray()};
    }
}
