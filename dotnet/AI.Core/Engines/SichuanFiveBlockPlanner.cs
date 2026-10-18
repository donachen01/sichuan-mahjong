using System.Collections.Concurrent;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanFiveBlockChoice(int Tile, int OrdinaryShanten, int SevenPairsShanten,
    double WeakestSupply, double ReplacementSupply, int CapacityOverflow, string[] Reasons)
{
    public int[][] ParentGroups { get; init; } = Array.Empty<int[]>();
    public int[] ParentSingles { get; init; } = Array.Empty<int>();
    public int HeadTile { get; init; } = -1;
    public int[][] RequiredBlocks { get; init; } = Array.Empty<int[]>();
    public IReadOnlyList<SichuanBucketReplacementPath> ReplacementPaths { get; init; }
        = Array.Empty<SichuanBucketReplacementPath>();
    public IReadOnlyList<SichuanFiveBlockAlternative> Alternatives { get; init; }
        = Array.Empty<SichuanFiveBlockAlternative>();
    public SichuanFiveBlockReorganization? Reorganization { get; init; }
    public SichuanFiveBlockChoice? LocalDevelopment { get; init; }
}

public sealed record SichuanFiveBlockAlternative(int Tile, double[][] Qualities, int Singles);
public sealed record SichuanBucketReplacementPath(int Spare, int Draw, int Discard,
    int[] NewBlock, int DistanceAfter, int Copies);

/// <summary>
/// Local chapter-3 planning: retain the five groups' development channels,
/// including compound taatsu, public peng supply, and a spare tile that can
/// replace a weak group. Supply is an ordinal planning aid, not a probability
/// or settlement value. No textbook hand, seat, suit or discard keys.
/// </summary>
public sealed class SichuanFiveBlockPlanner
{
    internal sealed record Profile(int[][] Groups, int[] Singles);
    private sealed record Quality(double Supply, double Intrinsic, double Replacement, int Stability,
        int[] Block, int Head);
    private sealed record Plan(int Tile, Quality[] Groups, int Overflow, int Singles,
        int Ordinary, int Seven);
    private static readonly ConcurrentDictionary<string, Profile[]> Cache = new();
    private readonly SichuanShantenEngine _distance = new();

    public SichuanFiveBlockChoice? Select(SichuanStateView state, IReadOnlyList<int> legalTiles,
        int incumbent = -1)
    {
        var local = SelectLocal(state, legalTiles);
        var reference = local?.Tile ?? incumbent;
        if (reference < 0) return local;
        var whole = new SichuanFiveBlockReorganizationEngine().Analyze(state, legalTiles, reference);
        if (!whole.Supported) return local;
        var chosen = whole.Candidates.First(c => c.Tile == whole.Tile);
        var role = chosen.Organizations.FirstOrDefault(o => o.Head == whole.Head && o.HeadCount == whole.HeadCount)
            ?? chosen.Best;
        var notes = new[] { "FIVE_BLOCK_WHOLE_HAND_REORGANIZATION",
            "按四面子一将重新组织手牌，比较有效进张、候补替换和碰牌后的出牌",
            $"将牌方案为{role.Head % 9 + 1}{new[] {"条","筒","万"}[role.Head / 9]}"
                + (role.HeadCount == 2 ? "对子；同时保留其他牌组的改良空间" : "单张候补；仍须补成将牌") };
        var kept = state.Hand18.ToArray(); kept[whole.Tile]--;
        var replacements = role.RequiredBlocks.Where(g => g.Length == 2)
            .SelectMany(g => new SichuanBucketBlockRoutes().Analyze(kept, state.Remaining18,
                state.OwnMeldCount, state.OwnDingQueSuit, g, role.Singles))
            .Where(p => p.Kind == "start_replacement")
            .Select(p => new SichuanBucketReplacementPath(p.RetainedBlock.First(t => role.Singles.Contains(t)),
                p.Draw, p.Discard, p.RetainedBlock, p.DistanceAfter, p.Copies)).ToArray();
        return new(whole.Tile, chosen.OrdinaryDistance, chosen.SevenDistance,
            role.WeakestCopies, replacements.Select(p => p.Draw).Distinct()
                .Sum(t => state.Remaining18[t]), role.Pressure, notes)
        { ParentGroups = role.Groups, ParentSingles = role.Singles, HeadTile = role.Head,
            RequiredBlocks = role.RequiredBlocks, Reorganization = whole,
            ReplacementPaths = replacements, LocalDevelopment = local };
    }

