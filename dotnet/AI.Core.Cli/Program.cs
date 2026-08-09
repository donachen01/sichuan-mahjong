using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Learning;
using SichuanMahjong.AI.Core.Models;

var options = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    WriteIndented = false,
    Converters = { new JsonStringEnumConverter() }
};

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: AI.Core.Cli <discard-json|reaction-json|self-action-json|ding-que-json|host-tcp> [args]");
    return 2;
}

return args[0] switch
{
    "discard-json" => await RunDiscardJsonAsync(args.Skip(1).ToArray(), options),
    "hell-discard-json" => await RunHellDiscardJsonAsync(args.Skip(1).ToArray(), options),
    "reaction-json" => await RunReactionJsonAsync(args.Skip(1).ToArray(), options),
    "self-action-json" => await RunSelfActionJsonAsync(args.Skip(1).ToArray(), options),
    "ding-que-json" => await RunDingQueJsonAsync(args.Skip(1).ToArray(), options),
    "learning-record" => await RunLearningRecordAsync(args.Skip(1).ToArray(), options),
    "host-tcp" => await RunHostTcpAsync(args.Skip(1).ToArray(), options),
    _ => 2
};

static async Task<int> RunDiscardJsonAsync(string[] args, JsonSerializerOptions options)
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: AI.Core.Cli discard-json <payload.json>");
        return 2;
    }

    var payloadPath = args[0];
    if (!File.Exists(payloadPath))
    {
        Console.Error.WriteLine($"Payload file not found: {payloadPath}");
        return 3;
    }

    var payload = JsonSerializer.Deserialize<DiscardPayload>(await File.ReadAllTextAsync(payloadPath), options);
    if (payload is null)
    {
        Console.Error.WriteLine("Invalid payload");
        return 4;
    }

    var facade = new SichuanAiFacade();
    var output = BuildDiscardOutput(facade, payload, options);
    Console.WriteLine(output);
    return 0;
}

static async Task<int> RunHellDiscardJsonAsync(string[] args, JsonSerializerOptions options)
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: AI.Core.Cli hell-discard-json <payload.json>");
        return 2;
    }

    var payloadPath = args[0];
    if (!File.Exists(payloadPath))
    {
        Console.Error.WriteLine($"Payload file not found: {payloadPath}");
        return 3;
    }

    var payload = JsonSerializer.Deserialize<HellDiscardPayload>(await File.ReadAllTextAsync(payloadPath), options);
    if (payload is null)
    {
        Console.Error.WriteLine("Invalid hell discard payload");
        return 4;
    }

    var facade = new SichuanAiFacade();
    var state = BuildState(payload);
    state.InformationMode = "oracle";
    var result = new SichuanHellChallengeEngine(facade).DecideDiscard(
        state,
        payload.AllHands18.Select(hand => (IReadOnlyList<int>)hand).ToArray(),
        payload.ExactWall18,
        payload.CurrentScores);
    Console.WriteLine(JsonSerializer.Serialize(new
    {
        action = result.Action.ActionType.ToString().ToLowerInvariant(),
        tileType = result.Action.TileType,
        score = result.Action.Score,
        preset = "hell",
        informationMode = "oracle",
        mobileSpeedMode = false,
        compactResult = payload.CompactResult,
        result.HumanPressureLevel,
        result.SelectedShanten,
        result.SelectedLiveUkeire,
        result.SelectedWaitCount,
        result.SelectedTier,
        result.ExactWallRemaining,
        candidates = result.Candidates.Select(item => new
        {
            item.TileType,
            item.Score,
            item.Shanten,
            item.LiveUkeire,
            item.WaitCount,
            item.ExactDealIn,
            item.FeedsHumanHu,
            item.FeedsHumanPeng,
            item.FeedsHumanGang,
            item.ExactWallRemaining,
            item.Tier,
            item.OldHandRoute,
            item.OldHandExpectedNetScore
        })
    }, options));
    return 0;
}

