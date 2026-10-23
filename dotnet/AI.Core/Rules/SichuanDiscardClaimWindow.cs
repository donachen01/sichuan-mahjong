using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

/// <summary>Public Hu closes meld claims on that discard, while permitting
/// other Hu responses. A later discard opens a different window.</summary>
public static class SichuanDiscardClaimWindow
{
    public static bool HuAlreadyClaimed(SichuanStateView state, int source, int tile)
    {
        var observedHu = false;
        for (var i = state.PublicEvents.Count - 1; i >= 0; i--)
        {
            var e = state.PublicEvents[i];
            if (e.Type == SichuanPublicEventType.Discard)
                return observedHu && e.Seat == source && e.TileType == tile;
            if (e.Type == SichuanPublicEventType.Hu && e.SourceSeat == source && e.TileType == tile)
                observedHu = true;
        }
        return observedHu;
    }
}
