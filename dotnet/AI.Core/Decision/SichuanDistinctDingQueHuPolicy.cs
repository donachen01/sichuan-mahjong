using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanDistinctDingQueHuAssessment(bool Applies, bool AllowsRefusal,
    int UnseenWaitCopies, int OwnRound, int UsedRefusals, int MaximumRefusals,
    int ViableGangTargets, int DangerLevel, bool GangRealized, string DevelopmentRoute,
    IReadOnlyList<string> Reasons)
{
    public string CashOutOrigin { get; init; } = "not_cashed";
    public SichuanPublicDangerAssessment? DangerEvidence { get; init; }
}

/// <summary>
/// Chapters 4.1.2 and 4.2.2 explicit triplet discipline. This only permits a refusal to be evaluated;
/// the shared local value and risk evidence must still support it.
/// Confirmed per-seat round events are the memory: never spend a token merely
/// because a decision was queried, and never renew tokens after changing waits.
/// </summary>
public sealed class SichuanDistinctDingQueHuPolicy
{
    public SichuanDistinctDingQueHuAssessment Evaluate(SichuanStateView state)
    {
        var own = state.SeatIndex;
        var opponents = Enumerable.Range(0,4).Where(s => s != own).ToArray();
        if (own is < 0 or > 3 || !opponents.Select(s=>state.DingQueSuits[s]).Order().SequenceEqual(new[]{0,1,2}))
            return new(false,true,0,0,0,0,0,0,false,"",new[]{"DISTINCT_DINGQUE_NOT_APPLICABLE"});
        var reasons = new List<string>{"DISTINCT_DINGQUE_HU_DISCIPLINE"};
        var history = new SichuanHuRefusalHistory(state);
        var events = history.Events;
        var used = history.Used;
        var realized = history.GangRealized;
        var round = history.OwnRound;
        var melds=Melds(state,own);
        var waits=new SichuanExactHandAnalyzer().EnumerateWaits(state.Hand18,state.Remaining18,melds.Count)
            .Where(w=>w.TileType/9!=state.OwnDingQueSuit).ToArray();
        // These are unseen copies, INCLUDING opponents' concealed allocations,
        // matching the chapter's bands. They are not declared drawable copies.
        var live=waits.Sum(w=>Math.Max(0,state.Remaining18[w.TileType]));
        var dangerEvidence=new SichuanPublicDangerEvaluator().Evaluate(state);
        reasons.AddRange(dangerEvidence.Reasons);
        var danger=dangerEvidence.Level;
        var active=opponents.Where(s=>state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        var offset=SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(state,state.CurrentSeat,own);
        var timeToExit=state.WallCount<=offset;
        var viable=SichuanIndependentTriplet.LiveTargets(state).Length;
        var cap=SichuanConcealedTripletHuTable.Distinct(live,round,danger,realized?0:viable);
        var development=!realized&&viable>=2&&cap>0?"two_viable_gangs":"";
        // Actual close big-hand routes remain a separate bounded exception;
        // a pair of raw triplets no longer creates an extra two-token route.
        if(!timeToExit&&!realized&&danger==0&&live<7&&viable==0)
        {
            var belief=new SichuanBeliefEngine().Build(state);
            var wall=new SichuanWallAvailabilityEngine().Build(state,belief);
            development=SichuanRepresentativeHuPolicy.FindDevelopment(state,melds,wall,0);
            if(development.Length>0)cap=2;
        }
        reasons.Add("CONCEALED_TRIPLET_EXPLICIT_HU_TABLE");
        var cashOutOrigin="not_cashed";
        var narrowCashed=false;
        if(realized)
        {
            var firstWaits=history.FirstRefusalWaits(state);
            narrowCashed=firstWaits is null || firstWaits.Sum()<=6;
            cashOutOrigin=firstWaits is null?"unknown_conservative_exit":narrowCashed?"narrow_development_cashed":"restore_base_budget";
            if(narrowCashed)cap=0;
            reasons.Add("DISTINCT_GANG_CASH_OUT_"+cashOutOrigin);
        }
        var dangerExit=danger>=2;
        if(timeToExit)reasons.Add("牌墙不足以轮到自己摸牌");
        if(dangerExit)reasons.Add("当前听牌宽度不能承受该级别危险，接胡退出");
        if(realized)reasons.Add(live<7?"窄听贪杠已兑现，转为接胡":"杠牌已兑现，取消额外额度并恢复基础策略");
        var allowed=!timeToExit && !dangerExit && !narrowCashed && used<cap;
        reasons.Add($"公开未见听张 {live}，本家约第 {round} 巡，已拒胡 {used} 次，上限 {cap} 次，可争取杠 {viable} 组");
        if(development.Length>0)reasons.Add("发展例外："+development);
        reasons.Add(allowed?"DISTINCT_DINGQUE_REFUSAL_ELIGIBLE":"DISTINCT_DINGQUE_TAKE_HU");
        return new(true,allowed,live,round,used,cap,viable,danger,realized,development,reasons)
        {CashOutOrigin=cashOutOrigin,DangerEvidence=dangerEvidence};
    }
    internal static int AssessDanger(SichuanStateView state, List<string> reasons)
    {
        var assessment=new SichuanPublicDangerEvaluator().Evaluate(state);
        reasons.AddRange(assessment.Reasons);
        return assessment.Level;
    }

    private static bool HasGoldenHookPeng(SichuanStateView state,List<SichuanMeldView> melds,SichuanWallAvailability wall)
    {
        if(melds.Count!=3)return false;
        var offer=state.PublicEvents.LastOrDefault(e=>e.Type is not SichuanPublicEventType.Draw
            and not SichuanPublicEventType.Pass and not SichuanPublicEventType.Hu);
        for(int tile=0;tile<27;tile++)
        {
            bool offeredNow=offer?.Type==SichuanPublicEventType.Discard&&offer.Seat==state.CurrentSeat
                &&offer.Seat!=state.SeatIndex&&offer.TileType==tile;
            if(tile/9==state.OwnDingQueSuit || state.Hand18[tile]<2
                || !offeredNow&&(state.Remaining18[tile]<=0||wall.ExpectedCounts18[tile]<=0))continue;
            var hand=(int[])state.Hand18.Clone();hand[tile]-=2;
            var projected=melds.Append(new SichuanMeldView(SichuanMeldType.Peng,tile,-1,0)).ToArray();
            for(int discard=0;discard<27;discard++)
            {
                if(hand[discard]==0)continue;
                hand[discard]--;
                bool legal=SichuanReadyWaitPricing.HasLegalOwnedContext(state,hand,projected);
                var price=legal?new SichuanReadyWaitPricing().Build(state,hand,wall.ExpectedCounts18,projected):null;
                hand[discard]++;
                if(price is {HasDrawableWait:true})return true;
            }
        }
        return false;
    }
    private static List<SichuanMeldView> Melds(SichuanStateView state,int seat)=>state.MeldViews[seat].Count>0
        ?state.MeldViews[seat].ToList():state.Melds18[seat].GroupBy(t=>t).Select(g=>new SichuanMeldView(g.Count()==4?SichuanMeldType.MeldedGang:SichuanMeldType.Peng,g.Key,-1,0)).ToList();
}
