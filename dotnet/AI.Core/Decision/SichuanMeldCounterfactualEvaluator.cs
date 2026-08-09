using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanMeldCounterfactual(
    string Action,
    int Shanten,
    int LiveUkeire,
    double RouteLoss,
    double Risk,
    double Value,
    double ExpectedFan);

public sealed class SichuanMeldCounterfactualEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanActionTreeEvaluator _tree = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();

    public SichuanMeldCounterfactual Evaluate(SichuanStateView state, string action, int tileType, int removeCount, int meldCountAfter, double routeLoss, double risk, double gangGain)
    {
        var hand = (int[])state.Hand18.Clone();
        if (tileType is >= 0 and < 27) hand[tileType] = Math.Max(0, hand[tileType] - removeCount);
        var bestShanten = 8;
        var bestLive = 0;
        for (var discard = 0; discard < 27; discard++)
        {
            if (hand[discard] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(hand, discard, meldCountAfter);
            var (_, live, _) = _ukeire.CalcUkeire(hand, state.Remaining18, discard, meldCountAfter);
            if (shanten < bestShanten || shanten == bestShanten && live > bestLive) { bestShanten = shanten; bestLive = live; }
        }
        // Keep the exact shape metrics, then price the next few draws with a
        // bounded public-information chance search. This captures wall length,
        // active-player pressure and the value of still having a live route,
        // without turning every reaction into a full-game Monte Carlo search.
        var melds = state.MeldViews[state.SeatIndex].Count > 0
            ? state.MeldViews[state.SeatIndex].ToArray()
            : InferMeldViews(state);
        var projectedMelds = action == "pass"
            ? melds
            : melds.Concat(new[]
            {
                new SichuanMeldView(
                    action == "gang" ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng,
                    tileType,
                    -1,
                    state.EventVersion)
            }).ToArray();
        var handForWaits = (int[])hand.Clone();
        if (bestShanten >= 0 && bestLive > 0)
        {
            var bestDiscard = FindBestDiscard(hand, state, meldCountAfter);
            if (bestDiscard >= 0) handForWaits[bestDiscard] = Math.Max(0, handForWaits[bestDiscard] - 1);
        }
        var waits = _hands.EnumerateWaits(handForWaits, state.Remaining18, meldCountAfter);
        var waitWeight = waits.Sum(wait => Math.Max(0, wait.LiveCount));
        var expectedFan = 0.0;
        var expectedSelfDrawGain = 0.0;
        var expectedGangDrawBonus = 0.0;
        var activeSeatList = state.ActiveSeats
            .Select((active, seat) => (active, seat))
            .Where(item => item.active)
            .Select(item => item.seat)
            .ToArray();
        var settlement = new SichuanSettlementProjectionEngine();
        if (waitWeight > 0)
        {
            foreach (var wait in waits)
            {
                var completed = (int[])handForWaits.Clone();
                completed[wait.TileType]++;
                var fan = _fans.Project(completed, projectedMelds, SichuanWinType.SelfDraw);
                var weight = Math.Max(0, wait.LiveCount) / (double)waitWeight;
                expectedFan += fan.CappedFan * weight;
                expectedSelfDrawGain += settlement
                    .ProjectWin(state.SeatIndex, -1, activeSeatList, fan, SichuanWinType.SelfDraw)
                    .WinnerGain * weight;
                if (action == "gang")
                {
                    var gangFan = _fans.Project(completed, projectedMelds, SichuanWinType.GangSelfDraw);
                    var normalGain = settlement
                        .ProjectWin(state.SeatIndex, -1, activeSeatList, fan, SichuanWinType.SelfDraw)
                        .WinnerGain;
                    var gangGainValue = settlement
                        .ProjectWin(state.SeatIndex, -1, activeSeatList, gangFan, SichuanWinType.GangSelfDraw)
                        .WinnerGain;
                    expectedGangDrawBonus += Math.Max(0, gangGainValue - normalGain) * weight;
                }
            }
        }

        var activePlayers = Math.Clamp(state.ActiveSeats.Count(value => value), 2, 4);
        var expectedOwnDraws = Math.Max(1, Math.Min(6, state.WallCount / activePlayers));
        var winScore = bestShanten == 0 ? 3.5 : 1.5;
        var opponentLoss = bestShanten == 0 ? 2.4 : 1.2;
        var chance = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
            bestLive,
            Math.Max(1, state.WallCount),
            activePlayers,
            0,
            winScore,
            state.IsReady.Count(value => value) * 0.006,
            opponentLoss,
            GangOpportunityProbability: gangGain > 0 ? 0.08 : 0,
            GangGain: gangGain,
            ChaJiaoValue: bestShanten == 0 ? 0.35 : 0,
            MaxDraws: Math.Min(12, Math.Max(4, state.WallCount)),
            Simulations: 128,
            Seed: 20260809 ^ state.RoundIndex ^ tileType ^ (action == "gang" ? 17 : action == "peng" ? 11 : 3)));
        var value = -bestShanten * 2.4
            + bestLive * 0.12
            + gangGain
            + chance.ExpectedNetScore * 0.45
            + Math.Clamp(expectedFan - 1.0, 0, 3) * 0.35
            + Math.Clamp(expectedSelfDrawGain / 8.0, 0, 4) * 0.12
            + Math.Clamp(expectedGangDrawBonus / 8.0, 0, 4) * 0.08
            - routeLoss
            - risk;
        return new SichuanMeldCounterfactual(action, bestShanten, bestLive, routeLoss, risk, value, expectedFan);
    }

    private int FindBestDiscard(int[] hand, SichuanStateView state, int meldCountAfter)
    {
        var bestDiscard = -1;
        var bestShanten = 8;
        var bestLive = -1;
        for (var discard = 0; discard < 27; discard++)
        {
            if (hand[discard] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(hand, discard, meldCountAfter);
            var (_, live, _) = _ukeire.CalcUkeire(hand, state.Remaining18, discard, meldCountAfter);
            if (shanten < bestShanten || shanten == bestShanten && live > bestLive)
            {
                bestDiscard = discard;
                bestShanten = shanten;
                bestLive = live;
            }
        }
        return bestDiscard;
    }

    private static SichuanMeldView[] InferMeldViews(SichuanStateView state)
        => state.Melds18[state.SeatIndex]
            .Where(tile => tile is >= 0 and < 27)
            .GroupBy(tile => tile)
            .Select((group, index) => new SichuanMeldView(
                group.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng,
                group.Key,
                -1,
                index))
            .ToArray();
}
