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
    private readonly SichuanMeldCounterfactualEvaluator _melds = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanActionTreeEvaluator _tree = new();

    public SichuanDecisionJudgement JudgeDiscard(SichuanStateView state, int actualTileType)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
            && Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
            ? state.OwnDingQueSuit : -1;
        var analyses = _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount, true, forcedSuit);
        var candidates = analyses
            .Select(item => (item.DiscardTileType, value: ObjectiveValue(state, item)))
            .OrderByDescending(item => item.value)
            .ToArray();
        if (candidates.Length == 0)
            return new SichuanDecisionJudgement(actualTileType.ToString(), "none", -100, -100, 0, SichuanDecisionErrorCategory.Rule, new[] { "没有合法弃牌候选" });
        var best = candidates[0];
        var actual = candidates.FirstOrDefault(item => item.DiscardTileType == actualTileType);
        var actualValue = actual == default && best.DiscardTileType != actualTileType ? -100 : actual.value;
        var regret = Math.Max(0, best.value - actualValue);
        var category = ResolveCategory(state, actualTileType, candidates, regret);
        var bestAnalysis = analyses.First(item => item.DiscardTileType == best.DiscardTileType);
        var actualAnalysis = analyses.FirstOrDefault(item => item.DiscardTileType == actualTileType);
        var routeConsistent = actualAnalysis is not null
            && actualAnalysis.StructuralLoss <= bestAnalysis.StructuralLoss + 0.35;
        return new SichuanDecisionJudgement($"discard:{actualTileType}", $"discard:{best.DiscardTileType}", actualValue, best.value, regret, category,
            new[] { $"独立牌形值 {actualValue:F2}", $"最佳牌形值 {best.value:F2}", $"后悔值 {regret:F2}" }, routeConsistent);
    }

    public SichuanDecisionJudgement JudgeReaction(
        SichuanStateView state,
        SichuanActionType actualAction,
        int tileType,
        bool canHu,
        bool canPeng,
        bool canGang)
    {
        var actions = _legal.BuildReactionActions(tileType, canHu, canGang, canPeng);
        var values = actions
            .Select(action => (key: ActionKey(action), value: ReactionObjectiveValue(state, action)))
            .OrderByDescending(item => item.value)
            .ToArray();
        var category = actualAction == SichuanActionType.Pass && canHu
            ? SichuanDecisionErrorCategory.PassHu
            : SichuanDecisionErrorCategory.Meld;
        return BuildActionJudgement(ActionKey(new SichuanAction(actualAction, tileType)), values, category);
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
            calibration.Length,
            byPdf);
    }

    private double ObjectiveValue(SichuanStateView state, SichuanDiscardAnalysis item)
    {
        var safety = Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex)
            .Count(seat => state.Discards18[seat].Contains(item.DiscardTileType));
        var waitWidth = item.Waits.Sum(wait => wait.LiveCount);
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
            Seed: unchecked(20260713 + state.RoundIndex * 131 + item.DiscardTileType * 17)));
        return -item.Shanten * 4.0
            + item.LiveUkeire * 0.16
            + waitWidth * 0.12
            + safety * 0.32
            + terminalPenalty
            - item.StructuralLoss * 0.7
            + search.ExpectedNetScore * 0.16;
    }

    private double ReactionObjectiveValue(SichuanStateView state, SichuanAction action)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        return action.ActionType switch
        {
            SichuanActionType.Pass => BestDiscardObjectiveValue(state),
            SichuanActionType.Hu => ProjectHuValue(state, action.TileType, SichuanWinType.Discard),
            SichuanActionType.Peng => _melds.Evaluate(state, "peng", action.TileType, 2, meldCount + 1, 0.25, 0.15, 0).Value,
            SichuanActionType.Gang => _melds.Evaluate(state, "melded_gang", action.TileType, 3, meldCount + 1, 0.35, 0.25, 1.0).Value,
            _ => -100
        };
    }

    private double SelfActionObjectiveValue(SichuanStateView state, SichuanAction action, bool concealedGang)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        return action.ActionType switch
        {
            SichuanActionType.Pass => BestDiscardObjectiveValue(state),
            SichuanActionType.Hu => ProjectHuValue(state, -1, SichuanWinType.SelfDraw),
            SichuanActionType.Gang => _melds.Evaluate(
                state,
                concealedGang ? "concealed_gang" : "added_gang",
                action.TileType,
                concealedGang ? 4 : 1,
                meldCount + 1,
                0.25,
                concealedGang ? 0.10 : 0.55,
                concealedGang ? 1.5 : 0.8).Value,
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

    private static SichuanPdfEvaluationMetrics BuildPdfMetrics(IReadOnlyList<SichuanDecisionJudgement> items)
        => new(
            items.Count,
            items.Count == 0 ? 0 : items.Average(item => item.Regret),
            Rate(items, item => item.Regret >= 2.5),
            Rate(items, item => item.RouteConsistent));
}
