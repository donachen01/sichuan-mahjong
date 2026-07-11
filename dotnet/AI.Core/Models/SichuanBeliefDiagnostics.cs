namespace SichuanMahjong.AI.Core.Models;

public sealed record SichuanBeliefDiagnostics(
    long CallCount,
    long CacheHits,
    long CacheMisses,
    long BuildCount,
    long TotalBuildMs,
    int CacheSize);
