using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Search;

var hand = new[]
{
    SichuanTileCodec.EncodeTileType(0, 2),
    SichuanTileCodec.EncodeTileType(0, 3),
    SichuanTileCodec.EncodeTileType(0, 4),
    SichuanTileCodec.EncodeTileType(0, 5),
    SichuanTileCodec.EncodeTileType(0, 6),
    SichuanTileCodec.EncodeTileType(0, 7),
    SichuanTileCodec.EncodeTileType(1, 2),
    SichuanTileCodec.EncodeTileType(1, 3),
    SichuanTileCodec.EncodeTileType(1, 4),
    SichuanTileCodec.EncodeTileType(1, 5),
    SichuanTileCodec.EncodeTileType(1, 5),
    SichuanTileCodec.EncodeTileType(1, 7),
    SichuanTileCodec.EncodeTileType(1, 8),
};

var state = SichuanStateCodec.FromRaw(1, 0, 1, 38, SichuanTileCodec.BuildCount18(hand), new int[27]);
var facade = new SichuanAiFacade();
var result = facade.DecideDiscard(state);
var bestCandidate = result.Candidates.FirstOrDefault(item => item.TileType == result.Action.TileType);
if (bestCandidate is null)
{
    Console.Error.WriteLine("missing_best_candidate");
    return 1;
}

if (Math.Abs(bestCandidate.ExpectedNetScore) < 0.0001 && bestCandidate.ExpectedWinGain <= 0)
{
    Console.Error.WriteLine("expected_score_model_not_populated");
    return 2;
}

if (bestCandidate.SelfDrawProbability <= 0 || bestCandidate.SelfDrawProbability > 1)
{
    Console.Error.WriteLine("self_draw_probability_out_of_range");
    return 3;
}

Console.WriteLine($"best_tile={result.Action.TileType}");
Console.WriteLine($"shanten={result.Shanten}");
Console.WriteLine($"ukeire={result.Ukeire}");
Console.WriteLine($"live_ukeire={result.LiveUkeire}");
Console.WriteLine($"self_draw_probability={bestCandidate.SelfDrawProbability:F4}");
Console.WriteLine($"expected_net_score={bestCandidate.ExpectedNetScore:F2}");
Console.WriteLine($"expected_win_gain={bestCandidate.ExpectedWinGain:F2}");
Console.WriteLine($"expected_deal_in_loss={bestCandidate.ExpectedDealInLoss:F2}");
Console.WriteLine($"reasons={string.Join(" | ", result.Reasons)}");
if (!SmokeReactionTransitionsRespectTiming())
{
	Console.Error.WriteLine("reaction_transition_timing_smoke_failed");
	return 401;
}

if (!SmokeMutuallyExclusiveShapePreservesPairRoutes())
{
	Console.Error.WriteLine("mutually_exclusive_shape_smoke_failed");
	return 402;
}

if (!SmokePassesNoSpeedPeng(facade))
{
    Console.Error.WriteLine("pass_no_speed_peng_smoke_failed");
    return 4;
}

if (!SmokeReasonableAnGang(facade))
{
    Console.Error.WriteLine("reasonable_an_gang_smoke_failed");
    return 5;
}

if (!SmokeWanSuitIncludedInCoreLogic(facade))
{
    Console.Error.WriteLine("wan_suit_core_logic_smoke_failed");
    return 52;
}

if (!SmokeCSharpForcesOwnDingQueSuit(facade))
{
    Console.Error.WriteLine("csharp_ding_que_priority_smoke_failed");
    return 53;
}

if (!SmokeRiskCalibration())
{
    Console.Error.WriteLine("risk_calibration_smoke_failed");
    return 6;
}

if (!SmokePosteriorDefenseAdjustment(facade))
{
    Console.Error.WriteLine("posterior_defense_adjustment_smoke_failed");
    return 7;
}

if (!SmokeHandShapeDetails(facade))
{
    Console.Error.WriteLine("hand_shape_details_smoke_failed");
    return 8;
}

if (!SmokeEvidenceSnapshot())
{
    Console.Error.WriteLine("evidence_snapshot_smoke_failed");
    return 9;
}

if (!SmokeOpponentRangeUsesNoHuEvidence())
{
    Console.Error.WriteLine("opponent_range_no_hu_smoke_failed");
    return 10;
}

if (!SmokePosteriorNormalizationConservesRemainingTiles())
{
    Console.Error.WriteLine("posterior_normalization_conservation_smoke_failed");
    return 11;
}

if (!SmokePassedReactionEvidenceFeedsOpponentRange())
{
    Console.Error.WriteLine("passed_reaction_evidence_smoke_failed");
    return 12;
}

if (!SmokeWaitShapeClassification())
{
    Console.Error.WriteLine("wait_shape_classification_smoke_failed");
    return 13;
}

if (!SmokeLimitedLookaheadScoresFutureImprovement())
{
    Console.Error.WriteLine("limited_lookahead_smoke_failed");
    return 14;
}

if (!SmokeHellOracleRejectsExactDealIn())
{
    Console.Error.WriteLine("hell_oracle_dealin_smoke_failed");
    return 15;
}

if (!SmokeHellOracleAvoidsFeedingHumanCalls())
{
    Console.Error.WriteLine("hell_oracle_human_call_suppression_smoke_failed");
    return 36;
}

if (!SmokeHellOracleAvoidsFeedingHumanGang())
{
    Console.Error.WriteLine("hell_oracle_human_gang_suppression_smoke_failed");
    return 37;
}

if (!SmokeHellOracleRaisesPressureWhenHumanLeads())
{
    Console.Error.WriteLine("hell_oracle_human_pressure_smoke_failed");
    return 38;
}

if (!SmokeHellChallengeDirectDoesNotNeedFairRecommendation())
{
    Console.Error.WriteLine("hell_challenge_direct_smoke_failed");
    return 39;
}

if (!SmokeHellChallengeReportsSelectedShape())
{
    Console.Error.WriteLine("hell_challenge_selected_shape_smoke_failed");
    return 3901;
}

if (!SmokeHellChallengeInheritsOldHandFlushRoute())
{
    Console.Error.WriteLine("hell_challenge_old_hand_flush_route_smoke_failed");
    return 3903;
}

if (!SmokeHellChallengeInheritsOldHandTripletProtection())
{
    Console.Error.WriteLine("hell_challenge_old_hand_triplet_protection_smoke_failed");
    return 3904;
}

if (!SmokeHellChallengeEnforcesDingQueLegality())
{
    Console.Error.WriteLine("hell_challenge_ding_que_legality_smoke_failed");
    return 3905;
}

if (!SmokeHellChallengeSharesContinuousBrainWithReaction())
{
    Console.Error.WriteLine("hell_challenge_shared_continuous_brain_smoke_failed");
    return 3906;
}

if (!SmokeHellChallengeTierKeepsOneAwayOverWideTwoAway())
{
    Console.Error.WriteLine("hell_challenge_tier_one_away_smoke_failed");
    return 3902;
}

if (!SmokeHellChallengeReactionBlocksHumanMomentum())
{
    Console.Error.WriteLine("hell_challenge_reaction_smoke_failed");
    return 40;
}

if (!SmokeHellChallengeTeamPlanCoordinatesSeats())
{
    Console.Error.WriteLine("hell_challenge_team_plan_smoke_failed");
    return 41;
}

if (!SmokeHellChallengeDiscardUsesTeamPlan())
{
    Console.Error.WriteLine("hell_challenge_discard_team_plan_smoke_failed");
    return 42;
}

if (!SmokeHellChallengeReactionUsesTeamPlan())
{
    Console.Error.WriteLine("hell_challenge_reaction_team_plan_smoke_failed");
    return 43;
}

if (!SmokeHellChallengePassesNonHumanMiddlePengUnlessReady())
{
    Console.Error.WriteLine("hell_challenge_non_human_middle_peng_restraint_smoke_failed");
    return 433;
}

if (!SmokeHellChallengeAllowsHumanPengToKeepReady())
{
    Console.Error.WriteLine("hell_challenge_peng_interaction_smoke_failed");
    return 44;
}

if (!SmokeHellChallengeAllowsMidgamePengWhenHumanNotReady())
{
    Console.Error.WriteLine("hell_challenge_mid_peng_interaction_smoke_failed");
    return 441;
}

if (!SmokeHellChallengeAllowsLatePengOnlyWhenHumanReady())
{
    Console.Error.WriteLine("hell_challenge_late_peng_only_interaction_smoke_failed");
    return 45;
}

if (!SmokeHellChallengeKeepsReadyWhenHumanReadyCanOnlyPeng())
{
    Console.Error.WriteLine("hell_challenge_ready_human_peng_only_smoke_failed");
    return 451;
}

if (!SmokeHellChallengePrefersDirectGangOverPeng())
{
    Console.Error.WriteLine("hell_challenge_direct_gang_over_peng_smoke_failed");
    return 46;
}

if (!SmokeHellChallengeGangsWhenPengWouldRediscardClaimedTile())
{
    Console.Error.WriteLine("hell_challenge_peng_rediscard_same_tile_smoke_failed");
    return 47;
}

if (!SmokeHellChallengeAllowsPengWhenGangHurtsShape())
{
    Console.Error.WriteLine("hell_challenge_peng_over_gang_shape_smoke_failed");
    return 48;
}

if (!SmokeLateWallRiskRegression(facade))
{
    Console.Error.WriteLine("late_wall_risk_regression_smoke_failed");
    return 16;
}

if (!SmokeReactionPassesSevenPairsTenpai(facade))
{
    Console.Error.WriteLine("reaction_seven_pairs_tenpai_smoke_failed");
    return 17;
}

if (!SmokeReactionPrefersReadyPengWhenGangWouldLoseReady(facade))
{
    Console.Error.WriteLine("reaction_ready_peng_over_unready_gang_smoke_failed");
    return 18;
}

if (!SmokeHellChallengePengRediscardPenaltyIsDecisive())
{
    Console.Error.WriteLine("hell_challenge_peng_rediscard_decisive_smoke_failed");
    return 181;
}

if (!SmokeReactionAllowsSameShantenPengForLargeLiveGain(facade))
{
	Console.Error.WriteLine("reaction_same_shanten_live_gain_smoke_failed");
	return 19;
}

if (!SmokeLateWallPassesNarrowNoSpeedPeng(facade))
{
    Console.Error.WriteLine("late_wall_pass_narrow_no_speed_peng_smoke_failed");
    return 20;
}

if (!SmokeLateWallKeepsReadyOverSafeFold(facade))
{
    Console.Error.WriteLine("late_wall_keep_ready_smoke_failed");
    return 21;
}

if (!SmokeLateWallKeepsReadyAgainstAbandonedSuitThreat(facade))
{
    Console.Error.WriteLine("late_wall_abandoned_suit_ready_smoke_failed");
    return 22;
}

if (!SmokeLateWallKeepsReadyFromMarkedCases(facade))
{
    Console.Error.WriteLine("late_wall_marked_cases_ready_smoke_failed");
    return 23;
}

if (!SmokeBeliefReuseWithinReaction(facade))
{
    Console.Error.WriteLine("belief_reuse_reaction_smoke_failed");
    return 24;
}

if (!SmokeMobileReactionSkipsShortSearch(facade))
{
    Console.Error.WriteLine("mobile_reaction_short_search_smoke_failed");
    return 25;
}

if (!SmokeBeliefReuseWithinSelfAction(facade))
{
    Console.Error.WriteLine("belief_reuse_self_action_smoke_failed");
    return 26;
}

if (!SmokeBeliefCacheExactStateHit())
{
    Console.Error.WriteLine("belief_cache_exact_state_smoke_failed");
    return 27;
}

if (!SmokeEarlyBigPairRouteKeepsPair(facade))
{
    Console.Error.WriteLine("early_big_pair_route_smoke_failed");
    return 28;
}

if (!SmokeFastReadyBeatsUnreadyBigPairRoute(facade))
{
    Console.Error.WriteLine("fast_ready_beats_big_pair_route_smoke_failed");
    return 281;
}

if (!SmokeBigPairRouteDoesNotOverrideLargeScoreGap())
{
    Console.Error.WriteLine("big_pair_route_large_score_gap_smoke_failed");
    return 286;
}

if (!SmokeChaseSortPrefersHigherScoreRoute())
{
    Console.Error.WriteLine("chase_sort_higher_score_route_smoke_failed");
    return 2861;
}

if (!SmokeDefenseSortPrefersSafeCandidate())
{
    Console.Error.WriteLine("defense_sort_safe_candidate_smoke_failed");
    return 2862;
}

if (!SmokeProtectLeadSortDoesNotOverpayForTinyDangerDifference())
{
    Console.Error.WriteLine("protect_lead_tiny_danger_overpay_smoke_failed");
    return 2863;
}

if (!SmokeProtectLeadEarlyKeepsBalancedProgress())
{
    Console.Error.WriteLine("protect_lead_early_balanced_progress_smoke_failed");
    return 2864;
}

if (!SmokeFoldSortUsesSafetyBandsWithoutTinyDangerOverpay())
{
    Console.Error.WriteLine("fold_sort_safety_band_smoke_failed");
    return 2865;
}

if (!SmokeWideTwoAwayHighEvCanBeatNarrowOneAway())
{
    Console.Error.WriteLine("wide_two_away_high_ev_sort_smoke_failed");
    return 2866;
}

if (!SmokePotentialFlushPrefersOffSuitDiscard(facade))
{
    Console.Error.WriteLine("potential_flush_prefers_off_suit_smoke_failed");
    return 287;
}

if (!SmokeQuadTileGetsStrongPreservationPenalty())
{
    Console.Error.WriteLine("quad_tile_preservation_penalty_smoke_failed");
    return 288;
}

if (!SmokeRoutePlanDiagnosticsAreReturned(facade))
{
    Console.Error.WriteLine("route_plan_diagnostics_smoke_failed");
    return 282;
}

if (!SmokeRoutePlanFivePairsForbidsCalls(facade))
{
    Console.Error.WriteLine("route_plan_five_pairs_forbid_calls_smoke_failed");
    return 283;
}

if (!SmokeRoutePlanThreePairsStaysFlexible(facade))
{
    Console.Error.WriteLine("route_plan_three_pairs_flexible_smoke_failed");
    return 284;
}

if (!SmokeRoutePlanSevenPairsRejectsSelfGang(facade))
{
    Console.Error.WriteLine("route_plan_seven_pairs_reject_self_gang_smoke_failed");
    return 285;
}

if (!SmokeAvoidsUnnecessaryTripletBreak(facade))
{
    Console.Error.WriteLine("avoid_unnecessary_triplet_break_smoke_failed");
    return 29;
}

if (!SmokePrefersOrphanTerminalFromMarkedCases(facade))
{
    Console.Error.WriteLine("orphan_terminal_marked_cases_smoke_failed");
    return 30;
}

if (!SmokePrefersIsolatedTerminalOverBreakingRuns(facade))
{
    Console.Error.WriteLine("isolated_terminal_over_run_smoke_failed");
    return 31;
}

if (!SmokeHaidiPreservesPairWaitOverFutureShape(facade))
{
    Console.Error.WriteLine("haidi_pair_wait_smoke_failed");
    return 32;
}

if (!SmokeReadyPreservesCentralBoneFromSeedLive(facade))
{
    Console.Error.WriteLine("ready_central_bone_seedlive_smoke_failed");
    return 34;
}

