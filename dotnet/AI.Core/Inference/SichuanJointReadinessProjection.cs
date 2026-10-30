using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanJointReadinessReport(bool Supported,string Status,int Samples,
    double PriorEffectiveSamples,double EffectiveSamples,double MaximumMarginalError,
    double[] Target,double[] PriorReady,double[] Ready,double[] PriorMaskMass,double[] MaskMass,
    double MaximumWeight,double RelativeEntropy,int Iterations)
{
    // Hypothetical allocations remain internal; diagnostics expose summaries.
    internal IReadOnlyList<SichuanHiddenHandParticle> Particles {get;init;}=[];
    public string Proposal {get;init;}="public_weighted_ready_mixture_v1";
    public double[] PriorWallCopies {get;init;}=[];
    public double[] WallCopies {get;init;}=[];
    public double[] PriorWallPresence {get;init;}=[];
    public double[] WallPresence {get;init;}=[];
}

/// <summary>Minimum-relative-entropy projection of the existing JOINT public
/// allocation to independently calibrated ready marginals. Never a product of
/// marginal seat hands. Physical allocations and within-mask weight ratios
/// are preserved. Missing support and low effective mass are explicit refusals.
/// This is a research/diagnostic capability, not a live action-score override.</summary>
public sealed class SichuanJointReadinessProjection
{
    internal sealed record Fit(bool Supported,string Status,double[] Mass,int Iterations,double Error);

    internal static Fit FitMasks(IReadOnlyList<double> prior,IReadOnlyDictionary<int,double> targets)
    {
        if(prior.Count!=16||prior.Any(x=>!double.IsFinite(x)||x<0)||!(prior.Sum()>0)
            ||targets.Any(x=>x.Key is <0 or >3||!double.IsFinite(x.Value)||x.Value is <0 or >1))
            return new(false,"invalid_probability_input",[],0,double.PositiveInfinity);
        var mass=prior.Select(x=>x/prior.Sum()).ToArray();
        double Marginal(int seat)=>Enumerable.Range(0,16).Where(m=>(m&(1<<seat))!=0).Sum(m=>mass[m]);
        for(int cycle=0;cycle<4096;cycle++)
        {
            foreach(var (seat,q) in targets.OrderBy(x=>x.Key))
            {
                double p=Marginal(seat);
                if((p==0&&q>0)||(p==1&&q<1))
                    return new(false,"ready_mask_support_missing",mass,cycle,double.PositiveInfinity);
                for(int mask=0;mask<16;mask++)
                    mass[mask]*=(mask&(1<<seat))!=0?(p>0?q/p:0):(p<1?(1-q)/(1-p):0);
                double total=mass.Sum();
                if(!(total>0)||!double.IsFinite(total))
                    return new(false,"joint_ready_marginals_infeasible",mass,cycle,double.PositiveInfinity);
                for(int mask=0;mask<16;mask++)mass[mask]/=total;
            }
            double error=targets.Count==0?0:targets.Max(t=>Math.Abs(Marginal(t.Key)-t.Value));
            if(error<=1e-8)return new(true,"joint_ready_projection_converged",mass,cycle+1,error);
        }
        return new(false,"joint_ready_marginals_infeasible_or_not_converged",mass,4096,
            targets.Max(t=>Math.Abs(Marginal(t.Key)-t.Value)));
    }

