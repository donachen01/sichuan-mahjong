using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Codec;

internal static class BucketTheorySmoke
{
    public static int Run()
    {
        var engine = new SichuanBucketTheoryEngine();
        var a = Hand(11, 16, 17, 18, 18, 22, 24, 10);
        var openA = Hand(14, 14, 14, 19, 19, 19);
        var openB = Hand(14, 14, 14, 23, 23, 23);
        var regular = Evaluate(engine, a, openA, 2, 16);
        var regularGap = Evaluate(engine, a, openA, 2, 22);
        var depleted = Evaluate(engine, a, openB, 2, 16);
        var depletedGap = Evaluate(engine, a, openB, 2, 22);
        if (!regular.Supported || !regularGap.Supported || !depleted.Supported || !depletedGap.Supported
            || !Better(regular, regularGap) || !Better(depletedGap, depleted))
            return Fail($"3-17 A/B dynamic block order: A {Show(regular)}/{Show(regularGap)}, B {Show(depleted)}/{Show(depletedGap)}");

        var d = Hand(12, 13, 17, 17, 18, 18, 22, 24, 25, 26, 24);
        var kong = Hand(11, 11, 11, 11);
        var discardRyanmen = Evaluate(engine, d, kong, 1, 12);
        var discardGap = Evaluate(engine, d, kong, 1, 22);
        if (!discardRyanmen.Supported || !discardGap.Supported || !Better(discardRyanmen, discardGap))
            return Fail($"3-17 D depleted nominal ryanmen: {Show(discardRyanmen)}/{Show(discardGap)}");

        // Seven pairs is a different route; five ordinary blocks must not
        // overrule its closer distance.
        var sevenPairs = Hand(0,0, 2,2, 4,4, 9,9, 11,11, 18,18, 22);
        var excluded = Evaluate(engine, sevenPairs, new int[27], 0, -1);
        if (excluded.Supported) return Fail("seven-pairs route incorrectly bucket-ranked");

        // Exercise the actual discard path. The book omits full opponent
        // histories, so this checks integration and evidence rather than
        // pinning the final discard to its reference answer.
        var hand316 = Hand(9,9,9,12,13,16,17,19,20,20,23,26,26,25);
        var visible316 = new int[27]; visible316[15] = 3;
        var state = SichuanStateCodec.FromRaw(0,0,0,55,hand316,visible316,
            dingQueSuits: [0,1,2,0]);
        state.PolicyVariant = "bucket_disabled";
        var baseline = new SichuanDecisionEngine().DecideDiscard(state);
        state.PolicyVariant = "current";
        var decision = new SichuanDecisionEngine().DecideDiscard(state);
        var bucketCandidates = decision.Candidates.Where(c => c.BucketSupported).ToArray();
        var oldChoice = baseline.Candidates.Single(c => c.TileType == baseline.Action.TileType);
        var newChoice = decision.Candidates.Single(c => c.TileType == decision.Action.TileType);
        // This old textbook reconstruction lacks public discard allocation
        // and has the wrong total wall/hand count. Shape evidence is allowed;
        // full continuation must reject it rather than invent hidden tiles.
        if (bucketCandidates.Length == 0 || bucketCandidates.Any(c => c.Shanten != 2)
            || decision.Action.TileType != baseline.Action.TileType
            || bucketCandidates.Any(c => c.BucketContinuationSamples > 0))
            return Fail($"3-16 depleted 89筒 should replace the dead edge: {baseline.Action.TileType}/{decision.Action.TileType}; shanten={oldChoice.Shanten}/{newChoice.Shanten}; live={oldChoice.LiveUkeire}/{newChoice.LiveUkeire}; bucket={bucketCandidates.Length}; reasons={string.Join("|", decision.Reasons.Take(3))}");

        var hand321 = Hand(0,2,5,5,8,8,11,12,16,16,17);
        var open321 = Hand(9,9,9);
        var breakOverload = Evaluate(engine, hand321, open321, 1, 0);
        var trimEdge = Evaluate(engine, hand321, open321, 1, 17);
        if (!breakOverload.Supported || !trimEdge.Supported
            || breakOverload.CapacityOverflow >= trimEdge.CapacityOverflow)
            return Fail("3-21 exposed meld plus five concealed blocks must reveal overload");
        var hand322 = Hand(1,2,5,6,7,8,8,9,11,11,16,16,17,17);
        var balanced = Evaluate(engine, hand322, new int[27], 0, 16);
        var crowded = Evaluate(engine, hand322, new int[27], 0, 9);
        if (!balanced.Supported || !crowded.Supported
            || balanced.CapacityOverflow >= crowded.CapacityOverflow)
            return Fail("3-22 balanced 2+2+3+3 should not inherit crowded 2+2+2+4 pressure");

        var hand320a = Hand(10,11,11,12,13,13,14,16,19,20,20,24,25,26);
        var state320a = PhysicalState(hand320a, new int[27]);
        var decision320a = new SichuanDecisionEngine().DecideDiscard(state320a);
        if (decision320a.Action.TileType != 11)
            return Fail($"3-20 A one-shanten ready entry regressed: {decision320a.Action.TileType}");

        var hand320c = Hand(12,13,13,14,16,17,17,19,21,22,22,25,25,26);
        var state320c = PhysicalState(hand320c, new int[27]);
        var decision320c = new SichuanDecisionEngine().DecideDiscard(state320c);
        if (decision320c.Action.TileType != 16)
            return Fail($"3-20 C replacement-tile route regressed: {decision320c.Action.TileType}");

        var hand320d = Hand(11,11,11,12,13,13,15,17,19,21,23,24,24,26);
        var visible320d = new int[27]; visible320d[14] = 3;
        var state320d = PhysicalState(hand320d, visible320d);
        var decision320d = new SichuanDecisionEngine().DecideDiscard(state320d);
        var breakWeak45 = Evaluate(engine, hand320d, visible320d, 0, 12);
        var discard9Tiao = Evaluate(engine, hand320d, visible320d, 0, 26);
        if (!breakWeak45.Supported || !discard9Tiao.Supported
            || breakWeak45.TotalImprovementMass <= discard9Tiao.TotalImprovementMass)
            return Fail("3-20 D depleted 45筒 should expose a stronger replacement route");
        if (decision320d.Action.TileType != 12)
            return Fail($"3-20 D must execute the balanced route, not merely expose its evidence: {decision320d.Action.TileType}");

        Console.WriteLine($"bucket_3_5: PASS; incomplete-state guard, 3-17 A/B/D, 3-20 A/C/D final actions, 3-21, 3-22, seven-pairs boundary; 3-20 D current={decision320d.Action.TileType}");
        return 0;
    }

