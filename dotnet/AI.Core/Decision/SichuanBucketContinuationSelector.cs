using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanBucketContinuationSelection(
    int Tile, string Status, SichuanPublicContinuationReport? Discovery,
    SichuanPublicContinuationReport? Confirmation);

/// <summary>
/// Full-horizon confirmation for chapter 3.5. Structural evidence nominates
/// alternatives; paired public particles, legal claims, replanned discards and
/// settlement decide whether sacrificing immediate ukeire is worthwhile.
/// Never observes actual hidden hands or a future wall. No textbook tile keys.
/// </summary>
public sealed class SichuanBucketContinuationSelector
{
    private readonly SichuanPublicEndgameEvaluator _continuation = new();

    public SichuanBucketContinuationSelection Select(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, int currentTile)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        var current = candidates.FirstOrDefault(c => c.TileType == currentTile);
        if (current is null || current.Shanten is < 1 or > 2)
            return new(-1, "outside_structural_phase", null, null);
        if (state.OwnDingQueSuit is >= 0 and < 3
            && state.Hand18.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0))
            return new(-1, "missing_suit_not_cleared", null, null);
        var eligible = candidates.Where(c => c.TileType != currentTile
            && c.Shanten == current.Shanten
            && !Engines.SichuanRoutePlanEngine.IsFlushRoute(c.RoutePlanPrimary)
            && c.Danger <= current.Danger + 5
            && c.DealInProbability <= current.DealInProbability + 0.01).ToArray();

        // Keep two distinct proposals: a balanced block allocation and a
        // pair supplied by active opponents' missing suits. This is only a
        // proposal, not a probability or an automatic score bonus.
        var structural = eligible.Where(c => c.BucketSupported && (!current.BucketSupported
                || c.BucketWeakestCompletionMass > current.BucketWeakestCompletionMass + 0.25
                || c.BucketTotalImprovementMass > current.BucketTotalImprovementMass + 0.5
                || c.BucketCapacityOverflow < current.BucketCapacityOverflow))
            .OrderBy(c => c.BucketCapacityOverflow)
            .ThenByDescending(c => c.BucketWeakestCompletionMass)
            .ThenByDescending(c => c.BucketTotalImprovementMass)
            .ThenByDescending(c => c.LiveUkeire).FirstOrDefault();
        var pair = eligible.Where(c => PairSupply(c.TileType) > PairSupply(currentTile))
            .OrderByDescending(c => PairSupply(c.TileType))
            .ThenByDescending(c => c.LiveUkeire).FirstOrDefault();
        var replacement = eligible.Where(c => c.BucketSupported
                && c.BucketTotalImprovementMass > current.BucketTotalImprovementMass + 0.5)
            .OrderBy(c => c.BreaksTriplet)
            .ThenBy(c => c.BreaksPair)
            .ThenByDescending(c => c.BucketTotalImprovementMass)
            .ThenBy(c => c.BucketCapacityOverflow).FirstOrDefault();
        var flexible = eligible.Where(c => c.SameShantenImprovementCount > current.SameShantenImprovementCount
                || current.Shanten == 1 && c.LiveUkeire > current.LiveUkeire)
            .OrderByDescending(c => c.SameShantenImprovementCount)
            .ThenByDescending(c => c.LiveUkeire).FirstOrDefault();
        if (structural is null && replacement is null && pair is null && flexible is null)
            return new(-1, "no_structural_alternative", null, null);
        // Local block labels cannot safely prune a whole-hand replacement.
        // Once a planning conflict exists, compare every same-distance legal
        // alternative within the existing risk boundary on paired worlds.
        var proposals = eligible.Select(c => c.TileType).Prepend(currentTile).Distinct().ToArray();

        var seed = 20261001 ^ state.RoundIndex * 7919 ^ state.TurnIndex * 104729;
        var discovery = _continuation.AnalyzeContinuation(state, proposals, 72, 32, seed,
            includeUnready: true, fastStructural: true);
        Publish(discovery);
        if (discovery.EffectiveSampleSize < 12)
            return new(-1, "discovery_" + discovery.Status, discovery, null);
        var challenger = discovery.Comparisons.Where(c => c.TileType != currentTile)
            .OrderByDescending(c => c.MeanNetDifference).FirstOrDefault();
        // Discovery only nominates a positive candidate. All evidence for
        // promotion comes from the disjoint fixed-size confirmation batch.
        if (challenger is null || challenger.MeanNetDifference <= 0.10)
            return new(-1, "no_confirmed_discovery_advantage", discovery, null);

        var confirmation = _continuation.AnalyzeContinuation(state,
            new[] { currentTile, challenger.TileType }, 72, 96, seed ^ 15485863,
            includeUnready: true, fastStructural: true);
        Publish(confirmation);
        var comparison = confirmation.Comparisons.FirstOrDefault(c => c.TileType == challenger.TileType);
        var reference = confirmation.Candidates.FirstOrDefault(c => c.TileType == currentTile);
        var alternative = confirmation.Candidates.FirstOrDefault(c => c.TileType == challenger.TileType);
        if (confirmation.EffectiveSampleSize < 32 || comparison is null || reference is null || alternative is null
            || comparison.MeanNetDifference <= Math.Max(0.10, 2.4 * comparison.StandardError)
            || alternative.InitialDealInProbability > reference.InitialDealInProbability + 0.02)
            return new(-1, "confirmation_retains_current", discovery, confirmation);
        return new(challenger.TileType, "BUCKET_FULL_CONTINUATION_SELECTION", discovery, confirmation);

        int PairSupply(int discard)
        {
            var supply = 0;
            for (var tile = 0; tile < 27; tile++)
            {
                if (state.Hand18[tile] - (tile == discard ? 1 : 0) < 2 || state.Remaining18[tile] <= 0) continue;
                supply += Enumerable.Range(0,4).Count(s => s != state.SeatIndex
                    && state.ActiveSeats[s] && !state.HasHu[s] && state.DingQueSuits[s] == tile / 9);
            }
            return supply;
        }
        void Publish(SichuanPublicContinuationReport report)
        {
            foreach (var estimate in report.Candidates)
            {
                var candidate = candidates.First(c => c.TileType == estimate.TileType);
                candidate.BucketContinuationSamples = report.ParticleCount;
                candidate.BucketContinuationEffectiveSamples = report.EffectiveSampleSize;
                candidate.BucketContinuationNet = estimate.NetScore;
                candidate.BucketContinuationPeng = estimate.ExpectedOwnPengClaims;
                candidate.BucketContinuationStandardError = report.Comparisons
                    .First(c => c.TileType == estimate.TileType).StandardError;
            }
        }
    }
}
