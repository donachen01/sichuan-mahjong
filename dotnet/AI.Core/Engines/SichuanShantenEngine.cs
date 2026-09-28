namespace SichuanMahjong.AI.Core.Engines;

using System.Collections.Concurrent;

public sealed class SichuanShantenEngine
{
    // Only mathematical hand structure is shared, never seat information or
    // policy state. Bounded memoization also works in the iOS AOT runtime.
    private static readonly ConcurrentDictionary<(ulong Low, ulong High, int Melds), int> StandardCache = new();
    private const int CacheCapacity = 65536;
    private static int _cacheEntries;

    public int CalcStandardShanten(int[] hand18, int meldCount = 0)
    {
        var cacheable = hand18.Length == 27 && meldCount is >= 0 and <= 4;
        ulong low = 0, high = 0;
        if (cacheable)
            for (var tile = 0; tile < 27; tile++)
            {
                if (hand18[tile] is < 0 or > 4) { cacheable = false; break; }
                if (tile < 21) low |= (ulong)hand18[tile] << (tile * 3);
                else high |= (ulong)hand18[tile] << ((tile - 21) * 3);
            }
        var key = (low, high, meldCount);
        if (cacheable && StandardCache.TryGetValue(key, out var cached)) return cached;
        var counts = (int[])hand18.Clone();
        var best = 8;
        Search(counts, 0, meldCount, 0, 0, ref best);
        var result = Math.Max(-1, best);
        if (cacheable)
        {
            if (StandardCache.TryAdd(key, result) && Interlocked.Increment(ref _cacheEntries) >= CacheCapacity)
            {
                StandardCache.Clear();
                Interlocked.Exchange(ref _cacheEntries, 0);
            }
        }
        return result;
    }

    public int CalcSevenPairsShanten(int[] hand18)
    {
        // 四川龙七对允许四张同牌按两对参与七对结构。
        var pairUnits = hand18.Sum(count => Math.Clamp(count, 0, 4) / 2);
        var singleUnits = hand18.Count(count => Math.Clamp(count, 0, 4) % 2 == 1);
        var missingPairs = Math.Max(0, 7 - pairUnits);
        var singlesUsed = Math.Min(missingPairs, singleUnits);
        var tilesNeeded = singlesUsed + (missingPairs - singlesUsed) * 2;
        return Math.Max(-1, tilesNeeded - 1);
    }

    public int CalcBestShanten(int[] hand18, int meldCount = 0, bool allowQiDui = true)
    {
        var standard = CalcStandardShanten(hand18, meldCount);
        if (!allowQiDui || meldCount > 0)
            return standard;
        return Math.Min(standard, CalcSevenPairsShanten(hand18));
    }

    public int CalcShantenAfterDiscard(int[] hand18, int tileType, int meldCount = 0, bool allowQiDui = true)
    {
        if (tileType is < 0 or >= 27 || hand18[tileType] <= 0)
            return CalcBestShanten(hand18, meldCount, allowQiDui);
        var clone = (int[])hand18.Clone();
        clone[tileType]--;
        return CalcBestShanten(clone, meldCount, allowQiDui);
    }

    private static void Search(int[] counts, int index, int melds, int taatsu, int pairs, ref int best)
    {
        while (index < counts.Length && counts[index] == 0) index++;
        if (index >= counts.Length)
        {
            var effectiveTaatsu = Math.Min(taatsu, Math.Max(0, 4 - melds));
            var hasPair = pairs > 0 ? 1 : 0;
            var shanten = 8 - melds * 2 - effectiveTaatsu - hasPair;
            best = Math.Min(best, shanten);
            return;
        }

        if (counts[index] >= 3)
        {
            counts[index] -= 3;
            Search(counts, index, melds + 1, taatsu, pairs, ref best);
            counts[index] += 3;
        }

        if (CanSequence(counts, index))
        {
            counts[index]--; counts[index + 1]--; counts[index + 2]--;
            Search(counts, index, melds + 1, taatsu, pairs, ref best);
            counts[index]++; counts[index + 1]++; counts[index + 2]++;
        }

        if (counts[index] >= 2)
        {
            counts[index] -= 2;
            Search(counts, index, melds, taatsu, pairs + 1, ref best);
            Search(counts, index, melds, taatsu + 1, pairs, ref best);
            counts[index] += 2;
        }
        else if (counts[index] >= 1)
        {
            if (CanAdjacent(counts, index, 1))
            {
                counts[index]--; counts[index + 1]--;
                Search(counts, index, melds, taatsu + 1, pairs, ref best);
                counts[index]++; counts[index + 1]++;
            }
            if (CanAdjacent(counts, index, 2))
            {
                counts[index]--; counts[index + 2]--;
                Search(counts, index, melds, taatsu + 1, pairs, ref best);
                counts[index]++; counts[index + 2]++;
            }
        }

        counts[index]--;
        Search(counts, index, melds, taatsu, pairs, ref best);
        counts[index]++;
    }

    private static bool CanSequence(int[] counts, int index)
    {
        var rank = index % 9;
        return rank <= 6 && counts[index] > 0 && counts[index + 1] > 0 && counts[index + 2] > 0;
    }

    private static bool CanAdjacent(int[] counts, int index, int gap)
    {
        var rank = index % 9;
        return rank + gap <= 8 && counts[index] > 0 && counts[index + gap] > 0;
    }
}
