using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Agents;

public sealed record AgentCandidateEvidence(string Action, int Tile, double SelectionScore,
    string ScoreUnit, double? ModeledNet, bool? Admissible, string[] Reasons);
public sealed record AgentDecisionTrace(string Id, long ViewVersion, long EventIndex, string Kind,
    string Action, int Tile, string Status, string StateFingerprint, string PolicyVersion,
    string PrimaryRoute, string FallbackRoute, string[] PlanEvidence, string[] Reasons,
    AgentCandidateEvidence[] Candidates, int[] OwnHand, int[] PublicScores,
    long? ExecutionEvent, long? OutcomeViewVersion, int? ObservedScoreDelta,
    string OutcomeMeaning)
{
    public string[] ReviewFlags { get; init; } = Array.Empty<string>();
    public long? LatestReviewVersion { get; init; }
    public int? ScoreDeltaSinceDecision { get; init; }
    public string LatestRoute { get; init; } = "";
    public int? LatestBestDistance { get; init; }
    public bool OwnWinObserved { get; init; }
    public string ReviewMeaning => "trajectory_association_not_causal_credit_or_empirical_policy_strength";
    public AgentDecisionTrace Copy() => this with {
        ReviewFlags = ReviewFlags.ToArray(), PlanEvidence = PlanEvidence.ToArray(), Reasons = Reasons.ToArray(), OwnHand = OwnHand.ToArray(),
        PublicScores = PublicScores.ToArray(), Candidates = Candidates.Select(c => c with { Reasons = c.Reasons.ToArray() }).ToArray()
    };
}

internal static class SichuanDecisionJournal
{
    public static (string[] Reasons, AgentCandidateEvidence[] Candidates) Explain(object result)
        => result switch
        {
            SichuanDecisionResult d => (d.Reasons.Concat(d.Arbitration.Select(a => $"ARBITRATION:{a.Module}:tile={a.ProposedTile}:priority={a.Priority}:accepted={a.Accepted}:previous={a.PreviousTile}:{a.Reason}")).ToArray(), d.Candidates.Select(c =>
                new AgentCandidateEvidence("Discard", c.TileType, c.Score, "discard_policy_score",
                    c.Reasons.Contains("ONLY_LEGAL_MISSING_SUIT_DISCARD") ? null : c.ExpectedNetScore, true, c.Reasons.Concat(c.RiskReasons).ToArray())).ToArray()),
            SichuanReactionDecisionResult r => (r.Reasons.ToArray(), r.ActionScores.Select(c =>
                new AgentCandidateEvidence(c.Key, r.Action.TileType, c.Value, "reaction_policy_score",
                    r.ValueCandidates.FirstOrDefault(v => string.Equals(v.Action.ActionType.ToString(),c.Key,StringComparison.OrdinalIgnoreCase))?.ExpectedNetScore,
                    r.ValueCandidates.FirstOrDefault(v => string.Equals(v.Action.ActionType.ToString(),c.Key,StringComparison.OrdinalIgnoreCase))?.IsAdmissible,
                    r.ValueCandidates.FirstOrDefault(v => string.Equals(v.Action.ActionType.ToString(),c.Key,StringComparison.OrdinalIgnoreCase))?.ReasonCodes.ToArray()
                        ?? (string.Equals(c.Key,r.Action.ActionType.ToString(),StringComparison.OrdinalIgnoreCase)?r.Reasons.ToArray():Array.Empty<string>()))).ToArray()),
            SichuanSelfActionDecisionResult s => (s.Reasons.ToArray(), s.ActionScores.Select(c =>
                new AgentCandidateEvidence(c.Key, c.Key.Contains(':') && int.TryParse(c.Key.Split(':')[1],out var tile) ? tile : -1,
                    c.Value, "self_action_policy_score", null, null, s.CandidateReasons.GetValueOrDefault(c.Key)?.ToArray() ?? Array.Empty<string>())).ToArray()),
            SichuanDingQueDecisionResult q => (q.Reasons.ToArray(), q.KScoreBySuit.Select(c =>
                new AgentCandidateEvidence(c.Key,-1,c.Value,"K_score_not_settlement",null,true,q.Reasons.ToArray())).ToArray()),
            _ => (new[] { "NO_STRUCTURED_EXPLANATION" }, Array.Empty<AgentCandidateEvidence>())
        };
}
