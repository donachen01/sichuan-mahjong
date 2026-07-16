using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Search;

public sealed record SichuanSimulatedHandState(
    int[] Hand27,
    int MeldCount,
    int LockedFan,
    bool OwnDrawUnlockPending,
    int WallCount,
    string LastAction);

public sealed class SichuanActionTransitionEngine
{
    public SichuanSimulatedHandState FromState(SichuanStateView state)
        => new(
            (int[])state.Hand18.Clone(),
            Math.Max(0, state.Melds18[state.SeatIndex].Count / 3),
            state.LockedFans[state.SeatIndex],
            state.UnlockOnOwnDraw[state.SeatIndex],
            state.WallCount,
            "state");

    public SichuanSimulatedHandState ApplyDiscard(SichuanSimulatedHandState source, int tileType)
        => source with { Hand27 = CloneAndRemove(source.Hand27, tileType, 1), LastAction = $"discard:{tileType}" };

    public SichuanSimulatedHandState ApplyPeng(SichuanSimulatedHandState source, int tileType)
        => source with { Hand27 = CloneAndRemove(source.Hand27, tileType, 2), MeldCount = source.MeldCount + 1, LastAction = $"peng:{tileType}" };

    public SichuanSimulatedHandState ApplyMeldedGang(SichuanSimulatedHandState source, int tileType)
        => source with { Hand27 = CloneAndRemove(source.Hand27, tileType, 3), MeldCount = source.MeldCount + 1, WallCount = Math.Max(0, source.WallCount - 1), LastAction = $"melded_gang:{tileType}" };

    public SichuanSimulatedHandState ApplyConcealedGang(SichuanSimulatedHandState source, int tileType)
        => source with { Hand27 = CloneAndRemove(source.Hand27, tileType, 4), MeldCount = source.MeldCount + 1, WallCount = Math.Max(0, source.WallCount - 1), LastAction = $"concealed_gang:{tileType}" };

    public SichuanSimulatedHandState ApplyAddedGang(SichuanSimulatedHandState source, int tileType)
        => source with { Hand27 = CloneAndRemove(source.Hand27, tileType, 1), WallCount = Math.Max(0, source.WallCount - 1), LastAction = $"added_gang:{tileType}" };

    public SichuanSimulatedHandState ApplyPassedHu(SichuanSimulatedHandState source, int currentFan)
        => source with { LockedFan = Math.Max(source.LockedFan, currentFan), OwnDrawUnlockPending = true, LastAction = "pass_hu" };

    public SichuanSimulatedHandState ApplyOwnDraw(SichuanSimulatedHandState source, int tileType)
    {
        var hand = (int[])source.Hand27.Clone();
        if (tileType is >= 0 and < 27) hand[tileType]++;
        return source with
        {
            Hand27 = hand,
            LockedFan = source.OwnDrawUnlockPending ? -1 : source.LockedFan,
            OwnDrawUnlockPending = false,
            WallCount = Math.Max(0, source.WallCount - 1),
            LastAction = $"draw:{tileType}"
        };
    }

    private static int[] CloneAndRemove(IReadOnlyList<int> source, int tileType, int count)
    {
        var hand = source.ToArray();
        if (tileType is < 0 or >= 27 || hand[tileType] < count)
            throw new InvalidOperationException($"Illegal transition: tile={tileType}, required={count}.");
        hand[tileType] -= count;
        return hand;
    }
}
