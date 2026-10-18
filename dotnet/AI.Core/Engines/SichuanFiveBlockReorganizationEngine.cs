using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanFiveBlockOrganization(int Head, int HeadCount, int MissingGroups,
    int Pressure, int Made, int Triplets, int WeakestCopies, int TotalCopies,
    int[][] Groups, int[] Singles, int[][] RequiredBlocks, int[] DrawOnlySupplies);
public sealed record SichuanFiveBlockForwardDraw(int Draw, int Copies, int DistanceAfter,
    int[] Discards, int PressureAfter, int WeakestAfter, int WitnessDiscard);
public sealed record SichuanFiveBlockPengBranch(int Offered, int Copies, int[] PossibleSources,
    int DistanceAfter, int[] Discards, int PressureAfter, int WitnessDiscard);
public sealed record SichuanFiveBlockCandidate(int Tile, int OrdinaryDistance, int SevenDistance,
    int PairCount, int EffectiveCopies, int[] EffectiveTiles,
    SichuanFiveBlockOrganization Best, IReadOnlyList<SichuanFiveBlockOrganization> Organizations)
{
    public IReadOnlyList<SichuanFiveBlockForwardDraw> Forward { get; set; } = Array.Empty<SichuanFiveBlockForwardDraw>();
    public IReadOnlyList<SichuanFiveBlockPengBranch> Peng { get; set; } = Array.Empty<SichuanFiveBlockPengBranch>();
}
public sealed record SichuanFiveBlockReorganization(bool Supported, int Tile, int Head, int HeadCount,
    bool Changed, IReadOnlyList<SichuanFiveBlockCandidate> Candidates, string Status);

/// <summary>
/// Five final roles, not five permanently frozen piles. Each discard receives
/// its own mutually exclusive decompositions and alternative head assignments.
/// Different heads are compared as complete physical organizations, not as a
/// free extra role. Draw-only needs and optional peng channels remain distinct.
/// Unknown copies and conditional draw branches are counts, not win odds or EV.
/// </summary>
public sealed class SichuanFiveBlockReorganizationEngine
{
    private readonly SichuanShantenEngine _distance = new();
    private readonly Dictionary<string, IReadOnlyList<SichuanFiveBlockOrganization>> _organizations = new();

    public IReadOnlyList<SichuanFiveBlockOrganization> Organize(int[] hand, int[] remaining,
        int melds, int missing)
    {
        if (hand.Length != 27 || remaining.Length != 27 || melds is < 0 or > 4
            || hand.Sum() + melds * 3 != 13 || hand.Any(n => n is < 0 or > 4)
            || remaining.Any(n => n is < 0 or > 4)
            || Enumerable.Range(0,27).Any(t => hand[t] + remaining[t] > 4)
            || missing is >= 0 and < 3 && hand.Skip(missing * 9).Take(9).Any(n => n > 0))
            return Array.Empty<SichuanFiveBlockOrganization>();
        var key = string.Join(',', hand) + "/" + string.Join(',', remaining) + "/" + melds + "/" + missing;
        if (_organizations.TryGetValue(key, out var saved)) return saved;
        var standard = _distance.CalcStandardShanten(hand, melds);
        var best = new Dictionary<(int Tile, int Count), SichuanFiveBlockOrganization>();
        foreach (var p in SichuanFiveBlockPlanner.Enumerate(hand))
        {
            var made = p.Groups.Count(Complete) + melds;
            if (made > 4) continue;
            var dev = p.Groups.Where(g => !Complete(g)).ToArray();
            var heads = dev.Select((g,i) => (Tile:g[0], Count:g.Length, Index:i))
                .Where(x => x.Count == 2 && dev[x.Index][1] == x.Tile)
                .Concat(p.Singles.Distinct().Select(t => (Tile:t, Count:1, Index:-1)));
            foreach (var head in heads)
            {
                var blocks = dev.Where((_,i) => i != head.Index).ToArray();
                var need = 4 - made;
                if (8 - 2 * made - Math.Min(need, blocks.Length) - (head.Count == 2 ? 1 : 0) != standard) continue;
                var singles = p.Singles.ToList(); if (head.Count == 1) singles.Remove(head.Tile);
                var ranked = blocks.Select(g => (Group:g, Copies:Completion(g, remaining)))
                    .OrderByDescending(x => x.Copies).ThenBy(x => string.Join(',',x.Group)).ToArray();
                var required = ranked.Take(need).ToArray();
                var weakest = required.Length == 0 ? 99 : required.Min(x => x.Copies);
                if (head.Count == 1) weakest = Math.Min(weakest, remaining[head.Tile]);
                // Extra groups compete for final roles. A fourth tile in an
                // unfinished compound and multiple loose reserves compete for
                // the same limited development space. A fixed kong is a meld.
                var pressure = Math.Max(0, blocks.Length - need)
                    + blocks.Sum(g => Math.Max(0, g.Length - 3)) + Math.Max(0, singles.Count - 1);
                // Labeling 8899 as "889 + spare 9" cannot hide its fourth
                // tile. Count attached reserves back into unfinished groups.
                // A completed 111/123 plus a spare remains a different case.
                pressure += singles.Count(t => blocks.Any(g => g.Length == 3
                    && AttachedUnfinished(g,t)));
                var o = new SichuanFiveBlockOrganization(head.Tile, head.Count,
                    Math.Max(0, need - blocks.Length), pressure, made,
                    p.Groups.Count(g => Complete(g) && g[0] == g[2]), weakest,
                    required.SelectMany(x => CompletionTiles(x.Group, remaining))
                        .Concat(head.Count == 1 && remaining[head.Tile] > 0 ? new[] { head.Tile } : Array.Empty<int>())
                        .Distinct().Sum(t => remaining[t]), p.Groups, singles.ToArray(),
                    required.Select(x => x.Group).ToArray(),
                    required.Where(x => !x.Group.GroupBy(t => t)
                            .Any(g => g.Count() >= 2 && remaining[g.Key] > 0))
                        .Select(x => x.Copies).Order().ToArray());
                var hk = (head.Tile,head.Count);
                if (!best.TryGetValue(hk, out var old) || Compare(o, old) > 0) best[hk] = o;
            }
        }
        return _organizations[key] = best.Values.OrderBy(o => o.Head).ThenByDescending(o => o.HeadCount).ToArray();
    }

