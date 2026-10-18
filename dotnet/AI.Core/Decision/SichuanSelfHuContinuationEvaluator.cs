using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed partial class SichuanPublicEndgameEvaluator
{
    // Research-only paired full continuation. Ordinary self-Hu and each legal
    // refusal discard share the same sampled public-information worlds.
    public SichuanHuContinuationReport AnalyzeSelfHuContinuation(SichuanStateView state,
        IReadOnlyList<int> refusalDiscards, int samples=32, int seed=20261002)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        SichuanHuContinuationReport Empty(string reason)=>new([],0,0,seed,reason);
        if(state.LastDrawOrigin!=SichuanTileOrigin.Draw || state.LastDrawTileType is <0 or >26
            || state.Hand18[state.LastDrawTileType]<=0 || SichuanSelfDrawContext.Resolve(state).WinType!=SichuanWinType.SelfDraw)
            return Empty("ordinary_self_draw_context_required");
        if(!SichuanPublicInferenceBoundary.TryProject(state,out var projection,out var reason))return Empty(reason);
        var melds=Melds(state,state.SeatIndex);
        if(!_hands.IsWinning(state.Hand18,melds.Count) || HasMissing(state.Hand18,state.OwnDingQueSuit))
            return Empty("self_hu_not_legal");
        var discards=refusalDiscards.Distinct().Order().ToArray();
        if(discards.Length==0 || discards.Any(t=>t is <0 or >26 || state.Hand18[t]<=0))return Empty("invalid_refusal_discard");
        projection.LastDrawTileType=state.LastDrawTileType;projection.LastDrawOrigin=state.LastDrawOrigin;
        projection.LockedFans[state.SeatIndex]=state.LockedFans[state.SeatIndex];
        samples=Math.Clamp(samples,32,512);
        var particles=_inference.SampleParticles(projection,samples,seed,SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        if(particles.Count!=samples || particles.Any(p=>!SichuanPublicInferenceBoundary.ParticleConserves(projection,p)))
            return Empty("particle_conservation_failed");
        var total=particles.Sum(p=>p.Weight);if(!(total>0))return Empty("zero_particle_weight");
        var ess=1.0/particles.Sum(p=>Math.Pow(p.Weight/total,2));
        SichuanPublicInferenceBoundary.RestorePolicyHistory(state,projection);
        var outcomes=new SimulationOutcome[particles.Count][];
        Parallel.For(0,particles.Count,new ParallelOptions{MaxDegreeOfParallelism=Math.Min(4,Environment.ProcessorCount)},i=>
        {
            using var cache=Engines.SichuanBeliefEngine.UseCache(new Engines.SichuanBeliefEngine.ScopedCache());
            var evaluator=new SichuanPublicEndgameEvaluator();
            var wall=ShuffledWall(particles[i],seed ^ projection.RoundIndex ^ i*7919, SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(projection));
            outcomes[i]=new[]{evaluator.Simulate(projection,particles[i],wall,-1,selfHuRoot:true)}
                .Concat(discards.Select(t=>evaluator.Simulate(projection,particles[i],wall,t))).ToArray();
        });
        var estimates=Enumerable.Range(0,discards.Length+1).Select(a=>
        {
            double Mean(Func<SimulationOutcome,double> f)=>Enumerable.Range(0,particles.Count).Sum(i=>f(outcomes[i][a])*particles[i].Weight/total);
            var delta=Enumerable.Range(0,particles.Count).Sum(i=>(outcomes[i][a].NetScore-outcomes[i][0].NetScore)*particles[i].Weight/total);
            var variance=Enumerable.Range(0,particles.Count).Sum(i=>particles[i].Weight/total*Math.Pow(outcomes[i][a].NetScore-outcomes[i][0].NetScore-delta,2));
            return new SichuanHuContinuationEstimate(a==0?SichuanActionType.Hu:SichuanActionType.Pass,
                Mean(r=>r.NetScore),delta,Math.Sqrt(variance/Math.Max(1,ess-1)),Mean(r=>r.WinGain),Mean(r=>r.GangNet),
                Mean(r=>r.DrawSettlement),Mean(r=>r.DealInLoss),Mean(r=>r.OpponentLoss),Mean(r=>r.OwnWon?1:0),
                Mean(r=>r.OwnSelfDraw?1:0),Mean(r=>r.SelfDrawPayers),Mean(r=>r.OwnDraws),Mean(r=>r.LockedRonDenied))
                {RefusalDiscardTile=a==0?-1:discards[a-1],ExpectedStrategicRefusals=Mean(r=>r.OwnStrategicRefusals)};
        }).ToArray();
        return new(estimates,samples,ess,seed,"complete_public_ordinary_self_hu_continuation");
    }
}
