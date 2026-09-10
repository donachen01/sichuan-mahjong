namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanDecisionResult
{
    public SichuanAction Action { get; init; } = new(SichuanActionType.Pass);
    public int Shanten { get; init; }
    public int Ukeire { get; init; }
    public int LiveUkeire { get; init; }
    public double WinProbability { get; init; }
    public double DealInProbability { get; init; }
    public string GangSubtype { get; init; } = "";
    public bool SearchUsed { get; init; }
    public int SearchSimulations { get; init; }
    public SichuanRoutePlanResult RoutePlan { get; init; } = new();
    public SichuanRoundBrainSnapshot RoundBrain { get; init; } = new();
    public SichuanBeliefSummary BeliefSummary { get; init; } = new();
    public SichuanAiContext? AiContext { get; init; }
    public SichuanDecisionExplain Explain { get; init; } = new();
    public SichuanDecisionPerformanceReport Performance { get; init; } = new();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
    public IReadOnlyDictionary<int, int> CandidateScores { get; init; } = new Dictionary<int, int>();
    public IReadOnlyList<SichuanCandidateDetail> Candidates { get; init; } = Array.Empty<SichuanCandidateDetail>();
    public SichuanClassicPatternAnalysis? ClassicPattern { get; init; }
}
