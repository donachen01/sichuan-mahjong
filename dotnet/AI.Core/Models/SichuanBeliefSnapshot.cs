namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanBeliefSnapshot
{
    public int[] Unknown18 { get; set; } = new int[27];
    public Dictionary<int, double> SeatPressure { get; } = new();
    public Dictionary<int, double> SeatReadyPosterior { get; } = new();
    public Dictionary<int, Dictionary<int, double>> SeatTileDanger { get; } = new();
    public Dictionary<int, Dictionary<int, double>> SeatTileHoldProbability { get; } = new();
    public Dictionary<int, Dictionary<int, double>> SeatTileWaitProbability { get; } = new();
    public Dictionary<int, Dictionary<int, double>> SeatTileNoHuEvidence { get; } = new();
    public Dictionary<int, Dictionary<int, double>> SeatSuitDemand { get; } = new();
    public Dictionary<int, HashSet<int>> SeatExactSafeTiles { get; } = new();
    public Dictionary<int, HashSet<int>> SeatAbandonedSuits { get; } = new();
    public Dictionary<int, double> SeatThreatScore { get; } = new();
    public Dictionary<int, double> TileWallPosterior { get; } = new();
    public Dictionary<string, double> PublicReadFeatures { get; } = new();
}
