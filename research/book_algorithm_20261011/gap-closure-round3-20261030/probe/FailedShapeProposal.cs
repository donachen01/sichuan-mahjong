// Archived failed experiment, retained only for its independent arithmetic evidence.
internal static class FailedShapeProposal
{
    private static double ShapeWeight(IReadOnlyList<int> hand,int tile)
    {
        double w=1+3*hand[tile];
        for(int d=1;d<=2;d++)
        {
            double a=d==1?1.5:.5;
            if(tile%9>=d)w+=a*hand[tile-d];
            if(tile%9+d<9)w+=a*hand[tile+d];
        }
        return w;
    }

    private static int ShapeDraw(int[] remaining,int[] hand,Random random,int forbidden,IReadOnlyList<int> order,uint excluded)
    {
        double total=order.Where(t=>t/9!=forbidden&&(excluded&(1u<<t))==0).Sum(t=>remaining[t]*ShapeWeight(hand,t));
        if(!(total>0))return -1;
        double roll=random.NextDouble()*total;int last=-1;
        foreach(int t in order)if(remaining[t]>0&&t/9!=forbidden&&(excluded&(1u<<t))==0)
        {last=t;roll-=remaining[t]*ShapeWeight(hand,t);if(roll<0)return t;}
        return last;
    }

    // The latent proposal regime is mixed over a WHOLE seat path, not at
    // each tile. Both path densities enter the balance denominator, even
    // when one regime generated the path. Uniform support bounds P/Q.
    internal static double ShapePathLogImportance(IReadOnlyList<int> pool,IReadOnlyList<int> path,int forbidden=-1,uint excluded=0)
    {
        var remaining=pool.ToArray();var hand=new int[pool.Count];double p=0,u=0,q=0;
        foreach(int tile in path)
        {
            if(tile<0||tile>=remaining.Length||remaining[tile]<=0||tile/9==forbidden||(excluded&(1u<<tile))!=0)
                throw new ArgumentException("shape_path_not_in_public_support");
            var allowed=Enumerable.Range(0,pool.Count).Where(t=>t/9!=forbidden&&(excluded&(1u<<t))==0).ToArray();
            int total=remaining.Sum(),legal=allowed.Sum(t=>remaining[t]);
            double z=allowed.Sum(t=>remaining[t]*ShapeWeight(hand,t));
            p+=Math.Log(remaining[tile]/(double)total);
            u+=Math.Log(remaining[tile]/(double)legal);
            q+=Math.Log(remaining[tile]*ShapeWeight(hand,tile)/z);
            hand[tile]++;remaining[tile]--;
        }
        double max=Math.Max(u,q);
        return p-(max+Math.Log(.5*Math.Exp(u-max)+.5*Math.Exp(q-max)));
    }

}