static async Task<int> RunReactionJsonAsync(string[] args, JsonSerializerOptions options)
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: AI.Core.Cli reaction-json <payload.json>");
        return 2;
    }

    var payloadPath = args[0];
    if (!File.Exists(payloadPath))
    {
        Console.Error.WriteLine($"Payload file not found: {payloadPath}");
        return 3;
    }

    var payload = JsonSerializer.Deserialize<ReactionPayload>(await File.ReadAllTextAsync(payloadPath), options);
    if (payload is null)
    {
        Console.Error.WriteLine("Invalid reaction payload");
        return 4;
    }

    var facade = new SichuanAiFacade();
    var output = BuildReactionOutput(facade, payload, options);
    Console.WriteLine(output);
    return 0;
}

static async Task<int> RunSelfActionJsonAsync(string[] args, JsonSerializerOptions options)
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: AI.Core.Cli self-action-json <payload.json>");
        return 2;
    }

    var payloadPath = args[0];
    if (!File.Exists(payloadPath))
    {
        Console.Error.WriteLine($"Payload file not found: {payloadPath}");
        return 3;
    }

    var payload = JsonSerializer.Deserialize<SelfActionPayload>(await File.ReadAllTextAsync(payloadPath), options);
    if (payload is null)
    {
        Console.Error.WriteLine("Invalid self action payload");
        return 4;
    }

    var facade = new SichuanAiFacade();
    var output = BuildSelfActionOutput(facade, payload, options);
    Console.WriteLine(output);
    return 0;
}

static async Task<int> RunDingQueJsonAsync(string[] args, JsonSerializerOptions options)
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: AI.Core.Cli ding-que-json <payload.json>");
        return 2;
    }

    var payloadPath = args[0];
    if (!File.Exists(payloadPath))
    {
        Console.Error.WriteLine($"Payload file not found: {payloadPath}");
        return 3;
    }

    var payload = JsonSerializer.Deserialize<DingQuePayload>(await File.ReadAllTextAsync(payloadPath), options);
    if (payload is null)
    {
        Console.Error.WriteLine("Invalid ding que payload");
        return 4;
    }

    var facade = new SichuanAiFacade();
    var output = BuildDingQueOutput(facade, payload, options);
    Console.WriteLine(output);
    return 0;
}

static async Task<int> RunLearningRecordAsync(string[] args, JsonSerializerOptions options)
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: AI.Core.Cli learning-record <payload.json>");
        return 2;
    }

    var payloadPath = args[0];
    if (!File.Exists(payloadPath))
    {
        Console.Error.WriteLine($"Payload file not found: {payloadPath}");
        return 3;
    }

    var payload = JsonSerializer.Deserialize<LearningRecordPayload>(await File.ReadAllTextAsync(payloadPath), options);
    if (payload is null)
    {
        Console.Error.WriteLine("Invalid learning payload");
        return 4;
    }

    var engine = new SichuanLearningEngine();
    var profile = engine.RecordHumanRound(
        payload.LearningFilePath,
        payload.LearningHistoryFilePath,
        payload.RoundResult);
    var output = new
    {
        ok = true,
        totalHumanRounds = profile.TotalHumanRounds,
        parameterBias = profile.ParameterBias,
        parameterAdjustments = profile.ParameterAdjustments,
        lastAdjustmentReasons = profile.LastAdjustmentReasons
    };
    Console.WriteLine(JsonSerializer.Serialize(output, options));
    return 0;
}

static async Task<int> RunHostTcpAsync(string[] args, JsonSerializerOptions options)
{
    var port = ResolvePort(args);
    var facade = new SichuanAiFacade();
    TcpListener listener;
    try
    {
        listener = new TcpListener(IPAddress.Loopback, port);
        listener.Start();
    }
    catch (SocketException ex) when (ex.SocketErrorCode == SocketError.AddressAlreadyInUse)
    {
        Console.Error.WriteLine($"AI host already listening on 127.0.0.1:{port}");
        return 0;
    }
    Console.Error.WriteLine($"AI host listening on 127.0.0.1:{port}");

    while (true)
    {
        using var client = await listener.AcceptTcpClientAsync();
        client.NoDelay = true;
        await HandleClientAsync(client, facade, options);
    }
}

