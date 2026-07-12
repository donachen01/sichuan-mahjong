using System.Collections.ObjectModel;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanHellChallengeReactionEngine
{
    private readonly SichuanReactionDecisionEngine _fair = new();
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanHellChallengeEngine _followUpDiscard = new();

    public SichuanReactionDecisionResult DecideReaction(
        SichuanStateView state,
        int reactionTileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        int sourceSeat,
        string reactionType,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int> exactWall18,
        IReadOnlyList<int>? currentScores = null,
        bool mandatoryGang = false)
    {
        allHands18 = NormalizeHands(allHands18);
        exactWall18 = NormalizeCounts(exactWall18);
        var fair = _fair.DecideReaction(
            state,
            reactionTileType,
            canHu,
            canPeng,
            canGang,
            sourceSeat,
            reactionType,
            forceLightweight: true,
            mandatoryGang);
        if (mandatoryGang && fair.Action.ActionType == SichuanActionType.Gang)
            return fair;
        var scores = new Dictionary<string, int>(fair.ActionScores);
        var teamPlan = SichuanHellChallengeTeamPlanner.BuildPlan(state, allHands18, exactWall18, currentScores);
        var seatPlan = teamPlan.ForSeat(state.SeatIndex);
        var humanPressure = teamPlan.HumanPressureLevel;
        var currentMeldCount = state.Melds18[state.SeatIndex].Count / 3;
        var currentShanten = _shanten.CalcBestShanten(state.Hand18, currentMeldCount);
        var currentLive = EstimateBestLiveUkeire(state.Hand18, exactWall18, currentMeldCount);

        if (canHu)
        {
            var teamPlanPressure = sourceSeat == 0 ? seatPlan.CallInterceptionBias : seatPlan.PressureBonus / 2;
            var huScore = 100000 + humanPressure * 1000 + (sourceSeat == 0 ? 3000 : 0) + teamPlanPressure;
            return BuildResult(
                SichuanActionType.Hu,
                reactionTileType,
                huScore,
                currentShanten: -1,
                currentLive,
                shantenAfter: -1,
                liveAfter: 0,
                humanPressure,
                new Dictionary<string, int>(scores)
                {
                    ["hu"] = huScore,
                    ["team_block_human"] = sourceSeat == 0 ? humanPressure * 1000 : 0,
                    ["team_plan_pressure"] = teamPlanPressure
                },
                new[]
                {
                    "地狱挑战：可胡直接收口",
                    sourceSeat == 0 ? $"围剿：截断本家放铳后续节奏 P{humanPressure}" : "团队：AI 胡牌优先锁定收益",
                    $"三家协作：{seatPlan.Summary}，胡牌截断 +{teamPlanPressure}"
                }.Concat(teamPlan.Reasons).Distinct().ToArray());
        }

        var best = BuildPassResult(reactionTileType, currentShanten, currentLive, humanPressure, scores);
        var bestKey = "pass";
        var directMeldedGangAvailable = canGang
            && reactionTileType is >= 0 and < 27
            && state.Hand18[reactionTileType] >= 3;

        if (directMeldedGangAvailable)
        {
            var gang = EvaluateCall(
                state,
                reactionTileType,
                SichuanActionType.Gang,
                removeCount: 3,
                sourceSeat,
                reactionType,
                exactWall18,
                currentShanten,
                currentLive,
                humanPressure,
                seatPlan,
                teamPlan.Reasons,
                scores);
            scores["gang"] = gang.Action.Score;
            if (gang.Action.Score > best.Action.Score)
            {
                best = gang;
                bestKey = "gang";
            }
        }

        if (canPeng && reactionTileType is >= 0 and < 27 && state.Hand18[reactionTileType] >= 2)
        {
            var peng = EvaluateCall(
                state,
                reactionTileType,
                SichuanActionType.Peng,
                removeCount: 2,
                sourceSeat,
                reactionType,
                exactWall18,
                currentShanten,
                currentLive,
                humanPressure,
                seatPlan,
                teamPlan.Reasons,
                scores);
            if (directMeldedGangAvailable)
            {
                peng = ApplyPengRediscardSameTilePenalty(
                    peng,
                    state,
                    allHands18,
                    currentScores,
                    RemoveCopies(state.Hand18, reactionTileType, 2),
                    reactionTileType,
                    exactWall18);
                if (scores.TryGetValue("gang", out var directGangScore) && peng.Action.Score <= directGangScore + 180)
                    peng = ApplyWeakPengOverGangPenalty(peng, directGangScore);
                if (peng.ActionScores.TryGetValue("peng_rediscard_same_tile_penalty", out var sameTilePenalty))
                    scores["peng_rediscard_same_tile_penalty"] = sameTilePenalty;
                if (peng.ActionScores.TryGetValue("peng_weak_over_gang_penalty", out var weakOverGangPenalty))
                    scores["peng_weak_over_gang_penalty"] = weakOverGangPenalty;
            }
            if (peng.ActionScores.TryGetValue("middle_peng_shape_penalty", out var middlePengPenalty))
                scores["middle_peng_shape_penalty"] = middlePengPenalty;
            scores["peng"] = peng.Action.Score;
            if (peng.Action.Score > best.Action.Score)
            {
                best = peng;
                bestKey = "peng";
            }
        }

        var finalScores = new Dictionary<string, int>(scores)
        {
            ["team_block_human"] = sourceSeat == 0 && bestKey != "pass" ? humanPressure * 900 : 0,
            ["team_plan_pressure"] = sourceSeat == 0 && bestKey != "pass" ? seatPlan.CallInterceptionBias : 0
        };
        best.ActionScores = new ReadOnlyDictionary<string, int>(finalScores);
        return best;
    }

    private SichuanReactionDecisionResult BuildPassResult(
        int reactionTileType,
        int currentShanten,
        int currentLive,
        int humanPressure,
        Dictionary<string, int> scores)
    {
        var score = -20 + currentLive * 4 - humanPressure * 8;
        scores["pass"] = score;
        return BuildResult(
            SichuanActionType.Pass,
            reactionTileType,
            score,
            currentShanten,
            currentLive,
            currentShanten,
            currentLive,
            humanPressure,
            scores,
            new[]
            {
                "地狱挑战：过牌保留当前路径",
                $"当前活张 {currentLive}"
            });
    }

    private SichuanReactionDecisionResult EvaluateCall(
        SichuanStateView state,
        int reactionTileType,
        SichuanActionType actionType,
        int removeCount,
        int sourceSeat,
        string reactionType,
        IReadOnlyList<int> exactWall18,
        int currentShanten,
        int currentLive,
        int humanPressure,
        SichuanHellChallengeSeatPlan seatPlan,
        IReadOnlyList<string> teamPlanReasons,
        Dictionary<string, int> inheritedScores)
    {
        var handAfter = RemoveCopies(state.Hand18, reactionTileType, removeCount);
        var meldCountAfter = state.Melds18[state.SeatIndex].Count / 3 + 1;
        var shantenAfter = _shanten.CalcBestShanten(handAfter, meldCountAfter);
        var liveAfter = EstimateBestLiveUkeire(handAfter, exactWall18, meldCountAfter);
        var blocksHuman = sourceSeat == 0 && reactionType == "discard";
        var callBase = actionType == SichuanActionType.Gang ? 190 : 120;
        var teamPlanPressure = blocksHuman ? seatPlan.CallInterceptionBias : seatPlan.PressureBonus / 3;
        var teamBlockBonus = blocksHuman ? 420 + humanPressure * 170 + teamPlanPressure : 0;
        var speedScore = (currentShanten - shantenAfter) * 260 + (liveAfter - currentLive) * 14;
        var readyBonus = shantenAfter <= 0 ? 460 : 0;
        var slowPenalty = shantenAfter > currentShanten ? 520 : 0;
        var gangBonus = actionType == SichuanActionType.Gang ? 160 : 0;
        var nonHumanMiddlePengPenalty = 0;
        if (actionType == SichuanActionType.Peng
            && !blocksHuman
            && shantenAfter > 0
            && IsMiddleTile(reactionTileType))
        {
            nonHumanMiddlePengPenalty = 460;
        }
        var score = callBase + teamBlockBonus + speedScore + readyBonus + gangBonus - slowPenalty - nonHumanMiddlePengPenalty;
        var actionText = actionType == SichuanActionType.Gang ? "杠" : "碰";
        var reasons = new List<string>
        {
            $"地狱挑战：{actionText}后向听 {shantenAfter}",
            $"地狱挑战：{actionText}后活张 {liveAfter}",
        };
        if (blocksHuman)
            reasons.Add($"围剿：{actionText}本家弃牌，截断本家下一摸 P{humanPressure}");
        reasons.Add($"三家协作：{seatPlan.Summary}，响应截断 +{teamPlanPressure}");
        if (shantenAfter < currentShanten)
            reasons.Add("团队：响应后提速");
        if (shantenAfter == currentShanten && liveAfter + 2 >= currentLive)
            reasons.Add("团队：响应不明显降速，优先压制本家");
        if (actionType == SichuanActionType.Gang)
            reasons.Add("团队：明杠收雨钱并争取补牌");
        if (nonHumanMiddlePengPenalty > 0)
            reasons.Add("牌理约束：AI 间中张碰牌未直接下叫，避免见碰就碰");

        var scores = new Dictionary<string, int>(inheritedScores)
        {
            [actionType == SichuanActionType.Gang ? "gang" : "peng"] = score,
            ["team_block_human"] = blocksHuman ? teamBlockBonus : 0,
            ["team_plan_pressure"] = teamPlanPressure
        };
        if (nonHumanMiddlePengPenalty > 0)
            scores["middle_peng_shape_penalty"] = -nonHumanMiddlePengPenalty;
        return BuildResult(actionType, reactionTileType, score, currentShanten, currentLive, shantenAfter, liveAfter, humanPressure, scores, reasons.Concat(teamPlanReasons).Distinct().ToArray());
    }

    private SichuanReactionDecisionResult ApplyPengRediscardSameTilePenalty(
        SichuanReactionDecisionResult peng,
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int>? currentScores,
        int[] handAfterPeng,
        int reactionTileType,
        IReadOnlyList<int> exactWall18)
    {
        if (reactionTileType is < 0 or >= 27 || handAfterPeng[reactionTileType] <= 0)
            return peng;
        var followUpDiscard = EstimateBestFollowUpDiscard(state, allHands18, currentScores, handAfterPeng, reactionTileType, exactWall18);
        if (followUpDiscard != reactionTileType)
            return peng;

        var penalty = 6000;
        var reasons = peng.Reasons.Concat(new[] { "后端决策：碰后首打同张属于无效副露，同张可杠时必须让明杠胜出" }).Distinct().ToArray();
        var scores = new Dictionary<string, int>(peng.ActionScores)
        {
            ["peng"] = peng.Action.Score - penalty,
            ["peng_rediscard_same_tile_penalty"] = -penalty
        };
        peng.Action = new SichuanAction(peng.Action.ActionType, peng.Action.TileType, peng.Action.Score - penalty, peng.Action.Reason);
        peng.Reasons = reasons;
        peng.ActionScores = new ReadOnlyDictionary<string, int>(scores);
        return peng;
    }

    private static SichuanReactionDecisionResult ApplyWeakPengOverGangPenalty(
        SichuanReactionDecisionResult peng,
        int directGangScore)
    {
        var margin = peng.Action.Score - directGangScore;
        var penalty = 600 + Math.Max(0, 180 - margin);
        var reasons = peng.Reasons.Concat(new[] { "后端决策：同张可杠时，碰牌收益不足以压过明杠" }).Distinct().ToArray();
        var scores = new Dictionary<string, int>(peng.ActionScores)
        {
            ["peng"] = peng.Action.Score - penalty,
            ["peng_weak_over_gang_penalty"] = -penalty
        };
        peng.Action = new SichuanAction(peng.Action.ActionType, peng.Action.TileType, peng.Action.Score - penalty, peng.Action.Reason);
        peng.Reasons = reasons;
        peng.ActionScores = new ReadOnlyDictionary<string, int>(scores);
        return peng;
    }

    private int EstimateBestFollowUpDiscard(
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int>? currentScores,
        int[] handAfterPeng,
        int reactionTileType,
        IReadOnlyList<int> exactWall18)
    {
        var postPengState = new SichuanStateView
        {
            SeatIndex = state.SeatIndex,
            DealerSeat = state.DealerSeat,
            CurrentSeat = state.SeatIndex,
            WallCount = state.WallCount,
            TurnIndex = state.TurnIndex,
            Phase = state.Phase,
            Hand18 = handAfterPeng,
            Visible18 = state.Visible18,
            Remaining18 = state.Remaining18,
            DingQueSuits = (int[])state.DingQueSuits.Clone(),
            Discards18 = CloneLists(state.Discards18),
            Melds18 = CloneLists(state.Melds18),
            IsCalled = (bool[])state.IsCalled.Clone(),
            IsReady = (bool[])state.IsReady.Clone(),
            HasHu = (bool[])state.HasHu.Clone(),
            LastDrawTileType = state.LastDrawTileType,
            PassedHu18 = CloneMatrix(state.PassedHu18),
            PassedPeng18 = CloneMatrix(state.PassedPeng18),
            PassedGang18 = CloneMatrix(state.PassedGang18)
        };
        postPengState.Melds18[state.SeatIndex].AddRange(new[] { reactionTileType, reactionTileType, reactionTileType });
        var updatedHands = allHands18.Select((hand, seat) => (IReadOnlyList<int>)(seat == state.SeatIndex ? handAfterPeng : hand.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray())).ToArray();
        return _followUpDiscard.DecideDiscard(postPengState, updatedHands, exactWall18, currentScores).Action.TileType;
    }

    private static List<int>[] CloneLists(IReadOnlyList<List<int>> source)
        => source.Select(list => new List<int>(list)).ToArray();

    private static int[][] CloneMatrix(IReadOnlyList<int[]> source)
        => source.Select(row => (int[])row.Clone()).ToArray();

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

    private SichuanReactionDecisionResult BuildResult(
        SichuanActionType actionType,
        int reactionTileType,
        int score,
        int currentShanten,
        int currentLive,
        int shantenAfter,
        int liveAfter,
        int humanPressure,
        IReadOnlyDictionary<string, int> scores,
        IReadOnlyList<string> reasons)
        => new()
        {
            Action = new SichuanAction(actionType, reactionTileType, score, reasons.FirstOrDefault() ?? ""),
            ShantenAfter = shantenAfter,
            UkeireAfter = liveAfter,
            LiveUkeireAfter = liveAfter,
            CurrentShanten = currentShanten,
            CurrentLiveUkeire = currentLive,
            ThreatLevel = humanPressure,
            RoundStage = 0,
            MaxReadyPosterior = humanPressure / 4.0,
            Reasons = reasons,
            PosteriorSummary = new[] { $"地狱挑战压力 P{humanPressure}" },
            FutureSummary = new[] { $"team_block_human={scores.GetValueOrDefault("team_block_human", 0)}" },
            ActionScores = new ReadOnlyDictionary<string, int>(new Dictionary<string, int>(scores))
        };

    private int EstimateBestLiveUkeire(int[] hand18, IReadOnlyList<int> exactWall18, int meldCount)
    {
        if (hand18.Sum() <= 1)
            return 0;
        var bestLive = 0;
        var wall = exactWall18.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (hand18[tileType] <= 0)
                continue;
            var (_, liveUkeire, _) = _ukeire.CalcUkeire(hand18, wall, tileType, meldCount);
            bestLive = Math.Max(bestLive, liveUkeire);
        }
        return bestLive;
    }

    private static bool IsMiddleTile(int tileType)
    {
        var rank = tileType % 9 + 1;
        return rank is >= 3 and <= 7;
    }

    private static int[] RemoveCopies(int[] hand18, int tileType, int removeCount)
    {
        var clone = (int[])hand18.Clone();
        if (tileType < 0 || tileType >= clone.Length)
            return clone;
        clone[tileType] = Math.Max(0, clone[tileType] - removeCount);
        return clone;
    }
}
