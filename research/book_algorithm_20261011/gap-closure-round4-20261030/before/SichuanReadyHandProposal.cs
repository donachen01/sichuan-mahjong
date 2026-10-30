using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Inference;

/// <summary>A ready-hand proposal, NOT a posterior. Ordered construction paths
/// are marginalized exactly, including alternative decompositions and winning
/// tiles. Failed constructions are rejected at the WHOLE joint-sample level;
/// retrying only this seat would require an unknown acceptance correction.</summary>
internal static class SichuanReadyHandProposal
{
    private static readonly int[][][] Pairs=Enumerable.Range(0,3).Select(dq=>Enumerable.Range(0,27)
        .Where(t=>t/9!=dq).Select(t=>new[]{t,t}).ToArray()).ToArray();
    private static readonly int[][][] Sets=Enumerable.Range(0,3).Select(dq=>Enumerable.Range(0,27)
        .Where(t=>t/9!=dq).Select(t=>new[]{t,t,t}).Concat(Enumerable.Range(0,27)
            .Where(t=>t/9!=dq&&t%9<=6).Select(t=>new[]{t,t+1,t+2})).ToArray()).ToArray();
    private static string Key(int[] h)=>string.Concat(h.Select(n=>(char)('0'+n)));
    private static void Add(int[] h,int[] group,int sign){foreach(int t in group)h[t]+=sign;}
    private static int[][] Options(int[] h,int[] pool,int[] exposed,int[][] groups)
    {
        int overflow=Enumerable.Range(0,27).Sum(t=>Math.Max(0,h[t]-pool[t]));
        bool Allowed(int[] g)
        {
            int extra=0;
            if(g[0]==g[^1])
            {
                int t=g[0],n=g.Length;if(h[t]+n+exposed[t]>4)return false;
                extra=Math.Max(0,h[t]+n-pool[t])-Math.Max(0,h[t]-pool[t]);
            }
            else foreach(int t in g)
            {
                if(h[t]+1+exposed[t]>4)return false;
                extra+=Math.Max(0,h[t]+1-pool[t])-Math.Max(0,h[t]-pool[t]);
            }
            return overflow+extra<=1;
        }
        return groups.Where(Allowed).ToArray();
    }
    private static bool Fits(int[] h,int[] g,int[] target)
        =>g[0]==g[^1]?h[g[0]]+g.Length<=target[g[0]]:g.All(t=>h[t]+1<=target[t]);
    private static double Weight(int[] h,int[] pool,int[] g,double[]? logs)
    {
        double w=1,log=0;
        if(g[0]==g[^1])
        {
            int t=g[0],n=pool[t]+1-h[t];
            for(int j=1;j<=g.Length;j++)w*=(n-j+1)/(double)j;
            log=g.Length*(logs?[t]??0);
        }
        else foreach(int t in g){w*=pool[t]+1-h[t];log+=logs?[t]??0;}
        return w*Math.Exp(Math.Clamp(log,-80,80));
    }
    private static int RemovalMass(int[] complete,int[] pool)
    {
        int over=Enumerable.Range(0,27).FirstOrDefault(t=>complete[t]>pool[t],-1);
        return over>=0?complete[over]:complete.Sum();
    }
    private static bool CanRemove(int[] complete,int[] pool,int tile)
        =>complete[tile]>0&&Enumerable.Range(0,27).All(t=>complete[t]-(t==tile?1:0)<=pool[t]);

    internal static int[]? Draw(int[] pool,int[] exposed,int missing,int melds,Random random,double[]? logs=null)
    {
        if(missing is <0 or >2||exposed.Skip(missing*9).Take(9).Any(n=>n>0))return null;
        bool seven=melds==0&&random.NextDouble()<.1;
        var h=new int[27];int steps=seven?7:5-melds;
        for(int step=0;step<steps;step++)
        {
            var choices=Options(h,pool,exposed,seven||step==0?Pairs[missing]:Sets[missing]);
            if(choices.Length==0)return null;
            var weights=choices.Select(g=>Weight(h,pool,g,logs)).ToArray();
            double groupRoll=random.NextDouble()*weights.Sum();int chosen=weights.Length-1;
            for(int j=0;j<weights.Length;j++){groupRoll-=weights[j];if(groupRoll<0){chosen=j;break;}}
            Add(h,choices[chosen],1);
        }
        int total=RemovalMass(h,pool),roll=random.Next(total);
        for(int tile=0;tile<27;tile++)if(CanRemove(h,pool,tile))
        {roll-=h[tile];if(roll<0){h[tile]--;return h;}}
        throw new InvalidOperationException("ready_proposal_removal_support_failed");
    }