if (!SmokeExtremeDangerSameSpeedOverrideFromSeedLive(facade))
{
    Console.Error.WriteLine("extreme_danger_same_speed_seedlive_smoke_failed");
    return 35;
}

if (!SmokeAiContextStageExplainAndPerf(facade))
{
    Console.Error.WriteLine("ai_context_stage_explain_perf_smoke_failed");
    return 36;
}

if (!SmokeAiContextStrategyModes(facade))
{
    Console.Error.WriteLine("ai_context_strategy_modes_smoke_failed");
    return 37;
}

if (!RoundBrainSmoke.KeepsIndependentContinuousBrains())
{
    Console.Error.WriteLine("round_brain_continuity_smoke_failed");
    return 3801;
}

if (!RoundBrainSmoke.PenalizesBreakThenPengContradiction())
{
    Console.Error.WriteLine("round_brain_break_then_peng_smoke_failed");
    return 3802;
}

if (!RoundBrainSmoke.SafeReadyDominatesHigherScoredNonReady())
{
    Console.Error.WriteLine("round_brain_safe_ready_dominance_smoke_failed");
    return 3803;
}

if (!RoundBrainSmoke.ResetsAtRoundBoundaryAndExposesStrategyState())
{
    Console.Error.WriteLine("round_brain_strategy_state_smoke_failed");
    return 3804;
}

if (!SichuanTheorySmoke.RecognizesClassicFlushWaits())
{
    Console.Error.WriteLine("theory_classic_flush_waits_smoke_failed");
    return 3901;
}

if (!SichuanTheorySmoke.OpponentBigHandShiftsTowardFastReady())
{
    Console.Error.WriteLine("theory_opponent_threat_shift_smoke_failed");
    return 3902;
}

if (!SichuanTheorySmoke.DingQueWidthRaisesFlushValue())
{
    Console.Error.WriteLine("theory_dingque_width_smoke_failed");
    return 3903;
}

if (!SichuanTheorySmoke.ExactAnalyzerEnumeratesClassicFlushWaits())
{
    Console.Error.WriteLine("exact_analyzer_classic_flush_smoke_failed");
    return 3904;
}

if (!SichuanTheorySmoke.ScoringProjectionMatchesFrozenRules())
{
    Console.Error.WriteLine("scoring_projection_contract_smoke_failed");
    return 3905;
}

if (!SichuanTheorySmoke.PdfSixExpectedValueExampleIsExact())
{
    Console.Error.WriteLine("pdf6_expected_value_smoke_failed");
    return 3906;
}

if (!SichuanTheorySmoke.HiddenInferenceConservesProbability())
{
    Console.Error.WriteLine("hidden_inference_probability_smoke_failed");
    return 3907;
}

if (!SichuanTheorySmoke.QingPlannerPrefersDiscardingOffSuit())
{
    Console.Error.WriteLine("qing_planner_off_suit_smoke_failed");
    return 3908;
}

if (!SichuanTheorySmoke.UnifiedHuUsesExpectedValueContract())
{
    Console.Error.WriteLine("unified_hu_expected_value_smoke_failed");
    return 3909;
}

if (!SichuanTheorySmoke.IndependentJudgeDoesNotReadOnlineScore())
{
    Console.Error.WriteLine("independent_judge_isolation_smoke_failed");
    return 3910;
}

if (!SichuanTheorySmoke.LegalActionsAndTransitionsRespectSichuanRules())
{
    Console.Error.WriteLine("sichuan_legal_transition_smoke_failed");
    return 3911;
}

if (!SichuanTheorySmoke.PublicInferenceBeatsUniformOnBehaviorConsistentHand())
{
    Console.Error.WriteLine("sichuan_inference_calibration_smoke_failed");
    return 3912;
}

if (!SichuanTheorySmoke.MultiPlayerUtilityHonorsStrategicRiskBounds())
{
    Console.Error.WriteLine("sichuan_multiplayer_utility_bounds_smoke_failed");
    return 3913;
}

if (!SichuanTheorySmoke.MeldCounterfactualChargesRouteAndRisk())
{
    Console.Error.WriteLine("sichuan_meld_counterfactual_smoke_failed");
    return 3914;
}

if (!SichuanTheorySmoke.IndependentJudgeCoversReactionAndSelfActions())
{
    Console.Error.WriteLine("sichuan_independent_all_actions_smoke_failed");
    return 3915;
}

if (!SichuanTheorySmoke.ReplayJudgeAggregatesAllActionsCalibrationAndPdfSources())
{
    Console.Error.WriteLine("sichuan_independent_replay_metrics_smoke_failed");
    return 39151;
}

if (!SichuanTheorySmoke.GoldenPdfWaitCasesPass())
{
    Console.Error.WriteLine("sichuan_golden_pdf_waits_smoke_failed");
    return 3916;
}

if (!SichuanTheorySmoke.ExactAnalyzerExhaustivelyMatchesShanten())
{
    Console.Error.WriteLine("sichuan_exact_exhaustive_smoke_failed");
    return 3917;
}

if (!SichuanTheorySmoke.ExactScoringAndSettlementBreakdownIsComplete())
{
    Console.Error.WriteLine("sichuan_exact_scoring_settlement_smoke_failed");
    return 3918;
}

if (!SichuanTheorySmoke.PublicEventsRebuildThePublicTableExactly())
{
    Console.Error.WriteLine("sichuan_public_event_replay_smoke_failed");
    return 3919;
}

if (!SichuanTheorySmoke.QingPlannerDistinguishesStrongWeakOverlapAndCompetition())
{
    Console.Error.WriteLine("sichuan_qing_planner_strategy_smoke_failed");
    return 3920;
}

if (!SichuanTheorySmoke.ChanceSearchModelsOrderThreatGangAndBudget())
{
    Console.Error.WriteLine("sichuan_chance_search_smoke_failed");
    return 3921;
}

if (!SichuanTheorySmoke.UnifiedDecisionRanksAllLegalActionsAndCompositeTriplets())
{
    Console.Error.WriteLine("sichuan_unified_all_actions_smoke_failed");
    return 3922;
}

return 0;

static bool SmokeReactionTransitionsRespectTiming()
{
	var hand = SichuanTileCodec.BuildCount18(new[] { 4, 4, 4, 0, 1, 2, 9, 10, 11, 18, 19, 20, 6 });
	var state = SichuanStateCodec.FromRaw(1, 0, 1, 24, hand, new int[27], roundIndex: 20260809);
	var transitions = new SichuanActionTransitionEngine();
	var start = transitions.FromState(state);
	var pass = transitions.ApplyPass(start);
	var peng = transitions.ApplyPeng(start, 4);
	var gang = transitions.ApplyMeldedGang(start, 4);
	var replacement = transitions.ApplyReplacementDraw(gang, 8);
	var evaluator = new SichuanMeldCounterfactualEvaluator();
	var passValue = evaluator.Evaluate(state, "pass", 4, 0, start.MeldCount, 0, 0, 0);
	var gangValue = evaluator.Evaluate(state, "gang", 4, 3, start.MeldCount + 1, 0, 0, 2);
	var passed = pass.Hand27.Sum() == start.Hand27.Sum()
		&& pass.WallCount == start.WallCount
		&& peng.Hand27.Sum() == start.Hand27.Sum() - 2
		&& peng.WallCount == start.WallCount
		&& gang.Hand27.Sum() == start.Hand27.Sum() - 3
		&& gang.WallCount == start.WallCount
		&& replacement.Hand27.Sum() == gang.Hand27.Sum() + 1
		&& replacement.WallCount == start.WallCount - 1
		&& passValue.BestDiscardTile == -1
		&& passValue.Transition == "pass_wait_draw"
		&& gangValue.Transition == "gang_replacement_draw_then_discard";
	Console.WriteLine($"reaction_timing pass={pass.Hand27.Sum()}/{pass.WallCount} peng={peng.Hand27.Sum()}/{peng.WallCount} gang={gang.Hand27.Sum()}/{gang.WallCount} replacement={replacement.Hand27.Sum()}/{replacement.WallCount}");
	return passed;
}

static bool SmokeMutuallyExclusiveShapePreservesPairRoutes()
{
	var fivePairs = SichuanTileCodec.BuildCount18(new[] { 0, 0, 2, 2, 9, 9, 11, 11, 18, 18, 4, 5, 6, 7 });
	var composite = SichuanTileCodec.BuildCount18(new[] { 1, 1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 14, 16 });
	var remaining = Enumerable.Repeat(4, 27).ToArray();
	for (var tile = 0; tile < 27; tile++)
	{
		remaining[tile] = Math.Max(0, remaining[tile] - fivePairs[tile]);
	}
	var engine = new SichuanHandShapeEngine();
	var pairShape = engine.Evaluate(fivePairs, remaining, 0, 2);
	var compositeShape = engine.Evaluate(composite, Enumerable.Repeat(2, 27).ToArray(), 0, 1);
	Console.WriteLine($"shape_profiles pairs={pairShape.AlternativeDecompositionCount} pressure={pairShape.PairPressure} composite={compositeShape.AlternativeDecompositionCount} blocks={compositeShape.BestBlockCount}");
	return pairShape.PairPressure == 0
		&& pairShape.AlternativeDecompositionCount >= 1
		&& compositeShape.AlternativeDecompositionCount >= 2
		&& compositeShape.BestBlockCount >= 4;
}

static bool SmokeAiContextStageExplainAndPerf(SichuanAiFacade facade)
{
    var discards = new[]
    {
        new List<int> { 0, 9, 1, 10, 2, 11 },
        new List<int> { 3, 12, 4, 13, 5 },
        new List<int> { 6, 15, 7, 16 },
        new List<int> { 8, 17, 0, 9 }
    };
    var melds = new[]
    {
        new List<int>(),
        new List<int> { 6, 6, 6 },
        new List<int>(),
        new List<int>()
    };
    var state = SichuanStateCodec.FromRaw(
        0,
        0,
        0,
        6,
        new[] { 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 },
        new[] { 2, 2, 2, 1, 2, 1, 3, 2, 1, 2, 2, 1, 2, 1, 0, 1, 1, 1 },
        discards18: discards,
        melds18: melds,
        scores: new[] { 4, 0, -2, -2 },
        roundIndex: 3,
        totalRounds: 0,
        remainingRounds: 0,
        visibleVersion: 101,
        handVersion: 17,
        strategyContextVersion: 118);
    state.IsCalled[1] = true;
    state.IsReady[1] = true;

    var result = facade.DecideDiscard(state);
    Console.WriteLine($"ai_context_stage={result.AiContext?.Stage.Stage} mode={result.AiContext?.StrategyMode.Mode} explain={string.Join('|', result.Explain.ReasonCodes)} perf={result.Performance.TotalMs:F2}");
    return result.AiContext is not null
        && result.AiContext.Stage.Stage == "late"
        && result.AiContext.Stage.ReasonCode is "STAGE_LATE_BY_REMAINING_TILES" or "STAGE_LATE_BY_READY_PRESSURE"
        && result.Explain.Mode == "normal"
        && result.Explain.ReasonCodes.Count <= 10
        && result.Performance.TotalMs > 0
        && result.Performance.Modules.Count > 0;
}

static bool SmokeAiContextStrategyModes(SichuanAiFacade facade)
{
    var baseHand = new[] { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 };
    var visible = new int[27];
    var chaseState = SichuanStateCodec.FromRaw(
        0,
        0,
        0,
        18,
        baseHand,
        visible,
        scores: new[] { -20, 8, 7, 5 },
        roundIndex: 8,
        totalRounds: 8,
        remainingRounds: 1,
        visibleVersion: 210,
        handVersion: 20,
        strategyContextVersion: 230);
    var chaseResult = facade.DecideDiscard(chaseState);

    var protectDiscards = new[]
    {
        new List<int> { 0, 9, 1, 10 },
        new List<int> { 2, 11, 3, 12, 4, 13, 5 },
        new List<int> { 6, 15, 7 },
        new List<int> { 8, 17, 0 }
    };
    var protectMelds = new[]
    {
        new List<int>(),
        new List<int> { 6, 6, 6, 7, 7, 7 },
        new List<int>(),
        new List<int>()
    };
    var protectState = SichuanStateCodec.FromRaw(
        0,
        0,
        0,
        9,
        baseHand,
        visible,
        discards18: protectDiscards,
        melds18: protectMelds,
        scores: new[] { 25, -7, -9, -9 },
        roundIndex: 7,
        totalRounds: 8,
        remainingRounds: 2,
        visibleVersion: 310,
        handVersion: 20,
        strategyContextVersion: 330);
    protectState.IsCalled[1] = true;
    protectState.IsReady[1] = true;
    var protectResult = facade.DecideDiscard(protectState);

    Console.WriteLine($"ai_context_chase_mode={chaseResult.AiContext?.StrategyMode.Mode} protect_mode={protectResult.AiContext?.StrategyMode.Mode} protect_goal={protectResult.AiContext?.RoundGoal.Goal}");
    return chaseResult.AiContext?.StrategyMode.Mode == "chase"
        && protectResult.AiContext?.RoundGoal.Goal == "protect_lead"
        && protectResult.AiContext.StrategyMode.Mode is "defense" or "fold" or "attack";
}

static bool SmokePassesNoSpeedPeng(SichuanAiFacade facade)
{
    var pairTile = SichuanTileCodec.EncodeTileType(1, 8);
    var hand = new[]
    {
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(0, 6),
        SichuanTileCodec.EncodeTileType(0, 7),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 5),
        SichuanTileCodec.EncodeTileType(1, 6),
        pairTile,
        pairTile,
        SichuanTileCodec.EncodeTileType(1, 9),
    };
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 15, SichuanTileCodec.BuildCount18(hand), new int[27]);
    var result = facade.DecideReaction(state, pairTile, false, true, false, 0, "discard");
    Console.WriteLine($"peng_smoke_action={result.Action.ActionType} score={result.Action.Score} pass={result.ActionScores.GetValueOrDefault("pass")} current={result.CurrentShanten}/{result.CurrentLiveUkeire} after={result.ShantenAfter}/{result.LiveUkeireAfter}");
    return result.Action.ActionType == SichuanActionType.Pass
        && result.ShantenAfter >= result.CurrentShanten
        && result.LiveUkeireAfter <= result.CurrentLiveUkeire;
}

static bool SmokeReasonableAnGang(SichuanAiFacade facade)
{
    var gangTile = SichuanTileCodec.EncodeTileType(1, 8);
    var hand = new[]
    {
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(0, 6),
        SichuanTileCodec.EncodeTileType(0, 7),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 5),
        gangTile,
        gangTile,
        gangTile,
        gangTile,
        SichuanTileCodec.EncodeTileType(1, 9),
    };
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 15, SichuanTileCodec.BuildCount18(hand), new int[27]);
    var result = facade.DecideSelfAction(state, false, new[] { gangTile }, Array.Empty<int>());
    Console.WriteLine($"an_gang_smoke_action={result.Action.ActionType} score={result.Action.Score} pass={result.ActionScores.GetValueOrDefault("pass")}");
    return result.Action.ActionType == SichuanActionType.Gang;
}

