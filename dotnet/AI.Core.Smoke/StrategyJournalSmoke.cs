using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;

internal static class StrategyJournalSmoke
{
    public static int Run()
    {
        try
        {
            var quadState = new SichuanStateView { SeatIndex = 0 };
            foreach (var tile in new[]{0,9,18}) {
                quadState.MeldViews[0].Add(new(SichuanMeldType.ConcealedGang,tile,0,0));
                quadState.Melds18[0].AddRange(Enumerable.Repeat(tile,4));
            }
            Check(quadState.OwnMeldCount==3,"three_quads_are_three_melds");
            var flush = new SichuanMahjong.AI.Core.Engines.SichuanFlushStructureEngine();
            var available = Enumerable.Repeat(4,27).ToArray();
            var shape = flush.Analyze(new int[27],available,new int[27],1,0);
            var expectedUseful = shape.UsefulDraws.ToArray();
            ((int[])shape.UsefulDraws)[0]=26;
            Check(flush.Analyze(new int[27],available,new int[27],1,0).UsefulDraws.SequenceEqual(expectedUseful),"exact_cache_snapshot_isolation");
            Check(flush.Analyze(new int[27],new int[27],new int[27],1,0).FeasiblePatterns==0,"exact_cache_public_availability_dependency");
            var facade=new SichuanAiFacade();facade.Agents.ResearchRecordingEnabled=true;var first=View(false,1,1);
            facade.Agents.Begin(new[]{first});
            var result=facade.DecideDiscard(first);
            Check(result.Action.TileType==18,"forced_missing_discard");
            var proposed=facade.Agents.Inspect(first);
            Check(proposed.Decisions.Length==1 && proposed.Decisions[0].Status=="pending","proposal_not_execution");
            Check(proposed.Decisions[0].Reasons.Length>0 && proposed.Decisions[0].Candidates.Length>0,"evidence_recorded");
            _=facade.DecideDiscard(first);
            Check(facade.Agents.Inspect(first).Decisions.Length==1,"idempotent_retry");
            proposed.Decisions[0].OwnHand[0]=99;
            Check(facade.Agents.Inspect(first).Decisions[0].OwnHand[0]!=99,"snapshot_isolation");
            var pending=facade.Agents.Capture(first);
            facade.Agents.End(first.RoundId,1);
            var restarted=View(false,1,2);facade.Agents.Restore(new[]{restarted},new[]{pending});
            Check(facade.Agents.Inspect(restarted).Decisions[0].Status=="invalidated_on_restore","restore_does_not_execute_pending");
            _=facade.DecideSelfAction(restarted,false,Array.Empty<int>(),Array.Empty<int>());
            _=facade.DecideDiscard(restarted);
            var next=View(true,2,2);facade.Agents.Observe(next);
            var done=facade.Agents.Inspect(next);
            Check(done.Proposal?.Status=="executed","event_confirms_execution");
            Check(done.Decisions.Any(d=>d.Kind=="self" && d.Status=="executed"
                && d.OutcomeMeaning=="self_pass_confirmed_by_normal_discard"),"self_pass_followup_confirmation");
            Check(done.Decisions.Last().Status=="executed" && done.Decisions.Last().ExecutionEvent==1,"trace_confirms_exact_event");
            Check(done.Decisions.Last().ObservedScoreDelta==0,"outcome_is_observed_not_invented");
            var saved=facade.Agents.Capture(next);
            facade.Agents.End(next.RoundId,2);var restored=View(true,2,3);
            facade.Agents.Restore(new[]{restored},new[]{saved});
            Check(facade.Agents.Inspect(restored).Decisions.Last().ExecutionEvent==1,"completed_trace_survives_restore");
            Console.WriteLine("STRATEGY_JOURNAL PASS actual_discard/evidence/confirmation/retry/isolation/restore");return 0;
        }
        catch(Exception ex){Console.Error.WriteLine(ex);return 1;}
    }
    private static void Check(bool ok,string label){if(!ok)throw new Exception(label);}
    private static SichuanStateView View(bool after,long version,long generation)
    {
        var hand=SichuanTileCodec.BuildCount18(new[]{0,1,2,3,4,5,6,7,8,9,10,11,13,18});
        var visible=new int[27];if(after){hand[18]--;visible[18]++;}
        var s=SichuanStateCodec.FromRaw(1,0,1,40,hand,visible,roundIndex:1701);
        s.RoundId="strategy-journal-test";s.HostGeneration=generation;s.ViewVersion=version;
        s.DingQueSuits=new[]{0,2,1,0};s.HandCounts[1]=hand.Sum();
        if(after){s.Discards18[1].Add(18);s.EventVersion=1;s.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Discard,18));}
        return s;
    }
}
