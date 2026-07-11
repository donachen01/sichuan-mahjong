using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanReactionDecisionEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanBeliefEngine _belief = new();
    private readonly SichuanDangerEngine _danger = new();
    private readonly SichuanRoutePlanEngine _routePlan = new();
    private const int ReactionSearchDepth = 2;
    private const int ReactionSearchRollouts = 24;

    public SichuanReactionDecisionResult DecideReaction(
        SichuanStateView state,
        int reactionTileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        int sourceSeat = -1,
        string reactionType = "discard",
        bool forceLightweight = false,
        bool mandatoryGang = false)
    {
        if (canHu)
        {
            return new SichuanReactionDecisionResult
            {
                Action = new SichuanAction(SichuanActionType.Hu, reactionTileType, 100000, "可胡时直接胡牌"),
                ShantenAfter = -1,
                CurrentShanten = -1,
                Reasons = new[] { "可胡时直接胡牌", "四川血战先胡牌落袋为安" },
                ActionScores = new Dictionary<string, int>
                {
                    ["hu"] = 100000,
                    ["pass"] = -100000
                }
            };
        }

        var belief = _belief.Build(state);
        var roundStage = ResolveRoundStage(state);
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var currentFollowUp = EvaluateBestFollowUp(state.Hand18, state.Remaining18, meldCount);
        var currentPlan = _routePlan.Evaluate(state);
        var maxReadyPosterior = belief.SeatReadyPosterior.Values.DefaultIfEmpty(0.0).Max();
        var threatLevel = ResolveThreatLevel(state, belief);
        var passDiscardRisk = currentFollowUp.BestDiscardTile >= 0 ? _danger.EvaluateDetail(currentFollowUp.BestDiscardTile, state, belief) : new SichuanDangerEvaluation();
        var passWallPosterior = EstimateWallPosterior(currentFollowUp.ImprovingTiles, belief);
        var passBlockPosterior = EstimateBlockPosterior(currentFollowUp.ImprovingTiles, belief);
        var scores = new Dictionary<string, int>();

        var passScore = BuildPassScore(currentFollowUp, roundStage, threatLevel, maxReadyPosterior, state.WallCount, passWallPosterior, passBlockPosterior, passDiscardRisk.Risk);
        scores["pass"] = passScore;
        var best = new SichuanReactionDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Pass, reactionTileType, passScore, "保持当前最快成叫路径"),
            ShantenAfter = currentFollowUp.Shanten,
            UkeireAfter = currentFollowUp.Ukeire,
            LiveUkeireAfter = currentFollowUp.LiveUkeire,
            CurrentShanten = currentFollowUp.Shanten,
            CurrentLiveUkeire = currentFollowUp.LiveUkeire,
            ThreatLevel = threatLevel,
            RoundStage = roundStage,
            MaxReadyPosterior = maxReadyPosterior,
            Reasons = BuildPassReasons(currentFollowUp, roundStage, threatLevel, maxReadyPosterior)
                .Concat(BuildRouteProtectionPassReasons(state, currentPlan))
                .Concat(currentPlan.Reasons)
                .ToArray(),
            PosteriorSummary = BuildPosteriorSummary(passWallPosterior, passBlockPosterior, passDiscardRisk.Risk, maxReadyPosterior, threatLevel),
            FutureSummary = BuildFutureSummary("pass", currentFollowUp, passDiscardRisk.Risk, passWallPosterior, passBlockPosterior),
            ActionScores = scores
        };

        var candidates = new List<(string action, SichuanReactionDecisionResult result, int[] handAfter, int meldCountAfter)>
        {
            ("pass", best, (int[])state.Hand18.Clone(), meldCount)
        };

        if (canPeng && reactionTileType is >= 0 and < 27 && state.Hand18[reactionTileType] >= 2)
        {
            var pengResult = EvaluatePeng(state, belief, reactionTileType, currentFollowUp, currentPlan, roundStage, threatLevel, maxReadyPosterior);
            if (ShouldForceOldHandPeng(state, reactionTileType, currentFollowUp, pengResult, roundStage, threatLevel, maxReadyPosterior)
                && pengResult.Action.Score <= best.Action.Score)
            {
                pengResult.Action = pengResult.Action with
                {
                    Score = best.Action.Score + 96,
                    Reason = "老手主动碰牌抢听"
                };
                var forcedReasons = pengResult.Reasons.ToList();
                forcedReasons.Add("老手碰牌闸门：不升向听且非稳定七对，禁止被普通过牌压掉");
                pengResult.Reasons = forcedReasons;
            }
            scores["peng"] = pengResult.Action.Score;
            candidates.Add(("peng", pengResult, RemoveCopies(state.Hand18, reactionTileType, 2), meldCount + 1));
            if (pengResult.Action.Score > best.Action.Score)
            {
                pengResult.ActionScores = scores;
                best = pengResult;
            }
        }

        if (canGang && reactionTileType is >= 0 and < 27 && state.Hand18[reactionTileType] >= 3)
        {
            var gangResult = EvaluateGang(state, belief, reactionTileType, currentFollowUp, currentPlan, roundStage, threatLevel, maxReadyPosterior, reactionType, sourceSeat);
            if (ShouldForceMeldedGang(state, reactionTileType, currentFollowUp, gangResult, roundStage, threatLevel, maxReadyPosterior, reactionType, sourceSeat)
                && gangResult.Action.Score <= best.Action.Score)
            {
                gangResult.Action = gangResult.Action with
                {
                    Score = best.Action.Score + 112,
                    Reason = "明杠收益明确，且非七对路线"
                };
                var forcedReasons = gangResult.Reasons.ToList();
                forcedReasons.Add("明杠闸门：别人打出第四张且杠后不慢，优先收雨钱/补牌");
                gangResult.Reasons = forcedReasons;
            }
            scores["gang"] = gangResult.Action.Score;
            candidates.Add(("gang", gangResult, RemoveCopies(state.Hand18, reactionTileType, 3), meldCount + 1));
            if (gangResult.Action.Score > best.Action.Score)
            {
                gangResult.ActionScores = scores;
                best = gangResult;
            }
        }

        if (!forceLightweight && ShouldSearchReaction(candidates))
        {
            var simulations = 0;
            var bonusMap = EvaluateReactionSearchBonuses(state, candidates, ref simulations);
            for (var index = 0; index < candidates.Count; index++)
            {
                var item = candidates[index];
                var bonus = bonusMap.GetValueOrDefault(item.action, 0.0);
                item.result.SearchUsed = true;
                item.result.SearchSimulations = simulations;
                item.result.SearchBonus = bonus;
                item.result.Action = item.result.Action with { Score = item.result.Action.Score + (int)Math.Round(bonus * 100.0) };
                var mergedReasons = item.result.Reasons.ToList();
                mergedReasons.Add($"短搜索修正 {bonus:F2}");
                item.result.Reasons = mergedReasons;
                candidates[index] = item;
                scores[item.action] = item.result.Action.Score;
            }
            best = candidates
                .OrderByDescending(item => item.result.Action.Score)
                .Select(item => item.result)
                .First();
        }

        var forcedGangAfterSearch = candidates
            .FirstOrDefault(item => item.action == "gang"
                && ShouldForceMeldedGang(state, reactionTileType, currentFollowUp, item.result, roundStage, threatLevel, maxReadyPosterior, reactionType, sourceSeat));
        if (forcedGangAfterSearch.result is not null && forcedGangAfterSearch.result.Action.Score <= best.Action.Score)
        {
            forcedGangAfterSearch.result.Action = forcedGangAfterSearch.result.Action with
            {
                Score = best.Action.Score + 112,
                Reason = "明杠收益明确，且非七对路线"
            };
            var forcedReasons = forcedGangAfterSearch.result.Reasons.ToList();
            forcedReasons.Add("明杠闸门：短搜索后仍保护不降速的明杠收益");
            forcedGangAfterSearch.result.Reasons = forcedReasons;
            scores["gang"] = forcedGangAfterSearch.result.Action.Score;
            best = forcedGangAfterSearch.result;
        }

        var lateWallTripletGang = candidates
            .FirstOrDefault(item => item.action == "gang"
                && ShouldForceLateWallTripletGang(state, reactionTileType, currentFollowUp, item.result, reactionType, sourceSeat));
        if (lateWallTripletGang.result is not null && lateWallTripletGang.result.Action.Score <= best.Action.Score)
        {
            lateWallTripletGang.result.Action = lateWallTripletGang.result.Action with
            {
                Score = best.Action.Score + 96,
                Reason = "尾张明杠优先收雨钱"
            };
            var forcedReasons = lateWallTripletGang.result.Reasons.ToList();
            forcedReasons.Add("尾张三张在手且别人打出第四张，明杠不比当前路径更慢，优先直接杠");
            lateWallTripletGang.result.Reasons = forcedReasons;
            scores["gang"] = lateWallTripletGang.result.Action.Score;
            best = lateWallTripletGang.result;
        }

        if (!scores.ContainsKey("peng")) scores["peng"] = int.MinValue / 4;
        if (!scores.ContainsKey("gang")) scores["gang"] = int.MinValue / 4;
        best.ActionScores = new Dictionary<string, int>(scores);
        return best;
    }

    private SichuanReactionDecisionResult EvaluatePeng(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanRoutePlanResult currentPlan,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior)
    {
        var handAfter = RemoveCopies(state.Hand18, reactionTileType, 2);
        var meldCountAfter = state.Melds18[state.SeatIndex].Count / 3 + 1;
        var followUp = EvaluateBestFollowUp(handAfter, state.Remaining18, meldCountAfter);
        var reDiscardsClaimedTile = followUp.BestDiscardTile == reactionTileType && followUp.BestDiscardTile >= 0;
        var currentPairCount = CountPairs(state.Hand18);
        var pairCountAfter = CountPairs(handAfter);
        var currentMeldCount = state.Melds18[state.SeatIndex].Count / 3;
        var sevenPairsLikely = IsSevenPairsLikely(state.Hand18, currentMeldCount);
        var sevenPairsTenpai = IsSevenPairsTenpai(state.Hand18, currentMeldCount);
        var structureBoost = EstimatePengStructureBoost(
            reactionTileType,
            currentFollowUp,
            followUp,
            currentPairCount,
            pairCountAfter,
            sevenPairsLikely,
            roundStage);
        var oldHandPengBoost = EstimateOldHandPengBoost(
            currentFollowUp,
            followUp,
            currentPairCount,
            pairCountAfter,
            sevenPairsLikely,
            roundStage);
        var discardRisk = followUp.BestDiscardTile >= 0 ? _danger.EvaluateDetail(followUp.BestDiscardTile, state, belief) : new SichuanDangerEvaluation();
        var waitWallPosterior = EstimateWallPosterior(followUp.ImprovingTiles, belief);
        var waitBlockPosterior = EstimateBlockPosterior(followUp.ImprovingTiles, belief);
        var score = 96
            - followUp.Shanten * 108
            + followUp.LiveUkeire * 10
            + (currentFollowUp.Shanten - followUp.Shanten) * 118
            + (followUp.LiveUkeire - currentFollowUp.LiveUkeire) * 9
            + structureBoost
            + oldHandPengBoost
            + (int)Math.Round(waitWallPosterior * 96.0)
            - (int)Math.Round(waitBlockPosterior * 76.0)
            - discardRisk.Risk
            - roundStage * 12
            - threatLevel * 12;

        if (followUp.Shanten <= 0) score += 248;
        if (followUp.Shanten < currentFollowUp.Shanten) score += 132;
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.Shanten <= 1 && followUp.LiveUkeire >= currentFollowUp.LiveUkeire - 2) score += 96;
        if (followUp.Shanten == 0 && currentFollowUp.Shanten > 0) score += 168;
        if (followUp.Shanten <= 1 && followUp.Shanten <= currentFollowUp.Shanten && followUp.LiveUkeire + 4 >= currentFollowUp.LiveUkeire)
            score += roundStage <= 1 ? 92 : 46;
        if (followUp.Shanten <= 0 && discardRisk.Risk < 70)
            score += 132;
        if (currentPairCount >= 3 && !sevenPairsLikely && followUp.Shanten <= currentFollowUp.Shanten)
            score += 64;
        if (followUp.Shanten > currentFollowUp.Shanten)
        {
            score -= 112;
        }
        else if (followUp.Shanten == currentFollowUp.Shanten && structureBoost + oldHandPengBoost < 80)
        {
            score -= 24;
        }
        if (followUp.LiveUkeire <= currentFollowUp.LiveUkeire && followUp.Shanten >= currentFollowUp.Shanten && structureBoost + oldHandPengBoost < 80) score -= 12;
        if (discardRisk.Risk >= 56) score -= 38;
        if (roundStage >= 2 && maxReadyPosterior >= 0.56 && followUp.Shanten > 0) score -= 72;
        if (maxReadyPosterior >= 0.68 && followUp.Shanten > 0) score -= 18;
        if (roundStage >= 2 && maxReadyPosterior >= 0.72 && discardRisk.Risk >= 70 && followUp.Shanten >= currentFollowUp.Shanten)
            score -= 460;
        if (maxReadyPosterior >= 0.88 && discardRisk.Risk >= 78 && followUp.Shanten > 0)
            score -= 180;
        if (roundStage <= 0 && followUp.Shanten == 0 && currentFollowUp.Shanten > 0 && followUp.LiveUkeire <= 3 && currentFollowUp.LiveUkeire >= 14)
            score -= 1080;
        if (ShouldPassWideNoSpeedPeng(currentFollowUp, followUp, roundStage, maxReadyPosterior))
            score -= 1180;
        if (reDiscardsClaimedTile)
            score -= 640;
        if (reDiscardsClaimedTile && state.Hand18[reactionTileType] >= 3)
            score -= 980;
        if (sevenPairsTenpai)
            score -= 1320;
        if (sevenPairsLikely && currentPairCount >= 5)
            score -= 6000;
        if (currentPlan.ForbidsMelds)
            score -= 6000;

        var reasons = new List<string>
        {
            $"碰后最佳向听 {followUp.Shanten}",
            $"碰后活张 {followUp.LiveUkeire}",
            $"碰后首打危险 {discardRisk.Risk}",
        };
        if (currentPlan.ForbidsMelds)
            reasons.Add($"七对路线：{currentPlan.PrimaryRoute} 禁止碰牌，碰牌会破坏七对");
        if (sevenPairsLikely && currentPairCount >= 5)
            reasons.Add("七对路线：五对以上门清牌不碰，保留七对/龙七对");
        if (sevenPairsTenpai) reasons.Add("七对已听，碰牌会破坏听牌，优先过牌");
        if (reDiscardsClaimedTile) reasons.Add("碰后最优首打仍是同张，直接改碰属于无效副露");
        if (reDiscardsClaimedTile && state.Hand18[reactionTileType] >= 3)
            reasons.Add("已有三张可明杠时，碰后再打同张不如直接杠");
        if (followUp.Shanten <= 0) reasons.Add("碰后可直接成叫");
        if (followUp.Shanten < currentFollowUp.Shanten) reasons.Add("碰牌明显提速");
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.Shanten <= 1 && followUp.LiveUkeire >= currentFollowUp.LiveUkeire - 2)
            reasons.Add("碰牌虽不降向听，但能更主动定型抢胡");
        if (followUp.Shanten <= 1 && followUp.LiveUkeire + 4 >= currentFollowUp.LiveUkeire)
            reasons.Add("老手进攻：碰后接近成叫且活张不差");
        if (followUp.Shanten >= currentFollowUp.Shanten) reasons.Add("碰牌未缩短成叫路径");
        if (structureBoost >= 60) reasons.Add("碰后对子冗余下降，牌型更利于早听");
        else if (structureBoost >= 30) reasons.Add("碰后结构更顺，提前定型");
        if (oldHandPengBoost >= 120) reasons.Add("对子多且七对路线不稳，老手主动碰牌抢听");
        else if (oldHandPengBoost >= 70) reasons.Add("碰牌不损连牌速度，优先定型逼近听牌");
        if (waitWallPosterior >= 0.45) reasons.Add("后验显示等张更偏向牌墙");
        if (waitBlockPosterior >= 0.38) reasons.Add("后验显示关键进张更可能在他家手里");
        if (discardRisk.Risk >= 56) reasons.Add("碰后第一打点炮风险偏高");
        if (roundStage >= 2 || maxReadyPosterior >= 0.48) reasons.Add("尾盘或后验压力偏高，非必要不碰");
        if (roundStage >= 2 && maxReadyPosterior >= 0.72 && discardRisk.Risk >= 70 && followUp.Shanten >= currentFollowUp.Shanten)
            reasons.Add("后期高后验且首打高危，碰牌未降向听，C# 强制降权");
        if (roundStage <= 0 && followUp.Shanten == 0 && currentFollowUp.Shanten > 0 && followUp.LiveUkeire <= 3 && currentFollowUp.LiveUkeire >= 14)
            reasons.Add("早期碰后虽成叫但听口过窄，放弃低价值碰牌");
        if (ShouldPassWideNoSpeedPeng(currentFollowUp, followUp, roundStage, maxReadyPosterior))
            reasons.Add("当前不碰也有宽进张，碰牌不降向听，优先保留门前弹性");

        return new SichuanReactionDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Peng, reactionTileType, score, reasons[0]),
            ShantenAfter = followUp.Shanten,
            UkeireAfter = followUp.Ukeire,
            LiveUkeireAfter = followUp.LiveUkeire,
            CurrentShanten = currentFollowUp.Shanten,
            CurrentLiveUkeire = currentFollowUp.LiveUkeire,
            ThreatLevel = threatLevel,
            RoundStage = roundStage,
            MaxReadyPosterior = maxReadyPosterior,
            Reasons = reasons,
            PosteriorSummary = BuildPosteriorSummary(waitWallPosterior, waitBlockPosterior, discardRisk.Risk, maxReadyPosterior, threatLevel),
            FutureSummary = BuildFutureSummary("peng", followUp, discardRisk.Risk, waitWallPosterior, waitBlockPosterior)
        };
    }

    private SichuanReactionDecisionResult EvaluateGang(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanRoutePlanResult currentPlan,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
        string reactionType,
        int sourceSeat)
    {
        var handAfter = RemoveCopies(state.Hand18, reactionTileType, 3);
        var meldCountAfter = state.Melds18[state.SeatIndex].Count / 3 + 1;
        var followUp = EvaluateBestFollowUp(handAfter, state.Remaining18, meldCountAfter);
        var discardRisk = followUp.BestDiscardTile >= 0 ? _danger.EvaluateDetail(followUp.BestDiscardTile, state, belief) : new SichuanDangerEvaluation();
        var waitWallPosterior = EstimateWallPosterior(followUp.ImprovingTiles, belief);
        var waitBlockPosterior = EstimateBlockPosterior(followUp.ImprovingTiles, belief);
        var isMeldedGang = sourceSeat >= 0 && reactionType == "discard";
        var currentMeldCount = state.Melds18[state.SeatIndex].Count / 3;
        var sevenPairsLikely = IsSevenPairsLikely(state.Hand18, currentMeldCount);
        var tripletRedundancy = state.Hand18[reactionTileType] >= 3;
        var gangTaxBonus = isMeldedGang ? 118 : 36;
        var meldedGangShapeBonus = 0;
        if (isMeldedGang && followUp.Shanten <= currentFollowUp.Shanten)
        {
            meldedGangShapeBonus += 96;
            if (!sevenPairsLikely) meldedGangShapeBonus += 132;
            if (tripletRedundancy) meldedGangShapeBonus += 58;
            if (followUp.LiveUkeire + 3 >= currentFollowUp.LiveUkeire) meldedGangShapeBonus += 48;
            if (roundStage <= 1 && maxReadyPosterior < 0.56) meldedGangShapeBonus += 52;
        }
        var score = 86
            - followUp.Shanten * 112
            + followUp.LiveUkeire * 11
            + (currentFollowUp.Shanten - followUp.Shanten) * 124
            + (int)Math.Round(waitWallPosterior * 74.0)
            - (int)Math.Round(waitBlockPosterior * 82.0)
            - (int)Math.Round(discardRisk.Risk * 0.82)
            - roundStage * 10
            - threatLevel * 12
            + gangTaxBonus
            + meldedGangShapeBonus;

        if (followUp.Shanten <= 0) score += 172;
        if (roundStage <= 1 && maxReadyPosterior < 0.52 && followUp.Shanten <= currentFollowUp.Shanten) score += 78;
        if (followUp.Shanten == 0 && currentFollowUp.Shanten > 0) score += 168;
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.LiveUkeire >= currentFollowUp.LiveUkeire - 2) score += 112;
        if (followUp.Shanten <= currentFollowUp.Shanten && discardRisk.Risk < 64) score += 72;
        if (isMeldedGang && !sevenPairsLikely && followUp.Shanten <= currentFollowUp.Shanten && discardRisk.Risk < 72) score += 96;
        if (followUp.Shanten <= 0 && discardRisk.Risk < 70) score += 118;
        if (followUp.Shanten > currentFollowUp.Shanten) score -= 126;
        if (roundStage >= 1 && followUp.Shanten > 0) score -= 10;
        if (discardRisk.Risk >= 56) score -= 42;
        if (roundStage >= 2 && followUp.Shanten > 0) score -= 24;
        if (maxReadyPosterior >= 0.62 && followUp.Shanten > 0) score -= 12;
        if (sevenPairsLikely && CountPairs(state.Hand18) >= 5)
            score -= 6000;
        if (currentPlan.ForbidsGangs)
            score -= 6000;

        var reasons = new List<string>
        {
            $"杠后最佳向听 {followUp.Shanten}",
            $"杠后活张 {followUp.LiveUkeire}",
            $"杠后首打危险 {discardRisk.Risk}",
            "杠牌只在不拖慢成叫时考虑"
        };
        if (currentPlan.ForbidsGangs)
            reasons.Add($"七对路线：{currentPlan.PrimaryRoute} 禁止杠牌，杠牌会破坏七对");
        if (sevenPairsLikely && CountPairs(state.Hand18) >= 5)
            reasons.Add("七对路线：五对以上门清牌不杠，保留七对/龙七对");
        if (followUp.Shanten <= 0) reasons.Add("杠后仍保持成叫");
        if (followUp.Shanten > currentFollowUp.Shanten) reasons.Add("杠牌会拖慢速度，直接降权");
        if (isMeldedGang && followUp.Shanten <= currentFollowUp.Shanten && !sevenPairsLikely)
            reasons.Add("明杠收益明确，且非七对路线");
        if (isMeldedGang && followUp.Shanten <= currentFollowUp.Shanten)
            reasons.Add("杠后不拖慢成叫，优先收雨钱/补牌");
        if (followUp.Shanten <= currentFollowUp.Shanten && discardRisk.Risk < 64) reasons.Add("杠后不拖慢且首打风险可控，主动收雨钱");
        if (waitWallPosterior >= 0.45) reasons.Add("后验显示后续摸进仍有支撑");
        if (waitBlockPosterior >= 0.38) reasons.Add("后验显示关键进张受阻");
        if (discardRisk.Risk >= 56) reasons.Add("杠后首打风险偏高");
        if (roundStage >= 2 || maxReadyPosterior >= 0.50) reasons.Add("尾盘或后验压力高，谨慎放弃杠牌");

        return new SichuanReactionDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Gang, reactionTileType, score, reasons[0]),
            ShantenAfter = followUp.Shanten,
            UkeireAfter = followUp.Ukeire,
            LiveUkeireAfter = followUp.LiveUkeire,
            CurrentShanten = currentFollowUp.Shanten,
            CurrentLiveUkeire = currentFollowUp.LiveUkeire,
            ThreatLevel = threatLevel,
            RoundStage = roundStage,
            MaxReadyPosterior = maxReadyPosterior,
            Reasons = reasons,
            PosteriorSummary = BuildPosteriorSummary(waitWallPosterior, waitBlockPosterior, discardRisk.Risk, maxReadyPosterior, threatLevel),
            FutureSummary = BuildFutureSummary("gang", followUp, discardRisk.Risk, waitWallPosterior, waitBlockPosterior)
        };
    }

    private FollowUpSummary EvaluateBestFollowUp(int[] hand18, int[] remaining18, int meldCount)
    {
        var currentShanten = _shanten.CalcBestShanten(hand18, meldCount);
        if (hand18.Sum() <= 1)
        {
            return new FollowUpSummary(currentShanten, 0, 0, -1, Array.Empty<int>());
        }

        var bestShanten = int.MaxValue;
        var bestUkeire = 0;
        var bestLive = 0;
        var bestTile = -1;

        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            if (hand18[tileType] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(hand18, tileType, meldCount);
            var (ukeire, liveUkeire, _) = _ukeire.CalcUkeire(hand18, remaining18, tileType, meldCount);
            if (shanten < bestShanten
                || (shanten == bestShanten && liveUkeire > bestLive)
                || (shanten == bestShanten && liveUkeire == bestLive && ukeire > bestUkeire))
            {
                bestShanten = shanten;
                bestUkeire = ukeire;
                bestLive = liveUkeire;
                bestTile = tileType;
            }
        }

        if (bestTile < 0)
        {
            return new FollowUpSummary(currentShanten, 0, 0, -1, Array.Empty<int>());
        }

        var (_, _, improvingTiles) = _ukeire.CalcUkeire(hand18, remaining18, bestTile, meldCount);
        return new FollowUpSummary(bestShanten, bestUkeire, bestLive, bestTile, improvingTiles.ToArray());
    }

    private static int[] RemoveCopies(int[] hand18, int tileType, int removeCount)
    {
        var clone = (int[])hand18.Clone();
        if (tileType < 0 || tileType >= clone.Length) return clone;
        clone[tileType] = Math.Max(0, clone[tileType] - removeCount);
        return clone;
    }

    private static int ResolveRoundStage(SichuanStateView state)
    {
        var maxDiscards = state.Discards18.Max(list => list.Count);
        var hasLikelyReady = state.IsCalled.Any(value => value) || state.IsReady.Any(value => value);
        var exposedMeldCount = state.Melds18.Sum(list => list.Count / 3);
        if (state.WallCount <= 6) return 2;
        if (hasLikelyReady && state.WallCount <= 8) return 2;
        if (maxDiscards >= 10 || state.WallCount <= 13 || exposedMeldCount >= 5) return 1;
        if (hasLikelyReady && state.WallCount <= 10) return 1;
        return 0;
    }

    private int ResolveThreatLevel(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var total = 0;
        for (var seat = 0; seat < state.HasHu.Length; seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat]) continue;
            var seatDanger = 0;
            if (belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.56) seatDanger += 2;
            else if (belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.40) seatDanger += 1;
            if (state.IsCalled[seat] || state.IsReady[seat]) seatDanger += 1;
            if (state.Melds18[seat].Count / 3 >= 2) seatDanger += 1;
            total += seatDanger;
        }
        return Math.Clamp(total, 0, 5);
    }

    private static int BuildPassScore(FollowUpSummary currentFollowUp, int roundStage, int threatLevel, double maxReadyPosterior, int wallCount, double wallPosterior, double blockPosterior, int discardRisk)
    {
        var score = 24
            - currentFollowUp.Shanten * 84
            + currentFollowUp.LiveUkeire * 4
            + Math.Min(12, wallCount)
            + (int)Math.Round(wallPosterior * 48.0)
            - (int)Math.Round(blockPosterior * 88.0)
            - (int)Math.Round(discardRisk * 0.34)
            - roundStage * 12;
        if (threatLevel >= 3) score += 10;
        if (maxReadyPosterior >= 0.56) score += 12;
        return score;
    }

    private static IReadOnlyList<string> BuildPassReasons(FollowUpSummary currentFollowUp, int roundStage, int threatLevel, double maxReadyPosterior)
    {
        var reasons = new List<string>
        {
            $"当前最快向听 {currentFollowUp.Shanten}",
            $"当前潜在活张 {currentFollowUp.LiveUkeire}",
            "仅在副露收益不足时才选择过牌"
        };
        if (threatLevel >= 3 || maxReadyPosterior >= 0.56) reasons.Add("桌面压力偏高，过更稳");
        if (roundStage >= 2) reasons.Add("后期不为低价值副露冒险");
        return reasons;
    }

    private static IReadOnlyList<string> BuildRouteProtectionPassReasons(
        SichuanStateView state,
        SichuanRoutePlanResult currentPlan)
    {
        var currentMeldCount = state.Melds18[state.SeatIndex].Count / 3;
        var pairCount = CountPairs(state.Hand18);
        if (currentPlan.ForbidsMelds)
            return Array.Empty<string>();
        if (currentMeldCount == 0 && pairCount >= 5 && IsSevenPairsLikely(state.Hand18, currentMeldCount))
            return new[] { "七对路线：五对以上门清牌优先过牌，保留七对/龙七对" };
        return Array.Empty<string>();
    }

    private static IReadOnlyList<string> BuildPosteriorSummary(double wallPosterior, double blockPosterior, int discardRisk, double maxReadyPosterior, int threatLevel)
    {
        return new[]
        {
            $"牌墙后验 {wallPosterior * 100.0:0}%",
            $"他家持张后验 {blockPosterior * 100.0:0}%",
            $"首打危险 {discardRisk}%",
            $"最高听牌后验 {maxReadyPosterior * 100.0:0}%",
            $"桌面威胁 {threatLevel}"
        };
    }

    private static IReadOnlyList<string> BuildFutureSummary(string action, FollowUpSummary followUp, int discardRisk, double wallPosterior, double blockPosterior)
    {
        var actionLabel = action switch
        {
            "pass" => "过后",
            "peng" => "碰后",
            "gang" => "杠后",
            _ => "后续"
        };
        return new[]
        {
            $"{actionLabel}最快向听 {followUp.Shanten}",
            $"{actionLabel}活张 {followUp.LiveUkeire}",
            $"{actionLabel}墙内进张偏强 {wallPosterior * 100.0:0}%",
            $"{actionLabel}被捏风险 {blockPosterior * 100.0:0}%",
            $"{actionLabel}首打风险 {discardRisk}%"
        };
    }

    private bool ShouldSearchReaction(IReadOnlyList<(string action, SichuanReactionDecisionResult result, int[] handAfter, int meldCountAfter)> candidates)
    {
        if (candidates.Count < 2) return false;
        var ordered = candidates
            .OrderByDescending(item => item.result.Action.Score)
            .ToArray();
        if (ordered[0].action is "peng" or "gang")
        {
            if (ordered[0].result.RoundStage <= 1)
                return true;
            if (ordered[0].result.CurrentShanten <= 1 || ordered[0].result.ShantenAfter <= 1)
                return true;
        }
        var gap = ordered[0].result.Action.Score - ordered[1].result.Action.Score;
        if (gap <= 90) return true;
        if (ordered[0].result.ShantenAfter == ordered[1].result.ShantenAfter && Math.Abs(ordered[0].result.LiveUkeireAfter - ordered[1].result.LiveUkeireAfter) <= 4)
            return true;
        return false;
    }

    private Dictionary<string, double> EvaluateReactionSearchBonuses(
        SichuanStateView state,
        IReadOnlyList<(string action, SichuanReactionDecisionResult result, int[] handAfter, int meldCountAfter)> candidates,
        ref int simulations)
    {
        var bonuses = candidates.ToDictionary(item => item.action, _ => 0.0);
        foreach (var candidate in candidates)
        {
            var total = 0.0;
            for (var rollout = 0; rollout < ReactionSearchRollouts; rollout++)
            {
                total += SimulateReactionFuture(state, candidate.handAfter, candidate.meldCountAfter, ReactionSearchDepth);
            }
            bonuses[candidate.action] = total / Math.Max(1, ReactionSearchRollouts);
            simulations += ReactionSearchRollouts;
        }
        var min = bonuses.Values.Min();
        return bonuses.ToDictionary(item => item.Key, item => (item.Value - min) * 0.18);
    }

    private double SimulateReactionFuture(SichuanStateView state, int[] initialHand, int meldCount, int depth)
    {
        var hand = (int[])initialHand.Clone();
        var remaining = (int[])state.Remaining18.Clone();
        var total = 0.0;
        for (var step = 0; step < depth; step++)
        {
            var draw = SampleRemainingTile(remaining);
            if (draw < 0) break;
            hand[draw]++;
            remaining[draw] = Math.Max(0, remaining[draw] - 1);
            var followUp = EvaluateBestFollowUp(hand, remaining, meldCount);
            total += (8 - followUp.Shanten) * 1.7 + followUp.LiveUkeire * 0.34 + followUp.Ukeire * 0.16;
            if (followUp.Shanten <= 0) total += 3.6;
            if (followUp.BestDiscardTile >= 0 && hand[followUp.BestDiscardTile] > 0)
                hand[followUp.BestDiscardTile]--;
        }
        return total / Math.Max(1, depth);
    }

    private static int SampleRemainingTile(int[] remaining)
    {
        var total = 0;
        for (var index = 0; index < remaining.Length; index++)
            total += Math.Max(0, remaining[index]);
        if (total <= 0) return -1;
        var roll = Random.Shared.Next(total);
        for (var index = 0; index < remaining.Length; index++)
        {
            var count = Math.Max(0, remaining[index]);
            if (roll < count) return index;
            roll -= count;
        }
        return -1;
    }

    private static int EstimatePengStructureBoost(
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        FollowUpSummary followUp,
        int currentPairCount,
        int pairCountAfter,
        bool sevenPairsLikely,
        int roundStage)
    {
        if (sevenPairsLikely) return 0;
        var boost = 0;
        var pairReduction = Math.Max(0, currentPairCount - pairCountAfter);
        if (pairReduction > 0 && followUp.Shanten <= currentFollowUp.Shanten)
            boost += 42 + pairReduction * 18;
        if (currentPairCount >= 4 && pairReduction > 0 && followUp.Shanten <= Math.Min(2, currentFollowUp.Shanten))
            boost += 34;
        if (currentFollowUp.Shanten <= 2 && followUp.Shanten <= currentFollowUp.Shanten && followUp.LiveUkeire + 2 >= currentFollowUp.LiveUkeire)
            boost += 28;
        if (roundStage <= 1 && IsEdgeHeavyPair(reactionTileType) && followUp.Shanten <= currentFollowUp.Shanten)
            boost += 22;
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.LiveUkeire >= currentFollowUp.LiveUkeire && pairReduction > 0)
            boost += 20;
        return boost;
    }

    private static int EstimateOldHandPengBoost(
        FollowUpSummary currentFollowUp,
        FollowUpSummary followUp,
        int currentPairCount,
        int pairCountAfter,
        bool sevenPairsLikely,
        int roundStage)
    {
        var pairReduction = Math.Max(0, currentPairCount - pairCountAfter);
        if (pairReduction <= 0 || followUp.Shanten > currentFollowUp.Shanten)
            return 0;

        var boost = 0;
        var sevenPairsRouteWeak = !sevenPairsLikely || roundStage >= 1 || currentFollowUp.Shanten > 1;
        if (currentPairCount >= 3 && sevenPairsRouteWeak)
            boost += 78;
        if (currentPairCount >= 4 && sevenPairsRouteWeak)
            boost += 46;
        if (followUp.Shanten <= 1)
            boost += 72;
        if (followUp.Shanten == 0)
            boost += 96;
        if (followUp.LiveUkeire + 3 >= currentFollowUp.LiveUkeire)
            boost += 28;
        if (roundStage <= 1)
            boost += 24;
        return boost;
    }

    private static int CountPairs(int[] hand18)
    {
        var count = 0;
        for (var index = 0; index < hand18.Length; index++)
        {
            if (hand18[index] >= 2) count++;
        }
        return count;
    }

    private bool ShouldForceOldHandPeng(
        SichuanStateView state,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanReactionDecisionResult pengResult,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior)
    {
        if (reactionTileType < 0 || reactionTileType >= state.Hand18.Length || state.Hand18[reactionTileType] < 2)
            return false;
        if (pengResult.ShantenAfter > currentFollowUp.Shanten)
            return false;
        if (threatLevel >= 4 && maxReadyPosterior >= 0.70 && pengResult.ShantenAfter > 0 && pengResult.ShantenAfter >= currentFollowUp.Shanten)
            return false;
        if (roundStage >= 2
            && pengResult.ShantenAfter >= currentFollowUp.Shanten
            && pengResult.LiveUkeireAfter + 4 < currentFollowUp.LiveUkeire
            && (state.WallCount <= 5 || threatLevel >= 4 || maxReadyPosterior >= 0.56))
        {
            return false;
        }
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        if (IsSevenPairsTenpai(state.Hand18, meldCount))
            return false;
        var sevenPairsLikely = IsSevenPairsLikely(state.Hand18, meldCount);
        if (sevenPairsLikely && currentFollowUp.Shanten <= 1 && roundStage <= 0)
            return false;
        var handAfter = RemoveCopies(state.Hand18, reactionTileType, 2);
        var followUp = EvaluateBestFollowUp(handAfter, state.Remaining18, meldCount + 1);
        if (followUp.BestDiscardTile == reactionTileType && followUp.BestDiscardTile >= 0)
            return false;
        if (ShouldPassWideNoSpeedPeng(currentFollowUp, followUp, roundStage, maxReadyPosterior))
            return false;
        var pairCount = CountPairs(state.Hand18);
        if (pengResult.ShantenAfter <= 0)
            return true;
        if (pengResult.ShantenAfter < currentFollowUp.Shanten)
            return true;
        if (pairCount >= 3 && pengResult.ShantenAfter <= 1)
            return true;
        if (pairCount >= 4 && roundStage <= 1)
            return true;
        return roundStage <= 1 && pengResult.LiveUkeireAfter + 4 >= currentFollowUp.LiveUkeire;
    }

    private static bool ShouldPassWideNoSpeedPeng(
        FollowUpSummary currentFollowUp,
        FollowUpSummary followUp,
        int roundStage,
        double maxReadyPosterior)
    {
        return roundStage <= 1
            && maxReadyPosterior < 0.56
            && currentFollowUp.Shanten >= 2
            && followUp.Shanten >= currentFollowUp.Shanten
            && currentFollowUp.LiveUkeire >= 12
            && followUp.LiveUkeire >= currentFollowUp.LiveUkeire
            && followUp.Shanten > 1;
    }

    private static bool ShouldForceMeldedGang(
        SichuanStateView state,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanReactionDecisionResult gangResult,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
        string reactionType,
        int sourceSeat)
    {
        if (reactionType != "discard" || sourceSeat < 0)
            return false;
        if (reactionTileType < 0 || reactionTileType >= state.Hand18.Length || state.Hand18[reactionTileType] < 3)
            return false;
        if (gangResult.ShantenAfter > currentFollowUp.Shanten)
            return false;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        if (IsSevenPairsLikely(state.Hand18, meldCount))
            return false;
        if (threatLevel >= 4 && maxReadyPosterior >= 0.70 && gangResult.ShantenAfter > 0)
            return false;
        if (roundStage >= 2 && maxReadyPosterior >= 0.62 && gangResult.ShantenAfter > 0)
            return false;
        if (gangResult.ShantenAfter <= 0)
            return true;
        if (gangResult.ShantenAfter < currentFollowUp.Shanten)
            return true;
        return roundStage <= 1 && gangResult.LiveUkeireAfter + 3 >= currentFollowUp.LiveUkeire;
    }

    private static bool ShouldForceLateWallTripletGang(
        SichuanStateView state,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanReactionDecisionResult gangResult,
        string reactionType,
        int sourceSeat)
    {
        if (reactionType != "discard" || sourceSeat < 0)
            return false;
        if (state.WallCount > 2)
            return false;
        if (reactionTileType < 0 || reactionTileType >= state.Hand18.Length || state.Hand18[reactionTileType] < 3)
            return false;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        if (IsSevenPairsLikely(state.Hand18, meldCount))
            return false;
        return gangResult.ShantenAfter <= currentFollowUp.Shanten;
    }

    private static bool IsSevenPairsLikely(int[] hand18, int meldCount)
    {
        if (meldCount > 0) return false;
        var pairs = 0;
        var triplets = 0;
        var singles = 0;
        for (var index = 0; index < hand18.Length; index++)
        {
            if (hand18[index] >= 2) pairs++;
            if (hand18[index] >= 3) triplets++;
            if (hand18[index] == 1) singles++;
        }
        return pairs >= 5 && triplets <= 1 && singles <= 3;
    }

    private bool IsSevenPairsTenpai(int[] hand18, int meldCount)
    {
        return meldCount <= 0 && _shanten.CalcSevenPairsShanten(hand18) <= 0;
    }

    private static bool IsEdgeHeavyPair(int tileType)
    {
        var rank = tileType % 9 + 1;
        return rank is 1 or 2 or 8 or 9;
    }

    private static double EstimateWallPosterior(IReadOnlyList<int> improvingTiles, SichuanBeliefSnapshot belief)
    {
        if (improvingTiles.Count == 0) return 0.0;
        var total = 0.0;
        foreach (var tileType in improvingTiles)
            total += belief.TileWallPosterior.GetValueOrDefault(tileType, 0.0);
        return total / improvingTiles.Count;
    }

    private static double EstimateBlockPosterior(IReadOnlyList<int> improvingTiles, SichuanBeliefSnapshot belief)
    {
        if (improvingTiles.Count == 0) return 0.0;
        var total = 0.0;
        foreach (var tileType in improvingTiles)
        {
            var bestHolder = 0.0;
            foreach (var seatMap in belief.SeatTileHoldProbability.Values)
                bestHolder = Math.Max(bestHolder, seatMap.GetValueOrDefault(tileType, 0.0));
            total += bestHolder;
        }
        return total / improvingTiles.Count;
    }

    private sealed record FollowUpSummary(int Shanten, int Ukeire, int LiveUkeire, int BestDiscardTile, IReadOnlyList<int> ImprovingTiles);
}
