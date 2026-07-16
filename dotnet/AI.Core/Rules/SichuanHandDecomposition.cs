namespace SichuanMahjong.AI.Core.Rules;

public enum SichuanGroupType { Pair, Sequence, Triplet }
public sealed record SichuanHandGroup(SichuanGroupType Type, int TileType);
public sealed record SichuanHandDecomposition(IReadOnlyList<SichuanHandGroup> Groups, bool IsSevenPairs = false);

public sealed record SichuanWaitAnalysis(
    int TileType,
    int LiveCount,
    IReadOnlyList<SichuanHandDecomposition> Decompositions);

public sealed record SichuanScoredWaitAnalysis(
    SichuanWaitAnalysis Wait,
    IReadOnlyList<SichuanFanProjection> FanProjections,
    int MinimumFan,
    int MaximumFan,
    int MinimumSettlement,
    int MaximumSettlement);

public sealed record SichuanDiscardAnalysis(
    int DiscardTileType,
    int Shanten,
    IReadOnlyList<int> ImprovingTiles,
    int LiveUkeire,
    IReadOnlyList<SichuanWaitAnalysis> Waits,
    double WaitQuality = 0,
    int StructuralLoss = 0);