static async Task HandleClientAsync(TcpClient client, SichuanAiFacade facade, JsonSerializerOptions options)
{
    await using var stream = client.GetStream();
    using var reader = new StreamReader(stream, Encoding.UTF8, false, 4096, leaveOpen: true);
    await using var writer = new StreamWriter(stream, new UTF8Encoding(false), 4096, leaveOpen: true)
    {
        AutoFlush = true
    };

    while (true)
    {
        var line = await reader.ReadLineAsync();
        if (line is null)
        {
            return;
        }

        HostRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<HostRequest>(line, options);
        }
        catch (JsonException ex)
        {
            await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
            {
                Ok = false,
                Error = $"invalid_json:{ex.Message}"
            }, options));
            continue;
        }

        if (request is null)
        {
            await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
            {
                Ok = false,
                Error = "empty_request"
            }, options));
            continue;
        }

        if (string.Equals(request.Action, "shutdown", StringComparison.OrdinalIgnoreCase))
        {
            await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse { Ok = true }, options));
            return;
        }

        if (string.Equals(request.Action, "discard", StringComparison.OrdinalIgnoreCase))
        {
            if (request.Payload is null)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = "missing_discard_payload"
                }, options));
                continue;
            }

            try
            {
                var output = BuildDiscardObject(facade, request.Payload);
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = true,
                    Result = output
                }, options));
            }
            catch (Exception ex)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = ex.Message
                }, options));
            }
            continue;
        }

        if (string.Equals(request.Action, "reaction", StringComparison.OrdinalIgnoreCase))
        {
            if (request.ReactionPayload is null)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = "missing_reaction_payload"
                }, options));
                continue;
            }

            try
            {
                var output = BuildReactionObject(facade, request.ReactionPayload);
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = true,
                    Result = output
                }, options));
            }
            catch (Exception ex)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = ex.Message
                }, options));
            }
            continue;
        }

        if (string.Equals(request.Action, "self_action", StringComparison.OrdinalIgnoreCase)
            || string.Equals(request.Action, "self-action", StringComparison.OrdinalIgnoreCase))
        {
            if (request.SelfActionPayload is null)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = "missing_self_action_payload"
                }, options));
                continue;
            }

            try
            {
                var output = BuildSelfActionObject(facade, request.SelfActionPayload);
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = true,
                    Result = output
                }, options));
            }
            catch (Exception ex)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = ex.Message
                }, options));
            }
            continue;
        }

        if (string.Equals(request.Action, "ding_que", StringComparison.OrdinalIgnoreCase)
            || string.Equals(request.Action, "ding-que", StringComparison.OrdinalIgnoreCase))
        {
            if (request.DingQuePayload is null)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = "missing_ding_que_payload"
                }, options));
                continue;
            }

            try
            {
                var output = BuildDingQueObject(facade, request.DingQuePayload);
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = true,
                    Result = output
                }, options));
            }
            catch (Exception ex)
            {
                await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
                {
                    Ok = false,
                    Error = ex.Message
                }, options));
            }
            continue;
        }

        await writer.WriteLineAsync(JsonSerializer.Serialize(new HostResponse
        {
            Ok = false,
            Error = "unsupported_action"
        }, options));
    }
}

static int ResolvePort(string[] args)
{
    foreach (var arg in args)
    {
        if (arg.StartsWith("--port=", StringComparison.OrdinalIgnoreCase) &&
            int.TryParse(arg["--port=".Length..], out var inlinePort))
        {
            return inlinePort;
        }
    }

    for (var index = 0; index < args.Length - 1; index++)
    {
        if (string.Equals(args[index], "--port", StringComparison.OrdinalIgnoreCase) &&
            int.TryParse(args[index + 1], out var separatePort))
        {
            return separatePort;
        }
    }

    return 38581;
}

