using System.Collections.ObjectModel;

namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanSelfActionDecisionResult
{
    internal double ContinuationDiscardRisk { get; init; }
    public SichuanDecisionCommand? Command { get; set; }
    internal bool OpponentWideBedDefenseAllowed { get; init; } = true;
    public IReadOnlyDictionary<string, string[]> CandidateReasons { get; set; } = new Dictionary<string, string[]>();
    public SichuanAction Action { get; set; } = new(SichuanActionType.Pass, -1, 0, "");
    public string GangSubtype { get; set; } = "";
    // Only a Pass may commit this immediate discard. Gang replacement draws
    // change the state and always require a fresh decision.
    public int ContinuationDiscardTile { get; set; } = -1;
    public int ShantenAfter { get; set; } = 8;
    public int LiveUkeireAfter { get; set; }
    public IReadOnlyList<string> Reasons { get; set; } = Array.Empty<string>();
    public IReadOnlyDictionary<string, int> ActionScores { get; set; } = new ReadOnlyDictionary<string, int>(new Dictionary<string, int>());
}
