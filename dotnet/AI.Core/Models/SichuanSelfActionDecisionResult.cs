using System.Collections.ObjectModel;

namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanSelfActionDecisionResult
{
    public SichuanAction Action { get; set; } = new(SichuanActionType.Pass, -1, 0, "");
    public string GangSubtype { get; set; } = "";
    public int ShantenAfter { get; set; } = 8;
    public int LiveUkeireAfter { get; set; }
    public IReadOnlyList<string> Reasons { get; set; } = Array.Empty<string>();
    public IReadOnlyDictionary<string, int> ActionScores { get; set; } = new ReadOnlyDictionary<string, int>(new Dictionary<string, int>());
}
