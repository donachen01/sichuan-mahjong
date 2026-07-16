using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanHellChallengeEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanHandShapeEngine _shape = new();

    public SichuanHellOracleResult DecideDiscard(
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int> exactWall18,
        IReadOnlyList<int>? currentScores = null)
    {
        allHands18 = NormalizeHands(allHands18);
        exactWall18 = NormalizeCounts(exactWall18);

        var hand = state.Hand18;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var teamPlan = SichuanHellChallengeTeamPlanner.BuildPlan(state, allHands18, exactWall18, currentScores);
        var seatPlan = teamPlan.ForSeat(state.SeatIndex);
        var humanPressureLevel = teamPlan.HumanPressureLevel;
        var humanHuPenalty = 30000 + (humanPressureLevel * 7000);
        var humanGangPenalty = 9000 + (humanPressureLevel * 2500);
        var bestTile = -1;
        var bestScore = int.MinValue;
        var bestReasons = new List<string>();
        var bestExactDealIn = false;
        var bestDealInTargetSeats = Array.Empty<int>();
        var bestFeedsHumanHu = false;
        var bestFeedsHumanPeng = false;
        var bestFeedsHumanGang = false;
        var bestKeepsReady = false;
        var bestWallRemaining = 0;
        var bestShanten = 8;
        var bestWaitCount = 0;
        var bestTier = "";
        var candidates = new List<SichuanHellChallengeCandidate>();

        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (hand[tileType] <= 0)
                continue;

            var remainingHand = RemoveOne(hand, tileType);
            var dealInTargetSeats = ResolveDealInTargetSeats(state, allHands18, tileType);
            var exactDealIn = dealInTargetSeats.Count > 0;
            var feedsHumanHu = dealInTargetSeats.Contains(0);
            var feedsHumanGang = CanHumanGang(state, allHands18, tileType);
            var feedsHumanPeng = !feedsHumanGang && CanHumanPeng(state, allHands18, tileType);
            var shanten = _shanten.CalcShantenAfterDiscard(hand, tileType, meldCount);
            var (_, _, improvingTiles) = _ukeire.CalcUkeire(hand, exactWall18.ToArray(), tileType, meldCount);
            var exactReadyTiles = GetExactReadyTiles(remainingHand, meldCount);
            var waitCount = exactReadyTiles.Count > 0 ? exactReadyTiles.Count : (shanten <= 0 ? improvingTiles.Count : 0);
            var exactWallRemaining = exactReadyTiles.Count > 0
                ? exactReadyTiles.Sum(tile => SafeCount(exactWall18, tile))
                : improvingTiles.Sum(tile => SafeCount(exactWall18, tile));
            var keepsReady = exactReadyTiles.Count > 0 || shanten <= 0;
            var shapeSummary = _shape.Evaluate(remainingHand, exactWall18.ToArray(), meldCount, shanten);
            var speedPressure = ResolveSpeedPressure(state.WallCount, shanten, keepsReady);
            var humanPengThreat = feedsHumanPeng
                ? EstimateHumanPengThreat(state, allHands18, exactWall18, tileType)
                : 0;
            var humanAlreadyReady = state.IsReady.Length > 0 && state.IsReady[0];
            var humanPengPenalty = feedsHumanPeng
                ? CalculateHumanPengPenalty(
                    seatPlan,
                    humanPressureLevel,
                    humanPengThreat,
                    keepsReady,
                    exactWallRemaining,
                    humanAlreadyReady,
                    state.WallCount,
                    shanten)
                : 0;
            var tempoPengAllowanceBonus = CalculateTempoPengAllowanceBonus(
                feedsHumanPeng,
                feedsHumanHu,
                feedsHumanGang,
                keepsReady,
                humanPengThreat,
                humanAlreadyReady,
                state.WallCount,
                shanten);
            var pengOnlyInteractionBonus = feedsHumanPeng && humanPengThreat <= 4 && !feedsHumanHu && !feedsHumanGang
                && (keepsReady || shanten <= 1)
                && (humanAlreadyReady || state.WallCount <= 10)
                    ? 720
                    : 0;
            var tier = ResolveHellDiscardTier(
                shanten,
                keepsReady,
                waitCount,
                exactWallRemaining,
                exactDealIn,
                feedsHumanHu,
                feedsHumanGang,
                feedsHumanPeng,
                humanPengThreat,
                state.WallCount);
            var tierAdjustment = ResolveHellTierAdjustment(tier);
            var score = 0
                - shanten * 1700
                + exactWallRemaining * 70
                + waitCount * 360
                + (keepsReady ? 1100 : 0)
                + (keepsReady && exactWallRemaining > 0 ? exactWallRemaining * 220 : 0)
                + speedPressure
                + tierAdjustment
                + (int)Math.Round(shapeSummary.ShapeScore * 210.0)
                + (feedsHumanPeng && humanPengThreat <= 1 && keepsReady && exactWallRemaining > 0 ? 900 : 0)
                + tempoPengAllowanceBonus
                + pengOnlyInteractionBonus
                + seatPlan.DiscardSafetyBias
                - (exactDealIn ? 12000 : 0)
                - (feedsHumanHu ? humanHuPenalty : 0)
                - (feedsHumanGang ? humanGangPenalty : 0)
                - (feedsHumanPeng ? humanPengPenalty : 0);
            var reasons = new List<string>
            {
                $"透视向听 {shanten}",
                $"透视活张 {exactWallRemaining}",
                $"牌理层级 {tier.Label}",
            };
            if (exactDealIn)
                reasons.Add("透视：此张会点炮");
            if (feedsHumanHu)
                reasons.Add($"围剿：避开本家胡牌 P{humanPressureLevel}");
            if (feedsHumanGang)
                reasons.Add($"围剿：避开本家明杠加速 P{humanPressureLevel}");
            else if (feedsHumanPeng)
            {
                reasons.Add($"围剿：本家可碰，威胁 {humanPengThreat}，惩罚 {humanPengPenalty}");
                if (humanPengThreat <= 1 && keepsReady && exactWallRemaining > 0)
                    reasons.Add("互动保真：普通碰不压过 AI 自身下叫");
                if (tempoPengAllowanceBonus > 0 && state.WallCount >= 15)
                    reasons.Add("抢听优先：前期自己能先下叫，不为普通碰放弃速度");
                else if (tempoPengAllowanceBonus > 0 && !humanAlreadyReady)
                    reasons.Add("互动保真：中期本家未听，只给碰不下叫也可接受");
                else if (tempoPengAllowanceBonus > 0)
                    reasons.Add("互动保真：后期本家已听，只给碰不点炮可接受");
                if (pengOnlyInteractionBonus > 0)
                    reasons.Add("互动保真：尾盘只给碰不点炮，保留真实碰牌空间");
            }
            if (keepsReady)
                reasons.Add("透视：保听/成叫");
            if (speedPressure > 0)
                reasons.Add("四川血战：抢先成叫，速度优先");
            foreach (var reason in shapeSummary.Reasons.Take(2))
                reasons.Add(reason);
            reasons.Add($"三家协作：{seatPlan.Summary}，弃牌安全偏置 +{seatPlan.DiscardSafetyBias}");
            candidates.Add(new SichuanHellChallengeCandidate
            {
                TileType = tileType,
                Score = score,
                Shanten = shanten,
                LiveUkeire = exactWallRemaining,
                WaitCount = waitCount,
                ExactDealIn = exactDealIn,
                FeedsHumanHu = feedsHumanHu,
                FeedsHumanPeng = feedsHumanPeng,
                FeedsHumanGang = feedsHumanGang,
                HumanPengThreat = humanPengThreat,
                HumanPengPenalty = humanPengPenalty,
                TempoPengAllowanceBonus = tempoPengAllowanceBonus,
                PengOnlyInteractionBonus = pengOnlyInteractionBonus,
                KeepsReady = keepsReady,
                ExactWallRemaining = exactWallRemaining,
                Tier = tier.Label,
                TierRank = tier.Rank,
                TierAdjustment = tierAdjustment,
                DealInTargetSeats = dealInTargetSeats.ToArray(),
                Reasons = reasons.ToArray()
            });

            if (score > bestScore)
            {
                bestTile = tileType;
                bestScore = score;
                bestReasons = reasons;
                bestExactDealIn = exactDealIn;
                bestDealInTargetSeats = dealInTargetSeats.ToArray();
                bestFeedsHumanHu = feedsHumanHu;
                bestFeedsHumanPeng = feedsHumanPeng;
                bestFeedsHumanGang = feedsHumanGang;
                bestKeepsReady = keepsReady;
                bestWallRemaining = exactWallRemaining;
                bestShanten = shanten;
                bestWaitCount = waitCount;
                bestTier = tier.Label;
            }
        }

        return new SichuanHellOracleResult
        {
            DecisionType = "discard",
            Action = new SichuanAction(SichuanActionType.Discard, bestTile, bestScore, bestReasons.FirstOrDefault() ?? ""),
            Category = "hell_challenge_direct",
            Severity = bestFeedsHumanHu || bestFeedsHumanGang || bestExactDealIn ? "high" : "none",
            ExactDealIn = bestExactDealIn,
            OracleExactDealIn = bestExactDealIn,
            OracleFeedsHumanHu = bestFeedsHumanHu,
            OracleFeedsHumanPeng = bestFeedsHumanPeng,
            OracleFeedsHumanGang = bestFeedsHumanGang,
            HumanPressureLevel = humanPressureLevel,
            TeamRole = seatPlan.Role,
            TeamPressureBonus = seatPlan.DiscardSafetyBias,
            TeamPlanSummary = teamPlan.Reasons,
            OracleDealInTargetSeats = bestDealInTargetSeats,
            ExactKeepsReady = bestKeepsReady,
            ExactWallRemaining = bestWallRemaining,
            SelectedShanten = bestShanten,
            SelectedLiveUkeire = bestWallRemaining,
            SelectedWaitCount = bestWaitCount,
            SelectedTier = bestTier,
            Candidates = candidates
                .OrderByDescending(candidate => candidate.Score)
                .ThenBy(candidate => candidate.TierRank)
                .ThenBy(candidate => candidate.TileType)
                .ToArray(),
            Reasons = bestReasons.Concat(teamPlan.Reasons).Distinct().ToArray()
        };
    }

    private static (string Label, int Rank) ResolveHellDiscardTier(
        int shanten,
        bool keepsReady,
        int waitCount,
        int exactWallRemaining,
        bool exactDealIn,
        bool feedsHumanHu,
        bool feedsHumanGang,
        bool feedsHumanPeng,
        int humanPengThreat,
        int wallCount)
    {
        if (exactDealIn || feedsHumanHu)
            return ("X_DANGER_HU", 90);
        if (feedsHumanGang)
            return ("X_DANGER_GANG", 82);
        if (keepsReady && exactWallRemaining > 0)
            return ("A_READY", 0);
        if (feedsHumanPeng && humanPengThreat >= 4 && wallCount > 10)
            return ("D_FEEDS_STRONG_PENG", 70);
        if (shanten <= 1 && exactWallRemaining >= 3)
            return ("B_ONE_AWAY_LIVE", 10);
        if (shanten <= 1)
            return ("B_ONE_AWAY_NARROW", 16);
        if (shanten <= 2 && exactWallRemaining >= 12 && wallCount >= 15)
            return ("C_WIDE_TWO_AWAY", 28);
        if (shanten <= 2)
            return ("C_TWO_AWAY", 34);
        return ("D_SLOW_SHAPE", 48);
    }

    private static int ResolveHellTierAdjustment((string Label, int Rank) tier)
    {
        return tier.Label switch
        {
            "A_READY" => 3000,
            "B_ONE_AWAY_LIVE" => 1900,
            "B_ONE_AWAY_NARROW" => 1450,
            "C_WIDE_TWO_AWAY" => 350,
            "C_TWO_AWAY" => -350,
            "D_FEEDS_STRONG_PENG" => -2400,
            "D_SLOW_SHAPE" => -1800,
            "X_DANGER_GANG" => -9000,
            "X_DANGER_HU" => -30000,
            _ => 0
        };
    }

    public static IReadOnlyList<int> ResolveDealInTargetSeats(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
    {
        var targets = new List<int>();
        for (var seat = 0; seat < Math.Min(4, allHands18.Count); seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat])
                continue;
            var hand = allHands18[seat].Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
            hand[discardTileType]++;
            var meldCount = state.Melds18[seat].Count / 3;
            if (CanHu(hand, meldCount))
                targets.Add(seat);
        }
        return targets;
    }

    public static bool CanHumanPeng(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
        => CanHumanCall(state, allHands18, discardTileType, 2);

    public static bool CanHumanGang(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
        => CanHumanCall(state, allHands18, discardTileType, 3);

    private int EstimateHumanPengThreat(
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int> exactWall18,
        int discardTileType)
    {
        if (state.SeatIndex == 0 || discardTileType is < 0 or >= 27 || allHands18.Count <= 0 || allHands18[0].Count <= discardTileType)
            return 0;
        var humanHand = allHands18[0].Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
        if (humanHand[discardTileType] < 2)
            return 0;

        humanHand[discardTileType] = Math.Max(0, humanHand[discardTileType] - 2);
        var meldCountAfter = state.Melds18[0].Count / 3 + 1;
        var concealedCount = humanHand.Sum();
        if (concealedCount < 4)
            return 1;

        var shantenAfter = _shanten.CalcBestShanten(humanHand, meldCountAfter);
        var bestLive = 0;
        if (concealedCount > 1)
        {
            var wall = exactWall18.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
            for (var tileType = 0; tileType < 27; tileType++)
            {
                if (humanHand[tileType] <= 0)
                    continue;
                var (_, liveUkeire, _) = _ukeire.CalcUkeire(humanHand, wall, tileType, meldCountAfter);
                bestLive = Math.Max(bestLive, liveUkeire);
            }
        }

        if (shantenAfter <= 0)
            return 4;
        if (shantenAfter == 1 && bestLive >= 6)
            return 3;
        if (shantenAfter == 1)
            return 2;
        return 1;
    }

    private static int CalculateHumanPengPenalty(
        SichuanHellChallengeSeatPlan seatPlan,
        int humanPressureLevel,
        int humanPengThreat,
        bool keepsReady,
        int exactWallRemaining,
        bool humanAlreadyReady,
        int wallCount,
        int shantenAfterDiscard)
    {
        var roleBase = seatPlan.Role switch
        {
            "lead_suppressor" => 1500,
            "interceptor" => 850,
            "catch_up" => 450,
            _ => 650
        };
        var pressure = humanPressureLevel * (seatPlan.Role == "lead_suppressor" ? 360 : 210);
        var threat = humanPengThreat * humanPengThreat * 420;
        var penalty = roleBase + pressure + threat;
        if (humanPengThreat <= 1 && keepsReady)
            penalty -= 1800 + exactWallRemaining * 320;
        if (humanAlreadyReady && shantenAfterDiscard <= 1)
            penalty -= 900 + (keepsReady ? 450 : 0) + (wallCount <= 10 ? 650 : 0);
        if (humanAlreadyReady && wallCount <= 10 && shantenAfterDiscard <= 0 && keepsReady)
            penalty = Math.Min(penalty, 1800);
        if (!humanAlreadyReady && wallCount is >= 9 and <= 14 && shantenAfterDiscard <= 0 && humanPengThreat <= 2)
            penalty -= 950;
        if (wallCount <= 8 && shantenAfterDiscard <= 1 && humanPengThreat <= 2)
            penalty -= 700;
        if (seatPlan.Role == "catch_up" && keepsReady)
            penalty -= 500;
        if (keepsReady && exactWallRemaining > 0 && shantenAfterDiscard <= 0)
            penalty = Math.Min(penalty, wallCount <= 10 ? 1200 : 2200);
        var floor = humanPengThreat >= 3 ? 1600 : 120;
        if (keepsReady && exactWallRemaining > 0 && shantenAfterDiscard <= 0)
            floor = Math.Min(floor, wallCount <= 10 ? 600 : 1200);
        if (humanAlreadyReady && wallCount <= 10 && shantenAfterDiscard <= 1 && keepsReady)
            floor = 420;
        if (humanAlreadyReady && wallCount <= 10 && shantenAfterDiscard <= 0 && keepsReady && humanPengThreat <= 4)
            floor = 0;
        if (!humanAlreadyReady && wallCount is >= 9 and <= 14 && shantenAfterDiscard <= 0 && humanPengThreat <= 2)
            floor = 180;
        return Math.Max(floor, penalty);
    }

    private static int CalculateTempoPengAllowanceBonus(
        bool feedsHumanPeng,
        bool feedsHumanHu,
        bool feedsHumanGang,
        bool keepsReady,
        int humanPengThreat,
        bool humanAlreadyReady,
        int wallCount,
        int shantenAfterDiscard)
    {
        if (!feedsHumanPeng || feedsHumanHu || feedsHumanGang || !keepsReady)
            return 0;

        if (wallCount >= 15)
            return 760;
        if (!humanAlreadyReady && wallCount >= 9 && shantenAfterDiscard <= 0)
            return 620;
        if (humanAlreadyReady && wallCount <= 10 && shantenAfterDiscard <= 0)
            return humanPengThreat >= 3 ? 1280 : 720;
        if (humanAlreadyReady && wallCount <= 10 && shantenAfterDiscard <= 1)
            return 520;
        return 0;
    }

    private static int ResolveSpeedPressure(int wallCount, int shanten, bool keepsReady)
    {
        if (keepsReady)
            return wallCount <= 14 ? 520 : 380;
        if (shanten == 1)
            return wallCount <= 14 ? 360 : 260;
        if (shanten == 2 && wallCount >= 27)
            return 120;
        return 0;
    }

    public static int ResolveHumanPressureLevel(SichuanStateView state, IReadOnlyList<int>? currentScores)
    {
        if (currentScores is null || currentScores.Count < 4 || state.SeatIndex == 0)
            return 1;
        var humanScore = currentScores[0];
        var aiScore = currentScores[state.SeatIndex];
        var bestAiScore = currentScores
            .Take(4)
            .Where((_, seat) => seat != 0)
            .DefaultIfEmpty(aiScore)
            .Max();
        if (humanScore >= bestAiScore)
            return 4;
        if (humanScore >= aiScore)
            return 3;
        if (humanScore + 8 >= bestAiScore)
            return 2;
        return 1;
    }

    public static int[] RemoveOne(int[] hand18, int tileType)
    {
        var copy = (int[])hand18.Clone();
        copy[tileType] = Math.Max(0, copy[tileType] - 1);
        return copy;
    }

    public static List<int> GetExactReadyTiles(int[] hand18, int meldCount)
    {
        var results = new List<int>();
        var expectedConcealed = ((4 - meldCount) * 3) + 1;
        if (meldCount < 0 || meldCount > 4 || hand18.Sum() != expectedConcealed)
            return results;
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (hand18[tileType] >= 4) continue;
            var probe = (int[])hand18.Clone();
            probe[tileType]++;
            if (CanHu(probe, meldCount))
                results.Add(tileType);
        }
        return results;
    }

    private static bool CanHumanCall(
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        int discardTileType,
        int requiredCount)
    {
        if (state.SeatIndex == 0 || discardTileType is < 0 or >= 27 || state.HasHu[0] || allHands18.Count <= 0)
            return false;
        var humanHand = allHands18[0];
        return discardTileType < humanHand.Count && humanHand[discardTileType] >= requiredCount;
    }

    public static int SafeCount(IReadOnlyList<int> counts, int tileType)
        => tileType is >= 0 and < 27 && tileType < counts.Count ? Math.Max(0, counts[tileType]) : 0;

    private static IReadOnlyList<IReadOnlyList<int>> NormalizeHands(IReadOnlyList<IReadOnlyList<int>> hands)
    {
        return hands
            .Take(4)
            .Select(hand => (IReadOnlyList<int>)NormalizeCounts(hand))
            .Concat(Enumerable.Range(0, Math.Max(0, 4 - hands.Count)).Select(_ => (IReadOnlyList<int>)new int[27]))
            .Take(4)
            .ToArray();
    }

    private static int[] NormalizeCounts(IReadOnlyList<int> counts)
    {
        return counts.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
    }

    private static bool CanHu(int[] hand18, int meldCount)
    {
        var requiredConcealed = ((4 - meldCount) * 3) + 2;
        if (meldCount < 0 || meldCount > 4 || hand18.Sum() != requiredConcealed)
            return false;
        if (meldCount == 0 && IsQiDui(hand18))
            return true;
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (hand18[tileType] < 2) continue;
            var trial = (int[])hand18.Clone();
            trial[tileType] -= 2;
            if (CanClearSuit(trial, 0) && CanClearSuit(trial, 9) && CanClearSuit(trial, 18))
                return true;
        }
        return false;
    }

    private static bool IsQiDui(int[] hand18)
    {
        if (hand18.Sum() != 14) return false;
        var pairCount = 0;
        foreach (var count in hand18)
        {
            if (count != 0 && count != 2 && count != 4)
                return false;
            pairCount += count / 2;
        }
        return pairCount == 7;
    }

    private static bool CanClearSuit(int[] counts, int start)
    {
        for (var rank = 0; rank < 9; rank++)
        {
            var tileType = start + rank;
            while (counts[tileType] > 0)
            {
                if (counts[tileType] >= 3)
                {
                    counts[tileType] -= 3;
                    continue;
                }
                if (rank + 2 >= 9 || counts[tileType + 1] <= 0 || counts[tileType + 2] <= 0)
                    return false;
                counts[tileType]--;
                counts[tileType + 1]--;
                counts[tileType + 2]--;
            }
        }
        return true;
    }
}
