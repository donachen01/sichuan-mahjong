using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanPublicPosteriorTile(
    int TileType,
    double ExpectedWallCopies,
    double InWallProbability,
    IReadOnlyList<double> WallCopyProbabilities,
    IReadOnlyList<double> OpponentHoldProbabilities);

public sealed record SichuanPublicPosteriorReport(
    bool Supported,
    string Reason,
    int SampleCount,
    double EffectiveSampleSize,
    IReadOnlyList<SichuanPublicPosteriorTile> Tiles)
{
    public string Scope => "Uncalibrated public posterior diagnostic; exact public tile conservation, ordered "
        + "discards, and explicit Peng/Gang pass evidence; current active-seat snapshot; no hidden draw order, reveal labels, outcome, "
        + "meld-timing likelihood, claims, or future exit transitions";
}

public sealed record SichuanPublicPosteriorSeedRun(
    int Seed, double EffectiveSampleSize, IReadOnlyList<double> InWallProbabilities);

public sealed record SichuanPublicPosteriorEnsembleTile(
    int TileType, double MeanInWallProbability, double MinimumInWallProbability,
    double MaximumInWallProbability, double SeedRange);

public sealed record SichuanPublicPosteriorEnsembleReport(
    bool Supported, string Reason, int SampleCountPerSeed, int BaseSeed,
    double MinimumEffectiveSampleSize, double MaximumSeedRange,
    IReadOnlyList<SichuanPublicPosteriorSeedRun> Runs,
    IReadOnlyList<SichuanPublicPosteriorEnsembleTile> Tiles);

/// <summary>
/// Read-only diagnostic for calibrating the public particle model before its
/// values may affect candidate scores. The caller cannot inject a hidden wall,
/// opponent hand, or post-decision reveal.
/// </summary>
public sealed class SichuanPublicPosteriorAnalysis
{
    public SichuanPublicPosteriorReport Analyze(SichuanStateView state, int sampleCount, int seed)
    {
        if (!SichuanPublicInferenceBoundary.TryProject(state, out var projection, out var reason))
            return Rejected(reason);
        if (sampleCount is < 32 or > 4096) throw new ArgumentOutOfRangeException(nameof(sampleCount));

        var particles = new SichuanHiddenHandInferenceEngine().SampleParticles(
            projection, sampleCount, seed, SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        if (particles.Count != sampleCount
            || particles.Any(particle => !SichuanPublicInferenceBoundary.ParticleConserves(state, particle)))
            return Rejected("sample_conservation_failed");

        var sumSquares = particles.Sum(particle => particle.Weight * particle.Weight);
        var tiles = new List<SichuanPublicPosteriorTile>(27);
        for (var tile = 0; tile < 27; tile++)
        {
            var copyMass = new double[5];
            var holds = new double[4];
            foreach (var particle in particles)
            {
                copyMass[particle.Wall27[tile]] += particle.Weight;
                for (var seat = 0; seat < 4; seat++)
                    if (seat != state.SeatIndex && particle.Hands27[seat][tile] > 0)
                        holds[seat] += particle.Weight;
            }
            tiles.Add(new(
                tile,
                Enumerable.Range(0, 5).Sum(count => count * copyMass[count]),
                copyMass.Skip(1).Sum(),
                Array.AsReadOnly(copyMass),
                Array.AsReadOnly(holds)));
        }
        return new(true, "public_posterior_diagnostic", particles.Count,
            sumSquares <= 0 ? 0 : 1 / sumSquares, tiles.AsReadOnly());
    }

    public SichuanPublicPosteriorEnsembleReport AnalyzeSeedEnsemble(
        SichuanStateView state, int sampleCountPerSeed, int baseSeed, int seedCount = 6)
    {
        if (seedCount is < 3 or > 12) throw new ArgumentOutOfRangeException(nameof(seedCount));
        var reports = Enumerable.Range(0, seedCount)
            .Select(index => (Seed: checked(baseSeed + index), Report: Analyze(state, sampleCountPerSeed, checked(baseSeed + index))))
            .ToArray();
        var rejected = reports.FirstOrDefault(item => !item.Report.Supported);
        if (rejected.Report is not null)
            return new(false, rejected.Report.Reason, 0, baseSeed, 0, 0,
                Array.Empty<SichuanPublicPosteriorSeedRun>(), Array.Empty<SichuanPublicPosteriorEnsembleTile>());

        var runs = reports.Select(item => new SichuanPublicPosteriorSeedRun(
            item.Seed,
            item.Report.EffectiveSampleSize,
            Array.AsReadOnly(item.Report.Tiles.Select(tile => tile.InWallProbability).ToArray()))).ToArray();
        var tiles = Enumerable.Range(0, 27).Select(tile =>
        {
            var values = runs.Select(run => run.InWallProbabilities[tile]).ToArray();
            return new SichuanPublicPosteriorEnsembleTile(
                tile, values.Average(), values.Min(), values.Max(), values.Max() - values.Min());
        }).ToArray();
        return new(true, "public_posterior_seed_ensemble", sampleCountPerSeed, baseSeed,
            runs.Min(run => run.EffectiveSampleSize), tiles.Max(tile => tile.SeedRange),
            Array.AsReadOnly(runs), Array.AsReadOnly(tiles));
    }

    private static SichuanPublicPosteriorReport Rejected(string reason)
        => new(false, reason, 0, 0, Array.Empty<SichuanPublicPosteriorTile>());
}
