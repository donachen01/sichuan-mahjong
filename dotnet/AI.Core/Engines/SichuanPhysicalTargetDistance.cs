using System.Numerics;

namespace SichuanMahjong.AI.Core.Engines;

// Exact winning-target overlap for four-copy hands. A quad cannot be both
// a head and a pair waiting to become a triplet: that needs a fifth copy.
internal static class SichuanPhysicalTargetDistance
{
    private static readonly int[] Powers = { 1, 5, 25, 125, 625, 3125, 15625, 78125, 390625 };
    private static readonly ulong[][] Targets = BuildTargets();
    private static readonly (int A,int B,int C)[][] Combinations =
        Enumerable.Range(0,5).Select(BuildCombinations).ToArray();
    [ThreadStatic] private static Dictionary<int, int[]>? _profiles;

    internal static int Best(int[] hand, int exposed)
    {
        var keys=new int[3];
        for(int suit=0;suit<3;suit++)for(int rank=0;rank<9;rank++)
            keys[suit]+=hand[suit*9+rank]*Powers[rank];
        return BestEncoded(hand,exposed,keys[0],keys[1],keys[2]);
    }

    internal static int BestEncoded(int[] hand,int exposed,int suit0,int suit1,int suit2)
    {
        var cache = _profiles ??= new();
        if (cache.Count > 16384) cache.Clear();
        var profiles = new int[3][];
        for (var suit = 0; suit < 3; suit++)
        {
            var key = suit==0?suit0:suit==1?suit1:suit2;
            if (!cache.TryGetValue(key, out var profile))
            {
                // Four unary bits per rank: popcount(H & T) is exactly
                // sum(min(hand[rank], target[rank])). Targets still enforce
                // four-copy legality; no target or outcome is pruned here.
                ulong held=0;
                for(var rank=0;rank<9;rank++)
                    held |= ((1UL << hand[suit*9+rank])-1) << (rank*4);
                profile = new int[10];
                for (var index = 0; index < 10; index++)
                foreach (var target in Targets[index])
                {
                    var overlap = BitOperations.PopCount(held & target);
                    profile[index] = Math.Max(profile[index], overlap);
                }
                cache.Add(key, profile);
            }
            profiles[suit] = profile;
        }
        var overlapBest = 0;
        foreach(var (a,b,c) in exposed is >=0 and <=4 ? Combinations[exposed] : BuildCombinations(exposed))
            overlapBest = Math.Max(overlapBest, profiles[0][a] + profiles[1][b] + profiles[2][c]);
        return 13 - 3 * exposed - overlapBest;
    }

    private static (int A,int B,int C)[] BuildCombinations(int exposed)
        => (from a in Enumerable.Range(0,10)
            from b in Enumerable.Range(0,10)
            from c in Enumerable.Range(0,10)
            where a/2+b/2+c/2==4-exposed && a%2+b%2+c%2==1
            select (a,b,c)).ToArray();

    private static ulong[][] BuildTargets()
    {
        var groups = Enumerable.Range(0, 9).Select(t => new[] { t, t, t })
            .Concat(Enumerable.Range(0, 7).Select(t => new[] { t, t + 1, t + 2 })).ToArray();
        var result = new ulong[10][];
        for (var melds = 0; melds <= 4; melds++)
        for (var pair = 0; pair <= 1; pair++)
        {
            var unique = new HashSet<int>();
            var targets = new List<ulong>();
            var counts = new int[9];
            void Add()
            {
                if (counts.Any(n => n > 4)) return;
                var key = 0;
                for (var r = 0; r < 9; r++) key += counts[r] * Powers[r];
                if (unique.Add(key))
                {
                    ulong target=0;
                    for(var r=0;r<9;r++)target |= ((1UL<<counts[r])-1) << (r*4);
                    targets.Add(target);
                }
            }
            void Visit(int remaining, int first)
            {
                if (remaining == 0)
                {
                    if (pair == 0) Add();
                    else for (var r = 0; r < 9; r++) { counts[r] += 2; Add(); counts[r] -= 2; }
                    return;
                }
                for (var g = first; g < groups.Length; g++)
                {
                    foreach (var t in groups[g]) counts[t]++;
                    if (counts.All(n => n <= 4)) Visit(remaining - 1, g);
                    foreach (var t in groups[g]) counts[t]--;
                }
            }
            Visit(melds, 0);
            result[melds * 2 + pair] = targets.ToArray();
        }
        return result;
    }
}
