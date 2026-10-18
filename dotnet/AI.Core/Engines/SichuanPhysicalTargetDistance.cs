namespace SichuanMahjong.AI.Core.Engines;

// Exact winning-target overlap for four-copy hands. A quad cannot be both
// a head and a pair waiting to become a triplet: that needs a fifth copy.
internal static class SichuanPhysicalTargetDistance
{
    private static readonly int[] Powers = { 1, 5, 25, 125, 625, 3125, 15625, 78125, 390625 };
    private static readonly int[][][] Targets = BuildTargets();
    [ThreadStatic] private static Dictionary<int, int[]>? _profiles;

    internal static int Best(int[] hand, int exposed)
    {
        var cache = _profiles ??= new();
        if (cache.Count > 16384) cache.Clear();
        var profiles = new int[3][];
        for (var suit = 0; suit < 3; suit++)
        {
            var key = 0;
            for (var rank = 0; rank < 9; rank++) key += hand[suit * 9 + rank] * Powers[rank];
            if (!cache.TryGetValue(key, out var profile))
            {
                profile = new int[10];
                for (var index = 0; index < 10; index++)
                foreach (var target in Targets[index])
                {
                    var overlap = 0;
                    for (var rank = 0; rank < 9; rank++)
                        overlap += Math.Min(hand[suit * 9 + rank], target[rank]);
                    profile[index] = Math.Max(profile[index], overlap);
                }
                cache.Add(key, profile);
            }
            profiles[suit] = profile;
        }
        var overlapBest = 0;
        for (var a = 0; a < 10; a++)
        for (var b = 0; b < 10; b++)
        for (var c = 0; c < 10; c++)
            if (a / 2 + b / 2 + c / 2 == 4 - exposed && a % 2 + b % 2 + c % 2 == 1)
                overlapBest = Math.Max(overlapBest, profiles[0][a] + profiles[1][b] + profiles[2][c]);
        return 13 - 3 * exposed - overlapBest;
    }

    private static int[][][] BuildTargets()
    {
        var groups = Enumerable.Range(0, 9).Select(t => new[] { t, t, t })
            .Concat(Enumerable.Range(0, 7).Select(t => new[] { t, t + 1, t + 2 })).ToArray();
        var result = new int[10][][];
        for (var melds = 0; melds <= 4; melds++)
        for (var pair = 0; pair <= 1; pair++)
        {
            var unique = new HashSet<int>();
            var targets = new List<int[]>();
            var counts = new int[9];
            void Add()
            {
                if (counts.Any(n => n > 4)) return;
                var key = 0;
                for (var r = 0; r < 9; r++) key += counts[r] * Powers[r];
                if (unique.Add(key)) targets.Add((int[])counts.Clone());
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
