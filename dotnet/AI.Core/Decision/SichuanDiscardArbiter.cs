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
    private readonly Dictionary<int, SichuanCandidateDetail> _candidates = new();
    private readonly List<(int Tile, int Priority, string Module)> _proposals = new();
    public int SelectedTile { get; private set; }
    public IReadOnlyList<SichuanArbitrationStep> Steps => _steps.ToArray();
    public SichuanDiscardArbiter(IEnumerable<int> legal, int initial)
    {
        _legal = legal.ToHashSet();
        if (!_legal.Contains(initial)) throw new InvalidOperationException("arbitration_illegal_initial");
        SelectedTile = initial;
    }
    public SichuanDiscardArbiter(IEnumerable<SichuanCandidateDetail> candidates, int initial)
        : this(candidates.Select(c => c.TileType), initial)
        => _candidates = candidates.ToDictionary(c => c.TileType);

    public void Propose(int tile, int priority, string module)
    {
        if (!_legal.Contains(tile)) throw new InvalidOperationException("arbitration_illegal_proposal");
        _proposals.Add((tile, priority, module));
    }

    public int Resolve()
    {
        if (_proposals.Count == 0) return SelectedTile;
        var winner = _proposals.OrderByDescending(p => p.Priority)
            .ThenByDescending(p => _candidates.GetValueOrDefault(p.Tile)?.ExpectedValue ?? 0)
            .ThenBy(p => _candidates.GetValueOrDefault(p.Tile)?.Danger ?? 0)
            .ThenBy(p => p.Tile).ThenBy(p => p.Module, StringComparer.Ordinal).First();
        var previous = SelectedTile;
        _steps.Clear();
        foreach (var p in _proposals)
            _steps.Add(new(p.Module, p.Tile, p.Priority, p == winner, previous,
                p == winner ? "central_value_selection" : p.Priority < winner.Priority
                    ? "higher_priority_constraint" : "same_priority_common_value_comparison"));
        SelectedTile = winner.Tile;
        return SelectedTile;
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
