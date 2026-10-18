using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class DistinctDingQueHuSmoke
{
    public static int Run()
    {
        try
        {
            var rule=new SichuanDistinctDingQueHuPolicy();
            var wide=Book(12,13,14,15,16);
            var eligible=new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(wide,11,1,"discard");
            Check(eligible.Reasons.Contains("DISTINCT_DINGQUE_REFUSAL_ELIGIBLE")
                && eligible.Reasons.Contains("HU_STRATEGY_CURRENT_STATE"),"eligible actions bypassed local strategy evidence");
            Console.WriteLine("eligible production action="+eligible.SelectedAction);
            var a=rule.Evaluate(wide);
            Check(a.Applies && a.UnseenWaitCopies==10 && a.MaximumRefusals==2 && a.AllowsRefusal,"wide ten-copy band");
            AddPass(wide,0); var once=rule.Evaluate(wide);
            Check(once.UsedRefusals==1 && once.AllowsRefusal,"first refusal");
            Check(rule.Evaluate(wide)==once || rule.Evaluate(wide).UsedRefusals==1,"queries spend no tokens");
            AddPass(wide,2);Check(rule.Evaluate(wide).UsedRefusals==1,"opponent refusal leaked into own budget");
            AddPass(wide,0);var exhausted=rule.Evaluate(wide);
            Check(exhausted.UsedRefusals==2 && !exhausted.AllowsRefusal,"second refusal exhausted budget");
            var decision=new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(wide,11,1,"discard");
            Check(decision.SelectedAction==SichuanActionType.Hu && decision.Reasons.Contains("DISTINCT_DINGQUE_TAKE_HU"),"production gate bypass");
            var restored=Book(12,13,14,15,16);restored.PublicEvents.AddRange(wide.PublicEvents.Skip(1));
            Check(rule.Evaluate(restored).UsedRefusals==2 && !rule.Evaluate(restored).AllowsRefusal,"round event replay restores budget");
            Check(rule.Evaluate(Book(12,13,14,15,16)).UsedRefusals==0,"new round budget");
            var memory=Book(12,13,14,15,16);AddPass(memory,0);AddPass(memory,0);
            memory.RoundId="distinct-budget-check";memory.HostGeneration=1;memory.ViewVersion=1;
            var host=new SichuanRoundAgentHost();host.Begin([memory]);
            Check(host.Inspect(memory).Plan?.HuDiscipline?.UsedRefusals==2,"agent plan omitted budget");
            var checkpoint=host.Capture(memory);host.End(memory.RoundId,1);
            memory.HostGeneration=2;host.Restore([memory],[checkpoint]);
            Check(host.Inspect(memory).Plan?.HuDiscipline?.AllowsRefusal==false
                && host.Inspect(memory).Plan?.HuDiscipline?.UsedRefusals==2,"agent checkpoint renewed budget");
            host.End(memory.RoundId,2);


            var two=Book(11,12,13,15,16); // 6/9筒, both four copies; incoming 3筒 isn't a wait.
            var b=rule.Evaluate(two);
            Check(b.UnseenWaitCopies==7 && b.MaximumRefusals==1 && b.AllowsRefusal,"seven-copy band after offered tile");
            AddPass(two,0);Check(!rule.Evaluate(two).AllowsRefusal,"one refusal limit");
            two.PublicEvents.Clear();two.PublicEvents.AddRange(wide.PublicEvents);
            Check(!rule.Evaluate(two).AllowsRefusal,"changing waits reset budget");
            foreach(var tail in new[]{new[]{10,11,12,15,17},new[]{11,12,13,15,17},new[]{11,11,11,15,17}})
                Check(!rule.Evaluate(Book(tail)).AllowsRefusal,"4-3 A/B/C narrow default");
            var d=Book(11,11,11,15,17);
            d.Hand18[24]--;d.Hand18[25]--;d.Hand18[26]+=2;
            Recount(d);
            var dark=rule.Evaluate(d);
            Check(dark.ViableGangTargets==2 && dark.MaximumRefusals==2 && dark.AllowsRefusal,"4-3 D two live gang opportunities");
            d.Visible18[26]++;d.Remaining18[26]--;
            Check(!rule.Evaluate(d).AllowsRefusal,"one fourth copy exhausted removes narrow exception");
            d.Visible18[26]--;d.Remaining18[26]++;
            AddPass(d,0);
            d.Hand18[26]=0;d.Visible18[26]=4;d.Remaining18[26]=0;d.HandCounts[0]=10;
            d.MeldViews[0].Add(new(SichuanMeldType.MeldedGang,26,1,10));d.Melds18[0].AddRange([26,26,26,26]);
            d.PublicEvents.Add(new(10,10,0,SichuanPublicEventType.MeldedGang,26,SourceSeat:1));
            Check(rule.Evaluate(d).GangRealized && !rule.Evaluate(d).AllowsRefusal,"cash out first gang then take Hu");

            var late=Book(12,13,14,15,16);
            for(var i=0;i<7;i++)late.PublicEvents.Add(new(20+i,i,0,SichuanPublicEventType.Draw,18));
            Check(rule.Evaluate(late).OwnRound==8 && !rule.Evaluate(late).AllowsRefusal,"eighth own round");
            var claimDraw=Book(12,13,14,15,16);
            claimDraw.PublicEvents.Add(new(20,1,0,SichuanPublicEventType.ConcealedGang,18));
            claimDraw.PublicEvents.Add(new(21,1,0,SichuanPublicEventType.Draw,19));
            Check(rule.Evaluate(claimDraw).OwnRound==1,"replacement draw counted as normal round");
            var normalDanger=Book(11,12,13,15,16);
            AddMeld(normalDanger,1,9);AddMeld(normalDanger,1,10);AddMeld(normalDanger,1,11);
            Check(rule.Evaluate(normalDanger).DangerLevel==1 && !rule.Evaluate(normalDanger).AllowsRefusal,"three Peng normal danger");
            var major=Book(12,13,14,15,16);
            AddMeld(major,1,9,SichuanMeldType.ConcealedGang);AddMeld(major,2,0,SichuanMeldType.AddedGang);
            Check(rule.Evaluate(major).DangerLevel==2 && !rule.Evaluate(major).AllowsRefusal,"two gangs major danger");
            var flush=Book(12,13,14,15,16);
            // This test means deliberate abandonment, not unknown-origin or
            // draw discards. Those negative controls live in Chapter412Smoke.
            flush.PublicEvents[0]=flush.PublicEvents[0] with{Origin=SichuanTileOrigin.Hand};
            for(var i=0;i<3;i++)flush.PublicEvents.Add(new(20+i,i,1,SichuanPublicEventType.Discard,11+i,Origin:SichuanTileOrigin.Hand));
            Check(rule.Evaluate(flush).DangerLevel==1,"suspected flush signal");
            AddMeld(flush,1,22);AddMeld(flush,1,23);
            Check(rule.Evaluate(flush).DangerLevel==2 && !rule.Evaluate(flush).AllowsRefusal,"strong flush signal");
            var different=Book(12,13,14,15,16);different.DingQueSuits[3]=1;
            Check(!rule.Evaluate(different).Applies,"rule applied outside distinct dingque");
            var incomplete=Book(12,13,14,15,16);incomplete.PublicEvents.Clear();
            Check(new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(incomplete,11,1,"discard").SelectedAction==SichuanActionType.Hu,
                "available quota forced refusal without valid EV evidence");
            var claim=Book(12,13,14,15,16);
            claim.PublicEvents.Add(new(2,2,0,SichuanPublicEventType.Peng,18,SourceSeat:1,CanHu:true));
            Check(rule.Evaluate(claim).UsedRefusals==1,"choosing Peng over Hu not counted");
            Console.WriteLine("distinct-dingque-hu: PASS; book bands, A/B/C/D, budgets/replay/seat isolation, danger, turn and gang exits, production gate");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine("distinct-dingque-hu: FAIL "+e);return 1;}
    }
    private static SichuanStateView Book(params int[] tail)
    {
        var hand=new int[27];foreach(var t in new[]{18,18,19,20,21,24,25,26}.Concat(tail))hand[t]++;
        var visible=new int[27];
        var incoming=new SichuanExactHandAnalyzer().EnumerateWaits(hand,Enumerable.Range(0,27).Select(t=>4-hand[t]).ToArray(),0).First().TileType;
        visible[incoming]=1;
        var s=SichuanStateCodec.FromRaw(0,0,1,55,hand,visible,dingQueSuits:[0,0,1,2],handCounts:[13,13,13,13]);
        s.Discards18[1].Add(incoming);s.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Discard,incoming));return s;
    }
    private static void Recount(SichuanStateView s){for(var t=0;t<27;t++)s.Remaining18[t]=4-s.Hand18[t]-s.Visible18[t];}
    private static void AddPass(SichuanStateView s,int seat){var id=s.PublicEvents.Max(e=>e.EventIndex)+1;s.PublicEvents.Add(new(id,(int)id,seat,SichuanPublicEventType.Pass,11,SourceSeat:1,CanHu:true));}
    private static void AddMeld(SichuanStateView s,int seat,int tile,SichuanMeldType type=SichuanMeldType.Peng)
    {s.MeldViews[seat].Add(new(type,tile,-1,0));s.Melds18[seat].AddRange(Enumerable.Repeat(tile,type==SichuanMeldType.Peng?3:4));}
    private static void Check(bool ok,string message){if(!ok)throw new InvalidOperationException(message);}
}
