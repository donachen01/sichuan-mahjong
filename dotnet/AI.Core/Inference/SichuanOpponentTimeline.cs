using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanOpponentTimeline(int TurnsSinceNonMissingDiscard,
    int RecentHandDiscards, int RecentDrawDiscards, int RecentCentralDiscards,
    bool LastDiscardWasMissing)
{
    public static SichuanOpponentTimeline Build(SichuanStateView state, int seat)
    {
        var discards = state.PublicEvents.Where(e => e.Seat == seat
            && e.Type == SichuanPublicEventType.Discard && e.TileType is >= 0 and < 27).ToArray();
        if (discards.Length == 0) return new(-1, 0, 0, 0, false);
        var missing = state.DingQueSuits[seat];
        var cleared = Array.FindLastIndex(discards, e => e.TileType / 9 != missing);
        var recent = discards.TakeLast(4).ToArray();
        return new(cleared < 0 ? -1 : discards.Length - 1 - cleared,
            recent.Count(e => e.Origin == SichuanTileOrigin.Hand),
            recent.Count(e => e.Origin == SichuanTileOrigin.Draw),
            recent.Count(e => e.TileType / 9 != missing && e.TileType % 9 is >= 2 and <= 6),
            discards[^1].TileType / 9 == missing);
    }

    // At the post-discard / waiting boundary, once a player has legally
    // discarded a non-missing tile they cannot retain missing-suit tiles:
    // subsequent missing draws must be discarded immediately. Do not apply
    // this constraint between their draw and discard or to inactive winners.
    public static bool MustHaveClearedMissing(SichuanStateView state, int seat)
        => !state.HasHu[seat] && state.ActiveSeats[seat]
            && state.HandCounts[seat] == 13 - 3 * Math.Max(state.MeldViews[seat].Count, state.Melds18[seat].Count / 3)
            && state.DingQueSuits[seat] is >= 0 and < 3
            && (state.PublicEvents.Any(e => e.Seat == seat && e.Type == SichuanPublicEventType.Discard
                    && e.TileType is >= 0 and < 27 && e.TileType / 9 != state.DingQueSuits[seat])
                || state.Discards18[seat].Any(t => t is >= 0 and < 27 && t/9 != state.DingQueSuits[seat]));
}
