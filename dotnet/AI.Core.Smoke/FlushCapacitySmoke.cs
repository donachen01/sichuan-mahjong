using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Rules;

internal static class FlushCapacitySmoke
{
    public static int Run()
    {
        try
        {
            int checks=0;
            void Check(bool yes,string why){checks++;if(!yes)throw new Exception(why);}
            var planner=new SichuanRoutePlanEngine();
            foreach(int seat in Enumerable.Range(0,4))
            foreach(int target in Enumerable.Range(0,3))
            foreach(bool typed in new[]{false,true})
            {
                int Map(int rank)=>target*9+rank;
                int other=(target+1)%3;
                var hand=new int[27];hand[Map(0)]=2;
                foreach(int r in new[]{1,2,8})hand[other*9+r]++;
                var visible=new int[27];for(int r=0;r<9;r++)visible[Map(r)]=4-hand[Map(r)];
                var counts=Enumerable.Repeat(13,4).ToArray();counts[seat]=5;
                var state=SichuanStateCodec.FromRaw(seat,seat,seat,30,hand,visible,roundIndex:71,dingQueSuits:Enumerable.Repeat((target+2)%3,4).ToArray(),handCounts:counts);
                state.RoundId="capacity-proof";state.Phase=5;
                foreach(int r in new[]{3,4,5})
                {
                    state.Melds18[seat].AddRange(Enumerable.Repeat(Map(r),3));
                    if(typed)state.MeldViews[seat].Add(new(SichuanMeldType.Peng,Map(r),seat,0));
                }
                Check(hand.Sum()+visible.Sum()+state.Remaining18.Sum()==108,"108 physical copies in public partition");
                Check(state.Remaining18.Sum()==69 && state.Remaining18.Skip(target*9).Take(9).Sum()==0,"all remaining physical target tiles exhausted");
                var brain=new SichuanRoundBrainSnapshot{PrimaryRoute="清一色",TargetSuit=target,Commitment=92};
                var plan=planner.Evaluate(state,brain);
                Check(!SichuanRoutePlanEngine.IsFlushRoute(plan.PrimaryRoute),$"Impossible persistent flush retained seat{seat} suit{target} typed{typed}: {plan.PrimaryRoute}");
                Check(!plan.RouteWeights.Keys.Any(SichuanRoutePlanEngine.IsFlushRoute),"impossible flush still available in route weights");
                Check(plan.Reasons.Any(r=>r.Contains("FLUSH_READY_COPY_CAPACITY")),"public impossibility reason missing");
                var hostBrain=new SichuanRoundBrainEngine();
                hostBrain.Restore(state,new AgentBrainMemory(10,2,"清一色","平胡",target,92,
                    new Dictionary<string,int>{{"清一色",100},{"平胡",80}},Array.Empty<int>(),Array.Empty<string>()));
                var repaired=hostBrain.Observe(state);
                Check(!SichuanRoutePlanEngine.IsFlushRoute(repaired.PrimaryRoute),"same-observation restore keeps impossible goal");
                Check(repaired.Reasons.Any(r=>r.Contains("FLUSH_READY_COPY_CAPACITY")),"persistent goal exit reason missing");
                Check(hostBrain.Observe(state).Revision==repaired.Revision,"unchanged corrected observation churns revision");
                var missingGoal=planner.Evaluate(state,new SichuanRoundBrainSnapshot{PrimaryRoute="清一色",TargetSuit=state.OwnDingQueSuit});
                Check(!missingGoal.RouteWeights.Keys.Any(SichuanRoutePlanEngine.IsFlushRoute),"stale missing-suit goal retained");
                Check(missingGoal.Reasons.Any(r=>r.Contains("FLUSH_TARGET_MISSING_OR_INVALID") && !r.Contains("张数上限")),"missing-suit barrier falsely described as zero physical supply");
                // Claim windows can add the offered public copy; do not use the
                // own-discard bound when choosing Hu/Peng/Gang on that tile.
                state.Phase=6;
                var reaction=planner.Evaluate(state,brain);
                Check(reaction.RouteWeights.ContainsKey("清一色"),"own-discard capacity wrongly prunes an external claim window");
            }
            foreach(int target in Enumerable.Range(0,3))
            foreach(int groups in Enumerable.Range(0,5))
            foreach(int mask in Enumerable.Range(0,1<<groups))
            foreach(int representation in new[]{0,1,2}) // flat, typed+flat, typed only
            {
                var hand=new int[27];int offset=target*9;int other=(target+1)%3;
                if(groups==4)hand[offset+8]=1;
                else
                {
                    hand[offset+8]=2;hand[offset+4]=1;hand[offset+6]=1;
                    for(int i=0;i<3-groups;i++)foreach(int r in new[]{5,6,7})hand[offset+r]++;
                }
                var ready=(int[])hand.Clone();hand[other*9+8]=1;
                var visible=new int[27];for(int r=0;r<9;r++)visible[offset+r]=4-hand[offset+r];
                visible[((target+2)%3)*9]=4;visible[((target+2)%3)*9+1]=3;
                var state=SichuanStateCodec.FromRaw(0,0,0,25,hand,visible,dingQueSuits:Enumerable.Repeat((target+2)%3,4).ToArray(),handCounts:new[]{14-3*groups,13,13,13});state.Phase=5;
                int gangs=0;
                for(int g=0;g<groups;g++)
                {
                    bool gang=(mask&(1<<g))!=0;gangs+=gang?1:0;
                    if(representation!=2)state.Melds18[0].AddRange(Enumerable.Repeat(offset+g,gang?4:3));
                    if(representation!=0)state.MeldViews[0].Add(new(gang?SichuanMeldType.ConcealedGang:SichuanMeldType.Peng,offset+g,0,g));
                }
                var price=new SichuanReadyWaitPricing().Build(state,ready,new double[27]);
                Check(state.Remaining18.Sum()==state.WallCount+state.HandCounts.Skip(1).Sum(),"public unknown mass matches wall plus three concealed hands");
                Check(price is not null && price.Waits.Count>0 && !price.HasDrawableWait,"independent exact legal dead ready control");
                Check(ready.Sum()+3*groups+gangs==13+gangs,"actual ready physical total including gang extras");
                var oldGoal=new SichuanRoundBrainSnapshot{PrimaryRoute="清一色",TargetSuit=target,Commitment=92};
                var after=planner.Evaluate(state,ready,groups,oldGoal);
                Check(after.RouteWeights.ContainsKey("清一色"),$"dead ready incorrectly pruned target{target} groups{groups} mask{mask} representation{representation}");
                Check(after.TargetSuit==target,"canonical exposed suit lost under typed-only representation");
            }
            Console.WriteLine($"FLUSH_CAPACITY PASS checks={checks}; impossible three-peng public states, all suits/seats and typed/flat melds; external claim window excluded");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
