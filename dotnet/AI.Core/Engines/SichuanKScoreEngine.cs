namespace SichuanMahjong.AI.Core.Engines;

/// <summary>Opening-only K scoring. Exhaustive disjoint partitions, never discard valuation.</summary>
public sealed class SichuanKScoreEngine
{
    public const int BasePointsPerTile = 10;
    public const int StandardTripleGapBonus = 3;

    public sealed record Group(string Kind, int[] Ranks, int Bonus);
    public sealed record Evaluation(int BaseScore, int Bonus, IReadOnlyList<Group> Groups)
    {
        public int Total => BaseScore + Bonus;
    }

    /// <summary>The game uses this standard profile; 3–7 singles all score zero.</summary>
    public Evaluation Evaluate(IReadOnlyList<int> counts) => Evaluate(counts, StandardTripleGapBonus);

    // The explicit bonus overload is retained for source-discrepancy research.
    public Evaluation Evaluate(IReadOnlyList<int> counts, int tripleGapBonus)
    {
        if (counts.Count != 9 || counts.Any(n => n is < 0 or > 4))
            throw new ArgumentException("K scoring requires nine physical tile counts.", nameof(counts));
        if (tripleGapBonus is not (3 or 4)) throw new ArgumentOutOfRangeException(nameof(tripleGapBonus));
        var hand = counts.ToArray();
        var memo = new Dictionary<int, (int score, Group[] groups)>();
        (int score, Group[] groups) Solve()
        {
            var key = 0;
            for (var t = 8; t >= 0; t--) key = key * 5 + hand[t];
            if (memo.TryGetValue(key, out var cached)) return cached;
            var first = Array.FindIndex(hand, n => n > 0);
            if (first < 0) return (0, Array.Empty<Group>());
            var best = (score: int.MinValue, groups: Array.Empty<Group>());
            void Try(string kind, int bonus, params int[] tiles)
            {
                var needed = tiles.GroupBy(t => t).ToArray();
                if (needed.Any(g => g.Key >= 9 || hand[g.Key] < g.Count())) return;
                foreach (var t in tiles) hand[t]--;
                var rest = Solve();
                foreach (var t in tiles) hand[t]++;
                if (bonus + rest.score > best.score)
                    best = (bonus + rest.score, new[] { new Group(kind, tiles.Select(t => t + 1).ToArray(), bonus) }.Concat(rest.groups).ToArray());
            }
            var boundary = first is <= 1 or >= 7;
            Try("暗杠", 50, first, first, first, first);
            Try("暗刻", boundary ? 25 : 18, first, first, first);
            Try("顺子", 10, first, first + 1, first + 2);
            Try("对子", boundary ? 6 : 5, first, first);
            Try("连坎", tripleGapBonus, first, first + 2, first + 4);
            Try(first is 0 or 7 ? "边张" : "两面", first is 0 or 7 ? -1 : 4, first, first + 1);
            Try("坎张", first is >= 2 and <= 4 ? 2 : 1, first, first + 2);
            Try("单张", first is 0 or 8 ? -2 : first is 1 or 7 ? -1 : 0, first);
            memo[key] = best;
            return best;
        }
        var result = Solve();
        return new(counts.Sum() * BasePointsPerTile, result.score, result.groups);
    }
}