    private static SichuanMahjong.AI.Core.Models.SichuanStateView PhysicalState(int[] hand, int[] observed)
    {
        var visible = observed.ToArray();
        var rivers = Enumerable.Range(0,4).Select(_=>new List<int>()).ToArray();
        for(var t=0;t<27;t++)
            for(var n=0;n<observed[t];n++) rivers[n%4].Add(t);
        for(var t=0;t<9;t++)
            while(rivers.Sum(r=>r.Count)<16 && visible[t]+hand[t]<4)
            { visible[t]++; rivers[rivers.Sum(r=>r.Count)%4].Add(t); }
        var state = SichuanStateCodec.FromRaw(0,0,0,39,hand,visible,
            discards18:rivers, dingQueSuits:[0,2,1,0],handCounts:[14,13,13,13]);
        state.Phase=5; state.TurnIndex=16;
        return state;
    }

    private static SichuanBucketTheorySummary Evaluate(SichuanBucketTheoryEngine engine,
        int[] fullHand, int[] exposed, int melds, int discard)
    {
        var hand = (int[])fullHand.Clone();
        if (discard >= 0) hand[discard]--;
        var remaining = Enumerable.Range(0, 27)
            .Select(tile => Math.Max(0, 4 - fullHand[tile] - exposed[tile])).ToArray();
        return engine.Evaluate(hand, remaining, remaining.Select(n => (double)n).ToArray(), melds, -1);
    }

    private static int[] Hand(params int[] tiles)
    {
        var hand = new int[27];
        foreach (var tile in tiles) hand[tile]++;
        return hand;
    }

    private static bool Better(SichuanBucketTheorySummary a, SichuanBucketTheorySummary b)
        => a.WeakestCompletionMass > b.WeakestCompletionMass + 0.000001
            || Math.Abs(a.WeakestCompletionMass - b.WeakestCompletionMass) <= 0.000001
                && (a.NextCompletionMass > b.NextCompletionMass + 0.000001
                    || Math.Abs(a.NextCompletionMass - b.NextCompletionMass) <= 0.000001
                        && a.TotalImprovementMass > b.TotalImprovementMass + 0.000001);

    private static string Show(SichuanBucketTheorySummary s)
        => $"{s.WeakestCompletionMass:F1}:{s.NextCompletionMass:F1}:{s.TotalImprovementMass:F1}:{s.WeakestTileA}/{s.WeakestTileB}:supported={s.Supported}";

    private static int Fail(string reason)
    {
        Console.Error.WriteLine("bucket_3_5: FAIL " + reason);
        return 1;
    }
}
