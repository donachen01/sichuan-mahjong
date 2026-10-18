using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

internal static class BucketContinuationSmoke
{
    public static int Run()
    {
        var hand = new int[27];
        foreach (var t in new[] {11,11,11,12,13,13,15,17,19,21,23,24,24,26}) hand[t]++;
        var visible = new int[27]; visible[14] = 3;
        var state = SichuanStateCodec.FromRaw(0,0,0,52,hand,visible,dingQueSuits: [0,2,1,0], handCounts: [14,13,13,13]);
        for(var seat=1; seat<4; seat++)
        {
            state.Discards18[seat].Add(14);
            state.PublicEvents.Add(new(seat,seat,seat,SichuanPublicEventType.Discard,14));
        }
        var timer = System.Diagnostics.Stopwatch.StartNew();
        var report = new SichuanPublicEndgameEvaluator().AnalyzeContinuation(state,
            new[] {26,12},72,32,20261001,includeUnready:true,fastStructural:true);
        Console.WriteLine($"bucket_full status={report.Status} ess={report.EffectiveSampleSize:F1} ms={timer.ElapsedMilliseconds}");
        foreach(var c in report.Comparisons) Console.WriteLine($"tile={c.TileType} delta={c.MeanNetDifference:F2} se={c.StandardError:F2}");
        var reference = new SichuanPublicEndgameEvaluator().AnalyzeContinuation(state,
            new[] {26,12},72,32,20261001,includeUnready:true);
        if (report.Candidates.Count != 2 || reference.Candidates.Count != 2 || report.Candidates.Where((c,i) =>
            Math.Abs(c.NetScore-reference.Candidates[i].NetScore)>1e-9
            || Math.Abs(c.ExpectedOwnPengClaims-reference.Candidates[i].ExpectedOwnPengClaims)>1e-9).Any())
            return Fail("accelerated structural search changed paired outcomes");
        timer.Restart();
        var decision = new SichuanDecisionEngine().DecideDiscard(state);
        var decisionMs=timer.ElapsedMilliseconds;
        if (decision.Candidates.Any(c=>c.BucketContinuationSamples > 0)
            || !decision.Candidates.Any(c=>c.BucketSupported))
            return Fail("live discard must retain structure evidence without terminal samples");

        // A deterministic world is injected only into the internal simulator.
        // Its opponent must clear 8筒 when missing 筒, making a legal progressing
        // Peng available; changing the missing suit removes this forced supply.
        var own = Hand(18,19,20,16,16,26,26,10,11,14,15,13,17,0);
        var opponent = Hand(16,0,1,2,3,4,5,6,7,8,18,19,20);
        var supply = new SichuanStateView { SeatIndex=0, CurrentSeat=0, Hand18=own,
            ActiveSeats=[true,true,false,false], HasHu=[false,false,true,true],
            WonScores=[-1,-1,1,1], DingQueSuits=[0,1,0,0] };
        var particle = new SichuanHiddenHandParticle([own,opponent,new int[27],new int[27]],Hand(0),1);
        var evaluator = new SichuanPublicEndgameEvaluator();
        var offered = evaluator.Simulate(supply,particle,[0],0);
        supply.DingQueSuits[1]=2;
        var withheld = evaluator.Simulate(supply,particle,[0],0);
        if (offered.OwnPengClaims != 1 || withheld.OwnPengClaims != 0 || own.Sum()!=14)
            return Fail($"dingque legal supply mismatch {offered.OwnPengClaims}/{withheld.OwnPengClaims}");
        // Hidden runtime flags are outside the public sampling boundary.
        state.IsReady[1]=true;
        state.PublicEvents.Add(new(100,20,1,SichuanPublicEventType.Draw,0));
        var hiddenFlag = new SichuanPublicEndgameEvaluator().AnalyzeContinuation(state,
            [26,12],72,32,20261001,includeUnready:true,fastStructural:true);
        if (hiddenFlag.Candidates.Count!=report.Candidates.Count
            || hiddenFlag.Candidates.Where((c,i)=>Math.Abs(c.NetScore-report.Candidates[i].NetScore)>1e-9).Any())
            return Fail("hidden draw/readiness leaked into public planning");
        Console.WriteLine($"bucket_full: PASS; selected={decision.Action.TileType}; candidates={decision.Candidates.Count(c=>c.BucketContinuationSamples>0)}; decision_ms={decisionMs}; legal peng={offered.OwnPengClaims}/{withheld.OwnPengClaims}; accelerated/reference identical");
        return 0;
    }
    private static int[] Hand(params int[] tiles) { var h=new int[27]; foreach(var t in tiles) h[t]++; return h; }
    private static int Fail(string why) { Console.Error.WriteLine("bucket_full: FAIL "+why); return 1; }
}
