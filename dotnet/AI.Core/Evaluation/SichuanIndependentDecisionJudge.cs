using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Evaluation;

public sealed class SichuanIndependentDecisionJudge
{
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanLegalActionEngine _legal = new();
	private readonly SichuanOfflineCounterfactualEvaluator _offline = new();
	private readonly SichuanCrossValidatedActionOracle _crossValidatedOracle = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanActionTreeEvaluator _tree = new();

    public SichuanDecisionJudgement JudgeDiscard(SichuanStateView state, int actualTileType)
    {
		var oracle = _crossValidatedOracle.EvaluateDiscards(state, 48, OracleSeed(state, 17));
		var candidates = oracle.Actions;
		if (candidates.Count == 0)
            return new SichuanDecisionJudgement(actualTileType.ToString(), "none", -100, -100, 0, SichuanDecisionErrorCategory.Rule, new[] { "没有合法弃牌候选" });
		var actualKey = $"discard:{actualTileType}";
		var best = candidates[0];
		var actual = candidates.FirstOrDefault(item => item.ActionKey == actualKey);
		var legal = actual is not null;
		var actualValue = legal ? actual!.ValidationMean : -100;
		var regret = legal ? actual!.ValidationRegret : Math.Max(0, best.ValidationMean + 100);
		var category = !legal ? SichuanDecisionErrorCategory.Rule
			: regret < 0.45 ? SichuanDecisionErrorCategory.None
			: state.Hand18[actualTileType] >= 2 ? SichuanDecisionErrorCategory.Route
			: state.WallCount <= 8 ? SichuanDecisionErrorCategory.AttackDefense
			: SichuanDecisionErrorCategory.Weight;
		var breakdown = actual?.Breakdown ?? new SichuanOracleValueBreakdown(0, 0, 0, 0, 0, 0, 0);
		return new SichuanDecisionJudgement(actualKey, best.ActionKey, actualValue, best.ValidationMean, regret, category,
			new[]
			{
				$"交叉验证净值 {actualValue:F2}，95%CI [{actual?.ConfidenceLow ?? -100:F2}, {actual?.ConfidenceHigh ?? -100:F2}]",
				$"牌形 {breakdown.ShapeProgress:F2} / 胡益 {breakdown.WinGain:F2} / 查叫 {breakdown.ChaJiaoValue:F2}",
				$"点炮损失 {breakdown.DealInLoss:F2} / 路线 {breakdown.RouteValue:F2}",
				$"独立盲测后悔值 {regret:F2}"
			},
			actual?.ActionKey == oracle.ValidationBestAction);
    }

    public SichuanDecisionJudgement JudgeReaction(
        SichuanStateView state,
        SichuanActionType actualAction,
        int tileType,
        bool canHu,
        bool canPeng,
        bool canGang)
    {
		var oracle = _crossValidatedOracle.EvaluateReaction(
			state, tileType, canHu, canPeng, canGang, state.CurrentSeat, 48, OracleSeed(state, tileType + 101));
		var values = oracle.Actions.Select(item => (key: item.ActionKey, value: item.ValidationMean)).ToArray();
        var category = actualAction == SichuanActionType.Pass && canHu
            ? SichuanDecisionErrorCategory.PassHu
            : SichuanDecisionErrorCategory.Meld;
		var actionKey = actualAction == SichuanActionType.Pass ? "pass" : ActionKey(new SichuanAction(actualAction, tileType));
		var result = BuildActionJudgement(actionKey, values, category);
		var actual = oracle.Actions.FirstOrDefault(item => item.ActionKey == actionKey);
		return result with
		{
			Reasons = actual is null ? result.Reasons : new[]
			{
				$"交叉验证动作净值 {actual.ValidationMean:F2}，95%CI [{actual.ConfidenceLow:F2}, {actual.ConfidenceHigh:F2}]",
				$"牌形 {actual.Breakdown.ShapeProgress:F2} / 胡益 {actual.Breakdown.WinGain:F2} / 杠益 {actual.Breakdown.GangGain:F2}",
				$"点炮损失 {actual.Breakdown.DealInLoss:F2} / 后悔值 {actual.ValidationRegret:F2}"
			}
		};
    }

