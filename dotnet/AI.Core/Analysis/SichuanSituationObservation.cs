using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Analysis;

/// <summary>Immutable facts for explaining reassessment, never hidden hands,
/// an opponent strategy prediction, or a command to change the current route.</summary>
internal sealed record SichuanSituationObservation(int Wall, int Current, int Phase,
    int Missing, int OwnLock, string DrawContext, int[] OwnHand, int[] Remaining,
    int[] Scores, int[] HandCounts, bool[] Winners, bool[] Active, string[] Melds,
    string EventTail)
{
    internal static SichuanSituationObservation Capture(SichuanStateView s) => new(
        s.WallCount,s.CurrentSeat,s.Phase,s.OwnDingQueSuit,s.LockedFans[s.SeatIndex],
        $"{s.LastDrawOrigin}:{s.OwnDrawReason}",s.Hand18.ToArray(),s.Remaining18.ToArray(),
        s.Scores.ToArray(),s.HandCounts.ToArray(),s.HasHu.ToArray(),s.ActiveSeats.ToArray(),
        Enumerable.Range(0,4).Select(seat => s.MeldViews[seat].Count > 0
            ? string.Join(";",s.MeldViews[seat].Select(m=>$"{m.Type}:{m.TileType}"))
            : string.Join(",",s.Melds18[seat])).ToArray(),
        string.Join(";",s.PublicEvents.TakeLast(3)));

    internal string[] ChangesFrom(SichuanSituationObservation? before)
    {
        if(before is null)return ["首次观察当前牌局"];
        var facts=new List<string>();
        if(Wall!=before.Wall)facts.Add($"余墙{before.Wall}→{Wall}");
        if(Current!=before.Current)facts.Add($"当前行动座位{before.Current}→{Current}");
        if(Phase!=before.Phase)facts.Add($"行动阶段{before.Phase}→{Phase}");
        if(Missing!=before.Missing)facts.Add($"本家定缺{before.Missing}→{Missing}，重新约束合法动作");
        if(!OwnHand.SequenceEqual(before.OwnHand))facts.Add("本家整手结构更新");
        for(int seat=0;seat<4;seat++)
        {
            if(Winners[seat]!=before.Winners[seat])facts.Add(Winners[seat]
                ? $"座位{seat}胡牌退出，重算供牌、付款与轮序" : $"座位{seat}已胡状态更新");
            else if(Active[seat]!=before.Active[seat])facts.Add($"座位{seat}在局状态更新");
            if(Melds[seat]!=before.Melds[seat])facts.Add($"座位{seat}公开碰杠更新");
        }
        if(!Remaining.SequenceEqual(before.Remaining))
        {
            var tiles=Enumerable.Range(0,27).Where(t=>Remaining[t]!=before.Remaining[t]).ToArray();
            string Name(int t)=>$"{t%9+1}{new[]{"条","筒","万"}[t/9]}";
            facts.Add("可得副本更新："+string.Join("，",tiles.Take(6)
                .Select(t=>$"{Name(t)} {before.Remaining[t]}→{Remaining[t]}"))
                +(tiles.Length>6?$"等{tiles.Length}种":""));
        }
        if(!Scores.SequenceEqual(before.Scores))facts.Add("公开收支更新，按当前积分及实际付款重算");
        if(!HandCounts.SequenceEqual(before.HandCounts))facts.Add("各家手牌张数及摸打时序更新");
        if(OwnLock!=before.OwnLock)facts.Add("本家接胡限制更新");
        if(DrawContext!=before.DrawContext)facts.Add("本家摸牌来源更新，重算普通摸牌或杠后补牌");
        if(EventTail!=before.EventTail && facts.Count==0)facts.Add("公开行动证据更新");
        return facts.ToArray();
    }
}
