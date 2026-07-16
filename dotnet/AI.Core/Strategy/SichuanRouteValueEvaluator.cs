using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanRouteValue(
    string Route,
    double ExpectedValue,
    double CompletionProbability,
    double ExitValue,
    int TargetSuit,
    IReadOnlyList<string> Reasons);

public sealed class SichuanRouteValueEvaluator
{
    public IReadOnlyList<SichuanRouteValue> Evaluate(SichuanStateView state)
    {
        var hand = state.Hand18;
        var total = Math.Max(1, hand.Sum());
        var suitCounts = Enumerable.Range(0, 3).Select(suit => Enumerable.Range(suit * 9, 9).Sum(tile => hand[tile])).ToArray();
        var targetSuit = Array.IndexOf(suitCounts, suitCounts.Max());
        var offSuit = total - suitCounts[targetSuit];
        var pairs = hand.Count(value => value >= 2);
        var triplets = hand.Count(value => value >= 3) + state.Melds18[state.SeatIndex].Count / 3;
        var stage = state.WallCount <= 8 ? 2 : state.WallCount <= 16 ? 1 : 0;
        var capDampening = 0.72;

        var fastProbability = Math.Clamp(0.30 + total / 40.0 - stage * 0.05, 0.08, 0.80);
        var qingProbability = Math.Clamp(0.08 + suitCounts[targetSuit] * 0.065 - offSuit * 0.09 - stage * 0.04, 0.01, 0.82);
        var qiDuiProbability = state.Melds18[state.SeatIndex].Count == 0 ? Math.Clamp(0.04 + pairs * 0.105 - stage * 0.03, 0.01, 0.78) : 0;
        var pungProbability = Math.Clamp(0.05 + pairs * 0.045 + triplets * 0.13 - stage * 0.025, 0.01, 0.72);

        return new[]
        {
            new SichuanRouteValue("快速平胡", fastProbability * 2.2 + 0.45, fastProbability, 0.9, -1, new[] { "宽进张和成叫速度作为基础退路" }),
            new SichuanRouteValue("清一色", qingProbability * 8 * capDampening + (offSuit <= 3 ? 0.8 : 0), qingProbability, Math.Max(0.1, 0.8 - offSuit * 0.12), targetSuit, new[] { $"目标门保有 {suitCounts[targetSuit]} 张，异门 {offSuit} 张", "达到封顶后降低继续做大权重" }),
            new SichuanRouteValue("七对", qiDuiProbability * 8 * capDampening + pairs * 0.08, qiDuiProbability, pairs >= 5 ? 0.55 : 0.25, -1, new[] { $"对子资产 {pairs} 组", "门清且五对以上才提高承诺" }),
            new SichuanRouteValue("大对子", pungProbability * 4 * capDampening + triplets * 0.15, pungProbability, 0.45, -1, new[] { $"刻子/副露资产 {triplets} 组", "碰杠必须经过反事实速度比较" })
        }.OrderByDescending(item => item.ExpectedValue).ToArray();
    }
}
