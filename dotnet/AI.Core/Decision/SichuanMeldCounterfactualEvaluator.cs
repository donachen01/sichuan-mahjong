using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanMeldCounterfactual(string Action, int Shanten, int LiveUkeire, double RouteLoss, double Risk, double Value);

public sealed class SichuanMeldCounterfactualEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();

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
        var value = -bestShanten * 2.4 + bestLive * 0.12 + gangGain - routeLoss - risk;
        return new SichuanMeldCounterfactual(action, bestShanten, bestLive, routeLoss, risk, value);
    }
}
