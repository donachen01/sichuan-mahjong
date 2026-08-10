using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanWallAvailability(
    double[] ExpectedCounts18,
    int[] RepresentativeCounts18,
    int WallCount)
{
    public double SumExpected(IEnumerable<int> tileTypes)
        => tileTypes
            .Where(tile => tile is >= 0 and < 27)
            .Distinct()
            .Sum(tile => ExpectedCounts18[tile]);
}

/// <summary>
/// Converts public-information tile posteriors into a wall-constrained view.
/// Raw remaining counts include every hidden hand, so they must never be used
/// as drawable counts without enforcing the exact number of tiles in the wall.
/// </summary>
public sealed class SichuanWallAvailabilityEngine
{
    public SichuanWallAvailability Build(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var capacities = Enumerable.Range(0, 27)
            .Select(tile => Math.Clamp(state.Remaining18[tile], 0, 4))
            .ToArray();
        var target = Math.Clamp(state.WallCount, 0, capacities.Sum());
        if (target == 0)
            return new SichuanWallAvailability(new double[27], new int[27], 0);

        var weights = Enumerable.Range(0, 27)
            .Select(tile => capacities[tile] * ResolveWallShare(belief, tile))
            .ToArray();
        if (weights.Sum() <= 0.000001)
            weights = capacities.Select(value => (double)value).ToArray();

        var expected = AllocateExpectedCounts(capacities, weights, target);
        var representative = AllocateRepresentativeCounts(capacities, expected, target);
        return new SichuanWallAvailability(expected, representative, target);
    }

    public int[] SampleWallOrder(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int seed)
    {
        var capacities = Enumerable.Range(0, 27)
            .Select(tile => Math.Clamp(state.Remaining18[tile], 0, 4))
            .ToArray();
        var target = Math.Clamp(state.WallCount, 0, capacities.Sum());
        if (target == 0) return Array.Empty<int>();

        var random = new Random(seed);
        var order = new int[target];
        for (var draw = 0; draw < target; draw++)
        {
            var totalWeight = 0.0;
            for (var tile = 0; tile < 27; tile++)
                totalWeight += capacities[tile] * ResolveWallShare(belief, tile);

            var selected = totalWeight > 0.000001
                ? SampleWeightedTile(capacities, belief, random, totalWeight)
                : SampleByCapacity(capacities, random);
            if (selected < 0)
                return order.Take(draw).ToArray();
            order[draw] = selected;
            capacities[selected]--;
        }
        return order;
    }

    private static double ResolveWallShare(SichuanBeliefSnapshot belief, int tileType)
        => Math.Clamp(belief.TileWallPosterior.GetValueOrDefault(tileType, 0.01), 0.0001, 1.0);

    private static double[] AllocateExpectedCounts(
        IReadOnlyList<int> capacities,
        IReadOnlyList<double> weights,
        int target)
    {
        var result = new double[27];
        var active = Enumerable.Range(0, 27).Where(tile => capacities[tile] > 0).ToHashSet();
        var remainingTarget = (double)target;
        while (active.Count > 0 && remainingTarget > 0.000001)
        {
            var totalWeight = active.Sum(tile => Math.Max(0.000001, weights[tile]));
            var capped = active
                .Where(tile => remainingTarget * Math.Max(0.000001, weights[tile]) / totalWeight >= capacities[tile] - 0.000001)
                .ToArray();
            if (capped.Length == 0)
            {
                foreach (var tile in active)
                    result[tile] = remainingTarget * Math.Max(0.000001, weights[tile]) / totalWeight;
                break;
            }

            foreach (var tile in capped)
            {
                result[tile] = capacities[tile];
                remainingTarget -= capacities[tile];
                active.Remove(tile);
            }
        }
        return result;
    }

    private static int[] AllocateRepresentativeCounts(
        IReadOnlyList<int> capacities,
        IReadOnlyList<double> expected,
        int target)
    {
        var result = expected
            .Select((value, tile) => Math.Min(capacities[tile], (int)Math.Floor(value)))
            .ToArray();
        var remaining = target - result.Sum();
        foreach (var tile in Enumerable.Range(0, 27)
                     .Where(tile => result[tile] < capacities[tile])
                     .OrderByDescending(tile => expected[tile] - Math.Floor(expected[tile]))
                     .ThenByDescending(tile => expected[tile])
                     .ThenBy(tile => tile))
        {
            if (remaining <= 0) break;
            result[tile]++;
            remaining--;
        }
        return result;
    }

    private static int SampleWeightedTile(
        IReadOnlyList<int> capacities,
        SichuanBeliefSnapshot belief,
        Random random,
        double totalWeight)
    {
        var roll = random.NextDouble() * totalWeight;
        for (var tile = 0; tile < 27; tile++)
        {
            var weight = capacities[tile] * ResolveWallShare(belief, tile);
            if (weight <= 0) continue;
            if (roll < weight) return tile;
            roll -= weight;
        }
        return Enumerable.Range(0, 27).FirstOrDefault(tile => capacities[tile] > 0, -1);
    }

    private static int SampleByCapacity(IReadOnlyList<int> capacities, Random random)
    {
        var total = capacities.Sum();
        if (total <= 0) return -1;
        var roll = random.Next(total);
        for (var tile = 0; tile < 27; tile++)
        {
            if (roll < capacities[tile]) return tile;
            roll -= capacities[tile];
        }
        return -1;
    }
}