static string BuildDiscardOutput(SichuanAiFacade facade, DiscardPayload payload, JsonSerializerOptions options)
{
    var output = BuildDiscardObject(facade, payload);
    return JsonSerializer.Serialize(output, options);
}

static string BuildReactionOutput(SichuanAiFacade facade, ReactionPayload payload, JsonSerializerOptions options)
{
    var output = BuildReactionObject(facade, payload);
    return JsonSerializer.Serialize(output, options);
}

static string BuildSelfActionOutput(SichuanAiFacade facade, SelfActionPayload payload, JsonSerializerOptions options)
{
    var output = BuildSelfActionObject(facade, payload);
    return JsonSerializer.Serialize(output, options);
}

static string BuildDingQueOutput(SichuanAiFacade facade, DingQuePayload payload, JsonSerializerOptions options)
{
    var output = BuildDingQueObject(facade, payload);
    return JsonSerializer.Serialize(output, options);
}

static object BuildDiscardObject(SichuanAiFacade facade, DiscardPayload payload)
{
    var state = BuildState(payload);
    var result = facade.DecideDiscardCached(
        state,
        forceLightweight: payload.MobileSpeedMode || payload.ForceLightweight);
    var cacheSnapshot = facade.GetTurnCacheSnapshot();
    var strategyProfile = BuildStrategyProfile(state, result);
    var currentRoutes = EstimateRoutesForCli(state);
    return new
    {
        action = result.Action.ActionType.ToString().ToLowerInvariant(),
        tileType = result.Action.TileType,
        gangSubtype = result.GangSubtype,
        score = result.Action.Score,
        shanten = result.Shanten,
        ukeire = result.Ukeire,
        liveUkeire = result.LiveUkeire,
        winProbability = result.WinProbability,
        dealInProbability = result.DealInProbability,
        searchUsed = result.SearchUsed,
        searchSimulations = result.SearchSimulations,
        mobileSpeedMode = payload.MobileSpeedMode,
        forceLightweight = payload.ForceLightweight,
        compactResult = payload.CompactResult,
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
        beliefSummary = new
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
        },
        cache = new
        {
            count = cacheSnapshot.Count,
            capacity = cacheSnapshot.Capacity,
            hits = cacheSnapshot.Hits,
            misses = cacheSnapshot.Misses
        },
        explain = result.Explain,
        performance = result.Performance,
        aiContext = BuildAiContextObject(result.AiContext),
        reasons = result.Reasons,
        candidateScores = result.CandidateScores,
        candidates = result.Candidates.Select(item => new
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
        }).ToArray()
    };
}

static object BuildReactionObject(SichuanAiFacade facade, ReactionPayload payload)
{
    var state = BuildState(payload);
    var result = facade.DecideReaction(
        state,
        payload.ReactionTileType,
        payload.CanHu,
        payload.CanPeng,
        payload.CanGang,
        payload.SourceSeat,
        payload.ReactionType,
        payload.MobileSpeedMode,
        payload.MandatoryGang);
    return new
    {
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
        backendMode = "hybrid_csharp"
    };
}

static object BuildSelfActionObject(SichuanAiFacade facade, SelfActionPayload payload)
{
    var state = BuildState(payload);
    var result = facade.DecideSelfAction(
        state,
        payload.CanSelfHu,
        payload.AnGangTileTypes,
        payload.AddGangTileTypes,
        payload.AddGangQiangGangCounts,
        payload.MandatoryGangTileTypes);
    return new
    {
        action = result.Action.ActionType.ToString().ToLowerInvariant(),
        tileType = result.Action.TileType,
        gangSubtype = result.GangSubtype,
        score = result.Action.Score,
        reason = result.Action.Reason,
        shantenAfter = result.ShantenAfter,
        liveUkeireAfter = result.LiveUkeireAfter,
        reasons = result.Reasons,
        actionScores = result.ActionScores,
        backendMode = "csharp_self_action"
    };
}

