using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanWaitSuitDiscipline(int Suit,int MissingOpponents,string Situation,
    int UnseenCopies,double DrawDensity,int RefusalLimit,bool AllowsRefusal,string DevelopmentRoute);
public sealed record SichuanRepresentativeHuAssessment(bool Applies,bool AllowsRefusal,
    int OwnRound,int UsedRefusals,int RefusalLimit,int ViableGangTargets,int Danger,
    bool OpponentWon,bool OpponentSingleLane,bool GangRealized,string CashOutOrigin,
    string Goal,SichuanWaitSuitDiscipline[] WaitSuits,string[] Reasons);

/// <summary>Chapter 4.1.4. Each waiting suit must qualify on its own copies.
/// Successful suit routes share one personal budget (maximum, never sum).
/// The complete hand is assessed by shared local value evidence; explicit
/// terminal simulations validate this strategy in research.</summary>
public sealed class SichuanRepresentativeHuPolicy
{
    public SichuanRepresentativeHuAssessment Evaluate(SichuanStateView s)
    {
        SichuanRepresentativeHuAssessment NotApplicable()=>new(false,true,0,0,0,0,0,false,false,false,"","",[],[]);
        if(s.SeatIndex is <0 or >3 || s.DingQueSuits.Any(d=>d is <0 or >2))return NotApplicable();
        var opponents=Enumerable.Range(0,4).Where(i=>i!=s.SeatIndex).ToArray();
        if(opponents.Select(i=>s.DingQueSuits[i]).Order().SequenceEqual(new[]{0,1,2}))return NotApplicable();
        var melds=SichuanDevelopmentPolicy.Melds(s,s.SeatIndex);
        var waits=new SichuanExactHandAnalyzer().EnumerateWaits(s.Hand18,s.Remaining18,melds.Count)
            .Where(w=>w.TileType/9!=s.OwnDingQueSuit).ToArray();
        var ownLane=SichuanSingleLaneEvaluator.ResolveSuit(s);
        if(ownLane>=0 && waits.Length>0&&waits.All(w=>w.TileType/9==ownLane))return NotApplicable();
        var history=new SichuanHuRefusalHistory(s);var reasons=new List<string>{"REPRESENTATIVE_HU_DISCIPLINE"};
        var danger=SichuanDistinctDingQueHuPolicy.AssessDanger(s,reasons);
        var opponentWon=opponents.Any(i=>s.HasHu[i])||history.Events.Any(e=>e.Seat!=s.SeatIndex&&e.Type==SichuanPublicEventType.Hu);
        var opponentLane=SichuanOpponentWideBedDefense.ActiveSeat(s)>=0;
        var counts=waits.GroupBy(w=>w.TileType/9).ToDictionary(g=>g.Key,g=>g.Sum(w=>s.Remaining18[w.TileType]));
        if(SichuanOpponentWideBedDefense.Applies(s))
        {
            var cashGroups=counts.OrderBy(g=>g.Key).Select(g=>new SichuanWaitSuitDiscipline(g.Key,
                opponents.Count(i=>s.DingQueSuits[i]==g.Key),"opponent_single_lane",g.Value,0,0,false,"cash_out")).ToArray();
            reasons.AddRange(new[]{SichuanOpponentWideBedDefense.ActiveCode,"OPPONENT_WIDE_BED_TAKE_LEGAL_HU",
                "在局对手独享本家缺门：按已确认防守偏好兑现合法胡牌，不因宽听或暗刻获得拒胡额度"});
            return new(true,false,history.OwnRound,history.Used,0,0,danger,opponentWon,true,
                history.GangRealized,"defensive_cash_out","opponent_wide_bed_defense",cashGroups,reasons.ToArray());
        }
        var hasTime=SichuanDevelopmentPolicy.Draws(s)>0;
        var canDevelop=hasTime&&danger==0;
        var viable=0;var development="";
        // Inference/route search is only needed where a live triplet or an
        // actual close big-hand route can change this chapter's decision.
        if(hasTime&&danger<2&&(s.Hand18.Any(n=>n>=3)||canDevelop&&counts.Any(g=>opponents.Count(i=>s.DingQueSuits[i]==g.Key)==2&&g.Value<=5)))
        {
            var belief=new SichuanBeliefEngine().Build(s);
            var wall=new SichuanWallAvailabilityEngine().Build(s,belief);
            viable=ViableGangs(s,belief,wall);
            if(canDevelop&&!history.GangRealized&&counts.Any(g=>g.Value<=5&&opponents.Count(i=>s.DingQueSuits[i]==g.Key)==2))
                development=FindDevelopment(s,melds,wall,0);
        }
        var origin="not_cashed";var narrowCashed=false;
        if(history.GangRealized)
        {
            var original=history.FirstRefusalWaits(s);
            if(original is null){origin="unknown_conservative_exit";narrowCashed=true;}
            else
            {
                var hadNarrowTwo=Enumerable.Range(0,3).Any(suit=>original[suit] is >0 and <=5
                    &&opponents.Count(i=>s.DingQueSuits[i]==suit)==2);
                // Another contested suit only buys one refusal. It cannot
                // renew a two-token narrow-development commitment after cashout.
                var wider=Enumerable.Range(0,3).Any(suit=>original[suit]>=6
                    &&opponents.Count(i=>s.DingQueSuits[i]==suit)==2);
                narrowCashed=hadNarrowTwo&&!wider;
                origin=narrowCashed?"narrow_development_cashed":"restore_base_budget";
            }
            reasons.Add("REPRESENTATIVE_GANG_CASH_OUT_"+origin);
        }
        var groups=new List<SichuanWaitSuitDiscipline>();
        foreach(var (suit,live) in counts.OrderBy(g=>g.Key))
        {
            var missing=opponents.Count(i=>s.DingQueSuits[i]==suit);
            var situation=opponentLane?"opponent_single_lane":missing switch {
                3=>"own_single_lane",2=>"two_opponents_missing",0=>"four_players_collect",_=>"other_competition"};
            var cap=0;var route="wait_self_draw";
            if(situation=="two_opponents_missing")
            {
                reasons.Add("TWO_MISSING_HU_DISCIPLINE");
                var sameSuit=SichuanIndependentTriplet.LiveTargets(s,suit).Length;
                cap=SichuanConcealedTripletHuTable.TwoMissing(live,history.OwnRound,danger,
                    history.GangRealized?0:sameSuit);
                if(!history.GangRealized&&sameSuit>=2&&cap>0)route="two_viable_gangs";
                // Preserve the previously approved early-exit restriction at
                // 6–7 copies once another player has already won.
                if(live is >=6 and <=7&&opponentWon)cap=0;
                if(live<=5&&sameSuit==0&&canDevelop&&!history.GangRealized
                    &&development.Length>0&&development!="two_viable_gangs")
                {cap=2;route=development;}
                reasons.Add("CONCEALED_TRIPLET_EXPLICIT_HU_TABLE_SAME_WAIT_SUIT");
            }
            else if(situation=="own_single_lane")
            {
                if(danger==0&&live>=3)cap=int.MaxValue;
                else if(danger==1&&live>=5)cap=2;
                else if(danger==0&&live==2&&viable>0) {cap=int.MaxValue;route="wait_live_gang";}
                if(melds.Any(m=>m.Type!=SichuanMeldType.Peng))cap=Math.Min(cap,1);
            }
            else
            {
                // The text's "9张以上/7张以上" is read inclusively, matching
                // its explicit >=8 convention. Other unlisted competition
                // patterns use this conservative band, never the old >=5/2.
                if(danger<2&&(live>=9||live>=7&&viable>0))cap=1;
                if(history.GangRealized)cap=0;
            }
            if(!hasTime||danger>=2||narrowCashed)cap=0;
            var density=waits.Where(w=>w.TileType/9==suit).Sum(w=>SichuanDevelopmentPolicy.Density(s,w.TileType,s.Remaining18));
            groups.Add(new(suit,missing,situation,live,density,cap,history.Used<cap,route));
            reasons.Add($"花色 {suit}：{situation}，未见听张 {live}，本家第 {history.OwnRound} 巡，拒胡上限 {cap}");
        }
        var maximum=groups.Select(g=>g.RefusalLimit).DefaultIfEmpty(0).Max();
        var supporting=groups.Where(g=>g.AllowsRefusal).OrderByDescending(g=>g.RefusalLimit).ThenByDescending(g=>g.DrawDensity).FirstOrDefault();
        var allowed=hasTime&&history.Used<maximum;
        if(groups.Count>1)reasons.Add("MIXED_WAIT_SUITS_INDEPENDENT_BANDS_SHARED_MAX_BUDGET");
        if(opponentWon)reasons.Add("REPRESENTATIVE_OPPONENT_ALREADY_WON");
        reasons.Add($"本家已拒胡 {history.Used} 次，活暗刻 {viable}，历史杠兑现 {history.GangRealized}");
        reasons.Add(allowed?"REPRESENTATIVE_REFUSAL_ELIGIBLE":"REPRESENTATIVE_TAKE_HU");
        return new(true,allowed,history.OwnRound,history.Used,maximum,viable,danger,opponentWon,opponentLane,
            history.GangRealized,origin,supporting?.DevelopmentRoute??"take_hu",groups.ToArray(),reasons.ToArray());
    }

