using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanDingQueDecisionEngine
{
    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyList<int> hand18,
        IReadOnlyList<string> activeSuits)
    {
        using var decisionScope = Decision.SichuanPolicyExecutionScope.EnterDecision();
        if (hand18.Count != 27 || hand18.Any(count => count is < 0 or > 4) || hand18.Sum() is not (13 or 14))
            throw new ArgumentException("Ding Que requires 27 valid tile counts.", nameof(hand18));
        var suits = activeSuits.Count == 3 ? activeSuits : new[] { "tiao", "tong", "wan" };
        // Canonicalize the public hand before finite sampling and tie-breaking.
        // Merely renaming suits must not select a different retained structure.
        // Identical suit vectors are genuinely interchangeable; their labels
        // carry no strategy information.
        var order = Enumerable.Range(0, 3)
            .OrderBy(suit => string.Concat(Enumerable.Range(suit * 9, 9).Select(tile => (char)('0' + hand18[tile]))), StringComparer.Ordinal)
            .ToArray();
        return DecideCanonical(
            order.SelectMany(suit => Enumerable.Range(suit * 9, 9).Select(tile => hand18[tile])).ToArray(),
            order.Select(suit => suits[suit]).ToArray());
    }

    private static SichuanDingQueDecisionResult DecideCanonical(
        IReadOnlyList<int> hand18, IReadOnlyList<string> suits)
    {
        var counts = Enumerable.Range(0, 3).ToDictionary(s => suits[s], s =>
            Enumerable.Range(s * 9, 9).Sum(tile => hand18[tile]));
        var scorer = new SichuanKScoreEngine();
        var evaluations = Enumerable.Range(0, 3).Select(s =>
            scorer.Evaluate(hand18.Skip(s * 9).Take(9).ToArray())).ToArray();
        var minimum = evaluations.Min(e => e.Total);
        var tied = Enumerable.Range(0, 3).Where(s => evaluations[s].Total == minimum).ToArray();
        var selected = tied[0];
        var tieReason = "最低分唯一";
        var pairDevelopment = SichuanDominantSuitDingQue.PreferPairAfterMainMelds(hand18, suits);
        if (pairDevelopment is not null)
        {
            selected = pairDevelopment.MissingSuit;
            tieReason = "按人工讨论落实面子拆分后缺将的保对发展：" + pairDevelopment.Explanation;
        }
        else if (tied.Length > 1)
        {
            // Earlier chapter's structural policy may resolve exact ties only;
            // it cannot override even a one-point K-score difference.
            var shanten = new SichuanShantenEngine();
            var distances = Enumerable.Range(0, 3).Select(s =>
            {
                var kept = hand18.ToArray();
                Array.Clear(kept, s * 9, 9);
                return shanten.CalcBestShanten(kept);
            }).ToArray();
            var dominant = SichuanDominantSuitDingQue.Compare(hand18, distances, suits);
            if (dominant is not null && tied.Contains(dominant.MissingSuit))
            {
                selected = dominant.MissingSuit;
                tieReason = "同为最低分，用已学习的副门结构比较：" + dominant.Explanation;
            }
            else tieReason = "同为最低分，按牌形规范顺序确定；不改选较高分门";
        }
        return new SichuanDingQueDecisionResult
        {
            Suit = suits[selected],
            Score = evaluations[selected].Total,
            SuitCounts = counts,
            KScoreBySuit = Enumerable.Range(0, 3).ToDictionary(s => suits[s], s => evaluations[s].Total),
            Reasons = new[] { pairDevelopment is null
                ? "K神定缺评分：每张10分，枚举互斥拆分取最高分，严格定缺三门最低分；三连坎+3"
                : "定缺采用已讨论的面子拆分后缺将条件；K神互斥评分保留为诊断，三连坎+3；返回Score为实际所选门K分" }
                .Concat(Enumerable.Range(0, 3).Select(s => $"{suits[s]}：基础{evaluations[s].BaseScore}，加扣{evaluations[s].Bonus}，总分{evaluations[s].Total}；"
                    + string.Join("；", evaluations[s].Groups.Select(g => $"{g.Kind}{string.Concat(g.Ranks)}({g.Bonus:+0;-0;0})"))))
                .Append(tieReason).ToArray()
        };
    }

    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyDictionary<string, int> suitCounts,
        IReadOnlyList<string> activeSuits)
    {
        throw new ArgumentException("严格K评分需要完整起手牌，三门张数不足以计算结构；禁止数量回退。", nameof(suitCounts));
    }
}
