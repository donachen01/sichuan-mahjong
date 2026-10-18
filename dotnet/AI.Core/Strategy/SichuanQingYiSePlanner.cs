using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanQingPlanCandidate(
    int DiscardTileType,
    int TargetSuit,
    double TenpaiProbabilityNextDraw,
    double ExpectedLiveWaits,
    double ExpectedValue,
    double ExitValue,
	double ImmediateWinChanceNextDraw,
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
    private readonly SichuanFlushStructureEngine _flushStructure = new();
	private readonly SichuanWallAvailabilityEngine _wall = new();
	private readonly SichuanBeliefEngine _belief = new();

    public IReadOnlyList<SichuanQingPlanCandidate> Evaluate(
        SichuanStateView state,
        int targetSuit = -1,
        SichuanBeliefSnapshot? belief = null)
    {
        using var policyTimer = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("qing");
        var hand = (int[])state.Hand18.Clone();
        var ownMelds = state.Melds18[state.SeatIndex];
        bool IsLegalTarget(int suit) => suit != state.OwnDingQueSuit
            && ownMelds.All(tile => tile / 9 == suit)
            && state.MeldViews[state.SeatIndex].All(meld => meld.TileType / 9 == suit);
        if (targetSuit is < 0 or > 2)
            targetSuit = Enumerable.Range(0, 3).Where(IsLegalTarget)
                .OrderByDescending(suit => Enumerable.Range(suit * 9, 9).Sum(tile => hand[tile]))
                .DefaultIfEmpty(-1).First();
        // Exposed melds cannot be dismantled, and the missing suit can never
        // be a winning flush. Do not attach route value to impossible targets.
        if (targetSuit < 0 || !IsLegalTarget(targetSuit))
            return Array.Empty<SichuanQingPlanCandidate>();
        belief ??= _belief.Build(state);
		var wall = _wall.Build(state, belief);
        var meldCount = state.MeldCount(state.SeatIndex);
        var exposed = new int[27];
        if (state.MeldViews[state.SeatIndex].Count > 0)
        {
            meldCount = state.MeldViews[state.SeatIndex].Count;
            foreach (var meld in state.MeldViews[state.SeatIndex])
                exposed[meld.TileType] += meld.Type == Domain.SichuanMeldType.Peng ? 3 : 4;
        }
        else foreach (var tile in ownMelds) exposed[tile]++;
		var targetCompetition = EstimateTargetSuitCompetition(state, targetSuit, belief);
        var results = new List<SichuanQingPlanCandidate>();
        var mustClearMissingSuit = state.OwnDingQueSuit is >= 0 and < 3
            && Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => hand[tile] > 0);
        for (var discard = 0; discard < 27; discard++)
        {
            if (hand[discard] <= 0) continue;
            if (mustClearMissingSuit && discard / 9 != state.OwnDingQueSuit) continue;
            hand[discard]--;
            var structure = _flushStructure.Analyze(hand, state.Remaining18, exposed, targetSuit, meldCount);
            if (structure.FeasiblePatterns == 0)
            {
                hand[discard]++;
                continue;
            }
            var tenpaiProbability = 0.0;
            var expectedWaits = 0.0;
            var bestFutureShanten = 8;
            for (var draw = 0; draw < 27; draw++)
            {
                var live = wall.ExpectedCounts18[draw];
                if (live <= 0 || hand[draw] >= 4) continue;
                var probability = live / Math.Max(1, wall.WallCount);
                hand[draw]++;
                var best = EvaluateBestFutureDiscard(hand, wall.RepresentativeCounts18, meldCount, draw, state.OwnDingQueSuit);
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
			var progressChance = wall.WallCount > 0
				? Math.Clamp(wall.SumExpected(structure.UsefulDraws) / wall.WallCount, 0, 1) : 0;
			// A one-draw completion event is computable from the public wall model.
			// For a longer route the full-game completion probability is unknown,
			// and must not be invented from target count and off-suit count.
			var immediateWinChance = structure.MinimumAdditionalTiles == 1 ? progressChance : 0;
			var roots = Enumerable.Range(targetSuit * 9, 9).Count(tile => hand[tile] == 4)
				+ state.MeldViews[state.SeatIndex].Count(m => m.Type != Domain.SichuanMeldType.Peng);
			var expectedFan = Math.Min(SichuanRuleSnapshot.Frozen.FanCap, 2 + roots);
			var genGangPotential = Enumerable.Range(targetSuit * 9, 9).Sum(tile => hand[tile] >= 3 ? 0.45 : hand[tile] == 2 ? 0.16 : 0.0);
			var dangerCost = discard / 9 == targetSuit ? Math.Max(0, state.Remaining18[discard]) * (state.WallCount <= 12 ? 0.18 : 0.08) : 0.04;
			var ordinaryFallback = Math.Max(0, 2.1 - bestFutureShanten * 0.55 + tenpaiProbability * 1.6);
			var capDampening = expectedFan >= SichuanRuleSnapshot.Frozen.FanCap ? 0.72 : 1.0;
            var expectedValue = (tenpaiProbability * 5.0 + expectedWaits * 0.18
				+ progressChance * expectedFan * 0.7 / Math.Max(1, structure.MinimumAdditionalTiles)
				+ immediateWinChance * expectedFan * 1.2 + genGangPotential * 0.4) * capDampening
				+ routeContinuation + exitValue + ordinaryFallback * 0.34 - bestFutureShanten * 0.35 - dangerCost - targetCompetition * 0.08;
            var reasons = new List<string>
            {
                $"清色合法成牌至少还需 {structure.MinimumAdditionalTiles} 张；公开未见副本仅作供应上界",
                $"两层前瞻下轮成叫率 {tenpaiProbability:P1}",
                $"期望听口活张 {expectedWaits:F1}",
				$"公开墙模型下次摸牌清色结构进展 {progressChance:P1}；直接成胡 {immediateWinChance:P1}，路线远期完成率未校准",
				$"清色基础及已成根按封顶计 {expectedFan:F0} 番",
				$"目标门公开等效竞争 {targetCompetition:F2} 家，普通胡退路 {ordinaryFallback:F2}",
                discard / 9 != targetSuit ? "清理异门且保留清一色路线" : "打目标门会损失清一色连续性"
            };
            results.Add(new SichuanQingPlanCandidate(discard, targetSuit, tenpaiProbability, expectedWaits, expectedValue, exitValue, immediateWinChance, expectedFan, genGangPotential, dangerCost, targetCompetition, ordinaryFallback, reasons));
            hand[discard]++;
        }
        return results.OrderByDescending(item => item.ExpectedValue).ToArray();
    }

    private static double EstimateTargetSuitCompetition(
        SichuanStateView state,
        int targetSuit,
        SichuanBeliefSnapshot? belief)
    {
        var competition = 0.0;
        for (var seat = 0; seat < 4; seat++)
        {
            if (seat == state.SeatIndex || !state.ActiveSeats.ElementAtOrDefault(seat))
                continue;
            if (state.DingQueSuits.ElementAtOrDefault(seat) == targetSuit)
                continue;

            if (belief?.SeatSuitDemand.TryGetValue(seat, out var suitDemand) == true
                && suitDemand.TryGetValue(targetSuit, out var targetDemand))
            {
                // Normalize against this seat's strongest public suit demand. Neutral
                // evidence therefore preserves one full competitor, while public
                // discards/melds can only reduce the equivalent competition smoothly.
                var strongestDemand = suitDemand.Values.DefaultIfEmpty(0.0).Max();
                competition += strongestDemand <= 0.0
                    ? 1.0
                    : Math.Clamp(targetDemand / strongestDemand, 0.0, 1.0);
                continue;
            }

            // Preserve the previous rule-only behavior for callers without a public
            // belief snapshot; no hidden hand is required by either branch.
            competition += 1.0;
        }
        return competition;
    }

    private (int DiscardTileType, int Shanten, int LiveWaits) EvaluateBestFutureDiscard(
        int[] drawnHand,
        IReadOnlyList<int> remaining,
        int meldCount,
        int drawnTile,
        int missingSuit = -1)
    {
        var bestDiscard = -1;
        var bestShanten = 8;
        var bestLive = -1;
        var missingCount = missingSuit is >= 0 and < 3
            ? Enumerable.Range(missingSuit * 9, 9).Sum(tile => drawnHand[tile]) : 0;
        for (var discard = 0; discard < 27; discard++)
        {
            if (drawnHand[discard] <= 0) continue;
            if (missingCount > 0 && discard / 9 != missingSuit) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(drawnHand, discard, meldCount, meldCount == 0);
            // A structurally complete/tight hand still carrying the missing
            // suit is not ready under Sichuan rules.
            if (missingCount > 1) shanten = Math.Max(1, shanten);
            if (shanten > bestShanten) continue;
            var liveWaits = 0;
            if (shanten == 0)
            {
                drawnHand[discard]--;
                var adjustedRemaining = remaining.ToArray();
                if (drawnTile is >= 0 and < 27) adjustedRemaining[drawnTile] = Math.Max(0, adjustedRemaining[drawnTile] - 1);
                // The discarded tile becomes public; it does not return to
                // the wall or unknown supply. Only consume the simulated draw.
                var legalWaits = _analyzer.EnumerateWaits(drawnHand, null, meldCount)
                    .Where(wait => wait.TileType / 9 != missingSuit).ToArray();
                liveWaits = legalWaits.Sum(wait => adjustedRemaining[wait.TileType]);
                if (legalWaits.Length == 0) shanten = Math.Max(1, shanten);
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
