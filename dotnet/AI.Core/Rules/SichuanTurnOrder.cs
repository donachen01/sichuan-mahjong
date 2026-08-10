using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

public static class SichuanTurnOrder
{
    public static int DrawsBeforeSeatAfterDiscard(
        SichuanStateView state,
        int discardingSeat,
        int targetSeat)
    {
        if (targetSeat is < 0 or >= 4 || !state.ActiveSeats[targetSeat])
            return Math.Max(0, state.ActiveSeats.Count(active => active) - 1);

        var draws = 0;
        var seat = discardingSeat;
        for (var step = 0; step < 4; step++)
        {
            seat = NextActiveSeat(state, seat);
            if (seat < 0 || seat == targetSeat) return draws;
            draws++;
        }
        return Math.Max(0, state.ActiveSeats.Count(active => active) - 1);
    }

    public static int DrawsBeforeOwnTurnAfterClaim(SichuanStateView state)
        => DrawsBeforeSeatAfterDiscard(state, state.SeatIndex, state.SeatIndex);

    private static int NextActiveSeat(SichuanStateView state, int fromSeat)
    {
        for (var step = 1; step <= 4; step++)
        {
            var seat = (fromSeat - step + 8) % 4;
            if (state.ActiveSeats[seat]) return seat;
        }
        return -1;
    }
}
