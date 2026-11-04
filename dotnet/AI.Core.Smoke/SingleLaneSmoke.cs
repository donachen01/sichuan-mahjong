using System.Diagnostics;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Strategy;

internal static class SingleLaneSmoke
{
    public static int Run()
    {
        var failures = new List<string>();
        var watch = Stopwatch.StartNew();
        var strongTiles = new[] { 0, 0, 1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 9, 10 };
        var strong = Make(strongTiles);
        var evaluator = new SichuanSingleLaneEvaluator();
        var modelWatch = Stopwatch.StartNew();
        var values = Evaluate(strong, evaluator);
        Console.WriteLine($"single_lane_model_ms={modelWatch.ElapsedMilliseconds}");
        Check(values[10].Value > values[0].Value, "strong lane should preserve a useful target pair", failures);
        var safeExit = Make(strongTiles, safeExit: true);
        var strongResult = new SichuanAiFacade().DecideDiscard(safeExit);
        Check(strongResult.Action.TileType / 9 != 0, "real facade should keep strong lane", failures);
        Check(strongResult.Reasons.Any(r => r.Contains("单行道") || r.StartsWith("SINGLE_LANE_"))
            || strongResult.Candidates.Any(c => c.Reasons.Any(r => r.Contains("单行道"))), "lane reasoning missing from actual decision", failures);
        foreach (var v in values) Console.WriteLine($"lane_tile={v.Key}; target={v.Value.TargetShanten}; modeled={v.Value.ModeledCompletion:F3}; freedom={v.Value.FutureDiscardFreedom:F3}; EV={v.Value.Value:F3}");
        foreach (var c in strongResult.Candidates.Take(5)) Console.WriteLine($"candidate={c.TileType}; score={c.Score}; unified={c.UnifiedActionValue:F3}; shanten={c.Shanten}");
        Console.WriteLine($"strong_discard={strongResult.Action.TileType}; keep_EV={values[10].Value:F3}; break_pair_EV={values[0].Value:F3}");

        var weak = Make(new[] { 0, 8, 9, 9, 10, 11, 12, 13, 14, 15, 15, 16, 17, 17 });
        var weakResult = new SichuanAiFacade().DecideDiscard(weak);
        Check(weakResult.Action.TileType / 9 == 0, "weak lane must retain ordinary Hu exit", failures);
        Console.WriteLine($"weak_discard={weakResult.Action.TileType}");

        var dead = Make(strongTiles, deadLane: true);
        var deadValues = Evaluate(dead, evaluator);
        Check(deadValues.Values.All(v => v.ModeledCompletion == 0 && v.Value <= 0), "dead copies should not earn lane reward", failures);
        var cleared = Make(strongTiles, cleared: true);
        var clearedValues = Evaluate(cleared, evaluator);
        Check(clearedValues[10].ExpectedOffers < values[10].ExpectedOffers, "three public clearances should remove held-tile supply", failures);
        Console.WriteLine($"uncleared_offers={values[10].ExpectedOffers:F3}; cleared_offers={clearedValues[10].ExpectedOffers:F3}; dead_max_EV={deadValues.Values.Max(v => v.Value):F3}");

        // A later forced discard of a newly drawn missing tile does not undo
        // earlier public proof that the concealed hand had cleared that suit.
        cleared.Discards18[1].Add(0);
        cleared.PublicEvents.Add(new(10, 10, 1, SichuanPublicEventType.Discard, 0, SichuanTileOrigin.Draw));
        Check(SichuanMahjong.AI.Core.Inference.SichuanOpponentTimeline.MustHaveClearedMissing(cleared, 1),
            "forced missing-suit draw-discard incorrectly erased earlier clearance", failures);

        var late = Make(strongTiles, late: true);
        var lateValues = Evaluate(late, evaluator);
        Check(lateValues.Values.All(v => v.ModeledCompletion == 0), "insufficient draw budget must stop flush investment", failures);
        var forced = Make(new[] { 0, 0, 1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 9, 18 });
        Check(Evaluate(forced, evaluator).Count == 0, "unresolved own missing suit must disable lane investment", failures);
        Check(new SichuanAiFacade().DecideDiscard(forced).Action.TileType == 18, "real facade ignored compulsory discard", failures);
        var notLane = Make(strongTiles); notLane.DingQueSuits[3] = 1;
        Check(Evaluate(notLane, evaluator).Count == 0, "two missing opponents are not the three-opponent lane", failures);
        var mixedMeld = Make(strongTiles);
        mixedMeld.Melds18[0].AddRange(new[] { 11, 11, 11 });
        mixedMeld.MeldViews[0].Add(new SichuanMeldView(SichuanMeldType.Peng, 11, 1, 4));
        Check(Evaluate(mixedMeld, evaluator).Count == 0, "mixed exposed suit cannot earn flush reward", failures);
        Check(values.Values.All(v => double.IsFinite(v.Value) && v.ModeledCompletion is >= 0 and <= 1), "invalid modeled value", failures);
        CheckPhasedPolicy(failures);
        Console.WriteLine($"SINGLE_LANE_CHECKS elapsed_ms={watch.ElapsedMilliseconds}; failures={failures.Count}");
        foreach (var failure in failures) Console.Error.WriteLine(failure);
        return failures.Count == 0 ? 0 : 1;
    }

