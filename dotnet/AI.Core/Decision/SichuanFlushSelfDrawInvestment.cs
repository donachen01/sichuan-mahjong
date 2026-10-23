using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>A narrow source 6-9 investment: plain self-Hu, twelve target tiles
/// and one off-suit pair, a publicly known single-lane target pool, no threat.
/// Analytic fixed draw-order receipts only; never a hidden-world rollout.
/// Claims, exits and future voluntary supply are not added as free income.</summary>
public static class SichuanFlushSelfDrawInvestment
{
    public sealed record Result(int Discard, double Receipt, double HazardCost, double Net,
        int TargetSuit, int Endpoints, string[] Reasons);

    // Two fixed anchor positions: the first own target draw and a later winning
    // draw. Earlier own positions must be off-suit; intervening positions must
    // miss the endpoint waits. All copies are sampled without replacement.
    public static double OrderedEvent(int wall, int offSuit, int firstCopies,
        int winningCopiesAfterFirst, int allWaitCopiesAfterFirst, int earlierOwn, int intervening)
    {
        if(wall<2||firstCopies<=0||winningCopiesAfterFirst<=0||earlierOwn<0||intervening<0
            ||earlierOwn+intervening>wall-2)return 0;
        double p=firstCopies*(double)winningCopiesAfterFirst/(wall*(double)(wall-1));
        for(int i=0;i<earlierOwn;i++)
        {
            if(offSuit-i<=0)return 0;
            p*=(offSuit-i)/(double)(wall-2-i);
        }
        int available=wall-2-earlierOwn,forbidden=allWaitCopiesAfterFirst-1;
        for(int i=0;i<intervening;i++)
        {
            if(available-forbidden-i<=0)return 0;
            p*=(available-forbidden-i)/(double)(available-i);
        }
        return p;
    }

    public static double OrderedClaimEvent(int wall,int off,int first,int winningAfterFirst,int allWaitAfterFirst,
        int ownBefore,int opponentsBefore,int between,int rootsAfterAnchors,int rootWaitAfterAnchors)
    {
        if(wall<2||first<=0||winningAfterFirst<=0||ownBefore<0||opponentsBefore<0||between<0
            ||ownBefore+opponentsBefore+between>wall-2||rootsAfterAnchors<0
            ||rootWaitAfterAnchors<0||rootWaitAfterAnchors>rootsAfterAnchors)return 0;
        double p=first*(double)winningAfterFirst/(wall*(double)(wall-1));
        for(int i=0;i<ownBefore;i++){if(off-i<=0)return 0;p*=(off-i)/(double)(wall-2-i);}
        int n=wall-2-ownBefore,wait=allWaitAfterFirst-1;
        double Choose(int a,int k){if(k<0||k>a)return 0;double c=1;for(int j=0;j<k;j++)c*= (a-j)/(double)(j+1);return c;}
        double miss(int size,int forbidden,int positions)
        {double v=1;for(int j=0;j<positions;j++){if(size-forbidden-j<=0)return 0;v*=(size-forbidden-j)/(double)(size-j);}return v;}
        double free=0;
        for(int x=0;x<=rootsAfterAnchors-rootWaitAfterAnchors;x++)
        for(int y=0;y<=rootWaitAfterAnchors;y++)
        {
            int count=x+y;if(count>opponentsBefore)continue;
            double term=Choose(rootsAfterAnchors-rootWaitAfterAnchors,x)*Choose(rootWaitAfterAnchors,y);
            for(int j=0;j<count;j++)term*=(opponentsBefore-j)/(double)(n-j);
            free+=(count%2==0?1:-1)*term*miss(n-count,wait-y,between);
        }
        return Math.Clamp(p*free,0,1);
    }

