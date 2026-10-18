using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanDevelopmentPlan(string Goal, bool AllowsRefusal, int TargetSuit,
    int LiveWaits, int UsedRefusals, int RefusalLimit, int Danger, bool GangRealized,
    double SelfDrawEstimate, double GangOpportunity, string[] Reasons)
{
    public SichuanRepresentativeHuAssessment? Representative { get; init; }
    public SichuanWideBedHuAssessment? WideBed { get; init; }
}
public sealed record SichuanPengImprovement(bool Improves, int BeforeDistance, int AfterDistance,
    double BeforeSupply, double AfterSupply, double AddedGangChance, string[] Reasons)
{
    public int OwnDrawsBefore { get; init; }
    public int OwnDrawsAfter { get; init; }
    public bool ImmediateAddedGangAvailable { get; init; }
}

public sealed record SichuanHuRefusalAssessment(bool Refuse, double ImmediateHuGain,
    double LocalSelfDrawValue, double LocalGangValue, double RequiredValue,
    string[] Reasons)
{
    public SichuanWinType EffectiveWinType { get; init; }
    public SichuanHuWaitingEstimate? Waiting { get; init; }
}

/// <summary>Bounded continuation policy. Inputs are one player's hand and public
/// observations only. The same local evidence guides live and research actions;
/// terminal simulations validate the strategy outside the decision path.</summary>
public sealed class SichuanDevelopmentPolicy
{
    private readonly SichuanStructuralDistance _distance = new();
    private readonly SichuanExactHandAnalyzer _hands = new();

    internal static List<SichuanMeldView> Melds(SichuanStateView s, int seat) => s.MeldViews[seat].Count>0
        ? s.MeldViews[seat].ToList() : s.Melds18[seat].GroupBy(t=>t).Select(g=>new SichuanMeldView(
            g.Count()==4?SichuanMeldType.MeldedGang:SichuanMeldType.Peng,g.Key,-1,0)).ToList();
    internal static int Draws(SichuanStateView s) => Math.Max(0,(s.WallCount-
        SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(s,s.CurrentSeat,s.SeatIndex)
        +Math.Max(1,s.ActiveSeats.Where((a,i)=>a&&!s.HasHu[i]).Count())-1)
        /Math.Max(1,s.ActiveSeats.Where((a,i)=>a&&!s.HasHu[i]).Count()));

    // A cleared missing suit excludes that opponent's WAITING hand. It does not
    // imply that a just-drawn concealed tile is known, nor reveal sampled hands.
    internal static double Density(SichuanStateView s, int tile, int[] remaining)
    {
        var eligible=Enumerable.Range(0,4).Where(i=>i!=s.SeatIndex
            && !(s.DingQueSuits[i]==tile/9 && (s.HasHu[i]
                || SichuanOpponentTimeline.MustHaveClearedMissing(s,i))))
            .Sum(i=>Math.Max(0,s.HandCounts[i]));
        return Math.Clamp(remaining[tile]/(double)Math.Max(1,s.WallCount+eligible),0,1);
    }
    private (int Distance,double Supply,int Live) Profile(SichuanStateView s,int[] hand,int melds,int[] remaining)
    {
        var legal = new SichuanShantenEngine();
        var d=legal.CalcLegalShanten(hand,melds,s.OwnDingQueSuit);double supply=0;var live=0;
        for(var t=0;t<27;t++)
        {
            if(t/9==s.OwnDingQueSuit || hand[t]>=4 || remaining[t]<=0)continue;
            hand[t]++;var improves=legal.CalcLegalShanten(hand,melds,s.OwnDingQueSuit)<d;hand[t]--;
            if(!improves)continue;
            supply+=Density(s,t,remaining);live+=remaining[t];
        }
        return(d,Math.Min(1,supply),live);
    }

