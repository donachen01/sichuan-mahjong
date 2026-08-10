using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Godot;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Evaluation;
using SichuanMahjong.AI.Core.Learning;
using SichuanMahjong.AI.Core.Models;

public partial class SichuanCSharpRuntime : Node
{
    private readonly SichuanAiFacade _facade = new();
	private readonly SichuanLearningEngine _learningEngine = new();
	private readonly SichuanFrozenBaselinePolicy _frozenPolicy = new();
    private readonly SichuanHellOracleEngine _hellOracle = new();
    private readonly SichuanHellChallengeEngine _hellChallenge;
    private readonly SichuanHellChallengeReactionEngine _hellChallengeReaction;

    public SichuanCSharpRuntime()
    {
        _hellChallenge = new SichuanHellChallengeEngine(_facade);
        _hellChallengeReaction = new SichuanHellChallengeReactionEngine(_facade);
    }
    private sealed class AsyncAiRequest
    {
        public readonly object SyncRoot = new();
        public readonly Func<string> Compute;
        public readonly long StartedTimestamp = Stopwatch.GetTimestamp();
        public bool IsCompleted;
        public string Status = "created";
        public string? ResultJson;
        public string? ErrorMessage;
        public int ManagedThreadId = -1;

        public AsyncAiRequest(Func<string> compute)
        {
            Compute = compute;
        }
    }

