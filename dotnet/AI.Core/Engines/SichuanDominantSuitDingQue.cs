namespace SichuanMahjong.AI.Core.Engines;

// Opening qualitative policy. No opponent hand, future wall or unrevealed
// missing suit is an input. Ordinal structure classes are not probabilities.
internal static class SichuanDominantSuitDingQue
{
    internal sealed record Choice(int MissingSuit, string Explanation);
    private sealed record Shape(int Class, int DirectCopies, int Extension,
        int Competition, string Name);

    // Bounded application of the discussed 7/3/3 openings: keeping two
    // main-suit melds consumes six tiles and leaves no independent head.
    // Raw pairs used by those melds must not exclude the side-pair route.
    // This is a declared development preference, not a Gang probability/EV.
    internal static Choice? PreferPairAfterMainMelds(IReadOnlyList<int> hand, IReadOnlyList<string> suitNames)
    {
        if (hand.Sum() != 13) return null;
        var sizes = Enumerable.Range(0, 3).Select(s => hand.Skip(s * 9).Take(9).Sum()).ToArray();
        var main = Array.IndexOf(sizes, 7);
        if (main < 0 || sizes.Where((_, s) => s != main).Any(n => n != 3)) return null;
        var pairSuits = Enumerable.Range(0, 3).Where(s => s != main
            && hand.Skip(s * 9).Take(9).Any(n => n == 2)).ToArray();
        if (pairSuits.Length != 1) return null;
        var pairSuit = pairSuits[0];
        var other = Enumerable.Range(0, 3).Single(s => s != main && s != pairSuit);
        var side = Enumerable.Range(other * 9, 9).Where(t => hand[t] > 0).Select(t => t % 9).ToArray();
        if (side.Length != 3 || side[2] - side[0] == 2
            || !Pairs(side).Any(p => p.b == p.a + 1 && p.a > 0 && p.b < 8)) return null;
        var local = hand.Skip(main * 9).Take(9).ToArray();
        // An existing four-copy asset needs its own analysis, outside this case.
        if (local.Any(n => n == 4) || MadeMelds(local) != 2) return null;
        var shanten = new SichuanShantenEngine();
        if (shanten.CalcLegalShanten(hand.ToArray(), 0, other, true)
            > shanten.CalcLegalShanten(hand.ToArray(), 0, pairSuit, true)) return null;
        return new(other, $"一门占优7/3/3：{suitNames[main]}保留两副互斥现成面子，"
            + "主门仅余一张，面子占用的原始对子不重复计作将；"
            + $"保留{suitNames[pairSuit]}的对子兼顾作将、碰刻及后续取得第四张的杠机会；"
            + "两副门清缺张数相同，当前合法结构距离不增加；这是发展取向，不是必碰、必杠或确定杠收入");
    }

    private static int MadeMelds(int[] hand)
    {
        var t = Array.FindIndex(hand, n => n > 0);
        if (t < 0) return 0;
        hand[t]--; var best = MadeMelds(hand); hand[t]++;
        if (hand[t] >= 3)
        {
            hand[t] -= 3; best = Math.Max(best, 1 + MadeMelds(hand)); hand[t] += 3;
        }
        if (t <= 6 && hand[t + 1] > 0 && hand[t + 2] > 0)
        {
            hand[t]--; hand[t + 1]--; hand[t + 2]--;
            best = Math.Max(best, 1 + MadeMelds(hand));
            hand[t]++; hand[t + 1]++; hand[t + 2]++;
        }
        return best;
    }

