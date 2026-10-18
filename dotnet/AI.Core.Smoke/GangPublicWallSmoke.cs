using System.Reflection;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;

internal static class GangPublicWallSmoke
{
    public static int Run()
    {
        int checks = 0;
        void Check(bool value, string reason) { checks++; if (!value) throw new Exception(reason); }
        try
        {
            var engine = new SichuanWallAvailabilityEngine();
            var updated = typeof(SichuanWallAvailabilityEngine).GetMethod("AfterHypotheticalOwnDraw");
            var legacy = typeof(SichuanMeldCounterfactualEvaluator).GetMethod("RemoveWallTile", BindingFlags.NonPublic | BindingFlags.Static);
            foreach (int rotation in Enumerable.Range(0, 3))
            {
                var state = Fixture(rotation);
                var fingerprint = Fingerprint(state);
                var belief = new SichuanBeliefEngine().Build(state);
                var before = engine.Build(state, belief);
                Check(Math.Abs(before.ExpectedCounts18.Sum() - state.WallCount) < 1e-8, "root wall mass");
                Check(before.KnownWallCounts18.Sum() == 2, "root fixture did not exercise guaranteed wall copies");
                foreach (int draw in Enumerable.Range(0, 27).Where(t => before.ExpectedCounts18[t] > 0)
                    .OrderBy(t => before.ExpectedCounts18[t]))
                {
                    var after = (SichuanWallAvailability)(updated is not null
                        ? updated.Invoke(engine, [state, belief, draw])!
                        : legacy!.Invoke(null, [before, draw])!);
                    var capacity = state.Remaining18.ToArray(); capacity[draw]--;
                    var known = before.KnownWallCounts18.ToArray(); if (known[draw] > 0) known[draw]--;
                    Check(Math.Abs(after.ExpectedCounts18.Sum() - (state.WallCount - 1)) < 1e-8, "replacement wall mass");
                    foreach (int tile in Enumerable.Range(0, 27))
                    {
                        Check(after.ExpectedCounts18[tile] + 1e-8 >= known[tile],
                            $"Known wall diluted after replacement: draw={draw}, known tile={tile}, expected={after.ExpectedCounts18[tile]:R}, lower={known[tile]}");
                        Check(after.ExpectedCounts18[tile] <= capacity[tile] + 1e-8, "replacement expectation exceeds unseen physical copies");
                        Check(after.RepresentativeCounts18[tile] >= known[tile] && after.RepresentativeCounts18[tile] <= capacity[tile], "representative violates public copy bounds");
                        Check(after.KnownWallCounts18[tile] == known[tile], "replacement forgot known public copies");
                    }
                    Check(after.RepresentativeCounts18.Sum() == state.WallCount - 1, "replacement integer wall quota");
                    Check(Fingerprint(state) == fingerprint, "replacement mutated root observation");
                }
                var evaluated = new SichuanMeldCounterfactualEvaluator().Evaluate(state, "an_gang", rotation * 9, 4, 1, 0, 0, 0, belief);
                var result = new SichuanAiFacade().DecideSelfAction(state, false, [rotation * 9], []);
                Check(evaluated.ContinuationWallCount == state.WallCount - 1, "gang consumed wrong number of wall tiles");
                Check(result.CandidateReasons["an_gang:" + rotation * 9].Contains("GANG_REPLACEMENT_PUBLIC_WALL_REBUILT"), "real self-action did not use constrained replacement branch");
                // Remove only public clearing evidence; the suit is no longer
                // guaranteed to be in the wall. No artificial private labels.
                state.PublicEvents.Clear(); foreach (var river in state.Discards18) river.Clear();
                var unproved = engine.Build(state, new SichuanBeliefEngine().Build(state));
                Check(unproved.KnownWallCounts18.Sum() == 0, "missing public proof did not exit known-wall assertion");
            }
            Console.WriteLine($"GANG_PUBLIC_WALL PASS checks={checks}; actual self-action, public-known ablation, capacity and mass; not probability calibration");
            return 0;
        }
        catch (Exception e) { Console.Error.WriteLine($"GANG_PUBLIC_WALL FAIL after {checks} checks: {e.Message}"); return 1; }
    }

    private static string Fingerprint(SichuanStateView s) => string.Join(',', s.Hand18) + "|" + string.Join(',', s.Remaining18)
        + "|" + string.Join(',', s.Visible18) + "|" + s.WallCount + "|" + string.Join(',', s.PublicEvents);

    internal static SichuanStateView Fixture(int rotation)
    {
        int Map(int t) => (t + 9 * rotation) % 27;
        var hand = new int[27];
        foreach (int t in new[] { 0, 0, 0, 0, 2, 2, 2, 3, 4, 5, 5, 6, 7, 15 }) hand[Map(t)]++;
        var pool = Enumerable.Range(0, 27).Select(t => 4 - hand[t]).ToArray();
        var wall = new[] { 2, 7, 10, 19, 25 }.Select(Map).ToArray();
        foreach (int t in wall) pool[t]--;
        var hidden = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
        for (int seat = 1; seat < 4; seat++)
        for (int n = 0; n < 13; n++)
        {
            int t = Enumerable.Range(0, 27).Where(t => pool[t] > 0 && t / 9 != rotation)
                .OrderBy(t => (t - rotation * 9 + 27) % 27).First();
            pool[t]--; hidden[seat][t]++;
        }
        var s = SichuanStateCodec.FromRaw(0, 0, 0, wall.Length, hand, pool,
            dingQueSuits: [(rotation + 2) % 3, rotation, rotation, rotation], handCounts: [14, 13, 13, 13]);
        s.Phase = 5; long index = 0;
        for (int t = 0; t < 27; t++)
        for (int n = 0; n < pool[t]; n++)
        {
            int seat = (int)(index % 4); s.Discards18[seat].Add(t);
            s.PublicEvents.Add(new(++index, (int)index, seat, SichuanPublicEventType.Discard, t));
        }
        for (int t = 0; t < 27; t++)
            if (hand[t] + hidden.Sum(h => h[t]) + pool[t] + wall.Count(v => v == t) != 4)
                throw new Exception("Synthetic fixture does not conserve physical108");
        return s;
    }
}