static bool SmokeBeliefReuseWithinReaction(SichuanAiFacade facade)
{
    var tile = SichuanTileCodec.EncodeTileType(1, 5);
    var hand18 = new int[27];
    hand18[0] = 1;
    hand18[1] = 1;
    hand18[2] = 1;
    hand18[3] = 1;
    hand18[4] = 1;
    hand18[5] = 1;
    hand18[9] = 1;
    hand18[10] = 1;
    hand18[11] = 1;
    hand18[tile] = 3;
    hand18[17] = 1;
    SichuanBeliefEngine.ResetDiagnostics();
    var state = SichuanStateCodec.FromRaw(2, 0, 2, 12, hand18, new int[27]);
    var result = facade.DecideReaction(state, tile, false, true, true, 1, "discard");
    var diagnostics = SichuanBeliefEngine.GetDiagnostics();
    Console.WriteLine($"belief_reaction_action={result.Action.ActionType} calls={diagnostics.CallCount} builds={diagnostics.BuildCount} hits={diagnostics.CacheHits}");
    return diagnostics.CallCount <= 1 && diagnostics.BuildCount <= 1;
}

static bool SmokeBeliefReuseWithinSelfAction(SichuanAiFacade facade)
{
    var gangTile = SichuanTileCodec.EncodeTileType(1, 8);
    var hand = new[]
    {
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(0, 6),
        SichuanTileCodec.EncodeTileType(0, 7),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 5),
        gangTile,
        gangTile,
        gangTile,
        gangTile,
        SichuanTileCodec.EncodeTileType(1, 9),
    };
    SichuanBeliefEngine.ResetDiagnostics();
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 15, SichuanTileCodec.BuildCount18(hand), new int[27]);
    var result = facade.DecideSelfAction(state, false, new[] { gangTile }, Array.Empty<int>());
    var diagnostics = SichuanBeliefEngine.GetDiagnostics();
    Console.WriteLine($"belief_self_action={result.Action.ActionType} calls={diagnostics.CallCount} builds={diagnostics.BuildCount} hits={diagnostics.CacheHits}");
    return diagnostics.CallCount <= 1 && diagnostics.BuildCount <= 1;
}

static bool SmokeMobileReactionSkipsShortSearch(SichuanAiFacade facade)
{
    var tile = SichuanTileCodec.EncodeTileType(1, 9);
    var hand18 = new int[27];
    hand18[0] = 1;
    hand18[1] = 1;
    hand18[2] = 1;
    hand18[3] = 1;
    hand18[4] = 1;
    hand18[5] = 1;
    hand18[11] = 1;
    hand18[12] = 1;
    hand18[13] = 1;
    hand18[14] = 1;
    hand18[15] = 1;
    hand18[tile] = 2;
    var state = SichuanStateCodec.FromRaw(3, 3, 2, 14, hand18, new int[27]);
    var result = facade.DecideReaction(state, tile, false, true, false, 2, "discard", forceLightweight: true);
    Console.WriteLine($"mobile_reaction_action={result.Action.ActionType} search_used={result.SearchUsed} simulations={result.SearchSimulations}");
    return !result.SearchUsed && result.SearchSimulations == 0;
}

static bool SmokeBeliefCacheExactStateHit()
{
    var beliefEngine = new SichuanBeliefEngine();
    var hand = new[]
    {
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(0, 6),
        SichuanTileCodec.EncodeTileType(0, 7),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 5),
        SichuanTileCodec.EncodeTileType(1, 6),
        SichuanTileCodec.EncodeTileType(1, 7),
        SichuanTileCodec.EncodeTileType(1, 8),
    };
    var state = SichuanStateCodec.FromRaw(0, 0, 0, 14, SichuanTileCodec.BuildCount18(hand), new int[27]);
    SichuanBeliefEngine.ResetDiagnostics();
    beliefEngine.Build(state);
    beliefEngine.Build(state);
    var diagnostics = SichuanBeliefEngine.GetDiagnostics();
    Console.WriteLine($"belief_cache_calls={diagnostics.CallCount} builds={diagnostics.BuildCount} hits={diagnostics.CacheHits}");
    return diagnostics.CallCount == 2 && diagnostics.BuildCount == 1 && diagnostics.CacheHits == 1;
}

static bool SmokeEarlyBigPairRouteKeepsPair(SichuanAiFacade facade)
{
    var hand18 = new int[27];
    hand18[4] = 1;  // 5条 singleton
    hand18[6] = 1;  // 7条 singleton
    hand18[8] = 2;  // 9条 pair should be preserved for 对子胡 route
    hand18[11] = 1; // 3筒 singleton
    hand18[13] = 1; // 5筒 singleton
    hand18[15] = 2; // 7筒 pair
    hand18[16] = 2; // 8筒 pair

    var melds = new[]
    {
        Array.Empty<int>(),
        Array.Empty<int>(),
        Array.Empty<int>(),
        new[] { 1, 1, 1, 14, 14, 14 },
    };
    var visible18 = new int[27];
    foreach (var tileType in melds[3])
        visible18[tileType]++;

    var state = SichuanStateCodec.FromRaw(3, 0, 3, 16, hand18, visible18, null, null, melds);
    var result = facade.DecideDiscard(state);
    var nineTiao = result.Candidates.First(candidate => candidate.TileType == 8);
    var threeTong = result.Candidates.First(candidate => candidate.TileType == 11);
    var fiveTong = result.Candidates.First(candidate => candidate.TileType == 13);
    var eightTong = result.Candidates.First(candidate => candidate.TileType == 16);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    Console.WriteLine($"early_big_pair_tile={result.Action.TileType} selected_routes={string.Join('/', selected.RoutesAfter)} nine_score={nineTiao.Score} eight_tong={eightTong.Score} three_tong={threeTong.Score} five_tong={fiveTong.Score} nine_routes={string.Join('/', nineTiao.RoutesAfter)}");
    return result.Action.TileType != 8
        && result.Action.TileType != 15
        && result.Action.TileType != 16
        && selected.RoutesAfter.Contains("对对胡")
        && nineTiao.Score < Math.Max(threeTong.Score, fiveTong.Score)
        && eightTong.Score < Math.Max(threeTong.Score, fiveTong.Score)
        && (threeTong.RoutesAfter.Contains("对对胡") || fiveTong.RoutesAfter.Contains("对对胡"));
}

static bool SmokeFastReadyBeatsUnreadyBigPairRoute(SichuanAiFacade facade)
{
    var hand18 = SichuanTileCodec.BuildCount18(new[] { 0, 0, 1, 1, 2, 2, 4, 5, 6, 10, 11, 12, 13, 14 });
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 16, hand18, new int[27]);
    var result = facade.DecideDiscard(state);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    var unreadyCandidates = result.Candidates.Where(candidate => candidate.Shanten > 0).ToArray();
    Console.WriteLine($"fast_ready_priority_tile={result.Action.TileType} shanten={selected.Shanten} wait={selected.WaitCount} reasons={string.Join('|', selected.Reasons)} top={string.Join(',', result.Candidates.Take(5).Select(candidate => $"{candidate.TileType}:{candidate.Score}/{candidate.Shanten}/{candidate.WaitCount}"))}");
    return selected.Shanten <= 0
        && selected.WaitCount > 0
        && unreadyCandidates.Length > 0
        && selected.Reasons.Any(reason => reason.Contains("能成叫先成叫", StringComparison.Ordinal));
}

static bool SmokeBigPairRouteDoesNotOverrideLargeScoreGap()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "IsBetterDiscardCandidate",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var bigRouteButLowScore = new SichuanCandidateDetail
    {
        TileType = 2,
        Score = 1000,
        Shanten = 1,
        Danger = 74,
        LiveUkeire = 3,
        WaitCount = 0,
        RoutesAfter = new[] { "七对" }
    };
    var ordinaryButClearlyBetter = new SichuanCandidateDetail
    {
        TileType = 10,
        Score = 3200,
        Shanten = 1,
        Danger = 18,
        LiveUkeire = 10,
        WaitCount = 0,
        RoutesAfter = Array.Empty<string>()
    };

    var context = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "balanced" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "balanced_ev" }
    };
    var prefersBigRoute = (bool?)method.Invoke(null, new object[] { bigRouteButLowScore, ordinaryButClearlyBetter, 1, context }) ?? true;
    Console.WriteLine($"big_pair_route_gap_prefers_big={prefersBigRoute} big={bigRouteButLowScore.Score}/{bigRouteButLowScore.Danger} ordinary={ordinaryButClearlyBetter.Score}/{ordinaryButClearlyBetter.Danger}");
    return !prefersBigRoute;
}

static bool SmokeChaseSortPrefersHigherScoreRoute()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "SortDiscardCandidates",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var fasterLowValue = new SichuanCandidateDetail
    {
        TileType = 3,
        Score = 2500,
        Shanten = 0,
        Danger = 28,
        LiveUkeire = 6,
        WaitCount = 2,
        ExpectedNetScore = 1.2,
        RoutesAfter = Array.Empty<string>()
    };
    var slowerHighValue = new SichuanCandidateDetail
    {
        TileType = 12,
        Score = 3350,
        Shanten = 1,
        Danger = 35,
        LiveUkeire = 12,
        WaitCount = 0,
        ExpectedNetScore = 3.6,
        RoutesAfter = new[] { "清一色" }
    };
    var context = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "chase" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "chase_score" }
    };

    var sorted = method.Invoke(null, new object[] { new[] { fasterLowValue, slowerHighValue }, 1, context }) as IReadOnlyList<SichuanCandidateDetail>;
    var top = sorted?.FirstOrDefault();
    Console.WriteLine($"chase_sort_top={top?.TileType} faster={fasterLowValue.Score}/{fasterLowValue.Shanten} slower={slowerHighValue.Score}/{slowerHighValue.Shanten}/{string.Join('/', slowerHighValue.RoutesAfter)}");
    return top?.TileType == slowerHighValue.TileType;
}

static bool SmokeDefenseSortPrefersSafeCandidate()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "SortDiscardCandidates",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var riskyHighValue = new SichuanCandidateDetail
    {
        TileType = 7,
        Score = 3600,
        Shanten = 0,
        Danger = 76,
        LiveUkeire = 8,
        WaitCount = 2,
        ExpectedNetScore = 2.7
    };
    var safeLowerValue = new SichuanCandidateDetail
    {
        TileType = 16,
        Score = 3050,
        Shanten = 1,
        Danger = 18,
        LiveUkeire = 5,
        WaitCount = 0,
        ExpectedNetScore = 1.5
    };
    var context = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "defense" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "protect_lead" }
    };

    var sorted = method.Invoke(null, new object[] { new[] { riskyHighValue, safeLowerValue }, 2, context }) as IReadOnlyList<SichuanCandidateDetail>;
    var top = sorted?.FirstOrDefault();
    Console.WriteLine($"defense_sort_top={top?.TileType} risky={riskyHighValue.Score}/{riskyHighValue.Danger} safe={safeLowerValue.Score}/{safeLowerValue.Danger}");
    return top?.TileType == riskyHighValue.TileType
        && riskyHighValue.Shanten <= 0
        && riskyHighValue.WaitCount > 0
        && riskyHighValue.Danger < 78;
}

static bool SmokeProtectLeadSortDoesNotOverpayForTinyDangerDifference()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "SortDiscardCandidates",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var tinySaferLowValue = new SichuanCandidateDetail
    {
        TileType = 17,
        Score = 1273,
        Shanten = 2,
        Danger = 23,
        LiveUkeire = 18,
        WaitCount = 0,
        ExpectedNetScore = 0.2
    };
    var sameSafetyMuchHigherValue = new SichuanCandidateDetail
    {
        TileType = 9,
        Score = 5696,
        Shanten = 2,
        Danger = 25,
        LiveUkeire = 22,
        WaitCount = 0,
        ExpectedNetScore = 5.6
    };
    var context = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "balanced" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "protect_lead" }
    };

    var sorted = method.Invoke(null, new object[] { new[] { tinySaferLowValue, sameSafetyMuchHigherValue }, 0, context }) as IReadOnlyList<SichuanCandidateDetail>;
    var top = sorted?.FirstOrDefault();
    Console.WriteLine($"protect_lead_tiny_danger_top={top?.TileType} low={tinySaferLowValue.Score}/{tinySaferLowValue.Danger} high={sameSafetyMuchHigherValue.Score}/{sameSafetyMuchHigherValue.Danger}");
    return top?.TileType == sameSafetyMuchHigherValue.TileType;
}

static bool SmokeProtectLeadEarlyKeepsBalancedProgress()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "SortDiscardCandidates",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var overSafeLowValue = new SichuanCandidateDetail
    {
        TileType = 9,
        Score = -1472,
        Shanten = 2,
        Danger = 21,
        LiveUkeire = 32,
        WaitCount = 0,
        ExpectedNetScore = -1.4
    };
    var balancedProgress = new SichuanCandidateDetail
    {
        TileType = 8,
        Score = 2032,
        Shanten = 2,
        Danger = 35,
        LiveUkeire = 36,
        WaitCount = 0,
        ExpectedNetScore = 2.0
    };
    var context = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "balanced" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "protect_lead" }
    };

    var sorted = method.Invoke(null, new object[] { new[] { overSafeLowValue, balancedProgress }, 1, context }) as IReadOnlyList<SichuanCandidateDetail>;
    var top = sorted?.FirstOrDefault();
    Console.WriteLine($"protect_lead_early_top={top?.TileType} safe={overSafeLowValue.Score}/{overSafeLowValue.Danger} progress={balancedProgress.Score}/{balancedProgress.Danger}");
    return top?.TileType == balancedProgress.TileType;
}

static bool SmokeFoldSortUsesSafetyBandsWithoutTinyDangerOverpay()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "SortDiscardCandidates",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var tinySaferReady = new SichuanCandidateDetail
    {
        TileType = 10,
        Score = 3515,
        Shanten = 0,
        Danger = 52,
        LiveUkeire = 4,
        WaitCount = 2,
        ExpectedNetScore = 3.5
    };
    var sameBandBetterReady = new SichuanCandidateDetail
    {
        TileType = 11,
        Score = 5296,
        Shanten = 0,
        Danger = 53,
        LiveUkeire = 5,
        WaitCount = 2,
        ExpectedNetScore = 5.2
    };
    var trueSafeFold = new SichuanCandidateDetail
    {
        TileType = 5,
        Score = 750,
        Shanten = 1,
        Danger = 11,
        LiveUkeire = 12,
        WaitCount = 0,
        ExpectedNetScore = 0.7
    };
    var context = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "fold" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "avoid_deal_in" },
        Stage = new SichuanStageContext { StageIndex = 2, WallCount = 6 }
    };

    var withSafe = method.Invoke(null, new object[] { new[] { tinySaferReady, sameBandBetterReady, trueSafeFold }, 2, context }) as IReadOnlyList<SichuanCandidateDetail>;
    var sameBandOnly = method.Invoke(null, new object[] { new[] { tinySaferReady, sameBandBetterReady }, 2, context }) as IReadOnlyList<SichuanCandidateDetail>;
    var safeTop = withSafe?.FirstOrDefault();
    var sameBandTop = sameBandOnly?.FirstOrDefault();
    Console.WriteLine($"fold_sort_safe_top={safeTop?.TileType} same_band_top={sameBandTop?.TileType} safe={trueSafeFold.Score}/{trueSafeFold.Danger} tiny={tinySaferReady.Score}/{tinySaferReady.Danger} better={sameBandBetterReady.Score}/{sameBandBetterReady.Danger}");
    return safeTop?.TileType == sameBandBetterReady.TileType
        && sameBandTop?.TileType == sameBandBetterReady.TileType;
}

