using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanRoutePlanEngine
{
    private readonly SichuanShantenEngine _shanten = new();

    public SichuanRoutePlanResult Evaluate(SichuanStateView state)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        return Evaluate(state, state.Hand18, meldCount);
    }

    public SichuanRoutePlanResult Evaluate(SichuanStateView state, int[] hand18, int meldCount)
    {
        var features = BuildFeatures(state, hand18, meldCount);
        var weights = BuildWeights(features);
        var ordered = weights
            .OrderByDescending(item => item.Value)
            .ThenBy(item => RouteTieBreakRank(item.Key))
            .ToArray();
        var primary = ordered.FirstOrDefault().Key ?? "平胡";
        var secondary = ordered
            .Skip(1)
            .Where(item => item.Value >= Math.Max(35, ordered[0].Value - 22))
            .Take(3)
            .Select(item => item.Key)
            .ToArray();
        var constraints = BuildConstraints(primary, features);
        var reasons = BuildReasons(primary, secondary, features);

        return new SichuanRoutePlanResult
        {
            PrimaryRoute = primary,
            SecondaryRoutes = secondary,
            RouteWeights = weights,
            Constraints = constraints,
            Reasons = reasons,
            TargetSuit = features.TargetSuit
        };
    }

    public static bool IsSevenPairsRoute(string route)
        => route is "暗七对" or "龙七对" or "清七对" or "青龙七对";

    public static bool IsFlushRoute(string route)
        => route is "清一色" or "清对" or "清七对" or "青龙七对";

    public static bool IsPungRoute(string route)
        => route is "大对子" or "清对";

    private Dictionary<string, int> BuildWeights(RouteFeatures features)
    {
        var weights = new Dictionary<string, int>
        {
            ["平胡"] = ScorePingHu(features),
            ["大对子"] = ScoreDaDuiZi(features),
            ["清一色"] = ScoreQingYiSe(features)
        };

        if (features.MeldCount == 0)
        {
            weights["暗七对"] = ScoreQiDui(features);
            weights["龙七对"] = ScoreLongQiDui(features);
            weights["清七对"] = ScoreQingQiDui(features);
            weights["青龙七对"] = ScoreQingLongQiDui(features);
        }
        else
        {
            weights["暗七对"] = 0;
            weights["龙七对"] = 0;
            weights["清七对"] = 0;
            weights["青龙七对"] = 0;
        }

        weights["清对"] = ScoreQingDui(features);
        return weights
            .Where(item => item.Value > 0)
            .ToDictionary(item => item.Key, item => Math.Clamp(item.Value, 0, 100));
    }

    private static int ScorePingHu(RouteFeatures features)
    {
        var score = 50
            - Math.Max(0, features.StandardShanten) * 7
            + features.SequencePotential * 5
            + features.RyanmenPotential * 3
            - Math.Max(0, features.PairLikeCount - 3) * 5;
        if (features.StandardShanten <= 1)
            score += 18;
        else if (features.StandardShanten <= 2)
            score += 8;
        if (features.SequencePotential >= 5 && features.RyanmenPotential >= 2)
            score += 10;
        if (features.PairLikeCount <= 3)
            score += 10;
        if (features.WallCount <= 10)
            score += 8;
        if (features.PairLikeCount >= 5 && features.MeldCount == 0)
            score -= 16;
        return score;
    }

    private static int ScoreQiDui(RouteFeatures features)
    {
        if (features.MeldCount > 0)
            return 0;
        if (features.PairLikeCount <= 3)
            return 0;
        var score = 18
            + features.PairLikeCount * 12
            + features.QuadCount * 8
            + features.TripletCount * 3
            - Math.Max(0, features.SevenPairsShanten) * 10
            - features.SequencePotential * 2;
        if (features.PairLikeCount >= 5)
            score += 52;
        else if (features.PairLikeCount == 4)
            score += features.SevenPairsShanten <= 2 ? 8 : -10;
        if (features.WallCount <= 8 && features.SevenPairsShanten > 0)
            score -= 10;
        return score;
    }

    private static int ScoreLongQiDui(RouteFeatures features)
    {
        if (features.MeldCount > 0)
            return 0;
        var score = ScoreQiDui(features) - 10 + features.GuiPotential * 18;
        if (features.PairLikeCount >= 5 && features.GuiPotential > 0)
            score += 14;
        return score;
    }

    private static int ScoreQingYiSe(RouteFeatures features)
    {
        var offSuitPenalty = features.OffSuitCount <= 3 ? 7 : 14;
        var score = features.TargetSuitCount * 8
            - features.OffSuitCount * offSuitPenalty
            - Math.Max(0, features.StandardShanten) * 5;
        if (features.TargetSuitCount >= 11 && features.OffSuitCount <= 3)
            score += 82;
        else if (features.TargetSuitCount >= 10 && features.OffSuitCount <= 3)
            score += 44;
        else if (features.TargetSuitCount >= 10)
            score += 24;
        else if (features.TargetSuitCount >= 8)
            score += features.OffSuitCount <= 4 ? 8 : -16;
        else
            score -= 28;
        if (features.OffSuitCount == 0)
            score += 18;
        else if (features.OffSuitCount <= 2 && features.TargetSuitCount >= 10)
            score += 10;
        if (features.OffSuitCount >= 5)
            score -= 22;
        if (features.WallCount <= 10 && features.OffSuitCount >= 3)
            score -= 14;
        return score;
    }

    private static int ScoreQingQiDui(RouteFeatures features)
    {
        if (features.MeldCount > 0)
            return 0;
        return ScoreQiDui(features) + ScoreQingYiSe(features) / 2 - 12;
    }

    private static int ScoreQingLongQiDui(RouteFeatures features)
    {
        if (features.MeldCount > 0)
            return 0;
        return ScoreQingQiDui(features) + features.GuiPotential * 16 - 8;
    }

    private static int ScoreDaDuiZi(RouteFeatures features)
    {
        var score = 12
            + features.PairLikeCount * 8
            + features.TripletCount * 13
            + features.MeldCount * 14
            - features.SequencePotential * 4
            - Math.Max(0, features.StandardShanten) * 6;
        if (features.PairLikeCount + features.MeldCount >= 5)
            score += 20;
        if (features.MeldCount == 0 && features.PairLikeCount >= 5)
            score -= 10;
        return score;
    }

    private static int ScoreQingDui(RouteFeatures features)
        => ScoreDaDuiZi(features) + ScoreQingYiSe(features) / 2 - 8;

    private static IReadOnlyList<string> BuildConstraints(string primary, RouteFeatures features)
    {
        var constraints = new List<string>();
        if (IsSevenPairsRoute(primary))
        {
            constraints.Add("forbid_melds");
            constraints.Add("forbid_gangs");
            constraints.Add("preserve_pairs");
        }
        if (IsFlushRoute(primary))
            constraints.Add($"target_suit:{features.TargetSuit}");
        if (IsPungRoute(primary))
            constraints.Add("prefer_triplets");
        if (primary == "平胡")
            constraints.Add("prefer_fast_ready");
        return constraints;
    }

    private static IReadOnlyList<string> BuildReasons(string primary, IReadOnlyList<string> secondary, RouteFeatures features)
    {
        var reasons = new List<string>
        {
            $"路线规划：主路线 {primary}",
            $"对子 {features.PairLikeCount}，刻子 {features.TripletCount}，归潜力 {features.GuiPotential}",
            $"单门 {features.TargetSuitName} {features.TargetSuitCount} 张，异门 {features.OffSuitCount} 张"
        };
        if (secondary.Count > 0)
            reasons.Add($"副路线：{string.Join("/", secondary)}");
        if (IsSevenPairsRoute(primary))
            reasons.Add("七对路线：碰杠会破坏七对，优先门清推进");
        if (primary is "平胡" or "卡二条平胡")
            reasons.Add("平胡路线：速度、宽叫、活张优先");
        if (IsFlushRoute(primary))
            reasons.Add($"清色路线：优先保留{features.TargetSuitName}，清理异门孤张");
        if (IsPungRoute(primary))
            reasons.Add("对子胡路线：碰杠需服务成叫速度");
        return reasons;
    }

    private RouteFeatures BuildFeatures(SichuanStateView state, int[] hand18, int meldCount)
    {
        var suitCounts = new[] { 0, 0, 0 };
        var pairLike = 0;
        var triplets = 0;
        var quads = 0;
        var sequencePotential = 0;
        var ryanmenPotential = 0;

        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            var count = hand18[tileType];
            if (count <= 0) continue;
            suitCounts[tileType / 9] += count;
            if (count >= 2) pairLike++;
            if (count >= 3) triplets++;
            if (count >= 4) quads++;
        }

        foreach (var meldTile in state.Melds18[state.SeatIndex])
        {
            if (meldTile is >= 0 and < 27)
                suitCounts[meldTile / 9]++;
        }

        for (var suit = 0; suit < 3; suit++)
        {
            var offset = suit * 9;
            for (var rank = 0; rank <= 6; rank++)
            {
                if (hand18[offset + rank] > 0 && hand18[offset + rank + 1] > 0 && hand18[offset + rank + 2] > 0)
                    sequencePotential++;
            }
            for (var rank = 0; rank <= 7; rank++)
            {
                if (hand18[offset + rank] > 0 && hand18[offset + rank + 1] > 0)
                {
                    sequencePotential++;
                    if (rank is >= 1 and <= 5)
                        ryanmenPotential++;
                }
            }
        }

        var targetSuit = Enumerable.Range(0, 3)
            .OrderByDescending(suit => suitCounts[suit])
            .ThenBy(suit => suit)
            .First();
        var targetSuitCount = suitCounts[targetSuit];
        var offSuitCount = suitCounts.Sum() - targetSuitCount;
        return new RouteFeatures(
            hand18,
            meldCount,
            state.WallCount,
            pairLike,
            triplets,
            quads,
            quads,
            sequencePotential,
            ryanmenPotential,
            _shanten.CalcStandardShanten(hand18, meldCount),
            meldCount == 0 ? _shanten.CalcSevenPairsShanten(hand18) : 8,
            targetSuit,
            targetSuit switch { 0 => "条", 1 => "筒", _ => "万" },
            targetSuitCount,
            offSuitCount);
    }

    private static int RouteTieBreakRank(string route) => route switch
    {
        "清一色" => 0,
        "清对" => 1,
        "平胡" => 2,
        "大对子" => 3,
        "青龙七对" => 5,
        "清七对" => 6,
        "龙七对" => 7,
        "暗七对" => 8,
        _ => 99
    };

    private sealed record RouteFeatures(
        int[] Hand18,
        int MeldCount,
        int WallCount,
        int PairLikeCount,
        int TripletCount,
        int QuadCount,
        int GuiPotential,
        int SequencePotential,
        int RyanmenPotential,
        int StandardShanten,
        int SevenPairsShanten,
        int TargetSuit,
        string TargetSuitName,
        int TargetSuitCount,
        int OffSuitCount);
}
