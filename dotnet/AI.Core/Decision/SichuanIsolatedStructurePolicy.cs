using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>
/// Early ordinary-hand development: compare genuine singletons before removing
/// a pair's live sequence extension when that extension can coexist with an
/// intact triplet and its fourth-copy opportunity. This is a conditional
/// structural preference, not calibrated gang income or a shanten override.
/// </summary>
public sealed class SichuanIsolatedStructurePolicy
{
    private readonly SichuanShantenEngine _distance = new();

    public SichuanCourseTempoChoice? Select(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, SichuanCandidateDetail current, int roundStage)
    {
        if (current.Shanten is < 1 or > 3 || state.WallCount < 8
            || state.InformationMode != "public"
            || state.PolicyVariant == "bucket_disabled"
            || state.ActiveSeats.Count(active => active) < 3
            || SichuanDevelopmentPolicy.Draws(state) < 3
            || roundStage > 1
            || state.OwnDingQueSuit is < 0 or > 2)
            return null;
        var h = state.Hand18;
        if (h.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0)) return null;
        // Open seven-pairs/flush plans and an actual ready hand are handled by
        // the enclosing strategy. Do not dismantle them for a local analogy.
        if (SichuanRoutePlanEngine.IsFlushRoute(current.RoutePlanPrimary)
            || current.RoutesAfter.Contains("七对")) return null;
        if (state.OwnMeldCount == 0
            && _distance.CalcSevenPairsShanten(h) <= current.Shanten) return null;

        var singles = Enumerable.Range(0, 27).Where(t => IsSingleton(h, t)
            && t / 9 != state.OwnDingQueSuit).ToArray();
        if (singles.Length < 2 || singles.Contains(current.TileType)) return null;
        if (!singles.Any(t => HasSequenceBackedSplit(h, state.Remaining18, t))) return null;

        var extensions = CompatibleExtensions(h, state.Remaining18).ToArray();
        if (!extensions.Any(e => e.Extension == current.TileType)) return null;

