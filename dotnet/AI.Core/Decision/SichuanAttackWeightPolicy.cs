using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanAttackWeightAssessment(double ExtraDefenseCost,
    double AppliedDefenseWeight, int PublicThreatLevel, IReadOnlyList<string> Reasons);

/// <summary>
/// Attack-first treatment of the additional legacy defensive adjustment.
/// It does not discount the shared action value's deal-in, opponent-payment,
/// gang liability or settlement costs. Existing strong-risk boundaries remain.
/// </summary>
public sealed class SichuanAttackWeightPolicy
{
    public const double LegacyExtraDefenseWeight = 0.35;

    public static double SelectExtraDefenseWeight(int publicThreatLevel,
        int tileDanger, double maxReadyPosterior)
        => publicThreatLevel > 0 || tileDanger >= 78 || maxReadyPosterior >= 0.72
            ? LegacyExtraDefenseWeight : 0.0;

    public SichuanAttackWeightAssessment Evaluate(SichuanStateView state,
        int tileDanger, double maxReadyPosterior, double boundedLegacyCost)
    {
        if (state.InformationMode != "public")
            return new(Math.Clamp(boundedLegacyCost, 0, 2) * LegacyExtraDefenseWeight,
                LegacyExtraDefenseWeight, 0, new[] { "EXTRA_DEFENSE_ORACLE_POLICY_UNCHANGED" });
        var evidence = new List<string>();
        var level = SichuanDistinctDingQueHuPolicy.AssessDanger(state, evidence);
        var weight = SelectExtraDefenseWeight(level, tileDanger, maxReadyPosterior);
        var cost = Math.Clamp(boundedLegacyCost, 0, 2) * weight;
        var reasons = new List<string>
        {
            weight == 0 ? "ATTACK_FIRST_WEAK_EVIDENCE_NO_EXTRA_DEFENSE_COST"
                : "ATTACK_FIRST_STRONG_SIGNAL_RETAINS_EXTRA_DEFENSE_COST",
            $"ATTACK_EXTRA_DEFENSE_COST_{cost:F4}",
            "主评分中的放炮、后续支付及四川结算成本仍保留；此项只控制额外防守修正"
        };
        if (level > 0) reasons.AddRange(evidence);
        return new(cost, weight, level, reasons);
    }
}
