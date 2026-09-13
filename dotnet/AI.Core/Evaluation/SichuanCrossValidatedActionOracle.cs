using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Evaluation;

public sealed record SichuanOracleValueBreakdown(
    double ShapeProgress,
    double WinGain,
    double GangGain,
    double ChaJiaoValue,
    double DealInLoss,
    double RouteValue,
    double UncertaintyPenalty)
{
    public double Net => ShapeProgress + WinGain + GangGain + ChaJiaoValue + RouteValue - DealInLoss - UncertaintyPenalty;
}

public sealed record SichuanOracleActionEstimate(
    string ActionKey,
    double SelectionMean,
    double ValidationMean,
    double ValidationStdDev,
    double ConfidenceLow,
    double ConfidenceHigh,
    double ValidationRegret,
    SichuanOracleValueBreakdown Breakdown,
    int Samples);

public sealed record SichuanCrossValidatedOracleResult(
    string SelectedAction,
    string ValidationBestAction,
    double CrossValidatedRegret,
    IReadOnlyList<SichuanOracleActionEstimate> Actions,
    int ParticleCount,
    int Seed);

/// <summary>
/// Offline teacher that never reads production candidate scores. Candidate actions share the
/// same hidden-hand/wall particles; even particles select and odd particles validate.
/// </summary>
public sealed class SichuanCrossValidatedActionOracle
{
    private readonly SichuanHiddenHandInferenceEngine _inference = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanActionTransitionEngine _transitions = new();
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanSettlementProjectionEngine _settlement = new();

    public SichuanCrossValidatedOracleResult EvaluateDiscards(
        SichuanStateView state,
        int particleCount = 64,
        int seed = 20260810)
    {
        var source = _transitions.FromState(state);
        var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
            && Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
            ? state.OwnDingQueSuit : -1;
        var legalTiles = Enumerable.Range(0, 27)
            .Where(tile => state.Hand18[tile] > 0 && (forcedSuit < 0 || tile / 9 == forcedSuit))
            .Select(tile => (key: $"discard:{tile}", state: _transitions.ApplyDiscard(source, tile), immediateGang: 0.0, discardedTile: tile, meldTile: -1))
            .ToArray();
        return Evaluate(state, legalTiles, particleCount, seed);
    }

    public SichuanCrossValidatedOracleResult EvaluateReaction(
        SichuanStateView state,
        int tileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        int sourceSeat,
        int particleCount = 64,
        int seed = 20260810)
    {
        var source = _transitions.FromState(state);
        var actions = new List<(string key, SichuanSimulatedHandState state, double immediateGang, int discardedTile, int meldTile)>
        {
            ("pass", _transitions.ApplyPass(source), 0, -1, -1)
        };
        if (canPeng && state.Hand18[tileType] >= 2)
            actions.Add(($"peng:{tileType}", _transitions.ApplyPeng(source, tileType), 0, -2, tileType));
        if (canGang && state.Hand18[tileType] >= 3)
            actions.Add(($"gang:{tileType}", _transitions.ApplyMeldedGang(source, tileType), 2, -3, tileType));
        if (canHu)
            actions.Add(($"hu:{tileType}", source, ImmediateHuGain(state, tileType, sourceSeat), -4, -1));
        return Evaluate(state, actions, particleCount, seed ^ (tileType << 9));
    }

