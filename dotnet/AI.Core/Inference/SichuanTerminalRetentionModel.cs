using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanTerminalRetentionReport(bool Supported,string Status,int Samples,double EffectiveSamples,
    double[] ExpectedWall,double[] RonLoss,IReadOnlyList<SichuanHiddenHandParticle> Particles)
{
    public double[][] DrawRonProbability {get;init;}=[];
    public double[][] DrawRonCost {get;init;}=[];
    public double[][] DrawSelfCost {get;init;}=[];
    public double[][] CurrentRonProbability {get;init;}=[];
    public IReadOnlyList<SichuanReadyRaceOpponent> Rivals(SichuanStateView s,IReadOnlyList<SichuanReadyRaceGroup> groups,int discard)
    {
        var order=new List<int>{s.SeatIndex};for(int d=1;d<4;d++){int seat=(s.SeatIndex-d+4)%4;if(s.ActiveSeats[seat]&&!s.HasHu[seat])order.Add(seat);}
        var target=groups.SelectMany(g=>g.TileTypes??[]).ToHashSet();
        var miss=Enumerable.Range(0,27).Where(t=>!target.Contains(t)).ToArray();
        double mass=miss.Sum(t=>ExpectedWall[t])/Math.Max(1,s.WallCount);
        return order.Skip(1).Select((seat,index)=>
        {
            double p=miss.Sum(t=>DrawRonProbability[seat][t]);
            var probabilities=groups.Select(g=>
            {double z=g.ExpectedCopies/Math.Max(1,s.WallCount);return z>0?(g.TileTypes??[]).Sum(t=>DrawRonProbability[seat][t])/z:0;}).ToArray();
            var payments=groups.Select(g=>
            {double z=(g.TileTypes??[]).Sum(t=>DrawRonProbability[seat][t]);return z>0?(g.TileTypes??[]).Sum(t=>DrawSelfCost[seat][t])/z:0;}).ToArray();
            return new SichuanReadyRaceOpponent(index+1,mass>0?Math.Clamp(p/mass,0,1):0,
                mass>0?Math.Clamp(p/mass,0,1):0,p>0?miss.Sum(t=>DrawSelfCost[seat][t])/p:0,
                p>0?miss.Sum(t=>DrawRonCost[seat][t])/p:0,0,
                FirstDiscardRonProbability:CurrentRonProbability[seat][discard],FirstDiscardPayment:0)
                {GroupSelfDrawProbability=probabilities,GroupSelfDrawPayment=payments};
        }).ToArray();
    }
}

/// <summary>Short concealed-hand public allocation. The calibrated readiness
/// prior is a likelihood, not a certainty. Exact legal ready patterns form a
/// proposal; importance correction preserves the joint physical prior and
/// each seat's likelihood. No actual concealed cards or wall are accepted.</summary>
public sealed class SichuanTerminalRetentionModel
{
    private sealed record Range(int Seat,int Size,int Missing,bool Cleared,int[] Exposed,int Melds,
        int[][] Patterns,HashSet<string> ReadyKeys,double PriorReady,double ReadyLikelihood,double OtherLikelihood);
    private readonly SichuanExactHandAnalyzer _hands=new();
    private static string Key(IEnumerable<int> h)=>string.Concat(h.Select(n=>(char)('0'+n)));
    private static double Choose(int n,int k)
    {if(k<0||k>n)return 0;double a=1;for(int j=1;j<=Math.Min(k,n-k);j++)a*=(n-j+1)/(double)j;return a;}
    private static double PatternWeight(int[] pool,int[] h)
    {double w=1;for(int t=0;t<27;t++){if(h[t]>pool[t])return 0;w*=Choose(pool[t],h[t]);}return w;}

    public SichuanTerminalRetentionReport Evaluate(SichuanStateView source,SichuanBeliefSnapshot belief,
        int samples=256,int seed=20261030)
        =>SichuanPolicyExecutionScope.Memoize("terminal-retention",(SichuanDecisionCommand.Fingerprint(source),samples,seed,
            string.Join(',',Enumerable.Range(0,4).Select(s=>belief.SeatReadyPosterior.GetValueOrDefault(s).ToString("R",System.Globalization.CultureInfo.InvariantCulture)))),
            ()=>Compute(source,belief,samples,seed));

