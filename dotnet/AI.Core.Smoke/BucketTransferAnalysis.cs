using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Engines;
internal static class BucketTransferAnalysis
{
    public static int Run(string output)
    {
        var hand=new[]{0,1,1,0,2,3,1,1,0,1,2,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0};
        var rows=new List<object>();
        foreach(var permutation in new[]{new[]{0,1,2},new[]{0,2,1},new[]{1,0,2},new[]{1,2,0},new[]{2,0,1},new[]{2,1,0}})
        {
            int Map(int t)=>permutation[t/9]*9+t%9;
            int Original(int t)=>Array.IndexOf(permutation,t/9)*9+t%9;
            var transformed=new int[27];for(int t=0;t<27;t++)transformed[Map(t)]=hand[t];
            var state=SichuanStateCodec.FromRaw(0,0,0,55,transformed,new int[27],dingQueSuits:new[]{2,0,1,2}.Select(s=>permutation[s]).ToArray());
            var baseline=new SichuanDecisionEngine().DecideDiscard(state);
            state.PolicyVariant="bucket_local_candidate_v1";
            var candidate=new SichuanDecisionEngine().DecideDiscard(state);
            rows.Add(new{permutation,grounding="synthetic_transfer",baseline=Original(baseline.Action.TileType),candidate=Original(candidate.Action.TileType),candidate.Reasons,candidate.Arbitration,
                candidates=candidate.Candidates.Select(c=>new{tile=Original(c.TileType),c.Score,c.UnifiedActionValue,c.LiveUkeire,c.Danger,c.BucketSupported,c.BucketCapacityOverflow,c.BucketWeakestCompletionMass,c.BucketNextCompletionMass,c.BucketTotalImprovementMass})});
        }
        File.WriteAllText(output,JsonSerializer.Serialize(rows,new JsonSerializerOptions{WriteIndented=true}));return 0;
    }
}
