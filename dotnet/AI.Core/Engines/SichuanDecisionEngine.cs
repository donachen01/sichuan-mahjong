using System.Diagnostics;
using SichuanMahjong.AI.Core.Cache;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Decision;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanDecisionEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanCallQualityEngine _quality = new();
    private readonly SichuanBeliefEngine _belief = new();
    private readonly SichuanDangerEngine _danger = new();
    private readonly SichuanMctsEngine _search = new();
    private readonly SichuanExpectedScoreEngine _expectedScore = new();
    private readonly SichuanSelfDrawProbabilityEngine _selfDraw = new();
    private readonly SichuanHandShapeEngine _shape = new();
    private readonly SichuanWaitShapeEngine _waitShape = new();
    private readonly SichuanLimitedLookaheadEngine _limitedLookahead = new();
    private readonly SichuanRoutePlanEngine _routePlan = new();
    private readonly SichuanAiContextCache _contextCache = new();
    private readonly SichuanDealInPolicyEvaluator _dealInPolicy = new();
	private readonly SichuanQingYiSePlanner _qingYiSePlanner = new();
	private readonly SichuanRouteValueEvaluator _routeValueEvaluator = new();
	private readonly SichuanUnifiedDecisionEngine _unified = new();

    private sealed record SichuanBigHandRouteAdjustment(double Score, IReadOnlyList<string> Reasons)
    {
        public static readonly SichuanBigHandRouteAdjustment Empty = new(0.0, Array.Empty<string>());
    }

    private sealed record SichuanSimpleAdjustment(double Score, IReadOnlyList<string> Reasons)
    {
        public static readonly SichuanSimpleAdjustment Empty = new(0.0, Array.Empty<string>());
    }

    private sealed record SichuanSetPreservationAdjustment(
        double Score,
        bool BreaksPair,
        bool BreaksTriplet,
        IReadOnlyList<string> Reasons)
    {
        public static readonly SichuanSetPreservationAdjustment Empty = new(0.0, false, false, Array.Empty<string>());
    }

    public SichuanDecisionResult DecideDiscard(
        SichuanStateView state,
        bool forceLightweight = false,
        SichuanRoundBrainSnapshot? roundBrain = null)
    {
        var decisionStopwatch = Stopwatch.StartNew();
        var belief = _belief.Build(state);
        var aiContext = _contextCache.GetOrUpdate(state, belief);
        var roundStage = aiContext.Stage.StageIndex;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var maxReadyPosterior = belief.SeatReadyPosterior.Values.DefaultIfEmpty(0.0).Max();
        var currentShanten = _shanten.CalcBestShanten(state.Hand18, meldCount);
        var currentRoutes = EstimateRoutes(state.Hand18, state);
        roundBrain ??= new SichuanRoundBrainSnapshot
        {
            RoundIndex = state.RoundIndex,
            SeatIndex = state.SeatIndex,
            PrimaryRoute = _routePlan.Evaluate(state).PrimaryRoute
        };
        var routePlan = _routePlan.Evaluate(state, roundBrain);
		var routeValues = _routeValueEvaluator.Evaluate(state);
		var qingRouteValue = routeValues.FirstOrDefault(item => item.Route == "清一色");
		var shouldPlanQing = SichuanRoutePlanEngine.IsFlushRoute(roundBrain.PrimaryRoute)
			|| SichuanRoutePlanEngine.IsFlushRoute(routePlan.PrimaryRoute)
			|| qingRouteValue is { CompletionProbability: >= 0.42 };
		var qingPlans = shouldPlanQing
			? _qingYiSePlanner.Evaluate(state, roundBrain.TargetSuit >= 0 ? roundBrain.TargetSuit : routePlan.TargetSuit).ToDictionary(item => item.DiscardTileType)
			: new Dictionary<int, SichuanQingPlanCandidate>();
		var unifiedDiscardValues = forceLightweight
			? new Dictionary<int, double>()
			: _unified.RankDiscards(state).Candidates.ToDictionary(item => item.Action.TileType, item => item.ExpectedNetScore);
		var unifiedMean = unifiedDiscardValues.Values.DefaultIfEmpty(0).Average();
        var candidateScores = new Dictionary<int, int>();
        var candidates = new List<SichuanCandidateDetail>();
        var bestTile = -1;
        var bestScore = int.MinValue;
        var bestShanten = 8;
        var bestUkeire = 0;
        var bestLive = 0;
        var bestSearchBonus = 0.0;
        var reasons = new List<string>();
        var forcedDingQueSuit = state.OwnDingQueSuit;
        var mustClearDingQue = forcedDingQueSuit is >= 0 and < 3
            && Enumerable.Range(forcedDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0);
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (state.Hand18[tileType] <= 0) continue;
            if (mustClearDingQue && tileType / 9 != forcedDingQueSuit) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(state.Hand18, tileType, meldCount);
            var (ukeire, liveUkeire, improvingTiles) = _ukeire.CalcUkeire(state.Hand18, state.Remaining18, tileType, meldCount);
            var remainingHand = RemoveOne(state.Hand18, tileType);
            var exactReadyTiles = GetExactReadyTiles(remainingHand, meldCount);
            var effectiveUkeire = exactReadyTiles.Count > 0 ? exactReadyTiles.Count : ukeire;
            var effectiveShanten = exactReadyTiles.Count > 0 ? 0 : shanten;
            var effectiveLiveUkeire = exactReadyTiles.Count > 0 ? exactReadyTiles.Sum(item => Math.Max(0, state.Remaining18[item])) : liveUkeire;
            var effectiveImprovingTiles = exactReadyTiles.Count > 0 ? exactReadyTiles : improvingTiles;
            var waitCount = exactReadyTiles.Count > 0 ? exactReadyTiles.Count : (effectiveShanten <= 0 ? improvingTiles.Count : 0);
            var routesAfter = EstimateRoutes(remainingHand, state);
            var routePlanAfter = _routePlan.Evaluate(state, remainingHand, meldCount, roundBrain);
            var routeLoss = currentRoutes.Where(route => !routesAfter.Contains(route)).ToArray();
            var bigHandRoute = EvaluateBigHandRouteAdjustment(state.Hand18, remainingHand, state, tileType, meldCount, roundStage, currentShanten, effectiveShanten, effectiveLiveUkeire, waitCount);
            var routePlanAdjustment = EvaluateRoutePlanAdjustment(routePlan, routePlanAfter, state.Hand18, remainingHand, tileType, effectiveShanten, waitCount, roundStage);
			var qingPlanAdjustment = BuildQingPlanAdjustment(tileType, routePlan, qingPlans);
            var setPreservation = EvaluateSetPreservationAdjustment(state.Hand18, remainingHand, tileType, roundStage);
            var orphanTerminal = EvaluateOrphanTerminalDiscardAdjustment(state.Hand18, tileType, roundStage);
            var connectedRun = EvaluateConnectedRunPreservationAdjustment(state.Hand18, tileType, roundStage);
            var endgamePairWait = EvaluateEndgamePairWaitAdjustment(state.Hand18, tileType, state.WallCount, meldCount);
            var qualityScore = _quality.EvaluateScore(effectiveImprovingTiles, state.Remaining18);
            var shapeSummary = _shape.Evaluate(remainingHand, state.Remaining18, meldCount, effectiveShanten);
            var waitShapeSummary = _waitShape.Evaluate(remainingHand, waitCount > 0 ? effectiveImprovingTiles : Array.Empty<int>());
            var readyCentralPreservation = EvaluateReadyCentralPreservationAdjustment(
                state.Hand18,
                tileType,
                effectiveShanten,
                waitCount,
                effectiveLiveUkeire,
                roundStage);
            var limitedLookahead = _limitedLookahead.Evaluate(
                remainingHand,
                state.Remaining18,
                meldCount,
                effectiveShanten,
                effectiveLiveUkeire,
                0);
            var dangerEval = _danger.EvaluateDetail(tileType, state, belief);
            var danger = dangerEval.Risk;
            var fastTingPriority = EvaluateFastTingPriorityAdjustment(currentShanten, effectiveShanten, effectiveLiveUkeire, waitCount, roundStage, danger);
            var wallDrawPosterior = EstimateWallDrawPosterior(effectiveImprovingTiles, belief);
            var tenpaiProbability = EstimateTenpaiProbability(effectiveShanten, effectiveLiveUkeire);
            var selfDrawProbability = _selfDraw.Estimate(state, effectiveImprovingTiles, waitCount, effectiveLiveUkeire, effectiveShanten, danger, belief);
            var dealInProbability = SichuanRiskCalibration.ToDealInProbability(danger, roundStage, maxReadyPosterior);
            var winProbability = Math.Clamp(tenpaiProbability * 0.58 + selfDrawProbability * 0.42, 0.01, 0.95);
            var expectedFan = EstimateExpectedFan(routesAfter, qingPlans.GetValueOrDefault(tileType), waitCount);
            var posteriorAdjustment = EstimatePosteriorDefensePenalty(effectiveShanten, effectiveLiveUkeire, dealInProbability, maxReadyPosterior, wallDrawPosterior, state.WallCount, roundStage);
            var expectedScore = _expectedScore.EvaluateDiscardCandidate(
                state,
                remainingHand,
                effectiveShanten,
                effectiveLiveUkeire,
                waitCount,
                qualityScore,
                tenpaiProbability,
                selfDrawProbability,
                winProbability,
                dealInProbability,
                dangerEval.TopThreatScore,
                maxReadyPosterior,
                wallDrawPosterior,
                roundStage,
                routesAfter);
            var strategicAdjustment = EvaluateStrategyContextAdjustment(
                aiContext,
                tileType,
                effectiveShanten,
                waitCount,
                effectiveLiveUkeire,
                danger,
                expectedScore,
                routesAfter.Count);
            var dealInPolicy = _dealInPolicy.Evaluate(tileType, aiContext);
            var roundBrainAdjustment = EvaluateRoundBrainAdjustment(
                roundBrain,
                state.Hand18,
                remainingHand,
                tileType,
                effectiveShanten,
                waitCount,
                danger,
                roundStage);
            var shapeValue = EstimateShapeValue(effectiveShanten, effectiveUkeire, effectiveLiveUkeire, waitCount, qualityScore, wallDrawPosterior, roundStage, routesAfter.Count, routeLoss.Length)
                + shapeSummary.ShapeScore
                + waitShapeSummary.WaitShapeScore
                + limitedLookahead.Score
                + fastTingPriority.Score
                + routePlanAdjustment.Score
				+ qingPlanAdjustment.Score
                + bigHandRoute.Score
                + orphanTerminal.Score
                + connectedRun.Score
                + endgamePairWait.Score
                + readyCentralPreservation.Score
                + setPreservation.Score
                + strategicAdjustment.Score
                + roundBrainAdjustment.Score
                + dealInPolicy.AdjustmentScore / 100.0;
            var defenseAdjustment = posteriorAdjustment * ResolveDefenseAdjustmentWeight(effectiveShanten, waitCount, roundStage, maxReadyPosterior);
            var unifiedAdjustment = unifiedDiscardValues.TryGetValue(tileType, out var unifiedValue)
				? Math.Clamp((unifiedValue - unifiedMean) * 0.12, -0.65, 0.65)
				: 0;
			var expectedValue = expectedScore.Net + shapeValue - defenseAdjustment + unifiedAdjustment;
            var score = (int)Math.Round(expectedValue * 100.0);
            var fastTingDiscardRank = ResolveFastRank(effectiveShanten, waitCount, effectiveLiveUkeire);
            var riskLabel = dangerEval.RiskLabel;
            var strategyTag = ResolveStrategyTag(effectiveShanten, effectiveLiveUkeire, danger, roundStage);
            var strategyMode = aiContext.StrategyMode.Mode;
            var explanationHint = BuildExplanationHint(effectiveShanten, effectiveUkeire, effectiveLiveUkeire, waitCount, danger, strategyMode, riskLabel);
            var posteriorReasons = BuildPosteriorReasons(effectiveShanten, effectiveLiveUkeire, dealInProbability, maxReadyPosterior, wallDrawPosterior, state.WallCount, roundStage, posteriorAdjustment);
            var riskReasons = BuildRiskReasons(danger, riskLabel, state.WallCount, roundStage, effectiveLiveUkeire, dangerEval);
            var candidateReasons = BuildReasons(effectiveShanten, effectiveLiveUkeire, danger, riskLabel, strategyTag, waitCount, roundStage, posteriorReasons, expectedScore);
            var mergedReasons = candidateReasons
                .Concat(waitCount > 0 ? waitShapeSummary.Reasons : Array.Empty<string>())
                .Concat(shapeSummary.Reasons)
                .Concat(limitedLookahead.Reasons)
                .Concat(fastTingPriority.Reasons)
                .Concat(routePlanAdjustment.Reasons)
				.Concat(qingPlanAdjustment.Reasons)
                .Concat(bigHandRoute.Reasons)
                .Concat(orphanTerminal.Reasons)
                .Concat(connectedRun.Reasons)
                .Concat(endgamePairWait.Reasons)
                .Concat(readyCentralPreservation.Reasons)
                .Concat(setPreservation.Reasons)
                .Concat(strategicAdjustment.Reasons)
                .Concat(roundBrainAdjustment.Reasons)
				.Concat(unifiedDiscardValues.ContainsKey(tileType) ? new[] { $"统一净分层修正 {unifiedAdjustment:F2}" } : Array.Empty<string>())
                .Concat(new[] { dealInPolicy.ReasonCode })
                .ToArray();
            candidateScores[tileType] = score;
            candidates.Add(new SichuanCandidateDetail
            {
                TileType = tileType,
                FastTingDiscardRank = fastTingDiscardRank,
                Score = score,
                Shanten = effectiveShanten,
                Ukeire = effectiveUkeire,
                LiveUkeire = effectiveLiveUkeire,
                Danger = danger,
                WaitCount = waitCount,
                WaitQualityScore = qualityScore,
                ImprovingTiles = effectiveImprovingTiles.ToArray(),
                RiskLabel = riskLabel,
                StrategyTag = strategyTag,
                StrategyMode = strategyMode,
                ExplanationHint = explanationHint,
                RoutePlanPrimary = routePlanAfter.PrimaryRoute,
                RoutePlanScore = (int)Math.Round(routePlanAdjustment.Score * 100.0),
                RoutesAfter = routesAfter,
                RouteLoss = routeLoss,
                TenpaiProbability = tenpaiProbability,
                SelfDrawProbability = selfDrawProbability,
                WinProbability = winProbability,
                ExpectedFan = expectedFan,
                DealInProbability = dealInProbability,
                ExpectedValue = expectedValue,
                ExpectedNetScore = expectedScore.Net,
                ExpectedWinGain = expectedScore.WinGain,
                ExpectedDealInLoss = expectedScore.DealInLoss,
                ExpectedDrawRiskLoss = expectedScore.DrawRiskLoss,
                ExpectedReadyValue = expectedScore.ReadyValue,
                PosteriorAdjustment = posteriorAdjustment,
                DefenseAdjustment = defenseAdjustment,
                GoodShapeCount = shapeSummary.GoodShapeCount,
                BadShapeCount = shapeSummary.BadShapeCount,
                PairPressure = shapeSummary.PairPressure,
                TaatsuOverflow = shapeSummary.TaatsuOverflow,
                SameShantenImprovementCount = shapeSummary.SameShantenImprovementCount,
                MiddleTileFlexibility = shapeSummary.MiddleTileFlexibility,
                ShapeScore = shapeSummary.ShapeScore,
                BreaksPair = setPreservation.BreaksPair,
                BreaksTriplet = setPreservation.BreaksTriplet,
                SetPreservationScore = setPreservation.Score,
                WaitShapeLabel = waitShapeSummary.Label,
                WaitShapeScore = waitShapeSummary.WaitShapeScore,
                RyanmenWaitCount = waitShapeSummary.RyanmenCount,
                KanchanWaitCount = waitShapeSummary.KanchanCount,
                PenchanWaitCount = waitShapeSummary.PenchanCount,
                TankiWaitCount = waitShapeSummary.TankiCount,
                ShanponWaitCount = waitShapeSummary.ShanponCount,
                LimitedLookaheadScore = limitedLookahead.Score,
                LimitedLookaheadSamples = limitedLookahead.SampledDrawCount,
                LimitedLookaheadBestShanten = limitedLookahead.BestNextShanten,
                LimitedLookaheadBestLiveUkeire = limitedLookahead.BestNextLiveUkeire,
                SearchBonus = 0.0,
                SearchSimulations = 0,
                SearchUsed = false,
                PosteriorReasons = posteriorReasons,
                RiskReasons = riskReasons,
                Reasons = mergedReasons
            });
            var challenger = candidates[^1];
            var incumbent = bestTile >= 0 ? candidates.FirstOrDefault(item => item.TileType == bestTile) : null;
            if (IsBetterDiscardCandidate(challenger, incumbent, roundStage, aiContext))
            {
                bestTile = tileType;
                bestScore = score;
                bestShanten = effectiveShanten;
                bestUkeire = effectiveUkeire;
                bestLive = effectiveLiveUkeire;
                bestSearchBonus = 0.0;
                reasons = candidateReasons.ToList();
            }
        }

        candidates = SortDiscardCandidates(candidates, roundStage, aiContext);
        if (candidates.Count > 0)
        {
            var sortedBestCandidate = candidates[0];
            bestTile = sortedBestCandidate.TileType;
            bestScore = sortedBestCandidate.Score;
            bestShanten = sortedBestCandidate.Shanten;
            bestUkeire = sortedBestCandidate.Ukeire;
            bestLive = sortedBestCandidate.LiveUkeire;
            bestSearchBonus = sortedBestCandidate.SearchBonus;
            reasons = sortedBestCandidate.Reasons.ToList();
        }

        var useSearch = !forceLightweight && candidates.Count <= 8 && aiContext.Stage.StageIndex <= 1;
        var searchResult = useSearch
            ? _search.EvaluateTopCandidates(state, candidates, timeoutMs: 45, topK: 2, rolloutDepth: 1)
            : new SichuanSearchResult { Used = false };
        if (searchResult.Used)
        {
            candidates = ApplySearchBonuses(candidates, searchResult, roundStage, aiContext);
            candidateScores = candidates.ToDictionary(item => item.TileType, item => item.Score);
            var bestCandidate = candidates[0];
            bestTile = bestCandidate.TileType;
            bestScore = bestCandidate.Score;
            bestShanten = bestCandidate.Shanten;
            bestUkeire = bestCandidate.Ukeire;
            bestLive = bestCandidate.LiveUkeire;
            bestSearchBonus = bestCandidate.SearchBonus;
            reasons = bestCandidate.Reasons
                .Concat(new[] { $"限时搜索 {searchResult.Simulations} 次" })
                .ToList();
        }

        var extremeDangerOverride = SelectExtremeDangerSameSpeedOverride(candidates, bestTile, state);
        if (extremeDangerOverride is not null)
        {
            bestTile = extremeDangerOverride.TileType;
            bestScore = extremeDangerOverride.Score;
            bestShanten = extremeDangerOverride.Shanten;
            bestUkeire = extremeDangerOverride.Ukeire;
            bestLive = extremeDangerOverride.LiveUkeire;
            bestSearchBonus = extremeDangerOverride.SearchBonus;
            reasons = extremeDangerOverride.Reasons
				.Concat(new[] { "同速避险：对成叫压力下避开更危险生张" })
                .ToList();
        }

        var lateWallDefense = SelectLateWallDefenseOverride(candidates, bestTile, state, maxReadyPosterior);
        if (lateWallDefense is not null)
        {
            bestTile = lateWallDefense.TileType;
            bestScore = lateWallDefense.Score;
            bestShanten = lateWallDefense.Shanten;
            bestUkeire = lateWallDefense.Ukeire;
            bestLive = lateWallDefense.LiveUkeire;
            bestSearchBonus = lateWallDefense.SearchBonus;
            reasons = lateWallDefense.Reasons
                .Concat(new[] { "尾盘硬防守：牌墙极少时优先避开证据不牢的抢听风险" })
                .ToList();
        }

        var lateWallKeepReady = SelectLateWallKeepReadyOverride(candidates, bestTile, state);
        if (lateWallKeepReady is not null)
        {
            bestTile = lateWallKeepReady.TileType;
            bestScore = lateWallKeepReady.Score;
            bestShanten = lateWallKeepReady.Shanten;
            bestUkeire = lateWallKeepReady.Ukeire;
            bestLive = lateWallKeepReady.LiveUkeire;
            bestSearchBonus = lateWallKeepReady.SearchBonus;
            reasons = lateWallKeepReady.Reasons
                .Concat(new[] { "尾盘守叫：存在安全听牌时，查叫资格硬优先于普通综合分" })
                .ToList();
        }

        var bestCandidateSnapshot = candidates.FirstOrDefault(item => item.TileType == bestTile);
        var finalDanger = bestTile >= 0 ? _danger.EvaluateDetail(bestTile, state, belief) : new SichuanDangerEvaluation { Risk = 0, RiskLabel = "低危" };
        var finalDealInProbability = SichuanRiskCalibration.ToDealInProbability(finalDanger.Risk, roundStage, maxReadyPosterior);
        var finalTenpaiProbability = EstimateTenpaiProbability(bestShanten, bestLive);
        var finalSelfDrawProbability = bestCandidateSnapshot?.SelfDrawProbability ?? 0.01;
        var finalWinProbability = Math.Clamp(finalTenpaiProbability * 0.58 + finalSelfDrawProbability * 0.42, 0.01, 0.95);
        var beliefSummary = BuildBeliefSummary(state, belief, bestTile, bestCandidateSnapshot);
        decisionStopwatch.Stop();
        var performance = BuildPerformanceReport(decisionStopwatch.Elapsed.TotalMilliseconds, aiContext.ModulePerf);
        var explain = BuildExplain(bestTile, bestScore, aiContext, reasons);
        var finalReasons = reasons
            .Concat(aiContext.ReasonCodes)
            .Distinct()
            .Take(12)
            .ToArray();

        return new SichuanDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Discard, bestTile, bestScore, finalReasons.FirstOrDefault() ?? string.Empty),
            Shanten = bestShanten,
            Ukeire = bestUkeire,
            LiveUkeire = bestLive,
            WinProbability = finalWinProbability,
            DealInProbability = finalDealInProbability,
            SearchUsed = searchResult.Used,
            SearchSimulations = searchResult.Simulations,
            BeliefSummary = beliefSummary,
            AiContext = aiContext,
            Explain = explain,
            Performance = performance,
            Reasons = finalReasons,
            CandidateScores = candidateScores,
            Candidates = candidates,
            RoutePlan = routePlan,
            RoundBrain = roundBrain
        };
    }

    private static SichuanSimpleAdjustment EvaluateRoundBrainAdjustment(
        SichuanRoundBrainSnapshot brain,
        IReadOnlyList<int> currentHand,
        IReadOnlyList<int> remainingHand,
        int tileType,
        int shanten,
        int waitCount,
        int danger,
        int roundStage)
    {
        var score = 0.0;
        var reasons = new List<string>();
        if (brain.IsProtectedQuad(tileType) && currentHand[tileType] >= 4)
        {
            score -= roundStage <= 1 ? 18.0 : 10.0;
            reasons.Add("持续大脑：四张同牌是杠分和补张资产，禁止按普通孤张拆除");
        }
        else if (brain.IsProtectedTriplet(tileType) && currentHand[tileType] >= 3 && remainingHand[tileType] == 2)
        {
            var canBreakForSafeReady = roundStage >= 2 && shanten <= 0 && waitCount > 0 && danger < 70;
            score -= canBreakForSafeReady ? 2.0 : 10.0 + brain.Commitment / 12.0;
            reasons.Add(canBreakForSafeReady
                ? "持续大脑：尾盘安全成叫允许有条件拆刻"
                : "持续大脑：保护暗刻及第四张杠牌机会");
        }

        if (SichuanRoutePlanEngine.IsFlushRoute(brain.PrimaryRoute) && brain.TargetSuit is >= 0 and < 3)
        {
            if (tileType / 9 == brain.TargetSuit)
            {
                score -= 4.0 + brain.Commitment / 10.0;
                reasons.Add("持续大脑：主路线清色，拆目标花色需要显著收益");
            }
            else
            {
                score += 2.0 + brain.Commitment / 18.0;
                reasons.Add("持续大脑：清理清色路线异门牌");
            }
        }

        if (SichuanRoutePlanEngine.IsSevenPairsRoute(brain.PrimaryRoute) && currentHand[tileType] >= 2)
        {
            score -= 7.0 + brain.Commitment / 14.0;
            reasons.Add("持续大脑：七对主路线保护对子");
        }
        return new SichuanSimpleAdjustment(score, reasons);
    }

    private static SichuanSimpleAdjustment EvaluateStrategyContextAdjustment(
        SichuanAiContext context,
        int tileType,
        int shanten,
        int waitCount,
        int liveUkeire,
        int danger,
        SichuanExpectedScore expectedScore,
        int routeCount)
    {
        var score = 0.0;
        var reasons = new List<string>();
        var mode = context.StrategyMode.Mode;
        var tileDanger = context.TileDangerMap.TryGetValue(tileType, out var dangerProfile)
            ? dangerProfile.MaxDangerScore
            : danger;

        switch (mode)
        {
            case "attack":
                if (shanten <= 1)
                {
                    score += 1.8 + Math.Min(1.4, liveUkeire * 0.08);
                    reasons.Add("MODE_ATTACK_FAST_HAND_ADVANCE");
                }
                if (tileDanger >= 78)
                {
                    score -= 2.2;
                    reasons.Add("MODE_ATTACK_STILL_AVOIDS_EXTREME_RISK");
                }
                break;
            case "balanced":
                score += routeCount >= 2 ? 0.6 : 0.0;
                if (tileDanger >= 70) score -= 1.4;
                reasons.Add("MODE_BALANCED_ADVANCE_RISK_MIX");
                break;
            case "defense":
                score -= tileDanger * 0.035;
                if (shanten <= 0 && waitCount >= 2)
                    score += 0.9;
                reasons.Add("MODE_DEFENSE_SAFE_TILE_PRIORITY");
                break;
            case "fold":
                score -= tileDanger * 0.060;
                if (tileDanger <= 25)
                    score += 2.4;
                reasons.Add("MODE_FOLD_STOP_LOSS_SAFE_FIRST");
                break;
            case "chase":
                score += expectedScore.WinGain * 0.16 + context.HandAnalysis.BigHandPotential * 0.012;
                if (tileDanger >= 86)
                    score -= 3.4;
                reasons.Add("MODE_CHASE_REWARD_WEIGHT_UP");
                break;
        }

        if (context.RoundGoal.Goal == "protect_lead" && tileDanger >= 58)
        {
            score -= 1.2;
            reasons.Add("ROUND_GOAL_PROTECT_LEAD_RISK_DOWN");
        }
        if (context.RiskTolerance.Value >= 65 && tileDanger <= 55)
        {
            score += 0.55;
            reasons.Add("RISK_TOLERANCE_HIGH_ALLOW_PROGRESS");
        }
        return Math.Abs(score) < 0.001
            ? SichuanSimpleAdjustment.Empty
            : new SichuanSimpleAdjustment(score, reasons);
    }

    private static SichuanDecisionPerformanceReport BuildPerformanceReport(
        double totalMs,
        IReadOnlyList<SichuanModulePerfSample> modulePerf)
    {
        var warnings = modulePerf
            .Where(item => item.Warning)
            .Select(item => $"PERF_{item.Module.ToUpperInvariant()}_OVER_BUDGET")
            .ToList();
        if (totalMs >= 100.0)
            warnings.Add("PERF_CHOOSE_ACTION_P95_BUDGET_WARNING");
        return new SichuanDecisionPerformanceReport
        {
            TotalMs = Math.Round(totalMs, 3),
            MaxModuleMs = modulePerf.Select(item => item.ElapsedMs).DefaultIfEmpty(0.0).Max(),
            Warning = warnings.Count > 0,
            WarningCodes = warnings,
            Modules = modulePerf
        };
    }

    private static SichuanDecisionExplain BuildExplain(
        int tileType,
        int score,
        SichuanAiContext context,
        IReadOnlyList<string> reasons)
        => new()
        {
            Mode = "normal",
            Action = "discard",
            TileType = tileType,
            Score = score,
            StrategyMode = context.StrategyMode.Mode,
            ReasonCodes = context.ReasonCodes
                .Concat(reasons.Where(item => item.All(ch => char.IsUpper(ch) || ch == '_' || char.IsDigit(ch))).Take(4))
                .Distinct()
                .Take(10)
                .ToArray()
        };

    private static List<int> GetExactReadyTiles(int[] hand18, int meldCount)
    {
        var results = new List<int>();
        var expectedConcealed = ((4 - meldCount) * 3) + 1;
        if (meldCount < 0 || meldCount > 4 || hand18.Sum() != expectedConcealed)
            return results;
        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            if (hand18[tileType] >= 4) continue;
            var probe = (int[])hand18.Clone();
            probe[tileType]++;
            if (CanHu(probe, meldCount))
                results.Add(tileType);
        }
        return results;
    }

    private static bool CanHu(int[] hand18, int meldCount)
    {
        var requiredConcealed = ((4 - meldCount) * 3) + 2;
        if (meldCount < 0 || meldCount > 4 || hand18.Sum() != requiredConcealed)
            return false;
        if (meldCount == 0 && IsQiDui(hand18))
            return true;
        for (var tileType = 0; tileType < hand18.Length; tileType++)
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

    private static bool CanClearSuit(int[] hand18, int startIndex)
    {
        var suit = new int[9];
        Array.Copy(hand18, startIndex, suit, 0, 9);
        return CanClearSuitRecursive(suit, 0);
    }

    private static bool CanClearSuitRecursive(int[] counts, int startRank)
    {
        var rank = startRank;
        while (rank < 9 && counts[rank] == 0)
            rank++;
        if (rank >= 9)
            return true;

        if (counts[rank] >= 3)
        {
            var triplet = (int[])counts.Clone();
            triplet[rank] -= 3;
            if (CanClearSuitRecursive(triplet, rank))
                return true;
        }

        if (rank <= 6 && counts[rank + 1] > 0 && counts[rank + 2] > 0)
        {
            var sequence = (int[])counts.Clone();
            sequence[rank]--;
            sequence[rank + 1]--;
            sequence[rank + 2]--;
            if (CanClearSuitRecursive(sequence, rank))
                return true;
        }

        return false;
    }

    private static int[] RemoveOne(int[] hand18, int tileType)
    {
        var clone = (int[])hand18.Clone();
        if (tileType is >= 0 and < 27 && clone[tileType] > 0)
            clone[tileType]--;
        return clone;
    }

    private static IReadOnlyList<string> EstimateRoutes(int[] hand18, SichuanStateView state)
    {
        var routes = new List<string>();
        var counts = new Dictionary<int, int>();
        var pairCount = 0;
        var tripleLike = 0;
        var suitCounts = new Dictionary<int, int>();
        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            var count = hand18[tileType];
            if (count <= 0) continue;
            counts[tileType] = count;
            var suitIndex = tileType / 9;
            suitCounts[suitIndex] = suitCounts.GetValueOrDefault(suitIndex, 0) + count;
            if (count >= 2) pairCount++;
            if (count >= 3) tripleLike++;
        }
        var meldGroupCount = state.Melds18[state.SeatIndex].Count / 3;
        foreach (var meldTile in state.Melds18[state.SeatIndex])
        {
            var suitIndex = meldTile / 9;
            suitCounts[suitIndex] = suitCounts.GetValueOrDefault(suitIndex, 0) + 1;
        }
        if (counts.Count <= 7 && meldGroupCount == 0 && pairCount >= 4)
            routes.Add("七对");
        var pairRoutePotential = pairCount + meldGroupCount;
        var earlyPairRoute = state.WallCount >= 8
            && meldGroupCount >= 1
            && pairRoutePotential >= 5;
        if (tripleLike + meldGroupCount >= 3 || earlyPairRoute)
            routes.Add("对对胡");
        var totalTiles = hand18.Sum() + state.Melds18[state.SeatIndex].Count;
        var maxSuitCount = suitCounts.Count > 0 ? suitCounts.Values.Max() : 0;
        var offSuitCount = Math.Max(0, totalTiles - maxSuitCount);
        if (suitCounts.Count == 1 && suitCounts.Count > 0 && totalTiles >= 11 && state.WallCount >= 8)
            routes.Add("清一色");
        else if (state.WallCount >= 8 && totalTiles >= 11 && maxSuitCount >= 10 && offSuitCount <= 3)
            routes.Add("清一色");
        return routes;
    }

    private static bool IsBetterDiscardCandidate(
        SichuanCandidateDetail challenger,
        SichuanCandidateDetail? incumbent,
        int roundStage,
        SichuanAiContext? context = null)
    {
        if (incumbent is null)
            return true;
        var mode = context?.StrategyMode.Mode ?? "balanced";
        var roundGoal = context?.RoundGoal.Goal ?? "";
        var chase = mode == "chase" || roundGoal == "chase_score";
        var defensive = mode is "defense" or "fold" || roundGoal == "protect_lead";
        var scoreGap = challenger.Score - incumbent.Score;
        var dangerGap = challenger.Danger - incumbent.Danger;

        if (defensive && dangerGap <= -22 && scoreGap >= -650)
            return true;
        if (defensive && dangerGap >= 24 && scoreGap < 900)
            return false;

        var challengerRank = StrategicShantenRank(challenger, roundStage);
        var incumbentRank = StrategicShantenRank(incumbent, roundStage);
        if (challengerRank != incumbentRank)
        {
            if (chase && challengerRank > incumbentRank && scoreGap >= 520 && challenger.Danger <= 82)
                return true;
            if (chase && challengerRank < incumbentRank && scoreGap <= -780 && incumbent.Danger <= 82)
                return false;
            return challengerRank < incumbentRank;
        }
        if (challenger.Shanten != incumbent.Shanten && Math.Abs(challenger.Score - incumbent.Score) < 900)
            return challenger.Shanten < incumbent.Shanten;
        return challenger.Score > incumbent.Score;
    }

    private static List<SichuanCandidateDetail> SortDiscardCandidates(
        IReadOnlyList<SichuanCandidateDetail> candidates,
        int roundStage,
        SichuanAiContext? context)
    {
        var mode = context?.StrategyMode.Mode ?? "balanced";
        var roundGoal = context?.RoundGoal.Goal ?? "";
        var protectiveLeadActive = roundGoal == "protect_lead" && roundStage >= 2;
        var rankRoundGoal = protectiveLeadActive ? roundGoal : roundGoal == "protect_lead" ? "" : roundGoal;
        var wallCount = context?.Stage.WallCount ?? 99;
        if (mode == "fold")
        {
            return candidates
                .OrderBy(item => FoldCandidateTierRank(item, roundStage, wallCount))
                .ThenBy(item => item.Danger >= 82 ? 1 : 0)
                .ThenByDescending(item => item.Score)
                .ThenBy(item => item.Danger)
                .ThenBy(item => StrategicShantenRank(item, roundStage))
                .ThenByDescending(item => item.LiveUkeire)
                .ToList();
        }

        if (mode == "defense" || protectiveLeadActive)
        {
            return candidates
                .OrderBy(item => CandidateTierRank(item, mode, rankRoundGoal, roundStage))
                .ThenBy(item => item.Danger >= 72 ? 1 : 0)
                .ThenByDescending(item => item.Score)
                .ThenBy(item => item.Danger)
                .ThenBy(item => StrategicShantenRank(item, roundStage))
                .ThenByDescending(item => item.LiveUkeire)
                .ThenByDescending(item => item.WaitQualityScore)
                .ToList();
        }

        if (mode == "chase" || roundGoal == "chase_score")
        {
            return candidates
                .OrderBy(item => item.Danger >= 86 ? 1 : 0)
                .ThenBy(item => CandidateTierRank(item, mode, rankRoundGoal, roundStage))
                .ThenByDescending(item => item.Score)
                .ThenByDescending(item => item.ExpectedNetScore)
                .ThenByDescending(item => BigRouteCount(item))
                .ThenBy(item => StrategicShantenRank(item, roundStage))
                .ThenBy(item => item.FastTingDiscardRank)
                .ThenByDescending(item => item.WaitCount)
                .ThenByDescending(item => item.LiveUkeire)
                .ThenBy(item => item.Danger)
                .ToList();
        }

        return candidates
            .OrderBy(item => CandidateTierRank(item, mode, rankRoundGoal, roundStage))
            .ThenByDescending(item => item.Score)
            .ThenBy(item => StrategicShantenRank(item, roundStage))
            .ThenBy(item => item.FastTingDiscardRank)
            .ThenByDescending(item => item.WaitCount)
            .ThenByDescending(item => item.LiveUkeire)
            .ThenBy(item => item.Danger)
            .ThenByDescending(item => item.WaitQualityScore)
            .ToList();
    }

    private static int FoldCandidateTierRank(SichuanCandidateDetail candidate, int roundStage, int wallCount)
    {
        if (candidate.Danger >= 86)
            return 90;
        if (KeepsReadyWithAcceptableRisk(candidate))
            return 0;
        if (wallCount <= 2 && candidate.Shanten <= 0 && candidate.WaitCount > 0 && candidate.Danger < 82)
            return 0;
        if (candidate.Danger <= 12)
            return 4;
        if (candidate.Danger <= 25)
            return 8;
        if (candidate.Danger <= 42)
            return 16;
        if (candidate.Shanten <= 1 && candidate.LiveUkeire >= 4)
            return roundStage >= 2 ? 40 : 36;
        return 48;
    }

    private static int BigRouteCount(SichuanCandidateDetail candidate)
        => candidate.RoutesAfter.Count(route => route is "七对" or "对对胡" or "清一色");

    private static bool KeepsReadyWithAcceptableRisk(SichuanCandidateDetail candidate)
        => candidate.Shanten <= 0 && candidate.WaitCount > 0 && candidate.Danger < 78;

    private static int CandidateTierRank(
        SichuanCandidateDetail candidate,
        string mode,
        string roundGoal,
        int roundStage)
    {
        if (candidate.Danger >= 86)
            return 90;

        if (mode is "fold" or "defense" || roundGoal == "protect_lead")
        {
            if (KeepsReadyWithAcceptableRisk(candidate))
                return 0;
            if (candidate.Danger <= 25)
                return 8;
            if (candidate.Danger <= 42)
                return 16;
            if (candidate.Shanten <= 1 && candidate.LiveUkeire >= 4)
                return 28;
            return 42;
        }

        if (mode == "chase" || roundGoal == "chase_score")
        {
            if (candidate.Shanten <= 0 && candidate.WaitCount > 0)
                return 0;
            if (BigRouteCount(candidate) > 0 && candidate.Shanten <= 1)
                return 0;
            if (candidate.Shanten <= 1 && candidate.LiveUkeire >= 5)
                return 12;
            if (candidate.Shanten <= 2 && candidate.LiveUkeire >= 10 && roundStage <= 1 && candidate.Danger < 70)
                return 12;
            if (BigRouteCount(candidate) > 0 && candidate.Shanten <= 2)
                return 18;
            return 44;
        }

        if (candidate.Shanten <= 0 && candidate.WaitCount > 0)
            return 0;
        if (candidate.Shanten <= 1 && candidate.LiveUkeire >= 4)
            return 10;
        if (candidate.Shanten <= 2 && candidate.LiveUkeire >= 10 && roundStage <= 1 && candidate.Danger < 70)
            return 10;
        if (candidate.Shanten <= 1)
            return 18;
        return 48;
    }

    private static int StrategicShantenRank(SichuanCandidateDetail candidate, int roundStage)
    {
        return candidate.Shanten;
    }

    private static SichuanSetPreservationAdjustment EvaluateSetPreservationAdjustment(
        int[] handBeforeDiscard18,
        int[] handAfterDiscard18,
        int discardTileType,
        int roundStage)
    {
        if (discardTileType is < 0 or >= 27)
            return SichuanSetPreservationAdjustment.Empty;

        var beforeCount = handBeforeDiscard18[discardTileType];
        var afterCount = handAfterDiscard18[discardTileType];
        var breaksQuadResource = beforeCount >= 4 && afterCount == 3;
        var breaksTriplet = beforeCount >= 3 && afterCount <= 2;
        var breaksPair = beforeCount >= 2 && afterCount <= 1;
        if (!breaksQuadResource && !breaksTriplet && !breaksPair)
            return SichuanSetPreservationAdjustment.Empty;

        var score = 0.0;
        var reasons = new List<string>();
        if (breaksQuadResource)
        {
            var penalty = roundStage >= 2 ? 12.0 : 18.0;
            score -= penalty;
            reasons.Add("四张同牌/根牌不轻拆，强降权");
        }
        else if (breaksTriplet)
        {
            var penalty = beforeCount >= 4 ? 18.0 : 2.4;
            if (roundStage >= 2)
                penalty *= 0.65;
            score -= penalty;
            reasons.Add(beforeCount >= 4 ? "四张同牌/根牌不轻拆，强降权" : "拆刻子/杠材，降权");
        }
        else if (breaksPair)
        {
            var penalty = roundStage <= 1 ? 0.9 : 0.45;
            score -= penalty;
            reasons.Add("拆对子，轻微降权");
        }

        return new SichuanSetPreservationAdjustment(score, breaksPair, breaksTriplet, reasons);
    }

    private static SichuanSimpleAdjustment EvaluateOrphanTerminalDiscardAdjustment(
        int[] handBeforeDiscard18,
        int discardTileType,
        int roundStage)
    {
        if (discardTileType is < 0 or >= 27 || handBeforeDiscard18[discardTileType] != 1)
            return SichuanSimpleAdjustment.Empty;

        var rank = discardTileType % 9;
        if (rank is not 0 and not 8)
            return SichuanSimpleAdjustment.Empty;

        var suitStart = discardTileType - rank;
        var adjacent = rank == 0 ? suitStart + 1 : suitStart + 7;
        var innerNeighbor = rank == 0 ? suitStart + 2 : suitStart + 6;
        if (handBeforeDiscard18[adjacent] > 0 || handBeforeDiscard18[innerNeighbor] > 0)
            return SichuanSimpleAdjustment.Empty;

        var score = roundStage <= 0 ? 44.0 : roundStage == 1 ? 24.0 : 7.0;
        return new SichuanSimpleAdjustment(score, new[] { "孤幺九单张优先处理" });
    }

    private static SichuanSimpleAdjustment EvaluateConnectedRunPreservationAdjustment(
        int[] handBeforeDiscard18,
        int discardTileType,
        int roundStage)
    {
        if (discardTileType is < 0 or >= 27 || handBeforeDiscard18[discardTileType] <= 0)
            return SichuanSimpleAdjustment.Empty;

        var rank = discardTileType % 9;
        var suitStart = discardTileType - rank;
        var hasLeft = rank > 0 && handBeforeDiscard18[discardTileType - 1] > 0;
        var hasRight = rank < 8 && handBeforeDiscard18[discardTileType + 1] > 0;
        if (!hasLeft && !hasRight)
            return SichuanSimpleAdjustment.Empty;

        var blockStart = rank;
        while (blockStart > 0 && handBeforeDiscard18[suitStart + blockStart - 1] > 0)
            blockStart--;
        var blockEnd = rank;
        while (blockEnd < 8 && handBeforeDiscard18[suitStart + blockEnd + 1] > 0)
            blockEnd++;
        var blockLength = blockEnd - blockStart + 1;
        var singleton = handBeforeDiscard18[discardTileType] == 1;
        var connectedTerminal =
            (rank == 0 && handBeforeDiscard18[suitStart + 1] > 0 && handBeforeDiscard18[suitStart + 2] > 0) ||
            (rank == 8 && handBeforeDiscard18[suitStart + 7] > 0 && handBeforeDiscard18[suitStart + 6] > 0);

        var score = 0.0;
        var reasons = new List<string>();
        if (singleton && connectedTerminal)
        {
            score -= roundStage <= 1
                ? blockLength >= 5 ? 30.0 : 18.0
                : 6.0;
            reasons.Add("边张连着顺子骨架，拆张降权");
        }
        else if (singleton && hasLeft && hasRight)
        {
            score -= roundStage <= 1 ? 12.0 : 4.0;
            reasons.Add("中张连着两边，拆张降权");
        }
        else if (singleton && blockLength >= 4)
        {
            score -= roundStage <= 1 ? 8.0 : 3.0;
            reasons.Add("连续搭子较长，拆张降权");
        }
        else if (handBeforeDiscard18[discardTileType] >= 2 && roundStage <= 1)
        {
            score -= 12.0;
            reasons.Add("对子连着搭子，前期不轻拆");
        }

        return Math.Abs(score) < 0.001
            ? SichuanSimpleAdjustment.Empty
            : new SichuanSimpleAdjustment(score, reasons);
    }

    private static SichuanSimpleAdjustment EvaluateEndgamePairWaitAdjustment(
        int[] handBeforeDiscard18,
        int discardTileType,
        int wallCount,
        int meldCount)
    {
        if (wallCount > 0 || discardTileType is < 0 or >= 27)
            return SichuanSimpleAdjustment.Empty;

        var rank = discardTileType % 9;
        var reasons = new List<string>();
        var score = 0.0;
        if (handBeforeDiscard18[discardTileType] == 1
            && rank > 0
            && rank < 8
            && handBeforeDiscard18[discardTileType - 1] >= 2
            && handBeforeDiscard18[discardTileType + 1] >= 2
            && meldCount >= 2)
        {
            score += 26.0;
            reasons.Add("海底保留双碰/大对听口");
        }

        if (handBeforeDiscard18[discardTileType] >= 2 && meldCount >= 2)
        {
            score -= 6.0;
            reasons.Add("海底拆对子降权");
        }

        return Math.Abs(score) < 0.001
            ? SichuanSimpleAdjustment.Empty
            : new SichuanSimpleAdjustment(score, reasons);
    }

    private static SichuanSimpleAdjustment EvaluateReadyCentralPreservationAdjustment(
        int[] handBeforeDiscard18,
        int discardTileType,
        int effectiveShanten,
        int waitCount,
        int effectiveLiveUkeire,
        int roundStage)
    {
        if (effectiveShanten != 0 || waitCount <= 0 || effectiveLiveUkeire <= 0 || discardTileType is < 0 or >= 27)
            return SichuanSimpleAdjustment.Empty;
        if (handBeforeDiscard18[discardTileType] != 1)
            return SichuanSimpleAdjustment.Empty;

        var rank = discardTileType % 9;
        var suitStart = discardTileType - rank;
        var hasLeft = rank > 0 && handBeforeDiscard18[discardTileType - 1] > 0;
        var hasRight = rank < 8 && handBeforeDiscard18[discardTileType + 1] > 0;
        var hasOuterLeft = rank > 1 && handBeforeDiscard18[discardTileType - 2] > 0;
        var hasOuterRight = rank < 7 && handBeforeDiscard18[discardTileType + 2] > 0;
        var isCentralRank = rank is >= 3 and <= 5;
        var isMiddleRunBone = isCentralRank && ((hasLeft && hasOuterLeft) || (hasRight && hasOuterRight) || (hasLeft && hasRight));
        if (!isMiddleRunBone)
            return SichuanSimpleAdjustment.Empty;

        var penalty = roundStage <= 1 ? 2.2 : 1.1;
        if (handBeforeDiscard18.Skip(suitStart).Take(9).Sum() >= 6)
            penalty += roundStage <= 1 ? 0.6 : 0.2;
        return new SichuanSimpleAdjustment(-penalty, new[] { "已下叫时中张顺子骨架不轻拆" });
    }

    private static SichuanSimpleAdjustment EvaluateRoutePlanAdjustment(
        SichuanRoutePlanResult currentPlan,
        SichuanRoutePlanResult afterPlan,
        int[] handBeforeDiscard18,
        int[] handAfterDiscard18,
        int discardTileType,
        int shantenAfterDiscard,
        int waitCountAfterDiscard,
        int roundStage)
    {
        if (discardTileType is < 0 or >= 27)
            return SichuanSimpleAdjustment.Empty;

        var score = 0.0;
        var reasons = new List<string>
        {
            $"路线规划：{currentPlan.PrimaryRoute}->{afterPlan.PrimaryRoute}"
        };
        var reachesReady = shantenAfterDiscard <= 0 && waitCountAfterDiscard > 0;
        var speedScale = reachesReady ? 0.20 : roundStage >= 2 ? 0.70 : 1.0;
        var breaksPair = handBeforeDiscard18[discardTileType] >= 2 && handAfterDiscard18[discardTileType] <= 1;
        var breaksTriplet = handBeforeDiscard18[discardTileType] >= 3 && handAfterDiscard18[discardTileType] <= 2;

        if (SichuanRoutePlanEngine.IsSevenPairsRoute(currentPlan.PrimaryRoute))
        {
            if (breaksPair)
            {
                var penalty = (breaksTriplet ? 28.0 : 20.0) * speedScale;
                score -= penalty;
                reasons.Add(reachesReady
                    ? "七对路线被速度覆盖：能下叫时允许拆对子"
                    : "七对路线：拆对子强降权");
            }
            if (!SichuanRoutePlanEngine.IsSevenPairsRoute(afterPlan.PrimaryRoute))
            {
                score -= 12.0 * speedScale;
                reasons.Add(reachesReady
                    ? "路线切换：平胡已成叫，允许退出七对"
                    : "七对路线：未成叫前不轻易退出门清路线");
            }
        }

        if (SichuanRoutePlanEngine.IsFlushRoute(currentPlan.PrimaryRoute) && currentPlan.TargetSuit is >= 0 and <= 2)
        {
            var tileSuit = discardTileType / 9;
            var targetSuitCountBefore = CountSuit(handBeforeDiscard18, currentPlan.TargetSuit);
            var offSuitCountBefore = Math.Max(0, handBeforeDiscard18.Sum() - targetSuitCountBefore);
            if (tileSuit == currentPlan.TargetSuit && offSuitCountBefore > 0 && !reachesReady)
            {
                var penalty = targetSuitCountBefore >= 10 && offSuitCountBefore <= 3 ? 24.0 : 11.0;
                score -= penalty;
                reasons.Add("清色路线：异门未清完，不轻拆目标花色");
            }
            else if (tileSuit != currentPlan.TargetSuit)
            {
                var bonus = roundStage <= 1 ? 18.0 : 10.0;
                if (targetSuitCountBefore >= 10 && offSuitCountBefore <= 3)
                    bonus += 8.0;
                score += bonus;
                reasons.Add("清色路线：优先清理异门牌");
            }
        }

        if (SichuanRoutePlanEngine.IsPungRoute(currentPlan.PrimaryRoute))
        {
            if (breaksTriplet && !reachesReady)
            {
                score -= 15.0;
                reasons.Add("对子胡路线：不轻拆刻子");
            }
            else if (breaksPair && !reachesReady)
            {
                score -= 8.0;
                reasons.Add("对子胡路线：不轻拆对子");
            }
        }

        if (currentPlan.PrimaryRoute != afterPlan.PrimaryRoute && reachesReady)
        {
            score += 12.0;
            reasons.Add("路线切换：能下叫先下叫");
        }

		if (afterPlan.PrimaryRoute == "平胡")
        {
            score += reachesReady ? 8.0 : 2.0;
            reasons.Add("平胡路线：保持速度和宽叫");
        }

        return Math.Abs(score) < 0.001
            ? SichuanSimpleAdjustment.Empty
            : new SichuanSimpleAdjustment(score, reasons.Distinct().ToArray());
    }

	private static SichuanSimpleAdjustment BuildQingPlanAdjustment(
		int tileType,
		SichuanRoutePlanResult routePlan,
		IReadOnlyDictionary<int, SichuanQingPlanCandidate> plans)
	{
		if (!plans.TryGetValue(tileType, out var plan))
			return SichuanSimpleAdjustment.Empty;
		var committed = SichuanRoutePlanEngine.IsFlushRoute(routePlan.PrimaryRoute);
		var scale = committed ? 2.2 : 0.65;
		var score = plan.ExpectedValue * scale;
		if (committed && tileType / 9 != plan.TargetSuit) score += 2.4;
		if (committed && tileType / 9 == plan.TargetSuit) score -= 1.8;
		return new SichuanSimpleAdjustment(score, plan.Reasons.Concat(new[]
		{
			committed ? "连续大脑：清一色使用两层预下叫前瞻" : "路线评估：保留清一色可行性但不盲目承诺"
		}).ToArray());
	}

    private static SichuanBigHandRouteAdjustment EvaluateBigHandRouteAdjustment(
        int[] handBeforeDiscard18,
        int[] handAfterDiscard18,
        SichuanStateView state,
        int discardTileType,
        int meldCount,
        int roundStage,
        int currentShanten,
        int shantenAfterDiscard,
        int liveUkeireAfterDiscard,
        int waitCountAfterDiscard)
    {
        if (roundStage > 1 || state.WallCount < 8)
            return SichuanBigHandRouteAdjustment.Empty;

        var beforePairs = CountPairLikeGroups(handBeforeDiscard18);
        var afterPairs = CountPairLikeGroups(handAfterDiscard18);
        var beforePairPotential = beforePairs + meldCount;
        var afterPairPotential = afterPairs + meldCount;
        var concealedQiDuiBefore = meldCount == 0 && beforePairs >= 4;
        var concealedQiDuiAfter = meldCount == 0 && afterPairs >= 4;
        var duiDuiBefore = meldCount >= 1 && beforePairPotential >= 5;
        var duiDuiAfter = meldCount >= 1 && afterPairPotential >= 5;
        var beforeBigPairRoute = concealedQiDuiBefore || duiDuiBefore;
        var afterBigPairRoute = concealedQiDuiAfter || duiDuiAfter;
        if (!beforeBigPairRoute && !afterBigPairRoute)
            return SichuanBigHandRouteAdjustment.Empty;

        var score = 0.0;
        var reasons = new List<string>();
        var reachesReady = shantenAfterDiscard <= 0 && waitCountAfterDiscard > 0;
        var improvesShanten = shantenAfterDiscard < currentShanten;
        var speedProtectionScale = reachesReady ? 0.0 : improvesShanten ? 0.25 : 1.0;
        var breaksPair = discardTileType is >= 0 and < 27
            && handBeforeDiscard18[discardTileType] >= 2
            && handAfterDiscard18[discardTileType] <= 1;
        var breaksTriplet = discardTileType is >= 0 and < 27
            && handBeforeDiscard18[discardTileType] >= 3
            && handAfterDiscard18[discardTileType] <= 2;

        if (afterBigPairRoute)
        {
            var routeBonus = duiDuiAfter ? 4.8 : 3.6;
            if (reachesReady)
                routeBonus *= 0.35;
            else if (improvesShanten)
                routeBonus *= 0.55;
            score += routeBonus;
            reasons.Add(duiDuiAfter ? "前期保留对子胡路线" : "前期保留七对路线");
            if (handBeforeDiscard18[discardTileType] == 1)
            {
                score += 2.4;
                reasons.Add("优先拆孤张保留对子");
            }
        }

        if (beforeBigPairRoute && !afterBigPairRoute)
        {
            var penalty = (breaksTriplet ? 22.0 : 16.0) * speedProtectionScale;
            score -= penalty;
            reasons.Add(reachesReady
                ? "拆搭取速：能下叫时不为大牌路线硬留对子/刻子"
                : breaksTriplet ? "拆刻子破坏大牌路线" : "拆对子破坏大牌路线");
        }
        else if (afterBigPairRoute && breaksTriplet)
        {
            var penalty = 12.0 * speedProtectionScale;
            score -= penalty;
            reasons.Add(reachesReady ? "拆刻子但立刻成叫，速度优先" : "大牌路线下降：拆刻子");
        }
        else if (afterBigPairRoute && breaksPair)
        {
            var penalty = 7.0 * speedProtectionScale;
            score -= penalty;
            reasons.Add(reachesReady ? "拆对子但立刻成叫，速度优先" : "大牌路线下降：拆对子");
        }

        return new SichuanBigHandRouteAdjustment(score, reasons);
    }

    private static SichuanSimpleAdjustment EvaluateFastTingPriorityAdjustment(
        int currentShanten,
        int shantenAfterDiscard,
        int liveUkeireAfterDiscard,
        int waitCountAfterDiscard,
        int roundStage,
        int danger)
    {
        var score = 0.0;
        var reasons = new List<string>();

        if (shantenAfterDiscard <= 0 && waitCountAfterDiscard > 0)
        {
            score += roundStage <= 1 ? 15.0 : 8.0;
            score += Math.Min(7.0, waitCountAfterDiscard * 1.8);
            score += Math.Min(4.0, liveUkeireAfterDiscard * 0.35);
            reasons.Add("四川血战：能成叫先成叫，速度压过贪大牌");
            if (waitCountAfterDiscard >= 2)
                reasons.Add("成叫且听口不窄，优先落袋");
        }
        else if (shantenAfterDiscard < currentShanten)
        {
            score += roundStage <= 1 ? 7.0 : 3.5;
            score += Math.Min(3.0, liveUkeireAfterDiscard * 0.18);
            reasons.Add("四川血战：先降向听，尽快逼近成叫");
        }
        else if (roundStage <= 1 && shantenAfterDiscard <= 1 && liveUkeireAfterDiscard >= 10)
        {
            score += 3.0;
            reasons.Add("宽进张抢听，保持速度");
        }

        if (danger >= 78 && roundStage >= 1)
        {
            score *= 0.45;
            if (reasons.Count > 0)
                reasons.Add("高危牌降速攻加成");
        }

        return Math.Abs(score) < 0.001
            ? SichuanSimpleAdjustment.Empty
            : new SichuanSimpleAdjustment(score, reasons);
    }

    private static int CountPairLikeGroups(int[] hand18)
    {
        var count = 0;
        foreach (var tileCount in hand18)
        {
            if (tileCount >= 2)
                count++;
        }
        return count;
    }

    private static int CountSuit(int[] hand18, int suitIndex)
    {
        if (suitIndex is < 0 or > 2)
            return 0;
        return hand18.Skip(suitIndex * 9).Take(9).Sum();
    }

    private static int ResolveFastRank(int shanten, int waitCount, int liveUkeire)
    {
        if (shanten <= 0 && waitCount >= 2) return 0;
        if (shanten <= 0 && waitCount >= 1) return 1;
        if (shanten <= 1 && liveUkeire >= 8) return 2;
        if (shanten <= 1) return 3;
        if (liveUkeire >= 6) return 4;
        return 5;
    }

    private static double EstimateTenpaiProbability(int shanten, int liveUkeire)
    {
        if (shanten <= 0) return 0.94;
        if (shanten == 1) return Math.Clamp(0.36 + liveUkeire * 0.04, 0.18, 0.90);
        if (shanten == 2) return Math.Clamp(0.16 + liveUkeire * 0.02, 0.06, 0.72);
        return Math.Clamp(0.04 + liveUkeire * 0.01, 0.02, 0.50);
    }

    private static double EstimateExpectedFan(
        IReadOnlyList<string> routes,
        SichuanQingPlanCandidate? qingPlan,
        int waitCount)
    {
        if (qingPlan is not null && qingPlan.CompletionProbability >= 0.18)
            return Math.Clamp(qingPlan.ExpectedFan, 1, 6);
        if (routes.Any(route => route.Contains("青龙七对", StringComparison.Ordinal))) return 6;
        if (routes.Any(route => route.Contains("清七对", StringComparison.Ordinal))) return 5;
        if (routes.Any(route => route.Contains("龙七对", StringComparison.Ordinal))) return 3;
        if (routes.Any(route => route.Contains("清一色", StringComparison.Ordinal))) return 3;
        if (routes.Any(route => route.Contains("七对", StringComparison.Ordinal) || route.Contains("金钩钓", StringComparison.Ordinal))) return 2;
        return waitCount > 0 ? 1.0 : 0.8;
    }

    private static double EstimateShapeValue(
        int shanten,
        int ukeire,
        int liveUkeire,
        int waitCount,
        int qualityScore,
        double wallDrawPosterior,
        int roundStage,
        int routeCount,
        int routeLossCount)
    {
        var stageTempoBoost = roundStage switch
        {
            0 => 0.56,
            1 => 0.30,
            _ => 0.0
        };
        var routeKeepWeight = roundStage <= 0 ? 0.08 : roundStage == 1 ? 0.04 : 0.01;
        var routeLossWeight = roundStage <= 0 ? 0.05 : roundStage == 1 ? 0.02 : 0.01;
        var tempoValue = (8 - shanten) * (0.34 + stageTempoBoost * 0.16) + liveUkeire * 0.025 + ukeire * 0.015;
        var qualityValue = qualityScore / 180.0 + waitCount * 0.10 + wallDrawPosterior * 0.22;
        var routeValue = routeCount * routeKeepWeight - routeLossCount * routeLossWeight;
        return tempoValue + qualityValue + routeValue;
    }

    private static double EstimatePosteriorDefensePenalty(
        int shanten,
        int liveUkeire,
        double dealInProbability,
        double maxReadyPosterior,
        double wallDrawPosterior,
        int wallCount,
        int roundStage)
    {
        var penalty = 0.0;
        var lateStage = roundStage >= 1;
        var endStage = roundStage >= 2;
        if (!lateStage && maxReadyPosterior < 0.58)
            return penalty;

        if (lateStage)
            penalty += Math.Max(0.0, maxReadyPosterior - 0.48) * 4.2;
        if (dealInProbability >= 0.56)
            penalty += (dealInProbability - 0.55) * 11.0;
        if (dealInProbability >= 0.40 && maxReadyPosterior >= 0.62)
            penalty += 1.8;
        if (shanten > 0 && liveUkeire <= 6 && maxReadyPosterior >= 0.60)
            penalty += 1.4;
        if (endStage && shanten > 0)
            penalty += 1.2 + Math.Max(0.0, 0.40 - wallDrawPosterior) * 4.0;
        if (endStage && dealInProbability >= 0.34 && maxReadyPosterior >= 0.52)
            penalty += 1.6;
        return penalty;
    }

    private static double EstimateWallDrawPosterior(IReadOnlyList<int> improvingTiles, SichuanBeliefSnapshot belief)
    {
        if (improvingTiles.Count == 0) return 0.0;
        var total = 0.0;
        foreach (var tileType in improvingTiles)
            total += belief.TileWallPosterior.GetValueOrDefault(tileType, 0.0);
        return Math.Clamp(total / improvingTiles.Count, 0.0, 0.98);
    }

    private static double ResolveDefenseAdjustmentWeight(int shanten, int waitCount, int roundStage, double maxReadyPosterior)
    {
        var weight = 0.55;
        if (roundStage == 1) weight += 0.25;
        else if (roundStage >= 2) weight += 0.55;
        if (shanten > 0) weight += 0.24;
        if (waitCount <= 1) weight += 0.12;
        if (maxReadyPosterior >= 0.72) weight += 0.22;
        else if (maxReadyPosterior >= 0.56) weight += 0.12;
        return Math.Clamp(weight, 0.40, 1.75);
    }

    private static string ResolveStrategyTag(int shanten, int liveUkeire, int danger, int roundStage)
    {
        if (shanten <= 1 && liveUkeire >= 10) return "抢听";
        if (roundStage >= 2 && danger >= 52) return "防炮收缩";
        if (danger >= 70) return "收缩防守";
        if (shanten <= 2 && liveUkeire >= 6) return "速听推进";
        return "定缺取舍";
    }

    private static string ResolveStrategyMode(int shanten, int waitCount, int danger, int roundStage)
    {
        if (roundStage >= 2 && danger >= 56) return "收守";
        if (shanten <= 0 && waitCount >= 2) return "宽叫压制";
        if (shanten <= 1) return "快速成叫";
        return "定缺速听";
    }

    private static string BuildExplanationHint(int shanten, int ukeire, int liveUkeire, int waitCount, int danger, string strategyMode, string riskLabel)
    {
        if (strategyMode == "fold") return "这手先止损避炮";
        if (strategyMode == "defense") return "这手先降风险";
        if (strategyMode == "chase") return "落后局势提高收益权重";
        if (strategyMode == "attack") return "这手按进攻推进";
        if (strategyMode == "宽叫压制") return "这手先保宽叫";
        if (strategyMode == "快速成叫" && liveUkeire >= 8) return "这手先抢速度";
        if (danger >= 70) return "这手先保安全";
        if (waitCount >= 2 && ukeire >= 6) return "先保留两面搭子";
        if (shanten <= 1 && liveUkeire >= 10) return "这张进张最多";
        if (riskLabel == "低危") return "这张相对更安全";
        return "这手先保宽叫和安全";
    }

    private static IReadOnlyList<string> BuildRiskReasons(int danger, string riskLabel, int wallCount, int roundStage, int liveUkeire, SichuanDangerEvaluation dangerEvaluation)
    {
        var reasons = dangerEvaluation.Reasons.ToList();
        if (danger >= 70) reasons.Add("对手成牌压力高");
        if (roundStage >= 2) reasons.Add("后期风险上升");
        else if (roundStage == 1) reasons.Add("中盘开始要兼顾防炮");
        if (roundStage >= 2 && dangerEvaluation.TopThreatScore >= 55) reasons.Add("后验威胁高，尾盘收缩");
        if (liveUkeire <= 4) reasons.Add("活张偏少");
        if (reasons.Count == 0) reasons.Add($"当前{riskLabel}可控");
        return reasons.Distinct().Take(5).ToArray();
    }

    private static IReadOnlyList<string> BuildPosteriorReasons(
        int shanten,
        int liveUkeire,
        double dealInProbability,
        double maxReadyPosterior,
        double wallDrawPosterior,
        int wallCount,
        int roundStage,
        double posteriorAdjustment)
    {
        var reasons = new List<string>();
        if (posteriorAdjustment <= 0.01)
        {
            reasons.Add("后验未明显压分");
            return reasons;
        }
        if (roundStage >= 2)
            reasons.Add("后期已到，优先防炮");
        else if (roundStage == 1)
            reasons.Add("中盘压力上升，开始压风险");
        if (maxReadyPosterior >= 0.60)
            reasons.Add($"听牌后验高 {maxReadyPosterior:P0}");
        if (dealInProbability >= 0.40)
            reasons.Add($"点炮率偏高 {dealInProbability:P0}");
        if (roundStage >= 2 && wallDrawPosterior <= 0.30)
            reasons.Add($"牌墙后验低 {wallDrawPosterior:P0}");
        if (shanten > 0 && liveUkeire <= 6)
            reasons.Add("进张偏窄，宜收缩");
        return reasons.Distinct().Take(3).ToArray();
    }

    private static IReadOnlyList<string> BuildReasons(
        int shanten,
        int liveUkeire,
        int danger,
        string riskLabel,
        string strategyTag,
        int waitCount,
        int roundStage,
        IReadOnlyList<string> posteriorReasons,
        SichuanExpectedScore expectedScore)
    {
        var reasons = new List<string>
        {
            $"最小向听 {shanten}",
            $"活进张 {liveUkeire}",
            $"净分期望 {expectedScore.Net:0.00}",
            $"危险度 {danger}（{riskLabel}）",
            $"阶段 {RoundStageLabel(roundStage)}",
            $"策略 {strategyTag}"
        };
        if (waitCount > 0)
            reasons.Add($"宽叫 {waitCount} 门");
        if (posteriorReasons.Count > 0 && posteriorReasons[0] != "后验未明显压分")
            reasons.Add($"后验：{posteriorReasons[0]}");
        reasons.AddRange(expectedScore.Reasons.Take(2));
        return reasons;
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

    private static string RoundStageLabel(int roundStage) => roundStage switch
    {
        0 => "前期",
        1 => "中期",
        _ => "后期"
    };

    private static SichuanCandidateDetail? SelectExtremeDangerSameSpeedOverride(
        IReadOnlyList<SichuanCandidateDetail> candidates,
        int currentTile,
        SichuanStateView state)
    {
        if (candidates.Count < 2 || state.WallCount <= 0)
            return null;
        var current = candidates.FirstOrDefault(item => item.TileType == currentTile);
        if (current is null || current.Danger < 78)
            return null;

        return candidates
            .Where(item => item.TileType != current.TileType
                && item.Shanten <= current.Shanten
                && item.WaitCount >= current.WaitCount
                && item.LiveUkeire + 1 >= current.LiveUkeire
                && item.Danger + 4 <= current.Danger)
            .OrderBy(item => item.Shanten)
            .ThenBy(item => item.Danger)
            .ThenByDescending(item => item.LiveUkeire)
            .ThenByDescending(item => item.Score)
            .FirstOrDefault();
    }

    private static SichuanCandidateDetail? SelectLateWallDefenseOverride(
        IReadOnlyList<SichuanCandidateDetail> candidates,
        int currentTile,
        SichuanStateView state,
        double maxReadyPosterior)
    {
        if (state.WallCount > 5 || candidates.Count < 2)
            return null;
        var current = candidates.FirstOrDefault(item => item.TileType == currentTile);
        if (current is null)
            return null;

        if (state.WallCount <= 0 && current.WaitCount > 0)
        {
            var wallEmptyAlternative = candidates
                .Where(item => item.TileType != current.TileType
                    && item.Shanten == current.Shanten
                    && item.WaitCount >= current.WaitCount
                    && item.Danger + 4 < current.Danger)
                .OrderBy(item => item.Danger)
                .ThenBy(item => item.LiveUkeire)
                .ThenBy(item => item.TileType)
                .FirstOrDefault();
            if (wallEmptyAlternative is not null)
                return wallEmptyAlternative;
        }

        if (state.WallCount <= 0 && current.Shanten <= 0 && current.WaitCount > 0)
        {
            var saferReadyAlternative = candidates
                .Where(item => item.TileType != current.TileType
                    && item.Shanten <= current.Shanten
                    && item.WaitCount > 0
                    && item.Danger + 8 < current.Danger)
                .OrderBy(item => item.Danger)
                .ThenByDescending(item => item.WaitCount)
                .ThenByDescending(item => item.LiveUkeire)
                .ThenByDescending(item => item.Score)
                .FirstOrDefault();
            return saferReadyAlternative;
        }

        if (state.WallCount <= 5 && maxReadyPosterior >= 0.56 && current.Danger >= 22)
        {
            var currentKeepsReady = current.Shanten <= 0 && current.WaitCount > 0 && current.Danger < 78;
            var safeSameSpeed = candidates
                .Where(item => item.TileType != current.TileType
                    && item.Shanten <= current.Shanten
                    && (!currentKeepsReady || item.WaitCount > 0)
                    && item.Danger <= 12)
                .OrderBy(item => item.Danger)
                .ThenByDescending(item => item.WaitCount)
                .ThenByDescending(item => item.LiveUkeire)
                .ThenByDescending(item => item.Score)
                .FirstOrDefault();
            if (safeSameSpeed is not null)
                return safeSameSpeed;
        }

        if (state.WallCount <= 3 && current.WaitCount > 0 && current.LiveUkeire <= 6 && current.Danger > 24)
        {
            var currentKeepsReady = current.Shanten <= 0 && current.WaitCount > 0 && current.Danger < 78;
            var safeFold = candidates
                .Where(item => item.TileType != current.TileType
                    && item.Shanten <= current.Shanten + 1
                    && (!currentKeepsReady || item.WaitCount > 0)
                    && item.Danger <= 12
                    && (item.Shanten <= current.Shanten
                        || item.LiveUkeire >= 10
                        || current.Danger >= 78))
                .OrderBy(item => item.Shanten)
                .ThenBy(item => item.Danger)
                .ThenByDescending(item => item.LiveUkeire)
                .ThenByDescending(item => item.Score)
                .FirstOrDefault();
            if (safeFold is not null)
                return safeFold;
        }

        return null;
    }

    private static SichuanCandidateDetail? SelectLateWallKeepReadyOverride(
        IReadOnlyList<SichuanCandidateDetail> candidates,
        int currentTile,
        SichuanStateView state)
    {
        if (state.WallCount > 5 || candidates.Count < 2)
            return null;

        var current = candidates.FirstOrDefault(item => item.TileType == currentTile);
        if (current is null)
            return null;

        if (current.Shanten <= 0 && current.WaitCount > 0)
            return null;

        return candidates
            .Where(item => item.TileType != current.TileType
                && item.Shanten <= 0
                && item.WaitCount > 0
                && item.Danger < 70)
            .OrderBy(item => item.Danger)
            .ThenByDescending(item => item.WaitCount)
            .ThenByDescending(item => item.LiveUkeire)
            .ThenByDescending(item => item.Score)
            .FirstOrDefault();
    }

    private static List<SichuanCandidateDetail> ApplySearchBonuses(
        IReadOnlyList<SichuanCandidateDetail> candidates,
        SichuanSearchResult searchResult,
        int roundStage,
        SichuanAiContext? context)
    {
        var updated = new List<SichuanCandidateDetail>(candidates.Count);
        foreach (var candidate in candidates)
        {
            var bonus = searchResult.CandidateBonuses.GetValueOrDefault(candidate.TileType, 0.0);
            var mergedReasons = candidate.Reasons.ToList();
            if (Math.Abs(bonus) > 0.001)
                mergedReasons.Add($"前瞻修正 {bonus:F2}");

            updated.Add(new SichuanCandidateDetail
            {
                TileType = candidate.TileType,
                FastTingDiscardRank = candidate.FastTingDiscardRank,
                Score = candidate.Score + (int)Math.Round(bonus * 100.0),
                Shanten = candidate.Shanten,
                Ukeire = candidate.Ukeire,
                LiveUkeire = candidate.LiveUkeire,
                Danger = candidate.Danger,
                WaitCount = candidate.WaitCount,
                WaitQualityScore = candidate.WaitQualityScore,
                ImprovingTiles = candidate.ImprovingTiles,
                RiskLabel = candidate.RiskLabel,
                StrategyTag = candidate.StrategyTag,
                StrategyMode = candidate.StrategyMode,
                ExplanationHint = candidate.ExplanationHint,
                RoutePlanPrimary = candidate.RoutePlanPrimary,
                RoutePlanScore = candidate.RoutePlanScore,
                RoutesAfter = candidate.RoutesAfter,
                RouteLoss = candidate.RouteLoss,
                TenpaiProbability = candidate.TenpaiProbability,
                SelfDrawProbability = candidate.SelfDrawProbability,
                WinProbability = candidate.WinProbability,
                ExpectedFan = candidate.ExpectedFan,
                DealInProbability = candidate.DealInProbability,
                ExpectedValue = candidate.ExpectedValue + bonus,
                ExpectedNetScore = candidate.ExpectedNetScore,
                ExpectedWinGain = candidate.ExpectedWinGain,
                ExpectedDealInLoss = candidate.ExpectedDealInLoss,
                ExpectedDrawRiskLoss = candidate.ExpectedDrawRiskLoss,
                ExpectedReadyValue = candidate.ExpectedReadyValue,
                PosteriorAdjustment = candidate.PosteriorAdjustment,
                DefenseAdjustment = candidate.DefenseAdjustment,
                GoodShapeCount = candidate.GoodShapeCount,
                BadShapeCount = candidate.BadShapeCount,
                PairPressure = candidate.PairPressure,
                TaatsuOverflow = candidate.TaatsuOverflow,
                SameShantenImprovementCount = candidate.SameShantenImprovementCount,
                MiddleTileFlexibility = candidate.MiddleTileFlexibility,
                ShapeScore = candidate.ShapeScore,
                BreaksPair = candidate.BreaksPair,
                BreaksTriplet = candidate.BreaksTriplet,
                SetPreservationScore = candidate.SetPreservationScore,
                WaitShapeLabel = candidate.WaitShapeLabel,
                WaitShapeScore = candidate.WaitShapeScore,
                RyanmenWaitCount = candidate.RyanmenWaitCount,
                KanchanWaitCount = candidate.KanchanWaitCount,
                PenchanWaitCount = candidate.PenchanWaitCount,
                TankiWaitCount = candidate.TankiWaitCount,
                ShanponWaitCount = candidate.ShanponWaitCount,
                LimitedLookaheadScore = candidate.LimitedLookaheadScore,
                LimitedLookaheadSamples = candidate.LimitedLookaheadSamples,
                LimitedLookaheadBestShanten = candidate.LimitedLookaheadBestShanten,
                LimitedLookaheadBestLiveUkeire = candidate.LimitedLookaheadBestLiveUkeire,
                SearchBonus = bonus,
                SearchSimulations = searchResult.Simulations,
                SearchUsed = searchResult.Used,
                PosteriorReasons = candidate.PosteriorReasons,
                RiskReasons = candidate.RiskReasons,
                Reasons = mergedReasons
            });
        }

        return SortDiscardCandidates(updated, roundStage, context);
    }

    private static SichuanBeliefSummary BuildBeliefSummary(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int bestTile,
        SichuanCandidateDetail? bestCandidate)
    {
        var readyPosteriors = belief.SeatReadyPosterior
            .Select(item => new SichuanPosteriorSeatSummary
            {
                Seat = item.Key,
                ReadyPosterior = Math.Round(item.Value, 4),
                ThreatScore = Math.Round(belief.SeatThreatScore.GetValueOrDefault(item.Key, 0.0), 4),
                IsCalled = state.IsCalled[item.Key] || state.IsReady[item.Key]
            })
            .OrderByDescending(item => item.ReadyPosterior)
            .ThenByDescending(item => item.ThreatScore)
            .Take(3)
            .ToArray();

        var holdTop = Array.Empty<SichuanPosteriorSeatHoldSummary>();
        var waitTop = Array.Empty<SichuanPosteriorSeatWaitSummary>();
        if (bestTile >= 0)
        {
            var suit = bestTile / 9;
            holdTop = belief.SeatTileHoldProbability
                .Select(item => new SichuanPosteriorSeatHoldSummary
                {
                    Seat = item.Key,
                    HoldPosterior = Math.Round(item.Value.GetValueOrDefault(bestTile, 0.0), 4),
                    TileDanger = Math.Round(belief.SeatTileDanger.GetValueOrDefault(item.Key, new Dictionary<int, double>()).GetValueOrDefault(bestTile, 0.0), 4),
                    SuitDemand = Math.Round(belief.SeatSuitDemand.GetValueOrDefault(item.Key, new Dictionary<int, double>()).GetValueOrDefault(suit, 0.0), 4)
                })
                .OrderByDescending(item => item.HoldPosterior)
                .ThenByDescending(item => item.TileDanger)
                .Take(2)
                .ToArray();
            waitTop = belief.SeatTileWaitProbability
                .Select(item => new SichuanPosteriorSeatWaitSummary
                {
                    Seat = item.Key,
                    WaitPosterior = Math.Round(item.Value.GetValueOrDefault(bestTile, 0.0), 4),
                    NoHuEvidence = Math.Round(belief.SeatTileNoHuEvidence.GetValueOrDefault(item.Key, new Dictionary<int, double>()).GetValueOrDefault(bestTile, 0.0), 4),
                    ReadyPosterior = Math.Round(belief.SeatReadyPosterior.GetValueOrDefault(item.Key, 0.0), 4)
                })
                .OrderByDescending(item => item.WaitPosterior)
                .ThenBy(item => item.NoHuEvidence)
                .Take(3)
                .ToArray();
        }

        var improvingTiles = bestCandidate?.ImprovingTiles ?? Array.Empty<int>();
        var wallTop = improvingTiles
            .Distinct()
            .Select(tileType => new SichuanPosteriorTileSummary
            {
                TileType = tileType,
                Posterior = Math.Round(belief.TileWallPosterior.GetValueOrDefault(tileType, 0.0), 4)
            })
            .OrderByDescending(item => item.Posterior)
            .Take(3)
            .ToArray();
        var avgWall = wallTop.Length == 0 ? 0.0 : Math.Round(wallTop.Average(item => item.Posterior), 4);

        return new SichuanBeliefSummary
        {
            ReadyPosteriors = readyPosteriors,
            HoldSummary = new SichuanPosteriorHoldSummary
            {
                TileType = bestTile,
                TopHolders = holdTop
            },
            WallSummary = new SichuanPosteriorWallSummary
            {
                AveragePosterior = avgWall,
                TopTiles = wallTop
            },
            WaitSummary = new SichuanPosteriorWaitSummary
            {
                TileType = bestTile,
                TopWaiters = waitTop
            },
            UnknownSummary = new SichuanUnknownTileSummary
            {
                TotalUnknown = belief.Unknown18.Sum(),
                TopTiles = belief.Unknown18
                    .Select((count, tileType) => new SichuanUnknownTileCount
                    {
                        TileType = tileType,
                        Count = Math.Max(0, count)
                    })
                    .Where(item => item.Count > 0)
                    .OrderByDescending(item => item.Count)
                    .ThenBy(item => item.TileType)
                    .Take(6)
                    .ToArray()
            }
        };
    }
}
