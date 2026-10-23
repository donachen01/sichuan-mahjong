namespace SichuanMahjong.AI.Core.Rules;

/// <summary>Public unknown copies available to an opponent. A neighbour only
/// contributes to sequence affinity if its other partner is also available.
/// This is a structural feature, not a holding or release probability.</summary>
public static class SichuanPublicSequenceSupply
{
    public static double Affinity(IReadOnlyList<int> remaining, int tile)
    {
        if (tile is < 0 or > 26 || remaining.Count != 27)
            throw new ArgumentException("Expected a tile and 27 copy counts.");
        var rank = tile % 9;
        var supported = new bool[9];
        for (var start = Math.Max(0, rank - 2); start <= Math.Min(6, rank); start++)
        {
            if (!Enumerable.Range(start, 3).All(r => r == rank || remaining[tile / 9 * 9 + r] > 0))
                continue;
            for (var r = start; r < start + 3; r++) if (r != rank) supported[r] = true;
        }
        double affinity = 0;
        for (var r = Math.Max(0, rank - 2); r <= Math.Min(8, rank + 2); r++)
            if (supported[r]) affinity += Math.Clamp(remaining[tile / 9 * 9 + r], 0, 4) / 4.0
                * (Math.Abs(r - rank) == 1 ? 0.26 : 0.18);
        return affinity;
    }
}
