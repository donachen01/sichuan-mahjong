namespace SichuanMahjong.AI.Core.Benchmark;

public sealed class SichuanBenchmarkStats
{
    public int RoundCount { get; private set; }
    public int TotalDecisionCount { get; private set; }
    public int TotalTurnCacheHits { get; private set; }
    public int TotalTurnCacheMisses { get; private set; }
    public long TotalTurnMs { get; private set; }
    public long PeakTurnMs { get; private set; }
    public int TimeoutFallbackCount { get; private set; }

    public void RecordRound() => RoundCount++;

    public void RecordTurn(long elapsedMs, bool cacheHit, bool timeoutFallback)
    {
        TotalDecisionCount++;
        TotalTurnMs += Math.Max(0, elapsedMs);
        PeakTurnMs = Math.Max(PeakTurnMs, elapsedMs);
        if (cacheHit) TotalTurnCacheHits++;
        else TotalTurnCacheMisses++;
        if (timeoutFallback) TimeoutFallbackCount++;
    }

    public BenchmarkSnapshot Snapshot() => new()
    {
        RoundCount = RoundCount,
        TotalDecisionCount = TotalDecisionCount,
        TotalTurnCacheHits = TotalTurnCacheHits,
        TotalTurnCacheMisses = TotalTurnCacheMisses,
        AverageTurnMs = TotalDecisionCount == 0 ? 0 : (double)TotalTurnMs / TotalDecisionCount,
        PeakTurnMs = PeakTurnMs,
        TimeoutFallbackCount = TimeoutFallbackCount
    };
}

public sealed class BenchmarkSnapshot
{
    public int RoundCount { get; init; }
    public int TotalDecisionCount { get; init; }
    public int TotalTurnCacheHits { get; init; }
    public int TotalTurnCacheMisses { get; init; }
    public double AverageTurnMs { get; init; }
    public long PeakTurnMs { get; init; }
    public int TimeoutFallbackCount { get; init; }
}
