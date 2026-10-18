using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

/// <summary>Incremental gang-discard cost, separate from ordinary deal-in loss.
/// Conditional payments follow the rules; opponent wait probabilities and the
/// ordinary hand-score proxy remain uncalibrated public estimates.</summary>
public static class SichuanGangDiscardLiability
{
    public static double ExtraPayment(double ordinaryRonScore, double gangCash,
        SichuanRuleSnapshot? rules = null)
    {
        rules ??= SichuanRuleSnapshot.Frozen;
        var ordinary = Math.Max(0, ordinaryRonScore);
        var cap = rules.FanCap > 0 ? rules.BaseScore * Math.Pow(2, rules.FanCap) : double.PositiveInfinity;
        var gangRon = Math.Min(cap, ordinary * 2);
        return Math.Max(0, gangRon - Math.Min(cap, ordinary))
            + (rules.EnableHuJiaoTransfer ? Math.Max(0, gangCash) : 0);
    }

    public static double? CurrentGangCash(SichuanStateView state)
    {
        var recent = state.PublicEvents.LastOrDefault(e => e.Type is not
            (SichuanPublicEventType.Draw or SichuanPublicEventType.Pass));
        var recentOwnGang = recent?.Seat == state.SeatIndex && recent.Type is
            SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang;
        // A past gang or an unrelated player's replacement draw is not enough.
        if (state.CurrentSeat != state.SeatIndex ||
            !(state.OwnDrawReason == "gang_draw" && (state.LastGangSeat == state.SeatIndex || recentOwnGang)
              || state.OwnDrawReason.Length == 0 && recentOwnGang)) return null;
        SichuanMeldType? kind = recentOwnGang ? recent!.Type switch
        {
            SichuanPublicEventType.MeldedGang => SichuanMeldType.MeldedGang,
            SichuanPublicEventType.AddedGang => SichuanMeldType.AddedGang,
            _ => SichuanMeldType.ConcealedGang
        } : state.LastGangType switch
        {
            "melded_gang" => SichuanMeldType.MeldedGang,
            "add_gang" => SichuanMeldType.AddedGang,
            "an_gang" => SichuanMeldType.ConcealedGang,
            _ => (SichuanMeldType?)null
        };
        if (kind is null) return null;
        var scoreEligible = kind != SichuanMeldType.AddedGang
            || recentOwnGang && recent!.GangScoreEligible
            || !recentOwnGang && state.LastGangScoreEligible;
        var source = recentOwnGang && recent!.SourceSeat >= 0 ? recent.SourceSeat : state.LastGangSourceSeat;
        var payers = Enumerable.Range(0,4).Where(s => s != state.SeatIndex && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        var cash = new SichuanSettlementProjectionEngine().ProjectScenario(new SichuanSettlementScenario(
            GangEvents: new[] { new SichuanGangScoreEvent(state.SeatIndex,kind.Value,payers,SourceSeat:source,ScoreEligible:scoreEligible) }));
        return cash.GangChanges[state.SeatIndex];
    }

    // Only for conditioning the later refund model, not for summing payments.
    // Joint winner outcomes are unavailable here: this is explicitly an
    // independence approximation, re-evaluated from public marginal evidence.
    public static double NoImmediateHuProbability(SichuanStateView state, int tile, SichuanBeliefSnapshot belief)
    {
        var survival = 1.0;
        foreach (var seat in Enumerable.Range(0,4))
        {
            if (seat == state.SeatIndex || !state.ActiveSeats[seat] || state.HasHu[seat]
                || state.DingQueSuits[seat] == tile / 9) continue;
            survival *= 1 - Math.Clamp(belief.SeatTileWaitProbability.GetValueOrDefault(seat)
                ?.GetValueOrDefault(tile,0) ?? 0,0,1);
        }
        return survival;
    }

    public static double ExpectedExtraLoss(SichuanStateView state, int discardedTile,
        SichuanBeliefSnapshot belief, double? projectedGangCash = null)
    {
        var cash = projectedGangCash ?? CurrentGangCash(state);
        if (cash is null || discardedTile is < 0 or >= 27) return 0;
        var loss = 0.0;
        foreach (var seat in Enumerable.Range(0,4))
        {
            if (seat == state.SeatIndex || !state.ActiveSeats[seat] || state.HasHu[seat]
                || state.DingQueSuits[seat] == discardedTile / 9) continue;
            var probability = Math.Clamp(belief.SeatTileWaitProbability.GetValueOrDefault(seat)
                ?.GetValueOrDefault(discardedTile,0) ?? 0,0,1);
            // Same ordinary-score proxy as unified multi-Hu risk. Summing
            // marginal per-winner payments handles multiple Hu without assuming
            // independent winners; the game's transfer is charged per winner.
            var ordinaryScore = 2.0 + Math.Min(4,state.MeldCount(seat)) * 0.75;
            loss += probability * ExtraPayment(ordinaryScore,cash.Value);
        }
        return loss;
    }
}
