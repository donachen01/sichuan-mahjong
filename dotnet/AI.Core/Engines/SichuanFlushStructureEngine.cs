namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanFlushStructure(
    int MinimumAdditionalTiles,
    int FeasiblePatterns,
    IReadOnlyList<int> UsefulDraws,
    IReadOnlyList<int> RequiredInEveryNearestPattern);

/// <summary>
/// Exact structural reachability against a public unseen-copy upper bound.
/// This is neither a wall posterior nor a completion probability.
/// </summary>
public sealed class SichuanFlushStructureEngine
{
    // Private immutable patterns; Lazy safely shares the one-time enumeration.
    private static readonly Lazy<byte[][]>[] Patterns = Enumerable.Range(0, 5)
        .Select(melds => new Lazy<byte[][]>(() => BuildPatterns(melds))).ToArray();
    private static readonly Lazy<byte[][]>[] Ready = Enumerable.Range(0,5).Select(m=>new Lazy<byte[][]>(()=>
        Patterns[m].Value.SelectMany(goal=>Enumerable.Range(0,9).Where(t=>goal[t]>0).Select(t=>
        {var h=goal.ToArray();h[t]--;return h;})).GroupBy(h=>string.Join(',',h)).Select(g=>g.First()).ToArray())).ToArray();
    internal static IEnumerable<ReadOnlyMemory<byte>> ReadyPatterns(int melds)
        =>Ready[melds].Value.Select(a=>new ReadOnlyMemory<byte>(a));

    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, SichuanFlushStructure> Cache = new();
    private static SichuanFlushStructure Copy(SichuanFlushStructure value) => value with {
        UsefulDraws = value.UsefulDraws.ToArray(), RequiredInEveryNearestPattern = value.RequiredInEveryNearestPattern.ToArray() };

    public SichuanFlushStructure Analyze(IReadOnlyList<int> hand, IReadOnlyList<int> available,
        IReadOnlyList<int> exposed, int suit, int meldCount)
    {
        using var policyTimer = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("flush");
        if (hand.Count != 27 || available.Count != 27 || exposed.Count != 27
            || suit is < 0 or > 2 || meldCount is < 0 or > 4)
            throw new ArgumentException("Expected 27 tile counts, a valid suit and 0–4 melds.");
        var empty = new SichuanFlushStructure(-1, 0, Array.Empty<int>(), Array.Empty<int>());
        for (var tile = 0; tile < 27; tile++)
        {
            if (hand[tile] < 0 || exposed[tile] < 0 || available[tile] < 0
                || hand[tile] + exposed[tile] > 4)
                throw new ArgumentException("Tile counts must obey physical copy limits.");
            if (tile / 9 != suit && exposed[tile] > 0) return empty;
        }
        // Exact mathematical memoization only: every dependency is in the key.
        // Public availability is included, so a newly visible fourth copy invalidates it.
        var key = $"{suit}:{meldCount}:" + string.Join(',', Enumerable.Range(suit*9,9)
            .Select(t => $"{hand[t]}/{available[t]}/{exposed[t]}"));
        if (Cache.TryGetValue(key, out var saved)) return Copy(saved);
        SichuanFlushStructure Save(SichuanFlushStructure value)
        {
            if (Cache.Count >= 32768) Cache.Clear();
            Cache.TryAdd(key,value);
            return Copy(value);
        }
        var best = int.MaxValue;
        var feasible = 0;
        var union = 0;
        var intersection = 0;
        foreach (var goal in Patterns[meldCount].Value)
        {
            var distance = 0;
            var mask = 0;
            var possible = true;
            for (var rank = 0; rank < 9; rank++)
            {
                var tile = suit * 9 + rank;
                var need = Math.Max(0, goal[rank] - hand[tile]);
                if (goal[rank] + exposed[tile] > 4 || need > available[tile])
                {
                    possible = false;
                    break;
                }
                distance += need;
                if (need > 0) mask |= 1 << rank;
            }
            if (!possible) continue;
            feasible++;
            if (distance < best)
            {
                best = distance;
                union = intersection = mask;
            }
            else if (distance == best)
            {
                union |= mask;
                intersection &= mask;
            }
        }
        if (feasible == 0) return Save(empty);
        int[] Expand(int mask) => Enumerable.Range(0, 9)
            .Where(rank => (mask & (1 << rank)) != 0).Select(rank => suit * 9 + rank).ToArray();
        return Save(new(best, feasible, Expand(union), Expand(intersection)));
    }

    private static byte[][] BuildPatterns(int meldCount)
    {
        var goals = new Dictionary<int, byte[]>();
        var counts = new byte[9];
        void Add()
        {
            var key = 0;
            foreach (var count in counts) key = key * 5 + count;
            goals.TryAdd(key, (byte[])counts.Clone());
        }
        void Sets(int start, int remaining)
        {
            if (remaining == 0) { Add(); return; }
            for (var set = start; set < 16; set++)
            {
                var a = set < 9 ? set : set - 9;
                var b = set < 9 ? set : a + 1;
                var c = set < 9 ? set : a + 2;
                counts[a]++; counts[b]++; counts[c]++;
                if (counts[a] <= 4 && counts[b] <= 4 && counts[c] <= 4)
                    Sets(set, remaining - 1);
                counts[a]--; counts[b]--; counts[c]--;
            }
        }
        for (var pair = 0; pair < 9; pair++)
        {
            counts[pair] = 2;
            Sets(0, 4 - meldCount);
            counts[pair] = 0;
        }
        if (meldCount == 0)
        {
            void Pairs(int start, int remaining)
            {
                if (remaining == 0) { Add(); return; }
                for (var rank = start; rank < 9; rank++)
                {
                    if (counts[rank] > 2) continue;
                    counts[rank] += 2;
                    Pairs(rank, remaining - 1);
                    counts[rank] -= 2;
                }
            }
            Pairs(0, 7);
        }
        return goals.Values.ToArray();
    }
}
