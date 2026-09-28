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
        var diagnostics = new string[3];
        var shanten = new SichuanShantenEngine();
        for (var suit = 0; suit < 3; suit++)
        {
            // Compare the retained two-suit structure, not overlapping bonuses
            // for the same pair/sequence in the removed suit.
            var kept = hand18.ToArray();
            for (var tile = suit*9; tile < suit*9+9; tile++) kept[tile] = 0;
            var distance = shanten.CalcBestShanten(kept);
            var standard = shanten.CalcStandardShanten(kept);
            var pairs = shanten.CalcSevenPairsShanten(kept);
            var live = 0;
            var unseen = 0;
            for (var tile = 0; tile < 27; tile++)
            {
                if (tile/9 == suit || kept[tile] >= 4) continue;
                var copies = 4-hand18[tile];
                unseen += copies;
                kept[tile]++;
                if (shanten.CalcBestShanten(kept) < distance) live += copies;
                kept[tile]--;
            }
            // Partial hands have different live-tile rates. Dividing the whole
            // completion distance by the first improvement rate overvalues a
            // pile of isolated tiles. Structural distance is the primary cost;
            // live count resolves nearby routes without erasing completed sets.
            costs[suit] = distance * 2.0 + counts[suits[suit]] * 0.35
                - live / (double)Math.Max(1, unseen);
            diagnostics[suit] = $"{suits[suit]}：清缺 {counts[suits[suit]]}，保留结构向听 {distance}（普通 {standard}/七对 {pairs}），有效进张 {live}，预计成本 {costs[suit]:F2}";
        }
        var selected = Enumerable.Range(0, 3)
            .OrderBy(suit => costs[suit]).ThenBy(suit => suit).First();
        var rollout = hand18.Sum() is 13 or 14
            ? new SichuanDingQueRollout().Compare(hand18, selected) : null;
        if (rollout?.PreferredSuit is int preferred) selected = preferred;
        var rolloutReason = rollout is null ? "非开局手牌，不运行摸打模拟"
            : $"公开未知牌配对模拟 {rollout.Samples} 组、每组最多 {rollout.Horizon} 次自身摸牌：三方案进度成本 {string.Join("/", rollout.Costs.Select(v => v.ToString("F2")))}；配对优势 {rollout.PairedAdvantage:F2}、标准误 {rollout.StandardError:F2}；未计对手碰杠";
        return new SichuanDingQueDecisionResult
        {
            Suit = suits[selected],
            Score = (int)Math.Round(100 - costs[selected] * 10),
            SuitCounts = counts,
            Reasons = new[]
            {
                "定缺分别比较三种方案清缺成本、保留牌形和有效进张",
                diagnostics[0], diagnostics[1], diagnostics[2], rolloutReason
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
