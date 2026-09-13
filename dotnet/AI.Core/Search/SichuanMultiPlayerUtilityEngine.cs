namespace SichuanMahjong.AI.Core.Search;

public sealed record SichuanMultiPlayerUtilityInput(
    double OwnWinGain,
    double GangGain,
    double ChaJiaoValue,
    double DealInLoss,
    double DominantOpponentFutureGain,
    double OtherOpponentFutureGain,
    double ExitOrderValue,
    double UncertaintyPenalty,
    int ActivePlayers,
    double Confidence);

public sealed record SichuanMultiPlayerUtilityResult(
    double NetUtility,
    double OwnPositiveValue,
    double ThreatCost,
    double SurvivalValue,
    double ConfidencePenalty,
    IReadOnlyList<string> Reasons);

public sealed class SichuanMultiPlayerUtilityEngine
{
    public SichuanMultiPlayerUtilityResult Evaluate(SichuanMultiPlayerUtilityInput input)
    {
        var activePlayers = Math.Clamp(input.ActivePlayers, 1, 4);
        var confidence = Math.Clamp(input.Confidence, 0, 1);
        var ownPositive = input.OwnWinGain + input.GangGain + input.ChaJiaoValue;
        var dominantWeight = 0.42 + Math.Max(0, activePlayers - 2) * 0.08;
        var otherWeight = 0.18 + Math.Max(0, activePlayers - 2) * 0.05;
        var threatCost = Math.Max(0, input.DealInLoss)
            + Math.Max(0, input.DominantOpponentFutureGain) * dominantWeight
            + Math.Max(0, input.OtherOpponentFutureGain) * otherWeight;
        var survivalValue = input.ExitOrderValue * (1.0 + Math.Max(0, 4 - activePlayers) * 0.12);
        var confidencePenalty = (1 - confidence) * (Math.Abs(ownPositive) + threatCost) * 0.35;
        var net = ownPositive + survivalValue - threatCost - Math.Max(0, input.UncertaintyPenalty) - confidencePenalty;
        var reasons = new[]
        {
            $"自己正收益 {ownPositive:F2}",
            $"最大威胁与其他玩家成本 {threatCost:F2}",
            $"退出顺序价值 {survivalValue:F2}",
            $"置信度惩罚 {confidencePenalty:F2}"
        };
        return new SichuanMultiPlayerUtilityResult(net, ownPositive, threatCost, survivalValue, confidencePenalty, reasons);
    }

    public bool CanStrategicallyDealIn(double ownLoss, double dominantOpponentFutureGain, double confidence, int activePlayers)
    {
        var result = Evaluate(new SichuanMultiPlayerUtilityInput(
            0, 0, 0, ownLoss, dominantOpponentFutureGain, 0,
            dominantOpponentFutureGain - ownLoss, 0, activePlayers, confidence));
        return activePlayers <= 3
            && ownLoss <= 2.0
            && dominantOpponentFutureGain >= ownLoss + 3.0
            && confidence >= 0.88
            && result.SurvivalValue > result.ThreatCost;
    }

    public bool CanPassHu(double immediateGain, double futureNetGain, double confidence, bool ruleAllowsPass)
	{
		// A fixed 1.5-point hurdle made a one-point Hu require a 150% premium,
		// while barely protecting a high-value Hu.  Scale the refusal premium
		// with the realized score and retain a small absolute safety margin.
		var refusalPremium = Math.Max(0.25, Math.Max(0, immediateGain) * 0.25);
		return ruleAllowsPass && confidence >= 0.82 && futureNetGain >= immediateGain + refusalPremium;
	}
}