    private SichuanTerminalRetentionReport Compute(SichuanStateView source,SichuanBeliefSnapshot belief,int samples,int seed)
    {
        SichuanTerminalRetentionReport No(string why)=>new(false,why,0,0,new double[27],new double[27],[]);
        if(source.InformationMode!="public"||source.WallCount is <1 or >24||source.HasHu.Any(x=>x)
            ||Enumerable.Range(0,4).Any(s=>s!=source.SeatIndex&&(!source.ActiveSeats[s]||source.HandCounts[s] is <1 or >7)))return No("outside_short_concealed_hands");
        if(!SichuanPublicInferenceBoundary.TryProject(source,out var s,out var reason))return No(reason);
        if(samples is <32 or >4096)throw new ArgumentOutOfRangeException(nameof(samples));
        var pool=s.Remaining18;var ranges=new List<Range>();
        foreach(int seat in Enumerable.Range(0,4).Where(x=>x!=s.SeatIndex).OrderBy(x=>s.HandCounts[x]))
        {
            int size=s.HandCounts[seat],dq=s.DingQueSuits[seat];
            if(dq is <0 or >2||size!=13-3*s.MeldCount(seat))return No("concealed_size_not_at_waiting_boundary");
            var ex=new int[27];foreach(var t in s.Melds18[seat])ex[t]++;
            bool cleared=SichuanOpponentTimeline.MustHaveClearedMissing(s,seat);
            var patterns=ReadyPatterns(pool,ex,dq,s.MeldCount(seat));
            double z=patterns.Sum(h=>PatternWeight(pool,h));
            int eligible=pool.Where((n,t)=>!cleared||t/9!=dq).Sum();
            double prior=z/Choose(eligible,size);double q=Math.Clamp(belief.SeatReadyPosterior.GetValueOrDefault(seat),0,1);
            if(prior<=1e-14)q=0;if(prior>=1-1e-14)q=1;
            ranges.Add(new(seat,size,dq,cleared,ex,s.MeldCount(seat),patterns,
                patterns.Select(h=>Key(h)).ToHashSet(),prior,prior>0?q/prior:0,prior<1?(1-q)/(1-prior):0));
        }
        var random=new Random(seed);var particles=new List<SichuanHiddenHandParticle>();
        var distribution=new Dictionary<(int Seat,string Pool),(double[] Weights,double Z,double Prior,int Eligible)>();
        for(int i=0;i<samples;i++)
        {
            var remaining=pool.ToArray();var hidden=Enumerable.Range(0,4).Select(_=>new int[27]).ToArray();double importance=1;
            foreach(var r in ranges)
            {
                var key=(r.Seat,Key(remaining));
                if(!distribution.TryGetValue(key,out var d))
                {
                    var ws=r.Patterns.Select(h=>PatternWeight(remaining,h)).ToArray();double z=ws.Sum();
                    int eligible=remaining.Where((n,t)=>!r.Cleared||t/9!=r.Missing).Sum();
                    double denominator=Choose(eligible,r.Size);
                    if(denominator<=0)return No("no_legal_seat_allocation");
                    d=(ws,z,Math.Clamp(z/denominator,0,1),eligible);distribution[key]=d;
                }
                double q=Math.Clamp(r.PriorReady*r.ReadyLikelihood,0,1);
                double proposal=d.Prior<=1e-14?0:d.Prior>=1-1e-14?1:q;
                bool ready=random.NextDouble()<proposal;int[] hand;
                if(ready)
                {
                    double roll=random.NextDouble()*d.Z;int selected=-1;
                    for(int j=0;j<d.Weights.Length;j++){roll-=d.Weights[j];if(roll<0){selected=j;break;}}
                    if(selected<0)return No("ready_proposal_numerical_zero");
                    hand=r.Patterns[selected].ToArray();
                    importance*=d.Prior/proposal*r.ReadyLikelihood;
                }
                else
                {
                    hand=[];
                    for(int attempt=0;attempt<256;attempt++)
                    {
                        var trial=new int[27];var available=remaining.ToArray();
                        for(int k=0;k<r.Size;k++)
                        {
                            int total=available.Where((n,t)=>!r.Cleared||t/9!=r.Missing).Sum();
                            int roll=random.Next(total);
                            for(int t=0;t<27;t++)if(!r.Cleared||t/9!=r.Missing)
                            {roll-=available[t];if(roll<0){trial[t]++;available[t]--;break;}}
                        }
                        if(!r.ReadyKeys.Contains(Key(trial))){hand=trial;break;}
                    }
                    if(hand.Length==0)return No("nonready_rejection_budget_exhausted");
                    importance*=(1-d.Prior)/(1-proposal)*r.OtherLikelihood;
                }
                // The hard cleared-suit exclusion also changes proposal mass.
                importance*=Choose(d.Eligible,r.Size)/Choose(remaining.Sum(),r.Size);
                for(int t=0;t<27;t++)remaining[t]-=hand[t];hidden[r.Seat]=hand;
            }
            particles.Add(new(hidden,remaining,importance));
        }
        double mass=particles.Sum(p=>p.Weight);if(!(mass>0))return No("zero_joint_importance_mass");
        particles=particles.Select(p=>p with{Weight=p.Weight/mass}).ToList();
        if(particles.Any(p=>!SichuanPublicInferenceBoundary.ParticleConserves(s,p)))return No("particle_conservation_failed");
        double ess=1/particles.Sum(p=>p.Weight*p.Weight);
        if(ess<Math.Max(8,samples/8.0))return No("joint_importance_effective_samples_insufficient");
        var expected=new double[27];var loss=new double[27];
        var drawProbability=Enumerable.Range(0,4).Select(_=>new double[27]).ToArray();
        var drawRon=Enumerable.Range(0,4).Select(_=>new double[27]).ToArray();
        var drawSelf=Enumerable.Range(0,4).Select(_=>new double[27]).ToArray();
        var currentRon=Enumerable.Range(0,4).Select(_=>new double[27]).ToArray();
        var priced=new Dictionary<(int Seat,string Hand),double[]>();
        foreach(var p in particles)
        {
            for(int t=0;t<27;t++)expected[t]+=p.Weight*p.Wall27[t];
            foreach(var r in ranges)
            {
                var hand=p.Hands27[r.Seat];var key=(r.Seat,Key(hand));
                if(!priced.TryGetValue(key,out var ron))
                {
                    ron=new double[27];var cap=Enumerable.Range(0,27).Select(t=>4-hand[t]-r.Exposed[t]).ToArray();
                    if(!hand.Skip(r.Missing*9).Take(9).Any(n=>n>0))
                    foreach(var w in _hands.EnumerateWaits(hand,cap,r.Melds,false))
                    {
                        var completed=hand.ToArray();completed[w.TileType]++;
                        ron[w.TileType]=new SichuanFanProjectionEngine().Project(completed,SichuanDevelopmentPolicy.Melds(s,r.Seat),SichuanWinType.Discard).HandScore;
                    }
                    priced[key]=ron;
                }
                for(int t=0;t<27;t++)if(ron[t]>0)
                {
                    double chance=p.Weight*p.Wall27[t]/s.WallCount;
                    drawProbability[r.Seat][t]+=chance;drawRon[r.Seat][t]+=chance*ron[t];
                    drawSelf[r.Seat][t]+=chance*(ron[t]+SichuanRuleSnapshot.Frozen.SelfDrawBottomBonus);
                    if(SichuanPublicDiscardSafety.MayRon(s,r.Seat,t)){loss[t]+=p.Weight*ron[t];currentRon[r.Seat][t]+=p.Weight;}
                }
            }
        }
        return new(true,"public_short_hand_readiness_conditioned_importance_model",samples,ess,expected,loss,particles)
            {DrawRonProbability=drawProbability,DrawRonCost=drawRon,DrawSelfCost=drawSelf,CurrentRonProbability=currentRon};
    }

