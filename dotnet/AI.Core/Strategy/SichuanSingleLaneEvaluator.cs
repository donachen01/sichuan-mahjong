using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanSingleLaneValue(
    int Suit, double Value, double ModeledCompletion, double ExpectedOffers,
    double FutureDiscardFreedom, int TargetShanten, IReadOnlyList<string> Reasons);

/// <summary>
/// Bounded public-information continuation model for three opponents missing one
/// suit. It prices available copies and legal next discards, never their real hands.
/// Completion is a route estimate, not a calibrated full-game win probability.
/// </summary>
public sealed class SichuanSingleLaneEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanDangerEngine _danger = new();

    public static int ResolveSuit(SichuanStateView state)
    {
        if (state.SeatIndex is < 0 or > 3) return -1;
        for (var suit = 0; suit < 3; suit++)
            if (suit != state.OwnDingQueSuit && Enumerable.Range(0, 4)
                .Where(seat => seat != state.SeatIndex)
                .All(seat => state.DingQueSuits.ElementAtOrDefault(seat) == suit))
                return suit;
        return -1;
    }

    public IReadOnlyDictionary<int, SichuanSingleLaneValue> EvaluateDiscards(
        SichuanStateView state, SichuanBeliefSnapshot belief, SichuanWallAvailability wall)
    {
        var suit = ResolveSuit(state);
        if (suit < 0 || state.WallCount <= 0) return new Dictionary<int, SichuanSingleLaneValue>();
        // The compulsory missing-suit discard is a legality constraint, not a
        // strategic alternative. Also do not price an impossible exposed flush.
        if (state.OwnDingQueSuit >= 0 && Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(t => state.Hand18[t] > 0))
            return new Dictionary<int, SichuanSingleLaneValue>();
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        if (state.Melds18[state.SeatIndex].Any(t => t / 9 != suit)
            || state.MeldViews[state.SeatIndex].Any(m => m.TileType / 9 != suit))
            return new Dictionary<int, SichuanSingleLaneValue>();
        var opponents = Enumerable.Range(0, 4).Where(s => s != state.SeatIndex
            && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        if (opponents.Length == 0) return new Dictionary<int, SichuanSingleLaneValue>();
        var budget = Math.Min(18, Math.Max(0, state.WallCount / (opponents.Length + 1)));
        if (budget == 0) return new Dictionary<int, SichuanSingleLaneValue>();
        // Native background requests can overlap. Keep memoized hands local to
        // this decision so one request cannot clear or mutate another's cache.
        var shantenCache = new Dictionary<string, int>();
        int Shanten(int[] hand, int exposed)
        {
            var key = exposed + ":" + string.Join(',', hand);
            if (!shantenCache.TryGetValue(key, out var result))
                shantenCache[key] = result = _shanten.CalcBestShanten(hand, exposed, exposed == 0);
            return result;
        }
        var clearing = opponents.Where(seat => !HasPubliclyCleared(state, seat, suit)).ToArray();
        var clearingShare = clearing.Sum(seat => Math.Max(1, state.HandCounts[seat]));
        var offers = new double[27];
        var laneWall = (double[])wall.ExpectedCounts18.Clone();
        // After every opponent has legally discarded another suit and has not
        // drawn again, no target copy can remain in their concealed hands.
        if (clearing.Length == 0)
            for (var tile = suit * 9; tile < suit * 9 + 9; tile++)
                laneWall[tile] = Math.Clamp(state.Remaining18[tile], 0, 4);
        var futureDanger = Enumerable.Range(0, 27).Select(t => _danger.Evaluate(t, state, belief)).ToArray();
        for (var tile = suit * 9; tile < suit * 9 + 9; tile++)
        {
            var unseen = Math.Clamp(state.Remaining18[tile], 0, 4);
            var held = Math.Max(0, unseen - laneWall[tile]);
            // A non-missing discard proves the missing suit was cleared. Only
            // seats without that public proof can still feed starting-hand tiles.
            var release = clearing.Sum(seat => held * Math.Max(1, state.HandCounts[seat])
                / Math.Max(1.0, clearingShare) * Math.Min(1.0, budget / 3.0));
            var futureDrawOffers = laneWall[tile]
                * Math.Min(1.0, budget * opponents.Length / (double)state.WallCount);
            offers[tile] = Math.Min(unseen, release + futureDrawOffers);
        }
        var results = new Dictionary<int, SichuanSingleLaneValue>();
        for (var discard = 0; discard < 27; discard++)
        {
            if (state.Hand18[discard] == 0) continue;
            var hand = (int[])state.Hand18.Clone(); hand[discard]--;
            var target = TargetOnly(hand, suit);
            var targetShanten = Shanten(target, meldCount);
            var ordinaryShanten = Shanten(hand, meldCount);
            var offSuit = hand.Sum() - target.Sum();
            var usefulDrawMass = 0.0;
            var offerMass = 0.0;
            var freedomMass = 0.0;
            var totalTargetMass = 0.0;
            var futureDangerMass = 0.0;
            for (var tile = suit * 9; tile < suit * 9 + 9; tile++)
            {
                if (hand[tile] >= 4 || state.Remaining18[tile] <= 0) continue;
                target[tile]++;
                var improves = Shanten(target, meldCount) < targetShanten;
                target[tile]--;
                if (improves) usefulDrawMass += laneWall[tile];
                // No chi: an offered tile builds a set only with an existing
                // pair/triplet; a ready hand can also Hu on the offered tile.
                if (improves && (hand[tile] >= 2 || targetShanten == 0 && offSuit == 0))
                    offerMass += offers[tile];
                var weight = laneWall[tile];
                if (weight <= 0) continue;
                hand[tile]++;
                var bestTarget = 8;
                var choices = 0.0;
                var safestNextDiscard = 1.0;
                for (var nextDiscard = 0; nextDiscard < 27; nextDiscard++)
                {
                    if (hand[nextDiscard] == 0 || nextDiscard / 9 == state.OwnDingQueSuit) continue;
                    hand[nextDiscard]--;
                    var futureOrdinary = Shanten(hand, meldCount);
                    var futureTarget = Shanten(TargetOnly(hand, suit), meldCount);
                    // Permit one step of investment only while there is time to
                    // recover. Late play must retain the ordinary ready exit.
                    var permittedDebt = state.WallCount > 24 ? 1 : 0;
                    if (futureOrdinary <= ordinaryShanten + permittedDebt)
                    {
                        if (futureTarget < bestTarget) { bestTarget = futureTarget; choices = 0; safestNextDiscard = 1.0; }
                        if (futureTarget == bestTarget)
                        {
                            var risk = Math.Clamp(futureDanger[nextDiscard] / 100.0, 0, 1);
                            choices += 1.0 - risk;
                            safestNextDiscard = Math.Min(safestNextDiscard, risk);
                        }
                    }
                    hand[nextDiscard]++;
                }
                hand[tile]--;
                totalTargetMass += weight;
                if (bestTarget <= targetShanten)
                {
                    freedomMass += weight * Math.Min(1.0, choices / 3.0);
                    futureDangerMass += weight * safestNextDiscard;
                }
            }
            var freedom = totalTargetMass > 0 ? freedomMass / totalTargetMass : 0;
            var acquisitions = usefulDrawMass / Math.Max(1, state.WallCount)
                + offerMass / Math.Max(1, budget);
            var needed = Math.Max(1, Math.Max(targetShanten + 1, offSuit));
            // This stationary progress approximation is intentionally bounded;
            // it does not assert an exact full-game profit maximum.
            var completion = BinomialTail(budget, needed, Math.Clamp(acquisitions, 0, 0.95))
                * (0.5 + freedom * 0.5);
            // Qing Yi Se is 2 fan under the frozen rules. Four copies add roots;
            // never price an unlimited fan reward beyond the current cap.
            var roots = target.Count(count => count == 4)
                + state.MeldViews[state.SeatIndex].Count(m => m.Type != SichuanMeldType.Peng);
            var fan = Math.Min(SichuanRuleSnapshot.Frozen.FanCap, 2 + roots);
            var extraScore = (1 << fan) - 1;
            var reserveGain = completion * extraScore * opponents.Length;
            var delayCost = (1 - completion) * Math.Max(0, targetShanten - ordinaryShanten)
                * (state.WallCount <= 16 ? 0.8 : 0.3);
            var futureDangerCost = completion * (totalTargetMass > 0 ? futureDangerMass / totalTargetMass : 0) * 3.0;
            var offSuitExitRisk = Enumerable.Range(0, 27).Where(tile => tile / 9 != suit)
                .Sum(tile => hand[tile] * futureDanger[tile] / 100.0);
            var exitCost = ordinaryShanten == 0 && targetShanten > 0
                ? (1 - completion) * 2.0 : 0.0;
            var value = reserveGain - delayCost - futureDangerCost - offSuitExitRisk * Math.Min(1.0, completion * 2.0) - exitCost;
            results[discard] = new(suit, value, completion, offerMass, freedom, targetShanten, new[]
            {
                $"单行道公开模型：目标向听 {targetShanten}，预计可用碰/胡供张 {offerMass:F2}",
                $"后续合法弃牌空间 {freedom:P0}，有限牌墙路线完成估计 {completion:P1}",
                $"清色增益 {reserveGain:F2}，延迟 {delayCost:F2}，后续危险弃牌 {futureDangerCost:F2}，转普通胡成本 {exitCost:F2}；净值 {value:F2}",
                $"公开出张证明已清缺 {opponents.Length - clearing.Length} 家，未见清缺 {clearing.Length} 家",
                $"SINGLE_LANE_PUBLIC_SUIT_{suit}"
            });
        }
        return results;
    }

    private static int[] TargetOnly(int[] hand, int suit)
        => hand.Select((count, tile) => tile / 9 == suit ? count : 0).ToArray();

    private static bool HasPubliclyCleared(SichuanStateView state, int seat, int suit)
    {
        return state.DingQueSuits[seat] == suit
            && SichuanMahjong.AI.Core.Inference.SichuanOpponentTimeline.MustHaveClearedMissing(state, seat);
    }

    private static double BinomialTail(int trials, int needed, double probability)
    {
        if (needed > trials || probability <= 0) return 0;
        var distribution = new double[trials + 1]; distribution[0] = 1;
        for (var step = 0; step < trials; step++)
            for (var successes = step + 1; successes >= 0; successes--)
                distribution[successes] = distribution[successes] * (1 - probability)
                    + (successes > 0 ? distribution[successes - 1] * probability : 0);
        return distribution.Skip(needed).Sum();
    }
}
