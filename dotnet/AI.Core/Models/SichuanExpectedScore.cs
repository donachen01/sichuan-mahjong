namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanExpectedScore
{
    public double Net { get; init; }
    public double WinGain { get; init; }
    public double DealInLoss { get; init; }
    public double DrawRiskLoss { get; init; }
    public double ReadyValue { get; init; }
    public double EstimatedFan { get; init; }
    public int EstimatedBaseScore { get; init; }
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
