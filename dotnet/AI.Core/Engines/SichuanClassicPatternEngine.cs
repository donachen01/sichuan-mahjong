using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

/// <summary>Finds the course's effective pair count from mutually-exclusive blocks.</summary>
public sealed class SichuanClassicPatternEngine
{
    public double EvaluateDiscard(SichuanClassicPatternAnalysis before, IReadOnlyList<int> handAfterDiscard, int exposedMelds = 0)
    {
        var after = Analyze(handAfterDiscard, exposedMelds);
        return before.Type switch
        {
            1 => (after.EffectivePairCount == 0 ? 2.0 : 0.0) + Math.Min(2, after.TaatsuCount) * 0.5 - after.SingleCount * 0.05,
            2 => (after.EffectivePairCount == 1 ? 2.0 : -1.0) + Math.Max(0, before.SingleCount - after.SingleCount) * 0.35,
            3 or 4 => (after.EffectivePairCount == 2 ? 1.5 : -0.5) + (after.HasTwoPairsAndHalf ? 1.0 : 0.0),
            _ => 0.0
        };
    }

    public SichuanClassicPatternAnalysis Analyze(IReadOnlyList<int> source, int exposedMelds = 0)
    {
        var counts = Enumerable.Range(0, 27)
            .Select(i => i < source.Count ? Math.Clamp(source[i], 0, 4) : 0).ToArray();
        var rawPairs = counts.Count(n => n >= 2);
        var profiles = new List<Profile>();
        Search(counts, 0, new Profile(exposedMelds, 0, [], []), profiles);
        var best = profiles.OrderBy(Shanten)
            .ThenByDescending(p => p.Melds)
            .ThenByDescending(UsefulTaatsu)
            .ThenBy(p => p.Singles.Length)
            .ThenByDescending(p => p.Pairs.Length)
            .First();
        var effectivePairs = best.Pairs.Length;
        var type = Math.Clamp(effectivePairs + 1, 1, 4);
        var half = effectivePairs >= 2 && best.Singles.Any(single =>
            best.Pairs.Any(pair => pair / 9 == single / 9 && Math.Abs(pair % 9 - single % 9) <= 2));
        var label = type switch
        {
            1 => "1型-全手无对",
            2 => "2型-一对三单",
            3 => "3型-全手两对",
            _ => "4型-全手三对"
        };
        return new(type, label, Shanten(best), effectivePairs, rawPairs, best.Taatsu,
            best.Singles.Length, rawPairs > 0 && effectivePairs == 0, half, best.Pairs, best.Singles);
    }

    private static int Shanten(Profile p)
    {
        var useful = UsefulTaatsu(p);
        return Math.Max(-1, 8 - p.Melds * 2 - useful - (p.Pairs.Length > 0 ? 1 : 0));
    }

    private static int UsefulTaatsu(Profile p)
    {
        // One pair supplies the eyes. Every additional pair is also a two-tile
        // incomplete block and must count against the remaining meld slots.
        var pairTaatsu = Math.Max(0, p.Pairs.Length - 1);
        return Math.Min(p.Taatsu + pairTaatsu, Math.Max(0, 4 - p.Melds));
    }

    private static void Search(int[] c, int i, Profile p, List<Profile> output)
    {
        while (i < 27 && c[i] == 0) i++;
        if (i >= 27) { output.Add(p); return; }
        var rank = i % 9;
        if (c[i] >= 3)
        {
            c[i] -= 3; Search(c, i, p with { Melds = p.Melds + 1 }, output); c[i] += 3;
        }
        if (rank <= 6 && c[i + 1] > 0 && c[i + 2] > 0)
        {
            c[i]--; c[i + 1]--; c[i + 2]--;
            Search(c, i, p with { Melds = p.Melds + 1 }, output);
            c[i]++; c[i + 1]++; c[i + 2]++;
        }
        if (c[i] >= 2)
        {
            c[i] -= 2;
            Search(c, i, p with { Pairs = p.Pairs.Append(i).ToArray() }, output);
            c[i] += 2;
        }
        if (rank <= 7 && c[i + 1] > 0)
        {
            c[i]--; c[i + 1]--;
            Search(c, i, p with { Taatsu = p.Taatsu + 1 }, output);
            c[i]++; c[i + 1]++;
        }
        if (rank <= 6 && c[i + 2] > 0)
        {
            c[i]--; c[i + 2]--;
            Search(c, i, p with { Taatsu = p.Taatsu + 1 }, output);
            c[i]++; c[i + 2]++;
        }
        c[i]--;
        Search(c, i, p with { Singles = p.Singles.Append(i).ToArray() }, output);
        c[i]++;
    }

    private sealed record Profile(int Melds, int Taatsu, int[] Pairs, int[] Singles);
}