static bool SmokeWideTwoAwayHighEvCanBeatNarrowOneAway()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "SortDiscardCandidates",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var narrowOneAway = new SichuanCandidateDetail
    {
        TileType = 14,
        Score = 353,
        Shanten = 1,
        Danger = 36,
        LiveUkeire = 8,
        WaitCount = 0,
        ExpectedNetScore = 0.3
    };
    var wideTwoAwayHighEv = new SichuanCandidateDetail
    {
        TileType = 9,
        Score = 1748,
        Shanten = 2,
        Danger = 23,
        LiveUkeire = 50,
        WaitCount = 0,
        ExpectedNetScore = 1.7
    };
    var attackContext = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "attack" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "balanced_ev" }
    };
    var chaseContext = new SichuanAiContext
    {
        StrategyMode = new SichuanStrategyModeContext { Mode = "chase" },
        RoundGoal = new SichuanRoundGoalContext { Goal = "chase_score" }
    };

    var attackSorted = method.Invoke(null, new object[] { new[] { narrowOneAway, wideTwoAwayHighEv }, 0, attackContext }) as IReadOnlyList<SichuanCandidateDetail>;
    var chaseSorted = method.Invoke(null, new object[] { new[] { narrowOneAway, wideTwoAwayHighEv }, 1, chaseContext }) as IReadOnlyList<SichuanCandidateDetail>;
    var attackTop = attackSorted?.FirstOrDefault();
    var chaseTop = chaseSorted?.FirstOrDefault();
    Console.WriteLine($"wide_two_away_attack_top={attackTop?.TileType} chase_top={chaseTop?.TileType} narrow={narrowOneAway.Score}/{narrowOneAway.Shanten}/{narrowOneAway.LiveUkeire} wide={wideTwoAwayHighEv.Score}/{wideTwoAwayHighEv.Shanten}/{wideTwoAwayHighEv.LiveUkeire}");
    return attackTop?.TileType == wideTwoAwayHighEv.TileType
        && chaseTop?.TileType == wideTwoAwayHighEv.TileType;
}

static bool SmokePotentialFlushPrefersOffSuitDiscard(SichuanAiFacade facade)
{
    var hand18 = SichuanTileCodec.BuildCount18(new[]
    {
        0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 8,
        9, 13, 16
    });
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, hand18, new int[27]);
    var result = facade.DecideDiscard(state);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    var offSuitCandidates = result.Candidates
        .Where(candidate => candidate.TileType >= 9)
        .Select(candidate => $"{candidate.TileType}:{candidate.Score}/{candidate.Shanten}/{candidate.RoutePlanPrimary}")
        .ToArray();
    var targetSuitCandidates = result.Candidates
        .Where(candidate => candidate.TileType < 9)
        .Take(4)
        .Select(candidate => $"{candidate.TileType}:{candidate.Score}/{candidate.Shanten}/{candidate.RoutePlanPrimary}")
        .ToArray();

    Console.WriteLine($"potential_flush_tile={result.Action.TileType} primary={result.RoutePlan.PrimaryRoute} selected_route={selected.RoutePlanPrimary} off={string.Join(',', offSuitCandidates)} target_top={string.Join(',', targetSuitCandidates)} reasons={string.Join('|', selected.Reasons)}");
    return result.Action.TileType >= 9
        && SichuanRoutePlanEngine.IsFlushRoute(result.RoutePlan.PrimaryRoute)
        && selected.Reasons.Any(reason => reason.Contains("清色路线", StringComparison.Ordinal));
}

static bool SmokeQuadTileGetsStrongPreservationPenalty()
{
    var method = typeof(SichuanDecisionEngine).GetMethod(
        "EvaluateSetPreservationAdjustment",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
    if (method is null)
        return false;

    var before = new int[27];
    before[6] = 4;
    var after = (int[])before.Clone();
    after[6] = 3;

    var result = method.Invoke(null, new object[] { before, after, 6, 1 });
    if (result is null)
        return false;
    var scoreProperty = result.GetType().GetProperty("Score");
    var reasonsProperty = result.GetType().GetProperty("Reasons");
    if (scoreProperty is null)
        return false;

    var score = Convert.ToDouble(scoreProperty.GetValue(result));
    var reasons = reasonsProperty?.GetValue(result) as IEnumerable<string> ?? Array.Empty<string>();
    Console.WriteLine($"quad_preservation_score={score:F1} reasons={string.Join('|', reasons)}");
    return score <= -16.0
        && reasons.Any(reason => reason.Contains("四张", StringComparison.Ordinal) || reason.Contains("归", StringComparison.Ordinal));
}

static bool SmokeRoutePlanDiagnosticsAreReturned(SichuanAiFacade facade)
{
    var hand18 = SichuanTileCodec.BuildCount18(new[] { 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 9, 10, 11, 12 });
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 17, hand18, new int[27]);
    var result = facade.DecideDiscard(state);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    Console.WriteLine($"route_plan_diag primary={result.RoutePlan.PrimaryRoute} secondary={string.Join('/', result.RoutePlan.SecondaryRoutes)} selected_route={selected.RoutePlanPrimary} route_score={selected.RoutePlanScore} weights={string.Join(',', result.RoutePlan.RouteWeights.Select(item => $"{item.Key}:{item.Value}"))}");
    return !string.IsNullOrWhiteSpace(result.RoutePlan.PrimaryRoute)
        && result.RoutePlan.RouteWeights.Count > 0
        && !string.IsNullOrWhiteSpace(selected.RoutePlanPrimary)
        && selected.Reasons.Any(reason => reason.Contains("路线", StringComparison.Ordinal));
}

static bool SmokeRoutePlanFivePairsForbidsCalls(SichuanAiFacade facade)
{
    var hand18 = new int[27];
    hand18[0] = 3; // 1条 triplet: pair route plus visible gang chance.
    hand18[1] = 2;
    hand18[2] = 2;
    hand18[3] = 2;
    hand18[4] = 2;
    hand18[5] = 1;
    hand18[14] = 1;
    var state = SichuanStateCodec.FromRaw(2, 0, 2, 17, hand18, new int[27]);
    var result = facade.DecideReaction(state, 0, false, true, true, 1, "discard");
    Console.WriteLine($"route_plan_five_pairs_call action={result.Action.ActionType} pass={result.ActionScores.GetValueOrDefault("pass")} peng={result.ActionScores.GetValueOrDefault("peng")} gang={result.ActionScores.GetValueOrDefault("gang")} reasons={string.Join('|', result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Pass
        && result.ActionScores.GetValueOrDefault("peng") < result.ActionScores.GetValueOrDefault("pass")
        && result.ActionScores.GetValueOrDefault("gang") < result.ActionScores.GetValueOrDefault("pass")
        && result.Reasons.Any(reason => reason.Contains("七对路线", StringComparison.Ordinal));
}

static bool SmokeRoutePlanThreePairsStaysFlexible(SichuanAiFacade facade)
{
    var hand18 = SichuanTileCodec.BuildCount18(new[] { 0, 0, 1, 1, 2, 2, 3, 4, 5, 9, 10, 11, 12, 13 });
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 17, hand18, new int[27]);
    var result = facade.DecideDiscard(state);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    Console.WriteLine($"route_plan_three_pairs primary={result.RoutePlan.PrimaryRoute} selected={result.Action.TileType} selected_route={selected.RoutePlanPrimary} reasons={string.Join('|', selected.Reasons)}");
    return result.RoutePlan.PrimaryRoute != "暗七对"
        && result.RoutePlan.PrimaryRoute != "龙七对"
        && selected.Reasons.Any(reason => reason.Contains("平胡", StringComparison.Ordinal) || reason.Contains("速度", StringComparison.Ordinal) || reason.Contains("下叫", StringComparison.Ordinal));
}

static bool SmokeRoutePlanSevenPairsRejectsSelfGang(SichuanAiFacade facade)
{
    var hand18 = new int[27];
    hand18[0] = 4;
    hand18[1] = 2;
    hand18[2] = 2;
    hand18[3] = 2;
    hand18[4] = 2;
    hand18[5] = 1;
    hand18[14] = 1;
    var state = SichuanStateCodec.FromRaw(2, 0, 2, 17, hand18, new int[27]);
    var result = facade.DecideSelfAction(state, false, new[] { 0 }, Array.Empty<int>());
    Console.WriteLine($"route_plan_self_gang action={result.Action.ActionType} pass={result.ActionScores.GetValueOrDefault("pass")} gang={result.ActionScores.GetValueOrDefault("an_gang:0")} reasons={string.Join('|', result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Pass
        && result.ActionScores.GetValueOrDefault("an_gang:0") < result.ActionScores.GetValueOrDefault("pass")
        && result.Reasons.Any(reason => reason.Contains("七对路线", StringComparison.Ordinal));
}

static bool SmokeAvoidsUnnecessaryTripletBreak(SichuanAiFacade facade)
{
    var hand18 = new[] { 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 2, 1, 1, 3 };
    var visible18 = new[] { 2, 1, 1, 0, 1, 0, 1, 0, 2, 2, 1, 0, 1, 4, 2, 1, 2, 3 };
    var remaining18 = new[] { 2, 3, 3, 4, 3, 4, 3, 4, 2, 2, 3, 4, 3, 0, 2, 3, 2, 1 };
    var discards = new[]
    {
        new[] { 16 },
        new[] { 9, 0 },
        new[] { 9, 8 },
        new[] { 10, 8 },
    };
    var melds = new[]
    {
        Array.Empty<int>(),
        Array.Empty<int>(),
        Array.Empty<int>(),
        new[] { 13, 13, 13 },
    };

    var state = SichuanStateCodec.FromRaw(2, 2, 2, 12, hand18, visible18, remaining18, discards, melds);
    var result = facade.DecideDiscard(state);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    var nineTong = result.Candidates.First(candidate => candidate.TileType == 17);
    var top = string.Join(",", result.Candidates.Take(5).Select(candidate => $"{candidate.TileType}:{candidate.Score}/u{candidate.UnifiedActionValue:F2}/r{candidate.StrategicResidual:F2}/triplet={candidate.BreaksTriplet}"));
    Console.WriteLine($"triplet_break_regression_tile={result.Action.TileType} selected_breaks_triplet={selected.BreaksTriplet} nine_score={nineTong.Score} nine_penalty={nineTong.SetPreservationScore:F1} top={top}");
    return result.Action.TileType != 17
        && !selected.BreaksTriplet
        && nineTong.BreaksTriplet
        && nineTong.SetPreservationScore < 0;
}

static bool SmokeReactionPassesSevenPairsTenpai(SichuanAiFacade facade)
{
    var hand18 = new int[27];
    hand18[0] = 2;  // 1条 pair
    hand18[1] = 2;  // 2条 pair
    hand18[2] = 1;  // 3条 singleton wait for 七对
    hand18[5] = 2;  // 6条 pair; opponent discards another 6条
    hand18[7] = 2;  // 8条 pair
    hand18[16] = 2; // 8筒 pair
    hand18[17] = 2; // 9筒 pair
    var state = SichuanStateCodec.FromRaw(3, 0, 3, 10, hand18, new int[27]);
    var result = facade.DecideReaction(state, 5, false, true, false, 1, "discard");
    Console.WriteLine($"seven_pairs_tenpai_reaction_action={result.Action.ActionType} peng={result.ActionScores.GetValueOrDefault("peng")} pass={result.ActionScores.GetValueOrDefault("pass")}");
    return result.Action.ActionType == SichuanActionType.Pass
        && result.ActionScores.GetValueOrDefault("peng") < result.ActionScores.GetValueOrDefault("pass");
}

static bool SmokeReactionPrefersReadyPengWhenGangWouldLoseReady(SichuanAiFacade facade)
{
    var hand18 = new int[27];
    hand18[2] = 1;  // 3条
    hand18[11] = 1; // 3筒
    hand18[13] = 3; // 5筒 triplet; opponent discards the fourth 5筒
    hand18[16] = 2; // 8筒 pair

    var discards = new[]
    {
        new[] { 6, 9, 0, 13 },
        new[] { 6, 6, 9 },
        new[] { 0, 7, 9, 7 },
        new[] { 0, 7, 14, 0 },
    };
    var melds = new[]
    {
        new[] { 3, 3, 3, 1, 1, 1, 15, 15, 15 },
        new[] { 5, 5, 5, 5, 11, 11, 11 },
        new[] { 17, 17, 17, 17, 8, 8, 8 },
        new[] { 10, 10, 10, 10, 4, 4, 4, 4 },
    };
    var visible18 = new int[27];
    foreach (var seatDiscards in discards)
    {
        foreach (var tileType in seatDiscards)
            visible18[tileType]++;
    }
    foreach (var seatMelds in melds)
    {
        foreach (var tileType in seatMelds)
            visible18[tileType]++;
    }

    var state = SichuanStateCodec.FromRaw(2, 0, 2, 1, hand18, visible18, null, discards, melds);
    var result = facade.DecideReaction(state, 13, false, true, true, 0, "discard");
    Console.WriteLine($"ready_peng_over_unready_gang_action={result.Action.ActionType} gang={result.ActionScores.GetValueOrDefault("gang")} peng={result.ActionScores.GetValueOrDefault("peng")} shanten={result.ShantenAfter}");
    return result.Action.ActionType == SichuanActionType.Peng
        && result.ShantenAfter <= 0
        && result.ActionScores.GetValueOrDefault("peng") > result.ActionScores.GetValueOrDefault("gang");
}

static bool SmokeHellChallengePengRediscardPenaltyIsDecisive()
{
    var aiHand = new[] { 0, 0, 0, 1, 1, 2, 0, 3, 0, 0, 1, 1, 0, 1, 2, 0, 0, 1 };
    var state = SichuanStateCodec.FromRaw(3, 2, 3, 16, aiHand, new int[27]);
    var allHands = new[]
    {
        new[] { 1, 1, 0, 0, 1, 2, 2, 0, 1, 2, 0, 1, 2, 0, 0, 0, 0, 0 },
        new[] { 0, 1, 0, 0, 0, 0, 1, 0, 2, 1, 0, 1, 0, 1, 1, 1, 1, 0 },
        new[] { 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 2, 0, 1, 1, 0, 0, 0, 2 },
        aiHand
    };
    var exactWall = new[] { 0, 2, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1 };

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 7,
        canHu: false,
        canPeng: true,
        canGang: true,
        sourceSeat: 1,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { -1, 0, -2, 3 });

    var sameTilePenalty = result.ActionScores.GetValueOrDefault("peng_rediscard_same_tile_penalty", 0);
    var weakOverGangPenalty = result.ActionScores.GetValueOrDefault("peng_weak_over_gang_penalty", 0);
    Console.WriteLine($"hell_challenge_peng_rediscard_decisive action={result.Action.ActionType} gang={result.ActionScores.GetValueOrDefault("gang", int.MinValue)} peng={result.ActionScores.GetValueOrDefault("peng", int.MinValue)} same_penalty={sameTilePenalty} weak_penalty={weakOverGangPenalty}");
    return result.Action.ActionType == SichuanActionType.Gang
        && (sameTilePenalty <= -5000 || weakOverGangPenalty < 0)
        && result.ActionScores.GetValueOrDefault("gang", int.MinValue) > result.ActionScores.GetValueOrDefault("peng", int.MinValue);
}