    internal static double Density(int[] pool,int[] exposed,int missing,int melds,int[] hand,double[]? logs=null)
    {
        if(pool.Length!=27||exposed.Length!=27||hand.Length!=27||missing is <0 or >2||melds is <0 or >4)
            throw new ArgumentException("ready_proposal_requires_27_counts_and_legal_seat");
        if(hand.Sum()!=13-3*melds||hand.Skip(missing*9).Take(9).Any(n=>n>0)
            ||exposed.Skip(missing*9).Take(9).Any(n=>n>0)
            ||Enumerable.Range(0,27).Any(t=>hand[t]<0||hand[t]>pool[t]||hand[t]+exposed[t]>4))return 0;
        // Exact zero pruning only. The forward proposal cannot produce an
        // unready hand, nor complete at a tile outside its legal waits.
        if(new SichuanShantenEngine().CalcBestShanten(hand,melds,melds==0)!=0)return 0;
        var cap=Enumerable.Range(0,27).Select(t=>t/9==missing?0:4-hand[t]-exposed[t]).ToArray();
        var wins=new SichuanExactHandAnalyzer().EnumerateWaits(hand,cap,melds,melds==0).Select(w=>w.TileType).ToArray();
        double probability=0;
        var empty=new int[27];var firstPairs=Options(empty,pool,exposed,Pairs[missing]);
        if(firstPairs.Length==0)return 0;
        var pairWeights=firstPairs.Select(g=>Weight(empty,pool,g,logs)).ToArray();double pairTotal=pairWeights.Sum();
        foreach(int win in wins)
        {
            var target=hand.ToArray();target[win]++;var h=new int[27];
            var memo=new Dictionary<(string,int,bool),double>();
            double Complete(int left,bool pairs)
            {
                if(left==0)return h.SequenceEqual(target)?1:0;
                var key=(Key(h),left,pairs);if(memo.TryGetValue(key,out double known))return known;
                var options=Options(h,pool,exposed,pairs?Pairs[missing]:Sets[missing]);
                if(options.Length==0)return memo[key]=0;
                var weights=options.Select(g=>Weight(h,pool,g,logs)).ToArray();
                double sum=0;
                for(int j=0;j<options.Length;j++)if(Fits(h,options[j],target))
                {Add(h,options[j],1);sum+=weights[j]*Complete(left-1,pairs);Add(h,options[j],-1);}
                return memo[key]=sum/weights.Sum();
            }
            double ordinary=0;
            for(int j=0;j<firstPairs.Length;j++)if(Fits(h,firstPairs[j],target))
            {Add(h,firstPairs[j],1);ordinary+=pairWeights[j]*Complete(4-melds,false);Add(h,firstPairs[j],-1);}
            ordinary/=pairTotal;
            double seven=melds==0&&target.All(n=>n%2==0)?Complete(7,true):0;
            double construction=melds==0?.9*ordinary+.1*seven:ordinary;
            probability+=construction*target[win]/RemovalMass(target,pool);
        }
        return probability;
    }

    internal static double LogPhysicalMass(int[] pool,int[] hand,int forbidden=-1,uint excluded=0)
    {
        double ChooseLog(int n,int k)
        {if(k<0||k>n)return double.NegativeInfinity;double log=0;for(int j=1;j<=Math.Min(k,n-k);j++)log+=Math.Log((n-j+1)/(double)j);return log;}
        if(Enumerable.Range(0,27).Any(t=>hand[t]<0||hand[t]>pool[t]||hand[t]>0&&(t/9==forbidden||(excluded&(1u<<t))!=0)))
            return double.NegativeInfinity;
        int total=Enumerable.Range(0,27).Where(t=>t/9!=forbidden&&(excluded&(1u<<t))==0).Sum(t=>pool[t]);
        return Enumerable.Range(0,27).Sum(t=>ChooseLog(pool[t],hand[t]))-ChooseLog(total,hand.Sum());
    }
}