    private readonly ConcurrentDictionary<int, AsyncAiRequest> _asyncRequests = new();
    private int _nextAsyncRequestId;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false,
        Converters = { new JsonStringEnumConverter() }
    };

    public bool IsRuntimeReady() => true;

    public override void _Ready()
    {
        GD.Print("[SichuanCSharpRuntime] ready");
    }

    public int StartAnalyzeDiscardJson(string payloadJson)
    {
        return StartAsyncRequest(() => AnalyzeDiscardJson(payloadJson));
    }

    public int StartAnalyzeHellChallengeDiscardJson(string payloadJson)
    {
        return StartAsyncRequest(() => AnalyzeHellChallengeDiscardJson(payloadJson));
    }

    public int StartAnalyzeReactionJson(string payloadJson)
    {
        return StartAsyncRequest(() => AnalyzeReactionJson(payloadJson));
    }

    public int StartAnalyzeHellChallengeReactionJson(string payloadJson)
    {
        return StartAsyncRequest(() => AnalyzeHellChallengeReactionJson(payloadJson));
    }

    public int StartAnalyzeSelfActionJson(string payloadJson)
    {
        return StartAsyncRequest(() => AnalyzeSelfActionJson(payloadJson));
    }

    public int StartAnalyzeDingQueJson(string payloadJson)
    {
        return StartAsyncRequest(() => AnalyzeDingQueJson(payloadJson));
    }

    public string PollAiResultJson(int requestId)
    {
        if (!_asyncRequests.TryGetValue(requestId, out var request))
            return "{\"ok\":false,\"error\":\"unknown_ai_request\"}";

        lock (request.SyncRoot)
        {
            if (!request.IsCompleted)
            {
                return JsonSerializer.Serialize(new
                {
                    ok = true,
                    pending = true,
                    requestId,
                    status = request.Status,
                    elapsedMs = ElapsedMillisecondsSince(request.StartedTimestamp),
                    managedThreadId = request.ManagedThreadId
                }, JsonOptions);
            }
        }

        _asyncRequests.TryRemove(requestId, out _);
        lock (request.SyncRoot)
        {
            if (!string.IsNullOrEmpty(request.ErrorMessage))
            {
                return JsonSerializer.Serialize(new
                {
                    ok = false,
                    error = request.ErrorMessage,
                    requestId,
                    status = request.Status,
                    elapsedMs = ElapsedMillisecondsSince(request.StartedTimestamp),
                    managedThreadId = request.ManagedThreadId
                }, JsonOptions);
            }

            return string.IsNullOrEmpty(request.ResultJson)
                ? "{\"ok\":false,\"error\":\"empty_async_ai_result\"}"
                : request.ResultJson;
        }
    }

    public bool HasPendingAiRequests() => !_asyncRequests.IsEmpty;

    public string AnalyzeDiscardJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<DiscardPayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_discard_payload\"}";

            var output = BuildDiscardObject(payload);
            return JsonSerializer.Serialize(output, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string AnalyzeReactionJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<ReactionPayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_reaction_payload\"}";

            var output = BuildReactionObject(payload);
            return JsonSerializer.Serialize(output, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string AnalyzeHellChallengeReactionJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<HellChallengeReactionPayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_hell_challenge_reaction_payload\"}";

            var output = BuildHellChallengeReactionObject(payload);
            return JsonSerializer.Serialize(output, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string AnalyzeSelfActionJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<SelfActionPayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_self_action_payload\"}";

            var output = BuildSelfActionObject(payload);
            return JsonSerializer.Serialize(output, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string AnalyzeDingQueJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<DingQuePayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_ding_que_payload\"}";

            var output = BuildDingQueObject(payload);
            return JsonSerializer.Serialize(output, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string DecideDingQueSuit(int tiaoCount, int tongCount, int wanCount)
    {
        var suitCounts = new Dictionary<string, int>
        {
            ["tiao"] = Math.Max(0, tiaoCount),
            ["tong"] = Math.Max(0, tongCount),
            ["wan"] = Math.Max(0, wanCount)
        };
        return _facade.DecideDingQue(suitCounts, ["tiao", "tong", "wan"]).Suit;
    }

    // iOS NativeAOT disables reflection-based System.Text.Json metadata. These
    // compact entry points use generated input metadata and a scalar transport
    // so gameplay decisions remain available without a reflection fallback.
    public string AnalyzeDiscardAotCompact(string payloadJson, bool hellChallenge)
    {
        try
        {
            if (hellChallenge)
            {
                var payload = JsonSerializer.Deserialize(payloadJson, RuntimeJsonContext.Default.HellChallengePayload);
                if (payload is null)
                    return "error|invalid_hell_challenge_payload";
                var state = BuildState(payload);
                var result = _hellChallenge.DecideDiscard(
                    state,
                    payload.AllHands18.Select(item => (IReadOnlyList<int>)item).ToArray(),
                    payload.ExactWall18,
                    payload.CurrentScores);
                return PackCompact(
                    "ok",
                    result.Action.ActionType.ToString().ToLowerInvariant(),
                    result.Action.TileType,
                    result.Action.Score,
                    result.SelectedShanten,
                    0,
                    result.SelectedLiveUkeire,
                    "",
                    result.SelectedWaitCount,
                    "hell_challenge_aot_compact");
            }

            var discardPayload = JsonSerializer.Deserialize(payloadJson, RuntimeJsonContext.Default.DiscardPayload);
            if (discardPayload is null)
                return "error|invalid_discard_payload";
			var discardState = BuildState(discardPayload);
			if (IsFrozenPolicy(discardPayload))
			{
				var tile = _frozenPolicy.DecideDiscard(discardState);
				return PackCompact("ok", "discard", tile, 0, 0, 0, 0, "", 0, "frozen_hard_tier_aot_compact");
			}
			var discardResult = _facade.DecideDiscardCached(
                discardState,
                forceLightweight: discardPayload.MobileSpeedMode || discardPayload.ForceLightweight);
            var selectedDiscard = discardResult.Candidates.FirstOrDefault(item => item.TileType == discardResult.Action.TileType);
            return PackCompact(
                "ok",
                discardResult.Action.ActionType.ToString().ToLowerInvariant(),
                discardResult.Action.TileType,
                discardResult.Action.Score,
                discardResult.Shanten,
                discardResult.Ukeire,
                discardResult.LiveUkeire,
                discardResult.GangSubtype,
                selectedDiscard?.WaitCount ?? 0,
                "csharp_native_aot_compact",
                selectedDiscard?.ExpectedNetScore ?? 0,
                selectedDiscard?.ExpectedFan ?? 0,
                selectedDiscard?.WinProbability ?? discardResult.WinProbability,
                selectedDiscard?.TenpaiProbability ?? 0,
                selectedDiscard?.ExplanationHint ?? discardResult.Reasons.FirstOrDefault() ?? string.Empty);
        }
        catch (Exception ex)
        {
            return PackCompact("error", SanitizeCompactField(ex.GetBaseException().Message));
        }
    }

    public string AnalyzeReactionAotCompact(string payloadJson, bool hellChallenge)
    {
        try
        {
            if (hellChallenge)
            {
                var payload = JsonSerializer.Deserialize(payloadJson, RuntimeJsonContext.Default.HellChallengeReactionPayload);
                if (payload is null)
                    return "error|invalid_hell_challenge_reaction_payload";
                var state = BuildState(payload);
                var result = _hellChallengeReaction.DecideReaction(
                    state,
                    payload.ReactionTileType,
                    payload.CanHu,
                    payload.CanPeng,
                    payload.CanGang,
                    payload.SourceSeat,
                    payload.ReactionType,
                    payload.AllHands18.Select(item => (IReadOnlyList<int>)item).ToArray(),
                    payload.ExactWall18,
                    payload.CurrentScores,
                    payload.MandatoryGang);
                return PackCompact(
                    "ok",
                    result.Action.ActionType.ToString().ToLowerInvariant(),
                    result.Action.TileType,
                    result.Action.Score,
                    result.ShantenAfter,
                    result.LiveUkeireAfter,
                    result.CurrentShanten,
                    result.CurrentLiveUkeire,
                    result.ThreatLevel,
                    result.RoundStage,
                    "hell_challenge_reaction_aot_compact");
            }

            var reactionPayload = JsonSerializer.Deserialize(payloadJson, RuntimeJsonContext.Default.ReactionPayload);
            if (reactionPayload is null)
                return "error|invalid_reaction_payload";
			var reactionState = BuildState(reactionPayload);
			if (IsFrozenPolicy(reactionPayload))
			{
				var action = _frozenPolicy.DecideReaction(
					reactionState, reactionPayload.ReactionTileType, reactionPayload.CanHu,
					reactionPayload.CanPeng, reactionPayload.CanGang, reactionPayload.MandatoryGang);
				return PackCompact("ok", action.ToString().ToLowerInvariant(), reactionPayload.ReactionTileType,
					0, 0, 0, 0, 0, 0, 0, "frozen_hard_tier_reaction_aot_compact");
			}
			var reactionResult = _facade.DecideReaction(
                reactionState,
                reactionPayload.ReactionTileType,
                reactionPayload.CanHu,
                reactionPayload.CanPeng,
                reactionPayload.CanGang,
                reactionPayload.SourceSeat,
                reactionPayload.ReactionType,
                reactionPayload.MobileSpeedMode,
                reactionPayload.MandatoryGang);
            return PackCompact(
                "ok",
                reactionResult.Action.ActionType.ToString().ToLowerInvariant(),
                reactionResult.Action.TileType,
                reactionResult.Action.Score,
                reactionResult.ShantenAfter,
                reactionResult.LiveUkeireAfter,
                reactionResult.CurrentShanten,
                reactionResult.CurrentLiveUkeire,
                reactionResult.ThreatLevel,
                reactionResult.RoundStage,
                "csharp_reaction_aot_compact",
                reactionResult.Reasons.FirstOrDefault() ?? string.Empty);
        }
        catch (Exception ex)
        {
            return PackCompact("error", SanitizeCompactField(ex.GetBaseException().Message));
        }
    }

    public string AnalyzeSelfActionAotCompact(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize(payloadJson, RuntimeJsonContext.Default.SelfActionPayload);
            if (payload is null)
                return "error|invalid_self_action_payload";
            var state = BuildState(payload);
            var result = _facade.DecideSelfAction(
                state,
                payload.CanSelfHu,
                payload.AnGangTileTypes,
                payload.AddGangTileTypes,
                payload.AddGangQiangGangCounts,
                payload.MandatoryGangTileTypes);
            return PackCompact(
                "ok",
                result.Action.ActionType.ToString().ToLowerInvariant(),
                result.Action.TileType,
                result.Action.Score,
                result.GangSubtype,
                result.ShantenAfter,
                result.LiveUkeireAfter,
                "csharp_self_action_aot_compact",
                result.Reasons.FirstOrDefault() ?? string.Empty);
        }
        catch (Exception ex)
        {
            return PackCompact("error", SanitizeCompactField(ex.GetBaseException().Message));
        }
    }

    private static string PackCompact(params object?[] values)
        => string.Join('|', values.Select(value => SanitizeCompactField(value?.ToString() ?? string.Empty)));

    private static string SanitizeCompactField(string value)
        => value.Replace('|', '/').Replace('\r', ' ').Replace('\n', ' ');

    public string AnalyzeHellOracleDiscardJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<HellOraclePayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_hell_oracle_payload\"}";

            var state = BuildState(payload);
            var result = _hellOracle.DecideDiscard(
                state,
                payload.AllHands18.Select(item => (IReadOnlyList<int>)item).ToArray(),
                payload.ExactWall18,
                payload.FairTileType,
                payload.ActualTileType,
                payload.CurrentScores);
            return JsonSerializer.Serialize(new
            {
                ok = true,
                decisionType = result.DecisionType,
                action = result.Action.ActionType.ToString().ToLowerInvariant(),
                tileType = result.Action.TileType,
                score = result.Action.Score,
                category = result.Category,
                severity = result.Severity,
                exactDealIn = result.ExactDealIn,
                fairExactDealIn = result.FairExactDealIn,
                fairFeedsHumanHu = result.FairFeedsHumanHu,
                fairFeedsHumanPeng = result.FairFeedsHumanPeng,
                fairFeedsHumanGang = result.FairFeedsHumanGang,
                fairDealInTargetSeats = result.FairDealInTargetSeats,
                oracleExactDealIn = result.OracleExactDealIn,
                oracleFeedsHumanHu = result.OracleFeedsHumanHu,
                oracleFeedsHumanPeng = result.OracleFeedsHumanPeng,
                oracleFeedsHumanGang = result.OracleFeedsHumanGang,
                humanPressureLevel = result.HumanPressureLevel,
                oracleDealInTargetSeats = result.OracleDealInTargetSeats,
                exactKeepsReady = result.ExactKeepsReady,
            exactWallRemaining = result.ExactWallRemaining,
            fairTileType = result.FairTileType,
            actualTileType = result.ActualTileType,
            candidates = result.Candidates.Select(BuildHellChallengeCandidateObject).ToArray(),
            reasons = result.Reasons
        }, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string AnalyzeHellChallengeDiscardJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<HellChallengePayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_hell_challenge_payload\"}";

            var state = BuildState(payload);
            var result = _hellChallenge.DecideDiscard(
                state,
                payload.AllHands18.Select(item => (IReadOnlyList<int>)item).ToArray(),
                payload.ExactWall18,
                payload.CurrentScores);
            return JsonSerializer.Serialize(BuildHellChallengeObject(result), JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    public string RecordLearningJson(string payloadJson)
    {
        try
        {
            var payload = JsonSerializer.Deserialize<SichuanMahjong.AI.Core.Learning.LearningRecordPayload>(payloadJson, JsonOptions);
            if (payload is null)
                return "{\"ok\":false,\"error\":\"invalid_learning_payload\"}";

            var profile = _learningEngine.RecordHumanRound(
                payload.LearningFilePath,
                payload.LearningHistoryFilePath,
                payload.RoundResult);

            return JsonSerializer.Serialize(new
            {
                ok = true,
                totalHumanRounds = profile.TotalHumanRounds,
                parameterBias = profile.ParameterBias,
                parameterAdjustments = profile.ParameterAdjustments,
                lastAdjustmentReasons = profile.LastAdjustmentReasons
            }, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { ok = false, error = ex.Message }, JsonOptions);
        }
    }

    private object BuildDiscardObject(DiscardPayload payload)
    {
        var stopwatch = Stopwatch.StartNew();
        var beforeBelief = SichuanBeliefEngine.GetDiagnostics();
		var state = BuildState(payload);
		if (IsFrozenPolicy(payload))
		{
			var frozenTile = _frozenPolicy.DecideDiscard(state);
			stopwatch.Stop();
			return new
			{
				ok = true,
				action = "discard",
				tileType = frozenTile,
				gangSubtype = string.Empty,
				score = 0.0,
				shanten = 0,
				ukeire = 0,
				liveUkeire = 0,
				winProbability = 0.0,
				dealInProbability = 0.0,
				searchUsed = false,
				searchSimulations = 0,
				currentRoutes = Array.Empty<string>(),
				mobileSpeedMode = payload.MobileSpeedMode || payload.ForceLightweight,
				forceLightweight = payload.ForceLightweight,
				compactResult = payload.CompactResult,
				elapsedMs = stopwatch.ElapsedMilliseconds,
				reasons = new[] { "测试冻结基线：旧向听/活张硬排序" },
				candidateScores = new Dictionary<string, double>(),
				candidates = Array.Empty<object>()
			};
		}
		SichuanDecisionResult result;
		result = _facade.DecideDiscardCached(state, forceLightweight: payload.MobileSpeedMode || payload.ForceLightweight);
		var selectedTileType = result.Action.TileType;
		var selectedDetail = result.Candidates.FirstOrDefault(item => item.TileType == selectedTileType);
        stopwatch.Stop();
        var beliefMetrics = BuildBeliefMetrics(beforeBelief, SichuanBeliefEngine.GetDiagnostics());
        var cacheSnapshot = _facade.GetTurnCacheSnapshot();
        var strategyProfile = BuildStrategyProfile(state, result);
        var currentRoutes = EstimateRoutesForCli(state);
        var candidateSource = payload.CompactResult
            ? SelectCompactCandidates(result).Select(BuildCompactCandidateObject).ToArray<object>()
            : result.Candidates.Select(BuildFullCandidateObject).ToArray<object>();
        var beliefSummary = payload.CompactResult ? BuildCompactBeliefSummaryObject() : BuildBeliefSummaryObject(result);
        return new
        {
            ok = true,
			action = "discard",
			tileType = selectedTileType,
            gangSubtype = result.GangSubtype,
			score = selectedDetail?.Score ?? result.Action.Score,
			shanten = selectedDetail?.Shanten ?? result.Shanten,
			ukeire = selectedDetail?.Ukeire ?? result.Ukeire,
			liveUkeire = selectedDetail?.LiveUkeire ?? result.LiveUkeire,
            winProbability = result.WinProbability,
            dealInProbability = result.DealInProbability,
            searchUsed = result.SearchUsed,
            searchSimulations = result.SearchSimulations,
            currentRoutes = currentRoutes,
            routePlan = new
            {
                primaryRoute = result.RoutePlan.PrimaryRoute,
                secondaryRoutes = result.RoutePlan.SecondaryRoutes,
                routeWeights = result.RoutePlan.RouteWeights,
                constraints = result.RoutePlan.Constraints,
                reasons = result.RoutePlan.Reasons,
                targetSuit = result.RoutePlan.TargetSuit
            },
            roundBrain = new
            {
                result.RoundBrain.RoundIndex,
                result.RoundBrain.SeatIndex,
                result.RoundBrain.Revision,
                result.RoundBrain.Stage,
                result.RoundBrain.PrimaryRoute,
                result.RoundBrain.FallbackRoute,
                result.RoundBrain.Commitment,
                result.RoundBrain.TargetSuit,
                ProtectedTriplets = result.RoundBrain.ProtectedTriplets.ToArray(),
                ProtectedQuads = result.RoundBrain.ProtectedQuads.ToArray(),
                BrokenTriplets = result.RoundBrain.BrokenTriplets.ToArray(),
                Reasons = result.RoundBrain.Reasons.ToArray()
            },
            strategyProfile = strategyProfile,
            beliefSummary,
            cache = new
            {
                count = cacheSnapshot.Count,
                capacity = cacheSnapshot.Capacity,
                hits = cacheSnapshot.Hits,
                misses = cacheSnapshot.Misses
            },
            elapsedMs = stopwatch.ElapsedMilliseconds,
            beliefMetrics,
            explain = result.Explain,
            performance = result.Performance,
            aiContext = BuildAiContextObject(result.AiContext),
            mobileSpeedMode = payload.MobileSpeedMode || payload.ForceLightweight,
            forceLightweight = payload.ForceLightweight,
            compactResult = payload.CompactResult,
			reasons = result.Reasons,
            candidateScores = result.CandidateScores,
            candidates = candidateSource
        };
    }

    private static object BuildHellChallengeObject(SichuanHellOracleResult result)
        => new
        {
            ok = true,
            action = result.Action.ActionType.ToString().ToLowerInvariant(),
            tileType = result.Action.TileType,
            score = result.Action.Score,
            shanten = result.SelectedShanten,
            ukeire = result.SelectedLiveUkeire,
            liveUkeire = result.SelectedLiveUkeire,
            waitCount = result.SelectedWaitCount,
            winProbability = 0.0,
            dealInProbability = result.OracleExactDealIn ? 1.0 : 0.0,
            searchUsed = false,
            searchSimulations = 0,
            currentRoutes = result.Candidates
                .Where(item => item.TileType == result.Action.TileType && !string.IsNullOrWhiteSpace(item.OldHandRoute))
                .Select(item => item.OldHandRoute)
                .Distinct()
                .ToArray(),
            routePlan = new
            {
                primaryRoute = result.Candidates
                    .FirstOrDefault(item => item.TileType == result.Action.TileType)?.OldHandRoute ?? "",
                reasons = result.Reasons
            },
            strategyProfile = new
            {
                mode_label = "地狱挑战",
                round_stage = 0,
                round_stage_label = "明牌压制",
                threat_level = result.HumanPressureLevel,
                reasons = result.Reasons
            },
            beliefSummary = new
            {
                compact = true,
                ready_posteriors = Array.Empty<object>(),
                hold_summary = new { top_holders = Array.Empty<object>() },
                wall_summary = new { top_tiles = Array.Empty<object>() },
                wait_summary = new { top_waiters = Array.Empty<object>() },
                unknown_summary = new { top_tiles = Array.Empty<object>() }
            },
            elapsedMs = 0,
            mobileSpeedMode = false,
            compactResult = true,
            backendMode = "hell_challenge_direct",
            category = result.Category,
            severity = result.Severity,
            exactDealIn = result.ExactDealIn,
            oracleExactDealIn = result.OracleExactDealIn,
            oracleFeedsHumanHu = result.OracleFeedsHumanHu,
            oracleFeedsHumanPeng = result.OracleFeedsHumanPeng,
            oracleFeedsHumanGang = result.OracleFeedsHumanGang,
            humanPressureLevel = result.HumanPressureLevel,
            oracleDealInTargetSeats = result.OracleDealInTargetSeats,
            exactKeepsReady = result.ExactKeepsReady,
            exactWallRemaining = result.ExactWallRemaining,
            selectedTier = result.SelectedTier,
            teamRole = result.TeamRole,
            teamPressureBonus = result.TeamPressureBonus,
            teamPlanSummary = result.TeamPlanSummary,
            reasons = result.Reasons,
            candidates = result.Candidates.Select(BuildHellChallengeCandidateObject).ToArray()
        };

    private static object BuildHellChallengeCandidateObject(SichuanHellChallengeCandidate item)
        => new
        {
            tileType = item.TileType,
            score = item.Score,
            shanten = item.Shanten,
            ukeire = 0,
            liveUkeire = item.LiveUkeire,
            danger = item.ExactDealIn || item.FeedsHumanHu ? 100 : item.FeedsHumanGang ? 80 : item.FeedsHumanPeng ? 35 : 0,
            waitCount = item.WaitCount,
            riskLabel = item.FeedsHumanHu || item.ExactDealIn
                ? "点炮"
                : item.FeedsHumanGang
                    ? "给杠"
                    : item.FeedsHumanPeng
                        ? "给碰"
                        : "明牌",
            strategyTag = "hell_challenge",
            strategyMode = "地狱挑战",
            explanationHint = item.Reasons.FirstOrDefault() ?? "",
            routePlanPrimary = item.OldHandRoute,
            routePlanScore = item.OldHandScore,
            expectedNetScore = item.OldHandExpectedNetScore,
            breaksTriplet = item.OldHandBreaksTriplet,
            exactDealIn = item.ExactDealIn,
            feedsHumanHu = item.FeedsHumanHu,
            feedsHumanPeng = item.FeedsHumanPeng,
            feedsHumanGang = item.FeedsHumanGang,
            humanPengThreat = item.HumanPengThreat,
            humanPengPenalty = item.HumanPengPenalty,
            tempoPengAllowanceBonus = item.TempoPengAllowanceBonus,
            pengOnlyInteractionBonus = item.PengOnlyInteractionBonus,
            keepsReady = item.KeepsReady,
            exactWallRemaining = item.ExactWallRemaining,
            tier = item.Tier,
            tierRank = item.TierRank,
            tierAdjustment = item.TierAdjustment,
            oldHandScore = item.OldHandScore,
            oldHandRank = item.OldHandRank,
            oldHandRoute = item.OldHandRoute,
            oldHandExpectedNetScore = item.OldHandExpectedNetScore,
            oldHandBreaksTriplet = item.OldHandBreaksTriplet,
            dealInTargetSeats = item.DealInTargetSeats,
            reasons = item.Reasons
        };

	private object BuildReactionObject(ReactionPayload payload)
	{
        var stopwatch = Stopwatch.StartNew();
        var beforeBelief = SichuanBeliefEngine.GetDiagnostics();
		var state = BuildState(payload);
		if (IsFrozenPolicy(payload))
		{
			var action = _frozenPolicy.DecideReaction(
				state, payload.ReactionTileType, payload.CanHu, payload.CanPeng, payload.CanGang, payload.MandatoryGang);
			stopwatch.Stop();
			return new
			{
				ok = true,
				action = action.ToString().ToLowerInvariant(),
				tileType = payload.ReactionTileType,
				score = 0,
				reason = "测试冻结基线",
				shantenAfter = 0,
				ukeireAfter = 0,
				liveUkeireAfter = 0,
				currentShanten = 0,
				currentLiveUkeire = 0,
				threatLevel = 0,
				roundStage = 0,
				roundStageLabel = "冻结",
				maxReadyPosterior = 0.0,
				reasons = new[] { "测试冻结基线：旧向听/活张硬排序" },
				actionScores = new Dictionary<string, double> { [action.ToString().ToLowerInvariant()] = 0 },
				elapsedMs = stopwatch.ElapsedMilliseconds,
				mobileSpeedMode = false,
				backendMode = "frozen_hard_tier_v1"
			};
		}
		SichuanReactionDecisionResult result;
        result = _facade.DecideReaction(
            state,
            payload.ReactionTileType,
            payload.CanHu,
            payload.CanPeng,
            payload.CanGang,
            payload.SourceSeat,
            payload.ReactionType,
            payload.MobileSpeedMode,
            payload.MandatoryGang);
        stopwatch.Stop();
        var beliefMetrics = BuildBeliefMetrics(beforeBelief, SichuanBeliefEngine.GetDiagnostics());

        return new
        {
            ok = true,
            action = result.Action.ActionType.ToString().ToLowerInvariant(),
            tileType = result.Action.TileType,
            score = result.Action.Score,
            reason = result.Action.Reason,
            shantenAfter = result.ShantenAfter,
            ukeireAfter = result.UkeireAfter,
            liveUkeireAfter = result.LiveUkeireAfter,
            currentShanten = result.CurrentShanten,
            currentLiveUkeire = result.CurrentLiveUkeire,
            threatLevel = result.ThreatLevel,
            roundStage = result.RoundStage,
            roundStageLabel = RoundStageLabel(result.RoundStage),
            maxReadyPosterior = result.MaxReadyPosterior,
            reasons = result.Reasons,
            posteriorSummary = result.PosteriorSummary,
            futureSummary = result.FutureSummary,
            searchBonus = result.SearchBonus,
            searchSimulations = result.SearchSimulations,
            searchUsed = result.SearchUsed,
            actionScores = result.ActionScores,
            elapsedMs = stopwatch.ElapsedMilliseconds,
            beliefMetrics,
            mobileSpeedMode = payload.MobileSpeedMode,
            backendMode = "hybrid_csharp_native"
        };
    }

    private object BuildHellChallengeReactionObject(HellChallengeReactionPayload payload)
    {
        var stopwatch = Stopwatch.StartNew();
        var state = BuildState(payload);
        var result = _hellChallengeReaction.DecideReaction(
            state,
            payload.ReactionTileType,
            payload.CanHu,
            payload.CanPeng,
            payload.CanGang,
            payload.SourceSeat,
            payload.ReactionType,
            payload.AllHands18.Select(item => (IReadOnlyList<int>)item).ToArray(),
            payload.ExactWall18,
            payload.CurrentScores,
            payload.MandatoryGang);
        stopwatch.Stop();

        return new
        {
            ok = true,
            action = result.Action.ActionType.ToString().ToLowerInvariant(),
            tileType = result.Action.TileType,
            score = result.Action.Score,
            reason = result.Action.Reason,
            shantenAfter = result.ShantenAfter,
            ukeireAfter = result.UkeireAfter,
            liveUkeireAfter = result.LiveUkeireAfter,
            currentShanten = result.CurrentShanten,
            currentLiveUkeire = result.CurrentLiveUkeire,
            threatLevel = result.ThreatLevel,
            roundStage = result.RoundStage,
            roundStageLabel = RoundStageLabel(result.RoundStage),
            maxReadyPosterior = result.MaxReadyPosterior,
            reasons = result.Reasons,
            posteriorSummary = result.PosteriorSummary,
            futureSummary = result.FutureSummary,
            searchBonus = result.SearchBonus,
            searchSimulations = result.SearchSimulations,
            searchUsed = result.SearchUsed,
            actionScores = result.ActionScores,
            elapsedMs = stopwatch.ElapsedMilliseconds,
            mobileSpeedMode = false,
            teamPlanPressure = result.ActionScores.GetValueOrDefault("team_plan_pressure", 0),
            backendMode = "hell_challenge_reaction_direct"
        };
    }

    private object BuildSelfActionObject(SelfActionPayload payload)
    {
        var stopwatch = Stopwatch.StartNew();
        var beforeBelief = SichuanBeliefEngine.GetDiagnostics();
        var state = BuildState(payload);
        SichuanSelfActionDecisionResult result;
        result = _facade.DecideSelfAction(
            state,
            payload.CanSelfHu,
            payload.AnGangTileTypes,
            payload.AddGangTileTypes,
            payload.AddGangQiangGangCounts,
            payload.MandatoryGangTileTypes);
        stopwatch.Stop();
        var beliefMetrics = BuildBeliefMetrics(beforeBelief, SichuanBeliefEngine.GetDiagnostics());

        return new
        {
            ok = true,
            action = result.Action.ActionType.ToString().ToLowerInvariant(),
            tileType = result.Action.TileType,
            gangSubtype = result.GangSubtype,
            score = result.Action.Score,
            reason = result.Action.Reason,
            shantenAfter = result.ShantenAfter,
            liveUkeireAfter = result.LiveUkeireAfter,
            reasons = result.Reasons,
            actionScores = result.ActionScores,
            elapsedMs = stopwatch.ElapsedMilliseconds,
            beliefMetrics,
            backendMode = "csharp_native_self_action"
        };
    }

    private object BuildDingQueObject(DingQuePayload payload)
    {
        var result = _facade.DecideDingQue(payload.SuitCounts, payload.ActiveSuits);
        return new
        {
            ok = true,
            action = "ding_que",
            suit = result.Suit,
            score = result.Score,
            reasons = result.Reasons,
            suitCounts = result.SuitCounts,
            backendMode = "csharp_native_ding_que"
        };
    }

    private int StartAsyncRequest(Func<string> compute)
    {
        var requestId = Interlocked.Increment(ref _nextAsyncRequestId);
        var request = new AsyncAiRequest(compute);
        _asyncRequests[requestId] = request;
        try
        {
            var thread = new System.Threading.Thread(() =>
            {
                lock (request.SyncRoot)
                {
                    request.Status = "running";
                    request.ManagedThreadId = System.Environment.CurrentManagedThreadId;
                }

                try
                {
                    var resultJson = request.Compute();
                    lock (request.SyncRoot)
                    {
                        request.ResultJson = string.IsNullOrEmpty(resultJson)
                            ? "{\"ok\":false,\"error\":\"empty_async_ai_result\"}"
                            : resultJson;
                        request.Status = "completed";
                        request.IsCompleted = true;
                    }
                }
                catch (Exception ex)
                {
                    lock (request.SyncRoot)
                    {
                        request.ErrorMessage = ex.GetBaseException().Message;
                        request.Status = "faulted";
                        request.IsCompleted = true;
                    }
                }
            })
            {
                IsBackground = true,
                Name = $"SichuanAI-{requestId}"
            };
            thread.Start();
        }
        catch (Exception ex)
        {
            lock (request.SyncRoot)
            {
                request.ErrorMessage = ex.GetBaseException().Message;
                request.Status = "start_failed";
                request.IsCompleted = true;
            }
        }
        return requestId;
    }

    private static long ElapsedMillisecondsSince(long startedTimestamp)
    {
        return Math.Max(0L, (long)((Stopwatch.GetTimestamp() - startedTimestamp) * 1000.0 / Stopwatch.Frequency));
    }

    private static object BuildBeliefMetrics(SichuanBeliefDiagnostics before, SichuanBeliefDiagnostics after)
    {
        return new
        {
            calls = after.CallCount - before.CallCount,
            cacheHits = after.CacheHits - before.CacheHits,
            cacheMisses = after.CacheMisses - before.CacheMisses,
            builds = after.BuildCount - before.BuildCount,
            buildMs = after.TotalBuildMs - before.TotalBuildMs,
            cacheSize = after.CacheSize
        };
    }

    private static IReadOnlyList<SichuanCandidateDetail> SelectCompactCandidates(SichuanDecisionResult result)
    {
        if (result.Candidates.Count <= 4)
            return result.Candidates;

        var selected = new List<SichuanCandidateDetail>(4);
        var actionTileType = result.Action.TileType;
        var actionCandidate = result.Candidates.FirstOrDefault(item => item.TileType == actionTileType);
        if (actionCandidate is not null)
            selected.Add(actionCandidate);

        foreach (var candidate in result.Candidates)
        {
            if (selected.Any(item => item.TileType == candidate.TileType))
                continue;
            selected.Add(candidate);
            if (selected.Count >= 4)
                break;
        }

        return selected;
    }

    private static object BuildCompactBeliefSummaryObject()
    {
        return new
        {
            compact = true,
            ready_posteriors = Array.Empty<object>(),
            hold_summary = new { top_holders = Array.Empty<object>() },
            wall_summary = new { top_tiles = Array.Empty<object>() },
            wait_summary = new { top_waiters = Array.Empty<object>() },
            unknown_summary = new { top_tiles = Array.Empty<object>() }
        };
    }

    private static object BuildBeliefSummaryObject(SichuanDecisionResult result)
    {
        return new
        {
            ready_posteriors = result.BeliefSummary.ReadyPosteriors.Select(item => new
            {
                seat = item.Seat,
                ready_posterior = item.ReadyPosterior,
                threat_score = item.ThreatScore,
                is_called = item.IsCalled
            }).ToArray(),
            hold_summary = new
            {
                tile_type = result.BeliefSummary.HoldSummary.TileType,
                tile_label = TileLabel(result.BeliefSummary.HoldSummary.TileType),
                top_holders = result.BeliefSummary.HoldSummary.TopHolders.Select(item => new
                {
                    seat = item.Seat,
                    hold_posterior = item.HoldPosterior,
                    tile_danger = item.TileDanger,
                    suit_demand = item.SuitDemand
                }).ToArray()
            },
            wall_summary = new
            {
                average_posterior = result.BeliefSummary.WallSummary.AveragePosterior,
                top_tiles = result.BeliefSummary.WallSummary.TopTiles.Select(item => new
                {
                    tile_type = item.TileType,
                    tile_label = TileLabel(item.TileType),
                    posterior = item.Posterior
                }).ToArray()
            },
            wait_summary = new
            {
                tile_type = result.BeliefSummary.WaitSummary.TileType,
                tile_label = TileLabel(result.BeliefSummary.WaitSummary.TileType),
                top_waiters = result.BeliefSummary.WaitSummary.TopWaiters.Select(item => new
                {
                    seat = item.Seat,
                    wait_posterior = item.WaitPosterior,
                    no_hu_evidence = item.NoHuEvidence,
                    ready_posterior = item.ReadyPosterior
                }).ToArray()
            },
            unknown_summary = new
            {
                total_unknown = result.BeliefSummary.UnknownSummary.TotalUnknown,
                top_tiles = result.BeliefSummary.UnknownSummary.TopTiles.Select(item => new
                {
                    tile_type = item.TileType,
                    tile_label = TileLabel(item.TileType),
                    count = item.Count
                }).ToArray()
            }
        };
    }

    private static object BuildCompactCandidateObject(SichuanCandidateDetail item)
    {
        return new
        {
            tileType = item.TileType,
            fastTingDiscardRank = item.FastTingDiscardRank,
            score = item.Score,
            shanten = item.Shanten,
            ukeire = item.Ukeire,
            liveUkeire = item.LiveUkeire,
            danger = item.Danger,
            waitCount = item.WaitCount,
            waitQualityScore = item.WaitQualityScore,
            riskLabel = item.RiskLabel,
            strategyTag = item.StrategyTag,
            strategyMode = item.StrategyMode,
            explanationHint = item.ExplanationHint,
            routePlanPrimary = item.RoutePlanPrimary,
            routePlanScore = item.RoutePlanScore,
            tenpaiProbability = item.TenpaiProbability,
            selfDrawProbability = item.SelfDrawProbability,
            winProbability = item.WinProbability,
            expectedFan = item.ExpectedFan,
            dealInProbability = item.DealInProbability,
            expectedValue = item.ExpectedValue,
			unifiedActionValue = item.UnifiedActionValue,
			strategicResidual = item.StrategicResidual,
            expectedNetScore = item.ExpectedNetScore,
            expectedWinGain = item.ExpectedWinGain,
            expectedDealInLoss = item.ExpectedDealInLoss,
            expectedDrawRiskLoss = item.ExpectedDrawRiskLoss,
            expectedReadyValue = item.ExpectedReadyValue,
            posteriorAdjustment = item.PosteriorAdjustment,
            defenseAdjustment = item.DefenseAdjustment,
            goodShapeCount = item.GoodShapeCount,
            badShapeCount = item.BadShapeCount,
            pairPressure = item.PairPressure,
            taatsuOverflow = item.TaatsuOverflow,
            sameShantenImprovementCount = item.SameShantenImprovementCount,
            middleTileFlexibility = item.MiddleTileFlexibility,
            shapeScore = item.ShapeScore,
            breaksPair = item.BreaksPair,
            breaksTriplet = item.BreaksTriplet,
            setPreservationScore = item.SetPreservationScore,
            waitShapeLabel = item.WaitShapeLabel,
            waitShapeScore = item.WaitShapeScore,
            ryanmenWaitCount = item.RyanmenWaitCount,
            kanchanWaitCount = item.KanchanWaitCount,
            penchanWaitCount = item.PenchanWaitCount,
            tankiWaitCount = item.TankiWaitCount,
            shanponWaitCount = item.ShanponWaitCount,
            limitedLookaheadScore = item.LimitedLookaheadScore,
            limitedLookaheadSamples = item.LimitedLookaheadSamples,
            limitedLookaheadBestShanten = item.LimitedLookaheadBestShanten,
            limitedLookaheadBestLiveUkeire = item.LimitedLookaheadBestLiveUkeire,
            searchBonus = item.SearchBonus,
            searchSimulations = item.SearchSimulations,
            searchUsed = item.SearchUsed,
            posteriorReasons = item.PosteriorReasons,
            riskReasons = item.RiskReasons,
            reasons = item.Reasons
        };
    }

    private static object BuildFullCandidateObject(SichuanCandidateDetail item)
    {
        return new
        {
            tileType = item.TileType,
            fastTingDiscardRank = item.FastTingDiscardRank,
            score = item.Score,
            shanten = item.Shanten,
            ukeire = item.Ukeire,
            liveUkeire = item.LiveUkeire,
            danger = item.Danger,
            waitCount = item.WaitCount,
            waitQualityScore = item.WaitQualityScore,
            improvingTiles = item.ImprovingTiles,
            riskLabel = item.RiskLabel,
            strategyTag = item.StrategyTag,
            strategyMode = item.StrategyMode,
            explanationHint = item.ExplanationHint,
            routePlanPrimary = item.RoutePlanPrimary,
            routePlanScore = item.RoutePlanScore,
            routesAfter = item.RoutesAfter,
            routeLoss = item.RouteLoss,
            tenpaiProbability = item.TenpaiProbability,
            selfDrawProbability = item.SelfDrawProbability,
            winProbability = item.WinProbability,
            expectedFan = item.ExpectedFan,
            dealInProbability = item.DealInProbability,
            expectedValue = item.ExpectedValue,
			unifiedActionValue = item.UnifiedActionValue,
			strategicResidual = item.StrategicResidual,
            expectedNetScore = item.ExpectedNetScore,
            expectedWinGain = item.ExpectedWinGain,
            expectedDealInLoss = item.ExpectedDealInLoss,
            expectedDrawRiskLoss = item.ExpectedDrawRiskLoss,
            expectedReadyValue = item.ExpectedReadyValue,
            posteriorAdjustment = item.PosteriorAdjustment,
            defenseAdjustment = item.DefenseAdjustment,
            goodShapeCount = item.GoodShapeCount,
            badShapeCount = item.BadShapeCount,
            pairPressure = item.PairPressure,
            taatsuOverflow = item.TaatsuOverflow,
            sameShantenImprovementCount = item.SameShantenImprovementCount,
            middleTileFlexibility = item.MiddleTileFlexibility,
            shapeScore = item.ShapeScore,
            breaksPair = item.BreaksPair,
            breaksTriplet = item.BreaksTriplet,
            setPreservationScore = item.SetPreservationScore,
            waitShapeLabel = item.WaitShapeLabel,
            waitShapeScore = item.WaitShapeScore,
            ryanmenWaitCount = item.RyanmenWaitCount,
            kanchanWaitCount = item.KanchanWaitCount,
            penchanWaitCount = item.PenchanWaitCount,
            tankiWaitCount = item.TankiWaitCount,
            shanponWaitCount = item.ShanponWaitCount,
            limitedLookaheadScore = item.LimitedLookaheadScore,
            limitedLookaheadSamples = item.LimitedLookaheadSamples,
            limitedLookaheadBestShanten = item.LimitedLookaheadBestShanten,
            limitedLookaheadBestLiveUkeire = item.LimitedLookaheadBestLiveUkeire,
            posteriorReasons = item.PosteriorReasons,
            searchBonus = item.SearchBonus,
            searchSimulations = item.SearchSimulations,
            searchUsed = item.SearchUsed,
            riskReasons = item.RiskReasons,
            reasons = item.Reasons
        };
    }

    private static SichuanStateView BuildState(DiscardPayload payload)
    {
        var state = SichuanStateCodec.FromRaw(
            payload.SeatIndex,
            payload.DealerSeat,
            payload.CurrentSeat,
            payload.WallCount,
            payload.Hand18,
            payload.Visible18,
            payload.Remaining18,
            payload.Discards18,
            payload.Melds18,
            payload.PassedHu18,
            payload.PassedPeng18,
            payload.PassedGang18,
            payload.Scores,
            payload.RoundIndex,
            payload.TotalRounds,
            payload.RemainingRounds,
            payload.VisibleVersion,
            payload.HandVersion,
            payload.StrategyContextVersion,
            payload.DingQueSuits,
			payload.HandCounts,
			payload.LockedFans,
			payload.LockTurns,
			payload.UnlockOnOwnDraw,
			payload.ActiveSeats,
			payload.EventVersion,
			payload.InformationMode);

        if (payload.IsCalled is { Length: 4 }) Array.Copy(payload.IsCalled, state.IsCalled, 4);
        if (payload.IsReady is { Length: 4 }) Array.Copy(payload.IsReady, state.IsReady, 4);
        if (payload.HasHu is { Length: 4 }) Array.Copy(payload.HasHu, state.HasHu, 4);
        state.LastDrawTileType = payload.LastDrawTileType;
		state.LastDrawOrigin = payload.LastDrawOrigin;
		state.LastGangSeat = payload.LastGangSeat;
		state.LastGangTileType = payload.LastGangTileType;
		state.LastGangType = payload.LastGangType;
		state.PublicEvents.AddRange(payload.PublicEvents.Where(item => item.TileType is >= -1 and < 27));
		for (var seat = 0; seat < Math.Min(4, payload.MeldViews.Count); seat++)
			state.MeldViews[seat].AddRange(payload.MeldViews[seat].Where(item => item.TileType is >= 0 and < 27));
        return state;
    }

    private static object BuildAiContextObject(SichuanAiContext? context)
    {
        if (context is null)
            return new { enabled = false };
        return new
        {
            enabled = true,
            stage = context.Stage,
            roundGoal = context.RoundGoal,
            strategyMode = context.StrategyMode,
            handAnalysis = context.HandAnalysis,
            attackEligibility = context.AttackEligibility,
            opponentDangerProfiles = context.OpponentDangerProfiles,
            tileDangerMap = context.TileDangerMap,
            scoreSituation = context.ScoreSituation,
            riskTolerance = context.RiskTolerance,
            updatedAtTurn = context.UpdatedAtTurn,
            dirtyFlags = context.DirtyFlags,
            reasonCodes = context.ReasonCodes
        };
    }

    private static object BuildStrategyProfile(SichuanStateView state, SichuanDecisionResult result)
    {
        if (result.AiContext is not null)
        {
            var context = result.AiContext;
            return new
            {
                mode_label = context.StrategyMode.Mode,
                round_stage = context.Stage.StageIndex,
                round_stage_label = context.Stage.Stage,
                threat_level = context.OpponentDangerProfiles.Values.Select(item => item.DangerLevel).DefaultIfEmpty(0).Max(),
                score_situation = context.ScoreSituation.Situation,
                round_goal = context.RoundGoal.Goal,
                risk_tolerance = context.RiskTolerance.Value,
                attack_eligibility = context.AttackEligibility.Level,
                reasons = context.ReasonCodes
            };
        }
        var roundStage = ResolveRoundStage(state);
        var handShape = AnalyzeTwoSuitShape(state);
        var threatSummaries = Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex && !state.HasHu[seat])
            .Select(seat => BuildOpponentThreat(state, seat))
            .ToList();
        var topThreat = threatSummaries.OrderByDescending(item => item.ThreatScore).FirstOrDefault();
        var threatLevel = Math.Clamp(threatSummaries.Sum(item => item.ThreatPoints), 0, 5);
        var flushWatchCount = threatSummaries.Count(item => item.FlushProbability >= 65);
        var pungWatchCount = threatSummaries.Count(item => item.PungProbability >= 55);
        var fastCallCount = threatSummaries.Count(item => item.MeldCount >= 3 || (item.MeldCount >= 2 && item.DiscardsCount >= 6));
        var silentBigHandCount = threatSummaries.Count(item => item.MeldCount == 0 && item.DiscardsCount >= 8);
        var modeLabel = ResolveModeLabel(result.Shanten, result.LiveUkeire, threatLevel, roundStage);

        return new
        {
            mode_label = modeLabel,
            round_stage = roundStage,
            round_stage_label = RoundStageLabel(roundStage),
            threat_level = threatLevel,
            dingque_state = new
            {
                is_two_suit_table = true,
                is_all_same = false,
                is_three_same = false,
                is_two_same_self_diff = false,
                dominant_suit = handShape.DominantSuit,
                dominant_count = handShape.DominantCount,
                support_count = handShape.SupportCount,
                spread = handShape.Spread,
                state_label = handShape.StateLabel
            },
            opponent_state = new
            {
                threat_level = threatLevel,
                fast_call_count = fastCallCount,
                silent_big_hand_count = silentBigHandCount,
                flush_watch_count = flushWatchCount,
                pung_watch_count = pungWatchCount,
                top_threat_profile = topThreat is null ? new { seat = -1, dangerous_suit = "", dangerous_suit_label = "", flush_probability = 0, pung_probability = 0, threat_score = 0 } : new
                {
                    seat = topThreat.Seat,
                    dangerous_suit = topThreat.DangerousSuit,
                    dangerous_suit_label = SuitLabel(topThreat.DangerousSuit),
                    flush_probability = topThreat.FlushProbability,
                    pung_probability = topThreat.PungProbability,
                    threat_score = topThreat.ThreatScore
                }
            },
            reasons = new[]
            {
                $"当前策略 {modeLabel}",
                $"牌局阶段 {RoundStageLabel(roundStage)}",
                $"定缺牌形 {handShape.StateLabel}",
                threatLevel >= 3 ? "桌面对手威胁偏高" : "当前桌面威胁可控"
            }
        };
    }

    private static int ResolveRoundStage(SichuanStateView state)
    {
        if (state.WallCount >= 14) return 0;
        if (state.WallCount >= 8) return 1;
        return 2;
    }

    private static string RoundStageLabel(int roundStage) => roundStage switch
    {
        0 => "前段",
        1 => "中段",
        _ => "后段"
    };

    private static string ResolveModeLabel(int shanten, int liveUkeire, int threatLevel, int roundStage)
    {
        if (shanten <= 0 && liveUkeire >= 4) return "宽叫压制";
        if (shanten <= 1 && threatLevel <= 2) return "抢听进攻";
        if (roundStage >= 2 && threatLevel >= 3) return "收口防反";
        return "定缺速听";
    }

    private static (string DominantSuit, int DominantCount, int SupportCount, int Spread, string StateLabel) AnalyzeTwoSuitShape(SichuanStateView state)
    {
        var suitCounts = new Dictionary<string, int>
        {
            ["tiao"] = 0,
            ["tong"] = 0
        };

        for (var tileType = 0; tileType < Math.Min(18, state.Hand18.Length); tileType++)
        {
            var suit = tileType < 9 ? "tiao" : "tong";
            suitCounts[suit] += state.Hand18[tileType];
        }

        var dominantSuit = suitCounts.OrderByDescending(item => item.Value).First().Key;
        var dominantCount = suitCounts[dominantSuit];
        var supportCount = suitCounts.Where(item => item.Key != dominantSuit).Select(item => item.Value).FirstOrDefault();
        var spread = dominantCount - supportCount;
        var stateLabel = spread switch
        {
            <= 1 => "定缺均衡",
            <= 3 => "轻度偏门",
            _ => "单门偏重"
        };
        return (dominantSuit, dominantCount, supportCount, spread, stateLabel);
    }

    private static OpponentThreatSummary BuildOpponentThreat(SichuanStateView state, int seat)
    {
        var discards = state.Discards18[seat].Count;
        var meldCount = state.Melds18[seat].Count / 3;
        var tiaoVisible = state.Discards18[seat].Count(tile => tile is >= 0 and <= 8);
        var tongVisible = state.Discards18[seat].Count(tile => tile is >= 9 and <= 17);
        var dangerousSuit = tiaoVisible <= tongVisible ? "tiao" : "tong";
        var flushProbability = Math.Clamp(48 + (Math.Abs(tiaoVisible - tongVisible) * 8) + meldCount * 6, 0, 100);
        var pungProbability = Math.Clamp(35 + meldCount * 12, 0, 100);
        var threatScore = Math.Clamp(flushProbability / 4 + pungProbability / 5 + discards, 0, 100);
        var threatPoints = Math.Clamp(threatScore / 20, 0, 5);
        return new OpponentThreatSummary(seat, dangerousSuit, flushProbability, pungProbability, threatScore, threatPoints, meldCount, discards);
    }

    private static object[] EstimateRoutesForCli(SichuanStateView state)
    {
        var routes = new List<object>();
        for (var tileType = 0; tileType < Math.Min(18, state.Hand18.Length); tileType++)
        {
            if (state.Hand18[tileType] <= 0) continue;
            routes.Add(new
            {
                tileType,
                tileLabel = TileLabel(tileType)
            });
            if (routes.Count >= 6) break;
        }
        return routes.ToArray();
    }

    private static string SuitLabel(string suit) => suit switch
    {
        "tiao" => "条",
        "tong" => "筒",
        "wan" => "万",
        _ => suit
    };

    private static string TileLabel(int tileType)
    {
        if (tileType < 0) return "?";
        if (tileType < 9) return $"{tileType + 1}条";
        if (tileType < 18) return $"{tileType - 8}筒";
        if (tileType < 27) return $"{tileType - 17}万";
        return $"T{tileType}";
    }

	private class DiscardPayload
    {
        public int SeatIndex { get; set; }
        public int DealerSeat { get; set; }
        public int CurrentSeat { get; set; }
        public int WallCount { get; set; }
        public int RoundIndex { get; set; }
        public int TotalRounds { get; set; }
        public int RemainingRounds { get; set; }
        public int VisibleVersion { get; set; }
        public int HandVersion { get; set; }
        public int StrategyContextVersion { get; set; }
        public List<int> Scores { get; set; } = new();
        public List<int> DingQueSuits { get; set; } = new();
		public List<int> HandCounts { get; set; } = new();
		public List<int> LockedFans { get; set; } = new();
		public List<int> LockTurns { get; set; } = new();
		public List<bool> UnlockOnOwnDraw { get; set; } = new();
		public List<bool> ActiveSeats { get; set; } = new();
		public long EventVersion { get; set; }
		public string InformationMode { get; set; } = "public";
		public string PolicyVariant { get; set; } = "current";
        public int[] Hand18 { get; set; } = Array.Empty<int>();
        public int[] Visible18 { get; set; } = Array.Empty<int>();
        public int[] Remaining18 { get; set; } = Array.Empty<int>();
        public List<List<int>> Discards18 { get; set; } = new();
        public List<List<int>> Melds18 { get; set; } = new();
		public List<List<SichuanMeldView>> MeldViews { get; set; } = new();
		public List<SichuanPublicEvent> PublicEvents { get; set; } = new();
        public List<List<int>> PassedHu18 { get; set; } = new();
        public List<List<int>> PassedPeng18 { get; set; } = new();
        public List<List<int>> PassedGang18 { get; set; } = new();
        public bool[] IsCalled { get; set; } = Array.Empty<bool>();
        public bool[] IsReady { get; set; } = Array.Empty<bool>();
        public bool[] HasHu { get; set; } = Array.Empty<bool>();
        public int LastDrawTileType { get; set; } = -1;
		public SichuanTileOrigin LastDrawOrigin { get; set; } = SichuanTileOrigin.Unknown;
		public int LastGangSeat { get; set; } = -1;
		public int LastGangTileType { get; set; } = -1;
		public string LastGangType { get; set; } = string.Empty;
        public bool ForceLightweight { get; set; }
        public bool MobileSpeedMode { get; set; }
        public bool CompactResult { get; set; }
	}

	private static bool IsFrozenPolicy(DiscardPayload payload)
		=> string.Equals(payload.PolicyVariant, "frozen_hard_tier_v1", StringComparison.OrdinalIgnoreCase);

    private sealed class ReactionPayload : DiscardPayload
    {
        public int ReactionTileType { get; set; }
        public int SourceSeat { get; set; }
        public string ReactionType { get; set; } = "discard";
        public bool CanHu { get; set; }
        public bool CanPeng { get; set; }
        public bool CanGang { get; set; }
        public bool MandatoryGang { get; set; }
    }

    private sealed class HellChallengeReactionPayload : HellChallengePayload
    {
        public int ReactionTileType { get; set; }
        public int SourceSeat { get; set; }
        public string ReactionType { get; set; } = "discard";
        public bool CanHu { get; set; }
        public bool CanPeng { get; set; }
        public bool CanGang { get; set; }
        public bool MandatoryGang { get; set; }
    }

    private sealed class SelfActionPayload : DiscardPayload
    {
        public bool CanSelfHu { get; set; }
        public List<int> AnGangTileTypes { get; set; } = new();
        public List<int> AddGangTileTypes { get; set; } = new();
        public Dictionary<int, int> AddGangQiangGangCounts { get; set; } = new();
        public List<int> MandatoryGangTileTypes { get; set; } = new();
    }

    private sealed class DingQuePayload
    {
        public Dictionary<string, int> SuitCounts { get; set; } = new();
        public List<string> ActiveSuits { get; set; } = new();
    }

    private class HellChallengePayload : DiscardPayload
    {
        public List<List<int>> AllHands18 { get; set; } = new();
        public List<int> ExactWall18 { get; set; } = new();
        public List<int> CurrentScores { get; set; } = new();
    }

    private sealed class HellOraclePayload : HellChallengePayload
    {
        public int FairTileType { get; set; } = -1;
        public int ActualTileType { get; set; } = -1;
    }

    [JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true, UseStringEnumConverter = true)]
    [JsonSerializable(typeof(DiscardPayload))]
    [JsonSerializable(typeof(ReactionPayload))]
    [JsonSerializable(typeof(SelfActionPayload))]
    [JsonSerializable(typeof(HellChallengePayload))]
    [JsonSerializable(typeof(HellChallengeReactionPayload))]
    private partial class RuntimeJsonContext : JsonSerializerContext
    {
    }

    private sealed record OpponentThreatSummary(
        int Seat,
        string DangerousSuit,
        int FlushProbability,
        int PungProbability,
        int ThreatScore,
        int ThreatPoints,
        int MeldCount,
        int DiscardsCount);
}
