using System.Diagnostics;
using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class HuWaitingModelSmoke
{
    internal static int[] Hand(params int[] tiles) { var h=new int[27]; foreach(var t in tiles)h[t]++; return h; }
    internal static SichuanStateView Book(int missingWaitSeats=3, bool cleared=true, bool dead=false)
    {
        var own=Hand(18,18,19,20,21,24,25,26,12,13,14,15,16);
        var visible=Hand(11,0,1,2);
        int wall=52;
        if(dead)foreach(var t in new[]{11,14,17}) {int n=4-own[t]-visible[t];visible[t]+=n;wall-=n;}
        var s=SichuanStateCodec.FromRaw(0,0,1,wall,own,visible,
            dingQueSuits:[0,missingWaitSeats>=1?1:2,missingWaitSeats>=2?1:2,missingWaitSeats>=3?1:2],
            handCounts:[13,13,13,13]);
        long index=0;
        for(int seat=1;seat<4;seat++)
        {
            int t=cleared?seat-1:s.DingQueSuits[seat]*9;
            if(!cleared){s.Visible18[seat-1]--;s.Remaining18[seat-1]++;s.Visible18[t]++;s.Remaining18[t]--;}
            s.Discards18[seat].Add(t);s.PublicEvents.Add(new(++index,1,seat,SichuanPublicEventType.Discard,t));
        }
        if(dead)foreach(var t in new[]{11,14,17})
        {
            int n=s.Visible18[t]-(t==11?1:0);
            for(int j=0;j<n;j++){s.Discards18[1].Add(t);s.PublicEvents.Add(new(++index,1,1,SichuanPublicEventType.Discard,t));}
        }
        s.Discards18[1].Add(11);s.PublicEvents.Add(new(++index,1,1,SichuanPublicEventType.Discard,11));
        return s;
    }
    private static SichuanReadyPrice Price(int tile=11) => new([new(tile,0,1,2,1)],1,0,1,2);
    private static SichuanStateView Variant(int[] hand,int offered)
    {
        var s=SichuanStateCodec.FromRaw(0,0,1,52,hand,Hand(offered,0,1,2),
            dingQueSuits:[0,1,1,1],handCounts:[13,13,13,13]);
        for(int i=1;i<4;i++){s.Discards18[i].Add(i-1);s.PublicEvents.Add(new(i,1,i,SichuanPublicEventType.Discard,i-1));}
        s.Discards18[1].Add(offered);s.PublicEvents.Add(new(4,1,1,SichuanPublicEventType.Discard,offered));
        return s;
    }
    // Abstract hit/miss classes for probability arithmetic, not GameState
    // fixtures; concrete book states above enforce the four-copy boundary.
    private static SichuanStateView MathState(int wall,int source=1) => new()
    {SeatIndex=0,CurrentSeat=source,WallCount=wall,ActiveSeats=[true,true,true,true],HasHu=[false,false,false,false]};
    private static SichuanHuWaitingModel.SeatHazard Zero() => new(new double[27],new double[27],0,
        new double[27],new double[27],new double[27],new double[27]);
    public static int Run(string folder)
    {
        int checks=0;
        void Check(bool ok,string message){checks++;if(!ok)throw new InvalidOperationException(message);}
        void Near(double x,double y,string message)=>Check(Math.Abs(x-y)<1e-9,message+$": {x:R} != {y:R}");
        var rows=new List<object>();
        try
        {
            using var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_oracle.json")));
            var root=oracle.RootElement;
            var baseState=Book();
            var waits=new SichuanExactHandAnalyzer().EnumerateWaits(baseState.Hand18,baseState.Remaining18).Select(w=>w.TileType).ToArray();
            Check(waits.SequenceEqual(root.GetProperty("bookWaits").EnumerateArray().Select(x=>x.GetInt32())),"independent book waits");
            foreach(var row in root.GetProperty("opportunities").EnumerateArray())
            {
                int n=row.GetProperty("wall").GetInt32(), k=row.GetProperty("hits").GetInt32();
                var s=MathState(n);var wall=new int[27];wall[11]=k;wall[0]=n-k;
                var value=SichuanHuWaitingModel.Integrate(s,wall,Price(),new SichuanHuWaitingModel.SeatHazard?[4]);
                double expected=row.GetProperty("probability").GetDouble();
                Near(value.SelfDrawOpportunity,expected,"finite-wall opportunity");
                Near(value.SelfDrawGain,6*expected,"rule gain without hazards");
                Near(value.WaitingLoss,0,"no fabricated waiting cost");
            }
            foreach(var row in root.GetProperty("joint").EnumerateArray())
            {
                var c=row.GetProperty("counts").EnumerateArray().Select(x=>x.GetInt32()).ToArray();
                Near(SichuanHuWaitingModel.JointMiss(c[0],c[1],c[2],c[3],row.GetProperty("a").GetInt32(),row.GetProperty("b").GetInt32()),
                    row.GetProperty("probability").GetDouble(),"joint-survival permutation oracle");
            }
            // A positive own win probability is correlated with this payer's
            // prior exit. An unconditional 'probability * mean payers' fails.
            var correlationState=MathState(2,2);
            var hazards=new SichuanHuWaitingModel.SeatHazard?[4];hazards[1]=Zero();hazards[1]!.SelfPrice[0]=2;hazards[1]!.RonPrice[0]=1;
            var correlation=SichuanHuWaitingModel.Integrate(correlationState,Hand(0,11),Price(),hazards);
            var expectedCorrelation=root.GetProperty("correlation");
            Near(correlation.SelfDrawGain,expectedCorrelation.GetProperty("selfDrawGain").GetDouble(),"joint payer pricing");
            Near(correlation.OpponentSelfDrawLoss,expectedCorrelation.GetProperty("opponentLoss").GetDouble(),"actual self-draw payment");
            Near(correlation.SelfDrawPayerMass,expectedCorrelation.GetProperty("payerMass").GetDouble(),"joint payer mass");
            Near(correlation.ConditionalSelfDrawPayers,expectedCorrelation.GetProperty("conditionalPayers").GetDouble(),"conditional payer count");
            var one=MathState(1);
            var ronHazards=new SichuanHuWaitingModel.SeatHazard?[4];ronHazards[1]=Zero();ronHazards[1]!.RonPrice[0]=4;
            var ron=SichuanHuWaitingModel.Integrate(one,Hand(0),Price(),ronHazards);
            Near(ron.DealInLoss,4,"actual ron price");Near(ron.OpponentSelfDrawLoss,0,"ron is not self-draw loss");
            var gangHazards=new SichuanHuWaitingModel.SeatHazard?[4];gangHazards[1]=Zero();gangHazards[1]!.DiscardGangPrice[0]=2;
            Near(SichuanHuWaitingModel.Integrate(one,Hand(0),Price(),gangHazards).GangPaymentLoss,0,"last tile no replacement Gang");
            one=MathState(2);
            Near(SichuanHuWaitingModel.Integrate(one,Hand(0,0),Price(),gangHazards).GangPaymentLoss,2,"same fourth copy cannot charge twice");
            var development=new SichuanHuWaitingModel.SeatHazard?[4];development[1]=Zero() with{ReadyTransition=1};
            development[1]!.DevelopedSelfChance[0]=1;development[1]!.DevelopedSelfPrice[0]=2;
            var devState=MathState(5,2);
            Near(SichuanHuWaitingModel.Integrate(devState,Hand(0,0,0,0,0),Price(),development).OpponentSelfDrawLoss,2,"measured readiness transition grows later hazard");

            var model=new SichuanHuWaitingModel();
            for(int count=0;count<=3;count++)
            {
                var state=Book(count);var timer=Stopwatch.StartNew();var estimate=model.Estimate(state);
                Check(estimate.Supported,"public book state: "+estimate.Status);
                rows.Add(new{name="cleared_missing_"+count,estimate,milliseconds=timer.ElapsedMilliseconds});
                Console.WriteLine($"book cleared missing={count}: wallHits={estimate.ExpectedWallWaitCopies:F4} p={estimate.SelfDrawOpportunity:F4} gain={estimate.SelfDrawGain:F4} cost={estimate.WaitingLoss:F4} net={estimate.LocalNet:F4} ms={timer.ElapsedMilliseconds}");
            }
            var ordinary=model.Estimate(Book(0));var exclusive=model.Estimate(Book(3));
            Check(exclusive.ExpectedWallWaitCopies>ordinary.ExpectedWallWaitCopies,"cleared missing competition must affect wall supply");
            Check(exclusive.SelfDrawOpportunity>ordinary.SelfDrawOpportunity,"cleared missing competition must affect probability");
            Near(exclusive.ExpectedWallWaitCopies,10,"all cleared missing suit copies really are in wall");
            var unclear=model.Estimate(Book(3,cleared:false));
            Check(unclear.Supported,"uncleared state: "+unclear.Status);
            Check(unclear.ExpectedWallWaitCopies<10,"declaration alone treated as cleared");
            foreach(var variant in root.GetProperty("variants").EnumerateArray())
            {
                var hand=variant.GetProperty("hand").EnumerateArray().Select(t=>t.GetInt32()).ToArray();
                int offer=variant.GetProperty("offer").GetInt32();var state=Variant(hand,offer);
                var actualWaits=new SichuanExactHandAnalyzer().EnumerateWaits(hand,state.Remaining18).Select(w=>w.TileType);
                Check(actualWaits.SequenceEqual(variant.GetProperty("waits").EnumerateArray().Select(t=>t.GetInt32())),"new hand independent waits");
                var estimate=model.Estimate(state);Check(estimate.Supported,"variant public state: "+estimate.Status);
                Near(estimate.ExpectedWallWaitCopies,variant.GetProperty("copies").GetInt32(),"new hand wall copies");
                Near(estimate.SelfDrawOpportunity,variant.GetProperty("probability").GetDouble(),"new hand independent probability");
                var action=new SichuanReactionDecisionEngine().DecideReaction(state,offer,true,false,false,1);
                rows.Add(new{name=variant.GetProperty("name").GetString(),estimate,action=action.Action,action.Reasons});
            }
            var dead=model.Estimate(Book(dead:true));Check(dead.Supported,"dead state: "+dead.Status);
            Near(dead.SelfDrawOpportunity,0,"dead waits have zero self-draw opportunity");
            var before=JsonSerializer.Serialize(exclusive);
            var privateChanged=Book();privateChanged.IsReady[1]=true;privateChanged.IsCalled[2]=true;
            privateChanged.LockedFans[1]=8;privateChanged.PassedHu18[1][11]=9;
            privateChanged.PublicEvents.Add(new(100,3,2,SichuanPublicEventType.Draw,26));
            privateChanged.PublicEvents.Add(new(101,3,2,SichuanPublicEventType.Pass,11,SourceSeat:1,CanHu:true));
            Check(before==JsonSerializer.Serialize(model.Estimate(privateChanged)),"private flags or hidden draws leaked");
            var incomplete=Book();incomplete.PublicEvents.Clear();
            Check(!model.Estimate(incomplete).Supported,"incomplete public allocations accepted");
            var melds=Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
            foreach(var t in new[]{0,1,2,3})melds[1].Add(new(SichuanMeldType.Peng,t,2,0));
            var strong=HuIncomeCostSmoke.Fixture(baseState.Hand18,[9,17],2,11,new(){[1]=Hand(9)},melds);
            strong.State.DingQueSuits[0]=0;strong.State.DingQueSuits[1]=2;
            Check(SichuanPublicInferenceBoundary.ParticleConserves(strong.State,strong.Particle),"strong fixture must conserve108 copies");
            var strongPrice=new SichuanReadyWaitPricing().Build(strong.State,strong.State.Hand18,strong.Particle.Wall27.Select(n=>(double)n).ToArray())!;
            var strongEstimate=model.AssessAllocation(strong.State,strong.Particle,strongPrice);
            Check(strongEstimate.OpponentSelfDrawLoss>0 && strongEstimate.SelfDrawGain<6*strongEstimate.SelfDrawOpportunity,"real hand threat must cost and reduce payers");
            var rootReaction=new SichuanPublicEndgameEvaluator.HuReactionRoot(11,2,SichuanWinType.Discard,SichuanActionType.Pass,-1,SichuanMeldType.AddedGang,-1,[],[]);
            var fullEvaluator=new SichuanPublicEndgameEvaluator();
            var exactOrders=new[]{new[]{9,17},new[]{17,9}}.Select(w=>fullEvaluator.Simulate(strong.State,strong.Particle,w,-1,reaction:rootReaction)).ToArray();
            Near(strongEstimate.SelfDrawGain,exactOrders.Average(o=>o.WinGain),"real108-copy opponent exit exact order comparison");
            Near(strongEstimate.OpponentSelfDrawLoss,exactOrders.Average(o=>o.OpponentLoss),"real108-copy selfdraw price exact order comparison");
            rows.Add(new{name="physical_threat",estimate=strongEstimate,exactOrders});
            foreach(var kind in new[]{"drawn_added","held_added","concealed"})
            {
                var gs=Enumerable.Range(0,4).Select(_=>new List<SichuanMeldView>()).ToArray();
                int[] opponent, wallTiles;
                if(kind=="concealed")
                {opponent=Hand(0,0,0,1,2,3,4,5,6,10,11,15,15);wallTiles=[0,17];}
                else
                {
                    gs[1].Add(new(SichuanMeldType.Peng,9,2,0));
                    opponent=kind=="held_added"?Hand(9,10,11,18,19,20,24,25,26,12):Hand(18,19,20,21,22,23,24,25,26,12);
                    wallTiles=kind=="held_added"?[12,0]:[9,0];
                }
                var world=HuIncomeCostSmoke.Fixture(baseState.Hand18,wallTiles,2,11,new(){[1]=opponent},gs);
                world.State.DingQueSuits[0]=0;world.State.DingQueSuits[1]=kind=="concealed"?2:0;
                var pricing=new SichuanReadyWaitPricing().Build(world.State,world.State.Hand18,world.Particle.Wall27.Select(n=>(double)n).ToArray())!;
                var estimate=model.AssessAllocation(world.State,world.Particle,pricing);
                double expected=kind=="held_added"?0:kind=="concealed"?1:0.5;
                Near(estimate.GangPaymentLoss,expected,"physical ready-preserving Gang cash "+kind);
                rows.Add(new{name="physical_gang_"+kind,estimate});
            }
            var policy=new SichuanReactionDecisionEngine();
            var high=policy.DecideReaction(Book(),11,true,false,false,1);
            var low=policy.DecideReaction(Book(dead:true),11,true,false,false,1);
            Check(high.Action.ActionType==SichuanActionType.Pass,"wide supplied live production expected Pass: "+string.Join(";",high.Reasons));
            Check(low.Action.ActionType==SichuanActionType.Hu,"dead waits live production expected Hu");
            Check(high.Reasons.Contains("HU_WAITING_SUPPLY_AND_EVENT_COST_V1"),"production model not connected");
            foreach(var c in high.ValueCandidates)Near(c.ExpectedNetScore,c.WinGain+c.GangGain+c.ChaJiaoValue-c.DealInLoss-c.OpponentFutureLoss,"live candidate decomposition");
            rows.Add(new{name="production_live",high.Action,high.Reasons,candidates=high.ValueCandidates});
            rows.Add(new{name="production_dead",low.Action,low.Reasons,candidates=low.ValueCandidates});
            rows.Add(new{name="uncleared",estimate=unclear});rows.Add(new{name="dead",estimate=dead});rows.Add(new{name="correlation",estimate=correlation});
            File.WriteAllText(Path.Combine(folder,"model_results.json"),JsonSerializer.Serialize(new{checks,rows},new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"hu-waiting-model: PASS checks={checks}");return 0;
        }
        catch(Exception e)
        {
            File.WriteAllText(Path.Combine(folder,"model_failure.json"),JsonSerializer.Serialize(new{checks,error=e.ToString(),rows},new JsonSerializerOptions{WriteIndented=true}));
            Console.Error.WriteLine("hu-waiting-model: FAIL "+e);return 1;
        }
    }
}
