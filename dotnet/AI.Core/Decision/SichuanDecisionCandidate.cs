using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanDecisionCandidate(
    SichuanAction Action,
    double ExpectedNetScore,
    double WinGain,
    double GangGain,
    double ChaJiaoValue,
    double DealInLoss,
    double OpponentFutureLoss,
    double RouteContinuationValue,
    double UncertaintyPenalty,
    IReadOnlyList<string> ReasonCodes,
	bool IsAdmissible = true)
{
    public bool QuickReadyTiePreferred { get; init; }
    public double ContinuationDiscardRisk { get; init; }
    // Null for non-ready routes: their future hand development is not solved
    // by the fixed-wait race. Do not relabel a readiness heuristic as win odds.
    public double? ModeledOwnWinProbability { get; init; }
    public double? ModeledSelfDrawProbability { get; init; }
    public SichuanReadyPrice? ReadyPrice { get; init; }
}
