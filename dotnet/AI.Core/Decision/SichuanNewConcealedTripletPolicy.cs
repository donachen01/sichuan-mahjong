using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanTripletOption(int Discard,int LiveCopies,int WaitSuit,
    bool KeepsTriplet,double LocalOptionValue,double FourthInWallOptionValue,double ImmediateDiscardLoss,int[] Waits);
public sealed record SichuanNewTripletAssessment(int Tile,int SelectedDiscard,string Status,
    SichuanTripletOption[] Options);

/// <summary>A newly drawn third copy creates a real concealed-Gang option.
/// Compare ready successors separately from Ron-refusal discipline. This is a
/// bounded one-Gang, fixed-opponent local model, not terminal settlement EV.
/// No sampled future order, book tile identifiers or fitted bonuses are used.</summary>
public sealed class SichuanNewConcealedTripletPolicy
{
    public SichuanNewTripletAssessment Evaluate(SichuanStateView s,int fallback,
        IReadOnlyList<SichuanCandidateDetail>? candidates=null)
    {
        s=SichuanIndependentTriplet.PublicAllocationView(s);
        var tile=s.LastDrawTileType;
        SichuanNewTripletAssessment Exit(string why)=>new(tile,fallback,why,[]);
        if(s.InformationMode!="public"||tile is <0 or >26||s.CurrentSeat!=s.SeatIndex||s.Hand18[tile]!=3
            ||tile/9==s.OwnDingQueSuit||s.Hand18.Sum()+3*s.OwnMeldCount!=14
            ||s.WallCount<=1)return Exit("no_new_triplet_option");
        var last=s.PublicEvents.LastOrDefault(e=>e.Type!=SichuanPublicEventType.Pass);
        if(last?.Seat!=s.SeatIndex||last.Type!=SichuanPublicEventType.Draw||last.TileType!=tile)
            return Exit("new_triplet_draw_unconfirmed");
        if(new SichuanPublicDangerEvaluator().Evaluate(s).Level>0
            ||SichuanOpponentWideBedDefense.Applies(s))return Exit("defensive_wide_wait_first");
        var melds=SichuanDevelopmentPolicy.Melds(s,s.SeatIndex);
        if(!SichuanReadyWaitPricing.HasLegalOwnedContext(s,s.Hand18,melds))return Exit("illegal_owned_context");
        var belief=new SichuanBeliefEngine().Build(s);
        var wall=new SichuanWallAvailabilityEngine().Build(s,belief);
        var options=new List<SichuanTripletOption>();
        for(var d=0;d<27;d++)
        {
            if(s.Hand18[d]<=0)continue;
            var h=(int[])s.Hand18.Clone();h[d]--;
            var price=new SichuanReadyWaitPricing().Build(s,h,wall.ExpectedCounts18,melds);
            if(price is not {HasDrawableWait:true})continue;
            // Multiple prices/suits need a richer model. Leave those to the
            // existing engine instead of averaging away valuable wait types.
            if(price.Waits.Select(w=>(w.TileType/9,w.HandScore,w.SelfDrawPerPayer)).Distinct().Count()!=1)continue;
            var keeps=h[tile]==3;
            SichuanReadyPrice? after=null;
            if(keeps)
            {
                if(s.Remaining18[tile]!=1||wall.ExpectedCounts18[tile]<=0)continue;
                var reduced=(int[])h.Clone();reduced[tile]-=3;
                var gang=melds.Append(new SichuanMeldView(SichuanMeldType.ConcealedGang,tile,s.SeatIndex,0)).ToArray();
                if(!SichuanReadyWaitPricing.HasLegalOwnedContext(s,reduced,gang))continue;
                after=new SichuanReadyWaitPricing().Build(s,reduced,wall.ExpectedCounts18,gang);
                if(after is null||!price.Waits.Select(w=>w.TileType).SequenceEqual(after.Waits.Select(w=>w.TileType))
                    ||after.Waits.Select(w=>(w.HandScore,w.SelfDrawPerPayer)).Distinct().Count()!=1)continue;
            }
            var ws=price.Waits.Select(w=>w.TileType).ToArray();
            var value=OptionValue(s,tile,price,after,h,melds,wall);
            var availableValue=after is null?value:OptionValue(s,tile,price,after,h,melds,wall,1);
            var loss=candidates?.FirstOrDefault(c=>c.TileType==d)?.ExpectedDealInLoss??0;
            options.Add(new(d,ws.Sum(t=>s.Remaining18[t]),ws[0]/9,keeps,value,availableValue,loss,ws));
        }
        var incumbent=options.FirstOrDefault(o=>o.Discard==fallback);
        if(incumbent is null||!options.Any(o=>o.KeepsTriplet)||!options.Any(o=>!o.KeepsTriplet))
            return new(tile,fallback,"no_comparable_ready_options",options.ToArray());
        double Net(SichuanTripletOption o)=>o.LocalOptionValue-o.ImmediateDiscardLoss;
        var wide=options.OrderByDescending(o=>o.LiveCopies).ThenByDescending(Net)
            .ThenBy(o=>o.Discard==fallback?0:1).First();
        var missing=Enumerable.Range(0,4).Count(i=>i!=s.SeatIndex&&s.DingQueSuits[i]==wide.WaitSuit);
        if(missing>=2)
            return new(tile,wide.Discard,"TWO_MISSING_NEW_TRIPLET_KEEP_WIDE_WAIT",options.ToArray());
        var best=options.OrderByDescending(Net).ThenByDescending(o=>o.LiveCopies)
            .ThenBy(o=>o.Discard==fallback?0:1).First();
        int Channels(int targetSuit)=>Enumerable.Range(0,4).Count(i=>i!=s.SeatIndex&&s.ActiveSeats[i]&&!s.HasHu[i]
            &&s.DingQueSuits[i]==targetSuit&&SichuanOpponentTimeline.MustHaveClearedMissing(s,i));
        // The allocation model is uncalibrated. If moving the one unseen
        // fourth into the wall reverses its point estimate, use the approved
        // expert preference only with at least as many forced Gang channels
        // as forced Ron channels, or publicly weak sequence demand. This is
        // an ordinal strategy under allocation uncertainty, never extra EV.
        if(!best.KeepsTriplet)
        {
            var alternatives=options.Where(o=>o.KeepsTriplet
                &&o.FourthInWallOptionValue-o.ImmediateDiscardLoss>Net(best)+1e-9
                &&(Channels(tile/9)>0&&Channels(tile/9)>=Channels(o.WaitSuit)||LowSequenceDemand(s,tile)))
                .OrderByDescending(Net).ThenByDescending(o=>o.LiveCopies).ThenBy(o=>o.Discard==fallback?0:1).ToArray();
            if(alternatives.Length>0)
                return new(tile,alternatives[0].Discard,"NEW_TRIPLET_PUBLIC_CHANNELS_ALLOCATION_SENSITIVE",options.ToArray());
        }
        // This operation consumes no Hu-refusal token or history.
        return new(tile,Net(best)>Net(incumbent)+1e-9?best.Discard:fallback,
            "NEW_CONCEALED_TRIPLET_PUBLIC_OPTION_COMPARISON",options.ToArray());
    }

