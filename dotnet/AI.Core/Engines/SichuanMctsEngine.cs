using System.Diagnostics;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanMctsEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
	private readonly SichuanBeliefEngine _belief = new();
	private readonly SichuanWallAvailabilityEngine _wall = new();

    public SichuanSearchResult EvaluateTopCandidates(
        SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates,
        int timeoutMs = 280,
        int topK = 3,
        int rolloutDepth = 2)
    {
        if (state.WallCount <= 0)
            return new SichuanSearchResult { Used = false };

        if (candidates.Count < 2)
            return new SichuanSearchResult { Used = false };

        var narrowed = candidates
            .Take(Math.Min(topK, candidates.Count))
            .ToArray();
        if (!ShouldSearch(narrowed))
            return new SichuanSearchResult { Used = false };

        var sw = Stopwatch.StartNew();
        var bonuses = narrowed.ToDictionary(item => item.TileType, _ => 0.0);
        var counts = narrowed.ToDictionary(item => item.TileType, _ => 0);
        var bestTile = narrowed[0].TileType;
        var bestAvg = double.NegativeInfinity;
		var belief = _belief.Build(state);
		var rollout = 0;

        while (sw.ElapsedMilliseconds < timeoutMs)
        {
			var seed = unchecked(20260810
				^ state.RoundIndex * 397
				^ state.TurnIndex * 67
				^ (int)(state.EventVersion % int.MaxValue)
				^ rollout * 7919);
			var wallOrder = _wall.SampleWallOrder(state, belief, seed);
            foreach (var candidate in narrowed)
            {
                if (sw.ElapsedMilliseconds >= timeoutMs)
                    break;

				var score = SimulateCandidate(state, candidate.TileType, rolloutDepth, wallOrder);
                bonuses[candidate.TileType] += score;
                counts[candidate.TileType]++;
            }
			rollout++;
        }

        foreach (var candidate in narrowed)
        {
            if (counts[candidate.TileType] <= 0) continue;
            bonuses[candidate.TileType] /= counts[candidate.TileType];
            if (bonuses[candidate.TileType] > bestAvg)
            {
                bestAvg = bonuses[candidate.TileType];
                bestTile = candidate.TileType;
            }
        }

        var totalSimulations = counts.Values.Sum();
        return new SichuanSearchResult
        {
            Used = totalSimulations > 0,
            TimedOut = sw.ElapsedMilliseconds >= timeoutMs,
            Simulations = totalSimulations,
            Depth = rolloutDepth,
            TopK = narrowed.Length,
            BestTileType = bestTile,
            CandidateBonuses = bonuses
        };
    }

    private bool ShouldSearch(IReadOnlyList<SichuanCandidateDetail> candidates)
    {
        if (candidates.Count < 2) return false;
        var first = candidates[0];
        var second = candidates[1];
		if (Math.Abs(first.ExpectedValue - second.ExpectedValue) <= 1.4) return true;
		if (first.Shanten != second.Shanten && Math.Abs(first.ExpectedValue - second.ExpectedValue) > 2.2) return false;
        if (Math.Abs(first.LiveUkeire - second.LiveUkeire) <= 3) return true;
        if (Math.Abs(first.ExpectedValue - second.ExpectedValue) <= 0.8) return true;
        if (Math.Abs(first.DealInProbability - second.DealInProbability) <= 0.08) return true;
        return false;
    }

	private double SimulateCandidate(
		SichuanStateView state,
		int discardTileType,
		int rolloutDepth,
		IReadOnlyList<int> wallOrder)
    {
        var hand = RemoveOne(state.Hand18, discardTileType);
		var remaining = new int[27];
		foreach (var tile in wallOrder.Where(tile => tile is >= 0 and < 27))
			remaining[tile]++;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var totalScore = 0.0;
		var activePlayers = Math.Max(2, state.ActiveSeats.Count(active => active));
		var ownDrawOffset = Math.Max(0, activePlayers - 1);
		var ownDraws = 0;

		for (var drawIndex = 0; drawIndex < wallOrder.Count && ownDraws < rolloutDepth; drawIndex++)
        {
			var draw = wallOrder[drawIndex];
			if (draw is < 0 or >= 27) continue;
			remaining[draw] = Math.Max(0, remaining[draw] - 1);
			var isOwnDraw = drawIndex >= ownDrawOffset
				&& (drawIndex - ownDrawOffset) % activePlayers == 0;
			if (!isOwnDraw) continue;

            hand[draw]++;

            var bestDiscard = FindBestDiscard(hand, remaining, meldCount);
            var shanten = bestDiscard.shanten;
            var live = bestDiscard.liveUkeire;
            var ukeire = bestDiscard.ukeire;

            totalScore += (8 - shanten) * 1.8 + live * 0.42 + ukeire * 0.18;
            if (shanten <= 0)
                totalScore += 4.0 + bestDiscard.waitCount * 0.8;
            else if (shanten == 1)
                totalScore += 1.6;

            if (bestDiscard.tileType >= 0)
                hand[bestDiscard.tileType]--;
			ownDraws++;
        }

		return totalScore / Math.Max(1, ownDraws);
    }

    private (int tileType, int shanten, int ukeire, int liveUkeire, int waitCount) FindBestDiscard(int[] hand, int[] remaining, int meldCount)
    {
        var bestTile = -1;
        var bestShanten = int.MaxValue;
        var bestLive = -1;
        var bestUkeire = -1;
        var bestWait = -1;

        for (var tileType = 0; tileType < hand.Length; tileType++)
        {
            if (hand[tileType] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(hand, tileType);
            var (ukeire, liveUkeire, improvingTiles) = _ukeire.CalcUkeire(hand, remaining, tileType);
            var remainingHand = RemoveOne(hand, tileType);
            var exactReadyTiles = GetExactReadyTiles(remainingHand, meldCount);
            var effectiveShanten = exactReadyTiles.Count > 0 ? 0 : shanten;
            var effectiveLiveUkeire = exactReadyTiles.Count > 0
                ? exactReadyTiles.Sum(item => Math.Max(0, remaining[item]))
                : liveUkeire;
            var waitCount = exactReadyTiles.Count > 0 ? exactReadyTiles.Count : (effectiveShanten <= 0 ? improvingTiles.Count : 0);

            if (effectiveShanten < bestShanten
                || (effectiveShanten == bestShanten && effectiveLiveUkeire > bestLive)
                || (effectiveShanten == bestShanten && effectiveLiveUkeire == bestLive && waitCount > bestWait)
                || (effectiveShanten == bestShanten && effectiveLiveUkeire == bestLive && waitCount == bestWait && ukeire > bestUkeire))
            {
                bestTile = tileType;
                bestShanten = effectiveShanten;
                bestLive = effectiveLiveUkeire;
                bestUkeire = ukeire;
                bestWait = waitCount;
            }
        }

        return (bestTile, bestShanten, bestUkeire, bestLive, bestWait);
    }

    private static List<int> GetExactReadyTiles(int[] hand18, int meldCount)
    {
        var results = new List<int>();
        var expectedConcealed = ((4 - meldCount) * 3) + 1;
        if (meldCount < 0 || meldCount > 4 || hand18.Sum() != expectedConcealed)
            return results;
        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            if (hand18[tileType] >= 4) continue;
            var probe = (int[])hand18.Clone();
            probe[tileType]++;
            if (CanHu(probe, meldCount))
                results.Add(tileType);
        }
        return results;
    }

    private static bool CanHu(int[] hand18, int meldCount)
    {
        var requiredConcealed = ((4 - meldCount) * 3) + 2;
        if (meldCount < 0 || meldCount > 4 || hand18.Sum() != requiredConcealed)
            return false;
        if (meldCount == 0 && IsQiDui(hand18))
            return true;
        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            if (hand18[tileType] < 2) continue;
            var trial = (int[])hand18.Clone();
            trial[tileType] -= 2;
            if (CanClearSuit(trial, 0) && CanClearSuit(trial, 9) && CanClearSuit(trial, 18))
                return true;
        }
        return false;
    }

    private static bool IsQiDui(int[] hand18)
    {
        if (hand18.Sum() != 14) return false;
        var pairCount = 0;
        foreach (var count in hand18)
        {
            if (count != 0 && count != 2 && count != 4)
                return false;
            pairCount += count / 2;
        }
        return pairCount == 7;
    }

    private static bool CanClearSuit(int[] hand18, int startIndex)
    {
        var suit = new int[9];
        Array.Copy(hand18, startIndex, suit, 0, 9);
        return CanClearSuitRecursive(suit, 0);
    }

    private static bool CanClearSuitRecursive(int[] counts, int startRank)
    {
        var rank = startRank;
        while (rank < 9 && counts[rank] == 0)
            rank++;
        if (rank >= 9)
            return true;

        if (counts[rank] >= 3)
        {
            var triplet = (int[])counts.Clone();
            triplet[rank] -= 3;
            if (CanClearSuitRecursive(triplet, rank))
                return true;
        }

        if (rank <= 6 && counts[rank + 1] > 0 && counts[rank + 2] > 0)
        {
            var sequence = (int[])counts.Clone();
            sequence[rank]--;
            sequence[rank + 1]--;
            sequence[rank + 2]--;
            if (CanClearSuitRecursive(sequence, rank))
                return true;
        }

        return false;
    }

    private static int[] RemoveOne(int[] hand18, int tileType)
    {
        var clone = (int[])hand18.Clone();
        if (tileType is >= 0 and < 27 && clone[tileType] > 0)
            clone[tileType]--;
        return clone;
    }
}
