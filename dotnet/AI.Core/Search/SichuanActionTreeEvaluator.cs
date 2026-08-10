namespace SichuanMahjong.AI.Core.Search;

using System.Diagnostics;

public sealed record SichuanExpectedValueBreakdown(
    double WinGain,
    double GangGain,
    double ChaJiaoValue,
    double DealInLoss,
    double OpponentFutureLoss,
    double RouteContinuationValue,
    double UncertaintyPenalty)
{
    public double Net => WinGain + GangGain + ChaJiaoValue + RouteContinuationValue - DealInLoss - OpponentFutureLoss - UncertaintyPenalty;
}

public sealed class SichuanActionTreeEvaluator
{
	public sealed record ChanceSearchRequest(
		double LiveTiles,
		int WallTiles,
		int ActivePlayers,
		int OwnTurnOffset,
		double WinScore,
		double OpponentWinProbabilityPerDraw,
		double OpponentWinLoss,
		double GangOpportunityProbability = 0,
		double GangGain = 0,
		double ChaJiaoValue = 0,
		int MaxDraws = 24,
		int Simulations = 2048,
		int Seed = 20260713);

	public sealed record ChanceSearchResult(
		double ExpectedNetScore,
		double OwnWinProbability,
		double OpponentWinProbability,
		double DrawProbability,
		double ExpectedGangGain,
		int Simulations,
		double ElapsedMilliseconds);

    public SichuanExpectedValueBreakdown EvaluateWait(
        int liveTiles,
        int wallTiles,
        int expectedOwnDraws,
        double selfDrawScore,
        double discardHuProbability,
        double discardHuScore,
        double dealInProbability,
        double dealInCost,
        double chaJiaoValue = 0,
        double routeValue = 0,
        double uncertainty = 0)
    {
        var selfDrawProbability = SichuanProbabilityEngine.AtLeastOneHit(liveTiles, wallTiles, expectedOwnDraws);
        var winGain = selfDrawProbability * selfDrawScore + (1 - selfDrawProbability) * Math.Clamp(discardHuProbability, 0, 1) * discardHuScore;
        return new SichuanExpectedValueBreakdown(winGain, 0, chaJiaoValue, Math.Clamp(dealInProbability, 0, 1) * Math.Max(0, dealInCost), 0, routeValue, uncertainty);
    }

    public double CompareImmediateHuWithPass(double immediateHuScore, SichuanExpectedValueBreakdown passRoute, double shunHuLockCost)
        => passRoute.Net - shunHuLockCost - immediateHuScore;

	public ChanceSearchResult SearchChanceNodes(ChanceSearchRequest request)
	{
		var watch = Stopwatch.StartNew();
		var simulations = Math.Clamp(request.Simulations, 64, 8192);
		if (request.WallTiles <= 0)
		{
			watch.Stop();
			return new ChanceSearchResult(
				request.ChaJiaoValue,
				0,
				0,
				1,
				0,
				simulations,
				watch.Elapsed.TotalMilliseconds);
		}
		var activePlayers = Math.Clamp(request.ActivePlayers, 2, 4);
		var random = new Random(request.Seed);
		var totalNet = 0.0;
		var wins = 0;
		var opponentWins = 0;
		var draws = 0;
		var gangGain = 0.0;
		for (var sample = 0; sample < simulations; sample++)
		{
			var wall = Math.Max(1, request.WallTiles);
			var live = Math.Clamp(request.LiveTiles, 0.0, wall);
			var net = 0.0;
			var resolved = false;
			var extraOwnDraws = 0;
			for (var drawIndex = 0; drawIndex < Math.Min(request.MaxDraws, wall) + extraOwnDraws; drawIndex++)
			{
				var isOwnDraw = (drawIndex - request.OwnTurnOffset) % activePlayers == 0 && drawIndex >= request.OwnTurnOffset;
				if (isOwnDraw)
				{
					if (live > 0 && random.NextDouble() < live / (double)Math.Max(1, wall))
					{
						net += request.WinScore;
						wins++;
						resolved = true;
						break;
					}
					if (request.GangOpportunityProbability > 0 && random.NextDouble() < request.GangOpportunityProbability)
					{
						net += request.GangGain;
						gangGain += request.GangGain;
						extraOwnDraws++;
					}
				}
				else if (random.NextDouble() < Math.Clamp(request.OpponentWinProbabilityPerDraw, 0, 1))
				{
					net -= Math.Max(0, request.OpponentWinLoss);
					opponentWins++;
					resolved = true;
					break;
				}
				wall--;
				if (wall <= 0) break;
			}
			if (!resolved)
			{
				net += request.ChaJiaoValue;
				draws++;
			}
			totalNet += net;
		}
		watch.Stop();
		return new ChanceSearchResult(
			totalNet / simulations,
			wins / (double)simulations,
			opponentWins / (double)simulations,
			draws / (double)simulations,
			gangGain / simulations,
			simulations,
			watch.Elapsed.TotalMilliseconds);
	}
}
