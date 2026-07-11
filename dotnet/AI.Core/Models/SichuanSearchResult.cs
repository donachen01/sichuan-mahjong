namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanSearchResult
{
    public bool Used { get; init; }
    public bool TimedOut { get; init; }
    public int Simulations { get; init; }
    public int Depth { get; init; }
    public int TopK { get; init; }
    public int BestTileType { get; init; } = -1;
    public IReadOnlyDictionary<int, double> CandidateBonuses { get; init; } = new Dictionary<int, double>();
}
