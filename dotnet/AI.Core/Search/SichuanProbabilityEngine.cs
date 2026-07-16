namespace SichuanMahjong.AI.Core.Search;

public sealed class SichuanProbabilityEngine
{
    public static double AtLeastOneHit(int successes, int population, int draws)
    {
        if (successes <= 0 || population <= 0 || draws <= 0) return 0;
        successes = Math.Min(successes, population);
        draws = Math.Min(draws, population);
        var miss = 1.0;
        for (var i = 0; i < draws; i++)
            miss *= Math.Max(0, population - successes - i) / (double)Math.Max(1, population - i);
        return Math.Clamp(1.0 - miss, 0.0, 1.0);
    }

    public static double ExpectedSelfDrawGain(int liveTiles, int wallTiles, int expectedOwnDraws, double selfDrawScore)
        => AtLeastOneHit(liveTiles, wallTiles, expectedOwnDraws) * selfDrawScore;

    public static double HypergeometricProbability(int successes, int failures, int draws, int hits)
    {
        if (hits < 0 || hits > successes || draws - hits < 0 || draws - hits > failures) return 0;
        return Math.Exp(LogChoose(successes, hits) + LogChoose(failures, draws - hits) - LogChoose(successes + failures, draws));
    }

    private static double LogChoose(int n, int k)
    {
        if (k < 0 || k > n) return double.NegativeInfinity;
        k = Math.Min(k, n - k);
        var value = 0.0;
        for (var i = 1; i <= k; i++) value += Math.Log(n - k + i) - Math.Log(i);
        return value;
    }
}