    // One development draw, followed by a legal discard and a measured ready
    // exit. Finite-horizon estimate; never assumes an arbitrary tile helps.
    private double RebuiltReadyChance(SichuanStateView s,int[] hand,int melds,int[] remaining,int draws)
    {
        double progress=0,weighted=0;
        for(var draw=0;draw<27;draw++)
        {
            if(draw/9==s.OwnDingQueSuit || hand[draw]>=4 || remaining[draw]<=0)continue;
            hand[draw]++;remaining[draw]--;
            double best=0;
            for(var discard=0;discard<27;discard++)
            {
                if(hand[discard]<=0)continue;
                hand[discard]--;
                if(_distance.Best(hand,melds)==0)best=Math.Max(best,Profile(s,hand,melds,remaining).Supply);
                hand[discard]++;
            }
            remaining[draw]++;hand[draw]--;
            if(best<=0)continue;
            var p=Density(s,draw,remaining);progress+=p;weighted+=p*best;
        }
        if(progress<=0)return 0;
        var rate=Math.Min(1,weighted/progress);progress=Math.Min(1,progress);double chance=0;
        for(var turn=1;turn<draws;turn++)
            chance+=Math.Pow(1-progress,turn-1)*progress*(1-Math.Pow(1-rate,draws-turn));
        return chance;
    }

    internal int SelectLiveDiscard(SichuanStateView s,int fallback)
    {
        var last=s.PublicEvents.LastOrDefault(e=>e.Type!=SichuanPublicEventType.Pass);
        if(last?.Seat==s.SeatIndex && last.Type==SichuanPublicEventType.Peng)
        {
            var hand=(int[])s.Hand18.Clone();hand[last.TileType]+=2;
            var visible=(int[])s.Visible18.Clone();visible[last.TileType]-=2;
            var before=new SichuanStateView {SeatIndex=s.SeatIndex,CurrentSeat=last.SourceSeat,
                DealerSeat=s.DealerSeat,WallCount=s.WallCount,Hand18=hand,Visible18=visible,
                Remaining18=(int[])s.Remaining18.Clone(),DingQueSuits=(int[])s.DingQueSuits.Clone(),
                ActiveSeats=(bool[])s.ActiveSeats.Clone(),HasHu=(bool[])s.HasHu.Clone(),HandCounts=(int[])s.HandCounts.Clone()};
            before.HandCounts[s.SeatIndex]=hand.Sum();
            for(var i=0;i<4;i++)before.MeldViews[i].AddRange(Melds(s,i));
            var index=before.MeldViews[s.SeatIndex].FindLastIndex(m=>m.Type==SichuanMeldType.Peng&&m.TileType==last.TileType);
            if(index<0)return fallback;
            before.MeldViews[s.SeatIndex].RemoveAt(index);
            before.PublicEvents.AddRange(s.PublicEvents.TakeWhile(e=>!ReferenceEquals(e,last)));
            return SelectPengDiscard(before,last.TileType,fallback);
        }
        if(fallback<0 || s.Hand18[fallback]<=0 || SichuanSingleLaneEvaluator.ResolveSuit(s)<0
            || Draws(s)<6 || SichuanDistinctDingQueHuPolicy.AssessDanger(s,new())>0
            || s.OwnDingQueSuit>=0 && s.Hand18.Skip(s.OwnDingQueSuit*9).Take(9).Sum()>0)return fallback;
        var handAfter=(int[])s.Hand18.Clone();handAfter[fallback]--;
        var melds=Melds(s,s.SeatIndex).Count;
        var baseline=Profile(s,handAfter,melds,s.Remaining18);
        if(baseline.Distance!=0)return fallback;
        var best=1-Math.Pow(1-baseline.Supply,Draws(s));var chosen=fallback;
        for(var discard=0;discard<27;discard++)
        {
            if(discard==fallback || s.Hand18[discard]<=0)continue;
            var h=(int[])s.Hand18.Clone();h[discard]--;
            if(_distance.Best(h,melds)!=1)continue;
            var chance=RebuiltReadyChance(s,h,melds,(int[])s.Remaining18.Clone(),Draws(s));
            if(chance>best+0.10){best=chance;chosen=discard;}
        }
        return chosen;
    }

    internal int SelectPengDiscard(SichuanStateView s,int tile,int fallback)
    {
        var candidates=new List<(int Tile,SichuanPengImprovement Gain)>();
        for(var d=0;d<27;d++)
        {
            if(s.Hand18[d]-(d==tile?2:0)<=0)continue;
            if(s.OwnDingQueSuit>=0 && s.Hand18.Skip(s.OwnDingQueSuit*9).Take(9).Sum()>0 && d/9!=s.OwnDingQueSuit)continue;
            var gain=EvaluatePeng(s,tile,d);
            if(gain.Improves)candidates.Add((d,gain));
        }
        if(candidates.Count==0)return fallback;
        var best=candidates.OrderBy(c=>c.Gain.AfterDistance).ThenByDescending(c=>c.Gain.AfterSupply)
            .ThenBy(c=>c.Tile==fallback?0:1).First();
        // Preserve the production discard unless there is an explicit supply
        // or bounded rebuilding improvement, not simply a different tie order.
        var original=EvaluatePeng(s,tile,fallback);
        return best.Gain.AfterDistance<original.AfterDistance || !original.Improves
            || best.Gain.AfterDistance==original.AfterDistance && best.Gain.AfterSupply>original.AfterSupply+0.005
            ? best.Tile:fallback;
    }

