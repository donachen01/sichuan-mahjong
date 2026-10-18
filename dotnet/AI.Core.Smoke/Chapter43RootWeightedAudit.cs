using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class Chapter43RootWeightedAudit
{
    public static int Run(string folder)
    {
        var rows = new List<object>();
        var errors = new List<string>();
        var checks = 0;
        void Check(bool ok, string name) { checks++; if (!ok) errors.Add(name); }

        var exact = new SichuanExactHandAnalyzer();
        var pricing = new SichuanReadyWaitPricing();
        var random = new Random(20261018);
        var found = 0;
        var attempts = 0;
        while (attempts++ < 1800 && found < 24)
        {
            var hand = TryBuildOneAwayHand(random);
            if (hand is null) continue;
            var remaining = Enumerable.Range(0, 27).Select(t => 4 - hand[t]).ToArray();
            var state = SichuanStateCodec.FromRaw(0, 0, 0, remaining.Sum() - 39,
                hand, new int[27], remaining,
                handCounts: new[] { 14, 13, 13, 13 },
                dingQueSuits: new[] { -1, -1, -1, -1 });
            var analyses = exact.AnalyzeDiscards(hand, remaining)
                .Where(a => a.Shanten == 0)
                .ToArray();
            if (analyses.Length < 2) continue;
            var prices = analyses.ToDictionary(a => a.DiscardTileType, a =>
            {
                var after = hand.ToArray(); after[a.DiscardTileType]--;
                return pricing.Build(state, after, remaining.Select(x => (double)x).ToArray());
            });
            var viable = prices.Where(x => x.Value is { HasDrawableWait: true }).ToArray();
            if (viable.Length < 2) continue;
            var incumbent = viable.OrderBy(x => IndependentWeighted(x.Value!)).First();
            var improved = viable
                .Where(x => IndependentWeighted(x.Value!) > IndependentWeighted(incumbent.Value!) + 1e-9
                    && x.Value!.Waits.Any(w => w.GenCount > 0 && w.PublicWallWeight > 0))
                .OrderByDescending(x => IndependentWeighted(x.Value!))
                .FirstOrDefault();
            if (improved.Value is null) continue;

            var candidates = analyses.Select(a => new SichuanCandidateDetail
            {
                TileType = a.DiscardTileType,
                Shanten = a.Shanten,
                Ukeire = a.LiveUkeire,
                LiveUkeire = a.LiveUkeire,
                WaitCount = a.Waits.Count,
                WaitQualityScore = (int)Math.Round(a.WaitQuality),
                Danger = 0,
                DealInProbability = 0
            }).ToArray();
            var choice = new SichuanCourseTempoPolicy().Select(state, candidates, incumbent.Key);
            var selectedPrice = choice is null
                ? prices[incumbent.Key]
                : prices.GetValueOrDefault(choice.Tile);
            Check(selectedPrice is { HasDrawableWait: true }, $"case {found} selected price exists");
            Check(choice is not null && choice.Code == "READY_ROOT_WEIGHTED_WAIT_GAIN",
                $"case {found} weighted root gain uses production course policy");
            Check(choice is not null && IndependentWeighted(selectedPrice!) > IndependentWeighted(incumbent.Value!) + 1e-9,
                $"case {found} selected weighted supply improves");

            var beforeRoot = IndependentWeighted(incumbent.Value!);
            var selectedRoot = IndependentWeighted(selectedPrice!);
            var sourceComparison = SichuanRootWeightedWaitPolicy.Compare(incumbent.Value, selectedPrice);
            Check(Math.Abs(sourceComparison.BeforeWeightedCopies - beforeRoot) < 1e-9,
                $"case {found} source comparison before matches independent formula");
            Check(Math.Abs(sourceComparison.AfterWeightedCopies - selectedRoot) < 1e-9,
                $"case {found} source comparison after matches independent formula");
            rows.Add(new
            {
                id = $"synthetic-{found}",
                hand,
                incumbentDiscard = incumbent.Key,
                selectedDiscard = choice?.Tile ?? -1,
                choiceCode = choice?.Code ?? "none",
                beforeWeighted = beforeRoot,
                selectedWeighted = selectedRoot,
                delta = selectedRoot - beforeRoot,
                before = Describe(incumbent.Value!),
                selected = Describe(selectedPrice!),
                reasons = choice?.Reasons ?? Array.Empty<string>()
            });
            found++;
        }

        Check(found >= 12, $"found sufficient weighted-root cases: {found}");
        var source = new
        {
            id = "4.3-source-audit-baseline",
            note = "Historical 4.3 source audit already has 9 mathematical and 9 Facade candidates; this run independently verifies the new root=2/non-root=1 ready-switch signal."
        };
        var report = new
        {
            auditOnly = false,
            checks,
            errors,
            cases = rows.Count,
            attempts,
            source,
            strategyVersion = SichuanStrategyContract.Version,
            policy = "READY_ROOT_WEIGHTED_WAIT_GAIN",
            formula = "sum(public remaining copies * (GenCount > 0 ? 2 : 1)); exact fan/settlement and danger remain separate",
            scope = "4.3 ready-hand wait-switch validation; synthetic one-away states, no claim of long-run strength or author probability calibration."
        };
        File.WriteAllText(Path.Combine(folder, "chapter43-root-weighted-audit.json"),
            JsonSerializer.Serialize(new { report, rows }, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"CHAPTER43_ROOT_WEIGHTED cases={rows.Count} checks={checks} errors={errors.Count} attempts={attempts}");
        foreach (var error in errors.Take(12)) Console.WriteLine(error);
        return errors.Count == 0 ? 0 : 1;
    }

    private static double IndependentWeighted(SichuanReadyPrice price)
        => price.Waits.Sum(wait => Math.Max(0.0, wait.PublicWallWeight) * (wait.GenCount > 0 ? 2.0 : 1.0));

    private static object Describe(SichuanReadyPrice price)
        => new
        {
            weighted = IndependentWeighted(price),
            root = price.RootDrawableMass,
            nonRoot = price.NonRootDrawableMass,
            waits = price.Waits.Select(w => new { w.TileType, copies = w.PublicWallWeight, w.GenCount, w.CappedFan }).ToArray()
        };

    private static int[]? TryBuildOneAwayHand(Random random)
    {
        var counts = new int[27];
        var pair = random.Next(0, 9);
        counts[pair] += 2;
        for (var group = 0; group < 4; group++)
        {
            var suit = random.Next(0, 3);
            var start = random.Next(0, 7);
            var sequence = new[] { suit * 9 + start, suit * 9 + start + 1, suit * 9 + start + 2 };
            if (sequence.Any(tile => counts[tile] >= 3)) return null;
            foreach (var tile in sequence) counts[tile]++;
        }
        if (counts.Sum() != 14 || counts.Any(x => x > 4)) return null;
        var replaceable = Enumerable.Range(0, 27).Where(t => counts[t] > 0).ToArray();
        var remove = replaceable[random.Next(replaceable.Length)];
        counts[remove]--;
        var additions = Enumerable.Range(0, 27).Where(t => counts[t] < 4 && t != remove).ToArray();
        if (additions.Length == 0) return null;
        counts[additions[random.Next(additions.Length)]]++;
        return counts;
    }
}
