using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

internal sealed class SichuanHuRefusalHistory
{
    internal SichuanPublicEvent[] Events { get; }
    internal SichuanPublicEvent[] Refusals { get; }
    internal int Used => Refusals.Length;
    internal int OwnRound { get; }
    internal bool GangRealized { get; }
    internal static bool IsGang(SichuanPublicEventType t) => t is SichuanPublicEventType.MeldedGang
        or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang;
    internal SichuanHuRefusalHistory(SichuanStateView s)
    {
        Events=s.PublicEvents.Where(e=>e.Type!=SichuanPublicEventType.Pass||e.Seat==s.SeatIndex)
            .Where(e=>e.Type!=SichuanPublicEventType.Draw||e.Seat==s.SeatIndex||e.TileType==-1)
            .OrderBy(e=>e.EventIndex).ToArray();
        Refusals=Events.Where(e=>e.Seat==s.SeatIndex&&e.CanHu&&e.Type is SichuanPublicEventType.Pass
            or SichuanPublicEventType.Peng or SichuanPublicEventType.MeldedGang)
            .DistinctBy(e=>e.EventIndex).DistinctBy(e=>(e.TurnIndex,e.SourceSeat,e.TileType)).ToArray();
        GangRealized=Used>0&&Events.Any(e=>e.Seat==s.SeatIndex
            &&e.EventIndex>=Refusals[0].EventIndex&&IsGang(e.Type)&&e.GangScoreEligible);
        var draws=0;SichuanPublicEvent? previous=null;
        foreach(var e in Events)
        {
            if(e.Type==SichuanPublicEventType.Pass)continue;
            if(e.Seat==s.SeatIndex&&e.Type==SichuanPublicEventType.Draw
                &&!(previous?.Seat==s.SeatIndex&&IsGang(previous.Type)))draws++;
            previous=e;
        }
        OwnRound=Events.Any(e=>e.Seat==s.SeatIndex&&e.Type==SichuanPublicEventType.Draw)
            ?Math.Max(1,draws+(s.DealerSeat==s.SeatIndex?1:0))
            :1+Events.Count(e=>e.Seat==s.SeatIndex&&e.Type==SichuanPublicEventType.Discard);
    }

    internal static bool IsScoredGang(SichuanStateView state, SichuanMeldView meld)
    {
        if(meld.Type!=SichuanMeldType.AddedGang)return meld.Type!=SichuanMeldType.Peng;
        var recorded=state.PublicEvents.LastOrDefault(e=>e.Seat==state.SeatIndex
            &&e.Type==SichuanPublicEventType.AddedGang&&e.TileType==meld.TileType);
        if(recorded is not null)return recorded.GangScoreEligible;
        return state.LastGangSeat==state.SeatIndex && state.LastGangType=="add_gang"
            &&state.LastGangTileType==meld.TileType&&state.LastGangScoreEligible;
    }

    // Reconstruct only OUR known tiles and public counts. No private opponent
    // draw is needed. Unknown own draws mean insufficient evidence, never a
    // fabricated reconstruction. This preserves narrow-route cash-out even if
    // the current wait widened after the Gang or a checkpoint was restored.
    internal int[]? FirstRefusalWaits(SichuanStateView s)
    {
        if(Used==0)return null;
        var hand=(int[])s.Hand18.Clone();var visible=(int[])s.Visible18.Clone();
        var melds=SichuanDevelopmentPolicy.Melds(s,s.SeatIndex);
        foreach(var e in Events.Where(e=>e.EventIndex>=Refusals[0].EventIndex).Reverse())
        {
            var publicCount=e.Type switch {SichuanPublicEventType.Discard=>1,SichuanPublicEventType.Peng=>2,
                SichuanPublicEventType.MeldedGang=>3,SichuanPublicEventType.ConcealedGang=>4,
                SichuanPublicEventType.AddedGang=>1,_=>0};
            if(publicCount>0)
            {
                if(e.TileType is <0 or >26)return null;
                visible[e.TileType]-=publicCount;
            }
            if(e.Seat!=s.SeatIndex)continue;
            if(e.Type==SichuanPublicEventType.Draw)
            {if(e.TileType is <0 or >26)return null;hand[e.TileType]--;}
            else if(e.Type==SichuanPublicEventType.Discard)hand[e.TileType]++;
            else if(e.Type is SichuanPublicEventType.Peng or SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang)
            {
                hand[e.TileType]+=publicCount;
                var index=melds.FindLastIndex(m=>m.TileType==e.TileType);
                if(index<0)return null;melds.RemoveAt(index);
            }
            else if(e.Type==SichuanPublicEventType.AddedGang)
            {
                hand[e.TileType]++;
                var index=melds.FindLastIndex(m=>m.TileType==e.TileType);
                if(index<0)return null;melds[index]=melds[index] with {Type=SichuanMeldType.Peng};
            }
        }
        var remaining=Enumerable.Range(0,27).Select(t=>4-hand[t]-visible[t]).ToArray();
        if(hand.Sum()+3*melds.Count!=13 || hand.Any(n=>n<0||n>4)
            || visible.Any(n=>n<0||n>4)||remaining.Any(n=>n<0||n>4))return null;
        var counts=new int[3];
        foreach(var w in new SichuanExactHandAnalyzer().EnumerateWaits(hand,remaining,melds.Count))
            if(w.TileType/9!=s.OwnDingQueSuit)counts[w.TileType/9]+=remaining[w.TileType];
        return counts.Sum()>0?counts:null;
    }
}
