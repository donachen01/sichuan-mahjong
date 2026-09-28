using System.Diagnostics;
using SichuanMahjong.AI.Core.Cache;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

internal static class AiModelFixSmoke
{
    public static int Run()
    {
        var failures = new List<string>();
        CheckObserverIsolation(failures);
        CheckChanceTerminalState(failures);
        CheckGangContinuationScore(failures);
        CheckEndgameContract(failures);
        CheckReadyInferenceAndStage(failures);
        CheckStructuralWaitAndActiveCache(failures);
        CheckDecisionValueSemantics(failures);
        CheckDingQueShape(failures);
        Console.WriteLine($"AI_MODEL_FIX_CHECKS failures={failures.Count}");
        foreach (var failure in failures) Console.Error.WriteLine(failure);
        return failures.Count == 0 ? 0 : 1;
    }

    private static void CheckObserverIsolation(List<string> failures)
    {
        var hand = new int[27];
        foreach (var tile in new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 10, 10, 11 }) hand[tile]++;
        SichuanStateView State(int seat) => new()
        {
            SeatIndex = seat, CurrentSeat = seat, WallCount = 40, RoundIndex = 1,
            TotalRounds = 8, RemainingRounds = 8, Scores = new[] { 20, 0, -10, -10 },
            Hand18 = hand, Visible18 = new int[27],
            Remaining18 = hand.Select(count => 4 - count).ToArray(),
            DingQueSuits = new[] { 2, 2, 2, 2 }
        };
        var cache = new SichuanAiContextCache();
        var belief = new SichuanBeliefSnapshot();
        var first = cache.GetOrUpdate(State(0), belief);
        var switched = cache.GetOrUpdate(State(1), belief);
        var fresh = new SichuanAiContextCache().GetOrUpdate(State(1), belief);
        Check(first.ScoreSituation.SelfScore == 20 && switched.ScoreSituation.SelfScore == 0
            && switched.ScoreSituation.SelfScore == fresh.ScoreSituation.SelfScore
            && switched.DirtyFlags.HandAnalysis && switched.DirtyFlags.OpponentDanger,
            "seat switch reused another observer's context", failures);
        var changedPool = State(1);
        cache.GetOrUpdate(changedPool, belief);
        changedPool.Remaining18[10] = 0;
        var changed = cache.GetOrUpdate(changedPool, belief);
        var expected = new SichuanAiContextCache().GetOrUpdate(changedPool, belief);
        Check(changed.DirtyFlags.HandAnalysis && changed.DirtyFlags.TileDanger
            && changed.HandAnalysis.LiveUkeireCount == expected.HandAnalysis.LiveUkeireCount,
            "same-wall unknown-pool change reused live ukeire or threat analysis", failures);
    }

    private static void CheckChanceTerminalState(List<string> failures)
    {
        var tree = new SichuanActionTreeEvaluator();
        var actualDraw = tree.SearchChanceNodes(new(0, 8, 4, 3, 4, 0, 0,
            ChaJiaoValue: 7, MaxDraws: 8, Simulations: 64));
        var truncated = tree.SearchChanceNodes(new(0, 8, 4, 3, 4, 0, 0,
            ChaJiaoValue: 7, MaxDraws: 4, Simulations: 64));
        var beforeOurTurn = tree.SearchChanceNodes(new(1, 1, 4, 3, 4, 0, 0,
            Simulations: 64));
        Check(actualDraw.DrawProbability == 1 && actualDraw.ExpectedNetScore == 7
            && truncated.DrawProbability == 0 && truncated.HorizonProbability == 1
            && truncated.ExpectedNetScore == 7 && truncated.ExpectedContinuationValue == 7
            && beforeOurTurn.OwnWinProbability == 0,
            "chance search confused horizon with wall exhaustion or turn order", failures);
        var withoutReplacement = tree.SearchChanceNodes(new(1, 8, 4, 3, 12, 0, 0, MaxDraws: 8));
        Check(Math.Abs(withoutReplacement.OwnWinProbability - 0.25) < 1e-10,
            "fixed-wait probability disagrees with two own draws from eight tiles", failures);
        var continueAfterHu = tree.SearchChanceNodes(new(2, 2, 3, 1, 12, 1, 2, MaxDraws: 2));
        Check(continueAfterHu.OwnWinProbability == 1 && continueAfterHu.OpponentWinProbability == 1
            && continueAfterHu.ExpectedOwnWinGain == 6 && continueAfterHu.ExpectedOpponentLoss == 2
            && continueAfterHu.ExpectedNetScore == 4,
            "opponent exit did not continue play or reduce the self-draw payer count", failures);
        var lastSurvivor = tree.SearchChanceNodes(new(0, 8, 4, 3, 12, 1, 2, MaxDraws: 8));
        Check(lastSurvivor.BattleEndProbability == 1 && lastSurvivor.DrawProbability == 0
            && lastSurvivor.ExpectedOpponentLoss == 6 && lastSurvivor.ExpectedNetScore == -6,
            "blood battle stopped at the first opponent win or settled a false draw", failures);
    }

    private static void CheckGangContinuationScore(List<string> failures)
    {
        var result = new SichuanSettlementProjectionEngine().ProjectScenario(new(
            GangEvents: new[] { new SichuanGangScoreEvent(1, SichuanMeldType.MeldedGang,
                new[] {0, 2, 3}, SourceSeat: 2) },
            TransferEvents: new[] { new SichuanHuJiaoTransferEvent(0, SichuanMeldType.MeldedGang,
                new[] {0, 2, 3}, FromSeat: 1, GangSourceSeat: 2) }));
        Check(result.GangChanges.SequenceEqual(new[] {-1, 4, -2, -1})
            && result.TransferChanges.SequenceEqual(new[] {4, -4, 0, 0})
            && result.ScoreChanges.Sum() == 0,
            "melded gang or transfer disagrees with source-two / other-one payments", failures);
    }

    private static void CheckEndgameContract(List<string> failures)
    {
        var hand = new int[27];
        hand[0] = hand[1] = hand[2] = hand[9] = 3;
        hand[10] = 2;
        var remaining = new int[27];
        var budget = 43;
        for (var pass = 0; pass < 4; pass++)
            for (var tile = 0; tile < 27 && budget > 0; tile++)
                if (remaining[tile] < 4 - hand[tile]) { remaining[tile]++; budget--; }
        var visible = Enumerable.Range(0, 27).Select(tile => 4 - hand[tile] - remaining[tile]).ToArray();
        var state = new SichuanStateView
        {
            SeatIndex = 0, CurrentSeat = 0, WallCount = 4,
            Hand18 = hand, Visible18 = visible, Remaining18 = remaining,
            HandCounts = new[] { 14, 13, 13, 13 },
            DingQueSuits = new[] { 2, 2, 2, 2 }
        };
        var watch = Stopwatch.StartNew();
        var values = new SichuanPublicEndgameEvaluator().Evaluate(state, new[] { 10 });
        Console.WriteLine($"public_endgame_ms={watch.ElapsedMilliseconds}");
        Check(values.Count == 1 && values[0].TileType == 10 && double.IsFinite(values[0].NetScore),
            "a conserved public endgame failed to reach policy evaluation", failures);
        watch.Restart();
        Console.WriteLine($"public_endgame_ready_candidates={new SichuanExactHandAnalyzer().AnalyzeDiscards(hand, remaining, 0, true, -1).Count(item => item.Shanten == 0)}");
        var decision = new SichuanAiFacade().DecideDiscard(state);
        Console.WriteLine($"real_endgame_decision_ms={watch.ElapsedMilliseconds}; tile={decision.Action.TileType}");
        Check(decision.Action.TileType is >= 0 and < 27, "real endgame discard did not complete", failures);
        watch.Restart();
        var warmedDecision = new SichuanAiFacade().DecideDiscard(state);
        Console.WriteLine($"warmed_endgame_decision_ms={watch.ElapsedMilliseconds}; tile={warmedDecision.Action.TileType}");
        watch.Restart();
        _ = new SichuanUnifiedDecisionEngine().RankDiscards(state);
        Console.WriteLine($"warmed_unified_endgame_ms={watch.ElapsedMilliseconds}");

        var eventIndex = 0L;
        for (var tile = 0; tile < 27; tile++)
            for (var copy = 0; copy < visible[tile]; copy++)
            {
                var seat = (int)(eventIndex % 4);
                state.Discards18[seat].Add(tile);
                state.PublicEvents.Add(new(++eventIndex, (int)eventIndex, seat,
                    SichuanPublicEventType.Discard, tile, SichuanTileOrigin.Hand, seat));
            }
        // The last physical discard is won by seat 1 and removed from the
        // source's active river, while its historical discard remains public.
        var last = state.PublicEvents[^1];
        state.Discards18[last.Seat].RemoveAt(state.Discards18[last.Seat].Count - 1);
        state.HasHu[1] = true;
        state.ActiveSeats[1] = false;
        state.PublicEvents.Add(new(++eventIndex, last.TurnIndex, 1,
            SichuanPublicEventType.Hu, last.TileType, SourceSeat: last.Seat));
        var continuation = new SichuanPublicEndgameEvaluator().AnalyzeContinuation(
            state, new[] { 10 }, maximumWall: 4, sampleCount: 32);
        Check(continuation.Status == "diagnostic_only" && continuation.Candidates.Count == 1,
            $"claimed discard after Hu broke public allocation: {continuation.Status}", failures);
        state.HasHu[3] = true;
        state.ActiveSeats[3] = false;
        state.PublicEvents.Add(new(++eventIndex, last.TurnIndex, 3,
            SichuanPublicEventType.Hu, last.TileType, SourceSeat: last.Seat));
        var multiHu = new SichuanPublicEndgameEvaluator().AnalyzeContinuation(
            state, new[] { 10 }, maximumWall: 4, sampleCount: 32);
        Check(multiHu.Status == "diagnostic_only" && multiHu.Candidates.Count == 1,
            $"multi-Hu counted the shared physical tile twice: {multiHu.Status}", failures);
    }

    private static void CheckReadyInferenceAndStage(List<string> failures)
    {
        var state = new SichuanStateView
        {
            SeatIndex = 0, CurrentSeat = 0, WallCount = 8,
            ActiveSeats = new[] { true, true, true, true },
            IsCalled = new[] { false, true, false, false }
        };
        var evidence = new SichuanEvidenceEngine().Build(state);
        var ready = new SichuanOpponentRangeEngine().BuildSeatRange(state, evidence, 1).ReadyProbability;
        var stage = new SichuanStageEvaluator();
        var four = stage.Evaluate(state, new SichuanBeliefSnapshot());
        state.ActiveSeats[2] = false;
        state.ActiveSeats[3] = false;
        var two = stage.Evaluate(state, new SichuanBeliefSnapshot());
        Check(ready < 0.60 && four.StageIndex == 2 && two.StageIndex == 1,
            "one exposed meld was treated as ready or stage ignored future own draws", failures);
    }

    private static void CheckStructuralWaitAndActiveCache(List<string> failures)
    {
        var hand = new int[27];
        foreach (var tile in new[] {0,1,2,3,4,5,6,7,8,9,9,9,10}) hand[tile]++;
        var state = new SichuanStateView { SeatIndex = 0, DingQueSuits = new[] {2,2,2,2} };
        var oracle = new SichuanHiddenHandInferenceEngine().Infer(state, mode: SichuanInformationMode.Oracle,
            oracleHands: new[] {new int[27], hand, new int[27], new int[27]}, oracleWall: new int[27]);
        Check(oracle.ReadyProbabilities[1] == 1 && oracle.WaitProbabilities[1][10] == 1,
            "structural discard wait disappeared when the wall had zero copies", failures);
        var engine = new SichuanBeliefEngine();
        var active = engine.Build(state);
        state.ActiveSeats[1] = false;
        var exited = engine.Build(state);
        Check(!ReferenceEquals(active, exited) && !exited.SeatReadyPosterior.ContainsKey(1),
            "active-seat change reused cached inference or retained inactive threat", failures);
        state.ActiveSeats[1] = true;
        state.Discards18[1].Add(0);
        Check(SichuanOpponentTimeline.MustHaveClearedMissing(state, 1),
            "legal non-missing discard did not establish the post-discard cleared-suit constraint", failures);
        state.HandCounts[1] = 14;
        Check(!SichuanOpponentTimeline.MustHaveClearedMissing(state, 1),
            "post-discard missing-suit constraint leaked into a newly drawn hand", failures);
    }

    private static void CheckDingQueShape(List<string> failures)
    {
        var hand = new int[27];
        foreach (var tile in new[] { 0, 0, 0, 9, 12, 15, 17, 18, 18, 19, 20, 21, 22, 23 }) hand[tile]++;
        var choice = new SichuanDingQueDecisionEngine().DecideDingQue(hand, new[] { "tiao", "tong", "wan" });
        Console.WriteLine(string.Join("; ", choice.Reasons));
        Check(choice.Suit == "tong", "ding que discarded an existing triplet over four loose tiles", failures);
    }

    private static void CheckDecisionValueSemantics(List<string> failures)
    {
        var hand = new int[27];
        hand[0] = hand[1] = hand[2] = hand[9] = 3;
        hand[10] = 2;
        var state = new SichuanStateView
        {
            SeatIndex = 0, CurrentSeat = 0, WallCount = 8,
            Hand18 = hand, Remaining18 = hand.Select(count => 4 - count).ToArray()
        };
        var first = new SichuanBeliefSnapshot();
        first.SeatTileWaitProbability[1] = new Dictionary<int, double> { [10] = 0.25 };
        var second = new SichuanBeliefSnapshot();
        second.SeatTileWaitProbability[1] = new Dictionary<int, double> { [10] = 0.25 };
        second.SeatTileWaitProbability[2] = new Dictionary<int, double> { [10] = 0.25 };
        var engine = new SichuanUnifiedDecisionEngine();
        var oneThreat = engine.RankDiscards(state, first).Candidates.Single(c => c.Action.TileType == 10);
        var twoThreats = engine.RankDiscards(state, second).Candidates.Single(c => c.Action.TileType == 10);
        var all = engine.RankDiscards(state, first).Candidates;
        Check(twoThreats.DealInLoss > oneThreat.DealInLoss
            && oneThreat.WinGain > 0
            && all.Where(c => c.ReasonCodes.Any(reason => reason.StartsWith("EXACT_SHANTEN_")
                && reason != "EXACT_SHANTEN_0")).All(c => c.WinGain == 0),
            "discard EV did not separate progress from Hu or accumulate multi-Hu loss", failures);
    }

    private static void Check(bool condition, string message, List<string> failures)
    {
        if (!condition) failures.Add(message);
    }
}
