using System.Reflection;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;

internal static class RoundBrainSmoke
{
    public static bool KeepsIndependentContinuousBrains()
    {
        var engine = new SichuanRoundBrainEngine();
        var flushHand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 8, 9, 13, 16 });
        var seatOne = SichuanStateCodec.FromRaw(1, 0, 1, 30, flushHand, new int[27], roundIndex: 901);
        var first = engine.Observe(seatOne);

        var nextHand = (int[])flushHand.Clone();
        nextHand[8]--;
        nextHand[10]++;
        var discards = new[] { new List<int>(), new List<int> { 8 }, new List<int>(), new List<int>() };
        var next = SichuanStateCodec.FromRaw(1, 0, 1, 29, nextHand, new int[27], discards18: discards, roundIndex: 901);
        var second = engine.Observe(next);

        var balancedHand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 9, 10, 11, 18, 19, 20, 3, 4, 12, 13, 22 });
        var seatTwo = SichuanStateCodec.FromRaw(2, 0, 2, 30, balancedHand, new int[27], roundIndex: 901);
        var other = engine.Observe(seatTwo);

        Console.WriteLine($"round_brain first={first.PrimaryRoute}/{first.Commitment} second={second.PrimaryRoute}/{second.Commitment} other={other.PrimaryRoute}/{other.Commitment}");
        return first.SeatIndex == 1
            && second.SeatIndex == 1
            && other.SeatIndex == 2
            && second.Revision > first.Revision
            && first.PrimaryRoute == second.PrimaryRoute;
    }

    public static bool PenalizesBreakThenPengContradiction()
    {
        var facade = new SichuanAiFacade();
        var beforeHand = SichuanTileCodec.BuildCount18(new[] { 4, 4, 4, 0, 1, 2, 9, 10, 11, 18, 19, 20, 6, 7 });
        var before = SichuanStateCodec.FromRaw(1, 0, 1, 24, beforeHand, new int[27], roundIndex: 902);
        _ = facade.DecideDiscard(before);

        var afterHand = (int[])beforeHand.Clone();
        afterHand[4]--;
        var discards = new[] { new List<int>(), new List<int> { 4 }, new List<int>(), new List<int>() };
        var after = SichuanStateCodec.FromRaw(1, 0, 1, 23, afterHand, new int[27], discards18: discards, roundIndex: 902);
        var reaction = facade.DecideReaction(after, 4, false, true, false, 0);
        Console.WriteLine($"break_then_peng action={reaction.Action.ActionType} pass={reaction.ActionScores.GetValueOrDefault("pass")} peng={reaction.ActionScores.GetValueOrDefault("peng")} reasons={string.Join('|', reaction.Reasons)}");
        return reaction.Action.ActionType == SichuanActionType.Pass
            && reaction.ActionScores.GetValueOrDefault("peng") < reaction.ActionScores.GetValueOrDefault("pass")
            && reaction.Reasons.Any(reason => reason.Contains("主动拆刻", StringComparison.Ordinal));
    }

    public static bool SafeReadyDominatesHigherScoredNonReady()
    {
        var method = typeof(SichuanDecisionEngine).GetMethod(
            "SelectLateWallKeepReadyOverride",
            BindingFlags.NonPublic | BindingFlags.Static);
        if (method is null) return false;

        var nonReady = new SichuanCandidateDetail { TileType = 3, Score = 9000, Shanten = 1, WaitCount = 0, Danger = 6 };
        var safeReady = new SichuanCandidateDetail { TileType = 5, Score = 100, Shanten = 0, WaitCount = 2, LiveUkeire = 4, Danger = 28 };
        var state = SichuanStateCodec.FromRaw(1, 0, 1, 3, new int[27], new int[27], roundIndex: 903);
        var selected = method.Invoke(null, new object[] { new[] { nonReady, safeReady }, nonReady.TileType, state }) as SichuanCandidateDetail;
        Console.WriteLine($"safe_ready_dominance selected={selected?.TileType} ready_score={safeReady.Score} nonready_score={nonReady.Score}");
        return selected?.TileType == safeReady.TileType;
    }

	public static bool ResetsAtRoundBoundaryAndExposesStrategyState()
	{
		var engine = new SichuanRoundBrainEngine();
		var hand = SichuanTileCodec.BuildCount18(new[] { 0,1,2,3,4,5,6,7,8,9,10,18,19,20 });
		var firstState = SichuanStateCodec.FromRaw(1, 0, 1, 30, hand, new int[27], roundIndex: 910, eventVersion: 4, visibleVersion: 4);
		var first = engine.Observe(firstState);
		engine.RecordDiscard(firstState, 20, new SichuanRoutePlanEngine().Evaluate(firstState));

		var threatenedState = SichuanStateCodec.FromRaw(1, 0, 1, 20, hand, new int[27], roundIndex: 910, eventVersion: 8, visibleVersion: 8);
		threatenedState.IsReady[2] = true;
		threatenedState.Melds18[2].AddRange(new[] { 9, 9, 9, 10, 10, 10 });
		var threatened = engine.Observe(threatenedState);

		var nextRoundState = SichuanStateCodec.FromRaw(1, 1, 1, 30, hand, new int[27], roundIndex: 911, eventVersion: 0, visibleVersion: 0);
		var reset = engine.Observe(nextRoundState);
		Console.WriteLine($"round_brain_state risk={first.RiskBudget:F2}->{threatened.RiskBudget:F2} threat={threatened.MaxThreatSeat}/{threatened.MaxThreatScore:F2} reset={reset.Revision} probabilities={reset.RouteProbabilities.Values.Sum():F3}");
		return first.RulesVersion == SichuanMahjong.AI.Core.Domain.SichuanRuleSnapshot.Version
			&& first.ObservationVersion == 4
			&& threatened.Revision > first.Revision
			&& threatened.MaxThreatSeat == 2
			&& threatened.RiskBudget < first.RiskBudget
			&& threatened.DecisionHistory.Any(item => item.Contains("出牌"))
			&& reset.RoundIndex == 911
			&& reset.Revision == 1
			&& !reset.DecisionHistory.Any(item => item.Contains("出牌"))
			&& Math.Abs(reset.RouteProbabilities.Values.Sum() - 1.0) < 0.0001;
	}
}
