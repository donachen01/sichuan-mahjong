using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>One eligibility contract for plans, root actions and simulated actions.
/// Eligibility is not proof of profitability. Numerical estimates retain their
/// model labels; heuristic scores must never be presented as settlement EV.</summary>
public sealed record SichuanStrategyAssessment(string Version, string Objective,
    bool AllowsRonRefusal, string Goal, string[] Reasons,
    SichuanDevelopmentPlan Development, SichuanDistinctDingQueHuAssessment Discipline);

public static class SichuanStrategyContract
{
    public const string Version = "strategy-contract-v29-flying-gang-route";
    public const string Objective = "own_expected_terminal_net_with_rule_costs";

    public static SichuanStrategyAssessment Assess(SichuanStateView state)
    {
        var discipline = new SichuanDistinctDingQueHuPolicy().Evaluate(state);
        var development = new SichuanDevelopmentPolicy().Evaluate(state);
        var allowed = development.AllowsRefusal && (!discipline.Applies || discipline.AllowsRefusal);
        return new(Version, Objective, allowed, allowed ? development.Goal : "cash_out",
            discipline.Reasons.Concat(development.Reasons)
                .Concat(SichuanDevelopmentPolicy.Melds(state,state.SeatIndex).Any(m=>m.Type==Domain.SichuanMeldType.Peng)
                    ? new[]{"EXPOSED_TRIPLET_NO_GREED"} : Array.Empty<string>()).Append(allowed
                ? "REFUSAL_ELIGIBLE_REQUIRES_VALUE_EVIDENCE" : "SHARED_REFUSAL_EXIT").Distinct().ToArray(),
            development, discipline);
    }

    // The same hard exits and local evidence apply to live and research actions.
    public static bool CanRefuse(SichuanStrategyAssessment assessment, SichuanWinType type)
        => type == SichuanWinType.Discard && assessment.AllowsRonRefusal;

    public static int Score(double value)
        => (int)Math.Round(Math.Clamp(value, -1000000, 1000000) * 1000);
}