    private SichuanFiveBlockChoice? SelectLocal(SichuanStateView state, IReadOnlyList<int> legalTiles)
    {
        var hand = state.Hand18;
        var meldCount = state.OwnMeldCount;
        if (hand.Sum() + 3 * meldCount != 14 || legalTiles.Count == 0
            || state.Remaining18.Any(n => n < 0)
            || state.OwnDingQueSuit is >= 0 and < 3
                && hand.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0)) return null;
        var distances = legalTiles.ToDictionary(t => t, t =>
        {
            var after = hand.ToArray(); after[t]--;
            return (Ordinary: _distance.CalcStandardShanten(after, meldCount),
                Seven: meldCount == 0 ? _distance.CalcSevenPairsShanten(after) : 99);
        });
        var ordinary = distances.Values.Min(v => v.Ordinary);
        // Actual one-step ready entries are ranked by exact whole-hand ukeire.
        // Five-block development is for the more distant structural phase.
        if (ordinary is < 1 or > 3 || distances.Values.Min(v => Math.Min(v.Ordinary, v.Seven)) < ordinary
            && distances.Values.Min(v => v.Seven) <= 1)
            return null;
        var profiles = Enumerate(hand);
        if (profiles.Length == 0) return null;
        var massCache = new Dictionary<string, double>();
        var routeCache = new Dictionary<string, IReadOnlyList<SichuanBucketBlockPath>>();
        var parents = profiles.Where(p =>
        {
            var made = p.Groups.Count(Complete) + meldCount;
            var dev = p.Groups.Where(g => !Complete(g)).ToArray();
            // Five groups are the target, not a prerequisite for a valid
            // current hand. Forcing five here can split a natural triplet
            // into a pair/gap just to hide a genuinely missing block.
            return made <= 4
                && dev.Any(g => g.Length == 2 && g[0] == g[1])
                && 8 - 2 * made - Math.Min(4 - made, dev.Length - 1) - 1 == ordinary;
        }).ToArray();
        if (parents.Length == 0) return null;
        // A formed triplet has a real gang route; do not repartition it away
        // merely to fabricate a stronger spare block at the same distance.
        var natural = parents.Max(p => p.Groups.Count(g => Complete(g) && g[0] == g[2]));
        parents = parents.Where(p => p.Groups.Count(g => Complete(g) && g[0] == g[2]) == natural).ToArray();
        var minSingles = parents.Min(p => p.Singles.Length);
        parents = parents.Where(p => p.Singles.Length == minSingles).ToArray();
        Profile? parent = null;
        Quality[]? parentQuality = null;
        var parentHead = -1;
        foreach (var p in parents)
        {
            var quality = Qualities(p.Groups.Where(g => !Complete(g)), p.Singles,
                p.Groups.Where(Complete).ToArray(), includeReplacement: false);
            if (parent is null || Compare(quality, parentQuality!) > 0)
            { parent = p; parentQuality = quality; }
        }
        if (parent is null) return null;
        var completeGroups = parent.Groups.Where(Complete).ToArray();
        var develops = parent.Groups.Where(g => !Complete(g)).ToArray();
        var overloaded = parent.Groups.Length + meldCount > 5;
        if (ordinary == 1 && !overloaded) return null;
        var oversized = develops.Where(g => g.Length > 3).ToArray();
        // The head already fulfils its role. It is not a taatsu waiting to
        // become a triplet; rank only the blocks required as future sets.
        parentHead = parentQuality![0].Head;
        var weakest = develops.Where(g => !(g.Length == 2 && g[0] == parentHead && g[1] == parentHead))
            .Select(Mass).DefaultIfEmpty(0).Min();
        Plan? best = null;
        var alternatives = new List<SichuanFiveBlockAlternative>();
        foreach (var tile in legalTiles)
        {
            if (distances[tile].Ordinary != ordinary) continue;
            var group = develops.FirstOrDefault(g => g.Contains(tile));
            if (completeGroups.Any(g => g.Contains(tile)) && group is null
                && !parent.Singles.Contains(tile)) continue;
            if (oversized.Length > 0 && !oversized.Any(g => g.Contains(tile))) continue;
            if (overloaded && (group is null || Mass(group) > weakest + 1e-9)) continue;
            var remainingGroups = parent.Groups.Select(g => g.ToArray()).ToList();
            var singles = parent.Singles.ToList();
            if (singles.Contains(tile)) singles.Remove(tile);
            else
            {
                var index = remainingGroups.FindIndex(g => !Complete(g) && g.Contains(tile));
                if (index < 0) continue;
                var changed = remainingGroups[index].ToList(); changed.Remove(tile);
                remainingGroups.RemoveAt(index);
                if (changed.Count == 1) singles.Add(changed[0]);
                else if (changed.Count > 1) remainingGroups.Add(changed.ToArray());
            }
            var retained = remainingGroups.Where(g => !Complete(g)).ToArray();
            // The contraction must still support its claimed ordinary route.
            // Do not silently move the head to another block and compare a
            // four-block plan against a five-block plan as if both were full.
            var madeCount = completeGroups.Length + meldCount;
            if (!retained.Any(g => g.Length == 2 && g[0] == g[1])
                || 8 - 2 * madeCount - Math.Min(4 - madeCount, retained.Length - 1) - 1
                    != distances[tile].Ordinary) continue;
            var overflow = Math.Max(0, remainingGroups.Count + meldCount - 5)
                + retained.Sum(g => Math.Max(0, g.Length - 3));
            var afterDiscard = hand.ToArray(); afterDiscard[tile]--;
            var quality = Qualities(retained, singles.ToArray(), completeGroups, true, afterDiscard);
            if (quality.Length == 0) continue;
            var candidate = new Plan(tile, quality, overflow, singles.Count,
                distances[tile].Ordinary, distances[tile].Seven);
            alternatives.Add(new(tile, quality.Select(q => new[] {
                q.Supply, (double)q.Stability, q.Intrinsic, q.Replacement }).ToArray(), singles.Count));
            var comparison = best is null ? 1 : Compare(candidate.Groups, best.Groups);
            if (best is null || comparison > 0 || comparison == 0
                && (candidate.Overflow < best.Overflow || candidate.Overflow == best.Overflow
                    && (candidate.Singles < best.Singles || candidate.Singles == best.Singles
                        && RetainedSingleSupply(singles) > RetainedSingleSupplyFor(best.Tile))))
                best = candidate;
        }
        if (best is null || best.Groups.Length == 0) return null;
        var notes = new List<string>
        {
            "FIVE_BLOCK_PUBLIC_DEVELOPMENT",
            $"普通胡{best.Ordinary}上听；按五组复合结构、公开供牌与候补机会选择",
            $"最弱组发展供应{best.Groups[0].Supply:F1}，候补供应{best.Groups[0].Replacement:F1}；为结构指标，不是胜率"
        };
        if (overloaded) notes.Add("已有副露与暗牌搭子合计超过五组，先处理多余弱搭");
        if (parent.Groups.Length + meldCount < 5)
            notes.Add("现有搭子尚不足五组，保留已成刻子并比较孤张补组，不为凑组拆刻");
        if (oversized.Length > 0) notes.Add("缩减占用四张牌的复合搭子，保留其他组的发展空间");
        if (best.Groups.Any(g => g.Replacement > 0)) notes.Add("分别比较原搭补强与候补替换，候补靠牌后仍须核对实际摸打与整手上听数");
        if (best.Seven > distances.Values.Min(v => v.Seven) && best.Seven < 99)
            notes.Add($"七对退至{best.Seven}上听，明确承担改走普通补成路线的代价");
        return new(best.Tile, best.Ordinary, best.Seven, best.Groups[0].Supply,
            best.Groups[0].Replacement, best.Overflow, notes.ToArray())
            { ParentGroups = parent.Groups.Select(g => g.ToArray()).ToArray(),
              ParentSingles = parent.Singles.ToArray(),
              HeadTile = best.Groups[0].Head,
              RequiredBlocks = best.Groups.Select(q => q.Block.ToArray()).ToArray(),
              ReplacementPaths = ReplacementPathsFor(best.Tile, best.Groups),
              Alternatives = alternatives };

