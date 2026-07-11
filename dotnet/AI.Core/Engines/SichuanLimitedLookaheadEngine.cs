using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanLimitedLookaheadEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();

    public SichuanLimitedLookaheadSummary Evaluate(int[] hand18AfterDiscard, int[] remaining18, int meldCount, int currentShanten, int currentLiveUkeire, int maxDrawTypes = 27)
    {
        if (maxDrawTypes <= 0)
            return new SichuanLimitedLookaheadSummary();

        var totalRemaining = remaining18.Sum();
        if (totalRemaining <= 0)
            return new SichuanLimitedLookaheadSummary { Reasons = new[] { "前瞻无牌墙" } };

        var sampledDraws = 0;
        var weightedScore = 0.0;
        var totalWeight = 0.0;
        var bestNextShanten = 8;
        var bestNextLive = 0;
        var drawTiles = Enumerable.Range(0, 27)
            .Where(tile => remaining18[tile] > 0)
            .OrderByDescending(tile => EstimateDrawPriority(hand18AfterDiscard, tile, remaining18[tile]))
            .Take(Math.Clamp(maxDrawTypes, 1, 27));
        foreach (var drawTile in drawTiles)
        {
            var drawCount = remaining18[drawTile];
            var drawnHand = (int[])hand18AfterDiscard.Clone();
            drawnHand[drawTile]++;
            var bestForDraw = EvaluateBestNextDiscard(drawnHand, remaining18, drawTile, meldCount);
            var drawScore = (currentShanten - bestForDraw.Shanten) * 12.0
                + (bestForDraw.LiveUkeire - currentLiveUkeire) * 0.85
                + (bestForDraw.Shanten == 0 ? 5.0 : 0.0);
            weightedScore += drawScore * drawCount;
            totalWeight += drawCount;
            sampledDraws++;
            if (bestForDraw.Shanten < bestNextShanten || (bestForDraw.Shanten == bestNextShanten && bestForDraw.LiveUkeire > bestNextLive))
            {
                bestNextShanten = bestForDraw.Shanten;
                bestNextLive = bestForDraw.LiveUkeire;
            }
        }

        var score = totalWeight <= 0.0 ? 0.0 : weightedScore / totalWeight;
        var reasons = new List<string>();
        if (score >= 4.0)
            reasons.Add($"前瞻改良 {score:0.0}");
        else if (score <= -3.0)
            reasons.Add($"前瞻受限 {score:0.0}");
        if (bestNextShanten < currentShanten)
            reasons.Add($"下巡可降向听 {bestNextShanten}");
        else if (bestNextShanten == currentShanten && bestNextLive > currentLiveUkeire + 3)
            reasons.Add($"下巡活进张可扩 {bestNextLive}");

        return new SichuanLimitedLookaheadSummary
        {
            Score = Math.Clamp(score, -18.0, 24.0),
            SampledDrawCount = sampledDraws,
            BestNextShanten = bestNextShanten,
            BestNextLiveUkeire = bestNextLive,
            Reasons = reasons.Take(2).ToArray()
        };
    }

    private static int EstimateDrawPriority(int[] hand18AfterDiscard, int drawTile, int drawCount)
    {
        var priority = drawCount * 4;
        if (hand18AfterDiscard[drawTile] > 0)
            priority += 8 + hand18AfterDiscard[drawTile] * 3;
        if (drawTile % 9 > 0 && hand18AfterDiscard[drawTile - 1] > 0)
            priority += 5;
        if (drawTile % 9 < 8 && hand18AfterDiscard[drawTile + 1] > 0)
            priority += 5;
        if (drawTile % 9 > 1 && hand18AfterDiscard[drawTile - 2] > 0)
            priority += 3;
        if (drawTile % 9 < 7 && hand18AfterDiscard[drawTile + 2] > 0)
            priority += 3;
        return priority;
    }

    private (int Shanten, int LiveUkeire) EvaluateBestNextDiscard(int[] drawnHand, int[] remaining18, int drawTile, int meldCount)
    {
        var adjustedRemaining = (int[])remaining18.Clone();
        if (drawTile is >= 0 and < 27)
            adjustedRemaining[drawTile] = Math.Max(0, adjustedRemaining[drawTile] - 1);
        var bestShanten = 8;
        var bestLive = 0;
        for (var discardTile = 0; discardTile < 27; discardTile++)
        {
            if (drawnHand[discardTile] <= 0)
                continue;
            var shanten = _shanten.CalcShantenAfterDiscard(drawnHand, discardTile, meldCount);
            var (_, liveUkeire, _) = _ukeire.CalcUkeire(drawnHand, adjustedRemaining, discardTile, meldCount);
            if (shanten < bestShanten || (shanten == bestShanten && liveUkeire > bestLive))
            {
                bestShanten = shanten;
                bestLive = liveUkeire;
            }
        }
        return (bestShanten, bestLive);
    }
}
