using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Rules;

public sealed class SichuanExactHandAnalyzer
{
    private readonly SichuanShantenEngine _shanten = new();

    public IReadOnlyList<SichuanHandDecomposition> EnumerateWinningDecompositions(
        IReadOnlyList<int> hand27,
        int exposedMeldCount = 0,
        bool allowSevenPairs = true)
    {
        var counts = Normalize(hand27);
        if (counts.Sum() + exposedMeldCount * 3 != 14)
            return Array.Empty<SichuanHandDecomposition>();

        var results = new List<SichuanHandDecomposition>();
        if (allowSevenPairs && exposedMeldCount == 0 && counts.Sum(value => value / 2) == 7)
        {
            var groups = Enumerable.Range(0, 27)
                .SelectMany(tile => Enumerable.Repeat(new SichuanHandGroup(SichuanGroupType.Pair, tile), counts[tile] / 2))
                .ToArray();
            results.Add(new SichuanHandDecomposition(groups, true));
        }

        var requiredSets = 4 - exposedMeldCount;
        var suffixCache = new Dictionary<string, IReadOnlyList<IReadOnlyList<SichuanHandGroup>>>(StringComparer.Ordinal);
        for (var pair = 0; pair < 27; pair++)
        {
            if (counts[pair] < 2) continue;
            counts[pair] -= 2;
            foreach (var suffix in EnumerateSetSuffixes(counts, requiredSets, suffixCache))
            {
                var groups = new List<SichuanHandGroup>(suffix.Count + 1) { new(SichuanGroupType.Pair, pair) };
                groups.AddRange(suffix);
                results.Add(new SichuanHandDecomposition(groups));
            }
            counts[pair] += 2;
        }

        return results
            .GroupBy(BuildKey)
            .Select(group => group.First())
            .ToArray();
    }

    public IReadOnlyList<SichuanWaitAnalysis> EnumerateWaits(
        IReadOnlyList<int> hand27,
        IReadOnlyList<int>? remaining27 = null,
        int exposedMeldCount = 0,
        bool allowSevenPairs = true)
    {
        var counts = Normalize(hand27);
        if ((counts.Sum() + exposedMeldCount * 3) % 3 != 1)
            return Array.Empty<SichuanWaitAnalysis>();
        var remaining = remaining27 is null ? Enumerable.Range(0, 27).Select(tile => 4 - counts[tile]).ToArray() : NormalizeRemaining(remaining27);
        var waits = new List<SichuanWaitAnalysis>();
        for (var tile = 0; tile < 27; tile++)
        {
            if (counts[tile] >= 4 || remaining[tile] <= 0) continue;
            counts[tile]++;
            var decompositions = EnumerateWinningDecompositions(counts, exposedMeldCount, allowSevenPairs);
            counts[tile]--;
            if (decompositions.Count > 0)
                waits.Add(new SichuanWaitAnalysis(tile, Math.Max(0, remaining[tile]), decompositions));
        }
        return waits;
    }

    public IReadOnlyList<SichuanDiscardAnalysis> AnalyzeDiscards(
        IReadOnlyList<int> hand27,
        IReadOnlyList<int>? remaining27 = null,
        int exposedMeldCount = 0,
        bool allowSevenPairs = true,
        int forcedSuit = -1)
    {
        var counts = Normalize(hand27);
        var remaining = remaining27 is null ? Enumerable.Range(0, 27).Select(tile => 4 - counts[tile]).ToArray() : NormalizeRemaining(remaining27);
        var results = new List<SichuanDiscardAnalysis>();
        for (var discard = 0; discard < 27; discard++)
        {
            if (counts[discard] <= 0 || forcedSuit >= 0 && discard / 9 != forcedSuit) continue;
            counts[discard]--;
            var shanten = _shanten.CalcBestShanten(counts, exposedMeldCount, allowSevenPairs);
            var improving = new List<int>();
            var live = 0;
            for (var draw = 0; draw < 27; draw++)
            {
                if (counts[draw] >= 4 || remaining[draw] <= 0) continue;
                counts[draw]++;
                var after = _shanten.CalcBestShanten(counts, exposedMeldCount, allowSevenPairs);
                counts[draw]--;
                if (after < shanten)
                {
                    improving.Add(draw);
                    live += remaining[draw];
                }
            }
            var waits = shanten == 0 ? EnumerateWaits(counts, remaining, exposedMeldCount, allowSevenPairs) : Array.Empty<SichuanWaitAnalysis>();
            var waitQuality = waits.Sum(wait => wait.LiveCount) + waits.Count * 1.5;
            results.Add(new SichuanDiscardAnalysis(discard, shanten, improving, live, waits, waitQuality));
            counts[discard]++;
        }
        if (results.Count == 0) return results;
        var bestShanten = results.Min(item => item.Shanten);
        var bestLive = results.Where(item => item.Shanten == bestShanten).Select(item => item.LiveUkeire).DefaultIfEmpty(0).Max();
        return results.Select(item => item with
        {
            StructuralLoss = Math.Max(0, item.Shanten - bestShanten) * 100 + Math.Max(0, bestLive - item.LiveUkeire)
        }).ToArray();
    }

