namespace SichuanMahjong.AI.Core.Decision;

/// <summary>A model hypothesis, never an observed hidden wall or wall order.</summary>
public sealed record SichuanWeightedWall(IReadOnlyList<int> Counts, double Weight);

/// <summary>
/// First and ordered second draw laws for a weighted mixture of uniformly
/// permuted walls. Keeps factorial second moments, including same-tile draws.
/// This is exact for the supplied model, not evidence that its weights are calibrated.
/// </summary>
public sealed class SichuanJointWallDrawModel
{
    private readonly double[] _first = new double[27];
    private readonly double[,] _joint = new double[27, 27];
    private readonly int[] _maxCopies = new int[27];

    public int WallCount { get; }
    public double EffectiveSampleSize { get; }
    public double FirstProbability(int tile) => _first[tile];
    public double JointProbability(int first, int second) => _joint[first, second];
    public int MaximumCopies(int tile) => _maxCopies[tile];

    public SichuanJointWallDrawModel(IReadOnlyList<SichuanWeightedWall> hypotheses)
    {
        ArgumentNullException.ThrowIfNull(hypotheses);
        if (hypotheses.Count is < 1 or > 4096)
            throw new ArgumentException("Require 1..4096 model hypotheses", nameof(hypotheses));
        foreach (var hypothesis in hypotheses)
        {
            if (hypothesis.Counts.Count != 27 || hypothesis.Counts.Any(n => n is < 0 or > 4)
                || !double.IsFinite(hypothesis.Weight) || hypothesis.Weight < 0)
                throw new ArgumentException("Invalid wall hypothesis", nameof(hypotheses));
        }
        WallCount = hypotheses[0].Counts.Sum();
        if (hypotheses.Any(h => h.Counts.Sum() != WallCount))
            throw new ArgumentException("Wall size must agree across hypotheses", nameof(hypotheses));
        var maxWeight = hypotheses.Max(h => h.Weight);
        if (maxWeight <= 0) throw new ArgumentException("Positive total weight required", nameof(hypotheses));
        // Scaling first avoids overflow for valid, very large finite weights.
        var scaledTotal = hypotheses.Sum(h => h.Weight / maxWeight);
        var sumSquares = 0.0;
        foreach (var hypothesis in hypotheses.Where(h => h.Weight > 0))
        {
            var weight = (hypothesis.Weight / maxWeight) / scaledTotal;
            sumSquares += weight * weight;
            for (var first = 0; first < 27; first++)
            {
                var copies = hypothesis.Counts[first];
                _maxCopies[first] = Math.Max(_maxCopies[first], copies);
                if (WallCount == 0) continue;
                _first[first] += weight * copies / WallCount;
                if (WallCount < 2) continue;
                for (var second = 0; second < 27; second++)
                    _joint[first, second] += weight * copies
                        * (hypothesis.Counts[second] - (first == second ? 1 : 0))
                        / WallCount / (WallCount - 1.0);
            }
        }
        EffectiveSampleSize = 1 / sumSquares;
    }
}