    internal static Choice? Compare(IReadOnlyList<int> hand, int[] distances, IReadOnlyList<string> suitNames)
    {
        if (hand.Sum() is not (13 or 14)) return null;
        var sizes = Enumerable.Range(0, 3).Select(s => Enumerable.Range(s * 9, 9).Sum(t => hand[t])).ToArray();
        var main = Array.IndexOf(sizes, sizes.Max());
        if (sizes[main] < 7) return null;
        var sides = Enumerable.Range(0, 3).Where(s => s != main).ToArray();
        int missing;
        string reason;
        if (sizes[sides[0]] != sizes[sides[1]])
        {
            missing = sizes[sides[0]] < sizes[sides[1]] ? sides[0] : sides[1];
            reason = "副门数量不同，优先减少清缺占用的摸打机会";
        }
        else
        {
            // This chapter supports small equal side suits. Equal four-card
            // suits and balanced openings continue through the general engine.
            if (sizes[sides[0]] is not (2 or 3)) return null;
            var left = Describe(hand, sides[0]);
            var right = Describe(hand, sides[1]);
            if (left.Class == right.Class && left.Class is not (0 or 1 or 2 or 3)) return null;
            var comparison = left.Class.CompareTo(right.Class);
            var detail = "";
            if (comparison == 0 && sizes[sides[0]] == 3 && left.Class is 2 or 3)
            {
                var l = Enumerable.Range(sides[0] * 9, 9).Select(t => hand[t]).ToArray();
                var r = Enumerable.Range(sides[1] * 9, 9).Select(t => hand[t]).ToArray();
                comparison = left.Class == 2 ? ComparePairSingles(l, r) : CompareSequenceSingles(l, r);
                detail = left.Class == 2
                    ? "；同档对子比较边界类别、顺子连接与碰后单张的剩余组顺空间"
                    : "；同档两面先比较孤张发展空间，再减少新旧搭子的进张争用，最后比较互斥延展";
                // A tied specialist comparison is genuinely unresolved; don't
                // let an unrelated direct-copy metric reverse its priorities.
                if (comparison == 0) return null;
            }
            else if (comparison == 0 && left.Class is 2 or 3) return null;
            if (comparison == 0 && left.Class == 0)
                comparison = left.Competition.CompareTo(right.Competition);
            if (comparison == 0) comparison = right.DirectCopies.CompareTo(left.DirectCopies);
            if (comparison == 0) comparison = right.Extension.CompareTo(left.Extension);
            if (comparison == 0) return null;
            // Smaller comparison means the left side is better to keep.
            missing = comparison < 0 ? sides[1] : sides[0];
            reason = $"等张数副门互斥结构比较：{suitNames[sides[0]]}={left.Name}（成组余张{left.DirectCopies}、延展量{left.Extension}、顺子占用组合{left.Competition}），"
                + $"{suitNames[sides[1]]}={right.Name}（成组余张{right.DirectCopies}、延展量{right.Extension}、顺子占用组合{right.Competition}）；"
                + "对子保留碰牌/作将退路，暗刻同档比较第四张的结构竞争，指标不是释放概率" + detail;
        }
        // A local preference must not sacrifice a closer complete retained
        // route (including seven pairs). Do not force the source's ranking
        // when its full-hand premise is broken.
        if (distances[missing] > sides.Min(s => distances[s])) return null;
        return new(missing, $"一门占优（主门{sizes[main]}张）：{reason}；整手向听未倒退");
    }

    private static int ComparePairSingles(int[] left, int[] right)
    {
        (bool boundary, int connection, int afterClaim) Features(int[] h)
        {
            var pair = Array.FindIndex(h, n => n == 2);
            var single = Array.FindIndex(h, n => n == 1);
            var boundary = pair is <= 1 or >= 7;
            var a = Math.Min(pair, single);
            var b = Math.Max(pair, single);
            var sequenceWaits = Waits(a, b).ToArray();
            // For boundary pairs, an edge connection is not a flexible
            // alternative to claiming: the claim consumes its key neighbor.
            var edge = b == a + 1 && (a == 0 || b == 8);
            var connection = boundary && edge ? 0 : sequenceWaits.Sum(t => 4 - h[t]);
            var supply = Enumerable.Repeat(4, 9).ToArray();
            supply[pair] = 1; // two own copies + the claimed copy are exposed
            supply[single] = 3;
            var afterClaim = 0;
            for (var start = Math.Max(0, single - 2); start <= Math.Min(6, single); start++)
                afterClaim += Enumerable.Range(start, 3).Where(t => t != single)
                    .Aggregate(1, (n, t) => n * supply[t]);
            return (boundary, connection, afterClaim);
        }
        var l = Features(left);
        var r = Features(right);
        var c = r.boundary.CompareTo(l.boundary);
        if (c == 0) c = r.connection.CompareTo(l.connection);
        if (c == 0 && l.boundary) c = r.afterClaim.CompareTo(l.afterClaim);
        return c;
    }

    private static int CompareSequenceSingles(int[] left, int[] right)
    {
        int SingleReach(int[] h)
        {
            var tiles = Enumerable.Range(0, 9).Where(t => h[t] > 0).ToArray();
            var best = 0;
            for (var i = 0; i < tiles.Length; i++)
            for (var j = i + 1; j < tiles.Length; j++)
            {
                if (tiles[j] != tiles[i] + 1 || tiles[i] == 0 || tiles[j] == 8) continue;
                var single = tiles.Single(t => t != tiles[i] && t != tiles[j]);
                // Geometric reach gives the opening central/near-edge/edge
                // ordering. Actual supply and overlap enter Extension below.
                best = Math.Max(best, Math.Min(8, single + 2) - Math.Max(0, single - 2) + 1);
            }
            return best;
        }
        var c = SingleReach(right).CompareTo(SingleReach(left));
        if (c == 0) c = SharedCompletionExposure(left).CompareTo(SharedCompletionExposure(right));
        return c != 0 ? c : Extension(right).CompareTo(Extension(left));
    }