        // Do not pay an extra shanten or erase an existing route. The accepted
        // trade-off is fewer immediate outs for compatible block development.
        var choices = candidates.Where(c => singles.Contains(c.TileType)
            && c.Shanten == current.Shanten
            && !c.BreaksPair && !c.BreaksTriplet
            && c.Danger <= current.Danger + 5
            && c.DealInProbability <= current.DealInProbability + 0.01
            && c.RouteLoss.All(current.RouteLoss.Contains)
            && !SichuanRoutePlanEngine.IsFlushRoute(c.RoutePlanPrimary)).ToArray();
        if (choices.Length < 2) return null;
        var measured = choices.Select(c =>
        {
            var after = h.ToArray(); after[c.TileType]--;
            var improving = _distance.LegalImprovingTiles(after, state.Remaining18,
                state.OwnMeldCount, state.OwnDingQueSuit);
            return (Candidate: c, Supply: improving.Sum(t => state.Remaining18[t]));
        }).OrderByDescending(c => c.Supply).ThenBy(c => c.Candidate.Danger).ToArray();
        if (measured.Length < 2 || measured[0].Supply == measured[1].Supply) return null;
        var selected = measured[0];
        var continuations = AdvancingExtensions(state, selected.Candidate.TileType)
            .Where(e => e.Extension == current.TileType).ToArray();
        if (continuations.Length == 0) return null;
        var route = continuations[0];
        return new(selected.Candidate.TileType, "ISOLATED_COMPATIBLE_BLOCK_DEVELOPMENT",
            ["先比较真实孤张：不增加上听数，保留对子旁活顺子通道与现成暗刻的兼容用途",
             $"保留{Label(route.Extension)}，来{Label(route.Draw)}后存在完整合法摸打能上听，组顺不占用暗刻{Label(route.Triplet)}；第四张仍有未见副本，未计为确定杠钱",
             $"孤张候选完整重算、逐来牌去重：选中路线可上听未见副本{selected.Supply}；不代表墙内张数或胜率"]);
    }

    public IEnumerable<(int Extension, int Draw, int Triplet, int Pair)> AdvancingExtensions(
        SichuanStateView state, int discard)
    {
        if (state.OwnMeldCount > 2 || state.Hand18[discard] == 0) yield break;
        var after = state.Hand18.ToArray(); after[discard]--;
        var before = _distance.CalcLegalShanten(after, state.OwnMeldCount, state.OwnDingQueSuit, false);
        foreach (var route in CompatibleExtensions(after, state.Remaining18))
        {
            var future = after.ToArray(); future[route.Draw]++;
            future[route.Triplet] -= 3;
            future[route.Pair]--; future[route.Extension]--; future[route.Draw]--;
            if (future.Any(n => n < 0)) continue;
            // Fix the two actual sets, then enumerate a legal next discard
            // from the remaining physical cards. The same pair cannot also
            // be counted as an intact head after one copy entered the run.
            var advances = false;
            for (var next = 0; next < 27 && !advances; next++)
            {
                if (future[next] == 0 || next / 9 == state.OwnDingQueSuit) continue;
                future[next]--;
                advances = _distance.CalcLegalShanten(future, state.OwnMeldCount + 2,
                    state.OwnDingQueSuit, false) < before;
                future[next]++;
            }
            if (advances) yield return route;
        }
    }

    private static string Label(int tile) => $"{tile % 9 + 1}{new[] { "条", "筒", "万" }[tile / 9]}";

    public static bool IsSingleton(IReadOnlyList<int> h, int t) => h[t] == 1
        && (t % 9 == 0 || h[t - 1] == 0) && (t % 9 == 8 || h[t + 1] == 0);

    public static bool HasSequenceBackedSplit(IReadOnlyList<int> h, IReadOnlyList<int> remaining, int single)
    {
        var start = single / 9 * 9;
        for (var rank = 0; rank < 7; rank++)
        {
            var run = new[] { start + rank, start + rank + 1, start + rank + 2 };
            if (run.Contains(single) || run.Any(t => h[t] == 0)) continue;
            var four = run.Append(single).ToArray();
            // Enumerate physical, disjoint two-pair partitions, rather than
            // award a bonus merely because nearby ranks are present.
            for (var partner = 0; partner < 3; partner++)
            {
                var a = new[] { single, four[partner] };
                var b = run.Where((_, index) => index != partner).ToArray();
                if (CompletionTiles(a[0], a[1]).Any(t => remaining[t] > 0)
                    && CompletionTiles(b[0], b[1]).Any(t => remaining[t] > 0)) return true;
            }
        }
        return false;
    }

    public static IEnumerable<(int Extension, int Draw, int Triplet, int Pair)> CompatibleExtensions(
        IReadOnlyList<int> h, IReadOnlyList<int> remaining)
    {
        var triplets = Enumerable.Range(0, 27).Where(t => h[t] == 3 && remaining[t] > 0).ToArray();
        foreach (var pair in Enumerable.Range(0, 27).Where(t => h[t] == 2))
        foreach (var side in Enumerable.Range(pair / 9 * 9, 9).Where(t => h[t] == 1
            && Math.Abs(t - pair) == 1))
        foreach (var draw in CompletionTiles(pair, side).Where(t => remaining[t] > 0 && h[t] == 0))
        foreach (var triplet in triplets)
        {
            // The new run uses one pair tile, the extension and a fresh draw.
            // None of its physical tiles can be borrowed from the triplet.
            if (triplet != pair && triplet != side && triplet != draw)
                yield return (side, draw, triplet, pair);
        }
    }

    private static IEnumerable<int> CompletionTiles(int a, int b)
    {
        if (a / 9 != b / 9) yield break;
        for (var start = a / 9 * 9; start <= a / 9 * 9 + 6; start++)
        {
            var run = new[] { start, start + 1, start + 2 };
            if (a != b && run.Contains(a) && run.Contains(b))
                yield return run.Single(t => t != a && t != b);
        }
    }
}