    public SichuanPengImprovement EvaluatePeng(SichuanStateView s,int tile,int discard)
    {
        var melds=Melds(s,s.SeatIndex).Count;
        var after=(int[])s.Hand18.Clone();var reasons=new List<string>();
        // A missing-suit pair may still be Penged when it is the legal way to
        // expose/clear that suit.  The follow-up discard selection enforces
        // the remaining ding-que obligation; claiming the pair itself is not
        // an illegal action.
        if(tile is <0 or >26 || discard is <0 or >26 || after[tile]<2)
            return new(false,8,8,0,0,0,["PENG_INVALID"]);
        after[tile]-=2;
        if(after[discard]<=0)return new(false,8,8,0,0,0,["PENG_INVALID_DISCARD"]);
        after[discard]--;
        var before=Profile(s,(int[])s.Hand18.Clone(),melds,s.Remaining18);
        var next=Profile(s,after,melds+1,s.Remaining18);
        var danger=SichuanDistinctDingQueHuPolicy.AssessDanger(s,new());
        // Only a personal future draw can add to a Peng and earn the added-Gang
        // payment. A fourth copy already held after the Peng can be used to
        // upgrade only on a later own draw turn; that held upgrade earns zero
        // Gang money, so it must not be priced as an immediate cash gain.
        // Claiming takes an opponent's discard, not one of our future draws.
        // Count the next own draws from OUR discard after Peng; subtracting
        // one from the Pass budget loses a real draw at wall/seat boundaries.
        var active=Math.Max(1,s.ActiveSeats.Where((a,i)=>a&&!s.HasHu[i]).Count());
        var beforeDraws=Draws(s);
        var afterOffset=SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(s);
        var afterDraws=Math.Max(0,(s.WallCount-afterOffset+active-1)/active);
        var gang=1-Math.Pow(1-Density(s,tile,s.Remaining18),afterDraws);
        if(s.Remaining18[tile]<=0)gang=0;
        var heldFourth=after[tile]>0;
        if(after[tile]>0)gang=0;
        var speed=next.Distance<before.Distance;
        var supply=next.Distance==before.Distance && next.Supply>before.Supply+0.005;
        // A future fourth for a Peng is diagnostic, not an independent reason
        // to claim, lose supply, or delay completion. Actual later Gang cash
        // remains in the settlement/continuation model.
        var rebuild=false;
        if(before.Distance==0 && next.Distance==1 && danger==0 && afterDraws>=6
            && SichuanSingleLaneEvaluator.ResolveSuit(s)>=0)
        {
            var rebuilt=RebuiltReadyChance(s,after,melds+1,(int[])s.Remaining18.Clone(),afterDraws);
            var stay=1-Math.Pow(1-before.Supply,beforeDraws);
            rebuild=rebuilt>stay+0.10;
            if(rebuild)reasons.Add("PENG_BOUNDED_REBUILD_IMPROVES_COMPLETION");
        }
        if(speed)reasons.Add("PENG_DISTANCE_IMPROVES");
        if(supply)reasons.Add("PENG_PUBLIC_SUPPLY_IMPROVES");
        reasons.Add("PENG_FUTURE_ADDED_GANG_NO_GREED");
        if(!speed&&!supply&&!rebuild)reasons.Add("PENG_NO_PROVEN_IMPROVEMENT");
        reasons.Add($"PENG_OWN_DRAW_BUDGET_{beforeDraws}_{afterDraws}");
        if(heldFourth)reasons.Add("PENG_HELD_FOURTH_DEFERRED_NO_GANG_SCORE");
        else if(afterDraws==0)reasons.Add("PENG_NO_FUTURE_OWN_DRAW_FOR_ADDED_GANG");
        else if(s.Remaining18[tile]<=0)reasons.Add("PENG_FOURTH_COPY_PUBLICLY_EXHAUSTED");
        return new(speed||supply||rebuild,before.Distance,next.Distance,before.Supply,next.Supply,gang,reasons.ToArray())
        { OwnDrawsBefore=beforeDraws,OwnDrawsAfter=afterDraws,ImmediateAddedGangAvailable=false };
    }