    public SichuanDecisionJudgement JudgeSelfAction(
        SichuanStateView state,
        SichuanAction actualAction,
        bool canSelfHu,
        IReadOnlyList<int> concealedGangTiles,
        IReadOnlyList<int> addedGangTiles)
    {
        var actions = _legal.BuildSelfActions(canSelfHu, concealedGangTiles, addedGangTiles);
        var values = actions
            .Select(action => (key: ActionKey(action), value: SelfActionObjectiveValue(state, action, concealedGangTiles.Contains(action.TileType))))
            .OrderByDescending(item => item.value)
            .ToArray();
        var category = actualAction.ActionType == SichuanActionType.Pass && canSelfHu
            ? SichuanDecisionErrorCategory.PassHu
            : SichuanDecisionErrorCategory.Meld;
        return BuildActionJudgement(ActionKey(actualAction), values, category);
    }

    public SichuanEvaluationMetrics Aggregate(IEnumerable<SichuanDecisionJudgement> judgements)
    {
        var items = judgements.ToArray();
        var errors = items.GroupBy(item => item.Category).ToDictionary(group => group.Key, group => group.Count());
        var calibration = items.Where(item => item.ActualSuccess.HasValue).ToArray();
        var byPdf = items.Where(item => item.PdfSource > 0)
            .GroupBy(item => item.PdfSource)
            .ToDictionary(group => group.Key, group => BuildPdfMetrics(group.ToArray()));
        return new SichuanEvaluationMetrics(
            items.Length,
            items.Length == 0 ? 0 : items.Average(item => item.Regret),
            Rate(items, item => item.Regret >= 2.5),
            errors,
            Rate(items, item => item.RouteConsistent),
            Rate(items, item => item.Category == SichuanDecisionErrorCategory.Rule),
            Rate(items, item => item.Category == SichuanDecisionErrorCategory.PassHu),
            Rate(items, item => item.Category == SichuanDecisionErrorCategory.Meld),
			calibration.Length == 0 ? 0 : calibration.Average(item => Math.Pow(item.PredictedSuccessProbability - (item.ActualSuccess!.Value ? 1 : 0), 2)),
			ExpectedCalibrationError(calibration),
			calibration.Length,
            byPdf);
    }

