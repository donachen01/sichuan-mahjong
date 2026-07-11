using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanHandShapeEngine
{
    private readonly SichuanShantenEngine _shanten = new();

    public SichuanHandShapeSummary Evaluate(
        int[] hand18,
        int[] remaining18,
        int meldCount,
        int shanten)
    {
        var goodShapeCount = 0;
        var badShapeCount = 0;
        var pairCount = 0;
        var taatsuCount = 0;
        var middleTileFlexibility = 0;
        for (var suit = 0; suit < 3; suit++)
        {
            var start = suit * 9;
            for (var rank = 0; rank < 9; rank++)
            {
                var tileType = start + rank;
                var count = hand18[tileType];
                if (count <= 0) continue;
                if (rank is >= 2 and <= 6)
                    middleTileFlexibility += count;
                if (count >= 2)
                    pairCount++;
                if (rank <= 7 && hand18[tileType] > 0 && hand18[tileType + 1] > 0)
                {
                    taatsuCount++;
                    if (rank is >= 1 and <= 5)
                        goodShapeCount++;
                    else
                        badShapeCount++;
                }
                if (rank <= 6 && hand18[tileType] > 0 && hand18[tileType + 2] > 0)
                {
                    taatsuCount++;
                    badShapeCount++;
                }
            }
        }

        var neededTaatsu = Math.Max(0, 4 - meldCount);
        var pairPressure = Math.Max(0, pairCount - 2);
        var taatsuOverflow = Math.Max(0, taatsuCount - neededTaatsu - 1);
        var sameShantenImprovementCount = CountSameShantenImprovements(hand18, remaining18, meldCount, shanten);
        var shapeScore = goodShapeCount * 0.32
            - badShapeCount * 0.16
            - pairPressure * 0.18
            - taatsuOverflow * 0.12
            + sameShantenImprovementCount * 0.08
            + middleTileFlexibility * 0.025;

        var reasons = new List<string>();
        if (goodShapeCount > 0)
            reasons.Add($"手形好搭 {goodShapeCount}");
        if (badShapeCount > 0)
            reasons.Add($"手形愚形 {badShapeCount}");
        if (sameShantenImprovementCount > 0)
            reasons.Add($"同向听改良 {sameShantenImprovementCount}");
        if (pairPressure > 0)
            reasons.Add($"对子压力 {pairPressure}");
        if (taatsuOverflow > 0)
            reasons.Add($"搭子溢出 {taatsuOverflow}");
        if (reasons.Count == 0)
            reasons.Add("手形结构平稳");

        return new SichuanHandShapeSummary
        {
            GoodShapeCount = goodShapeCount,
            BadShapeCount = badShapeCount,
            PairPressure = pairPressure,
            TaatsuOverflow = taatsuOverflow,
            SameShantenImprovementCount = sameShantenImprovementCount,
            MiddleTileFlexibility = middleTileFlexibility,
            ShapeScore = shapeScore,
            Reasons = reasons.Take(4).ToArray()
        };
    }

    private int CountSameShantenImprovements(int[] hand18, int[] remaining18, int meldCount, int shanten)
    {
        var count = 0;
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (remaining18[tileType] <= 0 || hand18[tileType] >= 4) continue;
            var probe = (int[])hand18.Clone();
            probe[tileType]++;
            var drawShanten = _shanten.CalcBestShanten(probe, meldCount);
            if (drawShanten == shanten && ImprovesLocalShape(hand18, tileType))
                count += remaining18[tileType];
        }
        return count;
    }

    private static bool ImprovesLocalShape(int[] hand18, int tileType)
    {
        var suitStart = (tileType / 9) * 9;
        var rank = tileType % 9;
        for (var offset = -2; offset <= 2; offset++)
        {
            if (offset == 0) continue;
            var neighborRank = rank + offset;
            if (neighborRank is < 0 or >= 9) continue;
            if (hand18[suitStart + neighborRank] > 0)
                return true;
        }
        return false;
    }
}
