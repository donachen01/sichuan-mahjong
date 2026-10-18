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
    private sealed record ChanceValue(SichuanBloodBattleChanceModel.Value Value);
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
		double ElapsedMilliseconds,
		double HorizonProbability)
	{
		public double ExpectedOwnWinGain { get; init; }
		public double ExpectedOpponentLoss { get; init; }
		public double ExpectedChaJiaoValue { get; init; }
		public double ExpectedContinuationValue { get; init; }
		public double BattleEndProbability { get; init; }
	}

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
        using var policyTimer = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("chance_model");
        var watch = Stopwatch.StartNew();
        // Only the immutable numerical request enters this small model.
        // Identical requests inside one decision need one DP, irrespective of
        // which discard proposed them. Never cache a policy or seat plan here.
        var value = SichuanMahjong.AI.Core.Decision.SichuanPolicyExecutionScope.Memoize(
            "blood-battle-chance", request, () => SolveChance(request)).Value;
        watch.Stop();
        return new ChanceSearchResult(value.Net, value.Win, value.OpponentWin,
            value.Draw, value.Gang, 0, watch.Elapsed.TotalMilliseconds, value.Horizon)
        {
            ExpectedOwnWinGain = value.WinGain,
            ExpectedOpponentLoss = value.Loss,
            ExpectedChaJiaoValue = value.ChaJiao,
            ExpectedContinuationValue = value.Continuation,
            BattleEndProbability = value.BattleEnd
        };
    }

    private static ChanceValue SolveChance(ChanceSearchRequest request)
    {
        using var timing = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("chance_dp");
        return new(new SichuanBloodBattleChanceModel().Evaluate(request));
    }
}
