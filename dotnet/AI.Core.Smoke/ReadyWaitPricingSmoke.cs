using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class ReadyWaitPricingSmoke
{
    public static int Run(string? publicFile=null)
    {
        try
        {
            int checks=0;void Check(bool v,string m){checks++;if(!v)throw new Exception(m);}
            foreach(int suit in Enumerable.Range(0,3))
            {
                int Map(int t)=>(t+suit*9)%27;
                var h=new int[27];foreach(int t in new[]{0,0,0,1,2,3,4,5,6,7,8,8,8})h[Map(t)]++;
                var s=SichuanStateCodec.FromRaw(0,0,0,4,h,new int[27],dingQueSuits:[(suit+2)%3,0,0,0]);var weights=new double[27];weights[Map(0)]=1;weights[Map(4)]=3;
                var price=new SichuanReadyWaitPricing().Build(s,h,weights)!;
                Check(price.Waits.Count==9,"nine legal waits lost");Check(Math.Abs(price.WeightedFan-2.25)<1e-9,"wait-weighted capped fan wrong");Check(Math.Abs(price.WeightedHandScore-5)<1e-9,"averaged fan exponentiated instead of scoring each wait");Check(Math.Abs(price.WeightedSelfDrawPerPayer-6)<1e-9,"actual bottom bonus lost");
                var score=new SichuanExpectedScoreEngine().EvaluateDiscardCandidate(s,h,0,4,9,0,.94,.5,.7,0,0,0,.5,1,["清一色"],price);
                Check(score.EstimatedBaseScore==5 && score.Reasons.Contains("READY_WAIT_RULE_PRICING"),"exact mixed wait price did not enter candidate score");
                var dead=new SichuanReadyWaitPricing().Build(s,h,new double[27])!;var deadScore=new SichuanExpectedScoreEngine().EvaluateDiscardCandidate(s,h,0,0,9,0,.94,.5,.7,0,0,0,.5,1,["清一色"],dead);
                Check(deadScore.WinGain==0 && deadScore.Reasons.Contains("READY_ALL_WALL_WAITS_DEAD_NO_WIN_GAIN"),"dead wall waits assigned future win revenue");
                for(int seat=1;seat<4;seat++)s.HasHu[seat]=true;
                var exited=new SichuanExpectedScoreEngine().EvaluateDiscardCandidate(s,h,0,4,9,0,.94,.5,.7,0,0,0,.5,1,["清一色"],price);Check(exited.WinGain==0,"finished opponents still pay");
                var caphand=new int[27];foreach(int t in new[]{3,4,5,8})caphand[Map(t)]++;
                var capstate=SichuanStateCodec.FromRaw(0,0,0,1,caphand,new int[27],dingQueSuits:[(suit+2)%3,0,0,0]);foreach(int t in new[]{0,1,2}){capstate.MeldViews[0].Add(new(SichuanMeldType.ConcealedGang,Map(t),0,0));capstate.Melds18[0].AddRange(Enumerable.Repeat(Map(t),4));}
                var capweights=new double[27];capweights[Map(8)]=1;var capped=new SichuanReadyWaitPricing().Build(capstate,caphand,capweights)!;
                Check(capped.WeightedFan==4 && capped.WeightedHandScore==16 && capped.WeightedSelfDrawPerPayer==17,"actual three-gang cap or self-draw bottom wrong");
                Check(!capped.Waits.Any(w=>w.TileType==Map(0)),"fifth owned copy priced as legal wait");
            }
            if(publicFile is not null)
            {
                using var data=JsonDocument.Parse(File.ReadAllText(publicFile));int candidateChecks=0;
                foreach(var row in data.RootElement.GetProperty("rows").EnumerateArray())
                {
                    if(row.GetProperty("public_input").GetProperty("phase").GetInt32()!=5)continue;
                    var state=PublicPosteriorNaturalStudy.State(row.GetProperty("public_input"));var result=new SichuanAiFacade().DecideDiscard(state);var belief=new SichuanBeliefEngine().Build(state);var wall=new SichuanWallAvailabilityEngine().Build(state,belief);
                    foreach(var c in result.Candidates.Where(c=>c.Shanten==0))
                    {
                        var after=state.Hand18.ToArray();after[c.TileType]--;var price=new SichuanReadyWaitPricing().Build(state,after,wall.ExpectedCounts18);if(price is null)continue;
                        Check(Math.Abs(c.ExpectedFan-price.WeightedFan)<1e-9,"actual facade still uses projected future route fan for a ready hand");
                        Check(c.Reasons.Contains("READY_WAIT_RULE_PRICING"),"actual runtime candidate omitted exact wait price cause");candidateChecks++;
                    }
                }
                Console.WriteLine($"READY_WAIT_PRICE actual natural public candidate checks={candidateChecks}");
            }
            Console.WriteLine($"READY_WAIT_PRICE PASS checks={checks}; three-suit nine-wait 2.25 fan/5 score/6 selfpayer, dead waits, finished payers and three-gang cap");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
