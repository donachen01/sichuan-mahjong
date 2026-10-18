using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class GangCashflowSmoke
{
    public static int Run()
    {
        try
        {
            void Check(bool condition,string message){if(!condition)throw new Exception(message);}
            int checks=0;
            foreach(var actor in Enumerable.Range(0,4))
            foreach(var source in Enumerable.Range(0,4).Where(s=>s!=actor))
            foreach(var numberOfPayers in new[]{1,2,3})
            {
                var payers=new[]{source}.Concat(Enumerable.Range(0,4).Where(s=>s!=actor&&s!=source)).Take(numberOfPayers).ToArray();
                var active=Enumerable.Range(0,4).Select(s=>s==actor||payers.Contains(s)).ToArray();
                var state=SichuanStateCodec.FromRaw(actor,0,actor,55,new int[27],new int[27],activeSeats:active);
                for(int s=0;s<4;s++)state.HasHu[s]=!active[s];
                state.LastDrawOrigin=SichuanTileOrigin.Draw;state.LastDrawTileType=0;
                Check(SichuanMeldCounterfactualEvaluator.ProjectImmediateGangGain(state,"an_gang",source)==2*numberOfPayers,"concealed cash does not match actual payers");
                Check(SichuanMeldCounterfactualEvaluator.ProjectImmediateGangGain(state,"add_gang",source,0)==numberOfPayers,"顺摸补杠 cash does not match actual payers");
                Check(SichuanMeldCounterfactualEvaluator.ProjectImmediateGangGain(state,"add_gang",source,1)==0,"手上第四张补杠 incorrectly earns cash");
                Check(SichuanMeldCounterfactualEvaluator.ProjectImmediateGangGain(state,"melded_gang",source)==numberOfPayers+1,"discard source must pay two, other active seats one");
                checks+=3;
            }
            var settlementEngine = new SichuanSettlementProjectionEngine();
            var noScore = settlementEngine.ProjectScenario(new SichuanSettlementScenario(
                GangEvents: new[] { new SichuanGangScoreEvent(0, SichuanMeldType.AddedGang, new[] { 1, 2, 3 }, ScoreEligible: false) }));
            Check(noScore.GangChanges.SequenceEqual(new[] { 0, 0, 0, 0 }), "手上牌补杠仍进入结算杠分");
            var scored = settlementEngine.ProjectScenario(new SichuanSettlementScenario(
                GangEvents: new[] { new SichuanGangScoreEvent(0, SichuanMeldType.AddedGang, new[] { 1, 2, 3 }, ScoreEligible: true) }));
            Check(scored.GangChanges.SequenceEqual(new[] { 3, -1, -1, -1 }), "顺摸补杠未进入结算杠分");
            checks += 2;
            foreach(var rotation in Enumerable.Range(0,3))
            foreach(var payerCount in new[]{1,2,3})
            {
                int Map(int t)=>(t+rotation*9)%27;
                var hand=new int[27];hand[Map(19)]=3;hand[Map(22)]=1;
                var visible=new int[27];foreach(var t in new[]{18,23,26})visible[Map(t)]=3;visible[Map(19)]=1;
                var active=Enumerable.Range(0,4).Select(s=>s<=payerCount).ToArray();
                var state=SichuanStateCodec.FromRaw(0,0,1,55,hand,visible,activeSeats:active,dingQueSuits:[rotation,(rotation+1)%3,rotation,(rotation+1)%3],handCounts:[4,13,13,13]);
                foreach(var t in new[]{18,23,26}) {state.MeldViews[0].Add(new(SichuanMeldType.Peng,Map(t),1,0));state.Melds18[0].AddRange(Enumerable.Repeat(Map(t),3));}
                state.Discards18[1].Add(Map(19));state.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Discard,Map(19)));
                for(int s=0;s<4;s++)state.HasHu[s]=!active[s];
                var evaluator=new SichuanMeldCounterfactualEvaluator();
                var a=evaluator.Evaluate(state,"gang",Map(19),3,4,0,0,999,gangSourceSeat:1);
                var b=evaluator.Evaluate(state,"melded_gang",Map(19),3,4,0,0,-999,gangSourceSeat:1);
                Check(a.ImmediateGangGain==payerCount+1 && a.Value==b.Value,"gang aliases or caller heuristic changed rule cash");
                Check(a.ReplacementWinProbability>0,"test did not exercise replacement win");
                var win=(int[])hand.Clone();win[Map(19)]-=3;win[Map(22)]++;
                var melds=state.MeldViews[0].Append(new SichuanMeldView(SichuanMeldType.MeldedGang,Map(19),1,1)).ToArray();
                var fan=new SichuanFanProjectionEngine().Project(win,melds,SichuanWinType.DianGangHua);
                Check(Math.Abs(a.ReplacementWinGain-a.ReplacementWinProbability*fan.PerPayerScore)<1e-7,"discard-gang replacement win charged multiple payers");
                var actual=new SichuanAiFacade().DecideReaction(state,Map(19),false,true,true,1,"discard");
                var gang=actual.ValueCandidates.Single(c=>c.Action.ActionType==SichuanActionType.Gang);
                Check(gang.GangGain==payerCount+1 && gang.ReasonCodes.Contains("GANG_RULE_CASHFLOW"),"real reaction ranking did not use rule cash");
                // Independently enumerate the normal rotation after replacement
                // and discard. These reduced-wall component cases check timing,
                // not reconstructed complete deals.
                foreach(var wall in new[]{1,2,4,8,9,55})
                {
                    var timingState=SichuanStateCodec.FromRaw(0,0,1,wall,hand,visible,activeSeats:active,dingQueSuits:[rotation,(rotation+1)%3,rotation,(rotation+1)%3],handCounts:[4,13,13,13]);
                    timingState.MeldViews[0].AddRange(state.MeldViews[0]);timingState.Melds18[0].AddRange(state.Melds18[0]);
                    for(int s=0;s<4;s++)timingState.HasHu[s]=!active[s];
                    var timed=evaluator.Evaluate(timingState,"melded_gang",Map(19),3,4,0,0,0,gangSourceSeat:1);
                    var remaining=Math.Max(0,wall-1);var next=0;var ownDraws=0;
                    for(int draw=0;draw<remaining;draw++)
                    {
                        do{next=(next+3)%4;}while(!active[next]);
                        if(next==0)ownDraws++;
                    }
                    Check(timed.ContinuationWallCount==remaining && timed.OwnFutureDrawBudget==ownDraws,
                        $"replacement consumed twice or next own draw counted early: wall={wall}, payers={payerCount}");
                    checks++;
                }
                checks++;
            }
            Console.WriteLine($"GANG_CASHFLOW PASS checks={checks}; actors/sources/payer exit, suit transfer, point-gang win payment, real reaction ranking");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