static object BuildDingQueObject(SichuanAiFacade facade, DingQuePayload payload)
{
    var result = facade.DecideDingQue(payload.SuitCounts, payload.ActiveSuits);
    return new
    {
        action = "ding_que",
        suit = result.Suit,
        score = result.Score,
        reasons = result.Reasons,
        suitCounts = result.SuitCounts,
        backendMode = "csharp_ding_que"
    };
}

static SichuanStateView BuildState(DiscardPayload payload)
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
	for (var seat = 0; seat < Math.Min(4, payload.MeldViews.Length); seat++)
		state.MeldViews[seat].AddRange(payload.MeldViews[seat].Where(item => item.TileType is >= 0 and < 27));
    return state;
}

static object BuildAiContextObject(SichuanAiContext? context)
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

static object BuildStrategyProfile(SichuanStateView state, SichuanDecisionResult result)
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

static int ResolveRoundStage(SichuanStateView state)
{
    var maxDiscards = state.Discards18.Max(list => list.Count);
    if (state.WallCount >= 14 && maxDiscards <= 5) return 0;
    if (state.WallCount >= 8 && maxDiscards <= 11) return 1;
    return 2;
}

static string RoundStageLabel(int roundStage) => roundStage switch
{
    0 => "前期",
    1 => "中期",
    _ => "后期"
};

static string ResolveModeLabel(int shanten, int liveUkeire, int threatLevel, int roundStage)
{
    if (roundStage >= 2 && threatLevel >= 3 && shanten >= 1) return "防炮收守";
    if (shanten <= 0 && liveUkeire >= 8) return "宽叫压制";
    if (shanten <= 1) return "快速成叫";
    return "定缺速听";
}

static (string DominantSuit, int DominantCount, int SupportCount, int Spread, string StateLabel) AnalyzeTwoSuitShape(SichuanStateView state)
{
    var tiaoCount = 0;
    var tongCount = 0;
    for (var tileType = 0; tileType < state.Hand18.Length; tileType++)
    {
        var count = state.Hand18[tileType];
        if (count <= 0) continue;
        if (tileType < 9) tiaoCount += count;
        else tongCount += count;
    }
    foreach (var meldTile in state.Melds18[state.SeatIndex])
    {
        if (meldTile < 9) tiaoCount++;
        else tongCount++;
    }

    var dominantSuit = tiaoCount >= tongCount ? "tiao" : "tong";
    var dominantCount = Math.Max(tiaoCount, tongCount);
    var supportCount = Math.Min(tiaoCount, tongCount);
    var spread = Math.Abs(tiaoCount - tongCount);
    var stateLabel = spread >= 4 ? "单门偏重" : spread >= 2 ? "轻度偏门" : "定缺均衡";
    return (dominantSuit, dominantCount, supportCount, spread, stateLabel);
}

static OpponentThreatSummary BuildOpponentThreat(SichuanStateView state, int seat)
{
    var meldCount = state.Melds18[seat].Count / 3;
    var discardsCount = state.Discards18[seat].Count;
    var dangerousSuit = ResolveDangerousSuit(state, seat);
    var flushProbability = EstimateFlushProbability(state, seat, dangerousSuit);
    var pungProbability = EstimatePungProbability(state, seat);
    var threatScore = meldCount * 16
        + (discardsCount >= 10 ? 12 : discardsCount >= 7 ? 7 : 0)
        + (int)Math.Round(flushProbability * 0.16)
        + (int)Math.Round(pungProbability * 0.14)
        + (state.IsCalled[seat] ? 26 : 0);
    var threatPoints = 0;
    if (meldCount >= 3 || (meldCount >= 2 && discardsCount >= 6)) threatPoints += 2;
    else if (meldCount >= 1) threatPoints += 1;
    if (meldCount == 0 && discardsCount >= 8) threatPoints += 1;
    if (flushProbability >= 65) threatPoints += 1;
    if (pungProbability >= 55) threatPoints += 1;
    if (state.IsCalled[seat]) threatPoints += 1;

    return new OpponentThreatSummary(seat, meldCount, discardsCount, dangerousSuit, flushProbability, pungProbability, threatScore, threatPoints);
}