    private SichuanCrossValidatedOracleResult Evaluate(
        SichuanStateView state,
        IReadOnlyList<(string key, SichuanSimulatedHandState state, double immediateGang, int discardedTile, int meldTile)> actions,
        int particleCount,
        int seed)
    {
        particleCount = Math.Clamp(particleCount, 32, 1024);
        var particles = _inference.SampleParticles(state, particleCount, seed);
        var dealInLosses = particles.Select(particle => BuildDealInLosses(state, particle)).ToArray();
        var raw = new List<(string key, List<(SichuanOracleValueBreakdown value, double weight)> selection, List<(SichuanOracleValueBreakdown value, double weight)> validation)>();
        foreach (var action in actions)
        {
            var selection = new List<(SichuanOracleValueBreakdown value, double weight)>();
            var validation = new List<(SichuanOracleValueBreakdown value, double weight)>();
            for (var index = 0; index < particles.Count; index++)
            {
                var value = EvaluateParticle(state, action, particles[index], dealInLosses[index]);
                (index % 2 == 0 ? selection : validation).Add((value, particles[index].Weight));
            }
            if (validation.Count == 0) validation.AddRange(selection);
            raw.Add((action.key, selection, validation));
        }

        var selected = raw.OrderByDescending(item => WeightedMean(item.selection)).ThenBy(item => item.key).First();
        var validationBest = raw.OrderByDescending(item => WeightedMean(item.validation)).ThenBy(item => item.key).First();
        var bestValidation = WeightedMean(validationBest.validation);
        var estimates = raw.Select(item =>
        {
            var mean = WeightedMean(item.validation);
            var std = WeightedStandardDeviation(item.validation, mean);
            var effectiveSamples = EffectiveSampleSize(item.validation);
            var half = effectiveSamples <= 1 ? 0 : 1.96 * std / Math.Sqrt(effectiveSamples);
            return new SichuanOracleActionEstimate(
                item.key,
                WeightedMean(item.selection),
                mean,
                std,
                mean - half,
                mean + half,
                Math.Max(0, bestValidation - mean),
                WeightedAverage(item.validation),
                item.validation.Count);
        }).OrderByDescending(item => item.ValidationMean).ThenBy(item => item.ActionKey).ToArray();
        var selectedEstimate = estimates.First(item => item.ActionKey == selected.key);
        return new SichuanCrossValidatedOracleResult(
            selected.key,
            validationBest.key,
            selectedEstimate.ValidationRegret,
            estimates,
            particles.Count,
            seed);
    }

    private SichuanOracleValueBreakdown EvaluateParticle(
        SichuanStateView state,
        (string key, SichuanSimulatedHandState state, double immediateGang, int discardedTile, int meldTile) action,
        SichuanHiddenHandParticle particle,
        IReadOnlyList<double> dealInLosses)
    {
        if (action.discardedTile == -4)
            return new SichuanOracleValueBreakdown(0, action.immediateGang, 0, 0, 0, 0, 0);

        var wall = particle.Wall27;
        if (action.discardedTile == -3)
            return EvaluateGangBranches(state, action.state, wall, particle, dealInLosses, action.immediateGang, action.meldTile);

        if (action.discardedTile == -1)
            return EvaluateWaitingState(state, action.state, wall, particle, 0, 0);

        if (action.discardedTile == -2)
            return BestDiscardValue(state, action.state, wall, particle, dealInLosses, 0);

        return EvaluatePostDiscard(state, action.state, wall, particle, dealInLosses, action.discardedTile, 0);
    }

    private SichuanOracleValueBreakdown EvaluateGangBranches(
        SichuanStateView state,
        SichuanSimulatedHandState gang,
        IReadOnlyList<int> wall,
        SichuanHiddenHandParticle particle,
        IReadOnlyList<double> dealInLosses,
        double immediateGang,
        int gangTile)
    {
        var total = wall.Sum();
        if (total <= 0)
            return EvaluateWaitingState(state, gang, wall, particle, immediateGang, 0.6);
        var branches = new List<(SichuanOracleValueBreakdown value, double weight)>();
        for (var draw = 0; draw < 27; draw++)
        {
            if (wall[draw] <= 0 || gang.Hand27[draw] >= 4) continue;
            var branchWall = wall.ToArray();
            branchWall[draw]--;
            var replacement = _transitions.ApplyReplacementDraw(gang, draw);
            if (_hands.IsWinning(replacement.Hand27, replacement.MeldCount, replacement.MeldCount == 0))
            {
                var melds = InferOwnMelds(state, replacement.MeldCount, gangTile);
                var fan = _fans.Project(replacement.Hand27, melds, SichuanWinType.GangSelfDraw);
                var payers = Math.Max(1, state.ActiveSeats.Count(active => active) - 1);
                branches.Add((new SichuanOracleValueBreakdown(0, fan.PerPayerScore * payers, immediateGang, 0, 0, 0, 0), wall[draw]));
            }
            else
            {
                branches.Add((BestDiscardValue(state, replacement, branchWall, particle, dealInLosses, immediateGang), wall[draw]));
            }
        }
        return WeightedAverage(branches);
    }

