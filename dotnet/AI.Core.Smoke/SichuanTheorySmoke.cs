using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Evaluation;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using System.Text.Json;

internal static class SichuanTheorySmoke
{
    public static bool RecognizesClassicFlushWaits()
    {
        var cases = new[]
        {
            (tiles: new[] { 1, 1, 2, 2, 2, 3, 3 }, meldCount: 2, waits: new[] { 1, 2, 3 }),
            (tiles: new[] { 4, 4, 4, 5, 6, 6, 6 }, meldCount: 2, waits: new[] { 3, 4, 5, 6, 7 }),
            (tiles: new[] { 3, 4, 5, 5, 5, 8, 8 }, meldCount: 2, waits: new[] { 2, 5, 8 })
        };
        var shanten = new SichuanShantenEngine();
        foreach (var item in cases)
        {
            var hand = SichuanTileCodec.BuildCount18(item.tiles);
            var actual = Enumerable.Range(0, 9)
                .Where(tile => hand[tile] < 4)
                .Where(tile =>
                {
                    hand[tile]++;
                    var complete = shanten.CalcStandardShanten(hand, item.meldCount) == -1;
                    hand[tile]--;
                    return complete;
                })
                .ToArray();
            Console.WriteLine($"theory_flush_waits hand={string.Join(',', item.tiles)} actual={string.Join(',', actual)} expected={string.Join(',', item.waits)}");
            if (!actual.SequenceEqual(item.waits))
                return false;
        }
        return true;
    }

    public static bool OpponentBigHandShiftsTowardFastReady()
    {
        var planner = new SichuanRoutePlanEngine();
        var hand = SichuanTileCodec.BuildCount18(new[] { 0, 0, 2, 2, 9, 9, 11, 11, 18, 18, 4, 6, 15, 24 });
        var calm = SichuanStateCodec.FromRaw(1, 0, 1, 12, hand, new int[27], roundIndex: 904);
        var calmPlan = planner.Evaluate(calm);

        var discards = new[]
        {
            new List<int>(),
            new List<int>(),
            new List<int> { 0, 9, 1, 10, 2, 12, 3, 13 },
            new List<int>()
        };
        var melds = new[]
        {
            new List<int>(),
            new List<int>(),
            new List<int> { 18, 18, 18, 19, 19, 19, 20, 20, 20 },
            new List<int>()
        };
        var threatened = SichuanStateCodec.FromRaw(
            1, 0, 1, 12, hand, new int[27], discards18: discards, melds18: melds, roundIndex: 904);
        threatened.IsReady[2] = true;
        var threatenedPlan = planner.Evaluate(threatened);

        var calmPing = calmPlan.RouteWeights.GetValueOrDefault("平胡");
        var threatPing = threatenedPlan.RouteWeights.GetValueOrDefault("平胡");
        var calmSeven = MaxSevenPairsWeight(calmPlan.RouteWeights);
        var threatSeven = MaxSevenPairsWeight(threatenedPlan.RouteWeights);
        Console.WriteLine($"theory_threat_shift calm={calmPlan.PrimaryRoute}/{calmPing}/{calmSeven} threat={threatenedPlan.PrimaryRoute}/{threatPing}/{threatSeven}");
        return threatPing > calmPing && threatSeven < calmSeven;
    }

