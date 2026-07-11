namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanPosteriorNormalizationResult
{
    public double[] WallProbability18 { get; init; } = new double[27];
    public double[] WallExpectedCount18 { get; init; } = new double[27];
    public Dictionary<int, double[]> SeatHoldProbability18 { get; init; } = new();
    public Dictionary<int, double[]> SeatExpectedCount18 { get; init; } = new();
    public double MaxConservationOverflow { get; init; }
}
