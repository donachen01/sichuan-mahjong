using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Evaluation;

public enum SichuanReplayDecisionKind { Discard, Reaction, SelfAction }

public sealed record SichuanReplayDecision(
    SichuanReplayDecisionKind Kind,
    SichuanStateView State,
    SichuanAction ActualAction,
    int TileType = -1,
    bool CanHu = false,
    bool CanPeng = false,
    bool CanGang = false,
    IReadOnlyList<int>? ConcealedGangTiles = null,
    IReadOnlyList<int>? AddedGangTiles = null,
    double PredictedSuccessProbability = 0,
    bool? ActualSuccess = null,
    int PdfSource = 0);

public sealed class SichuanReplayDecisionEvaluator
{
    private readonly SichuanIndependentDecisionJudge _judge = new();

    public SichuanEvaluationMetrics Evaluate(IEnumerable<(SichuanStateView State, int DiscardTileType)> replay)
        => _judge.Aggregate(replay.Select(item => _judge.JudgeDiscard(item.State, item.DiscardTileType)));

    public SichuanEvaluationMetrics Evaluate(IEnumerable<SichuanReplayDecision> replay)
        => _judge.Aggregate(replay.Select(EvaluateOne));

    private SichuanDecisionJudgement EvaluateOne(SichuanReplayDecision item)
    {
        var judgement = item.Kind switch
        {
            SichuanReplayDecisionKind.Discard => _judge.JudgeDiscard(item.State, item.ActualAction.TileType),
            SichuanReplayDecisionKind.Reaction => _judge.JudgeReaction(
                item.State,
                item.ActualAction.ActionType,
                item.TileType,
                item.CanHu,
                item.CanPeng,
                item.CanGang),
            SichuanReplayDecisionKind.SelfAction => _judge.JudgeSelfAction(
                item.State,
                item.ActualAction,
                item.CanHu,
                item.ConcealedGangTiles ?? Array.Empty<int>(),
                item.AddedGangTiles ?? Array.Empty<int>()),
            _ => throw new ArgumentOutOfRangeException(nameof(item.Kind))
        };
        return judgement with
        {
            PredictedSuccessProbability = Math.Clamp(item.PredictedSuccessProbability, 0, 1),
            ActualSuccess = item.ActualSuccess,
            PdfSource = item.PdfSource
        };
    }
}
