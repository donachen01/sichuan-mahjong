using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Entry;

internal static class PublicKnownWallSmoke
{
    public static int Run()
    {
        try
        {
            void Check(bool ok,string why){if(!ok)throw new Exception(why);}
            var results=new List<string>();
            foreach(var rotation in Enumerable.Range(0,3))
            {
                var state=Fixture(rotation);var wall=new SichuanWallAvailabilityEngine().Build(state,new SichuanBeliefEngine().Build(state));
                double target=wall.ExpectedCounts18.Skip(rotation*9).Take(9).Sum();
                Console.WriteLine($"known target suit rotation={rotation} expected={target:R} exact=3");
                Check(Math.Abs(target-3)<1e-8,"public cleared-missing constraints did not keep guaranteed unseen tiles in wall");
                foreach(var tile in Enumerable.Range(rotation*9,9))Check(Math.Abs(wall.ExpectedCounts18[tile]-state.Remaining18[tile])<1e-8,"known wall copy count was diluted");
                var decision=new SichuanAiFacade().DecideDiscard(state);
                Check(decision.Reasons.Contains("PUBLIC_WALL_KNOWN_COPIES"),"exact public supply did not reach actual discard evaluation");
                var mixed=Fixture(rotation,true);var mixedBelief=new SichuanBeliefEngine().Build(mixed);
                var mixedWall=new SichuanWallAvailabilityEngine().Build(mixed,mixedBelief);
                Check(Math.Abs(mixedWall.ExpectedCounts18.Skip(rotation*9).Take(9).Sum()-3)<1e-8 && Math.Abs(mixedWall.ExpectedCounts18.Sum()-5)<1e-8,"mixed wall lost known quota or residual mass");
                for(int seed=0;seed<64;seed++)
                {
                    var sample=new SichuanWallAvailabilityEngine().SampleWallOrder(mixed,mixedBelief,seed);
                    Check(sample.Length==5,"sampled wall truncated");
                    foreach(var tile in Enumerable.Range(rotation*9,9))Check(sample.Count(t=>t==tile)==mixed.Remaining18[tile],"finite sampled wall omitted known copies");
                    foreach(var tile in Enumerable.Range(0,27))Check(sample.Count(t=>t==tile)<=mixed.Remaining18[tile],"sampled fifth copy");
                }
                // Remove only one opponent's public clearing proof; preserve
                // visible counts by reassigning those historical discards.
                foreach(var tile in state.Discards18[1].Where(t=>t/9!=rotation).ToArray()){state.Discards18[1].Remove(tile);state.Discards18[0].Add(tile);}
                state.PublicEvents.Clear();long index=0;for(int seat=0;seat<4;seat++)foreach(var t in state.Discards18[seat])state.PublicEvents.Add(new(++index,(int)index,seat,SichuanPublicEventType.Discard,t));
                var unproven=new SichuanWallAvailabilityEngine().Build(state,new SichuanBeliefEngine().Build(state));
                Check(unproven.ExpectedCounts18.Skip(rotation*9).Take(9).Sum()<3-1e-8,"unknown missing-suit holdings were treated as cleared");
                Check(Math.Abs(unproven.ExpectedCounts18.Sum()-3)<1e-8,"ablation lost wall mass");
            }
            Console.WriteLine("PUBLIC_KNOWN_WALL PASS: three suit transfers, exact public exclusion, evidence ablation; synthetic conserved components, no strength claim");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
    internal static SichuanStateView Fixture(int rotation,bool mixed=false)
    {
        int Map(int t)=>(t+rotation*9)%27;
        var hand=new int[27];foreach(var t in new[]{0,0,0,2,2,2,3,4,5,5,6,7,15,15})hand[Map(t)]++;
        var pool=Enumerable.Repeat(4,27).ToArray();for(int t=0;t<27;t++)pool[t]-=hand[t];var wallTiles=(mixed?new[]{0,2,7,10,19}:new[]{0,2,7}).Select(Map).ToArray();foreach(var t in wallTiles)pool[t]--;
        var hidden=Enumerable.Range(0,4).Select(_=>new int[27]).ToArray();for(int seat=1;seat<4;seat++)for(int n=0;n<13;n++)
        {int t=Enumerable.Range(0,27).Where(t=>pool[t]>0 && t/9!=rotation).OrderBy(t=>(t-rotation*9+27)%27).First();pool[t]--;hidden[seat][t]++;}
        var state=SichuanStateCodec.FromRaw(0,0,0,wallTiles.Length,hand,pool,dingQueSuits:[(rotation+2)%3,rotation,rotation,rotation],handCounts:[14,13,13,13]);
        int discardIndex=0;for(int original=0;original<27;original++){int t=Map(original);for(int n=0;n<pool[t];n++)
        {int seat=(4-discardIndex%4)%4;state.Discards18[seat].Add(t);state.PublicEvents.Add(new(++discardIndex,discardIndex,seat,SichuanPublicEventType.Discard,t));}}
        for(int t=0;t<27;t++)if(hand[t]+hidden.Sum(a=>a[t])+pool[t]+wallTiles.Count(x=>x==t)!=4)throw new Exception("bad 108-copy fixture");
        return state;
    }
}
