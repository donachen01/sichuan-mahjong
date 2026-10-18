using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanFourthCopySupply(int Tile, double OwnDrawOpportunity,
    double ForcedOfferOpportunity, double GangCashIfAvailable)
{
    public double AcquisitionOpportunity => OwnDrawOpportunity + ForcedOfferOpportunity;
}

/// <summary>Conditional finite-wall arithmetic, using public clearance only.
/// The fixed schedule excludes claims and early exits. An opportunity is not
/// a realized Gang or a calibrated whole-round win probability.</summary>
public static class SichuanSingleLaneSupply
{
    public static bool HasKnownWallSuit(SichuanStateView state, int suit)
        => suit is >= 0 and < 3 && state.SeatIndex is >= 0 and < 4
            && state.CurrentSeat is >= 0 and < 4 && state.WallCount > 0
            && state.HandCounts[state.SeatIndex] == state.Hand18.Sum()
            && Enumerable.Range(0,27).All(t => state.Hand18[t] is >= 0 and <= 4
                && state.Visible18[t] is >= 0 and <= 4 && state.Remaining18[t] is >= 0 and <= 4
                && state.Hand18[t] + state.Visible18[t] + state.Remaining18[t] == 4)
            && state.Remaining18.Sum() == state.WallCount + Enumerable.Range(0, 4)
                .Where(s => s != state.SeatIndex).Sum(s => state.HandCounts[s])
            && Enumerable.Range(0, 4).Where(s => s != state.SeatIndex && state.HandCounts[s] > 0)
                .All(s => state.DingQueSuits[s] == suit
                    && (state.HasHu[s] || SichuanOpponentTimeline.MustHaveClearedMissing(state, s)))
            && state.Remaining18.Skip(suit * 9).Take(9).Sum() <= state.WallCount;

    public static int[] DrawSchedule(SichuanStateView state)
    {
        var seats = new List<int>(); var from = state.CurrentSeat;
        for (int i = 0; i < state.WallCount; i++)
        {
            var next = Enumerable.Range(1, 4).Select(step => (from - step + 8) % 4)
                .FirstOrDefault(s => state.ActiveSeats[s] && !state.HasHu[s], -1);
            if (next < 0) break;
            seats.Add(next); from = next;
        }
        return seats.ToArray();
    }

    // A uniformly ordered known wall sampled without replacement. Other
    // players' forced discards consume copies even if we decline their Ron.
    public static double HitProbability(int wall, int copies, int positions)
    {
        if (wall <= 0 || copies <= 0 || positions <= 0) return 0;
        copies = Math.Min(copies, wall); positions = Math.Min(positions, wall);
        if (positions > wall - copies) return 1;
        double miss = 1;
        for (int i = 0; i < positions; i++) miss *= (wall - copies - i) / (double)(wall - i);
        return 1 - miss;
    }

    public static double? ReadySelfDrawProbability(SichuanStateView state, IEnumerable<int> waits)
    {
        var tiles = waits.Distinct().ToArray();
        if (tiles.Length == 0 || tiles.Select(t => t / 9).Distinct().Count() != 1
            || !HasKnownWallSuit(state, tiles[0] / 9)) return null;
        return HitProbability(state.WallCount, tiles.Sum(t => state.Remaining18[t]),
            DrawSchedule(state).Count(s => s == state.SeatIndex));
    }

    public static SichuanFourthCopySupply? FourthCopy(SichuanStateView state, int tile)
    {
        if (tile is < 0 or > 26 || state.Hand18[tile] != 3
            || state.Remaining18[tile] != 1 || !HasKnownWallSuit(state, tile / 9)) return null;
        // The final wall tile cannot support a replacement draw. All earlier
        // positions either reach us or are forcibly offered by a missing seat.
        var eligible = DrawSchedule(state).Take(Math.Max(0, state.WallCount - 1)).ToArray();
        double own = eligible.Count(s => s == state.SeatIndex) / (double)state.WallCount;
        double offered = eligible.Count(s => s != state.SeatIndex) / (double)state.WallCount;
        var payers = Enumerable.Range(0, 4).Count(s => s != state.SeatIndex
            && state.ActiveSeats[s] && !state.HasHu[s]);
        return new(tile, own, offered, own * payers * 2 + offered * (payers + 1));
    }
}
