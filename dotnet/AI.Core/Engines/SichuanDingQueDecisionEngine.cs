using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanDingQueDecisionEngine
{
    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyList<int> hand18,
        IReadOnlyList<string> activeSuits)
    {
        if (hand18.Count != 27 || hand18.Any(count => count is < 0 or > 4))
            throw new ArgumentException("Ding Que requires 27 valid tile counts.", nameof(hand18));
        var suits = activeSuits.Count == 3 ? activeSuits : new[] { "tiao", "tong", "wan" };
        var counts = Enumerable.Range(0, 3).ToDictionary(s => suits[s], s =>
            Enumerable.Range(s * 9, 9).Sum(tile => hand18[tile]));
        var costs = new double[3];
        for (var suit = 0; suit < 3; suit++)
        {
            var start = suit * 9;
            costs[suit] = counts[suits[suit]];
            for (var rank = 0; rank < 9; rank++)
            {
                var copies = hand18[start + rank];
                if (copies >= 2) costs[suit] += 0.60;
                if (copies >= 3) costs[suit] += 0.65;
                if (rank < 8 && copies > 0 && hand18[start + rank + 1] > 0) costs[suit] += 0.32;
                if (rank < 7 && copies > 0 && hand18[start + rank + 2] > 0) costs[suit] += 0.14;
                if (rank < 7 && copies > 0 && hand18[start + rank + 1] > 0
                    && hand18[start + rank + 2] > 0) costs[suit] += 0.40;
            }
        }
        var selected = Enumerable.Range(0, 3)
            .OrderBy(suit => costs[suit]).ThenBy(suit => suit).First();
        return new SichuanDingQueDecisionResult
        {
            Suit = suits[selected],
            Score = (int)Math.Round(100 - costs[selected] * 10),
            SuitCounts = counts,
            Reasons = new[]
            {
                "定缺比较三门牌的清除张数和已成型搭子",
                $"{suits[selected]} {counts[suits[selected]]} 张，清除成本 {costs[selected]:F2}"
            }
        };
    }

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
