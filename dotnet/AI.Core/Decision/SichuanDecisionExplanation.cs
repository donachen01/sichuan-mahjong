namespace SichuanMahjong.AI.Core.Decision;

using SichuanMahjong.AI.Core.Models;

public sealed record SichuanDecisionExplanation(
	SichuanActionType SelectedAction,
    string Summary,
    IReadOnlyList<string> Reasons,
    IReadOnlyList<SichuanDecisionCandidate> Candidates);
