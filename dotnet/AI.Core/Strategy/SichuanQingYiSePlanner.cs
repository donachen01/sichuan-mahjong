using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;
using SichuanMahjong.AI.Core.Engines;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanQingPlanCandidate(
    int DiscardTileType,
    int TargetSuit,
    double TenpaiProbabilityNextDraw,
    double ExpectedLiveWaits,
    double ExpectedValue,
    double ExitValue,
	double CompletionProbability,
	double ExpectedFan,
	double GenGangPotential,
	double DangerCost,
	double TargetSuitCompetition,
	double OrdinaryFallbackValue,
    IReadOnlyList<string> Reasons);

public sealed class SichuanQingYiSePlanner
{
    private readonly SichuanExactHandAnalyzer _analyzer = new();
    private readonly SichuanShantenEngine _shanten = new();

    public IReadOnlyList<SichuanQingPlanCandidate> Evaluate(SichuanStateView state, int targetSuit = -1)
    {
        var hand = (int[])state.Hand18.Clone();
        if (targetSuit is < 0 or > 2)
            targetSuit = Enumerable.Range(0, 3).OrderByDescending(suit => Enumerable.Range(suit * 9, 9).Sum(tile => hand[tile])).First();
        var totalRemaining = Math.Max(1, state.Remaining18.Sum());
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
		var targetCompetition = Enumerable.Range(0, 4)
			.Where(seat => seat != state.SeatIndex && state.ActiveSeats.ElementAtOrDefault(seat))
			.Count(seat => state.DingQueSuits.ElementAtOrDefault(seat) != targetSuit);
        var results = new List<SichuanQingPlanCandidate>();
        for (var discard = 0; discard < 27; discard++)
        {
            if (hand[discard] <= 0) continue;
            hand[discard]--;
            var tenpaiProbability = 0.0;
            var expectedWaits = 0.0;
            var bestFutureShanten = 8;
            for (var draw = 0; draw < 27; draw++)
            {
                var live = state.Remaining18[draw];
                if (live <= 0 || hand[draw] >= 4) continue;
                var probability = live / (double)totalRemaining;
                hand[draw]++;
                var best = EvaluateBestFutureDiscard(hand, state.Remaining18, meldCount, draw);
                if (best.DiscardTileType >= 0)
                {
                    bestFutureShanten = Math.Min(bestFutureShanten, best.Shanten);
                    if (best.Shanten == 0)
                    {
                        tenpaiProbability += probability;
                        expectedWaits += probability * best.LiveWaits;
                    }
                }
                hand[draw]--;
            }
            var offSuitAfter = Enumerable.Range(0, 27).Where(tile => tile / 9 != targetSuit).Sum(tile => hand[tile]);
            var routeContinuation = discard / 9 != targetSuit ? 2.2 : -1.6;
            var exitValue = Math.Max(0, 1.2 - offSuitAfter * 0.12);
			var targetRemaining = Enumerable.Range(targetSuit * 9, 9).Sum(tile => state.Remaining18[tile]);
			var completionProbability = Math.Clamp(0.08 + targetRemaining / 96.0 - offSuitAfter * 0.085 - targetCompetition * 0.035, 0.01, 0.88);
			var expectedFan = Math.Min(3.0, 1.0 + completionProbability * 3.2);
			var genGangPotential = Enumerable.Range(targetSuit * 9, 9).Sum(tile => hand[tile] >= 3 ? 0.45 : hand[tile] == 2 ? 0.16 : 0.0);
			var discardSeen = state.Visible18[discard];
			var dangerCost = discard / 9 == targetSuit ? Math.Max(0, 4 - discardSeen) * (state.WallCount <= 12 ? 0.18 : 0.08) : 0.04;
			var ordinaryFallback = Math.Max(0, 2.1 - bestFutureShanten * 0.55 + tenpaiProbability * 1.6);
			var capDampening = expectedFan >= 2.9 ? 0.72 : 1.0;
            var expectedValue = (tenpaiProbability * 5.0 + expectedWaits * 0.18 + completionProbability * expectedFan * 1.2 + genGangPotential * 0.4) * capDampening
				+ routeContinuation + exitValue + ordinaryFallback * 0.34 - bestFutureShanten * 0.35 - dangerCost - targetCompetition * 0.08;
            var reasons = new List<string>
            {
                $"两层前瞻下轮成叫率 {tenpaiProbability:P1}",
                $"期望听口活张 {expectedWaits:F1}",
				$"清色完成率 {completionProbability:P1}，预计 {expectedFan:F1} 番",
				$"目标门竞争 {targetCompetition} 家，普通胡退路 {ordinaryFallback:F2}",
                discard / 9 != targetSuit ? "清理异门且保留清一色路线" : "打目标门会损失清一色连续性"
            };
            results.Add(new SichuanQingPlanCandidate(discard, targetSuit, tenpaiProbability, expectedWaits, expectedValue, exitValue, completionProbability, expectedFan, genGangPotential, dangerCost, targetCompetition, ordinaryFallback, reasons));
            hand[discard]++;
        }
        return results.OrderByDescending(item => item.ExpectedValue).ToArray();
    }

    private (int DiscardTileType, int Shanten, int LiveWaits) EvaluateBestFutureDiscard(
        int[] drawnHand,
        IReadOnlyList<int> remaining,
        int meldCount,
        int drawnTile)
    {
        var bestDiscard = -1;
        var bestShanten = 8;
        var bestLive = -1;
        for (var discard = 0; discard < 27; discard++)
        {
            if (drawnHand[discard] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(drawnHand, discard, meldCount, meldCount == 0);
            if (shanten > bestShanten) continue;
            var liveWaits = 0;
            if (shanten == 0)
            {
                drawnHand[discard]--;
                var adjustedRemaining = remaining.ToArray();
                if (drawnTile is >= 0 and < 27) adjustedRemaining[drawnTile] = Math.Max(0, adjustedRemaining[drawnTile] - 1);
                adjustedRemaining[discard]++;
                liveWaits = _analyzer.EnumerateWaits(drawnHand, adjustedRemaining, meldCount).Sum(wait => wait.LiveCount);
                drawnHand[discard]++;
            }
            if (shanten < bestShanten || liveWaits > bestLive)
            {
                bestDiscard = discard;
                bestShanten = shanten;
                bestLive = liveWaits;
            }
        }
        return (bestDiscard, bestShanten, Math.Max(0, bestLive));
    }
}
