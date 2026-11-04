using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>One publicly exclusive suit is a development/wait objective, even
/// when useful sets in the other legal suit make a flush impossible. This
/// nominates and preserves plans; it adds no monetary or tile-name bonus.</summary>
internal static class SichuanIndependentSuitObjective
{
    private static readonly AsyncLocal<bool> Suppressed = new();
    internal static IDisposable SuppressForResearch()
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        bool old=Suppressed.Value;Suppressed.Value=true;
        return new Restore(()=>Suppressed.Value=old);
    }
    private sealed class Restore(Action restore):IDisposable
    {public void Dispose()=>restore();}

    // A current-state policy comparison, not a backend failure fallback.
    internal static IDisposable ReferencePolicy()
    {
        bool old=Suppressed.Value;Suppressed.Value=true;
        return new Restore(()=>Suppressed.Value=old);
    }

    internal static int Suit(SichuanStateView state)
    {
        if(Suppressed.Value||!SichuanLearningClosurePolicy.Completion(state)
            ||state.InformationMode!="public"||state.OwnDingQueSuit is <0 or >2
            ||state.Hand18.Skip(state.OwnDingQueSuit*9).Take(9).Any(n=>n>0))return -1;
        return SichuanSingleLaneEvaluator.ResolveSuit(state);
    }

    internal static bool IsGoal(SichuanStateView state,SichuanReadyPrice price)
    {
        int suit=Suit(state);
        return suit>=0&&price.HasDrawableWait&&price.Waits.Any(w=>w.TileType/9==suit&&w.PublicWallWeight>0);
    }

    // Keep at most one acquisition per outstanding set, with the existing
    // three-event improvement horizon as a floor. Every transition is still
    // checked for legal copies, claims and a valid final wait. This is a search
    // bound, not an income threshold learned from a particular video.
    internal static int Radius(SichuanStateView state)=>Math.Max(3,4-state.OwnMeldCount);
}