    public static Result? Evaluate(SichuanStateView s, double certainGain, SichuanBeliefSnapshot belief, bool requireMargin=true)
    {
        if(s.InformationMode!="public"||s.WallCount<8||s.OwnMeldCount!=0
            ||SichuanDistinctDingQueHuPolicy.AssessDanger(s,new())!=0
            ||SichuanSelfDrawContext.Resolve(s).WinType!=SichuanWinType.SelfDraw)return null;
        var fans=new SichuanFanProjectionEngine();
        if(fans.Project(s.Hand18,[],SichuanWinType.SelfDraw).BaseFan!=0)return null;
        int target=Enumerable.Range(0,3).OrderByDescending(x=>s.Hand18.Skip(x*9).Take(9).Sum()).First();
        var off=Enumerable.Range(0,27).Where(t=>t/9!=target&&s.Hand18[t]>0).ToArray();
        if(off.Length!=1||s.Hand18[off[0]]!=2||!SichuanSingleLaneSupply.HasKnownWallSuit(s,target))return null;
        var order=SichuanSingleLaneSupply.DrawSchedule(s);
        if(order.Count(x=>x==s.SeatIndex)<2)return null;
        var hand=s.Hand18.ToArray();hand[off[0]]-=2;
        var counts=s.Remaining18.Select(x=>(double)x).ToArray();
        var wall=new SichuanWallAvailabilityEngine().Build(s,belief);
        double hazard=SichuanUnifiedDecisionEngine.EstimateOpponentWinPerDraw(s,belief,wall);
        double receipt=0;int endpoints=0;var prices=new SichuanReadyWaitPricing();
        int offCopies=s.WallCount-s.Remaining18.Skip(target*9).Take(9).Sum();
        var rootTiles=Enumerable.Range(target*9,9).Where(t=>s.Hand18[t]==3).ToArray();
        // At most two live fourth copies in this narrow twelve-tile shape.
        // Inclusion-exclusion excludes an earlier compulsory root offer so
        // first-own-draw and first-opponent-claim receipts do not overlap.
        double Event(int copies,int winCopies,int totalWait,int earlierOwn,int earlierOpponent,int between,
            int rootAfterAnchors,int rootWaitAfterAnchors)
            => OrderedClaimEvent(s.WallCount,offCopies,copies,winCopies,totalWait,earlierOwn,earlierOpponent,between,
                rootAfterAnchors,rootWaitAfterAnchors);
        for(int actorKind=0;actorKind<2;actorKind++)
        for(int t=target*9;t<target*9+9;t++)
        {
            int copies=s.Remaining18[t];if(copies<=0||hand[t]>=4||actorKind==1&&!rootTiles.Contains(t))continue;
            var melds=new List<SichuanMeldView>();
            if(actorKind==0)hand[t]++;
            else{hand[t]-=2;melds.Add(new(SichuanMeldType.Peng,t,-1,0));}
            counts[t]--;
            var ready=prices.Build(s,hand,counts,melds);
            if(ready is {HasDrawableWait:true}&&ready.Waits.Count>=2)
            {
                endpoints++;int total=ready.Waits.Sum(w=>(int)w.PublicWallWeight),earlierOwn=0,earlierOpponent=0;
                int rootCountAfterFirst=rootTiles.Sum(r=>(int)counts[r]);
                int rootWaitAfterFirst=ready.Waits.Where(w=>rootTiles.Contains(w.TileType)).Sum(w=>(int)w.PublicWallWeight);
                for(int j=0;j<order.Length;j++)
                {
                    bool own=order[j]==s.SeatIndex;
                    if(own==(actorKind==0))
                    for(int k=j+1;k<order.Length;k++)
                    {
                        int opponents=order.Take(k+1).Count(actor=>actor!=s.SeatIndex);
                        double survives=Math.Pow(1-hazard,opponents);
                        foreach(var w in ready.Waits)
                        {
                            bool winningRoot=rootTiles.Contains(w.TileType);
                            receipt+=Event(copies,(int)w.PublicWallWeight,total,earlierOwn,earlierOpponent,k-j-1,
                                rootCountAfterFirst-(winningRoot?1:0),rootWaitAfterFirst-(winningRoot?1:0))
                                *survives*(order[k]==s.SeatIndex?w.SelfDrawPerPayer*(s.ActiveSeats.Count(x=>x)-1):w.HandScore);
                        }
                    }
                    if(own)earlierOwn++;else earlierOpponent++;
                }
            }
            counts[t]++;
            if(actorKind==0)hand[t]--;else hand[t]+=2;
        }
        if(endpoints==0)return null;
        // Stop at an opponent's first modeled Hu rather than retaining all
        // payers after an exit. Its price/hazard remains a public approximation.
        double hazardCost=(1-Math.Pow(1-hazard,order.Count(actor=>actor!=s.SeatIndex)))*3.5;
        double discardCost=new SichuanDangerEngine().EvaluateDetail(off[0],s,belief).Risk/100.0*2;
        double net=receipt-hazardCost-discardCost;
        if(requireMargin&&!new SichuanMultiPlayerUtilityEngine().CanPassHu(certainGain,net,.85,true))return null;
        return new(off[0],receipt,hazardCost,net,target,endpoints,[
            "FLUSH_SELF_DRAW_PUBLIC_SINGLE_LANE_BOUNDED_INVESTMENT",
            "PLAIN_SELF_DRAW_ONLY_EXACT_RECEIPT_AND_ROOT_CLAIM_POSITIONS_NO_REPLACEMENT",
            $"公开单行道固定轨迹收入 {receipt:F4}，对手先胡成本 {hazardCost:F4}，净估计 {net:F4}，当前确定收入 {certainGain:F4}",
            "FUTURE_HAZARD_AND_DISCARD_COST_PUBLIC_APPROX_NOT_CALIBRATED_WIN_RATE"]);
    }
}
