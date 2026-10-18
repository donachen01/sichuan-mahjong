using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

internal static class SelfHuContinuationSmoke
{
    public static int Run()
    {
        try
        {
            void Check(bool ok,string why){if(!ok)throw new Exception(why);}
            var evaluator=new SichuanPublicEndgameEvaluator();var results=new List<object>();
            foreach(var rotation in Enumerable.Range(0,3))
            {
                var empty=Fixture(rotation,[]);
                var hu=evaluator.Simulate(empty.State,empty.Particle,[],-1,selfHuRoot:true);
                Check(hu.OwnSelfDraw && hu.OwnDraws==0 && hu.SelfDrawPayers==3 && hu.WinGain==6 && hu.ImmediateScore==6,"ordinary root self-Hu payment or invented draw");
                Check(Math.Abs(hu.NetScore-(hu.WinGain+hu.GangNet+hu.DrawSettlement-hu.DealInLoss-hu.OpponentLoss))<1e-8,"complete self-Hu settlement decomposition");
                var fixture=Fixture(rotation,new[]{(0+rotation*9)%27,(2+rotation*9)%27,(5+rotation*9)%27,(7+rotation*9)%27});
                var report=evaluator.AnalyzeSelfHuContinuation(fixture.State,new[]{(15+rotation*9)%27},32,20261008);
                Check(report.Candidates.Count==2,"public research root: "+report.Status);
                Check(report.Candidates[0].ExpectedOwnDraws==0 && Math.Abs(report.Candidates[0].WinGain-6)<1e-8,"self-Hu continued own policy or lost root payment: "+JsonSerializer.Serialize(report.Candidates[0]));
                Check(report.Candidates[1].RefusalDiscardTile==(15+rotation*9)%27,"refusal discard identity lost");
                foreach(var c in report.Candidates)Check(Math.Abs(c.NetScore-(c.WinGain+c.GangNet+c.DrawSettlement-c.DealInLoss-c.OpponentLoss))<1e-8,"paired complete settlement accounting");
                var before=report;
                fixture.State.IsReady[1]=true;fixture.State.PassedHu18[2][4]=7;fixture.State.LockedFans[1]=4;
                var privateChanged=evaluator.AnalyzeSelfHuContinuation(fixture.State,new[]{(15+rotation*9)%27},32,20261008);
                Check(before.Candidates.SequenceEqual(privateChanged.Candidates),"opponent private flags affected public self-Hu study");
                var hand=(int[])fixture.State.Hand18.Clone();
                using(SichuanPolicyExecutionScope.EnterDecision())
                {
                    var blocked=false;try{evaluator.AnalyzeSelfHuContinuation(fixture.State,new[]{15});}catch(InvalidOperationException){blocked=true;}
                    Check(blocked,"production could invoke self-Hu terminal simulations");
                }
                Check(hand.SequenceEqual(fixture.State.Hand18),"research mutated caller");
                results.Add(new{rotation,grounding="synthetic_checkpoint",report});
            }
            Console.WriteLine(JsonSerializer.Serialize(results));Console.WriteLine("SELF_HU_CONTINUATION PASS; no phantom discard, true root income, complete settlement, public isolation, research-only guard");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
    public static int RunStudy(string output,bool publicCleared=false)
    {
        try
        {
            var rows=new List<object>();var evaluator=new SichuanPublicEndgameEvaluator();
            foreach(var weak in new[]{false,true})
            foreach(var wallLength in new[]{12,40})
            foreach(var rotation in Enumerable.Range(0,3))
            {
                var available=Enumerable.Repeat(4,27).ToArray();
                var tiles=weak?new[]{0,0,0,5,5,5,2,3,4,6,7,8,15,15}:new[]{0,0,0,2,2,2,3,4,5,5,6,7,15,15};
                foreach(var t in tiles)available[t]--;
                var pool=Enumerable.Range(0,27).SelectMany(t=>Enumerable.Repeat(t,available[t])).ToArray();
                var random=new Random(20261009+wallLength);for(int i=pool.Length-1;i>0;i--){int j=random.Next(i+1);(pool[i],pool[j])=(pool[j],pool[i]);}
                if(publicCleared)pool=pool.OrderBy(t=>t/9==0?0:1).ToArray();
                var fixture=Fixture(rotation,pool.Take(wallLength).Select(t=>(t+rotation*9)%27).ToArray(),weak,publicCleared);
                var result=evaluator.AnalyzeSelfHuContinuation(fixture.State,new[]{(15+rotation*9)%27},32,20261009);
                if(result.Candidates.Count!=2)throw new Exception(result.Status);
                SichuanHuContinuationReport? evidenceAblation=null;
                if(publicCleared)
                {
                    var ablated=Fixture(rotation,pool.Take(wallLength).Select(t=>(t+rotation*9)%27).ToArray(),weak,false);
                    if(!fixture.Particle.Wall27.SequenceEqual(ablated.Particle.Wall27) || !fixture.Particle.Hands27.Zip(ablated.Particle.Hands27).All(p=>p.First.SequenceEqual(p.Second)))throw new Exception("public ablation changed underlying physical world");
                    evidenceAblation=evaluator.AnalyzeSelfHuContinuation(ablated.State,new[]{(15+rotation*9)%27},32,20261009);
                }

                rows.Add(new{source_case=weak?"6-10":"6-9",rotation,wallLength,
                    grounding="synthetic_checkpoint",original_wall_and_history_unknown=true,hidden_world_not_source_reconstruction=true,
                    public_posterior_not_strength_calibrated=true,public_cleared_missing_evidence=publicCleared,same_underlying_world_public_evidence_ablation=publicCleared,evidenceAblation,result});
            }
            File.WriteAllText(output,JsonSerializer.Serialize(rows,new JsonSerializerOptions{WriteIndented=true}));return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
    static (SichuanStateView State,SichuanHiddenHandParticle Particle) Fixture(int rotation,int[] wall,bool weak=false,bool publicCleared=false)
    {
        int Map(int t)=>(t+rotation*9)%27;
        var own=new int[27];foreach(var t in weak?new[]{2,3,4,6,7,8,15,15}:new[]{0,0,0,2,2,2,3,4,5,5,6,7,15,15})own[Map(t)]++;
        var pool=Enumerable.Repeat(4,27).ToArray();
        void Take(int t,int n=1){pool[t]-=n;if(pool[t]<0)throw new Exception("four-copy fixture violation");}
        for(int t=0;t<27;t++)Take(t,own[t]);if(weak){Take(Map(0),3);Take(Map(5),3);}foreach(var t in wall)Take(t);
        var hands=Enumerable.Range(0,4).Select(_=>new int[27]).ToArray();
        for(int seat=1;seat<4;seat++)for(int i=0;i<13;i++)
        {var t=Enumerable.Range(0,27).Where(t=>pool[t]>0).OrderBy(t=>t/9==rotation?1:0).ThenBy(t=>(t-rotation*9+27)%27).First();Take(t);hands[seat][t]++;}
        var visible=(int[])pool.Clone();if(weak){visible[Map(0)]+=3;visible[Map(5)]+=3;}
        var state=SichuanStateCodec.FromRaw(0,0,0,wall.Length,own,visible,dingQueSuits:[(rotation+2)%3,rotation,rotation,rotation],handCounts:[own.Sum(),13,13,13]);
        if(weak)foreach(var t in new[]{Map(0),Map(5)}){state.MeldViews[0].Add(new(SichuanMeldType.Peng,t,1,0));state.Melds18[0].AddRange(Enumerable.Repeat(t,3));}
        state.LastDrawTileType=Map(2);state.LastDrawOrigin=SichuanTileOrigin.Draw;
        for(int original=0;original<27;original++){int t=Map(original);for(int n=0;n<pool[t];n++)
        {state.Discards18[0].Add(t);state.PublicEvents.Add(new(state.PublicEvents.Count+1,state.PublicEvents.Count+1,0,SichuanPublicEventType.Discard,t));}}
        if(publicCleared)
        {
            state.PublicEvents.Clear();foreach(var d in state.Discards18)d.Clear();
            var publicTiles=Enumerable.Range(0,27).SelectMany(t=>Enumerable.Repeat(t,pool[t])).OrderBy(t=>t/9==rotation?0:1).ThenBy(t=>(t-rotation*9+27)%27).ToArray();
            if(publicTiles.Count(t=>t/9!=rotation)<3)throw new Exception("insufficient non-missing public clearance evidence");
            for(int i=0;i<publicTiles.Length;i++)
            {
                int seat=1+i%3,t=publicTiles[i];state.Discards18[seat].Add(t);
                state.PublicEvents.Add(new(i+1,i+1,seat,SichuanPublicEventType.Discard,t));
            }
            for(int seat=1;seat<4;seat++)
                if(!SichuanOpponentTimeline.MustHaveClearedMissing(state,seat) || Enumerable.Range(rotation*9,9).Any(t=>hands[seat][t]>0))
                    throw new Exception("clearance fixture contradicts public/legal hand boundary");
        }
        for(int t=0;t<27;t++)if(own[t]+hands.Sum(h=>h[t])+wall.Count(x=>x==t)+visible[t]!=4)throw new Exception("108 tile fixture violation");
        var counts=new int[27];foreach(var t in wall)counts[t]++;
        return(state,new(hands,counts,1));
    }
}
