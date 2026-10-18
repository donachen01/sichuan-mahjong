using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class RepresentativeHuSmoke
{
    static readonly int[] Wide=[18,18,19,20,21,24,25,26,12,13,14,15,16];
    static readonly int[] Medium=[18,18,19,20,21,24,25,26,11,12,13,15,16];
    static readonly int[] Narrow=[18,18,19,20,21,24,25,26,11,12,13,15,17];
    static readonly int[] TwoMissing=[0,1,1,0];
    public static int Run()
    {
        try
        {
            var rule=new SichuanRepresentativeHuPolicy();
            var wide=Book(Wide,TwoMissing);
            Check(rule.Evaluate(wide).RefusalLimit==2&&rule.Evaluate(wide).AllowsRefusal,"wide >=8 band");
            var eight=Book(Wide,TwoMissing,8);Check(rule.Evaluate(eight).RefusalLimit==2,"exactly eight");
            var seven=Book(Medium,TwoMissing);Check(rule.Evaluate(seven).RefusalLimit==1,"seven band");
            var six=Book(Medium,TwoMissing,6);Check(rule.Evaluate(six).RefusalLimit==1,"six band");
            var five=Book(Medium,TwoMissing,5);Check(!rule.Evaluate(five).AllowsRefusal,"five defaults Hu");
            for(var i=0;i<7;i++)Add(eight,0,SichuanPublicEventType.Draw,-1);
            Check(rule.Evaluate(eight).OwnRound==8&&!rule.Evaluate(eight).AllowsRefusal,"eight-round boundary");
            var won=Book(Medium,TwoMissing);won.HasHu[3]=true;won.ActiveSeats[3]=false;
            Check(!rule.Evaluate(won).AllowsRefusal,"first opponent win closes medium band");
            var wonEvent=Book(Medium,TwoMissing);Add(wonEvent,3,SichuanPublicEventType.Hu,18);
            Check(!rule.Evaluate(wonEvent).AllowsRefusal,"public Hu event closes band before flag refresh");
            var normal=Book(Medium,TwoMissing);for(var t=18;t<21;t++)normal.MeldViews[1].Add(new(SichuanMeldType.Peng,t,-1,0));
            Check(rule.Evaluate(normal).Danger==1&&!rule.Evaluate(normal).AllowsRefusal,"medium general danger");
            var wideNormal=Book(Wide,TwoMissing);for(var t=18;t<21;t++)wideNormal.MeldViews[1].Add(new(SichuanMeldType.Peng,t,-1,0));
            Check(rule.Evaluate(wideNormal).AllowsRefusal,"wide tolerates general danger");
            wideNormal.MeldViews[1].Add(new(SichuanMeldType.Peng,21,-1,0));
            Check(!rule.Evaluate(wideNormal).AllowsRefusal,"major danger exit");

            var oneGang=Book([18,18,19,20,21,26,26,26,11,12,13,15,16],TwoMissing);
            Check(rule.Evaluate(oneGang).ViableGangTargets==1&&rule.Evaluate(oneGang).RefusalLimit==2,"medium live triplet bonus");
            var deadGang=Book([18,18,19,20,21,26,26,26,11,12,13,15,16],TwoMissing);
            deadGang.Visible18[26]++;deadGang.Remaining18[26]--;
            Check(rule.Evaluate(deadGang).RefusalLimit==1,"dead fourth no bonus");
            var twoGang=Book([18,18,19,20,21,26,26,26,11,11,11,15,17],TwoMissing);
            Check(rule.Evaluate(twoGang).Goal=="two_viable_gangs"&&rule.Evaluate(twoGang).RefusalLimit==2,"narrow two gangs");
            Pass(twoGang);var cashed=CashGang(twoGang,26);
            var cash=rule.Evaluate(cashed);
            Check(cash.GangRealized&&cash.CashOutOrigin=="narrow_development_cashed"&&!cash.AllowsRefusal,"narrow cash-out history");
            // Improve 79 to 78 after cash-out: same round must not renew quota.
            cashed.Hand18[16]++;cashed.Hand18[17]--;cashed.Visible18[17]++;
            for(var t=0;t<27;t++)cashed.Remaining18[t]=4-cashed.Hand18[t]-cashed.Visible18[t];
            Add(cashed,0,SichuanPublicEventType.Draw,16);Add(cashed,0,SichuanPublicEventType.Discard,17);
            Check(rule.Evaluate(cashed).WaitSuits.Sum(g=>g.UnseenCopies)>=6
                &&rule.Evaluate(cashed).RefusalLimit==0,"widening after narrow cashout renewed budget");
            Pass(oneGang);var baseAgain=rule.Evaluate(CashGang(oneGang,26));
            Check(baseAgain.CashOutOrigin=="restore_base_budget"&&baseAgain.RefusalLimit==1&&!baseAgain.AllowsRefusal,"medium restores original one-token budget");

            var contested=Book(Wide,[0,0,0,0]);
            Check(rule.Evaluate(contested).WaitSuits.Single().Situation=="four_players_collect"&&rule.Evaluate(contested).RefusalLimit==1,"four-way nine-plus band");
            var contestedGeneral=Book(Wide,[0,0,0,0]);
            for(var t=18;t<21;t++)contestedGeneral.MeldViews[1].Add(new(SichuanMeldType.Peng,t,-1,0));
            Check(rule.Evaluate(contestedGeneral).Danger==1&&rule.Evaluate(contestedGeneral).RefusalLimit==1,
                "four-way wide eligibility should still be priced under general danger");
            var contestedEight=Book(Wide,[0,0,0,0],8);Check(!rule.Evaluate(contestedEight).AllowsRefusal,"four-way eight no triplet");
            var contestedGang=Book([18,18,19,20,21,26,26,26,11,12,13,15,16],[0,0,0,0]);
            Check(rule.Evaluate(contestedGang).RefusalLimit==1,"four-way seven plus live triplet");
            var otherLane=Book(Wide,[0,1,0,0]);
            Check(rule.Evaluate(otherLane).OpponentSingleLane&&!rule.Evaluate(otherLane).AllowsRefusal,"opponent single lane defensive cash-out");
            Pass(contested);Check(!rule.Evaluate(contested).AllowsRefusal,"one refusal exhausted");
            var take=new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(contested,contested.Discards18[1][0],1,"discard");
            Check(take.SelectedAction==SichuanActionType.Hu&&take.Reasons.Contains("REPRESENTATIVE_TAKE_HU"),"formal root bypassed new gate");
            Check(!new SichuanDevelopmentPolicy().ShouldRefuse(contested,contested.Discards18[1][0],SichuanWinType.Discard),"rollout bypassed same gate");
            var golden=Book([9,9,10,11],TwoMissing,ownMelds:[new(SichuanMeldType.Peng,18,1,0),new(SichuanMeldType.Peng,21,1,0),new(SichuanMeldType.Peng,24,1,0)]);
            Check(rule.Evaluate(golden).Goal=="one_peng_to_golden_hook"&&rule.Evaluate(golden).RefusalLimit==2,"one Peng golden hook exception");

            var flush=Book([9,9,9,10,11,12,13,14,15,16,17,22,22],TwoMissing);
            flush.Visible18[12]++;flush.Remaining18[12]--;
            Check(rule.Evaluate(flush).Goal=="near_flush"&&rule.Evaluate(flush).RefusalLimit==2,"two-shanten flush exception");
            var pairs=Book([9,9,10,10,11,11,12,12,13,13,14,15,16],TwoMissing,5);
            Check(rule.Evaluate(pairs).Goal=="near_seven_pairs"&&rule.Evaluate(pairs).RefusalLimit==2,"one-shanten seven pairs exception");
            var mixed=Book([9,9,9,10,11,18,18,18,19,20,21,22,23],TwoMissing,offeredTile:12);
            foreach(var t in new[]{9,18}){mixed.Visible18[t]++;mixed.Remaining18[t]--;}
            var mixedResult=rule.Evaluate(mixed);
            Console.WriteLine("mixed="+string.Join(";",mixedResult.WaitSuits.Select(g=>$"{g.Suit}:{g.UnseenCopies}/{g.RefusalLimit}")));
            Check(mixedResult.WaitSuits.Length==2&&mixedResult.WaitSuits.Sum(g=>g.UnseenCopies)>=8
                &&!mixedResult.AllowsRefusal,"mixed waits added together into favourable band");
            var mixedSupported=Book([9,9,9,10,11,18,18,18,19,20,21,22,23],TwoMissing,offeredTile:12);
            var supported=rule.Evaluate(mixedSupported);
            Check(supported.AllowsRefusal&&supported.RefusalLimit==supported.WaitSuits.Max(g=>g.RefusalLimit),"mixed independent support/shared max budget");
            Pass(mixedSupported);
            Check(rule.Evaluate(CashGang(mixedSupported,9)).CashOutOrigin=="narrow_development_cashed",
                "other suit renewed narrow cashout commitment");
            var replacement=Book(Wide,TwoMissing);
            Add(replacement,0,SichuanPublicEventType.ConcealedGang,18);Add(replacement,2,SichuanPublicEventType.Draw,26);Add(replacement,0,SichuanPublicEventType.Draw,11);
            Check(rule.Evaluate(replacement).OwnRound==1,"replacement inflates own round");
            var hidden=Book(Wide,TwoMissing);var clean=rule.Evaluate(hidden);
            hidden.IsReady[2]=true;hidden.LockedFans[2]=4;hidden.PassedHu18[2][11]=3;
            Add(hidden,2,SichuanPublicEventType.Pass,11,true);Add(hidden,2,SichuanPublicEventType.Draw,26);
            var dirty=rule.Evaluate(hidden);
            Check(clean.RefusalLimit==dirty.RefusalLimit&&clean.UsedRefusals==dirty.UsedRefusals
                &&clean.AllowsRefusal==dirty.AllowsRefusal,"opponent private facts alter quota");
            var eligible=Book(Wide,TwoMissing);
            var liveChoice=new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(eligible,eligible.Discards18[1][0],1,"discard");
            Check(liveChoice.Reasons.Contains("REPRESENTATIVE_REFUSAL_ELIGIBLE")
                &&liveChoice.Reasons.Contains("HU_STRATEGY_CURRENT_STATE"),"eligible root skipped local strategy evidence");
            Console.WriteLine("eligible actual action="+liveChoice.SelectedAction);
            // Public particle projection must preserve rule history for later
            // policy without feeding private opponent data into inference.
            Check(SichuanPublicInferenceBoundary.TryProject(wide,out var projected,out var reason,true,1),"public fixture "+reason);
            Add(wide,0,SichuanPublicEventType.Draw,18);
            Add(wide,2,SichuanPublicEventType.Draw,22); // illegal private observation, excluded
            Add(wide,2,SichuanPublicEventType.Pass,11,true);
            SichuanPublicInferenceBoundary.RestorePolicyHistory(wide,projected);
            Check(projected.PublicEvents.Any(e=>e.Seat==0&&e.Type==SichuanPublicEventType.Draw&&e.TileType==18)
                &&!projected.PublicEvents.Any(e=>e.Seat==2&&(e.Type==SichuanPublicEventType.Pass||e.Type==SichuanPublicEventType.Draw&&e.TileType>=0)),"policy history information boundary");
            var memory=Book(Wide,TwoMissing);Pass(memory);Pass(memory);
            memory.RoundId="representative-history";memory.HostGeneration=1;memory.ViewVersion=1;
            var host=new SichuanRoundAgentHost();host.Begin([memory]);
            var snapshot=host.Inspect(memory);
            Check(snapshot.Plan?.DevelopmentPlan?.Representative?.UsedRefusals==2,"agent per-suit plan missing");
            snapshot.Plan!.DevelopmentPlan!.Representative!.WaitSuits[0]=snapshot.Plan.DevelopmentPlan.Representative.WaitSuits[0] with {RefusalLimit=99};
            Check(host.Inspect(memory).Plan!.DevelopmentPlan!.Representative!.WaitSuits[0].RefusalLimit==2,"mutable snapshot leaked");
            var checkpoint=host.Capture(memory);host.End(memory.RoundId,1);memory.HostGeneration=2;
            host.Restore([memory],[checkpoint]);Check(!host.Inspect(memory).Plan!.DevelopmentPlan!.AllowsRefusal,"restore renews budget");host.End(memory.RoundId,2);
            Console.WriteLine("representative-hu: PASS; bands, round/danger/winner exits, live/dead gangs, cashout replay, formal/rollout gates, memory/privacy");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
    internal static SichuanStateView Book(int[] tiles,int[] missing,int? live=null,SichuanMeldView[]? ownMelds=null,int? offeredTile=null)
    {
        ownMelds??=[];var hand=new int[27];foreach(var t in tiles)hand[t]++;
        var visible=new int[27];foreach(var m in ownMelds)visible[m.TileType]+=m.Type==SichuanMeldType.Peng?3:4;
        var remaining=Enumerable.Range(0,27).Select(t=>4-hand[t]-visible[t]).ToArray();
        var waits=new SichuanExactHandAnalyzer().EnumerateWaits(hand,remaining,ownMelds.Length);
        Check(waits.Count>0,"fixture not ready");var offered=offeredTile??waits[0].TileType;visible[offered]++;
        if(live.HasValue)
        {
            var excess=waits.Sum(w=>4-hand[w.TileType]-visible[w.TileType])-live.Value;
            foreach(var w in waits){var cut=Math.Min(Math.Max(0,excess),4-hand[w.TileType]-visible[w.TileType]);visible[w.TileType]+=cut;excess-=cut;}
            Check(excess==0,"fixture live target");
        }
        var s=SichuanStateCodec.FromRaw(0,0,1,108-hand.Sum()-39-visible.Sum(),hand,visible,dingQueSuits:missing,handCounts:[hand.Sum(),13,13,13]);
        s.MeldViews[0].AddRange(ownMelds);foreach(var m in ownMelds)s.Melds18[0].AddRange(Enumerable.Repeat(m.TileType,m.Type==SichuanMeldType.Peng?3:4));
        s.Discards18[1].Add(offered);Add(s,1,SichuanPublicEventType.Discard,offered);return s;
    }
    internal static void Add(SichuanStateView s,int seat,SichuanPublicEventType type,int tile,bool hu=false)
    {var id=s.PublicEvents.Select(e=>e.EventIndex).DefaultIfEmpty(0).Max()+1;s.PublicEvents.Add(new(id,(int)id,seat,type,tile,SourceSeat:1,CanHu:hu));s.EventVersion=id;}
    static void Pass(SichuanStateView s)=>Add(s,0,SichuanPublicEventType.Pass,s.Discards18[1][0],true);
    static SichuanStateView CashGang(SichuanStateView before,int tile)
    {
        var hand=(int[])before.Hand18.Clone();hand[tile]-=3;
        var visible=(int[])before.Visible18.Clone();visible[tile]+=4;visible[0]++;
        var after=SichuanStateCodec.FromRaw(0,0,1,before.WallCount-2,hand,visible,dingQueSuits:before.DingQueSuits,handCounts:[hand.Sum(),13,13,13]);
        for(var i=0;i<4;i++){after.MeldViews[i].AddRange(before.MeldViews[i]);after.Melds18[i].AddRange(before.Melds18[i]);after.Discards18[i].AddRange(before.Discards18[i]);}
        after.MeldViews[0].Add(new(SichuanMeldType.ConcealedGang,tile,0,0));after.Melds18[0].AddRange([tile,tile,tile,tile]);
        after.PublicEvents.AddRange(before.PublicEvents);
        Add(after,0,SichuanPublicEventType.Draw,tile);Add(after,0,SichuanPublicEventType.ConcealedGang,tile);
        Add(after,0,SichuanPublicEventType.Draw,0);Add(after,0,SichuanPublicEventType.Discard,0);return after;
    }
    static void Check(bool ok,string message){if(!ok)throw new InvalidOperationException(message);}
}