    private SichuanOracleValueBreakdown BestDiscardValue(
        SichuanStateView state,
        SichuanSimulatedHandState source,
        IReadOnlyList<int> wall,
        SichuanHiddenHandParticle particle,
        IReadOnlyList<double> dealInLosses,
        double immediateGang)
    {
        var candidates = Enumerable.Range(0, 27).Where(tile => source.Hand27[tile] > 0)
            .Select(tile => EvaluatePostDiscard(state, _transitions.ApplyDiscard(source, tile), wall, particle, dealInLosses, tile, immediateGang))
            .OrderByDescending(item => item.Net)
            .ToArray();
        return candidates.FirstOrDefault() ?? new SichuanOracleValueBreakdown(-32, 0, immediateGang, 0, 0, 0, 2);
    }

    private SichuanOracleValueBreakdown EvaluatePostDiscard(
        SichuanStateView state,
        SichuanSimulatedHandState after,
        IReadOnlyList<int> wall,
        SichuanHiddenHandParticle particle,
        IReadOnlyList<double> dealInLosses,
        int discardedTile,
        double immediateGang)
    {
        var baseValue = EvaluateWaitingState(state, after, wall, particle, immediateGang, 0);
        var dealInLoss = discardedTile is >= 0 and < 27 ? dealInLosses[discardedTile] : 0;
        return baseValue with { DealInLoss = dealInLoss };
    }

    private SichuanOracleValueBreakdown EvaluateWaitingState(
        SichuanStateView state,
        SichuanSimulatedHandState simulated,
        IReadOnlyList<int> wall,
        SichuanHiddenHandParticle particle,
        double immediateGang,
        double uncertainty)
    {
        var shanten = _shanten.CalcBestShanten(simulated.Hand27, simulated.MeldCount, simulated.MeldCount == 0);
        var improving = 0;
        var current = shanten;
        for (var tile = 0; tile < 27; tile++)
        {
            if (wall[tile] <= 0 || simulated.Hand27[tile] >= 4) continue;
            var drawn = (int[])simulated.Hand27.Clone();
            drawn[tile]++;
            var after = _shanten.CalcBestShanten(drawn, simulated.MeldCount, simulated.MeldCount == 0);
            if (after < current) improving += wall[tile];
        }
        var shape = -current * 4.2 + improving * 0.18;
        var route = RouteValue(simulated.Hand27, simulated.MeldCount);
        var chaJiao = state.WallCount <= 8 && current <= 0 ? 1.5 + improving * 0.08 : 0;
        return new SichuanOracleValueBreakdown(shape, 0, immediateGang, chaJiao, 0, route, uncertainty);
    }

    private double[] BuildDealInLosses(SichuanStateView state, SichuanHiddenHandParticle particle)
    {
        var losses = new double[27];
        for (var seat = 0; seat < 4; seat++)
        {
            if (seat == state.SeatIndex || !state.ActiveSeats[seat] || state.HasHu[seat]) continue;
            var meldCount = Math.Max(0, state.Melds18[seat].Count / 3);
            var waits = _hands.EnumerateWaits(particle.Hands27[seat], particle.Wall27, meldCount);
            foreach (var wait in waits)
            {
                var completed = (int[])particle.Hands27[seat].Clone();
                completed[wait.TileType]++;
                var fan = _fans.Project(completed, InferMelds(state, seat), SichuanWinType.Discard);
                losses[wait.TileType] += Math.Max(1, fan.HandScore);
            }
        }
        return losses;
    }

    private double ImmediateHuGain(SichuanStateView state, int tileType, int sourceSeat)
    {
        var completed = (int[])state.Hand18.Clone();
        completed[tileType]++;
        var fan = _fans.Project(completed, InferMelds(state, state.SeatIndex), SichuanWinType.Discard);
        return _settlement.ProjectWin(state.SeatIndex, sourceSeat, ActiveSeatIndexes(state), fan, SichuanWinType.Discard).WinnerGain;
    }

