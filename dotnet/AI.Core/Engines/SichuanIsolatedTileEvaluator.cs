namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanIsolatedTileValue(
    bool IsIsolated,
    double RetentionValue,
    double DiscardPriority,
    IReadOnlyList<string> Reasons,
    bool IsDepletedEdge = false)
{
    public static readonly SichuanIsolatedTileValue NotIsolated = new(false, 0, 0, Array.Empty<string>());
}

/// <summary>
/// Section 3.4's isolated tile is a singleton without either immediate neighbor.
/// This measures its marginal local draw supply, rather than assigning a fixed
/// penalty to every terminal. Exact shanten and live ukeire remain authoritative.
/// </summary>
public sealed class SichuanIsolatedTileEvaluator
{
    public SichuanIsolatedTileValue Evaluate(
        IReadOnlyList<int> hand, IReadOnlyList<int> unseen,
        IReadOnlyList<double> expectedWall, int tile)
    {
        if (hand.Count != 27 || unseen.Count != 27 || expectedWall.Count != 27
            || tile is < 0 or >= 27 || hand[tile] != 1)
            return SichuanIsolatedTileValue.NotIsolated;

        var rank = tile % 9;
        // A lone terminal attached to 2/8 can be a dead edge block rather
        // than an isolated tile. Its sole sequence-completing 3/7 may already
        // be nearly exhausted (3-15 C). This is still only a same-speed clue.
        var edgeCompletion = rank == 0 && hand[tile + 1] > 0 ? tile + 2
            : rank == 8 && hand[tile - 1] > 0 ? tile - 2 : -1;
        if (edgeCompletion >= 0 && unseen[edgeCompletion] <= 1)
            return new SichuanIsolatedTileValue(false, 0, 6.0,
                [$"边搭关键进张仅余 {unseen[edgeCompletion]} 张"], true);
        if ((rank > 0 && hand[tile - 1] > 0) || (rank < 8 && hand[tile + 1] > 0))
            return SichuanIsolatedTileValue.NotIsolated;

        var value = 0.0;
        var shared = 0.0;
        var compoundSupport = 0.0;
        var compoundWindows = 0;
        // Drawing the singleton itself makes a pair. The textbook definition
        // of an isolated tile includes this effective copy; do not drop it
        // merely because the loop below handles neighboring sequence paths.
        if (unseen[tile] > 0)
            value += Math.Min(unseen[tile], Math.Max(0.0, expectedWall[tile]));
        for (var offset = -2; offset <= 2; offset++)
        {
            if (offset == 0 || rank + offset is < 0 or > 8) continue;
            var draw = tile + offset;
            if (unseen[draw] <= 0) continue;
            // Expected wall copies are bounded by public availability. The
            // public count also makes a three-visible neighbor lose value even
            // if the posterior for its last hidden copy is optimistic.
            var supply = Math.Min(unseen[draw], Math.Max(0.0, expectedWall[draw]));
            var weight = Math.Abs(offset) == 1 ? 1.0 : 0.45;
            value += supply * weight;

            // Shared incoming tiles cannot be counted in full for two isolated
            // singles: only one tile is drawn, and the weaker singleton has
            // less unique contribution to the hand.
            for (var other = tile / 9 * 9; other < tile / 9 * 9 + 9; other++)
            {
                if (other == tile || hand[other] != 1 || Math.Abs(other - draw) > 2) continue;
                var otherRank = other % 9;
                if ((otherRank > 0 && hand[other - 1] > 0)
                    || (otherRank < 8 && hand[other + 1] > 0)) continue;
                shared += supply * Math.Min(weight, Math.Abs(other - draw) == 1 ? 1.0 : 0.45) * 0.18;
                break;
            }
        }

        // Core of 3.4: a singleton can borrow an existing three-tile run and
        // become one of two useful taatsu.  For x + (x+2,x+3,x+4), the two
        // blocks are x(x+2) and (x+3)(x+4); x+3 and x+5 are the additional
        // completion types that a simple +/-2 scan misses.  Require the full
        // three-tile core so a pair of distant cards cannot manufacture a
        // false “compound” bonus.
        for (var direction = -1; direction <= 1; direction += 2)
        {
            var core0 = rank + direction * 2;
            var core1 = rank + direction * 3;
            var core2 = rank + direction * 4;
            if (core0 is < 0 or > 8 || core1 is < 0 or > 8 || core2 is < 0 or > 8)
                continue;
            var suitBase = tile / 9 * 9;
            if (hand[suitBase + core0] <= 0 || hand[suitBase + core1] <= 0 || hand[suitBase + core2] <= 0)
                continue;

            compoundWindows++;
            foreach (var extensionRank in new[] { rank + direction * 3, rank + direction * 5 })
            {
                if (extensionRank is < 0 or > 8) continue;
                var extensionTile = suitBase + extensionRank;
                if (unseen[extensionTile] <= 0) continue;
                compoundSupport += Math.Min(unseen[extensionTile], Math.Max(0.0, expectedWall[extensionTile]));
            }
        }

        value += compoundSupport - shared;
        // This is only a same-speed ordering signal. A low marginal value
        // means this tile is easier to discard; it is not a win probability.
        var discardPriority = Math.Clamp(8.0 - value, -8.0, 8.0);
        var reasons = new List<string> { $"孤张边际进张 {value:0.0}" };
        if (compoundWindows > 0) reasons.Add($"可借用完整顺子形成复合搭子 {compoundWindows} 组");
        if (compoundSupport > 0.05) reasons.Add($"复合搭子新增有效牌 {compoundSupport:0.0}");
        if (shared > 0.05) reasons.Add("孤张进张重叠");
        if (value < 3.0) reasons.Add("邻牌现张使孤张价值降低");
        return new SichuanIsolatedTileValue(true, value, discardPriority, reasons);
    }
}
