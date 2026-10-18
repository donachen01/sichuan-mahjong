using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Domain;

internal static class PublicSamplingOrderSmoke
{
    private sealed class Ticket(int ticket):Random{public override int Next(int maxValue)=>ticket<maxValue?ticket:throw new Exception("ticket outside population");}
    public static int Run()
    {
        try
        {
            void Check(bool ok,string why){if(!ok)throw new Exception(why);}
            int checks=0;
            var h=new[]{0,1,1,0,2,3,1,1,0,1,2,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0};
            var permutations=new[]{new[]{0,1,2},new[]{0,2,1},new[]{1,0,2},new[]{1,2,0},new[]{2,0,1},new[]{2,1,0}};
            var baseState=SichuanStateCodec.FromRaw(0,0,0,55,h,new int[27],dingQueSuits:[2,0,1,2],handCounts:[14,13,13,13]);
            var engine=new SichuanHiddenHandInferenceEngine();
            var baseline=engine.SampleParticles(baseState,32,20261012,SichuanHiddenHandProposal.PublicPriorThenLikelihood);
            Check(baseline.Count==32,"no baseline particles");
            foreach(var p in permutations)
            {
                int Map(int t)=>p[t/9]*9+t%9;
                var hand=new int[27];for(int t=0;t<27;t++)hand[Map(t)]=h[t];
                var state=SichuanStateCodec.FromRaw(0,0,0,55,hand,new int[27],dingQueSuits:new[]{2,0,1,2}.Select(s=>p[s]).ToArray(),handCounts:[14,13,13,13]);
                var order=SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(state);
                foreach(var forbidden in new[]{-1,0,1,2})
                {
                    var pool=state.Remaining18;var counts=new int[27];var total=Enumerable.Range(0,27).Where(t=>t/9!=forbidden).Sum(t=>pool[t]);
                    for(int ticket=0;ticket<total;ticket++)counts[SichuanHiddenHandInferenceEngine.PriorDraw(pool,new Ticket(ticket),forbidden,order)]++;
                    for(int t=0;t<27;t++)Check(counts[t]==(t/9==forbidden?0:pool[t]),"canonical ordering changed exact copy-proportional prior");
                    checks++;
                }
                var result=engine.SampleParticles(state,32,20261012,SichuanHiddenHandProposal.PublicPriorThenLikelihood);
                Check(result.Count==baseline.Count,"particle count changed");
                for(int i=0;i<baseline.Count;i++)
                {
                    Check(Math.Abs(result[i].Weight-baseline[i].Weight)<1e-10,"likelihood changed under public suit permutation");
                    for(int t=0;t<27;t++)
                    {Check(result[i].Wall27[Map(t)]==baseline[i].Wall27[t],"sampled wall is not transferred");for(int seat=0;seat<4;seat++)Check(result[i].Hands27[seat][Map(t)]==baseline[i].Hands27[seat][t],"sampled concealed allocation is not transferred");}
                    Check(result[i].Wall27.Sum()==55 && Enumerable.Range(0,27).All(t=>result[i].Wall27[t]+result[i].Hands27.Sum(a=>a[t])==state.Remaining18[t]),"sample lost physical mass");checks++;
                }
                state.IsReady[1]=true;state.PassedHu18[2][3]=7;state.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Draw,Map(26)));
                Check(order.SequenceEqual(SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(state)),"public coupling used private opponent input");checks++;
            }
            Console.WriteLine($"PUBLIC_SAMPLING_ORDER PASS checks={checks}; exact prior marginal, six full suit permutations, identical physical particles/weights, public-only ordering; tied suit orbits not exact symmetry claim");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
