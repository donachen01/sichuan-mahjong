using System.Collections.ObjectModel;

namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanReactionDecisionResult
{
    public SichuanAction Action { get; set; } = new(SichuanActionType.Pass, -1, 0, "");
    public int ShantenAfter { get; set; } = 8;
    public int UkeireAfter { get; set; }
    public int LiveUkeireAfter { get; set; }
    public int CurrentShanten { get; set; } = 8;
    public int CurrentLiveUkeire { get; set; }
    public int ThreatLevel { get; set; }
    public int RoundStage { get; set; }
    public double MaxReadyPosterior { get; set; }
    public IReadOnlyList<string> Reasons { get; set; } = Array.Empty<string>();
    public IReadOnlyList<string> PosteriorSummary { get; set; } = Array.Empty<string>();
    public IReadOnlyList<string> FutureSummary { get; set; } = Array.Empty<string>();
    public double SearchBonus { get; set; }
    public int SearchSimulations { get; set; }
    public bool SearchUsed { get; set; }
    public IReadOnlyDictionary<string, int> ActionScores { get; set; } = new ReadOnlyDictionary<string, int>(new Dictionary<string, int>());
}