static bool SmokeReactionAllowsSameShantenPengForLargeLiveGain(SichuanAiFacade facade)
{
    var hand18 = new[] { 1, 1, 2, 1, 0, 0, 2, 2, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0 };
    var discards = new[]
    {
        new[] { 8 },
        new[] { 8, 5, 7 },
        new[] { 5, 9, 13 },
        Array.Empty<int>(),
    };
    var melds = new[]
    {
        Array.Empty<int>(),
        Array.Empty<int>(),
        new[] { 0, 0, 0, 16, 16, 16 },
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(3, 2, 1, 12, hand18, discards, melds);
    state.HasHu[2] = true;
    var result = facade.DecideReaction(state, 7, false, true, false, 1, "discard");
    Console.WriteLine($"reaction_wide_no_speed_peng_action={result.Action.ActionType} pass={result.ActionScores.GetValueOrDefault("pass")} peng={result.ActionScores.GetValueOrDefault("peng")} current={result.CurrentShanten}/{result.CurrentLiveUkeire} after={result.ShantenAfter}/{result.LiveUkeireAfter}");
	return result.Action.ActionType == SichuanActionType.Peng
		&& result.ShantenAfter == result.CurrentShanten
		&& result.CurrentLiveUkeire >= 12
		&& result.LiveUkeireAfter >= result.CurrentLiveUkeire + 8
		&& result.ActionScores.GetValueOrDefault("peng") > result.ActionScores.GetValueOrDefault("pass");
}

static bool SmokeLateWallPassesNarrowNoSpeedPeng(SichuanAiFacade facade)
{
    var hand18 = new[] { 0, 2, 0, 2, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 2, 0, 0, 2 };
    var discards = new[]
    {
        new[] { 12, 10, 16, 16, 1 },
        new[] { 4, 12, 12, 2, 10 },
        new[] { 10, 13, 1, 0 },
        new[] { 9, 10 },
    };
    var melds = new[]
    {
        new[] { 0, 0, 0, 2, 2, 2 },
        new[] { 9, 9, 9, 13, 13, 13 },
        new[] { 11, 11, 11, 4, 4, 4 },
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(3, 0, 0, 4, hand18, discards, melds);
    var result = facade.DecideReaction(state, 1, false, true, false, 0, "discard");
    Console.WriteLine($"late_wall_no_speed_peng_action={result.Action.ActionType} pass={result.ActionScores.GetValueOrDefault("pass")} peng={result.ActionScores.GetValueOrDefault("peng")} current_live={result.CurrentLiveUkeire} after_live={result.LiveUkeireAfter}");
    return result.Action.ActionType == SichuanActionType.Pass
        && result.ShantenAfter == result.CurrentShanten
        && result.ActionScores.GetValueOrDefault("peng") < result.ActionScores.GetValueOrDefault("pass");
}

static bool SmokeLateWallKeepsReadyOverSafeFold(SichuanAiFacade facade)
{
    var hand18 = new[]
    {
        1, 0, 0, 0, 0, 0, 1, 0, 0,
        1, 1, 1, 0, 1, 1, 1, 0, 0
    };
    var discards = new[]
    {
        new[] { 17, 9, 7, 12, 4 },
        new[] { 9 },
        new[] { 3, 10, 14, 10, 14 },
        new[] { 4, 3, 2, 4 },
    };
    var melds = new[]
    {
        new[] { 0, 0, 0, 8, 8, 8 },
        new[] { 1, 1, 1 },
        new[] { 5, 5, 5, 16, 16, 16, 16 },
        new[] { 17, 17, 17 },
    };
    var visible18 = new int[27];
    foreach (var seatDiscards in discards)
    {
        foreach (var tileType in seatDiscards)
            visible18[tileType]++;
    }
    foreach (var seatMelds in melds)
    {
        foreach (var tileType in seatMelds)
            visible18[tileType]++;
    }

    var state = SichuanStateCodec.FromRaw(2, 3, 2, 1, hand18, visible18, null, discards, melds);
    state.HasHu[1] = true;
    state.HasHu[3] = true;
    var result = facade.DecideDiscard(state);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    Console.WriteLine($"late_wall_keep_ready_tile={result.Action.TileType} score={result.Action.Score} shanten={result.Shanten} wait={selected.WaitCount} danger={selected.Danger} top={string.Join(',', result.Candidates.Take(5).Select(candidate => $"{candidate.TileType}:{candidate.Score}/{candidate.Shanten}/{candidate.WaitCount}/{candidate.Danger}"))}");
    return result.Shanten == 0 && selected.WaitCount > 0;
}

static bool SmokeLateWallKeepsReadyAgainstAbandonedSuitThreat(SichuanAiFacade facade)
{
    var hand18 = new[]
    {
        0, 0, 1, 1, 0, 1, 1, 1, 0,
        0, 1, 2, 1, 2, 0, 0, 0, 0
    };
    var discards = new[]
    {
        new[] { 9, 13, 17, 17, 9, 8 },
        new[] { 9, 7 },
        new[] { 16, 9 },
        new[] { 17, 12, 15, 17 },
    };
    var melds = new[]
    {
        new[] { 1, 1, 1, 1, 0, 0, 0, 0 },
        new[] { 8, 8, 8, 16, 16, 16 },
        Array.Empty<int>(),
        new[] { 14, 14, 14 },
    };
    var visible18 = new int[27];
    foreach (var seatDiscards in discards)
    {
        foreach (var tileType in seatDiscards)
            visible18[tileType]++;
    }
    foreach (var seatMelds in melds)
    {
        foreach (var tileType in seatMelds)
            visible18[tileType]++;
    }

    var state = SichuanStateCodec.FromRaw(3, 1, 3, 1, hand18, visible18, null, discards, melds);
    state.HasHu[1] = true;
    state.HasHu[2] = true;
    var result = facade.DecideDiscard(state);
    var threeTong = result.Candidates.First(candidate => candidate.TileType == 11);
    var fiveTong = result.Candidates.First(candidate => candidate.TileType == 13);
    Console.WriteLine($"late_wall_abandoned_suit_tile={result.Action.TileType} shanten={result.Shanten} three_tong_danger={threeTong.Danger} five_tong_danger={fiveTong.Danger}");
    return result.Action.TileType == 11
        && result.Shanten == 0
        && threeTong.Danger < 56;
}

static bool SmokeLateWallKeepsReadyFromMarkedCases(SichuanAiFacade facade)
{
    var case64 = BuildMarkedCase64();
    var result64 = facade.DecideDiscard(case64);
    var case253 = BuildMarkedCase253();
    var result253 = facade.DecideDiscard(case253);
    Console.WriteLine($"late_wall_marked_case64_tile={result64.Action.TileType} shanten={result64.Shanten} case253_tile={result253.Action.TileType} shanten={result253.Shanten}");
    return result64.Shanten == 0
        && result64.Action.TileType != 5
        && result253.Shanten == 0
        && result253.Action.TileType != 15;
}

static SichuanStateView BuildMarkedCase64()
{
    var hand18 = new[] { 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 };
    var discards = new[]
    {
        new[] { 17, 0, 13 },
        new[] { 6, 17, 9, 17, 5, 13 },
        Array.Empty<int>(),
        new[] { 1, 5, 13, 0, 5, 8, 13 },
    };
    var melds = new[]
    {
        new[] { 9, 9, 9, 7, 7, 7, 7, 10, 10, 10 },
        new[] { 4, 4, 4, 8, 8, 8, 16, 16, 16 },
        Array.Empty<int>(),
        new[] { 15, 15, 15 },
    };
    var state = BuildMarkedDiscardState(1, 3, 1, 0, hand18, discards, melds);
    state.HasHu[0] = true;
    state.HasHu[2] = true;
    return state;
}

static SichuanStateView BuildMarkedCase253()
{
    var hand18 = new[] { 2, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0 };
    var discards = new[]
    {
        new[] { 15, 13, 7, 14, 6, 12 },
        new[] { 5, 16, 8, 3, 6, 7 },
        new[] { 11, 8, 17 },
        new[] { 5 },
    };
    var melds = new[]
    {
        new[] { 4, 4, 4 },
        new[] { 17, 17, 17, 9, 9, 9, 9 },
        new[] { 10, 10, 10 },
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(1, 2, 1, 0, hand18, discards, melds);
    state.HasHu[2] = true;
    state.HasHu[3] = true;
    return state;
}

static bool SmokePrefersOrphanTerminalFromMarkedCases(SichuanAiFacade facade)
{
    var case210 = BuildMarkedCase210();
    var result210 = facade.DecideDiscard(case210);
    var case304 = BuildMarkedCase304();
    var result304 = facade.DecideDiscard(case304);
    var top210 = string.Join(",", result210.Candidates.Take(4).Select(candidate => $"{candidate.TileType}:{candidate.Score}/u{candidate.UnifiedActionValue:F2}/r{candidate.StrategicResidual:F2}"));
    var top304 = string.Join(",", result304.Candidates.Take(4).Select(candidate => $"{candidate.TileType}:{candidate.Score}/u{candidate.UnifiedActionValue:F2}/r{candidate.StrategicResidual:F2}"));
    Console.WriteLine($"orphan_terminal_case210_tile={result210.Action.TileType} case304_tile={result304.Action.TileType} top210={top210} top304={top304}");
    return result210.Action.TileType == 17
        && result304.Action.TileType == 17;
}

static bool SmokePrefersIsolatedTerminalOverBreakingRuns(SichuanAiFacade facade)
{
    var hand18 = new[]
    {
        1, 0, 0, 1, 1, 1, 1, 2, 0,
        1, 1, 1, 1, 1, 1, 1, 0, 0
    };
    var discards = new[]
    {
        Array.Empty<int>(),
        Array.Empty<int>(),
        new[] { 2 },
        Array.Empty<int>(),
    };
    var melds = new[]
    {
        new[] { 5, 5, 5 },
        Array.Empty<int>(),
        new[] { 1, 1, 1 },
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(1, 2, 1, 18, hand18, discards, melds);
    var result = facade.DecideDiscard(state);
    var oneTiao = result.Candidates.First(candidate => candidate.TileType == 0);
    var oneTong = result.Candidates.First(candidate => candidate.TileType == 9);
    var eightTiao = result.Candidates.First(candidate => candidate.TileType == 7);
    Console.WriteLine($"isolated_terminal_case_tile={result.Action.TileType} one_tiao={oneTiao.Score} one_tong={oneTong.Score} eight_tiao={eightTiao.Score}");
    return result.Action.TileType == 0
        && oneTiao.Score > oneTong.Score
        && oneTiao.Score > eightTiao.Score;
}

static bool SmokeHaidiPreservesPairWaitOverFutureShape(SichuanAiFacade facade)
{
    var hand18 = new[]
    {
        0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 2, 1, 2, 0, 0, 0, 0
    };
    var discards = new[]
    {
        new[] { 6, 14, 0, 8 },
        new[] { 9, 8 },
        new[] { 2, 10, 12, 17, 6 },
        new[] { 14, 10, 8, 1, 14 },
    };
    var melds = new[]
    {
        new[] { 5, 5, 5, 17, 17, 17 },
        Array.Empty<int>(),
        new[] { 1, 1, 1, 4, 4, 4, 0, 0, 0 },
        new[] { 15, 15, 15, 16, 16, 16, 16, 2, 2, 2 },
    };
    var passedHu = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    passedHu[3][12] = 1;
    var state = BuildMarkedDiscardState(2, 2, 2, 0, hand18, discards, melds, passedHu);
    state.HasHu[0] = true;
    state.HasHu[1] = true;
    var result = facade.DecideDiscard(state);
    var fourTong = result.Candidates.First(candidate => candidate.TileType == 12);
    var fiveTong = result.Candidates.First(candidate => candidate.TileType == 13);
    Console.WriteLine($"haidi_pair_wait_tile={result.Action.TileType} search={result.SearchUsed} four_tong={fourTong.Score} five_tong={fiveTong.Score} four_danger={fourTong.Danger} five_danger={fiveTong.Danger}");
    return result.Action.TileType == 12
        && !result.SearchUsed
        && fourTong.Score > fiveTong.Score;
}

static SichuanStateView BuildMarkedCase210()
{
    var hand18 = new[] { 0, 0, 1, 1, 0, 0, 3, 3, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1 };
    var discards = new[]
    {
        new[] { 11 },
        Array.Empty<int>(),
        new[] { 13 },
        Array.Empty<int>(),
    };
    var melds = new[]
    {
        new[] { 8, 8, 8, 9, 9, 9, 9 },
        new[] { 0, 0, 0, 16, 16, 16 },
        new[] { 10, 10, 10 },
        new[] { 17, 17, 17, 1, 1, 1 },
    };
    return BuildMarkedDiscardState(1, 1, 1, 18, hand18, discards, melds);
}

static SichuanStateView BuildMarkedCase304()
{
    var hand18 = new[] { 0, 0, 0, 1, 1, 1, 1, 2, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1 };
    var discards = new[]
    {
        new[] { 3 },
        Array.Empty<int>(),
        new[] { 7 },
        Array.Empty<int>(),
    };
    var melds = new[]
    {
        new[] { 0, 0, 0, 9, 9, 9 },
        new[] { 1, 1, 1 },
        new[] { 8, 8, 8 },
        new[] { 2, 2, 2 },
    };
    var state = BuildMarkedDiscardState(2, 3, 2, 17, hand18, discards, melds);
    state.HasHu[0] = true;
    state.HasHu[1] = true;
    return state;
}

static bool SmokeReadyPreservesCentralBoneFromSeedLive(SichuanAiFacade facade)
{
    var hand18 = new[] { 0, 1, 1, 2, 2, 2, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 2 };
    var discards = new[]
    {
        new[] { 6 },
        new[] { 14 },
        Array.Empty<int>(),
        Array.Empty<int>(),
    };
    var melds = new[]
    {
        new[] { 8, 8, 8 },
        new[] { 7, 7, 7 },
        Array.Empty<int>(),
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(3, 1, 3, 17, hand18, discards, melds);
    var result = facade.DecideDiscard(state);
    var threeTong = result.Candidates.First(candidate => candidate.TileType == 11);
    var sixTong = result.Candidates.First(candidate => candidate.TileType == 14);
    Console.WriteLine($"ready_central_seedlive_tile={result.Action.TileType} three={threeTong.Score}/u{threeTong.UnifiedActionValue:F3}/r{threeTong.StrategicResidual:F2}/{threeTong.Shanten}/{threeTong.WaitCount}/{threeTong.LiveUkeire} six={sixTong.Score}/u{sixTong.UnifiedActionValue:F3}/r{sixTong.StrategicResidual:F2}/{sixTong.Shanten}/{sixTong.WaitCount}/{sixTong.LiveUkeire}");
    return result.Action.TileType == 11
        && threeTong.Shanten == sixTong.Shanten
        && threeTong.WaitCount == sixTong.WaitCount
        && threeTong.LiveUkeire == sixTong.LiveUkeire
        && threeTong.Score > sixTong.Score;
}

static bool SmokeExtremeDangerSameSpeedOverrideFromSeedLive(SichuanAiFacade facade)
{
    var hand18 = new[] { 2, 2, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 1, 2, 1, 0, 0 };
    var discards = new[]
    {
        new[] { 11, 16 },
        new[] { 17 },
        new[] { 7 },
        new[] { 7, 16 },
    };
    var melds = new[]
    {
        Array.Empty<int>(),
        new[] { 9, 9, 9 },
        Array.Empty<int>(),
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(1, 0, 1, 13, hand18, discards, melds);
    state.IsReady[3] = true;
    state.IsCalled[3] = true;
    var result = facade.DecideDiscard(state);
    var sixTiao = result.Candidates.First(candidate => candidate.TileType == 5);
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    Console.WriteLine($"extreme_danger_same_speed_tile={result.Action.TileType} selected={selected.Score}/{selected.Shanten}/{selected.LiveUkeire}/{selected.Danger} six_tiao={sixTiao.Score}/{sixTiao.Shanten}/{sixTiao.LiveUkeire}/{sixTiao.Danger}");
    return result.Action.TileType != 5
        && selected.Shanten <= sixTiao.Shanten
        && selected.LiveUkeire + 1 >= sixTiao.LiveUkeire
        && selected.Danger < sixTiao.Danger;
}

static SichuanStateView BuildMarkedDiscardState(
    int seatIndex,
    int dealerSeat,
    int currentSeat,
    int wallCount,
    int[] hand18,
    int[][] discards,
    int[][] melds,
    int[][]? passedHu = null,
    int[][]? passedPeng = null,
    int[][]? passedGang = null)
{
    var visible18 = new int[27];
    foreach (var tileType in hand18.Select((count, tileType) => (count, tileType)).SelectMany(item => Enumerable.Repeat(item.tileType, item.count)))
        visible18[tileType]++;
    foreach (var seatDiscards in discards)
    {
        foreach (var tileType in seatDiscards)
            visible18[tileType]++;
    }
    foreach (var seatMelds in melds)
    {
        foreach (var tileType in seatMelds)
            visible18[tileType]++;
    }
    var remaining18 = visible18.Select(count => Math.Max(0, 4 - count)).ToArray();
    return SichuanStateCodec.FromRaw(seatIndex, dealerSeat, currentSeat, wallCount, hand18, visible18, remaining18, discards, melds, passedHu, passedPeng, passedGang);
}

static bool SmokeRiskCalibration()
{
    var low = SichuanRiskCalibration.ToDealInProbability(20, 0, 0.20);
    var high = SichuanRiskCalibration.ToDealInProbability(80, 2, 0.92);
    Console.WriteLine($"risk_calibration_low={low:F4} high={high:F4}");
    return low is > 0.0 and < 0.12
        && high is > 0.18 and < 0.55
        && high > low;
}

static bool SmokePosteriorDefenseAdjustment(SichuanAiFacade facade)
{
    var hand = new[]
    {
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(0, 6),
        SichuanTileCodec.EncodeTileType(0, 7),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 6),
        SichuanTileCodec.EncodeTileType(1, 7),
        SichuanTileCodec.EncodeTileType(1, 8),
        SichuanTileCodec.EncodeTileType(1, 9),
    };
    var visible = new int[27];
    var discards = new[]
    {
        new[] { 0, 1, 2, 9, 10, 11, 12, 13, 14, 15 },
        Array.Empty<int>(),
        new[] { 0, 1, 9, 10, 11, 12, 13, 14, 15, 16 },
        new[] { 0, 1, 2, 3, 9, 10, 11, 12, 13, 14 },
    };
    foreach (var seatDiscards in discards)
    {
        foreach (var tile in seatDiscards)
            visible[tile]++;
    }
    var state = SichuanStateCodec.FromRaw(
        1,
        0,
        1,
        5,
        SichuanTileCodec.BuildCount18(hand),
        visible,
        null,
        discards);
    state.IsCalled[0] = true;
    state.IsReady[0] = true;
    state.IsReady[2] = true;
    var result = facade.DecideDiscard(state);
    var adjusted = result.Candidates
        .Where(item => item.PosteriorAdjustment > 0.01)
        .ToArray();
    Console.WriteLine($"posterior_adjusted_candidates={adjusted.Length}");
    return adjusted.Length > 0 && adjusted.Any(item => item.DefenseAdjustment > 0.01);
}

static bool SmokeHandShapeDetails(SichuanAiFacade facade)
{
    var hand = new[]
    {
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(0, 7),
        SichuanTileCodec.EncodeTileType(0, 8),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 5),
        SichuanTileCodec.EncodeTileType(1, 7),
        SichuanTileCodec.EncodeTileType(1, 8),
        SichuanTileCodec.EncodeTileType(1, 9),
    };
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 16, SichuanTileCodec.BuildCount18(hand), new int[27]);
    var result = facade.DecideDiscard(state);
    var shapeAware = result.Candidates
        .Where(item => Math.Abs(item.ShapeScore) > 0.01
            || item.GoodShapeCount > 0
            || item.BadShapeCount > 0
            || item.SameShantenImprovementCount > 0)
        .ToArray();
    Console.WriteLine($"shape_aware_candidates={shapeAware.Length}");
    return shapeAware.Length > 0
        && result.Candidates.Any(item => item.Reasons.Any(reason => reason.Contains("手形", StringComparison.Ordinal)));
}

static bool SmokeEvidenceSnapshot()
{
    var discards = new[]
    {
        new[] { 1, 1, 2, 3 },
        Array.Empty<int>(),
        Array.Empty<int>(),
        Array.Empty<int>(),
    };
    var state = SichuanStateCodec.FromRaw(
        1,
        0,
        1,
        12,
        new int[27],
        new int[27],
        null,
        discards);
    var evidence = new SichuanEvidenceEngine().Build(state);
    Console.WriteLine($"evidence_safe={evidence.SeatExactSafeTiles[0].Count} no_hu_tile1={evidence.SeatNoHuEvidence[0][1]:F2}");
    return evidence.SeatExactSafeTiles[0].Contains(1)
        && evidence.SeatNoHuEvidence[0][1] >= 0.80
        && evidence.SeatRecentDiscardTrend[0].Count > 0;
}

static bool SmokeOpponentRangeUsesNoHuEvidence()
{
    var discards = new[]
    {
        new[] { 1, 1, 0, 9, 10, 11, 12 },
        Array.Empty<int>(),
        Array.Empty<int>(),
        Array.Empty<int>(),
    };
    var state = SichuanStateCodec.FromRaw(
        1,
        0,
        1,
        8,
        new int[27],
        new int[27],
        null,
        discards);
    state.IsReady[0] = true;
    state.IsCalled[0] = true;
    var evidence = new SichuanEvidenceEngine().Build(state);
    var range = new SichuanOpponentRangeEngine().BuildSeatRange(state, evidence, 0);
    Console.WriteLine($"range_wait_denied={range.WaitProbability18[1]:F4} live={range.WaitProbability18[4]:F4} wall1={range.WallPosterior18[1]:F4}");
    return range.WaitProbability18[1] < range.WaitProbability18[4] * 0.55
        && range.HoldProbability18[1] < range.HoldProbability18[4]
        && range.WallPosterior18[1] > 0.0;
}

static bool SmokePosteriorNormalizationConservesRemainingTiles()
{
    var state = SichuanStateCodec.FromRaw(
        1,
        0,
        1,
        9,
        new int[27],
        new int[27]);
    state.Remaining18[4] = 2;
    var activeSeats = new[] { 1, 2, 3 };
    var weights = activeSeats.ToDictionary(
        seat => seat,
        seat => new Dictionary<int, double>
        {
            [4] = seat == 1 ? 4.0 : 1.8,
            [7] = 0.8,
        });
    var normalized = new SichuanPosteriorNormalizer().Normalize(state, activeSeats, weights);
    var expectedCountSum = normalized.WallExpectedCount18[4]
        + activeSeats.Sum(seat => normalized.SeatExpectedCount18[seat][4]);
    Console.WriteLine($"posterior_conservation_tile4={expectedCountSum:F4} wall={normalized.WallProbability18[4]:F4} overflow={normalized.MaxConservationOverflow:F6}");
    return Math.Abs(expectedCountSum - state.Remaining18[4]) < 0.000001
        && normalized.MaxConservationOverflow < 0.000001
        && normalized.SeatHoldProbability18[1][4] > normalized.SeatHoldProbability18[2][4]
        && normalized.WallProbability18[4] is >= 0.0 and <= 1.0;
}

static bool SmokePassedReactionEvidenceFeedsOpponentRange()
{
    var passedHu = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var passedPeng = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var passedGang = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    passedHu[2][6] = 1;
    passedPeng[2][6] = 2;
    passedGang[2][6] = 1;
    var state = SichuanStateCodec.FromRaw(
        1,
        0,
        1,
        11,
        new int[27],
        new int[27],
        null,
        null,
        null,
        passedHu,
        passedPeng,
        passedGang);
    state.IsReady[2] = true;
    var evidence = new SichuanEvidenceEngine().Build(state);
    var range = new SichuanOpponentRangeEngine().BuildSeatRange(state, evidence, 2);
    Console.WriteLine($"passed_evidence_nohu={evidence.SeatNoHuEvidence[2][6]:F2} nopeng={evidence.SeatNoPengEvidence[2][6]:F2} nogal={evidence.SeatNoGangEvidence[2][6]:F2} wait={range.WaitProbability18[6]:F4} hold={range.HoldProbability18[6]:F4}");
    return evidence.SeatNoHuEvidence[2][6] >= 0.36
        && evidence.SeatNoPengEvidence[2][6] >= 0.48
        && evidence.SeatNoGangEvidence[2][6] >= 0.34
        && range.WaitProbability18[6] < range.WaitProbability18[7]
        && range.HoldProbability18[6] < range.HoldProbability18[7];
}

static bool SmokeWaitShapeClassification()
{
    var engine = new SichuanWaitShapeEngine();
    var hand = new int[27];
    hand[1] = 1;
    hand[2] = 1;
    var ryanmen = engine.Evaluate(hand, new[] { 0, 3 });
    var closed = new int[27];
    closed[1] = 1;
    closed[3] = 1;
    var kanchan = engine.Evaluate(closed, new[] { 2 });
    Console.WriteLine($"wait_shape_ryanmen={ryanmen.Label} score={ryanmen.WaitShapeScore:F1} kanchan={kanchan.Label} score={kanchan.WaitShapeScore:F1}");
    return ryanmen.RyanmenCount >= 1
        && ryanmen.WaitShapeScore > kanchan.WaitShapeScore
        && kanchan.KanchanCount == 1
        && kanchan.Reasons.Any(reason => reason.Contains("坎张", StringComparison.Ordinal));
}

static bool SmokeLimitedLookaheadScoresFutureImprovement()
{
    var hand = new int[27];
    hand[1] = 1;
    hand[2] = 1;
    hand[3] = 1;
    hand[4] = 1;
    hand[10] = 1;
    hand[11] = 1;
    hand[12] = 1;
    hand[14] = 1;
    hand[15] = 1;
    hand[16] = 1;
    hand[17] = 1;
    hand[7] = 1;
    var remaining = Enumerable.Repeat(2, 27).ToArray();
    remaining[0] = 4;
    remaining[5] = 4;
    var summary = new SichuanLimitedLookaheadEngine().Evaluate(hand, remaining, 0, 2, 8);
    Console.WriteLine($"limited_lookahead_score={summary.Score:F2} samples={summary.SampledDrawCount} best_shanten={summary.BestNextShanten} best_live={summary.BestNextLiveUkeire}");
    return summary.SampledDrawCount > 0
        && summary.BestNextShanten <= 2
        && summary.BestNextLiveUkeire > 0
        && summary.Score > -18.0;
}

static bool SmokeHellOracleRejectsExactDealIn()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 16, 17 })
        aiHand[tile]++;
    var visible = new int[27];
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 8, aiHand, visible);

    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    foreach (var tile in new[] { 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 16, 16 })
        allHands[2][tile]++;
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[0] = 0;
    exactWall[17] = 3;

    var result = new SichuanHellOracleEngine().DecideDiscard(state, allHands, exactWall, fairTileType: 0);
    Console.WriteLine($"hell_oracle_tile={result.Action.TileType} category={result.Category} severity={result.Severity} dealin={result.ExactDealIn}");
    return result.Action.TileType != 0
        && result.Category is "risk_underestimated" or "hand_efficiency_error"
        && result.Severity == "high"
        && result.FairExactDealIn
        && result.FairDealInTargetSeats.Contains(2)
        && !result.OracleExactDealIn
        && result.OracleDealInTargetSeats.Count == 0;
}

