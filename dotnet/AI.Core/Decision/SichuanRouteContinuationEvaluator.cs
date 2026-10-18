using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanRouteContinuation(string Route, int TargetSuit, bool Reachable,
    int DistanceToWin, int[] EffectiveDraws, double ExpectedWallCopies,
    double NextDrawProgressChance, double ComparableOpportunity)
{
    public string ChanceMeaning => "next_own_draw_structural_progress_under_public_wall_model_not_full_game_win";
    public string OpportunityMeaning => "bounded_route_comparison_proxy_not_expected_settlement";
}

/// <summary>
/// Compares the three hand routes after the SAME discard and from the SAME
/// public wall model. No route probabilities are added together: a future win
/// can satisfy several routes, so only the best incremental option is used.
/// </summary>
public sealed class SichuanRouteContinuationEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanFlushStructureEngine _flush = new();

    public SichuanRouteContinuation[] Evaluate(SichuanStateView state, int[] handAfterDiscard,
        SichuanWallAvailability wall)
    {
        var exposed = new int[27];
        var meldViews = state.MeldViews[state.SeatIndex];
        var meldCount = meldViews.Count > 0 ? meldViews.Count : state.MeldCount(state.SeatIndex);
        if (meldViews.Count > 0)
            foreach (var meld in meldViews)
                exposed[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        else foreach (var tile in state.Melds18[state.SeatIndex]) exposed[tile]++;

        var results = new List<SichuanRouteContinuation>();
        var missing = state.OwnDingQueSuit;
        var cleared = missing is < 0 or > 2 || handAfterDiscard.Skip(missing * 9).Take(9).Sum() == 0;
        var standard = _shanten.CalcStandardShanten(handAfterDiscard, meldCount);
        results.Add(Build("ordinary", -1, cleared, standard + 1,
            cleared ? ImprovingDraws(handAfterDiscard, state.Remaining18, standard,
                drawn => _shanten.CalcStandardShanten(drawn, meldCount)) : Array.Empty<int>(), 1, wall));
        if (meldCount == 0)
        {
            var pairs = _shanten.CalcSevenPairsShanten(handAfterDiscard);
            results.Add(Build("seven_pairs", -1, cleared, pairs + 1,
                cleared ? ImprovingDraws(handAfterDiscard, state.Remaining18, pairs,
                    drawn => _shanten.CalcSevenPairsShanten(drawn)) : Array.Empty<int>(),
                1 << Math.Min(2, SichuanRuleSnapshot.Frozen.FanCap), wall));
        }
        else results.Add(Build("seven_pairs", -1, false, -1, Array.Empty<int>(), 0, wall));

        for (var suit = 0; suit < 3; suit++)
        {
            if (!cleared || suit == missing || exposed.Where((count, tile) => count > 0 && tile / 9 != suit).Any())
            {
                results.Add(Build("flush", suit, false, -1, Array.Empty<int>(), 0, wall));
                continue;
            }
            var structure = _flush.Analyze(handAfterDiscard, state.Remaining18, exposed, suit, meldCount);
            results.Add(Build("flush", suit, structure.FeasiblePatterns > 0,
                structure.MinimumAdditionalTiles, structure.UsefulDraws.ToArray(),
                1 << Math.Min(2, SichuanRuleSnapshot.Frozen.FanCap), wall));
        }
        return results.ToArray();
    }

    private static int[] ImprovingDraws(int[] hand, int[] available, int distance,
        Func<int[], int> calculate)
    {
        var draws = new List<int>();
        for (var tile = 0; tile < 27; tile++)
        {
            if (available[tile] <= 0 || hand[tile] >= 4) continue;
            hand[tile]++;
            if (calculate(hand) < distance) draws.Add(tile);
            hand[tile]--;
        }
        return draws.ToArray();
    }

    private static SichuanRouteContinuation Build(string route, int suit, bool feasible,
        int distance, int[] effective, int scoreMultiplier, SichuanWallAvailability wall)
    {
        var copies = feasible ? wall.SumExpected(effective) : 0;
        var chance = wall.WallCount > 0 ? Math.Clamp(copies / wall.WallCount, 0, 1) : 0;
        // The route comparison uses the same one-draw structural event and
        // the same rules-capped nominal score scale. This is a limited
        // opportunity proxy, never represented as full-hand completion EV.
        var opportunity = feasible && distance > 0
            ? chance * scoreMultiplier / (distance * (double)distance) : 0;
        return new(route, suit, feasible, distance, effective, copies, chance, opportunity);
    }
}
