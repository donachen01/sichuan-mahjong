using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

/// <summary>Derive own-turn permissions for public research inputs.
/// The live game additionally validates concrete tile entities.</summary>
public sealed record SichuanOwnTurnActions(bool CanHu, int[] Concealed, int[] Added)
{
    public static SichuanOwnTurnActions FromState(SichuanStateView s)
    {
        if (s.Phase != 5 || s.CurrentSeat != s.SeatIndex || !s.ActiveSeats[s.SeatIndex] || s.HasHu[s.SeatIndex]
            || s.Hand18.Sum() + 3 * s.OwnMeldCount != 14)
            throw new InvalidOperationException("own_turn_requires_live_14_tile_window");
        bool cleared = s.OwnDingQueSuit is >= 0 and < 3
            && !s.Hand18.Skip(s.OwnDingQueSuit * 9).Take(9).Any(n => n > 0);
        var melds = Decision.SichuanDevelopmentPolicy.Melds(s, s.SeatIndex);
        bool huWindow = s.LastDrawOrigin == SichuanTileOrigin.Draw && s.LastDrawTileType is >= 0 and < 27
            || s.DealerSeat == s.SeatIndex && s.OwnDrawReason == "opening_discard"
                && s.Discards18.All(r => r.Count == 0) && s.Hand18.Sum() == 14;
        bool hu = huWindow && cleared && SichuanReadyWaitPricing.HasLegalOwnedContext(s, s.Hand18, melds)
            && new SichuanExactHandAnalyzer().IsWinning(s.Hand18, s.OwnMeldCount, s.OwnMeldCount == 0);
        var concealed = s.WallCount > 0 ? Enumerable.Range(0, 27)
            .Where(t => s.Hand18[t] == 4 && t / 9 != s.OwnDingQueSuit).ToArray() : [];
        var added = Enumerable.Range(0, 27).Where(t => SichuanAddedGangRules.CanUpgrade(s, t)).ToArray();
        return new(hu, concealed, added);
    }
}
