using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanSelfDrawProbabilityEngine
{
    public double Estimate(
        SichuanStateView state,
        IReadOnlyList<int> improvingTiles,
        int waitCount,
        int liveUkeire,
        int shanten,
        int danger,
        SichuanBeliefSnapshot belief)
    {
        if (improvingTiles.Count == 0 || liveUkeire <= 0)
            return Math.Clamp(0.015 + Math.Max(0, waitCount) * 0.01 - danger * 0.0004, 0.005, 0.08);

        var effectiveWallHits = 0.0;
        var totalLive = 0;
        foreach (var tileType in improvingTiles.Distinct())
        {
            if (tileType is < 0 or >= 27) continue;
            var liveCount = Math.Max(0, state.Remaining18[tileType]);
            if (liveCount <= 0) continue;
            var wallPosterior = belief.TileWallPosterior.GetValueOrDefault(tileType, 0.0);
            effectiveWallHits += liveCount * Math.Clamp(wallPosterior, 0.01, 0.98);
            totalLive += liveCount;
        }

        if (effectiveWallHits <= 0.001)
            return Math.Clamp(0.01 + waitCount * 0.008 - danger * 0.0004, 0.005, 0.06);

        var unknownTiles = Math.Max(1, belief.Unknown18.Sum());
        var availableWall = Math.Max(1.0, state.WallCount);
        var drawChances = EstimateSelfDrawChances(state, shanten);
        var perDrawHit = Math.Clamp(effectiveWallHits / Math.Max(availableWall, unknownTiles * 0.36), 0.002, 0.72);
        var atLeastOne = 1.0 - Math.Pow(1.0 - perDrawHit, drawChances);
        var widthBoost = Math.Clamp(0.90 + Math.Min(5, waitCount) * 0.035, 0.90, 1.10);
        var liveBoost = Math.Clamp(0.92 + Math.Min(12, totalLive) * 0.012, 0.92, 1.08);
        var dangerPenalty = Math.Clamp(1.0 - danger * 0.0018, 0.82, 1.0);
        var shantenPenalty = shanten <= 0 ? 1.0 : shanten == 1 ? 0.52 : 0.22;

        return Math.Clamp(atLeastOne * widthBoost * liveBoost * dangerPenalty * shantenPenalty, 0.005, 0.92);
    }

    private static double EstimateSelfDrawChances(SichuanStateView state, int shanten)
    {
        var activeSeats = 0;
        for (var seat = 0; seat < state.HasHu.Length; seat++)
        {
            if (!state.HasHu[seat])
                activeSeats++;
        }
        activeSeats = Math.Clamp(activeSeats, 1, 4);
        var baseChances = state.WallCount / (double)activeSeats;
        if (shanten == 1)
            baseChances *= 0.72;
        else if (shanten >= 2)
            baseChances *= 0.44;
        return Math.Clamp(baseChances, 0.4, 8.0);
    }
}
