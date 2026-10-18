using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

public static class SichuanAddedGangRules
{
    public static bool CanUpgrade(SichuanStateView state, int tile)
    {
        var seat = state.SeatIndex;
        return seat is >= 0 and < 4 && tile is >= 0 and < 27
            && state.CurrentSeat == seat && state.ActiveSeats[seat] && !state.HasHu[seat]
            && state.WallCount > 0 && state.LastDrawOrigin == SichuanTileOrigin.Draw
            && state.LastDrawTileType is >= 0 and < 27 && state.Hand18[tile] == 1
            && tile / 9 != state.OwnDingQueSuit
            && state.MeldViews[seat].Any(m => m.Type == SichuanMeldType.Peng
                && m.TileType == tile && !m.AddedGangBlockedUntilOwnDraw);
    }
}
