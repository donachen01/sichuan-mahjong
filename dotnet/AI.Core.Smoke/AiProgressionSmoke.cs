using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

internal static class AiProgressionSmoke
{
    public static int Run()
    {
        static int[] Hand(params int[] tiles)
        {
            var result = new int[27];
            foreach (var tile in tiles) result[tile]++;
            return result;
        }
        var own = Hand(0,1,2,3,4,5,9,10,12,13,15,15,17,26);
        var opponent = Hand(18,18,18,19,19,19,20,20,20,21,21,21,22);
        var state = new SichuanStateView
        {
            SeatIndex = 0, CurrentSeat = 0, Hand18 = own,
            ActiveSeats = new[] {true,true,false,false},
            DingQueSuits = new[] {2,2,0,0}
        };
        // The explicit world is test-only. Production accepts public state and
        // samples hidden hands; it cannot call this internal simulation entry.
        var hands = new[] {own, opponent, new int[27], new int[27]};
        var evaluator = new SichuanPublicEndgameEvaluator();
        var beforeDraw = evaluator.Simulate(state,
            new SichuanHiddenHandParticle(hands, Hand(23), 1), new[] {23}, 26);
        var progressed = evaluator.Simulate(state,
            new SichuanHiddenHandParticle(hands, Hand(23,11), 1), new[] {23,11}, 26);
        var won = evaluator.Simulate(state,
            new SichuanHiddenHandParticle(hands, Hand(23,11,24,14), 1), new[] {23,11,24,14}, 26);
        var passed = !beforeDraw.OwnWon && !beforeDraw.OwnReadyAtEnd
            && !progressed.OwnWon && progressed.OwnReadyAtEnd
            && won.OwnWon && won.NetScore > 0 && own[26] == 1 && own.Sum() == 14;
        var multiOwn = Hand(0,0,1,1,2,2,12,13,14,15,16,17,10,10);
        var firstWinner = Hand(0,1,2,3,4,5,6,7,8,9,9,9,10);
        var secondWinner = Hand(18,19,20,21,22,23,24,25,26,11,11,11,10);
        var multiState = new SichuanStateView {
            SeatIndex = 0, CurrentSeat = 0, Hand18 = multiOwn,
            ActiveSeats = new[] {true,true,true,false},
            HasHu = new[] {false,false,false,true},
            WonScores = new[] {-1,-1,-1,1}, DingQueSuits = new[] {2,2,0,1}
        };
        var multi = evaluator.Simulate(multiState,
            new SichuanHiddenHandParticle(new[] {multiOwn,firstWinner,secondWinner,new int[27]}, new int[27], 1),
            Array.Empty<int>(), 10);
        passed &= multi.InitialDealIn && multi.ImmediateScore == -2 && multi.NetScore == -2
            && !multi.OwnWon && multiOwn[10] == 2;
        Console.WriteLine($"MULTI_HU_CONTINUATION immediate={multi.ImmediateScore}; net={multi.NetScore}");
        Console.WriteLine($"REAL_HAND_PROGRESS before_ready={beforeDraw.OwnReadyAtEnd}; progressed_ready={progressed.OwnReadyAtEnd}; won={won.OwnWon}; score={won.NetScore}");
        Console.WriteLine($"AI_PROGRESSION_CHECKS failures={(passed ? 0 : 1)}");
        return passed ? 0 : 1;
    }
}
