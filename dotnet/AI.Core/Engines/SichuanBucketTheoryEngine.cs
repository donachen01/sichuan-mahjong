namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanBucketTheorySummary(
    bool Supported,
    double WeakestCompletionMass,
    double NextCompletionMass,
    double WeakestImprovementMass,
    double TotalImprovementMass,
    int WeakestTileA,
    int WeakestTileB,
    int CapacityOverflow,
    int ExploredNodes)
{
    public static SichuanBucketTheorySummary Unsupported(int explored = 0)
        => new(false, 0, 0, 0, 0, -1, -1, 0, explored);
}

/// <summary>
/// Chapter 3.5: compare the weakest REQUIRED block across mutually exclusive
/// ordinary-hand decompositions. Public wall expectations are opportunities,
/// not win probabilities; opponent discard/peng routes remain elsewhere.
/// </summary>
public sealed class SichuanBucketTheoryEngine
{
    private const int NodeBudget = 50000;
    private readonly SichuanShantenEngine _shanten = new();
    private readonly record struct Block(int A, int B, bool Pair);

    public SichuanBucketTheorySummary Evaluate(
        int[] handAfterDiscard, int[] remaining, double[] expectedWall,
        int meldCount, int missingSuit)
    {
        if (handAfterDiscard.Length != 27 || remaining.Length != 27 || expectedWall.Length != 27
            || meldCount is < 0 or > 3 || handAfterDiscard.Sum() + meldCount * 3 != 13
            || handAfterDiscard.Any(count => count is < 0 or > 4)
            || missingSuit is >= 0 and < 3
                && Enumerable.Range(missingSuit * 9, 9).Any(tile => handAfterDiscard[tile] > 0))
            return SichuanBucketTheorySummary.Unsupported();

        var standard = _shanten.CalcStandardShanten(handAfterDiscard, meldCount);
        if (standard is < 1 or > 2
            || meldCount == 0 && _shanten.CalcSevenPairsShanten(handAfterDiscard) < standard)
            return SichuanBucketTheorySummary.Unsupported();

        var counts = (int[])handAfterDiscard.Clone();
        var blocks = new List<Block>(8);
        var completionCache = new Dictionary<Block, double>();
        var improvementCache = new Dictionary<Block, uint>();
        var nodes = 0;
        var exceeded = false;
        var maxCapacityOverflow = 0;
        SichuanBucketTheorySummary? best = null;
        Search(0, 0);
        return exceeded ? SichuanBucketTheorySummary.Unsupported(nodes)
            : best is null ? SichuanBucketTheorySummary.Unsupported(nodes)
                : best with { CapacityOverflow = maxCapacityOverflow, ExploredNodes = nodes };

        void Search(int index, int completed)
        {
            if (++nodes > NodeBudget) { exceeded = true; return; }
            while (index < 27 && counts[index] == 0) index++;
            if (index == 27)
            {
                Assess(completed);
                return;
            }
            if (meldCount + completed > 4) return;

            var rank = index % 9;
            if (counts[index] >= 3 && meldCount + completed < 4)
            {
                counts[index] -= 3;
                Search(index, completed + 1);
                counts[index] += 3;
            }
            if (rank <= 6 && counts[index + 1] > 0 && counts[index + 2] > 0
                && meldCount + completed < 4)
            {
                counts[index]--; counts[index + 1]--; counts[index + 2]--;
                Search(index, completed + 1);
                counts[index]++; counts[index + 1]++; counts[index + 2]++;
            }
            if (counts[index] >= 2)
            {
                counts[index] -= 2;
                blocks.Add(new Block(index, index, true));
                Search(index, completed);
                blocks.RemoveAt(blocks.Count - 1);
                counts[index] += 2;
            }
            if (rank <= 7 && counts[index + 1] > 0)
            {
                counts[index]--; counts[index + 1]--;
                blocks.Add(new Block(index, index + 1, false));
                Search(index, completed);
                blocks.RemoveAt(blocks.Count - 1);
                counts[index]++; counts[index + 1]++;
            }
            if (rank <= 6 && counts[index + 2] > 0)
            {
                counts[index]--; counts[index + 2]--;
                blocks.Add(new Block(index, index + 2, false));
                Search(index, completed);
                blocks.RemoveAt(blocks.Count - 1);
                counts[index]++; counts[index + 2]++;
            }
            counts[index]--;
            Search(index, completed);
            counts[index]++;
        }

        void Assess(int completed)
        {
            var pairCount = blocks.Count(block => block.Pair);
            if (pairCount == 0) return;
            var needed = 4 - meldCount - completed;
            var availableTaatsu = blocks.Count - 1;
            if (needed < 1 || availableTaatsu < needed) return;
            var decompositionShanten = 8 - 2 * (meldCount + completed)
                - Math.Min(needed, availableTaatsu) - 1;
            if (decompositionShanten != standard) return;

            var overflow = Math.Max(0, meldCount + completed + blocks.Count - 5);
            maxCapacityOverflow = Math.Max(maxCapacityOverflow, overflow);
            for (var head = 0; head < blocks.Count; head++)
            {
                if (!blocks[head].Pair) continue;
                var ranked = blocks.Where((_, i) => i != head)
                    .Select(block => (Block: block, Mass: CompletionMass(block)))
                    .OrderByDescending(item => item.Mass)
                    .ThenByDescending(item => ImprovementMass(item.Block, item.Mass))
                    .Take(needed).ToArray();
                if (ranked.Length < needed) continue;
                var weakest = ranked[^1];
                var improvement = ImprovementMass(weakest.Block, weakest.Mass);
                var next = ranked.Length > 1 ? ranked[^2].Mass : weakest.Mass;
                // One draw can help several blocks, but is still one event.
                var improvementUnion = ranked.Aggregate(0u,
                    (mask, item) => mask | ImprovementTiles(item.Block, item.Mass));
                var totalImprovement = MaskMass(improvementUnion);
                var candidate = new SichuanBucketTheorySummary(true, weakest.Mass,
                    next, improvement, totalImprovement,
                    weakest.Block.A, weakest.Block.B, overflow, nodes);
                if (best is null || Better(candidate, best)) best = candidate;
            }
        }

        double CompletionMass(Block block)
        {
            if (completionCache.TryGetValue(block, out var cached)) return cached;
            double result;
            if (block.Pair) result = Wall(block.A);
            else if (block.B == block.A + 2) result = Wall(block.A + 1);
            else
            {
                var rank = block.A % 9;
                result = 0.0;
                if (rank > 0) result += Wall(block.A - 1);
                if (rank < 7) result += Wall(block.B + 1);
            }
            completionCache[block] = result;
            return result;
        }

        double ImprovementMass(Block block, double current)
            => MaskMass(ImprovementTiles(block, current));

        double MaskMass(uint mask)
            => Enumerable.Range(0, 27).Where(t => (mask & (1u << t)) != 0).Sum(Wall);

        uint ImprovementTiles(Block block, double current)
        {
            if (block.Pair) return 0;
            if (improvementCache.TryGetValue(block, out var cached)) return cached;
            var suit = block.A / 9;
            var result = 0u;
            for (var tile = suit * 9; tile < suit * 9 + 9; tile++)
            {
                var drawMass = Wall(tile);
                if (drawMass <= 0 || tile == block.A && tile == block.B) continue;
                // Completion is already priced above, not counted as improvement.
                if (block.B == block.A + 2 && tile == block.A + 1) continue;
                if (block.B == block.A + 1
                    && (tile == block.A - 1 || tile == block.B + 1)) continue;
                var trio = new[] { block.A, block.B, tile };
                var bestReplacement = 0.0;
                for (var omit = 0; omit < 3; omit++)
                {
                    var retained = trio.Where((_, i) => i != omit).Order().ToArray();
                    if (retained[0] == retained[1] || retained[1] - retained[0] is 1 or 2)
                        bestReplacement = Math.Max(bestReplacement, CompletionMass(
                            new Block(retained[0], retained[1], retained[0] == retained[1])));
                }
                if (bestReplacement > current + 0.000001) result |= 1u << tile;
            }
            improvementCache[block] = result;
            return result;
        }

        double Wall(int tile) => tile is >= 0 and < 27 && remaining[tile] > 0
            ? Math.Clamp(expectedWall[tile], 0, remaining[tile]) : 0;
    }

    private static bool Better(SichuanBucketTheorySummary candidate, SichuanBucketTheorySummary best)
        => candidate.WeakestCompletionMass > best.WeakestCompletionMass + 0.000001
            || Math.Abs(candidate.WeakestCompletionMass - best.WeakestCompletionMass) <= 0.000001
                && (candidate.NextCompletionMass > best.NextCompletionMass + 0.000001
                    || Math.Abs(candidate.NextCompletionMass - best.NextCompletionMass) <= 0.000001
                        && (candidate.TotalImprovementMass > best.TotalImprovementMass + 0.000001
                            || Math.Abs(candidate.TotalImprovementMass - best.TotalImprovementMass) <= 0.000001
                                && candidate.CapacityOverflow < best.CapacityOverflow));
}
