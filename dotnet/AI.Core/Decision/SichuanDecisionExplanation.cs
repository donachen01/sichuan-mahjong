namespace SichuanMahjong.AI.Core.Decision;

using SichuanMahjong.AI.Core.Models;

public sealed record SichuanDecisionExplanation(
	SichuanActionType SelectedAction,
    string Summary,
    IReadOnlyList<string> Reasons,
    IReadOnlyList<SichuanDecisionCandidate> Candidates)
{
    // Retain the concrete Peng discard/claim analysis when refusing an offered
    // Hu. This is internal execution metadata, not a second decision request.
    internal SichuanReactionDecisionResult? LocalReaction { get; init; }
}
