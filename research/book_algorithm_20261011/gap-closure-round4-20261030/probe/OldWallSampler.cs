using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;
namespace Round4;
internal static class OldWallSampler
{
    public static int[] SampleWallOrder(
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
