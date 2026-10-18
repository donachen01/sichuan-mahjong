using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Inference;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanCourseTempoChoice(int Tile, string Code, string[] Reasons);

/// <summary>Shared public-state basic play, before full-game strategic exceptions.
/// Exact readiness is protected; more distant development is evaluated separately
/// from immediate self-draw ukeire. No hand IDs or tile-specific answer table.</summary>
public sealed class SichuanCourseTempoPolicy
{
    private readonly SichuanFiveBlockPlanner _five = new();
    private readonly SichuanShantenEngine _distance = new();
    private readonly SichuanHandImprovementEngine _improvement = new();
    private readonly SichuanReadyWaitPricing _prices = new();
    private readonly SichuanHandDevelopmentEngine _development = new();

    public SichuanCourseTempoChoice? Select(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, int incumbent, int? roundStage = null)
    {
        var current = candidates.FirstOrDefault(c => c.TileType == incumbent);
        if (current is null || state.InformationMode != "public" || !CoherentAvailability(state)
            || state.WallCount < 8
            || current.Danger > 45 || state.OwnDingQueSuit is >= 0 and < 3
                && state.Hand18.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0)) return null;
        var eligible = candidates.Where(c => c.Danger <= current.Danger + 5
            && c.DealInProbability <= current.DealInProbability + 0.01).ToArray();
        if (current.Shanten == 0)
        {
            var priced = Ready(state, eligible, current);
            var pricedIncumbent = priced is null ? current : eligible.First(c => c.TileType == priced.Tile);
            return KnownWallReadyGrowth(state, eligible, pricedIncumbent) ?? priced;
        }
        // Replacement needs time to form a block and then complete it. This
        // bound depends on the actual active turn order, not a fixed book turn.
        if (SichuanDevelopmentPolicy.Draws(state) < 3) return null;
        var edge = DepletedEdge(state, eligible, current);
        if (edge is not null) return edge;
        var stage = roundStage ?? new SichuanStageEvaluator().Evaluate(state, new SichuanBeliefEngine().Build(state)).StageIndex;
        var isolated = new SichuanIsolatedStructurePolicy().Select(state, eligible, current, stage);
        if (isolated is not null) return isolated;
        var plan = _five.Select(state, eligible.Select(c => c.TileType).ToArray(), incumbent);
        if (plan is null || plan.Tile == incumbent && plan.Reorganization is null) return null;
        return new(plan.Tile, plan.Reorganization is null ? "COURSE_FIVE_BLOCK_SELECTION"
            : "FIVE_BLOCK_WHOLE_HAND_REORGANIZATION", plan.Reasons);
    }

    private static bool CoherentAvailability(SichuanStateView state)
    {
        // A development/time choice needs a consistent wall and public pool.
        // Historical partial hand fixtures may still expose shape evidence,
        // but must not acquire an invented number of future draws.
        return state.SeatIndex is >= 0 and < 4 && state.HandCounts.Length == 4
            && state.Hand18.Length == 27 && state.Visible18.Length == 27
            && state.Remaining18.Length == 27
            && state.HandCounts.All(n => n is >= 0 and <= 14)
            && state.HandCounts[state.SeatIndex] == state.Hand18.Sum()
            && Enumerable.Range(0, 27).All(t => state.Hand18[t] is >= 0 and <= 4
                && state.Visible18[t] is >= 0 and <= 4 && state.Remaining18[t] is >= 0 and <= 4
                && state.Hand18[t] + state.Visible18[t] + state.Remaining18[t] == 4)
            && state.Remaining18.Sum() == state.WallCount
                + Enumerable.Range(0,4).Where(s => s != state.SeatIndex).Sum(s => state.HandCounts[s]);
    }

    private SichuanCourseTempoChoice? Ready(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, SichuanCandidateDetail current)
    {
        var wall = state.Remaining18.Select(n => (double)n).ToArray();
        var before = state.Hand18.ToArray(); before[current.TileType]--;
        var reference = _prices.Build(state, before, wall);
        if (reference is null) return null;
        var melds = SichuanDevelopmentPolicy.Melds(state, state.SeatIndex);
        double Gain(int[] hand) => _improvement.EnumerateReadyFanImprovements(hand,
            state.Remaining18, melds, state.OwnDingQueSuit).Sum(i => i.Copies * i.FanValueGain);
        var best = current; var bestGain = Gain(before); var bestPrice = reference;
        var bestRootWeighted = bestPrice.RootWeightedDrawableMass;
        var rootWeightedSelection = false;
        foreach (var candidate in candidates.Where(c => c.Shanten == 0 && c.TileType != current.TileType))
        {
            var hand = state.Hand18.ToArray(); hand[candidate.TileType]--;
            var price = _prices.Build(state, hand, wall);
            if (price is null || !price.HasDrawableWait) continue;
            var rootComparison = SichuanRootWeightedWaitPolicy.Compare(bestPrice, price);
            var rootWeightedGain = rootComparison.Improves;
            // The book's 4.3 rule permits a ready-hand wait change when the
            // root=2 / ordinary=1 weighted supply improves.  Keep the same
            // caller-side danger and deal-in gates, and leave exact fan and
            // settlement pricing in the normal candidate score.
            if (rootWeightedGain)
            {
                best = candidate;
                bestGain = Gain(hand);
                bestPrice = price;
                bestRootWeighted = price.RootWeightedDrawableMass;
                rootWeightedSelection = true;
                continue;
            }
            if (price.Waits.Count != reference.Waits.Count
                || reference.Waits.Any(w => !price.Waits.Any(a => a.TileType == w.TileType
                    && a.SelfDrawPerPayer >= w.SelfDrawPerPayer))) continue;
            // A realized price increase must not lose to its own remaining
            // improvement potential. Compare each live wait with the current
            // best, not only the original incumbent. Potential breaks ties
            // only when all live wait prices are unchanged.
            var weakerThanBest = bestPrice.Waits.Any(w => w.PublicWallWeight > 0
                && (!price.Waits.Any(a => a.TileType == w.TileType)
                    || price.Waits.First(a => a.TileType == w.TileType).SelfDrawPerPayer < w.SelfDrawPerPayer));
            if (weakerThanBest) continue;
            var realized = bestPrice.Waits.Any(w => w.PublicWallWeight > 0
                && price.Waits.Any(a => a.TileType == w.TileType)
                && price.Waits.First(a => a.TileType == w.TileType).SelfDrawPerPayer > w.SelfDrawPerPayer);
            var gain = Gain(hand);
            if (realized || gain > bestGain + 1e-9)
            {
                best = candidate; bestGain = gain; bestPrice = price;
                bestRootWeighted = price.RootWeightedDrawableMass;
                rootWeightedSelection = false;
            }
        }
        if (best.TileType == current.TileType) return null;
        if (rootWeightedSelection)
            return new(best.TileType,
                "READY_ROOT_WEIGHTED_WAIT_GAIN",
                [$"带根加权听张 {bestRootWeighted:F2}，优于当前路线 {reference.RootWeightedDrawableMass:F2}",
                    "4.3根=2、非根=1仅作结构信号；真实番、封顶、付款人数和危险仍由候选净值处理"]);
        return new(best.TileType,
            "READY_SAME_WAIT_FAN_IMPROVEMENT",
            ["保住全部原听口与逐听口番值；先比较已经兑现的增番，再比较同价听口的后续改良"]);
    }

    private SichuanCourseTempoChoice? KnownWallReadyGrowth(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, SichuanCandidateDetail current)
    {
        var wall = state.Remaining18.Select(n => (double)n).ToArray();
        var before = state.Hand18.ToArray(); before[current.TileType]--;
        var reference = _prices.Build(state, before, wall);
        if (reference is null || !reference.HasDrawableWait) return null;
        var suits = reference.Waits.Select(w => w.TileType / 9).Distinct().ToArray();
        if (suits.Length != 1) return null;
        var suit = suits[0];
        // At each other player's waiting boundary, public non-missing discards
        // prove that their missing suit cannot be retained. A legal winner is
        // also clear. Otherwise unseen copies must not be treated as wall copies.
        if (Enumerable.Range(0, 4).Any(seat => seat != state.SeatIndex
            && state.HandCounts[seat] > 0
            && (state.DingQueSuits[seat] != suit
                || !state.HasHu[seat] && !SichuanOpponentTimeline.MustHaveClearedMissing(state, seat))))
            return null;
        var melds = SichuanDevelopmentPolicy.Melds(state, state.SeatIndex);
        double FanGain(int[] h) => _improvement.EnumerateReadyFanImprovements(h,
            state.Remaining18, melds, state.OwnDingQueSuit).Sum(i => i.Copies * i.FanValueGain);
        (int Fan, int HandScore, int SelfPrice, int Copies)[] PriceSignature(SichuanReadyPrice p)
            => p.Waits.Where(w => state.Remaining18[w.TileType] > 0)
                .GroupBy(w => (w.CappedFan, w.HandScore, w.SelfDrawPerPayer))
                .Select(g => (g.Key.CappedFan, g.Key.HandScore, g.Key.SelfDrawPerPayer,
                    g.Sum(w => state.Remaining18[w.TileType])))
                .OrderBy(g => g.CappedFan).ThenBy(g => g.HandScore).ThenBy(g => g.SelfDrawPerPayer).ToArray();
        int GrowthCopies(int[] h)
        {
            var development = _development.Analyze(h, state.Remaining18, melds.Count,
                state.OwnDingQueSuit, melds, requireKnownMissingSuit: true);
            if (!development.Summary.Available) return 0;
            // A draw is counted once, with a complete legal discard branch.
            // New waits must also belong to the publicly known wall suit.
            return development.Draws.Where(d => !d.Effective && d.DrawTile / 9 == suit
                && d.Branches.Any(b => b.BestDistance == 0
                    && b.LiveCopies > development.Summary.UnseenEffectiveCopies
                    && b.EffectiveTiles.All(t => t / 9 == suit))).Sum(d => d.Copies);
        }
        var signature = PriceSignature(reference);
        var fanGain = FanGain(before);
        var best = current; var bestGrowth = GrowthCopies(before);
        foreach (var candidate in candidates.Where(c => c.Shanten == 0 && c.TileType != current.TileType))
        {
            if (candidate.Danger > best.Danger || candidate.DealInProbability > best.DealInProbability + 1e-9
                || candidate.RouteLoss.Any(route => !best.RouteLoss.Contains(route))) continue;
            var hand = state.Hand18.ToArray(); hand[candidate.TileType]--;
            var price = _prices.Build(state, hand, wall);
            if (price is null || price.Waits.Any(w => w.TileType / 9 != suit)
                || !PriceSignature(price).SequenceEqual(signature)
                || Math.Abs(FanGain(hand) - fanGain) > 1e-9) continue;
            var growth = GrowthCopies(hand);
            if (growth > bestGrowth)
            { best = candidate; bestGrowth = growth; }
        }
        return best.TileType == current.TileType ? null : new(best.TileType,
            "KNOWN_WALL_SAME_PRICE_STRUCTURAL_IMPROVEMENT",
            ["公开出牌证明相关未见牌都在墙内；当前完成供应及番值相同、舍牌风险不增加，保留更多合法摸打后的活张改良"]);
    }

    private SichuanCourseTempoChoice? DepletedEdge(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, SichuanCandidateDetail current)
    {
        var h = state.Hand18;
        var afterCurrent = h.ToArray(); afterCurrent[current.TileType]--;
        var baseline = _distance.CalcStandardShanten(afterCurrent, state.OwnMeldCount);
        if (baseline is < 1 or > 2) return null;
        var proposals = new List<(SichuanCandidateDetail Candidate, int Progress, double Retention)>();
        for (var suit = 0; suit < 3; suit++)
        foreach (var low in new[] { 0, 7 })
        {
            var a = suit * 9 + low; var b = a + 1; var completion = low == 0 ? b + 1 : a - 1;
            if (h[a] != 1 || h[b] != 1 || h[completion] > 0
                || state.Remaining18[completion] > 1) continue;
            foreach (var candidate in candidates.Where(c => c.TileType == a || c.TileType == b))
            {
                var after = h.ToArray(); after[candidate.TileType]--;
                var distance = _distance.CalcStandardShanten(after, state.OwnMeldCount);
                if (distance != baseline + 1 || candidate.Shanten > current.Shanten + 1) continue;
                // There must be actual independent singleton development,
                // not just a nominal edge label on an otherwise connected run.
                var isolated = Enumerable.Range(0, 27).Where(t => after[t] == 1
                    && t != a && t != b && t / 9 != state.OwnDingQueSuit
                    && (t % 9 == 0 || after[t - 1] == 0)
                    && (t % 9 == 8 || after[t + 1] == 0)).ToArray();
                if (isolated.Length < 2) continue;
                var progress = 0;
                for (var draw = 0; draw < 27; draw++)
                {
                    if (draw / 9 == state.OwnDingQueSuit || state.Remaining18[draw] <= 0) continue;
                    after[draw]++;
                    if (_distance.CalcStandardShanten(after, state.OwnMeldCount) < distance)
                        progress += state.Remaining18[draw];
                    after[draw]--;
                }
                if (progress <= state.Remaining18[completion]) continue;
                var retained = candidate.TileType == a ? b : a;
                var value = new SichuanIsolatedTileEvaluator().Evaluate(after, state.Remaining18,
                    state.Remaining18.Select(n => (double)n).ToArray(), retained).RetentionValue;
                proposals.Add((candidate, progress, value));
            }
        }
        var best = proposals.OrderByDescending(p => p.Progress).ThenByDescending(p => p.Retention)
            .ThenBy(p => p.Candidate.Danger).FirstOrDefault();
        return best.Candidate is null || best.Candidate.TileType == current.TileType ? null
            : new(best.Candidate.TileType, "DEPLETED_EDGE_DEVELOPMENT",
                ["弱边搭补成仅余至多一张，有足够本家摸牌机会与两张可发展的孤张，先拆弱搭",
                 "承担普通上听退一步的代价；不用于已听牌、临近流局或防守局面"]);
    }
}
