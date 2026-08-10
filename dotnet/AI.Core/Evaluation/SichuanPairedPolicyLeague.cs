using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Evaluation;

public sealed record SichuanPairedPolicyLeagueResult(
    int Samples,
    int Seed,
    string CandidatePolicy,
    string BaselinePolicy,
    double CandidateAverageRegret,
    double BaselineAverageRegret,
    double PairedRegretImprovement,
    double ImprovementCiLow,
    double ImprovementCiHigh,
    double CandidateSevereRate,
    double BaselineSevereRate,
    double CandidatePairBreakRate,
    double BaselinePairBreakRate,
    double CandidateReactionRegret,
    double BaselineReactionRegret,
    double DecisionConsistencyRate,
    IReadOnlyDictionary<int, double> CandidateRegretBySeat,
    IReadOnlyList<SichuanPairedDecisionDiagnostic> WorstDiscardRegressions,
    bool PromotionGatePassed,
    IReadOnlyList<string> GateReasons);

public sealed record SichuanPairedDecisionDiagnostic(
    int Sample,
    int Seat,
    int WallCount,
    IReadOnlyList<int> Hand18,
    int CandidateTile,
    int BaselineTile,
    string JudgeBestAction,
    double CandidateRegret,
    double BaselineRegret,
    int CandidateShanten,
    int CandidateLiveUkeire,
    int CandidateDanger,
    double CandidateUnifiedValue,
    double CandidateStrategicResidual,
    int CandidateScore,
    int BaselineShanten,
    int BaselineLiveUkeire,
    int BaselineDanger,
    double BaselineUnifiedValue,
    double BaselineStrategicResidual,
    int BaselineScore);

public sealed class SichuanPairedPolicyLeague
{
	private const double DiscardNonInferiorityMargin = 0.002;
	private readonly SichuanFrozenBaselinePolicy _frozen = new();
	private readonly SichuanCrossValidatedActionOracle _oracle = new();

