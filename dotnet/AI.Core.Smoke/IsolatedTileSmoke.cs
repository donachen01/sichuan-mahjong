using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Engines;

internal static class IsolatedTileSmoke
{
    public static int Run()
    {
        var evaluator = new SichuanIsolatedTileEvaluator();

        // 3-13: the isolated 2筒 is strengthened by the 4/5/6筒 run.
        var hand13 = Hand([19,23,23,23,25,26,26,10,12,13,14]);
        var unseen13 = Enumerable.Range(0,27).Select(t => 4-hand13[t]-(t==17 ? 3 : 0)).ToArray();
        var wall13 = unseen13.Select(n => (double)n).ToArray();
        var wan2 = evaluator.Evaluate(hand13, unseen13, wall13, 19);
        var tong2 = evaluator.Evaluate(hand13, unseen13, wall13, 10);
        if (!wan2.IsIsolated || !tong2.IsIsolated || tong2.RetentionValue <= wan2.RetentionValue)
            return Fail("3-13 sequence-side singleton must have more marginal value");

        // 3-14: 1筒 and 4筒 share 2/3筒; the edge has less unique value.
        var hand14 = Hand([9,12,0,0,2,3,3,8]);
        var unseen14 = Enumerable.Range(0,27).Select(t => 4-hand14[t]-(t==16||t==17 ? 3 : 0)).ToArray();
        var wall14 = unseen14.Select(n => (double)n).ToArray();
        var tong1 = evaluator.Evaluate(hand14, unseen14, wall14, 9);
        var tiao9 = evaluator.Evaluate(hand14, unseen14, wall14, 8);
        if (tong1.RetentionValue >= tiao9.RetentionValue
            || !tong1.Reasons.Contains("孤张进张重叠"))
            return Fail("3-14 shared draws must lower the edge singleton");

        // 3-15 A/B: only the public 6筒 depletion changes. Preserve the
        // ordinary choice, then discard 5筒 when its right-side growth dies.
        var ordinary = Decide15(null);
        var depleted = Decide15(14);
        if (ordinary.Action.TileType != 10 || depleted.Action.TileType != 13)
            return Fail($"3-15 A/B discard {ordinary.Action.TileType}/{depleted.Action.TileType}");
        var a2 = ordinary.Candidates.Single(c => c.TileType == 10);
        var a5 = ordinary.Candidates.Single(c => c.TileType == 13);
        var b2 = depleted.Candidates.Single(c => c.TileType == 10);
        var b5 = depleted.Candidates.Single(c => c.TileType == 13);
        if (a2.Shanten != a5.Shanten || a2.LiveUkeire != a5.LiveUkeire
            || b2.Shanten != b5.Shanten || b2.LiveUkeire != b5.LiveUkeire
            || a2.IsolatedDiscardPriority <= a5.IsolatedDiscardPriority
            || b5.IsolatedDiscardPriority <= b2.IsolatedDiscardPriority)
            return Fail("3-15 isolated tiebreak must be bounded to equal speed");

        // 3-15 C: depleted edge plus independent singleton development,
        // with sufficient draws, may deliberately trade one step for growth.
        var deadEdge = Decide15(6);
        var edgeCandidate = deadEdge.Candidates.Single(c => c.TileType == 8);
        if (!edgeCandidate.Reasons.Any(r => r.Contains("边搭关键进张仅余 1 张")))
            return Fail("3-15 C depleted 8/9 edge must be recognized");
        if (deadEdge.Action.TileType != 8 || !deadEdge.Reasons.Contains("DEPLETED_EDGE_DEVELOPMENT"))
            return Fail("3-15 C must replace the depleted edge with time available");
        var shortWall = Decide15(6, 4);
        if (shortWall.Action.TileType != 10 || shortWall.Reasons.Contains("DEPLETED_EDGE_DEVELOPMENT"))
            return Fail("3-15 C must retain immediate speed with only one own draw");
        Console.WriteLine("isolated_3_4: PASS; A=2筒 B=5筒 C=9条; one-own-draw control=2筒");
        return 0;
    }

    private static SichuanMahjong.AI.Core.Models.SichuanDecisionResult Decide15(int? depleted, int wall = 39)
    {
        var hand = Hand([10,13,2,3,5,5,7,8]);
        var visible = new int[27]; visible[16] = 3; visible[17] = 3;
        var rivers = Enumerable.Range(0,4).Select(_ => new List<int>()).ToArray();
        if (depleted is int tile)
            for (var n = 0; n < 3; n++) { visible[tile]++; rivers[1].Add(tile); }
        // Complete a physical 108-copy public allocation. Other concealed
        // hands account for 39 unseen tiles; no hidden tile identities enter AI.
        var riverCount = 55 - wall;
        foreach (var t in Enumerable.Range(18,9).Concat(new[] { 0,1,4 })
            .Concat(Enumerable.Range(0,18)))
            while (rivers.Sum(r => r.Count) < riverCount && visible[t] + hand[t] < 4)
            { visible[t]++; rivers[rivers.Sum(r => r.Count) % 4].Add(t); }
        var state = SichuanStateCodec.FromRaw(0,0,0,wall,hand,visible,
            discards18: rivers,
            melds18: [new[] { 16,16,16,17,17,17 }, Array.Empty<int>(), Array.Empty<int>(), Array.Empty<int>()],
            dingQueSuits: [2,0,1,0], handCounts: [8,13,13,13]);
        state.Phase = 5; state.TurnIndex = riverCount;
        return new SichuanDecisionEngine().DecideDiscard(state);
    }

    private static int[] Hand(IEnumerable<int> tiles)
    {
        var hand = new int[27];
        foreach (var tile in tiles) hand[tile]++;
        return hand;
    }

    private static int Fail(string detail)
    {
        Console.Error.WriteLine("isolated_3_4: FAIL " + detail);
        return 1;
    }
}
