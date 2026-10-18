using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Agents;

// Concrete collection types keep persistence compatible with NativeAOT.
public sealed record AgentBrainMemory(int Revision, int Stage, string Primary, string Fallback,
    int TargetSuit, int Commitment, Dictionary<string, int> RouteWeights, int[] BrokenTriplets, string[] History);
public sealed record SichuanAgentCheckpoint(int SchemaVersion, string RulesVersion, string PolicyVersion,
    string RoundId, int Seat, long ViewVersion, string ViewFingerprint, AgentBrainMemory Brain,
    SichuanDingQueDecisionResult? OpeningDecision, string[] ConfirmedHistory)
{
    public AgentDecisionTrace[] Decisions { get; init; } = Array.Empty<AgentDecisionTrace>();
}