    private static int SharedCompletionExposure(int[] hand)
    {
        var tiles = Enumerable.Range(0, 9).Where(t => hand[t] > 0).ToArray();
        var best = int.MaxValue;
        foreach (var pair in Pairs(tiles))
        {
            if (pair.b != pair.a + 1 || pair.a == 0 || pair.b == 8) continue;
            var single = tiles.Single(t => t != pair.a && t != pair.b);
            var originalWaits = Waits(pair.a, pair.b).ToArray();
            var shared = 0;
            for (var draw = 0; draw < 9; draw++)
            {
                var copies = 4 - hand[draw];
                if (copies == 0) continue;
                // Keep the original two-sided group and build a distinct new
                // group from the isolated tile plus the actual drawn copy.
                // A second copy of an original tile is legal, but the same
                // physical copy can never belong to both groups.
                hand[draw]++;
                shared += copies * Waits(Math.Min(single, draw), Math.Max(single, draw))
                    .Intersect(originalWaits).Sum(t => 4 - hand[t]);
                hand[draw]--;
            }
            best = Math.Min(best, shared);
        }
        return best == int.MaxValue ? 0 : best;
    }

    private static Shape Describe(IReadOnlyList<int> full, int suit)
    {
        var h = Enumerable.Range(suit * 9, 9).Select(t => full[t]).ToArray();
        var tiles = Enumerable.Range(0, 9).SelectMany(t => Enumerable.Repeat(t, h[t])).ToArray();
        var triplet = Array.FindIndex(h, n => n == 3);
        if (triplet >= 0)
        {
            // Count possible two-tile sequence supports for the fourth copy
            // in unseen hands. Fewer supports is a qualitative release prior,
            // not a model that assumes another player must discard it.
            var competition = 0;
            for (var start = Math.Max(0, triplet - 2); start <= Math.Min(6, triplet); start++)
                competition += Enumerable.Range(start, 3).Where(t => t != triplet)
                    .Aggregate(1, (v, t) => v * (4 - h[t]));
            return new(0, 4 - h[triplet], 0, competition, "暗刻");
        }
        if (tiles.Length == 3 && tiles[1] == tiles[0] + 1 && tiles[2] == tiles[1] + 1)
            return new(1, 0, Extension(h), 0, "顺子");
        if (h.Any(n => n == 2)) return new(2, CompletionCopies(h), Extension(h), 0, "对子及副门将牌退路");
        var twoSided = Pairs(tiles).Any(p => p.b == p.a + 1 && p.a > 0 && p.b < 8);
        if (twoSided) return new(3, CompletionCopies(h), Extension(h), 0, "两面搭子");
        var gaps = Pairs(tiles).Count(p => p.b == p.a + 2);
        if (gaps >= 2) return new(4, CompletionCopies(h), Extension(h), 0, "共享牌的连坎");
        if (gaps == 1) return new(5, CompletionCopies(h), Extension(h), 0, "坎张搭子");
        if (Pairs(tiles).Any(p => p.b == p.a + 1))
            return new(6, CompletionCopies(h), Extension(h), 0, "边张搭子");
        return new(7, 0, Extension(h), 0, "散张");
    }

    private static IEnumerable<(int a, int b)> Pairs(int[] tiles)
    {
        for (var i = 0; i < tiles.Length; i++)
        for (var j = i + 1; j < tiles.Length; j++) yield return (tiles[i], tiles[j]);
    }

    private static IEnumerable<int> Waits(int a, int b)
    {
        if (a == b) { yield return a; yield break; }
        if (b == a + 2) { yield return a + 1; yield break; }
        if (b != a + 1) yield break;
        if (a > 0) yield return a - 1;
        if (b < 8) yield return b + 1;
    }

    private static int CompletionCopies(int[] hand)
    {
        var tiles = Enumerable.Range(0, 9).SelectMany(t => Enumerable.Repeat(t, hand[t])).ToArray();
        return Pairs(tiles).SelectMany(p => Waits(p.a, p.b)).Distinct().Sum(t => 4 - hand[t]);
    }

    private static int Extension(int[] hand)
    {
        var total = 0;
        for (var draw = 0; draw < 9; draw++)
        {
            var supply = 4 - hand[draw];
            if (supply == 0) continue;
            hand[draw]++;
            var tiles = Enumerable.Range(0, 9).SelectMany(t => Enumerable.Repeat(t, hand[t])).ToArray();
            var best = 0;
            // Enumerate disjoint two-tile groups; a shared middle tile cannot
            // be counted twice. Count each completion tile's physical supply
            // once, and consume the hypothetical draw before counting it.
            for (var i = 0; i < tiles.Length; i++)
            for (var j = i + 1; j < tiles.Length; j++)
            {
                var first = Waits(tiles[i], tiles[j]).ToArray();
                if (first.Length == 0) continue;
                var rest = tiles.Where((_, index) => index != i && index != j).ToArray();
                if (rest.Length == 2)
                {
                    var second = Waits(rest[0], rest[1]).ToArray();
                    if (second.Length == 0 || !first.Any(t => hand[t] < 4) || !second.Any(t => hand[t] < 4)) continue;
                    best = Math.Max(best, first.Concat(second).Distinct().Sum(t => 4 - hand[t]));
                }
                else best = Math.Max(best, first.Sum(t => 4 - hand[t]));
            }
            hand[draw]--;
            total += supply * best;
        }
        return total;
    }
}