    public SichuanFiveBlockReorganization Analyze(SichuanStateView state, IReadOnlyList<int> legal, int incumbent)
    {
        var rows = new List<SichuanFiveBlockCandidate>();
        SichuanFiveBlockReorganization Unsupported(string why) => new(false, incumbent, -1, 0, false, rows, why);
        var h = state.Hand18; var rem = state.Remaining18; var melds = state.OwnMeldCount;
        if (h.Sum() + 3 * melds != 14 || !legal.Contains(incumbent)) return Unsupported("outside_discard_state");
        foreach (var t in legal.Distinct())
        {
            if (t is < 0 or >= 27 || h[t] <= 0) continue;
            var after = h.ToArray(); after[t]--;
            var ordinary = _distance.CalcStandardShanten(after, melds);
            if (ordinary is < 1 or > 3) continue;
            var seven = melds == 0 ? _distance.CalcSevenPairsShanten(after) : 99;
            if (seven < ordinary && seven <= 1) continue;
            var organizations = Organize(after, rem, melds, state.OwnDingQueSuit);
            if (organizations.Count == 0) continue;
            var best = organizations.Aggregate((a,b) => Compare(a,b) >= 0 ? a : b);
            var effective = new List<int>();
            for (var draw = 0; draw < 27; draw++)
            {
                if (rem[draw] <= 0 || draw / 9 == state.OwnDingQueSuit) continue;
                after[draw]++;
                if (_distance.CalcStandardShanten(after, melds) < ordinary) effective.Add(draw);
                after[draw]--;
            }
            rows.Add(new(t, ordinary, seven,
                Enumerable.Range(0,27).Count(tile => after[tile] == 2 && rem[tile] > 0), effective.Sum(d => rem[d]),
                effective.ToArray(), best, organizations));
        }
        var reference = rows.FirstOrDefault(r => r.Tile == incumbent);
        if (reference is null) return Unsupported("reference_outside_structural_phase");
        EnsurePeng(reference);
        var bestRow = reference; var bestRole = reference.Best;
        foreach (var candidate in rows.Where(r => r.Tile != incumbent && r.OrdinaryDistance == reference.OrdinaryDistance))
        {
            var role = candidate.Best;
            var original = reference.Best;
            if (role.MissingGroups > original.MissingGroups || role.HeadCount < original.HeadCount
                || role.Pressure > original.Pressure || role.Triplets < original.Triplets
                || role.WeakestCopies < original.WeakestCopies
                || !DrawOnlyNoWorse(role.DrawOnlySupplies, original.DrawOnlySupplies)
                || role.TotalCopies < original.TotalCopies
                || role.Pressure == original.Pressure && candidate.PairCount < reference.PairCount) continue;
            if (role.Pressure == original.Pressure && role.WeakestCopies == original.WeakestCopies
                && role.TotalCopies == original.TotalCopies
                && CompareDrawOnly(role.DrawOnlySupplies, original.DrawOnlySupplies) <= 0
                && candidate.EffectiveCopies <= reference.EffectiveCopies) continue;
            if (candidate.EffectiveCopies < reference.EffectiveCopies && role.Pressure == original.Pressure
                && role.TotalCopies <= original.TotalCopies
                && CompareDrawOnly(role.DrawOnlySupplies, original.DrawOnlySupplies) <= 0) continue;
            // A local supply total does not justify paying immediate tempo
            // by itself. Require actual capacity relief or publicly depleted
            // support for the tile being released (not merely copies held in
            // our own natural triplet). This also protects flexible reserves.
            if (candidate.EffectiveCopies < reference.EffectiveCopies
                && role.Pressure == original.Pressure && !PubliclyDepletedSupport(candidate.Tile, original)) continue;
            EnsureForward(reference); EnsureForward(candidate);
            EnsurePeng(candidate);
            var advancing = candidate.Forward.Where(d => d.DistanceAfter < candidate.OrdinaryDistance).ToArray();
            var oldAdvancing = reference.Forward.Where(d => d.DistanceAfter < reference.OrdinaryDistance).ToArray();
            if (advancing.Length == 0 || advancing.Any(d => d.PressureAfter < 0)
                || oldAdvancing.Length > 0 && advancing.Max(d => d.PressureAfter)
                    > oldAdvancing.Max(d => d.PressureAfter)) continue;
            if (candidate.Peng.Any(p => reference.Peng.Any(old => old.Offered == p.Offered
                && p.DistanceAfter > old.DistanceAfter))) continue;
            // If several proposals relieve the same capacity pressure, first
            // preserve useful live pairs rather than splitting one just to
            // keep a weaker gap. This is conditional on all preceding whole-
            // hand and supply checks; it is not an unconditional pair bonus.
            var comparison = role.Pressure == bestRole.Pressure
                && role.Pressure < original.Pressure && candidate.PairCount != bestRow.PairCount
                    ? candidate.PairCount.CompareTo(bestRow.PairCount) : Compare(role, bestRole);
            if (bestRow == reference || comparison > 0
                || comparison == 0 && candidate.EffectiveCopies > bestRow.EffectiveCopies)
            { bestRow = candidate; bestRole = role; }
        }
        return new(true, bestRow.Tile, bestRole.Head, bestRole.HeadCount, bestRow.Tile != incumbent, rows,
            bestRow.Tile == incumbent ? "complete_route_retained" : "reorganized_development_tradeoff");

        void EnsureForward(SichuanFiveBlockCandidate candidate)
        {
            if (candidate.Forward.Count > 0) return;
            var after = h.ToArray(); after[candidate.Tile]--;
            var paths = new List<SichuanFiveBlockForwardDraw>();
            for (var draw = 0; draw < 27; draw++)
            {
                if (rem[draw] <= 0 || draw / 9 == state.OwnDingQueSuit) continue;
                var future = rem.ToArray(); future[draw]--;
                var drawn = after.ToArray(); drawn[draw]++;
                var branches = new List<(int Tile, int Distance)>();
                for (var discard = 0; discard < 27; discard++)
                {
                    if (drawn[discard] == 0 || discard / 9 == state.OwnDingQueSuit) continue;
                    drawn[discard]--; branches.Add((discard, _distance.CalcStandardShanten(drawn, melds))); drawn[discard]++;
                }
                if (branches.Count == 0) continue;
                var distance = branches.Min(x => x.Distance);
                var kept = branches.Where(x => x.Distance == distance).Select(x => x.Tile).ToArray();
                SichuanFiveBlockOrganization? bestNext = null;
                var witness = -1;
                // Reorganize whole resulting hands on progressing events.
                // Other draws still retain their complete legal discard set.
                if (distance < candidate.OrdinaryDistance)
                foreach (var discard in kept)
                {
                    drawn[discard]--;
                    foreach (var o in Organize(drawn, future, melds, state.OwnDingQueSuit))
                        if (bestNext is null || Compare(o, bestNext) > 0) { bestNext = o; witness = discard; }
                    drawn[discard]++;
                }
                paths.Add(new(draw, rem[draw], distance, kept, bestNext?.Pressure ?? -1,
                    bestNext?.WeakestCopies ?? -1, witness));
            }
            candidate.Forward = paths;
        }
        void EnsurePeng(SichuanFiveBlockCandidate candidate)
        {
            if (candidate.Peng.Count > 0 || melds >= 4) return;
            var sources = Enumerable.Range(0,4).Where(s => s != state.SeatIndex
                && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
            if (sources.Length == 0) return;
            var after = h.ToArray(); after[candidate.Tile]--;
            var paths = new List<SichuanFiveBlockPengBranch>();
            for (var offered = 0; offered < 27; offered++)
            {
                // This channel develops an actual pair. A natural triplet
                // already occupies a made-set role; its fourth copy belongs
                // to gang/hu analysis, not another mandatory peng benefit.
                if (after[offered] != 2 || rem[offered] <= 0 || offered / 9 == state.OwnDingQueSuit) continue;
                var future = rem.ToArray(); future[offered]--;
                after[offered] -= 2;
                var branches = new List<(int Tile,int Distance)>();
                for (var discard = 0; discard < 27; discard++)
                {
                    if (after[discard] <= 0 || discard / 9 == state.OwnDingQueSuit) continue;
                    after[discard]--; branches.Add((discard,_distance.CalcStandardShanten(after,melds+1))); after[discard]++;
                }
                if (branches.Count == 0) { after[offered] += 2; continue; }
                var distance = branches.Min(b => b.Distance);
                var kept = branches.Where(b => b.Distance == distance).Select(b => b.Tile).ToArray();
                SichuanFiveBlockOrganization? bestNext = null; var witness = -1;
                foreach (var discard in kept)
                {
                    after[discard]--;
                    foreach (var o in Organize(after,future,melds+1,state.OwnDingQueSuit))
                        if (bestNext is null || Compare(o,bestNext)>0) { bestNext=o; witness=discard; }
                    after[discard]++;
                }
                paths.Add(new(offered,rem[offered],sources,distance,kept,bestNext?.Pressure??-1,witness));
                after[offered] += 2;
            }
            candidate.Peng = paths;
        }
        bool PubliclyDepletedSupport(int tile, SichuanFiveBlockOrganization organization)
        {
            // A spare may lean on a pair in another head arrangement. Test
            // actual held partners too; requiring it to occur inside the
            // selected group's label would hide exactly this weak reserve.
            foreach (var other in Enumerable.Range(tile / 9 * 9,9).Where(t => t != tile && h[t] > 0))
            {
                var ends = Enumerable.Range(tile / 9 * 9,9)
                    .Where(t => Complete(new[] {tile,other,t}.Order().ToArray())).ToArray();
                if (ends.Length > 0 && ends.All(t => rem[t] <= 1)
                    && ends.Any(t => state.Visible18[t] >= 3)) return true;
            }
            return false;
        }
    }
    private static int Compare(SichuanFiveBlockOrganization a, SichuanFiveBlockOrganization b)
    {
        var c = b.MissingGroups.CompareTo(a.MissingGroups); if (c != 0) return c;
        c = b.Pressure.CompareTo(a.Pressure); if (c != 0) return c;
        c = a.HeadCount.CompareTo(b.HeadCount); if (c != 0) return c;
        c = a.Triplets.CompareTo(b.Triplets); if (c != 0) return c;
        // Do not make "fewer draw-only blocks" an unconditional pair bonus:
        // discarding a real two-sided block into spare labels loses supply.
        c = a.TotalCopies.CompareTo(b.TotalCopies); if (c != 0) return c;
        c = CompareDrawOnly(a.DrawOnlySupplies, b.DrawOnlySupplies); if (c != 0) return c;
        c = a.WeakestCopies.CompareTo(b.WeakestCopies); if (c != 0) return c;
        return 0;
    }
    private static bool DrawOnlyNoWorse(int[] a, int[] b)
        => a.Length <= b.Length && Enumerable.Range(0,a.Length).All(i => a[i] >= b[i]);
    private static int CompareDrawOnly(int[] a, int[] b)
    {
        var c = b.Length.CompareTo(a.Length); if (c != 0) return c;
        for (var i = 0; i < a.Length; i++) { c = a[i].CompareTo(b[i]); if (c != 0) return c; }
        return 0;
    }
    private static int Completion(int[] group, int[] remaining)
        => CompletionTiles(group, remaining).Sum(t => remaining[t]);
    private static IEnumerable<int> CompletionTiles(int[] group, int[] remaining)
        => Enumerable.Range(0,27).Where(t => remaining[t] > 0 && group
            .SelectMany((a,i) => group.Skip(i+1).Select(b => new[] {a,b,t}.Order().ToArray())).Any(Complete))
            ;
    private static bool Complete(int[] g) => g.Length == 3 && (g[0] == g[2]
        || g[0] / 9 == g[2] / 9 && g[1] == g[0] + 1 && g[2] == g[0] + 2);
    private static bool AttachedUnfinished(int[] group, int spare)
    {
        var four = group.Append(spare).Order().ToArray();
        return four[0] / 9 == four[3] / 9 && four[3] - four[0] <= 4
            && four.Distinct().Order().Zip(four.Distinct().Order().Skip(1),(a,b)=>b-a).All(gap=>gap<=2)
            && four.All(t => four.Count(n => Math.Abs(n-t) <= 2) >= 2)
            && !Enumerable.Range(0,4).Any(omit => Complete(four.Where((_,i)=>i!=omit).ToArray()));
    }
}
