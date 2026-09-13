using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Codec;

public static class SichuanStateCodec
{
    public static SichuanStateView FromRaw(
        int seatIndex,
        int dealerSeat,
        int currentSeat,
        int wallCount,
        IEnumerable<int> hand18,
        IEnumerable<int> visible18,
        IEnumerable<int>? remaining18 = null,
        IEnumerable<IEnumerable<int>>? discards18 = null,
        IEnumerable<IEnumerable<int>>? melds18 = null,
        IEnumerable<IEnumerable<int>>? passedHu18 = null,
        IEnumerable<IEnumerable<int>>? passedPeng18 = null,
        IEnumerable<IEnumerable<int>>? passedGang18 = null,
        IEnumerable<int>? scores = null,
        int roundIndex = 0,
        int totalRounds = 0,
        int remainingRounds = 0,
        int visibleVersion = 0,
        int handVersion = 0,
        int strategyContextVersion = 0,
        IEnumerable<int>? dingQueSuits = null,
		IEnumerable<int>? handCounts = null,
		IEnumerable<int>? lockedFans = null,
		IEnumerable<int>? lockTurns = null,
		IEnumerable<bool>? unlockOnOwnDraw = null,
		IEnumerable<bool>? activeSeats = null,
		long eventVersion = 0,
		string informationMode = "public",
		bool exchangeThreeEnabled = false)
    {
        var hand = hand18.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
        var visible = visible18.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
        var remaining = remaining18?.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray() ??
                        Enumerable.Range(0, 27).Select(i => Math.Max(0, 4 - visible[i] - hand[i])).ToArray();

        var state = new SichuanStateView
        {
            SeatIndex = seatIndex,
            DealerSeat = dealerSeat,
            CurrentSeat = currentSeat,
            WallCount = wallCount,
            Hand18 = hand,
            Visible18 = visible,
            Remaining18 = remaining,
            Scores = scores?.Take(4).Concat(Enumerable.Repeat(0, 4)).Take(4).ToArray() ?? new int[4],
            DingQueSuits = dingQueSuits?.Take(4).Concat(Enumerable.Repeat(-1, 4)).Take(4).ToArray()
                ?? Enumerable.Repeat(-1, 4).ToArray(),
			HandCounts = handCounts?.Take(4).Concat(Enumerable.Repeat(13, 4)).Take(4).ToArray() ?? new[] { 13, 13, 13, 13 },
			LockedFans = lockedFans?.Take(4).Concat(Enumerable.Repeat(-1, 4)).Take(4).ToArray() ?? Enumerable.Repeat(-1, 4).ToArray(),
			LockTurns = lockTurns?.Take(4).Concat(Enumerable.Repeat(-1, 4)).Take(4).ToArray() ?? Enumerable.Repeat(-1, 4).ToArray(),
			UnlockOnOwnDraw = unlockOnOwnDraw?.Take(4).Concat(Enumerable.Repeat(false, 4)).Take(4).ToArray() ?? new bool[4],
			ActiveSeats = activeSeats?.Take(4).Concat(Enumerable.Repeat(true, 4)).Take(4).ToArray() ?? Enumerable.Repeat(true, 4).ToArray(),
			EventVersion = eventVersion,
			InformationMode = informationMode,
			ExchangeThreeEnabled = exchangeThreeEnabled,
            RoundIndex = roundIndex,
            TotalRounds = totalRounds,
            RemainingRounds = remainingRounds,
            VisibleVersion = visibleVersion,
            HandVersion = handVersion,
            StrategyContextVersion = strategyContextVersion
        };

        if (discards18 is not null)
        {
            var seat = 0;
            foreach (var list in discards18.Take(4))
            {
                state.Discards18[seat].AddRange(list.Where(tile => tile is >= 0 and < 27));
                seat++;
            }
        }

        if (melds18 is not null)
        {
            var seat = 0;
            foreach (var list in melds18.Take(4))
            {
                state.Melds18[seat].AddRange(list.Where(tile => tile is >= 0 and < 27));
                seat++;
            }
        }

        CopyCountMatrix(passedHu18, state.PassedHu18);
        CopyCountMatrix(passedPeng18, state.PassedPeng18);
        CopyCountMatrix(passedGang18, state.PassedGang18);

        return state;
    }

    private static void CopyCountMatrix(IEnumerable<IEnumerable<int>>? source, int[][] target)
    {
        if (source is null)
            return;
        var seat = 0;
        foreach (var list in source.Take(4))
        {
            var values = list.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
            for (var tileType = 0; tileType < 27; tileType++)
                target[seat][tileType] = Math.Max(0, values[tileType]);
            seat++;
        }
    }
}
