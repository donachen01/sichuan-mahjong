namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanRoundBrainSnapshot
{
    public int RoundIndex { get; init; }
    public int SeatIndex { get; init; }
    public int Revision { get; init; }
    public int Stage { get; init; }
    public string PrimaryRoute { get; init; } = "平胡";
    public string FallbackRoute { get; init; } = "平胡";
    public int Commitment { get; init; }
    public int TargetSuit { get; init; } = -1;
    public IReadOnlyDictionary<string, int> RouteWeights { get; init; } = new Dictionary<string, int>();
	public IReadOnlyDictionary<string, double> RouteProbabilities { get; init; } = new Dictionary<string, double>();
	public double RiskBudget { get; init; }
	public int MaxThreatSeat { get; init; } = -1;
	public double MaxThreatScore { get; init; }
	public long ObservationVersion { get; init; }
	public string RulesVersion { get; init; } = string.Empty;
    public IReadOnlySet<int> ProtectedTriplets { get; init; } = new HashSet<int>();
    public IReadOnlySet<int> ProtectedQuads { get; init; } = new HashSet<int>();
    public IReadOnlySet<int> BrokenTriplets { get; init; } = new HashSet<int>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
	public IReadOnlyList<string> DecisionHistory { get; init; } = Array.Empty<string>();

    public bool IsProtectedTriplet(int tileType) => ProtectedTriplets.Contains(tileType);
    public bool IsProtectedQuad(int tileType) => ProtectedQuads.Contains(tileType);
    public bool WasTripletBroken(int tileType) => BrokenTriplets.Contains(tileType);
}
