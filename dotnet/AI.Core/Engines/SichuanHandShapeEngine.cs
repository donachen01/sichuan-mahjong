using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanHandShapeEngine
{
    private readonly SichuanShantenEngine _shanten = new();

    public SichuanHandShapeSummary Evaluate(
        int[] hand18,
        int[] remaining18,
        int meldCount,
        int shanten)
    {
        var profiles = EnumerateMutuallyExclusiveProfiles(hand18, meldCount);
        var best = profiles.FirstOrDefault() ?? ShapeProfile.Empty;
        var goodShapeCount = best.Ryanmen;
        var badShapeCount = best.Kanchan + best.Penchan;
        var pairCount = best.Pairs;
        var taatsuCount = best.Ryanmen + best.Kanchan + best.Penchan + Math.Max(0, pairCount - 1);
        var neededTaatsu = Math.Max(0, 4 - meldCount - best.Melds);
        // Multiple pairs are strategic assets in Sichuan Mahjong. Only the sixth
        // mutually-exclusive pair is structural pressure; four/five pairs remain
        // available to seven-pairs and all-triplets routes.
        var pairPressure = Math.Max(0, pairCount - 5);
        var taatsuOverflow = Math.Max(0, taatsuCount - neededTaatsu);
        var middleTileFlexibility = best.MiddleSingles;
        var sameShantenImprovementCount = CountSameShantenImprovements(hand18, remaining18, meldCount, shanten);
        var shapeScore = best.Score
            + sameShantenImprovementCount * 0.08
            + middleTileFlexibility * 0.025
            - pairPressure * 0.25
            - taatsuOverflow * 0.06;

        var reasons = new List<string>();
        if (goodShapeCount > 0)
            reasons.Add($"手形好搭 {goodShapeCount}");
        if (badShapeCount > 0)
            reasons.Add($"手形愚形 {badShapeCount}");
        if (sameShantenImprovementCount > 0)
            reasons.Add($"同向听改良 {sameShantenImprovementCount}");
        if (pairPressure > 0)
            reasons.Add($"对子压力 {pairPressure}");
        if (taatsuOverflow > 0)
            reasons.Add($"互斥分解搭子溢出 {taatsuOverflow}");
        if (profiles.Count > 1)
            reasons.Add($"近优互斥分解 {profiles.Count}");
        if (reasons.Count == 0)
            reasons.Add("手形结构平稳");

        return new SichuanHandShapeSummary
        {
            GoodShapeCount = goodShapeCount,
            BadShapeCount = badShapeCount,
            PairPressure = pairPressure,
            TaatsuOverflow = taatsuOverflow,
            SameShantenImprovementCount = sameShantenImprovementCount,
            MiddleTileFlexibility = middleTileFlexibility,
            BestBlockCount = best.Melds + Math.Min(neededTaatsu, taatsuCount),
            AlternativeDecompositionCount = profiles.Count,
            ShapeScore = shapeScore,
            Reasons = reasons.Take(4).ToArray()
        };
    }

    private static IReadOnlyList<ShapeProfile> EnumerateMutuallyExclusiveProfiles(int[] source, int exposedMeldCount)
    {
        var counts = source.Select(value => Math.Clamp(value, 0, 4)).ToArray();
        var profiles = new List<ShapeProfile>();
        SearchProfiles(counts, 0, ShapeProfile.Empty, profiles, exposedMeldCount);
        if (profiles.Count == 0) return new[] { ShapeProfile.Empty };
        var ordered = profiles
            .OrderByDescending(profile => profile.Score)
            .ThenByDescending(profile => profile.Melds)
            .ThenByDescending(profile => profile.Ryanmen)
            .ThenByDescending(profile => profile.Pairs)
            .ToArray();
        var cutoff = ordered[0].Score - 0.18;
        return ordered
            .Where(profile => profile.Score >= cutoff)
            .GroupBy(profile => profile.Key)
            .Select(group => group.First())
            .Take(8)
            .ToArray();
    }

    private static void SearchProfiles(int[] counts, int index, ShapeProfile profile, List<ShapeProfile> output, int exposedMeldCount)
    {
        while (index < counts.Length && counts[index] == 0) index++;
        if (index >= counts.Length)
        {
            output.Add(profile.WithScore(exposedMeldCount));
            return;
        }

        var rank = index % 9;
        if (counts[index] >= 3)
        {
            counts[index] -= 3;
            SearchProfiles(counts, index, profile with { Melds = profile.Melds + 1 }, output, exposedMeldCount);
            counts[index] += 3;
        }
        if (rank <= 6 && counts[index + 1] > 0 && counts[index + 2] > 0)
        {
            counts[index]--; counts[index + 1]--; counts[index + 2]--;
            SearchProfiles(counts, index, profile with { Melds = profile.Melds + 1 }, output, exposedMeldCount);
            counts[index]++; counts[index + 1]++; counts[index + 2]++;
        }
        if (counts[index] >= 2)
        {
            counts[index] -= 2;
            SearchProfiles(counts, index, profile with { Pairs = profile.Pairs + 1 }, output, exposedMeldCount);
            counts[index] += 2;
        }
        if (rank <= 7 && counts[index + 1] > 0)
        {
            counts[index]--; counts[index + 1]--;
            var isPenchan = rank is 0 or 7;
            SearchProfiles(counts, index, isPenchan
                ? profile with { Penchan = profile.Penchan + 1 }
                : profile with { Ryanmen = profile.Ryanmen + 1 }, output, exposedMeldCount);
            counts[index]++; counts[index + 1]++;
        }
        if (rank <= 6 && counts[index + 2] > 0)
        {
            counts[index]--; counts[index + 2]--;
            SearchProfiles(counts, index, profile with { Kanchan = profile.Kanchan + 1 }, output, exposedMeldCount);
            counts[index]++; counts[index + 2]++;
        }

        counts[index]--;
        SearchProfiles(counts, index, profile with
        {
            Singles = profile.Singles + 1,
            MiddleSingles = profile.MiddleSingles + (rank is >= 2 and <= 6 ? 1 : 0)
        }, output, exposedMeldCount);
        counts[index]++;
    }

    private sealed record ShapeProfile(
        int Melds,
        int Pairs,
        int Ryanmen,
        int Kanchan,
        int Penchan,
        int Singles,
        int MiddleSingles,
        double Score)
    {
        public static ShapeProfile Empty { get; } = new(0, 0, 0, 0, 0, 0, 0, 0);
        public string Key => $"{Melds}:{Pairs}:{Ryanmen}:{Kanchan}:{Penchan}:{Singles}:{MiddleSingles}";

        public ShapeProfile WithScore(int exposedMeldCount)
        {
            var neededBlocks = Math.Max(0, 4 - exposedMeldCount - Melds);
            var taatsu = Ryanmen + Kanchan + Penchan + Math.Max(0, Pairs - 1);
            var usefulTaatsu = Math.Min(neededBlocks, taatsu);
            var deficit = Math.Max(0, neededBlocks - usefulTaatsu);
            var overflow = Math.Max(0, taatsu - neededBlocks);
            var score = Melds * 0.46
                + Ryanmen * 0.34
                + Kanchan * 0.12
                + Penchan * 0.08
                + Math.Min(Pairs, 5) * 0.13
                - deficit * 0.22
                - overflow * 0.04
                - Singles * 0.025;
            return this with { Score = score };
        }
    }

    private int CountSameShantenImprovements(int[] hand18, int[] remaining18, int meldCount, int shanten)
    {
        var count = 0;
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (remaining18[tileType] <= 0 || hand18[tileType] >= 4) continue;
            var probe = (int[])hand18.Clone();
            probe[tileType]++;
            var drawShanten = _shanten.CalcBestShanten(probe, meldCount);
            if (drawShanten == shanten && ImprovesLocalShape(hand18, tileType))
                count += remaining18[tileType];
        }
        return count;
    }

    private static bool ImprovesLocalShape(int[] hand18, int tileType)
    {
        var suitStart = (tileType / 9) * 9;
        var rank = tileType % 9;
        for (var offset = -2; offset <= 2; offset++)
        {
            if (offset == 0) continue;
            var neighborRank = rank + offset;
            if (neighborRank is < 0 or >= 9) continue;
            if (hand18[suitStart + neighborRank] > 0)
                return true;
        }
        return false;
    }
}
