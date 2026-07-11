namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanBeliefSummary
{
    public IReadOnlyList<SichuanPosteriorSeatSummary> ReadyPosteriors { get; init; } = Array.Empty<SichuanPosteriorSeatSummary>();
    public SichuanPosteriorHoldSummary HoldSummary { get; init; } = new();
    public SichuanPosteriorWallSummary WallSummary { get; init; } = new();
    public SichuanPosteriorWaitSummary WaitSummary { get; init; } = new();
    public SichuanUnknownTileSummary UnknownSummary { get; init; } = new();
}

public sealed class SichuanPosteriorSeatSummary
{
    public int Seat { get; init; }
    public double ReadyPosterior { get; init; }
    public double ThreatScore { get; init; }
    public bool IsCalled { get; init; }
}

public sealed class SichuanPosteriorHoldSummary
{
    public int TileType { get; init; } = -1;
    public IReadOnlyList<SichuanPosteriorSeatHoldSummary> TopHolders { get; init; } = Array.Empty<SichuanPosteriorSeatHoldSummary>();
}

public sealed class SichuanPosteriorSeatHoldSummary
{
    public int Seat { get; init; }
    public double HoldPosterior { get; init; }
    public double TileDanger { get; init; }
    public double SuitDemand { get; init; }
}

public sealed class SichuanPosteriorWallSummary
{
    public double AveragePosterior { get; init; }
    public IReadOnlyList<SichuanPosteriorTileSummary> TopTiles { get; init; } = Array.Empty<SichuanPosteriorTileSummary>();
}

public sealed class SichuanPosteriorTileSummary
{
    public int TileType { get; init; }
    public double Posterior { get; init; }
}

public sealed class SichuanPosteriorWaitSummary
{
    public int TileType { get; init; } = -1;
    public IReadOnlyList<SichuanPosteriorSeatWaitSummary> TopWaiters { get; init; } = Array.Empty<SichuanPosteriorSeatWaitSummary>();
}

public sealed class SichuanPosteriorSeatWaitSummary
{
    public int Seat { get; init; }
    public double WaitPosterior { get; init; }
    public double NoHuEvidence { get; init; }
    public double ReadyPosterior { get; init; }
}

public sealed class SichuanUnknownTileSummary
{
    public int TotalUnknown { get; init; }
    public IReadOnlyList<SichuanUnknownTileCount> TopTiles { get; init; } = Array.Empty<SichuanUnknownTileCount>();
}

public sealed class SichuanUnknownTileCount
{
    public int TileType { get; init; }
    public int Count { get; init; }
}