    private static void CheckPhasedPolicy(List<string> failures)
    {
        var state = Make([0, 0, 2, 4, 5, 6, 8, 9, 12, 13, 14, 16, 16, 17]);
        var phase = SichuanPhasedSingleLanePolicy.Describe(state);
        Check(phase.Early && phase.AuxiliaryLooseDiscards.SequenceEqual([9, 17]),
            "early loose auxiliary candidates must exclude the formed 456 sequence and the pair", failures);
        var lane = new SichuanCandidateDetail { TileType = 8, Shanten = 1, LiveUkeire = 8 };
        var loose = new SichuanCandidateDetail { TileType = 9, Shanten = 1, LiveUkeire = 6 };
        var formed = new SichuanCandidateDetail { TileType = 13, Shanten = 1, LiveUkeire = 9 };
        Check(new SichuanDiscardArbiter([lane, loose, formed], 8).Resolve(phase: phase) == 9,
            "early preference should retain the lane and the auxiliary sequence", failures);
        Check(new SichuanDiscardArbiter([lane, formed], 8).Resolve(phase: phase) == 8,
            "early preference should allow lane discard when only auxiliary structure is available", failures);

        SichuanDecisionCandidate Ready(int discard, int wait, double mass, double win, double draw) =>
            new(new SichuanAction(SichuanActionType.Discard, discard), 1, 1, 0, 0, 0, 0, 0, 0, [])
            {
                ReadyPrice = new([new(wait, 0, 1, 2, mass)], mass, 0, 1, 2),
                ModeledOwnWinProbability = win, ModeledSelfDrawProbability = draw
            };
        var auxiliaryWait = Ready(8, 9, 3, .30, .30);
        var independentWait = Ready(9, 8, 1, .30, .10);
        Check(SichuanPhasedSingleLanePolicy.PreferReadyWait(0, auxiliaryWait, [independentWait]) == independentWait,
            "narrower independent wait should win on modeled opponent supply at equal value", failures);
        Check(SichuanPhasedSingleLanePolicy.PreferReadyWait(0, auxiliaryWait, [Ready(9, 8, 0, .30, .10)]) is null,
            "dead lane wait must not get the preference", failures);

        var peng = Make([0, 0, 0, 1, 2, 3, 4, 5, 7, 7, 8, 12, 12], safeExit: false);
        peng.Visible18[12] = 1;
        peng.Remaining18[12] = 1;
        peng.Phase = 6;
        var result = new SichuanAiFacade().DecideReaction(peng, 12, false, true, false, 1);
        Check(result.Action.ActionType == SichuanActionType.Peng && result.PlannedDiscardTile is >= 0 and < 9,
            "valuable last auxiliary pair must be able to Peng and discard from the independent suit", failures);
    }

    private static IReadOnlyDictionary<int, SichuanSingleLaneValue> Evaluate(SichuanStateView state, SichuanSingleLaneEvaluator evaluator)
    {
        var belief = new SichuanBeliefEngine().Build(state);
        return evaluator.EvaluateDiscards(state, belief, new SichuanWallAvailabilityEngine().Build(state, belief));
    }

    private static SichuanStateView Make(int[] tiles, bool deadLane = false, bool cleared = false, bool late = false, bool safeExit = false)
    {
        var hand = SichuanTileCodec.BuildCount18(tiles);
        var visible = new int[27];
        if (deadLane)
            for (var t = 0; t < 9; t++) visible[t] = 4 - hand[t];
        if (cleared) { visible[12]++; visible[13]++; visible[14]++; }
        if (safeExit) visible[10] = 3;
        if (late)
        {
            var needed = 108 - hand.Sum() - 39 - 7;
            foreach (var t in Enumerable.Range(0, 27).OrderByDescending(t => t / 9))
            {
                var count = Math.Min(needed, 4 - hand[t]); visible[t] += count; needed -= count;
                if (needed == 0) break;
            }
        }
        var state = SichuanStateCodec.FromRaw(0, 0, 0, 108 - hand.Sum() - visible.Sum() - 39,
            hand, visible, dingQueSuits: new[] { 2, 0, 0, 0 }, handCounts: new[] { tiles.Length, 13, 13, 13 });
        state.RoundIndex = 27;
        if (cleared)
            for (var s = 1; s < 4; s++)
            {
                state.Discards18[s].Add(11 + s);
                state.PublicEvents.Add(new(s, s, s, SichuanPublicEventType.Discard, 11 + s));
            }
        if (safeExit)
            for (var s = 1; s < 4; s++)
            {
                state.Discards18[s].Add(10);
                state.PublicEvents.Add(new(s, s, s, SichuanPublicEventType.Discard, 10));
            }
        return state;
    }

    private static void Check(bool okay, string message, List<string> failures)
    { if (!okay) failures.Add(message); }
}
