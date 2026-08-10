using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Evaluation;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Learning;

public sealed record SichuanActionValueModel(
    string Version,
    IReadOnlyList<string> FeatureNames,
    IReadOnlyList<double> Coefficients,
    int TrainingStates,
    int TrainingActions,
    int Seed);

public sealed record SichuanActionValueTrainingResult(
    SichuanActionValueModel Model,
    int ValidationStates,
    int ValidationActions,
    double ValidationMeanAbsoluteError,
    double LearnedPolicyAverageRegret,
    double ProductionPolicyAverageRegret,
    double RegretImprovement,
    double LearnedTopOneRate,
    double ProductionTopOneRate,
    bool ShadowPromotionPassed,
    IReadOnlyList<string> GateReasons);

/// <summary>
/// Builds an offline shadow value model from independent oracle labels. It never changes the
/// production policy by itself; promotion is a separate, evidence-gated operation.
/// </summary>
public sealed class SichuanActionValueTrainingEngine
{
    private static readonly string[] FeatureNames =
    {
        "bias", "negative_shanten", "sqrt_live_ukeire", "wait_count", "wait_quality",
        "shape", "set_preservation", "breaks_pair", "breaks_triplet", "danger",
        "deal_in_probability", "expected_fan", "late_wall", "late_ready",
		"unified_action_value", "strategic_residual", "expected_net_score", "expected_ready_value",
		"posterior_adjustment", "limited_lookahead"
    };

    private readonly SichuanCrossValidatedActionOracle _oracle = new();

    public SichuanActionValueTrainingResult Train(int states = 640, int seed = 20260810)
    {
        states = Math.Clamp(states, 128, 5000);
        var trainCount = Math.Max(96, (int)Math.Round(states * 0.75));
        var training = BuildSamples(trainCount, seed, "train");
        var validation = BuildSamples(states - trainCount, seed ^ 0x5A17, "blind");
        var coefficients = FitRidge(training.SelectMany(item => item.Actions).ToArray(), 0.35);
        var model = new SichuanActionValueModel(
            "bone_ash_action_value_shadow_v1",
            FeatureNames,
            coefficients,
            training.Count,
            training.Sum(item => item.Actions.Count),
            seed);

        var absoluteErrors = new List<double>();
        var learnedRegrets = new List<double>();
        var productionRegrets = new List<double>();
        var learnedTopOne = 0;
        var productionTopOne = 0;
        foreach (var state in validation)
        {
            foreach (var action in state.Actions)
                absoluteErrors.Add(Math.Abs(Predict(coefficients, action.Features) - action.TargetValue));
            var oracleBest = state.Actions.OrderByDescending(item => item.TargetValue).ThenBy(item => item.ActionKey).First();
            var learned = state.Actions.OrderByDescending(item => Predict(coefficients, item.Features)).ThenBy(item => item.ActionKey).First();
            var production = state.Actions.First(item => item.ActionKey == state.ProductionAction);
            learnedRegrets.Add(Math.Max(0, oracleBest.TargetValue - learned.TargetValue));
            productionRegrets.Add(Math.Max(0, oracleBest.TargetValue - production.TargetValue));
            if (learned.ActionKey == oracleBest.ActionKey) learnedTopOne++;
            if (production.ActionKey == oracleBest.ActionKey) productionTopOne++;
        }

        var learnedAverage = learnedRegrets.Average();
        var productionAverage = productionRegrets.Average();
        var reasons = new List<string>();
		var requiredImprovement = Math.Max(0.005, productionAverage * 0.10);
        if (learnedAverage > productionAverage - requiredImprovement)
			reasons.Add($"影子模型的盲测后悔值没有形成至少 {requiredImprovement:F3} 的改善");
        if (learnedTopOne < productionTopOne)
            reasons.Add("影子模型盲测 Top-1 低于现有 bone_ash");
        if (validation.Count < 32)
            reasons.Add("盲测状态不足 32");
        if (reasons.Count == 0) reasons.Add("影子训练晋级门槛通过，可进入配对整局验证");

        return new SichuanActionValueTrainingResult(
            model,
            validation.Count,
            validation.Sum(item => item.Actions.Count),
            absoluteErrors.Average(),
            learnedAverage,
            productionAverage,
            productionAverage - learnedAverage,
            learnedTopOne / (double)validation.Count,
            productionTopOne / (double)validation.Count,
            reasons.Count == 1 && reasons[0].StartsWith("影子训练晋级", StringComparison.Ordinal),
            reasons);
    }

    private List<TrainingState> BuildSamples(int count, int seed, string split)
    {
        var random = new Random(seed);
        var result = new List<TrainingState>(count);
        for (var sample = 0; sample < count; sample++)
        {
            var state = BuildDiscardState(random, sample % 4, seed + sample);
            var production = new SichuanAiFacade().DecideDiscard(state);
			var oracle = _oracle.EvaluateDiscards(state, 48, seed ^ (sample * 7919));
            var actions = new List<TrainingAction>();
            foreach (var candidate in production.Candidates)
            {
                var estimate = oracle.Actions.FirstOrDefault(item => item.ActionKey == $"discard:{candidate.TileType}");
                if (estimate is null) continue;
                actions.Add(new TrainingAction(
                    estimate.ActionKey,
                    BuildFeatures(candidate, state.WallCount),
                    estimate.ValidationMean));
            }
            if (actions.Count < 2) continue;
            result.Add(new TrainingState(split, production.Action.TileType >= 0 ? $"discard:{production.Action.TileType}" : actions[0].ActionKey, actions));
        }
        return result;
    }

