using SichuanMahjong.AI.Core.Domain;
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
	private readonly SichuanMeldCounterfactualEvaluator _melds = new();

	public SichuanDecisionExplanation RankDiscards(SichuanStateView state)
	{
		var meldCount = Math.Max(0, state.Melds18[state.SeatIndex].Count / 3);
		var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
			&& Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
			? state.OwnDingQueSuit : -1;
		var analyses = _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount, meldCount == 0, forcedSuit);
		var candidates = new List<SichuanDecisionCandidate>();
		foreach (var analysis in analyses)
		{
			var activePlayers = Math.Max(2, state.ActiveSeats.Count(value => value));
			var liveWaits = state.WallCount <= 0 ? 0 : analysis.Waits.Sum(wait => wait.LiveCount);
			var winScore = analysis.Shanten == 0 ? 4.0 * (activePlayers - 1) : 2.0;
			var opponentLoss = 2.5;
			var chance = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
				liveWaits,
				Math.Max(1, state.WallCount),
				activePlayers,
				0,
				winScore,
				state.IsReady.Count(value => value) * 0.008,
				opponentLoss,
				ChaJiaoValue: analysis.Shanten == 0 ? 1.2 : 0,
				Simulations: 512,
					Seed: 20260713 ^ state.RoundIndex ^ (state.SeatIndex << 8)));
			var structuralLoss = state.WallCount <= 0
				? Math.Max(0, analysis.Shanten - analyses.Min(item => item.Shanten)) * 3.5
				: analysis.StructuralLoss * 0.035;
			var dealInRisk = Math.Max(0, 4 - state.Visible18[analysis.DiscardTileType]) * (state.WallCount <= 10 ? 0.08 : 0.025);
			var winGain = chance.OwnWinProbability * winScore;
			var expectedGangGain = chance.ExpectedGangGain;
			var chaJiaoValue = chance.DrawProbability * (analysis.Shanten == 0 ? 1.2 : 0);
			var opponentFutureLoss = chance.OpponentWinProbability * opponentLoss;
			var routeValue = Math.Max(0, 1.2 - analysis.Shanten * 0.4);
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
				new[] { $"EXACT_SHANTEN_{analysis.Shanten}", $"EXACT_LIVE_{analysis.LiveUkeire}", $"STRUCTURAL_LOSS_{analysis.StructuralLoss}", $"CHANCE_EV_{utility.NetUtility:F2}" }));
		}
		var ordered = candidates.OrderByDescending(candidate => candidate.ExpectedNetScore).ThenBy(candidate => candidate.Action.TileType).ToArray();
		var selected = ordered.FirstOrDefault();
		return selected is null
			? new SichuanDecisionExplanation(SichuanActionType.Pass, "没有合法弃牌", new[] { "NO_LEGAL_DISCARD" }, Array.Empty<SichuanDecisionCandidate>())
			: new SichuanDecisionExplanation(SichuanActionType.Discard, $"精确净分最高，打 {selected.Action.TileType}", selected.ReasonCodes, ordered);
	}

	public SichuanDecisionExplanation RankMeldActions(
		SichuanStateView state,
		int tileType,
		bool canPeng,
		bool canGang,
		double routeLoss = 0,
		double risk = 0)
	{
		var meldCount = Math.Max(0, state.Melds18[state.SeatIndex].Count / 3);
		var pass = _melds.Evaluate(state, "pass", tileType, 0, meldCount, 0, 0, 0);
		var candidates = new List<SichuanDecisionCandidate>
		{
			FromCounterfactual(pass, new SichuanAction(SichuanActionType.Pass, tileType))
		};
		if (canPeng && state.Hand18[tileType] >= 2)
			candidates.Add(FromCounterfactual(_melds.Evaluate(state, "peng", tileType, 2, meldCount + 1, routeLoss, risk, 0), new SichuanAction(SichuanActionType.Peng, tileType)));
		if (canGang && state.Hand18[tileType] >= 3)
			candidates.Add(FromCounterfactual(_melds.Evaluate(state, "gang", tileType, 3, meldCount + 1, routeLoss, risk, 2), new SichuanAction(SichuanActionType.Gang, tileType)));
		var ordered = candidates.OrderByDescending(candidate => candidate.ExpectedNetScore).ToArray();
		return new SichuanDecisionExplanation(ordered[0].Action.ActionType, $"反事实净分选择 {ordered[0].Action.ActionType}", ordered[0].ReasonCodes, ordered);
	}

    public SichuanDecisionExplanation CompareDiscardHuWithPass(SichuanStateView state, int winningTileType, int sourceSeat, string reactionType)
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

		var waits = _hands.EnumerateWaits(state.Hand18, state.Remaining18, melds.Length);
        var liveTiles = waits.Sum(wait => wait.LiveCount);
        var activePlayers = state.ActiveSeats.Count(active => active);
        var expectedOwnDraws = Math.Max(1, Math.Min(4, state.WallCount / Math.Max(1, activePlayers)));
        var selfDrawPerPayer = fan.HandScore + SichuanRuleSnapshot.Frozen.SelfDrawBottomBonus;
        var passBreakdown = _tree.EvaluateWait(
            liveTiles,
            Math.Max(1, state.WallCount),
            expectedOwnDraws,
            selfDrawPerPayer * Math.Max(1, activePlayers - 1),
            Math.Clamp(liveTiles / (double)Math.Max(1, state.WallCount) * 0.35, 0, 0.45),
            fan.HandScore,
            0.015,
            fan.HandScore,
            state.WallCount <= 8 ? fan.HandScore * 0.45 : 0,
            waits.Count >= 2 ? 0.35 : 0,
            state.InformationMode == "oracle" ? 0 : 0.35);
        var lockCost = fan.HandScore * 0.28;
        var passNet = passBreakdown.Net - lockCost;
		var confidence = state.InformationMode == "oracle" ? 1.0 : Math.Clamp(0.62 + liveTiles * 0.025, 0.62, 0.90);
		var canPass = liveTiles >= 2 && state.WallCount >= 6 && _multiPlayer.CanPassHu(immediateGain, passNet, confidence, true);
		var pass = new SichuanDecisionCandidate(
            new SichuanAction(SichuanActionType.Pass, winningTileType), passNet, passBreakdown.WinGain, 0, passBreakdown.ChaJiaoValue,
            passBreakdown.DealInLoss, passBreakdown.OpponentFutureLoss, passBreakdown.RouteContinuationValue, passBreakdown.UncertaintyPenalty + lockCost,
            new[] { "PASS_HU_EV", $"过胡后 {waits.Count} 门 {liveTiles} 张活口", $"顺胡锁成本 {lockCost:F2}", $"未来净期望 {passNet:F2}", canPass ? "PASS_HU_ADMISSIBLE" : "PASS_HU_BLOCKED_BY_CONFIDENCE_OR_WALL" },
			canPass);

		var selected = new[] { hu, pass }.Where(candidate => candidate.IsAdmissible).OrderByDescending(candidate => candidate.ExpectedNetScore).First();
        var summary = selected.Action.ActionType == SichuanActionType.Hu
            ? "即时胡牌收益更稳，执行胡牌"
            : "未来自摸和多家付款净期望显著更高，策略性过胡";
		return new SichuanDecisionExplanation(selected.Action.ActionType, summary, selected.ReasonCodes, new[] { hu, pass });
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
