using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanOpeningObservation(int Seat, int FirstClearDiscard, int FirstClearTurn,
    int[] RecentHandDiscards, int[] RecentDrawDiscards, int FocusSuit, bool Active)
{
    public static SichuanOpeningObservation Build(SichuanStateView state, int seat)
    {
        var missing = state.DingQueSuits[seat];
        var discards = state.PublicEvents.Where(e => e.Seat == seat && e.Type == SichuanPublicEventType.Discard
            && e.TileType is >= 0 and < 27).OrderBy(e => e.EventIndex).ToArray();
        var first = missing is >= 0 and < 3 ? Array.FindIndex(discards, e => e.TileType / 9 != missing) : -1;
        var hand = new int[3]; var draw = new int[3];
        if (first >= 0)
            foreach (var e in discards.Skip(first).TakeLast(4).Where(e => e.TileType / 9 != missing))
            {
                if (e.Origin == SichuanTileOrigin.Hand) hand[e.TileType / 9]++;
                if (e.Origin == SichuanTileOrigin.Draw) draw[e.TileType / 9]++;
            }
        var focus = -1;
        if (missing is >= 0 and < 3)
        {
            var allowed = Enumerable.Range(0, 3).Where(s => s != missing).ToArray();
            // More than one deliberate discard is a trend, not a probability.
            foreach (var abandoned in allowed)
            {
                var target = allowed.Single(s => s != abandoned);
                if (hand[abandoned] >= 2 && hand[target] == 0
                    && state.Melds18[seat].All(t => t / 9 == target)) focus = target;
            }
        }
        return new(seat, first < 0 ? -1 : first + 1, first < 0 ? -1 : discards[first].TurnIndex,
            hand, draw, focus, state.ActiveSeats[seat] && !state.HasHu[seat]);
    }
}
