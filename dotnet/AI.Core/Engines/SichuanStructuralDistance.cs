namespace SichuanMahjong.AI.Core.Engines;

// Suit-local, mutually exclusive decompositions for the two-draw shape probe.
// Memo entries contain only mathematical tile counts, never player information.
internal sealed class SichuanStructuralDistance
{
    private static readonly int[] Powers = { 1, 5, 25, 125, 625, 3125, 15625, 78125, 390625 };
    [ThreadStatic] private static Dictionary<int,int[]>? _threadSuits;
    private static Dictionary<int,int[]> SuitCache => _threadSuits ??= new();
    private static readonly int[] EmptyProfile = {0,-1,-1,-1,-1,-1,-1,-1,-1,-1};


    internal int Best(int[] hand, int exposed, bool allowSevenPairs = true)
    {
        // All structural callers, including continuation and terminal probes,
        // must reject targets that complete a quad using a fifth copy.
        if (hand.Contains(4))
            return IncludeSevenPairs(SichuanPhysicalTargetDistance.Best(hand, exposed), hand, exposed, allowSevenPairs);
        var keys=new int[3];
        for (var suit = 0; suit < 3; suit++)
        {
            var key = 0;
            for (var rank = 0; rank < 9; rank++) key += hand[suit * 9 + rank] * Powers[rank];
            keys[suit]=key;
        }
        return IncludeSevenPairs(BestEncoded(hand,exposed,keys[0],keys[1],keys[2],false),hand,exposed,allowSevenPairs);
    }

    internal int BestEncoded(int[] hand,int exposed,int suit0,int suit1,int suit2,bool hasQuad)
    {
        if(hasQuad)return Math.Max(-1,SichuanPhysicalTargetDistance.BestEncoded(hand,exposed,suit0,suit1,suit2));
        if (SuitCache.Count > 131072) SuitCache.Clear();
        var profiles = new[]{Profile(suit0),Profile(suit1),Profile(suit2)};
        var best = 8;
        for (var a = 0; a < 10; a++)
        {
        if (profiles[0][a] < 0) continue;
        for (var b = 0; b < 10; b++)
        {
        if (profiles[1][b] < 0) continue;
        for (var c = 0; c < 10; c++)
        {
            if (profiles[2][c] < 0) continue;
            var melds = exposed + a / 2 + b / 2 + c / 2;
            var pair = a % 2 + b % 2 + c % 2;
            if (melds > 4 || pair > 1) continue;
            var taatsu = Math.Min(4 - melds, profiles[0][a] + profiles[1][b] + profiles[2][c]);
            best = Math.Min(best, 8 - melds * 2 - taatsu - pair);
        }
        }
        }
        return Math.Max(-1,best);
    }

    private static int IncludeSevenPairs(int best, int[] hand, int exposed, bool allowSevenPairs)
    {
        if (exposed == 0 && allowSevenPairs)
        {
            var pairs = hand.Sum(count => count / 2);
            var singles = hand.Count(count => count % 2 == 1);
            var needed = Math.Max(0, 7 - pairs);
            best = Math.Min(best, needed * 2 - Math.Min(needed, singles) - 1);
        }
        var answer=Math.Max(-1,best);
        return answer;
    }

    private int[] Profile(int key)
    {
        if (key==0) return EmptyProfile;
        if (SuitCache.TryGetValue(key, out var cached)) return cached;
        var rank = 0;
        while (key / Powers[rank] % 5 == 0) rank++;
        var copies = key / Powers[rank] % 5;
        var result = (int[])Profile(key - Powers[rank]).Clone(); // Leave this tile unused.
        if (copies >= 3) Merge(Profile(key - 3 * Powers[rank]), result, meld: 1);
        if (copies >= 2)
        {
            var rest = Profile(key - 2 * Powers[rank]);
            Merge(rest, result, pair: 1);
            Merge(rest, result, taatsu: 1);
        }
        if (rank <= 6 && key / Powers[rank + 1] % 5 > 0 && key / Powers[rank + 2] % 5 > 0)
            Merge(Profile(key - Powers[rank] - Powers[rank + 1] - Powers[rank + 2]), result, meld: 1);
        for (var gap = 1; gap <= 2 && rank + gap < 9; gap++)
            if (key / Powers[rank + gap] % 5 > 0)
                Merge(Profile(key - Powers[rank] - Powers[rank + gap]), result, taatsu: 1);
        SuitCache.TryAdd(key,result);
        return result;
    }

    private static void Merge(int[] source, int[] destination, int meld = 0, int pair = 0, int taatsu = 0)
    {
        for (var index = 0; index < 10; index++)
        {
            if (source[index] < 0) continue;
            var m = index / 2 + meld;
            var p = index % 2 + pair;
            if (m > 4 || p > 1) continue;
            var t = Math.Min(4 - m, source[index] + taatsu);
            destination[m * 2 + p] = Math.Max(destination[m * 2 + p], t);
        }
    }
}
