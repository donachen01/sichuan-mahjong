using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanDevelopmentRoute(string Route, int Distance, int[] EffectiveTiles, int LiveCopies);
public sealed record SichuanDevelopmentBranch(int DiscardTile, int StandardDistance, int? SevenPairsDistance,
    int BestDistance, int[] EffectiveTiles, int LiveCopies, string[] ProgressRoutes);
public sealed record SichuanDevelopmentDraw(int DrawTile, int Copies, bool CompletesStructure,
    bool Effective, bool StructuralImprovement, bool ValueImprovement, string[] ProgressRoutes,
    SichuanDevelopmentBranch[] Branches, SichuanHandImprovement[] WidthOptions,
    SichuanHandImprovement[] ValueOptions);
public sealed record SichuanHandDevelopmentSummary(bool Available, string Scope,
    SichuanDevelopmentRoute[] Routes, int[] EffectiveTiles, int[] StructuralImprovementTiles,
    int[] ValueImprovementTiles, int UnseenEffectiveCopies, int ImprovementCopies);
public sealed record SichuanHandDevelopment(SichuanHandDevelopmentSummary Summary,
    SichuanDevelopmentDraw[] Draws, SichuanHandImprovement[] PreferredImprovements);

/// <summary>One legal draw/discard cycle, at a cleared 13-equivalent-tile boundary.
/// Counts are unseen copies, not wall probabilities. All alternate discards remain
/// separate; a representative improvement is only a compatibility/counting view.
/// Hu locks, opponent offers and strategic route selection remain action concerns.</summary>
public sealed class SichuanHandDevelopmentEngine
{
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, SichuanHandDevelopment> Cache = new();
    public SichuanHandDevelopment Analyze(IReadOnlyList<int> hand27, IReadOnlyList<int> remaining27,
        int meldCount, int missingSuit = -1, IReadOnlyList<SichuanMeldView>? melds = null,
        bool requireKnownMissingSuit = false)
    {
        if (hand27.Count != 27 || remaining27.Count != 27 || meldCount is < 0 or > 4
            || hand27.Any(n => n is < 0 or > 4) || missingSuit is < -1 or > 2) throw new ArgumentException("Expected physical 27-type hand.");
        SichuanHandDevelopment Unavailable(string reason) => new(new(false, reason,
            Array.Empty<SichuanDevelopmentRoute>(), Array.Empty<int>(), Array.Empty<int>(),
            Array.Empty<int>(), 0, 0), Array.Empty<SichuanDevelopmentDraw>(), Array.Empty<SichuanHandImprovement>());
        if (requireKnownMissingSuit && missingSuit < 0) return Unavailable("missing_suit_not_selected");
        var scope = missingSuit < 0 ? "unrestricted_13_equivalent_math_only" : "cleared_13_equivalent_structural_not_wall_probability";
        if (hand27.Sum() + 3 * meldCount != 13) return Unavailable("not_13_equivalent_boundary");
        if (missingSuit is >= 0 and < 3 && hand27.Skip(9 * missingSuit).Take(9).Any(n => n > 0))
            return Unavailable("missing_suit_cleanup_separate");
        if (melds is not null && melds.Count != meldCount) throw new ArgumentException("Meld context count mismatch.");
        var fixedCopies = new int[27];
        if (melds is not null)
            foreach (var m in melds)
            {
                if (m.TileType is < 0 or > 26) throw new ArgumentException("Invalid fixed meld tile.");
                fixedCopies[m.TileType] += m.Type == SichuanMeldType.Peng ? 3 : 4;
            }
        if (Enumerable.Range(0, 27).Any(t => hand27[t] + fixedCopies[t] > 4)) return Unavailable("owned_copies_exceed_four");
        if (missingSuit is >= 0 and < 3 && fixedCopies.Skip(9 * missingSuit).Take(9).Any(n => n > 0))
            return Unavailable("fixed_meld_contains_missing_suit");
        var hand = hand27.ToArray();
        var remaining = Enumerable.Range(0, 27).Select(t => Math.Clamp(remaining27[t], 0, 4 - hand[t] - fixedCopies[t])).ToArray();
        var key = $"{meldCount}:{missingSuit}:" + string.Join(',', hand) + "/" + string.Join(',', remaining)
            + "/" + (melds is null ? "unknown-fixed" : string.Join(';', melds.Select(m => $"{m.Type}:{m.TileType}")));
        if (Cache.TryGetValue(key, out var saved)) return saved;
        var shanten = new SichuanShantenEngine();
        (int Standard, int? Seven, int Best) Distances()
        {
            var std = shanten.CalcStandardShanten(hand, meldCount);
            int? qi = meldCount == 0 ? shanten.CalcSevenPairsShanten(hand) : null;
            return (std, qi, qi.HasValue ? Math.Min(std, qi.Value) : std);
        }
        (SichuanDevelopmentRoute[] Routes, int[] Outs, int Live) Profile()
        {
            var d = Distances();var normal = new List<int>();var pairs = new List<int>();var combined = new List<int>();
            for (var t = 0; t < 27; t++)
            {
                if (t / 9 == missingSuit || remaining[t] <= 0 || hand[t] + fixedCopies[t] >= 4) continue;
                hand[t]++;var after = Distances();hand[t]--;
                if (after.Standard < d.Standard) normal.Add(t);
                if (d.Seven.HasValue && after.Seven < d.Seven) pairs.Add(t);
                if (after.Best < d.Best) combined.Add(t);
            }
            var routes = new List<SichuanDevelopmentRoute> { new("standard", d.Standard, normal.ToArray(), normal.Sum(t => remaining[t])) };
            if (d.Seven.HasValue) routes.Add(new("seven_pairs", d.Seven.Value, pairs.ToArray(), pairs.Sum(t => remaining[t])));
            return (routes.ToArray(), combined.ToArray(), combined.Sum(t => remaining[t]));
        }
        var beforeDistance = Distances();var before = Profile();
        var priceContext = melds ?? (meldCount == 0 ? Array.Empty<SichuanMeldView>() : null);
        var priced = beforeDistance.Best == 0 && priceContext is not null
            ? new SichuanHandImprovementEngine().EnumerateReadyFanImprovements(hand, remaining, priceContext, missingSuit, includeAllDiscards: true)
            : Array.Empty<SichuanHandImprovement>();
        var draws = new List<SichuanDevelopmentDraw>();
        for (var draw = 0; draw < 27; draw++)
        {
            if (draw / 9 == missingSuit || remaining[draw] <= 0 || hand[draw] + fixedCopies[draw] >= 4) continue;
            var copies = remaining[draw];hand[draw]++;remaining[draw]--;
            var drawnDistance = Distances();var completes = drawnDistance.Best < 0;
            var branches = new List<SichuanDevelopmentBranch>();var widths = new List<SichuanHandImprovement>();
            var progress = new HashSet<string>();
            if (completes)
            {
                if (drawnDistance.Standard < beforeDistance.Standard) progress.Add("standard");
                if (beforeDistance.Seven.HasValue && drawnDistance.Seven < beforeDistance.Seven) progress.Add("seven_pairs");
            }
            else
                for (var discard = 0; discard < 27; discard++)
                {
                    if (hand[discard] <= 0 || discard / 9 == missingSuit) continue;
                    hand[discard]--;var afterDistance = Distances();var after = Profile();
                    var advanced = new List<string>();
                    if (afterDistance.Standard < beforeDistance.Standard) advanced.Add("standard");
                    if (beforeDistance.Seven.HasValue && afterDistance.Seven < beforeDistance.Seven) advanced.Add("seven_pairs");
                    foreach (var route in advanced) progress.Add(route);
                    branches.Add(new(discard, afterDistance.Standard, afterDistance.Seven, afterDistance.Best,
                        after.Outs, after.Live, advanced.ToArray()));
                    if (afterDistance.Best == beforeDistance.Best && after.Live > before.Live)
                        widths.Add(new(draw, copies, discard, before.Live, after.Live));
                    hand[discard]++;
                }
            var effective = completes || branches.Any(b => b.BestDistance < beforeDistance.Best);
            var values = priced.Where(p => p.DrawTile == draw).ToArray();
            draws.Add(new(draw, copies, completes, effective, !effective && widths.Count > 0,
                !effective && values.Length > 0, progress.OrderBy(r => r == "standard" ? 0 : 1).ToArray(),
                branches.ToArray(), widths.ToArray(), values));
            remaining[draw]++;hand[draw]--;
        }
        var improvementDraws = draws.Where(d => !d.Effective && (d.StructuralImprovement || d.ValueImprovement)).ToArray();
        var preferred = improvementDraws.Select(d => d.WidthOptions.Concat(d.ValueOptions)
            .OrderByDescending(i => i.AfterLiveUkeire).ThenByDescending(i => i.FanValueGain).First()).ToArray();
        var summary = new SichuanHandDevelopmentSummary(true, scope, before.Routes, before.Outs,
            draws.Where(d => d.StructuralImprovement).Select(d => d.DrawTile).ToArray(),
            draws.Where(d => d.ValueImprovement).Select(d => d.DrawTile).ToArray(), before.Live,
            improvementDraws.Sum(d => d.Copies));
        var result = new SichuanHandDevelopment(summary, draws.ToArray(), preferred);
        if (Cache.Count > 256) Cache.Clear();
        Cache.TryAdd(key, result);return result;
    }
}
