using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Independent means extracting the triplet into a legal Gang leaves
/// the entire legal waiting set unchanged. Live means a physical fourth copy
/// has an acquisition channel with a replacement tile still available.</summary>
public static class SichuanIndependentTriplet
{
    public static int[] LiveTargets(SichuanStateView s,int suit=-1)
    {
        if(s.WallCount<=0||s.Hand18.Sum()+3*s.OwnMeldCount!=13)return [];
        s=PublicAllocationView(s);
        var melds=SichuanDevelopmentPolicy.Melds(s,s.SeatIndex);
        var pricing=new SichuanReadyWaitPricing();
        var weights=s.Remaining18.Select(n=>(double)n).ToArray();
        if(!SichuanReadyWaitPricing.HasLegalOwnedContext(s,s.Hand18,melds))return [];
        var before=pricing.Build(s,s.Hand18,weights,melds);
        if(before is null)return [];
        var original=before.Waits.Select(w=>w.TileType).Order().ToArray();
        var possible=Enumerable.Range(0,27).Where(t=>s.Hand18[t]==3&&t/9!=s.OwnDingQueSuit
            &&(suit<0||t/9==suit)).ToArray();
        if(possible.Length==0)return [];
        var belief=new SichuanBeliefEngine().Build(s);
        var wall=new SichuanWallAvailabilityEngine().Build(s,belief);
        var offer=s.PublicEvents.LastOrDefault(e=>e.Type is not SichuanPublicEventType.Draw and not SichuanPublicEventType.Pass);
        var offset=SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(s,s.CurrentSeat,s.SeatIndex);
        var result=new List<int>();
        foreach(var t in possible)
        {
            var h=(int[])s.Hand18.Clone();h[t]-=3;
            var projected=melds.Append(new SichuanMeldView(SichuanMeldType.ConcealedGang,t,s.SeatIndex,0)).ToArray();
            if(!SichuanReadyWaitPricing.HasLegalOwnedContext(s,h,projected))continue;
            var after=pricing.Build(s,h,weights,projected);
            if(after is null||!original.SequenceEqual(after.Waits.Select(w=>w.TileType).Order()))continue;
            var offered=offer?.Type==SichuanPublicEventType.Discard&&offer.Seat==s.CurrentSeat
                &&offer.Seat!=s.SeatIndex&&offer.TileType==t;
            if(offered){result.Add(t);continue;}
            if(s.Remaining18[t]<=0)continue;
            var forced=Enumerable.Range(0,4).Where(i=>i!=s.SeatIndex&&s.ActiveSeats[i]&&!s.HasHu[i]
                &&s.DingQueSuits[i]==t/9&&s.WallCount>SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(s,s.CurrentSeat,i)+1)
                .Sum(i=>belief.SeatTileHoldProbability.GetValueOrDefault(i)?.GetValueOrDefault(t)??0);
            var opportunity=(s.WallCount>offset+1 ? wall.ExpectedCounts18[t]*SichuanDevelopmentPolicy.Draws(s)/Math.Max(1,s.WallCount):0)+forced;
            // Retain the prior public availability threshold; no book example
            // probability or newly fitted multiplier is introduced here.
            if(opportunity>=0.10)result.Add(t);
        }
        // Two individually extractable triplets are not necessarily jointly
        // independent when alternate sequence decompositions overlap.
        for(var size=result.Count;size>=1;size--)
        for(var mask=1;mask<(1<<result.Count);mask++)
        {
            var subset=result.Where((_,i)=>(mask&(1<<i))!=0).ToArray();
            if(subset.Length!=size)continue;
            var h=(int[])s.Hand18.Clone();foreach(var t in subset)h[t]-=3;
            var projected=melds.Concat(subset.Select(t=>new SichuanMeldView(SichuanMeldType.ConcealedGang,t,s.SeatIndex,0))).ToArray();
            if(!SichuanReadyWaitPricing.HasLegalOwnedContext(s,h,projected))continue;
            var after=pricing.Build(s,h,weights,projected);
            if(after is not null&&original.SequenceEqual(after.Waits.Select(w=>w.TileType).Order()))return subset;
        }
        return [];
    }

    // The legacy belief engine accepts runtime readiness/pass flags. New
    // public strategy modules deliberately never pass those inputs to it.
    internal static SichuanStateView PublicAllocationView(SichuanStateView s)
    {
        var p=new SichuanStateView{SeatIndex=s.SeatIndex,DealerSeat=s.DealerSeat,CurrentSeat=s.CurrentSeat,
            WallCount=s.WallCount,Hand18=s.Hand18,Visible18=s.Visible18,Remaining18=s.Remaining18,
            DingQueSuits=s.DingQueSuits,HandCounts=s.HandCounts,ActiveSeats=s.ActiveSeats,HasHu=s.HasHu,
            Discards18=s.Discards18,Melds18=s.Melds18,LastDrawTileType=s.LastDrawTileType,
            LastDrawOrigin=s.LastDrawOrigin,OwnDrawReason=s.OwnDrawReason,InformationMode=s.InformationMode};
        for(var i=0;i<4;i++)p.MeldViews[i].AddRange(s.MeldViews[i]);
        SichuanPublicInferenceBoundary.RestorePolicyHistory(s,p);
        return p;
    }
}
