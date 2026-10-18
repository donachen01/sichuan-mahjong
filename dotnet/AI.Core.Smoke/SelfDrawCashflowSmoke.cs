using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class SelfDrawCashflowSmoke
{
    public static int Run()
    {
        try
        {
            void Check(bool ok,string why){if(!ok)throw new Exception(why);}
            int checks=0;
            foreach(var actor in Enumerable.Range(0,4))
            foreach(var source in Enumerable.Range(0,4).Where(s=>s!=actor))
            foreach(var payerCount in new[]{1,2,3})
            foreach(var kind in new[]{"melded_gang","an_gang","add_gang"})
            {
                var payers=new[]{source}.Concat(Enumerable.Range(0,4).Where(s=>s!=source && s!=actor)).Take(payerCount).ToArray();
                var active=Enumerable.Range(0,4).Select(s=>s==actor || payers.Contains(s)).ToArray();
                var hand=new int[27];foreach(var t in Enumerable.Range(18,9))hand[t]++;hand[15]=2;
                var visible=new int[27];visible[9]=4;
                var sizes=Enumerable.Range(0,4).Select(s=>s==actor?11:13).ToArray();
                var state=SichuanStateCodec.FromRaw(actor,0,actor,54,hand,visible,activeSeats:active,dingQueSuits:[0,0,0,0],handCounts:sizes);
                for(int s=0;s<4;s++)state.HasHu[s]=!active[s];
                var type=kind=="melded_gang"?SichuanMeldType.MeldedGang:kind=="an_gang"?SichuanMeldType.ConcealedGang:SichuanMeldType.AddedGang;
                state.MeldViews[actor].Add(new(type,9,kind=="melded_gang"?source:actor,1));state.Melds18[actor].AddRange(Enumerable.Repeat(9,4));
                state.OwnDrawReason="gang_draw";state.LastGangSeat=actor;state.LastGangType=kind;state.LastGangSourceSeat=kind=="melded_gang"?source:actor;state.LastDrawOrigin=SichuanTileOrigin.Draw;state.LastDrawTileType=15;
                var winType=kind=="melded_gang"?SichuanWinType.DianGangHua:SichuanWinType.GangSelfDraw;
                var fan=new SichuanFanProjectionEngine().Project(hand,state.MeldViews[actor],winType);
                var expected=fan.PerPayerScore*(kind=="melded_gang"?1:payerCount);
                var result=new SichuanAiFacade().DecideSelfAction(state,true,[],[]);
                Check(result.Action.ActionType==SichuanActionType.Hu && result.ActionScores["hu"]==expected*1000,"self-Hu entry charged wrong players or win fan");
                Check(result.Reasons.Contains("SELF_DRAW_RULE_CASHFLOW"),"rule pricing absent from real self action");
                state.PublicEvents.Add(new(1,1,actor,kind=="melded_gang"?SichuanPublicEventType.MeldedGang:kind=="an_gang"?SichuanPublicEventType.ConcealedGang:SichuanPublicEventType.AddedGang,9,SourceSeat:state.LastGangSourceSeat));
                state.OwnDrawReason="normal_draw"; // historical gang metadata remains
                var plain=new SichuanFanProjectionEngine().Project(hand,state.MeldViews[actor],SichuanWinType.SelfDraw);
                var ordinary=new SichuanAiFacade().DecideSelfAction(state,true,[],[]);
                Check(ordinary.ActionScores["hu"]==plain.PerPayerScore*payerCount*1000 && SichuanSelfDrawContext.Resolve(state).WinType==SichuanWinType.SelfDraw,"stale gang upgraded a later ordinary self draw");
                var explanation=new SichuanUnifiedDecisionEngine().ConfirmSelfDrawHu(state);
                var refusal=explanation.Candidates.Single(c=>c.Action.ActionType==SichuanActionType.Pass);
                Check(!refusal.IsAdmissible && refusal.ReasonCodes.Contains("SELF_DRAW_PASS_COST_ONLY_NOT_CONTINUATION_EV"),"unmeasured refusal cost presented as calibrated continuation EV");
                checks++;
            }
            Console.WriteLine($"SELF_DRAW_CASHFLOW PASS checks={checks}; all actors/sources/payer counts, point flower single payer, other gang self-draw, stale metadata, real facade, honest refusal scope");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