    private static int[][] ReadyPatterns(int[] pool,int[] ex,int missing,int melds)
    {
        var legal=Enumerable.Range(0,27).Where(t=>t/9!=missing).ToArray();var h=new int[27];var found=new Dictionary<string,int[]>();
        bool Add(int t){h[t]++;if(h[t]+ex[t]>4||Enumerable.Range(0,27).Sum(k=>Math.Max(0,h[k]-pool[k]))>1){h[t]--;return false;}return true;}
        var sets=legal.Select(t=>new[]{t,t,t}).Concat(legal.Where(t=>t%9<=6).Select(t=>new[]{t,t+1,t+2})).ToArray();
        void Visit(int start,int left)
        {
            if(left==0)
            {
                foreach(int t in legal.Where(t=>h[t]>0))
                {h[t]--;if(Enumerable.Range(0,27).All(k=>h[k]<=pool[k]))found.TryAdd(Key(h),h.ToArray());h[t]++;}return;
            }
            for(int j=start;j<sets.Length;j++)
            {int added=0;foreach(int t in sets[j]){if(!Add(t))break;added++;}if(added==3)Visit(j,left-1);for(int k=0;k<added;k++)h[sets[j][k]]--;}
        }
        foreach(int pair in legal)
        {if(!Add(pair))continue;if(Add(pair)){Visit(0,4-melds);h[pair]--;}h[pair]--;}
        return found.Values.ToArray();
    }
}