        double PairSupplyFactor(int tile)
        {
            var opponents = Enumerable.Range(0, 4).Where(s => s != state.SeatIndex
                && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
            var clearing = opponents.Count(s => state.DingQueSuits[s] == tile / 9);
            // The book's approximately four own-draw equivalents is a local
            // supply heuristic. Two clearing opponents add a separate channel;
            // the same physical copy is never added to the remaining array.
            return 1 + opponents.Length + 2 * Math.Max(0, clearing - 1);
        }
        double Mass(int[] group)
        {
            var key = string.Join(',', group);
            if (massCache.TryGetValue(key, out var saved)) return saved;
            var value = Completion(group, state.Remaining18);
            massCache[key] = value;
            return value;
        }
        double Completion(int[] group, int[] remaining)
        {
            double value = 0;
            for (var draw = group[0] / 9 * 9; draw < group[0] / 9 * 9 + 9; draw++)
            {
                if (remaining[draw] <= 0 || draw / 9 == state.OwnDingQueSuit) continue;
                double factor = 0;
                for (var a = 0; a < group.Length; a++)
                for (var b = a + 1; b < group.Length; b++)
                {
                    var triple = new[] { group[a], group[b], draw }.Order().ToArray();
                    if (Complete(triple)) factor = Math.Max(factor,
                        triple[0] == triple[2] ? PairSupplyFactor(draw) : 1);
                }
                value += remaining[draw] * factor;
            }
            return value;
        }
        int Stability(int[] group)
        {
            var pair = group.GroupBy(t => t).FirstOrDefault(g => g.Count() >= 2);
            if (group.Length >= 3) return 3 + (pair is not null
                && pair.Key % 9 is 0 or 8 && state.Remaining18[pair.Key] >= 2 ? 1 : 0);
            if (group[0] == group[1]) return state.Remaining18[group[0]] < 2 ? 0
                : group[0] % 9 is 0 or 8 ? 4 : 1;
            // A nominal two-sided taatsu is stable only when both sides
            // actually have supply. A kong or depleted neighboring rank can
            // reduce it to the same single channel as a gap/edge taatsu.
            return group[1] == group[0] + 1 && group[0] % 9 is not (0 or 7)
                && state.Remaining18[group[0] - 1] > 1
                && state.Remaining18[group[1] + 1] > 1 ? 3 : 0;
        }
        Quality[] Qualities(IEnumerable<int[]> groups, int[] singles, int[][] made, bool includeReplacement,
            int[]? wholeHand = null)
        {
            var all = groups.ToArray();
            if (!includeReplacement)
            {
                // Retain the existing partition prior (triplet preservation,
                // fewest singles, flexible groups). This is not the bottleneck
                // assessment: the actual contraction below assigns the head.
                var headTile = all.Where(g => g.Length == 2 && g[0] == g[1])
                    .OrderByDescending(Stability).First()[0];
                return all.Select(g => new Quality(Mass(g), 0, 0, Stability(g), g, headTile))
                    .OrderBy(q => q.Supply).ThenBy(q => q.Stability).ToArray();
            }
            Quality[]? bestRoles = null;
            for (var head = 0; head < all.Length; head++)
            {
                if (all[head].Length != 2 || all[head][0] != all[head][1]) continue;
                // Compare contractions of the selected route with its head
                // intact. Changing the head is a different whole-hand route,
                // not a free way to hide the weak block after each discard.
                if (all[head][0] != parentHead) continue;
                var roles = all.Where((_, i) => i != head).Select(g =>
                {
                    var growth = includeReplacement ? Improvement(g, singles, made, wholeHand!)
                        : (Intrinsic: 0d, Replacement: 0d);
                    return new Quality(Mass(g), growth.Intrinsic, growth.Replacement, Stability(g), g, all[head][0]);
                }).OrderBy(q => q.Supply).ThenBy(q => q.Stability).ThenBy(q => q.Intrinsic)
                    .ThenBy(q => q.Replacement).TakeLast(Math.Max(0, 4 - made.Length - meldCount)).ToArray();
                if (bestRoles is null || Compare(roles, bestRoles) > 0) bestRoles = roles;
            }
            return bestRoles ?? Array.Empty<Quality>();
        }
        (double Intrinsic, double Replacement) Improvement(int[] weak, int[] singles, int[][] made,
            int[] wholeHand)
        {
            var current = Mass(weak);
            var directReplacements = Routes(wholeHand, weak, singles)
                .Where(p => p.Kind == "start_replacement").ToArray();
            double intrinsicSupply = 0, replacementSupply = 0;
            for (var draw = 0; draw < 27; draw++)
            {
                if (state.Remaining18[draw] <= 0 || draw / 9 == state.OwnDingQueSuit) continue;
                var future = state.Remaining18.ToArray(); future[draw]--;
                var intrinsic = current; var replacement = current;
                var extended = weak.Concat(new[] { draw }).Order().ToArray();
                // Direct completion is already counted. All other draws may
                // improve this block with one legal local discard.
                if (!Combinations(extended, 3).Any(Complete))
                    foreach (var retained in Combinations(extended, weak.Length))
                        if (Linked(retained) && !Complete(retained))
                            intrinsic = Math.Max(intrinsic, Completion(retained, future));
                foreach (var path in directReplacements.Where(p => p.Draw == draw))
                {
                    // A spare can form a replacement directly. Only one old
                    // tile is discarded now; its other tile remains a spare.
                    // Check the actual whole-hand distance after this action.
                    replacement = Math.Max(replacement, Completion(path.RetainedBlock, future));
                }
                foreach (var single in singles)
                foreach (var meld in made)
                {
                    // A made triplet does not provide the flexible reserve of
                    // a made sequence. Its neighboring spare is an ordinary
                    // singleton, whose growth remains a later tie-breaker;
                    // do not promote it as sequence-backed block replacement.
                    if (meld[0] == meld[2]) continue;
                    if (single / 9 != meld[0] / 9 || draw / 9 != single / 9) continue;
                    var five = meld.Concat(new[] { single, draw }).Order().ToArray();
                    for (var a = 0; a < 3; a++)
                    for (var b = a + 1; b < 4; b++)
                    for (var c = b + 1; c < 5; c++)
                    {
                        if (!Complete(new[] { five[a], five[b], five[c] })) continue;
                        var two = five.Where((_, i) => i != a && i != b && i != c).ToArray();
                        if (two[1] - two[0] <= 2 && weak.Distinct().Any(discard =>
                        {
                            var after = wholeHand.ToArray(); after[draw]++; after[discard]--;
                            return _distance.CalcStandardShanten(after, meldCount) <= ordinary;
                        })) replacement = Math.Max(replacement, Completion(two, future));
                    }
                }
                if (intrinsic > current + 1e-9) intrinsicSupply += state.Remaining18[draw];
                if (replacement > current + 1e-9)
                    replacementSupply += state.Remaining18[draw];
            }
            return (intrinsicSupply, replacementSupply);
        }
        IReadOnlyList<SichuanBucketBlockPath> Routes(int[] wholeHand, int[] weak, int[] singles)
        {
            if (weak.Length != 2 || singles.Length == 0) return Array.Empty<SichuanBucketBlockPath>();
            var key = string.Join(',', wholeHand) + "/" + string.Join(',', weak) + "/" + string.Join(',', singles);
            if (routeCache.TryGetValue(key, out var saved)) return saved;
            return routeCache[key] = new SichuanBucketBlockRoutes().Analyze(wholeHand,
                state.Remaining18, meldCount, state.OwnDingQueSuit, weak, singles);
        }
        IReadOnlyList<SichuanBucketReplacementPath> ReplacementPathsFor(int discard, Quality[] roles)
        {
            var kept = hand.ToArray(); kept[discard]--;
            var groups = parent.Groups.Select(g => g.ToList()).ToList();
            var singles = parent.Singles.ToList();
            if (singles.Contains(discard)) singles.Remove(discard);
            else
            {
                var group = groups.First(g => !Complete(g.ToArray()) && g.Contains(discard));
                group.Remove(discard); if (group.Count == 1) singles.Add(group[0]);
            }
            var paths = new List<SichuanBucketReplacementPath>();
            foreach (var weak in roles.Where(q => Math.Abs(q.Supply - roles[0].Supply) < 1e-9))
            foreach (var path in Routes(kept, weak.Block, singles.ToArray()))
            {
                if (path.Kind != "start_replacement") continue;
                var future = state.Remaining18.ToArray(); future[path.Draw]--;
                if (Completion(path.RetainedBlock, future) <= weak.Supply + 1e-9) continue;
                var spare = path.RetainedBlock.First(t => singles.Contains(t));
                paths.Add(new(spare, path.Draw, path.Discard, path.RetainedBlock, path.DistanceAfter, path.Copies));
            }
            return paths;
        }
        double RetainedSingleSupply(IEnumerable<int> singles) => singles.Sum(t =>
            Enumerable.Range(t / 9 * 9, 9).Where(n => Math.Abs(n - t) <= 2)
                .Sum(n => state.Remaining18[n]));
        double RetainedSingleSupplyFor(int discard)
        {
            var singles = parent.Singles.ToList();
            if (singles.Contains(discard)) singles.Remove(discard);
            else
            {
                var group = parent.Groups.First(g => !Complete(g) && g.Contains(discard));
                if (group.Length == 2) singles.Add(group.First(t => t != discard || group[0] == group[1]));
            }
            return RetainedSingleSupply(singles);
        }
    }

