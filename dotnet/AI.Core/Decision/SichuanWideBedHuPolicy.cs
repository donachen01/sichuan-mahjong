using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanWideBedHuAssessment(bool Applies, bool AllowsRefusal,
    int Suit, int UnseenWaitCopies, int UsedRefusals, int RefusalLimit, int Danger,
    bool KnownWallSuit, bool GangRealized, string Goal, int PengTile, int PengDiscard,
    string[] Reasons);

/// <summary>Chapter 4.1.3 plain-hand discipline. Public clearance establishes
/// exclusive supply; eligibility never replaces the current income/cost test.</summary>
public sealed class SichuanWideBedHuPolicy
{
    public SichuanWideBedHuAssessment Evaluate(SichuanStateView s)
    {
        var lane = SichuanSingleLaneEvaluator.ResolveSuit(s);
        SichuanWideBedHuAssessment Outside() => new(false, false, lane, 0, 0, 0, 0,
            false, false, "outside_plain_wide_bed", -1, -1, []);
        if (lane < 0) return Outside();
        var melds = SichuanDevelopmentPolicy.Melds(s, s.SeatIndex);
        if (!SichuanReadyWaitPricing.HasLegalOwnedContext(s, s.Hand18, melds)) return Outside();
        var price = new SichuanReadyWaitPricing().Build(s, s.Hand18,
            s.Remaining18.Select(n => (double)n).ToArray(), melds);
        if (price is null) return Outside();
        // A valuable completed route has its own strategy. A realistic close
        // flush is also outside this chapter's expressly plain-hand table.
        foreach (var w in price.Waits)
        {
            var hand = (int[])s.Hand18.Clone(); hand[w.TileType]++;
            var fan = new SichuanFanProjectionEngine().Project(hand, melds, SichuanWinType.Discard);
            if (fan.IsQingYiSe || fan.IsSevenPairs || fan.IsDaDuiZi || fan.IsJinGouDiao) return Outside();
        }
        var draws = SichuanDevelopmentPolicy.Draws(s);
        if (draws >= 2 && Enumerable.Range(0, 3).Any(suit => suit != s.OwnDingQueSuit
            && s.Hand18.Where((_, t) => t / 9 != suit).Sum() <= 2
            && melds.All(m => m.TileType / 9 == suit)))
        {
            var belief = new SichuanBeliefEngine().Build(s);
            var wall = new SichuanWallAvailabilityEngine().Build(s, belief);
            if (new SichuanRouteContinuationEvaluator().Evaluate(s, s.Hand18, wall)
                .Any(r => r.Route == "flush" && r.Reachable && r.DistanceToWin is > 0 and <= 3
                    && r.DistanceToWin <= draws && r.ExpectedWallCopies > 0)) return Outside();
        }
        var history = new SichuanHuRefusalHistory(s);
        var danger = new SichuanPublicDangerEvaluator().Evaluate(s).Level;
        var known = SichuanSingleLaneSupply.HasKnownWallSuit(s, lane);
        var live = price.Waits.Sum(w => s.Remaining18[w.TileType]);
        var laneWaits = price.Waits.All(w => w.TileType / 9 == lane);
        var scored = melds.Any(m => SichuanHuRefusalHistory.IsScoredGang(s, m));
        var cap = 0; var goal = "take_hu"; var peng = -1; var discard = -1;
        var reasons = new List<string> { "WIDE_BED_HU_DISCIPLINE", "SINGLE_LANE_HU_DISCIPLINE" };
        if (known && draws > 0 && danger < 2)
        {
            if(laneWaits)
            {
                var independent=SichuanIndependentTriplet.LiveTargets(s,lane).Length;
                (cap,goal)=SichuanConcealedTripletHuTable.WideBed(live,danger,independent);
                reasons.Add($"CONCEALED_TRIPLET_EXPLICIT_HU_TABLE_SAME_WAIT_SUIT: {independent}");
                if(goal is "wait_live_gang" or "wait_last_copy" && (scored||history.GangRealized))
                {cap=0;goal="cash_out";}
            }
            // No speculative multi-turn dismantling is smuggled into a Peng
            // exception. The projected claim + legal discard must really be
            // ready in the exclusive suit with better drawable supply.
            if (cap == 0 && danger == 0 && draws >= 3 && !laneWaits)
            {
                (peng, discard) = FindPeng(s, lane, price, melds);
                if (peng >= 0) { cap = 1; goal = "improve_exclusive_wait"; }
            }
        }
        if (history.GangRealized)
        {
            var first = history.FirstRefusalWaits(s);
            if (first is null || first[lane] <= 2 && first.Sum() <= 2)
            {
                cap = 0; goal = "cash_out";
                reasons.Add(first is null ? "WIDE_BED_CASHOUT_HISTORY_UNKNOWN" : "WIDE_BED_NARROW_GANG_CASHED");
            }
        }
        if (!known) reasons.Add("WIDE_BED_CLEARANCE_NOT_PROVEN_NO_EXCLUSIVE_BUDGET");
        if (draws == 0) reasons.Add("WIDE_BED_NO_FUTURE_OWN_DRAW");
        if (danger >= 2) reasons.Add("WIDE_BED_MAJOR_DANGER_EXIT");
        if (scored) reasons.Add("WIDE_BED_SCORED_GANG_REPRICE_IMMEDIATE_HU_NO_NEW_GANG_EXCEPTION");
        var allowed = draws > 0 && known && danger < 2 && history.Used < cap;
        reasons.Add($"宽床门 {lane}，未见听张 {live}，已拒胡 {history.Used}，额度 {cap}；不设第八巡硬截止，仍须实时收益支持");
        reasons.Add(allowed ? "WIDE_BED_REFUSAL_ELIGIBLE" : "WIDE_BED_TAKE_HU");
        return new(true, allowed, lane, live, history.Used, cap, danger, known,
            history.GangRealized, goal, peng, discard, reasons.ToArray());
    }

