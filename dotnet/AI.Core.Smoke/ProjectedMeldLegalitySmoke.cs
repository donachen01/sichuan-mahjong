using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Engines;

internal static class ProjectedMeldLegalitySmoke
{
    public static int Run()
    {
        int checks = 0;
        var failures = new List<string>();
        void Check(bool ok, string reason) { checks++; if (!ok) failures.Add(reason); }
        var evaluator = new SichuanMeldCounterfactualEvaluator();
        foreach (int rotation in Enumerable.Range(0, 3))
        {
            int Map(int t) => (t + rotation * 9) % 27;
            var invalid = LegalReadyValueSmoke.Fixture(rotation, true);
            var root = string.Join(',', invalid.Hand18);
            var continuing = evaluator.Evaluate(invalid, "continue", -1, 0, 3, 0, 0, 0, plannedDiscardTile: Map(12));
            Check(continuing.Shanten > 0, $"rotation{rotation}: continuation protects owned fifth-copy pseudo-wait");
            Check(new SichuanAiFacade().DecideSelfAction(invalid, false, [], []).ShantenAfter > 0,
                $"rotation{rotation}: actual self-action continue still pseudo-ready");
            Check(string.Join(',', invalid.Hand18) == root, "hypothetical action mutated root");
            var waiting = LegalReadyValueSmoke.Fixture(rotation, true, 1);
            waiting.Hand18[Map(12)]--;
            waiting.Visible18[Map(12)]++;
            waiting.HandCounts[0]--;
            waiting.Phase = 6;
            var pass = new SichuanAiFacade().DecideReaction(waiting, Map(12), false, false, false, 1);
            Check(pass.CurrentShanten > 0 && pass.ShantenAfter > 0,
                $"rotation{rotation}: actual reaction pass still protects fifth-copy pseudo-ready");
            // Move the previous Peng back to its pre-claim public context:
            // two copies concealed, the third source discard, two old Gangs.
            invalid.Hand18[Map(8)] += 2;
            invalid.Visible18[Map(8)] -= 2;
            invalid.HandCounts[0] += 2;
            invalid.MeldViews[0].RemoveAll(m => m.TileType == Map(8));
            invalid.Melds18[0].RemoveAll(t => t == Map(8));
            Check(invalid.Hand18.Sum() == 7 && invalid.OwnMeldCount == 2
                && Enumerable.Range(0, 27).All(t => invalid.Hand18[t] + invalid.Visible18[t] + invalid.Remaining18[t] == 4), "pre-Peng physical108 public projection");
            var peng = evaluator.Evaluate(invalid, "peng", Map(8), 2, 3, 0, 0, 0, plannedDiscardTile: Map(12));
            Check(peng.Shanten > 0, $"rotation{rotation}: projected Peng did not include actual Gangs in wait capacity");
            var dead = LegalReadyValueSmoke.Fixture(rotation, false);
            var preserved = evaluator.Evaluate(dead, "continue", -1, 0, 4, 0, 0, 0, plannedDiscardTile: Map(12));
            Check(preserved.Shanten == 0 && preserved.LiveUkeire == 0 && preserved.ReplacementWinProbability == 0,
                "legal dead wait must stay ready without fabricated future wins");
            var missing = GangPublicWallSmoke.Fixture(rotation);
            missing.DingQueSuits[0] = (rotation + 1) % 3;
            var belief = new SichuanBeliefEngine().Build(missing);
            var wall = new SichuanWallAvailabilityEngine().Build(missing, belief);
            Check(wall.ExpectedCounts18[Map(15)] > 0, "missing-suit structural replacement win has positive model mass");
            var gang = evaluator.Evaluate(missing, "an_gang", Map(0), 4, 1, 0, 0, 0, belief);
            Check(gang.ReplacementWinProbability == 0 && gang.ReplacementWinGain == 0,
                $"rotation{rotation}: Gang replacement paid illegal missing-suit structural Hu ({gang.ReplacementWinProbability})");
        }
        foreach (var failure in failures) Console.Error.WriteLine(failure);
        Console.WriteLine($"PROJECTED_MELD_LEGALITY {(failures.Count == 0 ? "PASS" : "FAIL")} checks={checks} failures={failures.Count}; physical108 public contexts, exact future own melds and missing-suit Hu; not strength");
        return failures.Count == 0 ? 0 : 1;
    }
}
