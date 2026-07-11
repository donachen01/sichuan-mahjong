namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanDangerEvaluation
{
    public int Risk { get; init; }
    public string RiskLabel { get; init; } = string.Empty;
    public int TopThreatSeat { get; init; } = -1;
    public double TopThreatScore { get; init; }
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
