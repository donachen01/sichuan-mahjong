using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public static class SichuanOpeningClearPolicy
{
    public static SichuanCandidateDetail? SelectRaceTempo(SichuanStateView state, int stage, int target,
        IReadOnlyList<Inference.SichuanOpeningObservation> observations, IReadOnlyList<SichuanCandidateDetail> candidates, int currentTile)
    {
        if (stage != 0 || target < 0 || state.OwnDingQueSuit is < 0 or > 2
            || Enumerable.Range(state.OwnDingQueSuit*9,9).Any(t=>state.Hand18[t]>0)) return null;
        var race = observations.Any(o => o.Active && o.FirstClearDiscard is 1 or 2 && o.FocusSuit >= 0
            && Enumerable.Range(0,4).Where(s=>s!=o.Seat).All(s=>state.DingQueSuits[s]==o.FocusSuit));
        if (!race || Enumerable.Range(0,4).Any(s=>state.DingQueSuits[s]==target)) return null;
        var current = candidates.FirstOrDefault(c=>c.TileType==currentTile);
        return current is null ? null : candidates.Where(c=>c.Shanten<current.Shanten && c.Danger<=current.Danger)
            .OrderBy(c=>c.Shanten).ThenByDescending(c=>c.LiveUkeire).FirstOrDefault();
    }

    public static int Select(SichuanStateView state, int stage, IReadOnlyList<SichuanCandidateDetail> candidates)
    {
        var missing = state.OwnDingQueSuit;
        // This is an early mandatory-clearing policy, never a late defensive
        // override. Explicit ready/called opponents retain normal risk choice.
        if (stage != 0 || missing is < 0 or > 2 || Enumerable.Range(0,4).Any(s => s != state.SeatIndex
            && state.ActiveSeats[s] && !state.HasHu[s] && (state.IsReady[s] || state.IsCalled[s]))) return -1;
        var legal = candidates.Where(c => c.TileType / 9 == missing && state.Hand18[c.TileType] > 0).ToArray();
        if (legal.Length == 0) return -1;
        var receivers = Enumerable.Range(0,4).Where(s => s != state.SeatIndex && state.ActiveSeats[s]
            && !state.HasHu[s] && state.DingQueSuits[s] != missing).ToArray();
        int Disruption(int tile)
        {
            if (receivers.Length != 1) return 0;
            var exposed = state.Melds18[receivers[0]];
            var rank = tile % 9;
            var lost = 0;
            // How many still-possible neighboring sequences lose a physical
            // supporting copy when this tile is locked into a claim? This is
            // structural disruption, not access to the receiver's hand.
            for (var start = Math.Max(0,rank-2); start <= Math.Min(6,rank); start++)
                if (Enumerable.Range(start,3).Where(r => r != rank)
                    .All(r => exposed.Count(t => t == missing*9+r) < 3)) lost++;
            return lost;
        }
        return legal.OrderBy(c => state.Visible18[c.TileType] > 0 ? 1 : 0)
            .ThenBy(c => Disruption(c.TileType))
            .ThenBy(c => c.TileType % 9 is 0 or 8 ? 0 : c.TileType % 9 is 1 or 7 ? 1 : 2)
            .ThenByDescending(c => c.Score).First().TileType;
    }
}
