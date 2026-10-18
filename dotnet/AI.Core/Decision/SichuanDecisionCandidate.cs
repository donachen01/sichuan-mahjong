using SichuanMahjong.AI.Core.Models;

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
}