    internal static int ViableGangs(SichuanStateView s,SichuanBeliefSnapshot belief,SichuanWallAvailability wall)
    {
        return SichuanIndependentTriplet.LiveTargets(s).Length;
    }

    internal static string FindDevelopment(SichuanStateView s,List<SichuanMeldView> melds,SichuanWallAvailability wall,int viable)
    {
        if(viable>=2)return "two_viable_gangs";
        var routes=new SichuanRouteContinuationEvaluator().Evaluate(s,s.Hand18,wall);
        var draws=SichuanDevelopmentPolicy.Draws(s);
        if(routes.Any(r=>r.Route=="flush"&&r.Reachable&&r.DistanceToWin is >1 and <=3
            &&r.DistanceToWin<=draws&&r.ExpectedWallCopies>0))return "near_flush";
        if(routes.Any(r=>r.Route=="seven_pairs"&&r.Reachable&&r.DistanceToWin is >1 and <=2
            &&r.DistanceToWin<=draws&&r.ExpectedWallCopies>0))return "near_seven_pairs";
        if(melds.Count==3&&draws>0)
        {
            var offer=s.PublicEvents.LastOrDefault(e=>e.Type is not SichuanPublicEventType.Draw
                and not SichuanPublicEventType.Pass and not SichuanPublicEventType.Hu);
            // A current offer is already public: zero unseen copies must not
            // hide the last claimable copy. Future claims need actual supply.
            for(var t=0;t<27;t++)if(s.Hand18[t]>=2&&t/9!=s.OwnDingQueSuit)
            {
                var offeredNow=offer?.Type==SichuanPublicEventType.Discard&&offer.Seat==s.CurrentSeat
                    &&offer.Seat!=s.SeatIndex&&offer.TileType==t;
                if(!offeredNow&&(s.Remaining18[t]<=0||wall.ExpectedCounts18[t]<=0))continue;
                var after=(int[])s.Hand18.Clone();after[t]-=2;
                var projected=melds.Append(new SichuanMeldView(SichuanMeldType.Peng,t,-1,0)).ToArray();
                var weights=(double[])wall.ExpectedCounts18.Clone();
                if(!offeredNow)weights[t]=Math.Max(0,weights[t]-1);
                for(var d=0;d<27;d++)if(after[d]>0)
                {
                    after[d]--;
                    var legal=SichuanReadyWaitPricing.HasLegalOwnedContext(s,after,projected);
                    var ready=legal?new SichuanReadyWaitPricing().Build(s,after,weights,projected):null;
                    after[d]++;
                    if(ready is {HasDrawableWait:true})return "one_peng_to_golden_hook";
                }
            }
        }
        return "";
    }
}