    private static double[] BuildFeatures(SichuanCandidateDetail item, int wallCount)
        => new[]
        {
            1.0,
            -item.Shanten / 4.0,
            Math.Sqrt(Math.Max(0, item.LiveUkeire)) / 4.0,
            item.WaitCount / 4.0,
            item.WaitQualityScore / 200.0,
            item.ShapeScore / 8.0,
            item.SetPreservationScore / 20.0,
            item.BreaksPair ? 1.0 : 0.0,
            item.BreaksTriplet ? 1.0 : 0.0,
            item.Danger / 100.0,
            item.DealInProbability,
            item.ExpectedFan / 4.0,
            wallCount <= 8 ? 1.0 : 0.0,
			wallCount <= 8 && item.Shanten <= 0 && item.WaitCount > 0 ? 1.0 : 0.0,
			item.UnifiedActionValue / 10.0,
			item.StrategicResidual / 10.0,
			item.ExpectedNetScore / 10.0,
			item.ExpectedReadyValue / 10.0,
			item.PosteriorAdjustment / 10.0,
			item.LimitedLookaheadScore / 10.0
        };

    private static double[] FitRidge(IReadOnlyList<TrainingAction> samples, double lambda)
    {
        var n = FeatureNames.Length;
        var matrix = new double[n, n];
        var target = new double[n];
        foreach (var sample in samples)
        {
            for (var row = 0; row < n; row++)
            {
                target[row] += sample.Features[row] * sample.TargetValue;
                for (var column = 0; column < n; column++)
                    matrix[row, column] += sample.Features[row] * sample.Features[column];
            }
        }
        for (var index = 1; index < n; index++) matrix[index, index] += lambda;
        return Solve(matrix, target);
    }

    private static double[] Solve(double[,] matrix, double[] target)
    {
        var n = target.Length;
        var augmented = new double[n, n + 1];
        for (var row = 0; row < n; row++)
        {
            for (var column = 0; column < n; column++) augmented[row, column] = matrix[row, column];
            augmented[row, n] = target[row];
        }
        for (var pivot = 0; pivot < n; pivot++)
        {
            var best = Enumerable.Range(pivot, n - pivot).OrderByDescending(row => Math.Abs(augmented[row, pivot])).First();
            if (best != pivot)
                for (var column = pivot; column <= n; column++)
                    (augmented[pivot, column], augmented[best, column]) = (augmented[best, column], augmented[pivot, column]);
            var divisor = Math.Abs(augmented[pivot, pivot]) < 1e-9 ? 1e-9 : augmented[pivot, pivot];
            for (var column = pivot; column <= n; column++) augmented[pivot, column] /= divisor;
            for (var row = 0; row < n; row++)
            {
                if (row == pivot) continue;
                var factor = augmented[row, pivot];
                for (var column = pivot; column <= n; column++) augmented[row, column] -= factor * augmented[pivot, column];
            }
        }
        return Enumerable.Range(0, n).Select(row => augmented[row, n]).ToArray();
    }

    private static double Predict(IReadOnlyList<double> coefficients, IReadOnlyList<double> features)
        => Enumerable.Range(0, Math.Min(coefficients.Count, features.Count)).Sum(index => coefficients[index] * features[index]);

    private static SichuanStateView BuildDiscardState(Random random, int seat, int roundIndex)
    {
        var wall = Enumerable.Range(0, 27).SelectMany(tile => Enumerable.Repeat(tile, 4)).ToArray();
        for (var index = wall.Length - 1; index > 0; index--)
        {
            var swap = random.Next(index + 1);
            (wall[index], wall[swap]) = (wall[swap], wall[index]);
        }
        var hand = new int[27];
        for (var index = 0; index < 14; index++) hand[wall[index]]++;
        var discards = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
        var visible = new int[27];
        var publicCount = random.Next(8, 58);
        for (var index = 14; index < Math.Min(wall.Length, 14 + publicCount); index++)
        {
            discards[(index - 14) % 4].Add(wall[index]);
            visible[wall[index]]++;
        }
        var remaining = Enumerable.Range(0, 27).Select(tile => Math.Max(0, 4 - hand[tile] - visible[tile])).ToArray();
        return SichuanStateCodec.FromRaw(
            seat, roundIndex % 4, seat, Math.Max(1, 81 - publicCount), hand, visible, remaining,
            discards18: discards, roundIndex: roundIndex);
    }

    private sealed record TrainingState(string Split, string ProductionAction, IReadOnlyList<TrainingAction> Actions);
    private sealed record TrainingAction(string ActionKey, double[] Features, double TargetValue);
}
