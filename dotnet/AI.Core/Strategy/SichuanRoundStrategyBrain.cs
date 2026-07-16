using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanRoundStrategy(
    string PrimaryRoute,
    string FallbackRoute,
    double PrimaryExpectedValue,
    int TargetSuit,
    double Commitment,
    double RiskBudget,
    int Revision,
    IReadOnlyList<string> Reasons);

public sealed class SichuanRoundStrategyBrain
{
    private readonly SichuanRoundBrainEngine _engine = new();

    public SichuanRoundBrainSnapshot Observe(SichuanStateView state) => _engine.Observe(state);
    public void RecordDiscard(SichuanStateView state, int tileType, SichuanRoutePlanResult plan) => _engine.RecordDiscard(state, tileType, plan);
    public void RecordReaction(SichuanStateView state, SichuanAction action) => _engine.RecordReaction(state, action);
}
