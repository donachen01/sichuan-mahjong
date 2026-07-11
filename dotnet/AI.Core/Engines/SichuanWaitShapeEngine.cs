using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanWaitShapeEngine
{
    public SichuanWaitShapeSummary Evaluate(int[] hand18AfterDiscard, IReadOnlyList<int> waitTiles)
    {
        if (waitTiles.Count == 0)
        {
            return new SichuanWaitShapeSummary
            {
                Label = "未成听",
                Reasons = new[] { "未成听形" }
            };
        }

        var ryanmen = 0;
        var kanchan = 0;
        var penchan = 0;
        var tanki = 0;
        var shanpon = 0;
        foreach (var tileType in waitTiles.Distinct())
        {
            var shape = ClassifySingleWait(hand18AfterDiscard, tileType);
            switch (shape)
            {
                case "两面":
                    ryanmen++;
                    break;
                case "坎张":
                    kanchan++;
                    break;
                case "边张":
                    penchan++;
                    break;
                case "双碰":
                    shanpon++;
                    break;
                default:
                    tanki++;
                    break;
            }
        }

        var score = ryanmen * 10.0
            + waitTiles.Distinct().Count() * 2.4
            - kanchan * 3.2
            - penchan * 4.0
            - tanki * 2.2
            + shanpon * 1.4;
        var label = ResolveLabel(ryanmen, kanchan, penchan, tanki, shanpon, waitTiles.Distinct().Count());
        var reasons = new List<string> { $"听形 {label}" };
        if (ryanmen > 0) reasons.Add($"两面 {ryanmen}");
        if (kanchan > 0) reasons.Add($"坎张 {kanchan}");
        if (penchan > 0) reasons.Add($"边张 {penchan}");
        if (shanpon > 0) reasons.Add($"双碰 {shanpon}");
        if (tanki > 0) reasons.Add($"单钓 {tanki}");

        return new SichuanWaitShapeSummary
        {
            RyanmenCount = ryanmen,
            KanchanCount = kanchan,
            PenchanCount = penchan,
            TankiCount = tanki,
            ShanponCount = shanpon,
            WaitShapeScore = score,
            Label = label,
            Reasons = reasons.Take(4).ToArray()
        };
    }

    private static string ClassifySingleWait(int[] hand18, int tileType)
    {
        var suitStart = (tileType / 9) * 9;
        var rank = tileType % 9;
        var sameCount = hand18[tileType];
        var left2 = rank >= 2 && hand18[suitStart + rank - 2] > 0;
        var left1 = rank >= 1 && hand18[suitStart + rank - 1] > 0;
        var right1 = rank + 1 < 9 && hand18[suitStart + rank + 1] > 0;
        var right2 = rank + 2 < 9 && hand18[suitStart + rank + 2] > 0;

        if (left1 && right1)
            return "坎张";
        if ((rank == 2 && left2 && left1) || (rank == 6 && right1 && right2))
            return "边张";
        if ((left2 && left1) || (right1 && right2))
            return "两面";
        if (sameCount >= 2)
            return "双碰";
        return "单钓";
    }

    private static string ResolveLabel(int ryanmen, int kanchan, int penchan, int tanki, int shanpon, int waitCount)
    {
        if (waitCount >= 3 && ryanmen > 0) return "多面好听";
        if (ryanmen >= 2) return "双两面";
        if (ryanmen == 1 && waitCount >= 2) return "两面复合";
        if (ryanmen == 1) return "两面";
        if (shanpon > 0 && waitCount >= 2) return "双碰";
        if (kanchan > 0) return "坎张";
        if (penchan > 0) return "边张";
        if (tanki > 0) return "单钓";
        return "普通听形";
    }
}