    private static int Compare(Quality[] a, Quality[] b)
    {
        for (var i = 0; i < Math.Min(a.Length, b.Length); i++)
        {
            var c = a[i].Supply.CompareTo(b[i].Supply); if (c != 0) return c;
            c = a[i].Stability.CompareTo(b[i].Stability); if (c != 0) return c;
            // One draw and one local discard develop this existing block.
            // A spare replacing a whole block needs additional contraction;
            // do not value that longer route as the same immediate event.
            c = a[i].Intrinsic.CompareTo(b[i].Intrinsic); if (c != 0) return c;
            c = a[i].Replacement.CompareTo(b[i].Replacement); if (c != 0) return c;
        }
        return a.Length.CompareTo(b.Length);
    }
    private static bool Complete(int[] group) => group.Length == 3
        && (group[0] == group[2] || group[0] / 9 == group[2] / 9
            && group[1] == group[0] + 1 && group[2] == group[0] + 2);
    private static bool Linked(int[] group) => group[0] / 9 == group[^1] / 9
        && group[^1] - group[0] <= 4
        && group.Distinct().Order().Zip(group.Distinct().Order().Skip(1), (a,b) => b-a).All(gap => gap <= 2)
        && group.All(t => group.Count(n => Math.Abs(n - t) <= 2) >= 2);

