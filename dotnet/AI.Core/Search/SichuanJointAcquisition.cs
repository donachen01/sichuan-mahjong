namespace SichuanMahjong.AI.Core.Search;

/// <summary>Exact multivariate hypergeometric requirement event in an
/// exchangeable physical urn. Different required ranks compete for the same
/// draw slots. Used only to nominate plans, never as calibrated whole-game EV.</summary>
public static class SichuanJointAcquisition
{
    public static double AtLeast(IReadOnlyList<int> supply,IReadOnlyList<int> required,int draws)
    {
        if(supply.Count!=required.Count||supply.Any(n=>n<0)||required.Any(n=>n<0)||draws<0)
            throw new ArgumentException("invalid acquisition urn");
        int total=supply.Sum();draws=Math.Min(draws,total);
        if(required.Where((n,i)=>n>supply[i]).Any()||required.Sum()>draws)return 0;
        double Choose(int n,int k){if(k<0||k>n)return 0;double a=1;for(int j=1;j<=Math.Min(k,n-k);j++)a*= (n-j+1)/(double)j;return a;}
        var active=Enumerable.Range(0,supply.Count).Where(i=>required[i]>0).ToArray();
        int other=total-active.Sum(i=>supply[i]);double sum=0;
        void Visit(int index,int used,double ways)
        {
            if(index==active.Length){sum+=ways*Choose(other,draws-used);return;}
            int t=active[index];for(int k=required[t];k<=Math.Min(supply[t],draws-used);k++)Visit(index+1,used+k,ways*Choose(supply[t],k));
        }
        Visit(0,0,1);return total==0?1:Math.Clamp(sum/Choose(total,draws),0,1);
    }
}