    public SichuanJointReadinessReport Analyze(SichuanStateView source,int samples=4096,int seed=20261130)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        samples=Math.Clamp(samples,256,16384);
        SichuanJointReadinessReport No(string why)=>new(false,why,0,0,0,double.PositiveInfinity,
            new double[4],new double[4],new double[4],new double[16],new double[16],0,0,0);
        bool reaction=source.Phase==6;
        if(!SichuanPublicInferenceBoundary.TryProject(source,out var s,out var reason,
            reaction:reaction,sourceSeat:reaction?source.CurrentSeat:-1,waiting:!reaction&&source.Hand18.Sum()%3==1))
            return No("public_projection_"+reason);
        // Only reconstruct observable status. Runtime private ready flags,
        // hidden draw identities and pass alternatives are not predictors.
        s.PolicyVariant=source.PolicyVariant;
        for(int seat=0;seat<4;seat++)s.IsCalled[seat]=s.MeldCount(seat)>0;
        var belief=new SichuanBeliefEngine().Build(s);
        var targets=belief.SeatReadyPosterior.Where(x=>x.Key!=s.SeatIndex&&s.ActiveSeats[x.Key]&&!s.HasHu[x.Key])
            .ToDictionary(x=>x.Key,x=>x.Value);
        var sampler=new SichuanHiddenHandInferenceEngine();
        var particles=sampler.SamplePublicResearchParticles(s,samples,seed,SichuanHiddenHandProposal.PublicReadyMixture,targets);
        if(particles.Count!=samples)return No("joint_proposal_attempt_budget_exhausted");
        if(particles.Any(p=>!SichuanPublicInferenceBoundary.ParticleConserves(s,p)))
            return No("particle_conservation_failed");
        var masks=new int[samples];var prior=new double[16];var shanten=new SichuanShantenEngine();
        var exact=new SichuanExactHandAnalyzer();
        for(int i=0;i<samples;i++)
        {
            foreach(int seat in targets.Keys)
            {
                var hand=particles[i].Hands27[seat];int dq=s.DingQueSuits[seat],mc=s.MeldCount(seat);
                if(hand.Sum()!=13-3*mc)return No("concealed_not_at_waiting_boundary");
                if(dq is <0 or >2||hand.Skip(dq*9).Take(9).Any(n=>n>0)
                    ||shanten.CalcBestShanten(hand,mc,mc==0)!=0)continue;
                var remaining=Enumerable.Range(0,27).Select(t=>t/9==dq?0:Math.Max(0,4-hand[t]-s.Melds18[seat].Count(x=>x==t))).ToArray();
                if(exact.EnumerateWaits(hand,remaining,mc,mc==0).Count>0)masks[i]|=1<<seat;
            }
            prior[masks[i]]+=particles[i].Weight;
        }
        double total=prior.Sum();if(!(total>0))return No("zero_particle_mass");
        for(int i=0;i<16;i++)prior[i]/=total;
        var fit=FitMasks(prior,targets);
        double[] Marginals(IReadOnlyList<double> m)=>Enumerable.Range(0,4).Select(s=>
            Enumerable.Range(0,16).Where(k=>(k&(1<<s))!=0).Sum(k=>m[k])).ToArray();
        var priorReady=Marginals(prior);
        var updated=fit.Supported?particles.Select((p,i)=>p with{Weight=p.Weight==0?0:p.Weight/total*fit.Mass[masks[i]]/prior[masks[i]]}).ToArray():[];
        double before=1/particles.Sum(p=>Math.Pow(p.Weight/total,2));
        double ess=updated.Length>0?1/updated.Sum(p=>p.Weight*p.Weight):0;
        bool supported=fit.Supported&&ess>=Math.Max(16,samples/32.0);
        double entropy=0;
        // KL is measured over original weighted hypotheses, not resampled
        // copies. Repeating a hypothesis cannot manufacture effective mass.
        if(fit.Supported)entropy=Enumerable.Range(0,16).Where(i=>fit.Mass[i]>0)
            .Sum(i=>fit.Mass[i]*Math.Log(fit.Mass[i]/prior[i]));
        var target=new double[4];foreach(var t in targets)target[t.Key]=t.Value;
        var oldWall=new double[27];var newWall=new double[27];var oldPresence=new double[27];var newPresence=new double[27];
        for(int i=0;i<samples;i++)for(int tile=0;tile<27;tile++)
        {
            int copies=particles[i].Wall27[tile];double a=particles[i].Weight/total,b=updated.Length>0?updated[i].Weight:0;
            oldWall[tile]+=a*copies;newWall[tile]+=b*copies;
            if(copies>0){oldPresence[tile]+=a;newPresence[tile]+=b;}
        }
        return new(supported,!fit.Supported?fit.Status:supported?"joint_ready_projection_supported":"joint_ready_effective_samples_insufficient",
            samples,before,ess,fit.Error,target,priorReady,fit.Mass.Length==16?Marginals(fit.Mass):new double[4],
            prior,fit.Mass,updated.Length>0?updated.Max(p=>p.Weight):0,entropy,fit.Iterations)
            {Particles=supported?updated:[],PriorWallCopies=oldWall,WallCopies=newWall,
                PriorWallPresence=oldPresence,WallPresence=newPresence};
    }
}
