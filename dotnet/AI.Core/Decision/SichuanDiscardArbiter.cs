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

    public int Resolve(bool settleNow = false,
        IReadOnlyDictionary<int, SichuanDecisionCandidate>? readyValues = null)
    {
        if (settleNow && _candidates.Count > 0)
        {
            // No future draw remains. Compare every legal, already-priced
            // candidate; arbitrary danger tiers cannot override the common
            // settlement value. A costly live deal-in may still justify folding.
            var terminalWinner = _candidates.Values.OrderByDescending(c => c.UnifiedActionValue)
                .ThenBy(c => c.ExpectedDealInLoss).ThenBy(c => c.Danger).ThenBy(c => c.TileType).First();
            var terminalPrevious = SelectedTile;
            _steps.Clear();
            foreach (var p in _proposals)
                _steps.Add(new(p.Module, p.Tile, p.Priority, false, terminalPrevious, "wall_empty_common_value_required"));
            _steps.Add(new("WALL_EMPTY_COMMON_SETTLEMENT_VALUE", terminalWinner.TileType, int.MaxValue,
                true, terminalPrevious, "all_legal_candidates_common_value_comparison"));
            SelectedTile = terminalWinner.TileType;
            return SelectedTile;
        }
        var winner = _proposals.OrderByDescending(p => p.Priority)
            .ThenByDescending(p => _candidates.GetValueOrDefault(p.Tile)?.ExpectedValue ?? 0)
            .ThenBy(p => _candidates.GetValueOrDefault(p.Tile)?.Danger ?? 0)
            .ThenBy(p => p.Tile).ThenBy(p => p.Module, StringComparer.Ordinal).FirstOrDefault();
        var previous = SelectedTile;
        _steps.Clear();
        foreach (var p in _proposals)
            _steps.Add(new(p.Module, p.Tile, p.Priority, p == winner, previous,
                p == winner ? "central_value_selection" : p.Priority < winner.Priority
                    ? "higher_priority_constraint" : "same_priority_common_value_comparison"));
        if (_proposals.Count > 0) SelectedTile = winner.Tile;
        if((_proposals.Count==0||winner.Priority<SafeTempo)&&_candidates.Count>0
            &&_candidates.Values.All(c=>c.Reasons.Contains("SEVEN_PAIRS_SHARED_WIN_PRICE_DELAY_LOSS_NO_ROUTE_OR_DISTANCE_BONUS")))
        {
            var common=_candidates.Values.OrderByDescending(c=>c.UnifiedActionValue)
                .ThenBy(c=>c.Danger).ThenByDescending(c=>c.ExpectedValue).ThenBy(c=>c.TileType).First();
            for(int i=0;i<_steps.Count;i++)if(_steps[i].Accepted)
                _steps[i]=_steps[i] with{Accepted=false,Reason="complete_common_development_value_required"};
            _steps.Add(new("COMMON_BOUNDED_DEVELOPMENT_VALUE",common.TileType,GlobalPlan,true,SelectedTile,
                "all_legal_candidates_same_win_delay_and_risk_model"));
            SelectedTile=common.TileType;
        }
        // The initial implementation uses a Pareto boundary rather than an
        // invented "close risk" tolerance: identical per-wait prices, no
        // greater priced risk, and no lost Gang value. Exact wait prices also
        // preserve the legal ready/cha-jiao price; its expected payment need
        // not be greater, since winning first removes the cha-jiao event.
        // A structure
        // bonus cannot defeat a strictly higher modeled Hu chance here.
        // Hard safety/ready-settlement constraints retain their authority.
        if ((_proposals.Count == 0 || winner.Priority < SafeTempo)
            && readyValues is not null && readyValues.TryGetValue(SelectedTile, out var current)
            && current.ModeledOwnWinProbability is not null && current.ReadyPrice is { Waits.Count: > 0 })
        {
            var prices = current.ReadyPrice.Waits.Select(w => (w.CappedFan, w.HandScore, w.SelfDrawPerPayer)).Distinct().ToArray();
            if (prices.Length == 1)
            {
                var higher = readyValues.Values.Where(c => _legal.Contains(c.Action.TileType)
                    && c.IsAdmissible && c.ReadyPrice is { Waits.Count: > 0 }
                    && c.ReadyPrice.Waits.All(w => (w.CappedFan, w.HandScore, w.SelfDrawPerPayer) == prices[0])
                    && c.ModeledOwnWinProbability > current.ModeledOwnWinProbability + 1e-9
                    && c.DealInLoss <= current.DealInLoss + 1e-9
                    && c.OpponentFutureLoss <= current.OpponentFutureLoss + 1e-9
                    && c.GangGain + 1e-9 >= current.GangGain)
                    .OrderByDescending(c => c.ModeledOwnWinProbability)
                    .ThenByDescending(c => c.ExpectedNetScore).ThenBy(c => c.Action.TileType).FirstOrDefault();
                if (higher is not null)
                {
                    for (var i = 0; i < _steps.Count; i++)
                        if (_steps[i].Accepted) _steps[i] = _steps[i] with { Accepted = false, Reason = "ready_probability_constraint" };
                    _steps.Add(new("SAME_PRICE_NO_GREATER_COST_HIGHER_HU_PROBABILITY", higher.Action.TileType,
                        GlobalPlan, true, SelectedTile, "shared_model_probability_dominance"));
                    SelectedTile = higher.Action.TileType;
                }
            }
        }
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
