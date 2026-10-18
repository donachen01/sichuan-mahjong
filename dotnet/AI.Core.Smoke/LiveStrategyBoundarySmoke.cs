using System.Diagnostics;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class LiveStrategyBoundarySmoke
{
    public static int Run()
    {
        try
        {
            var tiles = new[] {0,1,2,3,4,6,7,9,10,11,13,14,16,17};
            foreach (var wall in new[] {55,12,4})
            {
                var state = SichuanStateCodec.FromRaw(0,0,0,wall,SichuanTileCodec.BuildCount18(tiles),
                    new int[27],dingQueSuits:[2,0,1,2],handCounts:[14,13,13,13]);
                var watch = Stopwatch.StartNew();
                var decision = new SichuanDecisionEngine().DecideDiscard(state);
                Check(state.Hand18[decision.Action.TileType] > 0, "illegal live discard");
                Check(decision.Reasons.Count > 0, "missing live reasons");
                Check(decision.Candidates.All(c => c.BucketContinuationSamples == 0), "terminal bucket samples in live decision");
                Check(decision.Performance.Modules.All(m => m.Module is not ("BucketContinuation" or "CriticalContinuation")), "terminal module in live decision");
                using (new SichuanPolicyExecutionScope())
                    Check(new SichuanDecisionEngine().DecideDiscard(state).Action.TileType == decision.Action.TileType,
                        "live/research discard strategies differ");
                Console.WriteLine($"LIVE_DISCARD wall={wall} ms={watch.Elapsed.TotalMilliseconds:F2} tile={decision.Action.TileType}");
            }
            var offered = RepresentativeHuSmoke.Book([18,18,19,20,21,24,25,26,12,13,14,15,16],[0,1,1,0]);
            var local = new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(offered,11,1,"discard");
            SichuanDecisionExplanation simulated;
            using (new SichuanPolicyExecutionScope())
                simulated = new SichuanUnifiedDecisionEngine().CompareDiscardHuWithPass(offered,11,1,"discard");
            Check(local.SelectedAction == simulated.SelectedAction && local.Reasons.SequenceEqual(simulated.Reasons), "live/research Hu strategies differ");
            Check(local.Reasons.Contains("HU_LOCAL_ESTIMATE_NOT_TERMINAL_EV"), "local estimate presented as terminal evidence");
            Check(!SichuanPolicyExecutionScope.IsSimulation, "simulation scope leaked");
            var watchHu = Stopwatch.StartNew();
            var reaction = new SichuanReactionDecisionEngine().DecideReaction(offered,11,true,false,false,1);
            Check(reaction.Action.ActionType == local.SelectedAction, "reaction bypasses shared local Hu strategy");
            Check(!reaction.Reasons.Contains("HU_INCOME_COST_FULL_CONTINUATION"), "terminal evidence in live Hu");
            Console.WriteLine($"LIVE_HU ms={watchHu.Elapsed.TotalMilliseconds:F2} action={reaction.Action.ActionType}");
            var rob = new SichuanReactionDecisionEngine().DecideReaction(offered,11,true,false,false,1,"qiang_gang_hu");
            Check(rob.Action.ActionType == SichuanActionType.Hu, "rob-gang premium refused");
            var gangDiscard = RepresentativeHuSmoke.Book([18,18,19,20,21,24,25,26,12,13,14,15,16],[0,1,1,0]);
            gangDiscard.PublicEvents.Insert(gangDiscard.PublicEvents.Count-1,
                new(0,0,1,SichuanPublicEventType.ConcealedGang,0));
            var premium = new SichuanReactionDecisionEngine().DecideReaction(gangDiscard,11,true,false,false,1,"discard");
            Check(premium.Action.ActionType == SichuanActionType.Hu, "gang-discard history premium refused");
            _ = new SichuanSelfActionDecisionEngine().DecideSelfAction(offered,false,[],[]);
            _ = new SichuanDingQueDecisionEngine().DecideDingQue(SichuanTileCodec.BuildCount18(tiles),["tiao","tong","wan"]);
            var evaluator = new SichuanPublicEndgameEvaluator();
            using (SichuanPolicyExecutionScope.EnterDecision())
            {
                Reject(() => evaluator.AnalyzeContinuation(offered,[12,13]));
                Reject(() => evaluator.AnalyzeHuContinuation(offered,11,1));
                Reject(() => evaluator.Evaluate(offered,[12,13]));
                Reject(() => new SichuanUnifiedDecisionEngine().AnalyzeDiscardHuWithPass(offered,11,1,"discard"));
            }
            // After leaving a decision, explicit research remains available.
            var unsupported = evaluator.AnalyzeContinuation(offered,[12,13],maximumWall:4);
            Check(unsupported.Status != "", "research entry unavailable after decision scope");
            Console.WriteLine("LIVE_STRATEGY_BOUNDARY PASS: live/local parity, legal actions, reasons, and research-only terminal guard");
            return 0;
        }
        catch (Exception e) { Console.Error.WriteLine(e); return 1; }
    }

    private static void Reject(Action action)
    {
        try { action(); }
        catch (InvalidOperationException e) when (e.Message.StartsWith("Terminal simulation is research-only")) { return; }
        throw new Exception("terminal simulation was accepted inside a live decision");
    }
    private static void Check(bool condition,string label) { if (!condition) throw new Exception(label); }
}
