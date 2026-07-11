using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanDingQueDecisionEngine
{
    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyDictionary<string, int> suitCounts,
        IReadOnlyList<string> activeSuits)
    {
        var suits = activeSuits.Count > 0
            ? activeSuits.Where(suit => !string.IsNullOrWhiteSpace(suit)).Distinct().ToArray()
            : new[] { "tiao", "tong", "wan" };
        if (suits.Length == 0)
            suits = new[] { "tiao", "tong", "wan" };

        var normalized = suits.ToDictionary(
            suit => suit,
            suit => Math.Max(0, suitCounts.GetValueOrDefault(suit, 0)));
        var selected = normalized
            .OrderBy(item => item.Value)
            .ThenBy(item => Array.IndexOf(suits, item.Key))
            .First();

        return new SichuanDingQueDecisionResult
        {
            Suit = selected.Key,
            Score = 100 - selected.Value * 10,
            SuitCounts = normalized,
            Reasons = new[]
            {
                "C#定缺：选择手牌数量最少的花色",
                $"候选 {selected.Key} 数量 {selected.Value}"
            }
        };
    }
}
