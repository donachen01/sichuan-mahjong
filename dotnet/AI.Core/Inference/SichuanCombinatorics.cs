namespace SichuanMahjong.AI.Core.Inference;

public static class SichuanCombinatorics
{
    public static double LogCombination(int n, int k)
    {
        if (k < 0 || k > n) return double.NegativeInfinity;
        k = Math.Min(k, n - k);
        var result = 0.0;
        for (var i = 1; i <= k; i++) result += Math.Log(n - k + i) - Math.Log(i);
        return result;
    }

    public static double LogMultivariateHypergeometric(IReadOnlyList<int> population, IReadOnlyList<int> sample)
    {
        if (population.Count != sample.Count) return double.NegativeInfinity;
        var totalPopulation = 0;
        var totalSample = 0;
        var numerator = 0.0;
        for (var i = 0; i < population.Count; i++)
        {
            if (sample[i] < 0 || sample[i] > population[i]) return double.NegativeInfinity;
            totalPopulation += population[i];
            totalSample += sample[i];
            numerator += LogCombination(population[i], sample[i]);
        }
        return numerator - LogCombination(totalPopulation, totalSample);
    }
}
