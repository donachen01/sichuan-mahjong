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
    private readonly SichuanIndependentDecisionJudge _judge = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanShantenEngine _shanten = new();

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
            var baseline = SelectFrozenHardTierDiscard(state);
            var candidateJudge = _judge.JudgeDiscard(state, candidate);
            var baselineJudge = _judge.JudgeDiscard(state, baseline);
            candidateRegrets.Add(candidateJudge.Regret);
            baselineRegrets.Add(baselineJudge.Regret);
            pairedImprovements.Add(baselineJudge.Regret - candidateJudge.Regret);
            bySeat[seat].Add(candidateJudge.Regret);
            if (candidateJudge.Regret >= 2.5) candidateSevere++;
            if (baselineJudge.Regret >= 2.5) baselineSevere++;
            if (IsRegrettedPairBreak(state, candidate, candidateJudge)) candidatePairBreak++;
            if (IsRegrettedPairBreak(state, baseline, baselineJudge)) baselinePairBreak++;
            if (candidateJudge.Regret > baselineJudge.Regret + 0.01)
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
                    candidateJudge.BestAction,
                    candidateJudge.Regret,
                    baselineJudge.Regret,
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
            var baselineReaction = SelectFrozenReaction(reactionState, reactionTile, canGang);
            candidateReactionRegrets.Add(_judge.JudgeReaction(reactionState, candidateReaction, reactionTile, false, true, canGang).Regret);
            baselineReactionRegrets.Add(_judge.JudgeReaction(reactionState, baselineReaction, reactionTile, false, true, canGang).Regret);
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
        if (candidateAverage > baselineAverage) gateReasons.Add("候选弃牌后悔值高于冻结基线");
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

    private int SelectFrozenHardTierDiscard(SichuanStateView state)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
            && Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
            ? state.OwnDingQueSuit : -1;
        return _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount, true, forcedSuit)
            .OrderBy(item => item.Shanten)
            .ThenByDescending(item => item.LiveUkeire)
            .ThenByDescending(item => item.WaitQuality)
            .ThenBy(item => item.StructuralLoss)
            .ThenBy(item => item.DiscardTileType)
            .Select(item => item.DiscardTileType)
            .DefaultIfEmpty(-1)
            .First();
    }

    private SichuanActionType SelectFrozenReaction(SichuanStateView state, int tileType, bool canGang)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var current = _shanten.CalcBestShanten(state.Hand18, meldCount, meldCount == 0);
        var pengHand = (int[])state.Hand18.Clone();
        pengHand[tileType] -= 2;
        var peng = _hands.AnalyzeDiscards(pengHand, state.Remaining18, meldCount + 1, false)
            .Select(item => item.Shanten).DefaultIfEmpty(8).Min();
        if (canGang && state.WallCount > 8)
        {
            var gangHand = (int[])state.Hand18.Clone();
            gangHand[tileType] -= 3;
            var oldPreReplacementGang = _shanten.CalcBestShanten(gangHand, meldCount + 1, false);
            if (oldPreReplacementGang <= peng) return SichuanActionType.Gang;
        }
        return peng < current ? SichuanActionType.Peng : SichuanActionType.Pass;
    }

    private static bool IsRegrettedPairBreak(SichuanStateView state, int tile, SichuanDecisionJudgement judgement)
        => tile is >= 0 and < 27 && state.Hand18[tile] >= 2 && judgement.Regret >= 0.45;

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
