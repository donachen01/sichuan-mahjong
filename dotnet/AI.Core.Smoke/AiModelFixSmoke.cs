using System.Diagnostics;
using SichuanMahjong.AI.Core.Cache;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

internal static class AiModelFixSmoke
{
    public static int Run()
    {
        var failures = new List<string>();
        CheckObserverIsolation(failures);
        CheckChanceTerminalState(failures);
        CheckEndgameContract(failures);
        CheckReadyInferenceAndStage(failures);
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
            && truncated.ExpectedNetScore == 0
            && beforeOurTurn.OwnWinProbability == 0,
            "chance search confused horizon with wall exhaustion or turn order", failures);
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

    private static void CheckDingQueShape(List<string> failures)
    {
        var hand = new int[27];
        foreach (var tile in new[] { 0, 0, 0, 9, 12, 15, 17, 18, 18, 19, 20, 21, 22, 23 }) hand[tile]++;
        var choice = new SichuanDingQueDecisionEngine().DecideDingQue(hand, new[] { "tiao", "tong", "wan" });
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
