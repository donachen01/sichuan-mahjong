using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>
/// Builds the only state representation accepted by the public particle model.
/// The projection contains observable tile allocations and ordered public
/// decisions, but never runtime-only readiness flags, hidden draw events, or
/// cached pass matrices.
/// </summary>
internal static class SichuanPublicInferenceBoundary
{
    public static bool TryProject(SichuanStateView state, out SichuanStateView projection, out string reason, bool reaction = false, int sourceSeat = -1, bool robGang = false, bool waiting = false)
    {
        projection = new SichuanStateView();
        reason = Validate(state, reaction, sourceSeat, robGang, waiting) ?? string.Empty;
        if (reason.Length > 0) return false;

        projection = new SichuanStateView {
            SeatIndex = state.SeatIndex,
            OwnDrawReason=state.OwnDrawReason,LastGangSourceSeat=state.LastGangSourceSeat,
            LastGangSeat=state.LastGangSeat,LastGangTileType=state.LastGangTileType,LastGangType=state.LastGangType,
            LastGangScoreEligible=state.LastGangScoreEligible,
            PendingAddedGangScoreEligible=state.PendingAddedGangScoreEligible,
            LastDrawTileType=state.LastDrawTileType,LastDrawOrigin=state.LastDrawOrigin,
            DealerSeat = state.DealerSeat,
            CurrentSeat = reaction ? sourceSeat : state.SeatIndex,
            WallCount = state.WallCount,
            Hand18 = (int[])state.Hand18.Clone(),
            Visible18 = (int[])state.Visible18.Clone(),
            Remaining18 = (int[])state.Remaining18.Clone(),
            HandCounts = (int[])state.HandCounts.Clone(),
            WonScores = (int[])state.WonScores.Clone(),
            RoundIndex = state.RoundIndex,
            TurnIndex = state.TurnIndex,
            DingQueSuits = (int[])state.DingQueSuits.Clone(),
            ActiveSeats = (bool[])state.ActiveSeats.Clone(),
            HasHu = (bool[])state.HasHu.Clone(),
            Discards18 = state.Discards18.Select(d => d.ToList()).ToArray(),
            Melds18 = state.Melds18.Select(m => m.ToList()).ToArray()
        };

        for (var seat = 0; seat < 4; seat++)
            projection.MeldViews[seat].AddRange(state.MeldViews[seat]);
        // Keep public Hu/meld facts even though their timing has no hand-
        // strength likelihood model yet: they consume rivers and constrain
        // completed hands. Draw identities remain private. A Pass is retained only when its
        // own legal alternatives were explicitly recorded. Opponent passes
        // expose private legality and are never inference inputs.
        foreach (var item in state.PublicEvents.Where(IsInferenceEvent)
            .Where(item => item.Type != SichuanPublicEventType.Pass || item.Seat == state.SeatIndex))
        {
            projection.PublicEvents.Add(new(
                projection.PublicEvents.Count,
                item.TurnIndex,
                item.Seat,
                item.Type,
                item.TileType,
                item.Type == SichuanPublicEventType.Discard ? item.Origin : SichuanTileOrigin.Unknown,
                item.SourceSeat,
                item.WallCountAfter,
                item.Seat==state.SeatIndex && item.CanHu,
                item.Seat==state.SeatIndex && item.CanPeng,
                item.Seat==state.SeatIndex && item.CanGang,
                item.GangScoreEligible));
        }
        return true;
    }

    // Particle likelihood and continuation-policy history have different
    // needs. Restore rule/tempo evidence only AFTER particles were sampled.
    // Private opponent draw identities and pass alternatives remain excluded.
    internal static void RestorePolicyHistory(SichuanStateView original,SichuanStateView projection)
    {
        projection.PublicEvents.Clear();
        projection.PublicEvents.AddRange(original.PublicEvents
            .Where(e=>e.Type!=SichuanPublicEventType.Pass||e.Seat==original.SeatIndex)
            .Where(e=>e.Type!=SichuanPublicEventType.Draw||e.Seat==original.SeatIndex||e.TileType==-1)
            .Select(e=>e.Seat==original.SeatIndex?e:e with {CanHu=false,CanPeng=false,CanGang=false}));
    }

