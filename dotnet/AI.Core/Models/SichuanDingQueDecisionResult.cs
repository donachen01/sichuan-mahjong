namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanDingQueDecisionResult
{
    public string Suit { get; init; } = "";
    public int Score { get; init; }
    public IReadOnlyDictionary<string, int> KScoreBySuit { get; init; } = new Dictionary<string, int>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
    public IReadOnlyDictionary<string, int> SuitCounts { get; init; } = new Dictionary<string, int>();
}
