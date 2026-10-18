using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

public static class SichuanSelfDrawContext
{
    public static (SichuanWinType WinType,int SourceSeat) Resolve(SichuanStateView state)
    {
        var recent=state.PublicEvents.LastOrDefault(e=>e.Type is not (SichuanPublicEventType.Draw or SichuanPublicEventType.Pass));
        var recentOwnGang=recent?.Seat==state.SeatIndex && recent.Type is
            SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang;
        // Current draw reason is authoritative. A historical LastGangSeat
        // alone never turns a later ordinary draw into a replacement draw.
        var replacement=state.OwnDrawReason=="gang_draw" || state.OwnDrawReason.Length==0 && recentOwnGang;
        if(!replacement)return(SichuanWinType.SelfDraw,-1);
        if(state.OwnDrawReason=="gang_draw" && state.LastGangSeat!=state.SeatIndex && !recentOwnGang)throw new InvalidOperationException("replacement_gang_actor_mismatch");
        var point=recentOwnGang ? recent!.Type==SichuanPublicEventType.MeldedGang : state.LastGangType=="melded_gang";
        if(!point)return(SichuanWinType.GangSelfDraw,-1);
        var source=recentOwnGang && recent!.SourceSeat>=0 ? recent.SourceSeat : state.LastGangSourceSeat;
        if(source is <0 or >3 || source==state.SeatIndex)throw new InvalidOperationException("point_gang_flower_source_missing");
        return(SichuanWinType.DianGangHua,source);
    }
}
