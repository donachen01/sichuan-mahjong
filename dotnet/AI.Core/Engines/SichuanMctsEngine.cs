using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Rules;
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

        var bonuses = narrowed.ToDictionary(item => item.TileType, _ => 0.0);
        var counts = narrowed.ToDictionary(item => item.TileType, _ => 0);
        var bestTile = narrowed[0].TileType;
        var bestAvg = double.NegativeInfinity;
		var belief = _belief.Build(state);
		var rollout = 0;

        // Equal public state and policy must receive equal bounded work in
        // live and counterfactual play, independent of CPU/cache warm-up.
        const int workBudget = 8;
        while (rollout < workBudget)
        {
			var seed = unchecked(20260810
				^ state.RoundIndex * 397
				^ state.TurnIndex * 67
				^ (int)(state.EventVersion % int.MaxValue)
				^ rollout * 7919);
			var wallOrder = _wall.SampleWallOrder(state, belief, seed);
            foreach (var candidate in narrowed)
            {
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
            TimedOut = false,
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
        var branch = SichuanBranchState.AfterDiscard(state, discardTileType);
        var hand = (int[])branch.Hand18.Clone();
		var remaining = new int[27];
		foreach (var tile in wallOrder.Where(tile => tile is >= 0 and < 27))
			remaining[tile]++;
        var meldCount = state.MeldCount(state.SeatIndex);
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

            // This structural lookahead freezes rivals' hands and public
            // actions. Skipped rival positions nominate our next tile but
            // cannot consume physical stock without projecting those hands.
            // The shared continuation model prices the actual seat timing.
            var drawn = SichuanBranchState.AfterOwnDraw(branch,hand,draw,branch.WallCount-1);
            if(SichuanReadyWaitPricing.HasLegalOwnedContext(drawn, hand, drawn.MeldViews[drawn.SeatIndex])
                && new SichuanExactHandAnalyzer().IsWinning(hand,meldCount,meldCount==0))
            { totalScore+=24; ownDraws++; break; }
            var selected = SichuanDiscardPolicy.Select(drawn,source:state,searchLeaf:true);
            var detail=selected.Candidates.First(c=>c.TileType==selected.Action.TileType);
            var shanten=detail.Shanten; var live=detail.LiveUkeire;var ukeire=detail.Ukeire;

            totalScore += (8 - shanten) * 1.8 + live * 0.42 + ukeire * 0.18;
            if (shanten <= 0)
                totalScore += 4.0 + detail.WaitCount * 0.8;
            else if (shanten == 1)
                totalScore += 1.6;

            branch=SichuanBranchState.AfterDiscard(drawn,selected.Action.TileType);
            hand=(int[])branch.Hand18.Clone();
			ownDraws++;
        }

		return totalScore / Math.Max(1, ownDraws);
    }

    private static int[] RemoveOne(int[] hand18, int tileType)
    {
        var clone = (int[])hand18.Clone();
        if (tileType is >= 0 and < 27 && clone[tileType] > 0)
            clone[tileType]--;
        return clone;
    }
}