    public SichuanPairedPolicyLeagueResult Run(int samples = 1000, int seed = 20260809)
    {
        samples = Math.Clamp(samples, 32, 20_000);
        var random = new Random(seed);
        var pairedImprovements = new List<double>(samples);
        var candidateRegrets = new List<double>(samples);
        var baselineRegrets = new List<double>(samples);
        var candidateReactionRegrets = new List<double>();
        var baselineReactionRegrets = new List<double>();
        var candidateSevere = 0;
        var baselineSevere = 0;
        var candidatePairBreak = 0;
        var baselinePairBreak = 0;
        var consistent = 0;
        var bySeat = Enumerable.Range(0, 4).ToDictionary(seat => seat, _ => new List<double>());
        var discardRegressions = new List<SichuanPairedDecisionDiagnostic>();

        for (var sample = 0; sample < samples; sample++)
        {
            var seat = sample % 4;
            var state = BuildDiscardState(random, seat, seed + sample);
            var candidateResult = new SichuanAiFacade().DecideDiscard(state);
            var candidate = candidateResult.Action.TileType;
            var repeated = new SichuanAiFacade().DecideDiscard(state).Action.TileType;
            if (candidate == repeated) consistent++;
			var baseline = _frozen.DecideDiscard(state);
			var discardOracle = _oracle.EvaluateDiscards(state, 48, seed ^ (sample * 7919));
			var candidateRegret = ActionRegret(discardOracle, $"discard:{candidate}");
			var baselineRegret = ActionRegret(discardOracle, $"discard:{baseline}");
			candidateRegrets.Add(candidateRegret);
			baselineRegrets.Add(baselineRegret);
			pairedImprovements.Add(baselineRegret - candidateRegret);
			bySeat[seat].Add(candidateRegret);
			if (candidateRegret >= 2.5) candidateSevere++;
			if (baselineRegret >= 2.5) baselineSevere++;
			if (IsRegrettedPairBreak(state, candidate, candidateRegret)) candidatePairBreak++;
			if (IsRegrettedPairBreak(state, baseline, baselineRegret)) baselinePairBreak++;
			if (candidateRegret > baselineRegret + 0.01)
            {
                var detail = candidateResult.Candidates.First(item => item.TileType == candidate);
                var baselineDetail = candidateResult.Candidates.First(item => item.TileType == baseline);
                discardRegressions.Add(new SichuanPairedDecisionDiagnostic(
                    sample,
                    seat,
                    state.WallCount,
                    state.Hand18.ToArray(),
                    candidate,
                    baseline,
					discardOracle.ValidationBestAction,
					candidateRegret,
					baselineRegret,
                    detail.Shanten,
                    detail.LiveUkeire,
                    detail.Danger,
                    detail.UnifiedActionValue,
                    detail.StrategicResidual,
                    detail.Score,
                    baselineDetail.Shanten,
                    baselineDetail.LiveUkeire,
                    baselineDetail.Danger,
                    baselineDetail.UnifiedActionValue,
                    baselineDetail.StrategicResidual,
                    baselineDetail.Score));
            }

            var reactionState = BuildReactionState(random, seat, seed + 100_000 + sample, out var reactionTile, out var canGang);
            var candidateReaction = new SichuanAiFacade().DecideReaction(
                reactionState, reactionTile, false, true, canGang, (seat + 3) % 4, "discard").Action.ActionType;
			var baselineReaction = _frozen.DecideReaction(reactionState, reactionTile, false, true, canGang);
			var reactionOracle = _oracle.EvaluateReaction(
				reactionState, reactionTile, false, true, canGang, (seat + 3) % 4, 48,
				seed ^ (100_000 + sample * 3571));
			candidateReactionRegrets.Add(ActionRegret(reactionOracle, ReactionKey(candidateReaction, reactionTile)));
			baselineReactionRegrets.Add(ActionRegret(reactionOracle, ReactionKey(baselineReaction, reactionTile)));
        }

        var (ciLow, ciHigh) = BootstrapMeanInterval(pairedImprovements, seed ^ 0x5A17);
        var candidateAverage = candidateRegrets.Average();
        var baselineAverage = baselineRegrets.Average();
        var candidateReactionAverage = candidateReactionRegrets.Average();
        var baselineReactionAverage = baselineReactionRegrets.Average();
        var candidatePairRate = candidatePairBreak / (double)samples;
        var baselinePairRate = baselinePairBreak / (double)samples;
        var consistency = consistent / (double)samples;
        var gateReasons = new List<string>();
		if (candidateAverage > baselineAverage + DiscardNonInferiorityMargin
			|| ciLow < -DiscardNonInferiorityMargin)
			gateReasons.Add($"候选弃牌未通过 {DiscardNonInferiorityMargin:F3} 非劣界或置信区间越界");
        if (candidateReactionAverage > baselineReactionAverage) gateReasons.Add("候选碰过杠后悔值高于冻结基线");
        if (candidateSevere > baselineSevere) gateReasons.Add("候选严重错误率高于冻结基线");
        if (candidatePairRate > baselinePairRate + 0.01) gateReasons.Add("候选非必要拆对率高于冻结基线超过 1 个百分点");
        if (consistency < 0.999) gateReasons.Add("同状态重复决策不稳定");
        if (samples < 500) gateReasons.Add("样本量不足 500，不能晋级");
        if (gateReasons.Count == 0) gateReasons.Add("所有影子晋级门槛通过");

        return new SichuanPairedPolicyLeagueResult(
            samples,
            seed,
            "bone_ash_action_value_v2",
            "frozen_hard_tier_v1",
            candidateAverage,
            baselineAverage,
            baselineAverage - candidateAverage,
            ciLow,
            ciHigh,
            candidateSevere / (double)samples,
            baselineSevere / (double)samples,
            candidatePairRate,
            baselinePairRate,
            candidateReactionAverage,
            baselineReactionAverage,
            consistency,
            bySeat.ToDictionary(item => item.Key, item => item.Value.Count == 0 ? 0 : item.Value.Average()),
            discardRegressions
                .OrderByDescending(item => item.CandidateRegret - item.BaselineRegret)
                .ThenBy(item => item.Sample)
                .Take(10)
                .ToArray(),
            gateReasons.Count == 1 && gateReasons[0].StartsWith("所有", StringComparison.Ordinal),
            gateReasons);
    }