    private double ObjectiveValue(SichuanStateView state, SichuanDiscardAnalysis item)
    {
        var safety = Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex)
            .Count(seat => state.Discards18[seat].Contains(item.DiscardTileType));
        var waitWidth = state.WallCount <= 0 ? item.Waits.Count : item.Waits.Sum(wait => wait.LiveCount);
        var terminalPenalty = item.DiscardTileType % 9 is 0 or 8 ? 0.12 : 0;
        var search = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
            LiveTiles: Math.Max(item.LiveUkeire, waitWidth),
            WallTiles: Math.Max(1, state.Remaining18.Sum()),
            ActivePlayers: Math.Max(1, state.ActiveSeats.Count(active => active)),
            OwnTurnOffset: state.SeatIndex,
            WinScore: Math.Max(1, item.WaitQuality),
            OpponentWinProbabilityPerDraw: state.WallCount <= 12 ? 0.045 : 0.022,
            OpponentWinLoss: state.WallCount <= 12 ? 4 : 3,
            Simulations: 4096,
            Seed: unchecked(20260713 + state.RoundIndex * 131 + state.SeatIndex * 17)));
        return -item.Shanten * 4.0
            + (state.WallCount <= 0 ? 0 : item.LiveUkeire * 0.16)
            + waitWidth * 0.12
            + safety * 0.32
            + terminalPenalty
            - (state.WallCount <= 0 ? Math.Max(0, item.Shanten) * 3.5 : item.StructuralLoss * 0.035)
            + search.ExpectedNetScore * 0.16;
    }

    private double ReactionObjectiveValue(SichuanStateView state, SichuanAction action)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        return action.ActionType switch
        {
			SichuanActionType.Pass => _offline.EvaluateReactionPass(state).Value,
			SichuanActionType.Hu => ProjectHuValue(state, action.TileType, SichuanWinType.Discard),
			SichuanActionType.Peng => _offline.EvaluatePeng(state, action.TileType).Value,
			SichuanActionType.Gang => _offline.EvaluateMeldedGang(state, action.TileType).Value,
            _ => -100
        };
    }

    private double SelfActionObjectiveValue(SichuanStateView state, SichuanAction action, bool concealedGang)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        return action.ActionType switch
        {
			SichuanActionType.Pass => _offline.EvaluateSelfContinue(state).Value,
			SichuanActionType.Hu => ProjectHuValue(state, -1, SichuanWinType.SelfDraw),
			SichuanActionType.Gang => concealedGang
				? _offline.EvaluateConcealedGang(state, action.TileType).Value
				: _offline.EvaluateAddedGang(state, action.TileType).Value,
            _ => -100
        };
    }

    private double BestDiscardObjectiveValue(SichuanStateView state)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        return _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount)
            .Select(item => ObjectiveValue(state, item))
            .DefaultIfEmpty(-20)
            .Max();
    }

    private double ProjectHuValue(SichuanStateView state, int winningTileType, SichuanWinType winType)
    {
        var completed = (int[])state.Hand18.Clone();
        if (winningTileType is >= 0 and < 27) completed[winningTileType]++;
        var meldViews = state.MeldViews[state.SeatIndex].Cast<SichuanMeldView>().ToArray();
        var projected = _fans.Project(completed, meldViews, winType);
        return Math.Max(1, projected.HandScore);
    }

    private static SichuanDecisionJudgement BuildActionJudgement(
        string actualKey,
        IReadOnlyList<(string key, double value)> candidates,
        SichuanDecisionErrorCategory errorCategory)
    {
        if (candidates.Count == 0)
            return new SichuanDecisionJudgement(actualKey, "none", -100, -100, 0, SichuanDecisionErrorCategory.Rule, new[] { "没有合法动作候选" });
        var best = candidates[0];
        var found = candidates.FirstOrDefault(item => item.key == actualKey);
        var legal = candidates.Any(item => item.key == actualKey);
        var actualValue = legal ? found.value : -100;
        var regret = Math.Max(0, best.value - actualValue);
        var category = !legal ? SichuanDecisionErrorCategory.Rule : regret < 0.45 ? SichuanDecisionErrorCategory.None : errorCategory;
        return new SichuanDecisionJudgement(actualKey, best.key, actualValue, best.value, regret, category,
            new[] { $"独立动作值 {actualValue:F2}", $"最佳动作值 {best.value:F2}", $"后悔值 {regret:F2}" });
    }

	private static string ActionKey(SichuanAction action)
		=> action.TileType >= 0 ? $"{action.ActionType.ToString().ToLowerInvariant()}:{action.TileType}" : action.ActionType.ToString().ToLowerInvariant();

	private static int OracleSeed(SichuanStateView state, int salt)
		=> unchecked(20260810 ^ state.RoundIndex * 1009 ^ state.SeatIndex * 131 ^ state.WallCount * 17 ^ salt);

    private static SichuanDecisionErrorCategory ResolveCategory(SichuanStateView state, int actual, IReadOnlyList<(int DiscardTileType, double value)> candidates, double regret)
    {
        if (candidates.All(item => item.DiscardTileType != actual)) return SichuanDecisionErrorCategory.Rule;
        if (regret < 0.45) return SichuanDecisionErrorCategory.None;
        if (state.Hand18[actual] >= 3) return SichuanDecisionErrorCategory.Route;
        if (state.WallCount <= 8) return SichuanDecisionErrorCategory.AttackDefense;
        return SichuanDecisionErrorCategory.Weight;
    }

	private static double Rate(IReadOnlyList<SichuanDecisionJudgement> items, Func<SichuanDecisionJudgement, bool> predicate)
		=> items.Count == 0 ? 0 : items.Count(predicate) / (double)items.Count;

	private static double ExpectedCalibrationError(IReadOnlyList<SichuanDecisionJudgement> items)
	{
		if (items.Count == 0) return 0;
		var error = 0.0;
		for (var bin = 0; bin < 10; bin++)
		{
			var lower = bin / 10.0;
			var upper = (bin + 1) / 10.0;
			var bucket = items.Where(item => item.PredictedSuccessProbability >= lower
				&& (bin == 9 ? item.PredictedSuccessProbability <= upper : item.PredictedSuccessProbability < upper)).ToArray();
			if (bucket.Length == 0) continue;
			var confidence = bucket.Average(item => item.PredictedSuccessProbability);
			var accuracy = bucket.Average(item => item.ActualSuccess!.Value ? 1.0 : 0.0);
			error += bucket.Length / (double)items.Count * Math.Abs(confidence - accuracy);
		}
		return error;
	}

    private static SichuanPdfEvaluationMetrics BuildPdfMetrics(IReadOnlyList<SichuanDecisionJudgement> items)
        => new(
            items.Count,
            items.Count == 0 ? 0 : items.Average(item => item.Regret),
            Rate(items, item => item.Regret >= 2.5),
            Rate(items, item => item.RouteConsistent));
}
