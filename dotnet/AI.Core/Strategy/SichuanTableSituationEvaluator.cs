using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanTableSituation(
    int Stage,
    string ScorePosition,
    int StrongestThreatSeat,
    double StrongestThreat,
    double AttackBudget,
    double DefenseBudget,
    IReadOnlyList<string> Reasons);

public sealed class SichuanTableSituationEvaluator
{
    public SichuanTableSituation Evaluate(SichuanStateView state, SichuanHiddenHandPosterior? posterior = null)
    {
        var stage = state.WallCount <= 7 ? 2 : state.WallCount <= 15 ? 1 : 0;
        var ownScore = state.Scores.ElementAtOrDefault(state.SeatIndex);
        var rank = state.Scores.Count(score => score > ownScore) + 1;
        var threats = Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex && state.ActiveSeats[seat] && !state.HasHu[seat])
            .Select(seat => (seat, value: (posterior?.ReadyProbabilities.ElementAtOrDefault(seat) ?? 0.0) + state.Melds18[seat].Count / 12.0 + (state.IsReady[seat] ? 0.45 : 0)))
            .OrderByDescending(item => item.value)
            .ToArray();
        var strongest = threats.FirstOrDefault();
        var defense = Math.Clamp(0.18 + stage * 0.22 + strongest.value * 0.34 + (rank == 1 ? 0.12 : 0), 0, 1);
        var attack = Math.Clamp(1 - defense + (rank >= 3 ? 0.18 : 0), 0, 1);
        return new SichuanTableSituation(stage, rank == 1 ? "领先" : rank == 4 ? "落后" : "中游", strongest.seat, strongest.value, attack, defense,
            new[] { $"牌局阶段 {stage}", $"当前排名 {rank}", strongest.value >= 0.65 ? $"{strongest.seat} 号位为最大威胁" : "桌面威胁尚可控" });
    }
}