    public SichuanDevelopmentPlan Evaluate(SichuanStateView s)
    {
        var lane=SichuanSingleLaneEvaluator.ResolveSuit(s);var own=s.SeatIndex;
        var reasons=new List<string>();var danger=SichuanDistinctDingQueHuPolicy.AssessDanger(s,reasons);
        var events=s.PublicEvents.OrderBy(e=>e.EventIndex).ToArray();
        var used=new SichuanHuRefusalHistory(s).Used;
        var melds=Melds(s,own);var realized=melds.Any(m=>SichuanHuRefusalHistory.IsScoredGang(s,m));
        var waits=_hands.EnumerateWaits(s.Hand18,s.Remaining18,melds.Count)
            .Where(w=>w.TileType/9!=s.OwnDingQueSuit).ToArray();
        var live=waits.Sum(w=>s.Remaining18[w.TileType]);
        var draws=Draws(s);var density=Math.Min(1,waits.Sum(w=>Density(s,w.TileType,s.Remaining18)));
        var knownSelfDraw=SichuanSingleLaneSupply.ReadySelfDrawProbability(s,waits.Select(w=>w.TileType));
        var probability=knownSelfDraw ?? 1-Math.Pow(1-density,draws);
        if(knownSelfDraw.HasValue)reasons.Add("SINGLE_LANE_SELF_DRAW_WITHOUT_REPLACEMENT_FIXED_SCHEDULE");
        var gang=Enumerable.Range(0,27).Where(t=>s.Hand18[t]>=3 && t/9!=s.OwnDingQueSuit
            && (lane<0 || t/9==lane) && s.Remaining18[t]>0)
            .Select(t=>1-Math.Pow(1-Density(s,t,s.Remaining18),Math.Max(0,draws-1))).DefaultIfEmpty(0).Max();
        foreach(var t in Enumerable.Range(0,27).Where(t=>s.Hand18[t]==3))
            if(SichuanSingleLaneSupply.FourthCopy(s,t) is {} supply)
            {
                gang=Math.Max(gang,supply.AcquisitionOpportunity);
                reasons.Add($"单行道第四张 {t}：固定轮序摸入机会 {supply.OwnDrawOpportunity:F4}，他家强制供张机会 {supply.ForcedOfferOpportunity:F4}；兑现前仍须比较胡/杠，未额外叠加潜在杠钱");
                reasons.Add("SINGLE_LANE_GANG_OPPORTUNITY_INCLUDES_FORCED_OFFERS");
            }
        var wideBed=new SichuanWideBedHuPolicy().Evaluate(s);
        if(wideBed.Applies)
            return new(wideBed.Goal,wideBed.AllowsRefusal,lane,wideBed.UnseenWaitCopies,
                wideBed.UsedRefusals,wideBed.RefusalLimit,wideBed.Danger,wideBed.GangRealized,
                probability,gang,reasons.Concat(wideBed.Reasons).ToArray()) { WideBed=wideBed };
        var representative=new SichuanRepresentativeHuPolicy().Evaluate(s);
        if(representative.Applies)
            return new(representative.Goal,representative.AllowsRefusal,lane,live,
                representative.UsedRefusals,representative.RefusalLimit,representative.Danger,
                representative.GangRealized,probability,gang,representative.Reasons)
            { Representative=representative };
        var cap=0;var goal="take_hu";
        if(lane>=0)
        {
            reasons.Add("SINGLE_LANE_HU_DISCIPLINE");
            var laneWaits=waits.Length>0 && waits.All(w=>w.TileType/9==lane);
            if(laneWaits && live>=3 && danger==0){cap=int.MaxValue;goal="wait_self_draw";}
            if(laneWaits && live>=5 && danger==1){cap=2;goal="bounded_self_draw";}
            // Formal summary wins over the looser 4-5 A example at 3-4 copies.
            if(laneWaits && live==2 && gang>=0.10 && danger==0
                && Enumerable.Range(0,4).Where(i=>i!=own&&s.ActiveSeats[i]&&!s.HasHu[i])
                    .All(i=>Melds(s,i).All(m=>m.Type==SichuanMeldType.Peng)&&Melds(s,i).Count<3))
            {cap=int.MaxValue;goal="wait_live_gang";}
            if(danger==0 && draws>=3 && (!laneWaits || live==2))
            {
                // Enumerate a legal, concrete Peng + discard to improve supply.
                for(var t=lane*9;t<lane*9+9;t++)
                {
                    if(s.Hand18[t]<2 || s.Remaining18[t]<=0 || melds.Count>=4)continue;
                    for(var d=0;d<27;d++)
                    {
                        if(s.Hand18[d]-(d==t?2:0)<=0)continue;
                        var gain=EvaluatePeng(s,t,d);
                        if(!gain.Improves || !(gain.AfterDistance==0 && gain.AfterSupply>gain.BeforeSupply+0.005
                            || gain.Reasons.Contains("PENG_BOUNDED_REBUILD_IMPROVES_COMPLETION")))continue;
                        if(cap==0){cap=1;goal="improve_exclusive_wait";}
                    }
                }
            }
            if(realized){cap=Math.Min(cap,1);reasons.Add("GANG_CASHED_REDUCE_GREED");}
        }
        else
        {
            var distinct=new SichuanDistinctDingQueHuPolicy().Evaluate(s);
            if(distinct.Applies)
            {
                cap=distinct.MaximumRefusals;goal=distinct.DevelopmentRoute.Length>0?distinct.DevelopmentRoute:"wait_self_draw";
                reasons.AddRange(distinct.Reasons);
                if(!distinct.AllowsRefusal)cap=0;
            }
            // Other competition patterns are classified by the per-suit policy above.
        }
        // The chapter's plain-hand table must not suppress an already valuable
        // flush/seven-pairs hand. Such routes still need local value evidence.
        if(lane>=0 && waits.Any(w=> {
            var h=(int[])s.Hand18.Clone();h[w.TileType]++;
            var f=new SichuanFanProjectionEngine().Project(h,melds,SichuanWinType.Discard);
            return f.IsQingYiSe||f.IsSevenPairs||f.IsDaDuiZi||f.IsJinGouDiao;
        })) { cap=danger==0?2:0;goal="valuable_hand_development"; }
        var allowed=draws>0&&waits.Length>0&&danger<2&&used<cap;
        reasons.Add($"目标 {goal}，剩余听张 {live}，已拒胡 {used}，危险 {danger}，后续摸牌约 {draws} 次");
        reasons.Add(allowed?"DEVELOPMENT_REFUSAL_ELIGIBLE":"DEVELOPMENT_TAKE_HU");
        return new(goal,allowed,lane,live,used,cap,danger,realized,probability,gang,reasons.ToArray());
    }

