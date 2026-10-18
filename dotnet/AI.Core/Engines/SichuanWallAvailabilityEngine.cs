using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;

namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanWallAvailability(
    double[] ExpectedCounts18,
    int[] RepresentativeCounts18,
    int WallCount)
{
    public int[] KnownWallCounts18 { get; init; } = new int[27];

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
        return BuildFromPublicConstraints(state, belief, capacities, target);
    }

    /// <summary>
    /// Constrain the existing heuristic wall model after this player's
    /// hypothetical replacement draw. Unseen copies and the wall shrink by
    /// one; the other players' public waiting-hand exclusions remain valid.
    /// This enforces physical bounds, not an exact conditional posterior.
    /// </summary>
    public SichuanWallAvailability AfterHypotheticalOwnDraw(
        SichuanStateView state, SichuanBeliefSnapshot belief, int tileType)
    {
        if (tileType is < 0 or > 26 || state.WallCount <= 0 || state.Remaining18[tileType] <= 0)
            throw new ArgumentException("Replacement draw is outside the public physical supply.", nameof(tileType));
        var capacities = Enumerable.Range(0, 27)
            .Select(tile => Math.Clamp(state.Remaining18[tile], 0, 4)).ToArray();
        capacities[tileType]--;
        var source = Build(state, belief);
        var target = Math.Clamp(state.WallCount - 1, 0, capacities.Sum());
        var known = (int[])source.KnownWallCounts18.Clone();
        if (known[tileType] > 0) known[tileType]--;
        var legacyWeights = (double[])source.ExpectedCounts18.Clone();
        legacyWeights[tileType] = Math.Max(0, legacyWeights[tileType] - 1);
        // Reserve integer lower bounds before reallocating the uncertain
        // surplus. Global scaling diluted guaranteed copies. Relative legacy
        // weights are retained wherever those physical constraints allow it.
        var residual = capacities.Select((n, t) => n - known[t]).ToArray();
        var weights = legacyWeights.Select((n, t) => Math.Max(0, n - known[t])).ToArray();
        var expected = AllocateExpectedCounts(residual, weights, target - known.Sum());
        for (int t = 0; t < 27; t++) expected[t] += known[t];
        return new SichuanWallAvailability(expected,
            AllocateRepresentativeCounts(capacities, expected, target), target)
        { KnownWallCounts18 = known };
    }

    private static SichuanWallAvailability BuildFromPublicConstraints(
        SichuanStateView state, SichuanBeliefSnapshot belief, int[] capacities, int target)
    {
        if (target == 0)
            return new SichuanWallAvailability(new double[27], new int[27], 0);

        var weights = Enumerable.Range(0, 27)
            .Select(tile => capacities[tile] * ResolveWallShare(belief, tile))
            .ToArray();
        if (weights.Sum() <= 0.000001)
            weights = capacities.Select(value => (double)value).ToArray();

        var known = ResolveKnownWallCounts(state,capacities,target);
        var residualCapacities=capacities.Select((n,t)=>n-known[t]).ToArray();
        var residualWeights=weights.Select((w,t)=>known[t]>0?0:w).ToArray();
        var expected = AllocateExpectedCounts(residualCapacities, residualWeights, target-known.Sum());
        for(int tile=0;tile<27;tile++)expected[tile]+=known[tile];
        var representative = AllocateRepresentativeCounts(capacities, expected, target);
        return new SichuanWallAvailability(expected, representative, target){KnownWallCounts18=known};
    }

    public int[] SampleWallOrder(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int seed,
        int firstSuit = 0)
    {
        if (firstSuit is < 0 or > 2) throw new ArgumentOutOfRangeException(nameof(firstSuit));
        var capacities = Enumerable.Range(0, 27)
            .Select(tile => Math.Clamp(state.Remaining18[tile], 0, 4))
            .ToArray();
        var target = Math.Clamp(state.WallCount, 0, capacities.Sum());
        if (target == 0) return Array.Empty<int>();

        var known=ResolveKnownWallCounts(state,capacities,target);
        var residual=capacities.Select((n,t)=>n-known[t]).ToArray();
        var random = new Random(seed);
        var order = new int[target];
        for (var draw = 0; draw < target; draw++)
        {
            var knownRemaining=known.Sum();
            var drawKnown=knownRemaining>0 && random.Next(target-draw)<knownRemaining;
            var drawPool=drawKnown?known:residual;
            var totalWeight = 0.0;
            for (var tile = 0; tile < 27; tile++)
                totalWeight += drawPool[tile] * ResolveWallShare(belief, tile);

            var selected = drawKnown ? SampleByCapacity(drawPool,random,firstSuit)
                : totalWeight > 0.000001
                    ? SampleWeightedTile(drawPool, belief, random, totalWeight, firstSuit)
                    : SampleByCapacity(drawPool, random, firstSuit);
            if (selected < 0)
                return order.Take(draw).ToArray();
            order[draw] = selected;
            capacities[selected]--;
            drawPool[selected]--;
        }
        return order;
    }

    private static int[] ResolveKnownWallCounts(SichuanStateView state,IReadOnlyList<int> capacities,int target)
    {
        var known=new int[27];
        for(int suit=0;suit<3;suit++)
        {
            var excluded=Enumerable.Range(0,4).Where(s=>s!=state.SeatIndex && state.HandCounts[s]>0)
                .All(s=>state.DingQueSuits[s]==suit && (state.HasHu[s] || SichuanOpponentTimeline.MustHaveClearedMissing(state,s)));
            if(excluded)for(int tile=suit*9;tile<suit*9+9;tile++)known[tile]=capacities[tile];
        }
        if(known.Sum()>target)throw new InvalidOperationException("public_known_wall_exceeds_wall_size");
        return known;
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
        double totalWeight,
        int firstSuit)
    {
        var roll = random.NextDouble() * totalWeight;
        for (var index = 0; index < 27; index++)
        {
            var tile = ((firstSuit + index / 9) % 3) * 9 + index % 9;
            var weight = capacities[tile] * ResolveWallShare(belief, tile);
            if (weight <= 0) continue;
            if (roll < weight) return tile;
            roll -= weight;
        }
        return Enumerable.Range(0, 27)
            .Select(index => ((firstSuit + index / 9) % 3) * 9 + index % 9)
            .FirstOrDefault(tile => capacities[tile] > 0, -1);
    }

    private static int SampleByCapacity(IReadOnlyList<int> capacities, Random random, int firstSuit)
    {
        var total = capacities.Sum();
        if (total <= 0) return -1;
        var roll = random.Next(total);
        for (var index = 0; index < 27; index++)
        {
            var tile = ((firstSuit + index / 9) % 3) * 9 + index % 9;
            if (roll < capacities[tile]) return tile;
            roll -= capacities[tile];
        }
        return -1;
    }
}
