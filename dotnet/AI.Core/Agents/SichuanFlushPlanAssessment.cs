using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Agents;

public sealed record FlushImprovement(int DrawTile, int Copies, int DiscardTile,
    int EffectiveCopiesAfter, bool PreservesOrdinaryReady);

public sealed record SichuanFlushPlanAssessment(int TargetSuit, bool Legal, string Reason,
    bool SingleLane, int TargetConcealedTiles, int OffSuitTiles,
    int? MinimumAdditionalTilesToWin, int[] EffectiveDraws, int UnseenEffectiveCopies,
    int[] BottleneckTiles, bool ImprovementEvaluated, FlushImprovement[] Improvements)
{
    public string DistanceMeaning => "additional_tiles_to_legal_flush_win_not_ordinary_shanten";
    public string SupplyMeaning => "public_unseen_upper_bound_not_wall_probability";

    public static SichuanFlushPlanAssessment[] Build(SichuanStateView state)
    {
        var hand = state.Hand18;
        var exposed = new int[27];
        var melds = state.MeldViews[state.SeatIndex];
        var meldCount = melds.Count > 0 ? melds.Count : state.MeldCount(state.SeatIndex);
        if (melds.Count > 0)
            foreach (var meld in melds) exposed[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        else foreach (var tile in state.Melds18[state.SeatIndex]) exposed[tile]++;
        var engine = new SichuanFlushStructureEngine();
        var shanten = new SichuanShantenEngine();
        var isThirteen = hand.Sum() + meldCount * 3 == 13;
        var missing = state.OwnDingQueSuit;
        var clear = missing >= 0 && hand.Skip(missing * 9).Take(9).Sum() == 0;
        var ordinaryReady = isThirteen && clear && shanten.CalcStandardShanten(hand, meldCount) == 0;
        var result = new List<SichuanFlushPlanAssessment>();
        for (var suit = 0; suit < 3; suit++)
        {
            var count = hand.Skip(suit * 9).Take(9).Sum();
            var singleLane = Enumerable.Range(0, 4).Where(s => s != state.SeatIndex).All(s => state.DingQueSuits[s] == suit);
            var blocked = suit == missing ? "own_missing_suit" :
                Enumerable.Range(0, 27).Any(t => exposed[t] > 0 && t / 9 != suit) ? "irreversible_other_suit_meld" : "";
            if (blocked.Length > 0)
            {
                result.Add(new(suit, false, blocked, singleLane, count, hand.Sum() - count,
                    null, Array.Empty<int>(), 0, Array.Empty<int>(), false, Array.Empty<FlushImprovement>()));
                continue;
            }
            var structure = engine.Analyze(hand, state.Remaining18, exposed, suit, meldCount);
            if (structure.FeasiblePatterns == 0)
            {
                result.Add(new(suit, true, "public_supply_cannot_complete", singleLane, count, hand.Sum() - count,
                    null, Array.Empty<int>(), 0, Array.Empty<int>(), false, Array.Empty<FlushImprovement>()));
                continue;
            }
            var live = structure.UsefulDraws.Sum(t => state.Remaining18[t]);
            var improvements = new List<FlushImprovement>();
            // A same-distance improvement is draw + legal discard, not merely adjacency.
            // Missing-suit cleanup and 14-tile choice are handled by the formal discard planner.
            var evaluate = isThirteen && clear;
            if (evaluate)
            {
                var work = (int[])hand.Clone();
                var supply = (int[])state.Remaining18.Clone();
                for (var draw = suit * 9; draw < suit * 9 + 9; draw++)
                {
                    if (supply[draw] <= 0 || hand[draw] >= 4 || structure.UsefulDraws.Contains(draw)) continue;
                    work[draw]++; supply[draw]--;
                    FlushImprovement? best = null;
                    for (var discard = 0; discard < 27; discard++)
                    {
                        if (work[discard] == 0 || discard == draw) continue;
                        work[discard]--;
                        var after = engine.Analyze(work, supply, exposed, suit, meldCount);
                        var afterLive = after.UsefulDraws.Sum(t => supply[t]);
                        var preservesReady = ordinaryReady && shanten.CalcStandardShanten(work, meldCount) == 0;
                        if (after.FeasiblePatterns > 0 && after.MinimumAdditionalTiles == structure.MinimumAdditionalTiles && afterLive > live &&
                            (best is null || (preservesReady && !best.PreservesOrdinaryReady) ||
                             (preservesReady == best.PreservesOrdinaryReady && afterLive > best.EffectiveCopiesAfter)))
                            best = new(draw, state.Remaining18[draw], discard, afterLive, preservesReady);
                        work[discard]++;
                    }
                    work[draw]--; supply[draw]++;
                    if (best is not null) improvements.Add(best);
                }
            }
            result.Add(new(suit, true, "structurally_reachable", singleLane, count, hand.Sum() - count,
                structure.MinimumAdditionalTiles, structure.UsefulDraws.ToArray(), live,
                structure.RequiredInEveryNearestPattern.ToArray(), evaluate, improvements.ToArray()));
        }
        return result.ToArray();
    }
}