    public static bool DingQueWidthRaisesFlushValue()
    {
        var planner = new SichuanRoutePlanEngine();
        var hand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 9, 10, 13, 16 });
        var narrow = SichuanStateCodec.FromRaw(
            1, 0, 1, 30, hand, new int[27], roundIndex: 905, dingQueSuits: new[] { 2, 2, 2, 1 });
        var wide = SichuanStateCodec.FromRaw(
            1, 0, 1, 30, hand, new int[27], roundIndex: 906, dingQueSuits: new[] { 0, 2, 0, 0 });
        var narrowScore = planner.Evaluate(narrow).RouteWeights.GetValueOrDefault("清一色");
        var wideScore = planner.Evaluate(wide).RouteWeights.GetValueOrDefault("清一色");
        Console.WriteLine($"theory_dingque_width narrow={narrowScore} wide={wideScore}");
        return wideScore > narrowScore;
    }

    public static bool ExactAnalyzerEnumeratesClassicFlushWaits()
    {
        var analyzer = new SichuanExactHandAnalyzer();
        var cases = new[]
        {
            (tiles: new[] { 1, 1, 2, 2, 2, 3, 3 }, meldCount: 2, waits: new[] { 1, 2, 3 }),
            (tiles: new[] { 4, 4, 4, 5, 6, 6, 6 }, meldCount: 2, waits: new[] { 3, 4, 5, 6, 7 }),
            (tiles: new[] { 3, 4, 4, 4, 4, 5, 5 }, meldCount: 2, waits: new[] { 2, 3, 5, 6 }),
            (tiles: new[] { 3, 4, 5, 5, 5, 8, 8 }, meldCount: 2, waits: new[] { 2, 5, 8 }),
            (tiles: new[] { 4, 4, 4, 5, 5, 6, 6 }, meldCount: 2, waits: new[] { 4, 5, 6, 7 })
        };
        foreach (var item in cases)
        {
            var hand = SichuanTileCodec.BuildCount18(item.tiles);
            var actual = analyzer.EnumerateWaits(hand, Enumerable.Repeat(4, 27).ToArray(), item.meldCount).Select(wait => wait.TileType).ToArray();
            Console.WriteLine($"exact_flush_waits hand={string.Join(',', item.tiles)} actual={string.Join(',', actual)} expected={string.Join(',', item.waits)}");
            if (!actual.SequenceEqual(item.waits)) return false;
        }
        return true;
    }

    public static bool ScoringProjectionMatchesFrozenRules()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 18,18,18,19,20,21,22,23,24,25,25,25,26,26 });
        var engine = new SichuanFanProjectionEngine();
        var projection = engine.Project(hand, Array.Empty<SichuanMeldView>(), SichuanWinType.SelfDraw);
        var sevenPairs = engine.Project(
            SichuanTileCodec.BuildCount18(new[] { 0,0,1,1,2,2,12,12,13,13,14,14,15,15 }),
            Array.Empty<SichuanMeldView>(),
            SichuanWinType.SelfDraw);
        var qingSevenPairs = engine.Project(
            SichuanTileCodec.BuildCount18(new[] { 0,0,1,1,2,2,3,3,4,4,5,5,6,6 }),
            Array.Empty<SichuanMeldView>(),
            SichuanWinType.SelfDraw);
        var bigPairs = engine.Project(
            SichuanTileCodec.BuildCount18(new[] { 0,0,0,2,2,2,13,13,13,15,15,15,8,8 }),
            Array.Empty<SichuanMeldView>(),
            SichuanWinType.SelfDraw);
        Console.WriteLine($"scoring_projection type={projection.HandType} uncapped={projection.UncappedFan} capped={projection.CappedFan} score={projection.PerPayerScore}");
        return projection.HandType == "qing_yi_se" && projection.CappedFan == 2 && projection.PerPayerScore == 5
            && sevenPairs.HandType == "qi_dui" && sevenPairs.CappedFan == 2 && sevenPairs.PerPayerScore == 5
            && qingSevenPairs.HandType == "qing_qi_dui" && qingSevenPairs.CappedFan == 4 && qingSevenPairs.PerPayerScore == 17
            && bigPairs.HandType == "da_dui_zi" && bigPairs.CappedFan == 1 && bigPairs.PerPayerScore == 3;
    }

    public static bool PdfSixExpectedValueExampleIsExact()
    {
        var one = SichuanProbabilityEngine.ExpectedSelfDrawGain(1, 3, 1, 24);
        var two = SichuanProbabilityEngine.ExpectedSelfDrawGain(2, 3, 1, 16);
        Console.WriteLine($"pdf6_ev one={one:F3} two={two:F3}");
        return Math.Abs(one - 8.0) < 0.001 && Math.Abs(two - 10.6666667) < 0.001;
    }

    public static bool HiddenInferenceConservesProbability()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 0,1,2,3,4,5,9,10,11,18,19,20,22 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 42, hand, new int[27], roundIndex: 1201, visibleVersion: 7, handCounts: new[] { 13,13,13,13 });
        var posterior = new SichuanHiddenHandInferenceEngine().Infer(state, 96, 42);
        var valid = posterior.ParticleCount >= 32
            && posterior.HoldProbabilities.SelectMany(row => row).All(value => value is >= 0 and <= 1)
            && posterior.ReadyProbabilities.All(value => value is >= 0 and <= 1)
            && posterior.WallProbabilities.All(value => value >= 0);
        Console.WriteLine($"inference particles={posterior.ParticleCount} ess={posterior.EffectiveSampleSize:F1} valid={valid}");
        return valid;
    }

    public static bool QingPlannerPrefersDiscardingOffSuit()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 0,1,2,3,4,5,6,7,8,8,18,19,22,24 });
        var state = SichuanStateCodec.FromRaw(1, 0, 1, 35, hand, new int[27], roundIndex: 1202);
        var best = new SichuanQingYiSePlanner().Evaluate(state, 0).First();
        Console.WriteLine($"qing_planner discard={best.DiscardTileType} ev={best.ExpectedValue:F2} tenpai={best.TenpaiProbabilityNextDraw:P1}");
        return best.DiscardTileType / 9 != 0;
    }

	public static bool UnifiedHuUsesExpectedValueContract()
	{
		var hand = SichuanTileCodec.BuildCount18(new[] { 0,0,1,2,3,4,5,6,9,10,11,18,18 });
		var state = SichuanStateCodec.FromRaw(1, 0, 1, 20, hand, new int[27], roundIndex: 1203, handCounts: new[] { 13,13,13,13 });
		var result = new SichuanAiFacade().DecideReaction(state, 0, true, false, false, 0);
		Console.WriteLine($"unified_hu action={result.Action.ActionType} hu={result.ActionScores.GetValueOrDefault("hu")} pass={result.ActionScores.GetValueOrDefault("pass")}");
		return result.ActionScores.ContainsKey("hu") && result.ActionScores.ContainsKey("pass")
			&& Math.Abs(result.ActionScores["hu"]) < 100000 && result.Reasons.Any(reason => reason.Contains("收益") || reason.Contains("胡牌"));
	}

	public static bool IndependentJudgeDoesNotReadOnlineScore()
	{
		var hand = SichuanTileCodec.BuildCount18(new[] { 0,1,2,3,4,5,6,7,8,18,19,22,24,26 });
		var state = SichuanStateCodec.FromRaw(1, 0, 1, 28, hand, new int[27], roundIndex: 1204);
		var judge = new SichuanIndependentDecisionJudge();
		var bad = judge.JudgeDiscard(state, 4);
		var good = judge.JudgeDiscard(state, int.Parse(bad.BestAction.Split(':')[1]));
		Console.WriteLine($"independent_judge bad_regret={bad.Regret:F2} good_regret={good.Regret:F2} best={bad.BestAction}");
		return good.Regret < 0.001 && bad.BestAction == good.BestAction;
	}

    public static bool LegalActionsAndTransitionsRespectSichuanRules()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 9, 10, 11, 18, 18, 18, 19, 20, 21, 22, 23 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 30, hand, new int[27], dingQueSuits: new[] { 2, 0, 1, 2 });
        var legal = new SichuanLegalActionEngine().BuildDiscardActions(state);
        var onlyDingQue = legal.Count > 0 && legal.All(action => action.ActionType == SichuanActionType.Discard && action.TileType / 9 == 2);
        var transition = new SichuanActionTransitionEngine();
        var source = transition.FromState(state);
        var peng = transition.ApplyPeng(source, 18);
        var locked = transition.ApplyPassedHu(peng, 2);
        var drawn = transition.ApplyOwnDraw(locked, 24);
        Console.WriteLine($"legal_transition discards={string.Join(',', legal.Select(item => item.TileType))} peng_hand={peng.Hand27.Sum()} melds={peng.MeldCount} lock={locked.LockedFan}->{drawn.LockedFan}");
        return onlyDingQue
            && source.Hand27[18] == 3
            && peng.Hand27[18] == 1
            && peng.MeldCount == source.MeldCount + 1
            && locked.LockedFan == 2
            && drawn.LockedFan == -1;
    }

    public static bool PublicInferenceBeatsUniformOnBehaviorConsistentHand()
    {
        var ownHand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 9, 10, 11, 18, 19, 20, 24 });
        var discards = new[]
        {
            new List<int>(),
            new List<int> { 18, 19, 20, 21, 22, 23 },
            new List<int>(),
            new List<int>()
        };
        var melds = new[]
        {
            new List<int>(),
            new List<int> { 6, 6, 6 },
            new List<int>(),
            new List<int>()
        };
        var visible = new int[27];
        foreach (var tile in discards[1].Concat(melds[1])) visible[tile]++;
        var state = SichuanStateCodec.FromRaw(
            0, 0, 0, 40, ownHand, visible,
            discards18: discards,
            melds18: melds,
            dingQueSuits: new[] { 2, 2, 1, 0 },
            handCounts: new[] { 13, 10, 13, 13 },
            visibleVersion: 31,
            eventVersion: 31);
        state.PublicEvents.Add(new SichuanPublicEvent(29, 8, 1, SichuanPublicEventType.Discard, 21, SichuanTileOrigin.Hand, WallCountAfter: 42));
        state.PublicEvents.Add(new SichuanPublicEvent(30, 9, 1, SichuanPublicEventType.Discard, 22, SichuanTileOrigin.Hand, WallCountAfter: 41));
        state.PublicEvents.Add(new SichuanPublicEvent(31, 10, 1, SichuanPublicEventType.Discard, 23, SichuanTileOrigin.Draw, WallCountAfter: 40));
        var truth = SichuanTileCodec.BuildCount18(new[] { 1, 2, 3, 4, 5, 9, 10, 11, 13, 15 });
        var posterior = new SichuanHiddenHandInferenceEngine().Infer(state, 512, 20260713);
        var totalUnknown = state.Remaining18.Sum();
        var uniform = Enumerable.Range(0, 27)
            .Select(tile => AtLeastOneUniform(state.Remaining18[tile], totalUnknown, 10))
            .ToArray();
        var modelCalibration = SichuanInferenceCalibrationEvaluator.Evaluate(new[] { posterior.HoldProbabilities[1] }, new[] { truth });
        var uniformCalibration = SichuanInferenceCalibrationEvaluator.Evaluate(new[] { uniform }, new[] { truth });
        var modelTop = posterior.HoldProbabilities[1].Select((value, tile) => (value, tile)).OrderByDescending(item => item.value).Take(3).Select(item => item.tile).ToArray();
        var uniformTop = uniform.Select((value, tile) => (value, tile)).OrderByDescending(item => item.value).Take(3).Select(item => item.tile).ToArray();
        Console.WriteLine($"inference_calibration model_brier={modelCalibration.BrierScore:F4} uniform_brier={uniformCalibration.BrierScore:F4} model_ece={modelCalibration.CalibrationError:F4} uniform_ece={uniformCalibration.CalibrationError:F4} model_top3={modelCalibration.TopThreeCoverage:F2}/{string.Join(',', modelTop)} uniform_top3={uniformCalibration.TopThreeCoverage:F2}/{string.Join(',', uniformTop)}");
        return modelCalibration.BrierScore < uniformCalibration.BrierScore
            && modelCalibration.TopThreeCoverage > uniformCalibration.TopThreeCoverage;
    }

    public static bool PublicActionCompatibilityIsSuitRotationInvariant()
    {
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 30, new int[27], new int[27]);
        var candidate = SichuanTileCodec.BuildCount18(new[] { 1, 1, 2, 2, 3, 3, 9, 10, 11, 18, 19, 20, 21 });
        state.PassedPeng18[1][1] = 1;
        state.PassedPeng18[1][2] = 1;
        var original = SichuanOrderedPublicInference.CandidateHandCompatibility(state, 1, candidate);

        var rotatedState = SichuanStateCodec.FromRaw(0, 0, 0, 30, new int[27], new int[27]);
        var rotatedCandidate = new int[27];
        for (var tile = 0; tile < 27; tile++)
            rotatedCandidate[(tile + 9) % 27] = candidate[tile];
        rotatedState.PassedPeng18[1][10] = 1;
        rotatedState.PassedPeng18[1][11] = 1;
        var rotated = SichuanOrderedPublicInference.CandidateHandCompatibility(rotatedState, 1, rotatedCandidate);
        Console.WriteLine($"public_action_rotation original={original:F6} rotated={rotated:F6}");
        return original is > 0 and < 1
            && Math.Abs(original - rotated) < 0.000001;
    }

    public static bool FixedDiscardSequenceDoesNotCreateProductionFeatures()
    {
        var own = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 28, own, new int[27], handCounts: new[] { 13, 10, 13, 13 });
        state.PublicEvents.Add(new SichuanPublicEvent(10, 5, 1, SichuanPublicEventType.Discard, 22, SichuanTileOrigin.Hand));
        state.PublicEvents.Add(new SichuanPublicEvent(20, 6, 1, SichuanPublicEventType.Discard, 22, SichuanTileOrigin.Hand));
        state.PublicEvents.Add(new SichuanPublicEvent(30, 7, 1, SichuanPublicEventType.Peng, 11, SichuanTileOrigin.Unknown, 2));
        state.PublicEvents.Add(new SichuanPublicEvent(31, 7, 1, SichuanPublicEventType.Discard, 25, SichuanTileOrigin.Hand));
        var belief = new SichuanBeliefEngine().Build(state);
        var forbiddenFeatures = new[] { "有序邻张手切", "拆对碰后手切", "高端隔张递减手切", "碰后低端重组" };
        var absent = forbiddenFeatures.All(name => !belief.PublicReadFeatures.ContainsKey($"seat:1:{name}"))
            && !belief.SeatTileInferenceReasons.ContainsKey(1);
        Console.WriteLine($"fixed_sequence_features_absent={absent}");
        return absent;
    }

    public static bool InactiveSeatLeavesThreatAndSuitCompetition()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 9,10,11,12,13,14,15,16,17,18,19,20,21,22 });
        SichuanStateView Build(bool active)
        {
            var state = SichuanStateCodec.FromRaw(0, 0, 0, 18, hand, new int[27],
                dingQueSuits: new[] { 0, 0, 1, 1 }, activeSeats: new[] { true, active, true, true });
            state.HasHu[1] = !active;
            state.Melds18[1].AddRange(new[] { 9, 9, 9, 16, 16, 16 });
            return state;
        }

        var contested = new SichuanQingYiSePlanner().Evaluate(Build(true), 1).First();
        var sole = new SichuanQingYiSePlanner().Evaluate(Build(false), 1).First();
        var table = new SichuanTableSituationEvaluator().Evaluate(Build(false));
        Console.WriteLine($"inactive_strategy competition={contested.TargetSuitCompetition}->{sole.TargetSuitCompetition} completion={contested.CompletionProbability:F3}->{sole.CompletionProbability:F3} threat={table.StrongestThreatSeat}");
        return sole.TargetSuitCompetition == contested.TargetSuitCompetition - 1
            && sole.CompletionProbability > contested.CompletionProbability
            && table.StrongestThreatSeat != 1;
    }

    public static bool PassedReactionEvidenceRejectsCompositePairHypothesisWithoutEliminatingIt()
    {
        var ownHand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 9, 10, 11, 18, 19, 20, 24 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 30, ownHand, new int[27]);
        var candidate = SichuanTileCodec.BuildCount18(new[] { 14, 14, 15, 15, 16, 16, 0, 1, 2, 3, 4, 5, 6 });
        var neutral = SichuanOrderedPublicInference.CandidateHandCompatibility(state, 1, candidate);
        state.PassedPeng18[1][14] = 1;
        var singlePass = SichuanOrderedPublicInference.CandidateHandCompatibility(state, 1, candidate);
        state.PassedPeng18[1][15] = 1;
        var adjacentDoublePass = SichuanOrderedPublicInference.CandidateHandCompatibility(state, 1, candidate);
        Console.WriteLine($"ordered_pass_compatibility neutral={neutral:F3} single={singlePass:F3} adjacent_double={adjacentDoublePass:F3}");
        return Math.Abs(neutral - 1.0) < 0.000001
            && singlePass is > 0 and < 1.0
            && adjacentDoublePass is > 0 and < 1.0
            && adjacentDoublePass < singlePass * singlePass;
    }

    public static bool BeliefPipelineUsesGenericEventOriginWithoutSequencePattern()
    {
        static SichuanStateView BuildState(SichuanTileOrigin secondOrigin)
        {
            var ownHand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 9, 10, 11, 18, 19, 20, 24 });
            var visible = new int[27];
            visible[10] = 1;
            visible[11] = 1;
            var discards = new[]
            {
                new List<int>(),
                new List<int> { 11, 10 },
                new List<int>(),
                new List<int>()
            };
            var state = SichuanStateCodec.FromRaw(
                0, 0, 0, 34, ownHand, visible,
                discards18: discards,
                handCounts: new[] { 13, 13, 13, 13 },
                visibleVersion: 4200,
                eventVersion: 4200);
            state.PublicEvents.Add(new SichuanPublicEvent(100, 8, 1, SichuanPublicEventType.Discard, 11, SichuanTileOrigin.Hand));
            state.PublicEvents.Add(new SichuanPublicEvent(108, 10, 1, SichuanPublicEventType.Discard, 10, secondOrigin));
            return state;
        }

        SichuanBeliefEngine.ResetDiagnostics();
        var engine = new SichuanBeliefEngine();
        var handCut = engine.Build(BuildState(SichuanTileOrigin.Hand));
        var drawCut = engine.Build(BuildState(SichuanTileOrigin.Draw));
        var handHold = handCut.SeatTileHoldProbability[1][9];
        var drawHold = drawCut.SeatTileHoldProbability[1][9];
        var forbiddenFeature = handCut.PublicReadFeatures.Keys.Any(key =>
            key.Contains("有序邻张", StringComparison.Ordinal)
            || key.Contains("拆对碰后", StringComparison.Ordinal)
            || key.Contains("高端隔张", StringComparison.Ordinal)
            || key.Contains("碰后低端", StringComparison.Ordinal));
        var diagnostics = SichuanBeliefEngine.GetDiagnostics();
        Console.WriteLine($"generic_event_origin hand_hold={handHold:F3} draw_hold={drawHold:F3} forbidden_feature={forbiddenFeature} builds={diagnostics.BuildCount}");
        return Math.Abs(handHold - drawHold) > 0.00001
            && !forbiddenFeature
            && !handCut.SeatTileInferenceReasons.ContainsKey(1)
            && diagnostics.BuildCount == 2;
    }

    public static bool MultiPlayerUtilityHonorsStrategicRiskBounds()
    {
        var utility = new SichuanMultiPlayerUtilityEngine();
        var allowSmallDealIn = utility.CanStrategicallyDealIn(1.5, 5.5, 0.93, 3);
        var rejectBigDealIn = !utility.CanStrategicallyDealIn(4.0, 9.0, 0.99, 2);
        var rejectLowConfidence = !utility.CanStrategicallyDealIn(1.0, 8.0, 0.62, 2);
        var allowPassHu = utility.CanPassHu(2.0, 4.2, 0.90, true);
        var requireImmediateHu = !utility.CanPassHu(4.0, 4.8, 0.95, true);
        var lockForbidsPass = !utility.CanPassHu(1.0, 9.0, 1.0, false);
        Console.WriteLine($"multiplayer_bounds small={allowSmallDealIn} big={rejectBigDealIn} confidence={rejectLowConfidence} pass={allowPassHu} hu={requireImmediateHu} lock={lockForbidsPass}");
        return allowSmallDealIn && rejectBigDealIn && rejectLowConfidence && allowPassHu && requireImmediateHu && lockForbidsPass;
    }

    public static bool MeldCounterfactualChargesRouteAndRisk()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 9, 9, 9, 10, 11, 12, 18, 18 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 28, hand, new int[27], roundIndex: 1206);
        var evaluator = new SichuanMeldCounterfactualEvaluator();
        var clean = evaluator.Evaluate(state, "peng", 9, 2, 1, 0.0, 0.0, 0.0);
        var costly = evaluator.Evaluate(state, "peng", 9, 2, 1, 2.5, 1.5, 0.0);
        var gangIncome = evaluator.Evaluate(state, "gang", 9, 3, 1, 0.0, 0.0, 1.8);
        Console.WriteLine($"meld_counterfactual clean={clean.Value:F2} costly={costly.Value:F2} gang={gangIncome.Value:F2} shanten={clean.Shanten}/{gangIncome.Shanten}");
        return Math.Abs((clean.Value - costly.Value) - 4.0) < 0.001
            && gangIncome.Value > double.NegativeInfinity
            && clean.LiveUkeire >= 0
            && gangIncome.LiveUkeire >= 0;
    }

    public static bool IndependentJudgeCoversReactionAndSelfActions()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 9, 9, 9, 9, 10, 11, 18, 18 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 24, hand, new int[27], roundIndex: 1207);
        var judge = new SichuanIndependentDecisionJudge();
        var reaction = judge.JudgeReaction(state, SichuanActionType.Peng, 9, false, true, true);
        var illegalHu = judge.JudgeReaction(state, SichuanActionType.Hu, 9, false, true, true);
        var selfGang = judge.JudgeSelfAction(state, new SichuanAction(SichuanActionType.Gang, 9), false, new[] { 9 }, Array.Empty<int>());
        Console.WriteLine($"independent_all_actions reaction={reaction.Action}/{reaction.BestAction}/{reaction.Regret:F2} illegal={illegalHu.Category} self={selfGang.Action}/{selfGang.BestAction}/{selfGang.Regret:F2}");
        return reaction.Action == "peng:9"
            && reaction.BestAction != "none"
            && illegalHu.Category == SichuanDecisionErrorCategory.Rule
            && selfGang.Action == "gang:9"
            && selfGang.BestAction != "none";
    }

    public static bool ReplayJudgeAggregatesAllActionsCalibrationAndPdfSources()
    {
        var hand = SichuanTileCodec.BuildCount18(new[] { 0, 1, 2, 3, 4, 5, 9, 9, 9, 9, 10, 11, 18, 18 });
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 24, hand, new int[27], roundIndex: 1208);
        var judge = new SichuanIndependentDecisionJudge();
        var bestDiscard = int.Parse(judge.JudgeDiscard(state, 0).BestAction.Split(':')[1]);
        var replay = new[]
        {
            new SichuanReplayDecision(SichuanReplayDecisionKind.Discard, state, new SichuanAction(SichuanActionType.Discard, bestDiscard), PredictedSuccessProbability: 0.75, ActualSuccess: true, PdfSource: 5),
            new SichuanReplayDecision(SichuanReplayDecisionKind.Reaction, state, new SichuanAction(SichuanActionType.Hu, 9), TileType: 9, CanHu: false, CanPeng: true, CanGang: true, PredictedSuccessProbability: 0.80, ActualSuccess: false, PdfSource: 13),
            new SichuanReplayDecision(SichuanReplayDecisionKind.Reaction, state, new SichuanAction(SichuanActionType.Pass, 9), TileType: 9, CanHu: true, CanPeng: true, CanGang: false, PdfSource: 6),
            new SichuanReplayDecision(SichuanReplayDecisionKind.SelfAction, state, new SichuanAction(SichuanActionType.Gang, 9), ConcealedGangTiles: new[] { 9 }, PdfSource: 9)
        };
        var metrics = new SichuanReplayDecisionEvaluator().Evaluate(replay);
        Console.WriteLine($"replay_judge decisions={metrics.Decisions} regret={metrics.AverageRegret:F2} severe={metrics.SevereErrorRate:F2} rule={metrics.RuleErrorRate:F2} passhu={metrics.PassHuErrorRate:F2} meld={metrics.MeldErrorRate:F2} route={metrics.RouteConsistencyRate:F2} brier={metrics.CalibrationBrierScore:F3} pdf={string.Join(',', metrics.ByPdf.Keys.Order())}");
        return metrics.Decisions == 4
            && metrics.CalibrationSamples == 2
            && Math.Abs(metrics.CalibrationBrierScore - 0.35125) < 0.0001
            && metrics.RuleErrorRate > 0
            && metrics.ByPdf.Keys.Order().SequenceEqual(new[] { 5, 6, 9, 13 });
    }

    public static bool GoldenPdfWaitCasesPass()
    {
        var path = Path.Combine(Environment.CurrentDirectory, "测试数据统计", "PDF黄金牌例", "牌形与听口.json");
        if (!File.Exists(path))
        {
            Console.WriteLine($"golden_pdf_missing path={path}");
            return false;
        }
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var analyzer = new SichuanExactHandAnalyzer();
        var count = 0;
        foreach (var item in document.RootElement.GetProperty("cases").EnumerateArray())
        {
            var hand = new int[27];
            foreach (var oneBased in item.GetProperty("concealedTiles").EnumerateArray())
                hand[oneBased.GetInt32() - 1]++;
            var meldCount = item.GetProperty("existingMeldCount").GetInt32();
            var expected = item.GetProperty("expectedWaits").EnumerateArray().Select(value => value.GetInt32()).Order().ToArray();
            var actual = analyzer.EnumerateWaits(hand, Enumerable.Repeat(4, 27).ToArray(), meldCount)
                .Select(wait => wait.TileType + 1)
                .Order()
                .ToArray();
            count++;
            if (!actual.SequenceEqual(expected))
            {
                Console.WriteLine($"golden_pdf_failed id={item.GetProperty("id").GetString()} actual={string.Join(',', actual)} expected={string.Join(',', expected)}");
                return false;
            }
        }
        Console.WriteLine($"golden_pdf_waits passed={count}");
        return count >= 19;
    }

    public static bool ExactAnalyzerExhaustivelyMatchesShanten()
    {
		if (Environment.GetEnvironmentVariable("SICHUAN_SKIP_EXHAUSTIVE") == "1")
		{
			Console.WriteLine("exact_exhaustive skipped_by_environment");
			return true;
		}
        var analyzer = new SichuanExactHandAnalyzer();
        var shanten = new SichuanShantenEngine();
        var checkedStates = 0;
        string? failure = null;
        foreach (var concealedCount in new[] { 7, 10, 13 })
        {
            var exposedMeldCount = (13 - concealedCount) / 3;
            VisitSingleSuitStates(concealedCount, state =>
            {
                if (failure is not null) return;
                var expected = new List<int>();
                for (var tile = 0; tile < 9; tile++)
                {
                    if (state[tile] >= 4) continue;
                    state[tile]++;
                    if (shanten.CalcBestShanten(state, exposedMeldCount, exposedMeldCount == 0) == -1)
                        expected.Add(tile);
                    state[tile]--;
                }
                var actual = analyzer.EnumerateWaits(state, Enumerable.Repeat(4, 27).ToArray(), exposedMeldCount, exposedMeldCount == 0)
                    .Select(wait => wait.TileType)
                    .Where(tile => tile < 9)
                    .ToArray();
                checkedStates++;
                if (!actual.SequenceEqual(expected))
                    failure = $"count={concealedCount} hand={string.Join(',', state.Take(9))} actual={string.Join(',', actual)} expected={string.Join(',', expected)}";
            });
            if (failure is not null) break;
        }
        Console.WriteLine($"exact_exhaustive states={checkedStates} failure={failure ?? "none"}");
        return failure is null && checkedStates == 131841;
    }

    public static bool ExactScoringAndSettlementBreakdownIsComplete()
    {
        var hand = new int[27];
        foreach (var tile in new[] { 1, 1, 2, 2, 2, 3, 3 }) hand[tile]++;
        var melds = new[]
        {
            new SichuanMeldView(SichuanMeldType.Peng, 0, 1, 1),
            new SichuanMeldView(SichuanMeldType.Peng, 4, 2, 2)
        };
        var scored = new SichuanExactHandAnalyzer().EnumerateScoredWaits(
            hand,
            Enumerable.Repeat(4, 27).ToArray(),
            melds,
            SichuanWinType.SelfDraw,
            new[] { 0, 1, 2, 3 },
            0);
        var scenario = new SichuanSettlementScenario(
            GangEvents: new[] { new SichuanGangScoreEvent(0, SichuanMeldType.ConcealedGang, new[] { 1, 2, 3 }) },
            GangRefunds: new[] { new SichuanGangRefundEvent(0, SichuanMeldType.ConcealedGang, new[] { 1, 2, 3 }) },
            TransferEvents: new[] { new SichuanHuJiaoTransferEvent(2, SichuanMeldType.AddedGang, new[] { 0, 1, 3 }, FromSeat: 0) },
            DrawAssessments: new[]
            {
                new SichuanDrawAssessment(0, true, false, 2),
                new SichuanDrawAssessment(1, false, false, 0),
                new SichuanDrawAssessment(2, false, true, 0),
                new SichuanDrawAssessment(3, true, false, 4)
            });
        var settlement = new SichuanSettlementProjectionEngine().ProjectScenario(scenario);
        Console.WriteLine($"exact_scored_waits={scored.Count} settlement={string.Join(',', settlement.ScoreChanges)} cha={string.Join(',', settlement.ChaJiaoChanges)} hua={string.Join(',', settlement.HuaZhuChanges)}");
        return scored.Count == 3
            && scored.All(item => item.FanProjections.Count > 0 && item.MaximumSettlement >= item.MinimumSettlement)
            && settlement.ScoreChanges.SequenceEqual(new[] { 21, -8, -31, 18 })
            && settlement.GangChanges.SequenceEqual(new[] { 6, -2, -2, -2 })
            && settlement.RefundChanges.SequenceEqual(new[] { 0, 0, 0, 0 })
            && settlement.TransferChanges.SequenceEqual(new[] { -3, 0, 3, 0 })
            && settlement.ChaJiaoChanges.SequenceEqual(new[] { 2, -6, 0, 4 })
            && settlement.HuaZhuChanges.SequenceEqual(new[] { 16, 0, -32, 16 });
    }

    public static bool PublicEventsRebuildThePublicTableExactly()
    {
        var events = new[]
        {
            new SichuanPublicEvent(1, 0, 0, SichuanPublicEventType.Draw, -1, SichuanTileOrigin.Draw, WallCountAfter: 55),
            new SichuanPublicEvent(2, 0, 0, SichuanPublicEventType.Discard, 4, SichuanTileOrigin.Hand, WallCountAfter: 55),
            new SichuanPublicEvent(3, 0, 1, SichuanPublicEventType.Peng, 4, SourceSeat: 0, WallCountAfter: 55),
            new SichuanPublicEvent(4, 1, 1, SichuanPublicEventType.Discard, 9, SichuanTileOrigin.Hand, WallCountAfter: 55),
            new SichuanPublicEvent(5, 1, 2, SichuanPublicEventType.Draw, -1, SichuanTileOrigin.Draw, WallCountAfter: 54),
            new SichuanPublicEvent(6, 1, 2, SichuanPublicEventType.Discard, 10, SichuanTileOrigin.Draw, WallCountAfter: 54),
            new SichuanPublicEvent(7, 1, 3, SichuanPublicEventType.Pass, 10, SourceSeat: 2, WallCountAfter: 54, CanHu: true),
            new SichuanPublicEvent(8, 2, 1, SichuanPublicEventType.AddedGang, 4, SourceSeat: 0, WallCountAfter: 54),
            new SichuanPublicEvent(9, 2, 1, SichuanPublicEventType.Draw, -1, SichuanTileOrigin.Draw, WallCountAfter: 53),
            new SichuanPublicEvent(10, 2, 1, SichuanPublicEventType.Discard, 12, SichuanTileOrigin.Hand, WallCountAfter: 53),
            new SichuanPublicEvent(11, 2, 2, SichuanPublicEventType.Hu, 12, SourceSeat: 1, WallCountAfter: 53)
        };
        var state = new SichuanPublicStateReplay().Replay(new[] { 13, 13, 13, 13 }, events);
        Console.WriteLine($"public_replay version={state.EventVersion} wall={state.WallCount} hands={string.Join(',', state.HandCounts)} visible4={state.Visible27[4]} passHu={state.PassedHu27[3][10]}");
        return state.EventVersion == 11
            && state.WallCount == 53
            && state.HandCounts.SequenceEqual(new[] { 13, 9, 13, 13 })
            && state.Visible27[4] == 4
            && state.Visible27[9] == 1
            && state.Visible27[10] == 1
            && state.Visible27[12] == 1
            && state.Discards[0].Count == 0
            && state.Discards[1].SequenceEqual(new[] { 9, 12 })
            && state.Melds[1].Count == 1
            && state.Melds[1][0].Type == SichuanMeldType.AddedGang
            && state.PassedHu27[3][10] == 1
            && !state.ActiveSeats[2];
    }

	public static bool QingPlannerDistinguishesStrongWeakOverlapAndCompetition()
	{
		var planner = new SichuanQingYiSePlanner();
		var strongHand = SichuanTileCodec.BuildCount18(new[] { 0,0,1,2,3,4,5,6,7,7,8,8,18,19 });
		var weakHand = SichuanTileCodec.BuildCount18(new[] { 0,1,2,3,4,9,10,11,12,13,18,19,20,21 });
		var strongState = SichuanStateCodec.FromRaw(0, 0, 0, 36, strongHand, new int[27], dingQueSuits: new[] { 2, 0, 0, 0 });
		var weakState = SichuanStateCodec.FromRaw(0, 0, 0, 36, weakHand, new int[27], dingQueSuits: new[] { 2, 0, 0, 0 });
		var strong = planner.Evaluate(strongState, 0).First();
		var weak = planner.Evaluate(weakState, 0).First();

		var overlapHand = SichuanTileCodec.BuildCount18(new[] { 0,0,1,1,2,2,3,3,4,4,5,5,18,19 });
		var overlapState = SichuanStateCodec.FromRaw(0, 0, 0, 30, overlapHand, new int[27], dingQueSuits: new[] { 2, 0, 0, 0 });
		var overlap = planner.Evaluate(overlapState, 0).First();

		var lowCompetitionState = SichuanStateCodec.FromRaw(0, 0, 0, 36, strongHand, new int[27], dingQueSuits: new[] { 2, 0, 0, 0 });
		var highCompetitionState = SichuanStateCodec.FromRaw(0, 0, 0, 36, strongHand, new int[27], dingQueSuits: new[] { 2, 1, 1, 1 });
		var lowCompetition = planner.Evaluate(lowCompetitionState, 0).First();
		var highCompetition = planner.Evaluate(highCompetitionState, 0).First();
		Console.WriteLine($"qing_strength strong={strong.CompletionProbability:F2}/{strong.ExpectedValue:F2} weak={weak.CompletionProbability:F2}/{weak.ExpectedValue:F2} overlap={overlap.OrdinaryFallbackValue:F2}/{overlap.GenGangPotential:F2} competition={lowCompetition.TargetSuitCompetition}->{highCompetition.TargetSuitCompetition}");
		return strong.DiscardTileType / 9 != 0
			&& strong.CompletionProbability > weak.CompletionProbability
			&& strong.ExpectedFan >= weak.ExpectedFan
			&& overlap.OrdinaryFallbackValue > 0
			&& overlap.GenGangPotential > 0
			&& lowCompetition.TargetSuitCompetition < highCompetition.TargetSuitCompetition
			&& lowCompetition.ExpectedValue > highCompetition.ExpectedValue;
	}

	public static bool ChanceSearchModelsOrderThreatGangAndBudget()
	{
		var tree = new SichuanActionTreeEvaluator();
		var wide = tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(6, 36, 4, 0, 12, 0.015, 3, Simulations: 4096, Seed: 77));
		var narrow = tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(1, 36, 4, 0, 12, 0.015, 3, Simulations: 4096, Seed: 77));
		var threatened = tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(6, 36, 4, 0, 12, 0.09, 5, Simulations: 4096, Seed: 77));
		var gang = tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(3, 36, 3, 1, 8, 0.02, 3, 0.12, 2, 1, Simulations: 4096, Seed: 77));
		Console.WriteLine($"chance_search wide={wide.ExpectedNetScore:F2}/{wide.OwnWinProbability:F2} narrow={narrow.ExpectedNetScore:F2} threat={threatened.ExpectedNetScore:F2}/{threatened.OpponentWinProbability:F2} gang={gang.ExpectedGangGain:F2} ms={wide.ElapsedMilliseconds:F1}");
		return wide.ExpectedNetScore > narrow.ExpectedNetScore
			&& threatened.ExpectedNetScore < wide.ExpectedNetScore
			&& threatened.OpponentWinProbability > wide.OpponentWinProbability
			&& gang.ExpectedGangGain > 0
			&& wide.ElapsedMilliseconds < 100;
	}

	public static bool UnifiedDecisionRanksAllLegalActionsAndCompositeTriplets()
	{
		var engine = new SichuanUnifiedDecisionEngine();
		var hand = SichuanTileCodec.BuildCount18(new[] { 1,1,1,2,4,4,4,5,6,7,9,10,18,18 });
		var state = SichuanStateCodec.FromRaw(0, 0, 0, 24, hand, Enumerable.Repeat(1, 27).ToArray(), roundIndex: 1210, eventVersion: 8, visibleVersion: 8);
		var discards = engine.RankDiscards(state);
		var twoTwoTwoThree = engine.RankMeldActions(state, 1, true, true);
		var fiveFiveFiveSix = engine.RankMeldActions(state, 4, true, true);
		var allFinite = discards.Candidates.Concat(twoTwoTwoThree.Candidates).Concat(fiveFiveFiveSix.Candidates).All(item => double.IsFinite(item.ExpectedNetScore));
		Console.WriteLine($"unified_all discard={discards.Candidates.Count}/{discards.Candidates.FirstOrDefault()?.Action.TileType} 2223={string.Join(',', twoTwoTwoThree.Candidates.Select(item => item.Action.ActionType))} 5556={string.Join(',', fiveFiveFiveSix.Candidates.Select(item => item.Action.ActionType))}");
		return discards.SelectedAction == SichuanActionType.Discard
			&& discards.Candidates.Count == hand.Count(value => value > 0)
			&& twoTwoTwoThree.Candidates.Select(item => item.Action.ActionType).ToHashSet().SetEquals(new[] { SichuanActionType.Pass, SichuanActionType.Peng, SichuanActionType.Gang })
			&& fiveFiveFiveSix.Candidates.Select(item => item.Action.ActionType).ToHashSet().SetEquals(new[] { SichuanActionType.Pass, SichuanActionType.Peng, SichuanActionType.Gang })
			&& allFinite;
	}

    private static void VisitSingleSuitStates(int total, Action<int[]> visitor)
    {
        var counts = new int[27];
        void Visit(int tile, int remaining)
        {
            if (tile == 9)
            {
                if (remaining == 0) visitor(counts);
                return;
            }
            for (var value = 0; value <= Math.Min(4, remaining); value++)
            {
                counts[tile] = value;
                Visit(tile + 1, remaining - value);
            }
            counts[tile] = 0;
        }
        Visit(0, total);
    }

    private static double AtLeastOneUniform(int copies, int total, int draws)
    {
        if (copies <= 0 || total <= 0 || draws <= 0) return 0;
        var miss = 1.0;
        for (var index = 0; index < Math.Min(draws, total); index++)
            miss *= Math.Max(0, total - copies - index) / (double)Math.Max(1, total - index);
        return 1.0 - miss;
    }

    private static int MaxSevenPairsWeight(IReadOnlyDictionary<string, int> weights)
        => new[] { "暗七对", "龙七对", "清七对", "青龙七对" }
            .Select(route => weights.GetValueOrDefault(route))
            .Max();
}
