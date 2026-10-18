using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Public distribution plus the user's defensive preference. This
/// never asserts readiness, inflates danger, or invents a financial penalty.</summary>
public static class SichuanOpponentWideBedDefense
{
    public const string ActiveCode = "OPPONENT_WIDE_BED_DEFENSE_ACTIVE";
    public static int ActiveSeat(SichuanStateView s)
    {
        if (s.SeatIndex is < 0 or > 3 || s.DingQueSuits.Any(d => d is < 0 or > 2)
            || s.HasHu[s.SeatIndex] || !s.ActiveSeats[s.SeatIndex]) return -1;
        for (int seat = 0; seat < 4; seat++)
            if (seat != s.SeatIndex && s.ActiveSeats[seat] && !s.HasHu[seat]
                && !s.PublicEvents.Any(e => e.Seat == seat && e.Type == SichuanPublicEventType.Hu)
                && s.DingQueSuits[seat] != s.OwnDingQueSuit
                && Enumerable.Range(0, 4).Where(i => i != seat).All(i => s.DingQueSuits[i] == s.OwnDingQueSuit)) return seat;
        return -1;
    }
    public static bool Applies(SichuanStateView s) => s.InformationMode == "public" && ActiveSeat(s) >= 0;

    public static SichuanCandidateDetail? SaferDiscard(SichuanStateView s,
        IReadOnlyList<SichuanCandidateDetail> candidates, int current)
    {
        if (!Applies(s)) return null;
        var b = candidates.Single(c => c.TileType == current);
        // Safety preference cannot silently destroy a live ready exit or
        // increase distance. Existing extreme/late defense retains authority.
        return candidates.Where(c => c.Shanten <= b.Shanten && c.Danger <= b.Danger
                && c.ExpectedDealInLoss <= b.ExpectedDealInLoss
                && (b.Shanten != 0 || b.LiveUkeire <= 0 || c.LiveUkeire > 0)
                && (c.Danger < b.Danger || c.ExpectedDealInLoss < b.ExpectedDealInLoss))
            .OrderBy(c => c.Danger).ThenBy(c => c.ExpectedDealInLoss).ThenBy(c => c.Shanten)
            .ThenByDescending(c => c.LiveUkeire).ThenByDescending(c => c.UnifiedActionValue)
            .ThenBy(c => c.TileType).FirstOrDefault();
    }

    public static int ReferenceDiscardRisk(SichuanStateView s, SichuanBeliefSnapshot belief)
    {
        bool missing = s.OwnDingQueSuit >= 0 && s.Hand18.Skip(s.OwnDingQueSuit * 9).Take(9).Any(n => n > 0);
        return Enumerable.Range(0, 27).Where(t => s.Hand18[t] > 0 && (!missing || t / 9 == s.OwnDingQueSuit))
            .Select(t => new SichuanDangerEngine().Evaluate(t, s, belief)).DefaultIfEmpty(0).Min();
    }

    public static bool SafeClaim(int beforeShanten, int beforeLive, int afterShanten,
        int afterLive, int referenceRisk, int forcedDiscardRisk)
        => afterShanten <= beforeShanten && forcedDiscardRisk <= referenceRisk
            && (beforeShanten != 0 || beforeLive <= 0 || afterShanten == 0 && afterLive > 0);

    public static bool SafeGang(SichuanStateView s, SichuanBeliefSnapshot belief,
        int beforeShanten, int beforeLive, SichuanMeldCounterfactual value)
    {
        if (!Applies(s)) return true;
        int reference = ReferenceDiscardRisk(s, belief);
        var branches = value.ReplacementBranches.Where(b => b.Weight > 0).ToArray();
        return branches.Length > 0 && branches.All(b => b.ImmediateWin || b.DiscardTile >= 0
            && SafeClaim(beforeShanten, beforeLive, b.Shanten, b.LiveUkeire, reference,
                new SichuanDangerEngine().Evaluate(b.DiscardTile, s, belief)));
    }
}