    private static bool LowSequenceDemand(SichuanStateView s,int tile)
    {
        var rank=tile%9;var start=tile/9*9;var channels=new List<int[]>();
        for(int low=Math.Max(0,rank-2);low<=Math.Min(rank,6);low++)
        {
            var pair=Enumerable.Range(start+low,3).Where(t=>t!=tile).ToArray();
            if(pair.All(t=>s.Remaining18[t]>0))channels.Add(pair);
        }
        return channels.Count<=1||channels[0].Any(t=>s.Remaining18[t]==1&&channels.All(c=>c.Contains(t)));
    }

    private static double OptionValue(SichuanStateView s,int target,SichuanReadyPrice before,
        SichuanReadyPrice? after,int[] hand,List<SichuanMeldView> melds,SichuanWallAvailability wall,
        double? fourthOverride=null)
    {
        var own=s.SeatIndex;
        var active=Enumerable.Range(0,4).Where(i=>s.ActiveSeats[i]&&!s.HasHu[i]).ToArray();
        var payers=active.Where(i=>i!=own).ToArray();
        var suit=before.Waits[0].TileType/9;
        bool Forced(int seat,int tileSuit)=>seat!=own&&s.DingQueSuits[seat]==tileSuit
            &&SichuanOpponentTimeline.MustHaveClearedMissing(s,seat);
        var win=before.Waits[0];var raised=after?.Waits[0]??win;
        var replacementSelf=0;var replacementSource=0;
        if(after is not null)
        {
            var reduced=(int[])hand.Clone();reduced[target]-=3;reduced[win.TileType]++;
            var projected=melds.Append(new SichuanMeldView(SichuanMeldType.ConcealedGang,target,own,0)).ToArray();
            var fans=new SichuanFanProjectionEngine();
            replacementSelf=fans.Project(reduced,projected,SichuanWinType.GangSelfDraw).PerPayerScore*payers.Length;
            replacementSource=fans.Project(reduced,projected,SichuanWinType.DianGangHua).PerPayerScore;
        }
        // Integrate the floor/ceiling counts of the public expected allocation.
        // Each component is a physical finite wall. This is a two-marginal
        // approximation, not a calibrated joint posterior over full hands.
        static IEnumerable<(int Count,double Weight)> Mix(double n)
        {
            var lo=(int)Math.Floor(n);var fraction=n-lo;
            if(1-fraction>1e-12)yield return(lo,1-fraction);
            if(fraction>1e-12)yield return(lo+1,fraction);
        }
        double total=0,mass=0;
        foreach(var (waits,pw) in Mix(before.PublicDrawableMass))
        foreach(var (fourth,pg) in Mix(after is null?0:fourthOverride??Math.Clamp(wall.ExpectedCounts18[target],0,1)))
        {
            if(waits+fourth>s.WallCount)continue;
            var cache=new Dictionary<(int N,int W,int G,int From,bool Raised,int Replacement),double>();
            double Visit(int n,int w,int g,int from,bool root,int replacement)
            {
                if(n<=0)return 0;
                var key=(n,w,g,from,root,replacement);
                if(cache.TryGetValue(key,out var found))return found;
                var seat=replacement>0?own:Enumerable.Range(1,4).Select(k=>(from-k+8)%4).First(active.Contains);
                double result=0;
                if(w>0)
                {
                    var hit=seat==own ? replacement==1?replacementSelf:replacement==2?replacementSource
                        :(root?raised.SelfDrawPerPayer:win.SelfDrawPerPayer)*payers.Length
                        : Forced(seat,suit)?(root?raised.HandScore:win.HandScore):Visit(n-1,w-1,g,seat,root,0);
                    result+=w/(double)n*hit;
                }
                if(g>0)
                {
                    var canGang=after is not null&&n>1&&(seat==own||Forced(seat,target/9));
                    if(canGang)
                    {
                        var type=seat==own?SichuanMeldType.ConcealedGang:SichuanMeldType.MeldedGang;
                        var cash=payers.Sum(p=>SichuanSettlementProjectionEngine.GangPayment(type,p,seat));
                        result+=g/(double)n*(cash+Visit(n-1,w,0,own,true,seat==own?1:2));
                    }
                    else result+=g/(double)n*Visit(n-1,w,g-1,seat,root,0);
                }
                if(n-w-g>0)result+=(n-w-g)/(double)n*Visit(n-1,w,g,seat,root,0);
                cache[key]=result;return result;
            }
            total+=pw*pg*Visit(s.WallCount,waits,fourth,own,false,0);mass+=pw*pg;
        }
        return mass>0?total/mass:0;
    }
}
