namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanRoutePlanResult
{
    public string PrimaryRoute { get; init; } = "平胡";
    public IReadOnlyList<string> SecondaryRoutes { get; init; } = Array.Empty<string>();
    public IReadOnlyDictionary<string, int> RouteWeights { get; init; } = new Dictionary<string, int>();
    public IReadOnlyList<string> Constraints { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
    public int TargetSuit { get; init; } = -1;

    public bool ForbidsMelds => Constraints.Contains("forbid_melds");
    public bool ForbidsGangs => Constraints.Contains("forbid_gangs");
    public bool PreservesPairs => Constraints.Contains("preserve_pairs");
}
