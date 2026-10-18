using System.Diagnostics;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

internal static class SharedPolicyProbe
{
    public static int Run()
    {
        SichuanPolicyTiming.Enabled=true;SichuanPolicyTiming.Reset();
        var state=RepresentativeHuSmoke.Book([18,18,19,20,21,24,25,26,12,13,14,15,16],[0,1,1,0]);
        var offered=state.Discards18[1][0];
        if(!SichuanPublicInferenceBoundary.TryProject(state,out var projected,out var reason,true,1))throw new Exception(reason);
        var particles=new SichuanHiddenHandInferenceEngine().SampleParticles(projected,32,781,SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        var p=particles[0];
        var wall=(int[])typeof(SichuanPublicEndgameEvaluator).GetMethod("ShuffledWall",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static)!.Invoke(null,new object[]{p,781})!;
        SichuanPublicInferenceBoundary.RestorePolicyHistory(state,projected);
        var root=SichuanPublicEndgameEvaluator.PrepareReactionRoot(state,offered,1,"discard")!;
        var watch=Stopwatch.StartNew();
        var outcome=new SichuanPublicEndgameEvaluator().Simulate(projected,p,wall,-1,reaction:root with { Action=SichuanActionType.Pass });
        Console.WriteLine($"SHARED_POLICY_PROBE ms={watch.ElapsedMilliseconds} net={outcome.NetScore} wall={wall.Length} scope_restored={!SichuanPolicyExecutionScope.IsSimulation}");
        foreach(var row in SichuanPolicyTiming.Report())Console.WriteLine(row);
        return SichuanPolicyExecutionScope.IsSimulation?1:0;
    }
}
