using System.Text;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Analysis;

public static class SichuanStateFingerprint
{
    public static string BuildTurnKey(SichuanStateView state, bool preferCsharp, bool forceLightweight)
    {
        var builder = new StringBuilder(512);
		builder.Append("seat=").Append(state.SeatIndex)
			.Append("|policy=").Append(state.PolicyVariant)
			.Append("|exchange3=").Append(state.ExchangeThreeEnabled ? 1 : 0)
            .Append("|dealer=").Append(state.DealerSeat)
            .Append("|current=").Append(state.CurrentSeat)
            .Append("|wall=").Append(state.WallCount)
            .Append("|turn=").Append(state.TurnIndex)
            .Append("|phase=").Append(state.Phase)
            .Append("|round=").Append(state.RoundIndex)
            .Append("|totalRounds=").Append(state.TotalRounds)
            .Append("|remainingRounds=").Append(state.RemainingRounds)
            .Append("|visibleVersion=").Append(state.VisibleVersion)
            .Append("|handVersion=").Append(state.HandVersion)
            .Append("|strategyContextVersion=").Append(state.StrategyContextVersion)
            .Append("|lastDraw=").Append(state.LastDrawTileType)
            .Append("|preferCsharp=").Append(preferCsharp ? 1 : 0)
            .Append("|light=").Append(forceLightweight ? 1 : 0);

        AppendVector(builder, "hand", state.Hand18);
        AppendVector(builder, "visible", state.Visible18);
        AppendVector(builder, "remain", state.Remaining18);
        AppendVector(builder, "scores", state.Scores);
        AppendVector(builder, "dingQue", state.DingQueSuits);

        for (var seat = 0; seat < 4; seat++)
        {
            AppendList(builder, $"d{seat}", state.Discards18[seat]);
            AppendList(builder, $"m{seat}", state.Melds18[seat]);
            builder.Append("|bj").Append(seat).Append('=').Append(state.IsCalled[seat] ? 1 : 0);
            builder.Append("|rd").Append(seat).Append('=').Append(state.IsReady[seat] ? 1 : 0);
            builder.Append("|hu").Append(seat).Append('=').Append(state.HasHu[seat] ? 1 : 0);
        }

        return builder.ToString();
    }

    private static void AppendVector(StringBuilder builder, string name, IReadOnlyList<int> values)
    {
        builder.Append('|').Append(name).Append('=');
        for (var index = 0; index < values.Count; index++)
        {
            if (index > 0) builder.Append(',');
            builder.Append(values[index]);
        }
    }

    private static void AppendList(StringBuilder builder, string name, IReadOnlyList<int> values)
    {
        builder.Append('|').Append(name).Append('=');
        for (var index = 0; index < values.Count; index++)
        {
            if (index > 0) builder.Append(',');
            builder.Append(values[index]);
        }
    }
}