	private static bool IsRegrettedPairBreak(SichuanStateView state, int tile, double regret)
		=> tile is >= 0 and < 27 && state.Hand18[tile] >= 2 && regret >= 0.45;

	private static double ActionRegret(SichuanCrossValidatedOracleResult oracle, string actionKey)
		=> oracle.Actions.FirstOrDefault(item => item.ActionKey == actionKey)?.ValidationRegret ?? 100;

	private static string ReactionKey(SichuanActionType action, int tileType)
		=> action == SichuanActionType.Pass ? "pass" : $"{action.ToString().ToLowerInvariant()}:{tileType}";

    private static SichuanStateView BuildDiscardState(Random random, int seat, int roundIndex)
    {
        var tiles = BuildShuffledWall(random);
        var hand = new int[27];
        for (var i = 0; i < 14; i++) hand[tiles[i]]++;
        var discards = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
        var visible = new int[27];
        var publicCount = random.Next(8, 29);
        for (var i = 14; i < 14 + publicCount; i++)
        {
            var discardSeat = (i - 14) % 4;
            discards[discardSeat].Add(tiles[i]);
            visible[tiles[i]]++;
        }
        var remaining = Enumerable.Range(0, 27).Select(tile => Math.Max(0, 4 - hand[tile] - visible[tile])).ToArray();
        return SichuanStateCodec.FromRaw(
            seat, roundIndex % 4, seat, Math.Max(6, 81 - publicCount), hand, visible, remaining,
            discards18: discards, roundIndex: roundIndex);
    }

    private static SichuanStateView BuildReactionState(Random random, int seat, int roundIndex, out int reactionTile, out bool canGang)
    {
        while (true)
        {
            var tiles = BuildShuffledWall(random);
            var hand = new int[27];
            for (var i = 0; i < 13; i++) hand[tiles[i]]++;
            var pairs = Enumerable.Range(0, 27).Where(tile => hand[tile] >= 2).ToArray();
            if (pairs.Length == 0) continue;
            reactionTile = pairs[random.Next(pairs.Length)];
            canGang = hand[reactionTile] >= 3;
            var visible = new int[27];
            visible[reactionTile] = 1;
            var discards = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
            discards[(seat + 3) % 4].Add(reactionTile);
            var remaining = Enumerable.Range(0, 27).Select(tile => Math.Max(0, 4 - hand[tile] - visible[tile])).ToArray();
            return SichuanStateCodec.FromRaw(
                seat, roundIndex % 4, (seat + 3) % 4, random.Next(6, 56), hand, visible, remaining,
                discards18: discards, roundIndex: roundIndex);
        }
    }

    private static int[] BuildShuffledWall(Random random)
    {
        var wall = Enumerable.Range(0, 27).SelectMany(tile => Enumerable.Repeat(tile, 4)).ToArray();
        for (var i = wall.Length - 1; i > 0; i--)
        {
            var swap = random.Next(i + 1);
            (wall[i], wall[swap]) = (wall[swap], wall[i]);
        }
        return wall;
    }

    private static (double Low, double High) BootstrapMeanInterval(IReadOnlyList<double> values, int seed)
    {
        var random = new Random(seed);
        var means = new double[800];
        for (var sample = 0; sample < means.Length; sample++)
        {
            var sum = 0.0;
            for (var i = 0; i < values.Count; i++) sum += values[random.Next(values.Count)];
            means[sample] = sum / values.Count;
        }
        Array.Sort(means);
        return (means[(int)(means.Length * 0.025)], means[(int)(means.Length * 0.975)]);
    }
}
