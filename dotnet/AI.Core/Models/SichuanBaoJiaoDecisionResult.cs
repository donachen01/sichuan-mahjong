using System.Collections.ObjectModel;

namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanBaoJiaoDecisionResult
{
    public bool Declare { get; init; }
    public IReadOnlyList<string> SelectedBaoGangKeys { get; init; } = Array.Empty<string>();
    public int Score { get; init; }
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
    public IReadOnlyDictionary<string, int> CandidateScores { get; init; } = new ReadOnlyDictionary<string, int>(new Dictionary<string, int>());
}
