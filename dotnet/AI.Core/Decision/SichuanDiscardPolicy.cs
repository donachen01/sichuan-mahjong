using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Agents;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>One discard policy; branches fork their own plan and never publish.</summary>
public static class SichuanDiscardPolicy
{
    private static readonly AsyncLocal<int> LeafDepth = new();
    public static bool AtSearchLeaf => LeafDepth.Value > 0;

    public static SichuanRoundBrainSnapshot? ForkPlan(SichuanStateView source, SichuanStateView target, SichuanRoundBrainSnapshot? brain)
    {
        if(brain is null) return null;
        if(brain.SeatIndex!=source.SeatIndex || target.SeatIndex!=source.SeatIndex)
            throw new InvalidOperationException("discard_plan_seat_mismatch");
        var fork=new SichuanRoundBrainEngine();
        fork.Restore(source,new AgentBrainMemory(brain.Revision,brain.Stage,brain.PrimaryRoute,brain.FallbackRoute,
            brain.TargetSuit,brain.Commitment,new(brain.RouteWeights),brain.BrokenTriplets.ToArray(),brain.DecisionHistory.ToArray()));
        return fork.Observe(target);
    }

    public static SichuanDecisionResult Select(SichuanStateView state, SichuanRoundBrainSnapshot? brain = null,
        SichuanStateView? source = null, bool searchLeaf = false, bool rootContinuation = false)
    {
        using var branch = source is not null && !rootContinuation || searchLeaf ? SichuanSearchBudget.EnterBranch() : null;
        brain ??= SichuanPolicyExecutionScope.OwnPlan;
        if (brain is not null && brain.SeatIndex != state.SeatIndex)
            throw new InvalidOperationException("discard_plan_seat_mismatch");
        if(source is not null) brain=ForkPlan(source,state,brain);
        using var plan=SichuanPolicyExecutionScope.UseOwnPlan(brain);
        if(searchLeaf) LeafDepth.Value++;
        try { return new SichuanDecisionEngine().DecideDiscard(state, false, brain); }
        finally { if(searchLeaf) LeafDepth.Value--; }
    }
}
