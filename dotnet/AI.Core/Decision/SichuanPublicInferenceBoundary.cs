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
    public static bool TryProject(SichuanStateView state, out SichuanStateView projection, out string reason)
    {
        projection = new SichuanStateView();
        reason = Validate(state) ?? string.Empty;
        if (reason.Length > 0) return false;

        projection = new SichuanStateView {
            SeatIndex = state.SeatIndex,
            CurrentSeat = state.SeatIndex,
            WallCount = state.WallCount,
            Hand18 = (int[])state.Hand18.Clone(),
            Visible18 = (int[])state.Visible18.Clone(),
            Remaining18 = (int[])state.Remaining18.Clone(),
            HandCounts = (int[])state.HandCounts.Clone(),
            DingQueSuits = (int[])state.DingQueSuits.Clone(),
            ActiveSeats = (bool[])state.ActiveSeats.Clone(),
            HasHu = (bool[])state.HasHu.Clone(),
            Discards18 = state.Discards18.Select(d => d.ToList()).ToArray(),
            Melds18 = state.Melds18.Select(m => m.ToList()).ToArray()
        };

        // Draw events reveal no tile identity to opponents. Hu and meld timing
        // are not likelihood features yet. A Pass is retained only when its
        // legal public alternatives were explicitly recorded.
        foreach (var item in state.PublicEvents.Where(IsInferenceEvent))
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
                item.CanHu,
                item.CanPeng,
                item.CanGang));
        }
        return true;
    }

    public static bool ParticleConserves(SichuanStateView state, SichuanMahjong.AI.Core.Inference.SichuanHiddenHandParticle particle)
        => particle.Wall27.Sum() == state.WallCount
            && Enumerable.Range(0, 4).Where(seat => seat != state.SeatIndex)
                .All(seat => particle.Hands27[seat].Sum() == state.HandCounts[seat])
            && Enumerable.Range(0, 27).All(tile => particle.Wall27[tile]
                + particle.Hands27.Sum(hand => hand[tile]) == state.Remaining18[tile]);

    private static bool IsInferenceEvent(SichuanPublicEvent item)
        => item.Type == SichuanPublicEventType.Discard
            || item.Type == SichuanPublicEventType.Pass && (item.CanHu || item.CanPeng || item.CanGang);

    private static string? Validate(SichuanStateView state)
    {
        if (state.InformationMode != "public") return "public_mode_required";
        if (state.SeatIndex is < 0 or > 3 || state.CurrentSeat != state.SeatIndex)
            return "own_discard_phase_required";
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
                ? state.HandCounts[seat] == baseHandSize + 1 && state.Hand18.Sum() == baseHandSize + 1
                : state.HandCounts[seat] == baseHandSize
                    || state.HasHu[seat] && state.HandCounts[seat] == baseHandSize + 1;
            if (!handSizeValid) return "public_hand_size_failed";
            foreach (var tile in state.Melds18[seat].Concat(state.Discards18[seat])) publicCounts[tile]++;
            var orderedDiscards = state.PublicEvents
                .Where(item => item.Seat == seat && item.Type == SichuanPublicEventType.Discard)
                .Select(item => item.TileType);
            if (!orderedDiscards.SequenceEqual(state.Discards18[seat]))
                return "public_discard_history_incomplete";
        }
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