    public static bool ParticleConserves(SichuanStateView state, SichuanMahjong.AI.Core.Inference.SichuanHiddenHandParticle particle)
        => particle.Wall27.Sum() == state.WallCount
            && Enumerable.Range(0, 4).Where(seat => seat != state.SeatIndex)
                .All(seat => particle.Hands27[seat].Sum() == state.HandCounts[seat])
            && Enumerable.Range(0, 27).All(tile => particle.Wall27[tile]
                + particle.Hands27.Sum(hand => hand[tile]) == state.Remaining18[tile]);

    private static bool IsInferenceEvent(SichuanPublicEvent item)
        => item.Type == SichuanPublicEventType.Discard
            || item.Type is SichuanPublicEventType.Peng or SichuanPublicEventType.MeldedGang
                or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang or SichuanPublicEventType.Hu
            || item.Type == SichuanPublicEventType.Pass && (item.CanHu || item.CanPeng || item.CanGang);

    private static string? Validate(SichuanStateView state, bool reaction, int sourceSeat, bool robGang, bool waiting)
    {
        if (state.InformationMode != "public") return "public_mode_required";
        if (state.SeatIndex is < 0 or > 3 || (!reaction && state.CurrentSeat != state.SeatIndex))
            return "own_discard_phase_required";
        if (reaction && (sourceSeat is < 0 or > 3 || sourceSeat == state.SeatIndex))
            return "invalid_reaction_source";
        if (state.ActiveSeats.Length != 4 || state.HasHu.Length != 4
            || !state.ActiveSeats[state.SeatIndex] || state.HasHu[state.SeatIndex]
            || Enumerable.Range(0, 4).Any(seat => state.ActiveSeats[seat] == state.HasHu[seat]))
            return "invalid_active_seat_state";
        if (state.ActiveSeats.Count(active => active) < 2)
            return "insufficient_active_seats";
        if (state.HandCounts.Length != 4 || state.DingQueSuits.Length != 4
            || state.DingQueSuits.Any(s => s is < 0 or > 2)
            || state.Hand18.Length != 27 || state.Visible18.Length != 27 || state.Remaining18.Length != 27
            || state.Discards18.Length != 4 || state.Melds18.Length != 4 || state.WallCount is < 0 or > 108)
            return "invalid_public_dimensions";
        if (Enumerable.Range(0, 27).Any(tile => state.Hand18[tile] is < 0 or > 4
            || state.Visible18[tile] is < 0 or > 4 || state.Remaining18[tile] is < 0 or > 4
            || state.Hand18[tile] + state.Visible18[tile] + state.Remaining18[tile] != 4))
            return "four_copy_conservation_failed";

        var publicCounts = new int[27];
        var recordedDiscards = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
        var claimedDiscardEvents = new HashSet<long>();
        var externalHuTiles = new HashSet<(long Origin, int Source, int Tile)>();
        SichuanPublicEvent? offer=null;
        foreach (var item in state.PublicEvents)
        {
            if (item.Seat is < 0 or > 3) continue;
            if (item.Type == SichuanPublicEventType.Discard && item.TileType is >= 0 and < 27)
            {
                recordedDiscards[item.Seat].Add(item.TileType);
                offer=item;
                continue;
            }
            if(item.Type is SichuanPublicEventType.AddedGang or SichuanPublicEventType.ConcealedGang)
            { offer=item; continue; }
            if (item.Type is not (SichuanPublicEventType.Peng or SichuanPublicEventType.MeldedGang or SichuanPublicEventType.Hu)
                || item.SourceSeat is < 0 or > 3 || item.SourceSeat == item.Seat
                || item.TileType is < 0 or > 26) continue;
            var meldGroups = state.Melds18[item.Seat].Distinct().Count();
            var concealedBase = 13 - 3 * meldGroups;
            // A self-draw can transfer gang money from another seat; its Hu
            // source does not mean the winning tile came from that seat.
            if (item.Type == SichuanPublicEventType.Hu && state.HandCounts[item.Seat] != concealedBase)
                continue;
            // River count/TurnIndex can repeat after Hu consumes a discard.
            // Distinct discards use their stable event IDs; multiple winners
            // on the SAME discard share one origin. Added-Gang Hu has no river
            // tile to remove. Missing old source events never justify deleting
            // an unrelated earlier same-type river tile.
            var origin=offer is not null && offer.Seat==item.SourceSeat && offer.TileType==item.TileType?offer:null;
            var claim = (Origin:origin?.EventIndex??-(long)item.TurnIndex-1, Source: item.SourceSeat, Tile: item.TileType);
            if (item.Type == SichuanPublicEventType.Hu) externalHuTiles.Add(claim);
            if(item.Type!=SichuanPublicEventType.Hu && origin?.Type==SichuanPublicEventType.Discard
                && claimedDiscardEvents.Contains(origin.EventIndex))return "public_discard_claim_reused_after_hu";
            if(item.Type!=SichuanPublicEventType.Hu)offer=null;
            if(origin?.Type!=SichuanPublicEventType.Discard || !claimedDiscardEvents.Add(origin.EventIndex))continue;
            var history = recordedDiscards[item.SourceSeat];
            var index = history.FindLastIndex(tile => tile == item.TileType);
            if (index >= 0) history.RemoveAt(index);
        }
        for (var seat = 0; seat < 4; seat++)
        {
            if (state.Melds18[seat].Concat(state.Discards18[seat]).Any(tile => tile is < 0 or > 26))
                return "unknown_public_tiles_not_supported";
            var meldGroups = state.Melds18[seat].GroupBy(tile => tile).ToArray();
            if (meldGroups.Length > 4 || meldGroups.Any(group => group.Count() is not (3 or 4)
                || group.Key / 9 == state.DingQueSuits[seat]))
                return "illegal_public_melds";
            var baseHandSize = 13 - 3 * meldGroups.Length;
            var handSizeValid = seat == state.SeatIndex
                ? state.HandCounts[seat] == baseHandSize + (reaction || waiting ? 0 : 1) && state.Hand18.Sum() == baseHandSize + (reaction || waiting ? 0 : 1)
                : state.HandCounts[seat] == baseHandSize
                    || (state.HasHu[seat] || reaction && robGang && seat == sourceSeat) && state.HandCounts[seat] == baseHandSize + 1;
            if (!handSizeValid) return "public_hand_size_failed";
            foreach (var tile in state.Melds18[seat].Concat(state.Discards18[seat])) publicCounts[tile]++;
            if (!recordedDiscards[seat].SequenceEqual(state.Discards18[seat]))
                return "public_discard_history_incomplete";
        }
        foreach (var claim in externalHuTiles) publicCounts[claim.Tile]++;
        if (!publicCounts.SequenceEqual(state.Visible18)) return "public_allocation_incomplete";
        if (state.Remaining18.Sum() != state.WallCount + Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex).Sum(seat => state.HandCounts[seat]))
            return "hidden_pool_size_mismatch";
        if (state.Hand18.Skip(state.OwnDingQueSuit * 9).Take(9).Any(count => count > 0))
            return "unresolved_missing_suit";
        if (state.PublicEvents.Any(item => item.Seat is < 0 or > 3)
            || state.PublicEvents.Zip(state.PublicEvents.Skip(1))
                .Any(pair => pair.First.EventIndex >= pair.Second.EventIndex)
            || state.PublicEvents.Where(item => item.Type == SichuanPublicEventType.Discard)
                .Any(item => item.TileType is < 0 or > 26 || !Enum.IsDefined(item.Origin))
            || state.PublicEvents.Where(item => item.Type == SichuanPublicEventType.Pass)
                .Any(item => item.TileType is < 0 or > 26 || item.SourceSeat is < 0 or > 3
                    || item.SourceSeat == item.Seat || !item.CanHu && !item.CanPeng && !item.CanGang))
            return "invalid_public_event";
        return null;
    }
}
