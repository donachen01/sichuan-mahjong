using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanPosteriorNormalizer
{
    public SichuanPosteriorNormalizationResult Normalize(
        SichuanStateView state,
        IReadOnlyList<int> activeSeats,
        IReadOnlyDictionary<int, Dictionary<int, double>> seatHoldWeights)
    {
        var wallProbability = new double[27];
        var wallExpectedCount = new double[27];
        var seatHoldProbability = new Dictionary<int, double[]>();
        var seatExpectedCount = new Dictionary<int, double[]>();
        foreach (var seat in activeSeats)
        {
            seatHoldProbability[seat] = new double[27];
            seatExpectedCount[seat] = new double[27];
        }

        var maxOverflow = 0.0;
        for (var tileType = 0; tileType < 27; tileType++)
        {
            var remainingCount = Math.Clamp(state.Remaining18[tileType], 0, 4);
            if (remainingCount <= 0)
            {
                wallProbability[tileType] = 0.0;
                wallExpectedCount[tileType] = 0.0;
                foreach (var seat in activeSeats)
                {
                    seatHoldProbability[seat][tileType] = 0.0;
                    seatExpectedCount[seat][tileType] = 0.0;
                }
                continue;
            }

            var wallWeight = BuildWallWeight(state, tileType, remainingCount);
            var totalWeight = wallWeight;
            foreach (var seat in activeSeats)
            {
                var weight = ResolveSeatWeight(seatHoldWeights, seat, tileType);
                totalWeight += weight;
            }

            if (totalWeight <= 0.000001)
                totalWeight = 1.0;

            var wallShare = wallWeight / totalWeight;
            wallProbability[tileType] = Math.Clamp(wallShare, 0.0, 1.0);
            wallExpectedCount[tileType] = wallProbability[tileType] * remainingCount;

            var expectedSum = wallExpectedCount[tileType];
            foreach (var seat in activeSeats)
            {
                var seatShare = ResolveSeatWeight(seatHoldWeights, seat, tileType) / totalWeight;
                seatHoldProbability[seat][tileType] = Math.Clamp(seatShare, 0.0, 1.0);
                seatExpectedCount[seat][tileType] = seatHoldProbability[seat][tileType] * remainingCount;
                expectedSum += seatExpectedCount[seat][tileType];
            }
            maxOverflow = Math.Max(maxOverflow, Math.Max(0.0, expectedSum - remainingCount));
        }

        return new SichuanPosteriorNormalizationResult
        {
            WallProbability18 = wallProbability,
            WallExpectedCount18 = wallExpectedCount,
            SeatHoldProbability18 = seatHoldProbability,
            SeatExpectedCount18 = seatExpectedCount,
            MaxConservationOverflow = maxOverflow
        };
    }

    private static double ResolveSeatWeight(
        IReadOnlyDictionary<int, Dictionary<int, double>> seatHoldWeights,
        int seat,
        int tileType)
    {
        if (!seatHoldWeights.TryGetValue(seat, out var weights))
            return 0.01;
        return Math.Clamp(weights.GetValueOrDefault(tileType, 0.01), 0.001, 12.0);
    }

    private static double BuildWallWeight(SichuanStateView state, int tileType, int remainingCount)
    {
        if (state.WallCount <= 0)
            return 0.0;
        var countWeight = Math.Max(0.001, remainingCount);
        var wallDepth = Math.Clamp(state.WallCount / 19.0, 0.0, 1.0);
        var visibleScarcity = Math.Clamp(1.0 - state.Visible18[tileType] / 4.0, 0.0, 1.0);
        return countWeight * (0.74 + wallDepth * 0.18 + visibleScarcity * 0.08);
    }
}