    private static IReadOnlyList<int> ActiveSeatIndexes(SichuanStateView state)
        => Enumerable.Range(0, 4).Where(seat => state.ActiveSeats[seat] && !state.HasHu[seat]).ToArray();

    private static IReadOnlyList<SichuanMeldView> InferMelds(SichuanStateView state, int seat)
        => state.MeldViews[seat].Count > 0
            ? state.MeldViews[seat]
            : state.Melds18[seat].Chunk(3).Where(chunk => chunk.Length == 3)
                .Select(chunk => new SichuanMeldView(SichuanMeldType.Peng, chunk[0], seat, 0)).ToArray();

    private static IReadOnlyList<SichuanMeldView> InferOwnMelds(SichuanStateView state, int targetMeldCount, int gangTile)
    {
        var result = InferMelds(state, state.SeatIndex).ToList();
        while (result.Count < targetMeldCount)
            result.Add(new SichuanMeldView(SichuanMeldType.MeldedGang, Math.Max(0, gangTile), state.SeatIndex, 0));
        return result;
    }

    private static double RouteValue(IReadOnlyList<int> hand, int meldCount)
    {
        var pairs = hand.Count(count => count >= 2);
        var triples = hand.Count(count => count >= 3) + meldCount;
        var suitTotals = Enumerable.Range(0, 3).Select(suit => Enumerable.Range(suit * 9, 9).Sum(tile => hand[tile])).ToArray();
        var qing = suitTotals.Max() >= Math.Max(1, hand.Sum() - 2) ? 0.9 : 0;
        var sevenPairs = meldCount == 0 && pairs >= 4 ? (pairs - 3) * 0.28 : 0;
        var triplets = triples >= 3 ? (triples - 2) * 0.22 : 0;
        return qing + sevenPairs + triplets;
    }

    private static double WeightedMean(IReadOnlyList<(SichuanOracleValueBreakdown value, double weight)> values)
    {
        var total = values.Sum(item => item.weight);
        return total <= 0 ? -100 : values.Sum(item => item.value.Net * item.weight) / total;
    }

    private static SichuanOracleValueBreakdown WeightedAverage(IReadOnlyList<(SichuanOracleValueBreakdown value, double weight)> values)
    {
        var total = values.Sum(item => item.weight);
        if (total <= 0) return new SichuanOracleValueBreakdown(-32, 0, 0, 0, 0, 0, 2);
        return new SichuanOracleValueBreakdown(
            values.Sum(item => item.value.ShapeProgress * item.weight) / total,
            values.Sum(item => item.value.WinGain * item.weight) / total,
            values.Sum(item => item.value.GangGain * item.weight) / total,
            values.Sum(item => item.value.ChaJiaoValue * item.weight) / total,
            values.Sum(item => item.value.DealInLoss * item.weight) / total,
            values.Sum(item => item.value.RouteValue * item.weight) / total,
            values.Sum(item => item.value.UncertaintyPenalty * item.weight) / total);
    }

    private static double WeightedStandardDeviation(
        IReadOnlyList<(SichuanOracleValueBreakdown value, double weight)> values,
        double mean)
    {
        var total = values.Sum(item => item.weight);
        var squaredWeight = values.Sum(item => item.weight * item.weight);
        var denominator = total - squaredWeight / Math.Max(total, double.Epsilon);
        if (values.Count <= 1 || denominator <= 0) return 0;
        return Math.Sqrt(values.Sum(item => item.weight * Math.Pow(item.value.Net - mean, 2)) / denominator);
    }

    private static double EffectiveSampleSize(
        IReadOnlyList<(SichuanOracleValueBreakdown value, double weight)> values)
    {
        var total = values.Sum(item => item.weight);
        var squaredWeight = values.Sum(item => item.weight * item.weight);
        return squaredWeight <= 0 ? 0 : total * total / squaredWeight;
    }
}
