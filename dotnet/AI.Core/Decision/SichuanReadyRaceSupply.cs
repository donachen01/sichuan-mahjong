using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Public compulsory-discard channels only, in actual draw order.
/// A concealed opponent hand is never read and voluntary releases are not
/// assigned an invented fixed probability.</summary>
public static class SichuanReadyRaceSupply
{
    internal static IReadOnlyList<SichuanReadyRaceGroup> ForStopping(SichuanStateView s,SichuanReadyPrice ready)
    {
        return Build(s,ready,separatePrices:true);
    }
    internal static bool SupportsStopping(IReadOnlyList<SichuanReadyRaceGroup> groups)=>
        groups.Count is >0 and <=3&&groups.Select(g=>g.ForcedDiscardMask).Distinct().Count()==1;
    public static IReadOnlyList<SichuanReadyRaceGroup> Build(SichuanStateView s,SichuanReadyPrice ready,bool separatePrices=false)
    {
        // Existing passed-Hu windows need a richer lock/unlock state than this
        // fixed-wait model. Retain the conservative self-draw-only path there.
        if(s.InformationMode!="public" || s.OwnDingQueSuit is <0 or >2
            || s.SeatIndex is <0 or >3 || s.LockedFans[s.SeatIndex]>=0)return Array.Empty<SichuanReadyRaceGroup>();
        var order=new List<int>{s.SeatIndex};
        for(int offset=1;offset<=3;offset++)
        {
            var seat=(s.SeatIndex-offset+4)%4;
            if(s.ActiveSeats[seat]&&!s.HasHu[seat])order.Add(seat);
        }
        return ready.Waits.Where(w=>w.PublicWallWeight>0)
            .GroupBy(w=>(Suit:w.TileType/9,Score:separatePrices?w.HandScore:0,Self:separatePrices?w.SelfDrawPerPayer:0)).Select(g=>
        {
            var mass=g.Sum(w=>w.PublicWallWeight);var mask=0;
            for(int actor=1;actor<order.Count;actor++)if(SichuanOpponentTimeline.MustOfferDraw(s,order[actor],g.Key.Suit*9))mask|=1<<actor;
            return new SichuanReadyRaceGroup(mass,g.Sum(w=>w.PublicWallWeight*w.SelfDrawPerPayer)/mass,
                g.Sum(w=>w.PublicWallWeight*w.HandScore)/mass,mask){TileTypes=g.Select(w=>w.TileType).ToArray()};
        }).ToArray();
    }
}
