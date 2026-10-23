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
		int Seed = 20260713,
        IReadOnlyList<SichuanReadyRaceGroup>? ReadyGroups = null,
        IReadOnlyList<SichuanReadyRaceOpponent>? ReadyOpponents = null,
        SichuanReadyRaceGang? ReadyGang = null);

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
        public double SelfDrawWinProbability { get; init; }
        public double DiscardHuProbability { get; init; }
        public double ExpectedSelfDrawGain { get; init; }
        public double ExpectedDiscardHuGain { get; init; }
        public double NaturalGangProbability { get; init; }
        public double ExpectedDealInLoss { get; init; }
        public double ExpectedOpponentSelfDrawLoss { get; init; }
        public double ExpectedGangPaymentLoss { get; init; }
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

    public static ChanceSearchResult MixChanceResults(IReadOnlyList<(ChanceSearchResult Value,double Weight)> rows)
    {
        var mass=rows.Sum(r=>r.Weight);
        if(!(mass>0))throw new ArgumentException("empty chance mixture",nameof(rows));
        double Mean(Func<ChanceSearchResult,double> f)=>rows.Sum(r=>r.Weight*f(r.Value))/mass;
        return new(Mean(v=>v.ExpectedNetScore),Mean(v=>v.OwnWinProbability),Mean(v=>v.OpponentWinProbability),
            Mean(v=>v.DrawProbability),Mean(v=>v.ExpectedGangGain),0,rows.Sum(r=>r.Value.ElapsedMilliseconds),Mean(v=>v.HorizonProbability))
        {
            ExpectedOwnWinGain=Mean(v=>v.ExpectedOwnWinGain),SelfDrawWinProbability=Mean(v=>v.SelfDrawWinProbability),
            DiscardHuProbability=Mean(v=>v.DiscardHuProbability),ExpectedSelfDrawGain=Mean(v=>v.ExpectedSelfDrawGain),
            ExpectedDiscardHuGain=Mean(v=>v.ExpectedDiscardHuGain),ExpectedOpponentLoss=Mean(v=>v.ExpectedOpponentLoss),
            ExpectedChaJiaoValue=Mean(v=>v.ExpectedChaJiaoValue),ExpectedContinuationValue=Mean(v=>v.ExpectedContinuationValue),
            BattleEndProbability=Mean(v=>v.BattleEndProbability),NaturalGangProbability=Mean(v=>v.NaturalGangProbability),
            ExpectedDealInLoss=Mean(v=>v.ExpectedDealInLoss),ExpectedOpponentSelfDrawLoss=Mean(v=>v.ExpectedOpponentSelfDrawLoss),
            ExpectedGangPaymentLoss=Mean(v=>v.ExpectedGangPaymentLoss)
        };
    }

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
            SelfDrawWinProbability = UsesReadyRace(request) ? value.SelfDrawWin : value.Win,
            DiscardHuProbability = value.RonWin,
            ExpectedSelfDrawGain = UsesReadyRace(request) ? value.SelfDrawGain : value.WinGain,
            NaturalGangProbability = value.NaturalGang,
            ExpectedDealInLoss = value.RonLoss,ExpectedOpponentSelfDrawLoss = value.SelfLoss,ExpectedGangPaymentLoss = value.GangLoss,
            ExpectedDiscardHuGain = value.RonGain,
            ExpectedOpponentLoss = value.Loss,
            ExpectedChaJiaoValue = value.ChaJiao,
            ExpectedContinuationValue = value.Continuation,
            BattleEndProbability = value.BattleEnd
        };
    }

    private static bool UsesReadyRace(ChanceSearchRequest r) => r.ReadyGroups is { Count: > 0 and <= 2 } && r.GangOpportunityProbability == 0;

    private static ChanceValue SolveChance(ChanceSearchRequest request)
    {
        using var timing = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("chance_dp");
        return new(UsesReadyRace(request)
            ? SichuanReadyRaceModel.Evaluate(request)
            : new SichuanBloodBattleChanceModel().Evaluate(request));
    }
}
