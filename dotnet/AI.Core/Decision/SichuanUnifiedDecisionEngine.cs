using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Inference;

namespace SichuanMahjong.AI.Core.Decision;

public sealed class SichuanUnifiedDecisionEngine
{
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanActionTreeEvaluator _tree = new();
    private readonly SichuanMultiPlayerUtilityEngine _multiPlayer = new();
	private readonly SichuanBeliefEngine _belief = new();
	private readonly SichuanWallAvailabilityEngine _wall = new();
	private readonly SichuanHandShapeEngine _shape = new();
	private readonly SichuanMeldCounterfactualEvaluator _melds = new();
	private readonly SichuanPublicEndgameEvaluator _publicEndgame = new();
	private readonly SichuanSingleLaneEvaluator _singleLane = new();
	private readonly SichuanRouteContinuationEvaluator _routes = new();
	private readonly SichuanReadyWaitPricing _readyPrices = new();
	private readonly SichuanFlyingDecisionPolicy _flying = new();

	public SichuanDecisionExplanation RankDiscards(SichuanStateView state, SichuanBeliefSnapshot? belief = null,
        IReadOnlyList<SichuanDiscardAnalysis>? preparedAnalyses = null)
	{
        using var decisionScope = SichuanPolicyExecutionScope.EnterDecision();
        using var policyTimer = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("unified_discard");
		belief ??= _belief.Build(state);
		var wallAvailability = _wall.Build(state, belief);
		var meldCount = Math.Max(0, state.OwnMeldCount);
		var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
			&& Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
			? state.OwnDingQueSuit : -1;
		var analyses = preparedAnalyses ?? _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount, meldCount == 0, forcedSuit);
		var candidates = new List<SichuanDecisionCandidate>();
		var laneValues = _singleLane.EvaluateDiscards(state, belief, wallAvailability);
        var readyProfiles = analyses.ToDictionary(a => a.DiscardTileType, a =>
        {
            if (a.Shanten != 0) return null;
            var after = (int[])state.Hand18.Clone(); after[a.DiscardTileType]--;
            return _readyPrices.Build(state, after, wallAvailability.ExpectedCounts18);
        });
        int LegalDistance(SichuanDiscardAnalysis a)
        {
            var hand = (int[])state.Hand18.Clone(); hand[a.DiscardTileType]--;
            var distance = new SichuanShantenEngine().CalcLegalShanten(hand, meldCount, state.OwnDingQueSuit, meldCount == 0);
            return distance == 0 && readyProfiles[a.DiscardTileType] is null ? 1 : distance;
        }
        int[] LegalDrawsAfterDiscard(int tile)
        {
            var hand = (int[])state.Hand18.Clone(); hand[tile]--;
            return new SichuanShantenEngine().LegalImprovingTiles(hand, state.Remaining18, meldCount, state.OwnDingQueSuit);
        }
        var minimumLegalDistance = analyses.Count > 0 ? analyses.Min(LegalDistance) : 8;
        // Full endgame projection is a late/high-threat calculation. Early
        // ready hands use their exact live waits and leave cha-jiao payer
        // estimation to the current terminal model only when it can change
        // the decision materially.
        var needsTerminalReadiness = state.WallCount <= 24
            || belief.SeatReadyPosterior.Values.Any(v => v >= 0.55);
        var terminalReadiness = needsTerminalReadiness && readyProfiles.Values.Any(r => r is not null)
            ? new SichuanTerminalReadinessProjection().Evaluate(state, belief) : null;
		foreach (var analysis in analyses)
		{
			var activePlayers = Math.Max(2, state.ActiveSeats.Count(value => value));
			var ready = readyProfiles[analysis.DiscardTileType];
            var legalDistance = LegalDistance(analysis);
			var relevantTiles = ready is not null
				? ready.Waits.Select(wait => wait.TileType)
				: forcedSuit >= 0 ? LegalDrawsAfterDiscard(analysis.DiscardTileType) : analysis.ImprovingTiles;
			var liveWaits = wallAvailability.SumExpected(relevantTiles);
			var isReady = ready is not null;
			var opponentLoss = 2.5;
			var handAfterDiscard = (int[])state.Hand18.Clone();
			handAfterDiscard[analysis.DiscardTileType]--;
			var winScore = ready is { HasDrawableWait: true } ? ready.WeightedSelfDrawPerPayer * (activePlayers - 1) : 0.0;
			var chaJiaoScore = EstimateChaJiaoScore(state, ready, belief, terminalReadiness);
			var opponentWinPerDraw = EstimateOpponentWinPerDraw(state, belief, wallAvailability);
			var chance = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
				isReady ? liveWaits : 0,
				Math.Max(0, state.WallCount),
				activePlayers,
				SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state),
				winScore,
				opponentWinPerDraw,
				opponentLoss,
				ChaJiaoValue: chaJiaoScore,
				// The chance model already solves its tail to wall exhaustion.
				// Keep that tail in its win/loss/cha-jiao components: treating a
				// truncated tail's net as route value applies different utility
				// weights and makes the same position depend on MaxDraws.
				MaxDraws: Math.Max(0, state.WallCount),
				Simulations: 512,
					Seed: 20260713 ^ state.RoundIndex ^ (state.SeatIndex << 8)));
			var structuralLoss = state.WallCount <= 0
				? Math.Max(0, legalDistance - minimumLegalDistance) * 3.5
				: analysis.StructuralLoss * 0.035;
			var baselineRisk = Math.Max(0, state.Remaining18[analysis.DiscardTileType])
				* (state.WallCount <= 10 ? 0.08 : 0.025);
			var modeledMultiHuRisk = Enumerable.Range(0, 4)
				.Where(seat => seat != state.SeatIndex && state.ActiveSeats[seat] && !state.HasHu[seat])
				.Sum(seat => (belief.SeatTileWaitProbability.GetValueOrDefault(seat)
					?.GetValueOrDefault(analysis.DiscardTileType, 0.0) ?? 0.0)
					* (2.0 + Math.Min(4, state.MeldCount(seat)) * 0.75));
			// Public wait probabilities are not yet calibrated enough to price
			// routine early discards. Use the multi-Hu cost when the wall is short
			// or there is independent high-readiness evidence.
			var highThreat = state.WallCount <= 12 || Enumerable.Range(0, 4)
				.Any(seat => seat != state.SeatIndex && state.ActiveSeats[seat]
					&& belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.55);
			var dealInRisk = highThreat ? Math.Max(baselineRisk, modeledMultiHuRisk) : baselineRisk;
			var gangDiscardExtraLoss = SichuanGangDiscardLiability.ExpectedExtraLoss(state, analysis.DiscardTileType, belief);
			dealInRisk += gangDiscardExtraLoss;
			var winGain = chance.ExpectedOwnWinGain;
			var expectedGangGain = chance.ExpectedGangGain;
			var chaJiaoValue = chance.ExpectedChaJiaoValue;
			var opponentFutureLoss = chance.ExpectedOpponentLoss;
			var shape = _shape.Evaluate(handAfterDiscard, wallAvailability.RepresentativeCounts18, meldCount, legalDistance,
                state.PolicyVariant == "theory_shape_legacy" ? null : state.OwnDingQueSuit);
			var routeContinuations = _routes.Evaluate(state, handAfterDiscard, wallAvailability);
			var ordinaryOpportunity = routeContinuations.First(route => route.Route == "ordinary").ComparableOpportunity;
			var bestSpecialRoute = routeContinuations.Where(route => route.Route != "ordinary")
				.OrderByDescending(route => route.ComparableOpportunity).First();
			// Ready hands already have exact wait/settlement pricing above. Only a
			// bounded non-ready route option is added, never a sum of overlapping
			// seven-pairs, flush and ordinary outcomes.
			var specialRouteOption = isReady ? 0 : Math.Clamp(
				bestSpecialRoute.ComparableOpportunity - ordinaryOpportunity, 0, 0.45);
			var lane = laneValues.GetValueOrDefault(analysis.DiscardTileType);
			var exclusiveSuitRouteValue = lane?.Value ?? 0;
			var futureOwnDraws = Math.Max(0, (state.WallCount - SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state)
				+ activePlayers - 1) / activePlayers);
			var progressChance = isReady || state.WallCount <= 0 ? 0.0
				: 1.0 - Math.Pow(1.0 - Math.Clamp(liveWaits / state.WallCount, 0.0, 1.0), futureOwnDraws);
			var routeValue = Math.Max(0, 1.2 - legalDistance * 0.4)
				+ chance.ExpectedContinuationValue
				+ Math.Max(specialRouteOption, exclusiveSuitRouteValue)
				+ progressChance * Math.Max(0.2, 1.2 - legalDistance * 0.2)
				+ Math.Clamp(shape.ShapeScore, -1.0, 1.0) * 0.12;
			var uncertainty = state.InformationMode == "oracle" ? 0 : 0.18;
			var utility = _multiPlayer.Evaluate(new SichuanMultiPlayerUtilityInput(
				winGain,
				expectedGangGain,
				chaJiaoValue,
				dealInRisk,
				opponentFutureLoss,
				0,
				routeValue,
				uncertainty + structuralLoss,
				activePlayers,
				state.InformationMode == "oracle" ? 1 : 0.78));
			var reasons = new List<string> { $"EXACT_SHANTEN_{legalDistance}", $"WALL_LIVE_{liveWaits:F2}", $"PROGRESS_CHANCE_{progressChance:F2}", $"MULTI_HU_LOSS_{modeledMultiHuRisk:F2}", highThreat ? "MULTI_HU_RISK_ACTIVE" : "MULTI_HU_RISK_SHADOW", $"CHA_JIAO_{chaJiaoScore:F2}", $"CHANCE_HORIZON_{chance.HorizonProbability:F2}", $"STRUCTURAL_LOSS_{analysis.StructuralLoss}", $"CHANCE_EV_{utility.NetUtility:F2}" };
            if (SichuanGangDiscardLiability.CurrentGangCash(state) is not null)
                reasons.Add($"GANG_DISCARD_EXTRA_LOSS_PUBLIC_APPROX_{gangDiscardExtraLoss:F4}");
            if (ready is not null) reasons.Add("LEGAL_READY_ALL_WAIT_PRICING");
            if (ready is not null && terminalReadiness is not null) reasons.Add(terminalReadiness.Reason);
            if (ready is { HasDrawableWait: false }) reasons.Add("LEGAL_READY_DEAD_WAIT_CHA_JIAO");
            if (analysis.Shanten == 0 && !isReady) reasons.Add("STRUCTURAL_READY_NOT_LEGAL");
			reasons.Add($"ROUTE_OPTION_{bestSpecialRoute.Route}_{bestSpecialRoute.TargetSuit}_{specialRouteOption:F2}");
			if (lane != null) reasons.AddRange(lane.Reasons);
			candidates.Add(new SichuanDecisionCandidate(
				new SichuanAction(SichuanActionType.Discard, analysis.DiscardTileType),
				utility.NetUtility,
				winGain,
				expectedGangGain,
				chaJiaoValue,
				dealInRisk,
				opponentFutureLoss,
				routeValue,
				uncertainty + structuralLoss,
				reasons));
		}
		var ordered = candidates.OrderByDescending(candidate => candidate.ExpectedNetScore).ThenBy(candidate => candidate.Action.TileType).ToArray();
		var selected = ordered.FirstOrDefault();
		return selected is null
			? new SichuanDecisionExplanation(SichuanActionType.Pass, "没有合法弃牌", new[] { "NO_LEGAL_DISCARD" }, Array.Empty<SichuanDecisionCandidate>())
			: new SichuanDecisionExplanation(SichuanActionType.Discard, $"当前牌形、机会和风险策略值最高，打 {selected.Action.TileType}", selected.ReasonCodes, ordered);
	}

	internal static double EstimateOpponentWinPerDraw(
		SichuanStateView state, SichuanBeliefSnapshot belief, SichuanWallAvailability wall)
	{
		if (wall.WallCount <= 0) return 0;
		var seats = Enumerable.Range(0, 4).Where(seat => seat != state.SeatIndex
			&& state.ActiveSeats[seat] && !state.HasHu[seat]).ToArray();
		if (seats.Length == 0) return 0;
		return Math.Clamp(seats.Average(seat =>
		{
			var waits = belief.SeatTileWaitProbability.GetValueOrDefault(seat);
			return Enumerable.Range(0, 27).Sum(tile => wall.ExpectedCounts18[tile]
				* (waits?.GetValueOrDefault(tile, 0.0) ?? 0.0)) / wall.WallCount;
		}), 0.0, 0.35);
	}

	private double EstimateReadyWinScore(
		SichuanStateView state,
		int[] handAfterDiscard,
		IReadOnlyList<SichuanWaitAnalysis> waits,
		SichuanWallAvailability wall,
		int activeOpponents)
	{
		var melds = state.MeldViews[state.SeatIndex].Count > 0
			? state.MeldViews[state.SeatIndex].ToArray()
			: InferMeldViews(state, state.SeatIndex);
		var weightedScore = 0.0;
		var totalWeight = 0.0;
		foreach (var wait in waits)
		{
			var weight = wall.ExpectedCounts18[wait.TileType];
			if (weight <= 0) continue;
			var completed = (int[])handAfterDiscard.Clone();
			completed[wait.TileType]++;
			weightedScore += weight * _fans.Project(completed, melds, SichuanWinType.SelfDraw).PerPayerScore
				* activeOpponents;
			totalWeight += weight;
		}
		return totalWeight > 0 ? weightedScore / totalWeight : 0.0;
	}

	private double EstimateChaJiaoScore(
		SichuanStateView state,
		SichuanReadyPrice? ready,
		SichuanBeliefSnapshot belief, SichuanTerminalReadinessEstimate? terminalReadiness)
	{
		if (ready is null) return 0.0;
        // A partial fixture cannot support an invented future payer count.
        if (terminalReadiness is not { Supported: true }) return 0.0;
        // Cha-jiao is legal shape, not drawable supply. A publicly exhausted
        // legal wait can pay cha-jiao; an owned fifth-copy wait cannot.
		var bestPerPayer = ready.Waits.Max(wait => wait.HandScore);
		var expectedPayers = state.ActiveSeats
			.Select((active, seat) => (active, seat))
			.Where(item => item.active && item.seat != state.SeatIndex)
			.Sum(item => 1.0 - terminalReadiness.ReadyProbabilities[item.seat]);
		return bestPerPayer * expectedPayers;
	}

	public SichuanDecisionExplanation RankMeldActions(
		SichuanStateView state,
		int tileType,
		bool canPeng,
		bool canGang,
		double routeLoss = 0,
		double risk = 0,
		SichuanBeliefSnapshot? belief = null,
        int pengDiscardTile = -1,
        int gangSourceSeat = -1)
	{
		belief ??= _belief.Build(state);
		var meldCount = Math.Max(0, state.OwnMeldCount);
		var pass = _melds.Evaluate(state, "pass", tileType, 0, meldCount, 0, 0, 0, belief);
		var candidates = new List<SichuanDecisionCandidate>
		{
			FromCounterfactual(pass, new SichuanAction(SichuanActionType.Pass, tileType))
		};
        if (canPeng && state.Hand18[tileType] >= 2)
			candidates.Add(FromCounterfactual(_melds.Evaluate(state, "peng", tileType, 2, meldCount + 1, routeLoss, risk, 0, belief, pengDiscardTile, gangSourceSeat), new SichuanAction(SichuanActionType.Peng, tileType)));
		if (canGang && state.Hand18[tileType] >= 3)
			candidates.Add(FromCounterfactual(_melds.Evaluate(state, "melded_gang", tileType, 3, meldCount + 1, routeLoss, risk, 0, belief, gangSourceSeat:gangSourceSeat), new SichuanAction(SichuanActionType.Gang, tileType)));
		var ordered = candidates.OrderByDescending(candidate => candidate.ExpectedNetScore)
            .ThenByDescending(candidate => candidate.QuickReadyTiePreferred).ToArray();
		return new SichuanDecisionExplanation(ordered[0].Action.ActionType, $"反事实净分选择 {ordered[0].Action.ActionType}", ordered[0].ReasonCodes, ordered);
	}

    // Live choice uses the shared development strategy, not a terminal rollout.
    public SichuanDecisionExplanation CompareDiscardHuWithPass(SichuanStateView state, int winningTileType,
        int sourceSeat, string reactionType, bool canPeng = false, SichuanRoundBrainSnapshot? roundBrain = null,
        bool canGang = false)
    {
        using var decisionScope = SichuanPolicyExecutionScope.EnterDecision();
        var type = reactionType == "qiang_gang_hu" ? SichuanWinType.RobAddedGang
            : reactionType == "gang_discard" ? SichuanWinType.GangDiscard : SichuanWinType.Discard;
        var evidence = new SichuanDevelopmentPolicy().AssessRefusal(state, winningTileType, type);
        // Pass can have no future own draw while a legal Gang receives an
        // immediate replacement. Compare a publicly guaranteed win before
        // applying Pass's eligibility gate. No speculative future income is
        // used here: all known replacement copies must win immediately.
        if (canGang && !SichuanOpponentWideBedDefense.Applies(state)
            && evidence.EffectiveWinType == SichuanWinType.Discard && state.WallCount > 0
            && state.Hand18[winningTileType] == 3)
        {
            var belief = _belief.Build(state);
            var wall = _wall.Build(state, belief);
            if (wall.KnownWallCounts18.Sum() == wall.WallCount)
            {
                var gang = _melds.Evaluate(state, "melded_gang", winningTileType, 3,
                    state.OwnMeldCount + 1, 0, 0, 0, belief, gangSourceSeat: sourceSeat);
                var gain = gang.ImmediateGangGain + gang.ReplacementWinGain;
                if (gang.ReplacementBranches.Count > 0 && gang.ReplacementBranches.All(b => b.ImmediateWin)
                    && gang.ReplacementWinProbability >= 1 - 1e-9 && gain > evidence.ImmediateHuGain)
                {
                    var reasons = evidence.Reasons.Concat(new[] {
                        "HU_VS_GANG_KNOWN_IMMEDIATE_REPLACEMENT_WIN",
                        $"公开牌墙全部补牌均能立即胡：点杠 {gang.ImmediateGangGain}，补牌胡收入 {gang.ReplacementWinGain:F4}，当前接胡 {evidence.ImmediateHuGain:F4}"
                    }).ToArray();
                    return new(SichuanActionType.Gang, "比较接胡与点杠立即补牌，兑现更高的确定收入", reasons,
                        new[] {
                            new SichuanDecisionCandidate(new(SichuanActionType.Hu, winningTileType), evidence.ImmediateHuGain,
                                evidence.ImmediateHuGain, 0, 0, 0, 0, 0, 0, evidence.Reasons),
                            new SichuanDecisionCandidate(new(SichuanActionType.Gang, winningTileType), gain,
                                gang.ReplacementWinGain, gang.ImmediateGangGain, 0, 0, 0, 0, 0, reasons)
                        });
                }
            }
        }
        var candidates = new List<SichuanDecisionCandidate> {
            new(new(SichuanActionType.Hu, winningTileType), evidence.ImmediateHuGain,
                evidence.ImmediateHuGain, 0, 0, 0, 0, 0, 0, evidence.Reasons),
            new(new(SichuanActionType.Pass, winningTileType), evidence.LocalSelfDrawValue + evidence.LocalGangValue - (evidence.Waiting?.WaitingLoss ?? 0),
                evidence.LocalSelfDrawValue, evidence.LocalGangValue - (evidence.Waiting?.GangPaymentLoss ?? 0), 0,
                evidence.Waiting?.DealInLoss ?? 0, evidence.Waiting?.OpponentSelfDrawLoss ?? 0, 0, 0,
                evidence.Reasons, evidence.Refuse)
        };
        var selectedAction = evidence.Refuse ? SichuanActionType.Pass : SichuanActionType.Hu;
        SichuanReactionDecisionResult? localReaction = null;
        if (evidence.Refuse && (canPeng || canGang))
        {
            // Once refusal is justified, choose the concrete claim with the
            // same local meld strategy used for all other reactions.
            var followUp = new SichuanReactionDecisionEngine().DecideReaction(state, winningTileType,
                false, canPeng, canGang, sourceSeat, reactionType, roundBrain: roundBrain);
            localReaction = followUp;
            if (followUp.Action.ActionType is SichuanActionType.Peng or SichuanActionType.Gang)
            {
                selectedAction = followUp.Action.ActionType;
                candidates.Add(new(followUp.Action, evidence.LocalSelfDrawValue + evidence.LocalGangValue - (evidence.Waiting?.WaitingLoss ?? 0),
                    evidence.LocalSelfDrawValue, evidence.LocalGangValue - (evidence.Waiting?.GangPaymentLoss ?? 0), 0,
                    evidence.Waiting?.DealInLoss ?? 0, evidence.Waiting?.OpponentSelfDrawLoss ?? 0, 0, 0,
                    evidence.Reasons.Concat(followUp.Reasons).Append("HU_REFUSAL_FOLLOWS_LOCAL_MELD_POLICY").ToArray()));
            }
        }

        // 4.4 source action chain: a discard that could be Hu may be Penged,
        // followed by a deliberately selected first discard that re-enters
        // tenpai. This comparison is independent of the generic refusal
        // gate. It is still conservative: the branch must be legal, widen the
        // priced wait, survive the first-discard danger gate, and beat the
        // immediate Hu baseline by a visible margin.
        if (canPeng && reactionType == "discard")
        {
            var flying = _flying.Decide(state, winningTileType, sourceSeat, evidence);
            if (flying.IsAdmissible)
            {
                var followUp = new SichuanReactionDecisionEngine().DecideReaction(
                    state, winningTileType, false, canPeng: true, canGang: false,
                    sourceSeat, reactionType, roundBrain: roundBrain);
                var flightBranch = flying.Branches.First(branch => branch.DiscardTile == flying.DiscardTile);
                if (followUp.Action.ActionType != SichuanActionType.Peng)
                {
                    // The ordinary meld ranker is allowed to reject a Peng
                    // because it does not know that this Hu reaction is a
                    // source-style flight chain. Once the independent flight
                    // policy has passed its route, danger, wait and future
                    // Gang gates, promote the concrete action to Peng here.
                    followUp.Action = new SichuanAction(
                        SichuanActionType.Peng, winningTileType,
                        SichuanStrategyContract.Score(flying.Value),
                        "放飞：碰后指定首打并重新下叫");
                    followUp.Reasons = followUp.Reasons
                        .Append("FLYING_OVERRIDES_GENERIC_MELD_RANKING")
                        .ToArray();
                }
                if (followUp.Action.ActionType == SichuanActionType.Peng)
                {
                    followUp.PlannedDiscardTile = flying.DiscardTile;
                    followUp.Action = followUp.Action with
                    {
                        Score = SichuanStrategyContract.Score(flying.Value),
                        Reason = "放飞：碰后指定首打并重新下叫"
                    };
                    followUp.Reasons = followUp.Reasons
                        .Concat(flying.Reasons)
                        .Append("FLYING_PRODUCTION_ACTION_APPLIED")
                        .Distinct()
                        .ToArray();
                    followUp.FutureSummary = followUp.FutureSummary
                        .Concat(new[] { $"FLYING_PENG_DISCARD_{flying.DiscardTile}", "FLYING_REENTER_TENPAI" })
                        .ToArray();
                    followUp.ShantenAfter = flightBranch.Shanten;
                    followUp.UkeireAfter = flightBranch.WaitCount;
                    followUp.LiveUkeireAfter = (int)Math.Ceiling(flightBranch.DrawableMass);

                    candidates.RemoveAll(candidate => candidate.Action.ActionType == SichuanActionType.Peng);
                    candidates.Add(new(
                        followUp.Action,
                        flying.Value,
                        WinGain: 0,
                        GangGain: 0,
                        ChaJiaoValue: 0,
                        DealInLoss: flying.Branches.First(branch => branch.DiscardTile == flying.DiscardTile).Danger,
                        OpponentFutureLoss: 0,
                        RouteContinuationValue: flying.Value,
                        UncertaintyPenalty: 0,
                        evidence.Reasons.Concat(followUp.Reasons).Concat(flying.Reasons)
                            .Append("HU_VS_FLYING_PENG_RESHAPE")
                            .ToArray()));
                    selectedAction = SichuanActionType.Peng;
                    localReaction = followUp;
                }
            }
        }
        var selected = candidates.First(c => c.Action.ActionType == selectedAction);
        return new(selectedAction, selectedAction == SichuanActionType.Hu
            ? "依据当前听口、危险和收手条件兑现胡牌"
            : selectedAction == SichuanActionType.Peng && selected.ReasonCodes.Contains("HU_VS_FLYING_PENG_RESHAPE")
                ? "放飞比较通过：碰后指定首打重新下叫"
                : "当前发展策略及局部机会支持拒胡，后续随新状态重估",
            selected.ReasonCodes, candidates) { LocalReaction = localReaction };
    }

    // Explicit research comparison; independent terminal samples validate the
    // live strategy and never run implicitly while choosing an action.
    public SichuanDecisionExplanation AnalyzeDiscardHuWithPass(SichuanStateView state, int winningTileType,
        int sourceSeat, string reactionType, bool canPeng = false, SichuanRoundBrainSnapshot? roundBrain = null,
        bool canGang = false)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        var completed = (int[])state.Hand18.Clone();
        completed[winningTileType]++;
        var melds = state.MeldViews[state.SeatIndex].Count > 0
            ? state.MeldViews[state.SeatIndex].ToArray() : InferMeldViews(state, state.SeatIndex);
        var root = SichuanPublicEndgameEvaluator.PrepareReactionRoot(state, winningTileType, sourceSeat, reactionType);
        var type = root?.WinType ?? (reactionType == "qiang_gang_hu" ? SichuanWinType.RobAddedGang
            : reactionType == "gang_discard" ? SichuanWinType.GangDiscard : SichuanWinType.Discard);
        var fan = _fans.Project(completed, melds, type);
        var strategy = SichuanStrategyContract.Assess(state);
        var discipline = strategy.Discipline;
        var development = strategy.Development;
        if (!SichuanStrategyContract.CanRefuse(strategy, type))
        {
            var hu = new SichuanDecisionCandidate(new(SichuanActionType.Hu, winningTileType), fan.HandScore,
                fan.HandScore, 0, 0, 0, 0, 0, 0, strategy.Reasons);
            return new(SichuanActionType.Hu, "统一策略收手条件触发，兑现胡牌", hu.ReasonCodes, new[] { hu });
        }
        var pengDiscard = -1;
        if (canPeng && root?.PriorWinners.Length == 0 && state.Hand18[winningTileType] >= 2)
        {
            var hand = (int[])state.Hand18.Clone(); hand[winningTileType] -= 2;
            var projected = ProjectPengContinuation(state, hand, winningTileType, sourceSeat);
            // Price the discard the live production policy will actually choose.
            pengDiscard = SichuanDiscardPolicy.Select(projected, roundBrain, state).Action.TileType;
        }
        var seed = 20261002 ^ state.RoundIndex * 7919 ^ state.TurnIndex * 104729 ^ (state.SeatIndex << 16);
        var discovery = _publicEndgame.AnalyzeHuContinuation(state, winningTileType, sourceSeat, reactionType,
            32, seed, pengDiscard, canGang);
        if (discovery.Candidates.Count == 0)
        {
            // No speculative refusal from an incomplete public state. The
            // runtime has already established that this offered Hu is legal.
            var hu = new SichuanDecisionCandidate(new(SichuanActionType.Hu, winningTileType), fan.HandScore,
                fan.HandScore, 0, 0, 0, 0, 0, 0,
                new[] { "HU_CONTINUATION_UNAVAILABLE", discovery.Status, "拒绝凭不完整信息放弃合法胡牌" });
            return new(SichuanActionType.Hu, "公开信息不足以证明过胡有利，接胡", hu.ReasonCodes, new[] { hu });
        }
        var challenger = discovery.Candidates.Where(c => c.Action != SichuanActionType.Hu)
            .OrderByDescending(c => c.DifferenceFromHu).First();
        SichuanHuContinuationReport? confirmation = null;
        if (discovery.EffectiveSampleSize >= 12 && challenger.DifferenceFromHu > 0)
            confirmation = _publicEndgame.AnalyzeHuContinuation(state, winningTileType, sourceSeat, reactionType,
                128, seed ^ 15485863, pengDiscard, canGang);
        var report = confirmation?.Candidates.Count > 0 ? confirmation : discovery;
        var candidates = report.Candidates.Select(c =>
        {
            // Confirmation is independent of discovery; only the preselected
            // challenger may be promoted. This is sampling uncertainty, not a
            // claim of calibrated confidence against model misspecification.
            var margin = Math.Max(0.25, fan.HandScore * 0.25);
            var admissible = c.Action == SichuanActionType.Hu
                || confirmation is not null && report == confirmation && c.Action == challenger.Action
                    && report.EffectiveSampleSize >= 32
                    && c.DifferenceFromHu > margin + 2.4 * c.DifferenceStandardError;
            var conditionalPayers = c.SelfDrawProbability > 0 ? c.ExpectedSelfDrawPayers / c.SelfDrawProbability : 0;
            var reasons = new List<string> {
                "HU_INCOME_COST_FULL_CONTINUATION", SichuanPolicyExecutionScope.PolicyDescription,
                "研究终局轨迹使用相同实战策略；动作依据当前状态局部分析，不再嵌套终局模拟", $"样本 {report.Samples}，有效样本 {report.EffectiveSampleSize:F1}",
                $"终局净收益 {c.NetScore:F3}；比立即胡 {c.DifferenceFromHu:+0.000;-0.000;0}，配对标准误 {c.DifferenceStandardError:F3}",
                $"胡牌收入 {c.WinGain:F3}，杠与呼叫转移净额 {c.GangNet:F3}，流局结算 {c.DrawSettlement:F3}",
                $"放炮损失 {c.DealInLoss:F3}，被自摸等损失 {c.OpponentLoss:F3}",
                $"自摸概率估计 {c.SelfDrawProbability:F3}，自摸时平均付款 {conditionalPayers:F2} 家，自己实际摸牌 {c.ExpectedOwnDraws:F2} 次",
                $"顺胡限制阻止接胡 {c.ExpectedLockedRonDenied:F3} 次；已按自己摸牌解除",
                $"后续策略继续拒胡 {c.ExpectedStrategicRefusals:F3} 次；听口、收益或危险变化时重估",
                admissible ? "HU_ACTION_ADMISSIBLE" : "HU_REFUSAL_NOT_CONFIRMED"
            };
            if (discipline.Applies) reasons.AddRange(discipline.Reasons);
            reasons.AddRange(development.Reasons);
            if (c.Action == SichuanActionType.Peng) reasons.Add($"PENG_FOLLOWUP_DISCARD_{pengDiscard}");
            return new SichuanDecisionCandidate(new(c.Action, winningTileType), c.NetScore,
                c.WinGain, c.GangNet, c.DrawSettlement, c.DealInLoss, c.OpponentLoss, 0, 0, reasons, admissible);
        }).ToArray();
        var selected = candidates.Where(c => c.IsAdmissible).OrderByDescending(c => c.ExpectedNetScore).First();
        return new(selected.Action.ActionType, selected.Action.ActionType == SichuanActionType.Hu
            ? "接胡至终局收益更稳，或过胡优势未通过独立验证"
            : "计入动态付款、等待失分、顺胡和终局结算后，放弃本次接胡更有利",
            selected.ReasonCodes, candidates);
    }

	internal static SichuanStateView ProjectPengContinuation(SichuanStateView state, int[] hand, int tileType, int sourceSeat)
	{
        var projected = SichuanBranchState.Copy(state, hand, currentSeat: state.SeatIndex);
        projected.Phase=5; projected.VisibleVersion++; projected.HandVersion++; projected.EventVersion++;
        projected.LastDrawTileType=-1; projected.LastDrawOrigin=SichuanTileOrigin.Unknown;
		if (projected.MeldViews[state.SeatIndex].Count == 0)
			projected.MeldViews[state.SeatIndex].AddRange(InferMeldViews(state, state.SeatIndex));
		projected.MeldViews[state.SeatIndex].Add(new SichuanMeldView(SichuanMeldType.Peng, tileType, sourceSeat, projected.EventVersion) { AddedGangBlockedUntilOwnDraw = true });
		projected.Melds18[state.SeatIndex].AddRange(new[] { tileType, tileType, tileType });
        if (sourceSeat is >= 0 and < 4)
        {
            var claimedIndex = projected.Discards18[sourceSeat].LastIndexOf(tileType);
            if (claimedIndex >= 0) projected.Discards18[sourceSeat].RemoveAt(claimedIndex);
        }
		projected.Visible18[tileType] += 2; // The incoming discard was already public.
		projected.HandCounts[state.SeatIndex] = hand.Sum();
		projected.PublicEvents.Add(new SichuanPublicEvent(projected.EventVersion, state.TurnIndex, state.SeatIndex,
			SichuanPublicEventType.Peng, tileType, SourceSeat: sourceSeat, WallCountAfter: state.WallCount));
		return projected;
	}

    public SichuanDecisionExplanation ConfirmSelfDrawHu(SichuanStateView state)
    {
        var melds = state.MeldViews[state.SeatIndex].Count > 0 ? state.MeldViews[state.SeatIndex].Cast<SichuanMeldView>().ToArray() : InferMeldViews(state, state.SeatIndex);
        var context = SichuanSelfDrawContext.Resolve(state);
        var fan = _fans.Project(state.Hand18, melds, context.WinType);
        var activeSeats = Enumerable.Range(0,4).Where(s=>state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        var gain = new SichuanSettlementProjectionEngine().ProjectWin(state.SeatIndex,context.SourceSeat,activeSeats,fan,context.WinType).WinnerGain;
        var hu = new SichuanDecisionCandidate(new SichuanAction(SichuanActionType.Hu, state.LastDrawTileType), gain, gain, 0, 0, 0, 0, 0, 0,
            new[] { "SELF_DRAW_CERTAIN_GAIN", "SELF_DRAW_RULE_CASHFLOW", $"本次胡牌确定收入 {gain}", $"SELF_DRAW_WIN_TYPE_{context.WinType}" });
        var pass = new SichuanDecisionCandidate(new SichuanAction(SichuanActionType.Pass), -gain, 0, 0, 0, 0, gain, 0, 0, new[] { "SELF_DRAW_REFUSAL_UNCALIBRATED", "SELF_DRAW_PASS_COST_ONLY_NOT_CONTINUATION_EV" }, false);
		return new SichuanDecisionExplanation(SichuanActionType.Hu, "自摸为确定收益，直接胡牌", hu.ReasonCodes, new[] { hu, pass });
    }

    private static SichuanMeldView[] InferMeldViews(SichuanStateView state, int seat)
        => state.Melds18[seat]
            .Where(tile => tile is >= 0 and < 27)
            .GroupBy(tile => tile)
            .Select((group, index) => new SichuanMeldView(group.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng, group.Key, -1, index))
            .ToArray();

	private static SichuanDecisionCandidate FromCounterfactual(SichuanMeldCounterfactual value, SichuanAction action)
		=> new(action, value.Value, 0, value.ImmediateGangGain, 0, value.Risk, 0, -value.RouteLoss, 0,
			new[] { $"COUNTERFACTUAL_SHANTEN_{value.Shanten}", $"COUNTERFACTUAL_LIVE_{value.LiveUkeire}", $"COUNTERFACTUAL_EV_{value.Value:F2}" }
                .Concat(new[]{ $"CONTINUATION_MODEL_{value.ContinuationModel}",
                    $"MODEL_REACH_READY_{value.ReachReadyProbability:F6}",
                    $"MODEL_FUTURE_SELF_DRAW_{value.FutureSelfDrawProbability:F6}" })
                .Concat(action.ActionType==SichuanActionType.Gang ? new[]{"GANG_RULE_CASHFLOW",$"GANG_IMMEDIATE_RULE_GAIN_{value.ImmediateGangGain}"} : Array.Empty<string>())
                .Concat(value.ImmediateGangGain > 0 ? new[]{$"GANG_REFUND_EXPECTED_LOSS_{value.ExpectedGangRefundLoss:F4}","GANG_REFUND_PUBLIC_PROGRESS_APPROXIMATION",$"GANG_DISCARD_EXTRA_LOSS_PUBLIC_APPROX_{value.ExpectedGangDiscardExtraLoss:F4}"} : Array.Empty<string>())
                .Concat(value.ReplacementWallConstraintsRebuilt ? new[]{"GANG_REPLACEMENT_PUBLIC_WALL_REBUILT"} : Array.Empty<string>())
                .Concat(value.ContinuationLegalContextApplied ? new[]{"CONTINUATION_LEGAL_READY_CONTEXT"} : Array.Empty<string>())
                .Concat(value.ImmediateSelfAction.Length > 0
                    ? new[] { $"PENG_IMMEDIATE_{value.ImmediateSelfAction.ToUpperInvariant()}_{value.ImmediateSelfActionTile}", value.Transition }
                    : Array.Empty<string>())
                .Concat(value.BranchReadyValueApplied ? new[]{"GANG_BRANCH_READY_VALUE_WEIGHTED_BEFORE_ROUNDING"} : Array.Empty<string>()).ToArray())
        { QuickReadyTiePreferred = action.ActionType == SichuanActionType.Peng && value.Shanten == 0
            && value.LiveUkeire > 0 && value.ImmediateSelfAction.Length == 0,
          ContinuationDiscardRisk = value.ExpectedDiscardRisk };
}