    public IReadOnlyList<SichuanScoredWaitAnalysis> EnumerateScoredWaits(
        IReadOnlyList<int> hand27,
        IReadOnlyList<int>? remaining27,
        IReadOnlyList<SichuanMeldView> melds,
        SichuanWinType winType,
        IReadOnlyList<int> activeSeats,
        int winnerSeat,
        int sourceSeat = -1,
        SichuanRuleSnapshot? rules = null)
    {
        rules ??= SichuanRuleSnapshot.Frozen;
        var counts = Normalize(hand27);
        var fanEngine = new SichuanFanProjectionEngine();
        var settlementEngine = new SichuanSettlementProjectionEngine();
        var results = new List<SichuanScoredWaitAnalysis>();
        foreach (var wait in EnumerateWaits(counts, remaining27, melds.Count, rules.AllowSevenPairs))
        {
            counts[wait.TileType]++;
            var fan = fanEngine.Project(counts, melds, winType, rules);
            counts[wait.TileType]--;
            var settlement = settlementEngine.ProjectWin(winnerSeat, sourceSeat, activeSeats, fan, winType);
            results.Add(new SichuanScoredWaitAnalysis(
                wait,
                new[] { fan },
                fan.CappedFan,
                fan.CappedFan,
                settlement.WinnerGain,
                settlement.WinnerGain));
        }
        return results;
    }

    public bool IsWinning(IReadOnlyList<int> hand27, int exposedMeldCount = 0, bool allowSevenPairs = true)
        => EnumerateWinningDecompositions(hand27, exposedMeldCount, allowSevenPairs).Count > 0;

    private static IReadOnlyList<IReadOnlyList<SichuanHandGroup>> EnumerateSetSuffixes(
        int[] counts,
        int setsNeeded,
        Dictionary<string, IReadOnlyList<IReadOnlyList<SichuanHandGroup>>> cache)
    {
        var cacheKey = BuildCountKey(counts, setsNeeded);
        if (cache.TryGetValue(cacheKey, out var cached)) return cached;
        var first = Array.FindIndex(counts, value => value > 0);
        if (first < 0)
        {
            var terminal = setsNeeded == 0
                ? new IReadOnlyList<SichuanHandGroup>[] { Array.Empty<SichuanHandGroup>() }
                : Array.Empty<IReadOnlyList<SichuanHandGroup>>();
            cache[cacheKey] = terminal;
            return terminal;
        }
        if (setsNeeded <= 0)
        {
            cache[cacheKey] = Array.Empty<IReadOnlyList<SichuanHandGroup>>();
            return cache[cacheKey];
        }

        var results = new List<IReadOnlyList<SichuanHandGroup>>();

        if (counts[first] >= 3)
        {
            counts[first] -= 3;
            foreach (var suffix in EnumerateSetSuffixes(counts, setsNeeded - 1, cache))
                results.Add(Prepend(new SichuanHandGroup(SichuanGroupType.Triplet, first), suffix));
            counts[first] += 3;
        }

        if (first % 9 <= 6 && counts[first + 1] > 0 && counts[first + 2] > 0)
        {
            counts[first]--; counts[first + 1]--; counts[first + 2]--;
            foreach (var suffix in EnumerateSetSuffixes(counts, setsNeeded - 1, cache))
                results.Add(Prepend(new SichuanHandGroup(SichuanGroupType.Sequence, first), suffix));
            counts[first]++; counts[first + 1]++; counts[first + 2]++;
        }
        cache[cacheKey] = results;
        return results;
    }

    private static IReadOnlyList<SichuanHandGroup> Prepend(SichuanHandGroup group, IReadOnlyList<SichuanHandGroup> suffix)
    {
        var result = new SichuanHandGroup[suffix.Count + 1];
        result[0] = group;
        for (var index = 0; index < suffix.Count; index++) result[index + 1] = suffix[index];
        return result;
    }

    private static string BuildCountKey(IReadOnlyList<int> counts, int setsNeeded)
        => $"{setsNeeded}:{string.Concat(counts.Select(value => (char)('0' + value)))}";

    private static string BuildKey(SichuanHandDecomposition decomposition)
        => string.Join('|', decomposition.Groups.OrderBy(group => group.Type).ThenBy(group => group.TileType).Select(group => $"{(int)group.Type}:{group.TileType}"));

    private static int[] Normalize(IReadOnlyList<int> source)
        => Enumerable.Range(0, 27).Select(index => index < source.Count ? Math.Clamp(source[index], 0, 4) : 0).ToArray();

    private static int[] NormalizeRemaining(IReadOnlyList<int> source)
        => Enumerable.Range(0, 27).Select(index => index < source.Count ? Math.Max(0, source[index]) : 0).ToArray();
}
