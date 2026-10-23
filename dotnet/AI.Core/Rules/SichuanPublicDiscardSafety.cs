using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

/// <summary>A one-way impossibility proof from public copy limits. True means
/// only "not ruled out", never a prediction that the opponent is ready.
/// Every legal Sichuan winning hand must use the incoming tile in a pair,
/// triplet or same-suit sequence (seven pairs also requires a pair).
/// No concealed hand, sampled wall or statistical zero is used.</summary>
public static class SichuanPublicDiscardSafety
{
    public static bool MayRon(SichuanStateView s, int opponent, int tile)
    {
        if (tile is < 0 or > 26 || opponent is < 0 or > 3) return true;
        if (opponent == s.SeatIndex || !s.ActiveSeats[opponent] || s.HasHu[opponent]
            || s.DingQueSuits[opponent] == tile / 9) return false;
        if (s.InformationMode != "public" || s.SeatIndex is < 0 or > 3
            || s.Hand18[tile] <= 0 || !CoherentCopyLimits(s)) return true;
        // The incoming copy is still in our hand and is not part of Remaining18.
        // Pair feasibility subsumes triplet feasibility for this conservative test.
        if (s.Remaining18[tile] >= 1) return true;
        if (s.MeldCount(opponent) >= 4) return false;
        var rank = tile % 9;
        for (var start = Math.Max(0, rank - 2); start <= Math.Min(6, rank); start++)
        {
            var first = tile / 9 * 9 + start;
            if (Enumerable.Range(first, 3).All(t => t == tile || s.Remaining18[t] > 0))
                return true;
        }
        return false;
    }

    public static bool AnyMayRon(SichuanStateView s, int tile)
        => Enumerable.Range(0, 4).Any(seat => MayRon(s, seat, tile));

    private static bool CoherentCopyLimits(SichuanStateView s)
    {
        for (var t = 0; t < 27; t++)
            if (s.Visible18[t] < 0 || s.Hand18[t] < 0 || s.Visible18[t] + s.Hand18[t] > 4
                || s.Remaining18[t] != 4 - s.Visible18[t] - s.Hand18[t]) return false;
        for (var seat = 0; seat < 4; seat++)
            foreach (var group in s.Melds18[seat].GroupBy(t => t))
                if (group.Key is < 0 or > 26 || s.Visible18[group.Key] < group.Count()) return false;
        return true;
    }
}
