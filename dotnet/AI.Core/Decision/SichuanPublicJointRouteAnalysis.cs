using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanPublicJointRouteCandidate(int DiscardTile, SichuanJointRouteEstimate Estimate);
public sealed record SichuanPublicJointRouteReport(
    bool Supported, string Reason, int FixedScheduleOwnDrawBudget, int SampleCount,
    double EffectiveSampleSize, IReadOnlyList<SichuanPublicJointRouteCandidate> Candidates)
{
    public string Scope => "Uncalibrated public-hypothesis model; fixed current-active-seat schedule with no future claims/exits; "
        + "ordered discards and current meld allocation, but no meld-timing likelihood; "
        + "no intervening observations; at most two own draws; not full-game EV or policy promotion";
}

/// <summary>
/// Diagnostic production component. Samples ONLY from a freshly constructed
/// public projection; no wall/hypotheses parameter is exposed by the facade.
/// current action selection is unchanged pending model and strength validation.
/// </summary>
public sealed class SichuanPublicJointRouteAnalysis
{
    public SichuanPublicJointRouteReport Analyze(SichuanStateView state, int sampleCount, int seed)
    {
        if (!SichuanPublicInferenceBoundary.TryProject(state, out var projection, out var reason))
            return Rejected(reason);
        if (sampleCount is < 32 or > 4096) throw new ArgumentOutOfRangeException(nameof(sampleCount));
        var particles = new SichuanHiddenHandInferenceEngine().SampleParticles(
            projection, sampleCount, seed, SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        // The legacy sampler can emit an empty-hand fallback. Never treat that
        // as a valid wall or silently resize it to fit an incomplete snapshot.
        if (particles.Count != sampleCount
            || particles.Any(particle => !SichuanPublicInferenceBoundary.ParticleConserves(state, particle)))
            return Rejected("sample_conservation_failed");

        var wall = new SichuanJointWallDrawModel(particles.Select(p => new SichuanWeightedWall(p.Wall27, p.Weight)).ToArray());
        var budget = SichuanJointRouteEvaluator.FixedScheduleOwnDrawBudget(
            state.WallCount, state.ActiveSeats.Count(active => active));
        var ownMelds = new int[27];
        foreach (var tile in projection.Melds18[state.SeatIndex]) ownMelds[tile]++;
        var evaluator = new SichuanJointRouteEvaluator();
        var candidates = new List<SichuanPublicJointRouteCandidate>();
        for (var discard = 0; discard < 27; discard++)
        {
            if (state.Hand18[discard] == 0) continue;
            var hand = (int[])state.Hand18.Clone();
            hand[discard]--;
            candidates.Add(new(discard, evaluator.Evaluate(hand, ownMelds, wall, budget, state.OwnDingQueSuit)));
        }
        return new(true, "public_joint_model_diagnostic", budget, particles.Count,
            wall.EffectiveSampleSize, candidates.AsReadOnly());
    }

    private static SichuanPublicJointRouteReport Rejected(string reason)
        => new(false, reason, 0, 0, 0, Array.Empty<SichuanPublicJointRouteCandidate>());

}
