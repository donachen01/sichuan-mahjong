using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Compute allocation only. One escalation at the actual decision
/// root; hypothetical continuations cannot request another expensive search.
/// Scores remain heuristic units, not confidence intervals or settlement EV.</summary>
public static class SichuanSearchBudget
{
    public sealed record Option(string Action, double Score, int Shanten, double Live, double Risk = 0);
    private sealed class Budget(string root)
    {
        public string Root { get; } = root;
        public int Used;
        public bool MeldDepth;
        public bool RootDiscardOnly;
        public bool TerminalDepth;
        public string Reason = "SEARCH_BUDGET_FAST";
    }
    private static readonly AsyncLocal<Budget?> Current = new();
    private static readonly AsyncLocal<int> BranchDepth = new();
    public static bool Adaptive => Current.Value is not null;
    public static bool IsRoot(SichuanStateView state) => BranchDepth.Value == 0 && Current.Value?.Root == SichuanDecisionCommand.Fingerprint(state);
    public static bool RootDiscardOnly => Current.Value?.RootDiscardOnly == true;
    public static void AllowRootDiscardSearch(SichuanStateView state, bool allowed)
    { if (IsRoot(state)) Current.Value!.RootDiscardOnly = allowed; }
    public static IDisposable EnterBranch()
    { BranchDepth.Value++; return new Scope(() => BranchDepth.Value--); }
    public static bool DeepMeld => Current.Value?.MeldDepth == true;
    public static bool FastTerminal => Adaptive && Current.Value?.TerminalDepth != true;
    public static string CacheTag => DeepMeld ? "adaptive-deep-meld" : FastTerminal ? "adaptive-fast" : "legacy";
    public static string Reason => Current.Value?.Reason ?? "SEARCH_BUDGET_LEGACY";

    public static IDisposable Enter(SichuanStateView state)
    {
        if (Current.Value is not null || state.PolicyVariant is not ("current" or "adaptive_search_v1" or "before_round2_v1" or "pre_learning_closure_v1" or "ready_stopping_candidate" or "completion_candidate" or "terminal_retention_candidate" or "gap_candidate"))
            return new Scope(() => { });
        Current.Value = new(SichuanDecisionCommand.Fingerprint(state));
        return new Scope(() => Current.Value = null);
    }

    // The 90-unit proximity filter is the existing reaction search budget
    // scale. It is deliberately not used as a financial preference bonus.
    public static string? Qualify(SichuanStateView state, IReadOnlyList<Option> options, bool highThreat = false)
    {
        var budget = Current.Value;
        if (budget is null || Volatile.Read(ref budget.Used) != 0 || SichuanDiscardPolicy.AtSearchLeaf
            || BranchDepth.Value > 0 || budget.Root != SichuanDecisionCommand.Fingerprint(state) || state.WallCount <= 0)
            return null;
        var ordered = options.Where(o => double.IsFinite(o.Score) && o.Score > int.MinValue / 8)
            .OrderByDescending(o => o.Score).ThenBy(o => o.Action, StringComparer.Ordinal).Take(2).ToArray();
        if (ordered.Length != 2 || ordered[0].Score - ordered[1].Score > 90) return null;
        var a = ordered[0]; var b = ordered[1];
        bool Ready(Option o) => o.Shanten == 0 && o.Live > 0;
        if (Ready(a) != Ready(b) && state.WallCount <= 24
            && Math.Min(a.Shanten, b.Shanten) == 0
            && Math.Max(a.Shanten, b.Shanten) <= 1)
            return "SEARCH_DEEP_READY_SPEED_CONFLICT";
        if (Ready(a) && Ready(b) && Math.Min(a.Live, b.Live) <= 2 && Math.Max(a.Live, b.Live) > 2)
            return "SEARCH_DEEP_THIN_WAIT_CONFLICT";
        if (highThreat && Math.Abs(a.Risk - b.Risk) >= 0.10 && Math.Min(a.Shanten, b.Shanten) <= 1)
            return "SEARCH_DEEP_PUBLIC_RISK_CONFLICT";
        int players = Math.Max(2, Enumerable.Range(0, 4).Count(s => state.ActiveSeats[s] && !state.HasHu[s]));
        if (state.WallCount <= players * 2 && options.Any(o => o.Action.Contains("gang", StringComparison.Ordinal))
            && (a.Shanten != b.Shanten || a.Shanten > 0 || Math.Min(a.Live, b.Live) <= 0))
            return "SEARCH_DEEP_TERMINAL_GANG_REFUND";
        return null;
    }

    public static IDisposable? TryDeep(SichuanStateView state, string? reason, bool meld = false, bool terminal = false)
    {
        var b = Current.Value;
        if (reason is null || b is null || Volatile.Read(ref b.Used) != 0 || SichuanDiscardPolicy.AtSearchLeaf
            || BranchDepth.Value > 0 || b.Root != SichuanDecisionCommand.Fingerprint(state)) return null;
        if (Interlocked.CompareExchange(ref b.Used, 1, 0) != 0) return null; b.MeldDepth = meld; b.TerminalDepth = terminal; b.Reason = reason;
        using (SichuanPolicyTiming.Measure("adaptive_deep_trigger")) { }
        return new Scope(() => { b.MeldDepth = false; b.TerminalDepth = false; });
    }

    private sealed class Scope(Action end) : IDisposable
    {
        private Action? _end = end;
        public void Dispose() => Interlocked.Exchange(ref _end, null)?.Invoke();
    }
}