static bool SmokeHellOracleAvoidsFeedingHumanCalls()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 0, 0, 3, 3, 3, 6, 6, 6, 10, 10, 10, 17, 5 })
        aiHand[tile]++;
    var visible = new int[27];
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, visible);

    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[5] = 3;
    exactWall[17] = 1;

    var result = new SichuanHellOracleEngine().DecideDiscard(state, allHands, exactWall, fairTileType: 5);
    Console.WriteLine($"hell_oracle_human_call_tile={result.Action.TileType} category={result.Category} severity={result.Severity} fair_peng={result.FairFeedsHumanPeng} oracle_peng={result.OracleFeedsHumanPeng}");
    return result.Action.TileType != 5
        && result.Category == "human_peng_suppression"
        && result.Severity == "medium"
        && result.FairFeedsHumanPeng
        && !result.FairFeedsHumanGang
        && !result.OracleFeedsHumanPeng
        && !result.OracleFeedsHumanGang;
}

static bool SmokeHellOracleAvoidsFeedingHumanGang()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 0, 0, 3, 3, 3, 6, 6, 6, 10, 10, 10, 17, 5 })
        aiHand[tile]++;
    var visible = new int[27];
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, visible);

    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 3;
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[5] = 3;
    exactWall[17] = 1;

    var result = new SichuanHellOracleEngine().DecideDiscard(state, allHands, exactWall, fairTileType: 5);
    Console.WriteLine($"hell_oracle_human_gang_tile={result.Action.TileType} category={result.Category} severity={result.Severity} fair_gang={result.FairFeedsHumanGang} oracle_gang={result.OracleFeedsHumanGang}");
    return result.Action.TileType != 5
        && result.Category == "human_gang_suppression"
        && result.Severity == "high"
        && result.FairFeedsHumanGang
        && !result.OracleFeedsHumanPeng
        && !result.OracleFeedsHumanGang;
}

static bool SmokeHellOracleRaisesPressureWhenHumanLeads()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 0, 0, 3, 3, 3, 6, 6, 6, 10, 10, 10, 17, 5 })
        aiHand[tile]++;
    var visible = new int[27];
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, visible);

    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    var trailing = new SichuanHellOracleEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        fairTileType: 5,
        currentScores: new[] { -12, 18, 4, 2 });
    var leading = new SichuanHellOracleEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        fairTileType: 5,
        currentScores: new[] { 26, 18, 4, 2 });

    Console.WriteLine($"hell_oracle_pressure_trailing={trailing.HumanPressureLevel} leading={leading.HumanPressureLevel} leading_reasons={string.Join("|", leading.Reasons)}");
    return trailing.HumanPressureLevel == 1
        && leading.HumanPressureLevel == 4
        && leading.FairFeedsHumanPeng
        && !leading.OracleFeedsHumanPeng;
}

static bool SmokeHellChallengeDirectDoesNotNeedFairRecommendation()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 0, 0, 3, 3, 3, 6, 6, 6, 10, 10, 10, 17, 5 })
        aiHand[tile]++;
    var visible = new int[27];
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, visible);

    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[5] = 3;
    exactWall[17] = 1;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 26, 18, 4, 2 });

    Console.WriteLine($"hell_challenge_direct_tile={result.Action.TileType} category={result.Category} pressure={result.HumanPressureLevel} feeds_human_peng={result.OracleFeedsHumanPeng}");
    return result.Action.TileType != 5
        && result.Category == "hell_challenge_direct"
        && result.FairTileType == -1
        && result.HumanPressureLevel == 4
        && !result.OracleFeedsHumanPeng;
}

