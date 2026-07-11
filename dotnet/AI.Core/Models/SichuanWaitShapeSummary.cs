namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanWaitShapeSummary
{
    public int RyanmenCount { get; init; }
    public int KanchanCount { get; init; }
    public int PenchanCount { get; init; }
    public int TankiCount { get; init; }
    public int ShanponCount { get; init; }
    public double WaitShapeScore { get; init; }
    public string Label { get; init; } = "未成听";
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
