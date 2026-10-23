namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Research simulations reuse the live strategy. Terminal simulation
/// is forbidden while choosing an action. AsyncLocal isolates requests.</summary>
public sealed class SichuanPolicyExecutionScope : IDisposable
{
    public const string PolicyDescription = "production_strategy_adaptive_budget_v3";
    private static readonly AsyncLocal<int> Depth = new();
    private static readonly AsyncLocal<int> DecisionDepth = new();
    private static readonly AsyncLocal<System.Collections.Concurrent.ConcurrentDictionary<(string Key,object? Context),object>?> DecisionValues = new();
    internal static T Memoize<T>(string key, object? context, Func<T> compute) where T : class
    {
        var values=DecisionValues.Value;
        if(values is null)return compute();
        if(values.TryGetValue((key,context),out var saved))return (T)saved;
        var result=compute();values[(key,context)]=result;return result;
    }
    internal static T? ReadMemoized<T>(string key, object? context) where T : class
        => DecisionValues.Value?.TryGetValue((key, context), out var value) == true ? (T)value : null;
    public static bool IsSimulation => Depth.Value > 0;
    public static IDisposable EnterDecision() => new DecisionScope();
    public static void RequireResearchContext()
    {
        if (DecisionDepth.Value > 0)
            throw new InvalidOperationException("Terminal simulation is research-only and cannot run inside a live strategy decision.");
    }
    private sealed class DecisionScope : IDisposable
    {
        public DecisionScope()
        {
            if(DecisionDepth.Value==0)DecisionValues.Value=new();
            DecisionDepth.Value++;
        }
        public void Dispose()
        {
            DecisionDepth.Value--;
            if(DecisionDepth.Value==0)DecisionValues.Value=null;
        }
    }
    private static readonly AsyncLocal<SichuanMahjong.AI.Core.Models.SichuanRoundBrainSnapshot?> Memory = new();
    public static SichuanMahjong.AI.Core.Models.SichuanRoundBrainSnapshot? OwnPlan => Memory.Value;
    public static IDisposable UseOwnPlan(SichuanMahjong.AI.Core.Models.SichuanRoundBrainSnapshot? plan) => new PlanScope(plan);
    private sealed class PlanScope : IDisposable
    {
        private readonly SichuanMahjong.AI.Core.Models.SichuanRoundBrainSnapshot? _previous;
        public PlanScope(SichuanMahjong.AI.Core.Models.SichuanRoundBrainSnapshot? plan) { _previous=Memory.Value; Memory.Value=plan; }
        public void Dispose() { Memory.Value=_previous; }
    }
    public SichuanPolicyExecutionScope() { Depth.Value++; }
    public void Dispose() { Depth.Value--; }
}