static string ResolveDangerousSuit(SichuanStateView state, int seat)
{
    var meldCounts = new[] { 0, 0 };
    foreach (var tile in state.Melds18[seat])
    {
        var suitIndex = tile / 9;
        if (suitIndex is >= 0 and < 2) meldCounts[suitIndex]++;
    }
    if (meldCounts[0] > meldCounts[1]) return "tiao";
    if (meldCounts[1] > meldCounts[0]) return "tong";

    var discardCounts = new[] { 0, 0 };
    foreach (var tile in state.Discards18[seat])
    {
        var suitIndex = tile / 9;
        if (suitIndex is >= 0 and < 2) discardCounts[suitIndex]++;
    }
    return discardCounts[0] <= discardCounts[1] ? "tiao" : "tong";
}

static int EstimateFlushProbability(SichuanStateView state, int seat, string dangerousSuit)
{
    if (string.IsNullOrEmpty(dangerousSuit)) return 0;
    var suitIndex = dangerousSuit == "tong" ? 1 : 0;
    var meldTiles = state.Melds18[seat].Count;
    var suitTiles = state.Melds18[seat].Count(tile => tile / 9 == suitIndex);
    var ratio = meldTiles == 0 ? 0.0 : (double)suitTiles / meldTiles;
    var score = (int)Math.Round(ratio * 100.0);
    if (meldTiles >= 6 && ratio >= 0.75) score += 18;
    return Math.Clamp(score, 0, 100);
}

static int EstimatePungProbability(SichuanStateView state, int seat)
{
    var score = 0;
    for (var index = 0; index < state.Melds18[seat].Count; index += 3)
    {
        score += 26;
    }
    if (state.Discards18[seat].Count >= 8 && score > 0) score += 10;
    return Math.Clamp(score, 0, 100);
}

static string SuitLabel(string suit) => suit switch
{
    "tiao" => "条",
    "tong" => "筒",
    "wan" => "万",
    _ => suit
};

static string TileLabel(int tileType)
{
    if (tileType is < 0 or >= 27) return "?";
    var suitLabel = tileType < 9 ? "条" : tileType < 18 ? "筒" : "万";
    var rank = tileType % 9 + 1;
    return $"{rank}{suitLabel}";
}

static IReadOnlyList<string> EstimateRoutesForCli(SichuanStateView state)
{
    var counts = new Dictionary<int, int>();
    var pairCount = 0;
    var tripleLike = 0;
    var suitCounts = new Dictionary<int, int>();
    for (var tileType = 0; tileType < state.Hand18.Length; tileType++)
    {
        var count = state.Hand18[tileType];
        if (count <= 0) continue;
        counts[tileType] = count;
        var suitIndex = tileType / 9;
        suitCounts[suitIndex] = suitCounts.GetValueOrDefault(suitIndex, 0) + count;
        if (count >= 2) pairCount++;
        if (count >= 3) tripleLike++;
    }

    var routes = new List<string>();
    if (pairCount >= 5) routes.Add("七对");
    if (tripleLike >= 2) routes.Add("大对子");
    if (suitCounts.Count > 0 && suitCounts.MaxBy(item => item.Value).Value >= 10) routes.Add("清一色");
    if (routes.Count == 0) routes.Add("平胡");
    return routes;
}

