namespace SichuanMahjong.AI.Core.Rules;

/// <summary>
/// Bounded continuation approximation, not a calibrated probability. A ready
/// branch is retained; other branches need shanten advancing draws. Until a
/// full rollout is available, freeze the current public progress rate instead
/// of assuming that all immediate gang money is permanently retained.
/// Zero future draws and insufficient draw budgets have exact boundaries.
/// </summary>
public static class SichuanGangRefundRisk
{
    public static double NotReadyProbability(int shanten, double liveProgress,
        int remainingWall, int ownFutureDraws)
    {
        if (shanten <= 0) return 0;
        if (ownFutureDraws < shanten || remainingWall <= 0) return 1;
        var p = Math.Clamp(liveProgress / remainingWall, 0, 1);
        var probabilities = new double[shanten + 1];
        probabilities[0] = 1;
        for (var i = 0; i < ownFutureDraws; i++)
        {
            var next = new double[shanten + 1];
            for (var j = 0; j <= shanten; j++)
            {
                next[j] += probabilities[j] * (1 - p);
                next[Math.Min(shanten, j + 1)] += probabilities[j] * p;
            }
            probabilities = next;
        }
        return Math.Clamp(1 - probabilities[shanten], 0, 1);
    }
}