    private static (int Tile, int Discard) FindPeng(SichuanStateView s, int lane,
        SichuanReadyPrice before, List<SichuanMeldView> melds)
    {
        if (melds.Count >= 4) return (-1, -1);
        var prior = before.Waits.Sum(w => SichuanDevelopmentPolicy.Density(s, w.TileType, s.Remaining18));
        var offer = s.PublicEvents.LastOrDefault(e => e.Type is not SichuanPublicEventType.Pass
            and not SichuanPublicEventType.Draw and not SichuanPublicEventType.Hu);
        for (var t = lane * 9; t < lane * 9 + 9; t++)
        {
            if (s.Hand18[t] < 2) continue;
            var offeredNow = offer?.Type == SichuanPublicEventType.Discard
                && offer.Seat == s.CurrentSeat && offer.Seat != s.SeatIndex && offer.TileType == t;
            if (!offeredNow && s.Remaining18[t] <= 0) continue;
            var remaining = (int[])s.Remaining18.Clone();
            if (!offeredNow) remaining[t]--;
            var after = (int[])s.Hand18.Clone(); after[t] -= 2;
            var projected = melds.Append(new SichuanMeldView(SichuanMeldType.Peng, t, -1, 0)).ToArray();
            for (var d = 0; d < 27; d++)
            {
                if (after[d] <= 0) continue;
                after[d]--;
                var legal = SichuanReadyWaitPricing.HasLegalOwnedContext(s, after, projected);
                var price = legal ? new SichuanReadyWaitPricing().Build(s, after,
                    remaining.Select(n => (double)n).ToArray(), projected) : null;
                after[d]++;
                if (price is not { HasDrawableWait: true } || price.Waits.Any(w => w.TileType / 9 != lane)) continue;
                var copies = price.Waits.Sum(w => remaining[w.TileType]);
                // Spending a future wall tile on the claim must not turn an
                // unchanged wait into a fictitious supply improvement merely
                // because its conditional denominator became one smaller.
                if (before.Waits.All(w => w.TileType / 9 == lane)
                    && copies <= before.Waits.Sum(w => s.Remaining18[w.TileType])) continue;
                var chance = copies / (double)Math.Max(1, s.WallCount - (offeredNow ? 0 : 1));
                if (chance > prior + 1e-9) return (t, d);
            }
        }
        return (-1, -1);
    }
}