    // Shared current-state policy, without terminal simulation or future-wall access.
    internal bool ShouldRefuse(SichuanStateView s,int tile,SichuanWinType type)
        => AssessRefusal(s,tile,type).Refuse;

    public SichuanHuRefusalAssessment AssessRefusal(SichuanStateView s,int tile,SichuanWinType type)
    {
        // Transport can label a gang-following discard as plain "discard".
        // Preserve its rule premium from the actual public action sequence.
        if(type==SichuanWinType.Discard)
        {
            var offeredIndex=s.PublicEvents.FindLastIndex(e=>e.Type==SichuanPublicEventType.Discard
                && e.Seat==s.CurrentSeat && e.TileType==tile);
            var preceding=offeredIndex<0?null:s.PublicEvents.Take(offeredIndex)
                .LastOrDefault(e=>e.Type is not SichuanPublicEventType.Draw and not SichuanPublicEventType.Pass);
            if(preceding?.Seat==s.CurrentSeat && preceding.Type is SichuanPublicEventType.MeldedGang
                or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang)
                type=SichuanWinType.GangDiscard;
        }
        var strategy=SichuanStrategyContract.Assess(s);
        var plan=strategy.Development;
        var hand=(int[])s.Hand18.Clone();hand[tile]++;
        var fans=new SichuanFanProjectionEngine();var melds=Melds(s,s.SeatIndex);
        var now=fans.Project(hand,melds,type).HandScore;
        // The offered tile can have a different price from the other waits.
        // Price the whole current waiting hand, not every future win as if it
        // completed on this one offered tile. Density is still a public model.
        var weights=Enumerable.Range(0,27).Select(t=>Density(s,t,s.Remaining18)).ToArray();
        var prices=new SichuanReadyWaitPricing().Build(s,s.Hand18,weights,melds);
        var later=prices is { HasDrawableWait:true } ? prices.WeightedSelfDrawPerPayer : 0;
        var payers=s.ActiveSeats.Where((a,i)=>a&&!s.HasHu[i]&&i!=s.SeatIndex).Count();
        // Explicit public supply, future own positions and measured waiting
        // costs replace the blanket 0.8 haircut. This remains local analysis,
        // not terminal simulation inside a live decision.
        var offer=s.PublicEvents.LastOrDefault(e=>e.Type is not SichuanPublicEventType.Draw
            and not SichuanPublicEventType.Pass and not SichuanPublicEventType.Hu);
        var offerKnown=offer?.Type==SichuanPublicEventType.Discard && offer.TileType==tile
            && offer.Seat==s.CurrentSeat && offer.Seat!=s.SeatIndex;
        var strategyAllows=SichuanStrategyContract.CanRefuse(strategy,type);
        var waiting=strategyAllows && offerKnown ? new SichuanHuWaitingModel().Estimate(s)
            : new SichuanHuWaitingEstimate(false,"strategy_exit_or_offer_unknown",0,0,0,0,0,0,0,0,0,0,0,0);
        var future=waiting.Supported ? waiting.SelfDrawGain : 0;
        var gangValue=plan.Goal is "wait_live_gang" or "two_viable_gangs"?plan.GangOpportunity*payers:0;
        var threshold=now;
        var eligible=strategyAllows && offerKnown && waiting.Supported;
        var refuse=eligible && waiting.LocalNet+gangValue>threshold+1e-9;
        var reasons=strategy.Reasons.Concat(new[] {
            "HU_STRATEGY_CURRENT_STATE", "HU_LOCAL_ESTIMATE_NOT_TERMINAL_EV",
            "HU_FUTURE_ALL_LIVE_WAIT_PRICING",
            "HU_WAITING_SUPPLY_AND_EVENT_COST_V1",
            $"逐听口加权自摸每家 {later:F4}；当前来牌自摸每家 {fans.Project(hand,melds,SichuanWinType.SelfDraw).PerPayerScore}",
            $"当前胡牌牌分 {now:F2}；自摸收入估计 {future:F4}，等待失分 {waiting.WaitingLoss:F4}，杠机会策略值 {gangValue:F4}，要求净值超过 {threshold:F2}",
            $"当前胡牌类型 {type}；普通点炮才允许比较拒胡，抢杠与杠上炮兑现规则收益",
            $"公开未见听张 {waiting.UnseenWaitCopies}，预计墙内 {waiting.ExpectedWallWaitCopies:F3}，固定当前轮序本家摸牌 {waiting.ScheduledOwnDraws} 次；自摸机会 {waiting.SelfDrawOpportunity:F4}，计退出自摸估计 {waiting.SelfDrawProbability:F4}，自摸时平均付款 {waiting.ConditionalSelfDrawPayers:F3} 家",
            $"等待分项：被自摸 {waiting.OpponentSelfDrawLoss:F4}，放炮 {waiting.DealInLoss:F4}，付杠分 {waiting.GangPaymentLoss:F4}；模型 {waiting.Status}，有效样本 {waiting.EffectiveSampleSize:F2}",
            "当前手牌及一摸成听风险的局部模型；未校准，未预测后续碰杠轮序、全部改听及终局查叫，不是终局收益承诺",
            "听口机会与付款家数是当前状态估计，不能保证后续不变；每次新观测重新判断",
            offerKnown ? "HU_PUBLIC_OFFER_CONTEXT_KNOWN" : "HU_PUBLIC_OFFER_CONTEXT_INCOMPLETE",
            !eligible ? "HU_REFUSAL_STRATEGY_EXIT" : refuse ? "HU_REFUSAL_LOCAL_VALUE_SUPPORTED" : "HU_REFUSAL_LOCAL_VALUE_INSUFFICIENT"
        }).ToArray();
        return new(refuse,now,future,gangValue,threshold,reasons) { EffectiveWinType=type, Waiting=waiting };
    }
}