static bool SmokeHellChallengeReportsSelectedShape()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 0, 0, 3, 3, 3, 6, 6, 6, 10, 10, 10, 17, 5 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var exactWall = Enumerable.Repeat(1, 27).ToArray();

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 0, 0, 0, 0 });
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);

    Console.WriteLine($"hell_challenge_selected_shape tile={result.Action.TileType} shanten={result.SelectedShanten}/{selected.Shanten} live={result.SelectedLiveUkeire}/{selected.LiveUkeire} wait={result.SelectedWaitCount}/{selected.WaitCount} tier={result.SelectedTier}");
    return result.SelectedShanten == selected.Shanten
        && result.SelectedLiveUkeire == selected.LiveUkeire
        && result.SelectedWaitCount == selected.WaitCount
        && result.SelectedTier == selected.Tier;
}

static bool SmokeHellChallengeInheritsOldHandFlushRoute()
{
    var hand18 = SichuanTileCodec.BuildCount18(new[]
    {
        0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 8,
        9, 13, 16
    });
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, hand18, new int[27], roundIndex: 920);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[1] = hand18;
    var exactWall = Enumerable.Repeat(2, 27).ToArray();

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 0, 0, 0, 0 });
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);

    Console.WriteLine($"hell_old_hand_flush tile={result.Action.TileType} old={selected.OldHandScore}/{selected.OldHandRank}/{selected.OldHandRoute} reasons={string.Join('|', result.Reasons)}");
    return result.Action.TileType >= 9
        && selected.OldHandRank == 0
        && SichuanRoutePlanEngine.IsFlushRoute(selected.OldHandRoute)
        && result.Reasons.Any(reason => reason.Contains("老手主线", StringComparison.Ordinal));
}

static bool SmokeHellChallengeInheritsOldHandTripletProtection()
{
    var hand18 = new[] { 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 2, 1, 1, 3 };
    var visible18 = new[] { 2, 1, 1, 0, 1, 0, 1, 0, 2, 2, 1, 0, 1, 4, 2, 1, 2, 3 };
    var remaining18 = new[] { 2, 3, 3, 4, 3, 4, 3, 4, 2, 2, 3, 4, 3, 0, 2, 3, 2, 1 };
    var discards = new[]
    {
        new[] { 16 },
        new[] { 9, 0 },
        new[] { 9, 8 },
        new[] { 10, 8 },
    };
    var melds = new[]
    {
        Array.Empty<int>(),
        Array.Empty<int>(),
        Array.Empty<int>(),
        new[] { 13, 13, 13 },
    };
    var state = SichuanStateCodec.FromRaw(2, 2, 2, 12, hand18, visible18, remaining18, discards, melds, roundIndex: 921);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[2] = hand18;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        remaining18,
        currentScores: new[] { 0, 0, 0, 0 });
    var selected = result.Candidates.First(candidate => candidate.TileType == result.Action.TileType);
    var tripletCandidate = result.Candidates.First(candidate => candidate.TileType == 17);

    Console.WriteLine($"hell_old_hand_triplet tile={result.Action.TileType} breaks={selected.OldHandBreaksTriplet} triplet={tripletCandidate.Score}/{tripletCandidate.OldHandScore}/{tripletCandidate.OldHandRank} reasons={string.Join('|', result.Reasons)}");
    return result.Action.TileType != 17
        && !selected.OldHandBreaksTriplet
        && tripletCandidate.OldHandBreaksTriplet
        && result.Reasons.Any(reason => reason.Contains("老手主线", StringComparison.Ordinal));
}

static bool SmokeHellChallengeEnforcesDingQueLegality()
{
    var hand18 = SichuanTileCodec.BuildCount18(new[]
    {
        0, 1, 2, 3, 4,
        9, 10, 11, 12, 13,
        18, 20, 22, 24,
    });
    var state = SichuanStateCodec.FromRaw(
        2,
        0,
        2,
        38,
        hand18,
        new int[27],
        dingQueSuits: new[] { 0, 1, 2, 0 },
        roundIndex: 922);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[2] = hand18;
    var exactWall = Enumerable.Repeat(2, 27).ToArray();

    var result = new SichuanHellChallengeEngine().DecideDiscard(state, allHands, exactWall);
    var onlyDingQueCandidates = result.Candidates.Count > 0
        && result.Candidates.All(candidate => candidate.TileType is >= 18 and <= 26);
    Console.WriteLine($"hell_ding_que action={result.Action.TileType} candidates={string.Join(',', result.Candidates.Select(candidate => candidate.TileType))}");
    return result.Action.TileType is >= 18 and <= 26 && onlyDingQueCandidates;
}

static bool SmokeHellChallengeSharesContinuousBrainWithReaction()
{
    var sharedOldHand = new SichuanAiFacade();
    var discardEngine = new SichuanHellChallengeEngine(sharedOldHand);
    var reactionEngine = new SichuanHellChallengeReactionEngine(sharedOldHand);
    var beforeHand = SichuanTileCodec.BuildCount18(new[] { 4, 4, 4, 0, 1, 2, 9, 10, 11, 18, 19, 20, 6, 7 });
    var before = SichuanStateCodec.FromRaw(1, 0, 1, 24, beforeHand, new int[27], roundIndex: 923);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[1] = beforeHand;
    _ = discardEngine.DecideDiscard(before, allHands, Enumerable.Repeat(2, 27).ToArray());

    var afterHand = (int[])beforeHand.Clone();
    afterHand[4]--;
    var discards = new[] { new List<int>(), new List<int> { 4 }, new List<int>(), new List<int>() };
    var after = SichuanStateCodec.FromRaw(1, 0, 1, 23, afterHand, new int[27], discards18: discards, roundIndex: 923);
    allHands[1] = afterHand;
    var reaction = reactionEngine.DecideReaction(
        after,
        reactionTileType: 4,
        canHu: false,
        canPeng: true,
        canGang: false,
        sourceSeat: 0,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: Enumerable.Repeat(2, 27).ToArray());

    Console.WriteLine($"hell_shared_brain action={reaction.Action.ActionType} pass={reaction.ActionScores.GetValueOrDefault("pass")} peng={reaction.ActionScores.GetValueOrDefault("peng")} reasons={string.Join('|', reaction.Reasons)}");
    return reaction.Action.ActionType == SichuanActionType.Pass
        && reaction.ActionScores.GetValueOrDefault("peng") < reaction.ActionScores.GetValueOrDefault("pass")
        && reaction.Reasons.Any(reason => reason.Contains("主动拆刻", StringComparison.Ordinal));
}

static bool SmokeHellChallengeTierKeepsOneAwayOverWideTwoAway()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 0, 0, 1, 2, 3, 5, 6, 10, 10, 11, 12, 14, 15, 17 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    foreach (var tile in new[] { 0, 1, 2, 3, 5, 6, 10, 11, 12, 14, 15, 17 })
        exactWall[tile] = 2;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 0, 0, 0, 0 });
    var top = result.Candidates.Take(4).Select(candidate => $"{candidate.TileType}:{candidate.Score}/{candidate.Shanten}/{candidate.LiveUkeire}/{candidate.Tier}");
    Console.WriteLine($"hell_challenge_tier_top={result.Action.TileType} shape={result.SelectedShanten}/{result.SelectedLiveUkeire}/{result.SelectedTier} top={string.Join(',', top)}");
    return result.SelectedShanten <= 1
        || result.SelectedTier is "A_READY" or "B_ONE_AWAY_LIVE" or "B_ONE_AWAY_NARROW";
}

static bool SmokeHellChallengeReactionBlocksHumanMomentum()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 5, 5, 1, 2, 3, 6, 7, 8, 10, 11, 12, 14, 15 })
        aiHand[tile]++;
    var visible = new int[27];
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, visible);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][4] = 1;
    allHands[0][6] = 1;
    allHands[0][7] = 1;
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[5] = 2;

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 5,
        canHu: false,
        canPeng: true,
        canGang: false,
        sourceSeat: 0,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { 28, 8, 6, 4 });

    Console.WriteLine($"hell_challenge_reaction_action={result.Action.ActionType} score={result.Action.Score} reasons={string.Join("|", result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Peng
        && result.ActionScores.ContainsKey("team_block_human")
        && result.ActionScores["team_block_human"] > 0
        && result.Reasons.Any(reason => reason.Contains("围剿"));
}

static bool SmokeHellChallengeTeamPlanCoordinatesSeats()
{
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, new int[27], new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var exactWall = Enumerable.Repeat(2, 27).ToArray();
    var currentScores = new[] { 32, 16, 8, 4 };

    var plan = SichuanHellChallengeTeamPlanner.BuildPlan(state, allHands, exactWall, currentScores);

    Console.WriteLine($"hell_challenge_team_plan pressure={plan.HumanPressureLevel} seats={string.Join(",", plan.SeatPlans.Select(item => $"{item.Seat}:{item.Role}:{item.PressureBonus}"))}");
    return plan.TargetSeat == 0
        && plan.HumanPressureLevel == 4
        && plan.SeatPlans.Count == 3
        && plan.SeatPlans.Any(item => item.Seat == 1 && item.Role == "lead_suppressor" && item.PressureBonus > 0)
        && plan.SeatPlans.Any(item => item.Seat == 2 && item.Role == "interceptor")
        && plan.SeatPlans.Any(item => item.Seat == 3 && item.Role == "catch_up")
        && plan.Reasons.Any(reason => reason.Contains("三家协作"));
}

static bool SmokeHellChallengeDiscardUsesTeamPlan()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 5, 5, 1, 2, 3, 6, 7, 8, 10, 11, 12, 14, 15, 16 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(1, 0, 1, 18, aiHand, new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(2, 27).ToArray();

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 32, 16, 8, 4 });

    Console.WriteLine($"hell_challenge_discard_team_plan tile={result.Action.TileType} role={result.TeamRole} bonus={result.TeamPressureBonus} reasons={string.Join("|", result.Reasons)}");
    return result.TeamRole == "lead_suppressor"
        && result.TeamPressureBonus > 0
        && result.Reasons.Any(reason => reason.Contains("三家协作"));
}

static bool SmokeHellChallengeReactionUsesTeamPlan()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 5, 5, 1, 2, 3, 6, 7, 8, 10, 11, 12, 14, 15 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(2, 0, 2, 18, aiHand, new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[5] = 2;

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 5,
        canHu: false,
        canPeng: true,
        canGang: false,
        sourceSeat: 0,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { 32, 16, 8, 4 });

    Console.WriteLine($"hell_challenge_reaction_team_plan action={result.Action.ActionType} scores={string.Join(",", result.ActionScores.Select(item => $"{item.Key}:{item.Value}"))} reasons={string.Join("|", result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Peng
        && result.ActionScores.TryGetValue("team_plan_pressure", out var planPressure)
        && planPressure > 0
        && result.Reasons.Any(reason => reason.Contains("三家协作"));
}

static bool SmokeHellChallengePassesNonHumanMiddlePengUnlessReady()
{
    var aiHand = new[] { 0, 0, 0, 1, 1, 2, 0, 3, 0, 0, 1, 1, 0, 1, 2, 0, 0, 1 };
    var state = SichuanStateCodec.FromRaw(3, 2, 3, 16, aiHand, new int[27]);
    var allHands = new[]
    {
        new[] { 1, 1, 0, 0, 1, 2, 2, 0, 1, 2, 0, 1, 2, 0, 0, 0, 0, 0 },
        new[] { 0, 1, 0, 0, 0, 0, 1, 0, 2, 1, 0, 1, 0, 1, 1, 1, 1, 0 },
        new[] { 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 2, 0, 1, 1, 0, 0, 0, 2 },
        aiHand
    };
    var exactWall = new[] { 0, 2, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1 };

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 5,
        canHu: false,
        canPeng: true,
        canGang: false,
        sourceSeat: 1,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { -5, 8, 8, -11 });

    Console.WriteLine($"hell_challenge_non_human_middle_peng_action={result.Action.ActionType} pass={result.ActionScores.GetValueOrDefault("pass", int.MinValue)} peng={result.ActionScores.GetValueOrDefault("peng", int.MinValue)} current={result.CurrentShanten}/{result.CurrentLiveUkeire} after={result.ShantenAfter}/{result.LiveUkeireAfter} reasons={string.Join("|", result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Pass
        && result.ShantenAfter > 0
        && result.ActionScores.GetValueOrDefault("peng", int.MaxValue) < result.ActionScores.GetValueOrDefault("pass", int.MinValue)
        && result.ActionScores.GetValueOrDefault("middle_peng_shape_penalty", 0) <= -460;
}

static bool SmokeHellChallengeAllowsHumanPengToKeepReady()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 16, 16, 17, 17 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(3, 0, 3, 18, aiHand, new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(0, 27).ToArray();
    exactWall[16] = 3;
    exactWall[17] = 1;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 32, 16, 8, 4 });

    Console.WriteLine($"hell_challenge_peng_interaction_tile={result.Action.TileType} feeds_peng={result.OracleFeedsHumanPeng} ready={result.ExactKeepsReady} role={result.TeamRole} reasons={string.Join("|", result.Reasons)}");
    return result.Action.TileType == 5
        && result.OracleFeedsHumanPeng
        && result.ExactKeepsReady
        && result.Reasons.Any(reason => reason.Contains("互动保真"));
}

static bool SmokeHellChallengeAllowsLatePengOnlyWhenHumanReady()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 16, 16, 17, 17 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(3, 0, 3, 6, aiHand, new int[27]);
    state.IsReady[0] = true;
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(0, 27).ToArray();
    exactWall[16] = 3;
    exactWall[17] = 1;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 32, 16, 8, 4 });

    Console.WriteLine($"hell_challenge_late_peng_only_tile={result.Action.TileType} feeds_peng={result.OracleFeedsHumanPeng} ready={result.ExactKeepsReady} reasons={string.Join("|", result.Reasons)}");
    return result.Action.TileType == 5
        && result.OracleFeedsHumanPeng
        && !result.OracleFeedsHumanHu
        && !result.OracleFeedsHumanGang
        && result.ExactKeepsReady
        && result.Reasons.Any(reason => reason.Contains("尾盘只给碰不点炮", StringComparison.Ordinal));
}