    internal static Profile[] Enumerate(int[] hand)
    {
        var key = string.Join(',', hand);
        if (Cache.TryGetValue(key, out var saved)) return saved;
        var counts = hand.ToArray();
        var groups = new List<int[]>(); var singles = new List<int>();
        var result = new List<Profile>(); var nodes = 0; var exceeded = false;
        Search();
        if (exceeded) return Array.Empty<Profile>();
        var value = result.ToArray();
        if (Cache.Count > 4096) Cache.Clear();
        Cache.TryAdd(key, value); return value;
        void Search()
        {
            if (++nodes > 100000) { exceeded = true; return; }
            var first = Array.FindIndex(counts, n => n > 0);
            if (first < 0)
            {
                result.Add(new(groups.Select(g => g.ToArray()).ToArray(), singles.ToArray())); return;
            }
            if (exceeded || singles.Count > 4 || groups.Count > 6) return;
            counts[first]--; singles.Add(first); Search(); singles.RemoveAt(singles.Count - 1); counts[first]++;
            var available = Enumerable.Range(first, Math.Min(first / 9 * 9 + 9, first + 5) - first)
                .SelectMany(t => Enumerable.Repeat(t, counts[t] - (t == first ? 1 : 0))).ToArray();
            foreach (var size in new[] { 2, 3, 4 })
            {
                var seen = new HashSet<string>();
                foreach (var rest in Combinations(available, size - 1))
                {
                    var group = new[] { first }.Concat(rest).ToArray();
                    if (!seen.Add(string.Join(',', group))) continue;
                    var valid = size == 2 ? group[^1] - first <= 2
                        : size == 3 ? Complete(group) || Linked(group)
                        : Linked(group) && !Combinations(group, 3).Any(Complete);
                    if (!valid) continue;
                    foreach (var t in group) counts[t]--;
                    groups.Add(group); Search(); groups.RemoveAt(groups.Count - 1);
                    foreach (var t in group) counts[t]++;
                    if (exceeded) return;
                }
            }
        }
    }
    private static IEnumerable<int[]> Combinations(int[] values, int length)
    {
        var chosen = new int[length];
        return Pick(0, 0);
        IEnumerable<int[]> Pick(int start, int count)
        {
            if (count == length) { yield return chosen.ToArray(); yield break; }
            for (var i = start; i <= values.Length - length + count; i++)
            {
                chosen[count] = values[i];
                foreach (var group in Pick(i + 1, count + 1)) yield return group;
            }
        }
    }
}
