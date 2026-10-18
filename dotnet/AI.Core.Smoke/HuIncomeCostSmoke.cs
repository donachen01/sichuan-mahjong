using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class HuIncomeCostSmoke
{
    private static readonly int[] BookHand = Hand(18,18,19,20,21,24,25,26,12,13,14,15,16);
    public static int Run(bool diagnostics = false, bool rulesOnly = false)
    {
        var previousTiming=SichuanPolicyTiming.Enabled;
        if(diagnostics)SichuanPolicyTiming.Enabled=true;
        using var progress=diagnostics?new System.Threading.Timer(_=>
        {
            Console.WriteLine("HU_RESEARCH_PROFILE "+DateTimeOffset.UtcNow.ToString("O"));
            foreach(var row in SichuanPolicyTiming.Report().Take(7))Console.WriteLine(row);
        },null,TimeSpan.FromSeconds(30),TimeSpan.FromSeconds(30)):null;
        try
        {
            var evaluator = new SichuanPublicEndgameEvaluator();
            var state = PublicBookState();
            var timer = System.Diagnostics.Stopwatch.StartNew();
            SichuanHuContinuationReport? report=null;
            if(!rulesOnly)
            {
            Console.WriteLine("hu-income-cost: starting 32 paired full-wall research samples (55 wall tiles)");
            report = evaluator.AnalyzeHuContinuation(state,11,1,samples:32,seed:12345);
            Check(report.Candidates.Count==2, "public reaction sampling: "+report.Status);
            foreach(var c in report.Candidates)
                Check(Math.Abs(c.NetScore-(c.WinGain+c.GangNet+c.DrawSettlement-c.DealInLoss-c.OpponentLoss))<1e-8,"score decomposition");
            Console.WriteLine($"public paired samples={report.Samples} ess={report.EffectiveSampleSize:F1} ms={timer.ElapsedMilliseconds}");
            foreach(var c in report.Candidates) Console.WriteLine($"{c.Action}: net={c.NetScore:F3} delta={c.DifferenceFromHu:F3} se={c.DifferenceStandardError:F3} draws={c.ExpectedOwnDraws:F2}");
            var snapshot=(int[])state.Hand18.Clone();
            state.IsReady[1]=true; state.IsCalled[2]=true; state.LockedFans[1]=4;
            state.PassedHu18[2][11]=7;
            state.PublicEvents.Add(new(100,1,2,SichuanPublicEventType.Draw,26));
            state.PublicEvents.Add(new(101,1,2,SichuanPublicEventType.Pass,11,SourceSeat:1,CanHu:true));
            Console.WriteLine("hu-income-cost: privacy invariance full-wall batch");
            var changed=evaluator.AnalyzeHuContinuation(state,11,1,samples:32,seed:12345);
            Check(report.Candidates.SequenceEqual(changed.Candidates),"private runtime data leaked into decision");
            Check(snapshot.SequenceEqual(state.Hand18),"caller hand mutated");
            }
            timer.Restart();
            var policy = new SichuanReactionDecisionEngine().DecideReaction(PublicBookState(),11,true,false,false,1);
            Check(policy.Reasons.Any(r=>r=="HU_STRATEGY_CURRENT_STATE"),"production reaction bypasses local strategy");
            Console.WriteLine($"production={policy.Action.ActionType} ms={timer.ElapsedMilliseconds}");

            // Physically conserved deterministic worlds exercise the actual
            // event rules independently of the statistical inference layer.
            var own=(int[])BookHand.Clone();
            var fixture=Fixture(own,[17],1,11);
            var root=Root(11,1,SichuanActionType.Pass);
            var pass=evaluator.Simulate(fixture.State,fixture.Particle,[17],-1,reaction:root);
            Check(pass.OwnSelfDraw && pass.SelfDrawPayers==3 && pass.OwnDraws==1 && pass.WinGain==6,"actual reverse seat order or self-draw payers");
            var hu=evaluator.Simulate(fixture.State,fixture.Particle,[17],-1,reaction:root with{Action=SichuanActionType.Hu});
            Check(hu.WinGain==1 && hu.OwnDraws==0,"Hu branch immediate payment");
            var zero=Fixture(own,[],1,11, new(){[2]=Hand(0,0,1,1,2,2,3,4,5,7,9,10,12)});
            zero.State.DingQueSuits[2]=2;
            var huEnd=evaluator.Simulate(zero.State,zero.Particle,[],-1,reaction:root with{Action=SichuanActionType.Hu});
            Check(huEnd.DrawSettlement==0,"exited Hu winner must not receive future cha-jiao");
            var end=evaluator.Simulate(zero.State,zero.Particle,[],-1,reaction:root);
            Check(end.OwnDraws==0 && !end.OwnWon,"empty wall fabricated a draw");
            Check(Math.Abs(end.NetScore-end.DrawSettlement)<1e-9,"tail-wall value must be real settlement");

            var exit=Fixture(own,[6,17],2,11,new(){[1]=Hand(0,0,0,1,2,3,4,5,6,7,8,9,9)});
            exit.State.DingQueSuits[1]=2;
            var depleted=evaluator.Simulate(exit.State,exit.Particle,[6,17],-1,reaction:Root(11,2,SichuanActionType.Pass));
            Check(depleted.OwnSelfDraw && depleted.SelfDrawPayers==2 && depleted.OpponentLoss>0,
                $"dynamic exit cost/payers: {depleted}");
            var lockedWorld=Fixture(own,[2,17],2,11,new(){[1]=Hand(0,0,1,2,3,4,5,6,7,8,18,19,11)});
            lockedWorld.State.DingQueSuits[1]=1;
            var locked=evaluator.Simulate(lockedWorld.State,lockedWorld.Particle,[2,17],-1,reaction:Root(11,2,SichuanActionType.Pass));
            Check(locked.LockedRonDenied>=1 && locked.OwnSelfDraw,"same-fan lock then own-draw release");

            var gangMelds=Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
            gangMelds[1].Add(new(SichuanMeldType.MeldedGang,0,2,0));
            var gangWorld=Fixture(own,[],1,11,melds:gangMelds);
            var gangRoot=Root(11,1,SichuanActionType.Hu) with {WinType=SichuanWinType.GangDiscard,
                GangType=SichuanMeldType.MeldedGang,GangSource=2,GangPayers=[0,2,3]};
            var transfer=evaluator.Simulate(gangWorld.State,gangWorld.Particle,[],-1,reaction:gangRoot);
            Check(transfer.WinGain==2 && transfer.GangNet==4,"gang-discard transfer or fan");

            // Passing a robbed added gang allows the actor to collect gang
            // money and draw the replacement; taking it prevents both.
            var robMelds=Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
            robMelds[1].Add(new(SichuanMeldType.Peng,11,2,0));
            var robWorld=Fixture(own,[0],1,11,melds:robMelds);
            var robRoot=Root(11,1,SichuanActionType.Pass) with{WinType=SichuanWinType.RobAddedGang};
            var robPass=evaluator.Simulate(robWorld.State,robWorld.Particle,[0],-1,reaction:robRoot);
            var robHu=evaluator.Simulate(robWorld.State,robWorld.Particle,[0],-1,reaction:robRoot with{Action=SichuanActionType.Hu});
            Check(robPass.GangNet==0 && robPass.Events.Any(e=>e.Type==SichuanPublicEventType.AddedGang && e.GangScoreEligible)
                && robHu.GangNet==0 && robHu.WinGain==2,"rob gang cancellation or unready wall-end refund");
            // Restore pending fourth tile to the source's concealed hand to
            // match the real transport. Public sampling must reserve it there.
            var raw=robWorld.State;
            raw.PendingAddedGangScoreEligible = true;
            raw.HandCounts[1]++; raw.Visible18[11]--; raw.Remaining18[11]++;
            raw.Discards18[1].Remove(11);
            raw.PublicEvents.RemoveAll(e=>e.Type==SichuanPublicEventType.Discard && e.TileType==11);
            var history=raw.Discards18.SelectMany(d=>d).ToArray();
            foreach(var discards in raw.Discards18)discards.Clear();
            raw.PublicEvents.Clear();
            foreach(var t in history){raw.Discards18[0].Add(t);raw.PublicEvents.Add(new(raw.PublicEvents.Count+1,raw.PublicEvents.Count+1,0,SichuanPublicEventType.Discard,t));}
            Console.WriteLine("hu-income-cost: pending rob-Gang public batch");
            var robPublic=evaluator.AnalyzeHuContinuation(raw,11,1,"qiang_gang_hu",32,9123);
            Check(robPublic.Candidates.Count==2,"rob public root: "+robPublic.Status);
            Check(Math.Abs(robPublic.Candidates.Single(c=>c.Action==SichuanActionType.Hu).WinGain-2)<1e-9,"rob public score");

            // A winner between the source and us changes the resume point:
            // after source 3, seat 1 wins, so seat 0 draws before seat 2.
            var resume=Fixture(own,[17],3,11,new(){[1]=Hand(0,0,0,1,2,3,4,5,6,9,10,7,7)});
            resume.State.DingQueSuits[1]=2;
            var resumed=evaluator.Simulate(resume.State,resume.Particle,[17],-1,reaction:Root(11,3,SichuanActionType.Pass));
            Check(resumed.OwnSelfDraw && resumed.SelfDrawPayers==2,"resume after last ron winner");
            resume.State.HasHu[1]=true;resume.State.ActiveSeats[1]=false;resume.State.WonScores[1]=1;
            var already=evaluator.Simulate(resume.State,resume.Particle,[17],-1,reaction:Root(11,3,SichuanActionType.Pass) with{PriorWinners=[1]});
            Check(already.OwnSelfDraw && already.SelfDrawPayers==2,"earlier resolved winner not counted twice");

            var cannon=Fixture(own,[0],1,11,new(){[3]=Hand(1,2,3,4,5,6,9,10,11,12,13,14,0)});
            cannon.State.DingQueSuits[3]=2;
            var paidHu=evaluator.Simulate(cannon.State,cannon.Particle,[0],-1,reaction:Root(11,1,SichuanActionType.Pass));
            Check(paidHu.DealInLoss==1 && !paidHu.OwnWon,"waiting cost omitted actual own discard loss");

            var gangCost=Fixture(own,[0,23,17],2,11,new(){[1]=Hand(0,0,0,1,2,3,4,5,6,9,10,18,18)});
            gangCost.State.DingQueSuits[1]=2;
            var paidGang=evaluator.Simulate(gangCost.State,gangCost.Particle,[0,23,17],-1,reaction:Root(11,2,SichuanActionType.Pass));
            Check(paidGang.GangNet==0,"unready opponent must refund concealed-gang cash at wall exhaustion: "+paidGang.GangNet);
            Check(SichuanRuleSnapshot.Frozen.EnableGangRefund,"test expects the current draw-refund rules");

            var claimHand=Hand(9,9,9,10,11,12,13,14,18,19,20,21,21);
            var higherWorld=Fixture(claimHand,[0],2,15,new(){[1]=Hand(0,0,1,2,3,4,5,6,7,8,22,23,9)});
            higherWorld.State.DingQueSuits[1]=1;
            var higher=evaluator.Simulate(higherWorld.State,higherWorld.Particle,[0],-1,reaction:Root(15,2,SichuanActionType.Pass));
            Check(higher.OwnWon && !higher.OwnSelfDraw && higher.OwnDraws==0 && higher.WinGain==2,
                "higher fan ron must bypass same-or-lower lock");
            var claim=SichuanStateCodec.FromRaw(0,0,1,55,claimHand,Hand(9),dingQueSuits:[0,0,0,0],handCounts:[13,13,13,13]);
            claim.Discards18[1].Add(9);claim.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Discard,9));
            if(!rulesOnly)
            {
            Console.WriteLine("hu-income-cost: Hu/Pass/Peng/Gang full-wall batch");
            var claimReport=evaluator.AnalyzeHuContinuation(claim,9,1,samples:32,seed:87,pengDiscard:10,canGang:true);
            Check(claimReport.Candidates.Select(c=>c.Action).ToHashSet().SetEquals(new[]{SichuanActionType.Hu,SichuanActionType.Pass,SichuanActionType.Peng,SichuanActionType.Gang}),"Hu/Peng/Gang not on same scoring horizon");
            foreach(var c in claimReport.Candidates)Check(Math.Abs(c.NetScore-(c.WinGain+c.GangNet+c.DrawSettlement-c.DealInLoss-c.OpponentLoss))<1e-8,"claim score decomposition");
            // More than four own draws are possible; the former four-draw cap
            // must not survive in the production Hu/Pass path.
            Check(report!.Candidates.Single(c=>c.Action==SichuanActionType.Pass).ExpectedOwnDraws>4,"old four-draw cap survived");
            }

            // Complete public-history requirement is visible, not a fabricated
            // probability fallback or a crash on an older incomplete payload.
            state=PublicBookState(); state.PublicEvents.Clear();
            var blocked=evaluator.AnalyzeHuContinuation(state,11,1);
            Check(blocked.Candidates.Count==0,"incomplete history accepted");
            var safe=new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(state,11,1,"discard");
            Check(safe.SelectedAction==SichuanActionType.Hu && safe.Reasons.Contains("HU_STRATEGY_CURRENT_STATE"),"incomplete state refused legal Hu");
            Console.WriteLine(rulesOnly?"hu-income-cost rules-only: PASS (long-wall batches excluded explicitly)":"hu-income-cost: PASS"); return 0;
        }
        catch(Exception e){Console.Error.WriteLine("hu-income-cost: FAIL "+e);return 1;}
        finally { SichuanPolicyTiming.Enabled=previousTiming; }
    }
    internal static SichuanStateView PublicBookState()
    {
        var visible=Hand(11);
        var state=SichuanStateCodec.FromRaw(0,0,1,55,(int[])BookHand.Clone(),visible,
            dingQueSuits:[0,0,0,0],handCounts:[13,13,13,13]);
        state.Discards18[1].Add(11);
        state.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Discard,11));
        return state;
    }
    internal static (SichuanStateView State,SichuanHiddenHandParticle Particle) Fixture(int[] own,int[] wall,int source,int offered,
        Dictionary<int,int[]>? overrides=null,List<SichuanMeldView>[]? melds=null)
    {
        melds ??= Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
        var pool=Enumerable.Repeat(4,27).ToArray();
        void Take(int tile,int n=1){pool[tile]-=n;Check(pool[tile]>=0,"invalid fixture tile "+tile);}
        for(var t=0;t<27;t++)Take(t,own[t]);
        foreach(var t in wall)Take(t);
        Take(offered);
        foreach(var m in melds.SelectMany(m=>m))Take(m.TileType,m.Type==SichuanMeldType.Peng?3:4);
        var hands=Enumerable.Range(0,4).Select(_=>new int[27]).ToArray();
        foreach(var (seat,hand) in overrides ?? new())
        {hands[seat]=(int[])hand.Clone();for(var t=0;t<27;t++)Take(t,hand[t]);}
        for(var seat=1;seat<4;seat++)
        {
            if(overrides?.ContainsKey(seat)==true)continue;
            var size=13-3*melds[seat].Count;
            for(var i=0;i<size;i++){var t=Array.FindIndex(pool,c=>c>0);Take(t);hands[seat][t]++;}
        }
        var visible=(int[])pool.Clone(); visible[offered]++;
        foreach(var m in melds.SelectMany(m=>m))visible[m.TileType]+=m.Type==SichuanMeldType.Peng?3:4;
        var missing=Enumerable.Range(0,4).Select(s=>s==0?0:Enumerable.Range(0,27).First(t=>hands[s][t]>0)/9).ToArray();
        var state=SichuanStateCodec.FromRaw(0,0,source,wall.Length,(int[])own.Clone(),visible,
            dingQueSuits:missing,handCounts:[own.Sum(),hands[1].Sum(),hands[2].Sum(),hands[3].Sum()]);
        long index=0;
        for(var seat=0;seat<4;seat++)foreach(var m in melds[seat])
        {
            state.MeldViews[seat].Add(m);
            state.Melds18[seat].AddRange(Enumerable.Repeat(m.TileType,m.Type==SichuanMeldType.Peng?3:4));
        }
        // Historical discards distribute to a seat retaining that suit, so
        // they do not falsely prove every opponent has cleared its missing suit.
        for(var t=0;t<27;t++)for(var n=0;n<pool[t];n++)
        {
            var seat=Enumerable.Range(1,3).FirstOrDefault(s=>missing[s]==t/9,source);
            state.Discards18[seat].Add(t);state.PublicEvents.Add(new(++index,(int)index,seat,SichuanPublicEventType.Discard,t));
        }
        state.Discards18[source].Add(offered);
        state.PublicEvents.Add(new(++index,(int)index,source,SichuanPublicEventType.Discard,offered));
        for(var t=0;t<27;t++)Check(own[t]+hands.Sum(h=>h[t])+wall.Count(x=>x==t)+visible[t]==4,"fixture conservation");
        return(state,new(hands,Hand(wall),1));
    }
    private static SichuanPublicEndgameEvaluator.HuReactionRoot Root(int tile,int source,SichuanActionType action)
        =>new(tile,source,SichuanWinType.Discard,action,-1,SichuanMeldType.AddedGang,-1,[],[]);
    private static int[] Hand(params int[] tiles){var h=new int[27];foreach(var t in tiles)h[t]++;return h;}
    private static void Check(bool condition,string message){if(!condition)throw new InvalidOperationException(message);}
}
