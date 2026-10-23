using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanFlushSkeleton(int TwiceBlocks, int PairBlocks, int CompleteMelds,
    int WeakestCompletionCopies)
{
    public double Blocks => TwiceBlocks/2.0;
    public string Meaning => "disjoint_publicly_supported_blocks_not_completion_probability";
}

/// <summary>Non-overlapping source 6.3 blocks. A two-tile block with only one
/// possible completion is not promoted to a full efficient block. The pair
/// used as head is independent from the other sets; no tile is used twice.</summary>
public static class SichuanFlushSkeletonEngine
{
    public static SichuanFlushSkeleton Analyze(SichuanStateView s,int suit)
    {
        var melds=SichuanFlushCopyCapacity.OwnMeldCopies(s);
        if(suit is <0 or >2||suit==s.OwnDingQueSuit||melds.Any(m=>m.Tile/9!=suit))return new(0,0,0,0);
        var a=s.Hand18.Skip(suit*9).Take(9).ToArray();var supply=s.Remaining18.Skip(suit*9).Take(9).ToArray();
        var best=new SichuanFlushSkeleton(0,0,0,0);
        void Walk(int groups,int pairs,int complete,int singles,int weakest,int deadPairs)
        {
            int k=System.Array.FindIndex(a,n=>n>0);
            if(k<0)
            {
                if(deadPairs>1)return;
                int blocks=Math.Min(10,2*(groups+melds.Length)+(singles>0?1:0));
                if(pairs==0&&singles==0)blocks=Math.Max(0,blocks-1);
                var p=new SichuanFlushSkeleton(blocks,pairs,complete+melds.Length,weakest==int.MaxValue?0:weakest);
                if(p.TwiceBlocks>best.TwiceBlocks||p.TwiceBlocks==best.TwiceBlocks
                    &&(p.PairBlocks>best.PairBlocks||p.PairBlocks==best.PairBlocks&&p.WeakestCompletionCopies>best.WeakestCompletionCopies))best=p;
                return;
            }
            if(groups+melds.Length<5)
            {
                if(a[k]>=3){a[k]-=3;Walk(groups+1,pairs,complete+1,singles,weakest,deadPairs);a[k]+=3;}
                if(k<=6&&a[k+1]>0&&a[k+2]>0)
                {a[k]--;a[k+1]--;a[k+2]--;Walk(groups+1,pairs,complete+1,singles,weakest,deadPairs);a[k]++;a[k+1]++;a[k+2]++;}
                if(a[k]>=2)
                {a[k]-=2;Walk(groups+1,pairs+1,complete,singles,Math.Min(weakest,supply[k]),deadPairs+(supply[k]==0?1:0));a[k]+=2;}
                for(int delta=1;delta<=2;delta++)if(k+delta<=8&&a[k+delta]>0)
                {
                    int copies=delta==2?supply[k+1]:(k>0?supply[k-1]:0)+(k+2<9?supply[k+2]:0);
                    if(copies<2)continue;
                    a[k]--;a[k+delta]--;Walk(groups+1,pairs,complete,singles,Math.Min(weakest,copies),deadPairs);a[k]++;a[k+delta]++;
                }
            }
            a[k]--;Walk(groups,pairs,complete,singles+(supply[k]>0?1:0),weakest,deadPairs);a[k]++;
        }
        Walk(0,0,0,0,int.MaxValue,0);return best;
    }
}
