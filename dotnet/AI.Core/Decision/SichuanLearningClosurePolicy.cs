using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Shared public-information mechanisms validated during chapter-gap
/// closure. The pre-learning variant isolates the old mechanisms for research;
/// book identifiers and source-action labels never participate in policy.</summary>
internal static class SichuanLearningClosurePolicy
{
    // ExpectedOpponentLoss in ChanceResult is a payment by this player. It
    // must never use the strategic opponent-growth discount. The named control
    // isolates the old arithmetic, with every other current mechanism intact.
    internal static SichuanMahjong.AI.Core.Search.SichuanMultiPlayerUtilityInput OwnCash(
        SichuanStateView s, double win, double gang, double cha, double initialLoss,
        double ownFuturePayment, double otherGrowth, double exit, double uncertainty,
        int players, double confidence)
    {
        bool full=s.PolicyVariant is "current" or "adaptive_search_v1" or "gap_candidate" or "completion_candidate";
        return new(win,gang,cha,initialLoss,full?0:ownFuturePayment,otherGrowth,
            exit,uncertainty,players,confidence,FutureOwnPayment:full?ownFuturePayment:0,UsesOwnPaymentSeries:full);
    }
    internal static bool MonetaryClaims(SichuanStateView s)=>Completion(s)&&s.PolicyVariant!="before_round2_v1";
    internal static bool Completion(SichuanStateView s)=>s.PolicyVariant is "current" or "adaptive_search_v1" or "cash_cost_before_v1" or "before_round2_v1" or "completion_candidate" or "gap_candidate";
    internal static bool Stopping(SichuanStateView s)=>s.PolicyVariant is "current" or "adaptive_search_v1" or "cash_cost_before_v1" or "before_round2_v1" or "ready_stopping_candidate" or "gap_candidate";
    internal static bool Retention(SichuanStateView s)=>s.PolicyVariant is "current" or "adaptive_search_v1" or "cash_cost_before_v1" or "before_round2_v1" or "terminal_retention_candidate" or "gap_candidate";
    internal static bool MayStop(SichuanStateView s)=>Stopping(s)&&s.InformationMode=="public"
        &&s.LockedFans[s.SeatIndex]<0&&s.WallCount>0
        &&SichuanDistinctDingQueHuPolicy.AssessDanger(s,new())==0
        &&SichuanGangDiscardLiability.CurrentGangCash(s) is null;
}
