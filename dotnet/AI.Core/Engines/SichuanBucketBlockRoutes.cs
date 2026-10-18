namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanBucketBlockPath(string Kind, int Draw, int Discard,
    int[] RetainedBlock, int DistanceAfter, int Copies, int NextCompletionCopies);

/// <summary>Physical one-draw/one-discard evidence for a two-tile bottleneck.
/// Counts unseen copies, without converting peng channels to draw probability.
/// Replacement starts a new block; the other old tile remains in the hand.</summary>
public sealed class SichuanBucketBlockRoutes
{
    private readonly SichuanShantenEngine _distance = new();
    public IReadOnlyList<SichuanBucketBlockPath> Analyze(int[] hand, int[] remaining,
        int meldCount, int missingSuit, int[] weak, int[] spares)
    {
        var result = new List<SichuanBucketBlockPath>();
        if (hand.Length != 27 || remaining.Length != 27 || weak.Length != 2
            || hand.Sum() + meldCount * 3 != 13 || hand.Any(n => n is < 0 or > 4)
            || remaining.Any(n => n is < 0 or > 4)
            || Enumerable.Range(0,27).Any(t => hand[t] + remaining[t] > 4)
            || weak.Any(t => t is < 0 or >= 27) || !Linked(weak)
            || weak.GroupBy(t => t).Any(g => hand[g.Key] < g.Count())
            || missingSuit is >= 0 and < 3 && hand.Skip(missingSuit * 9).Take(9).Any(n => n > 0))
            return result;
        var baseline = _distance.CalcStandardShanten(hand, meldCount);
        if (baseline < 1) return result;
        var current = CompletionCopies(weak, remaining);
        for (var draw = 0; draw < 27; draw++)
        {
            if (remaining[draw] <= 0 || draw / 9 == missingSuit) continue;
            var future = remaining.ToArray(); future[draw]--;
            var triple = weak.Append(draw).Order().ToArray();
            if (Complete(triple))
                Add("complete", triple, Enumerable.Range(0,27));
            else
                for (var omit = 0; omit < 3; omit++)
                {
                    var retained = triple.Where((_, i) => i != omit).ToArray();
                    if (Linked(retained) && CompletionCopies(retained, future) > current)
                        Add("strengthen", retained, new[] { triple[omit] });
                }
            foreach (var spare in spares.Distinct())
            {
                if (spare is < 0 or >= 27 || hand[spare] <= weak.Count(t => t == spare)) continue;
                var retained = new[] { spare, draw }.Order().ToArray();
                if (Linked(retained) && CompletionCopies(retained, future) > current)
                    Add("start_replacement", retained, weak.Distinct());
            }
            void Add(string kind, int[] retained, IEnumerable<int> discards)
            {
                foreach (var discard in discards.Distinct())
                {
                    if (discard / 9 == missingSuit) continue;
                    var after = hand.ToArray(); after[draw]++;
                    if (after[discard] <= retained.Count(t => t == discard)) continue;
                    after[discard]--;
                    var distance = _distance.CalcStandardShanten(after, meldCount);
                    if (distance > baseline) continue;
                    var path = new SichuanBucketBlockPath(kind, draw, discard, retained, distance,
                        remaining[draw], kind == "complete" ? 0 : CompletionCopies(retained, future));
                    if (!result.Any(p => p.Kind == kind && p.Draw == draw && p.Discard == discard
                        && p.RetainedBlock.SequenceEqual(retained))) result.Add(path);
                }
            }
        }
        return result;
    }
    public static int CompletionCopies(int[] block, int[] remaining)
        => Enumerable.Range(0,27).Where(t => remaining[t] > 0 && Complete(block.Append(t).Order().ToArray()))
            .Sum(t => remaining[t]);
    private static bool Complete(int[] block) => block.Length == 3
        && (block[0] == block[2] || block[0] / 9 == block[2] / 9
            && block[1] == block[0] + 1 && block[2] == block[0] + 2);
    private static bool Linked(int[] block) => block[0] / 9 == block[1] / 9
        && Math.Abs(block[1] - block[0]) <= 2;
}