static bool SmokeHellChallengeKeepsReadyWhenHumanReadyCanOnlyPeng()
{
    var aiHand = SichuanTileCodec.BuildCount18(new[]
    {
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(0, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 6),
        SichuanTileCodec.EncodeTileType(1, 8),
    });
    var melds = new[]
    {
        Array.Empty<int>(),
        Array.Empty<int>(),
        new[]
        {
            SichuanTileCodec.EncodeTileType(1, 1),
            SichuanTileCodec.EncodeTileType(1, 1),
            SichuanTileCodec.EncodeTileType(1, 1),
            SichuanTileCodec.EncodeTileType(1, 5),
            SichuanTileCodec.EncodeTileType(1, 5),
            SichuanTileCodec.EncodeTileType(1, 5),
        },
        Array.Empty<int>(),
    };
    var state = BuildMarkedDiscardState(
        seatIndex: 2,
        dealerSeat: 0,
        currentSeat: 2,
        wallCount: 5,
        hand18: aiHand,
        discards: new[]
        {
            Array.Empty<int>(),
            Array.Empty<int>(),
            Array.Empty<int>(),
            Array.Empty<int>(),
        },
        melds: melds);
    state.IsReady[0] = true;

    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0] = SichuanTileCodec.BuildCount18(new[]
    {
        SichuanTileCodec.EncodeTileType(0, 1),
        SichuanTileCodec.EncodeTileType(0, 2),
        SichuanTileCodec.EncodeTileType(0, 3),
        SichuanTileCodec.EncodeTileType(1, 1),
        SichuanTileCodec.EncodeTileType(1, 1),
        SichuanTileCodec.EncodeTileType(1, 1),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(1, 5),
        SichuanTileCodec.EncodeTileType(1, 8),
        SichuanTileCodec.EncodeTileType(1, 8),
    });
    allHands[2] = aiHand;
    var exactWall = Enumerable.Repeat(0, 27).ToArray();
    exactWall[SichuanTileCodec.EncodeTileType(1, 6)] = 1;
    exactWall[SichuanTileCodec.EncodeTileType(1, 8)] = 1;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { -6, 0, 6, 0 });

    var sixTong = SichuanTileCodec.EncodeTileType(1, 6);
    var eightTong = SichuanTileCodec.EncodeTileType(1, 8);
    Console.WriteLine($"hell_challenge_ready_human_peng_only_tile={result.Action.TileType} score={result.Action.Score} ready={result.ExactKeepsReady} feeds_hu={result.OracleFeedsHumanHu} feeds_peng={result.OracleFeedsHumanPeng} candidates={string.Join(",", result.Candidates.Select(candidate => $"{candidate.TileType}:{candidate.Score}/{candidate.Shanten}/{candidate.ExactWallRemaining}/hu={candidate.FeedsHumanHu}/peng={candidate.FeedsHumanPeng}/pth={candidate.HumanPengThreat}/ppen={candidate.HumanPengPenalty}/bonus={candidate.TempoPengAllowanceBonus + candidate.PengOnlyInteractionBonus}"))} reasons={string.Join("|", result.Reasons)}");
    return result.Action.TileType == eightTong
        && result.ExactKeepsReady
        && result.OracleFeedsHumanPeng
        && !result.OracleFeedsHumanHu
        && !result.OracleFeedsHumanGang
        && !result.OracleDealInTargetSeats.Contains(0)
        && SichuanHellChallengeEngine.ResolveDealInTargetSeats(state, allHands, sixTong).Contains(0)
        && !SichuanHellChallengeEngine.ResolveDealInTargetSeats(state, allHands, eightTong).Contains(0);
}

static bool SmokeHellChallengeAllowsMidgamePengWhenHumanNotReady()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 16, 16, 17, 17 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(3, 0, 3, 12, aiHand, new int[27]);
    state.IsReady[0] = false;
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    allHands[0][5] = 2;
    var exactWall = Enumerable.Repeat(0, 27).ToArray();
    exactWall[16] = 3;
    exactWall[17] = 1;

    var result = new SichuanHellChallengeEngine().DecideDiscard(
        state,
        allHands,
        exactWall,
        currentScores: new[] { 32, 16, 8, 4 });

    Console.WriteLine($"hell_challenge_mid_peng_tile={result.Action.TileType} feeds_peng={result.OracleFeedsHumanPeng} ready={result.ExactKeepsReady} reasons={string.Join("|", result.Reasons)}");
    return result.Action.TileType == 5
        && result.OracleFeedsHumanPeng
        && !result.OracleFeedsHumanHu
        && !result.OracleFeedsHumanGang
        && result.ExactKeepsReady
        && result.Reasons.Any(reason => reason.Contains("中期本家未听", StringComparison.Ordinal));
}

static bool SmokeHellChallengePrefersDirectGangOverPeng()
{
    var aiHand = new int[27];
    foreach (var tile in new[] { 7, 7, 7, 1, 2, 3, 4, 5, 6, 10, 11, 12, 14 })
        aiHand[tile]++;
    var state = SichuanStateCodec.FromRaw(3, 0, 3, 13, aiHand, new int[27]);
    var allHands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    var exactWall = Enumerable.Repeat(1, 27).ToArray();
    exactWall[7] = 0;

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 7,
        canHu: false,
        canPeng: true,
        canGang: true,
        sourceSeat: 0,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { 30, 12, 8, 2 });

    Console.WriteLine($"hell_challenge_direct_gang_action={result.Action.ActionType} gang={result.ActionScores.GetValueOrDefault("gang", int.MinValue)} peng={result.ActionScores.GetValueOrDefault("peng", int.MinValue)} reasons={string.Join("|", result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Gang
        && result.ActionScores.GetValueOrDefault("gang", int.MinValue) > result.ActionScores.GetValueOrDefault("peng", int.MinValue)
        && result.Reasons.Any(reason => reason.Contains("明杠", StringComparison.Ordinal));
}

static bool SmokeHellChallengeGangsWhenPengWouldRediscardClaimedTile()
{
    var aiHand = new[] { 0, 0, 0, 1, 1, 2, 0, 3, 0, 0, 1, 1, 0, 1, 2, 0, 0, 1 };
    var state = SichuanStateCodec.FromRaw(3, 2, 3, 16, aiHand, new int[27]);
    var allHands = new[]
    {
        new[] { 1, 1, 0, 0, 1, 2, 2, 0, 1, 2, 0, 1, 2, 0, 0, 0, 0, 0 },
        new[] { 0, 1, 0, 0, 0, 0, 1, 0, 2, 1, 0, 1, 0, 1, 1, 1, 1, 0 },
        new[] { 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 2, 0, 1, 1, 0, 0, 0, 2 },
        aiHand
    };
    var exactWall = new[] { 0, 2, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1 };

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 7,
        canHu: false,
        canPeng: true,
        canGang: true,
        sourceSeat: 1,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { -1, 0, -2, 3 });

    Console.WriteLine($"hell_challenge_peng_rediscard_tile_action={result.Action.ActionType} gang={result.ActionScores.GetValueOrDefault("gang", int.MinValue)} peng={result.ActionScores.GetValueOrDefault("peng", int.MinValue)} reasons={string.Join("|", result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Gang
        && result.ActionScores.GetValueOrDefault("peng", 0) < result.ActionScores.GetValueOrDefault("gang", 0);
}

static bool SmokeHellChallengeAllowsPengWhenGangHurtsShape()
{
    var aiHand = new[] { 1, 0, 1, 0, 1, 1, 2, 3, 1, 0, 0, 0, 0, 0, 0, 2, 0, 1 };
    var state = SichuanStateCodec.FromRaw(3, 2, 3, 9, aiHand, new int[27]);
    var allHands = new[]
    {
        new[] { 0, 2, 1, 1, 1, 0, 1, 0, 2, 1, 2, 1, 0, 2, 0, 0, 0, 1 },
        new[] { 0, 1, 0, 1, 1, 3, 0, 0, 0, 1, 0, 1, 3, 0, 2, 0, 0, 0 },
        new[] { 0, 0, 1, 0, 0, 0, 3, 0, 0, 0, 2, 0, 1, 1, 1, 0, 1, 0 },
        aiHand
    };
    var exactWall = new[] { 1, 2, 2, 1, 1, 0, 0, 0, 1, 2, 0, 2, 1, 0, 0, 2, 1, 0 };

    var result = new SichuanHellChallengeReactionEngine().DecideReaction(
        state,
        reactionTileType: 7,
        canHu: false,
        canPeng: true,
        canGang: true,
        sourceSeat: 2,
        reactionType: "discard",
        allHands18: allHands,
        exactWall18: exactWall,
        currentScores: new[] { 10, -2, 7, -5 });

    Console.WriteLine($"hell_challenge_peng_shape_action={result.Action.ActionType} gang={result.ActionScores.GetValueOrDefault("gang", int.MinValue)} peng={result.ActionScores.GetValueOrDefault("peng", int.MinValue)} reasons={string.Join("|", result.Reasons)}");
    return result.Action.ActionType == SichuanActionType.Peng
        && result.ActionScores.GetValueOrDefault("peng", int.MinValue) > result.ActionScores.GetValueOrDefault("gang", int.MinValue);
}

static bool SmokeLateWallRiskRegression(SichuanAiFacade facade)
{
    var case37 = SichuanStateCodec.FromRaw(3, 0, 3, 3,
        new[] { 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 2, 0, 0, 0 },
        new[] { 2, 1, 3, 0, 0, 1, 3, 4, 4, 3, 0, 2, 2, 1, 3, 3, 3, 2 },
        new[] { 2, 3, 1, 4, 4, 3, 1, 0, 0, 1, 4, 2, 2, 3, 1, 1, 1, 2 },
        new[] { new[] { 17, 2, 6, 0 }, new[] { 6, 11, 8, 1 }, Array.Empty<int>(), new[] { 2, 5, 14, 12, 2, 17 } },
        new[] { new[] { 9, 9, 9, 8, 8, 8 }, new[] { 7, 7, 7 }, Array.Empty<int>(), new[] { 16, 16, 16, 15, 15, 15 } });
    Array.Copy(new bool[] { true, false, true, false }, case37.HasHu, 4);

    var case84 = SichuanStateCodec.FromRaw(3, 2, 3, 5,
        new[] { 0, 0, 2, 0, 1, 1, 2, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 2 },
        new[] { 0, 3, 3, 1, 2, 1, 2, 1, 1, 2, 1, 4, 4, 4, 4, 2, 1, 2 },
        new[] { 4, 1, 1, 3, 2, 3, 2, 3, 3, 2, 3, 0, 0, 0, 0, 2, 3, 2 },
        new[] { new[] { 12 }, new[] { 1, 8, 2 }, new[] { 15, 1, 1, 4, 3 }, new[] { 13, 9 } },
        new[] { new[] { 13, 13, 13 }, new[] { 11, 11, 11, 11 }, new[] { 12, 12, 12, 14, 14, 14 }, Array.Empty<int>() });
    Array.Copy(new bool[] { true, true, false, false }, case84.HasHu, 4);

    var case215 = SichuanStateCodec.FromRaw(1, 0, 1, 0,
        new[] { 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0 },
        new[] { 4, 3, 3, 2, 1, 3, 1, 1, 2, 4, 4, 4, 3, 1, 2, 1, 1, 0 },
        new[] { 0, 1, 1, 2, 3, 1, 3, 3, 2, 0, 0, 0, 1, 3, 2, 3, 3, 4 },
        new[] { new[] { 12, 12 }, new[] { 2, 12, 11, 14 }, new[] { 2, 9, 1, 8, 13, 3 }, new[] { 1, 5, 5 } },
        new[] { new[] { 9, 9, 9 }, new[] { 10, 10, 10, 10 }, new[] { 0, 0, 0, 0 }, new[] { 11, 11, 11 } });
    Array.Copy(new bool[] { true, false, false, true }, case215.HasHu, 4);

    var result37 = facade.DecideDiscard(case37);
    var result84 = facade.DecideDiscard(case84);
    var result215 = facade.DecideDiscard(case215);
    var result37Selected = result37.Candidates.FirstOrDefault(candidate => candidate.TileType == result37.Action.TileType);
    var case37KeepsReadyWithAcceptableRisk = result37Selected is not null
        && result37Selected.Shanten <= 0
        && result37Selected.WaitCount > 0
        && result37Selected.Danger < 78;
    var case215Top = string.Join(",", result215.Candidates.Take(6).Select(candidate => $"{candidate.TileType}:{candidate.Score}/u{candidate.UnifiedActionValue:F2}/r{candidate.StrategicResidual:F2}/s{candidate.Shanten}/w{candidate.WaitCount}/l{candidate.LiveUkeire}/d{candidate.Danger}"));
    Console.WriteLine($"late_wall_case37_tile={result37.Action.TileType} case37_ready={case37KeepsReadyWithAcceptableRisk} case84_tile={result84.Action.TileType} case215_tile={result215.Action.TileType} case215_top={case215Top}");
    return (result37.Action.TileType != 0 || case37KeepsReadyWithAcceptableRisk)
        && result84.Action.TileType != 2
        && result215.Action.TileType != 8;
}

static bool SmokeWanSuitIncludedInCoreLogic(SichuanAiFacade facade)
{
    var oneWan = SichuanTileCodec.EncodeTileType(2, 1);
    var fiveWan = SichuanTileCodec.EncodeTileType(2, 5);
    var nineWan = SichuanTileCodec.EncodeTileType(2, 9);
    var decodedFiveWan = SichuanTileCodec.DecodeTileType(fiveWan);
    if (oneWan != 18 || fiveWan != 22 || nineWan != 26 || decodedFiveWan != (2, 5))
        return false;

    var completeWanHand = SichuanTileCodec.BuildCount18(new[]
    {
        SichuanTileCodec.EncodeTileType(2, 1),
        SichuanTileCodec.EncodeTileType(2, 1),
        SichuanTileCodec.EncodeTileType(2, 1),
        SichuanTileCodec.EncodeTileType(2, 2),
        SichuanTileCodec.EncodeTileType(2, 3),
        SichuanTileCodec.EncodeTileType(2, 4),
        SichuanTileCodec.EncodeTileType(2, 5),
        SichuanTileCodec.EncodeTileType(2, 6),
        SichuanTileCodec.EncodeTileType(2, 7),
        SichuanTileCodec.EncodeTileType(2, 8),
        SichuanTileCodec.EncodeTileType(2, 8),
        SichuanTileCodec.EncodeTileType(2, 8),
        SichuanTileCodec.EncodeTileType(2, 9),
        SichuanTileCodec.EncodeTileType(2, 9),
    });
    var shanten = new SichuanShantenEngine().CalcBestShanten(completeWanHand);
    if (shanten != -1)
        return false;

    var mixedHand = SichuanTileCodec.BuildCount18(new[]
    {
        SichuanTileCodec.EncodeTileType(2, 1),
        SichuanTileCodec.EncodeTileType(2, 2),
        SichuanTileCodec.EncodeTileType(2, 3),
        SichuanTileCodec.EncodeTileType(2, 4),
        SichuanTileCodec.EncodeTileType(2, 5),
        SichuanTileCodec.EncodeTileType(2, 6),
        SichuanTileCodec.EncodeTileType(2, 7),
        SichuanTileCodec.EncodeTileType(2, 8),
        SichuanTileCodec.EncodeTileType(2, 9),
        SichuanTileCodec.EncodeTileType(1, 2),
        SichuanTileCodec.EncodeTileType(1, 3),
        SichuanTileCodec.EncodeTileType(1, 4),
        SichuanTileCodec.EncodeTileType(0, 5),
    });
    var state = SichuanStateCodec.FromRaw(1, 0, 0, 38, mixedHand, new int[27]);
    var decision = facade.DecideDiscard(state);
    var hasWanCandidate = decision.Candidates.Any(candidate => candidate.TileType is >= 18 and <= 26);
    Console.WriteLine($"wan_suit_smoke one={oneWan} five={fiveWan} nine={nineWan} shanten={shanten} action={decision.Action.TileType} has_wan_candidate={hasWanCandidate}");
    return hasWanCandidate;
}

static bool SmokeCSharpForcesOwnDingQueSuit(SichuanAiFacade facade)
{
    var hand = SichuanTileCodec.BuildCount18(new[]
    {
        0, 1, 2, 3, 4,
        9, 10, 11, 12, 13,
        18, 20, 22, 24,
    });
    var state = SichuanStateCodec.FromRaw(
        2,
        0,
        2,
        38,
        hand,
        new int[27],
        dingQueSuits: new[] { 0, 1, 2, 0 });
    var decision = facade.DecideDiscard(state);
    var onlyWanCandidates = decision.Candidates.Count > 0
        && decision.Candidates.All(candidate => candidate.TileType is >= 18 and <= 26);
    Console.WriteLine($"ding_que_priority action={decision.Action.TileType} candidates={string.Join(',', decision.Candidates.Select(candidate => candidate.TileType))}");
    return decision.Action.TileType is >= 18 and <= 26 && onlyWanCandidates;
}
