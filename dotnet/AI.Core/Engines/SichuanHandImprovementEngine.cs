using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Engines;

public sealed record SichuanWaitFanImprovement(int TileType, int BeforeFan, int AfterFan,
    int BeforePerPayerScore, int AfterPerPayerScore, int LiveCopies);

public sealed record SichuanHandImprovement(
    int DrawTile, int Copies, int DiscardTile, int BeforeLiveUkeire, int AfterLiveUkeire)
{
    public IReadOnlyList<SichuanWaitFanImprovement> WaitFanImprovements { get; init; }
        = Array.Empty<SichuanWaitFanImprovement>();
    public bool PreservesWaits => WaitFanImprovements.Count > 0;
    public double FanValueGain => WaitFanImprovements.Sum(w =>
        w.LiveCopies * (w.AfterPerPayerScore - w.BeforePerPayerScore));
}

// A structural calculation over this player's hand and public availability.
// It is not a calibrated win probability or a forecast of opponents' discards.
public sealed class SichuanHandImprovementEngine
{
    private static long _evaluations;
    private static long _positiveDraws;
    public static string DiagnosticsCompact()
        => $"evaluations={Interlocked.Read(ref _evaluations)};positive_draws={Interlocked.Read(ref _positiveDraws)}";

    public IReadOnlyList<SichuanHandImprovement> Enumerate(
        IReadOnlyList<int> hand27, IReadOnlyList<int> remaining27,
        int meldCount, int missingSuit = -1)
    {
        using var policyTimer = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("improvement");
        var result = new SichuanHandDevelopmentEngine().Analyze(hand27, remaining27, meldCount, missingSuit)
            .PreferredImprovements;
        Interlocked.Increment(ref _evaluations);
        Interlocked.Add(ref _positiveDraws, result.Length);
        return result.ToArray();
    }

    public IReadOnlyList<SichuanHandImprovement> EnumerateReadyFanImprovements(
        IReadOnlyList<int> hand27, IReadOnlyList<int> remaining27,
        IReadOnlyList<SichuanMeldView> melds, int missingSuit = -1, bool includeAllDiscards = false)
    {
        var hand = hand27.ToArray();
        if (hand.Length != 27 || remaining27.Count != 27 || melds.Count > 4
            || hand.Sum() + 3 * melds.Count != 13 || hand.Any(n => n is < 0 or > 4)
            || missingSuit is >= 0 and < 3 && hand.Skip(missingSuit * 9).Take(9).Any(n => n > 0))
            return Array.Empty<SichuanHandImprovement>();
        var owned = hand.ToArray();
        foreach (var meld in melds) owned[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        if (owned.Any(n => n > 4)) return Array.Empty<SichuanHandImprovement>();
        var remaining = Enumerable.Range(0, 27)
            .Select(t => Math.Clamp(remaining27[t], 0, 4 - owned[t])).ToArray();
        var exact = new SichuanExactHandAnalyzer();
        var fans = new SichuanFanProjectionEngine();
        var baseline = Prices();
        if (baseline.Count == 0) return Array.Empty<SichuanHandImprovement>();
        var live = baseline.Keys.Sum(t => remaining[t]);
        var result = new List<SichuanHandImprovement>();
        for (var draw = 0; draw < 27; draw++)
        {
            if (draw / 9 == missingSuit || remaining[draw] <= 0 || baseline.ContainsKey(draw)) continue;
            var copies = remaining[draw];
            hand[draw]++; remaining[draw]--;
            SichuanHandImprovement? best = null;
            for (var discard = 0; discard < 27; discard++)
            {
                if (discard == draw || hand[discard] == 0) continue;
                hand[discard]--;
                var after = Prices();
                if (after.Count == baseline.Count && baseline.Keys.All(after.ContainsKey)
                    && baseline.All(w => after[w.Key].PerPayerScore >= w.Value.PerPayerScore))
                {
                    var changes = baseline.Where(w => remaining[w.Key] > 0
                        && after[w.Key].PerPayerScore > w.Value.PerPayerScore)
                        .Select(w => new SichuanWaitFanImprovement(w.Key, w.Value.CappedFan,
                            after[w.Key].CappedFan, w.Value.PerPayerScore,
                            after[w.Key].PerPayerScore, remaining[w.Key])).ToArray();
                    if (changes.Length > 0)
                    {
                        var candidate = new SichuanHandImprovement(draw, copies, discard, live, live)
                            { WaitFanImprovements = changes };
                        if (includeAllDiscards) result.Add(candidate);
                        else if (best is null || candidate.FanValueGain > best.FanValueGain) best = candidate;
                    }
                }
                hand[discard]++;
            }
            if (best is not null) result.Add(best);
            remaining[draw]++; hand[draw]--;
        }
        return result;

        Dictionary<int, SichuanFanProjection> Prices()
        {
            var capacity = Enumerable.Range(0, 27).Select(t => 4 - hand[t]).ToArray();
            foreach (var meld in melds) capacity[meld.TileType] -= meld.Type == SichuanMeldType.Peng ? 3 : 4;
            if (capacity.Any(n => n < 0)) return new();
            var prices = new Dictionary<int, SichuanFanProjection>();
            foreach (var wait in exact.EnumerateWaits(hand, capacity, melds.Count, melds.Count == 0))
            {
                if (wait.TileType / 9 == missingSuit) continue;
                hand[wait.TileType]++;
                prices[wait.TileType] = fans.Project(hand, melds, SichuanWinType.SelfDraw);
                hand[wait.TileType]--;
            }
            return prices;
        }
    }

}
