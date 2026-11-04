using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanSingleLanePhase(int Suit, string Stage, int Wall,
    int InitialWall, int[] AllowedDiscards, bool AllLaneOnly)
{
    internal int[] AuxiliaryLooseDiscards { get; init; } = [];
    public bool Early => Suit >= 0 && Stage == "early";
    public string Code => Suit < 0 ? "PHASED_SINGLE_LANE_OUTSIDE_SCOPE"
        : $"PHASED_SINGLE_LANE_{Stage.ToUpperInvariant()}"
          + (Early && AllLaneOnly ? "_NO_AUXILIARY_LEGAL_DISCARD" : Early ? "_PREFER_RESERVE" : "_SELECTIVE");
}

/// <summary>Phased discard preference. Early means
/// the first third of the ordinary 55-tile draw wall, fixed before outcomes.
/// Phase depends on public wall progress, never candidate quality or a rival's
/// private readiness. The remaining two thirds use the shared route policy.
/// Legal Hu/Gang permissions and mandatory missing-suit discards are unchanged.</summary>
public static class SichuanPhasedSingleLanePolicy
{
    private static readonly AsyncLocal<bool> Suppressed = new();
    public const int InitialDrawWall = 27 * 4 - (4 * 13 + 1);

    internal static IDisposable SuppressForResearch()
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        return ExistingHuAuthority();
    }
    internal static IDisposable ExistingHuAuthority()
    {
        bool old=Suppressed.Value; Suppressed.Value=true;
        return new Restore(()=>Suppressed.Value=old);
    }
    private sealed class Restore(Action restore) : IDisposable
    { public void Dispose()=>restore(); }

    public static SichuanSingleLanePhase Describe(SichuanStateView s)
    {
        int missing=s.OwnDingQueSuit;
        var held=Enumerable.Range(0,27).Where(t=>s.Hand18[t]>0).ToArray();
        var legal=missing is >=0 and <3 && held.Any(t=>t/9==missing)
            ? held.Where(t=>t/9==missing).ToArray() : held;
        int suit=Suppressed.Value || s.SeatIndex is <0 or >3 || s.HasHu[s.SeatIndex]
            || !s.ActiveSeats[s.SeatIndex] ? -1 : SichuanIndependentSuitObjective.Suit(s);
        if(suit<0)return new(-1,"outside",s.WallCount,InitialDrawWall,legal,false);
        string stage=3*s.WallCount>2*InitialDrawWall?"early"
            :3*s.WallCount>InitialDrawWall?"middle":"late";
        var auxiliary=legal.Where(t=>t/9!=suit).ToArray();
        bool laneOnly=auxiliary.Length==0;
        return new(suit,stage,s.WallCount,InitialDrawWall,
            legal,laneOnly)
        {
            AuxiliaryLooseDiscards = auxiliary.Where(tile => IsLoose(s.Hand18, tile)).ToArray()
        };
    }

    private static bool IsLoose(int[] hand, int tile)
    {
        if (hand[tile] != 1) return false;
        int start = tile / 9 * 9;
        // Even a tile that belongs to several overlapping sequences is protected.
        for (int first = Math.Max(start, tile - 2); first <= Math.Min(tile, start + 6); first++)
            if (hand[first] > 0 && hand[first + 1] > 0 && hand[first + 2] > 0) return false;
        return true;
    }

    internal const string PreferredDiscardCode = "PHASED_SINGLE_LANE_PREFER_AUXILIARY";

    internal const string PreferredWaitCode = "PHASED_SINGLE_LANE_PREFER_READY_WAIT";

    internal static SichuanDecisionCandidate? PreferReadyWait(int suit, SichuanDecisionCandidate current,
        IEnumerable<SichuanDecisionCandidate> candidates)
    {
        static bool HasLaneWait(SichuanDecisionCandidate candidate, int lane) =>
            candidate.ReadyPrice?.Waits.Any(wait => wait.TileType / 9 == lane && wait.PublicWallWeight > 0) == true;

        if (HasLaneWait(current, suit)
            || current.ModeledOwnWinProbability is not double currentWin
            || current.ModeledSelfDrawProbability is not double currentDraw) return null;

        return candidates.Where(candidate => candidate.IsAdmissible && HasLaneWait(candidate, suit)
                && candidate.ModeledOwnWinProbability is double win && win > 0 && win >= currentWin
                && candidate.ModeledSelfDrawProbability is double draw && win - draw > currentWin - currentDraw
                && candidate.ExpectedNetScore >= current.ExpectedNetScore
                && candidate.DealInLoss <= current.DealInLoss
                && candidate.OpponentFutureLoss <= current.OpponentFutureLoss
                && candidate.GangGain >= current.GangGain)
            .OrderByDescending(candidate => candidate.ExpectedNetScore)
            .ThenByDescending(candidate => candidate.ModeledOwnWinProbability)
            .ThenBy(candidate => candidate.Action.TileType)
            .FirstOrDefault();
    }

    internal static bool PreservesDiscardQuality(SichuanCandidateDetail candidate, SichuanCandidateDetail incumbent)
        => candidate.Shanten <= incumbent.Shanten
            && (candidate.Shanten > 0 || candidate.WaitQualityScore >= incumbent.WaitQualityScore)
            && candidate.Danger <= incumbent.Danger
            && candidate.ExpectedDealInLoss <= incumbent.ExpectedDealInLoss
            && (!candidate.BreaksPair || incumbent.BreaksPair)
            && (!candidate.BreaksTriplet || incumbent.BreaksTriplet)
            && candidate.RouteLoss.All(incumbent.RouteLoss.Contains);

    internal static void Annotate(SichuanStateView s,SichuanDecisionResult result)
    {
        var p=Describe(s);if(p.Suit<0)return;
        result.Reasons=new[]{p.Code,$"PHASED_SINGLE_LANE_WALL_{p.Wall}_INITIAL_{p.InitialWall}"}
            .Concat(result.Reasons).Distinct().ToArray();
    }
    internal static void Annotate(SichuanStateView s,SichuanSelfActionDecisionResult result)
    {
        var p=Describe(s);if(p.Suit<0)return;
        result.Reasons=new[]{p.Code,$"PHASED_SINGLE_LANE_WALL_{p.Wall}_INITIAL_{p.InitialWall}"}
            .Concat(result.Reasons).Distinct().ToArray();
    }
    internal static void Annotate(SichuanStateView s,SichuanReactionDecisionResult result)
    {
        var p=Describe(s);if(p.Suit<0)return;
        result.Reasons=new[]{p.Code,$"PHASED_SINGLE_LANE_WALL_{p.Wall}_INITIAL_{p.InitialWall}"}
            .Concat(result.Reasons).Distinct().ToArray();
    }
}
