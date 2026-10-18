using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanArbitrationStep(string Module, int ProposedTile, int Priority,
    bool Accepted, int PreviousTile, string Reason);

/// <summary>Ordinal authority, not calibrated value: legality, hard exits/safety,
/// committed plan, then local candidate quality. Lower authority cannot undo a hard decision.</summary>
public sealed class SichuanDiscardArbiter
{
    public const int CandidateValue = 10, GlobalPlan = 20, SafeTempo = 80,
        ExtremeSafety = 100, LateDefense = 110, SafeReadySettlement = 90, OpponentWideBedDefense = 95;
    private readonly HashSet<int> _legal;
    private readonly List<SichuanArbitrationStep> _steps = new();
    private int _priority;
    public int SelectedTile { get; private set; }
    public IReadOnlyList<SichuanArbitrationStep> Steps => _steps.ToArray();
    public SichuanDiscardArbiter(IEnumerable<int> legal, int initial)
    {
        _legal = legal.ToHashSet();
        if (!_legal.Contains(initial)) throw new InvalidOperationException("arbitration_illegal_initial");
        SelectedTile = initial;
    }
    public bool TrySelect(int tile, int priority, string module)
    {
        var legal = _legal.Contains(tile);
        var accepted = legal && priority >= _priority;
        _steps.Add(new(module, tile, priority, accepted, SelectedTile,
            !legal ? "illegal_candidate" : accepted ? "eligible_priority" : "higher_priority_decision_protected"));
        if (accepted) { SelectedTile = tile; _priority = priority; }
        return accepted;
    }

    /// <summary>Public-supply Pareto comparison. No terminal rollout or scalar
    /// conversion of bucket supply into claimed expected settlement income.</summary>
    public static SichuanCandidateDetail? SelectBucketDominance(IReadOnlyList<SichuanCandidateDetail> candidates, int current)
    {
        var b = candidates.First(c => c.TileType == current);
        if (!b.BucketSupported) return null;
        return candidates.Where(c => c.TileType != current && c.BucketSupported
            && c.Shanten == b.Shanten && c.Danger <= b.Danger
            && c.LiveUkeire >= b.LiveUkeire && c.Ukeire >= b.Ukeire
            && c.UnifiedActionValue >= b.UnifiedActionValue
            && (!c.BreaksPair || b.BreaksPair) && (!c.BreaksTriplet || b.BreaksTriplet)
            && c.RouteLoss.All(b.RouteLoss.Contains)
            && c.BucketCapacityOverflow <= b.BucketCapacityOverflow
            && c.BucketWeakestCompletionMass >= b.BucketWeakestCompletionMass
            && c.BucketNextCompletionMass >= b.BucketNextCompletionMass
            && c.BucketTotalImprovementMass >= b.BucketTotalImprovementMass
            && (c.BucketCapacityOverflow < b.BucketCapacityOverflow
                || c.BucketWeakestCompletionMass > b.BucketWeakestCompletionMass
                || c.BucketNextCompletionMass > b.BucketNextCompletionMass
                || c.BucketTotalImprovementMass > b.BucketTotalImprovementMass))
            .OrderBy(c => c.BucketCapacityOverflow).ThenByDescending(c => c.BucketWeakestCompletionMass)
            .ThenByDescending(c => c.BucketNextCompletionMass).ThenByDescending(c => c.BucketTotalImprovementMass)
            .ThenByDescending(c => c.Score).ThenBy(c => c.TileType).FirstOrDefault();
    }
}
