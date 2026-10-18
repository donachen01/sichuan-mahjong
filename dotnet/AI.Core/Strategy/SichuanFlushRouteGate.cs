using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

/// <summary>
/// Decides whether the optional flush lookahead is worth running. Every input is
/// visible to this seat; the unseen count is a supply ceiling, not a probability.
/// </summary>
public sealed class SichuanFlushRouteGate
{
    private readonly SichuanFlushStructureEngine _structure = new();

    public int FindReachableTarget(SichuanStateView state)
    {
        if (state.WallCount <= 0) return -1;
        var exposed = new int[27];
        var meldViews = state.MeldViews[state.SeatIndex];
        var meldCount = meldViews.Count > 0 ? meldViews.Count : state.MeldCount(state.SeatIndex);
        if (meldViews.Count > 0)
            foreach (var meld in meldViews)
                exposed[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        else
            foreach (var tile in state.Melds18[state.SeatIndex]) exposed[tile]++;

        var activePlayers = Math.Max(1, state.ActiveSeats.Count(active => active));
        var ownDrawBudget = (state.WallCount + activePlayers - 1) / activePlayers;
        var bestSuit = -1;
        var bestPriority = double.NegativeInfinity;
        for (var suit = 0; suit < 3; suit++)
        {
            if (suit == state.OwnDingQueSuit ||
                exposed.Where((count, tile) => count > 0 && tile / 9 != suit).Any()) continue;
            var held = state.Hand18.Skip(suit * 9).Take(9).Sum();
            var offSuit = state.Hand18.Sum() - held;
            var singleLane = Enumerable.Range(0, 4).Where(seat => seat != state.SeatIndex &&
                state.ActiveSeats[seat]).All(seat => state.DingQueSuits[seat] == suit);
            if (offSuit > 5 || (held < 8 && !(singleLane && held >= 6))) continue;
            var structure = _structure.Analyze(state.Hand18, state.Remaining18, exposed, suit, meldCount);
            if (structure.FeasiblePatterns == 0 || structure.MinimumAdditionalTiles > ownDrawBudget + 1 ||
                structure.UsefulDraws.Sum(tile => state.Remaining18[tile]) == 0) continue;
            var priority = held * 2.0 - offSuit - structure.MinimumAdditionalTiles + (singleLane ? 2 : 0);
            if (priority <= bestPriority) continue;
            bestPriority = priority;
            bestSuit = suit;
        }
        return bestSuit;
    }

    public bool HasReachableOpportunity(SichuanStateView state) => FindReachableTarget(state) >= 0;
}
