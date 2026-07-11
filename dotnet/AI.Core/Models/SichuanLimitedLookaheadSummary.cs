namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanLimitedLookaheadSummary
{
    public double Score { get; init; }
    public int SampledDrawCount { get; init; }
    public int BestNextShanten { get; init; } = 8;
    public int BestNextLiveUkeire { get; init; }
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