internal class DiscardPayload
{
    public int SeatIndex { get; init; }
    public int DealerSeat { get; init; }
    public int CurrentSeat { get; init; }
    public int WallCount { get; init; }
    public int RoundIndex { get; init; }
    public int TotalRounds { get; init; }
    public int RemainingRounds { get; init; }
    public int VisibleVersion { get; init; }
    public int HandVersion { get; init; }
    public int StrategyContextVersion { get; init; }
    public int[] Scores { get; init; } = Array.Empty<int>();
    public int[] DingQueSuits { get; init; } = Array.Empty<int>();
	public int[] HandCounts { get; init; } = Array.Empty<int>();
	public int[] LockedFans { get; init; } = Array.Empty<int>();
	public int[] LockTurns { get; init; } = Array.Empty<int>();
	public bool[] UnlockOnOwnDraw { get; init; } = Array.Empty<bool>();
	public bool[] ActiveSeats { get; init; } = Array.Empty<bool>();
	public long EventVersion { get; init; }
	public string InformationMode { get; init; } = "public";
    public int[] Hand18 { get; init; } = Array.Empty<int>();
    public int[] Visible18 { get; init; } = Array.Empty<int>();
    public int[] Remaining18 { get; init; } = Array.Empty<int>();
    public List<int>[] Discards18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
    public List<int>[] Melds18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
	public List<SichuanMeldView>[] MeldViews { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<SichuanMeldView>()).ToArray();
	public List<SichuanPublicEvent> PublicEvents { get; init; } = new();
    public List<int>[] PassedHu18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
    public List<int>[] PassedPeng18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
    public List<int>[] PassedGang18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
    public bool[]? IsCalled { get; init; }
    public bool[]? IsReady { get; init; }
    public bool[]? HasHu { get; init; }
    public int LastDrawTileType { get; init; } = -1;
	public SichuanTileOrigin LastDrawOrigin { get; init; } = SichuanTileOrigin.Unknown;
	public int LastGangSeat { get; init; } = -1;
	public int LastGangTileType { get; init; } = -1;
	public string LastGangType { get; init; } = string.Empty;
    public bool MobileSpeedMode { get; init; }
    public bool ForceLightweight { get; init; }
    public bool CompactResult { get; init; }
}

internal sealed class ReactionPayload : DiscardPayload
{
    public int ReactionTileType { get; init; } = -1;
    public int SourceSeat { get; init; } = -1;
    public string ReactionType { get; init; } = "discard";
    public bool CanHu { get; init; }
    public bool CanPeng { get; init; }
    public bool CanGang { get; init; }
    public bool MandatoryGang { get; init; }
}

internal sealed class HellDiscardPayload : DiscardPayload
{
    public int[][] AllHands18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    public int[] ExactWall18 { get; init; } = new int[27];
    public int[] CurrentScores { get; init; } = new int[4];
}

internal sealed class SelfActionPayload : DiscardPayload
{
    public bool CanSelfHu { get; init; }
    public List<int> AnGangTileTypes { get; init; } = new();
    public List<int> AddGangTileTypes { get; init; } = new();
    public Dictionary<int, int> AddGangQiangGangCounts { get; init; } = new();
    public List<int> MandatoryGangTileTypes { get; init; } = new();
}

internal sealed class DingQuePayload
{
    public Dictionary<string, int> SuitCounts { get; init; } = new();
    public List<string> ActiveSuits { get; init; } = new();
}

internal sealed class HostRequest
{
    public string Action { get; init; } = "";
    public DiscardPayload? Payload { get; init; }
    public ReactionPayload? ReactionPayload { get; init; }
    public SelfActionPayload? SelfActionPayload { get; init; }
    public DingQuePayload? DingQuePayload { get; init; }
}

internal sealed class HostResponse
{
    public bool Ok { get; init; }
    public object? Result { get; init; }
    public string? Error { get; init; }
}

internal sealed record OpponentThreatSummary(
    int Seat,
    int MeldCount,
    int DiscardsCount,
    string DangerousSuit,
    int FlushProbability,
    int PungProbability,
    int ThreatScore,
    int ThreatPoints);
