using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

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

	public SichuanDecisionExplanation RankDiscards(SichuanStateView state, SichuanBeliefSnapshot? belief = null)
	{
		belief ??= _belief.Build(state);
		var wallAvailability = _wall.Build(state, belief);
		var meldCount = Math.Max(0, state.Melds18[state.SeatIndex].Count / 3);
		var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
			&& Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
			? state.OwnDingQueSuit : -1;
		var analyses = _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount, meldCount == 0, forcedSuit);
		var endgameValues = _publicEndgame.Evaluate(state, analyses.Where(a => a.Shanten == 0).Select(a => a.DiscardTileType))
			.ToDictionary(value => value.TileType);
		var candidates = new List<SichuanDecisionCandidate>();
		foreach (var analysis in analyses)
		{
			var activePlayers = Math.Max(2, state.ActiveSeats.Count(value => value));
			var relevantTiles = analysis.Shanten == 0
				? analysis.Waits.Select(wait => wait.TileType)
				: analysis.ImprovingTiles;
			var liveWaits = wallAvailability.SumExpected(relevantTiles);
			var winScore = analysis.Shanten == 0 ? 4.0 * (activePlayers - 1) : 2.0;
			var opponentLoss = 2.5;
			var handAfterDiscard = (int[])state.Hand18.Clone();
			handAfterDiscard[analysis.DiscardTileType]--;
			var chaJiaoScore = EstimateChaJiaoScore(state, handAfterDiscard, analysis.Waits);
			var chance = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
				liveWaits,
				Math.Max(0, state.WallCount),
				activePlayers,
				0,
				winScore,
				state.IsReady.Count(value => value) * 0.008,
				opponentLoss,
				ChaJiaoValue: chaJiaoScore,
				Simulations: 512,
					Seed: 20260713 ^ state.RoundIndex ^ (state.SeatIndex << 8)));
			var structuralLoss = state.WallCount <= 0
				? Math.Max(0, analysis.Shanten - analyses.Min(item => item.Shanten)) * 3.5
				: analysis.StructuralLoss * 0.035;
			var dealInRisk = Math.Max(0, 4 - state.Visible18[analysis.DiscardTileType]) * (state.WallCount <= 10 ? 0.08 : 0.025);
			var winGain = chance.OwnWinProbability * winScore;
			var expectedGangGain = chance.ExpectedGangGain;
			var chaJiaoValue = chance.DrawProbability * chaJiaoScore;
			var opponentFutureLoss = chance.OpponentWinProbability * opponentLoss;
			var shape = _shape.Evaluate(handAfterDiscard, wallAvailability.RepresentativeCounts18, meldCount, analysis.Shanten);
			var pairCount = handAfterDiscard.Count(count => count >= 2);
			var pairRouteValue = meldCount == 0 && pairCount >= 4
				? Math.Min(0.45, (pairCount - 3) * 0.15)
				: 0.0;
			var routeValue = Math.Max(0, 1.2 - analysis.Shanten * 0.4)
				+ pairRouteValue
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
			var hasEndgame = endgameValues.TryGetValue(analysis.DiscardTileType, out var endgame);
			var reasons = new List<string> { $"EXACT_SHANTEN_{analysis.Shanten}", $"WALL_LIVE_{liveWaits:F2}", $"CHA_JIAO_{chaJiaoScore:F2}", $"STRUCTURAL_LOSS_{analysis.StructuralLoss}", $"CHANCE_EV_{utility.NetUtility:F2}" };
			if (hasEndgame)
			{
				reasons.Add($"PUBLIC_ENDGAME_SAMPLES_{endgame!.Samples}");
				reasons.Add($"PUBLIC_ENDGAME_MODELED_NET_{endgame.NetScore:F3}");
				reasons.Add("GENERIC_COMPONENTS_DIAGNOSTIC_ONLY");
			}
			candidates.Add(new SichuanDecisionCandidate(
				new SichuanAction(SichuanActionType.Discard, analysis.DiscardTileType),
				hasEndgame ? endgame!.NetScore : utility.NetUtility,
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
			: new SichuanDecisionExplanation(SichuanActionType.Discard, $"精确净分最高，打 {selected.Action.TileType}", selected.ReasonCodes, ordered);
	}

	private double EstimateChaJiaoScore(
		SichuanStateView state,
		int[] handAfterDiscard,
		IReadOnlyList<SichuanWaitAnalysis> waits)
	{
		if (waits.Count == 0) return 0.0;
		var melds = state.MeldViews[state.SeatIndex].Count > 0
			? state.MeldViews[state.SeatIndex].ToArray()
			: InferMeldViews(state, state.SeatIndex);
		var bestPerPayer = 0;
		foreach (var wait in waits)
		{
			var completed = (int[])handAfterDiscard.Clone();
			completed[wait.TileType]++;
			var fan = _fans.Project(completed, melds, SichuanWinType.SelfDraw);
			bestPerPayer = Math.Max(bestPerPayer, fan.HandScore);
		}
		var expectedPayers = state.ActiveSeats
			.Select((active, seat) => (active, seat))
			.Count(item => item.active && item.seat != state.SeatIndex && !state.IsReady[item.seat]);
		return bestPerPayer * expectedPayers;
	}

	public SichuanDecisionExplanation RankMeldActions(
		SichuanStateView state,
		int tileType,
		bool canPeng,
		bool canGang,
		double routeLoss = 0,
		double risk = 0,
		SichuanBeliefSnapshot? belief = null)
	{
		belief ??= _belief.Build(state);
		var meldCount = Math.Max(0, state.Melds18[state.SeatIndex].Count / 3);
		var pass = _melds.Evaluate(state, "pass", tileType, 0, meldCount, 0, 0, 0, belief);
		var candidates = new List<SichuanDecisionCandidate>
		{
			FromCounterfactual(pass, new SichuanAction(SichuanActionType.Pass, tileType))
		};
		if (canPeng && state.Hand18[tileType] >= 2)
			candidates.Add(FromCounterfactual(_melds.Evaluate(state, "peng", tileType, 2, meldCount + 1, routeLoss, risk, 0, belief), new SichuanAction(SichuanActionType.Peng, tileType)));
		if (canGang && state.Hand18[tileType] >= 3)
			candidates.Add(FromCounterfactual(_melds.Evaluate(state, "gang", tileType, 3, meldCount + 1, routeLoss, risk, 2, belief), new SichuanAction(SichuanActionType.Gang, tileType)));
		var ordered = candidates.OrderByDescending(candidate => candidate.ExpectedNetScore).ToArray();
		return new SichuanDecisionExplanation(ordered[0].Action.ActionType, $"反事实净分选择 {ordered[0].Action.ActionType}", ordered[0].ReasonCodes, ordered);
	}

    public SichuanDecisionExplanation CompareDiscardHuWithPass(SichuanStateView state, int winningTileType, int sourceSeat, string reactionType, bool canPeng = false, SichuanRoundBrainSnapshot? roundBrain = null)
    {
        var completed = (int[])state.Hand18.Clone();
        if (winningTileType is >= 0 and < 27) completed[winningTileType]++;
        var melds = state.MeldViews[state.SeatIndex].Count > 0
            ? state.MeldViews[state.SeatIndex].Cast<SichuanMeldView>().ToArray()
            : InferMeldViews(state, state.SeatIndex);
        var winType = reactionType == "qiang_gang_hu" ? SichuanWinType.RobAddedGang : reactionType == "gang_discard" ? SichuanWinType.GangDiscard : SichuanWinType.Discard;
        var fan = _fans.Project(completed, melds, winType);
        var immediateGain = fan.HandScore;
        var hu = new SichuanDecisionCandidate(
            new SichuanAction(SichuanActionType.Hu, winningTileType), immediateGain, immediateGain, 0, 0, 0, 0, 0, 0,
            new[] { "HU_REALIZED_SCORE", $"即时胡牌 {fan.CappedFan} 番，净得 {immediateGain}" });

		var belief = _belief.Build(state);
		var wallAvailability = _wall.Build(state, belief);
		var waits = _hands.EnumerateWaits(state.Hand18, state.Remaining18, melds.Length);
		// Raw Remaining18 also contains opponents' concealed tiles.  Passing a
		// legal Hu must be priced from the wall-constrained public posterior,
		// otherwise a nominal two-sided wait is routinely counted twice.
		var liveTiles = waits.Sum(wait => wallAvailability.RepresentativeCounts18[wait.TileType]);
		var expectedLiveTiles = wallAvailability.SumExpected(waits.Select(wait => wait.TileType));
        var activePlayers = state.ActiveSeats.Count(active => active);
        var expectedOwnDraws = Math.Max(1, Math.Min(4, state.WallCount / Math.Max(1, activePlayers)));
		var weightedSelfDraw = 0.0;
		var weightedDiscardWin = 0.0;
		foreach (var wait in waits)
		{
			var weight = wallAvailability.ExpectedCounts18[wait.TileType];
			if (weight <= 0) continue;
			var futureHand = (int[])state.Hand18.Clone();
			futureHand[wait.TileType]++;
			weightedSelfDraw += _fans.Project(futureHand, melds, SichuanWinType.SelfDraw).PerPayerScore * weight;
			weightedDiscardWin += _fans.Project(futureHand, melds, SichuanWinType.Discard).HandScore * weight;
		}
		var selfDrawPerPayer = expectedLiveTiles > 0 ? weightedSelfDraw / expectedLiveTiles
			: fan.HandScore + SichuanRuleSnapshot.Frozen.SelfDrawBottomBonus;
		var futureDiscardScore = expectedLiveTiles > 0 ? weightedDiscardWin / expectedLiveTiles : fan.HandScore;

		// A pair in a suit that opponents are forced to clear can become a real
		// Peng continuation.  Price the best such public branch with the same
		// meld evaluator and opponent hold posteriors; do not assume the tile is
		// in a particular hand or that a later added-Gang will arrive.
		var currentWaitValue = _melds.Evaluate(state, "pass", -1, 0, melds.Length, 0, 0, 0, belief).Value;
		var forcedPairRouteValue = 0.0;
		var forcedPairTile = -1;
		var forcedPairChance = 0.0;
		for (var tile = 0; tile < 27; tile++)
		{
			if (state.Hand18[tile] < 2) continue;
			var forcedSeats = Enumerable.Range(0, 4).Where(seat => seat != state.SeatIndex
				&& state.ActiveSeats[seat] && !state.HasHu[seat] && state.DingQueSuits[seat] == tile / 9).ToArray();
			if (forcedSeats.Length == 0) continue;
			var noHold = forcedSeats.Aggregate(1.0, (probability, seat) => probability *
				(1.0 - Math.Clamp(belief.SeatTileHoldProbability.GetValueOrDefault(seat)?.GetValueOrDefault(tile) ?? 0, 0, 1)));
			var forcedDiscardChance = 1.0 - noHold;
			if (forcedDiscardChance <= 0) continue;
			var peng = _melds.Evaluate(state, "peng", tile, 2, melds.Length + 1, 0, 0, 0, belief);
			var value = forcedDiscardChance * Math.Max(0, peng.Value - currentWaitValue);
			if (value <= forcedPairRouteValue) continue;
			forcedPairRouteValue = value;
			forcedPairTile = tile;
			forcedPairChance = forcedDiscardChance;
		}
        var passBreakdown = _tree.EvaluateWait(
            liveTiles,
            Math.Max(1, state.WallCount),
            expectedOwnDraws,
            selfDrawPerPayer * Math.Max(1, activePlayers - 1),
            Math.Clamp(liveTiles / (double)Math.Max(1, state.WallCount) * 0.35, 0, 0.45),
            futureDiscardScore,
            0.015,
            fan.HandScore,
            state.WallCount <= 8 ? fan.HandScore * 0.45 : 0,
            (waits.Count >= 2 ? 0.35 : 0) + forcedPairRouteValue,
            state.InformationMode == "oracle" ? 0 : 0.35);
        var lockCost = fan.HandScore * 0.28;
        var passNet = passBreakdown.Net - lockCost;
		var confidence = state.InformationMode == "oracle" ? 1.0 : Math.Clamp(0.70 + liveTiles * 0.04, 0.70, 0.90);
		var canPass = liveTiles >= 2 && state.WallCount >= 6 && _multiPlayer.CanPassHu(immediateGain, passNet, confidence, true);
		var passReasons = new List<string> { "PASS_HU_EV", $"过胡后 {waits.Count} 门，墙内代表活张 {liveTiles}，期望 {expectedLiveTiles:F2}",
			$"顺胡锁成本 {lockCost:F2}", $"未来净期望 {passNet:F2}" };
		if (forcedPairTile >= 0)
			passReasons.Add($"定缺强制排出对子 {forcedPairTile}：公开持有机会 {forcedPairChance:F3}，碰后路线增值 {forcedPairRouteValue:F2}");
		passReasons.Add(canPass ? "PASS_HU_ADMISSIBLE" : "PASS_HU_BLOCKED_BY_CONFIDENCE_OR_WALL");
		var pass = new SichuanDecisionCandidate(
            new SichuanAction(SichuanActionType.Pass, winningTileType), passNet, passBreakdown.WinGain, 0, passBreakdown.ChaJiaoValue,
            passBreakdown.DealInLoss, passBreakdown.OpponentFutureLoss, passBreakdown.RouteContinuationValue, passBreakdown.UncertaintyPenalty + lockCost,
			passReasons,
			canPass);

		var candidates = new List<SichuanDecisionCandidate> { hu, pass };
		// Hu and Peng may both be legal. Do not erase the claim continuation
		// merely because this discard can win. Keep the existing conservative
		// pass-Hu gate, and price the ready continuation with the same wait tree.
		if (canPeng && winningTileType is >= 0 and < 27 && state.Hand18[winningTileType] >= 2)
		{
			var afterClaim = (int[])state.Hand18.Clone();
			afterClaim[winningTileType] -= 2;
			var projectedMelds = melds.Append(new SichuanMeldView(SichuanMeldType.Peng, winningTileType, sourceSeat, state.EventVersion)).ToArray();
			var pengCandidates = new List<SichuanDecisionCandidate>();
			var projectedState = ProjectPengContinuation(state, afterClaim, winningTileType, sourceSeat);
			var projectedBelief = _belief.Build(projectedState);
			var projectedWall = _wall.Build(projectedState, projectedBelief);
			// The current discard policy must actually support the continuation
			// being priced. Do not assume an ideal discard that the next entry
			// call would replace with a different, narrower wait.
			var predictedDiscard = state.WallCount >= 6
				? new SichuanDecisionEngine().DecideDiscard(projectedState, false, roundBrain).Action.TileType : -1;
			foreach (var analysis in _hands.AnalyzeDiscards(afterClaim, state.Remaining18, projectedMelds.Length, false))
			{
				if (analysis.DiscardTileType != predictedDiscard) continue;
				if (analysis.Shanten != 0) continue;
				var afterDiscard = (int[])afterClaim.Clone();
				afterDiscard[analysis.DiscardTileType]--;
				var wallLive = analysis.Waits.Sum(wait => projectedWall.RepresentativeCounts18[wait.TileType]);
				var weightedHandScore = 0.0;
				foreach (var wait in analysis.Waits)
				{
					afterDiscard[wait.TileType]++;
					weightedHandScore += _fans.Project(afterDiscard, projectedMelds, SichuanWinType.SelfDraw).HandScore * projectedWall.RepresentativeCounts18[wait.TileType];
					afterDiscard[wait.TileType]--;
				}
				var futureHandScore = wallLive > 0 ? weightedHandScore / wallLive : 0;
				var ownDrawOffset = SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state);
				var drawsAfterClaim = state.WallCount <= ownDrawOffset ? 0
					: Math.Min(4, 1 + (state.WallCount - ownDrawOffset - 1) / Math.Max(1, activePlayers));
				var future = _tree.EvaluateWait(wallLive, Math.Max(1, state.WallCount), drawsAfterClaim,
					(futureHandScore + SichuanRuleSnapshot.Frozen.SelfDrawBottomBonus) * Math.Max(1, activePlayers - 1),
					0, futureHandScore, 0.015, futureHandScore,
					0, 0, state.InformationMode == "oracle" ? 0 : 0.35);
				// No future ron credit; reuse the conservative refusal cost from
				// Pass without changing the runtime's lock semantics. Price the mandatory discard
				// using public ready/wait posteriors and the frozen maximum loss.
				var discardLoss = 0.0;
				for (var seat = 0; seat < 4; seat++)
				{
					if (seat == state.SeatIndex || !state.ActiveSeats[seat] || state.HasHu[seat]
						|| state.DingQueSuits[seat] == analysis.DiscardTileType / 9) continue;
					var waitProbability = projectedBelief.SeatTileWaitProbability.TryGetValue(seat, out var seatWaits)
						? seatWaits.GetValueOrDefault(analysis.DiscardTileType) : 0;
					discardLoss += Math.Clamp(projectedBelief.SeatReadyPosterior.GetValueOrDefault(seat), 0, 1)
						* Math.Clamp(waitProbability, 0, 1)
						* SichuanRuleSnapshot.Frozen.BaseScore * (1 << SichuanRuleSnapshot.Frozen.FanCap);
				}
				var net = future.Net - lockCost - discardLoss;
				var claimConfidence = state.InformationMode == "oracle" ? 1.0 : Math.Clamp(0.62 + wallLive * 0.025, 0.62, 0.90);
				var admissible = wallLive >= 2 && state.WallCount >= 6
					&& _multiPlayer.CanPassHu(immediateGain, net, claimConfidence, true);
				pengCandidates.Add(new SichuanDecisionCandidate(new SichuanAction(SichuanActionType.Peng, winningTileType),
					net, future.WinGain, 0, 0, future.DealInLoss + discardLoss, 0, 0, future.UncertaintyPenalty + lockCost,
					new[] { "PENG_WHILE_HU_COUNTERFACTUAL", $"碰后弃 {analysis.DiscardTileType}，{analysis.Waits.Count} 门，墙内代表活张 {wallLive}",
						$"PENG_FOLLOWUP_DISCARD_{analysis.DiscardTileType}", $"强制弃牌封顶成本估值 {discardLoss:F2}",
						admissible ? "PENG_WHILE_HU_ADMISSIBLE" : "PENG_WHILE_HU_BLOCKED_BY_CONFIDENCE_OR_WALL" }, admissible));
			}
			candidates.Add(pengCandidates.OrderByDescending(candidate => candidate.IsAdmissible)
				.ThenByDescending(candidate => candidate.ExpectedNetScore).FirstOrDefault()
				?? new SichuanDecisionCandidate(new SichuanAction(SichuanActionType.Peng, winningTileType), -immediateGain,
					0, 0, 0, 0, 0, 0, immediateGain, new[] { "PENG_WHILE_HU_NO_READY_CONTINUATION" }, false));
		}
		var selected = candidates.Where(candidate => candidate.IsAdmissible).OrderByDescending(candidate => candidate.ExpectedNetScore).First();
        var summary = selected.Action.ActionType == SichuanActionType.Hu
            ? "即时胡牌收益更稳，执行胡牌"
            : selected.Action.ActionType == SichuanActionType.Peng
				? "碰后保叫的公开信息估值通过过胡门禁，选择碰牌"
				: "未来自摸和多家付款净期望显著更高，策略性过胡";
		return new SichuanDecisionExplanation(selected.Action.ActionType, summary, selected.ReasonCodes, candidates);
    }

	private static SichuanStateView ProjectPengContinuation(SichuanStateView state, int[] hand, int tileType, int sourceSeat)
	{
		var projected = new SichuanStateView
		{
			SeatIndex = state.SeatIndex, DealerSeat = state.DealerSeat, CurrentSeat = state.SeatIndex,
			WallCount = state.WallCount, TurnIndex = state.TurnIndex, Phase = state.Phase,
			RoundIndex = state.RoundIndex, TotalRounds = state.TotalRounds, RemainingRounds = state.RemainingRounds,
			VisibleVersion = state.VisibleVersion + 1, HandVersion = state.HandVersion + 1,
			StrategyContextVersion = state.StrategyContextVersion, EventVersion = state.EventVersion + 1,
			InformationMode = state.InformationMode, ExchangeThreeEnabled = state.ExchangeThreeEnabled, Hand18 = hand,
			Visible18 = (int[])state.Visible18.Clone(), Remaining18 = (int[])state.Remaining18.Clone(),
			Scores = (int[])state.Scores.Clone(), DingQueSuits = (int[])state.DingQueSuits.Clone(),
			HandCounts = (int[])state.HandCounts.Clone(), LockedFans = (int[])state.LockedFans.Clone(),
			LockTurns = (int[])state.LockTurns.Clone(), UnlockOnOwnDraw = (bool[])state.UnlockOnOwnDraw.Clone(),
			ActiveSeats = (bool[])state.ActiveSeats.Clone(), HasHu = (bool[])state.HasHu.Clone(),
			IsReady = (bool[])state.IsReady.Clone(), IsCalled = (bool[])state.IsCalled.Clone(),
			Discards18 = state.Discards18.Select(tiles => new List<int>(tiles)).ToArray(),
			Melds18 = state.Melds18.Select(tiles => new List<int>(tiles)).ToArray(),
			PassedHu18 = state.PassedHu18.Select(counts => (int[])counts.Clone()).ToArray(),
			PassedPeng18 = state.PassedPeng18.Select(counts => (int[])counts.Clone()).ToArray(),
			PassedGang18 = state.PassedGang18.Select(counts => (int[])counts.Clone()).ToArray(),
			LastDrawTileType = -1, LastDrawOrigin = SichuanTileOrigin.Unknown,
			LastGangSeat = state.LastGangSeat, LastGangTileType = state.LastGangTileType, LastGangType = state.LastGangType
		};
		for (var seat = 0; seat < 4; seat++) projected.MeldViews[seat].AddRange(state.MeldViews[seat]);
		if (projected.MeldViews[state.SeatIndex].Count == 0)
			projected.MeldViews[state.SeatIndex].AddRange(InferMeldViews(state, state.SeatIndex));
		projected.MeldViews[state.SeatIndex].Add(new SichuanMeldView(SichuanMeldType.Peng, tileType, sourceSeat, projected.EventVersion));
		projected.Melds18[state.SeatIndex].AddRange(new[] { tileType, tileType, tileType });
		projected.Visible18[tileType] += 2; // The incoming discard was already public.
		projected.HandCounts[state.SeatIndex] = hand.Sum();
		projected.PublicEvents.AddRange(state.PublicEvents);
		projected.PublicEvents.Add(new SichuanPublicEvent(projected.EventVersion, state.TurnIndex, state.SeatIndex,
			SichuanPublicEventType.Peng, tileType, SourceSeat: sourceSeat, WallCountAfter: state.WallCount));
		return projected;
	}

    public SichuanDecisionExplanation ConfirmSelfDrawHu(SichuanStateView state)
    {
        var melds = state.MeldViews[state.SeatIndex].Count > 0 ? state.MeldViews[state.SeatIndex].Cast<SichuanMeldView>().ToArray() : InferMeldViews(state, state.SeatIndex);
        var fan = _fans.Project(state.Hand18, melds, state.LastGangSeat == state.SeatIndex ? SichuanWinType.GangSelfDraw : SichuanWinType.SelfDraw);
        var activePayers = Math.Max(1, state.ActiveSeats.Count(active => active) - 1);
        var gain = fan.PerPayerScore * activePayers;
        var hu = new SichuanDecisionCandidate(new SichuanAction(SichuanActionType.Hu, state.LastDrawTileType), gain, gain, 0, 0, 0, 0, 0, 0,
            new[] { "SELF_DRAW_CERTAIN_GAIN", $"自摸确定收益 {gain}，禁止搜索误放弃" });
        var pass = new SichuanDecisionCandidate(new SichuanAction(SichuanActionType.Pass), -gain, 0, 0, 0, 0, gain, 0, 0, new[] { "SELF_DRAW_PASS_FORBIDDEN" });
		return new SichuanDecisionExplanation(SichuanActionType.Hu, "自摸为确定收益，直接胡牌", hu.ReasonCodes, new[] { hu, pass });
    }

    private static SichuanMeldView[] InferMeldViews(SichuanStateView state, int seat)
        => state.Melds18[seat]
            .Where(tile => tile is >= 0 and < 27)
            .GroupBy(tile => tile)
            .Select((group, index) => new SichuanMeldView(group.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng, group.Key, -1, index))
            .ToArray();

	private static SichuanDecisionCandidate FromCounterfactual(SichuanMeldCounterfactual value, SichuanAction action)
		=> new(action, value.Value, 0, action.ActionType == SichuanActionType.Gang ? 2 : 0, 0, value.Risk, 0, -value.RouteLoss, 0,
			new[] { $"COUNTERFACTUAL_SHANTEN_{value.Shanten}", $"COUNTERFACTUAL_LIVE_{value.LiveUkeire}", $"COUNTERFACTUAL_EV_{value.Value:F2}" });
}
